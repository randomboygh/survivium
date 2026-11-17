extends "res://src/client/world/mesh_faces.gd"
## The slopes of natural ground: two flat triangles over the corner heights WorldData
## shaped, split along the diagonal WorldData.split_ne_sw picks (a hip, a valley or a
## chamfer), the half beyond the diagonal of a cut corner left out with a wall up to the
## surface there, and side walls up to the surface where the column beside does not
## meet it. Called by ChunkMesher a column at a time.


## Steps of the grid WaterMesher lays water over a shore's slope with (surface_grid).
const PATCH_STEPS := 4

## The lines a rounded slope's top is drawn on, across the cell where its height changes
## (both ends bend, the middle is straight).
static var BENT_LINES := PackedFloat32Array([0.0, 0.125, 0.25, 0.5, 0.75, 0.875, 1.0])
static var STRAIGHT_LINES := PackedFloat32Array([0.0, 1.0])
## The tops of rounded slopes made so far, by their corners, split, cut and rounding
## (MeshBuffers.shape's [verts, normals, uvs, indices], at the origin).
static var _bent_tops := {}
const BENT_TOPS_MAX := 2048
## How far in from the cell's sides the rounding of a hip fades out: the cells beside
## meet the top there as it is without.
const HIP_FADE := 0.25


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
## sides beside it. A radius `r` (rounding) bends its brow and foot where flat ground
## goes on beyond them (`bends`, see corner_bends) and rounds its hips (see bend); `job` is
## ChunkMesher's, for the rounding of the slopes beside.
static func slope_faces(buf, faces: Array, c: PackedByteArray, sh: PackedByteArray, nb: PackedByteArray,
		side_offsets: PackedInt32Array, i: int, dy: int, base: Vector3, m: int, around: float, cuts: int,
		only := -1, r := 0.0, bends := 0, job = null) -> void:
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
	if r > 0.0:
		buf.shape(base, _bent_top(h, ne_sw, cut, r, bends), white, top)
	# The triangles by the corners they join, each named by the corner it holds alone.
	var tris: Array = [[0, 1, 3], [1, 2, 3]] if ne_sw else [[0, 1, 2], [0, 2, 3]]
	var alone: Array = [0, 2] if ne_sw else [1, 3]
	for t in 2:
		if alone[t] == cut or r > 0.0:
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
		if r > 0.0 and h[cut ^ 1] != h[3 - cut]:
			var o := Vector2(CORNER_DIRS[cut])
			var curve := corner_curve(cut)
			var qs := BENT_LINES
			_bent_wall(buf, base, curve[0] - o * EPS, curve[1] - o * EPS, Vector3(o.x, 0.0, o.y).normalized(), -1, qs,
				_bent_line(h[cut ^ 1], h[3 - cut], cut ^ 1, 3 - cut, qs, r, bends), _zeros(qs.size()), wall)
		else:
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
		var a := Vector2(CORNER_DIRS[ks[0]]) * 0.5 + Vector2(0.5, 0.5)
		var b := Vector2(CORNER_DIRS[ks[1]]) * 0.5 + Vector2(0.5, 0.5)
		var face: Dictionary = faces[d]
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
				if job != null and h0 != h1 and o & 15 != 0 and o < 16:
					_bend_gap(buf, job, j, base, a, b, face.normal, d, h0, h1, ks[0], ks[1], r, bends)
				continue
		if r > 0.0 and h0 != h1:
			var qs := BENT_LINES
			_bent_wall(buf, base, a, b, face.normal, d, qs, _bent_line(h0, h1, ks[0], ks[1], qs, r, bends), _zeros(qs.size()), packed)
			continue
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


## The radius the slopes of padded cell `i` of material `m` round by, for ChunkMesher's
## job: the material's edge_size on natural ground of a material that rounds, else 0
## (drawn flat, as built; hard ground keeps its slopes' edges).
## How far the slopes of a world with soft slopes bend at the brow and the foot, every
## material alike: half a cell, so a ramp between level ground curves over its whole cell.
const SOFT_RADIUS := 0.5


static func rounding(job, i: int, m: int) -> float:
	if job.wild.is_empty() or not job.soft and Mat.edge_mode[m] != Mat.EDGE_ROUND:
		return 0.0
	var dy: int = job.dy
	var y := i / dy - 1
	if y < 0 or (job.wild[i % dy] >> y) & 1 == 0:
		return 0.0
	return SOFT_RADIUS if job.soft else Mat.edge_size[m]


