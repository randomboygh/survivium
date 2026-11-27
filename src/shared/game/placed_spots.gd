extends "res://src/shared/game/placed_store.gd"
## Placed things, part 3 (see placed.gd): where a thing can stand: in front of the one setting it
## down (put_spot), in a wall for a door or a window, on a blueprint for a ghost thing, a light's
## cell; what fits a cell (_fits) and what holds it up (_rests).

## No level is cut from (`_open`): the thing goes on air only.
const NO_CUT := 1 << 30
## How far (cells) from the cell aimed at a door or a window looks for the wall it sticks to
## (_wall_near).
const WALL_SNAP := 2
## How much farther a floor's cell counts than a wall's when a door or a window looks for the
## wall it sticks to (_wall_near): over a floor by a wall it goes into the wall, not the floor.
const FLOOR_FAR := 2.0 * WALL_SNAP * WALL_SNAP + 1.0
## What a cell is to an opening set into a wall (_wall_cells): a block it cuts out, a cell of a
## gap left in the wall (or of the opening moved), or one in the open.
enum { WALL_OUT, WALL_GAP, WALL_CUT }
## While a wicket or a gate is being set down (put_at): the fences in its way may go.
var _swap_fences := false
## The opening being moved while its new place is looked for (opening_spot): standing
## open, it is no doorway in its own way (_in_open_door).
var _moving := {}
## The blueprint (Plans) a ghost thing's place is looked for in (ghost_spot,
## ghost_move_spot): the world as it will stand built, its ghost blocks solid (to stand on,
## to have a back or a doorway against) and taken (but an opening takes their place), its
## ghost things' cells taken (but `_ghost_self`'s, the one moved); null for a real thing.
var _ghosts = null
var _ghost_self := {}


## Whether a cross can stand in cell `c` (see put_grave).
func _grave_fits(c: Vector3i, people: Array) -> bool:
	if world.get_cell(c.x, c.y, c.z) != Mat.AIR or not world.is_solid(c.x, c.y - 1, c.z) \
			or world.blockers.has(c) or world.ladders.has(c) or not light_at(c).is_empty() or _in_open_door(c):
		return false
	for who in people:
		if who.has_method("overlaps_cell") and who.overlaps_cell(c):
			return false
	return true


## The cells thing `item` turned `turn` fills from its north-west cell ({"offsets"}) and
## how many levels high it stands ({"high"}).
func _shape_of(item: String, turn: int) -> Dictionary:
	var probe := {"item": item, "cell": Vector3i.ZERO, "turn": turn}
	var high := 1
	for box in boxes_of(probe):
		for b: AABB in (box if box is Array else [box]):
			high = maxi(high, ceili(b.end.y - 0.01))
	return {"offsets": cells_of(probe), "high": high}


