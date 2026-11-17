extends "res://src/client/world/mesh_faces.gd"
## Rounded and bevelled edges of natural ground, by material (Mat.edge_mode, edge_size):
## drawn only, the cells, walking and the server keep the shapes of WorldData.
##
## Each level of ground is a plan of pieces: a whole cell, or the half of a cell on one
## side of its diagonal (a cut cell, or the ground filling a corner of an open cell).
## Where the plan ends at something open on its level a wall drops (a brow); where a
## wall of the level above rises from it, its foot. The top of a level is one height
## over the plan: 1 less the drop of the nearest brows (a quarter circle of radius
## edge_size, or a flat cut edge_size wide) plus the heap at the foot of the walls
## rising from it (the same curve, the other way). Each cell draws the top over its own
## piece on a grid (GRID) and its walls up to that height, all from the same height
## function, so cells meet without seams whatever their materials: where a soft
## material meets a hard one its rounding runs out into the hard one's edge.
## ChunkMesher asks `prepare` first and draws the cell its own way where no rounded
## edge reaches it (most of the ground).

## Pieces of a cell (see portion): none, a whole cell, or 0..3, the half holding
## corner k (NW, NE, SE, SW), cut off by the diagonal across the cell beside k.
const EMPTY := -1
const FULL := 4
## Sides N, S, W, E: the way out, the corners on them, the opposite side, the DIRS face
## and the ends of the side in the cell.
const SIDE_OFF: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const SIDE_K := [[0, 1], [2, 3], [3, 0], [1, 2]]
const OPP := [1, 0, 3, 2]
const SIDE_D := [5, 4, 1, 0]
const SIDE_A: Array[Vector2] = [Vector2(0, 0), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)]
const SIDE_B: Array[Vector2] = [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(1, 1)]
## Lines of the grid a rounded top is drawn on, across and down a cell: close by the
## edges, where the curves are. Symmetric, so a diagonal runs through its points.
const GRID: Array[float] = [0.0, 0.125, 0.25, 0.75, 0.875, 1.0]
const GN := 6
## A segment of a level's plan edge, ST floats: the ends a, b (x, z, from the middle
## cell's NW corner), the way out n, the radius and EDGE_* mode of its owner, the
## owner's place in the window (3 * (oz + 1) + ox + 1, 4 the middle cell) and its kind
## (side 0..3 or DIAG_KIND), and how far its wall stands back from it (LEDGE or 0).
## WALL_ONLY: a wall against a cell drawn its own way (a slope, a trunk, a built form), no
## drop.
const ST := 11
const DIAG_KIND := 4
const WALL_ONLY := 0
const MIDDLE := 4
## The most any material rounds, in blocks: what lies farther away reaches no cell.
const REACH := 0.5
## How far a soft layer's wall stands back from the brow of a hard layer under it,
## leaving a ledge of the hard one: a line of GRID, so the top ends on it.
const LEDGE := 0.125
## How many soft levels down a wall is followed to a hard layer under it.
const LEDGE_DEPTH := 8


## The piece of padded cell `i` on its level (see EMPTY, FULL).
static func portion(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int) -> int:
	var s := sh[i]
	if cov[c[i]]:
		if s < 16:
			return FULL
		var cuts := s >> 4
		return (WorldData.level_of(cuts & -cuts) + 2) & 3
	if s >= 16:
		var fills := s >> 4
		return WorldData.level_of(fills & -fills)
	return EMPTY


## Whether piece `p` holds the whole of side `s`.
static func has_side(p: int, s: int) -> bool:
	return p == FULL or (p >= 0 and (SIDE_K[s][0] == p or SIDE_K[s][1] == p))


## The part of piece `p` not under piece `above` (open to the sky), EMPTY where none or
## where the two halves cross (not drawn rounded).
static func open_part(p: int, above: int) -> int:
	if above == EMPTY:
		return p
	if above == FULL:
		return EMPTY
	if p == FULL:
		return (above + 2) & 3
	return p if above == (p + 2) & 3 else EMPTY


## The column masks of the natural cells (WorldData.WILD) of the padded columns
## x0..x1, z0..z1, row by row, for `natural`.
static func wild_masks(w, x0: int, z0: int, x1: int, z1: int) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize((x1 - x0) * (z1 - z0))
	var n := 0
	for z in range(z0, z1):
		for x in range(x0, x1):
			var ch = w.chunk_at(x, z)
			out[n] = ch.wild[WorldData.col_of(x, z)] if ch != null else 0
			n += 1
	return out


