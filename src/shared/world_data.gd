extends RefCounted
## World grid: x and z are horizontal, y is the level. One byte per cell, plus flags
## for what the generator made: natural ground lies as slopes and turns its corners
## diagonally.

const Mat := preload("res://src/shared/materials.gd")

var size_x: int
var size_y: int
var size_z: int
var sea_level := 6
## In winter lakes freeze and can be walked on.
var water_frozen := false
var cells := PackedByteArray()
## WILD for every cell the generator left in place, SHEER besides on loose ground that
## keeps a sheer wall instead of a slope. Any edit clears the flags, so placed blocks
## always stay whole cubes and dug spaces keep square corners.
var natural := PackedByteArray()
const WILD := 1
const SHEER := 2

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


func _init(sx: int, sy: int, sz: int) -> void:
	size_x = sx
	size_y = sy
	size_z = sz
	cells.resize(sx * sy * sz)
	natural.resize(sx * sy * sz)


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
	if in_bounds(x, y, z):
		var i := (y * size_z + z) * size_x + x
		cells[i] = m
		natural[i] = 0


func set_natural(x: int, y: int, z: int, on: bool) -> void:
	if in_bounds(x, y, z):
		natural[(y * size_z + z) * size_x + x] = WILD if on else 0


func is_natural(x: int, y: int, z: int) -> bool:
	return in_bounds(x, y, z) and natural[(y * size_z + z) * size_x + x] & WILD != 0


## Shape of a cell's top as a mask of corners at full height (NW, NE, SE, SW). Natural
## loose ground with open air above slopes down to each side where the ground is one
## level lower (or water): a ramp to one side, an outer corner to two neighbouring
## sides, an inner corner where only a diagonal neighbour is lower. Stone, built blocks
## and drops of two levels or more stay whole cubes: those are cliffs.
func slope_mask(x: int, y: int, z: int) -> int:
	if not _can_slope(x, y, z):
		return FULL
	var low := 0
	for k in 4:
		var o: Vector2i = SIDES[k]
		if _is_low(x + o.x, y, z + o.y):
			low |= 1 << k
	if low != 0:
		return RAMPS[low]
	# Inner corner: exactly one lower diagonal between two sloping neighbours.
	var mask := FULL
	for corner in [[-1, -1, NW], [1, -1, NE], [1, 1, SE], [-1, 1, SW]]:
		var dx: int = corner[0]
		var dz: int = corner[1]
		if _is_low(x + dx, y, z + dz) and _can_slope(x + dx, y, z) and _can_slope(x, y, z + dz):
			if mask != FULL:
				return FULL
			mask = FULL & ~int(corner[2])
	return mask


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


## Height of the ground a walker stands on at (x, z): the top of the highest ground
## there, following slopes and cut or filled corners. -1 over open water.
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
## triangle where both sides and the diagonal are the same open wild cells (all air or
## all water), and the cell above is open or cut there too. A slope is cut only at a
## corner where it is low.
func corner_cut(x: int, y: int, z: int, k: int) -> bool:
	while corner_cut_here(x, y, z, k):
		var above := get_cell(x, y + 1, z)
		if above == Mat.AIR or above == Mat.WATER or above == Mat.LEAVES:
			return true
		y += 1
	return false


## Mask of the corners corner_cut takes off the cell at (x, y, z).
func corner_cuts(x: int, y: int, z: int) -> int:
	var mask := 0
	for k in 4:
		if corner_cut(x, y, z, k):
			mask |= 1 << k
	return mask


