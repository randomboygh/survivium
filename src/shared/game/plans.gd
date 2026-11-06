extends RefCounted
## The blueprint (decision 163, build mode): cells marked to be built, each with the
## block (an item that places a material) that goes there. In the build mode a player
## draws a shape (KINDS: «линия» a wall, «плоскость» a floor in place of the top ground
## cell, «квадрат» walls round a rectangle, «куб» a box with a floor, walls and a
## ceiling; walls 1–4 levels high and 1–4 cells thick) with the block chosen on the
## palette, or takes the ghost off a box drawn the same way. The ghost stays in the
## world; the action button of someone with a block in hand and a ghost cell within
## reach builds the ghost cell by cell (build), taking the blocks from the bag as it
## goes, and waits when they run out, so anyone allowed to build there finishes it. The
## server's are the session's (`plans`, saved with the world); the client keeps a copy
## fed by Protocol.PLANS and PLAN_CELLS (take, take_all) for the view and the build mode.

const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Cells one shape may have at most, and the ghost cells in the world at most.
const MAX_SHAPE := 1000
const MAX_CELLS := 4000
## How far (cells, across the ground and up or down) from the one drawing a shape's
## corners may lie: about the screen the shape is drawn on, so nobody draws ghosts far
## off where they cannot see.
const PLAN_REACH := 64
## How high a wall or a room is drawn, in levels.
const MIN_HEIGHT := 1
const MAX_HEIGHT := 4
## How thick a wall (and how deep a floor) is drawn, in cells.
const MIN_THICK := 1
const MAX_THICK := 4
## The time a ghost cell takes to build, in seconds.
const BUILD_SWING := 0.3

## Ghost cells were added (`item` the block of each) or taken off (`item` "").
signal changed(cells: Array, item: String)

## The ghost cells: Vector3i → the item id of the block that goes there.
var cells := {}
## The form of the block that goes in a ghost cell when it is not a cube (a slope,
## stairs: WorldData.forms), by cell.
var forms := {}


## The kinds of shape (the build mode's panel): a wall along a line, a floor in a
## plane, walls round a square, a box with walls, a floor and a ceiling.
const KINDS := ["line", "plane", "square", "cube", "flatten"]
## The ghost of a cell to dig out (flattening): in `cells` in place of a block's item.
const CUT := "-"
## How far over and under the level a flattening reaches, in levels, and how many
## columns it may take at most.
const FLAT_UP := 8
const FLAT_DOWN := 4
const MAX_FLAT := 400


## The cells of shape `kind` (one of KINDS) from cell `a` to cell `b` (the level of
## `a`): «line» a wall along the way the stroke went farthest, `height` levels high and
## `thick` cells thick (the rows past the first on the side away from `near`, a column
## in world units; INF: toward +x or +z); «plane» the rectangle, `thick` levels deep
## from the level of `a` down (a floor takes the place of the top ground cell); «square»
## walls round the rectangle, `height` high and `thick` thick inward; «cube» a floor on
## the level of `a`, walls on it `height` high and a ceiling over them. In no order.
static func shape(kind: String, a: Vector3i, b: Vector3i, height: int, near := Vector2.INF, thick := 1) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	# Counted before it is made: corners far apart would make millions of cells.
	if too_big(kind, a, b, height, thick):
		return out
	height = clampi(height, MIN_HEIGHT, MAX_HEIGHT)
	thick = clampi(thick, MIN_THICK, MAX_THICK)
	var lo := Vector2i(mini(a.x, b.x), mini(a.z, b.z))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.z, b.z))
	match kind:
		"flatten":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					out.append(Vector3i(x, a.y, z))
		"line":
			var d := b - a
			var along_x := absi(d.x) >= absi(d.z)
			var end := Vector3i(b.x, a.y, a.z) if along_x else Vector3i(a.x, a.y, b.z)
			# The rows of a thick wall go away from the one drawing.
			var side := 1
			if near.is_finite():
				var c := near / CELL
				side = 1 if (c.y if along_x else c.x) < (a.z if along_x else a.x) + 0.5 else -1
			for x in range(mini(a.x, end.x), maxi(a.x, end.x) + 1):
				for z in range(mini(a.z, end.z), maxi(a.z, end.z) + 1):
					for t in thick:
						var o := Vector3i(0, 0, t * side) if along_x else Vector3i(t * side, 0, 0)
						for y in height:
							out.append(Vector3i(x, a.y + y, z) + o)
		"plane":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					for t in thick:
						out.append(Vector3i(x, a.y - t, z))
		"square":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					if _in_ring(x, z, lo, hi, thick):
						for y in height:
							out.append(Vector3i(x, a.y + y, z))
		"cube":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					out.append(Vector3i(x, a.y, z))
					out.append(Vector3i(x, a.y + height + 1, z))
					if _in_ring(x, z, lo, hi, thick):
						for y in height:
							out.append(Vector3i(x, a.y + 1 + y, z))
	return out


