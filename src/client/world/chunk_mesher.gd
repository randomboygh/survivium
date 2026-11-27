extends "res://src/client/world/mesh_faces.gd"
## Builds meshes from the cell grid: one quad per visible cell face, with the data the
## world shader needs for edges and material transitions (see world.gdshader). Natural
## ground also gets slopes and diagonal corners, cut-off outer corners and filled inner
## ones, as WorldData shapes them; a slope is a smooth curved surface shared with the
## slopes beside it (see `patch`). A chunk mesh holds all levels of a 16x16 column of
## cells; only the cells next to something open are looked at, found from the world's
## column masks, and plain tops in a row are merged into one long quad. The cutaway
## hides upper levels in the shader, and `build_cap` closes the cut with dark tops.
## Leaves are not cubes: Foliage draws them as leaf clumps. Meshes are built in cells
## and scaled to world units.

## The vertex colour of the faces of a cracked built cell (building decay, WorldData.cracks):
## green at half marks it, world.gdshader draws the cracks and keeps the tile's colours.
const CRACKED := Color(1, 0.5, 1)
const OldSlopes := preload("res://src/client/world/old_slope_mesher.gd")
const Water := preload("res://src/client/world/water_mesher.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Trunks := preload("res://src/client/world/trunk_mesher.gd")
const Forms := preload("res://src/client/world/form_mesher.gd")

## Per direction: [corners, uvs, normal] of a whole cell face.
static var _cell_faces: Array = []
## Cells drawn as air though they are solid (cell -> true; ChunkStreamer.set_holes): the
## openings a door or a window of the blueprint, or one held up, will cut into a wall,
## shown cut in the build mode with the faces round them (user 2026-11-26). Only the view:
## the world and its picking keep the blocks.
static var holes := {}
## How far a cut's wall reaches down into a slope under it (see _cut_walls), in cells.
const CUT_SKIRT := 0.08


## The state of a chunk's meshes being built column by column (see `start`, `step`, `finish`),
## so the game can spread the work over frames.
class Job extends RefCounted:
	var w
	var x0: int
	var z0: int
	var x1: int
	var z1: int
	var z: int
	var x: int
	var faces: Array
	var solid
	var water
	var c: PackedByteArray
	var sh: PackedByteArray
	var cov: PackedByteArray
	var dz: int
	var dy: int
	var nb: PackedByteArray
	var side_offsets: PackedInt32Array
	var plain: PackedInt32Array
	var water_plain: PackedInt32Array
	## The waterfalls, drawn after all the other water (WaterMesher.falls).
	var water_falls: PackedInt32Array
	## How many of the plain tops are drawn (see _plain_rows).
	var plain_j := 0
	var water_j := 0
	var falls_j := 0
	var cands: PackedInt64Array
	## The forms of the built blocks that are not cubes (WorldData.forms) in the padded
	## grid, by index, and the steps to a cell's neighbours in DIRS order.
	var forms := {}
	var offsets: PackedInt32Array
	## Steps of copying the cells before the columns (see PREP_STEPS); 0 once done.
	var prep := PREP_STEPS
	## Where the buffers stood as each column was done, in the order of the columns:
	## solid vertices, solid indices, water vertices, water indices (see `patch`).
	var ends := PackedInt32Array()
	## Columns for `patch` only: the plain tops are left as keys, not drawn.
	var part := false
	## Where cells that cast light (Mat.lit: lava, crystals) show to the air, over their
	## middles in world units, and the material of each (GlowLights lights the nearest).
	var glows := PackedVector3Array()
	var glow_mats := PackedByteArray()
	## How far each column (and one round them) lies from the sea's waterline over land
	## level with it, for the surf (WaterMesher.swash_map); empty where it reaches none.
	var swash := PackedFloat32Array()


## The solid and water meshes of the cells x0..x0+size, z0..z0+size, all at once:
## [solid_mesh_or_null, water_mesh_or_null]. Works on copies of the chunk's cells and
## shapes with a border of PAD cells (outside the map is air, below it is stone), so
## neighbour lookups are plain array reads.
static func build_chunk(w, x0: int, z0: int, size: int) -> Array:
	var job := start(w, x0, z0, size)
	while not step(job, 1 << 30):
		pass
	return finish(job)


## Steps a job takes to copy the cells of the chunk and a border around it before
## the columns: the cells and their shapes, each in two halves of the levels, then the
## cells that may show a face. A whole copy takes about 0.9 ms on a desktop, some ten
## times that on a phone, three times the streamer's budget, so it goes half a step.
const PREP_STEPS := 5
## Added to a plain water cell's depth in its key (the depth is 8 at most) on the sea's
## water (WorldData.SEA_WATER), so the rows of the sea and of other water stay apart.
const SEA_TILE := 16


## Begins building the meshes of a chunk; `step` then copies its cells and builds a
## few columns at a time.
static func start(w, x0: int, z0: int, size: int) -> Job:
	return start_rect(w, x0, z0, x0 + size, z0 + size)


## Like `start`, for the columns x0..x1, z0..z1 (ends exclusive); `part` for a piece of a
## chunk that `patch` puts into the chunk's meshes.
static func start_rect(w, x0: int, z0: int, x1: int, z1: int, part := false) -> Job:
	var job := Job.new()
	job.w = w
	job.x0 = x0
	job.z0 = z0
	job.z = z0
	job.x = x0
	job.part = part
	sea_level = w.sea_level
	job.faces = face_table()
	job.solid = MeshBuffers.new()
	job.water = MeshBuffers.new()
	job.x1 = x1
	job.z1 = z1
	job.cov = covers_table()
	# Strides of the padded grid: +x, +z, +y.
	job.dz = x1 - x0 + 2 * PAD
	job.dy = job.dz * (z1 - z0 + 2 * PAD)
	job.nb = PackedByteArray()
	job.nb.resize(6)
	job.side_offsets = PackedInt32Array([1, -1, 0, 0, job.dz, -job.dz])
	job.offsets = PackedInt32Array([1, -1, job.dy, -job.dy, job.dz, -job.dz])
	# Plain tops (no edges, corners or transitions) and plain water wait here to be
	# merged into rows.
	job.plain = PackedInt32Array()
	job.water_plain = PackedInt32Array()
	job.water_falls = PackedInt32Array()
	return job


## Copies the cells of the chunk and its border into the job, part `i` of PREP_STEPS
## (counting down): the cells and their shapes, the lower levels and then the upper
## ones, then the cells that may show a face.
static func _prepare(job: Job, i: int) -> void:
	var w = job.w
	var x0 := job.x0 - PAD
	var z0 := job.z0 - PAD
	var x1 := job.x1 + PAD
	var z1 := job.z1 + PAD
	var half: int = w.size_y / 2
	match i:
		5:
			job.c = w.padded(false, Mat.STONE, x0, z0, x1, z1, -1, half)
		4:
			job.c.append_array(w.padded(false, Mat.STONE, x0, z0, x1, z1, half))
			_open_holes(job, job.c, Mat.AIR)
		3:
			w.refresh_shapes()
			job.sh = w.padded(true, 0, x0, z0, x1, z1, -1, half)
		2:
			w.refresh_shapes()
			job.sh.append_array(w.padded(true, 0, x0, z0, x1, z1, half))
			_open_holes(job, job.sh, 0)
		1:
			job.cands = _candidates(w, job.x0, job.z0, job.x1, job.z1)
			job.swash = Water.swash_map(w, job.x0, job.z0, job.x1, job.z1)
			_take_forms(job)
			_hole_cands(job)


## Sets the cells of `holes` within the job's padded copy `cells` (job.c, job.sh) to `to`.
static func _open_holes(job: Job, cells: PackedByteArray, to: int) -> void:
	if holes.is_empty():
		return
	var x0 := job.x0 - PAD
	var z0 := job.z0 - PAD
	for h: Vector3i in holes:
		if h.x < x0 or h.x >= job.x1 + PAD or h.z < z0 or h.z >= job.z1 + PAD or h.y < 0 or h.y >= job.w.size_y:
			continue
		var i := (h.y + 1) * job.dy + (h.z - z0) * job.dz + h.x - x0
		if i < cells.size():
			cells[i] = to


## The cells round `holes` may show a face now (job.cands, see _candidates): the four
## beside each on its level, and the ones over and under it.
static func _hole_cands(job: Job) -> void:
	if holes.is_empty():
		return
	var width := job.x1 - job.x0
	for h: Vector3i in holes:
		for o: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
				Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			var c := h + o
			if c.x < job.x0 or c.x >= job.x1 or c.z < job.z0 or c.z >= job.z1 or c.y < 0 or c.y >= job.w.size_y:
				continue
			job.cands[(c.z - job.z0) * width + c.x - job.x0] |= 1 << c.y


## Builds the next `columns` columns of cells of the chunk (a column is all levels of
## one x, z), after copying its cells over the first steps. Returns true once every
## column is built.
static func step(job: Job, columns: int) -> bool:
	while columns > 0 and job.prep > 0:
		_prepare(job, job.prep)
		job.prep -= 1
		columns -= 1
	while columns > 0 and job.z < job.z1:
		columns -= 1
		if not _column(job, job.x, job.z):
			continue
		job.ends.append_array([job.solid.verts.size(), job.solid.indices.size(), job.water.verts.size(),
			job.water.indices.size()])
		job.x += 1
		if job.x >= job.x1:
			job.x = job.x0
			job.z += 1
			if job.z >= job.z1:
				job.plain.sort()
				job.water_plain.sort()
	# Then the plain tops, PLAIN_RUNS merged quads per column (a chunk of open ground
	# has over a thousand).
	if job.part:
		return job.z >= job.z1
	while columns > 0 and job.z >= job.z1 and (job.plain_j < job.plain.size() or job.water_j < job.water_plain.size()
			or job.falls_j < job.water_falls.size()):
		if job.plain_j < job.plain.size():
			job.plain_j = _plain_rows(job.solid, job.plain, job.x0, job.z0, false, job.plain_j, PLAIN_RUNS)
		elif job.water_j < job.water_plain.size():
			job.water_j = _plain_rows(job.water, job.water_plain, job.x0, job.z0, true, job.water_j, PLAIN_RUNS)
		else:
			job.falls_j = Water.fall_faces(job.water, job.faces, job.water_falls, job.x0, job.z0, job.falls_j, PLAIN_RUNS)
		columns -= 1
	return (job.z >= job.z1 and job.plain_j >= job.plain.size() and job.water_j >= job.water_plain.size()
		and job.falls_j >= job.water_falls.size())


## Cells of a column built in one step: most columns show a few, but the ten cells of
## a tree's trunk took some 1.2 ms on a desktop (2026-10-24), ten times that on a phone.
const COLUMN_CELLS := 4


## Builds up to COLUMN_CELLS cells of column x, z that may show a face, and keeps the
## rest for the next call; true once the column is done.
static func _column(job: Job, x: int, z: int) -> bool:
	var w = job.w
	var x0 := job.x0
	var z0 := job.z0
	var x1 := job.x1
	var faces := job.faces
	var solid = job.solid
	var water = job.water
	var c := job.c
	var sh := job.sh
	var cov := job.cov
	var dx := 1
	var dz := job.dz
	var dy := job.dy
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILES)
	var nb := job.nb
	var side_offsets := job.side_offsets
	var plain := job.plain
	var water_plain := job.water_plain
	var cands := job.cands
	var forms := job.forms
	var offsets := job.offsets
	# The stone tops whose moss was picked (WorldData.turf "").
	var picked: Dictionary = w.turf.get(WorldData.chunk_key(x, z), {})
	# The built cells cracked by decay (WorldData.cracks).
	var cracked_here: Dictionary = w.cracks.get(WorldData.chunk_key(x, z), {}) if not w.cracks.is_empty() else {}
	var j := (z - z0) * (x1 - x0) + (x - x0)
	var cand := cands[j]
	var column := (z - z0 + PAD) * dz + PAD + x - x0
	var left := COLUMN_CELLS
	# Which cells of the column the generator left in place (WorldData.WILD): the faces
	# of the others are built and carry BUILT_BLUE (see mark_built).
	var home: WorldData.Chunk = w.chunk_at(x, z)
	var natural: PackedByteArray = home.natural if home != null else PackedByteArray()
	var col := WorldData.col_of(x, z)
	# The first vertex of the built cell drawn last, -1 for none.
	var built_from := -1
	while cand != 0:
		if built_from >= 0:
			mark_built(solid, built_from)
			built_from = -1
		if left == 0:
			cands[j] = cand
			return false
		left -= 1
		var bit := cand & -cand
		cand ^= bit
		var y := WorldData.level_of(bit)
		var i := (y + 1) * dy + column
		var m := c[i]
		var built := m != AIR and m != WATER and m != LEAVES and not natural.is_empty() \
				and natural[(y << 8) | col] & WorldData.WILD == 0
		if built:
			built_from = solid.colors.size()
		if m == AIR or m == LEAVES:
			if sh[i] >= 16:
				_fill_faces(solid, c, sh, cov, i, dy, dz, Vector3(x, y, z))
			elif m == AIR:
				var lips := Water.lip_fills(c, i, dy, dz)
				if lips != 0:
					Water.lip_fill(water, job.water_falls, w, c, i, dy, dz, Vector3(x, y, z), lips, x - x0, z - z0)
			continue
		# Neighbours in DIRS order: +x, -x, +y, -y, +z, -z.
		nb[0] = c[i + dx]
		nb[1] = c[i - dx]
		nb[2] = c[i + dy]
		nb[3] = c[i - dy]
		nb[4] = c[i + dz]
		nb[5] = c[i - dz]
		var base := Vector3(x, y, z)
		if Mat.lit[m] != 0 and (nb[0] == AIR or nb[1] == AIR or nb[2] == AIR or nb[3] == AIR or nb[4] == AIR or nb[5] == AIR):
			job.glows.append((base + Vector3(0.5, 1.0, 0.5)) * CELL)
			job.glow_mats.append(m)
		# The surf over land level with the sea, over its slope, or over its whole top where
		# a corner is cut (the water there is as high, water_top).
		if not job.swash.is_empty() and y == w.sea_level and m != WATER and cov[m] and not cov[nb[2]] \
				and nb[2] != WATER:
			Water.swash(water, job.swash, x1 - x0 + 2, c, sh, i, dy, dz, x - x0 + 1, z - z0 + 1, base)
		if not forms.is_empty() and forms.has(i):
			Forms.form_faces(solid, c, cov, forms, offsets, i, base, m, forms[i])
			continue
		var by_form := not forms.is_empty() and _by_form(forms, offsets, i)
		if m == WATER:
			var fills := sh[i] >> 4
			var foam := fills << 8
			for k in 4:
				if fills & (1 << k):
					foam |= _diag_shape(c, sh, cov, i, dz, k, _fill_shape(c, cov, i, dy, k)) << (16 + 2 * k)
			var murk: int = w.murk(x, y, z) if nb[2] == AIR else 0
			var sea: bool = nb[2] == AIR and w.sea(x, y, z)
			# Open water has no land beside it, so no foam.
			if cov[nb[0]] or cov[nb[1]] or cov[nb[4]] or cov[nb[5]]:
				foam |= Water.foam(c, sh, cov, i, dy, dz)
				if nb[2] == AIR:
					foam |= Water.deep_foam(c, sh, cov, i, dy, dz)
			var surf := Water.surf_here(sea, y)
			if surf:
				# The surf outlines the sea where the land beside is level with it; along a
				# wall rising out of it the water keeps its foam.
				for e in 4:
					var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
					if not (cov[c[n]] and cov[c[n + dy]]):
						foam &= ~(3 << (2 * e))
			var depth := 1
			while depth < 8 and c[i - depth * dy] == WATER:
				depth += 1
			var level := nb[2] == AIR and Water.level_bed(c, sh, cov, i, dy, dz, depth)
			if foam == 0 and level and murk == 0 and nb[0] != AIR and nb[1] != AIR and nb[4] != AIR and nb[5] != AIR:
				# The sea's plain water is told by SEA_TILE over its depth (see _plain_rows).
				water_plain.append(((y * 64 + depth + (SEA_TILE if sea else 0)) * 64 + z - z0) * 64 + x - x0)
			else:
				var corners := PackedColorArray()
				var murks := Water.murk_corners(w, c, i, dz, base) if murk > 0 else PackedFloat32Array([0, 0, 0, 0])
				if level or nb[2] != AIR:
					for k in 4:
						corners.append(Water.water_color(depth - 1.0 + water_top(y), 1.0, Water.kind(false, murks[k]), sea,
							surf))
				else:
					corners = Water.water_corners(c, sh, cov, i, dy, dz, depth, murks, sea, water_top(y), surf)
				if surf and fills != 0 and not job.swash.is_empty():
					Water.swash_fills(water, base, fills, foam, job.swash, x1 - x0 + 2, x - x0 + 1, z - z0 + 1)
				var lips := Water.lip_cuts(c, i, dy, dz) if nb[2] == AIR else 0
				Water.water_faces(water, faces, nb, base, depth, foam, corners, lips, fills)
				Water.falls(job.water_falls, c, nb, side_offsets, i, dy, dz, x - x0, z - z0, y)
			if fills != 0:
				_fill_faces(solid, c, sh, cov, i, dy, dz, base)
		elif m == Mat.LOG and Trunks.is_trunk(nb, w.trees.has(Vector2i(x, z))):
			# A tree drawn as a picture (TreeSprites) draws its trunk itself, its stump and
			# the pieces of wood lying in the woods.
			if Growth.standing_look(w, Vector2i(x, z)) < 0 and Growth.stump_look(w, Vector2i(x, z)) < 0 \
					and Growth.piece_look(w, Vector2i(x, z)) < 0:
				Trunks.trunk_faces(solid, w, x, y, z, nb, base, m)
		elif sh[i] & 15 != 0 and not cov[nb[2]]:
			var cuts := sh[i] >> 4
			OldSlopes.slope_faces(solid, faces, c, sh, nb, side_offsets, i, dy, base, m,
				float(_around_tiles(c, cov, i, dy, dz, sh)), cuts)
			if y == sea_level and Water.under_swash(job.swash, x1 - x0 + 2, x - x0 + 1, z - z0 + 1):
				pass
			elif Water.shore(c, cov, i, dy, dz):
				Water.shore_water(water, w, c, sh, i, dy, dz, base, Water.foam(c, sh, cov, i, dy, dz))
			elif Water.deep_shore(c, sh, cov, i, dy, dz):
				Water.shore_water(water, w, c, sh, i, dy, dz, base, 0, true)
			elif cuts:
				Water.cut_water(w, water, c, i, dy, base, cuts)
		elif sh[i] & 15 != 0 and sh[i] < 16:
			# A covered cell that the slope above goes on down into.
			OldSlopes.deep_faces(solid, faces, c, sh, nb, side_offsets, i, dy, base, m)
			# The ground under a cut corner of the slope above shows there (without it the
			# corner was a hole through the ground, 2026-11-18), going down with the slope.
			var exposed := sh[i + dy] >> 4 if cov[c[i + dy]] else 0
			if exposed != 0:
				var edges := _top_edges(c, cov, i, dy, dz, y == sea_level)
				var halves := _covered_halves(c, sh, cov, i, dy, dz, edges)
				var tops := []
				for k in 4:
					tops.append(_exposed_tile(c, cov, i, dz, m, k, edges, halves, false, c[i + dy]))
				OldSlopes.cut_floor(solid, c, sh, i, dy, dz, base + Vector3.UP, exposed, tops)
		else:
			var cuts := sh[i] >> 4
			# Corner shapes of the cuts, 2 bits a corner (see _diag_shapes).
			var shapes := _diag_shapes(c, sh, cov, i, dz, cuts, Mat.corner_shape[m]) if cuts != 0 else 0
			var bare: bool = m == Mat.STONE and not picked.is_empty() and picked.get(Vector3i(x, y, z), null) == ""
			# Its faces drawn one by one with the crack mark (CRACKED), never merged.
			var cracked: bool = not cracked_here.is_empty() and cracked_here.has(Vector3i(x, y, z))
			# Most tops lie under open sky amid the same flat ground: no sides, no
			# edges, no transitions.
			if cuts == 0 and not bare and not cracked and not by_form and not cov[nb[2]] and cov[nb[3]] and nb[0] == m and nb[1] == m and nb[4] == m \
					and nb[5] == m and (sh[i + dx] | sh[i - dx] | sh[i + dz] | sh[i - dz]) < 16 \
					and (sh[i + dx] | sh[i - dx] | sh[i + dz] | sh[i - dz]) & 15 == 0 \
					and cov[c[i + dx + dz]] and cov[c[i + dx - dz]] and cov[c[i - dx + dz]] and cov[c[i - dx - dz]] \
					and not cov[c[i + dy + dx]] and not cov[c[i + dy - dx]] and not cov[c[i + dy + dz]] \
					and not cov[c[i + dy - dz]]:
				plain.append(((y * 64 + m) * 64 + z - z0) * 64 + x - x0 | (PLAIN_BUILT if built else 0))
				continue
			for d in 6:
				var n := nb[d]
				# (A top or bottom looks at the cell's own slope: a covered cell a slope goes
				# on down into keeps its cube's top and bottom hidden.)
				if cov[n] and sh[i + side_offsets[d]] & 15 == 0 \
						and not (by_form and forms.has(i + offsets[d]) and not Forms.covers_side(forms[i + offsets[d]], d ^ 1)):
					# The ground under a thin trunk, and a bank beside its foot, still show around it.
					var o: Vector3i = DIRS[d]
					if not (n == Mat.LOG and d != FACE_BOTTOM and Trunks.trunk_at(w, x + o.x, y + o.y, z + o.z)):
						continue
				var tile := m * 3 + (0 if d == FACE_TOP else (2 if d == FACE_BOTTOM else 1))
				var edges := 0
				var flag := 0
				var around := no_tiles
				var color := CRACKED if cracked else white
				if d == FACE_TOP:
					edges = _top_edges(c, cov, i, dy, dz, y == sea_level)
					var halves := _covered_halves(c, sh, cov, i, dy, dz, edges)
					var a := _around_tiles(c, cov, i, dy, dz, sh)
					if cuts != 0 or halves != 0:
						_top_pieces(solid, base, m, cuts, edges, halves, float(a), shapes)
						continue
					if edges == 0 and not bare and not cracked and _plain_around(a, m):
						plain.append(((y * 64 + m) * 64 + z - z0) * 64 + x - x0 | (PLAIN_BUILT if built else 0))
						continue
					around = float(a)
					if bare:
						# A stone top whose moss was picked (see Grass.stone_moss): drawn bare
						# but for a ragged edge of moss along the tops beside not picked.
						color = Color(1, 1, 1, _picked_around(w, x, y, z) / 16.0)
				elif d != FACE_BOTTOM:
					# Every side shows from some turn of the camera. Outlines where nothing
					# nearer or level is beside or below; W and E are the ends of the face's
					# texture row (see face_uv).
					var f := side_offsets[d]
					var s := dz if d < 2 else dx
					if not cov[c[i + dy]]:
						flag = OPEN_TOP
					if not cov[c[i - dy + f]] and not cov[c[i - dy]]:
						edges |= DARK << EDGE_S
					if not cov[c[i - s]] and not cov[c[i - s + f]] and not cov[c[i - s + f + dy]]:
						edges |= DARK << EDGE_W
					if not cov[c[i + s]] and not cov[c[i + s + f]] and not cov[c[i + s + f + dy]]:
						edges |= DARK << EDGE_E
					around = float(_side_tiles(c, cov, i, dy, f, s))
				if cuts != 0:
					_cut_side(solid, faces, d, base, cuts, white, Vector2(pack(tile, edges, flag), around), shapes)
				else:
					_add_cell_face(solid, d, base, color, Vector2(pack(tile, edges, flag), around))
			if cuts != 0:
				_cut_walls(w, solid, water, c, cov, i, dy, base, m, cuts, shapes, sh[i - dy] & 15 != 0 and cov[c[i - dy]])
			# The ground under a cut corner of the cell above shows there.
			var exposed := sh[i + dy] >> 4 & ~cuts if cov[c[i + dy]] else 0
			if exposed != 0:
				var edges := _top_edges(c, cov, i, dy, dz, y == sea_level)
				_exposed_tops(solid, c, cov, i, dz, base, m, exposed, edges,
					_covered_halves(c, sh, cov, i, dy, dz, edges), sh[i + dy] & 15 == 0, c[i + dy])
	if built_from >= 0:
		mark_built(solid, built_from)
	return true