## The material a piece `p` of padded cell `i` is of: its own, or for the ground filling
## a corner of an open cell the ground's beside it.
static func material(c: PackedByteArray, cov: PackedByteArray, i: int, p: int) -> int:
	if cov[c[i]] or p < 0 or p == FULL:
		return c[i]
	return c[i + CORNER_DIRS[p].x]


## Whether the piece of padded cell `i` is drawn its own way (a slope, a log, a built
## form): no rounding of its own, only walls against it.
static func _odd(job, i: int) -> bool:
	var c: PackedByteArray = job.c
	var m := c[i]
	if m == Mat.LOG or (job.cov[m] and job.sh[i] & 15 != 0):
		return true
	return not job.forms.is_empty() and job.forms.has(i)


## Whether the ground of padded cell `i` (the cell beside for a fill) lies as the
## generator left it (only natural ground rounds).
static func _natural(job, i: int, p: int) -> bool:
	var dy: int = job.dy
	var j := i
	if not job.cov[job.c[i]] and p >= 0 and p < FULL:
		j += CORNER_DIRS[p].x
	var y := j / dy - 1
	if y < 0 or job.wild.is_empty():
		return false
	return (job.wild[j % dy] >> y) & 1 != 0


static func _push(out: PackedFloat32Array, a: Vector2, b: Vector2, n: Vector2, r: float, mode: int, place: int,
		kind: int, inset := 0.0) -> void:
	out.append_array([a.x, a.y, b.x, b.y, n.x, n.y, r, mode, place, kind, inset])


## How far the wall of side `s` of soft piece `p` of padded cell `j` stands back
## (LEDGE or 0): where the cliff under it goes down through soft levels to a hard one
## whose side is open too (layered cliffs: a narrow ledge of the hard layer stays).
static func _ledge(job, j: int, p: int, s: int) -> float:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dy: int = job.dy
	var f: int = SIDE_OFF[s].x + SIDE_OFF[s].y * job.dz
	var k := j
	for n in LEDGE_DEPTH:
		k -= dy
		if k < 0:
			return 0.0
		var pk := portion(c, sh, cov, k)
		if not has_side(pk, s) or _odd(job, k) or has_side(portion(c, sh, cov, k + f), OPP[s]):
			return 0.0
		var m := material(c, cov, k, pk)
		if Mat.edge_mode[m] != Mat.EDGE_ROUND:
			return LEDGE if _natural(job, k, pk) else 0.0
	return 0.0


## Distance between the middle cell (0..1 square) and segment a, b.
static func _square_distance(a: Vector2, b: Vector2) -> float:
	var sq := Rect2(0, 0, 1, 1)
	if sq.has_point(a) or sq.has_point(b):
		return 0.0
	var best := minf(a.distance_to(a.clamp(Vector2.ZERO, Vector2.ONE)), b.distance_to(b.clamp(Vector2.ZERO, Vector2.ONE)))
	for k in 4:
		var p := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[k]) * 0.5
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## The edge segments of the plan of the level of padded cell `i` that reach the cell:
## where its pieces end at an open cell (a brow), or at one drawn its own way (WALL_ONLY,
## only those of the cell itself).
static func segments(job, i: int) -> PackedFloat32Array:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dz: int = job.dz
	var out := PackedFloat32Array()
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var j := i + ox + oz * dz
			var p := portion(c, sh, cov, j)
			if p == EMPTY or _odd(job, j):
				continue
			var m := material(c, cov, j, p)
			var mode: int = Mat.edge_mode[m]
			var r: float = Mat.edge_size[m] if mode != Mat.EDGE_SHARP and _natural(job, j, p) else 0.0
			if mode == Mat.EDGE_SHARP:
				mode = Mat.EDGE_BEVEL
			var own := ox == 0 and oz == 0
			if r == 0.0 and not own:
				continue
			var o := Vector2(ox, oz)
			var place := 3 * (oz + 1) + ox + 1
			for s in 4:
				if not has_side(p, s):
					continue
				var so := SIDE_OFF[s]
				# The far sides of the cells round the middle one are out of its reach.
				if (ox != 0 and so.x == ox) or (oz != 0 and so.y == oz):
					continue
				var nj := j + so.x + so.y * dz
				var md := mode
				if has_side(portion(c, sh, cov, nj), OPP[s]):
					if not own or not _odd(job, nj):
						continue
					md = WALL_ONLY
				var a := SIDE_A[s] + o
				var b := SIDE_B[s] + o
				var inset := 0.0
				if md == Mat.EDGE_ROUND and r > 0.0:
					inset = _ledge(job, j, p, s)
				if not own and _square_distance(a, b) >= r + inset:
					continue
				_push(out, a, b, Vector2(so), r, md, place, s, inset)
			if p < FULL:
				var a := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 1) & 3]) * 0.5 + o
				var b := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 3) & 3]) * 0.5 + o
				if not own and _square_distance(a, b) >= r:
					continue
				_push(out, a, b, -Vector2(CORNER_DIRS[p]).normalized(), r, mode, place, DIAG_KIND)
	return out


