extends "res://src/shared/world/land_layout.gd"
## Deterministic world generator: the same seed and settings always give the same
## world, whatever order its chunks are made in. The world has no edge: everything
## comes from noise at the column itself, so any chunk can be made at any time, as the
## player comes near (see ChunkStreamer), and made again the same after it was dropped.
## Continents and oceans come from a very slow noise, mountains, plateaus and cliff
## coasts from slower and faster ones over the land (and flat beaches where the cliff
## noise is low), rivers run along the zero lines of a noise, widening towards the sea
## and parting into deltas at it, and lakes fill its high spots, both at the level of
## the sea. A mountain rises from a gentle foot through woods to bare scree and stone,
## snowy at the top (WorldData.SNOW_LINE); the rivers that rise on it come down in
## steps, over rapids and waterfalls, and now and then a cave is cut into its side. The
## climate (warmth and moisture) is noise too, so biomes spread over hundreds of cells. A chunk
## is made in three stages that each read only what the stages before left in place:
## 1. TERRAIN: the columns of the chunk and a margin around it are laid out (height,
##    water, top, biome), then the cells are written: stone with ore, dirt, the top,
##    water, caves. The trees of planted neighbours that reach in are grown again.
## 2. PLANTED: trees by biome, once the chunks around have their terrain (a crown may
##    reach into the next chunk). Which column gets a tree is a hash of the column, so
##    neighbours agree without looking at each other's cells.
## 3. SHAPED: slopes and corners (see WorldData.update_shapes) and bushes, once the
##    chunks around are planted, so nothing changes under them later.
## A chunk is meshed when it and its neighbours are SHAPED (see `needed`); the stages
## are ordered by the session of the world (Session.make_chunks). Every generated cell is
## marked wild: loose ground lies as slopes wherever it steps down one cell, while
## stone, steep patches, cliffs and canyon walls keep sheer walls. Water above the sea
## never stands beside open air: banks are raised to its level and caves keep away
## from it. Each stage is done a few rows (or a tree) at a time; sizes are in cells.
## A chunk the player changed comes back from the save (`saved`, see WorldStore) in
## place of its terrain stage, SHAPED at once, and grows its trees again into the
## chunks around that are not final, as its planting would have.

## A chunk reached `stage` (a job of it finished, see step): a chunk from the save comes
## back SHAPED in place of its terrain.
signal made(key: Vector2i, stage: int)

const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
## How far a tree reaches from its trunk, so a chunk made again knows which trees of
## its neighbours to grow again (see Trees.place).
const TREE_REACH := 10
## Stages of a chunk (see above); 0 is nothing yet.
const TERRAIN := 1
const PLANTED := 2
const SHAPED := 3
## Chance of a tree on a lattice column of the wooded slopes of a mountain (WOODS), at least.
const WOODS_CHANCE := 0.12
## With relief 1 the spawn keeps this many cells from mountains, mesas, gorges and tors
## (see _calm_around): about the chunks built before the world is ready.
const SPAWN_CALM := 64
## Veins are of one ore in each block of 2^VEIN_SHIFT cells a side (see _vein).
const VEIN_SHIFT := 3

var world: WorldData
## Cells of a saved chunk come from a world saved with materials in another order:
## saved index -> loaded index (see Mat.remap); empty when the orders agree.
var material_map := PackedByteArray()
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
	## The crown of the tree grown last and the next of its points to fill, a few
	## points a step (see CROWN_STEP).
	var crown: Array[Vector3i] = []
	var crown_at := 0
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
	beach = Mat.of_role("beach", Mat.DIRT)
	bank = Mat.of_role("bank", Mat.DIRT)
	scree = Mat.of_role("scree", Mat.STONE)
	snow = Mat.of_role("snow", Mat.STONE)
	peat = Mat.of_role("peat", Mat.DIRT)
	salt = Mat.of_role("salt", beach)
	ice = Mat.of_role("ice", Mat.STONE)
	grounds = {"grass": Mat.GRASS, "dirt": Mat.DIRT, "stone": Mat.STONE, "sand": beach, "clay": bank, "snow": snow, "peat": peat, "salt": salt, "ice": ice}
	ore = Mat.ORE if Mat.ORE >= 0 else Mat.STONE
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


