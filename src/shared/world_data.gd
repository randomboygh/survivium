extends RefCounted
## World grid: x and z are horizontal, y is the level. A cell is CELL world units on
## each side, 8 px on screen. One byte per cell, plus flags for what the generator
## made: natural ground lies as slopes and turns its corners diagonally. Those shapes
## follow from the cells around and are kept per cell (see update_shapes). Per column,
## bit masks of the materials let a whole column be tested at once, which keeps shapes
## and meshes fast on a fine grid.

const Mat := preload("res://src/shared/materials.gd")

## Size of a cell in world units; a world unit is 16 px on screen.
const CELL := 0.5
## Open water lies this far up its top cell (4 px under the ground beside it). Ice
## fills the cell to the top.
const WATER_TOP := 0.5

var size_x: int
var size_y: int
var size_z: int
var sea_level := 12
## In winter water freezes and is walked on like ground; otherwise it is waded and
## swum through.
var water_frozen := false
var cells := PackedByteArray()
## WILD for every cell the generator left in place, SHEER besides on loose ground that
## keeps a sheer wall instead of a slope. Any edit clears the flags, so placed blocks
## always stay whole cubes and dug spaces keep square corners.
var natural := PackedByteArray()
const WILD := 1
const SHEER := 2
## Shape of each cell, worked out from the cells and flags by update_shapes: the corners
## of a sloping top that are low (bits 0..3, none for a whole cube), and the corners cut
## off a ground cell or filled in an open one (bits 4..7). Corner k is bit 1 << k.
var shapes := PackedByteArray()
## Bit masks per column (index x + z * size_x), bit y for the cell on level y: air,
## water, leaves, logs, wild cells, and cells with a slope or with corners in `shapes`.
## Outside the map every cell is air.
var air_cols := PackedInt64Array()
var water_cols := PackedInt64Array()
var leaf_cols := PackedInt64Array()
var log_cols := PackedInt64Array()
var wild_cols := PackedInt64Array()
var sloped_cols := PackedInt64Array()
var corner_cols := PackedInt64Array()
## Trees grown in the world: species (see Trees) by the trunk's column, Vector2i(x, z).
var trees := {}
## Bits of all levels, and of the top level.
var all_bits: int
var top_bit: int
## Columns whose shapes are out of date: x0, z0, x1, z1 (ends exclusive), empty if x0 >= x1.
var _dirty := PackedInt32Array([0, 0, 0, 0])

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


func _init(sx: int, sy: int, sz: int) -> void:
	assert(sy <= 62, "a column's levels must fit in a 64-bit mask")
	size_x = sx
	size_y = sy
	size_z = sz
	cells.resize(sx * sy * sz)
	natural.resize(sx * sy * sz)
	shapes.resize(sx * sy * sz)
	all_bits = (1 << sy) - 1
	top_bit = 1 << (sy - 1)
	air_cols.resize(sx * sz)
	air_cols.fill(all_bits)
	water_cols.resize(sx * sz)
	leaf_cols.resize(sx * sz)
	log_cols.resize(sx * sz)
	wild_cols.resize(sx * sz)
	sloped_cols.resize(sx * sz)
	corner_cols.resize(sx * sz)


func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < size_x and y < size_y and z < size_z


## Cells below the world are bedrock, cells outside it horizontally or above are air.
func get_cell(x: int, y: int, z: int) -> int:
	if y < 0:
		return Mat.STONE
	if not in_bounds(x, y, z):
		return Mat.AIR
	return cells[(y * size_z + z) * size_x + x]


func set_cell(x: int, y: int, z: int, m: int) -> void:
	if not in_bounds(x, y, z):
		return
	cells[(y * size_z + z) * size_x + x] = m
	natural[(y * size_z + z) * size_x + x] = 0
	var col := z * size_x + x
	var bit := 1 << y
	air_cols[col] = air_cols[col] & ~bit | (bit if m == Mat.AIR else 0)
	water_cols[col] = water_cols[col] & ~bit | (bit if m == Mat.WATER else 0)
	leaf_cols[col] = leaf_cols[col] & ~bit | (bit if m == Mat.LEAVES else 0)
	log_cols[col] = log_cols[col] & ~bit | (bit if m == Mat.LOG else 0)
	wild_cols[col] &= ~bit
	_touch(x, z)