## Whether point `pt` (from the middle cell's NW corner) lies on a piece of the level of
## padded cell `i` drawn rounded.
static func _solid_at(job, i: int, pt: Vector2) -> bool:
	var fx := floori(pt.x)
	var fz := floori(pt.y)
	if absi(fx) > 1 or absi(fz) > 1 or fx > 1 or fz > 1:
		return false
	var j: int = i + fx + fz * job.dz
	var p := portion(job.c, job.sh, job.cov, j)
	if p == EMPTY or _odd(job, j):
		return false
	if p == FULL:
		return true
	var l := pt - Vector2(fx, fz) - Vector2(0.5, 0.5)
	return l.dot(Vector2(CORNER_DIRS[p])) > 0.0


## The brows of the level above padded cell `i` whose walls stand on its level: the feet
## its top heaps up against.
static func feet(job, i: int) -> PackedFloat32Array:
	var above := segments(job, i + job.dy)
	var out := PackedFloat32Array()
	for g in range(0, above.size(), ST):
		if above[g + 7] == WALL_ONLY or above[g + 6] <= 0.0:
			continue
		var mid := Vector2(above[g] + above[g + 2], above[g + 1] + above[g + 3]) * 0.5 \
				+ Vector2(above[g + 4], above[g + 5]) * 0.05
		if _solid_at(job, i, mid):
			out.append_array(above.slice(g, g + ST))
	return out


## How far below the edge's height a point `d` from it lies: a quarter circle of radius
## `r` or a flat cut `r` wide.
static func profile(d: float, r: float, mode: int) -> float:
	if d >= r:
		return 0.0
	if mode == Mat.EDGE_BEVEL:
		return r - d
	var t := r - d
	return r - sqrt(r * r - t * t)


## Height of the top of a level at point `p` (from the middle cell's NW corner), over the
## level's floor: 1 less the drops of the brows `drops`, plus the heaps at the feet `heaps`.
static func height(p: Vector2, drops: PackedFloat32Array, heaps: PackedFloat32Array) -> float:
	var drop := 0.0
	for g in range(0, drops.size(), ST):
		var r := drops[g + 6]
		if r <= 0.0 or drops[g + 7] == WALL_ONLY:
			continue
		var a := Vector2(drops[g], drops[g + 1])
		var b := Vector2(drops[g + 2], drops[g + 3])
		# A wall set back (a ledge under it) rounds from where it stands.
		var d := maxf(0.0, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - drops[g + 10])
		drop = maxf(drop, profile(d, r, int(drops[g + 7])))
	var heap := 0.0
	for g in range(0, heaps.size(), ST):
		var a := Vector2(heaps[g], heaps[g + 1])
		var b := Vector2(heaps[g + 2], heaps[g + 3])
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		heap = maxf(heap, profile(d, heaps[g + 6], int(heaps[g + 7])))
	return 1.0 - drop + heap


## Steepest a rounded top's slope is taken for its normal (a quarter circle stands
## upright at its foot).
const MAX_SLOPE := 6.0


