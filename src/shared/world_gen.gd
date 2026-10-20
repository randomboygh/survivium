extends RefCounted
## Deterministic world generator: the same seed always gives the same island, whatever
## order its chunks are made in. Nothing is laid out by hand. At the start only a coarse
## layout of the whole map is made (one sample per COARSE cells): the base relief, the
## sea, the lakes that fill its basins and the rivers that run from the mountains down
## to the lakes and the sea. Everything else is made a chunk at a time, when the player
## comes near (see ChunkStreamer), in three stages that each read only what the stages
## before left in place:
## 1. TERRAIN: the columns of the chunk from noise layers (relief, ridges, mountains,
##    cliffs, plateaus, ravines, soil, climate), the water of the coarse layout cut in,
##    a biome per column, then the cells: stone with ore, dirt, the top, water, caves.
## 2. PLANTED: trees by biome, once the chunks around have their terrain (a crown may
##    reach into the next chunk). Which column gets a tree is a hash of the column, so
##    neighbours agree without looking at each other's cells.
## 3. SHAPED: slopes and corners (see WorldData.update_shapes) and bushes, once the
##    chunks around are planted, so nothing changes under them later.
## A chunk is meshed when it and its neighbours are SHAPED. Every generated cell is
## marked wild: loose ground lies as slopes wherever it steps down one cell, while
## stone, steep patches, cliffs and canyon walls keep sheer walls. Water above the sea
## never stands beside open air: banks are raised to its level and caves keep away
## from it. Sizes are in cells (8 px).

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const Trees := preload("res://src/shared/trees.gd")
const Bushes := preload("res://src/shared/bushes.gd")

const CHUNK := WorldData.CHUNK
## Cells per sample of the coarse layout.
const COARSE := 16
## Columns around a chunk the terrain stage lays out too, so banks, caves and trees
## can look at their neighbours.
const MARGIN := 3
const WINDOW := CHUNK + 2 * MARGIN

## Stages of a chunk (see above); 0 is nothing yet.
const TERRAIN := 1
const PLANTED := 2
const SHAPED := 3

## Biomes of a column, from its height, temperature and moisture.
const SEA := 0
const BEACH := 1
const MEADOW := 2
const FOREST := 3
const TAIGA := 4
const SWAMP := 5
const ROCK := 6
const PLATEAU := 7
const BIOME_NAMES := ["Море", "Берег", "Луг", "Лес", "Тайга", "Болото", "Скалы", "Плато"]
## Chance of a tree on a lattice column (every other column each way) per biome, and
## the share of spruces among them; groves of the forest noise raise the chance on
## meadows. Content data of the core mod will replace these tables.
const TREE_CHANCE := [0.0, 0.0, 0.004, 0.2, 0.16, 0.03, 0.0, 0.0]
const SPRUCE_SHARE := [0.0, 0.0, 0.2, 0.15, 0.9, 0.0, 0.0, 0.0]
const GROVE_CHANCE := 0.1
## One bush try per this many cells of a biome's ground.
const BUSH_SPARSITY := [0, 0, 160, 120, 140, 200, 0, 400]

## The eight samples around one, the straight ones first.
const AROUND := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1),
	Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

## Column flags while laying out: the top keeps a sheer wall; caves may open at the
## surface here.
const SHEER_TOP := 1
const ENTRANCE := 2

var world: WorldData
var world_seed: int
var size_x: int
var size_y: int
var size_z: int
var sea: int
## The coarse layout, `gw` by `gh` samples: base height, the flooded height and
## where each sample drains to (the sample's index, -1 at the sea), the level of the
## lake over it (-1 for none) and how deep it is there, the level of a river through
## it (-1 for none), and the distance to the nearest water in samples (capped).
var gw: int
var gh: int
var g_height := PackedInt32Array()
var g_filled := PackedInt32Array()
var g_flow := PackedInt32Array()
var g_lake := PackedInt32Array()
var g_depth := PackedByteArray()
var g_river := PackedInt32Array()
var g_wet := PackedByteArray()
## Rivers: each a Dictionary with points (cell coordinates, about a cell apart),
## levels (the top water cell at each point), widths (half width of the water) and
## canyon (1 where the river runs between sheer walls).
var rivers: Array = []
## Points of the rivers by the chunk they are in: [river, point] pairs.
var river_index := {}
## Stage of each chunk, by Vector2i(cx, cz); absent means nothing is made yet.
var stages := {}
## The laid-out columns of chunks between TERRAIN and SHAPED (see _layout), by chunk.
var layouts := {}
## Where the player is first put: a meadow near the middle of the map, refined by
## find_spawn once its chunk is made.
var spawn_guess: Vector3i

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
var n_caves: FastNoiseLite
var n_ores: FastNoiseLite
var n_meander: FastNoiseLite
var n_swamp: FastNoiseLite
## The 2D noises sampled for a window, in the order _layout reads them.
var window_noises: Array


## A chunk's generation job, stepped a row of columns at a time (see start, step).
class Job extends RefCounted:
	var key: Vector2i
	var stage: int
	## Rows (or trees) done so far and to do.
	var row := 0
	var rows: int
	## The window of laid-out columns (TERRAIN).
	var lay: Dictionary
	## Candidate tree columns (PLANTED): x, z, species, hash.
	var trees: Array = []
	var done := false


## The whole world at once, for tests and tools.
static func generate(world_seed: int, sx := 1024, sy := 48, sz := 1024) -> WorldData:
	var gen := new(world_seed, sx, sy, sz)
	gen.generate_all()
	return gen.world