## Whether column x, z lies in the walls `thick` cells thick round the rectangle lo..hi.
static func _in_ring(x: int, z: int, lo: Vector2i, hi: Vector2i, thick: int) -> bool:
	return x - lo.x < thick or hi.x - x < thick or z - lo.y < thick or hi.y - z < thick


## The cells a stroke from `a` to `b` takes the ghost off: every cell of the box round
## shape `kind` (see shape), whatever ghost lies there.
static func erase_box(kind: String, a: Vector3i, b: Vector3i, height: int, near := Vector2.INF, thick := 1) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var cells := shape(kind, a, b, height, near, thick)
	if cells.is_empty():
		return out
	var lo: Vector3i = cells[0]
	var hi: Vector3i = cells[0]
	for c in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	if kind == "flatten":
		lo.y -= FLAT_DOWN - 1
		hi.y += FLAT_UP
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.z, hi.z + 1):
			for y in range(lo.y, hi.y + 1):
				out.append(Vector3i(x, y, z))
	return out


## Whether shape `kind` from `a` to `b`, `height` levels high and `thick` cells thick,
## would have more than MAX_SHAPE cells (counted from its corners, not made), or is of
## no known kind.
static func too_big(kind: String, a: Vector3i, b: Vector3i, height: int, thick := 1) -> bool:
	var w := absi(b.x - a.x) + 1
	var d := absi(b.z - a.z) + 1
	if w > MAX_SHAPE or d > MAX_SHAPE:
		return true
	var h := clampi(height, MIN_HEIGHT, MAX_HEIGHT)
	var t := clampi(thick, MIN_THICK, MAX_THICK)
	var ring := w * d - maxi(0, w - 2 * t) * maxi(0, d - 2 * t)
	match kind:
		"line":
			return maxi(w, d) * h * t > MAX_SHAPE
		"plane":
			return w * d * t > MAX_SHAPE
		"flatten":
			return w * d > MAX_FLAT
		"square":
			return ring * h > MAX_SHAPE
		"cube":
			return 2 * w * d + ring * h > MAX_SHAPE
	return true


## Whether cell `c` is near enough to `who` for a shape's corner (PLAN_REACH).
static func within_reach(who, c: Vector3i) -> bool:
	var p: Vector3 = who.position / CELL
	return Vector2(c.x + 0.5 - p.x, c.z + 0.5 - p.z).length() <= PLAN_REACH and absf(c.y - p.y) <= PLAN_REACH


