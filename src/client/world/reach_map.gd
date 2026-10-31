extends RefCounted
## PROTOTYPE: the floor the player can walk to from where they stand (steps of one level
## up or down), within REACH cells, for the cave looks that light it (cave_style 5).
## One texel per column of a SIZE square round the player: r = the level stood on there
## plus one, over 255, 0 where nothing is reached.

const Mat := preload("res://src/shared/content/materials.gd")

const SIZE := 64
const REACH := 20

var image := Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
var texture: ImageTexture
var _at := Vector3i(0, -1000, 0)


func _init() -> void:
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("reach_map", texture)


func _stand(w, x: int, y: int, z: int) -> bool:
	return y > 0 and y + 1 < w.size_y and Mat.is_roof(w.get_cell(x, y - 1, z)) \
		and not Mat.is_roof(w.get_cell(x, y, z)) and not Mat.is_roof(w.get_cell(x, y + 1, z))


func update(w, x: int, level: int, z: int) -> void:
	var at := Vector3i(x, level, z)
	if at == _at:
		return
	_at = at
	image.fill(Color(0, 0, 0))
	var x0 := x - SIZE / 2
	var z0 := z - SIZE / 2
	var seen := {}
	var queue: Array[Vector3i] = [at]
	seen[Vector2i(x, z)] = level
	while not queue.is_empty():
		var c: Vector3i = queue.pop_front()
		image.set_pixel(c.x - x0, c.z - z0, Color((c.y + 1) / 255.0, 0, 0))
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := c.x + o.x
			var nz := c.z + o.y
			if absi(nx - x) > REACH or absi(nz - z) > REACH or seen.has(Vector2i(nx, nz)):
				continue
			for dy in [0, 1, -1]:
				if _stand(w, nx, c.y + dy, nz) and (dy <= 0 or not Mat.is_roof(w.get_cell(c.x, c.y + 2, c.z))):
					seen[Vector2i(nx, nz)] = c.y + dy
					queue.append(Vector3i(nx, c.y + dy, nz))
					break
	texture.update(image)
	RenderingServer.global_shader_parameter_set("reach_origin", Vector2(x0, z0))
