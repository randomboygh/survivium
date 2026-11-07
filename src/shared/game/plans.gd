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
## The farming mode's marks (FarmMode: work to do on the ground, WORKS) are kept here
## too, told apart by their values (is_mark), and done by its action button (farm).

const Items := preload("res://src/shared/content/items.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Plants := preload("res://src/shared/content/plants.gd")
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
## How high a wall, a floor or a room (with its floor and ceiling) is drawn, in levels;
## a room is at least a floor, one level of walls and a ceiling.
const MIN_HEIGHT := 1
const MAX_HEIGHT := 6
const MIN_ROOM := 3
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
## in world units; INF: toward +x or +z); «plane» the rectangle, `height` levels from the
## level of `a` up (a floor laid on the ground, as walls are); «square» walls round the
## rectangle, `height` high and `thick` thick inward; «cube» `height` levels in all
## (MIN_ROOM at least): a floor on the level of `a`, walls on it and a ceiling over them.
## In no order.
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
					for y in height:
						out.append(Vector3i(x, a.y + y, z))
		"square":
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					if _in_ring(x, z, lo, hi, thick):
						for y in height:
							out.append(Vector3i(x, a.y + y, z))
		"cube":
			var walls := maxi(height, MIN_ROOM) - 2
			for x in range(lo.x, hi.x + 1):
				for z in range(lo.y, hi.y + 1):
					out.append(Vector3i(x, a.y, z))
					out.append(Vector3i(x, a.y + walls + 1, z))
					if _in_ring(x, z, lo, hi, thick):
						for y in walls:
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
			return w * d * h > MAX_SHAPE
		"flatten":
			return w * d > MAX_FLAT
		"square":
			return ring * h > MAX_SHAPE
		"cube":
			return 2 * w * d + ring * (maxi(h, MIN_ROOM) - 2) > MAX_SHAPE
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
		# The farming mode's marks stay.
		var box: Array = []
		for c in erase_box(kind, a, b, height, Vector2(p.x, p.z), thick):
			if cells.has(c) and not is_mark(cells[c]):
				box.append(c)
		return erase(actions, who, box)
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


## Whether cell `c` of shape `kind` drawn from `a` is a floor's lowest level: it may take
## the place of a bump of soft ground there (a plane, the bottom of a box).
static func is_floor(kind: String, a: Vector3i, c: Vector3i) -> bool:
	return kind in ["plane", "cube"] and c.y == a.y


## Takes every ghost cell off within PLAN_REACH of `who` where they may build (the
## farming mode's marks with `farm`, the blueprint's without); how many.
func clear(actions, who, farm := false) -> int:
	var near_cells: Array = []
	for c: Vector3i in cells:
		if is_mark(cells[c]) == farm and within_reach(who, c):
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


## The ghost cells within reach of `who` (the farming mode's marks with `farm`, the
## blueprint's without), the lowest first, then the nearest.
func near(who, farm := false) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if cells.is_empty():
		return out
	var p: Vector3 = who.position / CELL
	var r := Tools.PLACE_REACH
	for c: Vector3i in cells:
		if is_mark(cells[c]) != farm:
			continue
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
		if not who.act("place", "build"):
			return {"swing": actions.IDLE_SWING}
		if not free:
			who.inventory.remove(item, 1)
		if ground:
			var back: String = Mat.RECORDS[m].item
			# The ground taken out is dug, so it is given back even when building is free.
			if back != "":
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


# --- The farming mode's marks --------------------------------------------------------


## The farming mode's works (FarmMode): till a bed, sow or plant what is chosen on the
## palette, water a bed, reap a ripe crop.
const WORKS := ["till", "sow", "water", "reap"]
## The marks of the works in `cells` (a mark to sow is the item sown).
const TILL := "~till"
const WATER := "~water"
const REAP := "~reap"
const WORK_MARKS := {"till": TILL, "water": WATER, "reap": REAP}
## How far over and under the cell a stroke starts on the ground of each column is
## looked for, in levels.
const FARM_UP := 3
const FARM_DOWN := 3
## Columns one line may have at most (one square: MAX_FLAT).
const MAX_LINE := 2 * PLAN_REACH


## Whether `v` (a value of `cells`) is a mark of the farming mode, not the blueprint's.
static func is_mark(v: String) -> bool:
	return v.begins_with("~") or Tools.use_of(v) in ["plant", "sow"]


## The columns of a farming stroke from `a` to `b`: «line» along the way the stroke went
## farthest, «square» the whole rectangle; none when too many.
static func farm_columns(square: bool, a: Vector3i, b: Vector3i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var w := absi(b.x - a.x) + 1
	var d := absi(b.z - a.z) + 1
	if square:
		if w * d > MAX_FLAT:
			return out
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				out.append(Vector2i(x, z))
		return out
	if maxi(w, d) > MAX_LINE:
		return out
	if w >= d:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			out.append(Vector2i(x, a.z))
	else:
		for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
			out.append(Vector2i(a.x, z))
	return out


## The top ground cell of column `col` near level `y` (FARM_UP over, FARM_DOWN under):
## something solid with air over it; null for none.
static func surface(w, col: Vector2i, y: int) -> Variant:
	for at in range(mini(y + FARM_UP, w.size_y - 2), maxi(y - FARM_DOWN, 0) - 1, -1):
		if not w.in_bounds(col.x, at, col.y):
			return null
		var m: int = w.get_cell(col.x, at, col.y)
		if m != Mat.AIR and m != Mat.WATER and w.get_cell(col.x, at + 1, col.y) == Mat.AIR:
			return Vector3i(col.x, at, col.y)
	return null


## The mark work `work` leaves (WORK_MARKS; a mark to sow is `item`).
static func mark_of(work: String, item: String) -> String:
	return item if work == "sow" else WORK_MARKS.get(work, "")


## Whether work `work` (sowing `item`) could be done some day on ground cell `c`, by the
## rules over the world `actions`: «till» ground a hoe tills, «sow» where `item` grows
## (a crop's seeds on a bed or on ground tilled first), «water» a bed, «reap» a bed with
## a crop.
static func mark_fits(actions, work: String, item: String, c: Vector3i) -> bool:
	match work:
		"till":
			return actions.can_till(c)
		"sow":
			return actions.plantable(item, c)
		"water":
			var m: int = actions.world.get_cell(c.x, c.y, c.z)
			return Mat.is_bed(m)
		"reap":
			var m: int = actions.world.get_cell(c.x, c.y, c.z)
			return Mat.is_bed(m) and actions.crop_on(c) != ""
	return false


## The cells of a farming stroke from `a` to `b` (farm_columns), the ground of each
## column, sorted: {"fit": those the mark of `work` (sowing `item`) goes on, "blocked":
## those it cannot (nothing there to do, a block's ghost, where `who` may not build)}.
## The client shows the same before the stroke ends.
func farm_sort(actions, who, work: String, item: String, square: bool, a: Vector3i, b: Vector3i) -> Dictionary:
	var out := {"fit": [], "blocked": []}
	for col in farm_columns(square, a, b):
		var c: Variant = surface(actions.world, col, a.y)
		if c == null:
			out.blocked.append(Vector3i(col.x, a.y, col.y))
			continue
		var ok: bool = not (cells.has(c) and not is_mark(cells[c])) and mark_fits(actions, work, item, c) \
			and actions.territory_allows(who, c, "build")
		if ok:
			out.fit.append(c)
		else:
			out.blocked.append(c)
	return out


## Draws the marks of farming work `work` (one of WORKS; sowing what `who` holds) on the
## ground of a stroke from `a` to `b` (a «line», or a «square» filled), or takes the
## marks off its columns (`erase_it`); a mark takes the place of another one. How many
## cells changed.
func mark(actions, who, work: String, a: Vector3i, b: Vector3i, square: bool, erase_it := false) -> int:
	if not within_reach(who, a) or not within_reach(who, b):
		return 0
	var cols := farm_columns(square, a, b)
	if cols.is_empty():
		who.nag("plan_big", "Слишком большая разметка")
		return 0
	if erase_it:
		var gone: Array = []
		for col in cols:
			for y in range(a.y - FARM_DOWN, a.y + FARM_UP + 1):
				var c := Vector3i(col.x, y, col.y)
				if cells.has(c) and is_mark(cells[c]):
					gone.append(c)
		return erase(actions, who, gone)
	var item: String = who.held() if work == "sow" else ""
	if work == "sow" and not is_mark(item):
		who.nag("no_seed", "Выберите, что сажать")
		return 0
	var value := mark_of(work, item)
	if value == "":
		return 0
	var added: Array = []
	for c: Vector3i in farm_sort(actions, who, work, item, square, a, b).fit:
		if cells.get(c, "") == value:
			continue
		if not cells.has(c) and cells.size() + added.size() >= MAX_CELLS:
			who.nag("plan_full", "Слишком много разметки")
			break
		added.append(c)
	for c: Vector3i in added:
		cells[c] = value
		forms.erase(c)
	if not added.is_empty():
		changed.emit(added, value)
	elif work == "reap":
		who.nag("plan_none", "Здесь нечего собирать")
	return added.size()


## The farming mode's action button: does the work of one mark within reach of `who`
## (near: the lowest, the nearest), with the tool of the bag that does it best (a hoe,
## a can with water, a sickle or bare hands, the seeds of the mark), on as many marked
## cells round it as the tool works in a swing; the marks done go. Marks that can no
## longer be done go too; those that wait (green crops, no tool, winter) stay. The swing
## of the work, {"swing", "idle"} when nothing could be done (said why).
func farm(actions, who) -> Dictionary:
	var wait := ""
	var marks := near(who, true)
	var mine := {}
	for c in marks:
		mine[c] = true
	for c in marks:
		if not cells.has(c):
			continue
		var done: Variant = _farm_cell(actions, who, c, cells[c], mine)
		if done is Dictionary:
			return done
		if done is String and wait == "":
			wait = done
	if wait != "":
		who.nag("farm_wait", wait)
	elif marks.is_empty():
		who.nag("farm_none", "Рядом нет разметки: нарисуйте её на земле")
	return {"swing": actions.IDLE_SWING, "idle": true}


## The work of mark `v` on cell `c` (see farm), `mine` the marks within reach: the
## work done (a Dictionary: {"swing"} when the hands are busy), why it waits (a String,
## the mark kept), or null (the mark gone or passed by).
func _farm_cell(actions, who, c: Vector3i, v: String, mine: Dictionary) -> Variant:
	var w = actions.world
	if not actions.territory_allows(who, c, "build"):
		return null
	var m: int = w.get_cell(c.x, c.y, c.z)
	var bed := Mat.is_bed(m)
	match v:
		TILL:
			if bed or not actions.can_till(c):
				_drop([c])
				return null
			return _till(actions, who, c, v, mine)
		WATER:
			if not bed:
				_drop([c])
				return null
			var can := _best(who, func(t: Dictionary) -> bool: return Tools.can_water(t))
			if can == "":
				return "Нет лейки с водой: наберите воды"
			var cs := _around(c, v, Tools.of(can), mine, func(x: Vector3i) -> bool: return actions.can_water(x))
			return _done(actions, actions.water(who, cs, can), cs)
		REAP:
			if not bed or actions.crop_on(c) == "":
				_drop([c])
				return null
			if not actions.ripe_at(c):
				return "Ещё не созрело"
			var crop: Dictionary = Plants.BY_ID.get(actions.crop_on(c), {})
			var tool := _best(who, func(t: Dictionary) -> bool: return t.tool != "hand" and Tools.can_reap(t, crop))
			var t := Tools.of(tool)
			var cs := _around(c, v, t, mine, func(x: Vector3i) -> bool: return actions.can_reap(x, t))
			return _done(actions, actions.reap(who, cs, tool), cs)
	# A mark to sow: the item sown.
	if not actions.plantable(v, c):
		_drop([c])
		return null
	if who.inventory.count(v) == 0:
		return "В сумке нет: %s" % Items.title(v)
	if Plants.is_crop(Items.get_item(v).get("crop", "")):
		if actions.clock.season == actions.WINTER:
			return "Зимой не сеют: дождитесь весны"
		if not bed:
			return _till(actions, who, c, v, mine)
	if not actions._can_plant(who, v, c):
		return null
	if not actions.plant_at(who, v, c):
		return {"swing": actions.IDLE_SWING}
	_drop([c])
	return actions.work(actions.FRONT_PLACE_SWING, "reach", (Vector3(c) + Vector3(0.5, 1.0, 0.5)) * CELL)


## Tills the marked cells round `c` (marks `v`, within reach: `mine`) with the best hoe
## of the bag; a mark to till goes when done, a mark to sow stays to be sown.
func _till(actions, who, c: Vector3i, v: String, mine: Dictionary) -> Variant:
	var hoe := _best(who, func(t: Dictionary) -> bool: return Tools.can_till(t))
	if hoe == "":
		return "Нет тяпки: вскопать грядку"
	var cs := _around(c, v, Tools.of(hoe), mine, func(x: Vector3i) -> bool: return actions.can_till(x))
	var done: Dictionary = actions.till(who, cs, hoe)
	if done.is_empty():
		return {"swing": actions.IDLE_SWING}
	if v == TILL:
		_drop(cs)
	return done


## The work `done` on cells `cs` (their marks go), {"swing"} when nothing was done (the
## hands busy).
func _done(actions, done: Dictionary, cs: Array[Vector3i]) -> Dictionary:
	if done.is_empty():
		return {"swing": actions.IDLE_SWING}
	_drop(cs)
	return done


## Cell `c` and the cells round it (Tools.area_cells) marked `v` within reach (`mine`)
## that pass `fits`, as many as tool `t` works in a swing (its `area`).
func _around(c: Vector3i, v: String, t: Dictionary, mine: Dictionary, fits: Callable) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x in Tools.area_cells(c, Vector3i.UP):
		if out.size() >= maxi(1, t.get("area", 1)):
			break
		if mine.has(x) and cells.get(x, "") == v and fits.call(x):
			out.append(x)
	return out


## The tool of the bag of `who` that passes `fits` and works the most cells a swing
## (its `area`), "" for none.
static func _best(who, fits: Callable) -> String:
	var best := ""
	var area := -1
	for s in who.inventory.slots:
		if s == null or not Tools.is_tool_item(s[0]):
			continue
		var t := Tools.of(s[0])
		if fits.call(t) and int(t.get("area", 1)) > area:
			best = s[0]
			area = int(t.get("area", 1))
	return best


## Takes the marks off `of`.
func _drop(of: Array) -> void:
	var gone: Array = []
	for c: Vector3i in of:
		if cells.has(c):
			cells.erase(c)
			forms.erase(c)
			gone.append(c)
	if not gone.is_empty():
		changed.emit(gone, "")


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
			var item: String = Items.canon(e[1]) if e[1] != CUT and not e[1] in WORK_MARKS else e[1]
			if item == CUT or is_mark(item) or Mat.index(Items.get_item(item).get("place", "")) >= 0:
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