## Where the top of padded cell `i` may bend, by its corners: bit k where the ground
## goes on level beyond corner k at the top of the level (a brow: nothing over the
## level round the corner), bit 4 + k where it does at its floor (a foot: every cell
## under the level round the corner a whole top). Where a slope goes on up or down
## past a corner it stays straight there. Told by the corners, so the cells round a
## corner agree; blended over the cell by _corner_mix.
static func corner_bends(job, i: int) -> int:
	if job.wild.is_empty():
		return 0
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dy: int = job.dy
	var dz: int = job.dz
	var out := 0
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var crest := true
		var foot := true
		for f: int in [0, o.x, o.y * dz, o.x + o.y * dz]:
			if cov[c[i + dy + f]]:
				crest = false
			var j := i - dy + f
			if not cov[c[j]] or sh[j] != 0:
				foot = false
		# Only a high corner has a brow beyond it, only a low one a foot.
		var low := sh[i] & (1 << k) != 0
		if crest and not low:
			out |= 1 << k
		if foot and low:
			out |= 16 << k
	return out


## The shape the brow and the foot of a slope bend by: phi(0) = 0, phi(1) = 1, level at
## 0 and as steep as the slope at 1.
static func _phi(t: float) -> float:
	return t * t * (2.0 - t)


## The height of a slope bent at its brow and foot, from its plain height `b` (0..1 over
## its level): within `r` of the top it curves to lie level at it as much as `crest`
## (0..1) says, within `r` of the floor as much as `foot`; between them it stays.
static func bend(b: float, r: float, crest: float, foot: float) -> float:
	b = clampf(b, 0.0, 1.0)
	if r <= 0.0:
		return b
	if b > 1.0 - r:
		return b + crest * (1.0 - r * _phi((1.0 - b) / r) - b)
	if b < r:
		return b + foot * (r * _phi(b / r) - b)
	return b


## The gradient of `bend` over (b, crest, foot).
static func _bend_grad(b: float, r: float, crest: float, foot: float) -> Vector3:
	b = clampf(b, 0.0, 1.0)
	if r <= 0.0:
		return Vector3(1.0, 0.0, 0.0)
	if b > 1.0 - r:
		var t := (1.0 - b) / r
		return Vector3(1.0 + crest * (t * (4.0 - 3.0 * t) - 1.0), 1.0 - r * _phi(t) - b, 0.0)
	if b < r:
		var t := b / r
		return Vector3(1.0 + foot * (t * (4.0 - 3.0 * t) - 1.0), 0.0, r * _phi(t) - b)
	return Vector3(1.0, 0.0, 0.0)


## The heights of a bent top along a side or a diagonal from corner `k0` (height `h0`)
## to `k1` (`h1`), at the points `qs`.
static func _bent_line(h0: float, h1: float, k0: int, k1: int, qs: PackedFloat32Array, r: float,
		bends: int) -> PackedFloat32Array:
	var c0 := float((bends >> k0) & 1)
	var c1 := float((bends >> k1) & 1)
	var f0 := float((bends >> (4 + k0)) & 1)
	var f1 := float((bends >> (4 + k1)) & 1)
	var out := PackedFloat32Array()
	for q: float in qs:
		out.append(bend(lerpf(h0, h1, q), r, minf(1.0, lerpf(c0, c1, q) / (1.0 - r)),
			minf(1.0, lerpf(f0, f1, q) / (1.0 - r))))
	return out


## The height of the bent top of padded slope cell `j` at point `l` of its side (0..1 in
## the cell), for the walls of the cells beside.
static func bent_height(job, j: int, l: Vector2) -> float:
	var s: int = job.sh[j]
	var u := clampf(l.x, 0.0, 1.0)
	var v := clampf(l.y, 0.0, 1.0)
	var h := PackedFloat32Array()
	for k in 4:
		h.append(0.0 if s & (1 << k) else 1.0)
	var b := lerpf(lerpf(h[0], h[1], u), lerpf(h[3], h[2], u), v)
	var r := rounding(job, j, job.c[j])
	if r <= 0.0:
		return b
	var bends := corner_bends(job, j)
	return bend(b, r, _corner_mix(bends, u, v, r), _corner_mix(bends >> 4, u, v, r))


## The flags of the four corners (bits 0..3 of `bits`) blended over the cell at (u, v),
## whole within `r` of a flagged corner's height (a straight slope's brow and foot bend
## all along).
static func _corner_mix(bits: int, u: float, v: float, r: float) -> float:
	var w := lerpf(lerpf(float(bits & 1), float((bits >> 1) & 1), u), lerpf(float((bits >> 3) & 1), float((bits >> 2) & 1), u), v)
	return minf(1.0, w / (1.0 - r))


