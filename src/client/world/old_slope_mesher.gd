extends "res://src/client/world/mesh_faces.gd"
## The slopes of natural ground (the "old" slopes, every world's since the blocky
## relief was taken out, 2026-11-20): a smooth curved surface over the corner heights
## WorldData shaped (`patch`), shared with the slopes beside it, its sides and the cuts
## where the surface meets a wall; the deep faces under a slope. Called by ChunkMesher a
## column at a time.


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
	return WorldData.make_patch(h, far, c[i + dy] == WATER or shore_top(c, sh, i, dy, dz))


## True when the top of padded ground cell `i` lies at the shore of water on its level
## (see WorldData.shore_top, which tells the same from the world).
static func shore_top(c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int) -> bool:
	var wet := false
	var deep := sh[i - dy] & 15 != 0 and c[i - dy] != AIR and c[i - dy] != WATER
	for o: int in [1, -1, dz, -dz, dz + 1, dz - 1, 1 - dz, -1 - dz]:
		var n := c[i + o]
		if n == WATER:
			wet = wet or c[i + o + dy] == AIR
		elif n == AIR and deep and c[i + o - dy] == WATER:
			wet = true
		elif n == AIR or n == LEAVES:
			return false
	return wet


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
			if corner_height(sh, l, dy, near) + dl == hv:
				return corner_height(sh, l, dy, far) + dl
	return WorldData.NO_CORNER


## Height of corner k of the top of padded ground cell `i` (see _corner_heights).
static func corner_height(sh: PackedByteArray, i: int, dy: int, k: int) -> int:
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


## Heights and normals of patch `p` raised by `lift` at the points of a grid of
## `steps` (x, z) squares, row by row from the north-west.
static func patch_grid(p: PackedFloat32Array, lift: float, steps: Vector2i) -> Array:
	if p.size() > WorldData.PATCH_DIAG:
		return _diag_grid(p, lift, steps)
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


## patch_grid of a shore's corner on the diagonal (see WorldData.PATCH_DIAG): its
## heights from WorldData.patch_height, its normals from the heights beside on the grid,
## straight up where it lies level (from its diagonal on, WorldData.diag_reach): taken
## across the diagonal they leaned the level ground beside it, a band of other shade
## along the water's line.
static func _diag_grid(p: PackedFloat32Array, lift: float, steps: Vector2i) -> Array:
	var nu := steps.x + 1
	var nv := steps.y + 1
	var hs := PackedFloat32Array()
	var ns := PackedVector3Array()
	hs.resize(nu * nv)
	ns.resize(nu * nv)
	for b in nv:
		for a in nu:
			hs[b * nu + a] = lift + WorldData.patch_height(p, float(a) / steps.x, float(b) / steps.y)
	for b in nv:
		for a in nu:
			if WorldData.diag_reach(p, float(a) / steps.x, float(b) / steps.y) >= 1.0 - DIAG_EPS:
				ns[b * nu + a] = Vector3.UP
				continue
			var a0 := maxi(a - 1, 0)
			var a1 := mini(a + 1, steps.x)
			var b0 := maxi(b - 1, 0)
			var b1 := mini(b + 1, steps.y)
			var gx := (hs[b * nu + a1] - hs[b * nu + a0]) * steps.x / (a1 - a0)
			var gz := (hs[b1 * nu + a] - hs[b0 * nu + a]) * steps.y / (b1 - b0)
			ns[b * nu + a] = Vector3(-gx, 1.0, -gz).normalized()
	return [hs, ns]


## Slack in the grid's distances from a diagonal corner (see WorldData.diag_reach).
const DIAG_EPS := 0.001


## True when the grid of patch `p` is split along its squares' diagonals from north-east
## to south-west, not from north-west to south-east: a shore's corner on the diagonal
## (WorldData.PATCH_DIAG) at the north-west or south-east bends along such a line, which
## squares split the other way drew in teeth (the level ground dipped into each
## square's lower triangle), and the flush water's edge along it (WaterMesher.shore_water)
## did not lie on the ground's.
static func crease_flip(p: PackedFloat32Array) -> bool:
	return p.size() > WorldData.PATCH_DIAG and int(p[WorldData.PATCH_DIAG]) & 1 == 0


