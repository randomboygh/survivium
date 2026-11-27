extends "res://src/shared/game/placed_kinds.gd"
## Placed things, part 2 (see placed.gd): the things and lights set down and the cells they block,
## the index of them by cell and by chunk (at, near: the rules look only at the things near a
## point, not over every thing of the world), saving them (to_list, from_list), the camp of a new
## world and the free ground near a point.

const Content := preload("res://src/shared/content/content.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
## How far (cells) from its own spot a thing of the start's camp is set down when that
## spot is taken, and how many levels above or below the spawn it may stand (see camp_spot).
const CAMP_REACH := 12
const CAMP_RISE := 3
## How many levels over the camp's spot must be open (_open_above).
const CAMP_SKY := 24
## The steps to the sides a fence joins, by the bit of `join` (1 << i): north, east,
## south, west, as Placed.turn_voxels turns the north rail of its model.
const SIDES: Array[Vector3i] = [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]
var world
## Each light set down: {"item": id, "cell": Vector3i (the cell it stands in), "burnt":
## seconds it has burned, "light": true, "items": null, "lit": true}. Saved with the
## things (to_list).
var lights: Array = []
## Each thing placed: {"item": id, "cell": Vector3i (the north-west of its square of
## cells), "turn": quarters it is turned (see sizes), "items": what a thing that stores holds (an Inventory, else null), "lit": false
## for a fire put out, and for a fire "fuel": the seconds it has left to burn, "wet": the
## seconds it has stood in the rain}, for a rain catcher "water": what it holds, and "by": the number of the player who put it
## from their bag (Player.id, 0 in a single game; none for the start's camp), "text": what a
## sign says (see write), for an opening (is_opening) "cut": the blocks it took out (offset
## from "cell" -> material id, see cut_of); a fire is a
## place its maker and their team come back to after death (Character.find_respawns).
## Saved with the world (to_list).
var things: Array = []
## The things and lights of `things` and `lights` whose item keeps the animals off while
## it burns (its `scares`; Wildlife._find_fires), kept as they come and go, so the
## animals' look for fires does not go over every thing set down.
var scarers: Array = []
## What the chest by the spawn holds (the first thing that stores placed).
var chest_items = null
## The solid boxes of a thing of a prop kind, not turned, in each of its cells (see
## WorldData.blockers): kind -> one per cell of its square, row by row from the
## north-west ([north-west, north-east, south-west, south-east] for two by two), each in
## cell units from that cell's corner, with no size where the cell stays empty, or for a
## thing with `steps` an Array of the boxes of its steps. The shapes are the models'
## (read_footprints); a kind not given fills its four cells.
var footprints := {}
## The same for each turn: kind -> [turn 0, 1, 2, 3].
var turned := {}
## The boxes of a door open, for each turn: kind -> [turn 0, 1, 2, 3]: none, an open door
## is drawn swung back (open_voxels) but bodies pass it.
var opened_boxes := {}
## The fences, wickets and gates by each cell they fill: what a fence joins (joins).
var _fences := {}
## The items that are seats (`seat` over 1) by id, with their `seat`: seat_near looks no
## further when there are none, every body every step.
static var seats := {}
## The boxes of a kind whose item has no model: the plain crate VoxelProps draws for
## it, its walls a voxel in from the edges of its cells.
## What a thing drawn as a picture (an item's `picture`) takes of its one cell.
const SPRITE_BOX := AABB(Vector3(0.125, 0.0, 0.125), Vector3(0.75, 2.0, 0.75))
const CRATE_BOX := AABB(Vector3(0.125, 0.0, 0.125), Vector3(0.75, 1.0, 0.75))
## The boxes of a fire: only the logs in its middle, a cell square across its four
## cells, a cell high so no step climbs it; the ring of stones round them is walked
## over, so a body comes right up to the flames to warm and cook.
const FIRE_BOXES := [
	AABB(Vector3(0.5, 0.0, 0.5), Vector3(0.5, 1.0, 0.5)),
	AABB(Vector3(0.0, 0.0, 0.5), Vector3(0.5, 1.0, 0.5)),
	AABB(Vector3(0.5, 0.0, 0.0), Vector3(0.5, 1.0, 0.5)),
	AABB(Vector3(0.0, 0.0, 0.0), Vector3(0.5, 1.0, 0.5)),
]


## Reads the solid boxes of every kind of thing placed from its model, so bodies go
## round the things as they are drawn: the model of the first item with that `prop`
## (its `model` PNG in its bundle, read as VoxelModel.from_image reads it, the slice's
## corner at the cell's). A fire takes only its middle (FIRE_BOXES); a kind without a
## model gets the crate's boxes. Called once the mods are loaded, and again when they
## are read anew.
func read_footprints() -> void:
	# The items read anew may scare otherwise.
	scarers = []
	for e: Dictionary in things + lights:
		_note_scarer(e)
	footprints = {}
	turned = {}
	sizes = {}
	middles = {}
	seats = {}
	for id in Items.IDS:
		var rec := Items.get_item(id)
		var kind: String = rec.get("prop", "none")
		if rec.get("seat", 1.0) > 1.0:
			seats[id] = rec.seat
		if kind == "none" or footprints.has(kind):
			continue
		if rec.get("fire", false) and rec.get("model", "") == "":
			footprints[kind] = FIRE_BOXES
			turned[kind] = [FIRE_BOXES, FIRE_BOXES, FIRE_BOXES, FIRE_BOXES]
			sizes[kind] = 2
			continue
		if rec.get("picture", "") != "":
			# Drawn as a picture standing on one cell (Props._add_sprite): solid as a post.
			footprints[kind] = [SPRITE_BOX]
			turned[kind] = [[SPRITE_BOX], [SPRITE_BOX], [SPRITE_BOX], [SPRITE_BOX]]
			sizes[kind] = 1
			middles[kind] = [Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, 0.5)]
			continue
		var name: String = rec.get("model", "")
		var path := Content.asset(rec, "models/%s.png" % name) if name != "" else ""
		var img: Image = Content.picture(path) if path != "" else null
		if img != null:
			var n := maxi(1, ceili(img.get_height() / 8.0))
			var voxels := shut_voxels(rec, voxels_of_image(img))
			sizes[kind] = n
			var all := []
			for t in 4:
				var boxes := footprint(turn_voxels(voxels, n * 8, t), n, rec.get("steps", false))
				if rec.get("fence", false):
					boxes = _fenced(boxes)
				all.append(boxes)
			footprints[kind] = all[0]
			turned[kind] = all
			var mids := []
			for t in 4:
				mids.append(_middle(all[t], n))
			middles[kind] = mids
			if rec.get("door", false):
				# An open door is solid nowhere: its leaf, swung back, would take a quarter of
				# a doorway a body only just fits through, and swing into the body opening it.
				var none := []
				for i in n * n:
					none.append(AABB())
				opened_boxes[kind] = [none, none, none, none]
		else:
			footprints[kind] = [CRATE_BOX, CRATE_BOX, CRATE_BOX, CRATE_BOX]
			turned[kind] = [footprints[kind], footprints[kind], footprints[kind], footprints[kind]]
			sizes[kind] = 2


