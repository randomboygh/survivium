extends RefCounted
## The roof map for the shaders (roof_map in common.gdshaderinc): one texel per column
## holding the level of the highest cell that keeps the weather off, plus one, so snow,
## rain and their particles stay off the ground under overhangs, roofs and cave
## ceilings while an open ravine takes them; and whether a tree's crown is over the
## column, for the leaves fallen under it, and whether a puddle may stand on its top
## after rain (g, see CROWN); and the top of the ground or the water in the
## column with whether it is water, which the fog lies on. The world has no edge, so the map covers
## WRAP by WRAP columns and repeats: column (x, z) is texel (x, z) modulo WRAP, far more
## than the view shows. Columns are filled as their chunks are generated; the texture
## is sent to the renderer once a frame at most (flush).

##
## Beside it, the biome map: a texel per column the same way holding its biome (Chunk.biome)
## in r and how much of the snow of the heights lies on it (Chunk.frost) in g,
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
## smoothly over the land instead of in steps where a tall thing's edge passes. Its g,
## b and a hold the colour of the water there (water_tint), over 2, filtered the same
## way, so where two waters meet (a river's mouth into the sea, a stream into a lake of
## another biome) one colour runs into the other over a few cells.
const LOW := 4
const LOW_SIZE := WRAP / LOW
## The size of the tints: every material the atlas holds, every biome byte.
const TINT_MATERIALS := 64
const TINT_BIOMES := 256
## No tint: the factor 1, kept over 4 (factors up to 4 whiten dark sand).
const NO_TINT := 0.25
## The roof map's g: CROWN under a tree's crown (over half, so the filtered map gives
## the crowns' cover as before), plus NO_PUDDLE where the top keeps no puddle and SLOPED
## where it slopes (top_bits).
const CROWN := 252
const NO_PUDDLE := 1
const SLOPED := 2
## Water's own colour where shallow (`shallow` in water.gdshader), which its tint is
## taken against.
const WATER_SHALLOW := Color(0.36, 0.62, 0.6)
## Water's colour by its body, on top of its biome's tint (thread «Сделать разный цвет
## воды в водоёмах»): the sea a little deeper blue, a river a little greener and paler
## with the silt it carries, a lake as it is.
const SEA_TINT := Color(0.9, 0.97, 1.07)
const RIVER_TINT := Color(1.06, 1.05, 0.93)
const LAKE_TINT := Color(1.0, 1.0, 1.0)
## And by where it lies: a slow noise of VARY_CELLS cells shades one lake or stretch of
## a river from the next, its brightness by up to VARY_LIGHT either way and its hue
## between green and blue by up to VARY_HUE.
const VARY_CELLS := 40
const VARY_LIGHT := 0.06
const VARY_HUE := 0.05

var image: Image
var texture: ImageTexture
var biome_image: Image
var biome_texture: ImageTexture
var tints_texture: ImageTexture
var low_image: Image
var low_texture: ImageTexture
## The factor of each biome's water tint (Biomes.tints), by biome byte.
var water_factors := PackedColorArray()
var dirty := false
var biomes_dirty := false


