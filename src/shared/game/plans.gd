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
const Lang := preload("res://src/shared/content/lang.gd")
const Placed := preload("res://src/shared/game/placed.gd")

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
## Ghost things in the world at most, and how far from its north-west cell one's cells
## lie at most (one of a save or of the server's copy is read no further).
const MAX_THINGS := 200
const THING_REACH := 4

## Ghost cells were added (`item` the block of each) or taken off (`item` ""); none and ""
## when the whole blueprint was read anew (from_list).
signal changed(cells: Array, item: String)
## Ghost thing `t` (things) was set down (`came`) or taken off.
signal thing_changed(t: Dictionary, came: bool)

## The ghost cells: Vector3i → the item id of the block that goes there.
var cells := {}
## The form of the block that goes in a ghost cell when it is not a cube (a slope,
## stairs: WorldData.forms), by cell.
var forms := {}
## The ghost things (the user's picks, 2026-11-26, 1А, 2А): doors, windows, furniture set
## down in the blueprint to be built after its blocks (build), seen as their models,
## see-through and blue (PlanThings). Each {"item", "cell" (its north-west cell), "turn",
## "cells" (every cell it fills, as high as it stands: Placed.volume_of), "wall" (an
## opening's: the ghost blocks it took the place of, offset from "cell" -> the block's
## item; they come back when it goes, as a door's place is walled up again)}.
var things: Array = []
## The ghost things by each cell they fill.
var _thing_cells := {}
## The ghost cell each builder built last (by the instance id of `who`): the next one built is
## the nearest to it, so a blueprint fills one cell after another along its rows (the user's
## ask, 2026-11-26), not jumping about as the builder moves.
var _last_built := {}
## The four cells beside one on its level.
const ROW_SIDES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## The kinds of shape (the build mode's panel): a wall along a line, a floor in a
## plane, walls round a square, a box with walls, a floor and a ceiling.
const KINDS := ["line", "plane", "square", "cube", "flatten"]
## The shapes drawn as a flight of slopes or stairs when a form is chosen (flight); the
## others are drawn of cubes whatever the form.
const FLIGHTS := ["line", "plane", "square"]
## In the form of a stroke (draw, flight), beside WorldData's form in bits 0..3: the
## flight is a band one block thick along its slope, not filled down to the ground.
const BAND := 32
## The ghost of a cell to dig out (flattening): in `cells` in place of a block's item.
const CUT := "-"
## How far over and under the level a flattening reaches, in levels, and how many
## columns it may take at most.
const FLAT_UP := 8
const FLAT_DOWN := 4
const MAX_FLAT := 400


## Whether item `id` is drawn as a blueprint in the build mode: a block (a `place`
## tool), or a fence, built segment by segment like a wall.
static func drawn_with(id: String) -> bool:
	return id != "" and (Tools.use_of(id) == "place" or is_fence(id))


## Whether item `id` is a fence (`fence`, not a wicket or a gate, which are doors).
static func is_fence(id: String) -> bool:
	var item := Items.get_item(id)
	return item.get("fence", false) and not item.get("door", false)


## The cells of shape `kind` (one of KINDS) from cell `a` to cell `b` (the level of
## `a`): «line» a wall along the way the stroke went farthest, `height` levels high and
## `thick` cells thick (the rows past the first on the side away from `near`, a column
## in world units; INF: toward +x or +z); «plane» the rectangle, `height` levels from the
## level of `a` up (a floor laid on the ground, as walls are); «square» walls round the
## rectangle, `height` high and `thick` thick inward; «cube» `height` levels in all
## (MIN_ROOM at least): a floor on the level of `a`, walls on it and a ceiling over them.
## In no order.
## With slopes or stairs (`form`, see flight) a line or a square is a flight of them.
static func shape(kind: String, a: Vector3i, b: Vector3i, height: int, near := Vector2.INF, thick := 1,
		form := 0) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	# Counted before it is made: corners far apart would make millions of cells.
	if too_big(kind, a, b, height, thick):
		return out
	if form & 3 != 0 and kind in FLIGHTS:
		out.assign(flight(kind, a, b, height, near, thick, form).keys())
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


## The cells of a flight of slopes or stairs (`form`, WorldData.forms: its kind in bits
## 0..1, the side a lone column rises to in bits 2..3, BAND) drawn as shape `kind` (a
## line, a plane or a square, FLIGHTS) from `a` to `b`, by cell → its form (0 a cube). It
## climbs from the first corner, one level high, to the last, `height` levels high: a line
## and a plane along the way the stroke went (a plane all across its width), a square
## along both its sides to the far corner (each row of a thick wall the same). A column is
## filled with cubes under its top, which is a slope or a step rising toward `b` where the
## column is higher than the one before it. An upturned slope mirrors that from the top:
## every column reaches `height` levels, the first hangs one level high at the top, the
## last goes down to the ground, and the lowest cell of each column that reaches lower
## than the one before it is the upturned slope. With BAND a column holds only the cells
## from its top down to the level of the one before it, and the lowest of them, where the
## column rises, is the slope turned the other way (an upturned one under a slope, a
## slope over an upturned one) or, under stairs, a notch (WorldData.FORM_NOTCH), so the
## underside steps as the top does: a band one block thick that hangs by its shape.
static func flight(kind: String, a: Vector3i, b: Vector3i, height: int, near := Vector2.INF, thick := 1,
		form := 0) -> Dictionary:
	var out := {}
	if kind not in FLIGHTS or form & 3 == 0 or too_big(kind, a, b, height, thick):
		return out
	height = clampi(height, MIN_HEIGHT, MAX_HEIGHT)
	thick = clampi(thick, MIN_THICK, MAX_THICK)
	var f := form & 3
	var band := form & BAND != 0
	var d := b - a
	var along_x := absi(d.x) >= absi(d.z)
	var lo := Vector2i(mini(a.x, b.x), mini(a.z, b.z))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.z, b.z))
	var straight := kind != "square"
	# How many steps along the way from the first corner to the last.
	var span := (absi(d.x) if along_x else absi(d.z)) if straight else absi(d.x) + absi(d.z)
	for c in shape(kind, a, b, 1, near, thick):
		var t := absi(c.x - a.x) + absi(c.z - a.z)
		var by_x := along_x
		if straight:
			t = absi(c.x - a.x) if along_x else absi(c.z - a.z)
		elif d.x == 0 or d.z == 0:
			by_x = d.x != 0
		else:
			# Along the side it lies on; a corner along the side the way comes into it by.
			var row := c.z - lo.y < thick or hi.y - c.z < thick
			var col := c.x - lo.x < thick or hi.x - c.x < thick
			by_x = row and not (col and absi(c.x - a.x) < thick and absi(c.z - a.z) >= thick)
		var side := form >> 2 & 3
		if span > 0:
			side = (1 if d.x > 0 else 3) if by_x else (2 if d.z > 0 else 0)
		var h := _rise(t, span, height)
		var before := _rise(t - 1, span, height) if t > 0 else h
		var formed := t == 0 or h > before
		# The cell that takes the form: the top, or the bottom of an upturned flight.
		var edge := Vector3i(c.x, a.y + height - h, c.z) if f == WorldData.FORM_UPPER else Vector3i(c.x, a.y + h - 1, c.z)
		var up := 1 if f == WorldData.FORM_UPPER else -1
		var cells := h - before + 1 if band else h
		for y in cells:
			out[edge + Vector3i(0, y * up, 0)] = 0
		if formed:
			out[edge] = f | side << 2
			if band and cells > 1:
				var low := edge + Vector3i(0, (cells - 1) * up, 0)
				if f == WorldData.FORM_STAIRS:
					# Under stairs a notch, so the underside steps as the top does.
					out[low] = WorldData.FORM_NOTCH | side << 2
				else:
					var under := WorldData.FORM_RAMP if f == WorldData.FORM_UPPER else WorldData.FORM_UPPER
					out[low] = under | ((side + 2) % 4) << 2
	return out


