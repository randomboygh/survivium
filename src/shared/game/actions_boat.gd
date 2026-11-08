extends "res://src/shared/game/actions_tame.gd"
## Rafts and boats (plan/backlog.md; decision 178, answer 4Б). An item with `vessel` held
## in the hand is launched by the action button facing open water near the feet: it
## leaves the bag and floats there (Vessels), and the one who held it sits in it and rows
## (Character.riding, vessel, seat 0; Body.vessel: afloat at the item's share of the
## walking pace, a boat whose `oars` are not in the rower's bag at Character.OARLESS of
## it). The action button facing a vessel with a seat free boards it: the first aboard
## rows, a second is carried (seat 1) wherever the rower takes it. The action button
## facing the shore steps ashore and leaves the vessel moored where it floats (a rower
## leaving hands the oars to the one carried); a tap on a moored vessel no one sits in
## takes it back up into the bag (take_vessel). Water freezing under a vessel puts its
## riders on the nearest shore (step_boats); a death leaves the vessel where it floats.
## A river's current (Currents, answer 5А) carries a body in its water or afloat
## (Character.flow, Body.flow: a raft rows up it slowly, a boat with oars well), and the
## things lying in its water near the players (step_drift).

const Body := preload("res://src/shared/game/body.gd")
const VesselsScript := preload("res://src/shared/game/vessels.gd")

## How far ahead of the body water is looked for to launch on (cells, half a cell at a
## time), and how far the water's surface may be under or over the feet.
const LAUNCH_REACH := 2.0
const LAUNCH_DROP := 1.6
## How far from the point a cell ahead of the body a vessel can be boarded (world units),
## and how far from the body one can be taken up.
const BOARD_REACH := 0.9
const TAKE_REACH := 2.0
## Where the one carried sits behind the rower, in cells along the vessel.
const BACK_SEAT := 0.6
## How far ahead of a vessel the shore is looked for (cells), and how far round it when
## the vessel no longer floats.
const ASHORE_AHEAD := [1.0, 1.5]
const ASHORE_ROUND := 3
## Seconds of the hands a launch, a boarding or a step ashore takes.
const BOAT_SWING := 0.5
## Seconds between two looks at whether the vessels still float (step_boats), and
## between two moves of the things the rivers carry (step_drift).
const BOATS_EVERY := 0.5
const DRIFT_EVERY := 0.5
## The things lying in a river this many chunks round a player drift.
const DRIFT_CHUNKS := 1

## The vessels on the water (Vessels), the session's.
var vessels = VesselsScript.new()
## A body the rules ask where a hull floats and where one stands (its world is the
## world's), made when first asked for.
var _probe_body = null
var _boats_wait := 0.0
var _drift_wait := 0.0
## The currents of the rivers (Currents), null where none run (a client's copy).
var currents = null


## The share of the walking pace vessel item `id` goes at, 0 for a thing that is no vessel.
static func vessel_of(id: String) -> float:
	return float(Items.get_item(id).get("vessel", 0.0)) if id != "" and Items.has(id) else 0.0


## The id of the vessel `who` sits in, 0 on foot (or for one who cannot ride).
static func vessel_id(who) -> int:
	var v: Variant = who.get("vessel")
	return v if v is int else 0


func _probe():
	if _probe_body == null:
		_probe_body = Body.new()
	_probe_body.world = world
	return _probe_body


## The way `who` faces, of length 1 (ZERO for none).
static func _way(who) -> Vector2:
	var dir := Vector2(who.facing_step())
	return dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO


## What the action button does about a vessel: "launch" (a vessel in the hand, open water
## in front), "board" (a vessel with a seat free in front), "ashore" (afloat, ground in
## front), "" for nothing.
func boat_kind(who) -> String:
	if vessel_id(who) != 0:
		return "ashore" if ashore_spot(who).is_finite() else ""
	if vessel_of(who.held()) > 0.0 and launch_spot(who).is_finite():
		return "launch"
	if not boarded(who).is_empty():
		return "board"
	return ""