## Whether a neighbour of padded cell `i` is a built block of a form (see Forms).
static func _by_form(forms: Dictionary, offsets: PackedInt32Array, i: int) -> bool:
	for d in 6:
		if forms.has(i + offsets[d]):
			return true
	return false


## Takes the forms of the built blocks in the padded grid of the job (WorldData.forms)
## and makes them and the cells beside them candidates for faces.
static func _take_forms(job: Job) -> void:
	var w = job.w
	if w.forms.is_empty():
		return
	var x0 := job.x0 - PAD
	var z0 := job.z0 - PAD
	var x1 := job.x1 + PAD
	var z1 := job.z1 + PAD
	var keys := {}
	for x in [x0, job.x0, x1 - 1]:
		for z in [z0, job.z0, z1 - 1]:
			keys[WorldData.chunk_key(x, z)] = true
	var sx := job.x1 - job.x0
	for key: Vector2i in keys:
		for cell: Vector3i in w.form_chunks.get(key, {}):
			if cell.x < x0 or cell.x >= x1 or cell.z < z0 or cell.z >= z1:
				continue
			job.forms[(cell.y + 1) * job.dy + (cell.z - z0) * job.dz + cell.x - x0] = w.forms[cell]
			for o: Vector3i in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
					Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var n := cell + o
				if n.x < job.x0 or n.x >= job.x1 or n.z < job.z0 or n.z >= job.z1 or n.y < 0 or n.y >= w.size_y:
					continue
				job.cands[(n.z - job.z0) * sx + n.x - job.x0] |= 1 << n.y


