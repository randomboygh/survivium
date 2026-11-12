extends RefCounted
## The land claimed in a world (plan/design/territory-pvp.md, decision 15; the user's
## picks 2026-11-02: 1А, 2А): a thing that `claims` (a boundary post), set down by a
## player, is the centre of a claim of theirs; around it the player, or anyone of their
## team, paints squares of two by two cells (SQUARE) by hand, each touching the claim's
## squares already painted, no farther than `territory_radius` squares from the centre,
## not on another's. A claim holds its squares on all levels within `territory_levels`
## of the centre's. How many squares a player may hold: `territory_start` and
## `territory_per_level` for each level of all their skills (Rules, decision 39: SkillSet.total,
## kept in `skilled` as `step` sees the players); a team holds its biggest member's and half of the others'
## together (decision 15). The centre taken away, the claim is gone with its squares.
## In another's claim a player may do only what its owner lets their team or the others
## do (`rights`, ACTIONS; `may`, asked by the rules that change the world, and
## `step_walk`, which puts one back who may not walk there; the user's pick 3А).
## Players are named by their number (Player.id), their teams by Teams. Kept in the
## world's save (to_dict, from_dict); a client keeps a copy fed by the server's events
## (take_claims, take_squares). Changes are told by `squares_changed` (the squares and
## the claim each now belongs to, 0 for none) and `claims_changed`.
## A claim nobody of its owner's team has stood in for `territory_abandon_hours` of the
## world's running time decays (plan/design/territory-pvp.md «Заброшенные территории»),
## a stage each `territory_decay_hours` more (`step`, `_decay`): by Rules'
## `territory_decay` its protection weakens (others may walk and open, then break and
## harvest: DECAY_MASKS by the claim's `weak`), it shrinks to the nearer squares, or
## both; after DECAY_STAGES stages it is nobody's land (the post stays, anyone may take
## it). One of the team standing in it again gives it its protection back; squares lost
## are painted again by hand.

const WorldData := preload("res://src/shared/world/world_data.gd")
const Lang := preload("res://src/shared/content/lang.gd")

## Cells along each side of a square.
const SQUARE := 2
## What a player may do in another's land (the user's pick 3А): each a bit of the masks
## of `rights`, in this order, with its words. Doors and touching animals are kept for
## when there are doors and tame animals; hitting players is Т5's (PvP).
const ACTIONS := ["walk", "build", "doors", "chests", "harvest", "animals", "hit_animals", "hit_players"]
const TITLES := {"walk": "[walk]", "build": "[build_and_break]", "doors": "[open_doors]",
	"chests": "[take_from_chests]", "harvest": "[harvest]", "animals": "[touch_animals]",
	"hit_animals": "[hit_animals]", "hit_players": "[hit_players]"}
## By default the owner's team may do everything, the others only walk (decision 101).
const TEAM_DEFAULT := 255
const OTHERS_DEFAULT := 1
## How many colours an owner may pick from for their land.
const COLORS := 8
## What the others may do besides the owner's rights in a claim weakened by `weak`
## stages of neglect: nothing more; walk, open doors and chests; and build, break,
## harvest and touch and hit the animals (hitting players stays the owner's to say).
const DECAY_MASKS := [0, 1 | 4 | 8, 127]
## The stage of neglect at which a claim is gone.
const DECAY_STAGES := 3

## Squares changed: [[square, claim (0 none)]…].
signal squares_changed(list: Array)
## A claim was made or taken away.
signal claims_changed

## The rules (Rules: territory_start, territory_per_level, territory_radius,
## territory_levels) and the teams (Teams); a copy on a client has neither.
var rules
var teams
## The claims by number: {"id", "center": the north-west cell of the thing (Vector3i),
## "sq": its square, "by": the player who set it, "count": its squares, "seen": `time`
## one of the team last stood in it, "stage": stages of neglect gone by, "weak": how far
## its protection has weakened (DECAY_MASKS)}.
var claims := {}
## The claim each square painted belongs to.
var squares := {}
## Game days each player has lived in the world.
var played := {}
## The sum of the levels of each player's skills (SkillSet.total), as `step` last saw it.
var skilled := {}
## What each owner lets others do in all their claims: {player: [team mask, others
## mask]} (bits of ACTIONS); the defaults for one not in it.
var rights := {}
## The colour each owner picked for their land, a number in the clients' palette
## (UiStyle.LAND_COLORS; 0 when none is picked).
var colors := {}
## Where each player last stood on land they may walk on (see step_walk).
var _walked := {}
var next_claim := 1
## Seconds the world has run (the server's ticks), by which claims are seen and decay.
var time := 0.0


