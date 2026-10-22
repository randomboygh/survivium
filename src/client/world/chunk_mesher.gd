extends RefCounted
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

const Mat := preload("res://src/shared/content/materials.gd")
const MeshBuffers := preload("res://src/client/world/mesh_buffers.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Trees := preload("res://src/shared/content/trees.gd")

const DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const FACE_TOP := 2
const FACE_BOTTOM := 3
const FACE_SOUTH := 4
const CORNERS := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)],
]
## Water stands half a cell (4 px) below the shore, so the bank shows above it.
const WATER_TOP := WorldData.WATER_TOP
static var AIR: int = Mat.AIR
static var WATER: int = Mat.WATER
static var LEAVES: int = Mat.LEAVES
## Tile index meaning "no texture" (voxels) or "no neighbour" (transitions).
const NO_TILE := 63
## Plain tops merged per step of a job once its columns are done: as costly as a column.
const PLAIN_RUNS := 64
## Edge codes, 2 bits per edge in the order N, S, W, E (see world.gdshader).
const LIGHT := 1
const DARK := 2
const CONTACT := 3
const EDGE_N := 0
const EDGE_S := 2
const EDGE_W := 4
const EDGE_E := 6
## Face flags (see world.gdshader): a season-tinted voxel, a wall with open sky above,
## a face textured in screen texels (slopes and diagonal walls), a diagonal edge across
## corner k (flag bits 16..32) on the corner's side of it or away from it, with an edge
## code (bits 128..256).
const FOLIAGE_VOXEL := 1
const OPEN_TOP := 2
const SLOPE := 4
const DIAG := 8
const DIAG_CORNER := 64
const FULL := WorldData.FULL
const CORNER_DIRS := WorldData.CORNER_DIRS
## Pieces of a top (see _piece): a whole quarter of the cell, the part of a quarter away
## from its corner, the triangle at its corner.
const QUARTER := 0
const CUT := 1
const CORNER := 2
## Cut and filled corners run from the middle of one side of the cell to the middle of
## the next along a curve u^p + v^p = 0.5^p around the cell's middle, p by the
## material's corner shape (Mat.corner_shape): 1 a straight diagonal (stone), 1.5 a
## little rounded (soil), 2 a quarter circle (sand). A curve is drawn in CURVE_STEPS
## straight pieces. Each ends at the middle of a side whatever its shape, so cells of
## any shape meet without gaps. Slopes keep the straight cut, their curved surface
## rounds them.
const CORNER_P := [1.0, 1.5, 2.0]
const CURVE_STEPS := 4
## Diagonals reach a hair past their line, so the texels it runs through belong to the
## ground side and the shader's edge texels match what is drawn.
const EPS := 0.002
## Cells around the chunk copied for neighbour lookups: corners look two cells away.
const PAD := 2
## The two corners on the sides E, W, S, N (in DIRS order), the one nearer the origin first.
const SIDE_CORNERS := [[1, 2], [0, 3], [], [], [3, 2], [0, 1]]
## Half edges of a top, 2 * edge + half (edges N, S, W, E; halves west/east or north/south):
## the corner of the neighbour across each, and the two half edges of each quarter.
const HALF_CORNER := [3, 2, 0, 1, 1, 2, 0, 3]
const QUARTER_HALVES := [[0, 4], [1, 6], [3, 7], [2, 5]]
## A log pillar that is no noted tree is drawn as a trunk 6 texels wide in its 8-texel
## cell; a tree's trunk has its own girth (see Trees.trunk_box).
const PILLAR := Rect2i(1, 1, 6, 6)
## What tops a piece of a trunk (see _bark).
const CAP_NONE := 0
const CAP_CUT := 1
const CAP_BARK := 2
const CELL := WorldData.CELL

static var _faces: Array = []
## Per direction: [corners, uvs, normal] of a whole cell face.
static var _cell_faces: Array = []
static var _covers_lut := PackedByteArray()
## Points of the corner curves, by corner and shape (see corner_curve).
static var _curves := {}


## Per direction: corners in clockwise order seen from outside, and the normal.
static func face_table() -> Array:
	if not _faces.is_empty():
		return _faces
	for d in 6:
		var di: Vector3i = DIRS[d]
		var n := Vector3(di.x, di.y, di.z)
		var c: Array = CORNERS[d].duplicate()
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var e: Vector3 = c[2]
		if (b - a).cross(e - a).dot(n) > 0.0:
			c.reverse()
		_faces.append({"corners": c, "normal": n})
	return _faces


## Texture position of a point on a face: x/z on tops and bottoms, across and down on
## walls (v = 0 at the top of a wall and at the north edge of a top).
static func face_uv(d: int, v: Vector3) -> Vector2:
	if d == FACE_TOP or d == FACE_BOTTOM:
		return Vector2(v.x, v.z)
	if d < 2:
		return Vector2(v.z, 1.0 - v.y)
	return Vector2(v.x, 1.0 - v.y)


## Packs a face's tile, edge codes and flag into UV2.x (see world.gdshader).
static func pack(tile: int, edges: int, flag: int) -> float:
	return float(tile + 64 * edges + 16384 * flag)


## Returns [solid_mesh_or_null, water_mesh_or_null] for the column of cells x0..x0+size, z0..z0+size.
## Works on copies of the chunk's cells and shapes with a border of PAD cells (outside
## the map is air, below it is stone), so neighbour lookups are plain array reads.
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
	## How many of the plain tops are drawn (see _plain_rows).
	var plain_j := 0
	var water_j := 0
	var cands: PackedInt64Array


## The solid and water meshes of the cells x0..x0+size, z0..z0+size, all at once.
static func build_chunk(w, x0: int, z0: int, size: int) -> Array:
	var job := start(w, x0, z0, size)
	while not step(job, 1 << 30):
		pass
	return finish(job)


## Begins building the meshes of a chunk; `step` then builds a few columns at a time.
static func start(w, x0: int, z0: int, size: int) -> Job:
	w.refresh_shapes()
	var job := Job.new()
	job.w = w
	job.x0 = x0
	job.z0 = z0
	job.z = z0
	job.x = x0
	job.faces = face_table()
	job.solid = MeshBuffers.new()
	job.water = MeshBuffers.new()
	var x1 := x0 + size
	var z1 := z0 + size
	job.x1 = x1
	job.z1 = z1
	job.c = w.padded(false, Mat.STONE, x0 - PAD, z0 - PAD, x1 + PAD, z1 + PAD)
	job.sh = w.padded(true, 0, x0 - PAD, z0 - PAD, x1 + PAD, z1 + PAD)
	job.cov = covers_table()
	# Strides of the padded grid: +x, +z, +y.
	job.dz = x1 - x0 + 2 * PAD
	job.dy = job.dz * (z1 - z0 + 2 * PAD)
	job.nb = PackedByteArray()
	job.nb.resize(6)
	job.side_offsets = PackedInt32Array([1, -1, 0, 0, job.dz, -job.dz])
	# Plain tops (no edges, corners or transitions) and plain water wait here to be
	# merged into rows.
	job.plain = PackedInt32Array()
	job.water_plain = PackedInt32Array()
	job.cands = _candidates(w, x0, z0, x1, z1)
	return job


## Builds the next `columns` columns of cells of the chunk (a column is all levels of
## one x, z). Returns true once every column is built.
static func step(job: Job, columns: int) -> bool:
	while columns > 0 and job.z < job.z1:
		_column(job, job.x, job.z)
		columns -= 1
		job.x += 1
		if job.x >= job.x1:
			job.x = job.x0
			job.z += 1
			if job.z >= job.z1:
				job.plain.sort()
				job.water_plain.sort()
	# Then the plain tops, PLAIN_RUNS merged quads per column (a chunk of open ground
	# has over a thousand).
	while columns > 0 and job.z >= job.z1 and (job.plain_j < job.plain.size() or job.water_j < job.water_plain.size()):
		if job.plain_j < job.plain.size():
			job.plain_j = _plain_rows(job.solid, job.plain, job.x0, job.z0, false, job.plain_j, PLAIN_RUNS)
		else:
			job.water_j = _plain_rows(job.water, job.water_plain, job.x0, job.z0, true, job.water_j, PLAIN_RUNS)
		columns -= 1
	return job.z >= job.z1 and job.plain_j >= job.plain.size() and job.water_j >= job.water_plain.size()


