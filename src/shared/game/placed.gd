extends RefCounted
## Things standing on two by two cells that are not cells (an item's `prop`): chests
## with what they hold, workbenches, kilns and campfires, placed from the bag, and the
## camp a new world starts with next to the spawn (Starts: a campfire, a chest). What a
## thing does goes by its item's flags, not its class: `storage` (it holds things, a
## chest), `fire` (a campfire), `serves` (the stations it stands in for), `place_tool` (the
## tool it is set down with). They are solid (WorldData.blockers): bodies go round them
## or jump on them, and a burning fire burns a body that touches it (see burns). A thing
## that stores is taken up with what it holds; a fire cannot be carried, but it can be put
## out, lit again for a branch, and destroyed without a trace. A fire burns on fuel (its
## item's `fuel_max`, see step): fed with branches, logs and the like, it goes out once
## they have burned, or in a downpour under the open sky; put out, it keeps what it has
## left. The rules take the one acting as `who` (see WorldActions) and tell what changed through signals: the
## client draws the things (Props) and rebuilds the chunks.
##
## Lights (an item with `light` and no `prop`: a torch, a candle, a lantern) are set down
## on one cell of their own (`lights`, see put_light_from_bag): not solid, they burn out
## their Items.burns seconds where they stand (step) and are gone, as in a hand (also when
## their cell is filled or the ground under it dug); taken
## back, what has burned goes with them. They come and go by the same signals as the
## things, their records marked `light`.