## The square of cell `c` (x and z).
static func square_of(c: Vector3i) -> Vector2i:
	return Vector2i(c.x >> 1, c.z >> 1)


## The claim that holds cell `c` (its square, and its level within the claim's levels),
## {} for none.
func claim_at(c: Vector3i) -> Dictionary:
	var id: int = squares.get(square_of(c), 0)
	if id == 0:
		return {}
	var claim: Dictionary = claims.get(id, {})
	if claim.is_empty() or absi(c.y - claim.center.y) > _levels():
		return {}
	return claim


## True when player `id` is with the one who set claim `claim` (themselves or their team).
func with(claim: Dictionary, id: int) -> bool:
	if claim.is_empty():
		return false
	return claim.by == id or (teams != null and teams.together(claim.by, id))


## True when `who` stands in land of theirs or of their team: leaving the game there,
## the character goes at once (Server.linger_of).
func at_home(who) -> bool:
	return with(claim_at(_cell(who.position)), _id(who))


## What owner `owner` lets others do: [team mask, others mask].
func rights_of(owner: int) -> Array:
	return rights.get(owner, [TEAM_DEFAULT, OTHERS_DEFAULT])


## Player `id` sets what others may do in their land; true when it changed.
func set_rights(id: int, team: int, others: int) -> bool:
	var r := [clampi(team, 0, 255), clampi(others, 0, 255)]
	if r == rights_of(id):
		return false
	rights[id] = r
	claims_changed.emit()
	return true


## The colour owner `owner` picked for their land (0 for the first).
func color_of(owner: int) -> int:
	return int(colors.get(owner, 0))


## Player `id` picks colour `color` (0..COLORS - 1) for their land; true when it changed.
func set_color(id: int, color: int) -> bool:
	if color < 0 or color >= COLORS or color == color_of(id):
		return false
	colors[id] = color
	claims_changed.emit()
	return true


## Whether player `id` may do `action` (one of ACTIONS) in claim `claim`: always out of
## every claim and in their own; by the owner's rights for their team or the others.
func allowed(claim: Dictionary, id: int, action: String) -> bool:
	if claim.is_empty() or claim.by == id:
		return true
	var r := rights_of(claim.by)
	var mask: int = r[1] | DECAY_MASKS[clampi(int(claim.get("weak", 0)), 0, DECAY_MASKS.size() - 1)]
	if teams != null and teams.together(claim.by, id):
		mask = r[0]
	return mask & (1 << ACTIONS.find(action)) != 0


## Whether `who` may do `action` at cell `c`; false with a word to them.
func may(who, c: Vector3i, action: String) -> bool:
	var claim := claim_at(c)
	if allowed(claim, _id(who), action):
		return true
	who.nag("claim", Lang.line("[territory_not_allowed_here]", [title_of(claim), TITLES[action]]))
	return false


## The players walk: one in a claim they may not walk in is put back where they last
## stood on land they may (nothing when that is in such a claim too: the claim was made
## round them).
func step_walk(players: Array) -> void:
	for p in players:
		if p.is_dead():
			continue
		var id := _id(p)
		var claim := claim_at(_cell(p.position))
		if allowed(claim, id, "walk"):
			_walked[id] = p.position
			continue
		var back: Variant = _walked.get(id)
		if back != null and allowed(claim_at(_cell(back)), id, "walk"):
			p.teleport(back)
			p.nag("claim", Lang.line("[territory_no_entry]", [title_of(claim)]))


## The name of claim `claim`: its team's, or the one's who set it.
func title_of(claim: Dictionary) -> String:
	if teams != null and teams.team_of(claim.get("by", 0)) != 0:
		return str(teams.teams[teams.team_of(claim.by)].name)
	return str(claim.get("name", ""))


## The squares player `id` may hold: Rules' start and a share for each day lived;
## together with their team's (the biggest whole, half of each other).
func budget(id: int) -> int:
	var own := []
	for m: int in (teams.members(teams.team_of(id)) if teams != null and teams.team_of(id) != 0 else [id]):
		own.append(_own_budget(m))
	own.sort()
	var total := float(own.pop_back())
	for b: int in own:
		total += b * 0.5
	return int(total)


