extends "res://src/shared/world/world_cells.gd"
## The world with the shapes of its natural ground: slopes and diagonal corners worked
## out from the cells around (`update_shapes`, a column at a time, after edits), the
## smooth surface of a slope (`surface_patch`, `ground_height`), the cut and filled
## corners a body walks around, and what a body meets in a cell (`blocks_body`,
## `blocks_part`, `ground_part`). The cells themselves are kept by world_cells.gd.


## Surfaces of sloping tops looked at lately (see surface_patch), by cell; emptied
## whenever shapes change.
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
## Slope mask for the low sides N, S, W, E (1, 2, 4, 8) of a cell; FULL where it stays
## a cube: no low side, or two opposite ones.
const RAMPS := [FULL, SE | SW, NW | NE, FULL, NE | SE, SE, NE, FULL, NW | SW, SW, NW,
	FULL, FULL, FULL, FULL, FULL]
## Way from a cell to its corners NW, NE, SE, SW (corner k is bit 1 << k of a mask).
const CORNER_DIRS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

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
## (SlopeMesher.patch); tests check that both agree.
const PATCH_CI := [0, 1, 1, 0]
const PATCH_CJ := [0, 0, 1, 1]


# --- Slope surfaces --------------------------------------------------------------


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


## The highest level of column (x, z) that is not air or leaves, -1 for none.
func _top(x: int, z: int) -> int:
	var c := chunk_at(x, z)
	if c == null:
		return -1
	var col := ((z & MASK) << SHIFT) | (x & MASK)
	return top_level(~(c.air[col] | c.leaf[col]) & all_bits)


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
	# Nothing to stand on above the highest cell of this column and of the three
	# beside corner k (a filled corner needs ground beside it at its own level).
	var d: Vector2i = CORNER_DIRS[k]
	var top := maxi(maxi(_top(cx, cz), _top(cx + d.x, cz)), maxi(_top(cx, cz + d.y), _top(cx + d.x, cz + d.y)))
	for y in range(top, -1, -1):
		var m := get_cell(cx, y, cz)
		if m == Mat.AIR or m == Mat.LEAVES or m == Mat.WATER:
			if inside and corner_fill(cx, y, cz, k):
				return y + 1.0
			if m == Mat.WATER:
				return y + ice_top(cx, y, cz) if water_frozen else -1.0
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
		return water_frozen
	return m != Mat.LEAVES and Mat.is_solid(m)


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
	if chunk_at(x, z) == null:
		return true
	if not blockers.is_empty() and blocker_part(x, y, z, ax, bx, az, bz) > 0.0:
		return true
	if not trees.is_empty() and _bark_touched(x, y, z, ax, bx, az, bz):
		return true
	return _cell_blocks(x, y, z)


## Whether the part ax..bx, az..bz (0..1) of air cell (x, y, z) holds the bark of a trunk
## beside it thicker than its own cell (see Trees.trunk_box).
func _bark_touched(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if get_cell(x, y, z) != Mat.AIR:
		return false
	for o in SIDES:
		var col := Vector2i(x + o.x, z + o.y)
		var species: int = trees.get(col, -1)
		if species < 0 or species >= Trees.SPECIES.size() or get_cell(col.x, y, col.y) != Mat.LOG:
			continue
		var k := 0
		while k < 64 and get_cell(col.x, y - k - 1, col.y) == Mat.LOG:
			k += 1
		var box := Trees.trunk_box(species, col, k)
		# The box in texels of this cell.
		box.position += o * 8
		if ax * 8.0 < box.end.x and bx * 8.0 > box.position.x and az * 8.0 < box.end.y and bz * 8.0 > box.position.y:
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
	var box: AABB = blockers.get(c, AABB())
	var base := 0.0
	if not box.has_volume():
		c.y -= 1
		box = blockers.get(c, AABB())
		base = 1.0
	if not box.has_volume() or ax >= box.end.x or bx <= box.position.x or az >= box.end.z or bz <= box.position.z:
		return 0.0
	return clampf(box.end.y - base, 0.0, 1.0)


## True when the part ax..bx, az..bz (0..1) of the cell at (x, y, z) stands on its top:
## solid there (not leaves, which a body goes through), not only its cut corner, ground
## filling its corner, ice, or a thing standing there (see blockers).
func ground_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		var cuts := corner_cuts(x, y, z)
		for k in 4:
			if cuts & (1 << k) and in_corner(k, ax, bx, az, bz):
				return false
		return true
	var m := get_cell(x, y, z)
	return m != Mat.LEAVES and Mat.is_solid(m) or water_frozen and m == Mat.WATER \
		or _fill_touched(x, y, z, ax, bx, az, bz) or not blockers.is_empty() and blocker_part(x, y, z, ax, bx, az, bz) > 0.0


func _fill_touched(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	var fills := corner_fills(x, y, z)
	for k in 4:
		if fills & (1 << k) and touches_corner(k, ax, bx, az, bz):
			return true
	return false
