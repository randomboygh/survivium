extends RefCounted
## The blueprint (decision 163, 5А/6А): cells marked to be built, each with the block
## (an item that places a material) that goes there. A player draws a shape with the
## blueprint brushes of the hand that places (Tools.BRUSHES with `plan`): «стена», a line
## 1–4 levels high; «пол», a rectangle that takes the place of the top ground cell, flush
## with it; «комната», walls round a rectangle with a gap for a 1×2 door in the side
## nearest the one drawing. The ghost stays in the world; the action button of someone
## with a block in hand and a ghost cell within reach builds the ghost cell by cell
## (build), taking the blocks from the bag as it goes, and waits when they run out, so
## anyone allowed to build there finishes it. Drawn again from a ghost cell, a shape
## takes the ghost off. The server's are the session's (`plans`, saved with the world);
## the client keeps a copy fed by Protocol.PLANS and PLAN (take, take_all) for the view
## and the action button's label.

const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Cells one shape may have at most, and the ghost cells in the world at most.
const MAX_SHAPE := 400
const MAX_CELLS := 4000
## How high a wall or a room is drawn, in levels.
const MIN_HEIGHT := 1
const MAX_HEIGHT := 4
## The time a ghost cell takes to build, in seconds.
const BUILD_SWING := 0.3

## Ghost cells were added (`item` the block of each) or taken off (`item` "").
signal changed(cells: Array, item: String)

## The ghost cells: Vector3i → the item id of the block that goes there.
var cells := {}


## The cells of shape `kind` ("wall", "floor", "room") from cell `a` to cell `b` (the
## level of `a`), `height` levels high (a wall, a room); a room leaves a door's gap in
## the side nearest `near` (a column, world units; INF for none). In no order.
static func shape(kind: String, a: Vector3i, b: Vector3i, height: int, near := Vector2.INF) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	height = clampi(height, MIN_HEIGHT, MAX_HEIGHT)
	var lo := Vector2i(mini(a.x, b.x), mini(a.z, b.z))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.z, b.z))
	match kind:
		"wall":
			# Along the way the stroke went farthest, from `a`.
			var d := b - a
			var end := Vector3i(b.x, a.y, a.z) if absi(d.x) >= absi(d.z) else Vector3i(a.x, a.y, b.z)
			var lo3 := Vector3i(mini(a.x, end.x), a.y, mini(a.z, end.z))
			var hi3 := Vector3i(maxi(a.x, end.x), a.y, maxi(a.z, end.z))
			for x in range(lo3.x, hi3.x + 1):
				for z in range(lo3.z, hi3.z + 1):
					for y in height:
						out.append(Vector3i(x, a.y + y, z))
		"floor":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					out.append(Vector3i(x, a.y, z))
		"room":
			var gap := _door_gap(lo, hi, near)
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					if x != lo.x and x != hi.x and z != lo.y and z != hi.y:
						continue
					for y in height:
						if Vector2i(x, z) == gap and y < 2:
							continue
						out.append(Vector3i(x, a.y + y, z))
	return out


## The column of a room's door gap: the middle of its side nearest `near` (world units),
## of the sides long enough to keep both corners; (lo - 1) for no gap.
static func _door_gap(lo: Vector2i, hi: Vector2i, near: Vector2) -> Vector2i:
	var none := lo - Vector2i.ONE
	if not near.is_finite():
		return none
	var c := near / CELL
	var mx := (lo.x + hi.x) / 2
	var mz := (lo.y + hi.y) / 2
	var sides: Array[Vector2i] = []
	if hi.x - lo.x >= 2:
		sides.append_array([Vector2i(mx, lo.y), Vector2i(mx, hi.y)])
	if hi.y - lo.y >= 2:
		sides.append_array([Vector2i(lo.x, mz), Vector2i(hi.x, mz)])
	var best := none
	var best_d := INF
	for g in sides:
		var d := (Vector2(g) + Vector2(0.5, 0.5)).distance_to(c)
		if d < best_d:
			best_d = d
			best = g
	return best


## Draws shape `kind` from `a` to `b` with the block `who` holds (see shape), or takes
## the ghost off those cells when `a` is a ghost cell already; only where `who` may build
## and a block could go (in the world, not this block already; a floor over ground or
## open air), by the rules over the world `actions` (WorldActions, which holds the
## plans: passed, not kept, so the two make no cycle). Returns how many cells changed.
func draw(actions, who, kind: String, a: Vector3i, b: Vector3i, height: int) -> int:
	var item: String = who.held()
	if cells.has(a):
		return erase(actions, who, shape(kind, a, b, height))
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0:
		who.nag("plan_block", "Возьми в руку блок для чертежа")
		return 0
	var p: Vector3 = who.position
	var all := shape(kind, a, b, height, Vector2(p.x, p.z))
	if all.size() > MAX_SHAPE:
		who.nag("plan_big", "Слишком большой чертёж")
		return 0
	var added: Array = []
	for c in all:
		if cells.size() + added.size() >= MAX_CELLS:
			who.nag("plan_full", "Слишком много чертежей")
			break
		if cells.has(c) or not _fits(actions, c, block, kind == "floor"):
			continue
		if actions != null and not actions.territory_allows(who, c, "build"):
			continue
		added.append(c)
	for c: Vector3i in added:
		cells[c] = item
	if not added.is_empty():
		changed.emit(added, item)
	return added.size()