const Mat := preload("res://src/shared/content/materials.gd")
const Content := preload("res://src/shared/content/content.gd")
const Items := preload("res://src/shared/content/items.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Body := preload("res://src/shared/game/body.gd")
const Tools := preload("res://src/shared/content/tools.gd")

const CELL := WorldData.CELL
## The campfire of the camp by the spawn of a new world (see Starts), the place to come
## back to after death.
const CAMPFIRE := "core:campfire"
## How close (in cells) a body standing by a burning campfire comes to be burnt.
const SINGE := 0.02
## A fire burning under the open sky goes out after this many seconds of a heavy rain
## (of strength RAIN_HEAVY or more: a downpour, a storm; a light rain does not), and dries
## as fast once it stops.
const RAIN_OUT := 60.0
const RAIN_HEAVY := 0.9
## A fire is not fed while it has room for less than this many seconds.
const FUEL_ROOM := 30.0
## Those who copy the world learn what a fire has left this often, in seconds of it
## (fuel_changed), besides when it is fed.
const FUEL_TELL := 10.0
## How far (cells) from its own spot a thing of the start's camp is set down when that
## spot is taken, and how many levels above or below the spawn it may stand (see camp_spot).
const CAMP_REACH := 12
const CAMP_RISE := 3

## Thing `e` (see things) was placed, as the save had it or anew.
signal added(e: Dictionary)
## Thing `e` was taken out of the world.
signal removed(e: Dictionary)
## Campfire `e` was put out or lit again (its `lit`).
signal lit_changed(e: Dictionary)
## What campfire `e` has left to burn (its `fuel`) changed: it was fed, or another
## FUEL_TELL seconds of it burned.
signal fuel_changed(e: Dictionary)
## A cell under a thing was levelled or a bush there taken away: its chunks change.
signal cell_changed(cell: Vector3i)

var world
## Each light set down: {"item": id, "cell": Vector3i (the cell it stands in), "burnt":
## seconds it has burned, "light": true, "items": null, "lit": true}. Saved with the
## things (to_list).
var lights: Array = []
## Each thing placed: {"item": id, "cell": Vector3i (the north-west of its two by two
## cells), "items": what a thing that stores holds (an Inventory, else null), "lit": false
## for a fire put out, and for a fire "fuel": the seconds it has left to burn, "wet": the
## seconds it has stood in the rain}. Saved with the world (to_list).
var things: Array = []
## What the chest by the spawn holds (the first thing that stores placed).
var chest_items = null
## The solid boxes of a thing of a prop kind in each of its cells (see
## WorldData.blockers): kind -> [north-west, north-east, south-west, south-east], each
## in cell units from that cell's corner, with no size where the cell stays empty. The
## shapes are the models' (read_footprints); a kind not given fills its four cells.
var footprints := {}
## The boxes of a kind whose item has no model: the plain crate VoxelProps draws for
## it, its walls a voxel in from the edges of its cells.
const CRATE_BOX := AABB(Vector3(0.125, 0.0, 0.125), Vector3(0.75, 1.0, 0.75))


## Reads the solid boxes of every kind of thing placed from its model, so bodies go
## round the things as they are drawn: the model of the first item with that `prop`
## (its `model` PNG in its bundle, read as VoxelModel.from_image reads it, the slice's
## corner at the cell's). A fire is not solid (it burns bodies instead); a kind without
## a model gets the crate's boxes. Called once the mods are loaded, and again when they
## are read anew.
func read_footprints() -> void:
	footprints = {}
	for id in Items.IDS:
		var rec := Items.get_item(id)
		var kind: String = rec.get("prop", "none")
		if kind == "none" or rec.get("fire", false) or footprints.has(kind):
			continue
		var name: String = rec.get("model", "")
		var path := Content.asset(rec, "models/%s.png" % name) if name != "" else ""
		if path != "" and ResourceLoader.exists(path):
			footprints[kind] = footprint_of_image(load(path).get_image())
		else:
			footprints[kind] = [CRATE_BOX, CRATE_BOX, CRATE_BOX, CRATE_BOX]


## The boxes of the model in `img`, a row of square slices (the image's height wide),
## one per level from the ground up, a pixel of any alpha the voxel at its x and z (z
## down the slice), the slice's corner at the thing's north-west cell.
static func footprint_of_image(img: Image) -> Array[AABB]:
	var voxels: Array[Vector3i] = []
	var size := img.get_height()
	if size > 0 and img.get_width() % size == 0:
		for y in img.get_width() / size:
			for z in size:
				for x in size:
					if img.get_pixel(y * size + x, z).a > 0.0:
						voxels.append(Vector3i(x, y, z))
	return footprint(voxels)


## The boxes a thing on 2x2 cells of the voxels `voxels` (Vector3i each, an Array or the
## keys of a Dictionary, 8 voxels a cell, from the north-west cell's corner) takes in
## each of its cells, for WorldData.blockers: [north-west, north-east, south-west,
## south-east], each in cell units from that cell's corner, with no size where it leaves
## the cell empty. A layer much smaller than the one under it (a flint lying on a
## workbench) is left out of the box's top, so it does not lift the player off the planks.
static func footprint(voxels) -> Array[AABB]:
	var lo: Array[Vector3i] = []
	var hi: Array[Vector3i] = []
	var layers: Array[Dictionary] = []
	for i in 4:
		lo.append(Vector3i(8, 0, 8))
		hi.append(Vector3i.ZERO)
		layers.append({})
	for p: Vector3i in voxels:
		var i := (p.z >> 3) * 2 + (p.x >> 3)
		var q := Vector3i(p.x & 7, 0, p.z & 7)
		lo[i] = lo[i].min(q)
		hi[i] = hi[i].max(q + Vector3i(1, 0, 1))
		layers[i][p.y] = layers[i].get(p.y, 0) + 1
	var out: Array[AABB] = []
	for i in 4:
		var size := (hi[i] - lo[i]).max(Vector3i.ZERO)
		var top := 0
		for y: int in layers[i]:
			if y + 1 > top and layers[i][y] * 4 >= layers[i].get(y - 1, 0):
				top = y + 1
		out.append(AABB(Vector3(lo[i].x, 0, lo[i].z) / 8.0, Vector3(size.x, top, size.z) / 8.0) if size.x > 0 else AABB())
	return out


## True for a fire (its item's `fire`: what burns, see put_out and light).
static func is_fire(e: Dictionary) -> bool:
	return Items.get_item(e.item).get("fire", false)


## Places thing `item` (an item with a `prop`) with its north-west cell at `cell`;
## `items` is what a thing that stores holds, as Inventory.to_dict() gave it; `lit` false
## puts a fire there cold; `fuel` is the seconds a fire has left (below 0: a new one's
## `fuel_start`).
func put(item: String, cell: Vector3i, items: Variant = null, lit := true, fuel := -1.0) -> Dictionary:
	var rec := Items.get_item(item)
	var e := {"item": item, "cell": cell, "items": null, "lit": lit or not rec.fire}
	if rec.fire:
		e.fuel = clampf(fuel, 0.0, rec.fuel_max) if fuel >= 0.0 else rec.fuel_start
		e.wet = 0.0
	var whole := AABB(Vector3.ZERO, Vector3.ONE)
	var boxes: Array = footprints.get(rec.prop, [whole, whole, whole, whole])
	for i in 4:
		if boxes[i].has_volume():
			world.blockers[cell + Vector3i(i & 1, 0, i >> 1)] = boxes[i]
	if rec.storage > 0:
		e.items = Inventory.new(rec.storage)
		e.items.nests = false
		if items is Dictionary:
			e.items.from_dict(items)
		if chest_items == null:
			chest_items = e.items
	things.append(e)
	added.emit(e)
	return e


## Puts back the things of a save (see to_list).
func from_list(list: Array) -> void:
	for d in list:
		if d is Dictionary and Items.has(Items.canon(d.get("item", ""))) and d.get("cell") is Array and d.cell.size() == 3:
			var id: String = Items.get_item(Items.canon(d.item)).id
			if is_light_item(id):
				put_light(id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), float(d.get("burnt", 0.0)))
				continue
			put(id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), d.get("items"),
				not d.get("out", false), float(d.get("fuel", -1.0)))


