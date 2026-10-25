extends RefCounted
## The textures of the prototype's cell materials, each three tiles of TILE px side by
## side (the top, the sides, the underside), drawn from a seeded noise per texel:
## `tools/make_textures.gd` writes them into `content/<mod>/textures/<texture>.png`,
## where the game reads them (PixelTextures.build_atlas) and where they can be painted
## over by hand. Not loaded by the game.

const TILE := 16
const KINDS := 3

const DIRT := Color(0.47, 0.35, 0.25)
const STONE := Color(0.5, 0.52, 0.55)
const GRASS := Color(0.4, 0.54, 0.25)


## The texture named `name` (the bare id of the material), or null for one not drawn here.
static func picture(name: String) -> Image:
	if not name in ["grass", "dirt", "stone", "sand", "water", "log", "leaves", "planks", "clay", "copper_ore", "scree", "brick"]:
		return null
	var img := Image.create_empty(TILE * KINDS, TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	for kind in KINDS:
		rng.seed = hash(name) * 31 + kind + 7
		for py in TILE:
			for px in TILE:
				img.set_pixel(kind * TILE + px, py, _texel(name, kind, px, py, rng))
	return img


static func _vary(c: Color, rng: RandomNumberGenerator, amount := 0.05) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(c.r * k, c.g * k, c.b * k)


static func _texel(name: String, kind: int, px: int, py: int, rng: RandomNumberGenerator) -> Color:
	match name:
		"grass":
			if kind == 0:
				var r := rng.randf()
				return _vary(GRASS * (0.9 if r < 0.12 else (1.07 if r > 0.92 else 1.0)), rng, 0.03)
			if kind == 1 and py < 2 + (px * 7 % 3):
				return _vary(GRASS * 0.95, rng, 0.03)
			return _dirt(px, py, rng)
		"dirt":
			return _dirt(px, py, rng)
		"stone":
			if kind == 1:
				# Strata on walls.
				var seam := (py + (px / 5) % 2) % 6 == 5
				return _vary(STONE * (0.82 if seam else 1.0), rng, 0.03)
			var crack := (px * 3 + py * 5) % 23 == 0 or rng.randf() < 0.05
			return _vary(STONE * (0.85 if crack else 1.0), rng, 0.03)
		"sand":
			return _vary(Color(0.77, 0.67, 0.48) * (0.93 if rng.randf() < 0.1 else 1.0), rng, 0.025)
		"water":
			return Color(0.25, 0.45, 0.55)
		"log":
			if kind == 1:
				return _vary(Color(0.36, 0.27, 0.2) * (0.8 if px % 3 == 0 else 1.0), rng, 0.04)
			var r := Vector2(px - 7.5, py - 7.5).length()
			return _vary(Color(0.66, 0.52, 0.36) * (0.82 if int(r) % 3 == 0 else 1.0), rng, 0.03)
		"leaves":
			return _vary(Color(0.3, 0.45, 0.22) * (0.8 if rng.randf() < 0.25 else 1.0), rng, 0.06)
		"planks":
			var line := py % 4 == 3 or (px == (py / 4 * 5) % 16 and py % 4 != 3)
			return _vary(Color(0.64, 0.49, 0.33) * (0.72 if line else 1.0), rng, 0.03)
		"clay":
			return _vary(Color(0.6, 0.47, 0.4), rng, 0.03)
		"copper_ore":
			if rng.randf() < 0.12:
				return _vary(Color(0.78, 0.5, 0.3), rng)
			return _vary(STONE, rng, 0.03)
		"scree":
			# Pebbles of a few greys, a shade darker in the gaps between them.
			var r := rng.randf()
			var gap := (px + (py / 3) * 2) % 4 == 0 and py % 3 == 2
			var tone := 0.78 if gap else (0.9 if r < 0.3 else (1.08 if r > 0.8 else 1.0))
			return _vary(Color(0.52, 0.5, 0.48) * tone, rng, 0.035)
		"brick":
			var row := py / 4
			var mortar := py % 4 == 3 or (px + (row % 2) * 4) % 8 == 7
			return _vary(Color(0.74, 0.7, 0.64) if mortar else Color(0.58, 0.32, 0.25), rng, 0.04)
	return Color.MAGENTA


static func _dirt(px: int, py: int, rng: RandomNumberGenerator) -> Color:
	var r := rng.randf()
	if r < 0.06:
		return _vary(Color(0.6, 0.52, 0.42), rng, 0.03)
	return _vary(DIRT * (0.88 if r > 0.9 else 1.0), rng, 0.03)