## Takes the ghost off `of` (the cells that are ghost cells) where `who` may build.
func erase(actions, who, of: Array) -> int:
	var gone: Array = []
	for c: Vector3i in of:
		if cells.has(c) and (actions == null or actions.territory_allows(who, c, "build")):
			cells.erase(c)
			gone.append(c)
	if not gone.is_empty():
		changed.emit(gone, "")
	return gone.size()


## Whether `block` could go in cell `c` some day: in the world, not that block already, and
## open (air, water), or a floor's ground (a cell the hands or a shovel dig).
func _fits(actions, c: Vector3i, block: int, floor: bool) -> bool:
	if actions == null:
		return true
	var w = actions.world
	if not w.in_bounds(c.x, c.y, c.z) or c.y < 1:
		return false
	var m: int = w.get_cell(c.x, c.y, c.z)
	if m == block:
		return false
	return m == Mat.AIR or m == Mat.WATER or floor and _soft(m)


## Ground a floor takes the place of: dug by the hands or a shovel.
static func _soft(m: int) -> bool:
	return m != Mat.AIR and m != Mat.WATER and Mat.RECORDS[m].dig in ["hand", "shovel"]


## The ghost cells within reach of `who`, the lowest first, then the nearest.
func near(who) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if cells.is_empty():
		return out
	var p: Vector3 = who.position / CELL
	var r := Tools.PLACE_REACH
	for c: Vector3i in cells:
		if absf(c.x + 0.5 - p.x) <= r and absf(c.z + 0.5 - p.z) <= r and absf(c.y - p.y) <= r:
			if (Vector3(c) + Vector3(0.5, 0.5, 0.5)).distance_to(p + Vector3(0.0, 0.5 / CELL, 0.0)) <= r:
				out.append(c)
	out.sort_custom(func(x: Vector3i, y: Vector3i) -> bool:
		if x.y != y.y:
			return x.y < y.y
		return Vector3(x).distance_squared_to(p) < Vector3(y).distance_squared_to(p))
	return out


## Whether the action button of `who` builds now: a block in hand and a ghost cell within
## reach.
func builds(who) -> bool:
	return Tools.use_of(who.held()) == "place" and not near(who).is_empty()


## The action button builds one ghost cell within reach of `who` (near: the lowest, the
## nearest) whose block is in the bag (the one in hand first), below level `top`, where
## it stands on something (or is a floor's ground), clear of bodies and things, by the
## rules over the world `actions` (see draw). The swing of the work, {"swing"} alone
## when nothing could be built.
func build(actions, who, top: int) -> Dictionary:
	var w = actions.world
	var free: bool = actions.rules.free_build
	var held: String = who.held()
	var missing := ""
	var ready: Array[Vector3i] = []
	for c in near(who):
		if c.y > top:
			continue
		var item: String = cells[c]
		if not free and who.inventory.count(item) == 0:
			missing = item if missing == "" else missing
			continue
		ready.append(c)
	# The block in hand first.
	ready.sort_custom(func(x: Vector3i, y: Vector3i) -> bool:
		return cells[x] == held and cells[y] != held)
	for c in ready:
		var item: String = cells[c]
		var block := Mat.index(Items.get_item(item).get("place", ""))
		var m: int = w.get_cell(c.x, c.y, c.z)
		if block < 0 or m == block:
			cells.erase(c)
			changed.emit([c], "")
			continue
		var ground := _soft(m)
		if not ground and m != Mat.AIR and m != Mat.WATER:
			continue
		if not ground and not actions.can_place(who, c, top):
			continue
		if not actions.territory_allows(who, c, "build"):
			continue
		if not who.act("place"):
			return {"swing": actions.IDLE_SWING}
		if not free:
			who.inventory.remove(item, 1)
		if ground:
			var back: String = Mat.RECORDS[m].item
			if back != "" and not free:
				who.inventory.add(back, 1)
		actions.put_block(c, block)
		cells.erase(c)
		changed.emit([c], "")
		var done: Dictionary = actions.work(BUILD_SWING, "reach", (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * CELL, block)
		done.placed = 1
		return done
	if missing != "":
		who.nag("no_block", "В сумке нет: %s" % Items.title(missing))
	else:
		who.nag("plan_wait", "Чертёж: сначала то, на чём стоять")
	return {"swing": actions.IDLE_SWING}


## The ghost cells for the save and for a client joining: [[cell, item], …].
func to_list() -> Array:
	var out: Array = []
	for c: Vector3i in cells:
		out.append([c, cells[c]])
	return out


## The ghost cells of a save (to_list); those of blocks no longer known are left out.
func from_list(list: Array) -> void:
	cells.clear()
	for e in list:
		if e is Array and e.size() == 2 and e[0] is Vector3i and e[1] is String:
			var item: String = Items.canon(e[1])
			if Mat.index(Items.get_item(item).get("place", "")) >= 0:
				cells[e[0]] = item
	changed.emit([], "")


## The client's copy: ghost cells came (`item`) or went ("").
func take(list: Array, item: String) -> void:
	var got: Array = []
	for c in list:
		if c is Vector3i:
			if item == "":
				cells.erase(c)
			else:
				cells[c] = item
			got.append(c)
	changed.emit(got, item)


## The client's copy: every ghost cell there is, on joining (to_list).
func take_all(list: Array) -> void:
	from_list(list)