## The top of a level at point `p` as `height` gives it, with its slope: (height, dh/dx,
## dh/dz, 1 where a rounded edge shapes it most, 0 where a bevel or nothing does). The
## slope comes from the nearest brow or foot (the one shaping it most), so the normals
## of cells beside each other agree and a rounded edge is shaded smoothly.
static func surface(p: Vector2, drops: PackedFloat32Array, heaps: PackedFloat32Array) -> Vector4:
	var drop := 0.0
	var dg := Vector2.ZERO
	var round_drop := false
	for g in range(0, drops.size(), ST):
		var r := drops[g + 6]
		if r <= 0.0 or drops[g + 7] == WALL_ONLY:
			continue
		var a := Vector2(drops[g], drops[g + 1])
		var b := Vector2(drops[g + 2], drops[g + 3])
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := maxf(0.0, p.distance_to(q) - drops[g + 10])
		var mode := int(drops[g + 7])
		var v := profile(d, r, mode)
		if v > drop:
			drop = v
			# The drop falls toward the edge: its gradient points out of the ground.
			var away := (p - q).normalized() if p.distance_to(q) > 0.0001 else -Vector2(drops[g + 4], drops[g + 5])
			dg = -away * _steepness(d, r, mode)
			round_drop = mode == Mat.EDGE_ROUND
	var heap := 0.0
	var hg := Vector2.ZERO
	var round_heap := false
	for g in range(0, heaps.size(), ST):
		var a := Vector2(heaps[g], heaps[g + 1])
		var b := Vector2(heaps[g + 2], heaps[g + 3])
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		var mode := int(heaps[g + 7])
		var v := profile(d, heaps[g + 6], mode)
		if v > heap:
			heap = v
			var away := (p - q) / d if d > 0.0001 else Vector2(heaps[g + 4], heaps[g + 5])
			hg = -away * _steepness(d, heaps[g + 6], mode)
			round_heap = mode == Mat.EDGE_ROUND
	var grad := hg - dg
	var smooth := round_heap if heap > drop else round_drop
	return Vector4(1.0 - drop + heap, grad.x, grad.y, 1.0 if smooth else 0.0)


## How fast `profile` falls toward the edge at `d` from it.
static func _steepness(d: float, r: float, mode: int) -> float:
	if d >= r:
		return 0.0
	if mode == Mat.EDGE_BEVEL:
		return 1.0
	var t := r - d
	var under := r * r - t * t
	return MAX_SLOPE if under <= 0.0 else minf(t / sqrt(under), MAX_SLOPE)


## Whether any segment rounds (a radius and a drop).
static func _rounds(segs: PackedFloat32Array) -> bool:
	for g in range(0, segs.size(), ST):
		if segs[g + 6] > 0.0 and segs[g + 7] != WALL_ONLY:
			return true
	return false


## Whether the 3x3 cells round padded cell `i` are all whole ground with nothing on
## them: no edge on the level, no wall rising (most tops).
static func _plain_window(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int,
		dz: int) -> bool:
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var j := i + ox + oz * dz
			if not cov[c[j]] or sh[j] >= 16 or cov[c[j + dy]] or sh[j + dy] >= 16:
				return false
	return true


## The brows and feet of padded cell `i` when a rounded edge reaches it ([drops, heaps]),
## else an empty array: ChunkMesher draws it its own way.
static func prepare(job, i: int) -> Array:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	if _plain_window(c, sh, cov, i, job.dy, job.dz):
		return []
	if portion(c, sh, cov, i) == EMPTY or _odd(job, i):
		return []
	var drops := segments(job, i)
	var heaps := feet(job, i)
	if not _rounds(drops) and not _rounds(heaps):
		return []
	return [drops, heaps]