func _init(seed_value: int, sx := 1024, sy := 48, sz := 1024) -> void:
	world_seed = seed_value
	size_x = sx
	size_y = sy
	size_z = sz
	world = WorldData.new(sx, sy, sz)
	sea = world.sea_level
	_noises()
	_coarse_layout()


## Generates every chunk of the map, stage by stage.
func generate_all() -> void:
	var cw := ceili(size_x / float(CHUNK))
	var ch := ceili(size_z / float(CHUNK))
	for stage: int in [TERRAIN, PLANTED, SHAPED]:
		for cz in ch:
			for cx in cw:
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


func chunks_x() -> int:
	return ceili(size_x / float(CHUNK))


func chunks_z() -> int:
	return ceili(size_z / float(CHUNK))


func in_map(key: Vector2i) -> bool:
	return key.x >= 0 and key.y >= 0 and key.x < chunks_x() and key.y < chunks_z()


## True when every chunk within `reach` of `key` (on the map) has reached `stage`.
func around(key: Vector2i, reach: int, stage: int) -> bool:
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var k := Vector2i(key.x + dx, key.y + dz)
			if in_map(k) and stages.get(k, 0) < stage:
				return false
	return true


## The first chunk within `reach` of `key` that has not reached `stage`, nearest to
## `key` first, or `key` itself with x = -1 when all have.
func missing(key: Vector2i, reach: int, stage: int) -> Vector2i:
	for r in range(0, reach + 1):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var k := Vector2i(key.x + dx, key.y + dz)
				if in_map(k) and stages.get(k, 0) < stage:
					return k
	return Vector2i(-1, 0)


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
	match stage:
		TERRAIN:
			job.lay = _window(key)
			job.rows = WINDOW + CHUNK
		PLANTED:
			job.trees = _tree_candidates(key, layouts[key])
			job.rows = job.trees.size()
		SHAPED:
			job.rows = 1 + CHUNK / 4
	return job


## Does the next `n` rows (or trees) of the job; true when the stage is done.
func step(job: Job, n: int) -> bool:
	world.track_edits = false
	while n > 0 and job.row < job.rows:
		match job.stage:
			TERRAIN:
				if job.row < WINDOW:
					_layout_row(job.key, job.lay, job.row)
					if job.row == WINDOW - 1:
						_rivers(job.key, job.lay)
						_banks(job.lay)
				else:
					_fill_row(job.key, job.lay, job.row - WINDOW)
			PLANTED:
				_plant(job.trees[job.row])
			SHAPED:
				_shape_rows(job.key, job.row)
		job.row += 1
		n -= 1
	world.track_edits = true
	if job.row >= job.rows and not job.done:
		job.done = true
		stages[job.key] = job.stage
		if job.stage == TERRAIN:
			layouts[job.key] = job.lay
		elif job.stage == SHAPED:
			_bushes(job.key, layouts[job.key])
			layouts.erase(job.key)
	return job.done


# --- Noises -------------------------------------------------------------------

func _noises() -> void:
	n_hills = _noise(0, 0.005, 4)
	n_ridges = _noise(1, 0.009, 3)
	n_mount = _noise(2, 0.0022, 2)
	n_shape = _noise(3, 0.004, 2)
	n_cliff = _noise(4, 0.006, 2)
	n_plateau = _noise(5, 0.0035, 2)
	n_steep = _noise(6, 0.045, 2)
	n_soil = _noise(7, 0.025, 2)
	n_forest = _noise(8, 0.015, 2)
	n_gully = _noise(9, 0.01, 1)
	n_mouths = _noise(10, 0.03, 1)
	n_pools = _noise(11, 0.07, 2)
	n_temp = _noise(12, 0.003, 2)
	n_moist = _noise(13, 0.004, 2)
	n_caves = _noise(14, 0.03, 2)
	n_ores = _noise(15, 0.075, 1)
	n_meander = _noise(16, 0.02, 1)
	n_swamp = _noise(17, 0.006, 2)
	window_noises = [n_hills, n_ridges, n_mount, n_shape, n_cliff, n_plateau, n_steep, n_soil,
		n_forest, n_gully, n_mouths, n_pools, n_temp, n_moist, n_swamp]


