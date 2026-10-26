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
const CLUMP := 32
const CLUMP_SIZES := [28, 22, 16]
## Needle rows: spruce branches pointing eight ways (two rows of four, leaves.gdshader
## picks one by the way the card points on the screen), then tufts for the tips.
const NEEDLE_ROW := 3
const BRANCH_ROW := 6
## Then the curly lumps and the scale-like broad leaves, a row per size each.
const CURLY_ROW := 7
const SCALES_ROW := 10
## Then spruce branches smaller and larger than those of the needle rows, for the top
## and the bottom of a cone: four ways each (right, down-right, down, up-right; the
## shader mirrors them for the left), small in SMALL_BRANCH_ROW, large in
## LARGE_BRANCH_ROW, and the two pointing up in UP_BRANCH_ROW, small then large.
const SMALL_BRANCH_ROW := 13
const UP_BRANCH_ROW := 14
const LARGE_BRANCH_ROW := 15
const CLUMP_ROWS := 16
## Lengths of the small and the large spruce branches, as shares of the card.
const SMALL_BRANCH := 0.5
const LARGE_BRANCH := 0.8
## The ways of the mirrored rows, in order (see _spruce_branch).
const BRANCH_WAYS := [0, 1, 2, 7]
## The first row of each leaf style (Trees.LEAF_STYLES).
## A layered crown (Foliage._broad) takes only the largest bundle of its style, so the
## pointed style's smaller rows hold the soft one: leaves blunter and wider (linden, birch).
const LEAF_ROWS := {"pointed": 0, "soft": 1, "needles": NEEDLE_ROW, "curly": CURLY_ROW, "scales": SCALES_ROW}
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
	# Species sharing a bark (one picture in the mod's common/) share its tiles.
	var by_path := {}
	for i in Trees.SPECIES.size():
		bark_material[i] = -1
		var path := Trees.bark_path(i)
		if by_path.has(path):
			bark_material[i] = by_path[path]
			continue
		var tex := _three_tiles(path)
		if tex == null:
			continue
		if next >= MOST_MATERIALS:
			push_warning("no room in the atlas for the bark of %s" % Trees.SPECIES[i].id)
			continue
		_blit_tiles(img, tex, next)
		bark_material[i] = next
		by_path[path] = next
		next += 1
	atlas_image = img
	return ImageTexture.create_from_image(img)


