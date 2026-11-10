extends RefCounted
## The land claimed, as the server tells it (Protocol.CLAIMS, SQUARES, LAND; the rules
## are src/shared/game/territory.gd): a copy of the claims and squares (`copy`, a
## Territory with no rules), how many squares the player and their team hold and may
## hold, and the painting mode (`painting`, turned on and off by a tap on one's own
## boundary post: taps on the ground paint squares or clear them, LAND_PAINT). Tells
## whose land the player stands on as they walk (`entered`, from `update`; `here`), and
## the colour each owner picked (`color`, UiStyle.LAND_COLORS). `game` is the Main node.

const Territory := preload("res://src/shared/game/territory.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Items := preload("res://src/shared/content/items.gd")

## How long after asking to set a post down its claim still starts painting.
const EXPECT_MS := 10000
## How many cells over its foot the column of a post's square reaches for a tap (the post
## stands in it): a tap anywhere in that column is a tap on the post.
const POST_HEIGHT := 3

## Something changed: the claims, the squares, the count, the mode.
signal changed
## The player walked into claim `claim` ({} out of every claim); `own` it is theirs or
## their team's.
signal entered(claim: Dictionary, own: bool)
## Painting was turned on (`on`) or off by the player's tap or their new post.
signal painting_toggled(on: bool)

var game
var copy := Territory.new()
var used := 0
var budget := 0
var painting := false
## The claim the player stood in last frame (its id, 0 for none).
var _in := -1
## Until when (Time.get_ticks_msec) a new claim of the player's is a post they have just
## asked to set down (expect_post): painting starts with it. A claim told otherwise (the
## world loaded on entering the game, a rejoin) leaves painting off.
var _expect_until := 0


func _init() -> void:
	copy.claims_changed.connect(_changed)
	copy.squares_changed.connect(_on_squares)


func take_claims(list: Array) -> void:
	var had := {}
	for id: int in copy.claims:
		had[id] = true
	copy.take_claims(list)
	if Time.get_ticks_msec() < _expect_until:
		for claim: Dictionary in copy.claims.values():
			if not had.has(claim.id) and claim.by == me():
				# A post just set down: its square is the player's already, the rest to paint.
				_expect_until = 0
				toggle_painting(true)


## The player asks the server to set item `id` down: when it claims land (a boundary
## post), the claim told within a few seconds starts painting.
func expect_post(id: String) -> void:
	if Items.get_item(id).get("claims", false):
		_expect_until = Time.get_ticks_msec() + EXPECT_MS


func take_squares(list: Array, all: bool) -> void:
	copy.take_squares(list, all)


func take_land(args: Array) -> void:
	used = int(args[0])
	budget = int(args[1])
	changed.emit()


## True when claim `claim` is the player's or their team's.
func own(claim: Dictionary) -> bool:
	if claim.is_empty():
		return false
	if claim.by == me():
		return true
	for m: Array in game.team.view.get("members", []):
		if m[0] == claim.by:
			return true
	return false


## True when the player or their team has a claim (painting makes sense).
func has_own() -> bool:
	for claim: Dictionary in copy.claims.values():
		if own(claim):
			return true
	return false


## The claim the player stands in ({} for none).
func here() -> Dictionary:
	return copy.claims.get(_in, {}) if _in > 0 else {}


## The colour of the land of claim `claim`'s owner (UiStyle.LAND_COLORS).
func color(claim: Dictionary) -> Color:
	return UiStyle.LAND_COLORS[clampi(copy.color_of(claim.get("by", 0)), 0, UiStyle.LAND_COLORS.size() - 1)]


## The colour the player picked for their land, a number.
func my_color() -> int:
	return copy.color_of(me())


## Picks colour `i` for the player's land, through the server.
func set_color(i: int) -> void:
	game.net.request(Protocol.LAND_COLOR, [i])


## A tap on placed thing `e` that claims land (a boundary post): the owner's (or their
## team's) turns painting on or off; true when it was theirs.
func tap_post(e: Dictionary) -> bool:
	for claim: Dictionary in copy.claims.values():
		if claim.center == e.cell and own(claim):
			toggle_painting(not painting)
			return true
	return false


## Whether cell `cell` lies in the square of the post of a claim of the player's (or
## their team's), within its levels: a tap there turns painting on or off, as a tap on
## the post does.
func is_post_square(cell: Vector3i) -> bool:
	var claim := copy.claim_at(cell)
	return own(claim) and claim.sq == Territory.square_of(cell)


## Whether the ray from `o` along `d` (in cells) goes into the column of the square of
## a post of the player's (or their team's) before `far` (how far along it the world's
## first cell is, INF for none): the post and the ground of its first square answer a
## tap alike.
func hits_post_square(o: Vector3, d: Vector3, far: float) -> bool:
	for claim: Dictionary in copy.claims.values():
		if not own(claim):
			continue
		var lo := Vector3(claim.sq.x * Territory.SQUARE, claim.center.y - 1, claim.sq.y * Territory.SQUARE)
		var hi := lo + Vector3(Territory.SQUARE, 1 + POST_HEIGHT, Territory.SQUARE)
		var t := _enter_box(o, d, lo, hi)
		if t < INF and t <= far + 0.001:
			return true
	return false


## How far along ray `o`, `d` it enters box `lo`..`hi`; INF when it misses it.
static func _enter_box(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> float:
	var t0 := -INF
	var t1 := INF
	for axis in 3:
		if absf(d[axis]) < 0.000001:
			if o[axis] < lo[axis] or o[axis] > hi[axis]:
				return INF
			continue
		var a := (lo[axis] - o[axis]) / d[axis]
		var b := (hi[axis] - o[axis]) / d[axis]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return t0 if t0 <= t1 and t1 >= 0.0 else INF


## Turns painting on or off as the player asked (painting_toggled tells the HUD).
func toggle_painting(on: bool) -> void:
	set_painting(on)
	painting_toggled.emit(on)


## The player's own number (0 in a game of one's own).
func me() -> int:
	return int(game.welcome.get("id", 0))


## True when the player has set a claim themselves (their rights are theirs to set).
func has_mine() -> bool:
	for claim: Dictionary in copy.claims.values():
		if claim.by == me():
			return true
	return false


## What the player lets others do in their land: [team mask, others mask].
func my_rights() -> Array:
	return copy.rights_of(me())


## Lets others do what masks `team` and `others` say (Territory.ACTIONS bits), through
## the server.
func set_rights(team: int, others: int) -> void:
	game.net.request(Protocol.LAND_RIGHTS, [team, others])


## The words of what the player may do in claim `claim` of another (Territory.TITLES,
## from a small letter), [] for nothing.
func may_here(claim: Dictionary) -> Array:
	var out := []
	for a: String in Territory.ACTIONS:
		if copy.allowed(claim, me(), a):
			out.append(Territory.TITLES[a].to_lower())
	return out


## The claim at square `sq` ({} for none).
func claim_of(sq: Vector2i) -> Dictionary:
	var id: int = copy.squares.get(sq, 0)
	return copy.claims.get(id, {}) if id != 0 else {}


func set_painting(on: bool) -> void:
	if painting != on:
		painting = on
		changed.emit()


## Paints square `sq` (`on`) or clears it, through the server.
func paint(sq: Vector2i, on: bool) -> void:
	game.net.request(Protocol.LAND_PAINT, [sq, on])


## Each frame: tells when the player's feet go into another claim.
func update() -> void:
	if painting and not has_own():
		set_painting(false)
	var p: Vector3 = game.player.position
	var cell := Vector3i(floori(p.x / WorldData.CELL), game.player.level(), floori(p.z / WorldData.CELL))
	var claim := copy.claim_at(cell)
	var id: int = claim.get("id", 0)
	if id != _in:
		var first := _in == -1
		_in = id
		if not first or id != 0:
			entered.emit(claim, own(claim))
		changed.emit()


func _changed() -> void:
	changed.emit()


func _on_squares(_list: Array) -> void:
	changed.emit()