static func _column(job: Job, x: int, z: int) -> void:
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
	var no_tiles := float(NO_TILE * 0x41041)
	var nb := job.nb
	var side_offsets := job.side_offsets
	var plain := job.plain
	var water_plain := job.water_plain
	var cands := job.cands
	var j := (z - z0) * (x1 - x0) + (x - x0)
	var cand := cands[j]
	var column := (z - z0 + PAD) * dz + PAD + x - x0
	while cand != 0:
		var bit := cand & -cand
		cand ^= bit
		var y := WorldData.level_of(bit)
		var i := (y + 1) * dy + column
		var m := c[i]
		if m == AIR or m == LEAVES:
			if sh[i] >= 16:
				_fill_faces(solid, c, sh, cov, i, dy, dz, Vector3(x, y, z))
			continue
		# Neighbours in DIRS order: +x, -x, +y, -y, +z, -z.
		nb[0] = c[i + dx]
		nb[1] = c[i - dx]
		nb[2] = c[i + dy]
		nb[3] = c[i - dy]
		nb[4] = c[i + dz]
		nb[5] = c[i - dz]
		var base := Vector3(x, y, z)
		if m == WATER:
			var fills := sh[i] >> 4
			var foam := fills << 8
			for k in 4:
				if fills & (1 << k):
					foam |= _fill_shape(c, cov, i, dy, k) << (16 + 2 * k)
			# Open water has no land beside it, so no foam.
			if cov[nb[0]] or cov[nb[1]] or cov[nb[4]] or cov[nb[5]]:
				foam |= _foam(c, sh, cov, i, dz)
			var depth := 1
			while depth < 8 and c[i - depth * dy] == WATER:
				depth += 1
			if foam == 0 and nb[2] == AIR and nb[0] != AIR and nb[1] != AIR and nb[4] != AIR and nb[5] != AIR:
				water_plain.append(((y * 64 + depth) * 64 + z - z0) * 64 + x - x0)
			else:
				_water_faces(water, faces, nb, base, depth, foam)
			if fills != 0:
				_fill_faces(solid, c, sh, cov, i, dy, dz, base)
		elif m == Mat.LOG and _is_trunk(nb):
			_trunk_faces(solid, w, x, y, z, nb, base, m)
		elif sh[i] & 15 != 0 and not cov[nb[2]]:
			var cuts := sh[i] >> 4
			_slope_faces(solid, faces, c, sh, nb, side_offsets, i, dy, base, m, _around(c, cov, i, dy, dz), cuts)
			if cuts:
				_cut_water(w, water, c, i, dy, base, cuts)
		elif sh[i] & 15 != 0 and sh[i] < 16:
			_deep_faces(solid, faces, c, sh, nb, side_offsets, i, dy, base, m)
		else:
			var cuts := sh[i] >> 4
			# Most tops lie under open sky amid the same flat ground: no sides, no
			# edges, no transitions.
			if cuts == 0 and not cov[nb[2]] and cov[nb[3]] and nb[0] == m and nb[1] == m and nb[4] == m \
					and nb[5] == m and (sh[i + dx] | sh[i - dx] | sh[i + dz] | sh[i - dz]) & 15 == 0 \
					and not cov[c[i + dy + dx]] and not cov[c[i + dy - dx]] and not cov[c[i + dy + dz]] \
					and not cov[c[i + dy - dz]]:
				plain.append(((y * 64 + m * 3) * 64 + z - z0) * 64 + x - x0)
				continue
			for d in 6:
				var n := nb[d]
				if cov[n] and sh[i + side_offsets[d]] & 15 == 0:
					# The ground under a thin trunk still shows around it.
					if not (d == FACE_TOP and n == Mat.LOG and _trunk_at(w, x, y + 1, z)):
						continue
				var tile := m * 3 + (0 if d == FACE_TOP else (2 if d == FACE_BOTTOM else 1))
				var edges := 0
				var flag := 0
				var around := no_tiles
				if d == FACE_TOP:
					edges = _top_edges(c, cov, i, dy, dz)
					var halves := _covered_halves(c, sh, cov, i, dy, dz, edges)
					var a := _around_tiles(c, cov, i, dy, dz)
					if cuts != 0 or halves != 0:
						_top_pieces(solid, base, m, cuts, edges, halves, float(a))
						continue
					if edges == 0 and _plain_around(a, tile):
						plain.append(((y * 64 + tile) * 64 + z - z0) * 64 + x - x0)
						continue
					around = float(a)
				elif d == FACE_SOUTH:
					if not cov[c[i + dy]]:
						flag = OPEN_TOP
					# Outlines where nothing nearer or level is beside or below.
					if not cov[c[i - dy + dz]] and not cov[c[i - dy]]:
						edges |= DARK << EDGE_S
					if not cov[c[i - dx]] and not cov[c[i - dx + dz]] and not cov[c[i - dx + dz + dy]]:
						edges |= DARK << EDGE_W
					if not cov[c[i + dx]] and not cov[c[i + dx + dz]] and not cov[c[i + dx + dz + dy]]:
						edges |= DARK << EDGE_E
				if cuts != 0:
					_cut_side(solid, faces, d, base, cuts, white, Vector2(pack(tile, edges, flag), around),
						Mat.corner_shape[m])
				else:
					_add_cell_face(solid, d, base, white, Vector2(pack(tile, edges, flag), around))
			if cuts != 0:
				_cut_walls(w, solid, water, c, cov, i, dy, base, m, cuts)
			# The ground under a cut corner of the cell above shows there.
			var exposed := sh[i + dy] >> 4 & ~cuts if cov[c[i + dy]] else 0
			if exposed != 0:
				var edges := _top_edges(c, cov, i, dy, dz)
				_exposed_tops(solid, c, cov, i, dz, base, m, exposed, edges,
					_covered_halves(c, sh, cov, i, dy, dz, edges), sh[i + dy] & 15 == 0)


## The meshes once every column is built: [solid, water], null where empty.
static func finish(job: Job) -> Array:
	var out := []
	for i in FINISH_PARTS:
		out.append(finish_part(job, i))
	return out


## Making the meshes takes longer than a column, so ChunkStreamer makes them one a
## frame: part 0 is the solid mesh, part 1 the water.
const FINISH_PARTS := 2


static func finish_part(job: Job, i: int) -> ArrayMesh:
	var b = job.solid if i == 0 else job.water
	return null if b.is_empty() else b.to_mesh(CELL)


## Cells of each column of x0..x1, z0..z1 (row by row) that may show a face, as bit
## masks of levels: those that hide what is behind them next to an open or sloping
## cell, under a cut corner or a trunk; water next to air; open cells with filled
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
				| (corners & cover) >> 1 | log_cols[col] >> 1
			var air_near := (air >> 1) | top_bit
			var a := air_cols[col - 1] | air_cols[col + 1] | air_cols[col - sx] | air_cols[col + sx]
			near |= a | water_cols[col - 1] | water_cols[col + 1] | water_cols[col - sx] | water_cols[col + sx] \
				| leaf_cols[col - 1] | leaf_cols[col + 1] | leaf_cols[col - sx] | leaf_cols[col + sx] \
				| sloped_cols[col - 1] | sloped_cols[col + 1] | sloped_cols[col - sx] | sloped_cols[col + sx]
			air_near |= a
			out[j] = cover & near | water & air_near | corners & open
			j += 1
	return out


