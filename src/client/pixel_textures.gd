extends RefCounted
## Procedural pixel textures: 16x16 cell materials packed into one atlas, grass tufts,
## leaf clusters and the cloud noise. Placeholder art until the content editor exists.
## The palette is muted and warm; mood and colour shifts come from the colour grade.

const Mat := preload("res://src/shared/materials.gd")

const TILE := 16
const TILES := 8
const TUFT := 8
## Ground plants: PLANTS variants, each PLANT_W x PLANT_H px (see build_plants).
const PLANT_W := 8
const PLANT_H := 16
const PLANTS := 14
## Leaf cluster cards of trees: every card is CLUMP px square, the bunch of leaves in it
## one of CLUMP_SIZES across. The texture has a row per size of broad-leaf bunch, then a
## row per size of needle sprig (from NEEDLE_ROW), then bare branches (BRANCH_ROW).
const CLUMP := 24
const CLUMP_SIZES := [24, 16, 11]
const NEEDLE_ROW := 3
const BRANCH_ROW := 6
const CLUMP_ROWS := 7
## Alpha of the pixels on the upper edge of a leaf, needle or twig (see _mark_edges).
const EDGE_ALPHA := 0.8
## Bush clusters: rows of bunches of leaves this many px across, then the same with
## berries on them, then bare twigs. Berry pixels carry BERRY_ALPHA, red a random number
## per berry and green its shading (1 the shine, 0 the shaded side).
const BUSH_SIZES := [12, 8]
const BERRY_ROW := 2
const BUSH_TWIG_ROW := 4
const BUSH_ROWS := 5
const BERRY_ALPHA := 0.65


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