## Where `who` setting thing `id` down at cell `aim` puts it (put_at): [its north-west
## corner, null where it has no room; its quarter turn]. `view` is the view's turn, taken
## by a thing that faces the camera (faces_view), or by any thing when `kept` (the turn the
## player gave the last one of its kind, kept in the build mode). The best turn is taken by
## itself where there is one (the user's pick, 2026-11-26, 4А): a door, a window, a wicket or
## a gate in the plane of the wall or the fence it goes into or stands in (plane_turn; `face`,
## the side of the face tapped, SIDES index, -1 none, settles a corner), and a thing that
## faces the view or a ladder with its back to a wall when one is at hand (_backed); in the
## open as before, but a door or a window only in a wall (or a gap in one). The build mode shows it while a thing new from the bag is held up in the air.
func put_spot(who, id: String, aim: Vector3i, top: int, view := -1, kept := false, face := -1) -> Array:
	var item := Items.get_item(id)
	var p: Vector3 = who.position / CELL
	var turn := view if view >= 0 and (kept or faces_view(item.id)) else turn_facing(Tools.step_of(Vector2(aim.x + 0.5 - p.x, aim.z + 0.5 - p.z)))
	var rest := rest_of(item.id)
	var stacked := false
	if rest == ON_LADDER:
		# A ladder goes on with the one under it, turned as it is.
		for dy in [1, 2]:
			if world.ladders.has(aim - Vector3i(0, dy, 0)) and not world.ladders.has(aim - Vector3i(0, dy - 1, 0)):
				turn = world.ladders[aim - Vector3i(0, dy, 0)]
				stacked = true
	var cuts: bool = item.get("door", false) or item.get("window", false)
	var hatch: bool = item.get("hatch", false)
	var into_wall: bool = cuts and not hatch and not item.get("fence", false)
	if into_wall:
		# It sticks to the wall nearest the cell aimed at (over its top, before it, by it),
		# a door down to the floor (user 2026-11-26).
		aim = _wall_near(aim, floori(p.y + 0.25), item.get("door", false))
	if cuts and not hatch:
		turn = plane_turn(aim, turn, face, p)
	elif not stacked and (rest == ON_LADDER or faces_view(item.id)):
		var backed := _backed(who, item.id, aim, top, turn, rest)
		if not backed.is_empty():
			return backed
	var shape := _shape_of(item.id, turn)
	# An opening is cut from the level of their feet up: never into the floor they stand on;
	# a hatch's into the floor or the ceiling tapped.
	var cut_from: int = floori(p.y + 0.25) if cuts else NO_CUT
	if rest == IN_FLOOR:
		cut_from = aim.y
	_swap_fences = item.get("door", false) and item.get("fence", false)
	if into_wall and not _walled(aim) and not _in_gap(aim) and not _moving_cells().has(aim):
		# A door or a window goes only into a wall (or a gap left in one, or the opening it is
		# moved from), never in the open (user 2026-11-26).
		return [null, turn]
	var spot: Variant
	if into_wall:
		spot = _wall_spot(who, aim, top, size_of(item.id), shape.offsets, rest, shape.high, cut_from, item.get("door", false), turn)
	else:
		spot = _spot_at(who, Vector2(aim.x + 0.5, aim.z + 0.5), aim.y, top, size_of(item.id), shape.offsets, rest, shape.high, cut_from)
	_swap_fences = false
	return [spot, turn]


## Whether cell `c` is of a wall an opening is cut into: a block put there (not natural
## ground, not water), or a ghost block of the blueprint while a ghost thing's place is looked
## for (_ghosts).
func _walled(c: Vector3i) -> bool:
	if _ghosts != null and _ghosts.block_at(c):
		return true
	var m: int = world.get_cell(c.x, c.y, c.z)
	return m != Mat.AIR and m != Mat.WATER and not world.is_natural(c.x, c.y, c.z)


## The wall cell a door or a window aimed at cell `aim` goes into (put_spot): `aim` itself
## when it is a wall's, else the wall cell nearest it (WALL_SNAP cells round it, over its top
## or before its face; a floor's farther, FLOOR_FAR); a door then goes down the wall to the
## level of the feet `feet` or the wall's foot. `aim` where no wall is near (it stands in the
## open).
func _wall_near(aim: Vector3i, feet: int, door: bool) -> Vector3i:
	var at := aim
	# The opening moved stands in a wall: its own cells are of it (opening_spot).
	var own := _moving_cells()
	if not _walled(aim) and not _in_gap(aim) and not own.has(aim):
		var best := -1.0
		for dy in range(-WALL_SNAP, 2):
			for dz in range(-WALL_SNAP, WALL_SNAP + 1):
				for dx in range(-WALL_SNAP, WALL_SNAP + 1):
					var c := aim + Vector3i(dx, dy, dz)
					if c.y < feet or not (_walled(c) or own.has(c)):
						continue
					var d := float(dx * dx + dz * dz) + dy * dy * 0.5 + (FLOOR_FAR if _floor_cell(c) else 0.0)
					if best < 0.0 or d < best:
						best = d
						at = c
	if door:
		while at.y > feet and _walled(at + Vector3i.DOWN) and not _floor_cell(at + Vector3i.DOWN):
			at += Vector3i.DOWN
	return at


