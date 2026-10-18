extends RefCounted
## World grid: x and z are horizontal, y is the level. One byte per cell.

const Mat := preload("res://src/shared/materials.gd")

var size_x: int
var size_y: int
var size_z: int
var sea_level := 6
## In winter lakes freeze and can be walked on.
var water_frozen := false
var cells := PackedByteArray()


func _init(sx: int, sy: int, sz: int) -> void:
	size_x = sx
	size_y = sy
	size_z = sz
	cells.resize(sx * sy * sz)


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
		cells[(y * size_z + z) * size_x + x] = m


func is_solid(x: int, y: int, z: int) -> bool:
	return Mat.is_solid(get_cell(x, y, z))


## True when a walking body cannot be in this cell: solid, water, the map edge,
## or air right above open water (there is no swimming yet).
func blocks_body(x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= size_x or z >= size_z:
		return true
	var m := get_cell(x, y, z)
	if m == Mat.WATER:
		return true
	if m == Mat.AIR and not water_frozen and get_cell(x, y - 1, z) == Mat.WATER:
		return true
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
