extends RefCounted
## The roof map for the shaders (roof_map in common.gdshaderinc): one texel per column
## holding the level of the highest cell that keeps the weather off, plus one, so snow,
## rain and their particles stay off the ground under overhangs, roofs and cave
## ceilings while an open ravine takes them. The world has no edge, so the map covers
## WRAP by WRAP columns and repeats: column (x, z) is texel (x, z) modulo WRAP, far more
## than the view shows. Columns are filled as their chunks are generated; the texture
## is sent to the renderer once a frame at most (flush).

## Columns the map covers each way before it repeats (a multiple of the chunk size).
const WRAP := 512
const MASK := WRAP - 1

var image: Image
var texture: ImageTexture
var dirty := false


## An empty map, to be filled chunk by chunk.
func prepare(_w = null) -> void:
	image = Image.create_empty(WRAP, WRAP, false, Image.FORMAT_R8)
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("roof_map", texture)
	RenderingServer.global_shader_parameter_set("wrap_size", Vector2(WRAP, WRAP) * 0.5)


## The map of every chunk kept, at once (tools).
func build(w) -> void:
	prepare()
	for key: Vector2i in w.chunks:
		fill_chunk(w, key)
	flush()


## Fills the columns of chunk `key` straight from its masks (see WorldData.roof_level);
## an absent chunk leaves them open.
func fill_chunk(w, key: Vector2i) -> void:
	var n: int = w.CHUNK
	var data := PackedByteArray()
	data.resize(n * n)
	var c = w.chunks.get(key)
	if c != null:
		var air: PackedInt64Array = c.air
		var water: PackedInt64Array = c.water
		var leaf: PackedInt64Array = c.leaf
		var all: int = w.all_bits
		for col in n * n:
			data[col] = w.top_level(~(air[col] | water[col] | leaf[col]) & all) + 1
	image.blit_rect(Image.create_from_data(n, n, false, Image.FORMAT_R8, data),
		Rect2i(0, 0, n, n), Vector2i((key.x * n) & MASK, (key.y * n) & MASK))
	dirty = true


## Refreshes the column of a changed cell.
func touch(w, cell: Vector3i) -> void:
	if image == null:
		return
	image.set_pixel(cell.x & MASK, cell.z & MASK, Color((w.roof_level(cell.x, cell.z) + 1) / 255.0, 0.0, 0.0))
	dirty = true


## Sends the changed map to the renderer.
func flush() -> void:
	if dirty:
		dirty = false
		texture.update(image)