## Whether wall cell `c` is of a floor (built or of the blueprint): walled cells beside it
## both along x and along z, where a wall has them only along itself. A door stands on the
## floor (user 2026-11-26: a floor laid first, the walls on it, the door on that floor, not
## down to the ground under it).
func _floor_cell(c: Vector3i) -> bool:
	return _walled(c) and (_walled(c + Vector3i(1, 0, 0)) or _walled(c - Vector3i(1, 0, 0))) \
		and (_walled(c + Vector3i(0, 0, 1)) or _walled(c - Vector3i(0, 0, 1)))


## Whether cell `c` is a gap left in a wall (a doorway): wall cells on both sides of it along
## a row, WALL_SNAP + 1 cells at most from it, each the end of a wall going on along that row,
## not of one across it (inside a small room the walls left and right are no doorway: user
## 2026-11-27, doors stood in the middle of a room).
func _in_gap(c: Vector3i) -> bool:
	for along: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
		var across := Vector3i(along.z, 0, along.x)
		var sides := 0
		for way in [-1, 1]:
			for k in range(1, WALL_SNAP + 2):
				var w: Vector3i = c + along * way * k
				if _walled(w):
					if not (_walled(w + across) and _walled(w - across)):
						sides += 1
					break
		if sides == 2:
			return true
	return false


## The north-west cell of an opening `offsets` (`high` tall) set into the wall at cell `aim`
## (put_spot: a wall's, one of a gap left in a wall, or of the opening moved): of the spots
## round it with every column in the wall (_wall_cells) that fit (_fits, blocks at `cut_from`
## or higher cut out), the one with the most of its cells in the wall, then (`aim` a gap's: it
## fills the doorway) the fewest blocks cut, then for a door the lowest, then the nearest;
## never one across its wall (_across, turned `turn`). Null for none.
func _wall_spot(who, aim: Vector3i, top: int, n: int, offsets: Array[Vector3i], rest: int, high: int, cut_from: int,
		door: bool, turn: int) -> Variant:
	var mid := Vector2.ZERO
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
	mid /= maxi(offsets.size(), 1)
	var to := Vector2(aim.x + 0.5, aim.z + 0.5)
	var best: Variant = null
	var best_by := Vector4.ZERO
	var own := _moving_cells()
	var fill := not _walled(aim) and not own.has(aim)
	var kinds := {}
	for dz in range(-n - 1, 3):
		for dx in range(-n - 1, 3):
			var c := Vector2i(aim.x + dx, aim.z + dz)
			var far := (Vector2(c) + mid).distance_squared_to(to)
			if far > n * n + 1.0:
				continue
			for dy in range(-high, 2):
				var corner := Vector3i(c.x, aim.y + dy, c.y)
				var cells := _wall_cells(corner, offsets, high, own, kinds)
				if cells.x < 0:
					continue
				if not _fits(who, corner, top, offsets, rest, high, cut_from):
					continue
				if door and _sunk(corner, offsets):
					continue
				if _across(corner, offsets, high, turn):
					continue
				# Most cells in the wall, then (filling a doorway) the fewest cut, then (a door)
				# the lowest or (a window) the level aimed at, then the nearest.
				var by := Vector4(-cells.x, cells.y if fill else 0, corner.y if door else absi(dy), far)
				if best == null or by < best_by:
					best = corner
					best_by = by
	return best


