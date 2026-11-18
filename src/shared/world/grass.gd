extends RefCounted
## What grows on the top of a ground cell: the plants drawn there (Foliage) are the ones
## cutting the grass gives (WorldActions), so both read them from here, from a hash of
## the cell and slow noises over the map. Grass grows in tiers that follow the ground's
## own patches (ground_patch, the noise that also tints the ground): bare dirt on the
## lowest spots, low sparse grass on thin ground, the ordinary tufts in between (the
## shader thins them further); and over them, by a slow noise of their own, wide meadows
## of tall grass, three tufts a cell, several chunks across, with wide lawns of dense low
## grass between them. Flowers and low herbs grow in clumps of their own; ears of dry grass
## stand in fields on flat fertile lowland and hardly anywhere else; reeds line the
## water, except on sand. In the shade of the crowns moss grows in patches on the forest
## floor and mushrooms in groups, and here and there groups of mushrooms that glow at
## night. A cell the player cut or sowed (WorldData.turf) changes what grows on it.

const Mat := preload("res://src/shared/content/materials.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Plant kinds, the rows of PixelTextures.build_plants and grass.gdshader: tufts from
## 0, then flowers, ears, reeds, herbs, low tufts, tall tufts, moss, mushrooms, glowing
## mushrooms, and last the spores that rise from those at night and their glow (drawn
## only, see Foliage).
const FLOWER := 4
const EAR := 8
const REED := 10
const HERB := 12
const LOW := 14
const TALL := 18
const MOSS := 22
const MUSHROOM := 24
const GLOW := 26
const SPORE := 28
const HALO := 29
## The plants the mods bring with their own pictures (Plants.CUSTOM) take the kinds
## from here on, a kind per frame: CUSTOM + the plant's `first` + the frame.
const CUSTOM := 30
## Grass tiers by the patch noise.
const BARE_TIER := 0
const LOW_TIER := 1
const MID_TIER := 2
const TALL_TIER := 3
## A dense lawn of low grass, two or three tufts a cell (see MEADOW_TALL).
const LAWN_TIER := 4
## What a world laid out by hand (WorldData.grows) makes grow on a column whatever the
## noises say: a field of ears, moss, moss with mushrooms, moss with glowing mushrooms,
## nothing; from GROW_PLANT on one plant alone, the plant of that place in the load
## order (Plants.BY_ID) at GROW_PLANT + its index.
const GROW_EARS := 1
const GROW_MOSS := 2
const GROW_MUSHROOMS := 3
const GROW_GLOW := 4
const GROW_NONE := 5
const GROW_PLANT := 16
## Flowers grow in clumps where the flower noise is above FLOWER_CLUMP: on most cells
## at its rim, two to a cell more and more toward its heart (FLOWER_HEART above the
## rim); a lone flower outside on FLOWERS_APART of the cells.
const FLOWER_CLUMP := 0.42
const FLOWER_HEART := 0.15
const FLOWERS_APART := 0.004
## How far from a crown the plants of the woods (`grows: woods`) still come out onto open
## grass, in cells.
const WOODS_EDGE := 3
const WOODS_PROBES: Array[Vector2i] = [Vector2i(WOODS_EDGE, 0), Vector2i(-WOODS_EDGE, 0), Vector2i(0, WOODS_EDGE),
	Vector2i(0, -WOODS_EDGE), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]
## Lowland for ears: this many levels above the sea at most.
const FERTILE_LEVELS := 10
## The meadow noise (meadow_noise, about 140 cells from one meadow to the next): tall
## grass above MEADOW_TALL, a dense lawn of low grass below -MEADOW_TALL, a tenth of the
## ground each, in patches two to three chunks wide.
const MEADOW_FREQ := 0.007
const MEADOW_TALL := 0.35
## Fields of ears: large (two to three chunks of the noise, broken up by what is not flat
## fertile lowland) and rare, a few in a square of a thousand cells.
const EAR_FREQ := 0.005
const EAR_FIELD := 0.45

## Meadows of tall grass, clumps of flowers and herbs and the fields of ears: slow
## noises over the map.
static var meadow_noise: FastNoiseLite
static var flower_noise: FastNoiseLite
static var herb_noise: FastNoiseLite
static var ear_noise: FastNoiseLite
## Above this ground patch (salt 21, see ground_patch) the tops of stone are mossy,
## as world.gdshader draws them.
const STONE_MOSS := 0.66
## Patches of moss and the places where mushrooms and glowing mushrooms come up in groups.
static var moss_noise: FastNoiseLite
static var mushroom_noise: FastNoiseLite
static var glow_noise: FastNoiseLite
## The clumps of each custom plant that grows in clumps: id -> noise.
static var custom_noises := {}
## The tileable noise of the ground patches, the clouds and the water's ripples (see
## PixelTextures.build_cloud_noise), kept so scripts read the same patches the shaders do.
static var cloud_image: Image
static var _cloud_values := PackedFloat32Array()


static func _fields() -> void:
	if flower_noise != null:
		return
	meadow_noise = _field_noise(20, MEADOW_FREQ)
	flower_noise = _field_noise(21, 0.06)
	herb_noise = _field_noise(22, 0.12)
	ear_noise = _field_noise(23, EAR_FREQ)
	moss_noise = _field_noise(24, 0.08)
	mushroom_noise = _field_noise(25, 0.16)
	glow_noise = _field_noise(26, 0.11)


static func _field_noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	return n


## The cloud noise image (see cloud_image), made on first use.
static func cloud_noise() -> Image:
	if cloud_image == null:
		var noise := FastNoiseLite.new()
		noise.seed = 5
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		cloud_image = noise.get_seamless_image(128, 128)
	return cloud_image


## The cloud noise at `uv` (wrapping), bilinear like the shaders' sampler.
static func cloud_sample(uv: Vector2) -> float:
	if _cloud_values.is_empty():
		# The pixels' values read once (get_pixel makes a Color each time): every grass
		# cell of a chunk's plants samples them eight times (see tier_at).
		var img := cloud_noise()
		_cloud_values.resize(img.get_width() * img.get_height())
		for y in img.get_height():
			for x in img.get_width():
				_cloud_values[y * img.get_width() + x] = img.get_pixel(x, y).r
	var v := _cloud_values
	const N := 128
	var p := Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0)) * N - Vector2(0.5, 0.5)
	var x0 := floori(p.x)
	var y0 := floori(p.y)
	var fx := p.x - x0
	var fy := p.y - y0
	var xa := posmod(x0, N)
	var xb := posmod(x0 + 1, N)
	var ya := posmod(y0, N) * N
	var yb := posmod(y0 + 1, N) * N
	return lerpf(lerpf(v[ya + xa], v[ya + xb], fx), lerpf(v[yb + xa], v[yb + xb], fx), fy)


