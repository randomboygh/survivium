extends "res://src/shared/game/actions_dig.gd"
## The rules of the hands, part six (world_actions.gd): placing blocks and planting
## seeds and bushes.

## Seconds between two placings of a stroke, and of the action button (slower, so a
## bridge grows a cell at a time while walking).

const PLACE_SWING := 0.1
const FRONT_PLACE_SWING := 0.25


## Places the block in the hand in use of `who` with its brush around `center`, across
## face `normal`: each cell that is free, within reach, no higher than level `top` and
## next to something solid. The swing tells how many were placed (`placed`).
func place_at(who, center: Vector3i, normal: Vector3i, top: int) -> Dictionary:
	var item: String = who.held()
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0:
		return {}
	var free: bool = rules.free_build
	var placed := 0
	var fresh := 0
	var far := false
	for cell in Tools.brush_shape(center, normal, who.brush()):
		if not can_place(who, cell, top):
			far = far or too_far(who, cell, Tools.PLACE_REACH)
			continue
		if not _may(who, cell, "build"):
			continue
		if not free and who.inventory.count(item) == 0:
			who.nag("no_block", Lang.line("В сумке нет: %s", [Items.title(item)]))
			break
		if not who.act("place", "build"):
			break
		if not free:
			who.inventory.remove(item, 1)
		if build_cell(cell, block):
			fresh += 1
		placed += 1
	if placed > 0:
		var done := _work(skilled(who, "build", PLACE_SWING, float(fresh) / placed), "reach",
			(Vector3(center) + Vector3(0.5, 0.5, 0.5)) * CELL, block)
		done.placed = placed
		return done
	if far:
		who.nag("far", "Слишком далеко")
	return {}


## Whether `who` can place a block in `cell`: in the world, no higher than level `top`,
## within reach, air or water clear of the body and of placed things, next to something
## solid.
func can_place(who, cell: Vector3i, top: int) -> bool:
	if not world.in_bounds(cell.x, cell.y, cell.z) or cell.y > top or too_far(who, cell, Tools.PLACE_REACH):
		return false
	var cur: int = world.get_cell(cell.x, cell.y, cell.z)
	if cur != Mat.AIR and cur != Mat.WATER or who.overlaps_cell(cell) or world.blocker_top(cell.x, cell.y, cell.z) > 0.0 \
			or world.ladders.has(cell):
		return false
	for d in [Vector3i.DOWN, Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var n: Vector3i = cell + d
		if world.is_solid(n.x, n.y, n.z):
			return true
	return false


# --- The action button ------------------------------------------------------------------


## Plants item `id` from the bag of `who` in front of it: a bush (an item with `plant`)
## on grass, seeds (with `sow`) on the bare ground they grow on; true if it was planted.
func plant(who, id: String) -> bool:
	var spot: Variant = plant_spot(who, id)
	if spot == null:
		var item := Items.get_item(id)
		who.nag("plant", "Сажать можно на ровную траву рядом" if item.get("plant", "") != "" \
			else "Сеять можно на голую землю рядом")
		return false
	return plant_at(who, id, spot)


## The ground cell round `who` where item `id` would be planted (see plant_at), in the
## order of Tools.sector, or null.
func plant_spot(who, id: String) -> Variant:
	var feet: Vector3i = who.feet()
	for o in Tools.sector(who.facing_step()):
		for dy in [-1, 0, -2]:
			var cell: Vector3i = feet + Vector3i(o.x, dy, o.y)
			if _can_plant(who, id, cell):
				return cell
	return null


## Plants item `id` from the bag of `who` on ground cell `cell` (the cell a bush stands
## on, or the ground that seeds turn into their `sow`); true if it was planted.
func plant_at(who, id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if item.is_empty() or who.inventory.count(item.id) == 0:
		who.nag("no_seed", Lang.line("В сумке нет: %s", [Items.title(id)]))
		return false
	if not _can_plant(who, id, cell):
		who.nag("plant", "Сюда не посадить")
		return false
	if not _may(who, cell, "build"):
		return false
	if not who.act("gather", "farm"):
		return false
	who.inventory.remove(item.id, 1)
	if item.plant != "":
		var at := cell + Vector3i.UP
		Growth.place_bush(world, at.x, at.y, at.z, Bushes.index(item.plant))
		world.note_bush(at)
		looks_changed.emit(WorldData.chunk_key(at.x, at.z))
	else:
		world.set_material(cell.x, cell.y, cell.z, Mat.index(item.sow))
		world.set_turf(cell, item.crop)
		_changed(cell)
	return true


## Whether item `id` can be planted on ground cell `cell` within reach of `who`: a bush
## on level grass with air above, seeds on the ground their `sow` grows from (what that
## material is cut down to) open to the air.
func _can_plant(who, id: String, cell: Vector3i) -> bool:
	var item := Items.get_item(id)
	if item.is_empty() or too_far(who, cell, Tools.PLACE_REACH):
		return false
	var at := cell + Vector3i.UP
	if item.plant != "":
		return Bushes.index(item.plant) >= 0 and Growth.bush_fits(world, at.x, at.y, at.z) and not world.bushes.has(at) \
			and not who.overlaps_cell(at)
	if item.sow == "":
		return false
	var grows := Mat.index(item.sow)
	return grows >= 0 and Tools.mown(grows) == world.get_cell(cell.x, cell.y, cell.z) \
		and world.get_cell(at.x, at.y, at.z) == Mat.AIR and not world.bushes.has(at)


# --- The year -----------------------------------------------------------------------------