## The squares player `id` and their team hold.
func used(id: int) -> int:
	var n := 0
	for claim: Dictionary in claims.values():
		if with(claim, id):
			n += claim.count
	return n


## Whether `who` may set a thing that claims at cell `c`: false (with a word to them)
## in another's land or with no square left to hold.
func can_claim(who, c: Vector3i) -> bool:
	var there := claim_at(c)
	if not there.is_empty() and not with(there, who.id):
		who.nag("claim", "[this_is_someone_elses_territory]")
		return false
	if squares.has(square_of(c)):
		# Its own square is painted already: the claim takes no more.
		return true
	if used(who.id) >= budget(who.id):
		who.nag("claim", Lang.line("[no_plots_left_of]", [used(who.id), budget(who.id)]))
		return false
	return true


## Thing `e`, set down by player `by` named `name`, is the centre of a new claim; its
## square is painted for it unless it is already someone's. The claim's number.
func add_claim(by: int, e: Dictionary, name := "") -> int:
	var id := next_claim
	next_claim += 1
	var cell: Vector3i = e.cell
	claims[id] = {"id": id, "center": cell, "sq": square_of(cell), "by": by, "name": name, "count": 0,
		"seen": time, "stage": 0, "weak": 0}
	claims_changed.emit()
	if not squares.has(square_of(cell)):
		_assign([square_of(cell)], id)
	return id


## Takes back every square painted, of every player: each claim keeps only its post's
## square (the test page's «Очистка территории»). How many squares went.
func clear_painted() -> int:
	var gone := []
	for sq: Vector2i in squares:
		var claim: Dictionary = claims.get(squares[sq], {})
		if claim.is_empty() or claim.sq != sq:
			gone.append(sq)
	_assign(gone, 0)
	return gone.size()


## Thing `e` was taken out of the world (Placed.removed): a claim it was the centre of
## is gone with its squares.
func thing_removed(e: Dictionary) -> void:
	thing_gone(e.cell)


## The thing at `cell` was taken away: a claim it was the centre of is gone with its squares.
func thing_gone(cell: Vector3i) -> void:
	for id: int in claims.keys():
		if claims[id].center == cell:
			_drop(id)


## `who` paints square `sq` (`on`) or clears it: true when done. Painted: next to a
## square of a claim of theirs (or of their team), within the radius of its centre,
## nobody's yet, with a square left to hold; it goes to that claim. Cleared: a square of
## theirs other than a centre's, and the claim's squares stay joined to its centre.
func paint(who, sq: Vector2i, on: bool) -> bool:
	if on:
		if squares.has(sq):
			return false
		var to := 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var id: int = squares.get(sq + d, 0)
			if id != 0 and with(claims[id], who.id) and _within(claims[id], sq):
				to = id
				break
		if to == 0:
			return false
		if used(who.id) >= budget(who.id):
			who.nag("claim", Lang.line("[no_plots_left_of]", [used(who.id), budget(who.id)]))
			return false
		_assign([sq], to)
		return true
	var id: int = squares.get(sq, 0)
	if id == 0 or not with(claims[id], who.id) or claims[id].sq == sq or not _joined_without(id, sq):
		return false
	_assign([sq], 0)
	return true


## The days lived go by: each living player of `players` in the world adds `days`;
## `seconds` of the world's running go by: a claim one of its team stands in is seen
## (and protected again), one long unseen decays (`_decay`).
func step(days: float, players: Array, seconds := 0.0) -> void:
	time += seconds
	for p in players:
		if not p.is_dead():
			var id := _id(p)
			played[id] = float(played.get(id, 0.0)) + days
			var sk = p.get("skills")
			if sk != null:
				skilled[id] = sk.total()
			var claim := claim_at(_cell(p.position))
			if with(claim, id):
				claim.seen = time
				if int(claim.get("weak", 0)) > 0:
					claim.weak = 0
					claim.stage = 0
					p.nag("claim", "[the_territory_is_protected_again]")
					claims_changed.emit()
				else:
					claim.stage = 0
	if rules == null or seconds <= 0.0:
		return
	var abandon: float = rules.territory_abandon_hours * 3600.0
	var each: float = maxf(rules.territory_decay_hours * 3600.0, 1.0)
	for id: int in claims.keys():
		var claim: Dictionary = claims[id]
		var away: float = time - float(claim.get("seen", time))
		if away < abandon:
			continue
		var due := int((away - abandon) / each) + 1
		while claims.has(id) and int(claim.get("stage", 0)) < due:
			_decay(id)


