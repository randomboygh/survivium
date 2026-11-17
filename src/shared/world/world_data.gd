extends "res://src/shared/world/world_cells.gd"
## The world with the shapes of its natural ground: slopes and diagonal corners worked
## out from the cells around (`update_shapes`, a column at a time, after edits), the
## flat triangles of a slope (`top_height`, `ground_height`), the cut and filled
## corners a body walks around, and what a body meets in a cell (`blocks_body`,
## `blocks_part`, `ground_part`). The cells themselves are kept by world_cells.gd.


## True for a world with the slopes of before the blocky relief (the world setting
## `slopes` 1, see LandLayout.DEFAULT_SETTINGS): a sloping top goes down a level in its
## cell, a smooth curved patch (surface_patch), and cut and
## filled corners take a triangle half a cell along each side. False (the default) for
## the flat triangles, one-level corners and half-blocks. Set by WorldGen.
var old_slopes := false
## True for a world with the world setting `slopes` 1: the shapes are the blocky relief's
## (one level a cell, straight diagonals, flat triangles) but drawn soft, as the old
## slopes looked: every natural slope bends level at its brow and foot, edges stay sharp
## (ChunkMesher Job.soft). Set by WorldGen.
var soft_slopes := false
## Surfaces of sloping tops looked at lately with old slopes (see surface_patch), by
## cell; emptied whenever shapes change.
var _patches := {}
## Corner bits of a slope mask: which corners of the cell's top are at full height.
## North is -z. FULL is a whole cube.
const NW := 1
const NE := 2
const SE := 4
const SW := 8
const FULL := 15
## Horizontal neighbours N, S, W, E.
const SIDES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
## Low corners of a top for its low sides N, S, W, E (1, 2, 4, 8): each low side takes
## its two corners down.
const LOW_CORNERS := [0, NW | NE, SE | SW, FULL, NW | SW, FULL & ~SE, FULL & ~NE, FULL, NE | SE, FULL & ~SW,
	FULL & ~NW, FULL, FULL, FULL, FULL, FULL]
## The side a ridge's tip lower on three sides (by `lows`: 1 N, 2 S, 4 W, 8 E) ends
## at: the one across from its higher side.
const TIP_END := {7: 4, 11: 8, 13: 1, 14: 2}
## Way from a cell to its corners NW, NE, SE, SW (corner k is bit 1 << k of a mask).
const CORNER_DIRS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
## The eight columns round one: beside it, then across its corners.
const AROUND: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

## Level of a single-bit mask, by the bit's remainder modulo 67 (distinct for 2^0..2^63).
static var _bit_levels := PackedByteArray()


# --- Shapes of natural ground ----------------------------------------------------


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
	# Inner corners (only the column across lower) of soft slopes, checked once all the
	# slopes are done.
	var inner: Array[Vector4i] = []
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
				if old_slopes:
					var old := _old_slope(lows, j, bit, low, diag, x, y, z)
					if old != 0:
						shapes[i] = old
						c.sloped[col] |= bit
					continue
				var mask: int = LOW_CORNERS[lows]
				# With soft slopes the tip of a ridge a cell wide (lower on three sides) ramps
				# down to its free end instead of standing up as a post.
				if soft_slopes and mask == FULL and lows != 15 and lows != 3 and lows != 12:
					mask = LOW_CORNERS[TIP_END[lows]]
				# A corner with only the column across it lower goes down too, where both
				# columns beside it may slope (and so go down there as well).
				for k in 4:
					if mask & (1 << k) or low[j + diag[k]] & bit == 0:
						continue
					var o: Vector2i = CORNER_DIRS[k]
					if _can_slope(x + o.x, y, z) and _can_slope(x, y, z + o.y):
						mask |= 1 << k
						if soft_slopes and lows == 0:
							inner.append(Vector4i(x, y, z, k))
				# No slope steeper than 45 degrees: a corner the column across drops two levels
				# or more at (open there and a level under) stays up, and a top that keeps
				# only two opposite corners down that way stays a cube (its corner is cut
				# instead, a straight wall on the diagonal).
				if soft_slopes and mask != 0:
					for k in 4:
						if mask & (1 << k) == 0:
							continue
						var d := j + diag[k]
						var od := air[d] | water[d]
						if od & (od << 1) & bit:
							mask &= ~(1 << k)
					if mask == (NW | SE) or mask == (NE | SW):
						mask = 0
				# All four corners down (a ridge one cell wide): it stays a cube.
				if mask != 0 and mask != FULL:
					shapes[i] = mask
					c.sloped[col] |= bit
	# An inner corner goes down only where the tops beside it go down there too: beside
	# a top kept whole by the 45 degree limit it stays up (and the cell a cube).
	for v in inner:
		var o: Vector2i = CORNER_DIRS[v.w]
		var a := _shape(v.x + o.x, v.y, v.z)
		var b := _shape(v.x, v.y, v.z + o.y)
		if a & 15 & (1 << (v.w ^ 1)) != 0 and b & 15 & (1 << (3 - v.w)) != 0:
			continue
		var c := chunk_at(v.x, v.z)
		var col := ((v.z & MASK) << SHIFT) | (v.x & MASK)
		var i := (v.y << 8) | col
		var mask := c.shapes[i] & ~(1 << v.w)
		c.shapes[i] = mask
		if mask & 15 == 0:
			c.sloped[col] &= ~(1 << v.y)