## The planes of the two triangles of a top with corner heights `h` (NW, NE, SE, SW),
## split along NE-SW or not, each as Vector3(height at the NW corner, d/dx, d/dz); the
## first holds corner 0 (NE-SW) or 1, the second corner 2 or 3 (see slope_faces).
static func _planes(h: PackedFloat32Array, ne_sw: bool) -> Array:
	if ne_sw:
		return [Vector3(h[0], h[1] - h[0], h[3] - h[0]),
			Vector3(h[2] - (h[2] - h[3]) - (h[2] - h[1]), h[2] - h[3], h[2] - h[1])]
	return [Vector3(h[0], h[1] - h[0], h[2] - h[1]), Vector3(h[0], h[2] - h[3], h[3] - h[0])]


## The plain height of a top at (x, z) with its gradient, Vector3(b, db/dx, db/dz):
## the plane of triangle `side`, or where a hip or a valley runs between the two
## (`crease` 1 a hip, -1 a valley, 0 none), the two blended within about `r` of it,
## fading out toward the cell's sides (HIP_FADE), where the cells beside meet it.
static func _plain(planes: Array, side: int, crease: int, x: float, z: float, r: float) -> Vector3:
	var pa: Vector3 = planes[side]
	var own := Vector3(pa.x + pa.y * x + pa.z * z, pa.y, pa.z)
	if crease == 0 or r <= 0.0:
		return own
	var k := r * clampf(minf(minf(x, 1.0 - x), minf(z, 1.0 - z)) / HIP_FADE, 0.0, 1.0)
	if k <= 0.0001:
		return own
	var pb: Vector3 = planes[1 - side]
	var other := Vector3(pb.x + pb.y * x + pb.z * z, pb.y, pb.z)
	# As a hip (the lower plane, rounded down); a valley the same upside down.
	var a := own * crease
	var b := other * crease
	var lo := a if a.x <= b.x else b
	var hi := b if a.x <= b.x else a
	var gap := hi.x - lo.x
	if gap >= k:
		return lo * crease
	var w := (k - gap) / k
	return Vector3(lo.x - w * w * k * 0.25, lo.y * (1.0 - w * 0.5) + hi.y * w * 0.5,
		lo.z * (1.0 - w * 0.5) + hi.z * w * 0.5) * crease


## The bent top of a slope (see bend) with corner heights `h`, split along NE-SW or not,
## less the triangle holding corner `cut` (-1 none), rounded by `r` where `bends` say;
## made once for each and kept (MeshBuffers.shape's arrays, at the origin).
static func _bent_top(h: PackedFloat32Array, ne_sw: bool, cut: int, r: float, bends: int) -> Array:
	var key := Vector4i(int(h[0]) | int(h[1]) << 1 | int(h[2]) << 2 | int(h[3]) << 3 | int(ne_sw) << 4,
		cut, roundi(r * 1000.0), bends)
	var got = _bent_tops.get(key)
	if got != null:
		return got
	var planes := _planes(h, ne_sw)
	var crease := 0
	if cut < 0:
		# Which way the top folds along the diagonal, told in the middle of the first triangle.
		var pa: Vector3 = planes[0]
		var pb: Vector3 = planes[1]
		var m := Vector2(1.0 / 3.0, 1.0 / 3.0) if ne_sw else Vector2(2.0 / 3.0, 1.0 / 3.0)
		var da := pa.x + pa.y * m.x + pa.z * m.y
		var db := pb.x + pb.y * m.x + pb.z * m.y
		crease = 0 if absf(da - db) < 0.0001 else (1 if da < db else -1)
	# Straight where nothing bends (the middle of a long slope).
	var plain := bends == 0 and crease == 0
	var xs := BENT_LINES if (h[0] != h[1] or h[3] != h[2]) and not plain else STRAIGHT_LINES
	var zs := BENT_LINES if (h[0] != h[3] or h[1] != h[2]) and not plain else STRAIGHT_LINES
	var cb := bends & 15
	var fb := (bends >> 4) & 15
	# How the corner flags change over the cell (see _corner_mix), for the normals.
	var cs := Vector4(cb & 1, (cb >> 1) & 1, (cb >> 2) & 1, (cb >> 3) & 1)
	var fs := Vector4(fb & 1, (fb >> 1) & 1, (fb >> 2) & 1, (fb >> 3) & 1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var at := {}
	var off := Vector2(CORNER_DIRS[cut]) * -EPS if cut >= 0 else Vector2.ZERO
	for bz in zs.size() - 1:
		for bx in xs.size() - 1:
			var x0 := xs[bx]
			var x1 := xs[bx + 1]
			var z0 := zs[bz]
			var z1 := zs[bz + 1]
			var tris: Array = [[Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1)],
				[Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]] if ne_sw else \
				[[Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1)],
				[Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)]]
			for tri: Array in tris:
				var mid: Vector2 = (tri[0] + tri[1] + tri[2]) / 3.0
				var side := (0 if mid.x + mid.y < 1.0 else 1) if ne_sw else (0 if mid.x > mid.y else 1)
				var alone := (0 if side == 0 else 2) if ne_sw else (1 if side == 0 else 3)
				if alone == cut:
					continue
				for pt: Vector2 in tri:
					var on_diag := absf(pt.x + pt.y - 1.0) < 0.0001 if ne_sw else absf(pt.x - pt.y) < 0.0001
					var vk := Vector3(pt.x, pt.y, side if on_diag else -1)
					var v = at.get(vk)
					if v == null:
						v = verts.size()
						at[vk] = v
						var pl := _plain(planes, side, crease, pt.x, pt.y, r)
						var wc := _corner_mix(cb, pt.x, pt.y, r)
						var wf := _corner_mix(fb, pt.x, pt.y, r)
						var g := _bend_grad(pl.x, r, wc, wf)
						# Where a blend is whole it stays so: no slope of its own.
						var gc := 0.0 if wc >= 1.0 else 1.0 / (1.0 - r)
						var gf := 0.0 if wf >= 1.0 else 1.0 / (1.0 - r)
						var cx := lerpf(cs.y - cs.x, cs.z - cs.w, pt.y) * gc
						var cz := lerpf(cs.w - cs.x, cs.z - cs.y, pt.x) * gc
						var fx := lerpf(fs.y - fs.x, fs.z - fs.w, pt.y) * gf
						var fz := lerpf(fs.w - fs.x, fs.z - fs.y, pt.x) * gf
						var dx := g.x * pl.y + g.y * cx + g.z * fx
						var dz := g.x * pl.z + g.y * cz + g.z * fz
						var q := pt + off if on_diag else pt
						verts.append(Vector3(q.x, bend(pl.x, r, wc, wf), q.y))
						normals.append(Vector3(-dx, 1.0, -dz).normalized())
						uvs.append(q)
					indices.append(v)
	got = [verts, normals, uvs, indices]
	if _bent_tops.size() >= BENT_TOPS_MAX:
		_bent_tops.clear()
	_bent_tops[key] = got
	return got