## The ground patch noise at a world position, the same as `ground_patch` in
## common.gdshaderinc: lush islands near 1, bare dirt under 0.2.
static func ground_patch(xz: Vector2, salt := 0.0) -> float:
	var t := (xz * 16.0).floor() / 16.0
	var a := cloud_sample(t / 23.0 + Vector2(salt * 0.37, salt * 0.61))
	var b := cloud_sample(t / 7.0 + Vector2(salt * 0.71, 0.5 + salt * 0.13))
	return clampf((a - 0.5) + (b - 0.5) * 0.45 + 0.5, 0.0, 1.0)


## Grass tier of a column: tall meadows and dense lawns by a slow noise of their own, so
## they come as whole fields that the small patches do not break up and never repeat the
## way the tiled patches do; bare and low by the patch noise at the middle of the cell
## (the same noise that tints the ground), bare spots also inside a lawn.
static func tier_at(x: int, z: int) -> int:
	_fields()
	var meadow := meadow_noise.get_noise_2d(x, z)
	if meadow > MEADOW_TALL:
		return TALL_TIER
	var patch := ground_patch(Vector2(x + 0.5, z + 0.5) * CELL)
	if patch < 0.2:
		return BARE_TIER
	if meadow < -MEADOW_TALL:
		return LAWN_TIER
	return LOW_TIER if patch < 0.38 else MID_TIER