func _noise(salt: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed + salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Byte value of a noise level, as the sampled grids hold them (0..255 for -1..1).
static func _byte(v: float) -> int:
	return int((v * 0.5 + 0.5) * 255.0)


## A noise's byte at a point, the same as a grid sampled there would hold.
static func _at(n: FastNoiseLite, x: int, z: int) -> int:
	n.offset = Vector3.ZERO
	return _byte(n.get_noise_2d(x, z))


## A hash of a column, 0..2^24, different for each `salt` and world.
func _hash(x: int, z: int, salt: int) -> int:
	var h := (x * 374761393 + z * 668265263 + (world_seed + salt) * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFF


func _chance(x: int, z: int, salt: int) -> float:
	return _hash(x, z, salt) / float(1 << 24)


# --- Relief -------------------------------------------------------------------

## Base height of the land at a column from its noise bytes: the island mask over
## plains of low hills, mountains with sharp ridges along the noise's zero lines, the
## terraces of a plateau and the raised rim of a cliff coast. Shared by the coarse
## layout and the columns of a chunk, so both agree. Returns [height, kind] with kind
## 0 plain, 1 mountain, 2 plateau, 3 cliff coast, 4 sea floor.
func _relief(x: int, z: int, hills: int, ridges: int, mount: int, shape: int, cliff: int, plateau: int) -> Array:
	var half := minf(size_x, size_z) * 0.5
	var wobble := (shape - 128) / 128.0
	# Island mask: land in the middle, sea at the edges, a ragged coast.
	var d := Vector2(x - size_x * 0.5, z - size_z * 0.52).length() / half * (1.0 + 0.15 * wobble)
	var mask := 1.0 - smoothstep(0.72, 0.9, d)
	var h := hills / 255.0
	var land := sea + 2.0 + h * 7.0
	var kind := 0
	# Cliff coasts: the land keeps its height right up to the water and drops into
	# the sea in one sheer wall.
	var cliffy := smoothstep(0.35, 0.6, cliff / 127.5 - 1.0)
	if cliffy > 0.5 and d > 0.6:
		mask = 1.0 if mask > 0.5 else 0.0
		land += 4.0
		kind = 3
	# Mountains inland where the mountain noise is high.
	var mountain := smoothstep(0.3, 0.7, mount / 127.5 - 1.0) * smoothstep(0.85, 0.6, d)
	if mountain > 0.0:
		var ridge := 1.0 - absf(ridges / 127.5 - 1.0)
		land += mountain * (3.0 + h * 4.0 + ridge * ridge * 18.0)
		if mountain > 0.3:
			kind = 1
	# Plateaus rise in terraces four cells apart, with sheer edges.
	var plat := plateau / 127.5 - 1.0
	if plat > 0.42 and d < 0.7 and mountain < 0.3:
		land = sea + 6.0 + 4.0 * floorf(h * 3.0 + smoothstep(0.42, 0.7, plat) * 2.0)
		kind = 2
	var height := clampi(int(round(lerpf(sea - 7.0, land, mask))), 2, size_y - 6)
	if height < sea:
		kind = 4
	return [height, kind]


# --- Coarse layout --------------------------------------------------------------

## Lays out the whole map coarsely: base heights, drainage, lakes, rivers, distance
## to water, and the spawn.
func _coarse_layout() -> void:
	gw = ceili(size_x / float(COARSE))
	gh = ceili(size_z / float(COARSE))
	var n := gw * gh
	g_height.resize(n)
	for j in gh:
		for i in gw:
			var x := i * COARSE + COARSE / 2
			var z := j * COARSE + COARSE / 2
			g_height[j * gw + i] = _relief(x, z, _at(n_hills, x, z), _at(n_ridges, x, z), _at(n_mount, x, z),
				_at(n_shape, x, z), _at(n_cliff, x, z), _at(n_plateau, x, z))[0]
	_flood()
	_lakes()
	_trace_rivers()
	_wetness()
	_pick_spawn()


## Priority flood from the sea and the map's edge: the height each sample would fill
## to before draining, and the neighbour it drains through.
func _flood() -> void:
	var n := gw * gh
	g_filled.resize(n)
	g_filled.fill(-1)
	g_flow.resize(n)
	g_flow.fill(-1)
	# A binary heap of [filled height, index].
	var heap: Array = []
	for j in gh:
		for i in gw:
			var k := j * gw + i
			if g_height[k] < sea or i == 0 or j == 0 or i == gw - 1 or j == gh - 1:
				g_filled[k] = maxi(g_height[k], sea - 1)
				_heap_push(heap, [g_filled[k], k])
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var k: int = top[1]
		if top[0] != g_filled[k]:
			continue
		var i := k % gw
		var j := k / gw
		for d: Vector2i in AROUND:
			var ni := i + d.x
			var nj := j + d.y
			if ni < 0 or nj < 0 or ni >= gw or nj >= gh:
				continue
			var nk := nj * gw + ni
			if g_filled[nk] >= 0:
				continue
			g_filled[nk] = maxi(g_height[nk], g_filled[k])
			g_flow[nk] = k
			_heap_push(heap, [g_filled[nk], nk])


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if heap[p][0] <= heap[i][0]:
			break
		var t: Array = heap[p]
		heap[p] = heap[i]
		heap[i] = t
		i = p


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var i := 0
		var n := heap.size()
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < n and heap[l][0] < heap[m][0]:
				m = l
			if r < n and heap[r][0] < heap[m][0]:
				m = r
			if m == i:
				break
			var t: Array = heap[m]
			heap[m] = heap[i]
			heap[i] = t
			i = m
	return top


## Lakes fill the basins above the sea: samples that flood above their own height.
## A lake's level is one under the height it would spill at, so it never does; it is
## deeper away from its shore. Basins of a single sample stay dry hollows.
func _lakes() -> void:
	var n := gw * gh
	g_lake.resize(n)
	g_lake.fill(-1)
	g_depth.resize(n)
	var seen := PackedByteArray()
	seen.resize(n)
	for k in n:
		if seen[k] or g_filled[k] <= g_height[k] or g_filled[k] <= sea:
			continue
		# The connected basin at this filled height.
		var level := g_filled[k]
		var cells := PackedInt32Array([k])
		seen[k] = 1
		var at := 0
		while at < cells.size():
			var c := cells[at]
			at += 1
			var i := c % gw
			var j := c / gw
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni := i + d.x
				var nj := j + d.y
				if ni < 0 or nj < 0 or ni >= gw or nj >= gh:
					continue
				var nk := nj * gw + ni
				if not seen[nk] and g_filled[nk] == level and g_filled[nk] > g_height[nk]:
					seen[nk] = 1
					cells.append(nk)
		if cells.size() < 2:
			continue
		for c in cells:
			g_lake[c] = level - 1
	for k in n:
		if g_lake[k] < 0:
			continue
		var i := k % gw
		var j := k / gw
		var inner := 2
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni := i + d.x
			var nj := j + d.y
			if ni < 0 or nj < 0 or ni >= gw or nj >= gh or g_lake[nj * gw + ni] != g_lake[k]:
				inner = 0
		g_depth[k] = inner


## Rivers start at the highest samples of the mountains, a few samples apart, and
## follow the drainage down. One stops where it meets a lake, another river or the
## sea; past a lake it goes on from the lake's outflow. Its level only drops, stays
## two under the ground beside it and comes down to the level of what it flows into
## before it gets there.
func _trace_rivers() -> void:
	var n := gw * gh
	g_river.resize(n)
	g_river.fill(-1)
	var order: Array = []
	for k in n:
		if g_height[k] >= sea + 12 and g_lake[k] < 0:
			order.append([g_height[k], k])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var sources: Array[int] = []
	var spacing := maxi(3, gw / 10)
	for item in order:
		var k: int = item[1]
		var i := k % gw
		var j := k / gw
		var near := false
		for s in sources:
			if absi(s % gw - i) < spacing and absi(s / gw - j) < spacing:
				near = true
				break
		if not near:
			sources.append(k)
		if sources.size() >= maxi(2, gw / 8):
			break
	for s in sources:
		_trace_river(s)
	# Points of the rivers by chunk, for the chunks' layout.
	for r in rivers.size():
		var pts: PackedVector2Array = rivers[r].points
		for p in pts.size():
			var key := Vector2i(floori(pts[p].x / CHUNK), floori(pts[p].y / CHUNK))
			if not river_index.has(key):
				river_index[key] = []
			river_index[key].append([r, p])


func _trace_river(source: int) -> void:
	var path: Array[int] = [source]
	var level := g_height[source] - 2
	var levels: Array[int] = [level]
	var k := source
	var end_level := sea
	var travelled := 0
	while true:
		var nk := g_flow[k]
		if nk < 0:
			# Off the map or into the sea: the sea sample is the last point.
			break
		travelled += 1
		if g_lake[nk] >= 0:
			end_level = g_lake[nk]
			_river_segment(path, levels, end_level)
			# Through the lake to where it drains.
			var lake := g_lake[nk]
			while nk >= 0 and g_lake[nk] == lake:
				nk = g_flow[nk]
			if nk < 0:
				return
			path = [nk]
			level = mini(lake - 1, g_height[nk] - 2)
			levels = [level]
			k = nk
			continue
		if g_river[nk] >= 0:
			# Into another river: come down to its level there.
			path.append(nk)
			levels.append(g_river[nk])
			_river_segment(path, levels, g_river[nk])
			return
		path.append(nk)
		if g_height[nk] < sea:
			levels.append(sea)
			_river_segment(path, levels, sea)
			return
		level = maxi(sea, mini(level, g_height[nk] - 2))
		levels.append(level)
		k = nk
		if travelled > gw * 4:
			break
	_river_segment(path, levels, sea)


## Makes a river along the samples of `path` with the levels given, brought down to
## `end_level` over the last samples, and notes the samples it runs through.
func _river_segment(path: Array[int], levels: Array[int], end_level: int) -> void:
	if path.size() < 2:
		return
	var n := path.size()
	# The level never rises and reaches the end level over the last few samples.
	for i in n:
		var ramp: int = end_level + (n - 1 - i) * 2
		levels[i] = maxi(end_level, mini(levels[i], ramp))
	for i in range(1, n):
		levels[i] = mini(levels[i], levels[i - 1])
	for i in n:
		if g_river[path[i]] < 0:
			g_river[path[i]] = levels[i]
	# A smooth course through the middles of the samples, a cell a step, meandering.
	var pts: Array[Vector2] = []
	for k in path:
		# Each sample's point sits a little off its middle, so the course does not
		# follow the grid.
		var i := k % gw
		var j := k / gw
		pts.append(Vector2(i * COARSE + COARSE * 0.5 + (_chance(i, j, 6) - 0.5) * 8.0,
			j * COARSE + COARSE * 0.5 + (_chance(i, j, 7) - 0.5) * 8.0))
	var points := PackedVector2Array()
	var point_levels := PackedInt32Array()
	var widths := PackedFloat32Array()
	var canyon := PackedByteArray()
	var length := 0.0
	for i in n - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, n - 1)]
		var steps := maxi(1, ceili(p1.distance_to(p2)))
		for s in steps:
			var t := s / float(steps)
			var p := 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t)
			var along := (p2 - p0).normalized()
			var side := Vector2(-along.y, along.x)
			p += side * (n_meander.get_noise_1d(length) * 5.0 + n_meander.get_noise_1d(length * 0.2 + 1000.0) * 7.0)
			points.append(p)
			point_levels.append(levels[i])
			widths.append(minf(1.2 + length * 0.004, 3.4))
			canyon.append(1 if g_height[path[i]] - levels[i] > 5 else 0)
			length += 1.0
	rivers.append({"points": points, "levels": point_levels, "widths": widths, "canyon": canyon})