## Making the meshes takes longer than a column, so ChunkStreamer makes them one a
## frame: part 0 is the solid mesh, part 1 the water.
const FINISH_PARTS := 2


## The job of a whole chunk built before (`old`, its columns and plain tops kept) with
## the columns of `part` (start_rect with `part`, its columns built since the cells
## changed) put in place of its own: what building the whole chunk again would make,
## in the same order, for a few columns' work. The columns are copied over in runs,
## their indices moved by where the run lands; the plain tops are merged again.
static func patch(old: Job, part: Job) -> Job:
	var job := Job.new()
	job.w = old.w
	job.x0 = old.x0
	job.z0 = old.z0
	job.x1 = old.x1
	job.z1 = old.z1
	job.x = old.x0
	job.z = old.z1
	job.prep = 0
	job.solid = MeshBuffers.new()
	job.water = MeshBuffers.new()
	job.ends.resize(old.ends.size())
	var sx := old.x1 - old.x0
	var px := part.x1 - part.x0
	var n := old.ends.size() / 4
	# Runs of columns that lie one after another in the job they come from: [from part,
	# first column there, last column there, first column in the chunk].
	var runs := []
	var j := 0
	while j < n:
		var x := old.x0 + j % sx
		var z := old.z0 + j / sx
		var inside := x >= part.x0 and x < part.x1 and z >= part.z0 and z < part.z1
		var at := (z - part.z0) * px + x - part.x0 if inside else j
		if not runs.is_empty() and runs[-1][0] == inside and runs[-1][2] == at - 1:
			runs[-1][2] = at
		else:
			runs.append([inside, at, at, j])
		j += 1
	for k in [0, 2]:
		var out = job.solid if k == 0 else job.water
		for run: Array in runs:
			var from: Job = part if run[0] else old
			var buf = from.solid if k == 0 else from.water
			var e := from.ends
			var a: int = run[1]
			var b: int = run[2]
			var va := e[(a - 1) * 4 + k] if a > 0 else 0
			var ia := e[(a - 1) * 4 + k + 1] if a > 0 else 0
			var vb := e[b * 4 + k]
			var ib := e[b * 4 + k + 1]
			var shift: int = out.verts.size() - va
			var ishift: int = out.indices.size() - ia
			if vb > va:
				out.verts.append_array(buf.verts.slice(va, vb))
				out.normals.append_array(buf.normals.slice(va, vb))
				out.uvs.append_array(buf.uvs.slice(va, vb))
				out.uv2s.append_array(buf.uv2s.slice(va, vb))
				out.colors.append_array(buf.colors.slice(va, vb))
				var idx: PackedInt32Array = buf.indices.slice(ia, ib)
				if shift != 0:
					for q in idx.size():
						idx[q] += shift
				out.indices.append_array(idx)
			for c in range(a, b + 1):
				var to: int = run[3] + c - a
				job.ends[to * 4 + k] = e[c * 4 + k] + shift
				job.ends[to * 4 + k + 1] = e[c * 4 + k + 1] + ishift
	job.plain = _merged_keys(old.plain, part.plain, old, part)
	job.water_plain = _merged_keys(old.water_plain, part.water_plain, old, part)
	_plain_rows(job.solid, job.plain, job.x0, job.z0)
	_plain_rows(job.water, job.water_plain, job.x0, job.z0, true)
	job.water_falls = _merged_keys(old.water_falls, part.water_falls, old, part)
	Water.fall_faces(job.water, face_table(), job.water_falls, job.x0, job.z0)
	job.plain_j = job.plain.size()
	job.water_j = job.water_plain.size()
	job.falls_j = job.water_falls.size()
	# The lit cells of the old columns outside the part, then the part's.
	for g in old.glows.size():
		var p := old.glows[g] / CELL
		if p.x < part.x0 or p.x >= part.x1 or p.z < part.z0 or p.z >= part.z1:
			job.glows.append(old.glows[g])
			job.glow_mats.append(old.glow_mats[g])
	job.glows.append_array(part.glows)
	job.glow_mats.append_array(part.glow_mats)
	return job