## How far into a clump of flowers column x, z lies: 0 outside, a little above 0 at its
## rim, 1 at its heart (see FLOWER_CLUMP); whether flowers grow there also takes grass
## (see kinds). Butterflies and the like can look for flowers by it.
static func flower_clump(x: int, z: int) -> float:
	_fields()
	var f := flower_noise.get_noise_2d(x, z)
	if f <= FLOWER_CLUMP:
		return 0.0
	return clampf((f - FLOWER_CLUMP) / FLOWER_HEART, 0.01, 1.0)


## True in a field of ears: fertile ground is flat grass on the lowland with no crown
## over it, and fields lie where the ear noise is high.
static func ear_field_at(w, x: int, y: int, z: int) -> bool:
	_fields()
	if y > w.sea_level + FERTILE_LEVELS or w.leaf_col(x, z) != 0:
		return false
	return ear_noise.get_noise_2d(x, z) > EAR_FIELD


## The plants growing on ground cell x, y, z of material `m` (with air above), as kinds,
## drawn from `rng` seeded by the cell; `flat` when the cell is a whole level top.
static func kinds(w, x: int, y: int, z: int, m: int, flat: bool, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	if m == Mat.GRASS and w.grows.is_valid():
		var grow: int = w.grows.call(x, z)
		if grow != 0:
			_grown(grow, out, rng)
			return loaded(out)
	if m == Mat.MYCELIUM and m >= 0:
		_fields()
		_cave_floor(x, z, out, rng)
		return loaded(out)
	var tier := BARE_TIER
	if m == Mat.GRASS:
		_fields()
		tier = tier_at(x, z)
		if tier == TALL_TIER:
			for k in 3:
				out.append(TALL + rng.randi_range(0, 3))
		elif tier == LOW_TIER:
			if rng.randf() < 0.65:
				out.append(LOW + rng.randi_range(0, 3))
		elif tier == LAWN_TIER:
			for k in (2 if rng.randf() < 0.6 else 3):
				out.append(LOW + rng.randi_range(0, 3))
		elif tier == MID_TIER:
			# No tuft on a quarter of the cells and two on another quarter, so
			# the ground shows between them before the shader thins the meadows.
			var roll := rng.randf()
			for k in (0 if roll < 0.25 else (1 if roll < 0.75 else 2)):
				out.append(rng.randi_range(0, 3))
		if tier != BARE_TIER:
			# Flowers and herbs in clumps, dense inside and nearly absent outside.
			var clump := flower_clump(x, z)
			var flowers := 0.75 + 0.25 * clump if clump > 0.0 else FLOWERS_APART
			var herbs := 0.7 if herb_noise.get_noise_2d(x, z) > 0.35 else 0.04
			var extra := rng.randf()
			if extra < flowers:
				out.append(FLOWER + rng.randi_range(0, 3))
				if rng.randf() < clump * 0.8:
					out.append(FLOWER + rng.randi_range(0, 3))
			elif extra < flowers + herbs:
				out.append(HERB + rng.randi_range(0, 1))
		if tier != TALL_TIER and flat and ear_field_at(w, x, y, z):
			# A field of ears, with a lone ear here and there outside it.
			for k in rng.randi_range(1, 2):
				out.append(EAR + rng.randi_range(0, 1))
		elif tier == MID_TIER and flat and rng.randf() < 0.01:
			out.append(EAR + rng.randi_range(0, 1))
		if Plants.RING_INDEX >= 0 and _on_ring(x, z):
			_one_plant(Plants.RING_INDEX, out, rng)
		elif w.leaf_col(x, z) != 0:
			_forest_floor(x, z, out, rng)
	# Reeds line grassy and muddy banks, not the sand of a beach.
	var by_water: bool = m != Mat.BEACH and _by_water(w, x, y, z)
	if by_water and rng.randf() < (0.7 if m == Mat.GRASS else 0.4):
		for k in rng.randi_range(1, 2):
			out.append(REED + rng.randi_range(0, 1))
	if not Plants.CUSTOM.is_empty():
		_custom(w, x, z, m, tier, by_water, out, rng)
	return loaded(out)


## The mods' own plants on the cell (see Plants.CUSTOM): each where it `grows` (open
## grass, the shade of a crown, the woods: that shade and the open grass within
## WOODS_EDGE cells of a crown, a bank, open ground other than grass), on the share of that ground its `cover` says
## (within `near_water` cells of water when that is set),
## and only in clumps `clump_size` cells wide where its own noise is above `clumps` when
## that is set, and only in its `biomes` when it names some. A frame `across` cards wide
## is one kind, its first column (Foliage draws the rest beside it). `tier` and
## `by_water` are the cell's, as kinds found them.
static func _custom(w, x: int, z: int, m: int, tier: int, by_water: bool, out: Array[int], rng: RandomNumberGenerator) -> void:
	if not is_same(_rules_of, Plants.CUSTOM) or not is_same(_rules_biomes, Biomes.RECORDS):
		_compile_custom()
	var shaded: bool = w.leaf_col(x, z) != 0
	var grass := m == Mat.GRASS
	var b := -1
	for r: Array in _rules:
		match r[0]:
			MEADOW:
				if not grass or shaded or tier == BARE_TIER:
					continue
			SHADE:
				if not grass or not shaded:
					continue
			WOODS:
				# The near-crown test (a few columns) waits for the cheaper ones below.
				if not grass:
					continue
			BANK:
				if not by_water:
					continue
			BARE:
				if grass:
					continue
		var in_biomes: PackedByteArray = r[1]
		if not in_biomes.is_empty():
			if b < 0:
				b = w.biome_at(x, z)
			if b >= in_biomes.size() or in_biomes[b] == 0:
				continue
		var noise: FastNoiseLite = r[2]
		if noise != null and noise.get_noise_2d(x, z) < r[3]:
			continue
		if r[0] == WOODS and not shaded and not _near_crown(w, x, z):
			continue
		if rng.randf() < r[4] and (r[5] == 0 or _near_water(w, x, z, r[5])):
			out.append(CUSTOM + r[6] + rng.randi_range(0, r[7] - 1) * r[8])


## Where a custom plant grows (its `grows`, see _custom).
const MEADOW := 0
const SHADE := 1
const WOODS := 2
const BANK := 3
const BARE := 4
const GROWS := {"meadow": MEADOW, "shade": SHADE, "woods": WOODS, "bank": BANK, "bare": BARE}
## Plants.CUSTOM as _custom reads it, made once for each load of the plants and the
## biomes (_custom runs for every grass cell a chunk's plants are built on): for each
## plant that grows wild, [where it grows, a byte per biome index (1 where it grows,
## empty for anywhere), its clumps' noise (null for none), the noise's threshold,
## cover, near_water, first frame, frames, across].
static var _rules: Array[Array] = []
static var _rules_of: Array = []
static var _rules_biomes: Array = []


static func _compile_custom() -> void:
	_rules = []
	_rules_of = Plants.CUSTOM
	_rules_biomes = Biomes.RECORDS
	for c: Dictionary in Plants.CUSTOM:
		# A crop grows only where it was sown (WorldData.fields).
		if c.grows == "field":
			continue
		var in_biomes := PackedByteArray()
		if not c.biomes.is_empty():
			in_biomes.resize(Biomes.IDS.size())
			for i in Biomes.IDS.size():
				in_biomes[i] = 1 if Biomes.IDS[i] in c.biomes else 0
		var noise: FastNoiseLite = null
		if c.clumps > -1.0:
			noise = custom_noises.get(c.id)
			if noise == null:
				noise = _field_noise(hash(c.id), 1.0 / c.get("clump_size", 10.0))
				custom_noises[c.id] = noise
		_rules.append([GROWS.get(c.grows, -1), in_biomes, noise, float(c.clumps), float(c.cover), int(c.get("near_water", 0)),
			int(c.first), int(c.frames), int(c.get("across", 1))])


## Whether water stands within `reach` cells of column x, z (eight ways out from it, a
## cell at a time): where a plant with `near_water` grows.
static func _near_water(w, x: int, z: int, reach: int) -> bool:
	for r in range(1, reach + 1):
		for d: Vector2i in NEAR_WAYS:
			if w.water_col(x + d.x * r, z + d.y * r) != 0:
				return true
	return false


const SIDE_WAYS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NEAR_WAYS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1),
	Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