## Ground plants side by side, each PLANT_W x PLANT_H px, drawn from the bottom row up
## (see grass.gdshader for the kinds): grass tufts 0..3, whose alpha is the blade mask
## and red the height along the blade (0 at the root, 1 at the tip), coloured from the
## ground; then plants in their own colours: flowers 4..7 (white, yellow, violet,
## pink), ears of dry grass 8..9, reeds with cattails 10..11, low herbs 12..13.
static func build_plants() -> ImageTexture:
	var img := Image.create_empty(PLANT_W * PLANTS, PLANT_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for v in 4:
		var blades := 3 + v % 2 + rng.randi_range(0, 1)
		for b in blades:
			var x := rng.randi_range(1, PLANT_W - 2)
			var h := rng.randi_range(3, TUFT - 1 - (v % 2))
			var lean := rng.randi_range(-1, 1)
			for i in h:
				var px := x + (lean if i >= h / 2 else 0)
				px = clampi(px, 0, PLANT_W - 1)
				var k := float(i + 1) / h
				_plant_px(img, v, px, i, Color(k, 0, 0, 1))
	var stem := Color(0.27, 0.46, 0.2)
	var stem_dark := Color(0.2, 0.36, 0.16)
	var heads := [Color(0.95, 0.95, 0.88), Color(0.96, 0.8, 0.22), Color(0.62, 0.45, 0.86), Color(0.92, 0.4, 0.5)]
	for v in 4:
		var head: Color = heads[v]
		for f in 2 + v % 2:
			var x: int = [2, 5, 3][f] + rng.randi_range(-1, 0)
			var h := rng.randi_range(4, 7)
			for i in h:
				_plant_px(img, 4 + v, x, i, stem if i % 2 == 0 else stem_dark)
			# A leaf off the stem, then the head two texels wide with a lit corner.
			_plant_px(img, 4 + v, x + (1 if f % 2 == 0 else -1), h / 2, stem)
			_plant_px(img, 4 + v, x, h, head.darkened(0.15))
			_plant_px(img, 4 + v, x + 1, h, head)
			_plant_px(img, 4 + v, x, h + 1, head)
			_plant_px(img, 4 + v, x + 1, h + 1, head.lightened(0.2))
	var straw := Color(0.76, 0.66, 0.38)
	var straw_dark := Color(0.62, 0.52, 0.3)
	var grain := Color(0.86, 0.76, 0.46)
	for v in 2:
		for e in 2 + v:
			var x: int = [2, 5, 4][e]
			var h := rng.randi_range(8, 11)
			var lean := rng.randi_range(-1, 1)
			for i in h:
				_plant_px(img, 8 + v, x + (lean if i > h * 2 / 3 else 0), i, straw if i % 3 != 2 else straw_dark)
			var tx := x + lean
			for i in 4:
				_plant_px(img, 8 + v, tx, h + i, grain if i % 2 == 0 else straw_dark)
				_plant_px(img, 8 + v, tx + 1, h + i, straw_dark if i % 2 == 0 else grain)
	var reed := Color(0.3, 0.5, 0.22)
	var reed_dark := Color(0.22, 0.4, 0.17)
	var cattail := Color(0.42, 0.27, 0.14)
	for v in 2:
		for r in 3:
			var x: int = [1, 4, 6][r]
			var h := rng.randi_range(9, 13) + (2 if r == 1 else 0)
			for i in h:
				_plant_px(img, 10 + v, x, i, reed if (i + r) % 3 != 0 else reed_dark)
			if r == 1:
				for i in 4:
					_plant_px(img, 10 + v, x, h + i, cattail)
					_plant_px(img, 10 + v, x + 1, h + i, cattail.darkened(0.2))
				_plant_px(img, 10 + v, x, h + 4, reed_dark)
				_plant_px(img, 10 + v, x, h + 5, straw)
			else:
				# A blade leaning away from the middle at the top.
				_plant_px(img, 10 + v, x + (1 if r == 2 else -1), h - 1, reed_dark)
	var herb := Color(0.25, 0.44, 0.19)
	var herb_light := Color(0.36, 0.56, 0.25)
	for v in 2:
		for i in 12:
			var x := rng.randi_range(1, PLANT_W - 2)
			var y := rng.randi_range(0, 2 + (1 if x > 2 and x < 6 else 0))
			_plant_px(img, 12 + v, x, y, herb_light if rng.randf() < 0.35 else herb)
		if v == 1:
			for i in 3:
				_plant_px(img, 12 + v, rng.randi_range(1, PLANT_W - 2), rng.randi_range(2, 4), Color(0.94, 0.94, 0.9))
	return ImageTexture.create_from_image(img)


## Sets texel (x, row) of plant `v`, rows counted from the bottom; off the plant it is
## dropped.
static func _plant_px(img: Image, v: int, x: int, row: int, c: Color) -> void:
	if x < 0 or x >= PLANT_W or row < 0 or row >= PLANT_H:
		return
	img.set_pixel(v * PLANT_W + x, PLANT_H - 1 - row, c)


## Leaf cluster cards: one row per size in `sizes`, four variants in each, every
## variant `cell` px square with the bunch centred in it. A bunch is a dense heap of
## pointed leaves, the outer ones pointing outward, so the edge of a crown is jagged with
## leaf tips. With `conifers` the needle and branch rows follow (see CLUMP_ROWS).
## Red is a random number per leaf (for its tone, wind and falling leaves), green and
## blue tilt the leaf's normal left/right and up/down (0.5 = no tilt), so the light bands
## of the crown end along leaf outlines. Alpha marks the upper edge of every leaf, so
## single leaves show the way grass blades do.
static func build_clumps(cell := CLUMP, sizes: Array = CLUMP_SIZES, conifers := true) -> ImageTexture:
	var rows := sizes.size() * (2 if conifers else 1) + (1 if conifers else 0)
	var img := Image.create_empty(cell * 4, cell * rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var c := Vector2(cell - 1, cell - 1) / 2.0
	for row in sizes.size():
		var size: int = sizes[row]
		for v in 4:
			_leaf_bunch(img, Vector2i(v * cell, row * cell), cell, size, c, rng)
			if conifers:
				_needle_sprig(img, Vector2i(v * cell, (row + sizes.size()) * cell), cell, size, c, rng)
	if conifers:
		for v in 4:
			_branches(img, Vector2i(v * cell, 2 * sizes.size() * cell), cell, rng)
	for row in rows:
		for v in 4:
			_mark_edges(img, Vector2i(v * cell, row * cell), cell)
	return ImageTexture.create_from_image(img)


## Leaf clusters of bushes, `cell` px squares: four variants of each of BUSH_SIZES, then
## the same bunches with berries, then twigs (see BUSH_SIZES).
static func build_bush_clumps(cell: int) -> ImageTexture:
	var img := Image.create_empty(cell * 4, cell * BUSH_ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var c := Vector2(cell - 1, cell - 1) / 2.0
	for row in BUSH_SIZES.size():
		for v in 4:
			var plain := Vector2i(v * cell, row * cell)
			var ripe := Vector2i(v * cell, (row + BERRY_ROW) * cell)
			# The same bunch twice, the second time with berries.
			var state := rng.state
			_leaf_bunch(img, plain, cell, BUSH_SIZES[row], c, rng)
			rng.state = state
			_leaf_bunch(img, ripe, cell, BUSH_SIZES[row], c, rng)
			_mark_edges(img, plain, cell)
			_mark_edges(img, ripe, cell)
			_berries(img, ripe, cell, 3, rng)
	for v in 4:
		var twigs := Vector2i(v * cell, BUSH_TWIG_ROW * cell)
		_branches(img, twigs, cell, rng)
		_mark_edges(img, twigs, cell)
	return ImageTexture.create_from_image(img)


## Draws `count` round berries two by two pixels on the leaves of the `cell` px
## square at `origin`, apart from each other, more of them on the lower half.
static func _berries(img: Image, origin: Vector2i, cell: int, count: int, rng: RandomNumberGenerator) -> void:
	var placed: Array[Vector2i] = []
	for attempt in 60:
		if placed.size() >= count:
			return
		var p := Vector2i(rng.randi_range(1, cell - 3), roundi(lerpf(1.0, cell - 3.0, sqrt(rng.randf()))))
		var on_leaves := true
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if img.get_pixelv(origin + p + d).a < 0.5:
				on_leaves = false
		var apart := placed.all(func(q: Vector2i) -> bool: return absi(q.x - p.x) > 2 or absi(q.y - p.y) > 2)
		if not on_leaves or not apart:
			continue
		placed.append(p)
		var berry := rng.randf()
		img.set_pixelv(origin + p, Color(berry, 1.0, 0.0, BERRY_ALPHA))
		img.set_pixelv(origin + p + Vector2i(1, 0), Color(berry, 0.5, 0.0, BERRY_ALPHA))
		img.set_pixelv(origin + p + Vector2i(0, 1), Color(berry, 0.5, 0.0, BERRY_ALPHA))
		img.set_pixelv(origin + p + Vector2i(1, 1), Color(berry, 0.0, 0.0, BERRY_ALPHA))


## Draws one bunch `size` px across into the `cell` px square at `origin`.
static func _leaf_bunch(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator) -> void:
	var length := clampf(size / 3.2, 3.0, 5.5)
	var leaves := []
	for k in int(size * 4.5):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (size / 2.0 - length * 0.9)
		leaves.append(c + Vector2(cos(a), sin(a)) * r)
	# Lower leaves are nearer the viewer and drawn over the upper ones.
	leaves.sort_custom(func(p, q): return p.y < q.y)
	for p: Vector2 in leaves:
		# Leaves point away from the middle of the bunch and hang a little.
		var out := p - c
		var dir := (out.normalized() if out.length() > 1.5 else Vector2.from_angle(rng.randf() * TAU)) + Vector2(0.0, 0.4)
		dir = dir.normalized().rotated(rng.randf_range(-0.5, 0.5))
		var side := Vector2(-dir.y, dir.x)
		var l := length * rng.randf_range(0.8, 1.15)
		var wide := rng.randf_range(1.0, 1.5)
		var leaf := Color(rng.randf(), rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75), 1)
		for y in range(floori(p.y - l), ceili(p.y + l) + 1):
			for x in range(floori(p.x - l), ceili(p.x + l) + 1):
				if x < 0 or y < 0 or x >= cell or y >= cell:
					continue
				var d := Vector2(x, y) - p
				var along := d.dot(dir) / l
				if along < 0.0 or along > 1.0:
					continue
				# A lens: widest a third of the way along, pointed at the tip.
				var t := along / 0.35 if along < 0.35 else (1.0 - along) / 0.65
				if absf(d.dot(side)) > wide * t + 0.15:
					continue
				img.set_pixel(origin.x + x, origin.y + y, leaf)


## Draws a spruce sprig `size` px across: a short twig across the card with needles
## hanging from it in short strokes, a dense mass a little wider than tall, its lower
## edge a fringe of tips.
static func _needle_sprig(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator) -> void:
	var half := size / 2.0
	var length := clampf(size / 6.0, 2.0, 3.5)
	var needles := []
	for k in int(size * 9.0):
		var u := rng.randf_range(-1.0, 1.0)
		# Thick in the middle, thinning toward the ends of the sprig; the twig droops.
		var fall := (1.0 - u * u * 0.7) * half * 0.85
		var p := c + Vector2(u * (half - 1.0), u * u * half * 0.3 - fall * 0.5 + rng.randf() * fall)
		needles.append(p)
	needles.sort_custom(func(p, q): return p.y < q.y)
	for p: Vector2 in needles:
		# Needles hang down and away from the middle of the sprig.
		var dir := Vector2(clampf((p.x - c.x) / half, -1.0, 1.0) * 0.8 + rng.randf_range(-0.4, 0.4), 1.0).normalized()
		var needle := Color(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7), 1)
		var l := length * rng.randf_range(0.7, 1.2)
		for i in ceili(l) + 1:
			var q := (p + dir * i).round()
			if q.x >= 0 and q.y >= 0 and q.x < cell and q.y < cell:
				img.set_pixel(origin.x + int(q.x), origin.y + int(q.y), needle)


## Draws bare twigs: branches growing up and outward from the bottom of the card,
## forking into thinner twigs on the way.
static func _branches(img: Image, origin: Vector2i, cell: int, rng: RandomNumberGenerator) -> void:
	var tips := []
	for k in 4:
		tips.append([Vector2(rng.randf_range(cell * 0.2, cell * 0.8), cell - 1.0),
			Vector2(rng.randf_range(-0.9, 0.9), -1.0).normalized(), rng.randf_range(cell * 0.5, cell * 0.85), 0])
	while not tips.is_empty():
		var t: Array = tips.pop_back()
		var p: Vector2 = t[0]
		var dir: Vector2 = t[1]
		var l: float = t[2]
		var twig := Color(rng.randf(), 0.5, rng.randf_range(0.4, 0.7), 1)
		for i in int(l):
			var q := (p + dir * i).round()
			if q.x < 0 or q.y < 0 or q.x >= cell or q.y >= cell:
				break
			img.set_pixel(origin.x + int(q.x), origin.y + int(q.y), twig)
			if t[3] < 3 and i > 1 and rng.randf() < 0.2:
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				tips.append([q, dir.rotated(rng.randf_range(0.4, 0.9) * side), (l - i) * 0.75, t[3] + 1])
			dir = dir.rotated(rng.randf_range(-0.15, 0.15))


## Marks the upper edge of every leaf in a card: a pixel whose upper neighbour is empty
## or another leaf gets EDGE_ALPHA, and the shader lights it a little.
static func _mark_edges(img: Image, origin: Vector2i, cell: int) -> void:
	for y in range(cell - 1, -1, -1):
		for x in cell:
			var p := img.get_pixel(origin.x + x, origin.y + y)
			if p.a < 0.5:
				continue
			var up := img.get_pixel(origin.x + x, origin.y + y - 1) if y > 0 else Color(0, 0, 0, 0)
			if up.a < 0.5 or not is_equal_approx(up.r, p.r):
				img.set_pixel(origin.x + x, origin.y + y, Color(p.r, p.g, p.b, EDGE_ALPHA))


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