## Distance of each sample to water (the sea, a lake or a river), in samples, up to 15.
func _wetness() -> void:
	var n := gw * gh
	g_wet.resize(n)
	g_wet.fill(15)
	var queue := PackedInt32Array()
	for k in n:
		if g_height[k] < sea or g_lake[k] >= 0 or g_river[k] >= 0:
			g_wet[k] = 0
			queue.append(k)
	var at := 0
	while at < queue.size():
		var k := queue[at]
		at += 1
		var i := k % gw
		var j := k / gw
		var d: int = g_wet[k] + 1
		if d >= 15:
			continue
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni := i + o.x
			var nj := j + o.y
			if ni < 0 or nj < 0 or ni >= gw or nj >= gh:
				continue
			var nk := nj * gw + ni
			if g_wet[nk] > d:
				g_wet[nk] = d
				queue.append(nk)


## The sample nearest the middle of the map that is low, dry land near water: where
## the player starts.
func _pick_spawn() -> void:
	var ci := gw / 2
	var cj := gh / 2
	var best := -1
	var best_d := 1 << 30
	for k in gw * gh:
		var i := k % gw
		var j := k / gw
		var h := g_height[k]
		if h < sea + 3 or h > sea + 8 or g_lake[k] >= 0 or g_river[k] >= 0 or g_wet[k] < 1:
			continue
		var d := (i - ci) * (i - ci) + (j - cj) * (j - cj)
		if d < best_d:
			best_d = d
			best = k
	if best < 0:
		best = cj * gw + ci
	spawn_guess = Vector3i((best % gw) * COARSE + COARSE / 2, g_height[best] + 1, (best / gw) * COARSE + COARSE / 2)


