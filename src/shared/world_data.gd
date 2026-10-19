extends RefCounted
## World grid: x and z are horizontal, y is the level. One byte per cell, plus a flag
## for natural ground that may lie as a slope.

const Mat := preload("res://src/shared/materials.gd")

var size_x: int
var size_y: int
var size_z: int
var sea_level := 6
## In winter lakes freeze and can be walked on.
var water_frozen := false
var cells := PackedByteArray()
## 1 for ground the generator left in place: loose ground among it forms slopes. Any
## edit clears the flag, so placed blocks always stay whole cubes.
var natural := PackedByteArray()

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
		natural[(y * size_z + z) * size_x + x] = 1 if on else 0


func is_natural(x: int, y: int, z: int) -> bool:
	return in_bounds(x, y, z) and natural[(y * size_z + z) * size_x + x] == 1


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
## top is two flat triangles split along the diagonal through the odd corner, as the
## mesher draws it.
static func slope_height(mask: int, fx: float, fz: float) -> float:
	if mask == FULL:
		return 1.0
	var nw := float(mask & NW != 0)
	var ne := float(mask & NE != 0)
	var se := float(mask & SE != 0)
	var sw := float(mask & SW != 0)
	if split_nw_se(mask):
		if fx >= fz:
			return nw + (ne - nw) * fx + (se - ne) * fz
		return nw + (sw - nw) * fz + (se - sw) * fx
	if fx + fz <= 1.0:
		return nw + (ne - nw) * fx + (sw - nw) * fz
	return se + (sw - se) * (1.0 - fx) + (ne - se) * (1.0 - fz)


## True when the top splits along the NW-SE diagonal, false for NE-SW: the diagonal
## through the corner that differs from the other three (any for a ramp).
static func split_nw_se(mask: int) -> bool:
	return mask == NW or mask == SE or mask == FULL & ~NW or mask == FULL & ~SE \
		or mask == NW | NE or mask == SE | SW or mask == NE | SE or mask == NW | SW


## Height of the ground a walker stands on at (x, z): the top of the highest cell in
## the column, following slopes. -1 over open water.
func ground_height(x: float, z: float) -> float:
	var cx := floori(x)
	var cz := floori(z)
	var top := surface_y(cx, cz)
	if top <= 0:
		return float(top)
	var mask := slope_mask(cx, top - 1, cz)
	return top - 1 + slope_height(mask, x - cx, z - cz)


func _can_slope(x: int, y: int, z: int) -> bool:
	return is_natural(x, y, z) and Mat.can_slope(get_cell(x, y, z)) and get_cell(x, y + 1, z) == Mat.AIR


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