## The next stage some chunk needs before `key` can be meshed: [chunk, stage], or
## empty when it can be. A chunk is meshed once it is SHAPED, which takes the chunks
## around it PLANTED, which takes the chunks around those with terrain (a chunk from
## the save, SHAPED at once, still waits for them: its meshes read their cells).
func needed(key: Vector2i) -> Array:
	var m: Variant = missing(key, 2, TERRAIN)
	if m != null:
		return [m, TERRAIN]
	m = missing(key, 1, PLANTED)
	if m != null:
		return [m, PLANTED]
	if stages.get(key, 0) < SHAPED:
		return [key, SHAPED]
	return []


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


# --- Jobs ------------------------------------------------------------------------


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
			if not material_map.is_empty():
				var cells: PackedByteArray = d.cells
				for i in cells.size():
					cells[i] = material_map[cells[i]] if cells[i] < material_map.size() else Mat.STONE
				d.cells = cells
			job.restore = d
			job.trees = d.get("planted", [])
			job.rows = 1 + job.trees.size()
			if not d.get("biome") is PackedByteArray:
				# Saved before chunks kept their columns' biomes: laid out again, a row
				# a step.
				job.rows += CHUNK
			return job
		push_error("saved chunk %s is broken or of another world: made anew" % key)
	match stage:
		TERRAIN:
			job.lay = _window(key.x * CHUNK - MARGIN, key.y * CHUNK - MARGIN, WINDOW, WINDOW)
			job.trees = _regrown(key)
			job.rows = window_noises.size() + 1 + WINDOW + 1 + CHUNK + job.trees.size()
		PLANTED:
			job.trees = _tree_candidates(key, layouts[key])
			job.rows = job.trees.size()
		SHAPED:
			job.rows = 2 * SHAPE_BANDS
	return job


## Points of a crown filled in one step: a big oak has some 150, and a whole tree was
## the longest step of the generator (2026-10-24).
const CROWN_STEP := 8


## Does the next `n` steps of the job; true when the stage is done.
func step(job: Job, n: int) -> bool:
	world.track_edits = false
	while n > 0 and (job.row < job.rows or job.crown_at < job.crown.size()):
		if job.crown_at < job.crown.size():
			job.crown_at = Trees.fill(world, job.crown, job.crown_at, CROWN_STEP)
		elif not job.restore.is_empty():
			if job.row == 0:
				world.unpack_chunk(job.restore)
			elif job.row <= job.trees.size():
				_plant(job, job.trees[job.row - 1], true)
			else:
				_biome_row(job.key, job.row - 1 - job.trees.size())
			job.row += 1
		else:
			match job.stage:
				TERRAIN:
					_terrain_step(job, job.row)
				PLANTED:
					_plant(job, job.trees[job.row])
				SHAPED:
					_shape_step(job.key, job.row)
			job.row += 1
		n -= 1
	world.track_edits = true
	if job.row >= job.rows and job.crown_at >= job.crown.size() and not job.done:
		job.done = true
		if not job.restore.is_empty():
			job.stage = SHAPED
			stages[job.key] = SHAPED
			planted[job.key] = job.trees
			made.emit(job.key, SHAPED)
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
		made.emit(job.key, job.stage)
	return job.done


## The steps of the terrain stage: sample the noises one by one, the slow ones on the
## lattice, lay out the rows of the window, raise the banks, cut the caves into the
## mountains' sides, write the rows of cells, then grow the neighbours' trees that
## reach in.
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
	if row == 0:
		_tunnels(job.lay)
		return
	row -= 1
	if row < CHUNK:
		if row == 0:
			world.add_chunk(job.key)
		_fill_row(job.key, job.lay, row)
		return
	row -= CHUNK
	_plant(job, job.trees[row], true)