# --- Terrain of a chunk -----------------------------------------------------------

## The window of a chunk's terrain stage: the noise grids over the chunk and its
## margin, and the arrays the layout fills, one entry per window column (j = lz *
## WINDOW + lx, column x0 - MARGIN + lx): height, water_top (the top water cell, -1
## for none), tops, flags, biome.
func _window(key: Vector2i) -> Dictionary:
	var x0 := key.x * CHUNK - MARGIN
	var z0 := key.y * CHUNK - MARGIN
	var grids: Array = []
	for n: FastNoiseLite in window_noises:
		n.offset = Vector3(x0, z0, 0.0)
		grids.append(n.get_image(WINDOW, WINDOW, false, false, false).get_data())
	var count := WINDOW * WINDOW
	var heights := PackedInt32Array()
	heights.resize(count)
	var water := PackedInt32Array()
	water.resize(count)
	water.fill(-1)
	var tops := PackedByteArray()
	tops.resize(count)
	var flags := PackedByteArray()
	flags.resize(count)
	var biome := PackedByteArray()
	biome.resize(count)
	return {"x0": x0, "z0": z0, "grids": grids, "heights": heights, "water": water, "tops": tops,
		"flags": flags, "biome": biome}


## Lays out one row of the window: height, top, flags and biome of each column, the
## sea and the lakes of the coarse layout cut in.
func _layout_row(_key: Vector2i, lay: Dictionary, lz: int) -> void:
	var grids: Array = lay.grids
	var hills: PackedByteArray = grids[0]
	var ridges: PackedByteArray = grids[1]
	var mount: PackedByteArray = grids[2]
	var shape: PackedByteArray = grids[3]
	var cliff: PackedByteArray = grids[4]
	var plateau: PackedByteArray = grids[5]
	var steep: PackedByteArray = grids[6]
	var soil: PackedByteArray = grids[7]
	var gully: PackedByteArray = grids[8]
	var mouths: PackedByteArray = grids[9]
	var pools: PackedByteArray = grids[10]
	var temp: PackedByteArray = grids[11]
	var moist: PackedByteArray = grids[12]
	var swamp: PackedByteArray = grids[13]
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var tops: PackedByteArray = lay.tops
	var flags: PackedByteArray = lay.flags
	var biome: PackedByteArray = lay.biome
	var x0: int = lay.x0
	var z0: int = lay.z0
	var z: int = z0 + lz
	var soil_t := _byte(0.25)
	var steep_t := _byte(0.4)
	var mouth_t := _byte(0.55)
	var pool_t := _byte(0.12)
	var mud_t := _byte(0.0)
	for lx in WINDOW:
		var j := lz * WINDOW + lx
		var x := x0 + lx
		var r := _relief(x, z, hills[j], ridges[j], mount[j], shape[j], cliff[j], plateau[j])
		var height: int = r[0]
		var kind: int = r[1]
		var f := 0
		var top := Mat.GRASS
		var b := MEADOW
		var in_map: bool = x >= 0 and z >= 0 and x < size_x and z < size_z
		var gi := clampi(x / COARSE, 0, gw - 1)
		var gj := clampi(z / COARSE, 0, gh - 1)
		var gk := gj * gw + gi
		var wet: int = g_wet[gk] if in_map else 0
		var lake: int = g_lake[gk] if in_map else -1
		var sheer := steep[j] >= steep_t or kind == 3 or kind == 2
		var rocky := height > sea + 12 or (kind == 3 and height >= sea)
		# Climate: colder to the north and up the hills, wetter near water.
		var t: float = (temp[j] / 255.0) * 0.5 + 0.7 - 0.8 * z / float(size_z) - (height - sea) * 0.025
		var m := (moist[j] / 255.0) * 0.6 + 0.4 - wet * 0.04
		# Ravines: narrow winding cuts along a noise's zero line through the dry
		# lowlands, four to six cells deep.
		var g := absi(gully[j] - 128)
		if kind == 0 and not sheer and height > sea + 1 and wet >= 2 and g < 5 and lake < 0:
			height -= 6 if g < 4 else 4
			sheer = false
		var wt := -1
		if height < sea:
			wt = sea
			b = SEA
		elif lake >= 0 and height < lake:
			# A lake over this sample: deeper away from the shore.
			height = mini(height, lake - 1 - g_depth[gk])
			wt = lake
			b = SEA
		if rocky:
			top = Mat.STONE
			b = ROCK
		elif b == SEA:
			top = Mat.SAND if soil[j] < soil_t else Mat.CLAY
		elif kind == 2:
			b = PLATEAU
			top = Mat.STONE if height >= sea + 14 else Mat.GRASS
		elif height <= sea + 2 and wet <= 1:
			b = BEACH
			top = Mat.SAND if soil[j] < soil_t else Mat.CLAY
		elif kind == 0 and height <= sea + 3 and swamp[j] > _byte(0.45) and wet <= 4:
			# A swamp: flat wet ground a level or two above the sea, with pools.
			b = SWAMP
			height = sea + 1 + int(soil[j] > _byte(0.4))
			var p := pools[j]
			if p > pool_t:
				wt = height
				height -= 1 if p < pool_t + 20 else 2
				top = Mat.CLAY
			else:
				top = Mat.CLAY if p > mud_t else Mat.GRASS
			sheer = false
		elif t < 0.45 or height > sea + 9:
			b = TAIGA
		elif m > 0.64:
			b = FOREST
		if sheer:
			f |= SHEER_TOP
		# In the hills caves come up to the surface here and there, in the mountains
		# more often.
		if height > sea + 5 and mouths[j] > (mouth_t - 20 if rocky else mouth_t):
			f |= ENTRANCE
		heights[j] = height
		water[j] = wt
		tops[j] = top
		flags[j] = f
		biome[j] = b