## Claim `id` goes one stage further into neglect: by Rules' `territory_decay`
## ("rights", "radius" or "both") its protection weakens, its farther squares are
## let go (the claim keeps those within two thirds, then half, of its reach), or both;
## at DECAY_STAGES it is gone.
func _decay(id: int) -> void:
	var claim: Dictionary = claims[id]
	claim.stage = int(claim.get("stage", 0)) + 1
	if claim.stage >= DECAY_STAGES:
		_drop(id)
		return
	var how: String = rules.territory_decay
	if how != "radius":
		claim.weak = claim.stage
	if how != "rights":
		var reach := 0
		for sq: Vector2i in squares:
			if squares[sq] == id:
				reach = maxi(reach, _dist(claim, sq))
		var keep: int = reach * (DECAY_STAGES - claim.stage) / (DECAY_STAGES - claim.stage + 1)
		var gone := []
		for sq: Vector2i in squares:
			if squares[sq] == id and _dist(claim, sq) > keep:
				gone.append(sq)
		_assign(gone, 0)
		_assign(_cut_off(id), 0)
	claims_changed.emit()


## What a client is told of the claims: [[id, centre, by, the claim's name (title_of),
## its owner's rights, its owner's colour, how far its protection has weakened]…].
func claims_view() -> Array:
	var out := []
	for claim: Dictionary in claims.values():
		out.append([claim.id, claim.center, claim.by, title_of(claim), rights_of(claim.by), color_of(claim.by),
			int(claim.get("weak", 0))])
	return out


## Every square with its claim: [[square, claim]…].
func squares_view() -> Array:
	var out := []
	for sq: Vector2i in squares:
		out.append([sq, squares[sq]])
	return out


## A copy takes the claims the server told (claims_view), each with the name shown.
func take_claims(list: Array) -> void:
	var counts := {}
	for sq: Vector2i in squares:
		counts[squares[sq]] = int(counts.get(squares[sq], 0)) + 1
	claims.clear()
	rights.clear()
	colors.clear()
	for e in list:
		if e is Array and e.size() >= 4 and e[0] is int and e[1] is Vector3i and e[2] is int:
			claims[e[0]] = {"id": e[0], "center": e[1], "sq": square_of(e[1]), "by": e[2], "name": str(e[3]),
				"count": int(counts.get(e[0], 0))}
			if e.size() > 4 and e[4] is Array and e[4].size() == 2 and e[4][0] is int and e[4][1] is int:
				rights[e[2]] = e[4]
			if e.size() > 5 and e[5] is int:
				colors[e[2]] = e[5]
			if e.size() > 6 and e[6] is int:
				claims[e[0]].weak = clampi(e[6], 0, DECAY_MASKS.size() - 1)
	claims_changed.emit()


## A copy takes squares the server told: [[square, claim (0 none)]…]; `all` clears the rest first.
func take_squares(list: Array, all := false) -> void:
	if all:
		squares.clear()
		for claim: Dictionary in claims.values():
			claim.count = 0
	var told := []
	for e in list:
		if e is Array and e.size() == 2 and e[0] is Vector2i and e[1] is int:
			_put(e[0], e[1])
			told.append(e)
	squares_changed.emit(told)


func to_dict() -> Dictionary:
	var list := []
	for claim: Dictionary in claims.values():
		list.append({"id": claim.id, "center": [claim.center.x, claim.center.y, claim.center.z], "by": claim.by,
			"name": claim.get("name", ""), "seen": claim.get("seen", time), "stage": claim.get("stage", 0),
			"weak": claim.get("weak", 0)})
	var sq := []
	for s: Vector2i in squares:
		sq.append([s.x, s.y, squares[s]])
	var days := {}
	for id: int in played:
		days[str(id)] = played[id]
	var lv := {}
	for id: int in skilled:
		lv[str(id)] = skilled[id]
	var r := {}
	for id: int in rights:
		r[str(id)] = rights[id]
	var c := {}
	for id: int in colors:
		c[str(id)] = colors[id]
	return {"claims": list, "squares": sq, "played": days, "skilled": lv, "rights": r, "colors": c, "next": next_claim,
		"time": time}


