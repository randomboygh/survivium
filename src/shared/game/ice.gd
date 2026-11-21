extends RefCounted
## Holes in the ice (the user's ask of 2026-11-15, winter fishing): a tool of class `ice`
## (an ice pick, an auger) cuts one in frozen water at least DEEP cells deep, in HOLE_WORK
## blows of a tool of power 1 (one of power p takes HOLE_WORK / p, at least one). An open
## hole is open water (WorldData.ice_holes, frozen_at): a line is cast into it and the fish
## under the ice come to it, and a body over it falls into the water. It skins over
## SKIN_DAYS after it was cut, and one blow breaks the crust again. The water thawed, the
## holes are gone. A step of the session (Session.step_things); what changed it tells by
## `changed` (PlayerLink sends the holes, Protocol.ICE_HOLES). The holes are saved with the
## world ("ice_holes" of world.json: to_saved, from_saved).

const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")

## Blows of a tool of power 1 a hole takes; a crust takes one.
const HOLE_WORK := 4
## Days a hole stays open before a crust grows over it.
const SKIN_DAYS := 1.0
## The least water under the ice where a hole is cut, in cells (the ice cell and one more:
## the fish swim under the ice there, Wildlife.under_ice).
const DEEP := 2
## Holes kept at most; the oldest crusts go first.
const MOST := 256
## Seconds between two looks for holes to skin over.
const CHECK_EVERY := 2.0

## The holes or their crusts changed (cut, skinned over, gone with the ice).
signal changed

var world
var clock
## Blows so far into the ice of each column being cut (Vector2i -> blows of power 1).
var _blows := {}
# The first look waits for the clock to tell whether the water is frozen (a world loaded).
var _wait := CHECK_EVERY


## Why the ice of column `col` cannot be cut ("" when it can): a key for the player.
func why_not(col: Vector2i) -> String:
	if not world.frozen_at(col.x, col.y) and not world.ice_holes.has(col):
		return "[the_water_is_not_frozen]"
	var bits: int = world.water_col(col.x, col.y)
	if bits == 0:
		return "[no_ice_here]"
	var top := WorldData.top_level(bits)
	if world.surface_y(col.x, col.y) != top + 1 and not is_open(col):
		# Something stands on the ice (a block put there).
		return "[no_ice_here]"
	if top + 1 < DEEP or world.get_cell(col.x, top - (DEEP - 1), col.y) != Mat.WATER:
		return "[the_ice_lies_on_the_bottom]"
	return ""


## Whether column `col` has an open hole.
func is_open(col: Vector2i) -> bool:
	return world.ice_holes.get(col, -1.0) >= 0.0


## Whether column `col` has a crust over a hole.
func is_crust(col: Vector2i) -> bool:
	return world.ice_holes.get(col, 0.0) < 0.0


## A blow of a tool of `power` at the ice of column `col` (see why_not first): true when
## the hole is open after it (a crust breaks at one blow).
func cut(col: Vector2i, power: int) -> bool:
	if is_open(col):
		return true
	var need := 1 if is_crust(col) else HOLE_WORK
	var done: int = _blows.get(col, 0) + maxi(power, 1)
	if done < need:
		_blows[col] = done
		return false
	_blows.erase(col)
	if world.ice_holes.size() >= MOST and not world.ice_holes.has(col):
		_forget_oldest()
	world.ice_holes[col] = clock.now() if clock != null else 0.0
	changed.emit()
	return true


func _forget_oldest() -> void:
	var oldest = null
	var when := INF
	for col: Vector2i in world.ice_holes:
		var t: float = world.ice_holes[col]
		# A crust (-1) goes before any open hole.
		if t < when:
			when = t
			oldest = col
	if oldest != null:
		world.ice_holes.erase(oldest)


## The holes for `delta` seconds: open ones SKIN_DAYS old skin over; thawed water, or a
## world not frozen, takes them all.
func step(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_EVERY
	if world.ice_holes.is_empty():
		_blows.clear()
		return
	if not world.icy():
		world.ice_holes.clear()
		_blows.clear()
		changed.emit()
		return
	var now: float = clock.now() if clock != null else 0.0
	var skinned := false
	for col: Vector2i in world.ice_holes:
		var t: float = world.ice_holes[col]
		if t >= 0.0 and now - t >= SKIN_DAYS:
			world.ice_holes[col] = -1.0
			skinned = true
	if skinned:
		changed.emit()


## The holes as a list for the network: [[x, z, open], …].
func to_list() -> Array:
	var out := []
	for col: Vector2i in world.ice_holes:
		out.append([col.x, col.y, world.ice_holes[col] >= 0.0])
	return out


## The holes for world.json: [[x, z, day cut or -1 for a crust], …].
func to_saved() -> Array:
	var out := []
	for col: Vector2i in world.ice_holes:
		out.append([col.x, col.y, world.ice_holes[col]])
	return out


## The holes saved (to_saved) back into the world, checked.
func from_saved(list: Array) -> void:
	world.ice_holes.clear()
	for e in list:
		if e is Array and e.size() == 3 and (e[0] is int or e[0] is float) and (e[1] is int or e[1] is float) \
				and (e[2] is int or e[2] is float) and world.ice_holes.size() < MOST:
			world.ice_holes[Vector2i(int(e[0]), int(e[1]))] = maxf(float(e[2]), -1.0)
	changed.emit()


## The holes the server sent (Protocol.ICE_HOLES) into world `w`, checked.
static func take_list(w, list: Array) -> void:
	w.ice_holes.clear()
	for e in list:
		if e is Array and e.size() == 3 and e[0] is int and e[1] is int and w.ice_holes.size() < MOST:
			w.ice_holes[Vector2i(e[0], e[1])] = 0.0 if bool(e[2]) else -1.0