## Draws the piece of padded cell `i` (at `base`) with its rounded edges: the top over
## its open part on the grid, its walls up to the top, and walls against the cells
## beside where the top dips below theirs. `ready` from `prepare`; `around` and
## `top_edges` are the top's materials beside and edge codes (ChunkMesher). Not the
## underside.
static func draw(job, buf, i: int, base: Vector3, ready: Array, around: float, top_edges: int) -> void:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dy: int = job.dy
	var dz: int = job.dz
	var drops: PackedFloat32Array = ready[0]
	var heaps: PackedFloat32Array = ready[1]
	var p := portion(c, sh, cov, i)
	var pa := portion(c, sh, cov, i + dy)
	var m := material(c, cov, i, p)
	var t := open_part(p, pa)
	if t != EMPTY:
		var mt := m
		if p == FULL and t != FULL:
			# Under a cut corner of the cell above: the ground beside goes on into it.
			var o: Vector2i = CORNER_DIRS[t]
			mt = c[i + o.x] if cov[c[i + o.x]] else (c[i + o.y * dz] if cov[c[i + o.y * dz]] else m)
		elif p < FULL and not cov[c[i]]:
			# A fill: under a slope beside, the slope's ground.
			var o: Vector2i = CORNER_DIRS[p]
			if cov[c[i + o.x + dy]]:
				mt = c[i + o.x + dy]
		# The edge codes of the sides, and along the diagonal of a half a rim or an
		# outline (the shader draws them on the outermost texels, the rounded edge's foot).
		var flag := 0
		var edges := top_edges if t == p and cov[c[i]] else 0
		if t == FULL:
			edges = _level_edges(job, i, edges)
		if t < FULL:
			flag = _diag(t, true, DARK if t == p else CONTACT)
			# Only the sides the half holds: the shader draws a side's code on every
			# texel by it, and the half reaches the others at a corner.
			for s in 4:
				if not has_side(t, s):
					edges &= ~(3 << (2 * s))
		_top(buf, t, base, drops, heaps, mt, around if t == FULL else float(NO_TILES), edges, flag)
	var below_drops := PackedFloat32Array()
	var below_heaps := PackedFloat32Array()
	var below_ready := false
	var white := Color(1, 1, 1)
	for g in range(0, drops.size(), ST):
		if int(drops[g + 8]) != MIDDLE:
			continue
		var kind := int(drops[g + 9])
		var a := Vector2(drops[g], drops[g + 1])
		var b := Vector2(drops[g + 2], drops[g + 3])
		var n := Vector2(drops[g + 4], drops[g + 5])
		var open := not has_side(pa, kind) if kind < DIAG_KIND else (pa == EMPTY or (pa != FULL and pa != p))
		var inset := drops[g + 10]
		if inset > 0.0:
			var ab := _ledge_wall(job, buf, i, base, drops, heaps, g, open)
			a = ab[0]
			b = ab[1]
		var below := inset == 0.0 and _solid_at(job, i - dy, (a + b) * 0.5 + n * 0.05)
		if below and not below_ready:
			below_drops = segments(job, i - dy)
			below_heaps = feet(job, i - dy)
			below_ready = true
		var tops := PackedFloat32Array()
		var bottoms := PackedFloat32Array()
		for q: float in GRID:
			var pt := a.lerp(b, q)
			tops.append(height(pt, drops, heaps) if open else 1.0)
			bottoms.append(maxf(0.0, height(pt, below_drops, below_heaps) - 1.0) if below else 0.0)
		var edges := 0
		var flag := OPEN_TOP if open else 0
		var around_w := float(NO_TILES)
		if kind < DIAG_KIND:
			var so := SIDE_OFF[kind]
			var f := so.x + so.y * dz
			var s := dz if so.x != 0 else 1
			if not cov[c[i - dy + f]] and not cov[c[i - dy]]:
				edges |= DARK << EDGE_S
			if not cov[c[i - s]] and not cov[c[i - s + f]] and not cov[c[i - s + f + dy]]:
				edges |= DARK << EDGE_W
			if not cov[c[i + s]] and not cov[c[i + s + f]] and not cov[c[i + s + f + dy]]:
				edges |= DARK << EDGE_E
			if cov[c[i]]:
				around_w = float(_side_tiles(c, cov, i, dy, f, s))
		else:
			flag |= SLOPE
			edges = 0 if cov[c[i - dy]] else DARK << EDGE_S
		_wall(buf, base, a, b, n, kind, tops, bottoms, Vector2(pack(m * 3 + 1, edges, flag), around_w), white)
		if int(drops[g + 7]) == WALL_ONLY and open:
			# Against a slope, a trunk or a form: the gap over the dipping top.
			var nj: int = i + SIDE_OFF[kind].x + SIDE_OFF[kind].y * dz
			var caps := PackedFloat32Array()
			for q: float in GRID:
				caps.append(_slope_height(sh[nj], a.lerp(b, q) - Vector2(SIDE_OFF[kind])) if cov[c[nj]] and sh[nj] & 15 != 0 else 1.0)
			_wall(buf, base, a, b, -n, kind, caps, tops, Vector2(pack(c[nj] * 3 + 1, 0, 0), float(NO_TILES)), white)
	if t == EMPTY:
		return
	# Sides shared with ground whose top is covered: its wall shows over the dipping top.
	for s in 4:
		if not has_side(t, s):
			continue
		var nj: int = i + SIDE_OFF[s].x + SIDE_OFF[s].y * dz
		var pn := portion(c, sh, cov, nj)
		if not has_side(pn, OPP[s]) or _odd(job, nj) or has_side(open_part(pn, portion(c, sh, cov, nj + dy)), OPP[s]):
			continue
		var tops := PackedFloat32Array()
		var ones := PackedFloat32Array()
		var dips := false
		for q: float in GRID:
			var h := height(SIDE_A[s].lerp(SIDE_B[s], q), drops, heaps)
			dips = dips or h < 0.999
			tops.append(minf(h, 1.0))
			ones.append(1.0)
		if dips:
			_wall(buf, base, SIDE_A[s], SIDE_B[s], -Vector2(SIDE_OFF[s]), s, ones, tops,
				Vector2(pack(material(c, cov, nj, pn) * 3 + 1, 0, 0), float(NO_TILES)), white)


