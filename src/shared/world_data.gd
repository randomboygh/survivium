extends RefCounted
## World grid: x and z are horizontal, y is the level. A cell is CELL world units on
## each side, 8 px on screen. The world has no edge: it is kept in chunks of CHUNK by
## CHUNK columns, made by the generator as the player comes near and dropped again far
## away unless the player changed them (see WorldGen). Where no chunk is kept, every
## cell reads as air and nothing walks. One byte per cell, plus flags for what the
## generator made: natural ground lies as slopes and turns its corners diagonally.
## Those shapes follow from the cells around and are kept per cell (see update_shapes).
## Per column, bit masks of the materials let a whole column be tested at once, which
## keeps shapes and meshes fast on a fine grid.

const Mat := preload("res://src/shared/materials.gd")

## Size of a cell in world units; a world unit is 16 px on screen.
const CELL := 0.5
## Chunk size in cells: the unit the world is generated, kept, meshed and streamed in.
const CHUNK := 16
const SHIFT := 4
const MASK := CHUNK - 1
## Columns in a chunk: a level of a chunk is this many cells.
const LAYER := CHUNK * CHUNK
## Open water lies this far up its top cell (4 px under the ground beside it). Ice
## fills the cell to the top.
const WATER_TOP := 0.5

var size_y: int
## The top cell of the sea, about five twelfths of the way up (12 of 40, 20 of 48).
var sea_level := 12
## In winter water freezes and is walked on like ground; otherwise it is waded and
## swum through.
var water_frozen := false
## The chunks kept, by Vector2i(cx, cz) (chunk cx holds the columns cx * CHUNK and on).
var chunks := {}
## WILD for every cell the generator left in place, SHEER besides on loose ground that
## keeps a sheer wall instead of a slope. Any edit clears the flags, so placed blocks
## always stay whole cubes and dug spaces keep square corners.
const WILD := 1
const SHEER := 2
## Trees grown in the world: species (see Trees) by the trunk's column, Vector2i(x, z),
## and the trunks by chunk, so a dropped chunk forgets its trees without a search.
var trees := {}
var tree_chunks := {}
## Bushes grown in the world: type (see Bushes) by the cell they stand in, and the
## cells with a bush by chunk (Vector2i), for the chunk that draws them.
var bushes := {}
var bush_chunks := {}
## What has been gathered from bushes this year, by the bush's cell: berries picked
## (true) and branches broken off (how many). Spring clears both (see Gathering); a
## chunk with any is kept as an edited one.
var bush_picked := {}
var bush_twigs := {}
## What has been gathered by hand from standing trees this year, by the trunk's column:
## branches broken off and seeds picked (how many). Spring clears both (see Gathering);
## a chunk with any is kept as an edited one.
var tree_twigs := {}
var tree_seeds := {}
## What grows on grass cells the player changed, by chunk (Vector2i) and then by cell:
## "" for grass cut short (its tall plants gone until spring, see Gathering.mow), or the
## id of the crop sown there (see Plants; Foliage draws it). Saved with the chunk.
var turf := {}
## Things lying on the ground (the logs, branches and seeds of a felled tree, what was
## thrown away, a sack left by a death), by chunk (Vector2i): [kind, position in world
## units, angle about y, data] each. `kind` is an item id (a bare name is a core item,
## see Items) or Items.SACK; `data` is how many items for an item ({"n", "worn"} for a
## worn tool, see Inventory), the stacks ([[id, count]...]) for a sack. A chunk with any
## is kept as an edited one.
var drops := {}
## Things of one kind laid this close to a heap (world units) join it (see heap_drop).
const HEAP := 0.35
## Chunks the player changed since they were last saved (see note_edit, WorldGen.pack).
var unsaved := {}
## Per-cell records of the bushes (by the bush's cell, Vector3i), kept and saved with
## the chunk the bush stands in. Each name is a Dictionary var of this class.
const BUSH_MAPS := ["bushes", "bush_picked", "bush_twigs"]
## Per-tree records (by the trunk's column, Vector2i), kept and saved with the chunk of
## the trunk.
const TREE_MAPS := ["tree_twigs", "tree_seeds"]
## While the generator writes cells, edits are not tracked: it works out the shapes
## of each chunk itself once the chunks around are final (see WorldGen).
var track_edits := true
## Bits of all levels, and of the top level.
var all_bits: int
var top_bit: int
## Columns whose shapes are out of date: x0, z0, x1, z1 (ends exclusive), empty if x0 >= x1.
var _dirty := PackedInt32Array([0, 0, 0, 0])
## Surfaces of sloping tops looked at lately (see surface_patch), by cell; emptied
## whenever shapes change.
var _patches := {}
## The chunk looked up last, which the next lookup most often wants again.
var _last_key := Vector2i(1 << 30, 0)
var _last: Chunk


## The cells of a chunk, level by level: cell (lx, y, lz) of the chunk is index
## (y * CHUNK + lz) * CHUNK + lx, column lx + lz * CHUNK. Per column, bit masks with
## bit y for the cell on level y: air, water, leaves, logs, wild cells, and cells with
## a slope or with corners in `shapes`.
class Chunk extends RefCounted:
	var key: Vector2i
	var cells := PackedByteArray()
	var natural := PackedByteArray()
	## Shape of each cell, worked out from the cells and flags by update_shapes: the
	## corners of a sloping top that are low (bits 0..3, none for a whole cube; in the
	## covered cell under it, those where it goes on down into that cell), and the
	## corners cut off a ground cell or filled in an open one (bits 4..7). Corner k is
	## bit 1 << k.
	var shapes := PackedByteArray()
	var air := PackedInt64Array()
	var water := PackedInt64Array()
	var leaf := PackedInt64Array()
	var logs := PackedInt64Array()
	var wild := PackedInt64Array()
	var sloped := PackedInt64Array()
	var corner := PackedInt64Array()
	## Changed by the player: kept when the player goes far away.
	var edited := false
	## Done by the generator: its later stages of the chunks around write nothing here
	## (see WorldGen).
	var final := false

## Corner bits of a slope mask: which corners of the cell's top are at full height.
## North is -z. FULL is a whole cube.
const NW := 1
const NE := 2
const SE := 4
const SW := 8
const FULL := 15
## Horizontal neighbours N, S, W, E.
const SIDES := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## Slope mask for the low sides N, S, W, E (1, 2, 4, 8) of a cell; FULL where it stays
## a cube: no low side, or two opposite ones.
const RAMPS := [FULL, SE | SW, NW | NE, FULL, NE | SE, SE, NE, FULL, NW | SW, SW, NW,
	FULL, FULL, FULL, FULL, FULL]
## Way from a cell to its corners NW, NE, SE, SW (corner k is bit 1 << k of a mask).
const CORNER_DIRS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

## Level of a single-bit mask, by the bit's remainder modulo 67 (distinct for 2^0..2^63).
static var _bit_levels := PackedByteArray()