## A wall from `bottoms` up to `tops` at the points `qs` along p1..p2 (in the cell, at
## `base`), facing `n`: the side or the cut of a bent slope, whose top curves. `d` the
## face it lies in (its UVs as face_uv's) or -1 for a diagonal (UVs by x and height).
static func _bent_wall(buf, base: Vector3, p1: Vector2, p2: Vector2, n: Vector3, d: int, qs: PackedFloat32Array,
		tops: PackedFloat32Array, bottoms: PackedFloat32Array, packed: Vector2) -> void:
	var white := Color(1, 1, 1)
	for g in qs.size() - 1:
		var a := p1.lerp(p2, qs[g])
		var b := p1.lerp(p2, qs[g + 1])
		var ta := tops[g]
		var tb := tops[g + 1]
		var ba := bottoms[g]
		var bb := bottoms[g + 1]
		if ta - ba < 0.0005 and tb - bb < 0.0005:
			continue
		var pts := [Vector3(a.x, ba, a.y), Vector3(b.x, bb, b.y)]
		if tb - bb >= 0.0005:
			pts.append(Vector3(b.x, tb, b.y))
		if ta - ba >= 0.0005:
			pts.append(Vector3(a.x, ta, a.y))
		var vs := []
		var uvs := []
		for p: Vector3 in pts:
			vs.append(base + p)
			uvs.append(face_uv(d, p) if d >= 0 else Vector2(p.x, 1.0 - p.y))
		_wound(buf, vs, n, uvs, white, packed)


static func _zeros(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	return out


## Where the slope beside (padded cell `j`, across side `d` from a to b, by corners k0,
## k1 of this cell) rounds by another radius (another material) and its top stands
## higher along their side: its ground shows as a wall over this top, facing back in.
static func _bend_gap(buf, job, j: int, base: Vector3, a: Vector2, b: Vector2, n: Vector3, d: int, h0: float,
		h1: float, k0: int, k1: int, r: float, bends: int) -> void:
	var m: int = job.c[j]
	var other := rounding(job, j, m)
	if other == r:
		return
	var qs := BENT_LINES
	var own := _bent_line(h0, h1, k0, k1, qs, r, bends)
	var theirs := _bent_line(h0, h1, k0, k1, qs, other, bends)
	var higher := false
	for g in qs.size():
		if theirs[g] > own[g] + 0.0005:
			higher = true
		else:
			theirs[g] = own[g]
	if higher:
		_bent_wall(buf, base, a, b, -n, d, qs, theirs, own, Vector2(pack(m * 3 + 1, 0, 0), float(NO_TILES)))