## The edge codes `edges` of the whole top of padded cell `i` less those of the sides
## where its level goes on: a filled corner of the open cell beside (no rim), or a cut
## corner of the wall above it (no contact shadow). ChunkMesher's codes see only whole
## cells, and a rim along such a side ran on past the diagonal as a square outline.
static func _level_edges(job, i: int, edges: int) -> int:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	for s in 4:
		var code := (edges >> (2 * s)) & 3
		if code == 0:
			continue
		var nj: int = i + SIDE_OFF[s].x + SIDE_OFF[s].y * job.dz
		var gone := false
		if code == CONTACT:
			gone = not has_side(portion(c, sh, cov, nj + job.dy), OPP[s])
		else:
			gone = has_side(portion(c, sh, cov, nj), OPP[s])
		if gone:
			edges &= ~(3 << (2 * s))
	return edges


## Whether point `pt` of the middle cell lies on the ledge in front of a wall of its set
## back (see LEDGE): no top of its own there.
static func _on_ledge(pt: Vector2, drops: PackedFloat32Array) -> bool:
	for g in range(0, drops.size(), ST):
		var inset := drops[g + 10]
		if inset <= 0.0 or int(drops[g + 8]) != MIDDLE:
			continue
		var a := Vector2(drops[g], drops[g + 1])
		var b := Vector2(drops[g + 2], drops[g + 3])
		var n := Vector2(drops[g + 4], drops[g + 5])
		var along := (pt - a).dot(b - a) / (b - a).length_squared()
		if along >= -0.0001 and along <= 1.0001 and (pt - a).dot(n) > -inset + 0.0001:
			return true
	return false