## Works out the cut and filled corners of the columns x0..x1, z0..z1 (ends
## exclusive) from the cells and slopes around them (see corner_cut, corner_fill).
func update_corners(x0: int, z0: int, x1: int, z1: int) -> void:
	if old_slopes:
		_old_update_corners(x0, z0, x1, z1)
		return
	var mk := _masks(x0, z0, x1, z1)
	var wl: int = mk.wl
	var hl: int = mk.hl
	var air: PackedInt64Array = mk.air
	var water: PackedInt64Array = mk.water
	var open: PackedInt64Array = mk.open
	var ground: PackedInt64Array = mk.ground
	var wild: PackedInt64Array = mk.wild
	var sloped: PackedInt64Array = mk.sloped
	var low: PackedInt64Array = mk.low
	var side_x := PackedInt32Array([-1, 1, 1, -1])
	var side_z := PackedInt32Array([-wl, -wl, wl, wl])
	var found := PackedInt64Array([0, 0, 0, 0])
	for fills in 2:
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
					found[k] = 0
					var cx := j + side_x[k]
					var cz := j + side_z[k]
					var cd := cx + side_z[k]
					var wild4 := wild[j] & wild[cx] & wild[cz] & wild[cd]
					if wild4 == 0:
						continue
					if fills == 0:
						var cut := gr & wild4 & (air[cx] & air[cz] & air[cd] | water[cx] & water[cz] & water[cd])
						if cut == 0:
							continue
						# A slope is cut only at a corner where it is low, and where the ground
						# drops further than a level beside it (else the slopes meet in a hip).
						var sl := cut & sloped[j]
						var drop := (air[cx] | water[cx]) & ~low[cx] | (air[cz] | water[cz]) & ~low[cz] \
							| (air[cd] | water[cd]) & ~low[cd]
						while sl != 0:
							var bit := sl & -sl
							sl ^= bit
							var i := (level_of(bit) << 8) | col
							if c.shapes[i] & (1 << k) == 0 or drop & bit == 0:
								cut &= ~bit
						# The runs of such cells whose top has an open cell above.
						found[k] = _spread(cut, cut & ~(cut >> 1) & ((open[j] >> 1) | top_bit), -1)
					else:
						var fill := aw & wild4 & ground[cx] & ground[cz] & ground[cd] & ~sloped[cx] & ~sloped[cz]
						if fill == 0:
							continue
						# Ground beside that is open round its corner facing this cell (so it
						# is cut there) takes the diagonal: both would make a saw.
						var bx := j - side_x[k]
						var bz := j - side_z[k]
						fill &= ~(air[j] & air[bx] & air[bx + side_z[k]] | water[j] & water[bx] & water[bx + side_z[k]] \
							| air[j] & air[bz] & air[bz + side_x[k]] | water[j] & water[bz] & water[bz + side_x[k]])
						# The runs of such cells standing on something that hides what is behind it.
						found[k] = _spread(fill, fill & ~(fill << 1) & ((~open[j] << 1) | 1), 1)
				# One corner of a cell at most: a cell cut or filled at two is left whole.
				var all_cut := 0
				for k in 4:
					var only := found[k] & ~(found[(k + 1) & 3] | found[(k + 2) & 3] | found[(k + 3) & 3])
					_mark(c, col, only, 16 << k)
					all_cut |= only
				if fills == 0 and all_cut != 0:
					_floor_slopes(c, col, x, z, j, (all_cut & ~(all_cut << 1)) >> 1 & ground[j] & wild[j] & ~all_cut, mk)


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