## The sides fence `e` joins (bits of SIDES): each beside it on its level where a fence, a
## wicket or a gate stands; one alone has rails both ways across its front (along the
## line it was set down in).
func joins(e: Dictionary) -> int:
	var join := 0
	for i in 4:
		if _fences.has(e.cell + SIDES[i]):
			join |= 1 << i
	if join == 0:
		join = 10 if e.get("turn", 0) % 2 == 0 else 5
	return join


## The fences beside `cell` join their sides anew (one came or went there).
func _rejoin_around(cell: Vector3i) -> void:
	for d: Vector3i in SIDES:
		var n: Dictionary = _fences.get(cell + d, {})
		if n.is_empty() or not is_fence(n) or n.cell != cell + d:
			continue
		var join := joins(n)
		if join == n.get("join", -1):
			continue
		n.join = join
		world.blockers[n.cell] = boxes_of(n)[0]
		joined.emit(n)


## The boxes of thing `e` in each cell of its square (see footprints), by its turn, a
## door's by whether it is open.
func boxes_of(e: Dictionary) -> Array:
	var kind: String = Items.get_item(e.item).prop
	if e.has("join"):
		return [fence_boxes(e.join)]
	if e.get("open", false) and opened_boxes.has(kind):
		return opened_boxes[kind][e.get("turn", 0)]
	if turned.has(kind):
		return turned[kind][e.get("turn", 0)]
	var whole := AABB(Vector3.ZERO, Vector3.ONE)
	return [whole, whole, whole, whole]


## Makes the cells thing `e` fills solid by its boxes (WorldData.blockers); a ladder's
## are climbed instead (WorldData.ladders: its turn by cell), a fence's join those beside.
func _block(e: Dictionary) -> void:
	if is_ladder(e):
		world.ladders[e.cell] = e.get("turn", 0)
		return
	if is_fence(e):
		e.join = joins(e)
	var boxes := boxes_of(e)
	var n := size_of(e.item)
	for i in boxes.size():
		if boxes[i] is Array or boxes[i].has_volume():
			world.blockers[e.cell + Vector3i(i % n, 0, i / n)] = boxes[i]