## Top tiles of the level neighbours N, S, W, E of padded cell `i`, packed for UV2.y
## (material transitions, see world.gdshader).
static func _around_tiles(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int) -> int:
	var tn := c[i - dz] * 3 if cov[c[i - dz]] and not cov[c[i - dz + dy]] else NO_TILE
	var ts := c[i + dz] * 3 if cov[c[i + dz]] and not cov[c[i + dz + dy]] else NO_TILE
	var tw := c[i - 1] * 3 if cov[c[i - 1]] and not cov[c[i - 1 + dy]] else NO_TILE
	var te := c[i + 1] * 3 if cov[c[i + 1]] and not cov[c[i + 1 + dy]] else NO_TILE
	return tn | ts << 6 | tw << 12 | te << 18


static func _around(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int) -> float:
	return float(_around_tiles(c, cov, i, dy, dz))


## True when no neighbour tile differs from `tile`, so the top has no transitions.
static func _plain_around(a: int, tile: int) -> bool:
	for e in 4:
		var t := a >> (6 * e) & 63
		if t != NO_TILE and t != tile:
			return false
	return true


## Draws the plain tops (sorted keys from build_chunk: level, tile or water depth, z
## and x in the chunk) as one quad per row of neighbours with the same tile, up to
## `runs` quads from key `from` on; returns the key to go on from. The shaders texture
## tops by their world position, so a long quad looks the same as the cells it covers.
static func _plain_rows(buf, keys: PackedInt32Array, x0: int, z0: int, water := false, from := 0,
		runs := 1 << 30) -> int:
	var corners: Array = face_table()[FACE_TOP].corners
	var height := WATER_TOP if water else 1.0
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILE * 0x41041)
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
		var tile := first >> 12 & 63
		var y := first >> 18
		var base := Vector3(x0 + lx, y, z0 + lz)
		var pts := []
		var uvs := []
		for v: Vector3 in corners:
			pts.append(base + Vector3(v.x * length, v.y * height, v.z))
			uvs.append(Vector2(v.x * length, v.z))
		buf.quad(pts, Vector3.UP, uvs, white, Vector2(0.0, tile) if water else Vector2(pack(tile, 0, 0), no_tiles))
		j = end
	return j


## Edge codes of the top of padded cell `i`: what the oblique view shows next to each
## edge: a wall below the south edge (light rim), something lower and farther behind an
## edge (dark outline), or a wall rising from it (contact shadow).
static func _top_edges(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int) -> int:
	var edges := 0
	if cov[c[i + dy - dz]]:
		edges |= CONTACT << EDGE_N
	elif not cov[c[i - dz]]:
		edges |= DARK << EDGE_N
	if not cov[c[i + dz]]:
		edges |= LIGHT << EDGE_S
	if cov[c[i + dy - 1]]:
		edges |= CONTACT << EDGE_W
	elif not cov[c[i - 1]] and not cov[c[i + dy - 1 + dz]]:
		edges |= DARK << EDGE_W
	if cov[c[i + dy + 1]]:
		edges |= CONTACT << EDGE_E
	elif not cov[c[i + 1]] and not cov[c[i + dy + 1 + dz]]:
		edges |= DARK << EDGE_E
	return edges


## Half edges (bits, see HALF_CORNER) of the top of padded cell `i` where the ground
## goes on at the same height, so their edge code must not show: a filled corner of the
## neighbour, or a cut corner of the wall above the neighbour instead of a wall rising.
static func _covered_halves(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int,
		edges: int) -> int:
	# Mostly there are no corners around at all.
	if sh[i - dz] | sh[i + dz] | sh[i - 1] | sh[i + 1] | sh[i + dy - dz] | sh[i + dy - 1] | sh[i + dy + 1] < 16:
		return 0
	var halves := 0
	for h in 8:
		var e := h >> 1
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
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


## Flag of a face with a diagonal across corner k: its corner side (or the other) is
## the face, and `code` is drawn along the diagonal.
static func _diag(k: int, corner_side: bool, code: int) -> int:
	return DIAG | k << 4 | (DIAG_CORNER if corner_side else 0) | code << 7


## The top of a cell drawn in quarters: cut corners leave their diagonal, and half edges
## where the ground goes on lose their edge code.
static func _top_pieces(buf, base: Vector3, m: int, cuts: int, edges: int, halves: int, around: float) -> void:
	var white := Color(1, 1, 1)
	for q in 4:
		var e := _quarter_edges(q, edges, halves)
		if cuts & (1 << q):
			# Beyond a north diagonal lies lower ground (outline), below a south one the wall.
			var flag := _diag(q, false, DARK if q < 2 else LIGHT)
			_piece(buf, base, 1.0, q, CUT, Vector3.UP, white, Vector2(pack(m * 3, e, flag), around), Mat.corner_shape[m])
		else:
			_piece(buf, base, 1.0, q, QUARTER, Vector3.UP, white, Vector2(pack(m * 3, e, 0), around))


## Side `d` of a cell with cut corners: halves of a side next to an uncut corner, the
## bottom in pieces.
static func _cut_side(buf, faces: Array, d: int, base: Vector3, cuts: int, color: Color, packed: Vector2,
		shape := 0) -> void:
	if d == FACE_BOTTOM:
		for q in 4:
			_piece(buf, base, 0.0, q, CUT if cuts & (1 << q) else QUARTER, Vector3.DOWN, color, packed, shape)
		return
	var ks: Array = SIDE_CORNERS[d]
	for j in 2:
		if cuts & (1 << ks[j]) == 0:
			var along_z := d < 2
			var size := Vector3(1.0, 1.0, 0.5) if along_z else Vector3(0.5, 1.0, 1.0)
			var offset := Vector3(0.0, 0.0, 0.5 * j) if along_z else Vector3(0.5 * j, 0.0, 0.0)
			_add(buf, faces[d], d, base, size, offset, color, packed)


## Diagonal walls of the cut corners of padded cell `i`, and water standing in them
## where the cell is beside water.
static func _cut_walls(w, buf, water, c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, base: Vector3,
		m: int, cuts: int) -> void:
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILE * 0x41041)
	for k in 4:
		if cuts & (1 << k) == 0:
			continue
		var edges := 0 if cov[c[i - dy]] else DARK << EDGE_S
		var flag := SLOPE | (0 if cov[c[i + dy]] else OPEN_TOP)
		_diag_wall(buf, base, k, true, white, Vector2(pack(m * 3 + 1, edges, flag), no_tiles), Mat.corner_shape[m])
	_cut_water(w, water, c, i, dy, base, cuts, Mat.corner_shape[m])


## Water standing in the cut corners of padded cell `i` beside water with air above,
## up to the curve of corner shape `shape`.
static func _cut_water(w, water, c: PackedByteArray, i: int, dy: int, base: Vector3, cuts: int, shape := 0) -> void:
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		if cuts & (1 << k) and c[i + o.x] == WATER and c[i + o.x + dy] == AIR:
			var depth := 1
			while depth < 8 and w.get_cell(int(base.x) + o.x, int(base.y) - depth, int(base.z)) == WATER:
				depth += 1
			var foam := 1 << (12 + k) | shape << (16 + 2 * k)
			_piece(water, base, WATER_TOP, k, CORNER, Vector3.UP, Color(1, 1, 1), Vector2(float(foam), float(depth)), shape)