## Draws shape `kind` from `a` to `b` (see shape) with the block `who` holds, or takes
## the ghost off the box round it (`erase`, see erase_box); only where `who` may build
## and a block could go (fits: in the world, not this block already, open air or water,
## a floor's ground), by the rules over the world `actions` (WorldActions, which holds
## the plans: passed, not kept, so the two make no cycle). Returns how many cells changed.
func draw(actions, who, kind: String, a: Vector3i, b: Vector3i, height: int, thick := 1, erase_it := false,
		form := 0) -> int:
	var item: String = who.held()
	if too_big(kind, a, b, height, thick):
		who.nag("plan_big", "Слишком большой чертёж")
		return 0
	if not within_reach(who, a) or not within_reach(who, b):
		return 0
	var p: Vector3 = who.position
	if erase_it:
		return erase(actions, who, erase_box(kind, a, b, height, Vector2(p.x, p.z), thick))
	if kind == "flatten":
		return _flatten(actions, who, a, b)
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0:
		who.nag("plan_block", "Выберите блок для чертежа")
		return 0
	var sorted := sort(actions, who, kind, a, shape(kind, a, b, height, Vector2(p.x, p.z), thick), block)
	var added: Array = []
	for c: Vector3i in sorted.fit:
		if cells.size() + added.size() >= MAX_CELLS:
			who.nag("plan_full", "Слишком много чертежей")
			break
		added.append(c)
	form &= 15
	for c: Vector3i in added:
		cells[c] = item
		if form & 3 != 0:
			forms[c] = form
		else:
			forms.erase(c)
	if not added.is_empty():
		changed.emit(added, item)
	return added.size()


## Flattening (the build mode's «выровнять») the rectangle from `a` to `b` to the top of
## the level of `a`: the natural ground over it (FLAT_UP levels) becomes ghost cells to
## dig out (CUT), the holes in it down to solid ground (FLAT_DOWN levels) ghost cells of
## soil (the item dirt gives) to fill, where `who` may build. Trees are left standing,
## and so is what players built. How many cells changed.
func _flatten(actions, who, a: Vector3i, b: Vector3i) -> int:
	if actions == null:
		return 0
	var w = actions.world
	var soil: String = Mat.RECORDS[Mat.DIRT].item
	var cut: Array = []
	var fill: Array = []
	for c: Vector3i in shape("flatten", a, b, 1):
		for y in range(c.y + 1, mini(c.y + 1 + FLAT_UP, w.size_y)):
			var up := Vector3i(c.x, y, c.z)
			var m: int = w.get_cell(up.x, up.y, up.z)
			if m == Mat.AIR or m == Mat.WATER or m == Mat.LEAVES or not w.is_natural(up.x, up.y, up.z) \
					or actions.tree_of(up) != null or cells.has(up):
				continue
			if actions.territory_allows(who, up, "build"):
				cut.append(up)
		for y in range(c.y, maxi(c.y - FLAT_DOWN, 0), -1):
			var down := Vector3i(c.x, y, c.z)
			var m: int = w.get_cell(down.x, down.y, down.z)
			if m != Mat.AIR and m != Mat.WATER:
				break
			if not cells.has(down) and actions.territory_allows(who, down, "build"):
				fill.append(down)
	var room := MAX_CELLS - cells.size()
	if cut.size() + fill.size() > room:
		who.nag("plan_full", "Слишком много чертежей")
		cut = cut.slice(0, room)
		fill = fill.slice(0, maxi(0, room - cut.size()))
	for c: Vector3i in cut:
		cells[c] = CUT
		forms.erase(c)
	for c: Vector3i in fill:
		cells[c] = soil
		forms.erase(c)
	if not cut.is_empty():
		changed.emit(cut, CUT)
	if not fill.is_empty():
		changed.emit(fill, soil)
	if cut.is_empty() and fill.is_empty():
		who.nag("plan_flat", "Здесь уже ровно")
	return cut.size() + fill.size()


## The tool in the bag of `who` that digs material `m` fastest (its item, "" for bare
## hands), or null when nothing there digs it.
static func best_tool(who, m: int) -> Variant:
	var best: Variant = null
	var time := INF
	if Tools.can_dig(Tools.of(""), m):
		best = ""
		time = Tools.swing_time(Tools.of(""), m)
	for s in who.inventory.slots:
		if s == null or not Tools.is_tool_item(s[0]):
			continue
		var t := Tools.of(s[0])
		if Tools.can_dig(t, m) and Tools.swing_time(t, m) < time:
			best = s[0]
			time = Tools.swing_time(t, m)
	return best