## The plain tops (or plain water) of `old` outside the columns of `part`, with those
## of `part`, as keys of `old`'s corner, sorted (see _plain_rows).
static func _merged_keys(keys: PackedInt32Array, more: PackedInt32Array, old: Job, part: Job) -> PackedInt32Array:
	var out := PackedInt32Array()
	var lx0 := part.x0 - old.x0
	var lz0 := part.z0 - old.z0
	var lx1 := part.x1 - old.x0
	var lz1 := part.z1 - old.z0
	for key in keys:
		var lx := key & 63
		var lz := key >> 6 & 63
		if lx < lx0 or lx >= lx1 or lz < lz0 or lz >= lz1:
			out.append(key)
	for key in more:
		out.append((key & ~4095) | ((key >> 6 & 63) + lz0) << 6 | ((key & 63) + lx0))
	out.sort()
	return out


## How many columns around a changed `cell` the meshes and plants may change: three
## where ground is near it (shapes of ground follow their neighbours, slopes the shapes
## beside them), one for a cell up in the air (leaves and logs of a crown): its faces
## and the edges and tops beside it. But a column that lost its last leaf (a felled
## crown) or got its first one changes the plants of the woods WOODS_EDGE columns round
## it (Grass._near_crown), also in the chunk beside: Foliage.part_columns takes them
## from a rect that reaches into the chunk.
static func reach(w, cell: Vector3i) -> int:
	for dy in range(-1, 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var m: int = w.get_cell(cell.x + dx, cell.y + dy, cell.z + dz)
				if m != AIR and m != WATER and m != LEAVES and m != Mat.LOG:
					return 3
	if (w.leaf_col(cell.x, cell.z) & ~(1 << cell.y)) == 0:
		return Grass.WOODS_EDGE
	return 1


## Lets go of what a finished job no longer needs once its meshes are made, keeping
## what `patch` takes from it.
static func keep(job: Job) -> void:
	job.c = PackedByteArray()
	job.sh = PackedByteArray()
	job.cands = PackedInt64Array()
	job.forms = {}


## The meshes once every column is built: [solid, water], null where empty.
static func finish(job: Job) -> Array:
	var out := []
	for i in FINISH_PARTS:
		out.append(finish_part(job, i))
	return out


static func finish_part(job: Job, i: int) -> ArrayMesh:
	var b = job.solid if i == 0 else job.water
	return null if b.is_empty() else b.to_mesh(CELL)


## Cells of each column of x0..x1, z0..z1 (row by row) that may show a face, as bit
## masks of levels: those that hide what is behind them next to an open or sloping
## cell, under a cut corner or a trunk, beside a log (a trunk's foot against a bank); water next to air; open cells with filled
## corners. Where no chunk is kept beside, the cells count as next to open air.
static func _candidates(w, x0: int, z0: int, x1: int, z1: int) -> PackedInt64Array:
	var all: int = w.all_bits
	var top_bit: int = w.top_bit
	# The masks of the columns and a ring of one around them.
	var cols: Dictionary = w.column_masks(x0 - 1, z0 - 1, x1 + 1, z1 + 1)
	var sx := x1 - x0 + 2
	var air_cols: PackedInt64Array = cols.air
	var water_cols: PackedInt64Array = cols.water
	var leaf_cols: PackedInt64Array = cols.leaf
	var sloped_cols: PackedInt64Array = cols.sloped
	var corner_cols: PackedInt64Array = cols.corner
	var log_cols: PackedInt64Array = cols.logs
	var out := PackedInt64Array()
	out.resize((x1 - x0) * (z1 - z0))
	var j := 0
	for z in range(z0, z1):
		for x in range(x0, x1):
			var col := (z - z0 + 1) * sx + x - x0 + 1
			var air := air_cols[col]
			var water := water_cols[col]
			var open := air | water | leaf_cols[col]
			var sloped := sloped_cols[col]
			var corners := corner_cols[col]
			var cover := ~open & all
			var near := (open >> 1) | top_bit | (open << 1) & all | sloped | (sloped >> 1) | (sloped << 1) & all \
				| (corners & cover) >> 1 | log_cols[col] >> 1 \
				| log_cols[col - 1] | log_cols[col + 1] | log_cols[col - sx] | log_cols[col + sx]
			var air_near := (air >> 1) | top_bit
			var a := air_cols[col - 1] | air_cols[col + 1] | air_cols[col - sx] | air_cols[col + sx]
			near |= a | water_cols[col - 1] | water_cols[col + 1] | water_cols[col - sx] | water_cols[col + sx] \
				| leaf_cols[col - 1] | leaf_cols[col + 1] | leaf_cols[col - sx] | leaf_cols[col + sx] \
				| sloped_cols[col - 1] | sloped_cols[col + 1] | sloped_cols[col - sx] | sloped_cols[col + sx]
			air_near |= a
			# Air beside water on its level: the lip of a step, whose corners water may fill
			# (WaterMesher.lip_fills).
			var wet_near := water_cols[col - 1] | water_cols[col + 1] | water_cols[col - sx] | water_cols[col + sx]
			out[j] = cover & near | water & air_near | corners & open | air & wet_near
			j += 1
	return out


## Top materials of the neighbours N, S, W, E of padded cell `i`, packed for UV2.y
## (material transitions, see world.gdshader): the top at this level, or where a
## slope goes on from it a level up or down (`sh` given), the slope's or the one it goes
## down to, so two materials meeting on a slope spill over each other's edges in a
## ragged line as on flat ground, not straight along the cells.
static func _around_tiles(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int,
		sh := PackedByteArray()) -> int:
	if sh.is_empty():
		var tn := c[i - dz] if cov[c[i - dz]] and not cov[c[i - dz + dy]] else NO_MATERIAL
		var ts := c[i + dz] if cov[c[i + dz]] and not cov[c[i + dz + dy]] else NO_MATERIAL
		var tw := c[i - 1] if cov[c[i - 1]] and not cov[c[i - 1 + dy]] else NO_MATERIAL
		var te := c[i + 1] if cov[c[i + 1]] and not cov[c[i + 1 + dy]] else NO_MATERIAL
		return tn | ts << 6 | tw << 12 | te << 18
	var sloped := sh[i] & 15 != 0
	return _tile_beside(c, cov, sh, i - dz, dy, sloped) | _tile_beside(c, cov, sh, i + dz, dy, sloped) << 6 \
		| _tile_beside(c, cov, sh, i - 1, dy, sloped) << 12 | _tile_beside(c, cov, sh, i + 1, dy, sloped) << 18


## The top material beside a top at padded cell `j` (see _around_tiles): its own when open
## above, the slope's over it, or for a `sloped` top the one under it it goes down to.
static func _tile_beside(c: PackedByteArray, cov: PackedByteArray, sh: PackedByteArray, j: int, dy: int,
		sloped: bool) -> int:
	if cov[c[j]]:
		if not cov[c[j + dy]]:
			return c[j]
		if j + 2 * dy < c.size() and sh[j + dy] & 15 != 0 and not cov[c[j + 2 * dy]]:
			return c[j + dy]
	elif sloped and j - dy >= 0 and cov[c[j - dy]]:
		return c[j - dy]
	return NO_MATERIAL


## True when no neighbour's top material differs from material `m`, so the top has no
## transitions.
static func _plain_around(a: int, m: int) -> bool:
	for e in 4:
		var t := a >> (6 * e) & 63
		if t != NO_MATERIAL and t != m:
			return false
	return true


## The vertex colour's blue of the faces of a built cell (one the generator did not leave in
## place, WorldData.WILD): the build mode's cut of the floors hides them above it and keeps
## natural ground (world.gdshader, ChunkStreamer.build_cut). The shader takes the blue as
## the red for its colour. The faces of the ground are white or grey, a trunk's a little
## warm: their blue is never this low.
const BUILT_BLUE := 0.0
const BUILT_WHITE := Color(1, 1, BUILT_BLUE)
## A plain top's key (see _plain_rows) of a built cell: built and natural tops are never
## merged into one quad. Levels are the bits under it.
const PLAIN_BUILT := 1 << 29
const PLAIN_LEVELS := (1 << 11) - 1


## Marks the colours of `buf` from vertex `from` on as a built cell's (BUILT_BLUE).
static func mark_built(buf, from: int) -> void:
	buf.set_blue(from, BUILT_BLUE)


## Draws the plain tops (sorted keys from build_chunk: level, top material or water depth, z
## and x in the chunk) as one quad per row of neighbours with the same tile, up to
## `runs` quads from key `from` on; returns the key to go on from. The shaders texture
## tops by their world position, so a long quad looks the same as the cells it covers.
static func _plain_rows(buf, keys: PackedInt32Array, x0: int, z0: int, water := false, from := 0,
		runs := 1 << 30) -> int:
	var corners: Array = face_table()[FACE_TOP].corners
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILES)
	var n := keys.size()
	var j := from
	while j < n and runs > 0:
		runs -= 1
		var first := keys[j]
		var end := j + 1
		while end < n and keys[end] == first + (end - j) and (first & 63) + (end - j) < 64:
			end += 1
		var length := end - j
		var lx := first & 63
		var lz := first >> 6 & 63
		# The top's material, or the water's depth (plus SEA_TILE on the sea).
		var tile := first >> 12 & 63
		var sea := water and tile >= SEA_TILE
		if sea:
			tile -= SEA_TILE
		var y := first >> 18 & PLAIN_LEVELS
		var height := water_top(y) if water else 1.0
		var base := Vector3(x0 + lx, y, z0 + lz)
		var pts := []
		var uvs := []
		for v: Vector3 in corners:
			pts.append(base + Vector3(v.x * length, v.y * height, v.z))
			uvs.append(Vector2(v.x * length, v.z))
		buf.quad(pts, Vector3.UP, uvs, Water.water_color(tile - 1.0 + height, 1.0, 0.0, sea) if water
			else (BUILT_WHITE if first & PLAIN_BUILT else white),
			Vector2(0.0, tile) if water else Vector2(pack(tile * 3, 0, 0), no_tiles))
		j = end
	return j