## How many cells of an opening `offsets` (`high` tall) at north-west cell `corner` are of the
## wall it goes into, x (blocks it cuts out, cells of a gap left in the wall, _in_gap, or of
## the opening moved, `own`), and how many blocks it cuts out, y; each cell's kind is kept in
## `kinds` (WALL_CUT, WALL_GAP, WALL_OUT). x is -1 where a column of it has none: it would
## stand in the open by the wall or on a floor (user 2026-11-27: doors stood on the ground
## before a house, and on a floor with no walls).
func _wall_cells(corner: Vector3i, offsets: Array[Vector3i], high: int, own: Array[Vector3i], kinds: Dictionary) -> Vector2i:
	var out := Vector2i.ZERO
	for o: Vector3i in offsets:
		var column := 0
		for k in high:
			var c: Vector3i = corner + o + Vector3i(0, k, 0)
			if not kinds.has(c):
				kinds[c] = WALL_CUT if _walled(c) else (WALL_GAP if own.has(c) or _in_gap(c) else WALL_OUT)
			if kinds[c] != WALL_OUT:
				column += 1
			if kinds[c] == WALL_CUT:
				out.y += 1
		if column == 0:
			return Vector2i(-1, 0)
		out.x += column
	return out


## The opening whose new place is looked for: one set down (_moving, opening_spot) or a ghost
## one of the blueprint (_ghost_self, ghost_move_spot); {} while none is.
func _moved_opening() -> Dictionary:
	if not _moving.is_empty():
		return _moving
	if not _ghost_self.is_empty() and is_opening(str(_ghost_self.get("item", ""))):
		return _ghost_self
	return {}


## The cells of the opening moved (_moved_opening), none while none is.
func _moving_cells() -> Array[Vector3i]:
	var e := _moved_opening()
	if e.is_empty():
		return []
	return opening_cells(e)


## Whether an opening at north-west cell `corner` (its cells `offsets`, `high` tall) turned
## `turn` would stand across the wall it is cut into: more wall beside its cells across its
## plane than along it, or one of them a corner's (a door by a corner turned into the other wall's plane; user
## 2026-11-27: it stays in the plane of the wall it goes into). The cells of the opening
## moved (_moving_cells) are of the wall.
func _across(corner: Vector3i, offsets: Array[Vector3i], high: int, turn: int) -> bool:
	var cells := {}
	for o: Vector3i in offsets:
		for k in high:
			cells[corner + o + Vector3i(0, k, 0)] = true
	var own := _moving_cells()
	var plane := Vector3i(1, 0, 0) if posmod(turn, 2) == 0 else Vector3i(0, 0, 1)
	var cross := Vector3i(plane.z, 0, plane.x)
	var along := 0
	var across := 0
	for c: Vector3i in cells:
		var here := Vector2i.ZERO
		for way in [-1, 1]:
			var a: Vector3i = c + plane * way
			if not cells.has(a) and (_walled(a) or own.has(a)):
				here.x += 1
			var b: Vector3i = c + cross * way
			if not cells.has(b) and (_walled(b) or own.has(b)):
				here.y += 1
		# A corner's cell (walls beside it both ways) is no place for one.
		if here.x > 0 and here.y > 0:
			return true
		along += here.x
		across += here.y
	return across > along


## Whether a door at north-west cell `corner` (its cells `offsets`) would go down into a
## floor (_floor_cell): it stands on it.
func _sunk(corner: Vector3i, offsets: Array[Vector3i]) -> bool:
	for o: Vector3i in offsets:
		if o.y == 0 and _floor_cell(corner + o):
			return true
	return false