## Whether a crown stands over a column about WOODS_EDGE cells from column x, z (eight
## columns round it, crowns being wider than the gaps between them): the edge of a wood.
static func _near_crown(w, x: int, z: int) -> bool:
	for d: Vector2i in WOODS_PROBES:
		if w.leaf_col(x + d.x, z + d.y) != 0:
			return true
	return false


## Fairy rings: here and there on the open grass a ring of mushrooms (Plants.RING), one
## in a share Plants.RING_SHARE of the squares RING_GRID cells across, its middle well
## inside the square, RING_RADIUS cells round (the least and the most). Asleep inside
## one, a body dreams (Character).
const RING_GRID := 40
const RING_RADIUS := Vector2(2.2, 3.6)
## The rings of the squares looked at (fairy_ring), at most RINGS_KEPT before they are
## worked out again.
static var _rings := {}
const RINGS_KEPT := 4096


## The fairy ring whose square column x, z lies in: its middle (cells, x and z) and
## radius in z of the result, radius 0 when that square has none.
static func fairy_ring(x: int, z: int) -> Vector3:
	if Plants.RING_SHARE <= 0.0:
		return Vector3.ZERO
	var g := Vector2i(floori(float(x) / RING_GRID), floori(float(z) / RING_GRID))
	if _rings.has(g):
		return _rings[g]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([g, "ring"])
	var out := Vector3.ZERO
	if rng.randf() < Plants.RING_SHARE:
		var r := rng.randf_range(RING_RADIUS.x, RING_RADIUS.y)
		var edge := ceilf(r) + 2.0
		out = Vector3(g.x * RING_GRID + rng.randf_range(edge, RING_GRID - edge), g.y * RING_GRID + rng.randf_range(edge, RING_GRID - edge), r)
	if _rings.size() > RINGS_KEPT:
		_rings.clear()
	_rings[g] = out
	return out