## The own wall `g` of `drops` set back from its brow (LEDGE): its ends where it
## stands ([a, b], shortened at a corner where the next side stands back too), the
## ledge in front of it (the hard layer's top, on the lowest soft level) and the ends of
## the ledge where it runs into ground that does not stand back.
static func _ledge_wall(job, buf, i: int, base: Vector3, drops: PackedFloat32Array, heaps: PackedFloat32Array, g: int,
		open: bool) -> Array:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dy: int = job.dy
	var dz: int = job.dz
	var kind := int(drops[g + 9])
	var inset := drops[g + 10]
	var a := Vector2(drops[g], drops[g + 1])
	var b := Vector2(drops[g + 2], drops[g + 3])
	var n := Vector2(drops[g + 4], drops[g + 5])
	var along := (b - a).normalized()
	var ends := [a, b]
	var convex := [false, false]
	for h in range(0, drops.size(), ST):
		if h == g or int(drops[h + 8]) != MIDDLE or drops[h + 10] <= 0.0:
			continue
		var ha := Vector2(drops[h], drops[h + 1])
		var hb := Vector2(drops[h + 2], drops[h + 3])
		for e in 2:
			if ends[e].is_equal_approx(ha) or ends[e].is_equal_approx(hb):
				convex[e] = true
	var lowest := false
	var below := i - dy
	var pb := portion(c, sh, cov, below)
	if has_side(pb, kind) and not _odd(job, below):
		lowest = Mat.edge_mode[material(c, cov, below, pb)] != Mat.EDGE_ROUND
	var wa := a + along * inset if convex[0] else a
	var wb := b - along * inset if convex[1] else b
	var white := Color(1, 1, 1)
	if lowest:
		# The ledge: the top of the hard layer below, from the brow to the wall (mitred
		# at a corner where the next side has one too).
		var mh := material(c, cov, below, pb)
		var vs := [base + Vector3(a.x, 0.0, a.y), base + Vector3(b.x, 0.0, b.y),
			base + Vector3(wb.x - n.x * inset, 0.0, wb.y - n.y * inset),
			base + Vector3(wa.x - n.x * inset, 0.0, wa.y - n.y * inset)]
		var uvs := []
		for v: Vector3 in vs:
			uvs.append(Vector2(v.x - base.x, v.z - base.z))
		_wound(buf, vs, Vector3.UP, uvs, white, Vector2(pack(mh * 3, DARK << (2 * kind), 0), float(NO_TILES)))
	# Where the ledge runs into ground beside that does not stand back: its end.
	var m := material(c, cov, i, portion(c, sh, cov, i))
	for e in 2:
		if convex[e]:
			continue
		var out := -along if e == 0 else along
		var nj: int = i + int(out.x) + int(out.y) * dz
		var pn := portion(c, sh, cov, nj)
		if pn == EMPTY or (has_side(pn, kind) and not _odd(job, nj) and _ledge(job, nj, pn, kind) > 0.0):
			continue
		var e0: Vector2 = ends[e]
		var e1: Vector2 = e0 - n * inset
		var tops := PackedFloat32Array()
		var bottoms := PackedFloat32Array()
		for q: float in GRID:
			tops.append(height(e0.lerp(e1, q), drops, heaps) if open else 1.0)
			bottoms.append(0.0)
		var face := -out
		var fk := SIDE_OFF.find(Vector2i(roundi(face.x), roundi(face.y)))
		_wall(buf, base, e0, e1, face, fk, tops, bottoms, Vector2(pack(m * 3 + 1, 0, OPEN_TOP if open else 0),
			float(NO_TILES)), white)
	return [wa - n * inset, wb - n * inset]


## Height of the top of a slope of shape `s` at point `l` of its cell (0..1, on its
## edge), from its corner heights.
static func _slope_height(s: int, l: Vector2) -> float:
	var h := PackedFloat32Array()
	for k in 4:
		h.append(0.0 if s & (1 << k) else 1.0)
	var u := clampf(l.x, 0.0, 1.0)
	var v := clampf(l.y, 0.0, 1.0)
	return lerpf(lerpf(h[0], h[1], u), lerpf(h[3], h[2], u), v)


## A wall along a..b facing `n` (side `kind` or a diagonal), from `bottoms` up to `tops`
## at the GRID points along it; one quad where both stay level.
static func _wall(buf, base: Vector3, a: Vector2, b: Vector2, n: Vector2, kind: int, tops: PackedFloat32Array,
		bottoms: PackedFloat32Array, packed: Vector2, color: Color) -> void:
	var nn := Vector3(n.x, 0.0, n.y)
	var level := true
	for g in range(1, GN):
		if absf(tops[g] - tops[0]) > 0.0001 or absf(bottoms[g] - bottoms[0]) > 0.0001:
			level = false
			break
	var steps: Array = [0, GN - 1] if level else range(GN)
	# A diagonal wall stands a little inside the ground (see _diag_wall).
	var inside := -n * EPS if kind == DIAG_KIND else Vector2.ZERO
	for g in range(steps.size() - 1):
		var g0: int = steps[g]
		var g1: int = steps[g + 1]
		var p0 := a.lerp(b, GRID[g0]) + inside
		var p1 := a.lerp(b, GRID[g1]) + inside
		if tops[g0] - bottoms[g0] < 0.0001 and tops[g1] - bottoms[g1] < 0.0001:
			continue
		var vs := [base + Vector3(p0.x, bottoms[g0], p0.y), base + Vector3(p1.x, bottoms[g1], p1.y)]
		var pts := [Vector3(p0.x, bottoms[g0], p0.y), Vector3(p1.x, bottoms[g1], p1.y)]
		if tops[g1] - bottoms[g1] >= 0.0001:
			vs.append(base + Vector3(p1.x, tops[g1], p1.y))
			pts.append(Vector3(p1.x, tops[g1], p1.y))
		if tops[g0] - bottoms[g0] >= 0.0001:
			vs.append(base + Vector3(p0.x, tops[g0], p0.y))
			pts.append(Vector3(p0.x, tops[g0], p0.y))
		var uvs := []
		for v: Vector3 in pts:
			uvs.append(face_uv(SIDE_D[kind], v) if kind < DIAG_KIND else Vector2(v.x, 1.0 - v.y))
		_wound(buf, vs, nn, uvs, color, packed)