## Ground filling the corners of open padded cell `i`: a diagonal wall, and its top
## where nothing lies on it.
static func _fill_faces(buf, c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int,
		dz: int, base: Vector3) -> void:
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILE * 0x41041)
	var fills := sh[i] >> 4
	for k in 4:
		if fills & (1 << k) == 0:
			continue
		var o: Vector2i = CORNER_DIRS[k]
		var mf := c[i + o.x]
		var open_top: bool = not cov[c[i + dy]] and sh[i + dy] >> 4 & (1 << k) == 0
		var shape := _fill_shape(c, cov, i, dy, k)
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
			# A fill at a north corner faces the view across its diagonal (rim), one at a
			# south corner faces away (outline).
			var flag := _diag(k, true, LIGHT if k < 2 else DARK)
			_piece(buf, base, 1.0, k, CORNER, Vector3.UP, white, Vector2(pack(mf * 3, edges, flag), no_tiles), shape)


## Corner shape of the ground filling corner k of open padded cell `i`: that of the
## material its top is drawn with (see _fill_faces), which the shader rounds its edge by.
static func _fill_shape(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, k: int) -> int:
	var o: Vector2i = CORNER_DIRS[k]
	var mf := c[i + o.x + dy] if cov[c[i + o.x + dy]] else c[i + o.x]
	return Mat.corner_shape[mf]


## Tops of padded cell `i` under the cut corners of the cell above: the ground beside
## goes on into them, and a wall above (not a slope) shades their diagonal.
static func _exposed_tops(buf, c: PackedByteArray, cov: PackedByteArray, i: int, dz: int, base: Vector3, m: int,
		exposed: int, edges: int, halves: int, under_wall: bool) -> void:
	var white := Color(1, 1, 1)
	for k in 4:
		if exposed & (1 << k) == 0:
			continue
		var o: Vector2i = CORNER_DIRS[k]
		var me := c[i + o.x]
		if not cov[me]:
			me = c[i + o.y * dz]
		if not cov[me]:
			me = m
		var flag := _diag(k, true, CONTACT if under_wall else 0)
		_piece(buf, base, 1.0, k, CORNER, Vector3.UP, white,
			Vector2(pack(me * 3, _quarter_edges(k, edges, halves), flag), float(NO_TILE * 0x41041)))


## The corner curve of corner k for corner shape `shape` (see CORNER_P), on the top
## of a cell: points from the middle of its west or east side to the middle of its
## north or south side.
static func corner_curve(k: int, shape: int) -> PackedVector2Array:
	var key := k * 4 + shape
	if _curves.has(key):
		return _curves[key]
	var o := Vector2(CORNER_DIRS[k])
	var p: float = CORNER_P[shape]
	var steps := 1 if shape == 0 else CURVE_STEPS
	var pts := PackedVector2Array()
	for j in steps + 1:
		var a := PI * 0.5 * j / steps
		var cs := cos(a)
		var sn := sin(a)
		var r := 0.5 / pow(pow(cs, p) + pow(sn, p), 1.0 / p) if j > 0 and j < steps else 0.5
		pts.append(Vector2(0.5, 0.5) + Vector2(cs * o.x, sn * o.y) * r)
	_curves[key] = pts
	return pts


## A flat piece of quarter `q` of a cell at height `h` (see QUARTER, CUT, CORNER); the
## curve of a cut or a corner has corner shape `shape`.
static func _piece(buf, base: Vector3, h: float, q: int, kind: int, n: Vector3, color: Color, packed: Vector2,
		shape := 0) -> void:
	var o := Vector2(CORNER_DIRS[q])
	var corner := Vector2(0.5, 0.5) + o * 0.5
	var pts: Array
	if kind == QUARTER:
		pts = [Vector2(0.5, 0.5), Vector2(0.5, corner.y), corner, Vector2(corner.x, 0.5)]
	else:
		# A fan from the middle of the cell (a cut) or from the corner (the corner beyond
		# the curve).
		var hub := Vector2(0.5, 0.5) if kind == CUT else corner
		var curve := corner_curve(q, shape)
		var off := o * (EPS if kind == CUT else -EPS)
		for j in curve.size() - 1:
			pts = [hub, curve[j] + off, curve[j + 1] + off]
			var tri := []
			for p: Vector2 in pts:
				tri.append(base + Vector3(p.x, h, p.y))
			_wound(buf, tri, n, pts, color, packed)
		return
	var vs := []
	for p: Vector2 in pts:
		vs.append(base + Vector3(p.x, h, p.y))
	_wound(buf, vs, n, pts, color, packed)


## The wall along the curve of corner k (see corner_curve), facing the corner (a cut)
## or away from it (a fill): a straight piece of wall per piece of the curve. A
## straight corner is flat; a round one has the curve's own normals at its points, so
## the light runs smoothly around it.
static func _diag_wall(buf, base: Vector3, k: int, outward: bool, color: Color, packed: Vector2, shape := 0) -> void:
	var o := Vector2(CORNER_DIRS[k])
	var curve := corner_curve(k, shape)
	for j in curve.size() - 1:
		var p1 := curve[j]
		var p2 := curve[j + 1]
		var d := p2 - p1
		var side := Vector2(d.y, -d.x).normalized()
		if side.dot(o) < 0.0:
			side = -side
		var facing := 1.0 if outward else -1.0
		var n := Vector3(side.x, 0.0, side.y) * facing
		var vs := [base + Vector3(p1.x, 0.0, p1.y), base + Vector3(p2.x, 0.0, p2.y),
			base + Vector3(p2.x, 1.0, p2.y), base + Vector3(p1.x, 1.0, p1.y)]
		var uvs := [Vector2(p1.x, 1.0), Vector2(p2.x, 1.0), Vector2(p2.x, 0.0), Vector2(p1.x, 0.0)]
		if shape == 0:
			_wound(buf, vs, n, uvs, color, packed)
			continue
		# A round corner is shaded smoothly: each point gets the curve's own normal.
		var n1 := _curve_normal(p1, o, shape) * facing
		var n2 := _curve_normal(p2, o, shape) * facing
		var ns := [n1, n2, n2, n1]
		if (vs[1] - vs[0]).cross(vs[2] - vs[0]).dot(n) > 0.0:
			vs.reverse()
			uvs.reverse()
			ns.reverse()
		buf.tri_n([vs[0], vs[1], vs[2]], [ns[0], ns[1], ns[2]], [uvs[0], uvs[1], uvs[2]], color, packed)
		buf.tri_n([vs[0], vs[2], vs[3]], [ns[0], ns[2], ns[3]], [uvs[0], uvs[2], uvs[3]], color, packed)


## Normal of the curve of a corner toward `o` with corner shape `shape` at point `q`,
## pointing to the corner: across the curve u^p + v^p = 0.5^p.
static func _curve_normal(q: Vector2, o: Vector2, shape: int) -> Vector3:
	var p: float = CORNER_P[shape]
	var u := maxf((q.x - 0.5) * o.x, 0.0)
	var v := maxf((q.y - 0.5) * o.y, 0.0)
	var g := Vector2(pow(u, p - 1.0) * o.x, pow(v, p - 1.0) * o.y).normalized()
	return Vector3(g.x, 0.0, g.y)


## Adds a triangle or quad with corners in either order, turned to face along `n`.
static func _wound(buf, vs: Array, n: Vector3, uvs: Array, color: Color, packed: Vector2) -> void:
	var a: Vector3 = vs[0]
	var b: Vector3 = vs[1]
	var e: Vector3 = vs[2]
	if (b - a).cross(e - a).dot(n) > 0.0:
		vs.reverse()
		uvs.reverse()
	if vs.size() == 4:
		buf.quad(vs, n, uvs, color, packed)
	else:
		buf.tri(vs, n, uvs, color, packed)


## Steps of a sloping top's surface along a side where it curves: a grid of squares,
## each two triangles with the surface's own normals at their corners. Along a side
## where it stays level (a ramp's high and low sides) one step is enough.
const PATCH_STEPS := 4
## Hermite weights at the steps of 1 and of PATCH_STEPS (see WorldData.patch_height):
## of the height at the near and far end, of the slope there, and their changes.
static var _hw := {}