## An empty map, to be filled chunk by chunk.
func prepare(_w = null) -> void:
	image = Image.create_empty(WRAP, WRAP, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	PixelTextures.set_global("roof_map", texture)
	PixelTextures.set_global("roof_map_soft", texture)
	RenderingServer.global_shader_parameter_set("wrap_size", Vector2(WRAP, WRAP) * 0.5)
	low_image = Image.create_empty(LOW_SIZE, LOW_SIZE, false, Image.FORMAT_RGBA8)
	low_texture = ImageTexture.create_from_image(low_image)
	PixelTextures.set_global("ground_low", low_texture)
	biome_image = Image.create_empty(WRAP, WRAP, false, Image.FORMAT_RG8)
	biome_image.fill(Color(1, 1, 1))
	biome_texture = ImageTexture.create_from_image(biome_image)
	PixelTextures.set_global("biome_map", biome_texture)
	tints_texture = ImageTexture.create_from_image(tints())
	water_factors = _water_factors()
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


## Biome b's tint of water as a factor of its own colour (1 where it has none).
static func _water_factors() -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(TINT_BIOMES)
	out.fill(Color(1, 1, 1))
	for b in mini(Biomes.RECORDS.size(), TINT_BIOMES - 1):
		var want = Biomes.tints(b).get(Mat.WATER)
		if want is Color:
			out[b] = Color(want.r / WATER_SHALLOW.r, want.g / WATER_SHALLOW.g, want.b / WATER_SHALLOW.b)
	return out


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
		var sloped: PackedInt64Array = c.sloped
		var cells: PackedByteArray = c.cells
		var all: int = w.all_bits
		for col in n * n:
			var top: int = w.top_level(~(air[col] | leaf[col]) & all)
			data[col * 4] = w.top_level(~(air[col] | water[col] | leaf[col]) & all) + 1
			data[col * 4 + 1] = (CROWN if leaf[col] != 0 else 0) | (top_bits(cells[(top << 8) | col], sloped[col], top) if top >= 0 else 0)
			data[col * 4 + 2] = top + 1
			data[col * 4 + 3] = 255 if top >= 0 and water[col] & (1 << top) else 0
	image.blit_rect(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data),
		Rect2i(0, 0, n, n), Vector2i((key.x * n) & MASK, (key.y * n) & MASK))
	dirty = true
	var lows := PackedByteArray()
	var m := n / LOW
	lows.resize(m * m * 4)
	var tops := PackedInt32Array()
	tops.resize(LOW * LOW)
	for i in m * m:
		for k in LOW * LOW:
			tops[k] = data[(((i / m) * LOW + k / LOW) * n + (i % m) * LOW + k % LOW) * 4 + 2]
		lows[i * 4] = low_mean(tops)
	_water_tints(w, key, c, data, lows)
	low_image.blit_rect(Image.create_from_data(m, m, false, Image.FORMAT_RGBA8, lows),
		Rect2i(0, 0, m, m), Vector2i(((key.x * n) & MASK) / LOW, ((key.y * n) & MASK) / LOW))
	if c != null:
		var pairs := PackedByteArray()
		pairs.resize(2 * n * n)
		for i in n * n:
			pairs[2 * i] = c.biome[i]
			pairs[2 * i + 1] = c.frost[i]
		biome_image.blit_rect(Image.create_from_data(n, n, false, Image.FORMAT_RG8, pairs),
			Rect2i(0, 0, n, n), Vector2i((key.x * n) & MASK, (key.y * n) & MASK))
		biomes_dirty = true


## The bits of the roof map's g under the crown's (CROWN) for the column whose top is
## material `m` at level `top`, `sloped` its slope mask: NO_PUDDLE where no puddle
## stands on it after rain (a material that drains, a sloping top), as world.gdshader
## leaves it dry; SLOPED where the top slopes, as a shore's does down under water flush
## with the land (WaterMesher.shore_water), while a bank that keeps a sheer wall
## (WorldData.SHEER) or an islet stays a dry cube level with that water. The figures'
## mirrors (sprite_mirror.gdshader) look both up: they showed on such dry ground beside
## the water (thread «Исправить диагональный берег»).
static func top_bits(m: int, sloped: int, top: int) -> int:
	if sloped & (1 << top) != 0:
		return NO_PUDDLE | SLOPED
	if m < Mat.shader_bits.size() and Mat.shader_bits[m] & Mat.DRAINS != 0:
		return NO_PUDDLE
	return 0


## Refreshes the column of a changed cell.
func touch(w, cell: Vector3i) -> void:
	if image == null:
		return
	var top: int = w.top_level(~(w.air_col(cell.x, cell.z) | w.leaf_col(cell.x, cell.z)) & w.all_bits)
	var bits := CROWN if w.leaf_col(cell.x, cell.z) != 0 else 0
	var c = w.chunk_at(cell.x, cell.z)
	if top >= 0 and c != null:
		bits |= top_bits(w.get_cell(cell.x, top, cell.z), c.sloped[((cell.z & w.MASK) << w.SHIFT) | (cell.x & w.MASK)], top)
	var crown := bits / 255.0
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
	var was := low_image.get_pixel(lx, lz)
	was.r = low_mean(tops) / 255.0
	low_image.set_pixel(lx, lz, was)