## Edge codes of the top of padded cell `i`: a wall rising from an edge (contact
## shadow) or open ground lower beside it (DARK: the shader draws a light rim where the
## wall below faces the camera and an outline where it faces away, see world.gdshader).
## `sea`: the top is at the sea's level, where the water beside stands flush with it
## (water_top), so no rim shows toward it: the sea's foam and surf outline it there.
static func _top_edges(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int, sea := false) -> int:
	var edges := 0
	if cov[c[i + dy - dz]]:
		edges |= CONTACT << EDGE_N
	elif not cov[c[i - dz]] and not (sea and c[i - dz] == WATER and c[i - dz + dy] == AIR):
		edges |= DARK << EDGE_N
	if cov[c[i + dy + dz]]:
		edges |= CONTACT << EDGE_S
	elif not cov[c[i + dz]] and not (sea and c[i + dz] == WATER and c[i + dz + dy] == AIR):
		edges |= DARK << EDGE_S
	if cov[c[i + dy - 1]]:
		edges |= CONTACT << EDGE_W
	elif not cov[c[i - 1]] and not (sea and c[i - 1] == WATER and c[i - 1 + dy] == AIR):
		edges |= DARK << EDGE_W
	if cov[c[i + dy + 1]]:
		edges |= CONTACT << EDGE_E
	elif not cov[c[i + 1]] and not (sea and c[i + 1] == WATER and c[i + 1 + dy] == AIR):
		edges |= DARK << EDGE_E
	return edges


