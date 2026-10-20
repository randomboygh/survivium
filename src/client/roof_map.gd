extends RefCounted
## The roof map for the shaders (roof_map in common.gdshaderinc): one texel per column
## holding the level of the highest cell that keeps the weather off, plus one, so snow,
## rain and their particles stay off the ground under overhangs, roofs and cave
## ceilings while an open ravine takes them. Columns are filled as their chunks are
## generated; the texture is sent to the renderer once a frame at most (flush).

var image: Image
var texture: ImageTexture
var dirty := false


## An empty map of the world's size, to be filled chunk by chunk.
func prepare(w) -> void:
	image = Image.create_empty(w.size_x, w.size_z, false, Image.FORMAT_R8)
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("roof_map", texture)


## Builds the whole map at once (tools, and worlds generated whole).
func build(w) -> void:
	prepare(w)
	fill_chunk(w, 0, 0, maxi(w.size_x, w.size_z))
	flush()


## Fills the columns x0..x0+size, z0..z0+size.
func fill_chunk(w, x0: int, z0: int, size: int) -> void:
	var x1: int = mini(w.size_x, x0 + size)
	var z1: int = mini(w.size_z, z0 + size)
	var data := PackedByteArray()
	data.resize((x1 - x0) * (z1 - z0))
	var i := 0
	for z in range(z0, z1):
		for x in range(x0, x1):
			data[i] = w.roof_level(x, z) + 1
			i += 1
	image.blit_rect(Image.create_from_data(x1 - x0, z1 - z0, false, Image.FORMAT_R8, data),
		Rect2i(0, 0, x1 - x0, z1 - z0), Vector2i(x0, z0))
	dirty = true


## Refreshes the column of a changed cell.
func touch(w, cell: Vector3i) -> void:
	if image == null or cell.x < 0 or cell.z < 0 or cell.x >= w.size_x or cell.z >= w.size_z:
		return
	image.set_pixel(cell.x, cell.z, Color((w.roof_level(cell.x, cell.z) + 1) / 255.0, 0.0, 0.0))
	dirty = true


## Sends the changed map to the renderer.
func flush() -> void:
	if dirty:
		dirty = false
		texture.update(image)
