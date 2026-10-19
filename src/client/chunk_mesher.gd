extends RefCounted
## Builds meshes from the cell grid: one quad per visible cell face, with the data the
## world shader needs for edges and material transitions (see world.gdshader). Natural
## ground also gets slopes (see WorldData.slope_mask) and diagonal corners: cut-off
## outer corners and filled inner ones (see WorldData.corner_cut and corner_fill).
## A chunk mesh holds all levels of a 16x16 column; the cutaway hides upper levels
## in the shader, and `build_cap` closes the cut with dark tops. Leaves are not cubes:
## Foliage draws them as leaf clumps.

const Mat := preload("res://src/shared/materials.gd")
const MeshBuffers := preload("res://src/client/mesh_buffers.gd")
const WorldData := preload("res://src/shared/world_data.gd")

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
## Water stands a quarter of a level below the shore, so the bank shows above it.
const WATER_TOP := 0.75
const AIR := Mat.AIR
const WATER := Mat.WATER
const LEAVES := Mat.LEAVES
## Tile index meaning "no texture" (voxels) or "no neighbour" (transitions).
const NO_TILE := 63
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
## A tree trunk is drawn 6 texels wide.
const TRUNK_MIN := 5.0 / 16.0
const TRUNK_MAX := 11.0 / 16.0

static var _faces: Array = []
## Per direction: [corners, uvs, normal] of a whole cell face.
static var _cell_faces: Array = []
static var _covers_lut := PackedByteArray()


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
## Works on a copy of the chunk's cells with a border of one cell (outside the map is
## air, below it is stone), so neighbour lookups are plain array reads.
static func build_chunk(w, x0: int, z0: int, size: int) -> Array:
	var faces := face_table()
	var solid := MeshBuffers.new()
	var water := MeshBuffers.new()
	var sy: int = w.size_y
	var x1 := mini(x0 + size, w.size_x)
	var z1 := mini(z0 + size, w.size_z)
	var c := padded(w, x0 - PAD, z0 - PAD, x1 + PAD, z1 + PAD)
	var cov := covers_table()
	# Strides of the padded grid: +x, +z, +y.
	var dx := 1
	var dz: int = x1 - x0 + 2 * PAD
	var dy: int = dz * (z1 - z0 + 2 * PAD)
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILE * 0x41041)
	var nb := PackedByteArray()
	nb.resize(6)
	var shaped := shapes_and_corners(w, c, x0 - PAD, z0 - PAD, x1 + PAD, z1 + PAD)
	var shapes: PackedByteArray = shaped[0]
	var plan: PackedByteArray = shaped[1]
	var side_offsets := [dx, -dx, 0, 0, dz, -dz]
	for y in sy:
		for z in range(z0, z1):
			var i := (y + 1) * dy + (z - z0 + PAD) * dz + PAD
			for x in range(x0, x1):
				var m := c[i]
				if m == AIR or m == LEAVES:
					if plan[i] >= 16:
						_fill_faces(solid, c, cov, plan, i, dy, dz, Vector3(x, y, z))
					i += 1
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
					_water_faces(w, water, faces, nb, x, y, z, _foam(c, cov, plan, i, dz) | (plan[i] >> 4) << 8)
					if plan[i] >= 16:
						_fill_faces(solid, c, cov, plan, i, dy, dz, base)
				elif m == Mat.LOG and _is_trunk(nb):
					_trunk_faces(solid, faces, nb, base, m)
				elif shapes[i] != FULL:
					_slope_faces(solid, faces, nb, shapes, side_offsets, i, base, m, _around(c, cov, i, dy, dz), plan[i] & 15)
					if plan[i] & 15:
						_cut_water(w, water, c, i, dy, base, plan[i] & 15)
				else:
					var cuts := plan[i] & 15
					for d in 6:
						var n := nb[d]
						if n != AIR and n != WATER and n != LEAVES and shapes[i + side_offsets[d]] == FULL:
							# The ground under a thin trunk still shows around it.
							if not (d == FACE_TOP and n == Mat.LOG and _trunk_at(w, x, y + 1, z)):
								continue
						var tile := m * 3 + (0 if d == FACE_TOP else (2 if d == FACE_BOTTOM else 1))
						var edges := 0
						var flag := 0
						var around := no_tiles
						if d == FACE_TOP:
							edges = _top_edges(c, cov, i, dy, dz)
							around = _around(c, cov, i, dy, dz)
							var halves := _covered_halves(c, plan, i, dy, dz, edges)
							if cuts != 0 or halves != 0:
								_top_pieces(solid, base, m, cuts, edges, halves, around)
								continue
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
						var packed := Vector2(pack(tile, edges, flag), around)
						if cuts != 0:
							_cut_side(solid, faces, d, base, cuts, white, packed)
						else:
							_add_cell_face(solid, d, base, white, packed)
					if cuts != 0:
						_cut_walls(w, solid, water, c, cov, i, dy, base, m, cuts)
					# The ground under a cut corner of the cell above shows there.
					var exposed := plan[i + dy] & 15 & ~cuts if cov[c[i + dy]] else 0
					if exposed != 0:
						var edges := _top_edges(c, cov, i, dy, dz)
						_exposed_tops(solid, c, cov, i, dz, base, m, exposed, edges, _covered_halves(c, plan, i, dy, dz, edges),
							shapes[i + dy] == FULL)
				i += 1
	return [null if solid.is_empty() else solid.to_mesh(), null if water.is_empty() else water.to_mesh()]


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
static func _covered_halves(c: PackedByteArray, plan: PackedByteArray, i: int, dy: int, dz: int, edges: int) -> int:
	# Mostly there are no corners around at all.
	if plan[i - dz] | plan[i + dz] | plan[i - 1] | plan[i + 1] < 16 \
			and (plan[i + dy - dz] | plan[i + dy - 1] | plan[i + dy + 1]) & 15 == 0:
		return 0
	var halves := 0
	for h in 8:
		var e := h >> 1
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
		var bit: int = 1 << HALF_CORNER[h]
		if plan[n] >> 4 & bit or edges >> (2 * e) & 3 == CONTACT and plan[n + dy] & bit:
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
			_piece(buf, base, 1.0, q, CUT, Vector3.UP, white, Vector2(pack(m * 3, e, flag), around))
		else:
			_piece(buf, base, 1.0, q, QUARTER, Vector3.UP, white, Vector2(pack(m * 3, e, 0), around))


