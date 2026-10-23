extends RefCounted
## Deterministic world generator: the same seed and settings always give the same
## world, whatever order its chunks are made in. The world has no edge: everything
## comes from noise at the column itself, so any chunk can be made at any time, as the
## player comes near (see ChunkStreamer), and made again the same after it was dropped.
## Continents and oceans come from a very slow noise, mountains, plateaus and cliff
## coasts from slower and faster ones over the land (and flat beaches where the cliff
## noise is low), rivers run along the zero lines of a noise, widening towards the sea,
## and lakes fill its high spots, both at the level of the sea, and the climate
## (warmth and moisture) is noise too, so biomes spread over hundreds of cells. A chunk
## is made in three stages that each read only what the stages before left in place:
## 1. TERRAIN: the columns of the chunk and a margin around it are laid out (height,
##    water, top, biome), then the cells are written: stone with ore, dirt, the top,
##    water, caves. The trees of planted neighbours that reach in are grown again.
## 2. PLANTED: trees by biome, once the chunks around have their terrain (a crown may
##    reach into the next chunk). Which column gets a tree is a hash of the column, so
##    neighbours agree without looking at each other's cells.
## 3. SHAPED: slopes and corners (see WorldData.update_shapes) and bushes, once the
##    chunks around are planted, so nothing changes under them later.
## A chunk is meshed when it and its neighbours are SHAPED. Every generated cell is
## marked wild: loose ground lies as slopes wherever it steps down one cell, while
## stone, steep patches, cliffs and canyon walls keep sheer walls. Water above the sea
## never stands beside open air: banks are raised to its level and caves keep away
## from it. Each stage is done a few rows (or a tree) at a time; sizes are in cells.
## A chunk the player changed comes back from the save (`saved`, see WorldStore) in
## place of its terrain stage, SHAPED at once, and grows its trees again into the
## chunks around that are not final, as its planting would have.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")

const CHUNK := WorldData.CHUNK
## Columns around a chunk the terrain stage lays out too, so banks, caves and trees
## can look at their neighbours.
const MARGIN := 3
const WINDOW := CHUNK + 2 * MARGIN
## Cells between the samples of the slow noises (continents, rivers, lakes), which are
## sampled exactly and interpolated with their slopes in between.
const LATTICE := 4
## How far a tree reaches from its trunk, so a chunk made again knows which trees of
## its neighbours to grow again (see Trees.place).
const TREE_REACH := 10

## Stages of a chunk (see above); 0 is nothing yet.
const TERRAIN := 1
const PLANTED := 2
const SHAPED := 3

## Biomes of a column, from its height, warmth and moisture.
const SEA := 0
const BEACH := 1
const MEADOW := 2
const FOREST := 3
const TAIGA := 4
const SWAMP := 5
const ROCK := 6
const PLATEAU := 7
const DESERT := 8
const TUNDRA := 9
const BIOME_NAMES := ["Море", "Берег", "Луг", "Лес", "Тайга", "Болото", "Скалы", "Плато", "Пустыня", "Тундра"]
## Chance of a tree on a lattice column (every other column each way) per biome, and
## the share of spruces among them; groves of the forest noise raise the chance on
## meadows. Content data of the core mod will replace these tables.
const TREE_CHANCE := [0.0, 0.0, 0.004, 0.14, 0.12, 0.03, 0.0, 0.0, 0.0, 0.02]
const SPRUCE_SHARE := [0.0, 0.0, 0.2, 0.15, 0.9, 0.0, 0.0, 0.0, 0.0, 1.0]
const GROVE_CHANCE := 0.08
## One bush try per this many cells of a biome's ground.
const BUSH_SPARSITY := [0, 0, 160, 120, 140, 200, 0, 400, 900, 150]

## Relief kinds of a column.
const PLAIN := 0
const MOUNTAIN := 1
const HIGHLAND := 2
const CLIFFS := 3
const SEA_FLOOR := 4
## Water of a column: none, the sea, a lake or a river (a canyon floor counts as river).
const DRY := 0
const OCEAN := 1
const LAKE := 2
const RIVER := 3
const CANYON := 4

## World settings, each a level from 0 (little) to 2 (much); 1 is the usual world.
## size: how large continents and islands are; water: the share of the ocean;
## mountains: how much of the land rises into mountains; rivers: how many rivers and
## lakes; biomes: how far one climate stretches.
const DEFAULT_SETTINGS := {"size": 1, "water": 1, "mountains": 1, "rivers": 1, "biomes": 1}
const SIZE_SCALE := [0.4, 1.0, 2.2]
const WATER_SHARE := [0.25, 0.4, 0.58]
## Where the mountain noise starts and ends raising mountains.
const MOUNTAIN_FROM := [0.5, 0.3, 0.12]
const RIVER_FROM := [0.1, -0.1, -0.3]
const LAKE_FROM := [0.66, 0.55, 0.45]
const BIOME_SCALE := [0.5, 1.0, 2.0]

## Column flags while laying out: the top keeps a sheer wall; a cave mouth is here
## (see _entrances), with bigger caves under it.
const SHEER_TOP := 1
const ENTRANCE := 2
## The water of the column is the mud of a bog (WorldData.BOG).
const MIRE := 4
## A cave mouth opens sideways where its ground drops by WALL cells or more within
## three columns: a gallery ADIT cells high is cut in at the foot of the wall. On
## level ground it is a pit instead, up to PIT_DEPTH cells deep in its middle.
const WALL := 5
const ADIT := 4
const PIT_DEPTH := 12
## Cells of level sand along a flat coast (see _relief).
const FLAT_BEACH := 28.0
## Rivers widen towards the sea or a lake over this many cells, so they are brooks
## at their sources and broad at their mouths.
const MOUTH_REACH := 400.0

var world: WorldData
var world_seed: int
var settings: Dictionary
var size_y: int
var sea: int
## The continent noise's value at the coast: below it is the ocean.
var coast_level := 0.0
## Stage of each chunk, by Vector2i(cx, cz); absent means nothing is made yet.
var stages := {}
## The laid-out columns of chunks between TERRAIN and SHAPED (see _window), by chunk.
var layouts := {}
## The candidate trees of each planted chunk (see _tree_candidates), so they can grow
## again into a neighbour made again.
var planted := {}
## Where the player is first put: a meadow near the origin, refined by find_spawn once
## its chunk is made.
var spawn_guess: Vector3i
## Where chunks the player changed are kept between runs: has_chunk(key) and
## read_chunk(key) -> Dictionary (see WorldStore); null makes every chunk anew.
var saved