## The turn of a door, a window, a wicket or a gate set down at cell `aim` (the wall's cell
## tapped, or the cell it stands in) by one at `p` (cells): in the plane of the wall (or
## the fence) there, its front to them. The wall runs the way that has more solid cells or
## fences beside `aim` (a doorway left in a wall, a wall's end the opening goes on from);
## where both ways have as many (a corner, a pillar, the open), across the face tapped
## (`face`, the SIDES index it looks toward; -1 for none), else `turn` (as they face it).
func plane_turn(aim: Vector3i, turn: int, face: int, p: Vector3) -> int:
	var along_x := 0
	var along_z := 0
	# The cells of the opening moved are of its wall (opening_spot).
	var own := _moving_cells()
	for i in SIDES.size():
		var c: Vector3i = aim + SIDES[i]
		if _solid(c) or _fences.has(c) or own.has(c):
			if i % 2 == 1:
				along_x += 1
			else:
				along_z += 1
	var flat_x: bool
	if along_x != along_z:
		flat_x = along_x > along_z
	elif face >= 0 and face < SIDES.size():
		# A face looking north or south is a wall running along x.
		flat_x = face % 2 == 0
	elif not _moved_opening().is_empty():
		# An opening moved over a corner stays in the plane of the wall it was in.
		flat_x = int(_moved_opening().get("turn", 0)) % 2 == 0
	else:
		return turn
	# Turn 0 stands along the north edge of its cell, its front south (front_of).
	if flat_x:
		return 0 if p.z >= aim.z + 0.5 else 2
	return 1 if p.x < aim.x + 0.5 else 3


## [north-west cell, turn] of thing `id` set down at cell `aim` with its back to a wall
## (put_spot): of the four turns (from `turn`, which wins a tie) the one whose spot has the
## most solid cells right behind its back (SIDES[turn], as wall_turn has it), then the
## fewest open ones, so a long thing lies along the wall; [] when no turn puts it against
## one (it stands in the open: turned as before).
func _backed(who, id: String, aim: Vector3i, top: int, turn: int, rest: int) -> Array:
	var best: Array = []
	var best_by := Vector2i.ZERO
	var n := size_of(id)
	for k in 4:
		var t := (turn + k) % 4
		var shape := _shape_of(id, t)
		var spot: Variant = _spot_at(who, Vector2(aim.x + 0.5, aim.z + 0.5), aim.y, top, n, shape.offsets, rest, shape.high)
		if spot == null:
			continue
		var by := _backing(spot, shape.offsets, t)
		if by.x > 0 and (best.is_empty() or by.x > best_by.x or by.x == best_by.x and by.y > best_by.y):
			best = [spot, t]
			best_by = by
	return best


## How thing cells `offsets` from `spot` turned `turn` stand against a wall: (the solid
## cells right behind its back edge, minus the open ones there).
func _backing(spot: Vector3i, offsets: Array, turn: int) -> Vector2i:
	var back: Vector3i = SIDES[posmod(turn, 4)]
	var solid := 0
	var open := 0
	for o: Vector3i in offsets:
		if offsets.has(o + back):
			continue
		var c: Vector3i = spot + o + back
		if _solid(c):
			solid += 1
		else:
			open += 1
	return Vector2i(solid, -open)


## The north-west cell where thing `e` would stand moved to `corner` turned `turn` (see
## move): that cell, or the free one nearest to it at its level, one down or one up, its
## own cells counted free; null when there is none (and for an opening: opening_spot).
func move_spot(who, e: Dictionary, corner: Vector3i, turn: int) -> Variant:
	if not movable(e) or is_opening(e.item):
		return null
	var shape := _shape_of(e.item, posmod(turn, 4))
	var offsets: Array[Vector3i] = shape.offsets
	var mid := Vector2.ZERO
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
	mid /= maxi(offsets.size(), 1)
	_unblock(e)
	var spot: Variant = _spot_at(who, Vector2(corner.x, corner.z) + mid, corner.y, NO_CUT, size_of(e.item),
		offsets, rest_of(e.item), shape.high)
	_block(e)
	return spot


## The cells opening `e` takes out of the blocks it is set into (put_at), shut.
func opening_cells(e: Dictionary) -> Array[Vector3i]:
	return _opening_at(e.item, e.cell, int(e.get("turn", 0)))


## Every cell thing `item` turned `turn` with its north-west cell at `spot` fills, as high
## as it stands (a ghost thing's, Plans.things).
func volume_of(item: String, spot: Vector3i, turn: int) -> Array[Vector3i]:
	return _opening_at(item, spot, turn)


