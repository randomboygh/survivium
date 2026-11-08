extends "res://src/shared/game/actions_tame.gd"
## Rafts and boats (plan/backlog.md, answer 4А; decision 178). An item with `vessel` held
## in the hand is launched by the action button facing open water near the feet: it
## leaves the bag and the one who held it sits in it (Character.riding), afloat on the
## water (Body.vessel, at the item's share of the walking pace; a boat whose `oars` are
## not in the bag goes at Character.OARLESS of it). The action button facing the shore
## puts them on it, the vessel back in the bag (on the ground beside them when the bag
## is full). Water freezing under a vessel, or one ridden somewhere it does not float,
## puts its rider on the nearest shore the same way (step_boats); a death leaves the
## vessel in the sack with the rest.

const Body := preload("res://src/shared/game/body.gd")

## How far ahead of the body water is looked for to launch on (cells, half a cell at a
## time), and how far the water's surface may be under or over the feet.
const LAUNCH_REACH := 2.0
const LAUNCH_DROP := 1.6
## How far ahead of a vessel the shore is looked for (cells), and how far round it when
## the vessel no longer floats.
const ASHORE_AHEAD := [1.0, 1.5]
const ASHORE_ROUND := 3
## Seconds of the hands a launch or a step ashore takes.
const BOAT_SWING := 0.5
## Seconds between two looks at the riders (step_boats).
const BOATS_EVERY := 0.5

## A body the rules ask where a hull floats and where one stands (its world is the
## world's), made when first asked for.
var _probe_body = null
var _boats_wait := 0.0


## The share of the walking pace vessel item `id` goes at, 0 for a thing that is no vessel.
static func vessel_of(id: String) -> float:
	return float(Items.get_item(id).get("vessel", 0.0)) if id != "" and Items.has(id) else 0.0


## The vessel `who` sits in ("" on foot, or for one who cannot ride).
static func riding_of(who) -> String:
	var r: Variant = who.get("riding")
	return r if r is String else ""


func _probe():
	if _probe_body == null:
		_probe_body = Body.new()
	_probe_body.world = world
	return _probe_body


## What the action button does about a vessel: "launch" (a vessel in the hand, open water
## in front), "ashore" (afloat, ground in front), "" for nothing.
func boat_kind(who) -> String:
	if riding_of(who) != "":
		return "ashore" if ashore_spot(who).is_finite() else ""
	if vessel_of(who.held()) > 0.0 and launch_spot(who).is_finite():
		return "launch"
	return ""


## Where a vessel launched by `who` floats (the rider's feet, world units): the middle
## of the first column of open water ahead (LAUNCH_REACH) that holds the whole hull,
## with its surface within LAUNCH_DROP of the feet; INF for none.
func launch_spot(who) -> Vector3:
	var dir := Vector2(who.facing_step())
	if dir == Vector2.ZERO:
		return Vector3.INF
	dir = dir.normalized()
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
		if _probe().floats(at) and not _probe().blocked(at + Vector3(0.0, 0.05 * CELL, 0.0)):
			return at
	return Vector3.INF


## Where `who` afloat steps ashore (feet, world units): ground in front (ASHORE_AHEAD)
## a body stands on, up to two levels over the water; INF for none.
func ashore_spot(who) -> Vector3:
	var dir := Vector2(who.facing_step())
	if dir == Vector2.ZERO:
		return Vector3.INF
	dir = dir.normalized()
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
## sits `who` in it, or puts them ashore with it back in the bag. {} for nothing.
func boat(who) -> Dictionary:
	var kind := boat_kind(who)
	if kind == "launch":
		var item: String = who.held()
		var at := launch_spot(who)
		if who.inventory.remove(item, 1) < 1:
			return {}
		who.riding = item
		who.move_to(at)
		var it := Items.get_item(item)
		var oars: String = it.get("oars", "")
		if oars != "" and who.inventory.count(oars) == 0:
			who.say("%s на воде, но без вёсел она едва движется" % it.title)
		else:
			who.say("%s на воде" % it.title)
		return _work(BOAT_SWING, "", at)
	if kind == "ashore":
		var at := ashore_spot(who)
		leave_boat(who, at)
		return _work(BOAT_SWING, "", at)
	return {}


## Puts `who` off their vessel at `at` (world units), the vessel back in the bag or, the
## bag full, on the ground there.
func leave_boat(who, at: Vector3) -> void:
	var item := riding_of(who)
	who.riding = ""
	who.move_to(at)
	if item == "" or not Items.has(item):
		return
	if who.give(item, 1) < 1:
		world.heap_drop(item, at, 1, 0.0)
		drops_changed.emit(WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)))
	who.say("%s снова в сумке" % Items.get_item(item).title)


## The riders of `players` over `seconds` of play, looked at every BOATS_EVERY: one whose
## vessel no longer floats (the water froze) is put on the nearest shore (ASHORE_ROUND
## columns round), or where they are when there is none.
func step_boats(seconds: float, players: Array) -> void:
	_boats_wait -= seconds
	if _boats_wait > 0.0:
		return
	_boats_wait = BOATS_EVERY
	for who in players:
		if riding_of(who) == "" or who.is_dead():
			continue
		var at: Vector3 = who.position
		if _probe().floats(at):
			continue
		leave_boat(who, _shore_near(at))


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