func set_natural(x: int, y: int, z: int, on: bool) -> void:
	if in_bounds(x, y, z):
		natural[(y * size_z + z) * size_x + x] = WILD if on else 0
		var col := z * size_x + x
		wild_cols[col] = wild_cols[col] & ~(1 << y) | ((1 << y) if on else 0)
		_touch(x, z)


func is_natural(x: int, y: int, z: int) -> bool:
	return in_bounds(x, y, z) and natural[(y * size_z + z) * size_x + x] & WILD != 0


## Rebuilds the column masks after `cells` or `natural` were written directly, and
## marks all shapes out of date.
func rebuild_columns() -> void:
	var layer := size_x * size_z
	for col in layer:
		var a := 0
		var wt := 0
		var lf := 0
		var lg := 0
		var wd := 0
		for y in size_y:
			var i := y * layer + col
			var m := cells[i]
			var bit := 1 << y
			a |= bit if m == Mat.AIR else 0
			wt |= bit if m == Mat.WATER else 0
			lf |= bit if m == Mat.LEAVES else 0
			lg |= bit if m == Mat.LOG else 0
			wd |= bit if natural[i] & WILD else 0
		air_cols[col] = a
		water_cols[col] = wt
		leaf_cols[col] = lf
		log_cols[col] = lg
		wild_cols[col] = wd
	mark_all_dirty()


func mark_all_dirty() -> void:
	_dirty = PackedInt32Array([0, 0, size_x, size_z])