## Where a ghost of thing `id` set down at cell `aim` by `who` goes in blueprint `ghosts`
## (Plans.put_thing): as put_spot finds it (turned best, `view`, `kept`, `face` alike), but in
## the world as the blueprint will stand built (_ghosts) and with no body in the way.
func ghost_spot(who, ghosts, id: String, aim: Vector3i, view := -1, kept := false, face := -1) -> Array:
	_ghosts = ghosts
	var found := put_spot(who, id, aim, world.size_y, view, kept, face)
	_ghosts = null
	return found


## Where ghost thing `t` of blueprint `ghosts` moved to north-west cell `corner` turned `turn`
## goes (Plans.move_thing), its own cells counted free: as move_spot finds a place for a
## thing set down; a door, a window or a hatch by the wall's cell `corner` pressed and the
## side of its face `face`, as opening_spot does. [north-west cell or null, turn].
func ghost_move_spot(who, ghosts, t: Dictionary, corner: Vector3i, turn: int, face := -1) -> Array:
	_ghosts = ghosts
	_ghost_self = t
	var found: Array
	if is_opening(t.item):
		found = put_spot(who, t.item, corner, world.size_y, -1, false, face)
	else:
		turn = posmod(turn, 4)
		var shape := _shape_of(t.item, turn)
		var offsets: Array[Vector3i] = shape.offsets
		var mid := Vector2.ZERO
		for o: Vector3i in offsets:
			mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
		mid /= maxi(offsets.size(), 1)
		found = [_spot_at(who, Vector2(corner.x, corner.z) + mid, corner.y, world.size_y, size_of(t.item), offsets,
			rest_of(t.item), shape.high), turn]
	_ghosts = null
	_ghost_self = {}
	return found


## Whether cell `c` is solid: a block of the world, or of the blueprint while a ghost thing's
## place is looked for (_ghosts).
func _solid(c: Vector3i) -> bool:
	return world.is_solid(c.x, c.y, c.z) or _ghosts != null and _ghosts.block_at(c)


## Whether a ghost thing (not the one moved) fills cell `c` while a ghost thing's place is
## looked for (_ghosts).
func _ghost_taken(c: Vector3i) -> bool:
	if _ghosts == null:
		return false
	var t: Dictionary = _ghosts.thing_at(c)
	return not t.is_empty() and not is_same(t, _ghost_self)


## The cells thing `item` turned `turn` with its north-west cell at `spot` takes out of
## blocks as an opening: those it fills, as high as it stands.
func _opening_at(item: String, spot: Vector3i, turn: int) -> Array[Vector3i]:
	var shape := _shape_of(item, turn)
	var out: Array[Vector3i] = []
	for o: Vector3i in shape.offsets:
		for k in shape.high:
			out.append(spot + o + Vector3i(0, k, 0))
	return out


## Where opening `e` moved by `who` to cell `aim` would go (_move_opening): [its north-west
## cell, null where it has no room; its turn], looked for as for a new one set down there
## (put_spot: into the wall pressed, `face` the side of its face, in the wall's plane, its
## front to them), its own cells counted free. The build mode shows it so while it is held.
func opening_spot(who, e: Dictionary, aim: Vector3i, face := -1) -> Array:
	_unblock(e)
	_moving = e
	var found := put_spot(who, e.item, aim, world.size_y, -1, false, face)
	_moving = {}
	_block(e)
	return found


## The north-west cell from which opening `e` turned `turn` fills the very cells it fills
## now (turned the other way round where it stands), or null.
func flip_spot(e: Dictionary, turn: int) -> Variant:
	var now := opening_cells(e)
	now.sort()
	var n := size_of(e.item)
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var c: Vector3i = e.cell + Vector3i(dx, 0, dz)
			var cells := _opening_at(e.item, c, turn)
			cells.sort()
			if cells == now:
				return c
	return null