## A world of `sy` levels. For tests and tools, `area` makes empty chunks over the
## columns 0..area.x, 0..area.y at once.
func _init(sy: int, area := Vector2i.ZERO) -> void:
	assert(sy <= 62, "a column's levels must fit in a 64-bit mask")
	size_y = sy
	sea_level = maxi(4, sy * 5 / 12)
	all_bits = (1 << sy) - 1
	top_bit = 1 << (sy - 1)
	for cz in ceili(area.y / float(CHUNK)):
		for cx in ceili(area.x / float(CHUNK)):
			add_chunk(Vector2i(cx, cz))


## The key of the chunk holding column (x, z).
static func chunk_key(x: int, z: int) -> Vector2i:
	return Vector2i(x >> SHIFT, z >> SHIFT)


## The chunk holding column (x, z), null when it is not kept.
func chunk_at(x: int, z: int) -> Chunk:
	var key := Vector2i(x >> SHIFT, z >> SHIFT)
	if key != _last_key:
		_last_key = key
		_last = chunks.get(key)
	return _last


## Index of column (x, z) in its chunk.
static func col_of(x: int, z: int) -> int:
	return ((z & MASK) << SHIFT) | (x & MASK)


## A new empty chunk (all air), replacing what was kept there.
func add_chunk(key: Vector2i) -> Chunk:
	var c := Chunk.new()
	c.key = key
	c.cells.resize(LAYER * size_y)
	c.natural.resize(LAYER * size_y)
	c.shapes.resize(LAYER * size_y)
	for a: PackedInt64Array in [c.air, c.water, c.leaf, c.logs, c.wild, c.sloped, c.corner]:
		a.resize(LAYER)
	c.air.fill(all_bits)
	chunks[key] = c
	if key == _last_key:
		_last = c
	return c


## Forgets a chunk with its trees and bushes.
func remove_chunk(key: Vector2i) -> void:
	chunks.erase(key)
	if key == _last_key:
		_last = null
	for cell: Vector3i in bush_chunks.get(key, {}):
		bushes.erase(cell)
		bush_picked.erase(cell)
		bush_twigs.erase(cell)
	bush_chunks.erase(key)
	for t: Vector2i in tree_chunks.get(key, {}):
		trees.erase(t)
		tree_twigs.erase(t)
		tree_seeds.erase(t)
	tree_chunks.erase(key)
	drops.erase(key)
	turf.erase(key)
	unsaved.erase(key)


func has_chunk(key: Vector2i) -> bool:
	return chunks.has(key)


## True when the cell is in a chunk that is kept, on a level of the world.
func in_bounds(x: int, y: int, z: int) -> bool:
	return y >= 0 and y < size_y and chunk_at(x, z) != null


## Cells below the world are bedrock; cells above it or where no chunk is kept are air.
func get_cell(x: int, y: int, z: int) -> int:
	if y < 0:
		return Mat.STONE
	if y >= size_y:
		return Mat.AIR
	var c := chunk_at(x, z)
	if c == null:
		return Mat.AIR
	return c.cells[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)]


func set_cell(x: int, y: int, z: int, m: int) -> void:
	if y < 0 or y >= size_y:
		return
	var c := chunk_at(x, z)
	if c == null or c.final and not track_edits:
		return
	var col := ((z & MASK) << SHIFT) | (x & MASK)
	var i := (y << 8) | col
	c.cells[i] = m
	c.natural[i] = 0
	var bit := 1 << y
	c.air[col] = c.air[col] & ~bit | (bit if m == Mat.AIR else 0)
	c.water[col] = c.water[col] & ~bit | (bit if m == Mat.WATER else 0)
	c.leaf[col] = c.leaf[col] & ~bit | (bit if m == Mat.LEAVES else 0)
	c.logs[col] = c.logs[col] & ~bit | (bit if m == Mat.LOG else 0)
	c.wild[col] &= ~bit
	if turf.has(c.key):
		turf[c.key].erase(Vector3i(x, y, z))
	_touch(c, x, z)


## Makes cell x, y, z of material `m` and keeps its shape: the grass cut off the top of
## natural ground leaves the slope it lay on. For loose ground into loose ground only
## (see Mat.can_slope); set_cell is for anything else.
func set_material(x: int, y: int, z: int, m: int) -> void:
	if y < 0 or y >= size_y:
		return
	var c := chunk_at(x, z)
	if c == null:
		return
	c.cells[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)] = m
	_touch(c, x, z)


func set_natural(x: int, y: int, z: int, on: bool) -> void:
	if y < 0 or y >= size_y:
		return
	var c := chunk_at(x, z)
	if c == null:
		return
	var col := ((z & MASK) << SHIFT) | (x & MASK)
	c.natural[(y << 8) | col] = WILD if on else 0
	c.wild[col] = c.wild[col] & ~(1 << y) | ((1 << y) if on else 0)
	_touch(c, x, z)


func is_natural(x: int, y: int, z: int) -> bool:
	if y < 0 or y >= size_y:
		return false
	var c := chunk_at(x, z)
	return c != null and c.natural[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)] & WILD != 0


