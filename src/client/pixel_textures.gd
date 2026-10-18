extends RefCounted
## Procedural 16x16 pixel textures for cell materials, packed into one atlas.
## Placeholder art until the content editor exists.

const Mat := preload("res://src/shared/materials.gd")

const TILE := 16
const TILES := 8


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


static func _vary(c: Color, rng: RandomNumberGenerator, amount := 0.07) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(c.r * k, c.g * k, c.b * k)


static func _texel(m: int, kind: int, px: int, py: int, rng: RandomNumberGenerator) -> Color:
	var dirt := Color(0.47, 0.32, 0.2)
	var stone := Color(0.5, 0.5, 0.53)
	var grass := Color(0.36, 0.62, 0.25)
	match m:
		Mat.GRASS:
			if kind == 0:
				return _vary(grass * (1.15 if rng.randf() < 0.12 else 1.0), rng)
			if kind == 1 and py < 3 + (px * 7 % 3):
				return _vary(grass, rng)
			return _vary(dirt, rng)
		Mat.DIRT:
			return _vary(dirt * (0.8 if rng.randf() < 0.1 else 1.0), rng)
		Mat.STONE:
			return _vary(stone * (0.8 if rng.randf() < 0.12 else 1.0), rng, 0.05)
		Mat.SAND:
			return _vary(Color(0.86, 0.79, 0.56), rng, 0.04)
		Mat.WATER:
			var wave := (px + py * 3) % 9 == 0
			return _vary(Color(0.42, 0.62, 0.86) if wave else Color(0.2, 0.42, 0.7), rng, 0.03)
		Mat.LOG:
			if kind == 1:
				return _vary(Color(0.4, 0.27, 0.15) * (0.8 if px % 4 == 0 else 1.0), rng)
			var r := Vector2(px - 7.5, py - 7.5).length()
			return _vary(Color(0.72, 0.56, 0.36) * (0.8 if int(r) % 3 == 0 else 1.0), rng, 0.04)
		Mat.LEAVES:
			return _vary(Color(0.25, 0.5, 0.2) * (0.75 if rng.randf() < 0.25 else 1.0), rng, 0.1)
		Mat.PLANKS:
			var line := py % 4 == 3 or (px == (py / 4 * 5) % 16 and py % 4 != 3)
			return _vary(Color(0.7, 0.52, 0.3) * (0.7 if line else 1.0), rng, 0.04)
		Mat.CLAY:
			return _vary(Color(0.62, 0.5, 0.45), rng, 0.04)
		Mat.COPPER_ORE:
			if rng.randf() < 0.14:
				return _vary(Color(0.85, 0.5, 0.25), rng)
			return _vary(stone, rng, 0.05)
		Mat.BRICK:
			var row := py / 4
			var mortar := py % 4 == 3 or (px + (row % 2) * 4) % 8 == 7
			return _vary(Color(0.78, 0.74, 0.68) if mortar else Color(0.62, 0.3, 0.22), rng, 0.05)
	return Color.MAGENTA