var n_hills: FastNoiseLite
var n_ridges: FastNoiseLite
var n_mount: FastNoiseLite
var n_shape: FastNoiseLite
var n_cliff: FastNoiseLite
var n_plateau: FastNoiseLite
var n_steep: FastNoiseLite
var n_soil: FastNoiseLite
var n_forest: FastNoiseLite
var n_gully: FastNoiseLite
var n_mouths: FastNoiseLite
var n_pools: FastNoiseLite
var n_temp: FastNoiseLite
var n_moist: FastNoiseLite
var n_swamp: FastNoiseLite
var n_flow: FastNoiseLite
var n_dunes: FastNoiseLite
var n_roll: FastNoiseLite
var n_caves: FastNoiseLite
var n_ores: FastNoiseLite
## The slow noises sampled on the lattice: continents, rivers (along its zero lines)
## and lakes (over its high spots).
var n_land: FastNoiseLite
var n_river: FastNoiseLite
var n_lake: FastNoiseLite
## The 2D noises sampled for a window, in the order _layout_row reads them.
var window_noises: Array


## A chunk's generation job, stepped a row of columns (or a tree) at a time (see start,
## step).
class Job extends RefCounted:
	var key: Vector2i
	var stage: int
	## Steps done so far and to do.
	var row := 0
	var rows: int
	## The window of laid-out columns (TERRAIN).
	var lay: Dictionary
	## Candidate trees (PLANTED), or the neighbours' trees to grow again (TERRAIN):
	## x, z, species, ground height.
	var trees: Array = []
	## The saved record of a chunk brought back instead of made (see pack).
	var restore: Dictionary
	var done := false


## A world made at once over the chunks 0..area (all SHAPED), for tests and tools.
static func generate(seed_value: int, area := Vector2i(4, 4), sy := 48, options := {}) -> WorldData:
	var gen := new(seed_value, sy, options)
	gen.generate_area(Vector2i.ZERO, area)
	return gen.world


func _init(seed_value: int, sy := 48, options := {}) -> void:
	world_seed = seed_value
	size_y = sy
	settings = DEFAULT_SETTINGS.duplicate()
	for k in options:
		if settings.has(k):
			settings[k] = clampi(int(options[k]), 0, 2)
	world = WorldData.new(sy)
	sea = world.sea_level
	_noises()
	coast_level = _coast_level()
	spawn_guess = _pick_spawn()


## Makes the chunks from..to (ends exclusive) SHAPED, with what they need around.
func generate_area(from: Vector2i, to: Vector2i) -> void:
	for stage: int in [TERRAIN, PLANTED, SHAPED]:
		var grow := SHAPED - stage
		for cz in range(from.y - grow, to.y + grow):
			for cx in range(from.x - grow, to.x + grow):
				if stages.get(Vector2i(cx, cz), 0) < stage:
					run(Vector2i(cx, cz), stage)
	world.refresh_shapes()


## Runs one stage of a chunk at once.
func run(key: Vector2i, stage: int) -> void:
	var job := start(key, stage)
	while job != null and not step(job, 1 << 30):
		pass


func stage_of(key: Vector2i) -> int:
	return stages.get(key, 0)


## True when every chunk within `reach` of `key` has reached `stage`.
func around(key: Vector2i, reach: int, stage: int) -> bool:
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if stages.get(Vector2i(key.x + dx, key.y + dz), 0) < stage:
				return false
	return true