## The weights at `steps` steps: [a0, a1, b0, b1, da0, da1, db0, db1] per point.
static func _hermite_steps(steps: int) -> Array:
	if not _hw.has(steps):
		var out := []
		for j in steps + 1:
			var t := float(j) / steps
			out.append(PackedFloat32Array([1.0 - t * t * (3.0 - 2.0 * t), t * t * (3.0 - 2.0 * t),
				t * (1.0 - t) * (1.0 - t), t * t * (t - 1.0), 6.0 * t * (t - 1.0), 6.0 * t * (1.0 - t),
				1.0 - 4.0 * t + 3.0 * t * t, 3.0 * t * t - 2.0 * t]))
		_hw[steps] = out
	return _hw[steps]


## Steps of patch `p` along x and along z: one along a side where it stays level, all
## where something is cut.
static func _patch_steps(p: PackedFloat32Array, cuts: int) -> Vector2i:
	if cuts != 0:
		return Vector2i(PATCH_STEPS, PATCH_STEPS)
	var nu := 1 if p[0] == p[1] and p[3] == p[2] and p[4] == 0.0 and p[5] == 0.0 and p[6] == 0.0 \
		and p[7] == 0.0 else PATCH_STEPS
	var nv := 1 if p[0] == p[3] and p[1] == p[2] and p[8] == 0.0 and p[9] == 0.0 and p[10] == 0.0 \
		and p[11] == 0.0 else PATCH_STEPS
	return Vector2i(nu, nv)


## The surface of the sloping top of padded cell `i` (see WorldData.make_patch, which
## WorldData.surface_patch builds the same from the world).
static func patch(c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int) -> PackedFloat32Array:
	var h := _corner_heights(sh, i, dy)
	var far := PackedInt32Array()
	far.resize(8)
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var d := (k + 2) & 3
		var diag := i + o.x + o.y * dz
		far[2 * k] = WorldData.far_corner(_patch_far(c, sh, i + o.x, dy, k ^ 1, k, h[k]),
			_patch_far(c, sh, diag, dy, d, 3 - k, h[k]), h[k])
		far[2 * k + 1] = WorldData.far_corner(_patch_far(c, sh, i + o.y * dz, dy, 3 - k, k, h[k]),
			_patch_far(c, sh, diag, dy, d, k ^ 1, h[k]), h[k])
	return WorldData.make_patch(h, far)


## Heights of the corners of the top of padded ground cell `i` (see WorldData.corner_heights).
static func _corner_heights(sh: PackedByteArray, i: int, dy: int) -> PackedInt32Array:
	var s := sh[i]
	var below := sh[i - dy] if s & 15 else 0
	var h := PackedInt32Array([1, 1, 1, 1])
	for k in 4:
		if s & (1 << k):
			h[k] = -1 if below & (1 << k) else 0
	return h


## Height of corner `far` of the top in the padded column of cell `j` (same level)
## whose corner `near` meets one at `hv` (see WorldData._patch_far: the levels tried
## are a level above, at and below the corner).
static func _patch_far(c: PackedByteArray, sh: PackedByteArray, j: int, dy: int, near: int, far: int, hv: int) -> int:
	for dl: int in [hv + 1, hv, hv - 1]:
		var l := j + dl * dy
		if l - dy < 0 or l + dy >= c.size():
			continue
		var up := c[l + dy]
		var m := c[l]
		if (up == AIR or up == WATER) and m != AIR and m != WATER and m != LEAVES and m != Mat.LOG:
			if _corner_height(sh, l, dy, near) + dl == hv:
				return _corner_height(sh, l, dy, far) + dl
	return WorldData.NO_CORNER


## Height of corner k of the top of padded ground cell `i` (see _corner_heights).
static func _corner_height(sh: PackedByteArray, i: int, dy: int, k: int) -> int:
	var bit := 1 << k
	if sh[i] & bit == 0:
		return 1
	return -1 if sh[i - dy] & bit else 0


## Heights of the surface of the padded column of cell `j` at its corners above the
## level of `j`: its top's, or for a cell that a slope above goes down into, the slope's.
## Empty where the column has no surface on this level.
static func _column_heights(c: PackedByteArray, sh: PackedByteArray, j: int, dy: int) -> PackedInt32Array:
	var up := c[j + dy]
	if up == AIR or up == WATER:
		var m := c[j]
		if m == AIR or m == WATER or m == LEAVES:
			return PackedInt32Array()
		return _corner_heights(sh, j, dy)
	if sh[j] & 15 and j + 2 * dy < c.size():
		var h := _corner_heights(sh, j + dy, dy)
		for k in 4:
			h[k] += 1
		return h
	return PackedInt32Array()


## Heights and normals of patch `p` raised by `lift` at the points of a grid of
## `steps` (x, z) squares, row by row from the north-west.
static func _patch_grid(p: PackedFloat32Array, lift: float, steps: Vector2i) -> Array:
	var hwu := _hermite_steps(steps.x)
	var hwv := _hermite_steps(steps.y)
	var nu := steps.x + 1
	var hs := PackedFloat32Array()
	var ns := PackedVector3Array()
	hs.resize(nu * (steps.y + 1))
	ns.resize(nu * (steps.y + 1))
	for b in steps.y + 1:
		var wv: PackedFloat32Array = hwv[b]
		# Along this row the patch is a cubic in u: its weights at the west (0) and
		# east (1) ends, of the height, of its slope along x, and of the change along z.
		var r := PackedFloat32Array()
		r.resize(8)
		for i in 2:
			var kn: int = i
			var ks: int = 3 - i
			r[i] = p[kn] * wv[0] + p[ks] * wv[1] + p[8 + kn] * wv[2] + p[8 + ks] * wv[3]
			r[2 + i] = p[4 + kn] * wv[0] + p[4 + ks] * wv[1]
			r[4 + i] = p[kn] * wv[4] + p[ks] * wv[5] + p[8 + kn] * wv[6] + p[8 + ks] * wv[7]
			r[6 + i] = p[4 + kn] * wv[4] + p[4 + ks] * wv[5]
		for a in nu:
			var wu: PackedFloat32Array = hwu[a]
			var h := lift + r[0] * wu[0] + r[1] * wu[1] + r[2] * wu[2] + r[3] * wu[3]
			var gx := r[0] * wu[4] + r[1] * wu[5] + r[2] * wu[6] + r[3] * wu[7]
			var gz := r[4] * wu[0] + r[5] * wu[1] + r[6] * wu[2] + r[7] * wu[3]
			hs[b * nu + a] = h
			ns[b * nu + a] = Vector3(-gx, 1.0, -gz).normalized()
	return [hs, ns]


## A cell with a sloping top: the smooth surface of its patch, cut where its corners
## are cut (with a wall up to the surface there), side walls up to the surface where
## nothing covers them, and the bottom if open.
static func _slope_faces(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, nb: PackedByteArray,
		side_offsets: PackedInt32Array, i: int, dy: int, base: Vector3, m: int, around: float, cuts: int) -> void:
	var p := patch(c, sh, i, dy, side_offsets[4])
	var steps := _patch_steps(p, cuts)
	var grid := _patch_grid(p, 0.0, steps)
	var hs: PackedFloat32Array = grid[0]
	var ns: PackedVector3Array = grid[1]
	var white := Color(1, 1, 1)
	var top := Vector2(pack(m * 3, 0, SLOPE), around)
	if cuts == 0:
		_surface(buf, base, hs, ns, steps, top)
	else:
		_cut_surface(buf, base, hs, ns, cuts, top, Vector2(pack(m * 3 + 1, 0, SLOPE), float(NO_TILE * 0x41041)))
	var own := _corner_heights(sh, i, dy)
	for d in [0, 1, 3, 4, 5]:
		var nm := nb[d]
		if nm != AIR and nm != WATER and nm != LEAVES and (d == FACE_BOTTOM or sh[i + side_offsets[d]] & 15 == 0):
			continue
		if d == FACE_BOTTOM:
			for q in 4:
				_piece(buf, base, 0.0, q, CUT if cuts & (1 << q) else QUARTER, Vector3.DOWN, white,
					Vector2(pack(m * 3 + 2, 0, 0), float(NO_TILE * 0x41041)))
			continue
		_patch_side(buf, faces, c, sh, i, dy, side_offsets[d], d, base, m, hs, steps, own, cuts)