## Half edges (bits, see HALF_CORNER) of the top of padded cell `i` where the ground
## goes on at the same height, so their edge code must not show: a filled corner of the
## neighbour, or a cut corner of the wall above the neighbour instead of a wall rising.
static func _covered_halves(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int,
		edges: int) -> int:
	# Mostly there are no corners around at all.
	if sh[i - dz] | sh[i + dz] | sh[i - 1] | sh[i + 1] | sh[i + dy - dz] | sh[i + dy + dz] | sh[i + dy - 1] \
			| sh[i + dy + 1] < 16:
		return 0
	var halves := 0
	for h in 8:
		var e := h >> 1
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
		# A neighbour's cut or fill (half a cell along each side) at the corner by this
		# half covers it.
		var bit: int = 1 << HALF_CORNER[h]
		# A fill of the open neighbour, or a cut of the ground above it.
		if not cov[c[n]] and sh[n] >> 4 & bit \
				or edges >> (2 * e) & 3 == CONTACT and cov[c[n + dy]] and sh[n + dy] >> 4 & bit:
			halves |= 1 << h
	return halves


## Edge codes of quarter `q` of a top: those of its two outer half edges that show.
static func _quarter_edges(q: int, edges: int, halves: int) -> int:
	var out := 0
	for h: int in QUARTER_HALVES[q]:
		if halves & (1 << h) == 0:
			out |= edges & (3 << (2 * (h >> 1)))
	return out


## The top of a cell drawn in quarters: cut corners leave their diagonal, and half edges
## where the ground goes on lose their edge code.
static func _top_pieces(buf, base: Vector3, m: int, cuts: int, edges: int, halves: int, around: float,
		shapes := 0) -> void:
	var white := Color(1, 1, 1)
	for q in 4:
		var e := _quarter_edges(q, edges, halves)
		var cut := cuts & (1 << q) != 0
		var shape := shapes >> (2 * q) & 3
		var packed := Vector2(pack(m * 3, e, _diag(q, false, DARK, shape) if cut else 0), around)
		_piece(buf, base, 1.0, q, OLD_CUT if cut else QUARTER, Vector3.UP, white, packed, shape)


## Side `d` of a cell with cut corners: the half of a side by a cut corner is gone with
## the corner's triangle; the bottom in pieces.
static func _cut_side(buf, faces: Array, d: int, base: Vector3, cuts: int, color: Color, packed: Vector2,
		shapes := 0) -> void:
	if d == FACE_BOTTOM:
		for q in 4:
			_piece(buf, base, 0.0, q, quarter_kind(cuts, q), Vector3.DOWN, color, packed, shapes >> (2 * q) & 3)
		return
	var ks: Array = SIDE_CORNERS[d]
	# Halves of the side next to an uncut corner.
	for j in 2:
		if cuts & (1 << ks[j]) == 0:
			var along_z := d < 2
			var size := Vector3(1.0, 1.0, 0.5) if along_z else Vector3(0.5, 1.0, 1.0)
			var offset := Vector3(0.0, 0.0, 0.5 * j) if along_z else Vector3(0.5 * j, 0.0, 0.0)
			_add(buf, faces[d], d, base, size, offset, color, packed)