## The first chunk within `reach` of `key` that has not reached `stage`, nearest to
## `key` first, or null when all have.
func missing(key: Vector2i, reach: int, stage: int) -> Variant:
	for r in range(0, reach + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var k := Vector2i(key.x + dx, key.y + dz)
				if stages.get(k, 0) < stage:
					return k
	return null


## Drops a chunk the player has not changed: its cells, trees and bushes are made
## again the same when it is needed again. Chunks the player changed stay.
func forget(key: Vector2i) -> bool:
	var c: WorldData.Chunk = world.chunks.get(key)
	if c != null and c.edited:
		return false
	world.remove_chunk(key)
	stages.erase(key)
	layouts.erase(key)
	planted.erase(key)
	return true


## The record of chunk `key` for the save: what WorldData keeps of it and the trees
## it planted, which grow again into the chunks around when those are made anew.
func pack(key: Vector2i) -> Dictionary:
	world.refresh_shapes()
	var d := world.pack_chunk(key)
	d["planted"] = planted.get(key, [])
	return d


# --- Jobs --------------------------------------------------------------------

## Begins `stage` of chunk `key`, which must have reached the stage before it (and its
## neighbours the one before that, see the top of the file).
func start(key: Vector2i, stage: int) -> Job:
	if stages.get(key, 0) != stage - 1:
		push_error("stages of chunk %s go in order: at %d, asked for %d" % [key, stages.get(key, 0), stage])
		return null
	var job := Job.new()
	job.key = key
	job.stage = stage
	if stage == TERRAIN and saved != null and saved.has_chunk(key):
		var d: Dictionary = saved.read_chunk(key)
		if world.can_unpack(d):
			job.restore = d
			job.trees = d.get("planted", [])
			job.rows = 1 + job.trees.size()
			return job
		push_error("saved chunk %s is broken or of another world: made anew" % key)
	match stage:
		TERRAIN:
			job.lay = _window(key.x * CHUNK - MARGIN, key.y * CHUNK - MARGIN, WINDOW, WINDOW)
			job.trees = _regrown(key)
			job.rows = window_noises.size() + 1 + WINDOW + CHUNK + job.trees.size()
		PLANTED:
			job.trees = _tree_candidates(key, layouts[key])
			job.rows = job.trees.size()
		SHAPED:
			job.rows = 2 * SHAPE_BANDS
	return job


## Does the next `n` steps of the job; true when the stage is done.
func step(job: Job, n: int) -> bool:
	world.track_edits = false
	while n > 0 and job.row < job.rows and not job.restore.is_empty():
		if job.row == 0:
			world.unpack_chunk(job.restore)
		else:
			_plant(job.trees[job.row - 1], true)
		job.row += 1
		n -= 1
	while n > 0 and job.row < job.rows:
		match job.stage:
			TERRAIN:
				_terrain_step(job, job.row)
			PLANTED:
				_plant(job.trees[job.row])
			SHAPED:
				_shape_step(job.key, job.row)
		job.row += 1
		n -= 1
	world.track_edits = true
	if job.row >= job.rows and not job.done:
		job.done = true
		if not job.restore.is_empty():
			job.stage = SHAPED
			stages[job.key] = SHAPED
			planted[job.key] = job.trees
			return true
		stages[job.key] = job.stage
		if job.stage == TERRAIN:
			layouts[job.key] = job.lay
		elif job.stage == PLANTED:
			planted[job.key] = job.trees
			_reshape_edges(job.key)
		elif job.stage == SHAPED:
			_bushes(job.key, layouts[job.key])
			layouts.erase(job.key)
			var c: WorldData.Chunk = world.chunks.get(job.key)
			if c != null:
				c.final = true
	return job.done


## The steps of the terrain stage: sample the noises one by one, the slow ones on the
## lattice, lay out the rows of the window, raise the banks, write the rows of cells,
## then grow the neighbours' trees that reach in.
func _terrain_step(job: Job, row: int) -> void:
	var noises := window_noises.size()
	if row < noises:
		_sample(job.lay, row)
		return
	row -= noises
	if row == 0:
		_lattice(job.lay)
		return
	row -= 1
	if row < WINDOW:
		_layout_row(job.lay, row)
		if row == WINDOW - 1:
			_entrances(job.lay)
			_banks(job.lay)
		return
	row -= WINDOW
	if row < CHUNK:
		if row == 0:
			world.add_chunk(job.key)
		_fill_row(job.key, job.lay, row)
		return
	row -= CHUNK
	_plant(job.trees[row], true)


# --- Noises -------------------------------------------------------------------

func _noises() -> void:
	var size: float = SIZE_SCALE[settings.size]
	var biomes: float = BIOME_SCALE[settings.biomes]
	n_hills = _noise(0, 0.005, 4)
	n_ridges = _noise(1, 0.009, 3)
	n_mount = _noise(2, 0.0022 / sqrt(size), 2)
	n_shape = _noise(3, 0.012, 2)
	n_cliff = _noise(4, 0.006, 2)
	n_plateau = _noise(5, 0.0035, 2)
	n_steep = _noise(6, 0.045, 2)
	n_soil = _noise(7, 0.025, 2)
	n_forest = _noise(8, 0.015, 2)
	n_gully = _noise(9, 0.01, 1)
	n_mouths = _noise(10, 0.02, 1)
	n_pools = _noise(11, 0.07, 2)
	n_temp = _noise(12, 0.0005 / biomes, 1)
	n_moist = _noise(13, 0.0008 / biomes, 2)
	n_swamp = _noise(17, 0.006, 2)
	n_flow = _noise(18, 0.0009, 2)
	n_dunes = _noise(19, 0.035, 2)
	n_roll = _noise(23, 0.003, 2)
	n_caves = _noise(14, 0.03, 2)
	n_ores = _noise(15, 0.075, 1)
	n_land = _noise(20, 0.00028 / size, 4)
	n_river = _noise(21, 0.0018, 2)
	n_lake = _noise(22, 0.004, 2)
	window_noises = [n_hills, n_ridges, n_mount, n_shape, n_cliff, n_plateau, n_steep, n_soil,
		n_forest, n_gully, n_mouths, n_pools, n_temp, n_moist, n_swamp, n_flow, n_dunes, n_roll]


func _noise(salt: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed + salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## The continent noise's value below which lies the ocean, so that about the share of
## the world the water setting asks for is sea.
func _coast_level() -> float:
	var values := PackedFloat32Array()
	n_land.offset = Vector3.ZERO
	var spread := 0.5 / n_land.frequency
	for i in 32:
		for j in 32:
			values.append(n_land.get_noise_2d((i - 16) * spread * 0.37, (j - 16) * spread * 0.41))
	values.sort()
	return values[int(values.size() * WATER_SHARE[settings.water])]


## Byte value of a noise level, as the sampled grids hold them (0..255 for -1..1).
static func _byte(v: float) -> int:
	return int((v * 0.5 + 0.5) * 255.0)


## A hash of a column, 0..2^24, different for each `salt` and world.
func _hash(x: int, z: int, salt: int) -> int:
	var h := (x * 374761393 + z * 668265263 + (world_seed + salt) * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFF


func _chance(x: int, z: int, salt: int) -> float:
	return _hash(x, z, salt) / float(1 << 24)


# --- Laying out columns -------------------------------------------------------------

## A window of columns to lay out: `w` by `h` columns `step` cells apart from column
## x0, z0. Its noises are sampled by _sample and _lattice, its rows laid out by
## _layout_row into one entry per column (j = lz * w + lx): height, water (the top
## water cell, -1 for none), top, flags, biome, relief kind and what water it is, and
## by _entrances the floor of a cave mouth's gallery and the depth of its pit.
func _window(x0: int, z0: int, w: int, h: int, step := 1) -> Dictionary:
	var count := w * h
	var lay := {"x0": x0, "z0": z0, "w": w, "h": h, "step": step, "grids": []}
	for k: String in ["heights", "water"]:
		var a := PackedInt32Array()
		a.resize(count)
		lay[k] = a
	lay.water.fill(-1)
	for k: String in ["tops", "flags", "biome", "kind", "feature", "adit", "pit"]:
		var a := PackedByteArray()
		a.resize(count)
		lay[k] = a
	for k: String in ["land", "coast", "river", "lake"]:
		var a := PackedFloat32Array()
		a.resize(count)
		lay[k] = a
	return lay


## Samples window noise `k` over the window (bytes, see _byte).
func _sample(lay: Dictionary, k: int) -> void:
	var n: FastNoiseLite = window_noises[k]
	var step: int = lay.step
	var f := n.frequency
	# A grid of one sample every `step` cells: the noise runs `step` times faster.
	n.frequency = f * step
	n.offset = Vector3(lay.x0 / float(step), lay.z0 / float(step), 0.0)
	lay.grids.append(n.get_image(lay.w, lay.h, false, false, false).get_data())
	n.frequency = f
	n.offset = Vector3.ZERO


## The slow noises of the window on a lattice of points LATTICE cells apart (all over
## the world, so windows agree), which _lattice_row interpolates with their slopes row
## by row: the continent noise and how far a column is from the coast (cells, less than
## zero at sea), how far it is from the middle of a river, and how far inside a lake
## (less than zero outside).
func _lattice(lay: Dictionary) -> void:
	var step: int = lay.step
	var x0: int = lay.x0
	var z0: int = lay.z0
	var span := maxi(LATTICE, step)
	var gx0 := floori(x0 / float(span)) - 1
	var gz0 := floori(z0 / float(span)) - 1
	var gw := floori((x0 + (lay.w - 1) * step) / float(span)) + 3 - gx0
	var gh := floori((z0 + (lay.h - 1) * step) / float(span)) + 3 - gz0
	lay.lattice = [_grid(n_land, gx0, gz0, gw, gh, span), _grid(n_river, gx0, gz0, gw, gh, span),
		_grid(n_lake, gx0, gz0, gw, gh, span), gx0, gz0, gw, gh, span]


## The slow noises of row `lz` of a window, interpolated from the lattice: the land and
## the distances to the coast, to the middle of a river and to a lake shore.
func _lattice_row(lay: Dictionary, lz: int) -> void:
	var g: Array = lay.lattice
	var land: PackedFloat32Array = g[0]
	var river: PackedFloat32Array = g[1]
	var lake: PackedFloat32Array = g[2]
	var gx0: int = g[3]
	var gw: int = g[5]
	var gh: int = g[6]
	var span: int = g[7]
	var step: int = lay.step
	var x0: int = lay.x0
	var w: int = lay.w
	var out_land: PackedFloat32Array = lay.land
	var out_coast: PackedFloat32Array = lay.coast
	var out_river: PackedFloat32Array = lay.river
	var out_lake: PackedFloat32Array = lay.lake
	var lake_from: float = LAKE_FROM[settings.rivers]
	var z: int = lay.z0 + lz * step
	var gz0: int = g[4]
	var fz := z / float(span) - gz0
	var iz := clampi(floori(fz), 1, gh - 3)
	var tz := fz - iz
	for lx in w:
		var x := x0 + lx * step
		var fx := x / float(span) - gx0
		var ix := clampi(floori(fx), 1, gw - 3)
		var tx := fx - ix
		var j := lz * w + lx
		var c := _smooth(land, gw, ix, iz, tx, tz, span)
		out_land[j] = c.x
		out_coast[j] = (c.x - coast_level) / maxf(c.y, 1e-6)
		var r := _smooth(river, gw, ix, iz, tx, tz, span)
		out_river[j] = absf(r.x) / maxf(r.y, 1e-6)
		var l := _smooth(lake, gw, ix, iz, tx, tz, span)
		out_lake[j] = (l.x - lake_from) / maxf(l.y, 1e-6)


## Values of a noise at the lattice points gx0.., gz0.. (gw by gh), `span` cells apart.
static func _grid(n: FastNoiseLite, gx0: int, gz0: int, gw: int, gh: int, span: int) -> PackedFloat32Array:
	n.offset = Vector3.ZERO
	var out := PackedFloat32Array()
	out.resize(gw * gh)
	for j in gh:
		for i in gw:
			out[j * gw + i] = n.get_noise_2d((gx0 + i) * span, (gz0 + j) * span)
	return out


## The value of a lattice grid at (ix + tx, iz + tz) and the length of its slope per
## cell, both interpolated between the four points around.
static func _smooth(g: PackedFloat32Array, gw: int, ix: int, iz: int, tx: float, tz: float, span: int) -> Vector2:
	var j := iz * gw + ix
	var v00 := g[j]
	var v10 := g[j + 1]
	var v01 := g[j + gw]
	var v11 := g[j + gw + 1]
	var v := lerpf(lerpf(v00, v10, tx), lerpf(v01, v11, tx), tz)
	# Slopes at the four points from their neighbours, interpolated the same way.
	var sx := lerpf(lerpf(g[j + 1] - g[j - 1], g[j + 2] - g[j], tx),
		lerpf(g[j + gw + 1] - g[j + gw - 1], g[j + gw + 2] - g[j + gw], tx), tz)
	var sz := lerpf(lerpf(g[j + gw] - g[j - gw], g[j + gw + 1] - g[j - gw + 1], tx),
		lerpf(g[j + 2 * gw] - g[j], g[j + 2 * gw + 1] - g[j + 1], tx), tz)
	return Vector2(v, Vector2(sx, sz).length() / (2.0 * span))


## Base height of the land at a column: the ocean floor deepening away from the coast,
## low coasts rising inland into plains of low hills, mountains with sharp ridges along
## the noise's zero lines, the terraces of a plateau and the raised rim of a cliff
## coast. Returns [height, kind]; `coast` is the distance from the coast in cells.
func _relief(coast: float, hills: int, ridges: int, mount: int, shape: int, cliff: int, plateau: int, roll: int) -> Array:
	# A ragged coast: the distance wobbles with a faster noise.
	coast += (shape - 128) / 128.0 * 6.0
	var h := hills / 255.0
	# Where the cliff noise is low the coast is a flat beach: the land stays a level
	# above the sea for a band of FLAT_BEACH cells, and the sea floor slopes gently.
	var cl := cliff / 127.5 - 1.0
	var flat := 1.0 - smoothstep(-0.3, -0.05, cl)
	var inland := clampf((coast - FLAT_BEACH * flat) / 64.0, 0.0, 1.0)
	# The hills grow in further from the coast than the land rises, and only where
	# the rolling noise is high: elsewhere the plains lie nearly level.
	var rolling := 0.2 + 0.8 * smoothstep(-0.05, 0.4, roll / 127.5 - 1.0)
	var land := sea + 1.0 + inland * (1.0 + h * 7.0 * inland * rolling)
	# Off a beach the water stays shallow for a few cells, then deepens slowly.
	var floor_h := lerpf(sea - 2.0 - minf(5.0, -coast / 8.0), sea - 1.0 - minf(6.0, maxf(0.0, -coast - 6.0) / 12.0), flat)
	var kind := PLAIN
	var mask := smoothstep(-6.0, 6.0, coast)
	# Cliff coasts: the land keeps its height right up to the water and drops into
	# the sea in one sheer wall.
	var cliffy := smoothstep(0.35, 0.6, cl)
	if cliffy > 0.5 and coast < 48.0:
		mask = 1.0 if coast > 0.0 else 0.0
		land = maxf(land, sea + 4.0 + h * 3.0)
		kind = CLIFFS
	# Mountains inland where the mountain noise is high.
	var from: float = MOUNTAIN_FROM[settings.mountains]
	var mountain := smoothstep(from, from + 0.4, mount / 127.5 - 1.0) * smoothstep(24.0, 120.0, coast)
	if mountain > 0.0:
		var ridge := 1.0 - absf(ridges / 127.5 - 1.0)
		land += mountain * (3.0 + h * 4.0 + ridge * ridge * 18.0)
		if mountain > 0.3:
			kind = MOUNTAIN
	# Plateaus rise in terraces four cells apart, with sheer edges.
	var plat := plateau / 127.5 - 1.0
	if plat > 0.42 and coast > 64.0 and mountain < 0.3:
		land = sea + 6.0 + 4.0 * floorf(h * 3.0 + smoothstep(0.42, 0.7, plat) * 2.0)
		kind = HIGHLAND
	var height := clampi(int(round(lerpf(floor_h, land, mask))), 2, size_y - 6)
	if height < sea:
		kind = SEA_FLOOR
	return [height, kind]


## Lays out one row of the window: height, top, flags and biome of each column, with
## the sea, the lakes and the rivers cut in.
func _layout_row(lay: Dictionary, lz: int) -> void:
	_lattice_row(lay, lz)
	var grids: Array = lay.grids
	var hills: PackedByteArray = grids[0]
	var ridges: PackedByteArray = grids[1]
	var mount: PackedByteArray = grids[2]
	var shape: PackedByteArray = grids[3]
	var cliff: PackedByteArray = grids[4]
	var plateau: PackedByteArray = grids[5]
	var steep: PackedByteArray = grids[6]
	var soil: PackedByteArray = grids[7]
	var gully: PackedByteArray = grids[9]
	var mouths: PackedByteArray = grids[10]
	var pools: PackedByteArray = grids[11]
	var temp: PackedByteArray = grids[12]
	var moist: PackedByteArray = grids[13]
	var swamp: PackedByteArray = grids[14]
	var flow: PackedByteArray = grids[15]
	var dunes: PackedByteArray = grids[16]
	var roll: PackedByteArray = grids[17]
	var coast: PackedFloat32Array = lay.coast
	var river: PackedFloat32Array = lay.river
	var lake: PackedFloat32Array = lay.lake
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var tops: PackedByteArray = lay.tops
	var flags: PackedByteArray = lay.flags
	var biome: PackedByteArray = lay.biome
	var kinds: PackedByteArray = lay.kind
	var features: PackedByteArray = lay.feature
	var w: int = lay.w
	var soil_t := _byte(0.25)
	var steep_t := _byte(0.4)
	var mouth_t := _byte(0.55)
	var rough_t := _byte(0.3)
	var pool_t := _byte(0.12)
	var mud_t := _byte(0.0)
	var swamp_t := _byte(0.35)
	var mire_reach := 36
	var mire_t := _byte(-0.2)
	var river_from: float = RIVER_FROM[settings.rivers]
	for lx in w:
		var j := lz * w + lx
		var r := _relief(coast[j], hills[j], ridges[j], mount[j], shape[j], cliff[j], plateau[j], roll[j])
		var height: int = r[0]
		var kind: int = r[1]
		var f := 0
		var feature := DRY
		var top := Mat.GRASS
		var b := MEADOW
		var sheer := steep[j] >= steep_t or kind == CLIFFS or kind == HIGHLAND
		var rocky := height > sea + 12 or (kind == CLIFFS and height >= sea)
		var wt := -1
		# Rivers along the zero lines of the river noise, where the flow noise lets
		# them run, narrow at the source and wider towards the sea or a lake.
		var flowing := smoothstep(river_from, river_from + 0.35, flow[j] / 127.5 - 1.0)
		var d := river[j]
		var mouth := 1.0 - smoothstep(0.0, MOUTH_REACH, minf(coast[j], -lake[j]))
		var rw := 0.6 + (1.6 + 4.4 * mouth) * flowing
		var wet_bed := flowing > 0.2
		# The river's bed, also cut into the floor of the lake or the sea it flows
		# into, so the channel runs on without a step until the floor is deeper.
		var channel := sea - (2 if d < rw - 1.0 else 1) if wet_bed and d <= rw else size_y
		if height < sea:
			wt = sea
			b = SEA
			feature = OCEAN
			height = mini(height, channel)
		else:
			# Lakes over the high spots of the lake noise in the plains, with gentle
			# shores.
			var in_lake := lake[j]
			if kind == PLAIN and height <= sea + 8 and in_lake > -8.0:
				if in_lake > 0.0:
					height = mini(mini(height, sea - 1 - mini(4, int(in_lake / 3.0))), channel)
					wt = sea
					b = SEA
					feature = LAKE
				else:
					# The shore at the water's level, so it slopes into the water.
					height = mini(height, sea + int(-in_lake))
			# Where the flow fades the valley rises and the river ends.
			if wt < 0 and flowing > 0.0:
				var canyon := kind == MOUNTAIN or kind == HIGHLAND or height > sea + 10
				var rf := rw + (3.5 if canyon else 1.5)
				var bed := sea if wet_bed else int(lerpf(height, sea, flowing / 0.2))
				if d <= rw and wet_bed:
					height = mini(height, channel)
					wt = sea
					b = SEA
					top = Mat.SAND
					sheer = false
					feature = RIVER
				elif d <= rf:
					if canyon:
						height = mini(height, bed)
						top = Mat.SAND
						sheer = false
						feature = CANYON
					else:
						height = clampi(height, bed, bed + 1)
						sheer = false
				elif canyon and d <= rf + 2.0:
					# The canyon walls stay sheer.
					if height > bed + 2:
						sheer = true
				else:
					# A valley: the ground beyond the bank rises a cell per cell at most.
					height = mini(height, bed + 1 + int(d - rf))
		# How near water is, in steps of 16 cells: the coast, a lake or a river.
		var near := minf(coast[j], -lake[j])
		if flow[j] / 127.5 - 1.0 > river_from + 0.07:
			near = minf(near, river[j])
		var wet := clampi(int(near / 16.0), 0, 15)
		# Climate: warmth from the slow noise, colder up the hills; wetter near water.
		var t := clampf(0.5 + (temp[j] / 255.0 - 0.5) * 1.6, 0.0, 1.0) - (height - sea) * 0.006
		var m := (moist[j] / 255.0) * 0.6 + 0.4 - mini(wet, 5) * 0.04
		# Ravines: narrow winding cuts along a noise's zero line, four to six cells
		# deep, through the dry hot lowland and the rolling hills only.
		var g := absi(gully[j] - 128)
		var rough := (t > 0.6 and m < 0.6) or roll[j] > rough_t
		if kind == PLAIN and rough and not sheer and wt < 0 and height > sea + 1 and wet >= 2 and g < 5 and feature == DRY:
			height -= 6 if g < 4 else 4
		if rocky and wt < 0:
			top = Mat.STONE
			b = ROCK
		elif b == SEA:
			if feature != RIVER:
				top = Mat.SAND if soil[j] < soil_t else Mat.CLAY
		elif feature == CANYON:
			b = BEACH
		elif kind == HIGHLAND:
			b = PLATEAU
			top = Mat.STONE if height >= sea + 14 else Mat.GRASS
		elif height <= sea + 2 and wet <= 1:
			b = BEACH
			top = Mat.SAND if soil[j] < soil_t else Mat.CLAY
		elif kind == PLAIN and height <= sea + 4 and swamp[j] > swamp_t and wet <= 4 and t > 0.3:
			# A swamp: flat wet ground a level or two above the sea, with pools.
			b = SWAMP
			height = sea + 1 + int(soil[j] > _byte(0.4))
			var p := pools[j]
			if p > pool_t:
				wt = height
				height -= 1 if p < pool_t + 20 else 2
				top = Mat.CLAY
			elif p > pool_t - mire_reach and soil[j] > mire_t:
				# A mire along part of the pools' shores and in hollows of its own: mud
				# two cells deep a body sinks into to the waist.
				wt = height
				height -= 2
				top = Mat.CLAY
				f |= MIRE
			else:
				top = Mat.CLAY if p > mud_t else Mat.GRASS
			sheer = false
		elif t < 0.2:
			# Tundra: cold lowland, bare stone and clay showing through the grass.
			b = TUNDRA
			if soil[j] < _byte(-0.35):
				top = Mat.STONE
			elif soil[j] > _byte(0.45):
				top = Mat.CLAY
		elif t < 0.38 or height > sea + 14:
			b = TAIGA
		elif t > 0.66 and m < 0.56:
			# Desert: sand in low dunes.
			b = DESERT
			top = Mat.SAND
			if kind == PLAIN and not sheer:
				height += int(dunes[j] / 255.0 * 2.6)
		elif m > 0.7:
			b = FOREST
		if sheer:
			f |= SHEER_TOP
		# Cave mouths here and there in the hills, more often in the mountains.
		if height > sea + 3 and mouths[j] > (mouth_t - 20 if rocky else mouth_t):
			f |= ENTRANCE
		heights[j] = height
		water[j] = wt
		tops[j] = top
		flags[j] = f
		biome[j] = b
		kinds[j] = kind
		features[j] = feature


## Where each cave mouth of the window opens (columns three in from its edge, which
## see the same neighbours in every window, before the banks are raised): beside a
## drop of WALL cells or more a gallery at the foot of the drop, else on rolling ground
## high enough a pit, deepest in the middle of the mouth. None within three columns of
## water.
func _entrances(lay: Dictionary) -> void:
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var flags: PackedByteArray = lay.flags
	var adit: PackedByteArray = lay.adit
	var pit: PackedByteArray = lay.pit
	var mouths: PackedByteArray = lay.grids[10]
	var w: int = lay.w
	var pit_t := _byte(0.68)
	# Pits only in the rolling half of the land.
	var roll: PackedByteArray = lay.grids[17]
	var pit_roll_t := _byte(0.1)
	for lz in range(3, lay.h - 3):
		for lx in range(3, w - 3):
			var j := lz * w + lx
			if flags[j] & ENTRANCE == 0:
				continue
			var hh := heights[j]
			var foot := hh
			var top := hh
			var dry := true
			for dz in range(-3, 4):
				var base := j + dz * w
				for dx in range(-3, 4):
					if water[base + dx] >= 0:
						dry = false
					foot = mini(foot, heights[base + dx])
					top = maxi(top, heights[base + dx])
			if not dry:
				continue
			if top - foot >= WALL:
				if hh > foot and foot > sea:
					adit[j] = foot + 1
			elif hh > sea + 5 and mouths[j] > pit_t and roll[j] > pit_roll_t:
				pit[j] = mini(mini(2 + (mouths[j] - pit_t) / 4, PIT_DEPTH), hh - 2)


## Water above the sea must not stand beside open air: the ground beside water rises
## to its level. Caves keep away from water on their own (see _fill_row).
func _banks(lay: Dictionary) -> void:
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var w: int = lay.w
	var h: int = lay.h
	var raised := PackedInt32Array()
	raised.resize(heights.size())
	for lz in range(1, h - 1):
		for lx in range(1, w - 1):
			var j := lz * w + lx
			if water[j] >= 0:
				continue
			var hh := heights[j]
			hh = maxi(hh, maxi(maxi(water[j - 1], water[j + 1]), maxi(water[j - w], water[j + w])))
			raised[j] = hh - heights[j]
	for j in heights.size():
		heights[j] += raised[j]


## The columns of a window laid out at once (tools, the spawn, the map).
func lay_out(x0: int, z0: int, w: int, h: int, step := 1) -> Dictionary:
	var lay := _window(x0, z0, w, h, step)
	for k in window_noises.size():
		_sample(lay, k)
	_lattice(lay)
	for lz in h:
		_layout_row(lay, lz)
	if step == 1 and w > 2 and h > 2:
		_entrances(lay)
		_banks(lay)
	return lay


# --- Cells of a chunk -------------------------------------------------------------

## Writes the cells of one row of the chunk from the laid-out columns: stone with ore,
## a few cells of dirt (not under stone tops), the top, water up to its level, and
## caves under dry land away from water.
func _fill_row(key: Vector2i, lay: Dictionary, row: int) -> void:
	var c: WorldData.Chunk = world.chunks[key]
	var sy := size_y
	var layer := WorldData.LAYER
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var tops: PackedByteArray = lay.tops
	var flags: PackedByteArray = lay.flags
	var cells := c.cells
	var natural := c.natural
	var air_cols := c.air
	var water_cols := c.water
	var wild_cols := c.wild
	var all: int = world.all_bits
	var cave_t := _byte(0.42)
	var mouth_cave_t := _byte(0.3)
	var adit: PackedByteArray = lay.adit
	var pit: PackedByteArray = lay.pit
	var ore_t := _byte(0.55)
	var ore_top_t := _byte(0.7)
	var x_first := key.x * CHUNK
	var z := key.y * CHUNK + row
	# Does any column of the row want caves? Then sample the 3D noises along it.
	var caves := PackedByteArray()
	var ores := PackedByteArray()
	var want := false
	for lx in CHUNK:
		if heights[(row + MARGIN) * WINDOW + lx + MARGIN] > sea + 2:
			want = true
			break
	if want:
		n_caves.offset = Vector3(x_first, 0.0, z)
		n_ores.offset = Vector3(x_first, 0.0, z)
		# A slice of 3D noise: x along the row, y up (every other level), z this row.
		caves = _slice(n_caves, CHUNK, sy)
		ores = _slice(n_ores, CHUNK, sy)
	for lx in CHUNK:
		var j := (row + MARGIN) * WINDOW + lx + MARGIN
		var col := (row << WorldData.SHIFT) | lx
		var height := heights[j]
		var wt := water[j]
		var top: int = tops[j]
		var rocky := top == Mat.STONE
		var dirt := height if rocky else maxi(0, height - 4)
		var i := col
		for y in dirt:
			cells[i] = Mat.COPPER_ORE if want and ores[(y >> 1) * CHUNK + lx] > ore_t else Mat.STONE
			natural[i] = WorldData.WILD
			i += layer
		for y in range(dirt, height):
			cells[i] = Mat.DIRT
			natural[i] = WorldData.WILD
			i += layer
		cells[i] = Mat.COPPER_ORE if rocky and want and ores[(height >> 1) * CHUNK + lx] > ore_top_t else top
		natural[i] = WorldData.WILD | WorldData.SHEER if flags[j] & SHEER_TOP else WorldData.WILD
		var y := height + 1
		var wet := WorldData.WILD | (WorldData.BOG if flags[j] & MIRE else 0)
		while y <= wt:
			i += layer
			cells[i] = Mat.WATER
			natural[i] = wet
			y += 1
		for yy in range(maxi(height, wt) + 1, sy):
			i += layer
			cells[i] = Mat.AIR
			natural[i] = WorldData.WILD
		var air_bits := all & ~((1 << (maxi(height, wt) + 1)) - 1)
		water_cols[col] = ((1 << (wt + 1)) - 1) & ~((1 << (height + 1)) - 1) if wt > height else 0
		# Caves stay three cells under dry land away from any water, so they never
		# leak, and are bigger under a cave mouth. The mouth itself is a gallery cut
		# into the foot of a wall or a pit from the surface (see _entrances).
		if height > sea + 2 and wt < 0 and _dry_around(water, j):
			if want:
				var t2 := 2 * (mouth_cave_t if flags[j] & ENTRANCE else cave_t)
				i = layer + col
				for yc in range(1, height - 3):
					if caves[(yc >> 1) * CHUNK + lx] + caves[((yc + 1) >> 1) * CHUNK + lx] > t2:
						cells[i] = Mat.AIR
						air_bits |= 1 << yc
					i += layer
			var from := 0
			var to := -1
			if adit[j] > 0:
				from = adit[j]
				to = mini(from + ADIT - 1, height)
			elif pit[j] > 0:
				from = height - pit[j] + 1
				to = height
			for yc in range(from, to + 1):
				cells[yc * layer + col] = Mat.AIR
				air_bits |= 1 << yc
		air_cols[col] = air_bits
		wild_cols[col] = all


## True when no water lies within two columns of window column j.
static func _dry_around(water: PackedInt32Array, j: int) -> bool:
	for dz in range(-2, 3):
		var base := j + dz * WINDOW
		for dx in range(-2, 3):
			if water[base + dx] >= 0:
				return false
	return true


## A row of a 3D noise: `width` columns by every other level up to `depth`, as bytes
## (x + (y >> 1) * width), at the noise's offset.
static func _slice(n: FastNoiseLite, width: int, depth: int) -> PackedByteArray:
	# get_image_3d gives slices along z; a 1-deep volume with x along the row and y up.
	var imgs: Array = n.get_image_3d(width, depth / 2 + 1, 1, false, false)
	return (imgs[0] as Image).get_data()


# --- Trees -------------------------------------------------------------------

## The lattice columns of the chunk (x and z odd) that get a tree: a hash of the
## column against the chance of its biome, on grass above water, not beside another
## candidate to the west or north (trunks side by side would merge into a wall).
func _tree_candidates(_key: Vector2i, lay: Dictionary) -> Array:
	var out := []
	var x0: int = lay.x0
	var z0: int = lay.z0
	for lz in range(MARGIN, MARGIN + CHUNK):
		if (z0 + lz) & 1 == 0:
			continue
		for lx in range(MARGIN, MARGIN + CHUNK):
			if (x0 + lx) & 1 == 0:
				continue
			var species := _tree_at(lay, lx, lz)
			if species < 0 or _tree_at(lay, lx - 2, lz) >= 0 or _tree_at(lay, lx, lz - 2) >= 0:
				continue
			out.append([x0 + lx, z0 + lz, species, lay.heights[lz * WINDOW + lx]])
	return out


## Species of the tree a lattice column wants, -1 for none. Spruces on the high and
## cold ground, oaks in the lowland forest and the swamp, mixed where they meet.
func _tree_at(lay: Dictionary, lx: int, lz: int) -> int:
	var j := lz * WINDOW + lx
	var x: int = lay.x0 + lx
	var z: int = lay.z0 + lz
	var tops: PackedByteArray = lay.tops
	var water: PackedInt32Array = lay.water
	var flags: PackedByteArray = lay.flags
	if tops[j] != Mat.GRASS or water[j] >= 0 or flags[j] & (SHEER_TOP | ENTRANCE) or lay.heights[j] >= size_y - 8:
		return -1
	var b: int = lay.biome[j]
	var chance: float = TREE_CHANCE[b]
	var grids: Array = lay.grids
	var forest: PackedByteArray = grids[8]
	if b == MEADOW and forest[j] > _byte(0.3):
		chance = GROVE_CHANCE
	if _chance(x, z, 1) >= chance:
		return -1
	var spruce: float = SPRUCE_SHARE[b]
	# Higher up the share of spruces grows.
	spruce += clampf((lay.heights[j] - sea - 6) * 0.15, 0.0, 1.0) * 0.5
	return Trees.SPRUCE if _chance(x, z, 2) < spruce else Trees.OAK


## Grows one candidate tree: [x, z, species, ground height]. Chunks already SHAPED
## take nothing (see WorldData.Chunk.final). `again` grows a tree that was grown
## before, into a neighbour made again, unless the player cut its trunk.
func _plant(t: Array, again := false) -> void:
	var x: int = t[0]
	var z: int = t[1]
	var species: int = t[2]
	var hh: int = t[3]
	var base := world.get_cell(x, hh + 1, z)
	if again:
		if base != Mat.LOG or not world.trees.has(Vector2i(x, z)):
			return
	elif base != Mat.AIR and base != Mat.LEAVES:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(x, z, 3)
	var scale := Trees.fit(species, size_y - 1 - hh)
	if scale > 0.0:
		Trees.place(world, x, hh + 1, z, species, rng, scale)


## The trees of the planted neighbours of a chunk made again that reach into it.
func _regrown(key: Vector2i) -> Array:
	var out := []
	var x0 := key.x * CHUNK - TREE_REACH
	var z0 := key.y * CHUNK - TREE_REACH
	var x1 := (key.x + 1) * CHUNK + TREE_REACH
	var z1 := (key.y + 1) * CHUNK + TREE_REACH
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for t: Array in planted.get(Vector2i(key.x + dx, key.y + dz), []):
				if t[0] >= x0 and t[0] < x1 and t[1] >= z0 and t[1] < z1:
					out.append(t)
	return out


# --- Shapes and bushes ---------------------------------------------------------------

## The shape stage works on bands of rows: the slopes of every band first, then the
## corners, which look at the slopes beside them.
const SHAPE_BANDS := 4


## Slopes or corners of one band of rows of the chunk and two columns around it, so
## the chunk's mesh can read its neighbours' shapes.
func _shape_step(key: Vector2i, row: int) -> void:
	var x0 := key.x * CHUNK - 2
	var x1 := key.x * CHUNK + CHUNK + 2
	var z0 := key.y * CHUNK - 2
	var band := (CHUNK + 4) / SHAPE_BANDS
	var za := z0 + (row % SHAPE_BANDS) * band
	if row < SHAPE_BANDS:
		world.update_slopes(x0, za, x1, za + band)
	else:
		world.update_corners(x0, za, x1, za + band)


## A chunk made again after it was dropped (see forget) lost the shapes its shaped
## neighbours wrote along its edges, which their meshes read: works them out again on
## the strips of the chunk inside those neighbours' shape windows. A chunk made for the
## first time has no shaped neighbour yet (shaping needs the chunks around planted).
func _reshape_edges(key: Vector2i) -> void:
	var x0 := key.x * CHUNK
	var z0 := key.y * CHUNK
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dz != 0) and stage_of(key + Vector2i(dx, dz)) == SHAPED:
				var xa := x0 + (CHUNK - 2 if dx > 0 else 0)
				var za := z0 + (CHUNK - 2 if dz > 0 else 0)
				var xb := x0 + (2 if dx < 0 else CHUNK)
				var zb := z0 + (2 if dz < 0 else CHUNK)
				world.update_slopes(xa, za, xb, zb)
				world.update_corners(xa, za, xb, zb)


## Bushes of the chunk by biome: a hash of each cell against the biome's sparsity, on
## level grass in the open; blueberries under spruces, raspberries near oaks and at
## the edges of woods, plain shrubs elsewhere.
func _bushes(_key: Vector2i, lay: Dictionary) -> void:
	var biome: PackedByteArray = lay.biome
	var x0: int = lay.x0
	var z0: int = lay.z0
	for lz in range(MARGIN, MARGIN + CHUNK):
		for lx in range(MARGIN, MARGIN + CHUNK):
			var j := lz * WINDOW + lx
			var sparsity: int = BUSH_SPARSITY[biome[j]]
			if sparsity == 0:
				continue
			var x := x0 + lx
			var z := z0 + lz
			if _hash(x, z, 4) % sparsity != 0:
				continue
			var y: int = world.surface_y(x, z)
			if not Bushes.fits(world, x, y, z):
				continue
			var near := Bushes.tree_near(world, x, z, 10)
			var roll := _chance(x, z, 5)
			var type := Bushes.SHRUB
			if near == Trees.SPRUCE:
				type = Bushes.BLUEBERRY if roll < 0.7 else Bushes.SHRUB
			elif roll < (0.5 if near == Trees.OAK else 0.35):
				type = Bushes.RASPBERRY
			Bushes.place(world, x, y, z, type)


# --- Spawn, places and the map ---------------------------------------------------------

## A dry open meadow near the origin, on the lowland near water: where the player
## starts. Columns are tried on a spiral 16 cells apart; any dry land does when no
## meadow turns up.
func _pick_spawn() -> Vector3i:
	var fallback := Vector3i(0, size_y - 1, 0)
	var found_land := false
	var forest_t := _byte(0.3)
	for r in range(0, 160):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := dx * 16
				var z := dz * 16
				var lay := lay_out(x, z, 1, 1)
				var h: int = lay.heights[0]
				if lay.water[0] >= 0 or lay.flags[0] & SHEER_TOP:
					continue
				if not found_land:
					found_land = true
					fallback = Vector3i(x, h + 1, z)
				var grids: Array = lay.grids
				var forest: PackedByteArray = grids[8]
				if lay.biome[0] == MEADOW and h >= sea + 3 and h <= sea + 8 and forest[0] <= forest_t \
						and lay.river[0] > 12.0:
					return Vector3i(x, h + 1, z)
	return fallback


## Nearest dry grass cell to `around` on level ground (the chunks there must be
## SHAPED), or the guess itself.
static func find_spawn(w: WorldData, around: Vector3i) -> Vector3i:
	for r in range(0, 24):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := around.x + dx
				var z := around.z + dz
				var y := w.surface_y(x, z)
				if y > w.sea_level + 2 and y < w.size_y - 4 and w.get_cell(x, y - 1, z) == Mat.GRASS \
						and w.get_cell(x, y, z) == Mat.AIR and w.get_cell(x, y + 1, z) == Mat.AIR \
						and w.slope_mask(x, y - 1, z) == WorldData.FULL:
					return Vector3i(x, y, z)
	return Vector3i(around.x, w.size_y - 1, around.z)


## A column near `near` (in cells) that holds `what`: "lake", "river", "canyon" (a
## river between sheer walls), "swamp", "plateau", "cliffs" (a cliff coast), "beach",
## "mountain", "pit" (a cave mouth in the plains), "adit" (one in the mountains),
## "forest", "taiga", "desert" or "tundra"; `near` itself when there is
## none within `reach` cells. Columns are laid out on a spiral `stride` cells apart.
## For tools and tests.
func find_place(what: String, near: Vector2i, reach := 6000, stride := 16) -> Vector2i:
	if _is_place(what, lay_out(near.x, near.y, 1, 1), 0):
		return near
	for r in range(1, reach / stride):
		# The ring of radius r: the rows north and south, the columns west and east.
		var a := r * stride
		for side: Array in [[-a, -a, 2 * r + 1, 1], [-a, a, 2 * r + 1, 1], [-a, -a + stride, 1, 2 * r - 1],
				[a, -a + stride, 1, 2 * r - 1]]:
			var x0: int = near.x + side[0]
			var z0: int = near.y + side[1]
			var lay := lay_out(x0, z0, side[2], side[3], stride)
			for j in side[2] * side[3]:
				if _is_place(what, lay, j):
					var w: int = side[2]
					return Vector2i(x0 + (j % w) * stride, z0 + (j / w) * stride)
	return near


func _is_place(what: String, lay: Dictionary, j: int) -> bool:
	var b: int = lay.biome[j]
	var kind: int = lay.kind[j]
	var feature: int = lay.feature[j]
	match what:
		"lake":
			return feature == LAKE and lay.lake[j] > 6.0
		"river":
			return feature == RIVER and kind == PLAIN
		"canyon":
			return feature == CANYON
		"swamp":
			return b == SWAMP
		"plateau":
			return b == PLATEAU
		"cliffs":
			return kind == CLIFFS and lay.heights[j] >= sea + 3 and lay.coast[j] < 6.0
		"beach":
			return b == BEACH and feature == DRY and lay.coast[j] < 8.0 and kind == PLAIN
		"mountain":
			return b == ROCK and kind == MOUNTAIN
		"pit":
			var mouths: PackedByteArray = lay.grids[10]
			return lay.flags[j] & ENTRANCE and kind == PLAIN and mouths[j] > _byte(0.7) and lay.heights[j] > sea + 7
		"adit":
			return lay.flags[j] & ENTRANCE and kind == MOUNTAIN
		"forest":
			return b == FOREST
		"taiga":
			return b == TAIGA and lay.heights[j] <= sea + 9
		"desert":
			return b == DESERT
		"tundra":
			return b == TUNDRA
	return false


## Colour of a laid-out column for a map of the world before it is walked: the sea by
## depth, lakes and rivers blue, land by biome, lighter higher up.
func column_color(lay: Dictionary, j: int) -> Color:
	var h: int = lay.heights[j]
	var wt: int = lay.water[j]
	if wt >= 0:
		var deep := clampf((wt - h - 1) / 6.0, 0.0, 1.0)
		return Color(0.36, 0.6, 0.68).lerp(Color(0.12, 0.24, 0.42), deep)
	var c: Color = MAP_COLORS[lay.biome[j]]
	return c * (0.75 + 0.5 * clampf((h - sea) / 24.0, 0.0, 1.0))


## Colours of the biomes on the map.
const MAP_COLORS := [Color(0.12, 0.24, 0.42), Color(0.84, 0.76, 0.5), Color(0.42, 0.6, 0.28),
	Color(0.24, 0.44, 0.2), Color(0.22, 0.38, 0.3), Color(0.36, 0.44, 0.3), Color(0.56, 0.56, 0.56),
	Color(0.55, 0.58, 0.4), Color(0.86, 0.74, 0.46), Color(0.6, 0.66, 0.6)]