func from_dict(d: Dictionary) -> void:
	claims.clear()
	squares.clear()
	played.clear()
	skilled.clear()
	next_claim = int(d.get("next", 1))
	time = float(d.get("time", 0.0))
	for e in d.get("claims", []):
		if e is Dictionary and e.get("center") is Array and e.center.size() == 3:
			var id := int(e.get("id", 0))
			var cell := Vector3i(int(e.center[0]), int(e.center[1]), int(e.center[2]))
			claims[id] = {"id": id, "center": cell, "sq": square_of(cell), "by": int(e.get("by", 0)),
				"name": str(e.get("name", "")), "count": 0, "seen": float(e.get("seen", time)),
				"stage": int(e.get("stage", 0)), "weak": clampi(int(e.get("weak", 0)), 0, DECAY_MASKS.size() - 1)}
			next_claim = maxi(next_claim, id + 1)
	for e in d.get("squares", []):
		if e is Array and e.size() == 3 and claims.has(int(e[2])):
			_put(Vector2i(int(e[0]), int(e[1])), int(e[2]))
	var days: Dictionary = d.get("played", {})
	for k in days:
		played[int(k)] = float(days[k])
	var lv: Dictionary = d.get("skilled", {})
	for k in lv:
		skilled[int(k)] = int(lv[k])
	rights.clear()
	var r: Dictionary = d.get("rights", {})
	for k in r:
		if r[k] is Array and r[k].size() == 2:
			rights[int(k)] = [int(r[k][0]), int(r[k][1])]
	colors.clear()
	var c: Dictionary = d.get("colors", {})
	for k in c:
		colors[int(k)] = clampi(int(c[k]), 0, COLORS - 1)
	# Whoever was told the land before (a player who joined before the save was read)
	# hears it again.
	claims_changed.emit()
	squares_changed.emit(squares_view())


static func _id(who) -> int:
	var id: Variant = who.get("id")
	return id if id is int else 0


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / WorldData.CELL), floori(p.y / WorldData.CELL + 0.01), floori(p.z / WorldData.CELL))


func _own_budget(id: int) -> int:
	if rules == null:
		return 0
	return rules.territory_start + rules.territory_per_level * int(skilled.get(id, 0))


func _levels() -> int:
	return rules.territory_levels if rules != null else 8


## Square `sq` is within the radius of claim `claim`'s centre.
func _within(claim: Dictionary, sq: Vector2i) -> bool:
	var r: int = rules.territory_radius if rules != null else 24
	return _dist(claim, sq) <= r


## Square `sq`'s distance from claim `claim`'s centre, in squares (the radius's measure).
static func _dist(claim: Dictionary, sq: Vector2i) -> int:
	return maxi(absi(sq.x - claim.sq.x), absi(sq.y - claim.sq.y))


## Claim `id` is gone with its squares.
func _drop(id: int) -> void:
	var gone := []
	for sq: Vector2i in squares:
		if squares[sq] == id:
			gone.append(sq)
	_assign(gone, 0)
	claims.erase(id)
	claims_changed.emit()


## The squares of claim `id` no longer joined to its centre's.
func _cut_off(id: int) -> Array:
	var claim: Dictionary = claims[id]
	var seen := {claim.sq: true}
	var todo: Array[Vector2i] = [claim.sq]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := at + d
			if not seen.has(n) and squares.get(n, 0) == id:
				seen[n] = true
				todo.append(n)
	var out := []
	for sq: Vector2i in squares:
		if squares[sq] == id and not seen.has(sq):
			out.append(sq)
	return out


## True when the squares of claim `id` but `sq` are all joined to its centre's.
func _joined_without(id: int, sq: Vector2i) -> bool:
	var claim: Dictionary = claims[id]
	var seen := {claim.sq: true}
	var todo: Array[Vector2i] = [claim.sq]
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := at + d
			if n != sq and not seen.has(n) and squares.get(n, 0) == id:
				seen[n] = true
				todo.append(n)
	return seen.size() == claim.count - 1


## Squares `list` go to claim `id` (0: nobody's); told.
func _assign(list: Array, id: int) -> void:
	var told := []
	for sq: Vector2i in list:
		_put(sq, id)
		told.append([sq, id])
	if not told.is_empty():
		squares_changed.emit(told)


func _put(sq: Vector2i, id: int) -> void:
	var was: int = squares.get(sq, 0)
	if was != 0 and claims.has(was):
		claims[was].count -= 1
	if id == 0:
		squares.erase(sq)
	else:
		squares[sq] = id
		if claims.has(id):
			claims[id].count += 1