## The ground cells `floors` of column (x, z) (index `j` in the masks `mk`), each under the
## lowest of a run of cut cells: the cut shows their top, which slopes as an open top
## would (the rules of update_slopes on its level), so a slope cut by a diagonal goes on
## down into the cut instead of standing a level over the slopes beside. Only the
## triangle under the cut is drawn and walked on; the low corners are kept in the
## cell's shape (bits 0..3) and the cell marked in Chunk.corner.
func _floor_slopes(c: Chunk, col: int, x: int, z: int, j: int, floors: int, mk: Dictionary) -> void:
	var low: PackedInt64Array = mk.low
	var wl: int = mk.wl
	var diag := PackedInt32Array([-wl - 1, -wl + 1, wl + 1, wl - 1])
	while floors != 0:
		var bit := floors & -floors
		floors ^= bit
		var y := level_of(bit)
		var i := (y << 8) | col
		if c.natural[i] != WILD or not Mat.can_slope(c.cells[i]):
			continue
		var lows := (1 if low[j - wl] & bit else 0) | (2 if low[j + wl] & bit else 0) | (4 if low[j - 1] & bit else 0) \
			| (8 if low[j + 1] & bit else 0)
		var mask: int = LOW_CORNERS[lows]
		for k in 4:
			if mask & (1 << k) or low[j + diag[k]] & bit == 0:
				continue
			var o: Vector2i = CORNER_DIRS[k]
			if _can_slope(x + o.x, y, z) and _can_slope(x, y, z + o.y):
				mask |= 1 << k
		if mask != 0 and mask != FULL:
			c.shapes[i] = c.shapes[i] | mask
			c.corner[col] |= bit


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
## level lower (or water), both corners of that side going down; a corner goes down
## too where only the column across it is lower and both columns beside it may slope.
## A top with every corner down (a ridge a cell wide), stone, built blocks and drops of
## two levels or more stay whole cubes: those are cliffs.
func slope_mask(x: int, y: int, z: int) -> int:
	if y < 0 or y >= size_y:
		return FULL
	refresh_shapes()
	var c := chunk_at(x, z)
	if c == null:
		return FULL
	return FULL & ~(c.shapes[(y << 8) | ((z & MASK) << SHIFT) | (x & MASK)] & 15)


# --- Slope surfaces --------------------------------------------------------------


## A sloping top is two flat triangles, the cell split along one diagonal, each with
## its corners at full height or a level down (see slope_mask): a ramp is one plane, a
## corner of a hill a hip (both triangles falling away from the crease to its one high
## corner), the inside corner of a hill a valley. Where the outline of a hill runs
## diagonally its corners are chamfers instead: the crease runs past the odd corner,
## one triangle level and the other falling from the odd corner. A top cut at a corner
## (see corner_cut) keeps the triangle away from it. The mesher splits its copy of the
## cells the same way (split_ne_sw); tests check that both agree.


## True when a top of shape `s` (Chunk.shapes) is split along its diagonal NE-SW (else
## NW-SE); `sn`, `ss`, `sw`, `se` are the shapes of the cells beside it N, S, W, E on
## its level, `above` that of the cell above. A cut corner takes the diagonal across
## it, as does the cut above a sloping top under it. One corner unlike the other
## three is a hip or a valley (the crease through it) where a ramp goes on beside it
## at that corner, else a chamfer (the crease across it). Two opposite corners down
## make a ridge between the high ones.
static func split_ne_sw(s: int, sn: int, ss: int, sw: int, se: int, above := 0) -> bool:
	var cut := s >> 4
	if cut == 0 and s & 15 != 0:
		# The ground under a cut (see _floor_slopes): the cut's diagonal.
		cut = above >> 4
	if cut != 0:
		return cut & (NW | SE) != 0
	var lows := s & 15
	var odd: int = ODD_CORNER[lows]
	if odd < 0:
		return lows == NW | SE
	var o: Vector2i = CORNER_DIRS[odd]
	var through := _ramp(sw if o.x < 0 else se) or _ramp(sn if o.y < 0 else ss)
	# The crease through corner NW or SE is the diagonal NW-SE.
	return through != (odd == 0 or odd == 2)