## The grid of a surface as triangles sharing its points (they are many on a slope).
static func _surface(buf, base: Vector3, hs: PackedFloat32Array, ns: PackedVector3Array, steps: Vector2i,
		packed: Vector2) -> void:
	var start: int = buf.verts.size()
	var nu := steps.x + 1
	var white := Color(1, 1, 1)
	for b in steps.y + 1:
		var z := float(b) / steps.y
		for a in nu:
			var x := float(a) / steps.x
			buf.verts.append(base + Vector3(x, hs[b * nu + a], z))
			buf.normals.append(ns[b * nu + a])
			buf.uvs.append(Vector2(x, z))
			buf.uv2s.append(packed)
			buf.colors.append(white)
	for b in steps.y:
		for a in steps.x:
			var j := start + b * nu + a
			# Clockwise from above (Godot front faces).
			buf.indices.append_array(PackedInt32Array([j, j + 1, j + nu + 1, j, j + nu + 1, j + nu]))


## The surface of a sloping top with cut corners: each triangle of the grid clipped to
## the cuts, with a wall at each cut as high as the slope there.
static func _cut_surface(buf, base: Vector3, hs: PackedFloat32Array, ns: PackedVector3Array,
		cuts: int, top: Vector2, wall: Vector2) -> void:
	var white := Color(1, 1, 1)
	var n := PATCH_STEPS + 1
	var step := 1.0 / PATCH_STEPS
	for b in PATCH_STEPS:
		for a in PATCH_STEPS:
			var j00 := b * n + a
			var q00 := Vector3(a * step, hs[j00], b * step)
			var q10 := Vector3((a + 1) * step, hs[j00 + 1], b * step)
			var q11 := Vector3((a + 1) * step, hs[j00 + n + 1], (b + 1) * step)
			var q01 := Vector3(a * step, hs[j00 + n], (b + 1) * step)
			# Most squares lie wholly beside the cuts, or wholly in one.
			var whole := true
			var gone := false
			for k in 4:
				if cuts & (1 << k):
					var inside := 0
					for q: Vector3 in [q00, q10, q11, q01]:
						inside += int(_keep(k, q) < 0.0)
					whole = whole and inside == 0
					gone = gone or inside == 4
			if gone:
				continue
			if whole:
				buf.tri_n([base + q00, base + q10, base + q11], [ns[j00], ns[j00 + 1], ns[j00 + n + 1]],
					[Vector2(q00.x, q00.z), Vector2(q10.x, q10.z), Vector2(q11.x, q11.z)], white, top)
				buf.tri_n([base + q00, base + q11, base + q01], [ns[j00], ns[j00 + n + 1], ns[j00 + n]],
					[Vector2(q00.x, q00.z), Vector2(q11.x, q11.z), Vector2(q01.x, q01.z)], white, top)
				continue
			for t: Array in [[q00, q10, q11, ns[j00], ns[j00 + 1], ns[j00 + n + 1]],
					[q00, q11, q01, ns[j00], ns[j00 + n + 1], ns[j00 + n]]]:
				var poly: Array = [t[0], t[1], t[2]]
				for k in 4:
					if cuts & (1 << k) and not poly.is_empty():
						var clipped := _clip(poly, k)
						poly = clipped[0]
						var ends: Array = clipped[1]
						if ends.size() == 2 and (ends[0].y > 0.01 or ends[1].y > 0.01):
							var e0: Vector3 = ends[0]
							var e1: Vector3 = ends[1]
							var ha := maxf(e0.y, 0.0)
							var hb := maxf(e1.y, 0.0)
							var o := Vector2(CORNER_DIRS[k])
							_wound(buf, [base + Vector3(e0.x, 0.0, e0.z), base + Vector3(e1.x, 0.0, e1.z),
								base + Vector3(e1.x, hb, e1.z), base + Vector3(e0.x, ha, e0.z)],
								Vector3(o.x, 0.0, o.y).normalized(),
								[Vector2(e0.x, 1.0), Vector2(e1.x, 1.0), Vector2(e1.x, 1.0 - hb), Vector2(e0.x, 1.0 - ha)],
								white, wall)
				for j in range(1, poly.size() - 1):
					var pts: Array = [poly[0], poly[j], poly[j + 1]]
					var nrm := []
					var uvs := []
					for q: Vector3 in pts:
						nrm.append(_normal_in(t, q))
						uvs.append(Vector2(q.x, q.z))
					buf.tri_n([base + pts[0], base + pts[1], base + pts[2]], nrm, uvs, white, top)


## The normal at point q of triangle t ([3 corners, their 3 normals]), blended from its
## corners' by where q lies in it (seen from above).
static func _normal_in(t: Array, q: Vector3) -> Vector3:
	var a := Vector2(t[0].x, t[0].z)
	var b := Vector2(t[1].x, t[1].z)
	var e := Vector2(t[2].x, t[2].z)
	var p := Vector2(q.x, q.z)
	var area := (b - a).cross(e - a)
	var wb := (p - a).cross(e - a) / area
	var we := (b - a).cross(p - a) / area
	var n: Vector3 = t[3] * (1.0 - wb - we) + t[4] * wb + t[5] * we
	return n.normalized()


## A covered cell that the slope above goes down into: its sides up to that slope's
## surface where nothing covers them.
static func _deep_faces(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, nb: PackedByteArray,
		side_offsets: PackedInt32Array, i: int, dy: int, base: Vector3, m: int) -> void:
	var p := patch(c, sh, i + dy, dy, side_offsets[4])
	var steps := _patch_steps(p, 0)
	var hs: PackedFloat32Array = _patch_grid(p, 1.0, steps)[0]
	var own := _column_heights(c, sh, i, dy)
	for d in [0, 1, 4, 5]:
		var nm := nb[d]
		if nm != AIR and nm != WATER and nm != LEAVES and sh[i + side_offsets[d]] & 15 == 0:
			continue
		_patch_side(buf, faces, c, sh, i, dy, side_offsets[d], d, base, m, hs, steps, own, 0)


## Side `d` of padded cell `i` up to the surface whose heights on a grid of `steps`
## are `hs` (cut at 0 and 1), a piece per step of the grid along it; none where the
## column beside has a surface meeting this one at both ends of the side, halves next
## to cut corners left out.
static func _patch_side(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, off: int,
		d: int, base: Vector3, m: int, hs: PackedFloat32Array, steps: Vector2i, own: PackedInt32Array,
		cuts: int) -> void:
	var ks: Array = SIDE_CORNERS[d]
	var other := _column_heights(c, sh, i + off, dy)
	if not other.is_empty():
		var k0: int = ks[0]
		var k1: int = ks[1]
		var m0: int = k0 ^ 1 if d < 2 else 3 - k0
		var m1: int = k1 ^ 1 if d < 2 else 3 - k1
		if other[m0] == own[k0] and other[m1] == own[k1]:
			return
	var face: Dictionary = faces[d]
	var c0 := Vector2(CORNER_DIRS[ks[0]]) * 0.5 + Vector2(0.5, 0.5)
	var c1 := Vector2(CORNER_DIRS[ks[1]]) * 0.5 + Vector2(0.5, 0.5)
	var packed := Vector2(pack(m * 3 + 1, 0, 0), float(NO_TILE * 0x41041))
	var white := Color(1, 1, 1)
	var count := steps.y if d < 2 else steps.x
	for s in count:
		if cuts & (1 << ks[0 if 2 * s < count else 1]):
			continue
		var a := c0.lerp(c1, float(s) / count)
		var b := c0.lerp(c1, float(s + 1) / count)
		var ha := clampf(_grid_at(hs, steps, a), 0.0, 1.0)
		var hb := clampf(_grid_at(hs, steps, b), 0.0, 1.0)
		if ha < 0.001 and hb < 0.001:
			continue
		var vs := [base + Vector3(a.x, 0.0, a.y), base + Vector3(b.x, 0.0, b.y)]
		var uvs := [face_uv(d, Vector3(a.x, 0.0, a.y)), face_uv(d, Vector3(b.x, 0.0, b.y))]
		if hb >= 0.001:
			vs.append(base + Vector3(b.x, hb, b.y))
			uvs.append(face_uv(d, Vector3(b.x, hb, b.y)))
		if ha >= 0.001:
			vs.append(base + Vector3(a.x, ha, a.y))
			uvs.append(face_uv(d, Vector3(a.x, ha, a.y)))
		_wound(buf, vs, face.normal, uvs, white, packed)