## The placed things as plain data for the save.
func to_list() -> Array:
	var out := []
	for e in things:
		out.append(record(e))
	for e in lights:
		out.append(record(e))
	return out


## Thing `e` as plain data (one of to_list): {"item", "cell": [x, y, z], "items" what it
## holds (Inventory.to_dict) if it stores, "out" true for a fire put out, "fuel" the
## seconds a fire has left}.
static func record(e: Dictionary) -> Dictionary:
	var c: Vector3i = e.cell
	var d := {"item": e.item, "cell": [c.x, c.y, c.z]}
	if is_light(e):
		d.burnt = e.burnt
		return d
	if e.items != null:
		d.items = e.items.to_dict()
	if not e.lit:
		d.out = true
	if e.has("fuel"):
		d.fuel = snappedf(e.fuel, 0.1)
	return d


## Puts the camp of the start (Starts.START: the campfire, the chest when its bundle is
## loaded) next to world point `at` (the spawn), each thing its cells east and south of
## it, or at the nearest free level spot round there when that one is taken (a tree, a
## slope, water, the other thing): every thing of the camp stands by the spawn. The chunks
## there are made by then, so the ground under them is known.
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
					if y >= 0 and (rise < 0 or absi(y - home.y) <= rise):
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


## The middle of placed thing `e` in world units.
static func center(e: Dictionary) -> Vector3:
	if is_light(e):
		return (Vector3(e.cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	return (Vector3(e.cell) + Vector3(1.0, 0.5, 1.0)) * CELL


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


## True when a body with its feet at `p` (world units) touches a burning campfire (see
## burning).
func burns(p: Vector3) -> bool:
	return not burning(p).is_empty()


## The burning campfire a body with its feet at `p` (world units) touches, {} for none:
## beside it within SINGE or on top of it. Asked also for where a body pushed
## (Body.bumped), which a step stops short of the fire.
func burning(p: Vector3) -> Dictionary:
	var c := p / CELL
	for e in things:
		if not e.lit or not is_fire(e):
			continue
		var at: Vector3i = e.cell
		if c.y < at.y - Body.HEIGHT or c.y > at.y + 1.0 + SINGE:
			continue
		if c.x + Body.HALF_WIDTH + SINGE > at.x and c.x - Body.HALF_WIDTH - SINGE < at.x + 2 \
				and c.z + Body.HALF_DEPTH + SINGE > at.z and c.z - Body.HALF_DEPTH - SINGE < at.z + 2:
			return e
	return {}


## `who` places item `id` from the bag (from bag slot `slot` when given, else the first
## that holds it) on two by two free cells of level ground in front, at or below level
## `top`, with a tool of its `place_tool` class in the bag; a thing that stores brings back
## what it held. True if it was placed.
func put_from_bag(who, id: String, slot: int, top: int) -> bool:
	var item := Items.get_item(id)
	var inv = who.inventory
	if slot < 0:
		for i in inv.slots.size():
			if slot < 0 and inv.slots[i] != null and inv.slots[i][0] == item.get("id", ""):
				slot = i
	if item.get("prop", "none") == "none" or slot < 0 or inv.slots[slot] == null or inv.slots[slot][0] != item.id:
		return false
	if item.place_tool != "none" and not Tools.holds(inv, item.place_tool):
		who.nag("put", "Чтобы поставить, нужен инструмент: %s" % Items.tool_title(item.place_tool))
		return false
	var spot: Variant = _spot_in_front(who, top)
	if spot == null:
		who.nag("put", "Нужно ровное место 2×2 перед собой")
		return false
	if not who.act("place"):
		return false
	var taken: Array = inv.take_slot(slot, 1)
	for dz in 2:
		for dx in 2:
			_level_ground(spot + Vector3i(dx, -1, dz))
			_remove_bush(spot + Vector3i(dx, 0, dz))
	put(item.id, spot, taken[3] if taken.size() > 3 else null)
	world.note_edit(spot.x, spot.z)
	return true


## `who` takes placed thing `e` back into the bag, a thing that stores with what it holds
## (its weight and theirs go to the bag); not a fire (see put_out and destroy). True if it
## was taken.
func take_up(who, e: Dictionary) -> bool:
	if is_light(e):
		return take_light(who, e)
	if is_fire(e):
		who.nag("take", "%s не унести: его можно потушить и разобрать" % Items.title(e.item))
		return false
	var inv = who.inventory
	var full: bool = e.items != null and not e.items.is_empty()
	if (inv.add(e.item, 1, 0, e.items.to_dict()) if full else who.give(e.item, 1)) < 1:
		who.nag("full", "Сумка полна")
		return false
	if full:
		who.say("+1 %s с вещами" % Items.title(e.item))
	_remove(e)
	return true


## Puts out campfire `e`: it no longer burns, warms or lets anything be made at it.
func put_out(e: Dictionary) -> void:
	if not is_fire(e) or not e.lit:
		return
	e.lit = false
	lit_changed.emit(e)
	world.note_edit(e.cell.x, e.cell.z)


## `who` lights campfire `e` again for one piece of fuel from the bag (an item with
## `fuel`, a branch), which it then burns on, with what it had left; true if it burns.
func light(who, e: Dictionary) -> bool:
	if not is_fire(e) or e.lit:
		return e.lit
	var fuel := fuel_for(who.inventory)
	if fuel == "" or who.inventory.remove(fuel, 1) < 1:
		who.nag("light", "Чтобы разжечь, нужна ветка или другое топливо")
		return false
	_add_fuel(e, fuel)
	e.wet = 0.0
	e.lit = true
	lit_changed.emit(e)
	world.note_edit(e.cell.x, e.cell.z)
	return true


## `who` puts one piece of fuel from the bag on campfire `e` that burns (see fuel_for):
## it burns that much longer, up to its `fuel_max`; true if it was fed. One put out is
## lit (see light).
func feed(who, e: Dictionary) -> bool:
	if not is_fire(e):
		return false
	if not e.lit:
		return light(who, e)
	var most: float = Items.get_item(e.item).fuel_max
	if most <= 0.0:
		return false
	if most - e.fuel < FUEL_ROOM:
		who.nag("fuel", "Костёр и так горит в полную силу")
		return false
	var fuel := fuel_for(who.inventory)
	if fuel == "" or who.inventory.remove(fuel, 1) < 1:
		who.nag("fuel", "Подложить нечего: нужна ветка, бревно или другое топливо")
		return false
	_add_fuel(e, fuel)
	world.note_edit(e.cell.x, e.cell.z)
	return true


## The fuel in bag `inv` to put on a fire: the shortest burning (a branch before a log,
## which is worth more as timber); "" when the bag holds none.
static func fuel_for(inv) -> String:
	var shortest := ""
	for id: String in Items.IDS:
		var t := Items.fuel_time(id)
		if t > 0.0 and inv.count(id) > 0 and (shortest == "" or t < Items.fuel_time(shortest)):
			shortest = id
	return shortest


func _add_fuel(e: Dictionary, fuel: String) -> void:
	var most: float = Items.get_item(e.item).fuel_max
	if most > 0.0:
		e.fuel = minf(most, float(e.get("fuel", 0.0)) + Items.fuel_time(fuel))
		fuel_changed.emit(e)


## The share of what fire `e` holds that it has left to burn, 0..1 (1 for one that burns
## for ever).
static func fuel_share(e: Dictionary) -> float:
	var most: float = Items.get_item(e.item).get("fuel_max", 0.0)
	return 1.0 if most <= 0.0 else clampf(float(e.get("fuel", 0.0)) / most, 0.0, 1.0)


## True when nothing keeps the rain off fire `e`: a column of its cells has no roof above
## it (WorldData.roof_level), its chunk in memory.
func _in_rain(e: Dictionary) -> bool:
	var c: Vector3i = e.cell
	if world.chunk_at(c.x, c.z) == null:
		return false
	for dz in 2:
		for dx in 2:
			if world.roof_level(c.x + dx, c.z + dz) < c.y:
				return true
	return false


## Destroys campfire `e` that has been put out: nothing is left of it.
func destroy(e: Dictionary) -> bool:
	if not is_fire(e) or e.lit:
		return false
	_remove(e)
	return true


## Takes placed thing `e` out of the world.
func _remove(e: Dictionary) -> void:
	_forget(e)
	world.note_edit(e.cell.x, e.cell.z)


## Lets go of thing `e`: its cells are free again, it is told gone (removed).
func _forget(e: Dictionary) -> void:
	if is_light(e):
		lights.erase(e)
		removed.emit(e)
		return
	for dz in 2:
		for dx in 2:
			world.blockers.erase(e.cell + Vector3i(dx, 0, dz))
	if e.items == chest_items:
		chest_items = null
	things.erase(e)
	removed.emit(e)


## The north-west cell of two by two cells in front of `who` where a thing can be
## placed (see _fits), the nearest to two cells ahead, at the feet's level or a cell
## below or above; null if none.
func _spot_in_front(who, top: int) -> Variant:
	var feet: Vector3i = who.feet()
	var s: Vector2i = who.facing_step()
	var aim := Vector2(feet.x + 0.5 + s.x * 2.0, feet.z + 0.5 + s.y * 2.0)
	var corners: Array[Vector2i] = []
	for dz in range(-3, 3):
		for dx in range(-3, 3):
			corners.append(Vector2i(feet.x + dx, feet.z + dz))
	corners.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + Vector2.ONE).distance_squared_to(aim) < (Vector2(b) + Vector2.ONE).distance_squared_to(aim))
	for c in corners.slice(0, 6):
		for dy in [0, -1, 1]:
			var corner := Vector3i(c.x, feet.y + dy, c.y)
			if _fits(who, corner, top):
				return corner
	return null