## The corner of a top with one corner unlike the other three, by its low corners; -1
## for none.
const ODD_CORNER := [-1, 0, 1, -1, 2, -1, -1, 3, 3, -1, -1, 2, -1, 1, 0, -1]


## True when shape `s` is a straight ramp: two corners down along one side.
static func _ramp(s: int) -> bool:
	var lows := s & 15
	return s < 16 and (lows == NW | NE or lows == SE | SW or lows == NW | SW or lows == NE | SE)


## Height above its level of the top of shape `s` split as `ne_sw` says, at (fx, fz)
## inside the cell (0..1): on the plane of the triangle the point lies in.
static func top_height(s: int, ne_sw: bool, fx: float, fz: float) -> float:
	var h0 := 0.0 if s & NW else 1.0
	var h1 := 0.0 if s & NE else 1.0
	var h2 := 0.0 if s & SE else 1.0
	var h3 := 0.0 if s & SW else 1.0
	if ne_sw:
		if fx + fz <= 1.0:
			return h0 + (h1 - h0) * fx + (h3 - h0) * fz
		return h2 + (h2 - h3) * (fx - 1.0) + (h2 - h1) * (fz - 1.0)
	if fx >= fz:
		return h0 + (h1 - h0) * fx + (h2 - h1) * fz
	return h0 + (h2 - h3) * fx + (h3 - h0) * fz


## Whether the top of cell (x, y, z) is split along NE-SW (see split_ne_sw).
func split_at(x: int, y: int, z: int) -> bool:
	return split_ne_sw(_shape(x, y, z), _shape(x, y, z - 1), _shape(x, y, z + 1), _shape(x - 1, y, z),
		_shape(x + 1, y, z), _shape(x, y + 1, z) if _surface_ground(get_cell(x, y + 1, z)) else 0)


## Heights of the corners NW, NE, SE, SW of the top of the ground cell (x, y, z) above
## its level: 1 high, 0 low.
func corner_heights(x: int, y: int, z: int) -> PackedInt32Array:
	var s := _shape(x, y, z)
	# Old slopes: -1 where the corner goes on down into the cell below (no world makes
	# such corners now, see _old_update_corners; the mesher reads them the same way).
	var below := _shape(x, y - 1, z) if old_slopes and s & 15 else 0
	var h := PackedInt32Array([1, 1, 1, 1])
	for k in 4:
		if s & (1 << k):
			h[k] = -1 if below & (1 << k) else 0
	return h


## Height of the surface of the sloping cell (x, y, z) at (fx, fz) inside it, above its
## level.
func surface_height(x: int, y: int, z: int, fx: float, fz: float) -> float:
	if old_slopes:
		return patch_height(surface_patch(x, y, z), fx, fz)
	refresh_shapes()
	return top_height(_shape(x, y, z), split_at(x, y, z), fx, fz)