## The grid height at a point of the cell's edge (on a grid point).
static func _grid_at(hs: PackedFloat32Array, steps: Vector2i, q: Vector2) -> float:
	return hs[roundi(q.y * steps.y) * (steps.x + 1) + roundi(q.x * steps.x)]


## Clips a convex polygon of points in a cell (x, z in 0..1, y the height) to the side of
## the diagonal of corner k away from the corner. Returns the polygon and the points
## where it crosses the diagonal, in the order they were found.
static func _clip(poly: Array, k: int) -> Array:
	var out := []
	var ends := []
	var count := poly.size()
	for j in count:
		var p: Vector3 = poly[j]
		var q: Vector3 = poly[(j + 1) % count]
		var dp := _keep(k, p)
		var dq := _keep(k, q)
		if dp >= 0.0:
			out.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			var x := p.lerp(q, dp / (dp - dq))
			out.append(x)
			ends.append(x)
	return [out, ends]


## Positive on the side of the diagonal of corner k away from the corner.
static func _keep(k: int, p: Vector3) -> float:
	match k:
		0:
			return p.x + p.z - 0.5
		1:
			return 0.5 - p.x + p.z
		2:
			return 1.5 - p.x - p.z
	return 0.5 + p.x - p.z


## 1 for materials that hide what is behind them (not air, water or leaves).
static func covers_table() -> PackedByteArray:
	if _covers_lut.is_empty():
		_covers_lut.resize(256)
		for m in 256:
			_covers_lut[m] = 1 if _covers(m) else 0
	return _covers_lut


## Dark tops of solid cells on `level` that are covered by solid cells above:
## what you see in the cut when looking into a mountain. Cut corners stay open, and
## fills sliced by the cut show as dark triangles. Rows of whole tops of the same
## material are merged. Covers the cells x0..x0+size, z0..z0+size (a chunk from the
## origin by default), so the game can rebuild the cap chunk by chunk.
static func build_cap(w, level: int, x0 := 0, z0 := 0, size := WorldData.CHUNK) -> ArrayMesh:
	if level < 0 or level >= w.size_y - 1:
		return null
	w.refresh_shapes()
	var buf := MeshBuffers.new()
	var x1: int = x0 + size
	var z1: int = z0 + size
	var layer := WorldData.LAYER
	var row: int = level * layer
	var bit := 1 << level
	var both := bit | bit << 1
	var dark := Color(0.4, 0.4, 0.4)
	var no_tiles := float(NO_TILE * 0x41041)
	var corners: Array = face_table()[FACE_TOP].corners
	var cells := PackedByteArray()
	var shapes := PackedByteArray()
	for z in range(z0, z1):
		# A run of whole tops waiting to be drawn: first x and tile.
		var run_x := -1
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
				if open & both == 0 and (shapes[i] | shapes[i + layer]) < 16:
					tile = cells[i] * 3
			if tile != run_tile and run_x >= 0:
				var base := Vector3(run_x, level, z)
				var pts := []
				var uvs := []
				for v: Vector3 in corners:
					pts.append(base + Vector3(v.x * (x - run_x), v.y, v.z))
					uvs.append(Vector2(v.x * (x - run_x), v.z))
				buf.quad(pts, Vector3.UP, uvs, dark, Vector2(pack(run_tile, 0, 0), no_tiles))
				run_x = -1
			if tile >= 0:
				if run_x < 0:
					run_x = x
					run_tile = tile
				continue
			run_tile = -1
			if c == null:
				continue
			var base := Vector3(x, level, z)
			var packed := Vector2(pack(cells[i] * 3, 0, 0), no_tiles)
			if open & both == 0:
				var cuts: int = (shapes[i] | shapes[i + layer]) >> 4
				# Slopes keep the straight cut.
				var shape: int = 0 if shapes[i] & 15 != 0 else Mat.corner_shape[cells[i]]
				for q in 4:
					_piece(buf, base, 1.0, q, CUT if cuts & (1 << q) else QUARTER, Vector3.UP, dark, packed, shape)
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
							Mat.corner_shape[mf])
	return null if buf.is_empty() else buf.to_mesh(CELL)


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


## Adds a face of the box `offset`..`offset + size` inside the cell at `base`.
static func _add(buf, face: Dictionary, d: int, base: Vector3, size: Vector3, offset: Vector3, color: Color, packed: Vector2) -> void:
	var pts := []
	var uvs := []
	for c in face.corners:
		var v: Vector3 = offset + c * size
		pts.append(base + v)
		uvs.append(face_uv(d, v))
	buf.quad(pts, face.normal, uvs, color, packed)


## Cells that hide what is behind them; leaves and water do not.
static func _covers(m: int) -> bool:
	return m != AIR and m != WATER and m != LEAVES


## A log with open sides that continues up into a trunk or crown is a tree trunk.
static func _is_trunk(nb: PackedByteArray) -> bool:
	return not _covers(nb[0]) and not _covers(nb[1]) and not _covers(nb[4]) and not _covers(nb[5]) \
		and (nb[2] == Mat.LOG or nb[2] == LEAVES)


static func _trunk_at(w, x: int, y: int, z: int) -> bool:
	var nb := PackedByteArray([w.get_cell(x + 1, y, z), w.get_cell(x - 1, y, z), w.get_cell(x, y + 1, z),
		w.get_cell(x, y - 1, z), w.get_cell(x, y, z + 1), w.get_cell(x, y, z - 1)])
	return w.get_cell(x, y, z) == Mat.LOG and _is_trunk(nb)


## The trunk of a tree in its log cell at x, y, z: a column of bark of the tree's own
## girth and crook (see Trees.trunk_box) with its front corners cut, so the light gives
## it a lit and a shaded side, with a dark outline on the sides seen from the front. Its sides slant
## from cell to cell as it thins and bends; at the foot it flares out and sends out a
## few roots.
static func _trunk_faces(buf, w, x: int, y: int, z: int, nb: PackedByteArray, base: Vector3, m: int) -> void:
	var col := Vector2i(x, z)
	var species: int = w.trees.get(col, -1)
	if species >= Trees.SPECIES.size():
		species = -1
	var k := 0
	while k < 64 and w.get_cell(x, y - k - 1, z) == Mat.LOG:
		k += 1
	var box := PILLAR if species < 0 else Trees.trunk_box(species, col, k)
	var color := Color(1, 1, 1) if species < 0 else _bark_tone(col)
	var top := CAP_CUT if not _covers(nb[2]) else CAP_NONE
	# Going up into more trunk, the bark slants to where the next cell has it.
	var up := box
	if nb[2] == Mat.LOG:
		top = CAP_NONE
		if species >= 0:
			up = Trees.trunk_box(species, col, k + 1)
	var bottom := not _covers(nb[3]) and nb[3] != Mat.LOG
	if k > 0 or species < 0:
		_bark(buf, base, box, up, 0, 8, top, bottom, m, color)
		return
	# The foot flares out two texels each way, then the roots.
	_bark(buf, base, box.grow(2), box, 0, 4, CAP_NONE, bottom, m, color)
	_bark(buf, base, box, up, 4, 8, top, false, m, color)
	var foot := box.grow(2)
	var s: Dictionary = Trees.SPECIES[species]
	var roots: int = s.roots[0] + posmod(hash(col * 3 + Vector2i(1, 2)), s.roots[1] - s.roots[0] + 1)
	# On the sides that show: east, west and south.
	var first := posmod(hash(col * 5 + Vector2i(7, 3)), 3)
	for i in roots:
		var h := hash(Vector3i(col.x, i + 11, col.y))
		var side := (first + i) % 3
		var across := foot.size.y if side < 2 else foot.size.x
		var wide := 2 + (h & 1)
		var at := 2 + posmod(h >> 1, maxi(1, across - 4 - wide))
		var root := _root(foot, side, -1, 3 + posmod(h >> 5, 3), at, wide)
		_bark(buf, base, root, root, 0, 1 + (h >> 8 & 1), CAP_BARK, false, m, color)