## How far column x, z is from the middle of its square's fairy ring as a share of the
## ring's radius (1 on the ring), INF where there is none.
static func in_ring(x: int, z: int) -> float:
	var ring := fairy_ring(x, z)
	if ring.z <= 0.0:
		return INF
	return Vector2(x + 0.5 - ring.x, z + 0.5 - ring.y).length() / ring.z


## True on the line of the fairy ring of column x, z's square (see fairy_ring).
static func _on_ring(x: int, z: int) -> bool:
	var ring := fairy_ring(x, z)
	return ring.z > 0.0 and absf(Vector2(x + 0.5 - ring.x, z + 0.5 - ring.y).length() - ring.z) < 0.55


## The plants of a column whose growth the world sets (`grow`, one of GROW_*), added to
## `out`: low grass under a field of ears or the moss of a forest floor.
static func _grown(grow: int, out: Array[int], rng: RandomNumberGenerator) -> void:
	if grow == GROW_NONE:
		return
	if grow >= GROW_PLANT:
		_one_plant(grow - GROW_PLANT, out, rng)
		return
	if grow == GROW_EARS:
		out.append(rng.randi_range(0, 3))
		for k in rng.randi_range(1, 2):
			out.append(EAR + rng.randi_range(0, 1))
		return
	out.append(MOSS + rng.randi_range(0, 1))
	if grow == GROW_MUSHROOMS and rng.randf() < 0.6:
		out.append(MUSHROOM + rng.randi_range(0, 1))
	elif grow == GROW_GLOW and rng.randf() < 0.6:
		out.append(GLOW + rng.randi_range(0, 1))


