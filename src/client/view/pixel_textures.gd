extends RefCounted
## Procedural pixel textures: 16x16 cell materials packed into one atlas, grass tufts,
## leaf clusters and the cloud noise. Placeholder art until the content editor exists.
## The palette is muted and warm; mood and colour shifts come from the colour grade.

const Mat := preload("res://src/shared/content/materials.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Grass := preload("res://src/shared/world/grass.gd")

const TILE := 16
const TILES := 8
const TUFT := 8
## Ground plants: PLANTS variants, each PLANT_W x PLANT_H px (see build_plants).
const PLANT_W := 8
const PLANT_H := 24
const PLANTS := 29
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


## The atlas image, kept so scripts can read its tiles: reading a texture back is slow
## in the browser.
static var atlas_image: Image
## The average colour of each material's top tile (maps, particles), by material.
static var tints: PackedColorArray = []
## The bark of each tree species (Trees.SPECIES, a species' `bark` texture) as the
## material whose tiles it took in the atlas after the real ones, -1 for the log's own;
## the trunk mesher draws the trunk with it. The tiles are 6 bits in the mesh (63 none),
## so there is room for MOST_MATERIALS materials and barks together.
static var bark_material: PackedInt32Array = []
const MOST_MATERIALS := 21


## The atlas of the materials' textures, each read from its mod (Mat.texture_path: three
## tiles of TILE px side by side, the top, the sides and the underside) into tiles
## m * 3 + kind; magenta where a texture is missing or of another size (the validator
## reports it).
static func build_atlas() -> ImageTexture:
	var img := Image.create_empty(TILE * TILES, TILE * TILES, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	tints = []
	tints.resize(Mat.COUNT)
	for m in Mat.COUNT:
		tints[m] = Color(0.55, 0.5, 0.45)
		var tex := texture_of(m)
		if tex == null:
			continue
		_blit_tiles(img, tex, m)
		var sum := Color.BLACK
		for py in TILE:
			for px in TILE:
				sum += tex.get_pixel(px, py)
		tints[m] = sum / float(TILE * TILE)
	# The barks of the tree species after the materials, each a material of its own
	# to the mesh and the shader.
	bark_material = []
	bark_material.resize(Trees.SPECIES.size())
	var next := Mat.COUNT
	for i in Trees.SPECIES.size():
		bark_material[i] = -1
		var tex := _three_tiles(Trees.bark_path(i))
		if tex == null:
			continue
		if next >= MOST_MATERIALS:
			push_warning("no room in the atlas for the bark of %s" % Trees.SPECIES[i].id)
			continue
		_blit_tiles(img, tex, next)
		bark_material[i] = next
		next += 1
	atlas_image = img
	return ImageTexture.create_from_image(img)


## How many materials the atlas holds, the barks included (see bark_material).
static func material_count() -> int:
	var n := Mat.COUNT
	for b in bark_material:
		if b >= 0:
			n += 1
	return n


static func _blit_tiles(img: Image, tex: Image, m: int) -> void:
	for kind in 3:
		var tile := m * 3 + kind
		img.blit_rect(tex, Rect2i(kind * TILE, 0, TILE, TILE), Vector2i((tile % TILES) * TILE, floori(tile / float(TILES)) * TILE))


## The texture of material `m` as its mod gives it, null when it is missing or not
## three tiles of TILE px in a row.
static func texture_of(m: int) -> Image:
	if m <= 0 or m >= Mat.COUNT:
		return null
	return _three_tiles(Mat.texture_path(m))


## The image at `path` when it is three tiles of TILE px in a row, else null.
static func _three_tiles(path: String) -> Image:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var img := tex.get_image() if tex != null else null
	if img == null or img.get_width() != TILE * 3 or img.get_height() != TILE:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## The average colour of material `m`'s top tile, a neutral brown for none.
static func tint(m: int) -> Color:
	if tints.is_empty():
		build_atlas()
	return tints[m] if m >= 0 and m < tints.size() else Color(0.55, 0.5, 0.45)


## Ground plants side by side, each PLANT_W x PLANT_H px, drawn from the bottom row up
## (see grass.gdshader for the kinds): grass tufts 0..3, whose alpha is the blade mask
## and red the height along the blade (0 at the root, 1 at the tip), coloured from the
## ground; then plants in their own colours: flowers 4..7 (white, yellow, violet,
## pink), ears of dry grass 8..9, reeds with cattails 10..11, low herbs 12..13, low grass
## 14..17 and tall grass 18..21 (both masks like the tufts), cushions of moss 22..23,
## groups of mushrooms 24..25 and of glowing mushrooms 26..27, a spore 28 (see Grass).
static func build_plants() -> ImageTexture:
	var img := Image.create_empty(PLANT_W * (PLANTS + Plants.custom_frames()), PLANT_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The mods' own plants after the engine's (Plants.CUSTOM, Grass.CUSTOM): each a
	# row of frames of its picture, blank where the picture is missing or of another
	# size (the validator reports it).
	for c in Plants.CUSTOM:
		var path := Plants.sprite_path(c)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var pic := tex.get_image() if tex != null else null
		if pic == null or pic.get_width() != PLANT_W * c.frames or pic.get_height() != PLANT_H:
			continue
		pic.convert(Image.FORMAT_RGBA8)
		img.blit_rect(pic, Rect2i(0, 0, pic.get_width(), PLANT_H), Vector2i(PLANT_W * (PLANTS + c.first), 0))
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
	# Low grass: two or three short blades, the ground shows between them.
	for v in 4:
		for b in 2 + v % 2:
			var x: int = [1, 5, 3, 6][b + v % 2]
			var h := rng.randi_range(2, 4)
			for i in h:
				_plant_px(img, 14 + v, x, i, Color(float(i + 1) / h, 0, 0, 1))
	# Tall grass: five or six long blades that lean more and more toward the tip, so a
	# meadow of them waves as one; red is still the height for the tip light.
	for v in 4:
		var blades := 5 + v % 2
		for b in blades:
			var x := 1 + (b * 6) / blades + rng.randi_range(0, 1)
			var h := rng.randi_range(13, 17 + 2 * (v / 2))
			var lean := 1 if (x + v) % 2 == 0 else -1
			for i in h:
				var px := x + (lean if i >= h * 2 / 3 else 0) + (lean if i >= h * 5 / 6 else 0)
				px = clampi(px, 0, PLANT_W - 1)
				var k := float(i + 1) / h
				_plant_px(img, 18 + v, px, i, Color(k, 0, 0, 1))
	# Moss: low lumpy cushions, yellow-green and lit on their tops, darker in the
	# hollows between them, with a few stalks of spore boxes on one.
	var moss := Color(0.26, 0.42, 0.14)
	var moss_light := Color(0.5, 0.68, 0.2)
	for v in 2:
		var tops: Array = [[0, 2, 3, 2, 1, 2, 3, 1], [1, 3, 2, 0, 2, 3, 3, 1]][v]
		for x in PLANT_W:
			var h: int = tops[x]
			for i in h:
				var c := moss.lightened(0.12 * i)
				if i == h - 1:
					c = moss_light if rng.randf() < 0.7 else moss_light.darkened(0.15)
				_plant_px(img, 22 + v, x, i, c)
		if v == 1:
			for x in [1, 5]:
				_plant_px(img, 23, x, tops[x], Color(0.45, 0.32, 0.18))
				_plant_px(img, 23, x, tops[x] + 1, Color(0.72, 0.5, 0.24))
	# Mushrooms: two or three on a card, white stems and wide caps lit on top: brown
	# boletes, orange chanterelles.
	var stem_pale := Color(0.92, 0.88, 0.76)
	var caps := [Color(0.62, 0.32, 0.14), Color(0.92, 0.6, 0.16)]
	for v in 2:
		var cap: Color = caps[v]
		for f in 2 + v:
			var x: int = [2, 5, 4][f]
			var h: int = [3, 4, 2][f]
			for i in h:
				_plant_px(img, 24 + v, x, i, stem_pale if i > 0 else stem_pale.darkened(0.2))
			for dx in [-1, 0, 1, 2]:
				_plant_px(img, 24 + v, x + dx, h, cap.darkened(0.25))
				if dx == 0 or dx == 1:
					_plant_px(img, 24 + v, x + dx, h + 1, cap.lightened(0.2 if dx == 0 else 0.0))
	# Glowing mushrooms: thin pale stems and small caps the shader makes glow at night
	# (where green stands well above red).
	var glows := [Color(0.42, 0.95, 0.82), Color(0.5, 0.85, 1.0)]
	for v in 2:
		var cap: Color = glows[v]
		for f in 3:
			var x: int = [1, 4, 6][f] + (v if f == 1 else 0)
			var h: int = [3, 4, 2][f] + v
			for i in h:
				_plant_px(img, 26 + v, x, i, Color(0.78, 0.8, 0.74))
			_plant_px(img, 26 + v, x - 1, h, cap.darkened(0.25))
			_plant_px(img, 26 + v, x, h, cap)
			_plant_px(img, 26 + v, x + 1, h, cap.darkened(0.25))
			_plant_px(img, 26 + v, x, h + 1, cap.lightened(0.3))
	# A spore: one bright texel, carried up by the shader.
	_plant_px(img, 28, 3, 0, Color(0.6, 1.0, 0.85))
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


## Tileable noise for cloud shadows, water ripples and the ground patches (see
## Grass.cloud_noise, which scripts read the same patches from).
static func build_cloud_noise() -> ImageTexture:
	return ImageTexture.create_from_image(Grass.cloud_noise())