## The highest level of column (x, z) that is not air or leaves, -1 for none.
func _top(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	if c == null:
		return -1
	var col := ((z & MASK) << SHIFT) | (x & MASK)
	return top_level(~(c.air[col] | c.leaf[col]) & all_bits)


## Height of the ground a walker stands on at (x, z), in cells: the top of the highest
## ground there, following slopes and cut or filled corners. -1 over open water.
## Every animal step and body step asks it: the cells and shapes of the column are read
## from its chunk directly (the rules of corner_fills, corner_cuts and slope_mask).
func ground_height(x: float, z: float) -> float:
	if old_slopes:
		return _old_ground_height(x, z)
	var cx := floori(x)
	var cz := floori(z)
	var fx := x - cx
	var fz := z - cz
	refresh_shapes()
	var c := chunk_at(cx, cz)
	if c == null:
		return 0.0
	var col := ((cz & MASK) << SHIFT) | (cx & MASK)
	var top := top_level(~(c.air[col] | c.leaf[col]) & all_bits)
	# The corner triangles the point is in: only those can be cut or filled. A filled
	# corner needs ground beside it at its own level, so then nothing is to stand on
	# above the highest cell of this column and of the three beside such a corner.
	var inside := corners_at(fx, fz)
	if c.corner[col] != 0:
		for k in 4:
			if inside & (1 << k):
				var d: Vector2i = CORNER_DIRS[k]
				top = maxi(maxi(top, _top(cx + d.x, cz)), maxi(_top(cx, cz + d.y), _top(cx + d.x, cz + d.y)))
	var cells := c.cells
	var shapes := c.shapes
	for y in range(top, -1, -1):
		var i := (y << 8) | col
		var m := cells[i]
		var corner := shapes[i] >> 4 & inside
		if m == Mat.AIR or m == Mat.LEAVES or m == Mat.WATER:
			if corner and m != Mat.LEAVES:
				return y + 1.0
			if m == Mat.WATER:
				return y + ice_top(cx, y, cz) if frozen_at(cx, cz) else -1.0
			continue
		if corner:
			var d: Vector2i = CORNER_DIRS[level_of(corner)]
			if get_cell(cx + d.x, y, cz) == Mat.WATER and not frozen_at(cx + d.x, cz):
				return -1.0
			continue
		if not forms.is_empty():
			var f := form_at(cx, y, cz)
			if f != FORM_CUBE:
				return y + form_top(f, fx, fx, fz, fz)
		if shapes[i] & 15 == 0:
			return y + 1.0
		return y + top_height(shapes[i], split_at(cx, y, cz), fx, fz)
	return 0.0


## Height above its level of the top of a built block of form `f` (see forms) under the
## part ax..bx, az..bz (0..1) of its cell, the highest point there: a ramp rises
## straight from its low side to the side it faces, stairs are two steps half a level
## each, a cube and an upturned ramp are flat on top.
static func form_top(f: int, ax: float, bx: float, az: float, bz: float) -> float:
	var kind := f & 3
	if kind == FORM_CUBE or kind == FORM_UPPER:
		return 1.0
	# How far toward the high side the part reaches, 0..1.
	var t := 0.0
	match f >> 2 & 3:
		0:
			t = 1.0 - az
		1:
			t = bx
		2:
			t = bz
		_:
			t = 1.0 - ax
	t = clampf(t, 0.0, 1.0)
	if kind == FORM_RAMP:
		return t
	return 1.0 if t > 0.5 else 0.5


## Mask of the corners (NW, NE, SE, SW) whose triangle (half the cell, cut off by a
## diagonal) holds (fx, fz) inside a cell: two of them, both on a diagonal.
static func corners_at(fx: float, fz: float) -> int:
	return (NW if fx + fz < 1.0 else 0) | (SE if fx + fz > 1.0 else 0) | (NE if fx > fz else 0) \
		| (SW if fz > fx else 0)


## True when point (fx, fz) inside a cell lies in the triangle of one of the corners
## `cuts` takes off (see in_corner; old slopes: half a cell along each side).
func in_cuts(cuts: int, fx: float, fz: float) -> bool:
	if not old_slopes:
		return cuts & corners_at(fx, fz) != 0
	var q := corner_at(fx, fz)
	return cuts & (1 << q) != 0 and _old_in_corner(q, fx, fx, fz, fz)


## True when the box ax..bx, az..bz inside a cell (0..1) lies wholly in the triangle that
## a cut takes off corner k (half the cell, up to the diagonal across it), touching its
## edge at most.
static func in_corner(k: int, ax: float, bx: float, az: float, bz: float, old := false) -> bool:
	if old:
		return _old_in_corner(k, ax, bx, az, bz)
	match k:
		0:
			return bx + bz <= 1.0
		1:
			return ax >= bz
		2:
			return ax + az >= 1.0
	return az >= bx


## True when the box ax..bx, az..bz inside a cell (0..1) reaches into the triangle that
## a fill adds at corner k.
static func touches_corner(k: int, ax: float, bx: float, az: float, bz: float, old := false) -> bool:
	if old:
		return _old_touches_corner(k, ax, bx, az, bz)
	match k:
		0:
			return ax + az < 1.0
		1:
			return bx > az
		2:
			return bx + bz > 1.0
	return bz > ax


## True when corner k of the cell at (x, y, z) is cut off in plan, so cliffs, banks and
## creeks turn diagonally instead of at right angles: wild ground loses the half of the
## cell beyond the diagonal across corner k (a half-block) where both sides and the
## diagonal are the same open wild cells (all air or all water), and the cell above is
## open or cut there too. A slope is cut only at a corner where it is low and the
## ground drops more than a level beside it. A cell is cut at one corner at most. The
## ground under the lowest cut cell shows in the cut and slopes there as an open top
## would (see _floor_slopes).
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


## True when the open cell at (x, y, z) gets ground in the half beyond the diagonal
## across corner k: the inner corner where both sides and the diagonal are wild ground,
## the sides whole cubes, standing on ground or on the same fill below; not where a
## side is open round its own corner facing this cell (the side is cut there, and both
## would make a saw). A cell is filled at one corner at most.
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
	return _surface_ground(get_cell(x, y, z))


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


# --- What a body meets -----------------------------------------------------------


## True when a walking body cannot be in this cell: solid, frozen water, a thing
## standing in it (see blockers) or where no chunk is kept. Open water is waded and
## swum through, a crown's leaves walked through (only the trunk stops a body: a crown
## hangs its cells lower than its drawn leaves show, and a forest would be a wall).
func blocks_body(x: int, y: int, z: int) -> bool:
	if chunk_at(x, z) == null:
		return true
	if not blockers.is_empty() and blocker_top(x, y, z) > 0.0:
		return true
	return _cell_blocks(x, y, z)


## Height of frozen water cell (x, y, z) over its floor, in cells: ice lies where the
## water stood, so the shore beside is not lower than it, and fills cells under water.
func ice_top(x: int, y: int, z: int) -> float:
	return 1.0 if get_cell(x, y + 1, z) == Mat.WATER else WATER_TOP


func _cell_blocks(x: int, y: int, z: int) -> bool:
	var m := get_cell(x, y, z)
	if m == Mat.WATER:
		return frozen_at(x, z)
	return m != Mat.LEAVES and Mat.is_solid(m)


## True when a body taking the part ax..bx, az..bz (0..1) of the cell at (x, y, z) is
## blocked, as blocks_body says for whole cells. A cut corner holds what is beside it
## (air or water); a filled corner is ground.
func blocks_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		var cuts := corner_cuts(x, y, z)
		for k in 4:
			if cuts & (1 << k) and in_corner(k, ax, bx, az, bz, old_slopes):
				var o: Vector2i = CORNER_DIRS[k]
				return blocks_body(x + o.x, y, z)
		return true
	if _fill_touched(x, y, z, ax, bx, az, bz):
		return true
	if chunk_at(x, z) == null:
		return true
	if not blockers.is_empty() and blocker_part(x, y, z, ax, bx, az, bz) > 0.0:
		return true
	if not trees.is_empty() and _bark_touched(x, y, z, ax, bx, az, bz):
		return true
	return _cell_blocks(x, y, z)


## Whether the part ax..bx, az..bz (0..1) of air cell (x, y, z) holds the bark of a trunk
## beside it thicker than its own cell (see Growth.trunk_box): one beside or across a
## corner (a trunk three cells thick fills the cells round it, the corners too), its
## bark an octagon with the corners cut by a quarter of its width, as it is drawn
## (TrunkMesher._bark).
func _bark_touched(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if get_cell(x, y, z) != Mat.AIR:
		return false
	for o: Vector2i in AROUND:
		var col := Vector2i(x + o.x, z + o.y)
		var species: int = trees.get(col, -1)
		if species < 0 or species >= Trees.SPECIES.size() or get_cell(col.x, y, col.y) != Mat.LOG:
			continue
		var k := 0
		while k < 64 and get_cell(col.x, y - k - 1, col.y) == Mat.LOG:
			k += 1
		var box := Growth.trunk_box(species, col, k, Growth.young_at(self, col.x, y - k, col.y))
		# The box in texels of this cell.
		box.position += o * 8
		# The point of the part nearest the trunk's middle: in the octagon if any is.
		var mid := Vector2(box.get_center())
		var near := Vector2(clampf(mid.x, ax * 8.0, bx * 8.0), clampf(mid.y, az * 8.0, bz * 8.0))
		var off := (near - mid).abs()
		var half := Vector2(box.size) * 0.5
		if off.x < half.x and off.y < half.y and (half.x - off.x) + (half.y - off.y) > mini(box.size.x, box.size.y) / 4:
			return true
	return false


## How high above the floor of cell (x, y, z) the top of a thing standing there is
## (see blockers), at most 1; 0 when none stands in it.
func blocker_top(x: int, y: int, z: int) -> float:
	return blocker_part(x, y, z, 0.0, 1.0, 0.0, 1.0)


## As blocker_top, for the part ax..bx, az..bz (0..1) of the cell only: 0 when the
## thing stands in another part of it.
func blocker_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> float:
	var c := Vector3i(x, y, z)
	var box = blockers.get(c)
	var base := 0.0
	if box == null:
		c.y -= 1
		box = blockers.get(c)
		base = 1.0
	if box == null:
		return 0.0
	if box is Array:
		# The steps of stairs (see Placed.footprint): the highest under the part.
		var top := 0.0
		for b: AABB in box:
			if ax < b.end.x and bx > b.position.x and az < b.end.z and bz > b.position.z:
				top = maxf(top, clampf(b.end.y - base, 0.0, 1.0))
		return top
	var b: AABB = box
	if not b.has_volume() or ax >= b.end.x or bx <= b.position.x or az >= b.end.z or bz <= b.position.z:
		return 0.0
	return clampf(b.end.y - base, 0.0, 1.0)


## True when the part ax..bx, az..bz (0..1) of the cell at (x, y, z) stands on its top:
## solid there (not leaves, which a body goes through), not only its cut corner, ground
## filling its corner, ice, or a thing standing there (see blockers).
func ground_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		var cuts := corner_cuts(x, y, z)
		for k in 4:
			if cuts & (1 << k) and in_corner(k, ax, bx, az, bz, old_slopes):
				return false
		return true
	var m := get_cell(x, y, z)
	return m != Mat.LEAVES and Mat.is_solid(m) or m == Mat.WATER and frozen_at(x, z) \
		or _fill_touched(x, y, z, ax, bx, az, bz) or not blockers.is_empty() and blocker_part(x, y, z, ax, bx, az, bz) > 0.0


func _fill_touched(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	var fills := corner_fills(x, y, z)
	for k in 4:
		if fills & (1 << k) and touches_corner(k, ax, bx, az, bz, old_slopes):
			return true
	return false


# --- Old slopes (the world setting `slopes` 1, see old_slopes) --------------------


## The low corners of an old slope's top (see old_slopes) for its low sides `lows` (N,
## S, W, E as 1, 2, 4, 8) at bit `bit` of column j of the masks (`low`, `diag` as in
## update_slopes): a ramp to one side, an outer corner to two neighbouring sides, an
## inner corner where only a diagonal neighbour is lower; 0 for a whole cube.
func _old_slope(lows: int, j: int, bit: int, low: PackedInt64Array, diag: PackedInt32Array, x: int, y: int,
		z: int) -> int:
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
	return FULL & ~mask


## Old slopes: the full-height corners for the low sides N, S, W, E (1, 2, 4, 8) of a
## cell; FULL where it stays a cube: no low side, or two opposite ones.
const RAMPS := [FULL, SE | SW, NW | NE, FULL, NE | SE, SE, NE, FULL, NW | SW, SW, NW,
	FULL, FULL, FULL, FULL, FULL]


## Old slopes: works out the cut and filled corners of the columns x0..x1, z0..z1 (ends
## exclusive). A cut or fill takes a triangle half a cell along each side; a cell may
## have several. A slope goes down one level in its cell, never two (user 2026-11-18):
## where the ground beside drops further the corner is cut or meets a step.
func _old_update_corners(x0: int, z0: int, x1: int, z1: int) -> void:
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


## A sloping top is one smooth surface over its cell, a bicubic patch through the
## heights of its four corners (1 high, 0 low; -1, down into the cell below, is no
## longer made) with slopes there worked out from the corners of the tops beside it
## (see patch_tangent): a ramp between level ground starts and ends level and is
## steepest in the middle, a long slope stays straight, and tops that share a corner
## meet there at the same height and slope. The patch is 12 numbers: the heights of the
## corners NW, NE, SE, SW above the cell's level, then their slopes along x, then
## along z. The mesher builds the same patch from its copy of the cells
## (OldSlopeMesher.patch); tests check that both agree.
const PATCH_CI := [0, 1, 1, 0]
const PATCH_CJ := [0, 0, 1, 1]


## Height above the cell's level of patch `p` at (u, v) inside the cell, 0..1.
static func patch_height(p: PackedFloat32Array, u: float, v: float) -> float:
	# The corners k = 0..3 lie at (i, j) = PATCH_CI/CJ[k]: (0,0), (1,0), (1,1), (0,1),
	# summed in that order (locals, not arrays: this runs for every body step on a slope).
	var au0 := 1.0 - u * u * (3.0 - 2.0 * u)
	var au1 := u * u * (3.0 - 2.0 * u)
	var av0 := 1.0 - v * v * (3.0 - 2.0 * v)
	var av1 := v * v * (3.0 - 2.0 * v)
	var bu0 := u * (1.0 - u) * (1.0 - u)
	var bu1 := u * u * (u - 1.0)
	var bv0 := v * (1.0 - v) * (1.0 - v)
	var bv1 := v * v * (v - 1.0)
	var h := 0.0
	h += p[0] * au0 * av0 + p[4] * bu0 * av0 + p[8] * au0 * bv0
	h += p[1] * au1 * av0 + p[5] * bu1 * av0 + p[9] * au1 * bv0
	h += p[2] * au1 * av1 + p[6] * bu1 * av1 + p[10] * au1 * bv1
	h += p[3] * au0 * av1 + p[7] * bu0 * av1 + p[11] * au0 * bv1
	return h


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


## Old slopes: ground_height with curved patches and half-cell corner triangles.
func _old_ground_height(x: float, z: float) -> float:
	var cx := floori(x)
	var cz := floori(z)
	var fx := x - cx
	var fz := z - cz
	refresh_shapes()
	var c := chunk_at(cx, cz)
	if c == null:
		return 0.0
	var col := ((cz & MASK) << SHIFT) | (cx & MASK)
	var top := top_level(~(c.air[col] | c.leaf[col]) & all_bits)
	var k := corner_at(fx, fz)
	# Only the corner triangle of the quarter the point is in can be cut or filled; a
	# filled corner needs ground beside it at its own level, so then nothing is to stand
	# on above the highest cell of this column and of the three beside corner k.
	var inside := _old_in_corner(k, fx, fx, fz, fz)
	var d: Vector2i = CORNER_DIRS[k]
	if inside:
		top = maxi(maxi(top, _top(cx + d.x, cz)), maxi(_top(cx, cz + d.y), _top(cx + d.x, cz + d.y)))
	var cells := c.cells
	var shapes := c.shapes
	var corner := 1 << (k + 4)
	for y in range(top, -1, -1):
		var i := (y << 8) | col
		var m := cells[i]
		if m == Mat.AIR or m == Mat.LEAVES or m == Mat.WATER:
			if inside and m != Mat.LEAVES and shapes[i] & corner:
				return y + 1.0
			if m == Mat.WATER:
				return y + ice_top(cx, y, cz) if frozen_at(cx, cz) else -1.0
			continue
		if inside and shapes[i] & corner:
			if get_cell(cx + d.x, y, cz) == Mat.WATER and not frozen_at(cx + d.x, cz):
				return -1.0
			continue
		if not forms.is_empty():
			var f := form_at(cx, y, cz)
			if f != FORM_CUBE:
				return y + form_top(f, fx, fx, fz, fz)
		if shapes[i] & 15 == 0:
			return y + 1.0
		return y + patch_height(surface_patch(cx, y, cz), fx, fz)
	return 0.0


## The corner (NW, NE, SE, SW as 0..3) of the quarter of a cell that (fx, fz) is in.
static func corner_at(fx: float, fz: float) -> int:
	if fz < 0.5:
		return 0 if fx < 0.5 else 1
	return 3 if fx < 0.5 else 2


## True when the box ax..bx, az..bz inside a cell (0..1) lies wholly in the triangle that
## a cut takes off corner k (half a cell along each side), touching its edge at most.
static func _old_in_corner(k: int, ax: float, bx: float, az: float, bz: float) -> bool:
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
static func _old_touches_corner(k: int, ax: float, bx: float, az: float, bz: float) -> bool:
	match k:
		0:
			return ax + az < 0.5
		1:
			return bx - az > 0.5
		2:
			return bx + bz > 1.5
	return bz - ax > 0.5