## Lets go of the cells thing `e` fills.
func _unblock(e: Dictionary) -> void:
	if is_ladder(e):
		world.ladders.erase(e.cell)
		return
	for c: Vector3i in cells_of(e):
		world.blockers.erase(c)


## The cells thing `e` fills (its boxes there), from its north-west cell.
func cells_of(e: Dictionary) -> Array[Vector3i]:
	var n := size_of(e.item)
	var boxes := boxes_of(e)
	var out: Array[Vector3i] = []
	for i in boxes.size():
		if boxes[i] is Array or boxes[i].has_volume():
			out.append(e.cell + Vector3i(i % n, 0, i / n))
	return out


## Where a body stands beside thing `e` (world units): the first cell of `beside` with air
## for a body two cells tall on solid ground, else the first of them (the body climbs out).
func stand_by(e: Dictionary) -> Vector3:
	var c: Vector3i = e.cell
	var around := beside(size_of(e.item))
	var spot: Vector3i = c + around[0]
	for d: Vector3i in around:
		var p: Vector3i = c + d
		if world.get_cell(p.x, p.y, p.z) == Mat.AIR and world.get_cell(p.x, p.y + 1, p.z) == Mat.AIR \
				and world.is_solid(p.x, p.y - 1, p.z) and not world.blockers.has(p):
			spot = p
			break
	return (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL


## Places thing `item` (an item with a `prop`) with its north-west cell at `cell`;
## `items` is what a thing that stores holds, as Inventory.to_dict() gave it; `lit` false
## puts a fire there cold; `fuel` is the seconds a fire has left (below 0: a new one's
## `fuel_start`); `grave` who died there for a cross (see put_grave); `cut` the blocks an
## opening took out of a wall (see cut_of; null: not known, an old save's).
func put(item: String, cell: Vector3i, items: Variant = null, lit := true, fuel := -1.0, by: Variant = null, turn := 0, open := false, text := "", grave := {}, wreath := "", cut: Variant = {}) -> Dictionary:
	var rec := Items.get_item(item)
	var e := {"item": item, "cell": cell, "items": null, "lit": lit or not rec.fire, "turn": posmod(turn, 4)}
	if rec.get("sign_lines", 0) > 0:
		e.text = sign_text(item, text)
	if rec.get("grave", false):
		e.grave = grave_record(grave)
	if rec.get("door", false):
		e.open = open
		if wreath != "" and Items.has(wreath) and Items.get_item(wreath).get("wreath", false):
			e.wreath = Items.get_item(wreath).id
	if is_opening(item) and cut is Dictionary:
		# What it cut out of a wall (put_at, _move_opening): none where it went into a gap;
		# null for one of an old save, which takes the wall's blocks round it (cut_of).
		e.cut = cut.duplicate()
	if by is int:
		e.by = by
	if rec.get("rain_water", 0.0) > 0.0:
		e.water = 0.0
	if rec.get("melts", 0.0) > 0.0:
		e.melt = 0.0
	if rec.fire:
		e.fuel = clampf(fuel, 0.0, rec.fuel_max) if fuel >= 0.0 else rec.fuel_start
		e.wet = 0.0
		# One with nothing to burn (a fireplace set down, its `fuel_start` 0) stands cold.
		if e.fuel <= 0.0 and rec.fuel_max > 0.0:
			e.lit = false
	_block(e)
	if rec.storage > 0:
		e.items = Inventory.new(rec.storage)
		e.items.nests = false
		if items is Dictionary:
			e.items.from_dict(items)
		if chest_items == null:
			chest_items = e.items
	things.append(e)
	_note_scarer(e)
	if rec.get("fence", false):
		for c: Vector3i in cells_of(e):
			_fences[c] = e
		_rejoin_around(e.cell)
		for c: Vector3i in cells_of(e):
			_rejoin_around(c)
	added.emit(e)
	return e


## Places what a world's plan sets down (TestGround.plan_things): [item, north-west cell,
## turn (0 when left out), the seconds a fire has to burn (its `fuel_start` when left
## out)], a light on its cell (see put_light).
func put_plan(t: Array) -> void:
	if is_light_item(t[0]):
		put_light(t[0], t[1])
	else:
		put(t[0], t[1], null, true, float(t[3]) if t.size() > 3 else -1.0, null, t[2] if t.size() > 2 else 0)


## Puts back the things of a save (see to_list).
func from_list(list: Array) -> void:
	for d in list:
		if d is Dictionary and Items.has(Items.canon(d.get("item", ""))) and d.get("cell") is Array and d.cell.size() == 3:
			var id: String = Items.get_item(Items.canon(d.item)).id
			if is_light_item(id):
				put_light(id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), float(d.get("burnt", 0.0)), posmod(int(d.get("turn", 0)), 4))
				continue
			# An opening of a save from before it remembered its blocks has no `cut` (cut_of).
			var e := put(id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), d.get("items"),
				not d.get("out", false), float(d.get("fuel", -1.0)), int(d.by) if d.get("by") is float or d.get("by") is int else null,
				int(d.get("turn", 0)), bool(d.get("open", false)), str(d.get("text", "")),
				d.get("grave") if d.get("grave") is Dictionary else {}, str(d.get("wreath", "")),
				cut_from_list(d.cut) if d.get("cut") is Array else null)
			if e.has("water") and (d.get("water") is float or d.get("water") is int):
				e.water = clampf(float(d.water), 0.0, Items.get_item(id).rain_water)
			if e.has("melt") and (d.get("melt") is float or d.get("melt") is int):
				e.melt = clampf(float(d.melt), 0.0, 1.0)