## A cell with a sloping top: the smooth surface of its patch, cut where its corners
## are cut (with a wall up to the surface there), side walls up to the surface where
## nothing covers them, and the bottom if open.
static func slope_faces(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, nb: PackedByteArray,
		side_offsets: PackedInt32Array, i: int, dy: int, base: Vector3, m: int, around: float, cuts: int) -> void:
	var p := patch(c, sh, i, dy, side_offsets[4])
	var steps := _patch_steps(p, cuts)
	var grid := patch_grid(p, 0.0, steps)
	var hs: PackedFloat32Array = grid[0]
	var ns: PackedVector3Array = grid[1]
	var white := Color(1, 1, 1)
	var top := Vector2(pack(m * 3, 0, SLOPE), around)
	# The level part of an outer corner on the diagonal in the bed's material (see
	# level_bed_material), on its own copies of the grid's points.
	var bed := level_bed_material(c, i, dy, side_offsets[4], p)
	var level := _level_points(p, steps) if bed >= 0 else PackedByteArray()
	var bed_packed := Vector2(pack(bed * 3, 0, SLOPE), float(NO_TILES)) if bed >= 0 else Vector2.ZERO
	if cuts == 0:
		_surface(buf, base, hs, ns, steps, top, crease_flip(p), level, bed_packed)
	else:
		_cut_surface(buf, base, hs, ns, cuts, top, Vector2(pack(m * 3 + 1, 0, SLOPE), float(NO_TILES)),
			crease_flip(p), level, bed_packed)
	var own := _corner_heights(sh, i, dy)
	for d in [0, 1, 3, 4, 5]:
		var nm := nb[d]
		if nm != AIR and nm != WATER and nm != LEAVES and (d == FACE_BOTTOM or sh[i + side_offsets[d]] & 15 == 0):
			continue
		if d == FACE_BOTTOM:
			for q in 4:
				_piece(buf, base, 0.0, q, OLD_CUT if cuts & (1 << q) else QUARTER, Vector3.DOWN, white,
					Vector2(pack(m * 3 + 2, 0, 0), float(NO_TILES)))
			continue
		_patch_side(buf, faces, c, sh, i, dy, side_offsets[d], d, base, m, hs, steps, own, cuts)


## The material of the bed that the level part of an outer corner on the diagonal
## (WorldData.PATCH_DIAG) lies level with: the ground under the water beside it, across
## the corner from its high corner or beside it there; -1 where it is none (dry ground
## beside, or a top with no such part). Drawn in the bank's own material, that part
## stood in the bed in stairs round the cells, which shallow water shows (the user,
## 2026-11-28).
static func level_bed_material(c: PackedByteArray, i: int, dy: int, dz: int, p: PackedFloat32Array) -> int:
	if p.size() <= WorldData.PATCH_DIAG or int(p[WorldData.PATCH_DIAG]) >= 4:
		return -1
	var code := int(p[WorldData.PATCH_DIAG])
	return _bed_beside(c, i, dy, dz, code, int(p[(code + 2) & 3]))


## The bed's material (see level_bed_material) of the level part of the sloping top over
## padded cell `i`, where a cut corner of that top shows `i`'s own top: the cut goes on
## in the bed's material, not the bank's. -1 where that top has none: only an outer
## corner (three corners low) beside water has one. Told from the corners' heights, not
## the whole patch: many cells lie under cut corners.
static func level_bed_under(c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int) -> int:
	var t := i + dy
	var low := sh[t] & 15
	if low != 7 and low != 11 and low != 13 and low != 14 \
			or c[t + 1] != WATER and c[t - 1] != WATER and c[t + dz] != WATER and c[t - dz] != WATER:
		return -1
	var h := _corner_heights(sh, t, dy)
	var code := WorldData.diag_corner(h)
	if code < 0 or code >= 4 or not (c[t + dy] == WATER or shore_top(c, sh, t, dy, dz)):
		return -1
	return _bed_beside(c, t, dy, dz, code, h[(code + 2) & 3])


## The ground under the water beside padded cell `i` whose top lies at `level` (0 the
## bottom of `i`'s level, -1 a level lower), across the far corner of outer corner `code`
## or beside it there: its material, or -1.
static func _bed_beside(c: PackedByteArray, i: int, dy: int, dz: int, code: int, level: int) -> int:
	if level > 0:
		return -1
	var o: Vector2i = CORNER_DIRS[(code + 2) & 3]
	for j: int in [i + o.x + o.y * dz, i + o.x, i + o.y * dz]:
		# The ground whose top is at the level part's height, water over it.
		var g := j + (level - 1) * dy
		if g >= 0 and c[g + dy] == WATER and Mat.is_solid(c[g]) and c[g] != LEAVES \
				and (level == 0 or c[j] == AIR or c[j] == WATER):
			return c[g]
	return -1