## A change at column (x, z) can reshape the cells up to two columns away: slopes look
## at their neighbours, corners at the slopes beside them.
func _touch(x: int, z: int) -> void:
	var d := _dirty
	if d[0] >= d[2]:
		_dirty = PackedInt32Array([maxi(0, x - 2), maxi(0, z - 2), mini(size_x, x + 3), mini(size_z, z + 3)])
	else:
		_dirty = PackedInt32Array([mini(d[0], maxi(0, x - 2)), mini(d[1], maxi(0, z - 2)),
			maxi(d[2], mini(size_x, x + 3)), maxi(d[3], mini(size_z, z + 3))])


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
	var layer := size_x * size_z
	for z in range(z0, z1):
		for x in range(x0, x1):
			var col := z * size_x + x
			var m := sloped_cols[col] | corner_cols[col]
			while m != 0:
				var bit := m & -m
				m ^= bit
				shapes[level_of(bit) * layer + col] = 0
			sloped_cols[col] = 0
			corner_cols[col] = 0
	# Masks of the region and a ring of columns around it, `wl` columns wide. Outside
	# the map every cell is air, nothing is wild and nothing slopes down there.
	var wl := x1 - x0 + 2
	var hl := z1 - z0 + 2
	var air := PackedInt64Array()
	air.resize(wl * hl)
	air.fill(all_bits)
	var water := PackedInt64Array()
	water.resize(wl * hl)
	var open := air.duplicate()
	var ground := PackedInt64Array()
	ground.resize(wl * hl)
	var wild := ground.duplicate()
	var low := ground.duplicate()
	for lz in hl:
		var z := z0 - 1 + lz
		if z < 0 or z >= size_z:
			continue
		for lx in wl:
			var x := x0 - 1 + lx
			if x < 0 or x >= size_x:
				continue
			var j := lz * wl + lx
			var col := z * size_x + x
			var a := air_cols[col]
			var wt := water_cols[col]
			var o := a | wt | leaf_cols[col]
			air[j] = a
			water[j] = wt
			open[j] = o
			ground[j] = ~(o | log_cols[col]) & all_bits
			wild[j] = wild_cols[col]
			low[j] = (a | wt) & ~(a << 1) & all_bits
	var diag := PackedInt32Array([-wl - 1, -wl + 1, wl + 1, wl - 1])
	# Slopes: loose wild ground with air above.
	for lz in range(1, hl - 1):
		for lx in range(1, wl - 1):
			var j := lz * wl + lx
			var cand := ~open[j] & ((air[j] >> 1) | top_bit) & wild[j]
			if cand == 0:
				continue
			var x := x0 - 1 + lx
			var z := z0 - 1 + lz
			var col := z * size_x + x
			var low_n := low[j - wl]
			var low_s := low[j + wl]
			var low_w := low[j - 1]
			var low_e := low[j + 1]
			while cand != 0:
				var bit := cand & -cand
				cand ^= bit
				var y := level_of(bit)
				var i := y * layer + col
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
					sloped_cols[col] |= bit
	var sloped := PackedInt64Array()
	sloped.resize(wl * hl)
	for lz in hl:
		var z := z0 - 1 + lz
		if z >= 0 and z < size_z:
			for lx in wl:
				var x := x0 - 1 + lx
				if x >= 0 and x < size_x:
					sloped[lz * wl + lx] = sloped_cols[z * size_x + x]
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
			var col := (z0 - 1 + lz) * size_x + x0 - 1 + lx
			for k in 4:
				var cx := j + side_x[k]
				var cz := j + side_z[k]
				var cd := cx + side_z[k]
				var wild4 := wild[j] & wild[cx] & wild[cz] & wild[cd]
				if wild4 == 0:
					continue
				var cut := gr & wild4 & (air[cx] & air[cz] & air[cd] | water[cx] & water[cz] & water[cd])
				if cut != 0:
					# A slope is cut only at a corner where it is low.
					var sl := cut & sloped[j]
					while sl != 0:
						var bit := sl & -sl
						sl ^= bit
						if shapes[level_of(bit) * layer + col] & (1 << k) == 0:
							cut &= ~bit
					# The runs of such cells whose top has an open cell above.
					_mark(col, _spread(cut, cut & ~(cut >> 1) & ((open[j] >> 1) | top_bit), -1), 16 << k)
				var fill := aw & wild4 & ground[cx] & ground[cz] & ground[cd] & ~sloped[cx] & ~sloped[cz]
				if fill != 0:
					# The runs of such cells standing on something that hides what is behind it.
					_mark(col, _spread(fill, fill & ~(fill << 1) & ((~open[j] << 1) | 1), 1), 16 << k)


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


func _mark(col: int, bits: int, value: int) -> void:
	if bits == 0:
		return
	corner_cols[col] |= bits
	var layer := size_x * size_z
	while bits != 0:
		var bit := bits & -bits
		bits ^= bit
		var i := level_of(bit) * layer + col
		shapes[i] = shapes[i] | value


## Shape of a cell's top as a mask of corners at full height (NW, NE, SE, SW). Natural
## loose ground with open air above slopes down to each side where the ground is one
## level lower (or water): a ramp to one side, an outer corner to two neighbouring
## sides, an inner corner where only a diagonal neighbour is lower. Stone, built blocks
## and drops of two levels or more stay whole cubes: those are cliffs.
func slope_mask(x: int, y: int, z: int) -> int:
	if not in_bounds(x, y, z):
		return FULL
	refresh_shapes()
	return FULL & ~(shapes[(y * size_z + z) * size_x + x] & 15)


## Height of the top of a cell with this slope mask at (fx, fz) inside it, 0..1. The
## top is two flat triangles split along a diagonal, as the mesher draws it (see
## split_nw_se); `cuts` are the cell's cut corners.
static func slope_height(mask: int, fx: float, fz: float, cuts := 0) -> float:
	if mask == FULL:
		return 1.0
	var nw := float(mask & NW != 0)
	var ne := float(mask & NE != 0)
	var se := float(mask & SE != 0)
	var sw := float(mask & SW != 0)
	if split_nw_se(mask, cuts):
		if fx >= fz:
			return nw + (ne - nw) * fx + (se - ne) * fz
		return nw + (sw - nw) * fz + (se - sw) * fx
	if fx + fz <= 1.0:
		return nw + (ne - nw) * fx + (sw - nw) * fz
	return se + (sw - se) * (1.0 - fx) + (ne - se) * (1.0 - fz)