## The masks of column (x, z): air (all levels where no chunk is kept), water, leaves
## and logs.
func air_col(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	return all_bits if c == null else c.air[((z & MASK) << SHIFT) | (x & MASK)]


func water_col(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	return 0 if c == null else c.water[((z & MASK) << SHIFT) | (x & MASK)]


func leaf_col(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	return 0 if c == null else c.leaf[((z & MASK) << SHIFT) | (x & MASK)]


func log_col(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	return 0 if c == null else c.logs[((z & MASK) << SHIFT) | (x & MASK)]


## The column masks of x0..x1, z0..z1 (ends exclusive), row by row: a Dictionary of
## PackedInt64Array air, water, leaf, logs, wild, sloped, corner, and kept (all bits
## where a chunk is kept, else 0). Where no chunk is kept every cell is air.
func column_masks(x0: int, z0: int, x1: int, z1: int) -> Dictionary:
	var names := ["air", "water", "leaf", "logs", "wild", "sloped", "corner", "kept"]
	var out := {}
	for n: String in names:
		out[n] = PackedInt64Array()
	var empty := PackedInt64Array()
	empty.resize(CHUNK)
	var open := empty.duplicate()
	open.fill(all_bits)
	for z in range(z0, z1):
		var lz := (z & MASK) << SHIFT
		var x := x0
		while x < x1:
			var c := chunk_at(x, z)
			var b := mini(x1, (x | MASK) + 1)
			var a := lz | (x & MASK)
			var e := a + b - x
			if c == null:
				for n: String in names:
					var arr: PackedInt64Array = out[n]
					arr.append_array((open if n == "air" else empty).slice(0, b - x))
			else:
				out.air.append_array(c.air.slice(a, e))
				out.water.append_array(c.water.slice(a, e))
				out.leaf.append_array(c.leaf.slice(a, e))
				out.logs.append_array(c.logs.slice(a, e))
				out.wild.append_array(c.wild.slice(a, e))
				out.sloped.append_array(c.sloped.slice(a, e))
				out.corner.append_array(c.corner.slice(a, e))
				out.kept.append_array(open.slice(0, b - x))
			x = b
	return out


## Copy of the cells (`shapes` false) or shapes of x0..x1, z0..z1 (exclusive ends) and
## levels -1..size_y, in that order (x fastest). Where no chunk is kept and above the
## world the value is 0 (air, no shape), below it `below`.
func padded(shapes: bool, below: int, x0: int, z0: int, x1: int, z1: int) -> PackedByteArray:
	var width := x1 - x0
	var out := PackedByteArray()
	var rows := z1 - z0
	var below_rows := PackedByteArray()
	below_rows.resize(width * rows)
	below_rows.fill(below)
	out.append_array(below_rows)
	var air := PackedByteArray()
	air.resize(CHUNK)
	# Each piece of a row that lies in one chunk: the chunk's array, its start and
	# length, row by row.
	var parts := []
	for z in range(z0, z1):
		var x := x0
		while x < x1:
			var c := chunk_at(x, z)
			var b := mini(x1, (x | MASK) + 1)
			parts.append([null if c == null else (c.shapes if shapes else c.cells),
				((z & MASK) << SHIFT) | (x & MASK), b - x])
			x = b
	for y in size_y:
		var base := y << 8
		for p: Array in parts:
			var n: int = p[2]
			if p[0] == null:
				out.append_array(air.slice(0, n))
			else:
				var src: PackedByteArray = p[0]
				var a: int = base + p[1]
				out.append_array(src.slice(a, a + n))
	below_rows.fill(0)
	out.append_array(below_rows)
	return out


## Rebuilds the column masks of every chunk after cells or flags were written straight
## into its arrays, and marks all shapes out of date.
func rebuild_columns() -> void:
	for c: Chunk in chunks.values():
		for col in LAYER:
			var a := 0
			var wt := 0
			var lf := 0
			var lg := 0
			var wd := 0
			for y in size_y:
				var i := (y << 8) | col
				var m := c.cells[i]
				var bit := 1 << y
				a |= bit if m == Mat.AIR else 0
				wt |= bit if m == Mat.WATER else 0
				lf |= bit if m == Mat.LEAVES else 0
				lg |= bit if m == Mat.LOG else 0
				wd |= bit if c.natural[i] & WILD else 0
			c.air[col] = a
			c.water[col] = wt
			c.leaf[col] = lf
			c.logs[col] = lg
			c.wild[col] = wd
	mark_all_dirty()


## Marks the shapes of every kept chunk out of date.
func mark_all_dirty() -> void:
	if chunks.is_empty():
		return
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for k: Vector2i in chunks:
		lo = lo.min(k)
		hi = hi.max(k)
	_dirty = PackedInt32Array([lo.x * CHUNK, lo.y * CHUNK, (hi.x + 1) * CHUNK, (hi.y + 1) * CHUNK])


## A change at column (x, z) can reshape the cells up to two columns away: slopes look
## at their neighbours, corners at the slopes beside them. The chunk is now the
## player's and is kept from then on.
func _touch(c: Chunk, x: int, z: int) -> void:
	if not track_edits:
		return
	c.edited = true
	unsaved[c.key] = true
	var d := _dirty
	if d[0] >= d[2]:
		_dirty = PackedInt32Array([x - 2, z - 2, x + 3, z + 3])
	else:
		_dirty = PackedInt32Array([mini(d[0], x - 2), mini(d[1], z - 2), maxi(d[2], x + 3), maxi(d[3], z + 3)])


## Brings `shapes` up to date after edits. Everything that reads shapes calls it.
func refresh_shapes() -> void:
	if _dirty[0] < _dirty[2]:
		var d := _dirty
		_dirty = PackedInt32Array([0, 0, 0, 0])
		update_shapes(d[0], d[1], d[2], d[3])


## Works out the shapes of the columns x0..x1, z0..z1 (ends exclusive), all levels:
## slopes first, then the cut and filled corners, which look at the slopes beside them.
## The rules are those of slope_mask, corner_cut and corner_fill, applied to whole
## columns of bits at once; only the few cells that may slope are looked at one by one.
func update_shapes(x0: int, z0: int, x1: int, z1: int) -> void:
	update_slopes(x0, z0, x1, z1)
	update_corners(x0, z0, x1, z1)


## Masks of the columns x0..x1, z0..z1 and a ring of one around them, `wl` columns
## wide: air, water, open (air, water or leaves), ground, wild cells, cells with open
## air or water above a lower neighbour, and sloped cells. Where no chunk is kept
## every cell is air, nothing is wild and nothing is low.
func _masks(x0: int, z0: int, x1: int, z1: int) -> Dictionary:
	var wl := x1 - x0 + 2
	var hl := z1 - z0 + 2
	var cols := column_masks(x0 - 1, z0 - 1, x1 + 1, z1 + 1)
	var air: PackedInt64Array = cols.air
	var water: PackedInt64Array = cols.water
	var leaf: PackedInt64Array = cols.leaf
	var logs: PackedInt64Array = cols.logs
	var kept: PackedInt64Array = cols.kept
	var open := PackedInt64Array()
	open.resize(wl * hl)
	var ground := open.duplicate()
	var low := open.duplicate()
	var all := all_bits
	for j in wl * hl:
		var a := air[j]
		var wt := water[j]
		var o := a | wt | leaf[j]
		open[j] = o
		ground[j] = ~(o | logs[j]) & all
		low[j] = (a | wt) & ~(a << 1) & kept[j]
	return {"wl": wl, "hl": hl, "air": air, "water": water, "open": open, "ground": ground, "wild": cols.wild,
		"low": low, "sloped": cols.sloped}


## Clears the shapes of the columns x0..x1, z0..z1 (ends exclusive) and works out
## their slopes; update_corners then adds the corners, which look at the slopes
## beside them (all of a region's slopes must be done before its corners).
func update_slopes(x0: int, z0: int, x1: int, z1: int) -> void:
	_patches.clear()
	for z in range(z0, z1):
		var x := x0
		while x < x1:
			var c := chunk_at(x, z)
			var b := mini(x1, (x | MASK) + 1)
			if c != null:
				var shapes := c.shapes
				var sloped := c.sloped
				var corner := c.corner
				var col := ((z & MASK) << SHIFT) | (x & MASK)
				for k in b - x:
					var m := sloped[col] | corner[col]
					while m != 0:
						var bit := m & -m
						m ^= bit
						shapes[(level_of(bit) << 8) | col] = 0
					sloped[col] = 0
					corner[col] = 0
					col += 1
			x = b
	var mk := _masks(x0, z0, x1, z1)
	var wl: int = mk.wl
	var hl: int = mk.hl
	var air: PackedInt64Array = mk.air
	var water: PackedInt64Array = mk.water
	var open: PackedInt64Array = mk.open
	var wild: PackedInt64Array = mk.wild
	var low: PackedInt64Array = mk.low
	var diag := PackedInt32Array([-wl - 1, -wl + 1, wl + 1, wl - 1])
	# Slopes: loose wild ground with air or water above, so lake and river beds get
	# ramps too.
	for lz in range(1, hl - 1):
		for lx in range(1, wl - 1):
			var j := lz * wl + lx
			var cand := ~open[j] & (((air[j] | water[j]) >> 1) | top_bit) & wild[j]
			if cand == 0:
				continue
			var x := x0 - 1 + lx
			var z := z0 - 1 + lz
			var c := chunk_at(x, z)
			var col := ((z & MASK) << SHIFT) | (x & MASK)
			var cells := c.cells
			var natural := c.natural
			var shapes := c.shapes
			var low_n := low[j - wl]
			var low_s := low[j + wl]
			var low_w := low[j - 1]
			var low_e := low[j + 1]
			while cand != 0:
				var bit := cand & -cand
				cand ^= bit
				var y := level_of(bit)
				var i := (y << 8) | col
				if natural[i] != WILD or not Mat.can_slope(cells[i]):
					continue
				var lows := (1 if low_n & bit else 0) | (2 if low_s & bit else 0) | (4 if low_w & bit else 0) \
					| (8 if low_e & bit else 0)
				var mask: int = RAMPS[lows]
				if lows == 0:
					# Inner corner: exactly one lower diagonal between two sloping neighbours.
					for k in 4:
						if low[j + diag[k]] & bit == 0:
							continue
						var o: Vector2i = CORNER_DIRS[k]
						if _can_slope(x + o.x, y, z) and _can_slope(x, y, z + o.y):
							if mask != FULL:
								mask = FULL
								break
							mask = FULL & ~(1 << k)
				if mask != FULL:
					shapes[i] = FULL & ~mask
					c.sloped[col] |= bit


## Works out the cut and filled corners of the columns x0..x1, z0..z1 (ends
## exclusive) from the cells and slopes around them (see corner_cut, corner_fill).
func update_corners(x0: int, z0: int, x1: int, z1: int) -> void:
	_update_deep(x0, z0, x1, z1)
	var mk := _masks(x0, z0, x1, z1)
	var wl: int = mk.wl
	var hl: int = mk.hl
	var air: PackedInt64Array = mk.air
	var water: PackedInt64Array = mk.water
	var open: PackedInt64Array = mk.open
	var ground: PackedInt64Array = mk.ground
	var wild: PackedInt64Array = mk.wild
	var sloped: PackedInt64Array = mk.sloped
	var side_x := PackedInt32Array([-1, 1, 1, -1])
	var side_z := PackedInt32Array([-wl, -wl, wl, wl])
	# Corners.
	for lz in range(1, hl - 1):
		for lx in range(1, wl - 1):
			var j := lz * wl + lx
			if wild[j] == 0:
				continue
			var aw := air[j] | water[j]
			var gr := ground[j]
			# Mostly the ground beside is as high as here: nothing to cut or fill.
			if gr & (air[j - wl] | air[j + wl] | air[j - 1] | air[j + 1] | water[j - wl] | water[j + wl] \
					| water[j - 1] | water[j + 1]) == 0 \
					and aw & (ground[j - wl] | ground[j + wl] | ground[j - 1] | ground[j + 1]) == 0:
				continue
			var x := x0 - 1 + lx
			var z := z0 - 1 + lz
			var c := chunk_at(x, z)
			var col := ((z & MASK) << SHIFT) | (x & MASK)
			for k in 4:
				var cx := j + side_x[k]
				var cz := j + side_z[k]
				var cd := cx + side_z[k]
				var wild4 := wild[j] & wild[cx] & wild[cz] & wild[cd]
				if wild4 == 0:
					continue
				var cut := gr & wild4 & (air[cx] & air[cz] & air[cd] | water[cx] & water[cz] & water[cd])
				if cut != 0:
					# A slope is cut only at a corner where it is low, and not where it goes
					# on down into the cell below.
					var sl := cut & sloped[j]
					while sl != 0:
						var bit := sl & -sl
						sl ^= bit
						var i := (level_of(bit) << 8) | col
						if c.shapes[i] & (1 << k) == 0 or i >= LAYER and c.shapes[i - LAYER] & (1 << k):
							cut &= ~bit
					# The runs of such cells whose top has an open cell above.
					_mark(c, col, _spread(cut, cut & ~(cut >> 1) & ((open[j] >> 1) | top_bit), -1), 16 << k)
				var fill := aw & wild4 & ground[cx] & ground[cz] & ground[cd] & ~sloped[cx] & ~sloped[cz]
				if fill != 0:
					# The runs of such cells standing on something that hides what is behind it.
					_mark(c, col, _spread(fill, fill & ~(fill << 1) & ((~open[j] << 1) | 1), 1), 16 << k)


## Low corners of the sloping tops of the columns x0..x1, z0..z1 (ends exclusive) that
## go on down a level into the cell below (see _deep_corner), kept in that cell's
## shape (bits 0..3; it is covered, so it has no slope of its own). Needs the slopes
## of the columns around done.
func _update_deep(x0: int, z0: int, x1: int, z1: int) -> void:
	for z in range(z0, z1):
		for x in range(x0, x1):
			var c := chunk_at(x, z)
			if c == null:
				continue
			var col := ((z & MASK) << SHIFT) | (x & MASK)
			var m := c.sloped[col] & ~1
			while m != 0:
				var bit := m & -m
				m ^= bit
				var y := level_of(bit)
				var i := (y << 8) | col
				var deep := 0
				for k in 4:
					if c.shapes[i] & (1 << k) and _deep_corner(x, y, z, k):
						deep |= 1 << k
				if deep != 0:
					c.shapes[i - LAYER] = c.shapes[i - LAYER] | deep
					c.corner[col] |= bit >> 1


## True when low corner k of the sloping top at (x, y, z) goes on down to level y - 1,
## so that slopes falling a level a cell on the diagonal meet without steps: every
## other column around the corner meets it a level lower there, is a sloping top on
## this level, low there and going down with it, is open more than two levels down,
## or (only the column east or west) stands as high or higher; at least one meets it
## lower. The cells going down are loose wild ground.
func _deep_corner(x: int, y: int, z: int, k: int) -> bool:
	if not _deepable(x, y - 1, z):
		return false
	var o: Vector2i = CORNER_DIRS[k]
	var lower := false
	for n in 3:
		var nx := x + (o.x if n != 1 else 0)
		var nz := z + (o.y if n != 0 else 0)
		# The neighbour's own corner at this one.
		var kk: int = [k ^ 1, 3 - k, (k + 2) & 3][n]
		var a := get_cell(nx, y, nz)
		if a == Mat.AIR or a == Mat.WATER:
			var b := get_cell(nx, y - 1, nz)
			if b == Mat.AIR or b == Mat.WATER:
				# Two levels lower it meets the corner if its top is high there; lower
				# still (a bank over deep water, a cliff) it has no part in it.
				if _surface_ground(get_cell(nx, y - 2, nz)) and _shape(nx, y - 2, nz) & (1 << kk) == 0:
					lower = true
			elif not _surface_ground(b) or _shape(nx, y - 1, nz) & (1 << kk) == 0:
				return false
			else:
				lower = true
		elif n == 0:
			# The column to the east or west at the corner's level or higher: if it
			# stays up, the wall between them faces sideways, which the view never
			# shows, and the slope still meets the ground below and beyond.
			continue
		elif _surface_ground(a):
			var up := get_cell(nx, y + 1, nz)
			if up != Mat.AIR and up != Mat.WATER or _shape(nx, y, nz) & (1 << kk) == 0 \
					or not _deepable(nx, y - 1, nz):
				return false
		else:
			return false
	return lower


func _deepable(x: int, y: int, z: int) -> bool:
	if y < 0 or y >= size_y:
		return false
	var c := chunk_at(x, z)
	if c == null:
		return false
	var i := (y << 8) | ((z & MASK) << SHIFT) | (x & MASK)
	return c.natural[i] == WILD and Mat.can_slope(c.cells[i])


static func _surface_ground(m: int) -> bool:
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != Mat.LOG


## The shape byte of a cell as it is now (see Chunk.shapes), without bringing shapes up
## to date.
func _shape(x: int, y: int, z: int) -> int:
	if y < 0 or y >= size_y:
		return 0
	var c := chunk_at(x, z)
	if c == null:
		return 0
	return c.shapes[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)]


## Level of the single bit set in `bit`.
static func level_of(bit: int) -> int:
	if _bit_levels.is_empty():
		_bit_levels.resize(67)
		for k in 63:
			_bit_levels[(1 << k) % 67] = k
	return _bit_levels[bit % 67]


## Grows `seeds` through the cells of `cand` one level at a time, up (dir 1) or down (-1).
static func _spread(cand: int, seeds: int, dir: int) -> int:
	var r := seeds
	while true:
		var n := r | ((r << 1) if dir > 0 else (r >> 1)) & cand
		if n == r:
			return r
		r = n
	return r


func _mark(c: Chunk, col: int, bits: int, value: int) -> void:
	if bits == 0:
		return
	c.corner[col] |= bits
	var shapes := c.shapes
	while bits != 0:
		var bit := bits & -bits
		bits ^= bit
		var i := (level_of(bit) << 8) | col
		shapes[i] = shapes[i] | value


## Shape of a cell's top as a mask of corners at full height (NW, NE, SE, SW). Natural
## loose ground with open air above slopes down to each side where the ground is one
## level lower (or water): a ramp to one side, an outer corner to two neighbouring
## sides, an inner corner where only a diagonal neighbour is lower. Stone, built blocks
## and drops of two levels or more stay whole cubes: those are cliffs. For a covered
## cell, the corners where the slope above goes on down into it (see _deep_corner).
func slope_mask(x: int, y: int, z: int) -> int:
	if y < 0 or y >= size_y:
		return FULL
	refresh_shapes()
	var c := chunk_at(x, z)
	if c == null:
		return FULL
	return FULL & ~(c.shapes[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)] & 15)


## A sloping top is one smooth surface over its cell, a bicubic patch through the
## heights of its four corners (1 high, 0 low, -1 down into the cell below, see
## _deep_corner) with slopes there worked out from the corners of the tops beside it
## (see patch_tangent): a ramp between level ground starts and ends level and is
## steepest in the middle, a long slope stays straight, and tops that share a corner
## meet there at the same height and slope. The patch is 12 numbers: the heights of the
## corners NW, NE, SE, SW above the cell's level, then their slopes along x, then
## along z. The mesher builds the same patch from its copy of the cells
## (ChunkMesher.patch); tests check that both agree.
const PATCH_CI := [0, 1, 1, 0]
const PATCH_CJ := [0, 0, 1, 1]


## Height above the cell's level of patch `p` at (u, v) inside the cell, 0..1.
static func patch_height(p: PackedFloat32Array, u: float, v: float) -> float:
	var au := [1.0 - u * u * (3.0 - 2.0 * u), u * u * (3.0 - 2.0 * u)]
	var av := [1.0 - v * v * (3.0 - 2.0 * v), v * v * (3.0 - 2.0 * v)]
	var bu := [u * (1.0 - u) * (1.0 - u), u * u * (u - 1.0)]
	var bv := [v * (1.0 - v) * (1.0 - v), v * v * (v - 1.0)]
	var h := 0.0
	for k in 4:
		var i: int = PATCH_CI[k]
		var j: int = PATCH_CJ[k]
		h += p[k] * au[i] * av[j] + p[4 + k] * bu[i] * av[j] + p[8 + k] * au[i] * bv[j]
	return h


## Slope of patch `p` at (u, v): the height's change along x and along z.
static func patch_slope(p: PackedFloat32Array, u: float, v: float) -> Vector2:
	var au := [1.0 - u * u * (3.0 - 2.0 * u), u * u * (3.0 - 2.0 * u)]
	var av := [1.0 - v * v * (3.0 - 2.0 * v), v * v * (3.0 - 2.0 * v)]
	var bu := [u * (1.0 - u) * (1.0 - u), u * u * (u - 1.0)]
	var bv := [v * (1.0 - v) * (1.0 - v), v * v * (v - 1.0)]
	var du := [6.0 * u * (u - 1.0), 6.0 * u * (1.0 - u)]
	var dv := [6.0 * v * (v - 1.0), 6.0 * v * (1.0 - v)]
	var eu := [1.0 - 4.0 * u + 3.0 * u * u, 3.0 * u * u - 2.0 * u]
	var ev := [1.0 - 4.0 * v + 3.0 * v * v, 3.0 * v * v - 2.0 * v]
	var s := Vector2.ZERO
	for k in 4:
		var i: int = PATCH_CI[k]
		var j: int = PATCH_CJ[k]
		s.x += p[k] * du[i] * av[j] + p[4 + k] * eu[i] * av[j] + p[8 + k] * du[i] * bv[j]
		s.y += p[k] * au[i] * dv[j] + p[4 + k] * bu[i] * dv[j] + p[8 + k] * au[i] * ev[j]
	return s


## Slope of a patch at a corner from the rise d1 of the step before it and d2 of the
## one after, along a line of corners: level where the ground turns (or stays level),
## so a patch never bulges beyond its corners, and a steady slope where both agree.
static func patch_tangent(d1: float, d2: float) -> float:
	if d1 * d2 <= 0.0:
		return 0.0
	return 2.0 * d1 * d2 / (d1 + d2)


## The patch from the heights of the corners `h` and those one step on along x and
## along z from each, `far` (two per corner; see far_corner), above the cell's level.
static func make_patch(h: PackedInt32Array, far: PackedInt32Array) -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(12)
	for k in 4:
		p[k] = h[k]
		var kx := k ^ 1
		var kz := 3 - k
		p[4 + k] = patch_tangent(h[k] - far[2 * k], h[kx] - h[k]) if PATCH_CI[k] == 0 \
			else patch_tangent(h[k] - h[kx], far[2 * k] - h[k])
		p[8 + k] = patch_tangent(h[k] - far[2 * k + 1], h[kz] - h[k]) if PATCH_CJ[k] == 0 \
			else patch_tangent(h[k] - h[kz], far[2 * k + 1] - h[k])
	return p


## Heights of the corners NW, NE, SE, SW of the top of the ground cell (x, y, z) above
## its level: 1 high, 0 low, -1 going on down into the cell below.
func corner_heights(x: int, y: int, z: int) -> PackedInt32Array:
	var s := _shape(x, y, z)
	var below := _shape(x, y - 1, z) if s & 15 else 0
	var h := PackedInt32Array([1, 1, 1, 1])
	for k in 4:
		if s & (1 << k):
			h[k] = -1 if below & (1 << k) else 0
	return h


## The surface of the sloping top of cell (x, y, z) above its level (see make_patch). A
## covered cell that a slope above goes down into gets that slope's surface, a level
## higher. Kept until shapes change.
func surface_patch(x: int, y: int, z: int) -> PackedFloat32Array:
	refresh_shapes()
	var key := Vector3i(x, y, z)
	var p: PackedFloat32Array = _patches.get(key, PackedFloat32Array())
	if not p.is_empty():
		return p
	var up := get_cell(x, y + 1, z)
	if up != Mat.AIR and up != Mat.WATER:
		p = surface_patch(x, y + 1, z).duplicate()
		for k in 4:
			p[k] += 1.0
	else:
		var h := corner_heights(x, y, z)
		var far := PackedInt32Array()
		far.resize(8)
		for k in 4:
			var o: Vector2i = CORNER_DIRS[k]
			var d := (k + 2) & 3
			far[2 * k] = far_corner(_patch_far(x + o.x, y, z, k ^ 1, k, h[k]),
				_patch_far(x + o.x, y, z + o.y, d, 3 - k, h[k]), h[k])
			far[2 * k + 1] = far_corner(_patch_far(x, y, z + o.y, 3 - k, k, h[k]),
				_patch_far(x + o.x, y, z + o.y, d, k ^ 1, h[k]), h[k])
		p = make_patch(h, far)
	if _patches.size() > 4096:
		_patches.clear()
	_patches[key] = p
	return p


## No top meets the corner (see _patch_far).
const NO_CORNER := 99


## The corner one step on along a line of corners from one at `hv`, as the two tops
## along that line beyond it give it (`a` beside the cell, `b` beside the one across
## the line): one alone, or both if they agree; `hv` (level) if neither meets the
## corner or they disagree. Both cells along the line work it out the same, so their
## shared side has the same curve.
static func far_corner(a: int, b: int, hv: int) -> int:
	if a == NO_CORNER:
		return hv if b == NO_CORNER else b
	return a if b == NO_CORNER or b == a else hv


## Height above level y of corner `far` of the top in column (x, z) whose corner `near`
## meets the corner at `hv` above level y; NO_CORNER where no top there meets it. A
## corner is -1, 0 or 1 above its top's level, so the tops that can meet it lie a level
## above, at or below the corner itself: the same levels from either cell beside it.
func _patch_far(x: int, y: int, z: int, near: int, far: int, hv: int) -> int:
	for dl: int in [hv + 1, hv, hv - 1]:
		var l := y + dl
		var up := get_cell(x, l + 1, z)
		if (up == Mat.AIR or up == Mat.WATER) and _surface_ground(get_cell(x, l, z)) and l >= 0:
			var h := corner_heights(x, l, z)
			if h[near] + dl == hv:
				return h[far] + dl
	return NO_CORNER


## Height of the surface of the sloping cell (x, y, z) at (fx, fz) inside it, above its
## level (see surface_patch).
func surface_height(x: int, y: int, z: int, fx: float, fz: float) -> float:
	return patch_height(surface_patch(x, y, z), fx, fz)


## Height of the ground a walker stands on at (x, z), in cells: the top of the highest
## ground there, following slopes and cut or filled corners. -1 over open water.
func ground_height(x: float, z: float) -> float:
	var cx := floori(x)
	var cz := floori(z)
	var fx := x - cx
	var fz := z - cz
	var k := corner_at(fx, fz)
	# Only the corner triangle of the quarter the point is in can be cut or filled.
	var inside := in_corner(k, fx, fx, fz, fz)
	for y in range(size_y - 1, -1, -1):
		var m := get_cell(cx, y, cz)
		if m == Mat.AIR or m == Mat.LEAVES or m == Mat.WATER:
			if inside and corner_fill(cx, y, cz, k):
				return y + 1.0
			if m == Mat.WATER:
				return y + 1.0 if water_frozen else -1.0
			continue
		if inside and corner_cut(cx, y, cz, k):
			var o: Vector2i = CORNER_DIRS[k]
			if get_cell(cx + o.x, y, cz) == Mat.WATER and not water_frozen:
				return -1.0
			continue
		if slope_mask(cx, y, cz) == FULL:
			return y + 1.0
		return y + surface_height(cx, y, cz, fx, fz)
	return 0.0


## The corner (NW, NE, SE, SW as 0..3) of the quarter of a cell that (fx, fz) is in.
static func corner_at(fx: float, fz: float) -> int:
	if fz < 0.5:
		return 0 if fx < 0.5 else 1
	return 3 if fx < 0.5 else 2


## True when the box ax..bx, az..bz inside a cell (0..1) lies wholly in the triangle that
## a cut takes off corner k (half a cell along each side), touching its edge at most.
static func in_corner(k: int, ax: float, bx: float, az: float, bz: float) -> bool:
	match k:
		0:
			return bx + bz <= 0.5
		1:
			return ax - bz >= 0.5
		2:
			return ax + az >= 1.5
	return az - bx >= 0.5


## True when the box ax..bx, az..bz inside a cell (0..1) reaches into the triangle that
## a fill adds at corner k.
static func touches_corner(k: int, ax: float, bx: float, az: float, bz: float) -> bool:
	match k:
		0:
			return ax + az < 0.5
		1:
			return bx - az > 0.5
		2:
			return bx + bz > 1.5
	return bz - ax > 0.5


## True when corner k of the cell at (x, y, z) is cut off in plan, so cliffs, banks and
## creeks turn diagonally instead of at right angles: wild ground loses the corner
## triangle (half a cell along each side) where both sides and the diagonal are the same
## open wild cells (all air or all water), and the cell above is open or cut there too.
## A slope is cut only at a corner where it is low.
func corner_cut(x: int, y: int, z: int, k: int) -> bool:
	return corner_cuts(x, y, z) & (1 << k) != 0


## Mask of the corners cut off the cell at (x, y, z).
func corner_cuts(x: int, y: int, z: int) -> int:
	if y < 0 or y >= size_y:
		return 0
	refresh_shapes()
	var c := chunk_at(x, z)
	if c == null:
		return 0
	var i := (y << 8) | ((z & MASK) << SHIFT) | (x & MASK)
	var m := c.cells[i]
	return c.shapes[i] >> 4 if m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES else 0


## True when the open cell at (x, y, z) gets ground in the triangle at corner k: the
## inner corner where both sides and the diagonal are wild ground, the sides whole
## cubes, standing on ground or on the same fill below.
func corner_fill(x: int, y: int, z: int, k: int) -> bool:
	return corner_fills(x, y, z) & (1 << k) != 0


## Mask of the corners filled in the cell at (x, y, z).
func corner_fills(x: int, y: int, z: int) -> int:
	if y < 0 or y >= size_y:
		return 0
	refresh_shapes()
	var c := chunk_at(x, z)
	if c == null:
		return 0
	var i := (y << 8) | ((z & MASK) << SHIFT) | (x & MASK)
	var m := c.cells[i]
	return c.shapes[i] >> 4 if m == Mat.AIR or m == Mat.WATER else 0


## Ground that may have its corners cut or fill a neighbour's corner: anything that
## hides what is behind it except tree trunks.
func _ground(x: int, y: int, z: int) -> bool:
	var m := get_cell(x, y, z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != Mat.LOG


func _can_slope(x: int, y: int, z: int) -> bool:
	if y < 0 or y >= size_y:
		return false
	var c := chunk_at(x, z)
	if c == null or c.natural[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)] != WILD \
			or not Mat.can_slope(get_cell(x, y, z)):
		return false
	var above := get_cell(x, y + 1, z)
	return above == Mat.AIR or above == Mat.WATER


func is_solid(x: int, y: int, z: int) -> bool:
	return Mat.is_solid(get_cell(x, y, z))


## True when a walking body cannot be in this cell: solid, frozen water, or where no
## chunk is kept. Open water is waded and swum through.
func blocks_body(x: int, y: int, z: int) -> bool:
	if chunk_at(x, z) == null:
		return true
	var m := get_cell(x, y, z)
	if m == Mat.WATER:
		return water_frozen
	return Mat.is_solid(m)


## True when a body taking the part ax..bx, az..bz (0..1) of the cell at (x, y, z) is
## blocked, as blocks_body says for whole cells. A cut corner holds what is beside it
## (air or water); a filled corner is ground.
func blocks_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		var cuts := corner_cuts(x, y, z)
		for k in 4:
			if cuts & (1 << k) and in_corner(k, ax, bx, az, bz):
				var o: Vector2i = CORNER_DIRS[k]
				return blocks_body(x + o.x, y, z)
		return true
	if _fill_touched(x, y, z, ax, bx, az, bz):
		return true
	return blocks_body(x, y, z)


## True when the part ax..bx, az..bz (0..1) of the cell at (x, y, z) stands on its top:
## solid there, not only its cut corner, ground filling its corner, or ice.
func ground_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		var cuts := corner_cuts(x, y, z)
		for k in 4:
			if cuts & (1 << k) and in_corner(k, ax, bx, az, bz):
				return false
		return true
	return is_solid(x, y, z) or water_frozen and get_cell(x, y, z) == Mat.WATER \
		or _fill_touched(x, y, z, ax, bx, az, bz)


func _fill_touched(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	var fills := corner_fills(x, y, z)
	for k in 4:
		if fills & (1 << k) and touches_corner(k, ax, bx, az, bz):
			return true
	return false


## Notes a tree of `species` (see Trees) with its trunk in column x, z.
func add_tree(x: int, z: int, species: int) -> void:
	var at := Vector2i(x, z)
	trees[at] = species
	var key := Vector2i(x >> SHIFT, z >> SHIFT)
	if not tree_chunks.has(key):
		tree_chunks[key] = {}
	tree_chunks[key][at] = true


func remove_tree(x: int, z: int) -> void:
	note_edit(x, z)
	var at := Vector2i(x, z)
	trees.erase(at)
	tree_twigs.erase(at)
	tree_seeds.erase(at)
	var key := Vector2i(x >> SHIFT, z >> SHIFT)
	if tree_chunks.has(key):
		tree_chunks[key].erase(at)


## Notes a bush of `type` (see Bushes) in `cell`.
func add_bush(cell: Vector3i, type: int) -> void:
	bushes[cell] = type
	var key := Vector2i(cell.x >> SHIFT, cell.z >> SHIFT)
	if not bush_chunks.has(key):
		bush_chunks[key] = {}
	bush_chunks[key][cell] = true


## Lays a thing of `kind` on the ground at `pos` (world units), turned by `angle`;
## `data` is how many (see drops).
func add_drop(kind: String, pos: Vector3, angle: float, data: Variant = 1) -> void:
	var x := floori(pos.x / CELL)
	var z := floori(pos.z / CELL)
	var c := chunk_at(x, z)
	if c == null:
		return
	note_edit(x, z)
	var key := Vector2i(x >> SHIFT, z >> SHIFT)
	if not drops.has(key):
		drops[key] = []
	drops[key].append([kind, pos, angle, data])


## Lays `n` items `kind` at `pos` like add_drop, onto a heap of the same kind lying
## within HEAP of it if there is one (what a swing digs out piles up, not one per cell).
func heap_drop(kind: String, pos: Vector3, n: int, angle := 0.0) -> void:
	var key := Vector2i(floori(pos.x / CELL) >> SHIFT, floori(pos.z / CELL) >> SHIFT)
	for d: Array in drops.get(key, []):
		if d[0] == kind and d[3] is int and d[1].distance_to(pos) <= HEAP:
			d[3] += n
			note_edit(floori(pos.x / CELL), floori(pos.z / CELL))
			return
	add_drop(kind, pos, angle, n)


## Takes thing `i` of chunk `key` off the ground and returns it (see drops).
func take_drop(key: Vector2i, i: int) -> Array:
	var list: Array = drops[key]
	var d: Array = list[i]
	list.remove_at(i)
	note_edit(key.x << SHIFT, key.y << SHIFT)
	if list.is_empty():
		drops.erase(key)
	return d


## Notes something gathered from the bush in `cell`: its chunk is kept as edited.
func note_bush(cell: Vector3i) -> void:
	note_edit(cell.x, cell.z)


## What grows on grass cell `cell` (see turf): "" cut short, a crop's id, null for what
## the world grew there.
func turf_at(cell: Vector3i) -> Variant:
	var key := Vector2i(cell.x >> SHIFT, cell.z >> SHIFT)
	return turf[key].get(cell) if turf.has(key) else null


## Notes what grows on grass cell `cell` (see turf_at; null for what the world grew).
func set_turf(cell: Vector3i, what: Variant) -> void:
	var key := Vector2i(cell.x >> SHIFT, cell.z >> SHIFT)
	if what == null:
		if turf.has(key):
			turf[key].erase(cell)
			if turf[key].is_empty():
				turf.erase(key)
	else:
		if not turf.has(key):
			turf[key] = {}
		turf[key][cell] = what
	note_edit(cell.x, cell.z)


func remove_bush(cell: Vector3i) -> void:
	note_edit(cell.x, cell.z)
	bushes.erase(cell)
	bush_picked.erase(cell)
	bush_twigs.erase(cell)
	var key := Vector2i(cell.x >> SHIFT, cell.z >> SHIFT)
	if bush_chunks.has(key):
		bush_chunks[key].erase(cell)


## Cells with a bush in the chunk whose first column is x0, z0.
func bushes_in(x0: int, z0: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var found: Dictionary = bush_chunks.get(Vector2i(x0 >> SHIFT, z0 >> SHIFT), {})
	for cell: Vector3i in found:
		out.append(cell)
	return out


## Level a walker stands on in this column (the cell above the highest ground),
## or -1 over open water. Tree crowns are ignored so animals walk under them.
## Level of the highest cell in the column that keeps rain and snow off what lies
## below (anything but air, water and leaves), -1 when there is none.
func roof_level(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	if c == null:
		return -1
	var col := ((z & MASK) << SHIFT) | (x & MASK)
	var solid := ~(c.air[col] | c.water[col] | c.leaf[col]) & all_bits
	return top_level(solid)


## Level of the highest set bit, -1 for none.
static func top_level(bits: int) -> int:
	if bits == 0:
		return -1
	var level := 0
	if bits >> 32 != 0:
		bits >>= 32
		level = 32
	if bits >> 16 != 0:
		bits >>= 16
		level += 16
	if bits >> 8 != 0:
		bits >>= 8
		level += 8
	if bits >> 4 != 0:
		bits >>= 4
		level += 4
	if bits >> 2 != 0:
		bits >>= 2
		level += 2
	if bits >> 1 != 0:
		level += 1
	return level


## The level just above the highest cell of column (x, z) that is not air or leaves, 0
## where no chunk is kept, -1 when that cell is open (unfrozen) water.
func surface_y(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	if c == null:
		return 0
	var col := ((z & MASK) << SHIFT) | (x & MASK)
	var y := top_level(~(c.air[col] | c.leaf[col]) & all_bits)
	if y < 0:
		return 0
	if c.water[col] & (1 << y) and not water_frozen:
		return -1
	return y + 1


## Notes a change by the player to the chunk of column (x, z) that is not a cell (a
## drop, a tree or bush gone, a bush's records): the chunk is kept from then on and
## saved. The generator's writes are not changes.
func note_edit(x: int, z: int) -> void:
	if not track_edits:
		return
	var c := chunk_at(x, z)
	if c != null:
		c.edited = true
		unsaved[c.key] = true


# --- Saving --------------------------------------------------------------------

## Everything kept for chunk `key`, for a save (see WorldStore): the cells, flags,
## shapes and column masks as they are, the trees with their trunk in it and their
## records (TREE_MAPS), what grows on its changed grass (turf), its bushes
## with their records (BUSH_MAPS) and what lies on its ground.
func pack_chunk(key: Vector2i) -> Dictionary:
	var c: Chunk = chunks[key]
	var tree_list := []
	var tree_lists := {}
	for name: String in TREE_MAPS:
		tree_lists[name] = []
	for at: Vector2i in tree_chunks.get(key, {}):
		tree_list.append([at, trees[at]])
		for name: String in TREE_MAPS:
			var map: Dictionary = get(name)
			if map.has(at):
				tree_lists[name].append([at, map[at]])
	var bush_lists := {}
	var cells: Dictionary = bush_chunks.get(key, {})
	for name: String in BUSH_MAPS:
		var map: Dictionary = get(name)
		var list := []
		for cell: Vector3i in cells:
			if map.has(cell):
				list.append([cell, map[cell]])
		bush_lists[name] = list
	return {"key": key, "levels": size_y, "cells": c.cells, "natural": c.natural, "shapes": c.shapes,
		"air": c.air, "water": c.water, "leaf": c.leaf, "logs": c.logs, "wild": c.wild, "sloped": c.sloped,
		"corner": c.corner, "trees": tree_list, "tree_records": tree_lists, "bushes": bush_lists, "turf": turf.get(key, {}).duplicate(), "drops": drops.get(key, []).duplicate(true)}


## True when `d` is a chunk packed by pack_chunk for a world of this height.
func can_unpack(d: Dictionary) -> bool:
	if not d.get("key") is Vector2i or d.get("levels") != size_y:
		return false
	for name in ["cells", "natural", "shapes"]:
		if not d.get(name) is PackedByteArray or d[name].size() != LAYER * size_y:
			return false
	for name in ["air", "water", "leaf", "logs", "wild", "sloped", "corner"]:
		if not d.get(name) is PackedInt64Array or d[name].size() != LAYER:
			return false
	return true


## Puts a chunk packed by pack_chunk back, final and edited, in place of what is kept
## there; false (and nothing changed) when it does not fit (see can_unpack).
func unpack_chunk(d: Dictionary) -> bool:
	if not can_unpack(d):
		return false
	var key: Vector2i = d.key
	remove_chunk(key)
	var c := Chunk.new()
	c.key = key
	for name in ["cells", "natural", "shapes", "air", "water", "leaf", "logs", "wild", "sloped", "corner"]:
		c.set(name, d[name])
	c.edited = true
	c.final = true
	chunks[key] = c
	if key == _last_key:
		_last = c
	for t: Array in d.get("trees", []):
		add_tree(t[0].x, t[0].y, t[1])
	var records: Dictionary = d.get("tree_records", {})
	for name: String in TREE_MAPS:
		var map: Dictionary = get(name)
		for t: Array in records.get(name, []):
			map[t[0]] = t[1]
	var lists: Dictionary = d.get("bushes", {})
	for name: String in BUSH_MAPS:
		var map: Dictionary = get(name)
		for b: Array in lists.get(name, []):
			if name == "bushes":
				add_bush(b[0], b[1])
			else:
				map[b[0]] = b[1]
	var grown: Dictionary = d.get("turf", {})
	if not grown.is_empty():
		turf[key] = grown.duplicate()
	var on_ground: Array = d.get("drops", [])
	if not on_ground.is_empty():
		drops[key] = on_ground
	return true