## corner_cut without looking above.
func corner_cut_here(x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = CORNER_DIRS[k]
	var a := get_cell(x + o.x, y, z)
	if a != Mat.AIR and a != Mat.WATER or get_cell(x, y, z + o.y) != a or get_cell(x + o.x, y, z + o.y) != a:
		return false
	if not (_ground(x, y, z) and is_natural(x, y, z) and is_natural(x + o.x, y, z) \
			and is_natural(x, y, z + o.y) and is_natural(x + o.x, y, z + o.y)):
		return false
	var mask := slope_mask(x, y, z)
	return mask == FULL or mask & (1 << k) == 0


## True when the open cell at (x, y, z) gets ground in the triangle at corner k: the
## inner corner where both sides and the diagonal are wild ground, the sides whole
## cubes, standing on ground or on the same fill below.
func corner_fill(x: int, y: int, z: int, k: int) -> bool:
	while corner_fill_here(x, y, z, k):
		var below := get_cell(x, y - 1, z)
		if below != Mat.AIR and below != Mat.WATER and below != Mat.LEAVES:
			return true
		y -= 1
	return false


## Mask of the corners corner_fill fills in the cell at (x, y, z).
func corner_fills(x: int, y: int, z: int) -> int:
	var mask := 0
	for k in 4:
		if corner_fill(x, y, z, k):
			mask |= 1 << k
	return mask


## corner_fill without looking below.
func corner_fill_here(x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = CORNER_DIRS[k]
	var m := get_cell(x, y, z)
	if m != Mat.AIR and m != Mat.WATER:
		return false
	return _ground(x + o.x, y, z) and _ground(x, y, z + o.y) and _ground(x + o.x, y, z + o.y) \
		and is_natural(x, y, z) and is_natural(x + o.x, y, z) and is_natural(x, y, z + o.y) \
		and is_natural(x + o.x, y, z + o.y) and slope_mask(x + o.x, y, z) == FULL and slope_mask(x, y, z + o.y) == FULL


## Ground that may have its corners cut or fill a neighbour's corner: anything that
## hides what is behind it except tree trunks.
func _ground(x: int, y: int, z: int) -> bool:
	var m := get_cell(x, y, z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != Mat.LOG


func _can_slope(x: int, y: int, z: int) -> bool:
	return in_bounds(x, y, z) and natural[(y * size_z + z) * size_x + x] == WILD \
		and Mat.can_slope(get_cell(x, y, z)) and get_cell(x, y + 1, z) == Mat.AIR


## A neighbour the ground slopes down to: open at this level, ground or water below.
func _is_low(x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= size_x or z >= size_z:
		return false
	var m := get_cell(x, y, z)
	return (m == Mat.AIR or m == Mat.WATER) and get_cell(x, y - 1, z) != Mat.AIR


func is_solid(x: int, y: int, z: int) -> bool:
	return Mat.is_solid(get_cell(x, y, z))


## True when a walking body cannot be in this cell: solid, water, the map edge,
## or air anywhere above open water (there is no swimming yet). The whole column over
## the water blocks, so neither a step up nor a jump lands on an invisible floor.
func blocks_body(x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= size_x or z >= size_z:
		return true
	var m := get_cell(x, y, z)
	if m == Mat.WATER:
		return true
	if m == Mat.AIR and not water_frozen:
		var below := y - 1
		while below >= 0 and get_cell(x, below, z) == Mat.AIR:
			below -= 1
		return get_cell(x, below, z) == Mat.WATER
	return Mat.is_solid(m)


## True when a body taking the part ax..bx, az..bz (0..1) of the cell at (x, y, z) is
## blocked, as blocks_body says for whole cells. A cut corner holds what is beside it
## (air, or water that cannot be entered); a filled corner is ground.
func blocks_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		for k in 4:
			if in_corner(k, ax, bx, az, bz) and corner_cut(x, y, z, k):
				var o: Vector2i = CORNER_DIRS[k]
				return blocks_body(x + o.x, y, z)
		return true
	if _fill_touched(x, y, z, ax, bx, az, bz):
		return true
	return blocks_body(x, y, z)


## True when the part ax..bx, az..bz (0..1) of the cell at (x, y, z) stands on its top:
## solid there, not only its cut corner, or ground filling its corner.
func ground_part(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	if _ground(x, y, z):
		for k in 4:
			if in_corner(k, ax, bx, az, bz) and corner_cut(x, y, z, k):
				return false
		return true
	return is_solid(x, y, z) or _fill_touched(x, y, z, ax, bx, az, bz)


func _fill_touched(x: int, y: int, z: int, ax: float, bx: float, az: float, bz: float) -> bool:
	var m := get_cell(x, y, z)
	if m != Mat.AIR and m != Mat.WATER:
		return false
	for k in 4:
		if touches_corner(k, ax, bx, az, bz) and corner_fill(x, y, z, k):
			return true
	return false


## Level a walker stands on in this column (the cell above the highest ground),
## or -1 over open water. Tree crowns are ignored so animals walk under them.
func surface_y(x: int, z: int) -> int:
	for y in range(size_y - 1, -1, -1):
		var m := get_cell(x, y, z)
		if m == Mat.AIR or m == Mat.LEAVES:
			continue
		if m == Mat.WATER and not water_frozen:
			return -1
		return y + 1
	return 0
