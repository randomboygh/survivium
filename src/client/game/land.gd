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

## Something changed: the claims, the squares, the count, the mode.
signal changed
## The player walked into claim `claim` ({} out of every claim); `own` it is theirs or
## their team's.
signal entered(claim: Dictionary, own: bool)

var game
var copy := Territory.new()
var used := 0
var budget := 0
var painting := false
## The claim the player stood in last frame (its id, 0 for none).
var _in := -1


func _init() -> void:
	copy.claims_changed.connect(_changed)
	copy.squares_changed.connect(_on_squares)


func take_claims(list: Array) -> void:
	copy.take_claims(list)


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
			set_painting(not painting)
			return true
	return false


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