## Whether the two by two cells from `corner` are free (no cell, no other thing, not
## `who`), at or below level `top`, and stand on solid ground.
func _fits(who, corner: Vector3i, top: int) -> bool:
	for dz in 2:
		for dx in 2:
			var c := corner + Vector3i(dx, 0, dz)
			if world.get_cell(c.x, c.y, c.z) != Mat.AIR or not world.is_solid(c.x, c.y - 1, c.z) \
					or who.overlaps_cell(c) or c.y > top:
				return false
	for e in things:
		var o: Vector3i = e.cell
		if o.y == corner.y and absi(o.x - corner.x) < 2 and absi(o.z - corner.z) < 2:
			return false
	for e in lights:
		var o: Vector3i = e.cell
		if o.y == corner.y and o.x - corner.x in [0, 1] and o.z - corner.z in [0, 1]:
			return false
	return true


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


# --- Lights set down --------------------------------------------------------------------

## True for item `id` that is set down as a light on a cell of its own: it gives light
## (`light`) and is no thing of two by two cells (`prop`).
static func is_light_item(id: String) -> bool:
	var item := Items.get_item(id)
	return item.get("light", 0.0) > 0.0 and item.get("prop", "none") == "none"


## True for a light set down (see lights).
static func is_light(e: Dictionary) -> bool:
	return e.get("light", false)