## Writes the biomes of one row of chunk `key` from the layout (a chunk saved before
## chunks kept them, see Chunk.biome).
func _biome_row(key: Vector2i, row: int) -> void:
	var c: WorldData.Chunk = world.chunks[key]
	var lay := lay_out(key.x * CHUNK, key.y * CHUNK + row, CHUNK, 1)
	var biome: PackedByteArray = lay.biome
	for lx in CHUNK:
		c.biome[(row << WorldData.SHIFT) | lx] = biome[lx]


# --- Cells of a chunk ------------------------------------------------------------


## The ore of the vein at cell x, y, z: which of the loaded ores (Mat.vein_at, by their
## `veins`) the world's seed gives the block of VEIN cells it lies in.
func _vein(x: int, y: int, z: int) -> int:
	if Mat.ORES.size() < 2:
		return ore
	var h := hash(Vector4i(x >> VEIN_SHIFT, y >> VEIN_SHIFT, z >> VEIN_SHIFT, world_seed))
	return Mat.vein_at((h & 0xFFFF) / 65536.0, ore)


## Writes the cells of one row of the chunk from the laid-out columns: stone with ore,
## a few cells of dirt (not under stone tops) or of the top's own (Mat.layers), the top, water up to its level, and
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
	var cave_t := _byte(CAVE_FROM[settings.caves])
	var mouth_cave_t := _byte(MOUTH_CAVE_FROM[settings.caves])
	var adit: PackedByteArray = lay.adit
	var pit: PackedByteArray = lay.pit
	var shape: PackedByteArray = lay.grids[3]
	var bands := PackedInt32Array([Mat.STONE, bank, beach, bank, Mat.STONE])
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
		c.biome[col] = lay.biome[j]
		var height := heights[j]
		var wt := water[j]
		var top: int = tops[j]
		var rocky := top == Mat.STONE
		var dirt := height if rocky else maxi(0, height - 4)
		var bed := maxi(0, height - Mat.layers[top])
		var i := col
		for y in dirt:
			cells[i] = _vein(x_first + lx, y, z) if want and ores[(y >> 1) * CHUNK + lx] > ore_t else Mat.STONE
			natural[i] = WorldData.WILD
			i += layer
		for y in range(dirt, height):
			cells[i] = Mat.DIRT if y < bed else top
			natural[i] = WorldData.WILD
			i += layer
		if flags[j] & STRATA:
			# A mesa's walls are banded: layers of stone, clay and sand two cells
			# thick, wavering a little.
			var wob: int = shape[j] >> 6
			for y in range(maxi(0, sea - 2), height):
				cells[col + y * layer] = bands[((y + wob) >> 1) % bands.size()]
		cells[i] = _vein(x_first + lx, height, z) if rocky and want and ores[(height >> 1) * CHUNK + lx] > ore_top_t else top
		natural[i] = WorldData.WILD | WorldData.SHEER if flags[j] & SHEER_TOP else WorldData.WILD
		var y := height + 1
		var wet := WorldData.WILD | (WorldData.BOG if flags[j] & MIRE else (WorldData.SWAMP if flags[j] & MARSH else 0))
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


# --- Trees -----------------------------------------------------------------------


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


