extends RefCounted
## What grows on the top of a ground cell: the plants drawn there (Foliage) are the ones
## cutting the grass gives (WorldActions), so both read them from here, from a hash of
## the cell and slow noises over the map. Grass grows in tiers that follow the ground's
## own patches (ground_patch, the noise that also tints the ground): bare dirt on the
## lowest spots, low sparse grass on thin ground, the ordinary tufts in between (the
## shader thins them further), and small meadows of tall grass, three tufts a cell, on
## the lush islands. Flowers and low herbs grow in clumps of their own; ears of dry grass
## stand in fields on flat fertile lowland and hardly anywhere else; reeds line the
## water, except on sand. In the shade of the crowns moss grows in patches on the forest
## floor and mushrooms in groups, and here and there groups of mushrooms that glow at
## night. A cell the player cut or sowed (WorldData.turf) changes what grows on it.

const Mat := preload("res://src/shared/content/materials.gd")
const Plants := preload("res://src/shared/content/plants.gd")
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
## Lowland for ears: this many levels above the sea at most.
const FERTILE_LEVELS := 10

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


static func _fields() -> void:
	if flower_noise != null:
		return
	meadow_noise = _field_noise(20, 0.028)
	flower_noise = _field_noise(21, 0.06)
	herb_noise = _field_noise(22, 0.12)
	ear_noise = _field_noise(23, 0.035)
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
	var img := cloud_noise()
	var n := img.get_width()
	var p := Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0)) * n - Vector2(0.5, 0.5)
	var x0 := floori(p.x)
	var y0 := floori(p.y)
	var fx := p.x - x0
	var fy := p.y - y0
	var a := img.get_pixel(posmod(x0, n), posmod(y0, n)).r
	var b := img.get_pixel(posmod(x0 + 1, n), posmod(y0, n)).r
	var c := img.get_pixel(posmod(x0, n), posmod(y0 + 1, n)).r
	var d := img.get_pixel(posmod(x0 + 1, n), posmod(y0 + 1, n)).r
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## The ground patch noise at a world position, the same as `ground_patch` in
## common.gdshaderinc: lush islands near 1, bare dirt under 0.2.
static func ground_patch(xz: Vector2, salt := 0.0) -> float:
	var t := (xz * 16.0).floor() / 16.0
	var a := cloud_sample(t / 23.0 + Vector2(salt * 0.37, salt * 0.61))
	var b := cloud_sample(t / 7.0 + Vector2(salt * 0.71, 0.5 + salt * 0.13))
	return clampf((a - 0.5) + (b - 0.5) * 0.45 + 0.5, 0.0, 1.0)


## Grass tier of a column: tall meadows by a slow noise of their own, so they come as
## whole islands that the small patches do not break up and never repeat the way the
## tiled patches do; bare and low by the patch noise at the middle of the cell (the same
## noise that tints the ground).
static func tier_at(x: int, z: int) -> int:
	_fields()
	if meadow_noise.get_noise_2d(x, z) > 0.4:
		return TALL_TIER
	var patch := ground_patch(Vector2(x + 0.5, z + 0.5) * CELL)
	return BARE_TIER if patch < 0.2 else (LOW_TIER if patch < 0.38 else MID_TIER)


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
	return ear_noise.get_noise_2d(x, z) > 0.4


## The plants growing on ground cell x, y, z of material `m` (with air above), as kinds,
## drawn from `rng` seeded by the cell; `flat` when the cell is a whole level top.
static func kinds(w, x: int, y: int, z: int, m: int, flat: bool, rng: RandomNumberGenerator) -> Array[int]:
	var out: Array[int] = []
	if m == Mat.GRASS and w.grows.is_valid():
		var grow: int = w.grows.call(x, z)
		if grow != 0:
			_grown(grow, out, rng)
			return loaded(out)
	if m == Mat.GRASS:
		_fields()
		var tier := tier_at(x, z)
		if tier == TALL_TIER:
			for k in 3:
				out.append(TALL + rng.randi_range(0, 3))
		elif tier == LOW_TIER:
			if rng.randf() < 0.65:
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
		if w.leaf_col(x, z) != 0:
			_forest_floor(x, z, out, rng)
	# Reeds line grassy and muddy banks, not the sand of a beach.
	if m != Mat.BEACH and _by_water(w, x, y, z) and rng.randf() < (0.7 if m == Mat.GRASS else 0.4):
		for k in rng.randi_range(1, 2):
			out.append(REED + rng.randi_range(0, 1))
	if not Plants.CUSTOM.is_empty():
		_custom(w, x, y, z, m, out, rng)
	return loaded(out)


## The mods' own plants on the cell (see Plants.CUSTOM): each where it `grows` (open
## grass, the shade of a crown, a bank), on the share of that ground its `cover` says,
## and only in clumps where its own noise is above `clumps` when that is set.
static func _custom(w, x: int, y: int, z: int, m: int, out: Array[int], rng: RandomNumberGenerator) -> void:
	var shaded: bool = w.leaf_col(x, z) != 0
	for c in Plants.CUSTOM:
		match c.grows:
			"meadow":
				if m != Mat.GRASS or shaded or tier_at(x, z) == BARE_TIER:
					continue
			"shade":
				if m != Mat.GRASS or not shaded:
					continue
			"bank":
				if m == Mat.BEACH or not _by_water(w, x, y, z):
					continue
		if c.clumps > -1.0:
			var noise: FastNoiseLite = custom_noises.get(c.id)
			if noise == null:
				noise = _field_noise(hash(c.id), 0.1)
				custom_noises[c.id] = noise
			if noise.get_noise_2d(x, z) < c.clumps:
				continue
		if rng.randf() < c.cover:
			out.append(CUSTOM + c.first + rng.randi_range(0, c.frames - 1))


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
		"custom":
			for c in Plants.CUSTOM:
				if c.id == r.id:
					first = CUSTOM + c.first
					frames = c.frames
					count = 1
	if first < 0:
		return
	for k in count:
		out.append(first + rng.randi_range(0, frames - 1))


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
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + d.x
		var nz := z + d.y
		if w.water_col(nx, nz) & bits:
			return true
	return false