## Where a vessel launched by `who` floats (the rower's feet, world units): the middle
## of the first column of open water ahead (LAUNCH_REACH) that holds the whole hull,
## with its surface within LAUNCH_DROP of the feet; INF for none.
func launch_spot(who) -> Vector3:
	var dir := _way(who)
	if dir == Vector2.ZERO:
		return Vector3.INF
	var p: Vector3 = who.position / CELL
	var seen := {}
	for i in range(1, int(LAUNCH_REACH * 2.0) + 1):
		var c := Vector2(p.x, p.z) + dir * (i * 0.5)
		var x := floori(c.x)
		var z := floori(c.y)
		if seen.has(Vector2i(x, z)):
			continue
		seen[Vector2i(x, z)] = true
		var bits: int = world.water_col(x, z)
		if bits == 0:
			continue
		var top := WorldData.top_level(bits)
		if world.get_cell(x, top + 1, z) != Mat.AIR:
			continue
		var surface := top + WorldData.WATER_TOP
		if absf(surface - p.y) > LAUNCH_DROP:
			continue
		var at := Vector3(x + 0.5, surface - Body.DECK, z + 0.5) * CELL
		if _probe().floats(at) and not _probe().blocked(at + Vector3(0.0, 0.05 * CELL, 0.0)) \
				and vessels.near(at, CELL).is_empty():
			return at
	return Vector3.INF


## The vessel in front of `who` (a cell ahead, within BOARD_REACH) with a seat free that
## still floats, {} for none.
func boarded(who) -> Dictionary:
	var dir := _way(who)
	if dir == Vector2.ZERO:
		return {}
	var ahead: Vector3 = who.position + Vector3(dir.x, 0.0, dir.y) * CELL
	var v: Dictionary = vessels.near(ahead, BOARD_REACH)
	if v.is_empty() or riders(v.id).size() >= VesselsScript.SEATS or not _probe().floats(v.at):
		return {}
	return v


## The ones sitting in vessel `id`, the rower first.
func riders(id: int) -> Array:
	var out := []
	for p in people:
		if vessel_id(p) == id and not p.is_dead():
			if p.seat == 0:
				out.push_front(p)
			else:
				out.append(p)
	return out


## Where `who` afloat steps ashore (feet, world units): ground in front (ASHORE_AHEAD)
## a body stands on, up to two levels over the water; INF for none.
func ashore_spot(who) -> Vector3:
	var dir := _way(who)
	if dir == Vector2.ZERO:
		return Vector3.INF
	var p: Vector3 = who.position / CELL
	for ahead: float in ASHORE_AHEAD:
		var c := Vector2(p.x, p.z) + dir * ahead
		var at := _stand_at(floori(c.x), floori(c.y), p.y)
		if at.is_finite():
			return at
	return Vector3.INF


## Where a body stands in column x, z (feet, world units) on ground from a level under
## `y` (cells) to two over it, not in water; INF for none.
func _stand_at(x: int, z: int, y: float) -> Vector3:
	var probe = _probe()
	var mid := Vector3(x + 0.5, y, z + 0.5)
	var top: float = probe._ground_top(mid, y - 0.5, y + 2.5)
	if top == -INF:
		return Vector3.INF
	var at := Vector3(mid.x, top, mid.z) * CELL
	if world.get_cell(x, floori(top + 0.001), z) == Mat.WATER or probe.blocked(at) or not probe.standing(at):
		return Vector3.INF
	return at