## The top over piece `t` of a cell on the GRID, its heights from the brows and feet:
## flat squares as a plain top (with the cell's edge codes), the rest as slopes.
static func _top(buf, t: int, base: Vector3, drops: PackedFloat32Array, heaps: PackedFloat32Array, m: int,
		around: float, edges: int, flag: int) -> void:
	# The split of the squares: along the piece's diagonal, or a diagonal brow's near it.
	var ne_sw := t == 0 or t == 2
	if t == FULL:
		for g in range(0, drops.size() + heaps.size(), ST):
			var segs := drops if g < drops.size() else heaps
			var h := g if g < drops.size() else g - drops.size()
			if int(segs[h + 9]) == DIAG_KIND and segs[h + 4] * segs[h + 5] > 0.0:
				ne_sw = true
	var dir := Vector2(CORNER_DIRS[t]) if t < FULL else Vector2.ZERO
	var hs := PackedFloat32Array()
	var ns: Array = []
	var smooth := PackedByteArray()
	var inside := PackedByteArray()
	hs.resize(GN * GN)
	ns.resize(GN * GN)
	smooth.resize(GN * GN)
	inside.resize(GN * GN)
	for b in GN:
		for a in GN:
			var pt := Vector2(GRID[a], GRID[b])
			var k := b * GN + a
			inside[k] = 1 if (t == FULL or (pt - Vector2(0.5, 0.5)).dot(dir) > -0.0001) and not _on_ledge(pt, drops) else 0
			if inside[k]:
				var sf := surface(pt, drops, heaps)
				hs[k] = sf.x
				ns[k] = Vector3(-sf.y, 1.0, -sf.z).normalized()
				smooth[k] = int(sf.w)
	var white := Color(1, 1, 1)
	# Textured by x and z like a flat top (not as a slope, whose patterns go by its
	# height over the level): the rounding is low, and its texels join the top's.
	var packed := Vector2(pack(m * 3, edges, flag), around)
	for b in GN - 1:
		for a in GN - 1:
			var k00 := b * GN + a
			var ks := [k00, k00 + 1, k00 + GN + 1, k00 + GN]
			var n_in := inside[ks[0]] + inside[ks[1]] + inside[ks[2]] + inside[ks[3]]
			if n_in < 3:
				continue
			var tris: Array
			if n_in == 3:
				var tri := []
				for k: int in ks:
					if inside[k]:
						tri.append(k)
				tris = [tri]
			elif ne_sw:
				tris = [[ks[0], ks[1], ks[3]], [ks[1], ks[2], ks[3]]]
			else:
				tris = [[ks[0], ks[1], ks[2]], [ks[0], ks[2], ks[3]]]
			for tri: Array in tris:
				var vs := []
				var uvs := []
				var level := true
				for k: int in tri:
					var u := GRID[k % GN]
					var v := GRID[k / GN]
					vs.append(base + Vector3(u, hs[k], v))
					uvs.append(Vector2(u, v))
					level = level and absf(hs[k] - 1.0) < 0.0001
				if level:
					_wound(buf, vs, Vector3.UP, uvs, white, packed)
					continue
				var nrm: Vector3 = (vs[1] - vs[0]).cross(vs[2] - vs[0]).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				if smooth[tri[0]] + smooth[tri[1]] + smooth[tri[2]] == 0:
					_wound(buf, vs, nrm, uvs, white, packed)
					continue
				# A rounded edge: the normals of the curve at the corners, shaded smoothly.
				var vn := [ns[tri[0]], ns[tri[1]], ns[tri[2]]]
				if (vs[1] - vs[0]).cross(vs[2] - vs[0]).dot(nrm) > 0.0:
					vs.reverse()
					uvs.reverse()
					vn.reverse()
				buf.tri_n(vs, vn, uvs, white, packed)
