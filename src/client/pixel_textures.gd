extends RefCounted
## Procedural pixel textures: 16x16 cell materials packed into one atlas, grass tufts,
## leaf clumps and the cloud noise. Placeholder art until the content editor exists.
## The palette is muted and warm; mood and colour shifts come from the colour grade.

const Mat := preload("res://src/shared/materials.gd")

const TILE := 16
const TILES := 8
const TUFT := 8
const CLUMP := 20


static func build_atlas() -> ImageTexture:
	var img := Image.create_empty(TILE * TILES, TILE * TILES, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	var rng := RandomNumberGenerator.new()
	for m in Mat.COUNT:
		for kind in 3:
			rng.seed = m * 31 + kind + 7
			var tile := m * 3 + kind
			var ox := (tile % TILES) * TILE
			var oy := floori(tile / float(TILES)) * TILE
			for py in TILE:
				for px in TILE:
					img.set_pixel(ox + px, oy + py, _texel(m, kind, px, py, rng))
	return ImageTexture.create_from_image(img)


## Four tuft variants side by side, 8x8 each. Alpha is the blade mask, red is the
## height along the blade (0 at the root, 1 at the tip).
static func build_tufts() -> ImageTexture:
	var img := Image.create_empty(TUFT * 4, TUFT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for v in 4:
		var blades := 3 + v % 2 + rng.randi_range(0, 1)
		for b in blades:
			var x := rng.randi_range(1, TUFT - 2)
			var h := rng.randi_range(3, TUFT - 1 - (v % 2))
			var lean := rng.randi_range(-1, 1)
			for i in h:
				var px := x + (lean if i >= h / 2 else 0)
				px = clampi(px, 0, TUFT - 1)
				var k := float(i + 1) / h
				img.set_pixel(v * TUFT + px, TUFT - 1 - i, Color(k, 0, 0, 1))
	return ImageTexture.create_from_image(img)


## Four leaf clump variants side by side, `size` px square: a lumpy round blob.
## Red is the brightness of each texel (leaves and gaps).
static func build_clumps(size := CLUMP) -> ImageTexture:
	var img := Image.create_empty(size * 4, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var noise := FastNoiseLite.new()
	noise.frequency = 0.35
	var c := (size - 1) / 2.0
	for v in 4:
		noise.seed = v * 7 + 1
		for y in size:
			for x in size:
				var d := Vector2(x - c, y - c)
				var bump := noise.get_noise_2d(x, y) * 2.8 * size / CLUMP
				if d.length() > c - 0.6 + bump:
					continue
				# Leafy lumps a few pixels across, and only rarely a single dark gap,
				# so the clump reads as a calm mass rather than noise.
				var b := 0.55 + noise.get_noise_2d(x * 1.4 + 40, y * 1.4) * 0.5
				if rng.randf() < 0.04:
					b -= 0.3
				# A darker rim along the lower edge separates overlapping clumps.
				if d.y > 0.0 and d.length() > c - 1.8 + bump:
					b -= 0.45
				img.set_pixel(v * size + x, y, Color(clampf(b, 0.0, 1.0), 0, 0, 1))
	return ImageTexture.create_from_image(img)


## Tileable noise for cloud shadows and water ripples.
static func build_cloud_noise() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var img := noise.get_seamless_image(128, 128)
	return ImageTexture.create_from_image(img)


static func _vary(c: Color, rng: RandomNumberGenerator, amount := 0.05) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(c.r * k, c.g * k, c.b * k)


static func _texel(m: int, kind: int, px: int, py: int, rng: RandomNumberGenerator) -> Color:
	var dirt := Color(0.47, 0.35, 0.25)
	var stone := Color(0.5, 0.52, 0.55)
	var grass := Color(0.4, 0.54, 0.25)
	match m:
		Mat.GRASS:
			if kind == 0:
				var r := rng.randf()
				return _vary(grass * (0.9 if r < 0.12 else (1.07 if r > 0.92 else 1.0)), rng, 0.03)
			if kind == 1 and py < 2 + (px * 7 % 3):
				return _vary(grass * 0.95, rng, 0.03)
			return _dirt(dirt, px, py, rng)
		Mat.DIRT:
			return _dirt(dirt, px, py, rng)
		Mat.STONE:
			if kind == 1:
				# Strata on walls.
				var seam := (py + (px / 5) % 2) % 6 == 5
				return _vary(stone * (0.82 if seam else 1.0), rng, 0.03)
			var crack := (px * 3 + py * 5) % 23 == 0 or rng.randf() < 0.05
			return _vary(stone * (0.85 if crack else 1.0), rng, 0.03)
		Mat.SAND:
			return _vary(Color(0.77, 0.67, 0.48) * (0.93 if rng.randf() < 0.1 else 1.0), rng, 0.025)
		Mat.WATER:
			return Color(0.25, 0.45, 0.55)
		Mat.LOG:
			if kind == 1:
				return _vary(Color(0.36, 0.27, 0.2) * (0.8 if px % 3 == 0 else 1.0), rng, 0.04)
			var r := Vector2(px - 7.5, py - 7.5).length()
			return _vary(Color(0.66, 0.52, 0.36) * (0.82 if int(r) % 3 == 0 else 1.0), rng, 0.03)
		Mat.LEAVES:
			return _vary(Color(0.3, 0.45, 0.22) * (0.8 if rng.randf() < 0.25 else 1.0), rng, 0.06)
		Mat.PLANKS:
			var line := py % 4 == 3 or (px == (py / 4 * 5) % 16 and py % 4 != 3)
			return _vary(Color(0.64, 0.49, 0.33) * (0.72 if line else 1.0), rng, 0.03)
		Mat.CLAY:
			return _vary(Color(0.6, 0.47, 0.4), rng, 0.03)
		Mat.COPPER_ORE:
			if rng.randf() < 0.12:
				return _vary(Color(0.78, 0.5, 0.3), rng)
			return _vary(stone, rng, 0.03)
		Mat.BRICK:
			var row := py / 4
			var mortar := py % 4 == 3 or (px + (row % 2) * 4) % 8 == 7
			return _vary(Color(0.74, 0.7, 0.64) if mortar else Color(0.58, 0.32, 0.25), rng, 0.04)
	return Color.MAGENTA


static func _dirt(dirt: Color, px: int, py: int, rng: RandomNumberGenerator) -> Color:
	var r := rng.randf()
	if r < 0.06:
		return _vary(Color(0.6, 0.52, 0.42), rng, 0.03)
	return _vary(dirt * (0.88 if r > 0.9 else 1.0), rng, 0.03)