## Species of the tree a lattice column wants, -1 for none: its biome's chance (more in
## the biome's groves where the forest noise is high, and on the wooded slopes of a
## mountain at least WOODS_CHANCE) and one of its biome's species by their shares; the
## wooded slopes of a biome without trees take any loaded species.
func _tree_at(lay: Dictionary, lx: int, lz: int) -> int:
	var j := lz * WINDOW + lx
	var x: int = lay.x0 + lx
	var z: int = lay.z0 + lz
	var tops: PackedByteArray = lay.tops
	var water: PackedInt32Array = lay.water
	var flags: PackedByteArray = lay.flags
	var b: int = lay.biome[j]
	if (tops[j] != Mat.GRASS and not tops[j] in Biomes.tree_grounds(b, grounds)) or water[j] >= 0 or flags[j] & (SHEER_TOP | ENTRANCE) or lay.heights[j] >= size_y - 8:
		return -1
	var chance := Biomes.tree_chance(b)
	var grids: Array = lay.grids
	var forest: PackedByteArray = grids[8]
	if forest[j] > _byte(0.3):
		chance = maxf(chance, Biomes.groves(b))
	var woods := flags[j] & WOODS != 0
	if woods:
		chance = maxf(chance, WOODS_CHANCE)
	if _chance(x, z, 1) >= chance:
		return -1
	var species := Biomes.tree(b, _chance(x, z, 6))
	if species < 0 and woods and Biomes.of(b).get("tree_shares", []).is_empty():
		species = Trees.any(_chance(x, z, 2))
	return species


## Grows one candidate tree of the job: [x, z, species, ground height]; its crown is
## filled by the next steps. Chunks already SHAPED take nothing (see
## WorldData.Chunk.final). `again` grows a tree that was grown before, into a
## neighbour made again, unless the player cut its trunk.
func _plant(job: Job, t: Array, again := false) -> void:
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
		job.crown = Trees.grow(world, x, hh + 1, z, species, rng, scale)
		job.crown_at = 0


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


## The shape stage works on bands of rows: the slopes of every band first, then the
## corners, which look at the slopes beside them.
const SHAPE_BANDS := 10


# --- Shapes and bushes -----------------------------------------------------------


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
## level grass in the open; which bush, the biome says by its shares (Biomes.bush).
func _bushes(_key: Vector2i, lay: Dictionary) -> void:
	var biome: PackedByteArray = lay.biome
	var x0: int = lay.x0
	var z0: int = lay.z0
	for lz in range(MARGIN, MARGIN + CHUNK):
		for lx in range(MARGIN, MARGIN + CHUNK):
			var j := lz * WINDOW + lx
			var sparsity := Biomes.sparsity(biome[j])
			if sparsity == 0:
				continue
			var x := x0 + lx
			var z := z0 + lz
			if _hash(x, z, 4) % sparsity != 0:
				continue
			var y: int = world.surface_y(x, z)
			if not Bushes.fits(world, x, y, z):
				continue
			var type := Biomes.bush(biome[j], _chance(x, z, 5))
			if type >= 0:
				Bushes.place(world, x, y, z, type)


# --- Spawn -----------------------------------------------------------------------


## A dry open spot of a biome that allows it (a meadow) near the origin, on the lowland
## near water: where the player starts. Columns are tried on a spiral 16 cells apart; any dry land does when no
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
				if Biomes.spawn_ok(lay.biome[0]) and h >= sea + 3 and h <= sea + 8 and forest[0] <= forest_t \
						and lay.river[0] > 12.0 and _calm_around(x, z):
					return Vector3i(x, h + 1, z)
	return fallback


## With relief 1, whether the land within SPAWN_CALM cells of column x, z has no
## mountains, mesas, gorges or tors: a new player starts on gentle ground, and the
## chunks built first round them are the lighter ones to make and draw. Older worlds
## keep their spawn (always true).
func _calm_around(x: int, z: int) -> bool:
	if settings.relief < 1:
		return true
	var n := SPAWN_CALM * 2 / 16 + 1
	var lay := lay_out(x - SPAWN_CALM, z - SPAWN_CALM, n, n, 16)
	for j in lay.kind.size():
		if lay.kind[j] == MOUNTAIN or lay.kind[j] == HIGHLAND or lay.cut[j] != 0:
			return false
	return true


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


## The biome of column x, z (an index of Biomes): as its chunk keeps it when the chunk is
## made, else laid out for the column alone (the same: the layout of a column does not
## depend on its window; generation_test checks it).
func biome_of(x: int, z: int) -> int:
	var b: int = world.biome_at(x, z) if world != null else WorldData.NO_BIOME
	return b if b != WorldData.NO_BIOME else lay_out(x, z, 1, 1).biome[0]