## Whether a flight of form `form` (see flight) hangs by its shape, so its cells over a
## void are not told as hanging (sort): an upturned one, or a band.
static func hangs_by_shape(form: int) -> bool:
	return form & 3 == WorldData.FORM_UPPER or form & BAND != 0


## How many levels high the column `t` steps along a flight `span` steps long is: one at
## the first, `height` at the last, evenly between.
static func _rise(t: int, span: int, height: int) -> int:
	if span <= 0:
		return height
	return 1 + ((height - 1) * 2 * t + span) / (2 * span)


## Whether column x, z lies in the walls `thick` cells thick round the rectangle lo..hi.
static func _in_ring(x: int, z: int, lo: Vector2i, hi: Vector2i, thick: int) -> bool:
	return x - lo.x < thick or hi.x - x < thick or z - lo.y < thick or hi.y - z < thick


## The cells a stroke from `a` to `b` takes the ghost off: every cell of the box round
## shape `kind` (see shape), whatever ghost lies there.
## With `level` (a figure drawn with its earthwork) it reaches as far as that would:
## FLAT_DOWN levels under the figure's bottom.
static func erase_box(kind: String, a: Vector3i, b: Vector3i, height: int, near := Vector2.INF, thick := 1,
		level := false) -> Array[Vector3i]:
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
	elif level:
		lo.y -= FLAT_DOWN
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
## the plans: passed, not kept, so the two make no cycle). With `replace_it` the blocks
## in the box are marked to be rebuilt of the block held instead (replace). Returns how
## many cells changed.
func draw(actions, who, kind: String, a: Vector3i, b: Vector3i, height: int, thick := 1, erase_it := false,
		form := 0, level := false, replace_it := false) -> int:
	var item: String = who.held()
	if too_big(kind, a, b, height, thick):
		who.nag("plan_big", "[the_blueprint_is_too_big]")
		return 0
	if not within_reach(who, a) or not within_reach(who, b):
		return 0
	if replace_it and not erase_it:
		return replace(actions, who, kind, a, b, height, thick)
	var p: Vector3 = who.position
	if erase_it:
		# The farming mode's marks stay; the ghost things in the box go with the blocks.
		var box: Array = []
		var things_gone := 0
		var near := Vector2(p.x, p.z)
		# With `level` the box reaches under the figure as far as its earthwork, but there
		# takes only the ghost of the earth (soil): a floor drawn below stays.
		var figure := erase_box(kind, a, b, height, near, thick)
		var ys := Vector2i(figure[0].y, figure[-1].y) if not figure.is_empty() else Vector2i.ZERO
		for c in erase_box(kind, a, b, height, near, thick, level):
			var over := c.y < ys.x or c.y > ys.y
			if cells.has(c) and not is_mark(cells[c]) and (not over or is_earth(cells[c])):
				box.append(c)
			if over:
				continue
			var t := thing_at(c)
			if not t.is_empty() and (actions == null or actions.territory_allows(who, t.cell, "build")):
				drop_thing(t)
				things_gone += 1
		return erase(actions, who, box) + things_gone
	if kind == "flatten":
		return _flatten(actions, who, a, b)
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0 and is_fence(item):
		# A fence is one segment high and thick, along a line or round a square.
		if kind not in ["line", "square"]:
			who.nag("plan_fence", "[a_fence_is_drawn_as]")
			return 0
		height = 1
		thick = 1
		form = 0
	elif block < 0:
		who.nag("plan_block", "[choose_a_block_for_the]")
		return 0
	form &= 15 | BAND
	if form & 3 == 0 or kind not in FLIGHTS:
		form = 0
	var steps := flight(kind, a, b, height, Vector2(p.x, p.z), thick, form)
	var all := shape(kind, a, b, height, Vector2(p.x, p.z), thick, form)
	# A fence is set on the ground as it lies; a figure of blocks levels it with `level`.
	var work := earthwork(actions, who, kind, a, b, all, form) if level and block >= 0 else {}
	var sorted := sort(actions, who, kind, a, all, block, hangs_by_shape(form), work)
	var added: Array = []
	var full := false
	for c: Vector3i in sorted.fit:
		if cells.size() + added.size() >= MAX_CELLS:
			full = true
			break
		added.append(c)
	# The earth is dug out and filled in only under a figure that goes on.
	var cut: Array = []
	var fill: Array = []
	if not added.is_empty():
		for c: Vector3i in work.get("cut", []):
			if cells.size() + added.size() + cut.size() >= MAX_CELLS:
				full = true
				break
			cut.append(c)
		for c: Vector3i in work.get("fill", []):
			if cells.size() + added.size() + cut.size() + fill.size() >= MAX_CELLS:
				full = true
				break
			fill.append(c)
	if full:
		who.nag("plan_full", "[too_many_blueprints]")
	for c: Vector3i in added:
		cells[c] = item
		if steps.get(c, 0) != 0:
			forms[c] = steps[c]
		else:
			forms.erase(c)
	var soil := soil_item()
	for c: Vector3i in cut:
		cells[c] = CUT
		forms.erase(c)
	for c: Vector3i in fill:
		cells[c] = soil
		forms.erase(c)
	if not added.is_empty():
		changed.emit(added, item)
	if not cut.is_empty():
		changed.emit(cut, CUT)
	if not fill.is_empty():
		changed.emit(fill, soil)
	return added.size() + cut.size() + fill.size()