## Sets light `item` down on `cell`, burned `burnt` seconds already.
func put_light(item: String, cell: Vector3i, burnt := 0.0) -> Dictionary:
	var e := {"item": item, "cell": cell, "burnt": burnt, "light": true, "items": null, "lit": true}
	lights.append(e)
	added.emit(e)
	return e


## The light standing in `cell`, {} for none.
func light_at(cell: Vector3i) -> Dictionary:
	for e in lights:
		if e.cell == cell:
			return e
	return {}


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
func _light_fits(who, cell: Vector3i, top: int) -> bool:
	if cell.y > top or world.get_cell(cell.x, cell.y, cell.z) != Mat.AIR or not world.is_solid(cell.x, cell.y - 1, cell.z):
		return false
	if who.overlaps_cell(cell) or world.blockers.has(cell) or not light_at(cell).is_empty():
		return false
	for e in things:
		var o: Vector3i = e.cell
		if o.y == cell.y and cell.x - o.x in [0, 1] and cell.z - o.z in [0, 1]:
			return false
	return true


## `who` sets light `id` from the bag down in front (see light_spot), at or below level
## `top`: the one burning in a hand first, with what it has burned (Character.burning).
## True if it was set down.
func put_light_from_bag(who, id: String, top: int) -> bool:
	if not is_light_item(id) or who.inventory.count(id) < 1:
		return false
	var spot: Variant = light_spot(who, top)
	if spot == null:
		who.nag("put", "Некуда поставить: нужна свободная клетка на земле перед собой")
		return false
	if not who.act("place"):
		return false
	var burnt := 0.0
	if "burning" in who:
		var lit: Array = who.burning.get(id, [])
		if not lit.is_empty():
			burnt = float(lit.pop_front())
	if who.inventory.remove(id, 1) < 1:
		return false
	put_light(id, spot, burnt)
	world.note_edit(spot.x, spot.z)
	return true