## Side `d` of a cell with cut corners: halves of a side next to an uncut corner, the
## bottom in pieces.
static func _cut_side(buf, faces: Array, d: int, base: Vector3, cuts: int, color: Color, packed: Vector2) -> void:
	if d == FACE_BOTTOM:
		for q in 4:
			_piece(buf, base, 0.0, q, CUT if cuts & (1 << q) else QUARTER, Vector3.DOWN, color, packed)
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
		_diag_wall(buf, base, k, true, white, Vector2(pack(m * 3 + 1, edges, flag), no_tiles))
	_cut_water(w, water, c, i, dy, base, cuts)


## Water standing in the cut corners of padded cell `i` beside water with air above.
static func _cut_water(w, water, c: PackedByteArray, i: int, dy: int, base: Vector3, cuts: int) -> void:
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		if cuts & (1 << k) and c[i + o.x] == WATER and c[i + o.x + dy] == AIR:
			var depth := 1
			while depth < 8 and w.get_cell(int(base.x) + o.x, int(base.y) - depth, int(base.z)) == WATER:
				depth += 1
			_piece(water, base, WATER_TOP, k, CORNER, Vector3.UP, Color(1, 1, 1), Vector2(float(1 << (12 + k)), float(depth)))


## Ground filling the corners of open padded cell `i`: a diagonal wall, and its top
## where nothing lies on it.
static func _fill_faces(buf, c: PackedByteArray, cov: PackedByteArray, plan: PackedByteArray, i: int, dy: int,
		dz: int, base: Vector3) -> void:
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILE * 0x41041)
	var fills := plan[i] >> 4
	for k in 4:
		if fills & (1 << k) == 0:
			continue
		var o: Vector2i = CORNER_DIRS[k]
		var mf := c[i + o.x]
		var open_top: bool = not cov[c[i + dy]] and plan[i + dy] >> 4 & (1 << k) == 0
		_diag_wall(buf, base, k, false, white, Vector2(pack(mf * 3 + 1, 0, SLOPE | (OPEN_TOP if open_top else 0)), no_tiles))
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
			_piece(buf, base, 1.0, k, CORNER, Vector3.UP, white, Vector2(pack(mf * 3, edges, flag), no_tiles))


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