## Diagonal walls of the cut corners of padded cell `i`, and water standing in them
## where the cell is beside water.
static func _cut_walls(w, buf, water, c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, base: Vector3,
		m: int, cuts: int, shapes: int, on_slope := false) -> void:
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILES)
	# Over a slope going on down under the cut (WorldData._update_deep) the wall reaches a
	# little into the ground below, so no crack shows between it and the slope.
	var skirt := CUT_SKIRT if on_slope else 0.0
	for k in 4:
		if cuts & (1 << k) == 0:
			continue
		var edges := 0 if cov[c[i - dy]] else DARK << EDGE_S
		var flag := SLOPE | (0 if cov[c[i + dy]] else OPEN_TOP)
		_diag_wall(buf, base - Vector3(0.0, skirt, 0.0), k, true, white, Vector2(pack(m * 3 + 1, edges, flag), no_tiles),
			shapes >> (2 * k) & 3)
	Water.cut_water(w, water, c, i, dy, base, cuts, shapes)


## Ground filling the corners of open padded cell `i`: a diagonal wall, and its top
## where nothing lies on it.
static func _fill_faces(buf, c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int,
		dz: int, base: Vector3) -> void:
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILES)
	var fills := sh[i] >> 4
	for k in 4:
		if fills & (1 << k) == 0:
			continue
		var o: Vector2i = CORNER_DIRS[k]
		var mf := c[i + o.x]
		var open_top: bool = not cov[c[i + dy]] and sh[i + dy] >> 4 & (1 << k) == 0
		var shape := _diag_shape(c, sh, cov, i, dz, k, _fill_shape(c, cov, i, dy, k))
		_diag_wall(buf, base, k, false, white, Vector2(pack(mf * 3 + 1, 0, SLOPE | (OPEN_TOP if open_top else 0)), no_tiles),
			shape)
		# The top continues the ground around it: under a slope beside, the slope's.
		if cov[c[i + o.x + dy]]:
			mf = c[i + o.x + dy]
		if open_top:
			# A wall rising beside the fill shades it; ground at the same height goes on.
			var edges := 0
			if cov[c[i + dy + o.x]]:
				edges |= CONTACT << (EDGE_W if o.x < 0 else EDGE_E)
			if o.y < 0 and cov[c[i + dy - dz]]:
				edges |= CONTACT << EDGE_N
			if o.y > 0 and cov[c[i + dy + dz]]:
				edges |= CONTACT << EDGE_S
			# Open across its diagonal: a rim or an outline by the view.
			var flag := _diag(k, true, DARK, shape)
			_piece(buf, base, 1.0, k, CORNER, Vector3.UP, white, Vector2(pack(mf * 3, edges, flag), no_tiles), shape)


## Corner shape `shape` of the cut (ground cell) or fill (open cell) at
## corner k of padded cell `i`, or 0 (straight) where the diagonal goes on into a cell
## beside it: a cut beside a fill, a fill beside a cut. A diagonal wall so runs straight
## from cell to cell instead of bulging at each cut and sinking at each fill; the
## material's rounding stays where the outline turns (the ends of a wall).
static func _diag_shape(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dz: int, k: int,
		shape: int) -> int:
	if shape == 0:
		return 0
	var bit := 16 << ((k + 2) & 3)
	var o: Vector2i = CORNER_DIRS[k]
	var x := i + o.x
	var z := i + o.y * dz
	if sh[x] & bit and cov[c[x]] != cov[c[i]] or sh[z] & bit and cov[c[z]] != cov[c[i]]:
		return 0
	return shape


## The corner shapes (see _diag_shape) of the corners `corners` of padded cell `i` of
## corner shape `shape`, 2 bits a corner (NW lowest).
static func _diag_shapes(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dz: int,
		corners: int, shape: int) -> int:
	var out := 0
	for k in 4:
		if corners & (1 << k):
			out |= _diag_shape(c, sh, cov, i, dz, k, shape) << (2 * k)
	return out


## Corner shape of the ground filling corner k of open padded cell `i`: that of the
## material its top is drawn with (see _fill_faces), which the shader rounds its edge by.
static func _fill_shape(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, k: int) -> int:
	var o: Vector2i = CORNER_DIRS[k]
	var mf := c[i + o.x + dy] if cov[c[i + o.x + dy]] else c[i + o.x]
	return Mat.corner_shape[mf]


## Tops of padded cell `i` under the cut corners of the cell above (of material `over`):
## the ground beside goes on into them, and a wall above (not a slope) shades their
## diagonal.
static func _exposed_tops(buf, c: PackedByteArray, cov: PackedByteArray, i: int, dz: int, base: Vector3, m: int,
		exposed: int, edges: int, halves: int, under_wall: bool, over: int) -> void:
	var white := Color(1, 1, 1)
	for k in 4:
		if exposed & (1 << k) != 0:
			_piece(buf, base, 1.0, k, CORNER, Vector3.UP, white,
				_exposed_tile(c, cov, i, dz, m, k, edges, halves, under_wall, over))


## The packed tile of the top of padded cell `i` under cut corner k of the cell above
## (see _exposed_tops).
static func _exposed_tile(c: PackedByteArray, cov: PackedByteArray, i: int, dz: int, m: int, k: int, edges: int,
		halves: int, under_wall: bool, over: int) -> Vector2:
	var o: Vector2i = CORNER_DIRS[k]
	var me := c[i + o.x]
	if not cov[me]:
		me = c[i + o.y * dz]
	if not cov[me]:
		me = m
	# Under a slope the corner lies at its foot: the slope's ground goes on into it
	# when it grows over the ground beside (grass over sand), or a triangle of sand
	# shows amid the grass.
	if not under_wall and Mat.shader_bits[over] & Mat.PRIORITY_MASK > Mat.shader_bits[me] & Mat.PRIORITY_MASK:
		me = over
	var flag := _diag(k, true, CONTACT if under_wall else 0)
	return Vector2(pack(me * 3, _quarter_edges(k, edges, halves), flag), float(NO_TILES))


## The colour of the caps: dark, a cross-section (world.gdshader). The blueprint's ghost
## blocks have white ones, their tops at the cut (PlanBlocks).
const CAP_SHADE := Color(0.4, 0.4, 0.4)
## How far under the cut the caps lie, in cells: a slope going down beside a cap meets
## it at its edge, and a cap at the very height pokes through the slope there in dark
## lines a pixel wide, along a diagonal corner most of all.
const CAP_SINK := 0.01