## How many materials the atlas holds, the barks included (see bark_material).
static func material_count() -> int:
	var n := Mat.COUNT
	for b in bark_material:
		n = maxi(n, b + 1)
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
	var rows := CLUMP_ROWS if conifers else sizes.size()
	var img := Image.create_empty(cell * 4, cell * rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var c := Vector2(cell - 1, cell - 1) / 2.0
	for row in sizes.size():
		var size: int = sizes[row]
		for v in 4:
			if row == 0:
				_leaf_bunch(img, Vector2i(v * cell, row * cell), cell, size, c, rng)
			else:
				_bundle(img, Vector2i(v * cell, row * cell), cell, sizes[row - 1], c, rng, "soft")
			if conifers:
				# Spruce branches pointing one of eight ways round, the first four in the
				# first needle row, the others in the next, then tufts for the tips.
				var at := Vector2i(v * cell, (row + sizes.size()) * cell)
				if row < 2:
					_spruce_branch(img, at, cell, row * 4 + v, c, rng)
				else:
					_needle_sprig(img, at, cell, sizes[1], c, rng)
	if conifers:
		for v in 4:
			_branches(img, Vector2i(v * cell, 2 * sizes.size() * cell), cell, rng)
		for row in sizes.size():
			for v in 4:
				_curly_bunch(img, Vector2i(v * cell, (CURLY_ROW + row) * cell), cell, sizes[row], c, rng)
				_scale_bunch(img, Vector2i(v * cell, (SCALES_ROW + row) * cell), cell, sizes[row], c, rng)
		for v in 4:
			_spruce_branch(img, Vector2i(v * cell, SMALL_BRANCH_ROW * cell), cell, BRANCH_WAYS[v], c, rng, SMALL_BRANCH)
			_spruce_branch(img, Vector2i(v * cell, LARGE_BRANCH_ROW * cell), cell, BRANCH_WAYS[v], c, rng, LARGE_BRANCH)
		_spruce_branch(img, Vector2i(0, UP_BRANCH_ROW * cell), cell, 6, c, rng, SMALL_BRANCH)
		_spruce_branch(img, Vector2i(cell, UP_BRANCH_ROW * cell), cell, 6, c, rng, LARGE_BRANCH)
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


## Leaf bundles after SLYNYRD (Pixelblog 44). A bundle is a ball of broad leaves
## pointing outward (up at its top, down at its bottom), the inner ones on top, each
## leaf with a lit and a dark half and a dark rim, shaded as a sphere: a crescent a
## step darker along the lower left, a circle a step lighter on the upper right. Green
## holds the tone, a step of the tree's ramp from BUNDLE_DARKEST to BUNDLE_LIGHTEST
## below or above its own colour (see _tone_px); leaves.gdshader turns the steps into
## colours and lights each bundle as a whole by where it lies in the crown, so a crown
## is bundles in dark, middle and light variants layered toward the sun. Red is a
## random number per leaf.
const BUNDLE_DARKEST := -4
const BUNDLE_LIGHTEST := 1
## Steps of a leaf's parts in a bundle of middle value: the rim, the dark half, the
## lit half.
const LEAF_RIM := -3
const LEAF_BODY := -2
const LEAF_LIT := 0


## Draws one bundle of pointed (rhombus) leaves `size` px across.
static func _leaf_bunch(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator) -> void:
	_bundle(img, origin, cell, size, c, rng, "pointed")


## Draws a bundle `size` px across of small square leaves, 2 by 2 px, touching but not
## overlapping (small leaves; lime, linden).
static func _curly_bunch(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator) -> void:
	_bundle(img, origin, cell, size, c, rng, "squares")


## Draws a bundle `size` px across of round leaves.
static func _scale_bunch(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator) -> void:
	_bundle(img, origin, cell, size, c, rng, "round")


static func _bundle(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator, style: String) -> void:
	var r := size / 2.0
	var k := size / 28.0
	var px := {}
	var ids := {}
	# A dark heap under the leaves, so no gap shows through.
	var heap := r - 4.0 * k
	for y in range(-ceili(r), ceili(r) + 1):
		for x in range(-ceili(r), ceili(r) + 1):
			if Vector2(x / heap, y / (heap * 0.9)).length() <= 1.0:
				px[Vector2i(x, y)] = LEAF_RIM
				ids[Vector2i(x, y)] = 0.5
	if style == "pointed" or style == "soft":
		var leaves := []
		for i in 9:
			var a := (i + rng.randf_range(-0.15, 0.15)) / 9.0 * TAU
			leaves.append([0, a, rng.randf_range(3.5, 4.5) * k, rng.randf_range(9.5, 10.5) * k, rng.randf_range(3.3, 3.8) * k])
		for i in 6:
			var a := (i + 0.5 + rng.randf_range(-0.2, 0.2)) / 6.0 * TAU
			leaves.append([1, a, rng.randf_range(0.5, 1.2) * k, rng.randf_range(7.5, 8.5) * k, rng.randf_range(3.0, 3.4) * k])
		leaves.append([2, -PI / 2.0 + rng.randf_range(-0.6, 0.6), 0.0, 6.0 * k, 2.8 * k])
		# Outer ring first, the upper leaves under the lower ones.
		leaves.sort_custom(func(p: Array, q: Array) -> bool:
			return p[0] < q[0] or (p[0] == q[0] and sin(p[1]) * p[2] < sin(q[1]) * q[2]))
		for l: Array in leaves:
			var o := Vector2(cos(l[1]) * l[2], sin(l[1]) * l[2] * 0.9)
			var id := rng.randf()
			# The leaves turn a little the same way round, a pinwheel.
			var leaf := _rhombus(l[3], l[4] * (1.2 if style == "soft" else 1.0), l[1] + 0.3, style == "soft")
			for q: Vector2i in leaf:
				var p := Vector2i(roundi(o.x + q.x), roundi(o.y + q.y * 0.92))
				px[p] = leaf[q]
				ids[p] = id
	elif style == "round":
		var spots: Array[Vector2] = []
		for i in 26:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * (r - 3.2 * k)
			spots.append(Vector2(cos(a) * d, sin(a) * d * 0.9))
		spots.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y - absf(p.x) * 0.2 < q.y - absf(q.x) * 0.2)
		for s in spots:
			var id := rng.randf()
			var leaf := _disc(rng.randf_range(2.3, 2.8) * k)
			for q: Vector2i in leaf:
				var p := Vector2i(roundi(s.x) + q.x, roundi(s.y) + q.y)
				px[p] = leaf[q]
				ids[p] = id
	else:
		# Squares touch in places but never overlap, so the square shape prevails.
		var cells: Array[Vector2i] = []
		for y in range(-ceili(r), ceili(r) + 1):
			for x in range(-ceili(r), ceili(r) + 1):
				if Vector2(x / (r - 1.0), y / ((r - 1.0) * 0.9)).length() <= 1.0:
					cells.append(Vector2i(x, y))
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := cells[i]
			cells[i] = cells[j]
			cells[j] = t
		var taken := {}
		for p in cells:
			var sq := [p, p + Vector2i(1, 0), p + Vector2i(0, 1), p + Vector2i(1, 1)]
			if sq.any(func(q: Vector2i) -> bool: return taken.has(q)):
				continue
			var around := 0
			for q: Vector2i in [p + Vector2i(-1, 0), p + Vector2i(-1, 1), p + Vector2i(2, 0), p + Vector2i(2, 1),
					p + Vector2i(0, -1), p + Vector2i(1, -1), p + Vector2i(0, 2), p + Vector2i(1, 2)]:
				around += 1 if taken.has(q) else 0
			if around > 3 and rng.randf() < 0.7:
				continue
			var id := rng.randf()
			var tone := LEAF_BODY + (1 if rng.randf() < 0.33 else 0)
			for q: Vector2i in sq:
				taken[q] = true
				ids[q] = id
			px[p] = tone + 1
			px[p + Vector2i(1, 0)] = tone
			px[p + Vector2i(0, 1)] = tone
			px[p + Vector2i(1, 1)] = tone - 1
	# Shaded as a sphere lit from the upper right.
	for p: Vector2i in px:
		var d := Vector2(p).length() / r
		var crescent := (-p.x + p.y) / r > 0.45 - d * 0.1 and d > 0.35
		var lit := Vector2(p.x - r * 0.28, p.y + r * 0.3).length() < r * 0.48
		_tone_px(img, origin, cell, roundi(c.x) + p.x, roundi(c.y) + p.y, ids[p], px[p] - (1 if crescent else 0) + (1 if lit else 0))