## A flat piece of quarter `q` of a cell at height `h` (see QUARTER, CUT, CORNER).
static func _piece(buf, base: Vector3, h: float, q: int, kind: int, n: Vector3, color: Color, packed: Vector2) -> void:
	var o := Vector2(CORNER_DIRS[q])
	var corner := Vector2(0.5, 0.5) + o * 0.5
	var p1 := Vector2(0.5, corner.y)
	var p2 := Vector2(corner.x, 0.5)
	var pts: Array
	if kind == QUARTER:
		pts = [Vector2(0.5, 0.5), p1, corner, p2]
	elif kind == CUT:
		pts = [Vector2(0.5, 0.5), p1 + o * EPS, p2 + o * EPS]
	else:
		pts = [corner, p1 - o * EPS, p2 - o * EPS]
	var vs := []
	for p: Vector2 in pts:
		vs.append(base + Vector3(p.x, h, p.y))
	_wound(buf, vs, n, pts, color, packed)


## The wall along the diagonal of corner k, facing the corner (a cut) or away from it
## (a fill).
static func _diag_wall(buf, base: Vector3, k: int, outward: bool, color: Color, packed: Vector2) -> void:
	var o := Vector2(CORNER_DIRS[k])
	var corner := Vector2(0.5, 0.5) + o * 0.5
	var p1 := Vector2(0.5, corner.y)
	var p2 := Vector2(corner.x, 0.5)
	var n := Vector3(o.x, 0.0, o.y).normalized() * (1.0 if outward else -1.0)
	var vs := [base + Vector3(p1.x, 0.0, p1.y), base + Vector3(p2.x, 0.0, p2.y),
		base + Vector3(p2.x, 1.0, p2.y), base + Vector3(p1.x, 1.0, p1.y)]
	_wound(buf, vs, n, [Vector2(p1.x, 1.0), Vector2(p2.x, 1.0), Vector2(p2.x, 0.0), Vector2(p1.x, 0.0)], color, packed)


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


## Top tiles of the level neighbours N, S, W, E of padded cell `i`, packed for UV2.y
## (material transitions, see world.gdshader).
static func _around(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int) -> float:
	var tn := c[i - dz] * 3 if cov[c[i - dz]] and not cov[c[i - dz + dy]] else NO_TILE
	var ts := c[i + dz] * 3 if cov[c[i + dz]] and not cov[c[i + dz + dy]] else NO_TILE
	var tw := c[i - 1] * 3 if cov[c[i - 1]] and not cov[c[i - 1 + dy]] else NO_TILE
	var te := c[i + 1] * 3 if cov[c[i + 1]] and not cov[c[i + 1 + dy]] else NO_TILE
	return float(tn | ts << 6 | tw << 12 | te << 18)


## Shapes of the padded cells `c` of x0..x1, z0..z1 (exclusive ends): slope masks (see
## WorldData.slope_mask, FULL for everything that is not sloping ground), and corners
## as WorldData shapes them (cut corners in the low 4 bits, filled ones in the high 4,
## bit 1 << k for corner k) for all but the outermost ring. One pass over the copy picks
## the few cells on an edge or in an inner corner before WorldData decides.
static func shapes_and_corners(w, c: PackedByteArray, x0: int, z0: int, x1: int, z1: int) -> Array:
	var shapes := PackedByteArray()
	shapes.resize(c.size())
	shapes.fill(FULL)
	var plan := PackedByteArray()
	plan.resize(c.size())
	var cov := covers_table()
	var sy: int = w.size_y
	var nx := x1 - x0
	var nz := z1 - z0
	var dy := nx * nz
	var cut_cells := PackedInt32Array()
	var fill_cells := PackedInt32Array()
	for y in sy:
		var i := (y + 1) * dy
		for z in nz:
			var inner := z > 0 and z < nz - 1
			for x in nx:
				var m := c[i]
				if m == AIR or m == WATER:
					if inner and x > 0 and x < nx - 1 and (cov[c[i - 1]] or cov[c[i + 1]]) and (cov[c[i - nx]] or cov[c[i + nx]]):
						fill_cells.append(i)
				elif cov[m]:
					if Mat.can_slope(m) and c[i + dy] == AIR:
						shapes[i] = w.slope_mask(x0 + x, y, z0 + z)
					if inner and x > 0 and x < nx - 1 and m != Mat.LOG \
							and not (cov[c[i - 1]] and cov[c[i + 1]] and cov[c[i - nx]] and cov[c[i + nx]]):
						cut_cells.append(i)
				i += 1
	var ox := []
	var oz := []
	for o: Vector2i in CORNER_DIRS:
		ox.append(o.x)
		oz.append(o.y * nx)
	# Cuts from the top down: a corner is cut only under open cells or the same cut.
	for n in range(cut_cells.size() - 1, -1, -1):
		var i := cut_cells[n]
		for k in 4:
			var a := c[i + ox[k]]
			if (a == AIR or a == WATER) and c[i + oz[k]] == a and c[i + ox[k] + oz[k]] == a \
					and (shapes[i] == FULL or shapes[i] & (1 << k) == 0) and (not cov[c[i + dy]] or plan[i + dy] & (1 << k)):
				var r := i % dy
				if w.corner_cut_here(x0 + r % nx, i / dy - 1, z0 + r / nx, k):
					plan[i] |= 1 << k
	# Fills from the bottom up: a fill stands on ground or on the same fill.
	for i in fill_cells:
		for k in 4:
			var a: int = i + ox[k]
			var b: int = i + oz[k]
			if cov[c[a]] and cov[c[b]] and cov[c[a + oz[k]]] and shapes[a] == FULL and shapes[b] == FULL \
					and (cov[c[i - dy]] or plan[i - dy] & (16 << k)):
				var r := i % dy
				if w.corner_fill_here(x0 + r % nx, i / dy - 1, z0 + r / nx, k):
					plan[i] |= 16 << k
	return [shapes, plan]