## Cuts the rivers through the window: each column takes the nearest point of a
## river within reach. Where the ground stands far above the water the river runs in
## a canyon, a wide dry floor between sheer walls; elsewhere the banks rise a cell at
## most per cell, so loose ground lies as slopes down to the water.
func _rivers(key: Vector2i, lay: Dictionary) -> void:
	var near: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			near.append_array(river_index.get(Vector2i(key.x + dx, key.y + dz), []))
	if near.is_empty():
		return
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var tops: PackedByteArray = lay.tops
	var flags: PackedByteArray = lay.flags
	var biome: PackedByteArray = lay.biome
	var x0: int = lay.x0
	var z0: int = lay.z0
	var count := WINDOW * WINDOW
	var best_d := PackedFloat32Array()
	best_d.resize(count)
	best_d.fill(1e9)
	var best := PackedInt32Array()
	best.resize(count)
	best.fill(-1)
	for i in near.size():
		var ref: Array = near[i]
		var river: Dictionary = rivers[ref[0]]
		var pi: int = ref[1]
		var p: Vector2 = river.points[pi]
		var rw: float = river.widths[pi]
		var cny: bool = river.canyon[pi] != 0
		var reach := rw + (3.5 if cny else 1.5) + (2.0 if cny else 5.0)
		for lz in range(maxi(0, floori(p.y - reach) - z0), mini(WINDOW, ceili(p.y + reach + 1.0) - z0)):
			for lx in range(maxi(0, floori(p.x - reach) - x0), mini(WINDOW, ceili(p.x + reach + 1.0) - x0)):
				var d := Vector2(x0 + lx + 0.5, z0 + lz + 0.5).distance_to(p)
				var j := lz * WINDOW + lx
				if d <= reach and d < best_d[j]:
					best_d[j] = d
					best[j] = i
	for j in count:
		var i := best[j]
		if i < 0:
			continue
		var ref: Array = near[i]
		var river: Dictionary = rivers[ref[0]]
		var pi: int = ref[1]
		var d := best_d[j]
		var rw: float = river.widths[pi]
		var cny: bool = river.canyon[pi] != 0
		var rf := rw + (3.5 if cny else 1.5)
		var lv: int = river.levels[pi]
		if d <= rw:
			heights[j] = mini(heights[j], lv - (2 if d < rw - 1.0 else 1))
			water[j] = maxi(water[j], lv)
			tops[j] = Mat.SAND
			flags[j] = 0
			biome[j] = SEA
		elif d <= rf:
			if water[j] >= 0:
				continue
			if cny:
				heights[j] = lv
				tops[j] = Mat.SAND
				flags[j] = 0
			else:
				heights[j] = clampi(heights[j], lv, lv + 1)
				flags[j] &= ~ENTRANCE
			if biome[j] != SWAMP:
				biome[j] = BEACH if heights[j] <= lv + 1 else biome[j]
		elif cny:
			# The canyon walls stay sheer.
			if heights[j] > lv + 2:
				flags[j] |= SHEER_TOP
		elif water[j] < 0:
			# A valley: the ground beyond the bank rises a cell per cell at most.
			heights[j] = mini(heights[j], lv + 1 + int(d - rf))


## Water above the sea must not stand beside open air: the ground beside water rises
## to its level. Caves keep away from water on their own (see _fill_row).
func _banks(lay: Dictionary) -> void:
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var raised := PackedInt32Array()
	raised.resize(heights.size())
	for lz in range(1, WINDOW - 1):
		for lx in range(1, WINDOW - 1):
			var j := lz * WINDOW + lx
			if water[j] >= 0:
				continue
			var h := heights[j]
			h = maxi(h, maxi(maxi(water[j - 1], water[j + 1]), maxi(water[j - WINDOW], water[j + WINDOW])))
			raised[j] = h - heights[j]
	for j in heights.size():
		heights[j] += raised[j]