## The cells `all` of shape `kind` drawn from `a` with `block` (see shape), sorted:
## {"fit": those the ghost goes on, "blocked": those it cannot (inside other blocks, a
## floor buried under ground, where `who` may not build), "hanging": those of «fit»
## with nothing under them yet (uneven ground: a wall over a dip)}. Ghost cells there
## already are in none. The client shows the same before the stroke ends.
func sort(actions, who, kind: String, a: Vector3i, all: Array[Vector3i], block: int) -> Dictionary:
	var out := {"fit": [], "blocked": [], "hanging": []}
	var mine := {}
	# The lowest cell of the shape in each column: only those can hang (a ceiling rests
	# on the walls).
	var lowest := {}
	for c in all:
		mine[c] = true
		var col := Vector2i(c.x, c.z)
		lowest[col] = mini(lowest.get(col, c.y), c.y)
	for c in all:
		if cells.has(c):
			continue
		var ok := fits(actions, c, block, is_floor(kind, a, c))
		if ok and actions != null:
			var w = actions.world
			var up := c + Vector3i.UP
			# A floor takes the place of the top ground cell, not of one buried under more.
			if is_floor(kind, a, c) and _soft(w.get_cell(c.x, c.y, c.z)) and w.is_solid(up.x, up.y, up.z) \
					and not mine.has(up):
				ok = false
			elif not actions.territory_allows(who, c, "build"):
				ok = false
		if not ok:
			out.blocked.append(c)
			continue
		out.fit.append(c)
		var down := c + Vector3i.DOWN
		if actions != null and lowest[Vector2i(c.x, c.z)] == c.y and not cells.has(down) \
				and not actions.world.is_solid(down.x, down.y, down.z):
			out.hanging.append(c)
	return out


## Whether cell `c` of shape `kind` drawn from `a` is a floor's: it takes the place of
## the ground there (a plane, the bottom of a box).
static func is_floor(kind: String, a: Vector3i, c: Vector3i) -> bool:
	return kind == "plane" or kind == "cube" and c.y == a.y


## Takes every ghost cell off within PLAN_REACH of `who` where they may build; how many.
func clear(actions, who) -> int:
	var near_cells: Array = []
	for c: Vector3i in cells:
		if within_reach(who, c):
			near_cells.append(c)
	return erase(actions, who, near_cells)


## Takes the ghost off `of` (the cells that are ghost cells) where `who` may build.
func erase(actions, who, of: Array) -> int:
	var gone: Array = []
	for c: Vector3i in of:
		if cells.has(c) and (actions == null or actions.territory_allows(who, c, "build")):
			cells.erase(c)
			forms.erase(c)
			gone.append(c)
	if not gone.is_empty():
		changed.emit(gone, "")
	return gone.size()


## Whether `block` could go in cell `c` some day: in the world, not that block already, and
## open (air, water), or a floor's ground (a cell the hands or a shovel dig).
func fits(actions, c: Vector3i, block: int, floor: bool) -> bool:
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
## nearest) whose block is in the bag (the one in hand first), at any level (not only
## below the level cut: inside a house the cut lies under its ceiling), where
## it stands on something (or is a floor's ground), clear of bodies and things, by the
## rules over the world `actions` (see draw). The swing of the work, {"swing"} alone
## when nothing could be built.
func build(actions, who) -> Dictionary:
	var w = actions.world
	var free: bool = actions.rules.free_build
	var held: String = who.held()
	var missing := ""
	var ready: Array[Vector3i] = []
	for c in near(who):
		var item: String = cells[c]
		if item == CUT:
			ready.append(c)
			continue
		if not free and who.inventory.count(item) == 0:
			missing = item if missing == "" else missing
			continue
		ready.append(c)
	# What is to be dug out first, from the top; then the block in hand first.
	ready.sort_custom(func(x: Vector3i, y: Vector3i) -> bool:
		if (cells[x] == CUT) != (cells[y] == CUT):
			return cells[x] == CUT
		if cells[x] == CUT:
			return x.y > y.y
		return cells[x] == held and cells[y] != held)
	for c in ready:
		var item: String = cells[c]
		if item == CUT:
			var dug := _dig_out(actions, who, c)
			if dug.is_empty():
				continue
			return dug
		var block := Mat.index(Items.get_item(item).get("place", ""))
		var m: int = w.get_cell(c.x, c.y, c.z)
		var form: int = forms.get(c, 0)
		if block < 0 or m == block:
			cells.erase(c)
			forms.erase(c)
			changed.emit([c], "")
			continue
		var ground := _soft(m)
		if not ground and m != Mat.AIR and m != Mat.WATER:
			continue
		if not ground and not actions.can_place(who, c, w.size_y):
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
		var fresh: bool = actions.build_cell(c, block, form)
		cells.erase(c)
		forms.erase(c)
		changed.emit([c], "")
		var done: Dictionary = actions.work(actions.skilled(who, "build", BUILD_SWING, 1.0 if fresh else 0.0), "reach",
			(Vector3(c) + Vector3(0.5, 0.5, 0.5)) * CELL, block)
		done.placed = 1
		return done
	if missing != "":
		who.nag("no_block", "В сумке нет: %s" % Items.title(missing))
	else:
		who.nag("plan_wait", "Чертёж: сначала то, на чём стоять")
	return {"swing": actions.IDLE_SWING}


