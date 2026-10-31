extends RefCounted
## PROTOTYPE (cave_style 6): which cells round the player are solid, for the plane cut
## to draw its section only where the plane truly passes through rock (a seam between
## faces would show the section through it otherwise). One texel per column of a SIZE
## square: 32 bits for the levels base .. base + 31 (r the lowest eight).

const SIZE := 64
const LEVELS := 32

var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
var texture: ImageTexture
var dirty := true
var _at := Vector3i(0, -1000, 0)


func _init() -> void:
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("solid_map", texture)


func update(w, x: int, level: int, z: int) -> void:
	var at := Vector3i(x, level, z)
	if at == _at and not dirty:
		return
	_at = at
	dirty = false
	var x0 := x - SIZE / 2
	var z0 := z - SIZE / 2
	var base := level - LEVELS / 2
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 4)
	var k := 0
	for cz in range(z0, z0 + SIZE):
		for cx in range(x0, x0 + SIZE):
			var open: int = w.air_col(cx, cz) | w.water_col(cx, cz) | w.leaf_col(cx, cz)
			var solid: int = ~open
			var bits: int = (solid >> base) if base >= 0 else (solid << -base)
			data[k] = bits & 255
			data[k + 1] = (bits >> 8) & 255
			data[k + 2] = (bits >> 16) & 255
			data[k + 3] = (bits >> 24) & 255
			k += 4
	image.set_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
	texture.update(image)
	RenderingServer.global_shader_parameter_set("solid_origin", Vector3(x0, base, z0))