## The action button about a vessel (see boat_kind): launches the one in the hand and
## sits `who` in it, boards the one in front, or puts them ashore. {} for nothing.
func boat(who) -> Dictionary:
	match boat_kind(who):
		"launch":
			var item: String = who.held()
			var at := launch_spot(who)
			if who.inventory.remove(item, 1) < 1:
				return {}
			var dir := _way(who)
			var v: Dictionary = vessels.launch(item, at, atan2(dir.x, dir.y))
			_sit(who, v, 0)
			var it := Items.get_item(item)
			var oars: String = it.get("oars", "")
			if oars != "" and who.inventory.count(oars) == 0:
				who.say("%s на воде, но без вёсел она едва движется" % it.title)
			return _work(BOAT_SWING, "", at)
		"board":
			var v := boarded(who)
			_sit(who, v, 0 if riders(v.id).is_empty() else 1)
			return _work(BOAT_SWING, "", v.at)
		"ashore":
			var at := ashore_spot(who)
			leave_boat(who, at)
			return _work(BOAT_SWING, "", at)
	return {}


## Sits `who` in vessel `v` on seat `seat`, their body where that seat is.
func _sit(who, v: Dictionary, seat: int) -> void:
	who.riding = v.item
	who.vessel = v.id
	who.seat = seat
	who.move_to(seat_at(v, seat))


## Where the feet of the one on seat `seat` of vessel `v` are (world units).
static func seat_at(v: Dictionary, seat: int) -> Vector3:
	if seat == 0:
		return v.at
	return v.at - Vector3(sin(v.turn), 0.0, cos(v.turn)) * BACK_SEAT * CELL


## Puts `who` off their vessel at `at` (world units); the vessel stays moored where it
## floats, a rower leaving hands it to the one carried.
func leave_boat(who, at: Vector3) -> void:
	var id := vessel_id(who)
	var v: Dictionary = vessels.of(id)
	var rowed: bool = who.seat == 0
	if rowed and not v.is_empty():
		vessels.move(v, who.position, v.turn)
	who.riding = ""
	who.vessel = 0
	who.seat = 0
	who.move_to(at)
	if rowed and not v.is_empty():
		for p in riders(id):
			p.seat = 0
			p.say("Теперь гребёте вы")
			break


## Takes vessel `id` no one sits in, within TAKE_REACH of `who` on foot, back up into the
## bag (on the ground there when the bag is full); false when it cannot be.
func take_vessel(who, id: int) -> bool:
	var v: Dictionary = vessels.of(id)
	if v.is_empty() or vessel_id(who) != 0 or who.is_dead() or not riders(id).is_empty():
		return false
	var p: Vector3 = who.position
	if Vector2(v.at.x - p.x, v.at.z - p.z).length() > TAKE_REACH or absf(v.at.y - p.y) > 2.0:
		return false
	vessels.remove(id)
	if who.give(v.item, 1) < 1:
		world.heap_drop(v.item, p, 1, 0.0)
		drops_changed.emit(WorldData.chunk_key(floori(p.x / CELL), floori(p.z / CELL)))
	return true


## The vessels over `seconds` of play: each rowed goes where its rower is, turned the way
## they go; every BOATS_EVERY one that no longer floats (the water froze) puts its riders
## on the nearest shore (ASHORE_ROUND columns round), and the seats are put right (a
## rower gone hands the vessel to the one carried; a vessel gone, or too many aboard,
## leaves them in the water).
func step_boats(seconds: float, players: Array) -> void:
	for who in players:
		_feel_flow(who)
	step_drift(seconds, players)
	for v: Dictionary in vessels.list.values():
		var aboard := riders(v.id)
		if not aboard.is_empty() and aboard[0].seat == 0:
			var p: Vector3 = aboard[0].position
			var went := Vector2(p.x - v.at.x, p.z - v.at.z)
			vessels.move(v, p, atan2(went.x, went.y) if went.length() > 0.02 else v.turn)
	_boats_wait -= seconds
	if _boats_wait > 0.0:
		return
	_boats_wait = BOATS_EVERY
	var seats := {}
	for who in players:
		var id := vessel_id(who)
		if id == 0 or who.is_dead():
			continue
		var v: Dictionary = vessels.of(id)
		var taken: Array = seats.get(id, [])
		seats[id] = taken
		if v.is_empty() or taken.size() >= VesselsScript.SEATS:
			who.riding = ""
			who.vessel = 0
			who.seat = 0
			continue
		who.seat = 1 if 0 in taken else (0 if who.seat == 0 or taken.has(1) else who.seat)
		taken.append(who.seat)
		if not _probe().floats(v.at):
			leave_boat(who, _shore_near(who.position))
	for id: int in seats:
		if not 0 in seats[id]:
			for p in riders(id):
				p.seat = 0
				break