## Replacing the material (the build mode's «заменить», the user's idea 6 and picks,
## 2026-11-26): in the box round shape `kind` from `a` to `b` (erase_box) every block
## players built of another material than the block `who` holds becomes a ghost cell of
## that block, keeping its form (a slope stays a slope, turned as it was), and the ghost
## blocks there of another material are repainted with it (their forms kept too); natural
## ground, trees, the earth to dig or fill and the farming marks stay. Built by the action
## button as any ghost (build), from the bottom: once the new block is in the bag the old
## one is knocked out with the bag's best tool for it (into the bag, as dug) and the new
## one put in its place in the same work, so no hole is left.
## Only where `who` may build. How many cells changed.
func replace(actions, who, kind: String, a: Vector3i, b: Vector3i, height: int, thick := 1) -> int:
	var item: String = who.held()
	var block := Mat.index(Items.get_item(item).get("place", ""))
	if block < 0:
		who.nag("plan_block", "[choose_a_block_for_the]")
		return 0
	var p: Vector3 = who.position
	var added: Array = []
	var fresh := 0
	var full := false
	for c in erase_box(kind, a, b, height, Vector2(p.x, p.z), thick):
		var was: String = cells.get(c, "")
		if was == item or is_mark(was) or is_earth(was) or was != "" and not Items.get_item(was).has("place"):
			continue
		if was == "" and not replaceable(actions, c, block):
			continue
		if actions != null and not actions.territory_allows(who, c, "build"):
			continue
		if was == "":
			if cells.size() + fresh >= MAX_CELLS:
				full = true
				break
			fresh += 1
		added.append(c)
	if full:
		who.nag("plan_full", "[too_many_blueprints]")
	for c: Vector3i in added:
		if not cells.has(c) and actions != null:
			var f: int = actions.world.form_at(c.x, c.y, c.z)
			if f != 0:
				forms[c] = f
			else:
				forms.erase(c)
		cells[c] = item
	if not added.is_empty():
		changed.emit(added, item)
	return added.size()