## Dark tops of solid cells on `level` that are covered by solid cells above:
## what you see in the cut when looking into a mountain. Cut and deep corners stay open, and
## fills sliced by the cut show as dark triangles. Rows of whole tops of the same
## material are merged. Covers the cells x0..x0+size, z0..z0+size (a chunk from the
## origin by default), so the game can rebuild the cap chunk by chunk. The caps sit
## CAP_SINK under the cells' tops. `built`: only under built cells (not WorldData.WILD), the
## build mode's cut of the floors, which leaves natural ground whole, and the natural ground
## that built cells above the cut covered (_uncovered); `shade` their colour.
static func build_cap(w, level: int, x0 := 0, z0 := 0, size := WorldData.CHUNK, built := false,
		shade := CAP_SHADE) -> ArrayMesh:
	if level < 0 or level >= w.size_y - 1:
		return null
	w.refresh_shapes()
	sea_level = w.sea_level
	var buf := MeshBuffers.new()
	var x1: int = x0 + size
	var z1: int = z0 + size
	var layer := WorldData.LAYER
	var row: int = level * layer
	var bit := 1 << level
	var both := bit | bit << 1
	var dark := shade
	var no_tiles := float(NO_TILES)
	var corners: Array = face_table()[FACE_TOP].corners
	var cells := PackedByteArray()
	var shapes := PackedByteArray()
	for z in range(z0, z1):
		# A run of whole tops waiting to be drawn: first x and tile (-1 for none).
		var run_x := 0
		var run_tile := -1
		for x in range(x0, x1 + 1):
			var tile := -1
			var c: WorldData.Chunk = w.chunk_at(x, z) if x < x1 else null
			var i := 0
			var open := 0
			if c != null:
				var col := WorldData.col_of(x, z)
				i = row + col
				cells = c.cells
				shapes = c.shapes
				open = c.air[col] | c.water[col] | c.leaf[col]
				if open & both == 0 and (shapes[i] | shapes[i + layer]) < 16 and shapes[i] & 15 == 0 \
						and not (built and c.natural[i + layer] & WorldData.WILD != 0):
					tile = cells[i] * 3
			# (A run is marked by its tile: x may be negative.)
			if tile != run_tile and run_tile >= 0:
				var base := Vector3(run_x, level - CAP_SINK, z)
				var pts := []
				var uvs := []
				for v: Vector3 in corners:
					pts.append(base + Vector3(v.x * (x - run_x), v.y, v.z))
					uvs.append(Vector2(v.x * (x - run_x), v.z))
				buf.quad(pts, Vector3.UP, uvs, dark, Vector2(pack(run_tile, 0, 0), no_tiles))
				run_tile = -1
			if tile >= 0:
				if run_tile < 0:
					run_x = x
					run_tile = tile
				continue
			run_tile = -1
			# Built cells are whole cubes: their cuts and fills are natural ground's.
			if c == null or built:
				continue
			var base := Vector3(x, level - CAP_SINK, z)
			var packed := Vector2(pack(cells[i] * 3, 0, 0), no_tiles)
			if open & both == 0:
				var cuts: int = (shapes[i] | shapes[i + layer]) >> 4
				# A sloping top under the cap's height: no cap, or it shows over the
				# slope as dark triangles.
				if shapes[i] & 15 != 0:
					continue
				for q in 4:
					_piece(buf, base, 1.0, q, quarter_kind(cuts, q), Vector3.UP, dark, packed,
						_cap_shape(w, x, level, z, q, Mat.corner_shape[cells[i]]) if cuts & (1 << q) else 0)
			elif open & bit and shapes[i] >= 16 and cells[i] != LEAVES:
				var fills: int = shapes[i] >> 4
				if open & bit << 1:
					# Open above: only where the same corner is filled there too.
					fills &= shapes[i + layer] >> 4 if cells[i + layer] != LEAVES else 0
				for k in 4:
					if fills & (1 << k):
						var o: Vector2i = CORNER_DIRS[k]
						var mf: int = w.get_cell(x + o.x, level, z)
						_piece(buf, base, 1.0, k, CORNER, Vector3.UP, dark, Vector2(pack(mf * 3, 0, 0), no_tiles),
							_cap_shape(w, x, level, z, k, Mat.corner_shape[mf]))
	if built:
		_uncovered(buf, w, level, x0, z0, size, dark)
	return null if buf.is_empty() else buf.to_mesh(CELL)


## The sides of a cell as DIRS: east, west, south, north.
const SIDE_DIRS := [0, 1, 4, 5]


## The faces of natural ground that built cells left out by the build mode's cut of the
## floors at `level` uncover, dark as the caps (the user's ask, 2026-11-27: no hole where a
## building stood): the tops of natural cells over the cut under such a built cell, and
## their sides toward one beside them. The mesher leaves out a face between two solid
## cells, so without these the ground under a floor laid on it or in it showed the sky.
## Whole natural cubes only, CAP_SINK inside them; the cells x0..x0+size, z0..z0+size.
static func _uncovered(buf: MeshBuffers, w, level: int, x0: int, z0: int, size: int, shade: Color) -> void:
	# The built cells over the cut by column, of the chunk and a ring of columns round it.
	var over: int = w.all_bits & ~((1 << (level + 1)) - 1)
	var span := size + 2
	var gone := PackedInt64Array()
	gone.resize(span * span)
	var any := false
	for dz in span:
		for dx in span:
			var c: WorldData.Chunk = w.chunk_at(x0 - 1 + dx, z0 - 1 + dz)
			if c != null:
				var col := WorldData.col_of(x0 - 1 + dx, z0 - 1 + dz)
				var built: int = ~(c.air[col] | c.water[col] | c.leaf[col] | c.wild[col]) & over
				gone[dz * span + dx] = built
				any = any or built != 0
	if not any:
		return
	var faces: Array = face_table()
	var no_tiles := float(NO_TILES)
	# The column beside, as SIDE_DIRS; the fifth way is the top.
	var steps := [1, -1, span, -span]
	for z in range(z0, z0 + size):
		for x in range(x0, x0 + size):
			var at := (z - z0 + 1) * span + x - x0 + 1
			var c: WorldData.Chunk = w.chunk_at(x, z)
			if c == null:
				continue
			var col := WorldData.col_of(x, z)
			# Trunks are drawn as trunks (TrunkMesher), not cubes.
			var ground: int = ~(c.air[col] | c.water[col] | c.leaf[col] | c.logs[col]) & c.wild[col] & over
			if ground == 0:
				continue
			for k in 5:
				var y := level + 1
				var open: int = (ground & (gone[at] >> 1 if k == 4 else gone[at + steps[k]])) >> y
				while open != 0:
					var i := y * WorldData.LAYER + col
					if open & 1 and c.shapes[i] == 0:
						var tile: int = c.cells[i] * 3
						if k == 4:
							_add(buf, faces[FACE_TOP], FACE_TOP, Vector3(x, y - CAP_SINK, z), Vector3.ONE,
								Vector3.ZERO, shade, Vector2(pack(tile, 0, 0), no_tiles))
						else:
							var d: int = SIDE_DIRS[k]
							var n: Vector3 = faces[d].normal
							_add(buf, faces[d], d, Vector3(x, y, z) - n * CAP_SINK, Vector3.ONE, Vector3.ZERO,
								shade, Vector2(pack(tile + 1, 0, 0), no_tiles))
					open >>= 1
					y += 1


## The corner shape of a cap's cut or filled corner k at (x, level, z) as the cells are
## drawn (see _diag_shape): straight where the cell beside on this level or the next has
## the corner that goes on with the diagonal.
static func _cap_shape(w, x: int, level: int, z: int, k: int, shape: int) -> int:
	if shape == 0:
		return 0
	var bit := 16 << ((k + 2) & 3)
	var o: Vector2i = CORNER_DIRS[k]
	for y in [level, level + 1]:
		if w._shape(x + o.x, y, z) & bit or w._shape(x, y, z + o.y) & bit:
			return 0
	return shape


## Which of the stone tops beside (x, y, z) had their moss picked too: bits N, S, W, E
## (1, 2, 4, 8), for the ragged edge of the moss left along the others (world.gdshader).
static func _picked_around(w, x: int, y: int, z: int) -> int:
	var out := 0
	var k := 0
	for o: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nx := x + o.x
		var nz := z + o.y
		if w.turf.get(WorldData.chunk_key(nx, nz), {}).get(Vector3i(nx, y, nz), null) == "":
			out |= 1 << k
		k += 1
	return out


## Adds the whole face `d` of the cell at `base`.
static func _add_cell_face(buf, d: int, base: Vector3, color: Color, packed: Vector2) -> void:
	if _cell_faces.is_empty():
		var faces := face_table()
		for k in 6:
			var uvs := []
			for v in faces[k].corners:
				uvs.append(face_uv(k, v))
			_cell_faces.append([faces[k].corners, uvs, faces[k].normal])
	var f: Array = _cell_faces[d]
	var corners: Array = f[0]
	buf.quad([base + corners[0], base + corners[1], base + corners[2], base + corners[3]], f[2], f[1], color, packed)