## A cell with a sloping top: two triangles over the corner heights of its mask, side
## walls cut to the slope where nothing covers them, and the bottom if open. Cut corners
## clip the triangles, halve the side walls and leave a wall up to the slope.
static func _slope_faces(buf, faces: Array, nb: PackedByteArray, shapes: PackedByteArray, side_offsets: Array,
		i: int, base: Vector3, m: int, around: float, cuts: int) -> void:
	var mask := shapes[i]
	var h := [float(mask & WorldData.NW != 0), float(mask & WorldData.NE != 0),
		float(mask & WorldData.SE != 0), float(mask & WorldData.SW != 0)]
	var nw := Vector3(0, h[0], 0)
	var ne := Vector3(1, h[1], 0)
	var se := Vector3(1, h[2], 1)
	var sw := Vector3(0, h[3], 1)
	var tris := [[nw, ne, se], [nw, se, sw]] if WorldData.split_nw_se(mask, cuts) else [[nw, ne, sw], [ne, se, sw]]
	var white := Color(1, 1, 1)
	var top := Vector2(pack(m * 3, 0, SLOPE), around)
	var wall := Vector2(pack(m * 3 + 1, 0, SLOPE), float(NO_TILE * 0x41041))
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var e: Vector3 = t[2]
		var n := -(b - a).cross(e - a).normalized()
		var poly: Array = t
		for k in 4:
			if cuts & (1 << k):
				var clipped := _clip(poly, k)
				poly = clipped[0]
				var ends: Array = clipped[1]
				# The slope ends at the cut in a wall as high as the slope there.
				if ends.size() == 2 and (ends[0].y > 0.01 or ends[1].y > 0.01):
					var p: Vector3 = ends[0]
					var q: Vector3 = ends[1]
					var o := Vector2(CORNER_DIRS[k])
					_wound(buf, [base + Vector3(p.x, 0.0, p.z), base + Vector3(q.x, 0.0, q.z), base + q, base + p],
						Vector3(o.x, 0.0, o.y).normalized(),
						[Vector2(p.x, 1.0), Vector2(q.x, 1.0), Vector2(q.x, 1.0 - q.y), Vector2(p.x, 1.0 - p.y)], white, wall)
		for j in range(1, poly.size() - 1):
			var p0: Vector3 = poly[0]
			var p1: Vector3 = poly[j]
			var p2: Vector3 = poly[j + 1]
			buf.tri([base + p0, base + p1, base + p2], n, [Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), Vector2(p2.x, p2.z)],
				white, top)
	for d in [0, 1, 3, 4, 5]:
		var n := nb[d]
		if n != AIR and n != WATER and n != LEAVES and (d == FACE_BOTTOM or shapes[i + side_offsets[d]] == FULL):
			continue
		var face: Dictionary = faces[d]
		if d == FACE_BOTTOM:
			for q in 4:
				_piece(buf, base, 0.0, q, CUT if cuts & (1 << q) else QUARTER, Vector3.DOWN, white,
					Vector2(pack(m * 3 + 2, 0, 0), float(NO_TILE * 0x41041)))
			continue
		# Corners at both ends of this side and the heights of the slope there.
		var ks: Array = SIDE_CORNERS[d]
		var c0 := Vector2(CORNER_DIRS[ks[0]]) * 0.5 + Vector2(0.5, 0.5)
		var c1 := Vector2(CORNER_DIRS[ks[1]]) * 0.5 + Vector2(0.5, 0.5)
		var h0: float = h[ks[0]]
		var h1: float = h[ks[1]]
		# The whole side, or the halves next to corners that are not cut.
		var spans := [[0.0, 1.0]] if cuts & (1 << ks[0] | 1 << ks[1]) == 0 else [[0.0, 0.5], [0.5, 1.0]]
		for span: Array in spans:
			if cuts & (1 << ks[0 if span[0] < 0.5 else 1]):
				continue
			var a := c0.lerp(c1, span[0])
			var b := c0.lerp(c1, span[1])
			var ha := lerpf(h0, h1, span[0])
			var hb := lerpf(h0, h1, span[1])
			if ha + hb == 0.0:
				continue
			var tile := m * 3 + 1
			_wound(buf, [base + Vector3(a.x, 0.0, a.y), base + Vector3(b.x, 0.0, b.y), base + Vector3(b.x, hb, b.y),
				base + Vector3(a.x, ha, a.y)], face.normal,
				[face_uv(d, Vector3(a.x, 0.0, a.y)), face_uv(d, Vector3(b.x, 0.0, b.y)), face_uv(d, Vector3(b.x, hb, b.y)),
				face_uv(d, Vector3(a.x, ha, a.y))], white, Vector2(pack(tile, 0, 0), float(NO_TILE * 0x41041)))


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