## Which points of the grid of `steps` squares lie in the level part of a top's corner on
## the diagonal (WorldData.diag_reach), 1 each.
static func _level_points(p: PackedFloat32Array, steps: Vector2i) -> PackedByteArray:
	var nu := steps.x + 1
	var out := PackedByteArray()
	out.resize(nu * (steps.y + 1))
	for b in steps.y + 1:
		for a in nu:
			if WorldData.diag_reach(p, float(a) / steps.x, float(b) / steps.y) >= 1.0 - DIAG_EPS:
				out[b * nu + a] = 1
	return out


## The grid of a surface as triangles sharing its points (they are many on a slope),
## its squares split as `flip` says (see crease_flip). `level` (see _level_points): the
## triangles all of whose points are level take `level_packed` (the bed's material, see
## level_bed_material) on their own copies of the points.
static func _surface(buf, base: Vector3, hs: PackedFloat32Array, ns: PackedVector3Array, steps: Vector2i,
		packed: Vector2, flip := false, level := PackedByteArray(), level_packed := Vector2.ZERO) -> void:
	var start: int = buf.verts.size()
	var nu := steps.x + 1
	var count := nu * (steps.y + 1)
	var white := Color(1, 1, 1)
	for copy in (1 if level.is_empty() else 2):
		for b in steps.y + 1:
			var z := float(b) / steps.y
			for a in nu:
				var x := float(a) / steps.x
				buf.verts.append(base + Vector3(x, hs[b * nu + a], z))
				buf.normals.append(ns[b * nu + a])
				buf.uvs.append(Vector2(x, z))
				buf.uv2s.append(packed if copy == 0 else level_packed)
				buf.colors.append(white)
	# Clockwise from above (Godot front faces).
	var tris := PackedInt32Array([0, 1, nu, 1, nu + 1, nu]) if flip \
		else PackedInt32Array([0, 1, nu + 1, 0, nu + 1, nu])
	for b in steps.y:
		for a in steps.x:
			var j := b * nu + a
			if level.is_empty():
				for t in tris:
					buf.indices.append(start + j + t)
				continue
			for t in 2:
				var q0: int = j + tris[3 * t]
				var q1: int = j + tris[3 * t + 1]
				var q2: int = j + tris[3 * t + 2]
				var off := start + (count if level[q0] + level[q1] + level[q2] == 3 else 0)
				buf.indices.append(off + q0)
				buf.indices.append(off + q1)
				buf.indices.append(off + q2)


## Cut walls lower than this, in cells, would be thinner than a pixel: drawn, they show
## as a dotted line that comes and goes as the view moves. The surface comes down onto
## the cut there instead (see _onto_cut).
const LOW_CUT := 0.125


## The surface of a sloping top with cut corners: each triangle of the grid clipped to
## the cuts, with a wall at each cut as high as the slope there; its squares split as
## `flip` says and the level part in `level_packed` as in _surface.
static func _cut_surface(buf, base: Vector3, hs: PackedFloat32Array, ns: PackedVector3Array,
		cuts: int, top: Vector2, wall: Vector2, flip := false, level := PackedByteArray(),
		level_packed := Vector2.ZERO) -> void:
	var white := Color(1, 1, 1)
	var n := PATCH_STEPS + 1
	var step := 1.0 / PATCH_STEPS
	for b in PATCH_STEPS:
		for a in PATCH_STEPS:
			var j00 := b * n + a
			var q00 := _onto_cut(Vector3(a * step, hs[j00], b * step), cuts)
			var q10 := _onto_cut(Vector3((a + 1) * step, hs[j00 + 1], b * step), cuts)
			var q11 := _onto_cut(Vector3((a + 1) * step, hs[j00 + n + 1], (b + 1) * step), cuts)
			var q01 := _onto_cut(Vector3(a * step, hs[j00 + n], (b + 1) * step), cuts)
			# The square's two triangles (clockwise from above), the points of each by
			# their place in the grid.
			var t0: Array = [q00, q10, q01, j00, j00 + 1, j00 + n] if flip else [q00, q10, q11, j00, j00 + 1, j00 + n + 1]
			var t1: Array = [q10, q11, q01, j00 + 1, j00 + n + 1, j00 + n] if flip \
				else [q00, q11, q01, j00, j00 + n + 1, j00 + n]
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
			for tri: Array in [t0, t1]:
				var packed := top
				if not level.is_empty() and level[tri[3]] + level[tri[4]] + level[tri[5]] == 3:
					packed = level_packed
				var a0: Vector3 = tri[0]
				var a1: Vector3 = tri[1]
				var a2: Vector3 = tri[2]
				if whole:
					buf.tri_n([base + a0, base + a1, base + a2], [ns[tri[3]], ns[tri[4]], ns[tri[5]]],
						[Vector2(a0.x, a0.z), Vector2(a1.x, a1.z), Vector2(a2.x, a2.z)], white, packed)
					continue
				var t: Array = [a0, a1, a2, ns[tri[3]], ns[tri[4]], ns[tri[5]]]
				var poly: Array = [a0, a1, a2]
				for k in 4:
					if cuts & (1 << k) and not poly.is_empty():
						var clipped := _clip(poly, k)
						poly = clipped[0].map(_onto_cut.bind(cuts))
						var ends: Array = clipped[1].map(_onto_cut.bind(cuts))
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
					buf.tri_n([base + pts[0], base + pts[1], base + pts[2]], nrm, uvs, white, packed)


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
static func deep_faces(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, nb: PackedByteArray,
		side_offsets: PackedInt32Array, i: int, dy: int, base: Vector3, m: int) -> void:
	var p := patch(c, sh, i + dy, dy, side_offsets[4])
	var steps := _patch_steps(p, 0)
	var hs: PackedFloat32Array = patch_grid(p, 1.0, steps)[0]
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
	var packed := Vector2(pack(m * 3 + 1, 0, 0), float(NO_TILES))
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