## The kinds of the plant at index `i` of the load order (Plants.BY_ID), growing alone
## on a cell, added to `out`: one or two of its frames (three tufts of tall grass).
static func _one_plant(i: int, out: Array[int], rng: RandomNumberGenerator) -> void:
	if i < 0 or i >= Plants.BY_ID.size():
		return
	var r: Dictionary = Plants.BY_ID.values()[i]
	var first := -1
	var frames := 2
	var step := 1
	var count := rng.randi_range(1, 2)
	match r.kind:
		"tuft":
			first = 0
			frames = 4
		"tall_grass":
			first = TALL
			frames = 4
			count = 3
		"flowers":
			first = FLOWER
			frames = 4
		"herbs":
			first = HERB
		"ears":
			first = EAR
		"reeds":
			first = REED
		"moss":
			first = MOSS
			count = 1
		"mushrooms":
			first = MUSHROOM
			count = 1
		"glow_mushrooms":
			first = GLOW
			count = 1
		"custom", "crop", "sapling":
			for c in Plants.CUSTOM:
				if c.id == r.id:
					first = CUSTOM + c.first
					frames = c.frames
					step = c.get("across", 1)
					count = 1
	if first < 0:
		return
	for k in count:
		out.append(first + rng.randi_range(0, frames - 1) * step)


## What grows in the shade of a crown on grass column x, z, added to `out`: moss in
## patches, mushrooms in small groups (each card is two or three of them) where their
## noise is high, and rarer groups of glowing mushrooms.
static func _forest_floor(x: int, z: int, out: Array[int], rng: RandomNumberGenerator) -> void:
	if moss_noise.get_noise_2d(x, z) > -0.05 and rng.randf() < 0.6:
		out.append(MOSS + rng.randi_range(0, 1))
	if glow_noise.get_noise_2d(x, z) > 0.5:
		if rng.randf() < 0.55:
			out.append(GLOW + rng.randi_range(0, 1))
	elif mushroom_noise.get_noise_2d(x, z) > 0.4 and rng.randf() < 0.5:
		out.append(MUSHROOM + rng.randi_range(0, 1))


## The floor of a mushroom cave (Mat.MYCELIUM): moss in its patches, mushrooms in groups,
## and glowing ones more often than in the woods (they glow in the dark, grass.gdshader).
static func _cave_floor(x: int, z: int, out: Array[int], rng: RandomNumberGenerator) -> void:
	if moss_noise.get_noise_2d(x, z) > -0.3 and rng.randf() < 0.7:
		out.append(MOSS + rng.randi_range(0, 1))
	if glow_noise.get_noise_2d(x, z) > 0.1:
		if rng.randf() < 0.6:
			out.append(GLOW + rng.randi_range(0, 1))
	elif mushroom_noise.get_noise_2d(x, z) > 0.0 and rng.randf() < 0.5:
		out.append(MUSHROOM + rng.randi_range(0, 1))


