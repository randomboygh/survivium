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
## This script keeps the cells and what stands and lies on them (chunks, trees, bushes,
## drops, turf, trails, blockers) and saves and restores a chunk; WorldData extends it with
## the shapes of natural ground and what a body meets.


const Mat := preload("res://src/shared/content/materials.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const Items := preload("res://src/shared/content/items.gd")
const Content := preload("res://src/shared/content/content.gd")
## Size of a cell in world units; a world unit is 16 px on screen.
const CELL := 0.5
## Chunk size in cells: the unit the world is generated, kept, meshed and streamed in.
const CHUNK := 16
const SHIFT := 4
const MASK := CHUNK - 1
## Columns in a chunk: a level of a chunk is this many cells.
const LAYER := CHUNK * CHUNK
## A column's biome not known (Biomes.NONE; world/ loads no content but materials and
## trees, so the number is kept here too).
const NO_BIOME := 255
## Open water lies this far up its top cell (4 px under the ground beside it). Ice
## fills the cell to the top.
const WATER_TOP := 0.5

var size_y: int
## The top cell of the sea, about five twelfths of the way up (12 of 40, 20 of 48).
var sea_level := 12
## Levels above the sea from which snow lies all year, on the high mountains (see
## peak_snow); the world shader draws it from the same line (`snow_line`).
const SNOW_LINE := 18

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
## On a water cell: the murky water of a swamp, and the murkier water of a bog, which
## is waded slower (see Body); both lie like water in every other way.
const BOG := 4
const SWAMP := 8

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
## A world laid out by hand can set what grows on its grass in place of the noises: a
## static func (x, z) -> one of Grass.GROW_* or 0 (the noises decide), see TestGround.
var grows := Callable()
## Things standing on cells that bodies do not pass (placed chests and stations, see
## Props): cell -> the box (AABB) the thing takes in it, in cell units from the cell's
## corner; a box higher than 1 fills the same part of the cell over it too.
var blockers := {}
## Things lying on the ground (the logs, branches and seeds of a felled tree, what was
## thrown away, a sack left by a death), by chunk (Vector2i): [kind, position in world
## units, angle about y, data] each. `kind` is an item id (a bare name is a core item,
## see Items) or Items.SACK; `data` is how many items for an item ({"n", "worn"} for a
## worn tool, see Inventory), the stacks ([[id, count]...]) for a sack. A chunk with any
## is kept as an edited one.
var drops := {}
## Columns walked over in the snow: the time (Clock.now) a body last left each one,
## by Vector2i(x, z), so a trail is easier to walk (see Body). Not saved: snow
## covers trails within half a day anyway.
var trodden := {}
## Trails are forgotten once there are this many (the old ones first).
const TRAILS := 4096
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
	## The biome of each column (an index of Biomes, Biomes.NONE where it is not known:
	## a chunk of the test world, or one saved before biomes were kept), written by the
	## generator: what tints its ground and water and which plants grow on it.
	var biome := PackedByteArray()
	## Changed by the player: kept when the player goes far away.
	var edited := false
	## Done by the generator: its later stages of the chunks around write nothing here
	## (see WorldGen).
	var final := false


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


## The biome of column x, z (an index of Biomes), NO_BIOME when its chunk is not kept
## or did not know it (see Chunk.biome).
func biome_at(x: int, z: int) -> int:
	var c: Chunk = chunk_at(x, z)
	return NO_BIOME if c == null else c.biome[col_of(x, z)]


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
	c.biome.resize(LAYER)
	c.biome.fill(NO_BIOME)
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


## True when cell x, y, z is the water of a bog (see BOG).
func is_bog(x: int, y: int, z: int) -> bool:
	return murk(x, y, z) == 2


## How murky the water of cell x, y, z is: 0 clear, 1 a swamp's, 2 a bog's (see BOG).
func murk(x: int, y: int, z: int) -> int:
	if y < 0 or y >= size_y:
		return 0
	var c := chunk_at(x, z)
	if c == null:
		return 0
	var n := c.natural[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)]
	return 2 if n & BOG else (1 if n & SWAMP else 0)


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
## world the value is 0 (air, no shape), below it `below`. `y0`..`y1` (exclusive) gives
## a part of the levels, so a copy can be made in parts and put together.
func padded(shapes: bool, below: int, x0: int, z0: int, x1: int, z1: int, y0 := -1, y1 := -2) -> PackedByteArray:
	if y1 == -2:
		y1 = size_y + 1
	var width := x1 - x0
	var out := PackedByteArray()
	var rows := z1 - z0
	var below_rows := PackedByteArray()
	below_rows.resize(width * rows)
	below_rows.fill(below)
	if y0 < 0:
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
	for y in range(maxi(y0, 0), mini(y1, size_y)):
		var base := y << 8
		for p: Array in parts:
			var n: int = p[2]
			if p[0] == null:
				out.append_array(air.slice(0, n))
			else:
				var src: PackedByteArray = p[0]
				var a: int = base + p[1]
				out.append_array(src.slice(a, a + n))
	if y1 > size_y:
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


# --- What stands and lies on the cells -------------------------------------------


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


## Notes that a body walked off column (x, z) in the snow at time `now` (days).
func tread(x: int, z: int, now: float) -> void:
	if trodden.size() >= TRAILS:
		var old := now - 1.0
		for col: Vector2i in trodden.keys():
			if trodden[col] < old:
				trodden.erase(col)
		if trodden.size() >= TRAILS:
			trodden.clear()
	trodden[Vector2i(x, z)] = now


## How fresh the trail in column (x, z) is at time `now`: 1 just walked, 0 after
## `life` days or never.
func trail(x: int, z: int, now: float, life: float) -> float:
	var t: float = trodden.get(Vector2i(x, z), -INF)
	return clampf(1.0 - (now - t) / life, 0.0, 1.0)


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


## How much snow lies all year at height `y` (in cells, a top or the feet on it), 0..1:
## none below the snow line, full two levels above it.
func peak_snow(y: float) -> float:
	return clampf((y - sea_level - SNOW_LINE) / 2.0, 0.0, 1.0)


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


# --- Saving ----------------------------------------------------------------------


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
		"corner": c.corner, "biome": c.biome, "trees": tree_list, "tree_records": tree_lists, "bushes": bush_lists, "turf": turf.get(key, {}).duplicate(), "drops": drops.get(key, []).duplicate(true)}


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
	var biomes: Variant = d.get("biome")
	if biomes is PackedByteArray and biomes.size() == LAYER:
		c.biome = biomes
	else:
		c.biome.resize(LAYER)
		c.biome.fill(NO_BIOME)
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
	# Ids saved before a record was renamed (its `was`) are read as the record's id now:
	# the crops sown, the drops and the stacks in a sack.
	var grown: Dictionary = d.get("turf", {})
	if not grown.is_empty():
		var sown := {}
		for cell in grown:
			var what: Variant = grown[cell]
			sown[cell] = Content.canon("plants", what) if what is String and what != "" else what
		turf[key] = sown
	var on_ground: Array = d.get("drops", [])
	if not on_ground.is_empty():
		for drop in on_ground:
			if drop is Array and not drop.is_empty() and drop[0] is String:
				drop[0] = Items.canon(drop[0])
				if drop.size() > 3 and drop[3] is Array:
					for s in drop[3]:
						if s is Array and not s.is_empty() and s[0] is String:
							s[0] = Items.canon(s[0])
		drops[key] = on_ground
	return true