## The north-west cell of a thing's square of `n` by `n` cells in front of `who` where it
## can be placed (see _fits; `offsets` the cells it fills from there, `steps` for stairs),
## the nearest to a cell beyond its middle ahead, at the feet's level or a cell below or
## above; null if none.
func _spot_in_front(who, top: int, n := 2, offsets: Array[Vector3i] = [], rest := ON_GROUND, high := 1) -> Variant:
	if offsets.is_empty():
		for dz in n:
			for dx in n:
				offsets.append(Vector3i(dx, 0, dz))
	var feet: Vector3i = who.feet()
	var s: Vector2i = who.facing_step()
	# The cells it fills are aimed at, not its square: a door or a window two or three
	# cells wide fills only a row of it, set into a wall a step ahead.
	var mid := Vector2.ZERO
	var lo := Vector2i(n, n)
	var hi := Vector2i(-1, -1)
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
		lo = lo.min(Vector2i(o.x, o.z))
		hi = hi.max(Vector2i(o.x, o.z))
	mid /= offsets.size()
	# Aimed at the cells right in front: their middle as deep ahead as half of them, and a
	# half cell more from the feet's middle.
	var deep := (hi.x - lo.x + 1) if s.x != 0 else (hi.y - lo.y + 1)
	var ahead := deep * 0.5 + 0.5
	var aim := Vector2(feet.x + 0.5 + s.x * ahead, feet.z + 0.5 + s.y * ahead)
	return _spot_at(who, aim, feet.y, top, n, offsets, rest, high)


## The north-west cell of the free spot for a thing filling `offsets` (see
## _spot_in_front) whose filled cells' middle is nearest column point `aim` (cells), at
## level `level`, one down or one up; blocks put there at level `cut_from` or higher may
## be taken out for it (a door, a window, see put_at). Null for none.
func _spot_at(who, aim: Vector2, level: int, top: int, n: int, offsets: Array[Vector3i], rest: int, high: int, cut_from := NO_CUT) -> Variant:
	var mid := Vector2.ZERO
	for o: Vector3i in offsets:
		mid += Vector2(o.x, o.z) + Vector2(0.5, 0.5)
	mid /= maxi(offsets.size(), 1)
	var base := Vector2i(floori(aim.x), floori(aim.y))
	var corners: Array[Vector2i] = []
	for dz in range(-n - 1, 3):
		for dx in range(-n - 1, 3):
			corners.append(base + Vector2i(dx, dz))
	corners.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + mid).distance_squared_to(aim) < (Vector2(b) + mid).distance_squared_to(aim))
	# A hatch goes only into the floor or the ceiling tapped.
	var levels: Array = [0] if rest == IN_FLOOR else [0, -1, 1]
	for c in corners.slice(0, 6):
		for dy: int in levels:
			var corner := Vector3i(c.x, level + dy, c.y)
			if _fits(who, corner, top, offsets, rest, high, cut_from):
				return corner
	return null


## Whether the cells `offsets` from `corner` (two by two when none are given) are free
## (no cell, no other thing, ladder or light, not `who`), at or below level `top`, and rest
## as `rest` says (ON_GROUND on solid ground, see ON_GROUND), with air over them for a
## thing `high` cells tall (a door); stairs may stand on air, as blocks are laid.
func _fits(who, corner: Vector3i, top: int, offsets: Array[Vector3i] = [], rest := ON_GROUND, high := 1, cut_from := NO_CUT) -> bool:
	if offsets.is_empty():
		offsets = [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)]
	for o: Vector3i in offsets:
		var c := corner + o
		# A ghost thing (_ghosts) may stand where a body is now.
		if not _open(c, cut_from) or not _rests(c, rest) \
				or _ghosts == null and who.overlaps_cell(c) or c.y > top or world.blockers.has(c) and not _swappable(c) \
				or world.ladders.has(c) or not light_at(c).is_empty() or _in_open_door(c) or _ghost_taken(c):
			return false
		for k in range(1, high):
			var up := c + Vector3i(0, k, 0)
			if not _open(up, cut_from) or world.blockers.has(up) or _ghost_taken(up):
				return false
	return true