## Digs ghost cell `c` to be dug out (CUT) with the tool of the bag of `who` that digs
## it fastest; the work done, {} when it could not be dug (no tool for it, not allowed),
## {"swing"} when the hands are busy.
func _dig_out(actions, who, c: Vector3i) -> Dictionary:
	var w = actions.world
	var m: int = w.get_cell(c.x, c.y, c.z)
	if m == Mat.AIR or m == Mat.WATER or actions.tree_of(c) != null:
		cells.erase(c)
		changed.emit([c], "")
		return {}
	var tool: Variant = best_tool(who, m)
	if tool == null:
		who.nag("tool", Tools.why_not(Tools.of(who.held()), m))
		return {}
	if not actions.territory_allows(who, c, "build"):
		return {}
	var swing := Tools.swing_time(Tools.of(tool), m)
	var done: Dictionary = actions.dig(who, [c] as Array[Vector3i], swing, tool)
	if done.is_empty():
		return {"swing": actions.IDLE_SWING}
	cells.erase(c)
	changed.emit([c], "")
	return done


## The ghost cells for the save and for a client joining: [[cell, item], …], with the
## form third where it is not a cube.
func to_list() -> Array:
	var out: Array = []
	for c: Vector3i in cells:
		out.append([c, cells[c], forms[c]] if forms.has(c) else [c, cells[c]])
	return out


## The forms of ghost cells `list` (0 a cube), for the client's copy (take).
func forms_of(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append(forms.get(c, 0))
	return out


## The ghost cells of a save (to_list); those of blocks no longer known are left out.
func from_list(list: Array) -> void:
	cells.clear()
	forms.clear()
	for e in list:
		if e is Array and e.size() in [2, 3] and e[0] is Vector3i and e[1] is String:
			var item: String = Items.canon(e[1]) if e[1] != CUT else CUT
			if item == CUT or Mat.index(Items.get_item(item).get("place", "")) >= 0:
				cells[e[0]] = item
				if e.size() == 3 and e[2] is int and e[2] & 3 != 0:
					forms[e[0]] = e[2] & 15
	changed.emit([], "")


## The client's copy: ghost cells came (`item`, of `of`: their forms in the same order,
## forms_of) or went ("").
func take(list: Array, item: String, of := []) -> void:
	var got: Array = []
	for k in list.size():
		var c: Variant = list[k]
		if c is Vector3i:
			forms.erase(c)
			if item == "":
				cells.erase(c)
			else:
				cells[c] = item
				var f: Variant = of[k] if k < of.size() else 0
				if f is int and f & 3 != 0:
					forms[c] = f & 15
			got.append(c)
	changed.emit(got, item)


## The client's copy: every ghost cell there is, on joining (to_list).
func take_all(list: Array) -> void:
	from_list(list)
