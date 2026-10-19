extends RefCounted
## The roof map for the shaders (roof_map in common.gdshaderinc): one texel per column
## holding the level of the highest cell that keeps the weather off, plus one, so snow,
## rain and their particles stay off the ground under overhangs, roofs and cave
## ceilings while an open ravine takes them.

var image: Image
var texture: ImageTexture


## Builds the whole map and hands it to the shaders.
func build(w) -> void:
	var data := PackedByteArray()
	data.resize(w.size_x * w.size_z)
	for z in w.size_z:
		for x in w.size_x:
			data[z * w.size_x + x] = w.roof_level(x, z) + 1
	image = Image.create_from_data(w.size_x, w.size_z, false, Image.FORMAT_R8, data)
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("roof_map", texture)


## Refreshes the column of a changed cell.
func touch(w, cell: Vector3i) -> void:
	if image == null or cell.x < 0 or cell.z < 0 or cell.x >= w.size_x or cell.z >= w.size_z:
		return
	image.set_pixel(cell.x, cell.z, Color((w.roof_level(cell.x, cell.z) + 1) / 255.0, 0.0, 0.0))
	texture.update(image)