## The placed things as plain data for the save.
func to_list() -> Array:
	var out := []
	for e in things:
		out.append(record(e))
	for e in lights:
		out.append(record(e))
	return out


## Puts the camp of the start (Starts.START: the campfire, the chest when its bundle is
## loaded) next to world point `at` (the spawn), each thing its cells east and south of
## it, or at the nearest free level spot round there when that one is taken (a tree, a
## slope, water, the other thing): every thing of the camp stands by the spawn, under the
## open sky where there is such a spot (not under a crown or behind one, where the player
## would not see it: _open_above). The chunks there are made by then, so the ground under them is known.
func start_camp(at: Vector3) -> void:
	var home := Vector3i((at / CELL).floor())
	for e: Dictionary in Starts.START.camp:
		var spot := camp_spot(home, Vector2i(home.x + int(e.at[0]), home.z + int(e.at[1])))
		if spot.y >= 0:
			put(e.item, spot)


## The north-west cell of the free level two by two cells nearest to column `want`
## within CAMP_REACH of it and off the spawn `home`: at the spawn's level if
## there is one, else within CAMP_RISE levels, else at any level; the ground under them
## levelled. y = -1 when there is none.
func camp_spot(home: Vector3i, want: Vector2i) -> Vector3i:
	for open in [true, false]:
		var spot := _camp_spot(home, want, open)
		if spot.y >= 0:
			return spot
	return Vector3i(0, -1, 0)


## camp_spot's search, with `open`: only where nothing hangs over the spot (_open_above).
func _camp_spot(home: Vector3i, want: Vector2i, open: bool) -> Vector3i:
	for rise in [0, CAMP_RISE, -1]:
		for r in CAMP_REACH + 1:
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) != r:
						continue
					var x := want.x + dx
					var z := want.y + dz
					# The spawn's cell and those round it stay free for the body.
					if x <= home.x + 1 and x + 1 >= home.x - 1 and z <= home.z + 1 and z + 1 >= home.z - 1:
						continue
					var y := _free_at(x, z)
					if y >= 0 and (rise < 0 or absi(y - home.y) <= rise) and (not open or _open_above(x, y, z)):
						_clear(Vector3i(x, y, z))
						return Vector3i(x, y, z)
	return Vector3i(0, -1, 0)


## The cell of the first thing placed of `item`, or null.
func cell_of(item: String) -> Variant:
	for e in things:
		if e.item == item:
			return e.cell
	return null


## The thing placed with its north-west cell at `cell`, or {}: how a request names a
## thing (Requests).
func at(cell: Vector3i) -> Dictionary:
	for e in things:
		if e.cell == cell:
			return e
	for e in lights:
		if e.cell == cell:
			return e
	return {}


## The stations (things that store nothing; a fire while it burns) within `reach` world
## units of world point `p`, and those they serve: item id -> true.
func stations_near(p: Vector3, reach: float) -> Dictionary:
	var out := {}
	for e in things:
		if e.items == null and e.lit and center(e).distance_to(p) <= reach:
			out[e.item] = true
			for s: String in Items.get_item(e.item).serves:
				out[s] = true
	return out