## True where moss grows on the flat top of stone cell x, y, z under open air: in the
## damp patches world.gdshader draws it in (at least a quarter of the cell mossy),
## until it is picked (WorldData.turf "", back in spring).
static func stone_moss(w, x: int, y: int, z: int) -> bool:
	if w.get_cell(x, y, z) != Mat.STONE or w.get_cell(x, y + 1, z) != Mat.AIR or w.turf_at(Vector3i(x, y, z)) == "":
		return false
	var ch: WorldData.Chunk = w.chunk_at(x, z)
	if ch == null or ch.shapes[y * WorldData.LAYER + WorldData.col_of(x, z)] != 0:
		return false
	for k in 4:
		var p := (Vector2(x + 0.25 + 0.5 * (k & 1), z + 0.25 + 0.5 * (k >> 1))) * CELL
		if ground_patch(p + Vector2(7.0, 7.0), 21.0) > STONE_MOSS:
			return true
	return false


## The plants on the top of ground cell x, y, z (ids of Plants), the ones drawn there:
## what cutting that grass gives besides its material's own (see WorldActions.mow), and
## the moss on stone (see stone_moss).
static func plants_on(w, x: int, y: int, z: int) -> Array:
	var m: int = w.get_cell(x, y, z)
	if m == Mat.STONE and stone_moss(w, x, y, z):
		return [] if Plants.MOSS == "" else [Plants.MOSS]
	if not Mat.can_slope(m) or w.get_cell(x, y + 1, z) != Mat.AIR:
		return []
	var ch: WorldData.Chunk = w.chunk_at(x, z)
	var shape: int = ch.shapes[y * WorldData.LAYER + WorldData.col_of(x, z)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(x, y, z))
	var grown_kinds := kinds(w, x, y, z, m, shape == 0, rng)
	var grown: Variant = w.turf_at(Vector3i(x, y, z))
	if grown != null:
		grown_kinds = turf_kinds(grown_kinds, grown, rng)
	var out := []
	for kind in grown_kinds:
		out.append(plant_of(kind))
	return out