## `who` takes light `e` back into the bag; what it has burned goes with it (it burns
## after the ones already lit, see Character.burning). True if it was taken.
func take_light(who, e: Dictionary) -> bool:
	if who.give(e.item, 1) < 1:
		who.nag("full", "Сумка полна")
		return false
	if "burning" in who and float(e.burnt) > 0.0:
		var lit: Array = who.burning.get(e.item, [])
		lit.append(float(e.burnt))
		who.burning[e.item] = lit
		who.state_changed.emit()
	_remove(e)
	return true


## The lights and the fires burn `delta` seconds in a rain of strength `rain` (0 for
## none, 1 a downpour; Clock.WEATHERS): a light that has burned its Items.burns is gone,
## and so is one whose cell was filled or the ground under it dug (it goes out); a fire
## goes out once its fuel has burned, or after RAIN_OUT seconds in the rain under the
## open sky in a heavy rain (see _in_rain). The session's step (only where the chunk is in memory are
## cells asked).
func step(delta: float, rain := 0.0) -> void:
	for e: Dictionary in things:
		if e.lit and e.has("fuel"):
			_burn_fire(e, delta, rain)
	for e: Dictionary in lights.duplicate():
		e.burnt += delta
		var lasts := Items.burns(e.item)
		var c: Vector3i = e.cell
		if lasts > 0.0 and e.burnt >= lasts:
			_remove(e)
		elif world.chunk_at(c.x, c.z) != null and (world.get_cell(c.x, c.y, c.z) != Mat.AIR or not world.is_solid(c.x, c.y - 1, c.z)):
			_remove(e)


func _burn_fire(e: Dictionary, delta: float, rain: float) -> void:
	if Items.get_item(e.item).fuel_max <= 0.0:
		return
	var was: float = e.fuel
	e.fuel = maxf(0.0, was - delta)
	if rain >= RAIN_HEAVY and _in_rain(e):
		e.wet += delta
	else:
		e.wet = maxf(0.0, e.wet - delta)
	if e.fuel <= 0.0 or e.wet >= RAIN_OUT:
		e.wet = 0.0
		put_out(e)
		fuel_changed.emit(e)
	elif floori(e.fuel / FUEL_TELL) != floori(was / FUEL_TELL):
		fuel_changed.emit(e)
