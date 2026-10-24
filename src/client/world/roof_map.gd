extends RefCounted
## The roof map for the shaders (roof_map in common.gdshaderinc): one texel per column
## holding the level of the highest cell that keeps the weather off, plus one, so snow,
## rain and their particles stay off the ground under overhangs, roofs and cave
## ceilings while an open ravine takes them; and whether a tree's crown is over the
## column, for the leaves fallen under it; and the top of the ground or the water in the
## column with whether it is water, which the fog lies on. The world has no edge, so the map covers
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
	image = Image.create_empty(WRAP, WRAP, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	RenderingServer.global_shader_parameter_set("roof_map", texture)
	RenderingServer.global_shader_parameter_set("roof_map_soft", texture)
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
	data.resize(n * n * 4)
	var c = w.chunks.get(key)
	if c != null:
		var air: PackedInt64Array = c.air
		var water: PackedInt64Array = c.water
		var leaf: PackedInt64Array = c.leaf
		var all: int = w.all_bits
		for col in n * n:
			var top: int = w.top_level(~(air[col] | leaf[col]) & all)
			data[col * 4] = w.top_level(~(air[col] | water[col] | leaf[col]) & all) + 1
			data[col * 4 + 1] = 255 if leaf[col] != 0 else 0
			data[col * 4 + 2] = top + 1
			data[col * 4 + 3] = 255 if top >= 0 and water[col] & (1 << top) else 0
	image.blit_rect(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data),
		Rect2i(0, 0, n, n), Vector2i((key.x * n) & MASK, (key.y * n) & MASK))
	dirty = true


## Refreshes the column of a changed cell.
func touch(w, cell: Vector3i) -> void:
	if image == null:
		return
	var crown := 1.0 if w.leaf_col(cell.x, cell.z) != 0 else 0.0
	var top: int = w.top_level(~(w.air_col(cell.x, cell.z) | w.leaf_col(cell.x, cell.z)) & w.all_bits)
	var water := 1.0 if top >= 0 and w.water_col(cell.x, cell.z) & (1 << top) else 0.0
	image.set_pixel(cell.x & MASK, cell.z & MASK, Color((w.roof_level(cell.x, cell.z) + 1) / 255.0, crown,
		(top + 1) / 255.0, water))
	dirty = true


## Sends the changed map to the renderer; true when it did.
func flush() -> bool:
	if not dirty:
		return false
	dirty = false
	texture.update(image)
	return true
