extends "res://src/client/input/build_blueprint.gd"
## Where the build mode aims a thing (see build_mode.gd): the cell under the finger and
## the face pressed, a thing set down beside one of its kind, where a thing is grabbed,
## the double tap that turns a thing and the single tap that takes it.

## What a thing new from the bag is aimed at for a finger or the mouse at screen point
## `pos` (VoxelRaycast.cast's hit): the place right under it (user 2026-11-26: no lift over
## the finger). With `planned` the blueprint's ghost blocks are met as blocks
## (Controls.pick_planned: a ghost thing goes onto, against or into them).
func _aimed(pos: Vector2, planned := false) -> Dictionary:
	return game.controls.pick_planned(pos) if planned else game.controls.pick(pos)

## Whether thing `id` new from the bag goes into the blueprint as a ghost thing, built after
## its blocks (Plans.put_thing): the setting «Вещи из сумки» (Settings `build_things`, by the
## blueprint unless set to at once; the user's picks, 2026-11-26, 1А, 2А), for a thing with a
## model of its own (Props.ghostly; a campfire too, user 2026-11-27; a light is set down at once).
func _by_blueprint(id: String) -> bool:
	return int(game.settings.values.get("build_things", 0)) == 0 and Props.ghostly(id)

## The side (Placed.SIDES index) the face of hit `hit` (VoxelRaycast.cast) looks toward: a
## wall's face, which a door or a window set into it lies along (Placed.plane_turn); -1 for
## a top or a bottom.
static func face_of(hit: Dictionary) -> int:
	var n: Vector3i = hit.get("normal", Vector3i.UP)
	return Placed.SIDES.find(n) if n.y == 0 else -1

## The cell of thing `e` under screen point `pos`, from its north-west cell (the thing
## dragged keeps it under the finger).
func _grab(e: Dictionary, pos: Vector2) -> Vector3i:
	var n := Placed.size_of(e.item)
	var on_it: Variant = game.controls.on_plane(pos, e.cell, Vector3i.UP)
	if on_it == null:
		return Vector3i.ZERO
	var d: Vector3i = on_it - e.cell
	return Vector3i(clampi(d.x, 0, n - 1), 0, clampi(d.z, 0, n - 1))

## The cell a thing new from the bag is set down at on the cell `hit` (VoxelRaycast.cast)
## of item record `item`: a door or a window into the side of a wall tapped; on the top of
## a floor it stands on it, never cut into it; a hatch into the floor or the ceiling of
## blocks tapped; else the cell over the face tapped.
func _aim(hit: Dictionary, item: Dictionary) -> Vector3i:
	var cell: Vector3i = hit.cell
	var built: bool = not game.world.is_natural(cell.x, cell.y, cell.z)
	var into_wall: bool = (item.get("door", false) or item.get("window", false)) and not item.get("hatch", false) \
		and hit.normal.y == 0 and built
	var into_floor: bool = item.get("hatch", false) and hit.normal.y != 0 and built
	return cell if into_wall or into_floor else cell + hit.normal

## Ghost thing `t` of the blueprint turned where it stands (a double tap on it): a quarter,
## a door, a window or a hatch the other way round (Plans.move_thing).
func turn_ghost(t: Dictionary) -> void:
	var turned := (int(t.turn) + (2 if Placed.is_opening(t.item) else 1)) % 4
	if not Placed.is_opening(t.item):
		kept_turns[t.item] = turned
	game.net.request(Protocol.PLAN_THING_MOVE, [t.cell, t.cell, turned, -1])

## Thing `e` turned a quarter where it stands (a double tap on it), and the next of its
## kind set down turned so while the bag holds one (kept_turns); a door, a window or a
## hatch turned the other way round in its wall, its front to the other side.
func turn_thing(e: Dictionary) -> void:
	if Placed.is_opening(e.item):
		game.net.request(Protocol.PROP_MOVE, [e.cell, e.cell, (int(e.get("turn", 0)) + 2) % 4])
		return
	var turned := (int(e.get("turn", 0)) + 1) % 4
	kept_turns[e.item] = turned
	game.net.request(Protocol.PROP_MOVE, [e.cell, e.cell, turned])

## The tap on a thing waiting for a second one takes the thing now (see DOUBLE_TAP_MS); on
## a ghost thing, takes it off the blueprint.
func _take_waiting() -> void:
	if _tap_wait.is_empty():
		return
	var cell: Vector3i = _tap_wait.cell
	var ghost: bool = _tap_wait.get("ghost", false)
	_tap_wait = {}
	if ghost:
		if not game.plans.thing_at(cell).is_empty():
			game.net.request(Protocol.PLAN_THING_TAKE, [cell])
	elif not game.placed.at(cell).is_empty():
		_take(cell)

## The thing at `cell` back into the bag (Protocol.PROP_TAKE); taken, its slot is chosen
## on the palette (WorkMode._on_bag_changed).
func _take(cell: Vector3i) -> void:
	game.net.request(Protocol.PROP_TAKE, [cell])

## Whether a tap on thing `e` sets the next of its kind down beside it: it is one cell big
## and the hand holds one of its kind.
func _beside_kind(e: Dictionary) -> bool:
	return e.item == chosen() and Placed.size_of(e.item) == 1 and game.character.inventory.count(e.item) > 0

## The cell beside thing `e` (one cell big) the finger at `pos` points to: the cell under the
## finger when it is not the thing's own, else the cell past the face of the thing the
## finger's ray goes in by.
func _beside(e: Dictionary, pos: Vector2) -> Vector3i:
	var hit: Dictionary = game.controls.pick(pos)
	if not hit.is_empty():
		var aim := _aim(hit, Items.get_item(chosen()))
		if aim != e.cell and game.placed.at(aim).is_empty():
			return aim
	var ray: Array = game.controls._ray(pos)
	return e.cell + face_in(Vector3(e.cell), ray[0], ray[1])

## The face of the unit cube at `corner` a ray from `from` along `dir` goes in by, as the
## step out of it (up when it misses).
static func face_in(corner: Vector3, from: Vector3, dir: Vector3) -> Vector3i:
	var enter := -INF
	var face := Vector3i.UP
	for axis in 3:
		if absf(dir[axis]) < 0.000001:
			continue
		var t0 := (corner[axis] - from[axis]) / dir[axis]
		var t1 := (corner[axis] + 1.0 - from[axis]) / dir[axis]
		var near := minf(t0, t1)
		if near > enter:
			enter = near
			var step := Vector3i.ZERO
			step[axis] = -1 if dir[axis] > 0.0 else 1
			face = step
	return face

## Whether stroke `s` takes its thing up into the air now: held HOLD_MS, or gone DRAG_SHARE
## of the screen.
func _lift_due(s: Dictionary) -> bool:
	return Time.get_ticks_msec() - int(s.ms) >= HOLD_MS or s.pos.distance_to(s.from) >= _slop()