## The nearest place round `at` (world units, ASHORE_ROUND columns) a body stands on, `at`
## itself for none.
func _shore_near(at: Vector3) -> Vector3:
	var p := at / CELL
	var best := Vector3.INF
	for dz in range(-ASHORE_ROUND, ASHORE_ROUND + 1):
		for dx in range(-ASHORE_ROUND, ASHORE_ROUND + 1):
			var spot := _stand_at(floori(p.x) + dx, floori(p.z) + dz, p.y)
			if spot.is_finite() and (not best.is_finite() or spot.distance_to(at) < best.distance_to(at)):
				best = spot
	return best if best.is_finite() else at


## Sets the current `who` feels (Character.flow and their body's): the river's where
## their body is in the water or afloat, none elsewhere.
func _feel_flow(who) -> void:
	var f := Vector2.ZERO
	var body = who.get("body")
	if currents != null and body != null and not who.is_dead() and not world.water_frozen \
			and (vessel_id(who) != 0 or body.afloat or body.water_depth > 0.0):
		f = currents.at_point(who.position, CELL)
	who.flow = f
	if body != null:
		body.flow = f


## The things lying in a river's water within DRIFT_CHUNKS of a player, every
## DRIFT_EVERY: each heap is carried along by the current at its column, as far as the
## water goes, and lies on the bottom where it comes to (frozen water holds them).
func step_drift(seconds: float, players: Array) -> void:
	_drift_wait -= seconds
	if _drift_wait > 0.0:
		return
	_drift_wait = DRIFT_EVERY
	if currents == null or world.water_frozen:
		return
	var keys := {}
	for who in players:
		var c := WorldData.chunk_key(floori(who.position.x / CELL), floori(who.position.z / CELL))
		for dz in range(-DRIFT_CHUNKS, DRIFT_CHUNKS + 1):
			for dx in range(-DRIFT_CHUNKS, DRIFT_CHUNKS + 1):
				keys[c + Vector2i(dx, dz)] = true
	var moves := []
	for key: Vector2i in keys:
		var list: Array = world.drops.get(key, [])
		for i in range(list.size() - 1, -1, -1):
			var d: Array = list[i]
			if not d[3] is int or d.size() > 4:
				continue
			var p: Vector3 = d[1]
			var x := floori(p.x / CELL)
			var z := floori(p.z / CELL)
			if world.water_col(x, z) == 0:
				continue
			var v: Vector2 = currents.at(x, z)
			if v == Vector2.ZERO:
				continue
			var to := p + Vector3(v.x, 0.0, v.y) * DRIFT_EVERY * CELL
			var nx := floori(to.x / CELL)
			var nz := floori(to.z / CELL)
			if world.water_col(nx, nz) == 0:
				continue
			var lie := floor_under(Vector3i(nx, floori(p.y / CELL + 0.01) + 1, nz))
			if absf(lie.y - p.y) > CELL * 1.01:
				continue
			moves.append([key, i, Vector3(to.x, lie.y, to.z)])
	var changed := {}
	for m: Array in moves:
		var key: Vector2i = m[0]
		var d: Array = world.take_drop(key, m[1])
		world.add_drop(d[0], m[2], d[2], d[3])
		changed[key] = true
		changed[WorldData.chunk_key(floori(m[2].x / CELL), floori(m[2].z / CELL))] = true
	for key: Vector2i in changed:
		drops_changed.emit(key)