## `kinds` without the ones no loaded plant is of (see Plants.of_kind): what is not in
## the world's mods neither grows nor is drawn.
static func loaded(kinds: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for kind in kinds:
		if plant_of(kind) != "":
			out.append(kind)
	return out


## Whether something grows tall on grass cell `cell` (more than low tufts), what a tool
## that cuts only tall grass can cut.
static func has_tall(w, cell: Vector3i) -> bool:
	for id in plants_on(w, cell.x, cell.y, cell.z):
		if id != Plants.TUFT:
			return true
	return false


## A plant that stops a body (Plants.SOLID: a cactus) on the top of ground cell x, y, z
## (with air above), where Foliage._column draws it: [id, root x, root z], the root in
## 0..1 of the cell, as the same draws of the cell's `rng` put it; [] for none. Whether
## it shows this season is the caller's (`winter`).
static func solid_plant(w, x: int, y: int, z: int) -> Array:
	if Plants.SOLID.is_empty():
		return []
	var ch: WorldData.Chunk = w.chunk_at(x, z)
	if ch == null or y < 0 or y + 1 >= w.size_y:
		return []
	var col := WorldData.col_of(x, z)
	var i := y * WorldData.LAYER + col
	var m: int = ch.cells[i]
	if not Mat.can_slope(m) or m == Mat.GRASS and Plants.SOLID_BARE or ch.cells[i + WorldData.LAYER] != Mat.AIR:
		return []
	if not is_same(_solid_of, Plants.SOLID) or not is_same(_solid_biomes_of, Biomes.RECORDS):
		_compile_solid()
	if not _solid_biomes.is_empty():
		var b: int = ch.biome[col]
		if b < 0 or b >= _solid_biomes.size() or _solid_biomes[b] == 0:
			return []
	var cell := Vector3i(x, y, z)
	var beds: Dictionary = w.fields.get(ch.key, {})
	if beds.has(cell):
		return []
	var shape: int = ch.shapes[i]
	var turf: Variant = w.turf_at(cell)
	# Bodies ask of the same few cells step after step: what was found is kept while the
	# cell, its shape and its turf stay as they were.
	var seen: Variant = _solid_seen.get(cell)
	if seen != null and seen[0] == w.get_instance_id() and seen[1] == m and seen[2] == shape and seen[3] == turf:
		return seen[4]
	var found := _find_solid(w, cell, m, shape, turf)
	if _solid_seen.size() >= SOLID_SEEN_MOST:
		_solid_seen.clear()
	_solid_seen[cell] = [w.get_instance_id(), m, shape, turf, found]
	return found


## How many cells solid_plant keeps what it found on.
const SOLID_SEEN_MOST := 2048
static var _solid_seen := {}


static func _find_solid(w, cell: Vector3i, m: int, shape: int, turf: Variant) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var mask := WorldData.FULL & ~(shape & 15)
	var cuts := shape >> 4
	var grown := kinds(w, cell.x, cell.y, cell.z, m, mask == WorldData.FULL and cuts == 0, rng)
	if turf != null:
		grown = turf_kinds(grown, turf, rng)
	# The same draws as Foliage._column: a root, then the card's light and phase.
	for kind in grown:
		var fx := rng.randi_range(1, 7) / 8.0
		var fz := rng.randi_range(1, 7) / 8.0
		if w.in_cuts(cuts, fx, fz):
			continue
		var id := plant_of(kind)
		if Plants.SOLID.has(id):
			return [id, fx, fz]
		rng.randf()
		rng.randf()
	return []


## The biomes a solid plant grows in (a byte per biome index, 1 where one does; empty
## when one grows anywhere), made once for each load of the plants and the biomes.
static var _solid_biomes := PackedByteArray()
static var _solid_of: Dictionary = {}
static var _solid_biomes_of: Array = []


static func _compile_solid() -> void:
	_solid_of = Plants.SOLID
	_solid_biomes_of = Biomes.RECORDS
	_solid_biomes = PackedByteArray()
	_solid_biomes.resize(Biomes.IDS.size())
	for r: Dictionary in Plants.SOLID.values():
		if r.get("biomes", []).is_empty():
			_solid_biomes = PackedByteArray()
			return
		for k in Biomes.IDS.size():
			if Biomes.IDS[k] in r.biomes:
				_solid_biomes[k] = 1


## The plants of a grass cell the player changed (see WorldData.turf): cut short, only
## low grass is left of what grew there (`grown` ""); sown, ears stand among it.
static func turf_kinds(grown_kinds: Array[int], grown: String, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	for kind in grown_kinds:
		if kind >= MOSS:
			continue
		if kind >= TALL:
			out.append(LOW + kind - TALL)
		elif kind < FLOWER or kind >= LOW:
			out.append(kind)
	match Plants.kind_of(grown):
		Plants.KINDS.EARS:
			for k in 2:
				out.append(EAR + rng.randi_range(0, 1))
		Plants.KINDS.FLOWERS:
			out.append(FLOWER + rng.randi_range(0, 3))
	return out


## The id (see Plants) of plant kind `kind`, "" when no loaded plant is of that kind.
static func plant_of(kind: int) -> String:
	if kind >= CUSTOM:
		return Plants.custom_of(kind - CUSTOM)
	if kind >= GLOW:
		return Plants.GLOW
	if kind >= MUSHROOM:
		return Plants.MUSHROOMS
	if kind >= MOSS:
		return Plants.MOSS
	if kind >= TALL:
		return Plants.TALL
	if kind >= LOW:
		return Plants.TUFT
	if kind >= HERB:
		return Plants.HERBS
	if kind >= REED:
		return Plants.REEDS
	if kind >= EAR:
		return Plants.EARS
	if kind >= FLOWER:
		return Plants.FLOWERS
	return Plants.TUFT


## True for a ground cell at the water's edge: open water beside it at its own level
## or one below.
static func _by_water(w, x: int, y: int, z: int) -> bool:
	var bits := (1 << y) | (1 << (y - 1) if y > 0 else 0)
	for d: Vector2i in SIDE_WAYS:
		var nx := x + d.x
		var nz := z + d.y
		if w.water_col(nx, nz) & bits:
			return true
	return false