## Writes the cells of one row of the chunk from the laid-out columns: stone with ore,
## a few cells of dirt (not under stone tops), the top, water up to its level, and
## caves under dry land away from water.
func _fill_row(key: Vector2i, lay: Dictionary, row: int) -> void:
	var w := world
	var sx := size_x
	var sy := size_y
	var layer := sx * size_z
	var z := key.y * CHUNK + row
	if z >= size_z:
		return
	var heights: PackedInt32Array = lay.heights
	var water: PackedInt32Array = lay.water
	var tops: PackedByteArray = lay.tops
	var flags: PackedByteArray = lay.flags
	var cells := w.cells
	var natural := w.natural
	var air_cols := w.air_cols
	var water_cols := w.water_cols
	var wild_cols := w.wild_cols
	var all: int = w.all_bits
	var cave_t := _byte(0.42)
	var ore_t := _byte(0.55)
	var ore_top_t := _byte(0.7)
	var x_first := key.x * CHUNK
	var x_last := mini(x_first + CHUNK, sx)
	# Does any column of the row want caves? Then sample the 3D noises along it.
	var caves := PackedByteArray()
	var ores := PackedByteArray()
	var want := false
	for x in range(x_first, x_last):
		if heights[(row + MARGIN) * WINDOW + x - x_first + MARGIN] > sea + 2:
			want = true
			break
	if want:
		n_caves.offset = Vector3(x_first, 0.0, z)
		n_ores.offset = Vector3(x_first, 0.0, z)
		# A slice of 3D noise: x along the row, y up (every other level), z this row.
		caves = _slice(n_caves, CHUNK, sy)
		ores = _slice(n_ores, CHUNK, sy)
	for x in range(x_first, x_last):
		var lx := x - x_first + MARGIN
		var j := (row + MARGIN) * WINDOW + lx
		var col := z * sx + x
		var height := heights[j]
		var wt := water[j]
		var top: int = tops[j]
		var rocky := top == Mat.STONE
		var dirt := height if rocky else maxi(0, height - 4)
		var i := col
		var ore := want and ores.size() > 0
		for y in dirt:
			cells[i] = Mat.COPPER_ORE if ore and ores[(y >> 1) * CHUNK + x - x_first] > ore_t else Mat.STONE
			natural[i] = WorldData.WILD
			i += layer
		for y in range(dirt, height):
			cells[i] = Mat.DIRT
			natural[i] = WorldData.WILD
			i += layer
		cells[i] = Mat.COPPER_ORE if rocky and ore and ores[(height >> 1) * CHUNK + x - x_first] > ore_top_t else top
		natural[i] = WorldData.WILD | WorldData.SHEER if flags[j] & SHEER_TOP else WorldData.WILD
		var y := height + 1
		while y <= wt:
			i += layer
			cells[i] = Mat.WATER
			natural[i] = WorldData.WILD
			y += 1
		for yy in range(maxi(height, wt) + 1, sy):
			i += layer
			cells[i] = Mat.AIR
			natural[i] = WorldData.WILD
		var air_bits := all & ~((1 << (maxi(height, wt) + 1)) - 1)
		water_cols[col] = ((1 << (wt + 1)) - 1) & ~((1 << (height + 1)) - 1) if wt > height else 0
		# Caves stay under dry land away from any water, so they never leak; at the
		# cave mouths they break the surface.
		if want and height > sea + 2 and wt < 0 and _dry_around(water, j):
			var cave_top := height + 1 if flags[j] & ENTRANCE else height - 3
			i = layer + col
			for yc in range(1, cave_top):
				var cx := x - x_first
				if caves[(yc >> 1) * CHUNK + cx] + caves[((yc + 1) >> 1) * CHUNK + cx] > 2 * cave_t:
					cells[i] = Mat.AIR
					air_bits |= 1 << yc
				i += layer
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
func _tree_candidates(key: Vector2i, lay: Dictionary) -> Array:
	var out := []
	var x0: int = lay.x0
	var z0: int = lay.z0
	for lz in range(MARGIN, MARGIN + CHUNK):
		if (z0 + lz) % 2 == 0:
			continue
		for lx in range(MARGIN, MARGIN + CHUNK):
			if (x0 + lx) % 2 == 0:
				continue
			var species := _tree_at(lay, lx, lz)
			if species < 0 or _tree_at(lay, lx - 2, lz) >= 0 or _tree_at(lay, lx, lz - 2) >= 0:
				continue
			var x := x0 + lx
			var z := z0 + lz
			out.append([x, z, species, lay.heights[lz * WINDOW + lx]])
	return out


## Species of the tree a lattice column wants, -1 for none. Spruces on the high and
## cold ground, oaks in the lowland forest and the swamp, mixed where they meet.
func _tree_at(lay: Dictionary, lx: int, lz: int) -> int:
	var j := lz * WINDOW + lx
	var x: int = lay.x0 + lx
	var z: int = lay.z0 + lz
	if x < 2 or z < 2 or x >= size_x - 2 or z >= size_z - 2:
		return -1
	var tops: PackedByteArray = lay.tops
	var water: PackedInt32Array = lay.water
	var flags: PackedByteArray = lay.flags
	if tops[j] != Mat.GRASS or water[j] >= 0 or flags[j] & SHEER_TOP or lay.heights[j] >= size_y - 8:
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


