extends RefCounted
## Things standing on two by two cells that are not cells (an item's `prop`): chests
## with what they hold, workbenches, kilns and campfires, placed from the bag, and the
## chest and the campfire a new world starts with next to the spawn. They are solid
## (WorldData.blockers): bodies go round them or jump on them, and a burning campfire
## burns a body that touches it (see burns). A chest is taken up with what it holds; a
## campfire cannot be carried, but it can be put out, lit again for a branch, and
## destroyed without a trace. The rules take the
## one acting as `who` (see WorldActions) and tell what changed through signals: the
## client draws the things (Props) and rebuilds the chunks.

const Mat := preload("res://src/shared/content/materials.gd")
const Items := preload("res://src/shared/content/items.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Body := preload("res://src/shared/game/body.gd")

const CELL := WorldData.CELL
## Slots of a chest.
const CHEST_SLOTS := 16
## The campfire by the spawn of a new world (with a chest, the first item placed as one,
## when a loaded mod has it).
const CAMPFIRE := "core:campfire"
## How close (in cells) a body standing by a burning campfire comes to be burnt.
const SINGE := 0.02

## Thing `e` (see things) was placed, as the save had it or anew.
signal added(e: Dictionary)
## Thing `e` was taken out of the world.
signal removed(e: Dictionary)
## Campfire `e` was put out or lit again (its `lit`).
signal lit_changed(e: Dictionary)
## A cell under a thing was levelled or a bush there taken away: its chunks change.
signal cell_changed(cell: Vector3i)

var world
## Each thing placed: {"item": id, "cell": Vector3i (the north-west of its two by two
## cells), "items": what a chest holds (an Inventory, else null), "lit": false for a
## campfire put out}. Saved with the world (to_list).
var things: Array = []
## What the chest by the spawn holds (the first chest placed).
var chest_items = null
## The solid boxes of a thing of a prop kind in each of its cells (see
## WorldData.blockers): kind -> [north-west, north-east, south-west, south-east], each
## in cell units from that cell's corner, with no size where the cell stays empty. The
## shapes are the models' (on the client VoxelProps.footprint fills them in); a kind
## not given fills its four cells.
var footprints := {}


## True for a campfire (what burns, see put_out and light).
static func is_fire(e: Dictionary) -> bool:
	return Items.get_item(e.item).prop == "campfire"


## Places thing `item` (an item with a `prop`) with its north-west cell at `cell`;
## `items` is what a chest holds, as Inventory.to_dict() gave it; `lit` false puts a
## campfire there cold.
func put(item: String, cell: Vector3i, items: Variant = null, lit := true) -> Dictionary:
	var kind: String = Items.get_item(item).prop
	var e := {"item": item, "cell": cell, "items": null, "lit": lit or kind != "campfire"}
	var whole := AABB(Vector3.ZERO, Vector3.ONE)
	var boxes: Array = footprints.get(kind, [whole, whole, whole, whole])
	for i in 4:
		if boxes[i].has_volume():
			world.blockers[cell + Vector3i(i & 1, 0, i >> 1)] = boxes[i]
	if kind == "chest":
		e.items = Inventory.new(CHEST_SLOTS)
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
			put(Items.get_item(Items.canon(d.item)).id, Vector3i(int(d.cell[0]), int(d.cell[1]), int(d.cell[2])), d.get("items"),
				not d.get("out", false))


## The placed things as plain data for the save.
func to_list() -> Array:
	var out := []
	for e in things:
		var c: Vector3i = e.cell
		var d := {"item": e.item, "cell": [c.x, c.y, c.z]}
		if e.items != null:
			d.items = e.items.to_dict()
		if not e.lit:
			d.out = true
		out.append(d)
	return out


## Puts the chest and the campfire of a new world next to world point `at`; the
## chunks there are made by then, so the ground under them is known.
func start_camp(at: Vector3) -> void:
	for e in [[Items.with_prop("chest"), Vector3(2.0, 0.0, 1.0)], [CAMPFIRE, Vector3(-2.0, 0.0, 2.0)]]:
		if e[0] == "":
			continue
		var spot := spot_near(at + e[1])
		if spot.y >= 0:
			put(e[0], spot)


## The cell of the first thing placed of `item`, or null.
func cell_of(item: String) -> Variant:
	for e in things:
		if e.item == item:
			return e.cell
	return null


## The middle of placed thing `e` in world units.
static func center(e: Dictionary) -> Vector3:
	return (Vector3(e.cell) + Vector3(1.0, 0.5, 1.0)) * CELL


## The placed thing nearest world point `p` within `reach` world units, or {}.
func nearest(p: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for e in things:
		var d := center(e).distance_to(p)
		if d <= best_d:
			best_d = d
			best = e
	return best


## The stations (items with a prop other than a chest; a campfire while it burns)
## within `reach` world units of world point `p`: item id -> true.
func stations_near(p: Vector3, reach: float) -> Dictionary:
	var out := {}
	for e in things:
		if e.items == null and e.lit and center(e).distance_to(p) <= reach:
			out[e.item] = true
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


## The middle of the chest by the spawn in world units, or null when there is none.
func chest_center() -> Variant:
	for e in things:
		if e.items == chest_items and chest_items != null:
			return center(e)
	return null


## `who` places item `id` from the bag (from bag slot `slot` when given, else the first
## that holds it) on two by two free cells of level ground in front, at or below level
## `top`; a chest brings back what it held. True if it was placed.
func put_from_bag(who, id: String, slot: int, top: int) -> bool:
	var item := Items.get_item(id)
	var inv = who.inventory
	if slot < 0:
		for i in inv.slots.size():
			if slot < 0 and inv.slots[i] != null and inv.slots[i][0] == item.get("id", ""):
				slot = i
	if item.get("prop", "none") == "none" or slot < 0 or inv.slots[slot] == null or inv.slots[slot][0] != item.id:
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


## `who` takes placed thing `e` back into the bag, a chest with what it holds (its
## weight and theirs go to the bag); not a campfire (see put_out and destroy). True if
## it was taken.
func take_up(who, e: Dictionary) -> bool:
	if is_fire(e):
		who.nag("take", "Костёр не унести: его можно потушить и разобрать")
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
## `fuel`, a branch); true if it burns.
func light(who, e: Dictionary) -> bool:
	if not is_fire(e) or e.lit:
		return e.lit
	var fuel := Items.fuel_in(who.inventory)
	if fuel == "" or who.inventory.remove(fuel, 1) < 1:
		who.nag("light", "Чтобы разжечь, нужна ветка или другое топливо")
		return false
	e.lit = true
	lit_changed.emit(e)
	world.note_edit(e.cell.x, e.cell.z)
	return true


## Destroys campfire `e` that has been put out: nothing is left of it.
func destroy(e: Dictionary) -> bool:
	if not is_fire(e) or e.lit:
		return false
	_remove(e)
	return true


## Takes placed thing `e` out of the world.
func _remove(e: Dictionary) -> void:
	for dz in 2:
		for dx in 2:
			world.blockers.erase(e.cell + Vector3i(dx, 0, dz))
	if e.items == chest_items:
		chest_items = null
	things.erase(e)
	removed.emit(e)
	world.note_edit(e.cell.x, e.cell.z)


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
	return true


## The north-west cell of two by two free cells on ground at one level near the world
## point `p`, the ground under them levelled; y = -1 when there is no such spot.
func spot_near(p: Vector3) -> Vector3i:
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	var y: int = world.surface_y(x, z)
	if y <= 0:
		return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			if world.get_cell(x + dx, y, z + dz) != Mat.AIR or not world.is_solid(x + dx, y - 1, z + dz):
				return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			_level_ground(Vector3i(x + dx, y - 1, z + dz))
			_remove_bush(Vector3i(x + dx, y, z + dz))
	return Vector3i(x, y, z)


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