## The ground under the cut corners `cuts` of the slope above deep cell `i` (base `base`
## of that slope's cell): level with the slope's foot where the slope stands higher (its
## cut wall rises from there), the slope's own surface where it goes on down into cell
## `i`, so it meets the cut edge of the slope and the ground beside without a gap
## (2026-11-18: a hole showed there). `tops[k]`: the packed tile of corner k.
static func cut_floor(buf, c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int, base: Vector3,
		cuts: int, tops: Array) -> void:
	var p := patch(c, sh, i + dy, dy, dz)
	var hs: PackedFloat32Array = patch_grid(p, 0.0, Vector2i(PATCH_STEPS, PATCH_STEPS))[0]
	var white := Color(1, 1, 1)
	var n := PATCH_STEPS + 1
	var step := 1.0 / PATCH_STEPS
	for k in 4:
		if cuts & (1 << k) == 0:
			continue
		for b in PATCH_STEPS:
			for a in PATCH_STEPS:
				var j := b * n + a
				var q00 := Vector3(a * step, minf(hs[j], 0.0), b * step)
				var q10 := Vector3((a + 1) * step, minf(hs[j + 1], 0.0), b * step)
				var q11 := Vector3((a + 1) * step, minf(hs[j + n + 1], 0.0), (b + 1) * step)
				var q01 := Vector3(a * step, minf(hs[j + n], 0.0), (b + 1) * step)
				for t: Array in [[q00, q10, q11], [q00, q11, q01]]:
					var poly: Array = _clip(t, k, -1.0)[0]
					for v in range(1, poly.size() - 1):
						var pts: Array = [poly[0], poly[v], poly[v + 1]]
						var nrm: Vector3 = (pts[2] - pts[0]).cross(pts[1] - pts[0])
						if nrm.length_squared() < 1e-12:
							continue
						nrm = nrm.normalized()
						if nrm.y < 0.0:
							nrm = -nrm
						buf.tri_n([base + pts[0], base + pts[1], base + pts[2]], [nrm, nrm, nrm],
							[Vector2(pts[0].x, pts[0].z), Vector2(pts[1].x, pts[1].z), Vector2(pts[2].x, pts[2].z)],
							white, tops[k])


## Clips a convex polygon of points in a cell (x, z in 0..1, y the height) to the side of
## the diagonal of corner k away from the corner (with `side` -1, to the corner's side).
## Returns the polygon and the points where it crosses the diagonal, in the order they
## were found.
static func _clip(poly: Array, k: int, side := 1.0) -> Array:
	var out := []
	var ends := []
	var count := poly.size()
	for j in count:
		var p: Vector3 = poly[j]
		var q: Vector3 = poly[(j + 1) % count]
		var dp := _keep(k, p) * side
		var dq := _keep(k, q) * side
		if dp >= 0.0:
			out.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			var x := p.lerp(q, dp / (dp - dq))
			out.append(x)
			ends.append(x)
	return [out, ends]


## Point q of a cut surface, brought down onto a cut of `cuts` it lies on where the
## wall there would be lower than LOW_CUT.
static func _onto_cut(q: Vector3, cuts: int) -> Vector3:
	# (Not where the slope goes on down into the cell below: the ground under the cut
	# follows it there, see cut_floor.)
	if q.y < LOW_CUT and q.y > 0.0:
		for k in 4:
			if cuts & (1 << k) and absf(_keep(k, q)) < 0.0001:
				q.y = 0.0
	return q


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