## The part `from`..`to` texels out from the side `side` (E, W, S, N) of `foot` of a root
## `wide` texels across, `at` texels along that side.
static func _root(foot: Rect2i, side: int, from: int, to: int, at: int, wide: int) -> Rect2i:
	match side:
		0:
			return Rect2i(foot.end.x + from, foot.position.y + at, to - from, wide)
		1:
			return Rect2i(foot.position.x - to, foot.position.y + at, to - from, wide)
		2:
			return Rect2i(foot.position.x + at, foot.end.y + from, wide, to - from)
	return Rect2i(foot.position.x + at, foot.position.y - to, wide, to - from)


## The tone of the bark of the tree in column `col`: a little darker or lighter and
## warmer or greyer than the next one.
static func _bark_tone(col: Vector2i) -> Color:
	var h := hash(col * 13 + Vector2i(5, 9))
	var light := 0.86 + 0.14 * float(h & 255) / 255.0
	var warm := float(h >> 8 & 255) / 255.0
	return Color(light, light * (0.95 + 0.05 * warm), light * (0.9 + 0.1 * (1.0 - warm)))


## A column of bark from `r0` at `y0` texels up to `r1` at `y1` (texels of the cell at
## `base` seen from above, x west to east, y north to south), its front corners cut by a
## quarter of its width (see _ring); with its bottom when asked and its top as `top`
## says: CAP_NONE, CAP_CUT (the end grain of a stump) or CAP_BARK (a root).
static func _bark(buf, base: Vector3, r0: Rect2i, r1: Rect2i, y0: int, y1: int, top: int, bottom: bool, m: int, color: Color) -> void:
	var c := mini(r0.size.x, r1.size.x) / 4
	var low := _ring(r0, c)
	var high := _ring(r1, c)
	var mid := Vector2(r0.get_center())
	var side := m * 3 + 1
	var around := float(NO_TILE * 0x41041)
	for i in 8:
		var a: Vector2 = low[i]
		var b: Vector2 = low[(i + 1) % 8]
		if a == b:
			continue
		var e := b - a
		var out := Vector2(e.y, -e.x).normalized()
		if out.dot((a + b) * 0.5 - mid) < 0.0:
			out = -out
		# The cut corners seen from the front carry the outline at their outer edge.
		var edges := 0
		var ua := 0.5
		var ub := 0.5
		if i == 3 and c > 0:
			edges = DARK << EDGE_E
			ua = 1.0
			ub = 1.0 - c / 8.0
		elif i == 5 and c > 0:
			edges = DARK << EDGE_W
			ua = c / 8.0
			ub = 0.0
		var pts := [_texel(base, high[i], y1), _texel(base, high[(i + 1) % 8], y1), _texel(base, b, y0),
			_texel(base, a, y0)]
		var uvs := [Vector2(ua, 1.0 - y1 / 8.0), Vector2(ub, 1.0 - y1 / 8.0), Vector2(ub, 1.0 - y0 / 8.0),
			Vector2(ua, 1.0 - y0 / 8.0)]
		_facing(buf, pts, Vector3(out.x, 0.0, out.y), uvs, color, Vector2(pack(side, edges, 0), around))
	var caps: Array = []
	if top != CAP_NONE:
		caps.append([high, y1, Vector3.UP, m * 3 + (0 if top == CAP_CUT else 1)])
	if bottom:
		caps.append([low, y0, Vector3.DOWN, m * 3 + 2])
	for cap: Array in caps:
		var ring: Array = cap[0]
		var packed := Vector2(pack(cap[3], 0, 0), around)
		var rows := [[ring[0], ring[1], ring[3], ring[6]]]
		if c > 0:
			rows.append([ring[6], ring[3], ring[4], ring[5]])
		for q: Array in rows:
			var pts := []
			var uvs := []
			for p: Vector2 in q:
				pts.append(_texel(base, p, cap[1]))
				uvs.append(Vector2(clampf(p.x / 8.0, 0.0, 1.0), clampf(p.y / 8.0, 0.0, 1.0)))
			_facing(buf, pts, cap[2], uvs, color, packed)


## The eight corners round `r`, clockwise from the north-west one, with its south corners
## cut by `c` texels; the north ones, hidden behind it, stay square (and come twice).
static func _ring(r: Rect2i, c: int) -> Array:
	var l := r.position.x
	var e := r.end.x
	var n := r.position.y
	var s := r.end.y
	return [Vector2(l, n), Vector2(e, n), Vector2(e, n), Vector2(e, s - c),
		Vector2(e - c, s), Vector2(l + c, s), Vector2(l, s - c), Vector2(l, n)]


## The point `p` (texels across the cell at `base` from above) `up` texels up.
static func _texel(base: Vector3, p: Vector2, up: float) -> Vector3:
	return base + Vector3(p.x, up, p.y) / 8.0


## A quad with its corners turned clockwise as seen from the side `n` faces.
static func _facing(buf, pts: Array, n: Vector3, uvs: Array, color: Color, packed: Vector2) -> void:
	if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) > 0.0:
		pts.reverse()
		uvs.reverse()
	buf.quad(pts, n, uvs, color, packed)


## Foam bits of the water in padded cell `i`: the half edges (see HALF_CORNER) that
## touch land, not where the land beside has its corner cut and the water goes on.
static func _foam(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dz: int) -> int:
	var foam := 0
	for h in 8:
		var e := h >> 1
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
		if cov[c[n]] and sh[n] >> 4 & (1 << HALF_CORNER[h]) == 0:
			foam |= 1 << h
	return foam


## Water: the top face carries foam bits (UV2.x: the half edges that touch land, then
## the filled corners, then the cut corners of the land beside, see water.gdshader) and
## the depth to the bottom in cells (UV2.y). Filled corners are left out of the top.
static func _water_faces(buf, faces: Array, nb: PackedByteArray, base: Vector3, depth: int, foam: int) -> void:
	if nb[0] != AIR and nb[1] != AIR and nb[2] != AIR and nb[4] != AIR and nb[5] != AIR:
		return
	var h := WATER_TOP if nb[2] == AIR else 1.0
	var fills := foam >> 8 & 15
	var white := Color(1, 1, 1)
	var data := Vector2(float(foam), float(depth))
	for d in 6:
		if d != FACE_BOTTOM and nb[d] == AIR:
			if d == FACE_TOP and fills != 0:
				for q in 4:
					_piece(buf, base, h, q, CUT if fills & (1 << q) else QUARTER, Vector3.UP, white, data,
						foam >> (16 + 2 * q) & 3)
				continue
			_add(buf, faces[d], d, base, Vector3(1.0, h, 1.0), Vector3.ZERO, white, data)