## True when a sloping top splits along the NW-SE diagonal, false for NE-SW: the
## diagonal through the corner that differs from the other three (any for a ramp). With
## a cut corner the split runs across it instead, so the low corner stays flat up to the
## cut.
static func split_nw_se(mask: int, cuts := 0) -> bool:
	if cuts & (NW | SE):
		return false
	if cuts & (NE | SW):
		return true
	return mask == NW or mask == SE or mask == FULL & ~NW or mask == FULL & ~SE \
		or mask == NW | NE or mask == SE | SW or mask == NE | SE or mask == NW | SW


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
		var mask := slope_mask(cx, y, cz)
		return y + slope_height(mask, fx, fz, 0 if mask == FULL else corner_cuts(cx, y, cz))
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
	if not in_bounds(x, y, z):
		return 0
	refresh_shapes()
	var i := (y * size_z + z) * size_x + x
	var m := cells[i]
	return shapes[i] >> 4 if m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES else 0


## True when the open cell at (x, y, z) gets ground in the triangle at corner k: the
## inner corner where both sides and the diagonal are wild ground, the sides whole
## cubes, standing on ground or on the same fill below.
func corner_fill(x: int, y: int, z: int, k: int) -> bool:
	return corner_fills(x, y, z) & (1 << k) != 0


## Mask of the corners filled in the cell at (x, y, z).
func corner_fills(x: int, y: int, z: int) -> int:
	if not in_bounds(x, y, z):
		return 0
	refresh_shapes()
	var i := (y * size_z + z) * size_x + x
	var m := cells[i]
	return shapes[i] >> 4 if m == Mat.AIR or m == Mat.WATER else 0


## Ground that may have its corners cut or fill a neighbour's corner: anything that
## hides what is behind it except tree trunks.
func _ground(x: int, y: int, z: int) -> bool:
	var m := get_cell(x, y, z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != Mat.LOG


func _can_slope(x: int, y: int, z: int) -> bool:
	return in_bounds(x, y, z) and natural[(y * size_z + z) * size_x + x] == WILD \
		and Mat.can_slope(get_cell(x, y, z)) and get_cell(x, y + 1, z) == Mat.AIR


func is_solid(x: int, y: int, z: int) -> bool:
	return Mat.is_solid(get_cell(x, y, z))


## True when a walking body cannot be in this cell: solid, frozen water, or the map
## edge. Open water is waded and swum through.
func blocks_body(x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= size_x or z >= size_z:
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


## Level a walker stands on in this column (the cell above the highest ground),
## or -1 over open water. Tree crowns are ignored so animals walk under them.
## Level of the highest cell in the column that keeps rain and snow off what lies
## below (anything but air, water and leaves), -1 when there is none.
func roof_level(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= size_x or z >= size_z:
		return -1
	var col := z * size_x + x
	var solid := ~(air_cols[col] | water_cols[col] | leaf_cols[col]) & all_bits
	return top_level(solid)


## Level of the highest set bit, -1 for none.
static func top_level(bits: int) -> int:
	if bits == 0:
		return -1
	var level := 0
	for shift in [32, 16, 8, 4, 2, 1]:
		if bits >> shift != 0:
			bits >>= shift
			level += shift
	return level


func surface_y(x: int, z: int) -> int:
	for y in range(size_y - 1, -1, -1):
		var m := get_cell(x, y, z)
		if m == Mat.AIR or m == Mat.LEAVES:
			continue
		if m == Mat.WATER and not water_frozen:
			return -1
		return y + 1
	return 0