## Copy of the cells in x0..x1, z0..z1 (exclusive ends, may reach outside the map)
## and levels -1..size_y, in that order (x fastest).
static func padded(w, x0: int, z0: int, x1: int, z1: int) -> PackedByteArray:
	var sx: int = w.size_x
	var sy: int = w.size_y
	var sz: int = w.size_z
	var cells: PackedByteArray = w.cells
	var width := x1 - x0
	var air_row := PackedByteArray()
	air_row.resize(width)
	var stone_row := PackedByteArray()
	stone_row.resize(width)
	stone_row.fill(Mat.STONE)
	var left := PackedByteArray()
	left.resize(maxi(0, -x0))
	var right := PackedByteArray()
	right.resize(maxi(0, x1 - sx))
	var a := maxi(x0, 0)
	var b := mini(x1, sx)
	var c := PackedByteArray()
	for y in range(-1, sy + 1):
		for z in range(z0, z1):
			if y < 0:
				c.append_array(stone_row)
			elif y >= sy or z < 0 or z >= sz:
				c.append_array(air_row)
			else:
				var row := (y * sz + z) * sx
				c.append_array(left)
				c.append_array(cells.slice(row + a, row + b))
				c.append_array(right)
	return c


## 1 for materials that hide what is behind them (not air, water or leaves).
static func covers_table() -> PackedByteArray:
	if _covers_lut.is_empty():
		_covers_lut.resize(256)
		for m in 256:
			_covers_lut[m] = 1 if _covers(m) else 0
	return _covers_lut