## Whether the thing in cell `c` is a fence a wicket or a gate set down now takes the
## place of (see put_at).
func _swappable(c: Vector3i) -> bool:
	return _swap_fences and _fences.has(c) and is_fence(_fences[c])


## Whether a thing resting as `rest` (ON_GROUND…) can stand in cell `c`: on solid ground
## (for a ladder on a ladder too), anywhere, or in a floor (a solid cell beside it).
func _rests(c: Vector3i, rest: int) -> bool:
	match rest:
		ANYWHERE:
			return true
		ON_LADDER:
			if _solid(c + Vector3i.DOWN) or world.ladders.has(c + Vector3i.DOWN):
				return true
			# On a ghost ladder, while a ghost one's place is looked for.
			var under: Dictionary = _ghosts.thing_at(c + Vector3i.DOWN) if _ghosts != null else {}
			return not under.is_empty() and is_ladder(under)
		IN_FLOOR, ON_WALL:
			for d: Vector3i in SIDES:
				if _solid(c + d):
					return true
			return false
	return _solid(c + Vector3i.DOWN)


## Whether cell `c` is air, or a block put there that an opening takes out (at level
## `cut_from` or higher: an opening is cut into walls, not into the floor under it).
func _open(c: Vector3i, cut_from: int) -> bool:
	if _ghosts != null and _ghosts.block_at(c):
		# A ghost block: taken, but a ghost door or window takes its place.
		return c.y >= cut_from
	var m: int = world.get_cell(c.x, c.y, c.z)
	return m == Mat.AIR or c.y >= cut_from and m != Mat.WATER and not world.is_natural(c.x, c.y, c.z)


## True when cell `c` is one of those a door standing open fills when shut (it frees them
## while open, see opened_boxes): nothing is set down in a doorway.
func _in_open_door(c: Vector3i) -> bool:
	for e: Dictionary in near(Vector2i(c.x, c.z), Vector2i(c.x, c.z)):
		if e.get("open", false) and e.cell.y == c.y and not is_same(e, _moving):
			var shut := e.duplicate()
			shut.open = false
			if cells_of(shut).has(c):
				return true
	return false


## The cell in front of `who` a light can stand in (see _light_fits): one step ahead,
## else two, at the feet's level or a cell below or above; null if none.
func light_spot(who, top: int) -> Variant:
	var feet: Vector3i = who.feet()
	var s: Vector2i = who.facing_step()
	for ahead: int in [1, 2]:
		for dy: int in [0, -1, 1]:
			var c := Vector3i(feet.x + s.x * ahead, feet.y + dy, feet.z + s.y * ahead)
			if _light_fits(who, c, top):
				return c
	return null


## Whether a light can stand in `cell`: air over solid ground, no higher than `top`,
## clear of `who`, of the things and of the other lights.
func _light_fits(who, cell: Vector3i, top: int, own := {}) -> bool:
	if cell.y > top or world.get_cell(cell.x, cell.y, cell.z) != Mat.AIR or not world.is_solid(cell.x, cell.y - 1, cell.z):
		return false
	var there := light_at(cell)
	if who.overlaps_cell(cell) or world.blockers.has(cell) or world.ladders.has(cell) or not there.is_empty() and not is_same(there, own):
		return false
	return true


## The cell light `e` would stand in moved to `cell`: that cell, or the one below or above
## it that fits (its own cell counted free); null when there is none.
func light_move_spot(who, e: Dictionary, cell: Vector3i) -> Variant:
	for dy: int in [0, -1, 1]:
		var c := cell + Vector3i(0, dy, 0)
		if _light_fits(who, c, c.y, e):
			return c
	return null