## Pixels of a leaf from (0, 0) out along `angle`, `length` long and `width` wide at a
## third of the way: LEAF_RIM on its lower-left border, LEAF_LIT on the half facing the
## light (upper right), LEAF_BODY on the other half; `soft`: an oval with a blunt tip.
static func _rhombus(length: float, width: float, angle: float, soft := false) -> Dictionary:
	var ca := cos(angle)
	var sa := sin(angle)
	var shape := {}
	var reach := ceili(length) + 2
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var u := x * ca + y * sa
			var v := -x * sa + y * ca
			if u < -0.3 or u > length:
				continue
			var t := u / (length * 0.35) if u < length * 0.35 else (length - u) / (length * 0.65)
			# A soft leaf is an oval with a blunt tip.
			if soft:
				t = pow(clampf(t, 0.0, 1.0), 0.45)
			if absf(v) <= width * t + 0.35:
				shape[Vector2i(x, y)] = v
	# The side of the midrib that faces the light (1, -1).
	var lit_side := 1.0 if (-sa - ca) < 0.0 else -1.0
	var out := {}
	for p: Vector2i in shape:
		if not shape.has(p + Vector2i(-1, 0)) or not shape.has(p + Vector2i(0, 1)):
			out[p] = LEAF_RIM
		elif shape[p] * lit_side < -0.2:
			out[p] = LEAF_LIT
		else:
			out[p] = LEAF_BODY
	return out


## Pixels of a round leaf of radius `r`, parts as in _rhombus.
static func _disc(r: float) -> Dictionary:
	var out := {}
	var reach := ceili(r) + 1
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= r * r + 0.5:
				out[Vector2i(x, y)] = LEAF_BODY
	for p: Vector2i in out.keys():
		if not out.has(p + Vector2i(-1, 0)) or not out.has(p + Vector2i(0, 1)):
			out[p] = LEAF_RIM
		elif p.x - p.y > r * 0.4:
			out[p] = LEAF_LIT
	return out


## Sets a texel of a bundle: red `id`, green the step `off` of the ramp (BUNDLE_DARKEST
## .. BUNDLE_LIGHTEST) as a fraction.
static func _tone_px(img: Image, origin: Vector2i, cell: int, x: int, y: int, id: float, off: int) -> void:
	if x < 0 or y < 0 or x >= cell or y >= cell:
		return
	off = clampi(off, BUNDLE_DARKEST, BUNDLE_LIGHTEST)
	img.set_pixel(origin.x + x, origin.y + y, Color(id, float(off - BUNDLE_DARKEST) / (BUNDLE_LIGHTEST - BUNDLE_DARKEST), 0.5, 1.0))


## Draws a conifer sprig `size` px across: feathery branches (a spine, needle strokes
## slanting toward the tip, a serrated rim) radiating from the middle of the card, the
## ones pointing down (toward the viewer) drawn last, those toward the light (right)
## lighter and the left ones darker, so the card is a whole tuft of branches with no
## empty half to float above the next.
static func _needle_sprig(img: Image, origin: Vector2i, cell: int, size: int, c: Vector2, rng: RandomNumberGenerator) -> void:
	var k := size / 28.0
	var fronds := []
	for i in 7:
		var a := (i + rng.randf_range(-0.2, 0.2)) / 7.0 * TAU
		fronds.append(a)
	fronds.sort_custom(func(p: float, q: float) -> bool: return sin(p) < sin(q))
	for a: float in fronds:
		# Seen from above at 3/4 the tuft is flattened, and its branches droop.
		var dir := Vector2(cos(a), sin(a) * 0.6 + 0.25).normalized()
		var length := (13.0 - 3.0 * maxf(0.0, -sin(a))) * k * rng.randf_range(0.9, 1.05)
		var base := 1 if dir.x > 0.35 else (0 if dir.x > -0.35 else -1)
		var shape := _frond(length, 3.8 * k, dir.angle())
		var id := rng.randf()
		for q: Vector2i in shape:
			_tone_px(img, origin, cell, roundi(c.x) + q.x, roundi(c.y) + q.y, id, shape[q] + base)