## Grows one candidate tree: [x, z, species, ground height].
func _plant(t: Array) -> void:
	var x: int = t[0]
	var z: int = t[1]
	var species: int = t[2]
	var hh: int = t[3]
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(x, z, 3)
	var scale := Trees.fit(species, size_y - 1 - hh)
	var col := z * size_x + x
	if world.cells[(hh + 1) * size_x * size_z + col] != Mat.AIR and world.cells[(hh + 1) * size_x * size_z + col] != Mat.LEAVES:
		return
	if scale > 0.0:
		Trees.place(world, x, hh + 1, z, species, rng, scale)


# --- Shapes and bushes ---------------------------------------------------------------

## Slopes first (one step), then the corners a few rows at a time, for the chunk and
## two columns around it, so the chunk's mesh can read its neighbours' shapes.
func _shape_rows(key: Vector2i, row: int) -> void:
	var x0 := maxi(0, key.x * CHUNK - 2)
	var z0 := maxi(0, key.y * CHUNK - 2)
	var x1 := mini(size_x, key.x * CHUNK + CHUNK + 2)
	var z1 := mini(size_z, key.y * CHUNK + CHUNK + 2)
	if row == 0:
		world.update_slopes(x0, z0, x1, z1)
		return
	var step := ceili((z1 - z0) / float(CHUNK / 4))
	var za := z0 + (row - 1) * step
	var zb := mini(z1, za + step)
	if za < zb:
		world.update_corners(x0, za, x1, zb)


## Bushes of the chunk by biome: a hash of each cell against the biome's sparsity, on
## level grass in the open; blueberries under spruces, raspberries near oaks and at
## the edges of woods, plain shrubs elsewhere.
func _bushes(key: Vector2i, lay: Dictionary) -> void:
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
			if x < 1 or z < 1 or x >= size_x - 1 or z >= size_z - 1 or _hash(x, z, 4) % sparsity != 0:
				continue
			var y: int = world.surface_y(x, z)
			if not Bushes.fits(world, x, y, z):
				continue
			var near := Bushes._tree_near(world, x, z, 10)
			var roll := _chance(x, z, 5)
			var type := Bushes.SHRUB
			if near == Trees.SPRUCE:
				type = Bushes.BLUEBERRY if roll < 0.7 else Bushes.SHRUB
			elif roll < (0.5 if near == Trees.OAK else 0.35):
				type = Bushes.RASPBERRY
			Bushes.place(world, x, y, z, type)


# --- Spawn and the map ---------------------------------------------------------------

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


## The cell at the middle of the coarse sample nearest to `near` (in cells) that
## holds `what`: "lake", "river", "canyon" (a river between sheer walls), "swamp",
## "plateau", "cliffs" (a cliff coast), "beach", "mountain" or "forest"; `near`
## itself when there is none. For tools and tests.
func find_place(what: String, near: Vector2i) -> Vector2i:
	var best := near
	var best_d := 1 << 30
	for k in gw * gh:
		var i := k % gw
		var j := k / gw
		var x := i * COARSE + COARSE / 2
		var z := j * COARSE + COARSE / 2
		var ok := false
		match what:
			"lake":
				ok = g_lake[k] >= 0
			"river":
				ok = g_river[k] >= 0 and g_lake[k] < 0 and g_height[k] >= sea
			"canyon":
				ok = g_river[k] >= 0 and g_lake[k] < 0 and g_height[k] - g_river[k] > 5
			"swamp":
				ok = g_height[k] >= sea + 1 and g_height[k] <= sea + 3 and g_wet[k] <= 4 and g_wet[k] >= 1 \
					and _at(n_swamp, x, z) > _byte(0.45) and _kind_at(x, z) == 0
			"plateau":
				ok = _kind_at(x, z) == 2
			"cliffs":
				ok = _kind_at(x, z) == 3 and g_height[k] >= sea and g_wet[k] <= 1
			"beach":
				ok = g_height[k] >= sea and g_height[k] <= sea + 2 and g_wet[k] <= 1 and _kind_at(x, z) == 0
			"mountain":
				ok = _kind_at(x, z) == 1
			"forest":
				ok = g_height[k] >= sea + 3 and g_height[k] <= sea + 9 and _at(n_moist, x, z) > _byte(0.5)
		if not ok:
			continue
		var d := (x - near.x) * (x - near.x) + (z - near.y) * (z - near.y)
		if d < best_d:
			best_d = d
			best = Vector2i(x, z)
	return best


func _kind_at(x: int, z: int) -> int:
	return _relief(x, z, _at(n_hills, x, z), _at(n_ridges, x, z), _at(n_mount, x, z), _at(n_shape, x, z),
		_at(n_cliff, x, z), _at(n_plateau, x, z))[1]


## Colour of a coarse sample for a map of the island: the sea by depth, lakes and
## rivers blue, land by height from meadow green to the grey of the mountains.
func coarse_color(i: int, j: int) -> Color:
	var k := j * gw + i
	var h := g_height[k]
	if h < sea:
		return Color(0.16, 0.3, 0.5).lerp(Color(0.1, 0.2, 0.38), clampf((sea - h) / 7.0, 0.0, 1.0))
	if g_lake[k] >= 0 or g_river[k] >= 0:
		return Color(0.25, 0.45, 0.6)
	var t := clampf((h - sea) / 22.0, 0.0, 1.0)
	var c := Color(0.42, 0.58, 0.28).lerp(Color(0.6, 0.6, 0.55), smoothstep(0.35, 0.7, t))
	if t > 0.75:
		c = c.lerp(Color(0.85, 0.85, 0.88), (t - 0.75) * 4.0)
	if h <= sea + 2:
		c = c.lerp(Color(0.8, 0.74, 0.5), 0.6)
	return c