## Whether the block in cell `c` may be replaced by `block` (replace): one players built
## (not natural ground, not a tree's), of another material, with no thing in its cell.
func replaceable(actions, c: Vector3i, block: int) -> bool:
	if actions == null or _thing_cells.has(c):
		return false
	var w = actions.world
	if not w.in_bounds(c.x, c.y, c.z) or c.y < 1:
		return false
	var m: int = w.get_cell(c.x, c.y, c.z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != block and not w.is_natural(c.x, c.y, c.z) \
			and not w.blockers.has(c) and not w.ladders.has(c) and actions.tree_of(c) == null


## Whether ghost block `item` at cell `c` stands where a block players built of another
## material is to be dug out first (replace); soft ground (a built heap of earth) is not:
## the new block takes its place at once, as a floor's (build).
func _replaced(actions, c: Vector3i, item: String) -> bool:
	var block := Mat.index(Items.get_item(item).get("place", ""))
	return block >= 0 and replaceable(actions, c, block) \
			and not _soft(actions.world.get_cell(c.x, c.y, c.z))


## The item of the soil a dip is filled with (flattening, earthwork): what dirt gives.
static func soil_item() -> String:
	return Mat.RECORDS[Mat.DIRT].item


## Whether ghost item `v` is the earth's: a cell to dig out or soil to fill a dip with.
static func is_earth(v: String) -> bool:
	return v == CUT or v == soil_item()


## The earthwork under figure `kind` drawn from `a` to `b` (its cells `all`, of `form`: see
## shape, flight) on uneven ground, as «выровнять» would do at the figure's level (the
## user's item 11 and picks, 2026-11-26): under its footprint (a line's columns, the whole
## rectangle of a plane, a square, a box) the natural ground from its lowest level up to
## its top (2Б: the ground over the top stays) is dug out, and the dips under it filled with soil down to solid ground
## when it is at most FLAT_DOWN levels down (a deeper one is left and the figure hangs
## there). A flight of slopes or stairs only has its dips filled, under each column's lowest
## cell: a flight up a hill stays on the hill. A figure laid on a structure (_on_structure: a
## ceiling over walls) fills nothing, the room under it stays. Trees, what players built and ghost cells
## stay; only where `who` may build. {"cut": cells to dig out (not the figure's), "dig":
## the figure's cells in natural ground → true (its blocks go there once it is dug),
## "fill": cells of soil, "under": the same → true}; {} with no world, or a footprint over
## MAX_FLAT columns.
func earthwork(actions, who, kind: String, a: Vector3i, b: Vector3i, all: Array[Vector3i], form := 0) -> Dictionary:
	if actions == null or all.is_empty():
		return {}
	var w = actions.world
	var flight_of := form & 3 != 0 and kind in FLIGHTS
	var mine := {}
	# Each column's level: the lowest cell of the figure there; the ground is cut as high as
	# the figure's top (the user's pick 2Б: what is over it stays).
	var cols := {}
	var top: int = all[0].y
	for c in all:
		mine[c] = true
		top = maxi(top, c.y)
		var col := Vector2i(c.x, c.z)
		cols[col] = mini(cols.get(col, c.y), c.y)
	if not flight_of and kind in ["plane", "square", "cube"]:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
				cols[Vector2i(x, z)] = a.y
	if cols.size() > MAX_FLAT:
		return {}
	# A figure laid on what players built (a ceiling over walls, a floor of an upper storey,
	# a roof) fills no dips: the room under it stays open (the user's report of 2026-11-26).
	var held := _on_structure(actions, cols)
	var out := {"cut": [], "dig": {}, "fill": [], "under": {}}
	for col: Vector2i in cols:
		var base: int = cols[col]
		if not flight_of:
			for y in range(base, mini(top + 1, w.size_y)):
				var up := Vector3i(col.x, y, col.y)
				if not _natural_ground(actions, up) or cells.has(up) \
						or not actions.territory_allows(who, up, "build"):
					continue
				if mine.has(up):
					out.dig[up] = true
				else:
					out.cut.append(up)
		if held:
			continue
		var hole: Array = []
		var floor := false
		for i in FLAT_DOWN + 1:
			var down := Vector3i(col.x, base - 1 - i, col.y)
			if down.y < 0:
				break
			var m: int = w.get_cell(down.x, down.y, down.z)
			if m != Mat.AIR and m != Mat.WATER or cells.has(down):
				floor = true
				break
			if i == FLAT_DOWN:
				break
			hole.append(down)
		# A dip deeper than FLAT_DOWN is left: the figure hangs over it.
		if not floor or hole.is_empty():
			continue
		for c: Vector3i in hole:
			if not actions.territory_allows(who, c, "build"):
				break
			out.fill.append(c)
			out.under[c] = true
	return out


## Whether a figure over columns `cols` (column → its lowest level) rests on a structure:
## under one of them is a block players built or the ghost of one (_built) that does not
## stand on the ground (_ground), as a wall, a pillar or a beam does. A paved path or a
## floor laid on the ground is none.
func _on_structure(actions, cols: Dictionary) -> bool:
	for col: Vector2i in cols:
		var base: int = cols[col]
		if base >= 2 and _built(actions, Vector3i(col.x, base - 1, col.y)) \
				and not _ground(actions, Vector3i(col.x, base - 2, col.y)):
			return true
	return false


## Whether cell `c` holds a block players built, not of loose ground (dirt, sand: a dip
## filled is ground), or the ghost of one (not the earth's: CUT, soil).
func _built(actions, c: Vector3i) -> bool:
	if cells.has(c):
		return not is_earth(cells[c])
	var w = actions.world
	var m: int = w.get_cell(c.x, c.y, c.z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and not Mat.can_slope(m) \
			and not w.is_natural(c.x, c.y, c.z) and actions.tree_of(c) == null


## Whether cell `c` is ground: natural ground, loose ground players put (a dip filled), or
## the ghost of the soil filling a dip.
func _ground(actions, c: Vector3i) -> bool:
	if cells.get(c, "") == soil_item():
		return true
	var m: int = actions.world.get_cell(c.x, c.y, c.z)
	return m != Mat.AIR and m != Mat.WATER and Mat.can_slope(m) or _natural_ground(actions, c)


## Whether cell `c` is natural ground a flattening digs out: not air, water or leaves, not
## built by players, not a tree's.
static func _natural_ground(actions, c: Vector3i) -> bool:
	var w = actions.world
	var m: int = w.get_cell(c.x, c.y, c.z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and w.is_natural(c.x, c.y, c.z) \
			and actions.tree_of(c) == null


## Flattening (the build mode's «выровнять») the rectangle from `a` to `b` to the top of
## the level of `a`: the natural ground over it (FLAT_UP levels) becomes ghost cells to
## dig out (CUT), the holes in it down to solid ground (FLAT_DOWN levels) ghost cells of
## soil (the item dirt gives) to fill, where `who` may build. Trees are left standing,
## and so is what players built. How many cells changed.
func _flatten(actions, who, a: Vector3i, b: Vector3i) -> int:
	if actions == null:
		return 0
	var w = actions.world
	var soil := soil_item()
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
		who.nag("plan_full", "[too_many_blueprints]")
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
		who.nag("plan_flat", "[its_already_level_here]")
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
## with nothing under them yet (uneven ground: a wall over a dip; none with `hangs`, an
## upturned flight, which hangs by its shape, nor a figure resting on a structure: a ceiling
## over walls, whose middle is held by them, _on_structure)}. Ghost cells there already are in none.
## With the figure's earthwork `work` (see earthwork) its cells in natural ground fit (dug
## first) and those over soil to fill do not hang. The client shows the same before the
## stroke ends.
func sort(actions, who, kind: String, a: Vector3i, all: Array[Vector3i], block: int, hangs := false,
		work := {}) -> Dictionary:
	var dig: Dictionary = work.get("dig", {})
	var under: Dictionary = work.get("under", {})
	var out := {"fit": [], "blocked": [], "hanging": []}
	var mine := {}
	# The lowest cell of the shape in each column: only those can hang (a ceiling rests
	# on the walls).
	var lowest := {}
	for c in all:
		mine[c] = true
		var col := Vector2i(c.x, c.z)
		lowest[col] = mini(lowest.get(col, c.y), c.y)
	# A figure laid on what players built hangs nowhere: a ceiling over walls is held by
	# them (the user's report of 2026-11-27: the room under it was told as uneven ground).
	if actions != null and not hangs and _on_structure(actions, lowest):
		hangs = true
	for c in all:
		if cells.has(c):
			continue
		if dig.has(c):
			out.fit.append(c)
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
		if actions != null and not hangs and lowest[Vector2i(c.x, c.z)] == c.y and not cells.has(down) \
				and not under.has(down) and not actions.world.is_solid(down.x, down.y, down.z):
			out.hanging.append(c)
	return out


## Whether cell `c` of shape `kind` drawn from `a` is a floor's lowest level: it may take
## the place of a bump of soft ground there (a plane, the bottom of a box).
static func is_floor(kind: String, a: Vector3i, c: Vector3i) -> bool:
	return kind in ["plane", "cube"] and c.y == a.y


## Takes every ghost cell off within PLAN_REACH of `who` where they may build (the
## farming mode's marks with `farm`, the blueprint's and its ghost things without); how many.
func clear(actions, who, farm := false) -> int:
	var near_cells: Array = []
	for c: Vector3i in cells:
		if is_mark(cells[c]) == farm and within_reach(who, c):
			near_cells.append(c)
	var gone := erase(actions, who, near_cells)
	if not farm:
		for t: Dictionary in things.duplicate():
			if within_reach(who, t.cell) and (actions == null or actions.territory_allows(who, t.cell, "build")):
				drop_thing(t)
				gone += 1
	return gone


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


## The blueprint's ghost cells of the column at `c` joined to it up and down (no gap
## between), `c` first; none when `c` is no ghost of a block (a mark, nothing).
func column_of(c: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if not cells.has(c) or is_mark(cells[c]):
		return out
	out.append(c)
	for dir: Vector3i in [Vector3i.UP, Vector3i.DOWN]:
		var at: Vector3i = c + dir
		while cells.has(at) and not is_mark(cells[at]) and out.size() < 2 * PLAN_REACH:
			out.append(at)
			at += dir
	return out


## Whether the ghost column at `c` (column_of) holds a slope or stairs: a double tap on it
## in the build mode turns them (turn_form).
func formed_at(c: Vector3i) -> bool:
	for at in column_of(c):
		if forms.has(at):
			return true
	return false


## Turns the slopes and stairs of the ghost column at `c` (column_of) a quarter clockwise
## seen from above, each formed cell of it alike, so a band's underside turns with its top
## (the build mode's double tap on a ghost; the user's pick, 2026-11-26: the turn button is
## gone, a lone column rises away from the player and a double tap turns it), within reach
## of `who` (PLAN_REACH) and where they may build. How many cells turned.
func turn_form(actions, who, c: Vector3i) -> int:
	if not within_reach(who, c):
		return 0
	var turned := {}
	for at in column_of(c):
		if not forms.has(at) or actions != null and not actions.territory_allows(who, at, "build"):
			continue
		var f: int = forms[at]
		forms[at] = (f & ~12) | (((f >> 2 & 3) + 1) % 4) << 2
		if not turned.has(cells[at]):
			turned[cells[at]] = []
		turned[cells[at]].append(at)
	var count := 0
	for item: String in turned:
		count += turned[item].size()
		changed.emit(turned[item], item)
	return count


## Whether `block` could go in cell `c` some day: in the world, not that block already, and
## open (air, water), or a floor's ground (a cell the hands or a shovel dig); not where a
## ghost thing stands (a wall drawn through a ghost door goes round it).
func fits(actions, c: Vector3i, block: int, floor: bool) -> bool:
	if _thing_cells.has(c):
		return false
	if actions == null:
		return true
	var w = actions.world
	if not w.in_bounds(c.x, c.y, c.z) or c.y < 1:
		return false
	var m: int = w.get_cell(c.x, c.y, c.z)
	if m == block or w.blockers.has(c) or w.ladders.has(c):
		return false
	if block < 0:
		# A fence: in the air on the ground.
		return m == Mat.AIR
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
	return drawn_with(who.held()) and not near(who).is_empty()


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
	# The cells to dig out: those to cut, and the figure's cells in natural ground a block
	# cannot take the place of at once (see earthwork; soft ground it can, as a floor's).
	var to_dig := {}
	var swap := {}
	var missing_tool := -1
	for c in near(who):
		var item: String = cells[c]
		if item == CUT:
			to_dig[c] = true
			ready.append(c)
			continue
		if _buried(actions, c, item):
			to_dig[c] = true
			ready.append(c)
			continue
		if not free and who.inventory.count(item) == 0:
			missing = item if missing == "" else missing
			continue
		if _replaced(actions, c, item):
			# A block to replace is swapped for the new one in one work, in the order the
			# ghost is built (from the bottom), only with the new one in the bag.
			swap[c] = true
		ready.append(c)
	# What is to be dug out first, from the top; then the block in hand first, the lowest
	# level first; on a level one cell after another (the user's ask, 2026-11-26): the end
	# of a row first (the fewest ghost cells beside it on its level, so a row is not split
	# in two), the one nearest the cell built last, else nearest the builder.
	var last: Variant = _last_built.get(who.get_instance_id())
	var p: Vector3 = who.position / CELL
	var from: Vector3 = Vector3(last) if last is Vector3i and Vector3(last).distance_to(p) <= Tools.PLACE_REACH else p
	var beside := {}
	for c in ready:
		var n := 0
		for d: Vector3i in ROW_SIDES:
			var v: String = cells.get(c + d, CUT)
			if v != CUT and not is_mark(v):
				n += 1
		beside[c] = n
	ready.sort_custom(func(x: Vector3i, y: Vector3i) -> bool:
		if to_dig.has(x) != to_dig.has(y):
			return to_dig.has(x)
		if to_dig.has(x):
			return x.y > y.y
		if (cells[x] == held) != (cells[y] == held):
			return cells[x] == held
		if x.y != y.y:
			return x.y < y.y
		if beside[x] != beside[y]:
			return beside[x] < beside[y]
		var dx := Vector3(x).distance_squared_to(from)
		var dy := Vector3(y).distance_squared_to(from)
		if dx != dy:
			return dx < dy
		return x < y)
	for c in ready:
		var item: String = cells[c]
		if to_dig.has(c):
			var dug := _dig_out(actions, who, c, item != CUT)
			if dug.is_empty():
				continue
			return dug
		var block := Mat.index(Items.get_item(item).get("place", ""))
		var m: int = w.get_cell(c.x, c.y, c.z)
		var form: int = forms.get(c, 0)
		if block < 0 and is_fence(item):
			var fenced := _put_fence(actions, who, c, item, free)
			if fenced.is_empty():
				continue
			return fenced
		if block < 0 or m == block:
			cells.erase(c)
			forms.erase(c)
			changed.emit([c], "")
			continue
		var ground := _soft(m)
		var swapped: bool = swap.has(c) and _replaced(actions, c, item)
		if not ground and not swapped and m != Mat.AIR and m != Mat.WATER:
			continue
		if not ground and not swapped and not actions.can_place(who, c, w.size_y):
			continue
		# The old block of one replaced is knocked out with the bag's best tool for it.
		var tool: Variant = best_tool(who, m) if swapped else null
		if swapped and tool == null:
			missing_tool = m if missing_tool < 0 else missing_tool
			continue
		if not actions.territory_allows(who, c, "build"):
			continue
		if not who.act("place", "build"):
			return {"swing": actions.IDLE_SWING}
		if not free:
			who.inventory.remove(item, 1)
		if ground or swapped:
			var back: String = Mat.RECORDS[m].item if ground else Items.dug[m]
			# The ground taken out is dug, so it is given back even when building is free;
			# the block replaced goes into the bag as dug.
			if back != "":
				who.inventory.add(back, 1)
		var seconds := BUILD_SWING
		if swapped:
			seconds += actions.cell_swing(Tools.of(tool), c)
			if tool != "" and actions.rules.tool_wear \
					and who.inventory.wear_tool(tool, Items.get_item(tool).get("durability", 0)):
				who.say(Lang.line("[broke]", [Items.title(tool)]))
		var fresh: bool = actions.build_cell(c, block, form)
		cells.erase(c)
		forms.erase(c)
		_last_built[who.get_instance_id()] = c
		changed.emit([c], "")
		var done: Dictionary = actions.work(actions.skilled(who, "build", seconds, 1.0 if fresh else 0.0), "reach",
			(Vector3(c) + Vector3(0.5, 0.5, 0.5)) * CELL, block)
		done.placed = 1
		return done
	# Then the ghost things whose cells and ground are ready now (the user's pick,
	# 2026-11-26, 1А: the blocks first, then the things).
	for t in near_things(who):
		if who.inventory.count(t.item) == 0:
			missing = t.item if missing == "" else missing
			continue
		var set_down := _build_thing(actions, who, t)
		if not set_down.is_empty():
			return set_down
	if missing != "":
		who.nag("no_block", Lang.line("[not_in_the_bag]", [Items.title(missing)]))
	elif missing_tool >= 0:
		who.nag("tool", Tools.why_not(Tools.of(""), missing_tool))
	else:
		who.nag("plan_wait", "[blueprint_first_what_to_stand]")
	return {"swing": actions.IDLE_SWING}


## Sets fence `item` from the bag of `who` (none when building is `free`) down in ghost
## cell `c` (Placed.put, facing them) when it stands there: air on solid ground, nothing
## else there, clear of them, where they may build. The work done, {} when it cannot go
## there yet, {"swing"} when the hands are busy.
func _put_fence(actions, who, c: Vector3i, item: String, free: bool) -> Dictionary:
	var w = actions.world
	var placed = who.get("placed")
	if placed == null or w.get_cell(c.x, c.y, c.z) != Mat.AIR or not w.is_solid(c.x, c.y - 1, c.z) \
			or w.blockers.has(c) or w.ladders.has(c) or who.overlaps_cell(c) or who.overlaps_cell(c + Vector3i.UP):
		return {}
	if not actions.territory_allows(who, c, "build"):
		return {}
	if not who.act("place", "build"):
		return {"swing": actions.IDLE_SWING}
	if not free:
		who.inventory.remove(item, 1)
	var by: Variant = who.get("id")
	placed.put(item, c, null, true, -1.0, by if by is int else 0, placed.turn_facing(who.facing_step()))
	w.note_edit(c.x, c.z)
	cells.erase(c)
	forms.erase(c)
	changed.emit([c], "")
	var done: Dictionary = actions.work(actions.skilled(who, "build", BUILD_SWING, 1.0), "reach",
		(Vector3(c) + Vector3(0.5, 0.5, 0.5)) * CELL, -1)
	done.placed = 1
	return done


## Whether ghost block `item` at cell `c` stands in natural ground to be dug out before it
## is built (a figure's cell under its earthwork, see earthwork): ground no block takes the
## place of at once (not soft, _soft), not a tree's.
func _buried(actions, c: Vector3i, item: String) -> bool:
	if not Items.get_item(item).has("place"):
		return false
	var w = actions.world
	var m: int = w.get_cell(c.x, c.y, c.z)
	return not _soft(m) and m != Mat.index(Items.get_item(item).place) and _natural_ground(actions, c)


## Digs ghost cell `c` to be dug out (CUT) with the tool of the bag of `who` that digs
## it fastest; the work done, {} when it could not be dug (no tool for it, not allowed),
## {"swing"} when the hands are busy. With `keep` (a figure's block in the ground, _buried)
## its ghost stays, to be built once the cell is open.
func _dig_out(actions, who, c: Vector3i, keep := false) -> Dictionary:
	var w = actions.world
	var m: int = w.get_cell(c.x, c.y, c.z)
	if m == Mat.AIR or m == Mat.WATER or actions.tree_of(c) != null:
		if not keep:
			cells.erase(c)
			changed.emit([c], "")
		return {}
	if actions.water_holds(c):
		# Water has no physics yet: the ground it leans on stays (WorldActions.water_holds).
		who.nag("water", "[water_holds_this_ground]")
		if not keep:
			cells.erase(c)
			changed.emit([c], "")
		return {}
	var tool: Variant = best_tool(who, m)
	if tool == null:
		who.nag("tool", Tools.why_not(Tools.of(who.held()), m))
		return {}
	if not actions.territory_allows(who, c, "build"):
		return {}
	var swing: float = actions.cell_swing(Tools.of(tool), c)
	var done: Dictionary = actions.dig(who, [c] as Array[Vector3i], swing, tool)
	if done.is_empty():
		return {"swing": actions.IDLE_SWING}
	if not keep:
		cells.erase(c)
		changed.emit([c], "")
	return done


# --- Ghost things ----------------------------------------------------------------------


## The ghost thing filling cell `c`, {} for none.
func thing_at(c: Vector3i) -> Dictionary:
	return _thing_cells.get(c, {})


## Whether ghost cell `c` holds a block to build (not a mark, ground to dig out, a fence):
## a ghost thing stands on it, and a ghost door or window takes its place (Placed.ghost_spot).
func block_at(c: Vector3i) -> bool:
	var v: String = cells.get(c, "")
	return v != "" and v != CUT and not is_mark(v) and not is_fence(v)


## Adds ghost thing `item` at north-west cell `cell` turned `turn`, filling cells `filled`,
## in the place of ghost blocks `wall` (an opening's, see things), and tells of it.
func add_thing(item: String, cell: Vector3i, turn: int, filled: Array, wall := {}) -> Dictionary:
	var t := {"item": item, "cell": cell, "turn": posmod(turn, 4), "cells": filled.duplicate(), "wall": wall.duplicate()}
	things.append(t)
	for c: Vector3i in t.cells:
		_thing_cells[c] = t
	thing_changed.emit(t, true)
	return t


## Takes ghost thing `t` off and tells of it; with `back` the ghost blocks it took the place
## of (an opening's `wall`) come back into its cells.
func drop_thing(t: Dictionary, back := false) -> void:
	var i := _index_of(t)
	if i < 0:
		return
	things.remove_at(i)
	for c: Vector3i in t.cells:
		if is_same(_thing_cells.get(c), t):
			_thing_cells.erase(c)
	thing_changed.emit(t, false)
	if back:
		var hole := {}
		for o: Vector3i in t.wall:
			hole[t.cell + o] = t.wall[o]
		put_ghosts(hole)


## Where ghost thing `t` is in `things` (the very one), -1 when it is not.
func _index_of(t: Dictionary) -> int:
	for i in things.size():
		if is_same(things[i], t):
			return i
	return -1


## Takes the ghost things off that fill any of cells `of` (a thing set down there for real:
## Placed._set_down, move).
func drop_things_in(of: Array) -> void:
	for c in of:
		var t := thing_at(c)
		if not t.is_empty():
			drop_thing(t)


## The build mode with things set down by the blueprint (Protocol.PLAN_THING; the user's
## picks, 2026-11-26, 1А, 2А): `who` sets a ghost of thing `item` (one is in their bag) at
## cell `aim` as they would set the thing down there (Placed.put_at: turned best, `view`,
## `kept` and `face` alike), but in the world as the blueprint will stand built
## (Placed.ghost_spot): on ghost blocks, against ghost walls, clear of other ghost things; a
## door or a window takes the place of the ghost blocks where it goes. Within PLAN_REACH,
## where they may build, MAX_THINGS at most. True if it was set.
func put_thing(actions, who, item: String, aim: Vector3i, view := -1, kept := false, face := -1) -> bool:
	var placed = who.get("placed")
	var rec := Items.get_item(item)
	if placed == null or rec.get("prop", "none") == "none" or not within_reach(who, aim):
		return false
	if who.inventory.count(rec.id) <= 0:
		who.nag("put", Lang.line("[not_in_the_bag]", [Items.title(rec.id)]))
		return false
	if things.size() >= MAX_THINGS:
		who.nag("plan_full", "[too_many_blueprints]")
		return false
	var found: Array = placed.ghost_spot(who, self, rec.id, aim, view, kept, face)
	if found[0] == null:
		who.nag("put", Lang.line("[no_room_here]", [Items.title(rec.id)]))
		return false
	return not _set_thing(actions, who, placed, rec.id, found[0], found[1]).is_empty()


## Sets ghost thing `item` at north-west cell `spot` turned `turn` where `who` may build all
## its cells: a door or a window takes the ghost blocks of its cells off into its `wall`.
## The thing, {} when it was not set.
func _set_thing(actions, who, placed, item: String, spot: Vector3i, turn: int) -> Dictionary:
	var filled: Array = placed.volume_of(item, spot, turn)
	for c: Vector3i in filled:
		if actions != null and not actions.territory_allows(who, c, "build"):
			return {}
	var wall := {}
	var gone: Array = []
	if Placed.is_opening(item):
		for c: Vector3i in filled:
			if block_at(c):
				wall[c - spot] = cells[c]
				gone.append(c)
	_drop(gone)
	return add_thing(item, spot, turn, filled, wall)


## Moves the ghost thing filling cell `c` (Protocol.PLAN_THING_MOVE) as a thing set down is
## moved (Placed.move): to north-west cell `aim` turned `turn` (the same cell and a quarter
## more: turned where it stands); a door, a window or a hatch along its wall by the wall's
## cell `aim` pressed (`face` the side of its face, -1 none), or the other way round where it
## stands (its own cell, its turn + 2), its ghost wall going back into its old cells and
## taken off its new ones. Within PLAN_REACH of `who`, where they may build at both ends.
## True if it moved.
func move_thing(actions, who, c: Vector3i, aim: Vector3i, turn: int, face := -1) -> bool:
	var t := thing_at(c)
	var placed = who.get("placed")
	if t.is_empty() or placed == null or not within_reach(who, t.cell) or not within_reach(who, aim):
		return false
	if actions != null and not actions.territory_allows(who, t.cell, "build"):
		return false
	turn = posmod(turn, 4)
	var found: Array
	if Placed.is_opening(t.item) and aim == t.cell and turn == (int(t.turn) + 2) % 4:
		found = [placed.flip_spot(t, turn), turn]
	else:
		found = placed.ghost_move_spot(who, self, t, aim, turn, face)
	if found[0] == null:
		who.nag("put", Lang.line("[no_room_here]", [Items.title(t.item)]))
		return false
	if found[0] == t.cell and found[1] == t.turn:
		return false
	for at: Vector3i in placed.volume_of(t.item, found[0], found[1]):
		if actions != null and not actions.territory_allows(who, at, "build"):
			return false
	drop_thing(t, true)
	return not _set_thing(actions, who, placed, t.item, found[0], found[1]).is_empty()


## Takes the ghost thing filling cell `c` off the blueprint (Protocol.PLAN_THING_TAKE), a
## door's or a window's ghost wall back in its place, within PLAN_REACH of `who` where they
## may build. True if it was taken off.
func erase_thing(actions, who, c: Vector3i) -> bool:
	var t := thing_at(c)
	if t.is_empty() or not within_reach(who, t.cell) or actions != null and not actions.territory_allows(who, t.cell, "build"):
		return false
	drop_thing(t, true)
	return true


## The ghost things within reach of placing of `who` (Tools.PLACE_REACH), the lowest first,
## then the nearest.
func near_things(who) -> Array:
	var out: Array = []
	var p: Vector3 = who.position / CELL
	var r := Tools.PLACE_REACH
	for t: Dictionary in things:
		var c: Vector3i = t.cell
		if absf(c.x + 0.5 - p.x) <= r and absf(c.z + 0.5 - p.z) <= r and absf(c.y - p.y) <= r:
			out.append(t)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x.cell.y != y.cell.y:
			return x.cell.y < y.cell.y
		return Vector3(x.cell).distance_squared_to(p) < Vector3(y.cell).distance_squared_to(p))
	return out


## The action button builds ghost thing `t` (build): set down from the bag of `who` where it
## stands when its cells and the ground under it are ready (Placed.put_ghost). The work
## done, {} when it cannot go there yet, {"swing"} when the hands are tired.
func _build_thing(actions, who, t: Dictionary) -> Dictionary:
	var placed = who.get("placed")
	if placed == null or not actions.territory_allows(who, t.cell, "build"):
		return {}
	var got: int = placed.put_ghost(who, t)
	if got < 0:
		return {"swing": actions.IDLE_SWING}
	if got == 0:
		return {}
	drop_thing(t)
	var done: Dictionary = actions.work(actions.skilled(who, "build", BUILD_SWING, 1.0), "reach",
		Placed.center({"item": t.item, "cell": t.cell, "turn": t.turn}), -1)
	done.placed = 1
	return done


## Ghost thing `t` as plain data, for the save and the clients' copies (to_list,
## Protocol.GHOST_THING): {"thing": item, "cell", "turn", "cells", "wall": [[offset, block
## item], …]}.
static func thing_record(t: Dictionary) -> Dictionary:
	var wall: Array = []
	for o: Vector3i in t.wall:
		wall.append([o, t.wall[o]])
	return {"thing": t.item, "cell": t.cell, "turn": t.turn, "cells": t.cells.duplicate(), "wall": wall}


## Adds the ghost thing of record `d` (thing_record: a save's, the server's) when it is a thing
## still known, its cells near its north-west cell (THING_REACH) and none of them another
## ghost thing's. The thing, {} for none.
func _read_thing(d: Dictionary) -> Dictionary:
	var id: Variant = d.get("thing")
	if not (id is String and Items.has(Items.canon(id))):
		return {}
	var item: String = Items.get_item(Items.canon(id)).id
	var cell: Variant = cell_of(d.get("cell"))
	if Items.get_item(item).get("prop", "none") == "none" or not cell is Vector3i:
		return {}
	var tv: Variant = d.get("turn", 0)
	var turn: int = int(tv) if tv is int or tv is float and is_finite(tv) and absf(tv) < 1e9 else 0
	var filled: Array = []
	var listed: Variant = d.get("cells")
	if listed is Array:
		for v: Variant in listed:
			var c: Variant = cell_of(v)
			if c is Vector3i and _near_cell(c - cell) and not _thing_cells.has(c) and not filled.has(c) \
					and filled.size() < 4 * THING_REACH * THING_REACH:
				filled.append(c)
	if filled.is_empty():
		if _thing_cells.has(cell):
			return {}
		filled.append(cell)
	var wall := {}
	var walled: Variant = d.get("wall")
	if walled is Array:
		for w: Variant in walled:
			if not (w is Array and w.size() == 2 and w[1] is String):
				continue
			var o: Variant = cell_of(w[0])
			var block := Items.canon(w[1])
			if o is Vector3i and _near_cell(o) and Mat.index(Items.get_item(block).get("place", "")) >= 0:
				wall[o] = Items.get_item(block).id
	return add_thing(item, cell, turn, filled, wall)


## Whether offset `o` lies within THING_REACH of a ghost thing's north-west cell.
static func _near_cell(o: Vector3i) -> bool:
	return maxi(maxi(absi(o.x), absi(o.y)), absi(o.z)) <= THING_REACH


## The client's copy: ghost thing `d` (thing_record) was set (Protocol.GHOST_THING); one at
## its north-west cell before goes.
func take_thing(d: Dictionary) -> void:
	var cell: Variant = cell_of(d.get("cell"))
	if cell is Vector3i:
		take_thing_gone(cell)
	_read_thing(d)


## The client's copy: the ghost thing at north-west cell `cell` went (Protocol.GHOST_THING_GONE).
func take_thing_gone(cell: Vector3i) -> void:
	for t: Dictionary in things.duplicate():
		if t.cell == cell:
			drop_thing(t)


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
## (a crop's seeds on a bed, or on ground tilled first or sown wild), «water» a bed or a
## wild sowing, «reap» a crop (not a sapling).
static func mark_fits(actions, work: String, item: String, c: Vector3i) -> bool:
	match work:
		"till":
			return actions.can_till(c)
		"sow":
			return actions.plantable(item, c)
		"water":
			return actions.can_water(c)
		"reap":
			var crop: String = actions.crop_on(c)
			return crop != "" and not Plants.is_sapling(crop)
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
		who.nag("plan_big", "[the_marking_is_too_big]")
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
		who.nag("no_seed", "[choose_what_to_plant]")
		return 0
	var value := mark_of(work, item)
	if value == "":
		return 0
	var added: Array = []
	for c: Vector3i in farm_sort(actions, who, work, item, square, a, b).fit:
		if cells.get(c, "") == value:
			continue
		if not cells.has(c) and cells.size() + added.size() >= MAX_CELLS:
			who.nag("plan_full", "[too_much_marking]")
			break
		added.append(c)
	for c: Vector3i in added:
		cells[c] = value
		forms.erase(c)
	if not added.is_empty():
		changed.emit(added, value)
	elif work == "reap":
		who.nag("plan_none", "[nothing_to_gather_here]")
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
		who.nag("farm_none", "[no_marking_nearby_draw_it]")
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
			if not actions.can_water(c):
				_drop([c])
				return null
			var can := _best(who, func(t: Dictionary) -> bool: return Tools.can_water(t))
			if can == "":
				return "[no_watering_can_with_water]"
			var cs := _around(c, v, Tools.of(can), mine, func(x: Vector3i) -> bool: return actions.can_water(x))
			return _done(actions, actions.water(who, cs, can), cs)
		REAP:
			if actions.crop_on(c) == "" or Plants.is_sapling(actions.crop_on(c)):
				_drop([c])
				return null
			if not actions.ripe_at(c):
				return "[not_ripe_yet_n2]"
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
		return Lang.line("[not_in_the_bag]", [Items.title(v)])
	if Plants.is_crop(Items.get_item(v).get("crop", "")):
		if actions.clock.season == actions.WINTER:
			return "[no_sowing_in_winter_wait]"
		# Ground not tilled is tilled first with a hoe of the bag, else sown wild.
		if not bed and _best(who, func(t: Dictionary) -> bool: return Tools.can_till(t)) != "":
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
		return "[no_hoe_to_till_a]"
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


## Ghost blocks where blocks are missing (Placed: the hole of a door or a window taken
## out of a wall, or moved off with too few blocks to fill its place): `of` cell -> the
## item of the block, a cube, in each cell that has no ghost yet, as many as MAX_CELLS
## lets. How many were added.
func put_ghosts(of: Dictionary) -> int:
	var by_item := {}
	var added := 0
	for c: Vector3i in of:
		if cells.has(c) or cells.size() >= MAX_CELLS:
			continue
		cells[c] = of[c]
		forms.erase(c)
		if not by_item.has(of[c]):
			by_item[of[c]] = []
		by_item[of[c]].append(c)
		added += 1
	for item: String in by_item:
		changed.emit(by_item[item], item)
	return added


## Sets ghost cells `of` (cell -> [the block's item, "" none; its form, 0 a cube]) as they
## are given (PlanHistory: a step undone or done again), and tells of them. How many.
func set_ghosts(of: Dictionary) -> int:
	var by_item := {}
	for c: Vector3i in of:
		var item: String = of[c][0]
		var form: int = of[c][1]
		if item == "":
			cells.erase(c)
		else:
			cells[c] = item
		if form != 0 and item != "":
			forms[c] = form
		else:
			forms.erase(c)
		if not by_item.has(item):
			by_item[item] = []
		by_item[item].append(c)
	for item: String in by_item:
		changed.emit(by_item[item], item)
	return of.size()


## Takes the ghost blocks off cells `of` a thing now fills (Placed: a door or a window set
## into a hole the blueprint was to wall up): no block goes there any more. The farming
## mode's marks stay.
func drop_ghosts(of: Array) -> void:
	var gone: Array = []
	for c in of:
		if cells.has(c) and not is_mark(cells[c]):
			gone.append(c)
	_drop(gone)


## The ghost cells for the save and for a client joining: [[cell, item], …], with the
## form third where it is not a cube; then the ghost things, each a Dictionary
## (thing_record: a game from before them reads past it).
func to_list() -> Array:
	var out: Array = []
	for c: Vector3i in cells:
		out.append([c, cells[c], forms[c]] if forms.has(c) else [c, cells[c]])
	for t: Dictionary in things:
		out.append(thing_record(t))
	return out


## The forms of ghost cells `list` (0 a cube), for the client's copy (take).
func forms_of(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append(forms.get(c, 0))
	return out


## The ghost cells of a save (to_list); those of blocks no longer known are left out.
## A world's file is JSON (WorldStore.write_json), which keeps a cell as the words
## "(x, y, z)" and a form as a float: both are read back (cell_of).
func from_list(list: Array) -> void:
	cells.clear()
	forms.clear()
	things.clear()
	_thing_cells.clear()
	for e in list:
		if e is Dictionary:
			_read_thing(e)
			continue
		if not (e is Array and e.size() in [2, 3] and e[1] is String):
			continue
		var c: Variant = cell_of(e[0])
		if not c is Vector3i:
			continue
		var item: String = Items.canon(e[1]) if e[1] != CUT and not e[1] in WORK_MARKS else e[1]
		if item == CUT or is_mark(item) or Mat.index(Items.get_item(item).get("place", "")) >= 0:
			cells[c] = item
			var form: int = int(e[2]) if e.size() == 3 and (e[2] is int or e[2] is float and is_finite(e[2])) else 0
			form &= 15 | WorldData.FORM_NOTCH
			if WorldData.form_kind(form) != WorldData.FORM_CUBE:
				forms[c] = form
	changed.emit([], "")


## Cell `v` as a save keeps it: a Vector3i, the words "(x, y, z)" JSON writes one as, or
## [x, y, z]; null when it is none of them.
static func cell_of(v: Variant) -> Variant:
	if v is Vector3i:
		return v
	var parts: Array = []
	if v is String:
		var s: String = v
		if not (s.begins_with("(") and s.ends_with(")")):
			return null
		for word in s.substr(1, s.length() - 2).split(","):
			parts.append(word.strip_edges())
	elif v is Array:
		parts = v
	if parts.size() != 3:
		return null
	var n: Array[int] = []
	for p: Variant in parts:
		if p is String and (p as String).is_valid_int() and (p as String).length() < 11:
			n.append((p as String).to_int())
		elif p is int or p is float and is_finite(p) and absf(p) < 1e9:
			n.append(int(p))
		else:
			return null
	return Vector3i(n[0], n[1], n[2])


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
				if f is int and WorldData.form_kind(f) != WorldData.FORM_CUBE:
					forms[c] = f & (15 | WorldData.FORM_NOTCH)
			got.append(c)
	changed.emit(got, item)


## The client's copy: every ghost cell there is, on joining (to_list).
func take_all(list: Array) -> void:
	from_list(list)