## Draws a spruce branch (SLYNYRD's conifer): a broad frond from just behind the middle
## of the card out toward `way` of eight (0 right, then clockwise on the screen), widest
## a little before its middle and pointed, its edges stepped by the tips of its leaflets
## (deeper on the side away from the light, upper right), dark strokes of the leaflets
## slanting toward the tip, a dark rim. One fill: the light and shade of the branch as a
## whole come from the card (leaves.gdshader), as SLYNYRD shades whole branches light,
## middle or dark.
static func _spruce_branch(img: Image, origin: Vector2i, cell: int, way: int, c: Vector2, rng: RandomNumberGenerator,
		size := 0.6) -> void:
	var length := roundi(cell * size * rng.randf_range(0.95, 1.05))
	var width := length * 0.33
	# The frond pointing right with the light above it, cells (u, v).
	var shape := {}
	for u in length + 1:
		var t := float(u) / length
		var h := width * pow(sin(PI * minf(1.0, t * 0.85 + 0.12)), 0.8)
		for v in range(-ceili(width) - 1, ceili(width) + 2):
			var step := fmod(u + absf(v) * 0.6, 3.0)
			var edge := h - ((1.6 if step < 1.2 else 0.0) if v > 0 else (0.9 if step < 1.0 else 0.0))
			if absf(v) <= edge + 0.2:
				shape[Vector2i(u, v)] = true
	var a := way * TAU / 8.0
	var dir := Vector2(cos(a), sin(a))
	var side := Vector2(-dir.y, dir.x)
	# The side of the frond toward the light is its upper one (v < 0).
	var flip := 1.0 if (-side).dot(Vector2(1.0, -1.0)) > 0.0 else -1.0
	# A long branch starts farther behind the middle, or its tip would leave the card.
	var from := c - dir * length * (0.2 if size <= 0.6 else 0.42)
	var id := rng.randf()
	for y in cell:
		for x in cell:
			var rel := Vector2(x, y) - from
			var q := Vector2i(roundi(rel.dot(dir)), roundi(rel.dot(side) * flip))
			if not shape.has(q):
				continue
			var off := LEAF_LIT
			var rim := false
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not shape.has(q + n):
					rim = true
			var stroke := fmod(q.x - absi(q.y) * 1.2 + 40.0, 4.0)
			if rim:
				off = LEAF_RIM
			elif absi(q.y) >= 1 and stroke < 0.8 and q.x < length - 2:
				off = LEAF_BODY + 1
			elif q.y < 0 and stroke > 2.5:
				off = LEAF_LIT + 1
			if q.x < length / 4 and not rim:
				off -= 1
			_tone_px(img, origin, cell, x, y, id, off)


## Pixels of a frond from (0, 0) out along `angle`: steps from LEAF_RIM to LEAF_LIT.
static func _frond(length: float, width: float, angle: float) -> Dictionary:
	var ca := cos(angle)
	var sa := sin(angle)
	var shape := {}
	var reach := ceili(length) + 2
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			var u := x * ca + y * sa
			var v := -x * sa + y * ca
			if u < 0.0 or u > length:
				continue
			var t := u / length
			var half := width * minf(1.0, t * 3.5) * pow(1.0 - t, 0.55)
			# Serrated: teeth along the frond.
			var tooth := 0.9 * fmod(u + absf(v) * 0.9, 3.0) / 3.0
			if absf(v) <= half - tooth + 0.4:
				shape[Vector2i(x, y)] = Vector2(u, v)
	var lit_side := 1.0 if (-sa - ca) < 0.0 else -1.0
	var out := {}
	for p: Vector2i in shape:
		var uv: Vector2 = shape[p]
		if not shape.has(p + Vector2i(-1, 0)) or not shape.has(p + Vector2i(0, 1)):
			out[p] = LEAF_RIM
		elif absf(uv.y) < 0.6 or fmod(uv.x + absf(uv.y), 3.0) < 1.0:
			out[p] = LEAF_BODY
		else:
			out[p] = LEAF_LIT if uv.y * lit_side < 0.0 else LEAF_BODY
	return out


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
