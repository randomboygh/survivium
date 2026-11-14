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

##
## Beside it, the biome map: a texel per column the same way holding its biome (Chunk.biome),
## and the factors each biome's tints multiply each material by (biome_tints, a texel
## for material m and biome b at m, b), for biome_tint in common.gdshaderinc.

const Biomes := preload("res://src/shared/content/biomes.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")

## Columns the map covers each way before it repeats (a multiple of the chunk size).
const WRAP := 512
const MASK := WRAP - 1
## Beside it, a coarse map of the ground's height for the fog (ground_low in
## common.gdshaderinc): a texel per LOW by LOW columns holding the mean of their tops
## (b of the roof map), filtered between texels, so the fog's low places change
## smoothly over the land instead of in steps where a tall thing's edge passes.
const LOW := 4
const LOW_SIZE := WRAP / LOW
## The size of the tints: every material the atlas holds, every biome byte.
const TINT_MATERIALS := 64
const TINT_BIOMES := 256
## No tint: the factor 1, kept over 4 (factors up to 4 whiten dark sand).
const NO_TINT := 0.25
## Water's own colour where shallow (`shallow` in water.gdshader), which its tint is
## taken against.
const WATER_SHALLOW := Color(0.36, 0.62, 0.6)

var image: Image
var texture: ImageTexture
var biome_image: Image
var biome_texture: ImageTexture
var tints_texture: ImageTexture
var low_image: Image
var low_texture: ImageTexture
var dirty := false
var biomes_dirty := false


## An empty map, to be filled chunk by chunk.
func prepare(_w = null) -> void:
	image = Image.create_empty(WRAP, WRAP, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	PixelTextures.set_global("roof_map", texture)
	PixelTextures.set_global("roof_map_soft", texture)
	RenderingServer.global_shader_parameter_set("wrap_size", Vector2(WRAP, WRAP) * 0.5)
	low_image = Image.create_empty(LOW_SIZE, LOW_SIZE, false, Image.FORMAT_R8)
	low_texture = ImageTexture.create_from_image(low_image)
	PixelTextures.set_global("ground_low", low_texture)
	biome_image = Image.create_empty(WRAP, WRAP, false, Image.FORMAT_R8)
	biome_image.fill(Color(1, 1, 1))
	biome_texture = ImageTexture.create_from_image(biome_image)
	PixelTextures.set_global("biome_map", biome_texture)
	tints_texture = ImageTexture.create_from_image(tints())
	PixelTextures.set_global("biome_tints", tints_texture)


## The factors of the loaded biomes' tints (see Biomes.tints): what turns a material's
## own colour into the biome's, channel by channel, over 4 (the shaders blend in sRGB:
## factors taken in linear colour came out far too strong, 2026-11-01).
static func tints() -> Image:
	var img := Image.create_empty(TINT_MATERIALS, TINT_BIOMES, false, Image.FORMAT_RGBA8)
	img.fill(Color(NO_TINT, NO_TINT, NO_TINT, 1.0))
	for b in mini(Biomes.RECORDS.size(), TINT_BIOMES - 1):
		var named: Dictionary = Biomes.tints(b)
		for m: int in named:
			if m >= TINT_MATERIALS:
				continue
			var own: Color = WATER_SHALLOW if m == Mat.WATER else PixelTextures.tint(m)
			var want: Color = named[m]
			img.set_pixel(m, b, Color(_factor(want.r, own.r), _factor(want.g, own.g), _factor(want.b, own.b), 1.0))
	return img


static func _factor(want: float, own: float) -> float:
	return clampf(want / maxf(own, 0.01) * NO_TINT, 0.0, 1.0)


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
	var lows := PackedByteArray()
	var m := n / LOW
	lows.resize(m * m)
	var tops := PackedInt32Array()
	tops.resize(LOW * LOW)
	for i in m * m:
		for k in LOW * LOW:
			tops[k] = data[(((i / m) * LOW + k / LOW) * n + (i % m) * LOW + k % LOW) * 4 + 2]
		lows[i] = low_mean(tops)
	low_image.blit_rect(Image.create_from_data(m, m, false, Image.FORMAT_R8, lows),
		Rect2i(0, 0, m, m), Vector2i(((key.x * n) & MASK) / LOW, ((key.y * n) & MASK) / LOW))
	if c != null:
		biome_image.blit_rect(Image.create_from_data(n, n, false, Image.FORMAT_R8, c.biome),
			Rect2i(0, 0, n, n), Vector2i((key.x * n) & MASK, (key.y * n) & MASK))
		biomes_dirty = true


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
	var lx := (cell.x & MASK) / LOW
	var lz := (cell.z & MASK) / LOW
	var tops := PackedInt32Array()
	tops.resize(LOW * LOW)
	for k in LOW * LOW:
		tops[k] = roundi(image.get_pixel(lx * LOW + k % LOW, lz * LOW + k / LOW).b * 255.0)
	low_image.set_pixel(lx, lz, Color(low_mean(tops) / 255.0, 0.0, 0.0))


## The height a block of columns stands for in ground_low: the top three quarters
## of the way up its tops, so a pit or a ditch through it does not pull it down, nor a
## trunk, a post or a wall standing in it lift it.
static func low_mean(tops: PackedInt32Array) -> int:
	var sorted := tops.duplicate()
	sorted.sort()
	return sorted[(sorted.size() * 3) / 4]


## Sends the changed map to the renderer; true when it did.
func flush() -> bool:
	if biomes_dirty:
		biomes_dirty = false
		biome_texture.update(biome_image)
	if not dirty:
		return false
	dirty = false
	texture.update(image)
	low_texture.update(low_image)
	return true