## Dark tops of solid cells on `level` that are covered by solid cells above:
## what you see in the cut when looking into a mountain. Cut corners stay open, and
## fills sliced by the cut show as dark triangles.
static func build_cap(w, level: int) -> ArrayMesh:
	if level < 0 or level >= w.size_y - 1:
		return null
	var top: Dictionary = face_table()[FACE_TOP]
	var buf := MeshBuffers.new()
	var cells: PackedByteArray = w.cells
	var sx: int = w.size_x
	var sz: int = w.size_z
	var layer: int = sx * sz
	var row: int = level * layer
	var dark := Color(0.4, 0.4, 0.4)
	var no_tiles := float(NO_TILE * 0x41041)
	for z in sz:
		for x in sx:
			var i: int = row + z * sx + x
			var m: int = cells[i]
			var above: int = cells[i + layer]
			var base := Vector3(x, level, z)
			# Only cells beside an open cell or with an open cell beside them above can
			# have shaped corners.
			var edge := x == 0 or z == 0 or x == sx - 1 or z == sz - 1 \
				or not (_covers(cells[i - 1]) and _covers(cells[i + 1]) and _covers(cells[i - sx]) and _covers(cells[i + sx]) \
				and _covers(cells[i + layer - 1]) and _covers(cells[i + layer + 1]) and _covers(cells[i + layer - sx]) \
				and _covers(cells[i + layer + sx]))
			var packed := Vector2(pack(m * 3, 0, 0), no_tiles)
			if _covers(m) and _covers(above):
				var cuts: int = w.corner_cuts(x, level, z) | w.corner_cuts(x, level + 1, z) if edge else 0
				if cuts == 0:
					_add(buf, top, FACE_TOP, base, Vector3.ONE, Vector3.ZERO, dark, packed)
				else:
					for q in 4:
						_piece(buf, base, 1.0, q, CUT if cuts & (1 << q) else QUARTER, Vector3.UP, dark, packed)
			elif (m == AIR or m == WATER) and x > 0 and z > 0 and x < sx - 1 and z < sz - 1 \
					and (_covers(cells[i - 1]) or _covers(cells[i + 1])) and (_covers(cells[i - sx]) or _covers(cells[i + sx])):
				var fills: int = w.corner_fills(x, level, z)
				if fills != 0 and not _covers(above):
					fills &= w.corner_fills(x, level + 1, z)
				for k in 4:
					if fills & (1 << k):
						var o: Vector2i = CORNER_DIRS[k]
						var mf: int = w.get_cell(x + o.x, level, z)
						_piece(buf, base, 1.0, k, CORNER, Vector3.UP, dark, Vector2(pack(mf * 3, 0, 0), no_tiles))
	return null if buf.is_empty() else buf.to_mesh()


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


static func _trunk_faces(buf, faces: Array, nb: PackedByteArray, base: Vector3, m: int) -> void:
	var offset := Vector3(TRUNK_MIN, 0.0, TRUNK_MIN)
	var size := Vector3(TRUNK_MAX - TRUNK_MIN, 1.0, TRUNK_MAX - TRUNK_MIN)
	var white := Color(1, 1, 1)
	for d in 6:
		if (d == FACE_TOP or d == FACE_BOTTOM) and _covers(nb[d]) or d == FACE_TOP and nb[d] == Mat.LOG:
			continue
		var tile := m * 3 + (0 if d == FACE_TOP else 1)
		var edges := 0
		if d == FACE_SOUTH:
			edges = (DARK << EDGE_W) | (DARK << EDGE_E)
		elif d == FACE_TOP:
			edges = (DARK << EDGE_N) | (DARK << EDGE_W) | (DARK << EDGE_E) | (LIGHT << EDGE_S)
		_add(buf, faces[d], d, base, size, offset, white, Vector2(pack(tile, edges, 0), float(NO_TILE * 0x41041)))


## Foam bits of the water in padded cell `i`: the half edges (see HALF_CORNER) that
## touch land, not where the land beside has its corner cut and the water goes on.
static func _foam(c: PackedByteArray, cov: PackedByteArray, plan: PackedByteArray, i: int, dz: int) -> int:
	var foam := 0
	for h in 8:
		var e := h >> 1
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
		if cov[c[n]] and plan[n] & (1 << HALF_CORNER[h]) == 0:
			foam |= 1 << h
	return foam


## Water: the top face carries foam bits (UV2.x: the half edges that touch land, then
## the filled corners, then the cut corners of the land beside, see water.gdshader) and
## the depth to the bottom in cells (UV2.y). Filled corners are left out of the top.
static func _water_faces(w, buf, faces: Array, nb: PackedByteArray, x: int, y: int, z: int, foam: int) -> void:
	if nb[0] != AIR and nb[1] != AIR and nb[2] != AIR and nb[4] != AIR and nb[5] != AIR:
		return
	var h := WATER_TOP if nb[2] == AIR else 1.0
	var depth := 1
	while depth < 8 and w.get_cell(x, y - depth, z) == WATER:
		depth += 1
	var fills := foam >> 8 & 15
	var white := Color(1, 1, 1)
	var data := Vector2(float(foam), float(depth))
	for d in 6:
		if d != FACE_BOTTOM and nb[d] == AIR:
			if d == FACE_TOP and fills != 0:
				for q in 4:
					_piece(buf, Vector3(x, y, z), h, q, CUT if fills & (1 << q) else QUARTER, Vector3.UP, white, data)
				continue
			_add(buf, faces[d], d, Vector3(x, y, z), Vector3(1.0, h, 1.0), Vector3.ZERO, white, data)