## The turn of a thing hung on a wall at `cell` (ON_WALL): `turn` (facing who set it down)
## when the cell behind it is solid, else the first turn with a solid cell behind (SIDES,
## the back of turn `t` toward SIDES[t]: its front faces away from the wall).
func wall_turn(cell: Vector3i, turn: int) -> int:
	for k in 4:
		var t := (turn + k) % 4
		var back: Vector3i = cell + SIDES[t]
		if world.is_solid(back.x, back.y, back.z):
			return t
	return turn


## Thing `e` falls apart of neglect (building decay, Decay): gone, nothing left of it.
func fall_apart(e: Dictionary) -> void:
	_remove(e)


## Takes placed thing `e` out of the world.
func _remove(e: Dictionary) -> void:
	_forget(e)
	world.note_edit(e.cell.x, e.cell.z)


## Lets go of thing `e`: its cells are free again, it is told gone (removed).
func _forget(e: Dictionary) -> void:
	scarers.erase(e)
	if is_light(e):
		lights.erase(e)
		removed.emit(e)
		return
	_unblock(e)
	if e.items == chest_items:
		chest_items = null
	things.erase(e)
	var fenced: Array[Vector3i] = []
	if Items.get_item(e.item).get("fence", false):
		for c: Vector3i in _fences.keys():
			if _fences[c] == e:
				_fences.erase(c)
				fenced.append(c)
	removed.emit(e)
	for c in fenced:
		_rejoin_around(c)


## The north-west cell of two by two free cells on ground at one level near the world
## point `p`, the ground under them levelled; y = -1 when there is no such spot.
func spot_near(p: Vector3) -> Vector3i:
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	var y := _free_at(x, z)
	if y < 0:
		return Vector3i(0, -1, 0)
	_clear(Vector3i(x, y, z))
	return Vector3i(x, y, z)


## The level of the ground of the two by two cells from column x, z when they are free
## (air on solid ground at one level, no other thing there), else -1.
func _free_at(x: int, z: int) -> int:
	var y: int = world.surface_y(x, z)
	if y <= 0:
		return -1
	for dz in 2:
		for dx in 2:
			if world.get_cell(x + dx, y, z + dz) != Mat.AIR or not world.is_solid(x + dx, y - 1, z + dz) \
					or world.blockers.has(Vector3i(x + dx, y, z + dz)):
				return -1
	return y


## Whether nothing hangs over the two by two cells at (x, y, z) or stands between them
## and the camera: no leaves, trunk or rock CAMP_SKY levels up, with a cell round them,
## straight over them (from two levels up) and along the line the view looks down by at
## 3/4 (a level up is a cell south, PixelView.VIEW_DIR, the turn at the start). A thing
## there is seen from the start.
func _open_above(x: int, y: int, z: int) -> bool:
	for dy in range(1, CAMP_SKY + 1):
		var yy := y + dy
		if yy >= world.size_y:
			break
		for dx in range(-1, 3):
			for dz in range(-1, 3):
				if world.get_cell(x + dx, yy, z + dz + dy) != Mat.AIR:
					return false
				if dy >= 2 and world.get_cell(x + dx, yy, z + dz) != Mat.AIR:
					return false
	return true


## Levels the ground under the two by two cells from `corner` and takes the bushes off them.
func _clear(corner: Vector3i) -> void:
	for dz in 2:
		for dx in 2:
			_level_ground(corner + Vector3i(dx, -1, dz))
			_remove_bush(corner + Vector3i(dx, 0, dz))


## Things stand on level ground: a slope under them becomes a whole cube.
func _level_ground(cell: Vector3i) -> void:
	if world.slope_mask(cell.x, cell.y, cell.z) != WorldData.FULL:
		world.set_natural(cell.x, cell.y, cell.z, false)
		cell_changed.emit(cell)


## Takes the bush on `cell` out of the world.
func _remove_bush(cell: Vector3i) -> void:
	if not world.bushes.has(cell):
		return
	world.remove_bush(cell)
	cell_changed.emit(cell)


## Sets light `item` down on `cell`, burned `burnt` seconds already, turned `turn` quarters.
func put_light(item: String, cell: Vector3i, burnt := 0.0, turn := 0) -> Dictionary:
	var e := {"item": item, "cell": cell, "burnt": burnt, "light": true, "items": null, "lit": true}
	if turn != 0:
		e.turn = turn
	lights.append(e)
	_note_scarer(e)
	added.emit(e)
	return e


func _note_scarer(e: Dictionary) -> void:
	if Items.get_item(e.item).get("scares", 0.0) > 0.0:
		scarers.append(e)


## The light standing in `cell`, {} for none.
func light_at(cell: Vector3i) -> Dictionary:
	for e in lights:
		if e.cell == cell:
			return e
	return {}