## Fills g, b, a of the chunk's blocks in `lows` (RGBA, a texel per LOW by LOW columns)
## with the colour of their water, over 2: the mean over the columns whose top is water
## of their biome's water tint times their body's (SEA_TINT, RIVER_TINT, LAKE_TINT) and
## the slow shading of the place (_vary). A block with no water takes the mean of the
## blocks with water beside it in the chunk, else its biome's lake, so the filtering
## between texels does not pull a shore's water towards some other colour.
func _water_tints(w, key: Vector2i, c, data: PackedByteArray, lows: PackedByteArray) -> void:
	var n: int = w.CHUNK
	var m := n / LOW
	var sums: Array[Color] = []
	sums.resize(m * m)
	var counts := PackedInt32Array()
	counts.resize(m * m)
	# The biome of a block, for one with no water near it.
	var biomes := PackedInt32Array()
	biomes.resize(m * m)
	biomes.fill(TINT_BIOMES - 1)
	for i in m * m:
		sums[i] = Color(0, 0, 0)
	if c != null:
		for col in n * n:
			var b: int = c.biome[col]
			var block := ((col / n) / LOW) * m + (col % n) / LOW
			biomes[block] = b
			if data[col * 4 + 3] == 0:
				continue
			var natural: int = c.natural[((data[col * 4 + 2] - 1) << 8) | col]
			var body := SEA_TINT if natural & w.SEA_WATER else (RIVER_TINT if natural & w.RIVER_WATER else LAKE_TINT)
			sums[block] += water_factors[b] * body
			counts[block] += 1
	var x0: int = key.x * n
	var z0: int = key.y * n
	for i in m * m:
		var f: Color
		if counts[i] > 0:
			f = sums[i] / counts[i]
		else:
			var near := Color(0, 0, 0, 0)
			var k := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var bx := i % m + dx
					var bz := i / m + dz
					if bx >= 0 and bz >= 0 and bx < m and bz < m and counts[bz * m + bx] > 0:
						near += sums[bz * m + bx] / counts[bz * m + bx]
						k += 1
			if k > 0:
				f = near / k
			else:
				f = water_factors[biomes[i]] * LAKE_TINT
		f *= _vary(x0 + (i % m) * LOW + LOW / 2, z0 + (i / m) * LOW + LOW / 2)
		lows[i * 4 + 1] = clampi(roundi(f.r * 127.5), 0, 255)
		lows[i * 4 + 2] = clampi(roundi(f.g * 127.5), 0, 255)
		lows[i * 4 + 3] = clampi(roundi(f.b * 127.5), 0, 255)


## The slow shading of water at column x, z (see VARY_CELLS): the same wherever and
## whenever it is asked.
static func _vary(x: int, z: int) -> Color:
	var light := 1.0 + VARY_LIGHT * (_noise(x, z, 0) * 2.0 - 1.0)
	var hue := VARY_HUE * (_noise(x, z, 1) * 2.0 - 1.0)
	return Color(light, light * (1.0 + hue), light * (1.0 - hue))


## Value noise of column x, z on a lattice of VARY_CELLS cells, 0..1, smoothed between
## its points; `seed` picks one of its kinds.
static func _noise(x: int, z: int, seed: int) -> float:
	var gx := floori(float(x) / VARY_CELLS)
	var gz := floori(float(z) / VARY_CELLS)
	var fx := float(x) / VARY_CELLS - gx
	var fz := float(z) / VARY_CELLS - gz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(_hash(gx, gz, seed), _hash(gx + 1, gz, seed), fx)
	var b := lerpf(_hash(gx, gz + 1, seed), _hash(gx + 1, gz + 1, seed), fx)
	return lerpf(a, b, fz)


static func _hash(x: int, z: int, seed: int) -> float:
	var h := (x * 374761393 + z * 668265263 + seed * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h & 0xFFFF) / 65535.0


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
