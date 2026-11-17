extends "res://src/client/world/mesh_faces.gd"
## The slopes of natural ground: two flat triangles over the corner heights WorldData
## shaped, split along the diagonal WorldData.split_ne_sw picks (a hip, a valley or a
## chamfer), the half beyond the diagonal of a cut corner left out with a wall up to the
## surface there, and side walls up to the surface where the column beside does not
## meet it. Called by ChunkMesher a column at a time.


## Steps of the grid WaterMesher lays water over a shore's slope with (surface_grid).
const PATCH_STEPS := 4


## Height of corner k of the top of padded ground cell `i` above its level: 1 high, 0
## low (see WorldData.corner_heights).
static func corner_height(sh: PackedByteArray, i: int, _dy: int, k: int) -> int:
	return 0 if sh[i] & (1 << k) else 1


## Whether the top of padded cell `i` is split along NE-SW (see WorldData.split_ne_sw).
static func split(sh: PackedByteArray, i: int, dz: int, dy := 0) -> bool:
	return WorldData.split_ne_sw(sh[i], sh[i - dz], sh[i + dz], sh[i - 1], sh[i + 1], sh[i + dy] if dy != 0 else 0)


## Heights of the top of padded cell `i` at the points of a grid of `steps` squares, row
## by row from the north-west.
static func surface_grid(_c: PackedByteArray, sh: PackedByteArray, i: int, _dy: int, dz: int,
		steps: Vector2i) -> PackedFloat32Array:
	var s := sh[i] & 15
	var ne_sw := split(sh, i, dz)
	var hs := PackedFloat32Array()
	hs.resize((steps.x + 1) * (steps.y + 1))
	for b in steps.y + 1:
		for a in steps.x + 1:
			hs[b * (steps.x + 1) + a] = WorldData.top_height(s, ne_sw, float(a) / steps.x, float(b) / steps.y)
	return hs


## A cell with a sloping top: its two triangles (one when a corner is cut, with a wall
## up to the surface along the cut's diagonal), side walls up to the surface where the
## cell beside does not reach as high, and the bottom if open. With `only` a corner k,
## the ground under a cut at k (WorldData._floor_slopes): only the triangle at k and the
## sides beside it.
static func slope_faces(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, nb: PackedByteArray,
		side_offsets: PackedInt32Array, i: int, dy: int, base: Vector3, m: int, around: float, cuts: int,
		only := -1) -> void:
	var dz := side_offsets[4]
	var s := sh[i]
	var h := PackedFloat32Array()
	for k in 4:
		h.append(0.0 if s & (1 << k) else 1.0)
	var ne_sw := split(sh, i, dz, dy if only >= 0 else 0)
	var white := Color(1, 1, 1)
	var cut := -1 if cuts == 0 else WorldData.level_of(cuts & -cuts)
	if only >= 0:
		# Drawn as if cut at the opposite corner: the triangle at `only` is left.
		cut = (only + 2) & 3
	var flag := SLOPE | (_diag(cut, false, DARK) if cut >= 0 and only < 0 else 0)
	if only >= 0:
		# Under the cell above: lit and snowed on as the open column beyond the corner.
		flag = SLOPE | _diag(only, true, 0)
	var top := Vector2(pack(m * 3, 0, flag), around)
	# The triangles by the corners they join, each named by the corner it holds alone.
	var tris: Array = [[0, 1, 3], [1, 2, 3]] if ne_sw else [[0, 1, 2], [0, 2, 3]]
	var alone: Array = [0, 2] if ne_sw else [1, 3]
	for t in 2:
		if alone[t] == cut:
			continue
		var tri: Array = tris[t]
		var vs := []
		var uvs := []
		for k: int in tri:
			var p := Vector2(CORNER_DIRS[k]) * 0.5 + Vector2(0.5, 0.5)
			if cut >= 0 and k != alone[t]:
				# The corners on the cut's diagonal reach a little past it.
				p -= Vector2(CORNER_DIRS[cut]) * EPS
			vs.append(base + Vector3(p.x, h[k], p.y))
			uvs.append(p)
		var n: Vector3 = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized()
		if n.y < 0.0:
			n = -n
		_wound(buf, vs, n, uvs, white, top)
	if cut >= 0 and only < 0:
		var edges := 0 if cover(c[i - dy]) else DARK << EDGE_S
		var wall := Vector2(pack(m * 3 + 1, edges, SLOPE | OPEN_TOP), float(NO_TILES))
		_diag_wall(buf, base, cut, true, white, wall, 0, h[cut ^ 1], h[3 - cut])
	var packed := Vector2(pack(m * 3 + 1, 0, 0), float(NO_TILES))
	for d in [0, 1, 4, 5]:
		var ks: Array = SIDE_CORNERS[d]
		if cut >= 0 and (ks[0] == cut or ks[1] == cut):
			continue
		if only >= 0 and ks[0] != only and ks[1] != only:
			continue
		var h0: float = h[ks[0]]
		var h1: float = h[ks[1]]
		if h0 == 0.0 and h1 == 0.0:
			continue
		var j := i + side_offsets[d]
		if cover(nb[d]):
			# Ground beside on this level: its top meets this one where it is a whole
			# cube or slopes as high along this side.
			var o := sh[j]
			if o & 15 == 0 and o < 16:
				continue
			var m0: int = ks[0] ^ 1 if d < 2 else 3 - ks[0]
			var m1: int = ks[1] ^ 1 if d < 2 else 3 - ks[1]
			# Its corner is high where not down and not cut (a cut corner shows the
			# ground under it, lower still).
			var down := o | o >> 4
			if (down & (1 << m0) == 0 or h0 == 0.0) and (down & (1 << m1) == 0 or h1 == 0.0):
				continue
		var face: Dictionary = faces[d]
		var a := Vector2(CORNER_DIRS[ks[0]]) * 0.5 + Vector2(0.5, 0.5)
		var b := Vector2(CORNER_DIRS[ks[1]]) * 0.5 + Vector2(0.5, 0.5)
		var vs := [base + Vector3(a.x, 0.0, a.y), base + Vector3(b.x, 0.0, b.y)]
		var uvs := [face_uv(d, Vector3(a.x, 0.0, a.y)), face_uv(d, Vector3(b.x, 0.0, b.y))]
		if h1 > 0.0:
			vs.append(base + Vector3(b.x, h1, b.y))
			uvs.append(face_uv(d, Vector3(b.x, h1, b.y)))
		if h0 > 0.0:
			vs.append(base + Vector3(a.x, h0, a.y))
			uvs.append(face_uv(d, Vector3(a.x, h0, a.y)))
		_wound(buf, vs, face.normal, uvs, white, packed)
	if not cover(nb[FACE_BOTTOM]) and only < 0:
		for q in 4:
			_piece(buf, base, 0.0, q, cut_kind(cuts), Vector3.DOWN, white, Vector2(pack(m * 3 + 2, 0, 0), float(NO_TILES)))


## Whether material `m` hides what is behind it (not air, water or leaves).
static func cover(m: int) -> bool:
	return m != AIR and m != WATER and m != LEAVES
