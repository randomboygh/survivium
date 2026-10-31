extends RefCounted
## Which cells round the player are solid, for the cut in the plane of the camera
## (setting «Вид в пещере»): the shaders draw its section only where the plane truly
## passes through rock (section_here in common.gdshaderinc), since a seam between two
## faces of the world lets the line of sight through to the inside of the rock too.
## One texel per column of a SIZE square: 32 bits, eight in each of r, g, b, a, for the
## levels from the base up; the shader global solid_origin = (x, base, z) of its corner.
## Made again round the player a few rows a frame once they near its edge (the old one
## shows meanwhile); a changed cell is written at once (touch).

const SIZE := 128
const LEVELS := 32
## How far the player may go from the middle, in cells and levels, before it is made
## again round them.
const SLACK := 24
const LEVEL_SLACK := 6
const ROWS_PER_FRAME := 3

var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
var texture: ImageTexture
## The corner in force: (x, base level, z); y -1000 before the first is made.
var origin := Vector3i(0, -1000, 0)
var _next := Vector3i.ZERO
var _data := PackedByteArray()
## The next row of the one being made, -1 for none.
var _row := -1


func _init() -> void:
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("solid_map", texture)
	RenderingServer.global_shader_parameter_set("solid_origin", Vector3(origin))


## Called every frame the cut is on, with the player's column and level.
func update(w, x: int, level: int, z: int) -> void:
	if _row < 0:
		var mid := origin + Vector3i(SIZE / 2, LEVELS / 2, SIZE / 2)
		if origin.y > -1000 and absi(x - mid.x) <= SLACK and absi(z - mid.z) <= SLACK \
				and absi(level - mid.y) <= LEVEL_SLACK:
			return
		_next = Vector3i(x - SIZE / 2, level - LEVELS / 2, z - SIZE / 2)
		_data.resize(SIZE * SIZE * 4)
		_row = 0
	var end := mini(_row + ROWS_PER_FRAME, SIZE)
	for r in range(_row, end):
		for c in SIZE:
			_write(_data, (r * SIZE + c) * 4, _bits(w, _next.x + c, _next.z + r, _next.y))
	_row = end
	if _row < SIZE:
		return
	_row = -1
	origin = _next
	image.set_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, _data)
	texture.update(image)
	RenderingServer.global_shader_parameter_set("solid_origin", Vector3(origin))


## Cell `cell` changed: its column is written again.
func touch(w, cell: Vector3i) -> void:
	var c := cell.x - origin.x
	var r := cell.z - origin.z
	if origin.y > -1000 and c >= 0 and r >= 0 and c < SIZE and r < SIZE:
		var b := _bits(w, cell.x, cell.z, origin.y)
		image.set_pixel(c, r, Color8(b & 255, (b >> 8) & 255, (b >> 16) & 255, (b >> 24) & 255))
		texture.update(image)
	# A map being made may have passed that row already.
	c = cell.x - _next.x
	r = cell.z - _next.z
	if _row >= 0 and c >= 0 and r >= 0 and c < SIZE and r < _row:
		_write(_data, (r * SIZE + c) * 4, _bits(w, cell.x, cell.z, _next.y))


## The solid levels of column (x, z) from `base` up, a bit each.
static func _bits(w, x: int, z: int, base: int) -> int:
	var solid: int = ~(w.air_col(x, z) | w.water_col(x, z) | w.leaf_col(x, z))
	return (solid >> base) if base >= 0 else (solid << -base)


static func _write(data: PackedByteArray, k: int, bits: int) -> void:
	data[k] = bits & 255
	data[k + 1] = (bits >> 8) & 255
	data[k + 2] = (bits >> 16) & 255
	data[k + 3] = (bits >> 24) & 255
