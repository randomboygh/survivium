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

const Slopes := preload("res://src/client/world/slope_mesher.gd")

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
## What the brows and feet round a cell make of it (_entry): its top (_top_shape), the
## lines of its top and the heights along its sides and diagonal. Most edges repeat.
static var _shapes := {}
## Walls bent round corners (see draw), by the corners, the side and the piece.
static var _bent_walls := {}
const SHAPES_MAX := 4096
## GRID and its ends as packed arrays (not constant expressions).
static var GRID_P := PackedFloat32Array(GRID)
static var ENDS := PackedFloat32Array([0.0, 1.0])
static var ENDS_UP := PackedFloat32Array([1.0, 1.0])
## The whole walls of the four sides of a cell, floor to top.
static var _plain_walls := [_side_wall(0), _side_wall(1), _side_wall(2), _side_wall(3)]
static var ENDS_DOWN := PackedFloat32Array([0.0, 0.0])
## The whole of GRID as a mask of its lines (see lines).
const ALL_LINES := 63
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
	if y < 0 or job.wild.is_empty() or job.soft:
		return false
	return (job.wild[j % dy] >> y) & 1 != 0


static func _push(out: PackedFloat32Array, a: Vector2, b: Vector2, n: Vector2, r: float, mode: int, place: int,
		kind: int, inset := 0.0) -> void:
	var g := out.size()
	out.resize(g + ST)
	out[g] = a.x
	out[g + 1] = a.y
	out[g + 2] = b.x
	out[g + 3] = b.y
	out[g + 4] = n.x
	out[g + 5] = n.y
	out[g + 6] = r
	out[g + 7] = mode
	out[g + 8] = place
	out[g + 9] = kind
	out[g + 10] = inset


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


## A convex corner of a level's plan, rounded in plan (CORNER_KIND, see _add_corners): its
## record holds the points T1, T2 where its arc (or cut) meets the two brows, then the
## centre O of the arc of its radius touching both brows (a bevel cuts straight from T1 to
## T2), the radius and the mode, no place (no wall of its own: the walls of the brows bend
## round it), the kind and no inset.
const CORNER_KIND := 5
## A round corner of a wider angle (a brow meeting a diagonal one at 135°): its arc would
## cut the plan by a few hundredths of a block, so it only rounds the top (the brow does
## not mitre there); the walls keep their corner. (A bevel there keeps its mitre.)
const CORNER_TOP_KIND := 6
const NO_PLACE := -1


## Rounds the convex corners of the plan `segs` at the corners of the middle cell: where two
## brows of the same edge (radius, mode, standing at their brow) meet at an angle, they
## stop where an arc of their radius touches them (a cut of it for a bevel), and a corner
## record takes the corner between them. The cells round a corner see the same brows, so
## they agree on it.
static func _add_corners(segs: PackedFloat32Array) -> PackedFloat32Array:
	var n := segs.size()
	if n < 2 * ST:
		return segs
	var out := segs
	var found := false
	for g in range(0, n, ST):
		if segs[g + 6] <= 0.0 or segs[g + 7] == WALL_ONLY or segs[g + 10] > 0.0:
			continue
		for eg in 2:
			var cx := segs[g + 2 * eg]
			var cz := segs[g + 2 * eg + 1]
			if (cx != 0.0 and cx != 1.0) or (cz != 0.0 and cz != 1.0):
				continue
			for h in range(g + ST, n, ST):
				if segs[h + 6] != segs[g + 6] or segs[h + 7] != segs[g + 7] or segs[h + 10] > 0.0:
					continue
				var eh := -1
				if segs[h] == cx and segs[h + 1] == cz:
					eh = 0
				elif segs[h + 2] == cx and segs[h + 3] == cz:
					eh = 1
				if eh < 0:
					continue
				var c := Vector2(cx, cz)
				var pg := Vector2(segs[g + 2 - 2 * eg], segs[g + 3 - 2 * eg])
				var ph := Vector2(segs[h + 2 - 2 * eh], segs[h + 3 - 2 * eh])
				var ng := Vector2(segs[g + 4], segs[g + 5])
				var nh := Vector2(segs[h + 4], segs[h + 5])
				# Convex: each brow runs off behind the other one's edge.
				if (ph - c).dot(ng) > -0.0001 or (pg - c).dot(nh) > -0.0001:
					continue
				var dg := (pg - c).normalized()
				var dh := (ph - c).normalized()
				var cosa := clampf(dg.dot(dh), -0.999, 0.999)
				var right := absf(cosa) < 0.01
				if not right and segs[g + 7] != Mat.EDGE_ROUND:
					continue
				var r := segs[g + 6]
				var t := r * sqrt((1.0 + cosa) / (1.0 - cosa))
				var t1 := c + dg * t
				var t2 := c + dh * t
				if not found:
					out = segs.duplicate()
					found = true
				out[g + 2 * eg] = t1.x
				out[g + 2 * eg + 1] = t1.y
				out[h + 2 * eh] = t2.x
				out[h + 2 * eh + 1] = t2.y
				_push(out, t1, t2, t1 - ng * r, r, int(segs[g + 7]), NO_PLACE, CORNER_KIND if right else CORNER_TOP_KIND)
				break
	return out


## The corner records of `segs` that cut its plan (see _add_corners).
static func _corners(segs: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for g in range(0, segs.size(), ST):
		if segs[g + 9] == CORNER_KIND:
			out.append_array(segs.slice(g, g + ST))
	return out


## Whether point `p` lies in the wedge of corner `g` of `segs`: between the lines from its
## centre through T1 and T2, on the corner's side (where its arc shapes the ground); and
## if `inner`, on the ground's side of both brows too (the corner's own piece of plan).
static func _in_corner(p: Vector2, segs: PackedFloat32Array, g: int, inner: bool) -> bool:
	var t1 := Vector2(segs[g], segs[g + 1])
	var t2 := Vector2(segs[g + 2], segs[g + 3])
	var o := Vector2(segs[g + 4], segs[g + 5])
	var v1 := t1 - o
	var v2 := t2 - o
	if inner and ((p - t1).dot(v1) > 0.00001 or (p - t2).dot(v2) > 0.00001):
		return false
	var u1 := Vector2(-v1.y, v1.x)
	if u1.dot(t2 - t1) < 0.0:
		u1 = -u1
	var u2 := Vector2(-v2.y, v2.x)
	if u2.dot(t1 - t2) < 0.0:
		u2 = -u2
	return (p - t1).dot(u1) >= -0.00001 and (p - t2).dot(u2) >= -0.00001


## How far point `p` lies in from the arc of round corner `g` of `segs` (a drop), or out
## from it (`out`, a heap); -1 where the corner does not shape the ground at `p`. (A
## bevel's cut is a plain segment: its flat cut mitres with the brows' ones.)
static func _corner_distance(p: Vector2, segs: PackedFloat32Array, g: int, out: bool) -> float:
	if not _in_corner(p, segs, g, not out):
		return -1.0
	var d := p.distance_to(Vector2(segs[g + 4], segs[g + 5])) - segs[g + 6]
	return maxf(0.0, d if out else -d)


## Point `p` within the corners `cuts` moved out onto their arcs (or cuts): the other
## way from _project.
static func _push_out(p: Vector2, cuts: PackedFloat32Array) -> Vector2:
	for g in range(0, cuts.size(), ST):
		if not _in_corner(p, cuts, g, true):
			continue
		var t1 := Vector2(cuts[g], cuts[g + 1])
		var o := Vector2(cuts[g + 4], cuts[g + 5])
		var r := cuts[g + 6]
		if cuts[g + 7] == Mat.EDGE_ROUND:
			var d := p.distance_to(o)
			if d > 0.00001:
				return o + (p - o) / d * r
		else:
			var nc := (t1 - o + Vector2(cuts[g + 2], cuts[g + 3]) - o).normalized()
			return p - nc * (p - t1).dot(nc)
	return p


## Point `p` moved as _project moves it.
static func _moved(p: Vector2, cuts: PackedFloat32Array) -> Vector2:
	if cuts.is_empty():
		return p
	var pj := _project(p, cuts)
	return Vector2(pj.x, pj.y)


## Point `p` moved onto the plan of the corners `cuts` where they cut it off (onto the arc,
## or onto the cut of a bevel), with the way the plan's edge faces there: (x, z, nx, nz),
## the normal zero where `p` stays and twice as long on a cut (one way along all of it).
static func _project(p: Vector2, cuts: PackedFloat32Array) -> Vector4:
	for g in range(0, cuts.size(), ST):
		if not _in_corner(p, cuts, g, true):
			continue
		var t1 := Vector2(cuts[g], cuts[g + 1])
		var o := Vector2(cuts[g + 4], cuts[g + 5])
		var r := cuts[g + 6]
		if cuts[g + 7] == Mat.EDGE_ROUND:
			var d := p.distance_to(o)
			if d > r + 0.00001:
				var nr := (p - o) / d
				var q := o + nr * r
				return Vector4(q.x, q.y, nr.x, nr.y)
		else:
			var nc := (t1 - o + Vector2(cuts[g + 2], cuts[g + 3]) - o).normalized()
			var s := (p - t1).dot(nc)
			if s > 0.00001:
				var q := p - nc * s
				return Vector4(q.x, q.y, nc.x * 2.0, nc.y * 2.0)
	return Vector4(p.x, p.y, 0.0, 0.0)


## The edge segments of the plan of the level of padded cell `i` that reach the cell:
## where its pieces end at an open cell (a brow), or at one drawn its own way (WALL_ONLY,
## only those of the cell itself).
static func segments(job, i: int) -> PackedFloat32Array:
	var got = job.edge_segs.get(i)
	if got == null:
		got = _segments(job, i)
		job.edge_segs[i] = got
	return got


static func _segments(job, i: int) -> PackedFloat32Array:
	var info := _infos(job)
	var dz: int = job.dz
	var modes: PackedByteArray = Mat.edge_mode
	var sizes: PackedFloat32Array = Mat.edge_size
	var out := PackedFloat32Array()
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var j := i + ox + oz * dz
			var v := info[j]
			if v == 0:
				v = _info(job, j)
			var p := (v & 7) - 1
			if p == EMPTY or v & ODD_BIT:
				continue
			var m := (v >> 5) & 255
			var mode: int = modes[m]
			var r: float = sizes[m] if mode != Mat.EDGE_SHARP and v & NATURAL_BIT else 0.0
			if mode == Mat.EDGE_SHARP:
				mode = Mat.EDGE_BEVEL
			var own := ox == 0 and oz == 0
			if r == 0.0 and not own:
				continue
			var o := Vector2(ox, oz)
			var place := 3 * (oz + 1) + ox + 1
			# The far sides of the cells round the middle one are out of its reach; the
			# others touch it.
			var sides: int = SIDE_MASK[p + 1] & NEAR_SIDES[place]
			for s in 4:
				if sides & (1 << s) == 0:
					continue
				var so := SIDE_OFF[s]
				var nj := j + so.x + so.y * dz
				var vn := info[nj]
				if vn == 0:
					vn = _info(job, nj)
				var md := mode
				if SIDE_MASK[(vn & 7)] & (1 << OPP[s]):
					if not own or vn & ODD_BIT == 0:
						continue
					md = WALL_ONLY
				var inset := 0.0
				if md == Mat.EDGE_ROUND and r > 0.0:
					inset = _ledge(job, j, p, s)
				var g := out.size()
				out.resize(g + ST)
				out[g] = SIDE_AX[s] + ox
				out[g + 1] = SIDE_AZ[s] + oz
				out[g + 2] = SIDE_BX[s] + ox
				out[g + 3] = SIDE_BZ[s] + oz
				out[g + 4] = so.x
				out[g + 5] = so.y
				out[g + 6] = r
				out[g + 7] = md
				out[g + 8] = place
				out[g + 9] = s
				out[g + 10] = inset
			if p < FULL:
				var a := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 1) & 3]) * 0.5 + o
				var b := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 3) & 3]) * 0.5 + o
				if not own and _square_distance(a, b) >= r:
					continue
				_push(out, a, b, -Vector2(CORNER_DIRS[p]).normalized(), r, mode, place, DIAG_KIND)
	return _add_corners(out)


## The sides of a cell of the window (by place) that touch the middle cell: not its far ones.
const NEAR_SIDES := [10, 14, 6, 11, 15, 7, 9, 13, 5]
## SIDE_A, SIDE_B by coordinate.
const SIDE_AX := [0.0, 0.0, 0.0, 1.0]
const SIDE_AZ := [0.0, 1.0, 0.0, 0.0]
const SIDE_BX := [1.0, 1.0, 0.0, 1.0]
const SIDE_BZ := [0.0, 1.0, 1.0, 1.0]
## The sides (bits N 1, S 2, W 4, E 8) piece p holds, by p + 1.
const SIDE_MASK := [0, 5, 9, 10, 6, 15]
const ODD_BIT := 8
const NATURAL_BIT := 16
const KNOWN_BIT := 1 << 30


## The job's cache of `_info` by padded cell (0 where not asked yet).
static func _infos(job) -> PackedInt32Array:
	if job.edge_info.is_empty():
		job.edge_info.resize(job.c.size())
	return job.edge_info


## What segments asks of padded cell `j`, packed: its piece + 1 (bits 0..2), drawn its own
## way (ODD_BIT), natural (NATURAL_BIT), its material (bits 5..12); cached in the job.
static func _info(job, j: int) -> int:
	var p := portion(job.c, job.sh, job.cov, j)
	var v := KNOWN_BIT | (p + 1)
	if p != EMPTY:
		if _odd(job, j):
			v |= ODD_BIT
		if _natural(job, j, p):
			v |= NATURAL_BIT
		v |= material(job.c, job.cov, j, p) << 5
	job.edge_info[j] = v
	return v


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
	var got = job.edge_feet.get(i)
	if got == null:
		got = _feet(job, i)
		job.edge_feet[i] = got
	return got


static func _feet(job, i: int) -> PackedFloat32Array:
	# Nothing on the level above round it: no walls stand on this one.
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dz: int = job.dz
	var up: int = i + job.dy
	var bare := true
	for j in [up - dz - 1, up - dz, up - dz + 1, up - 1, up, up + 1, up + dz - 1, up + dz, up + dz + 1]:
		if cov[c[j]] or sh[j] >= 16:
			bare = false
			break
	if bare:
		return PackedFloat32Array()
	# The brows of the level above (as `segments` makes them, those that round) whose
	# wall stands on ground of this level.
	var info := _infos(job)
	var modes: PackedByteArray = Mat.edge_mode
	var sizes: PackedFloat32Array = Mat.edge_size
	var out := PackedFloat32Array()
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var j := up + ox + oz * dz
			var v := info[j]
			if v == 0:
				v = _info(job, j)
			var p := (v & 7) - 1
			if p == EMPTY or v & ODD_BIT or v & NATURAL_BIT == 0:
				continue
			var m := (v >> 5) & 255
			var mode: int = modes[m]
			if mode == Mat.EDGE_SHARP:
				continue
			var r: float = sizes[m]
			var o := Vector2(ox, oz)
			var place := 3 * (oz + 1) + ox + 1
			var sides: int = SIDE_MASK[p + 1] & NEAR_SIDES[place]
			for s in 4:
				if sides & (1 << s) == 0:
					continue
				var so := SIDE_OFF[s]
				var nj := j + so.x + so.y * dz
				var vn := info[nj]
				if vn == 0:
					vn = _info(job, nj)
				if SIDE_MASK[(vn & 7)] & (1 << OPP[s]):
					continue
				var a := SIDE_A[s] + o
				var b := SIDE_B[s] + o
				if _solid_at(job, i, (a + b) * 0.5 + Vector2(so) * 0.05):
					_push(out, a, b, Vector2(so), r, mode, place, s)
			if p < FULL:
				var a := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 1) & 3]) * 0.5 + o
				var b := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 3) & 3]) * 0.5 + o
				var nd := -Vector2(CORNER_DIRS[p]).normalized()
				if (ox != 0 or oz != 0) and _square_distance(a, b) >= r:
					continue
				if _solid_at(job, i, (a + b) * 0.5 + nd * 0.05):
					_push(out, a, b, nd, r, mode, place, DIAG_KIND)
	return _add_corners(out)


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
		var d := 0.0
		if drops[g + 9] >= CORNER_KIND and drops[g + 7] == Mat.EDGE_ROUND:
			d = _corner_distance(p, drops, g, false)
			if d < 0.0:
				continue
		else:
			var a := Vector2(drops[g], drops[g + 1])
			var b := Vector2(drops[g + 2], drops[g + 3])
			# A wall set back (a ledge under it) rounds from where it stands.
			d = maxf(0.0, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - drops[g + 10])
		drop = maxf(drop, profile(d, r, int(drops[g + 7])))
	var heap := 0.0
	for g in range(0, heaps.size(), ST):
		var d := 0.0
		if heaps[g + 9] >= CORNER_KIND and heaps[g + 7] == Mat.EDGE_ROUND:
			d = _corner_distance(p, heaps, g, true)
			if d < 0.0:
				continue
		else:
			var a := Vector2(heaps[g], heaps[g + 1])
			var b := Vector2(heaps[g + 2], heaps[g + 3])
			d = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
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
		var mode := int(drops[g + 7])
		var d := 0.0
		var away := Vector2.ZERO
		if drops[g + 9] >= CORNER_KIND and mode == Mat.EDGE_ROUND:
			d = _corner_distance(p, drops, g, false)
			if d < 0.0:
				continue
			# In from the arc: toward its centre.
			away = (Vector2(drops[g + 4], drops[g + 5]) - p).normalized()
		else:
			var a := Vector2(drops[g], drops[g + 1])
			var b := Vector2(drops[g + 2], drops[g + 3])
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			d = maxf(0.0, p.distance_to(q) - drops[g + 10])
			away = (p - q).normalized() if p.distance_to(q) > 0.0001 else -Vector2(drops[g + 4], drops[g + 5])
		var v := profile(d, r, mode)
		if v > drop:
			drop = v
			# The drop falls toward the edge: its gradient points out of the ground.
			dg = -away * _steepness(d, r, mode)
			round_drop = mode == Mat.EDGE_ROUND
	var heap := 0.0
	var hg := Vector2.ZERO
	var round_heap := false
	for g in range(0, heaps.size(), ST):
		var mode := int(heaps[g + 7])
		var d := 0.0
		var away := Vector2.ZERO
		if heaps[g + 9] >= CORNER_KIND and mode == Mat.EDGE_ROUND:
			d = _corner_distance(p, heaps, g, true)
			if d < 0.0:
				continue
			away = (p - Vector2(heaps[g + 4], heaps[g + 5])).normalized()
		else:
			var a := Vector2(heaps[g], heaps[g + 1])
			var b := Vector2(heaps[g + 2], heaps[g + 3])
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			d = p.distance_to(q)
			away = (p - q) / d if d > 0.0001 else Vector2(heaps[g + 4], heaps[g + 5])
		var v := profile(d, heaps[g + 6], mode)
		if v > heap:
			heap = v
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


## Whether a wall of piece `p` of padded cell `i`, whose top is covered, is drawn other
## than flat from its floor to its top: set back from its brow (a ledge). (Where it stands
## on the heap at its foot, the heap hides its lowest part: drawn flat all the same.)
static func _walls_shaped(job, i: int, p: int) -> bool:
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var m := material(c, cov, i, p)
	if Mat.edge_mode[m] != Mat.EDGE_ROUND or not _natural(job, i, p):
		return false
	for s in 4:
		if not has_side(p, s):
			continue
		var f: int = SIDE_OFF[s].x + SIDE_OFF[s].y * job.dz
		if not has_side(portion(c, sh, cov, i + f), OPP[s]) and _ledge(job, i, p, s) > 0.0:
			return true
	return false


## Corner `k` of a cell as the cell beside it across side `s` numbers it.
static func _mirror(k: int, s: int) -> int:
	# Across N or S the corners swap NW-SW and NE-SE; across W or E, NW-NE and SW-SE.
	return [3, 2, 1, 0][k] if s < 2 else [1, 0, 3, 2][k]


## Whether the plan of piece `p` of padded cell `i` may turn a corner out on it: a brow
## of its own that does not run on along the cell beside past an end, or a diagonal one.
static func _turns(job, i: int, p: int) -> bool:
	if p < FULL:
		return true
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dz: int = job.dz
	for s in 4:
		var f: int = SIDE_OFF[s].x + SIDE_OFF[s].y * dz
		if has_side(portion(c, sh, cov, i + f), OPP[s]):
			continue
		for s2 in ([2, 3] if s < 2 else [0, 1]):
			var f2: int = SIDE_OFF[s2].x + SIDE_OFF[s2].y * dz
			# Past this end the cell beside holds nothing at the corner: the brow turns
			# out square (a half there going on from the corner turns it at 135°, which
			# leaves the walls as they are).
			var k: int = SIDE_K[s][0] if SIDE_K[s2].has(SIDE_K[s][0]) else SIDE_K[s][1]
			var p2 := portion(c, sh, cov, i + f2)
			var k2 := _mirror(k, s2)
			if p2 == EMPTY or (p2 != FULL and p2 == (k2 + 2) & 3):
				return true
	return false


## The brows and feet of padded cell `i` when a rounded edge reaches it ([drops, heaps]),
## else an empty array: ChunkMesher draws it its own way.
static func prepare(job, i: int) -> Array:
	if not job.rounded:
		return []
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	if _plain_window(c, sh, cov, i, job.dy, job.dz):
		return []
	# A whole cell under a whole one of a material that does not round: its walls stand
	# flat (see _walls_shaped), but where they turn a corner.
	var whole := cov[c[i]] and sh[i] < 16 and cov[c[i + job.dy]] and sh[i + job.dy] < 16
	if whole and Mat.edge_mode[c[i]] == Mat.EDGE_SHARP:
		return []
	var p := portion(c, sh, cov, i)
	if p == EMPTY or _odd(job, i):
		return []
	var turns := _turns(job, i, p)
	if whole and Mat.edge_mode[c[i]] != Mat.EDGE_ROUND and not turns:
		return []
	var covered := open_part(p, portion(c, sh, cov, i + job.dy)) == EMPTY
	if covered and not turns and not _walls_shaped(job, i, p):
		return []
	var drops := segments(job, i)
	if covered and _corners(drops).is_empty() and not _walls_shaped(job, i, p):
		return []
	# A covered top has no heaps to draw.
	var heaps := PackedFloat32Array() if covered else feet(job, i)
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
	# A covered top needs its entry only for an open wall (see below).
	var entry := _entry(t, drops, heaps) if t != EMPTY else []
	var ln: Array = entry[1] if t != EMPTY else []
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
		# Textured by x and z like a flat top (not as a slope, whose patterns go by its
		# height over the level): the rounding is low, and its texels join the top's.
		buf.shape(base, entry[0], Color(1, 1, 1), Vector2(pack(mt * 3, edges, flag),
			around if t == FULL else float(NO_TILES)))
	var below_drops := PackedFloat32Array()
	var below_heaps := PackedFloat32Array()
	var below_ready := false
	var white := Color(1, 1, 1)
	# Corners rounded in plan: the walls bend round them (from the whole side or diagonal,
	# whose brow stops at the arc).
	var cuts := _corners(drops)
	for g in range(0, drops.size(), ST):
		if int(drops[g + 8]) != MIDDLE:
			continue
		var kind := int(drops[g + 9])
		var a := Vector2(drops[g], drops[g + 1])
		var b := Vector2(drops[g + 2], drops[g + 3])
		if kind < DIAG_KIND:
			a = SIDE_A[kind]
			b = SIDE_B[kind]
		else:
			a = Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 1) & 3]) * 0.5
			b = Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 3) & 3]) * 0.5
		var n := Vector2(drops[g + 4], drops[g + 5])
		var open := not has_side(pa, kind) if kind < DIAG_KIND else (pa == EMPTY or (pa != FULL and pa != p))
		var inset := drops[g + 10]
		if inset > 0.0:
			var ab := _ledge_wall(job, buf, i, base, drops, heaps, g, open)
			a = ab[0]
			b = ab[1]
		# A wall bent round a corner under a covered top stands from the floor whatever is
		# before it: the heap of the ground below hides its foot.
		var bent := not open and inset == 0.0 and not cuts.is_empty()
		var below := inset == 0.0 and not bent and _solid_at(job, i - dy, (a + b) * 0.5 + n * 0.05)
		if below and not below_ready:
			below_drops = segments(job, i - dy)
			below_heaps = feet(job, i - dy)
			below_ready = true
		var tops := PackedFloat32Array()
		var bottoms := PackedFloat32Array()
		# Along a side, the lines the top has there (its edge meets the wall's top).
		var qs := GRID_P
		# The wall's shape where the top's entry keeps it (made once for all such cells).
		var shape = null
		if not open and not below and cuts.is_empty() and kind < DIAG_KIND and inset == 0.0:
			qs = ENDS
			tops = ENDS_UP
			shape = _plain_walls[kind]
		elif open and inset == 0.0 and not below and (kind < DIAG_KIND or t == p):
			if entry.is_empty():
				entry = _entry(t, drops, heaps)
				ln = entry[1]
			# The top's own heights along the side (or its diagonal), made with it.
			qs = GRID_P if kind == DIAG_KIND else ln[0] if kind < 2 else ln[1]
			tops = entry[2][kind]
			shape = entry[3][kind]
			if shape == null:
				shape = _wall_shape(a, b, n, kind, tops, _zeros(qs.size()), qs, cuts)
				entry[3][kind] = shape
		elif not open and not below and cuts.is_empty():
			qs = ENDS
			tops = ENDS_UP
			bottoms = ENDS_DOWN
		elif bent:
			# Floor to top, bent round a corner: the same for every cell of a rounded cliff.
			var wkey := cuts.duplicate()
			wkey.append(kind)
			wkey.append(p)
			shape = _bent_walls.get(wkey)
			if shape == null:
				if _bent_walls.size() >= SHAPES_MAX:
					_bent_walls.clear()
				shape = _wall_shape(a, b, n, kind, _ones(GN), _zeros(GN), GRID_P, cuts)
				_bent_walls[wkey] = shape
		else:
			if kind < DIAG_KIND and inset == 0.0 and not below and open:
				if entry.is_empty():
					entry = _entry(t, drops, heaps)
					ln = entry[1]
				qs = ln[0] if kind < 2 else ln[1]
			for q: float in qs:
				var pt := _moved(a.lerp(b, q), cuts)
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
		var packed := Vector2(pack(m * 3 + 1, edges, flag), around_w)
		if shape == null:
			_wall(buf, base, a, b, n, kind, tops, bottoms, packed, white, qs, cuts)
		elif not shape.is_empty():
			buf.shape(base, shape, white, packed)
		if int(drops[g + 7]) == WALL_ONLY and open:
			# Against a slope, a trunk or a form: the gap over the dipping top.
			var nj: int = i + SIDE_OFF[kind].x + SIDE_OFF[kind].y * dz
			var caps := PackedFloat32Array()
			for q: float in qs:
				caps.append(Slopes.bent_height(job, nj, a.lerp(b, q) - Vector2(SIDE_OFF[kind])) if cov[c[nj]] and sh[nj] & 15 != 0 else 1.0)
			_wall(buf, base, a, b, -n, kind, caps, tops, Vector2(pack(c[nj] * 3 + 1, 0, 0), float(NO_TILES)), white, qs)
	if not cuts.is_empty():
		_floor(job, buf, i, base, p, cuts, drops)
	if t == EMPTY:
		return
	_shared_sides(job, buf, i, base, t, entry)


## The ground of the level below piece `p` of padded cell `i` where the corners `cuts`
## round its plan off: the strip between the old corner and the arc (with the heap at the
## arc's foot) would show nothing there, since the top below is covered. Not where the
## level below rounds the same corner (a rounded cliff going on down).
static func _floor(job, buf, i: int, base: Vector3, p: int, cuts: PackedFloat32Array,
		drops: PackedFloat32Array) -> void:
	var dy: int = job.dy
	var below := i - dy
	if below < 0:
		return
	# A cliff going on down: the level below turns the same corners (the same square
	# corner of ground of the same edge, open round it).
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dz: int = job.dz
	var info := _infos(job)
	var vb := info[below]
	if vb == 0:
		vb = _info(job, below)
	var pb := (vb & 7) - 1
	var mb := (vb >> 5) & 255
	var rest := PackedFloat32Array()
	for g in range(0, cuts.size(), ST):
		var cpt := Vector2(cuts[g] + cuts[g + 2] - cuts[g + 4], cuts[g + 1] + cuts[g + 3] - cuts[g + 5])
		var kx := roundi(cpt.x)
		var kz := roundi(cpt.y)
		var k: int = [[0, 3], [1, 2]][kx][kz]
		var same := pb != EMPTY and (pb == FULL or pb == k) and vb & ODD_BIT == 0 and vb & NATURAL_BIT != 0 \
				and Mat.edge_mode[mb] == int(cuts[g + 7]) and Mat.edge_size[mb] == cuts[g + 6]
		if same:
			# The other three cells round the corner hold none of it.
			for o: Vector2i in [Vector2i(kx * 2 - 1, 0), Vector2i(0, kz * 2 - 1), Vector2i(kx * 2 - 1, kz * 2 - 1)]:
				var po := portion(c, sh, cov, below + o.x + o.y * dz)
				# Their corner at C: k mirrored across the sides crossed.
				var ko := k
				if o.x != 0:
					ko = [1, 0, 3, 2][ko]
				if o.y != 0:
					ko = [3, 2, 1, 0][ko]
				if po == FULL or (po >= 0 and po != (ko + 2) & 3):
					same = false
					break
		if not same:
			rest.append_array(cuts.slice(g, g + ST))
	if rest.is_empty():
		return
	var need := rest
	# The ground below lies level there, heaped up at the foot of this level's walls (its
	# brows, as `feet` gives them to the ground below; a brow of the level below as near
	# as this is left out).
	var heaps := PackedFloat32Array()
	for g in range(0, drops.size(), ST):
		if drops[g + 6] > 0.0 and drops[g + 7] != WALL_ONLY and drops[g + 10] == 0.0:
			heaps.append_array(drops.slice(g, g + ST))
	var none := PackedFloat32Array()
	var out_p := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var idx := PackedInt32Array()
	# Along each brow of the piece, strips from its old line in to the arc (the points
	# its wall moves along), so they meet the ground beside on its line and the wall's
	# foot on the arc.
	for s in 5:
		var a: Vector2
		var b: Vector2
		if s < DIAG_KIND:
			if not has_side(p, s):
				continue
			a = SIDE_A[s]
			b = SIDE_B[s]
		else:
			if p == FULL:
				continue
			a = Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 1) & 3]) * 0.5
			b = Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(p + 3) & 3]) * 0.5
		var olds := PackedVector2Array()
		var news := PackedVector2Array()
		var moved := false
		for q: float in GRID:
			var pt := a.lerp(b, q)
			var pj := _project(pt, need)
			olds.append(pt)
			news.append(Vector2(pj.x, pj.y))
			moved = moved or pj.z != 0.0 or pj.w != 0.0
		if not moved:
			continue
		for k in GN - 1:
			if olds[k] == news[k] and olds[k + 1] == news[k + 1]:
				continue
			var quad := [olds[k], olds[k + 1], news[k + 1], news[k]]
			if not _solid_at(job, below, (olds[k] + olds[k + 1] + news[k] + news[k + 1]) * 0.25):
				continue
			var start := out_p.size()
			for pt: Vector2 in quad:
				var sf := surface(pt, none, heaps)
				out_p.append(Vector3(pt.x, sf.x - 1.0, pt.y))
				out_n.append(Vector3(-sf.y, 1.0, -sf.z).normalized())
				out_uv.append(pt)
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var v0: Vector3 = out_p[start + tri[0]]
				var v1: Vector3 = out_p[start + tri[1]]
				var v2: Vector3 = out_p[start + tri[2]]
				var cr := (v1 - v0).cross(v2 - v0)
				if absf(cr.y) < 0.0000001:
					continue
				# Clockwise seen from above.
				if cr.y > 0.0:
					idx.append_array([start + tri[0], start + tri[2], start + tri[1]])
				else:
					idx.append_array([start + tri[0], start + tri[1], start + tri[2]])
	if idx.is_empty():
		return
	var mf := material(c, cov, below, portion(c, sh, cov, below))
	buf.shape(base, [out_p, out_n, out_uv, idx], Color(1, 1, 1), Vector2(pack(mf * 3, 0, 0), float(NO_TILES)))


## The walls of the ground beside piece `t` of padded cell `i` whose top is covered,
## over the top of `t` where it dips by them; `ln` the lines of its top (see lines).
static func _shared_sides(job, buf, i: int, base: Vector3, t: int, entry: Array) -> void:
	var ln: Array = entry[1]
	var c: PackedByteArray = job.c
	var sh: PackedByteArray = job.sh
	var cov: PackedByteArray = job.cov
	var dz: int = job.dz
	var dy: int = job.dy
	var white := Color(1, 1, 1)
	# Sides shared with ground whose top is covered: its wall shows over the dipping top.
	for s in 4:
		if not has_side(t, s):
			continue
		var nj: int = i + SIDE_OFF[s].x + SIDE_OFF[s].y * dz
		var pn := portion(c, sh, cov, nj)
		if not has_side(pn, OPP[s]) or _odd(job, nj) or has_side(open_part(pn, portion(c, sh, cov, nj + dy)), OPP[s]):
			continue
		var tops := PackedFloat32Array()
		var dips := false
		var qs: PackedFloat32Array = ln[0] if s < 2 else ln[1]
		for h: float in entry[2][s]:
			dips = dips or h < 0.999
			tops.append(minf(h, 1.0))
		if dips:
			var ones := PackedFloat32Array()
			ones.resize(qs.size())
			ones.fill(1.0)
			_wall(buf, base, SIDE_A[s], SIDE_B[s], -Vector2(SIDE_OFF[s]), s, ones, tops,
				Vector2(pack(material(c, cov, nj, pn) * 3 + 1, 0, 0), float(NO_TILES)), white, qs)


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
			float(NO_TILES)), white, GRID_P)
	return [wa - n * inset, wb - n * inset]


## A wall along a..b facing `n` (side `kind` or a diagonal), from `bottoms` up to `tops`
## at the points `qs` along it (of GRID); one quad where both stay level.
static func _wall(buf, base: Vector3, a: Vector2, b: Vector2, n: Vector2, kind: int, tops: PackedFloat32Array,
		bottoms: PackedFloat32Array, packed: Vector2, color: Color, qs: PackedFloat32Array,
		cuts := PackedFloat32Array()) -> void:
	var shape := _wall_shape(a, b, n, kind, tops, bottoms, qs, cuts)
	if not shape.is_empty():
		buf.shape(base, shape, color, packed)


## The wall of `_wall` at the origin, as MeshBuffers.shape takes it (empty where it has
## no height anywhere). Where the corners `cuts` round the plan, its points move onto
## their arcs (or cuts) and face out from them there.
static func _wall_shape(a: Vector2, b: Vector2, n: Vector2, kind: int, tops: PackedFloat32Array,
		bottoms: PackedFloat32Array, qs: PackedFloat32Array, cuts := PackedFloat32Array()) -> Array:
	var nn := Vector3(n.x, 0.0, n.y)
	var level := true
	var gn := qs.size()
	var at := PackedVector2Array()
	var faces := PackedVector2Array()
	at.resize(gn)
	faces.resize(gn)
	for g in gn:
		var pt := a.lerp(b, qs[g])
		var pj := _project(pt, cuts) if not cuts.is_empty() else Vector4(pt.x, pt.y, 0.0, 0.0)
		at[g] = Vector2(pj.x, pj.y)
		faces[g] = Vector2(pj.z, pj.w)
		if faces[g] != Vector2.ZERO:
			level = false
	var flat := true
	for g in range(1, gn):
		if absf(tops[g] - tops[0]) > 0.0001 or absf(bottoms[g] - bottoms[0]) > 0.0001:
			flat = false
			break
	var steps: Array = [0, gn - 1] if level and flat else range(gn)
	if flat and not level:
		# Level along it but bent round a corner: only the moved points, and where the
		# straight part starts.
		steps = []
		for g in gn:
			if g == 0 or g == gn - 1 or faces[g] != Vector2.ZERO or faces[g - 1] != Vector2.ZERO \
					or faces[g + 1] != Vector2.ZERO:
				steps.append(g)
	# A diagonal wall stands a little inside the ground (see _diag_wall).
	var inside := -n * EPS if kind == DIAG_KIND else Vector2.ZERO
	var out_p := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for g in range(steps.size() - 1):
		var g0: int = steps[g]
		var g1: int = steps[g + 1]
		var p0 := at[g0] + inside
		var p1 := at[g1] + inside
		if tops[g0] - bottoms[g0] < 0.0001 and tops[g1] - bottoms[g1] < 0.0001:
			continue
		if p0.distance_squared_to(p1) < 0.00000001:
			continue
		# Facing out of the plan: the wall's way, or the arc's at a moved point (a cut's
		# whole quad faces the cut's way).
		var f0 := faces[g0]
		var f1 := faces[g1]
		if f0 == Vector2.ZERO and f1.length_squared() > 2.0:
			f0 = f1
		elif f1 == Vector2.ZERO and f0.length_squared() > 2.0:
			f1 = f0
		var n0 := Vector3(f0.x, 0.0, f0.y).normalized() if f0 != Vector2.ZERO else nn
		var n1 := Vector3(f1.x, 0.0, f1.y).normalized() if f1 != Vector2.ZERO else nn
		var vs: Array[Vector3] = [Vector3(p0.x, bottoms[g0], p0.y), Vector3(p1.x, bottoms[g1], p1.y)]
		var ns: Array[Vector3] = [n0, n1]
		if tops[g1] - bottoms[g1] >= 0.0001:
			vs.append(Vector3(p1.x, tops[g1], p1.y))
			ns.append(n1)
		if tops[g0] - bottoms[g0] >= 0.0001:
			vs.append(Vector3(p0.x, tops[g0], p0.y))
			ns.append(n0)
		# Clockwise seen from the front (as _wound turns them).
		if (vs[1] - vs[0]).cross(vs[2] - vs[0]).dot(nn) > 0.0:
			vs.reverse()
			ns.reverse()
		var start := out_p.size()
		for v_k in vs.size():
			var v := vs[v_k]
			out_p.append(v)
			out_n.append(ns[v_k])
			out_uv.append(face_uv(SIDE_D[kind], v) if kind < DIAG_KIND else Vector2(v.x, 1.0 - v.y))
		idx.append_array([start, start + 1, start + 2])
		if vs.size() == 4:
			idx.append_array([start, start + 2, start + 3])
	if out_p.is_empty():
		return []
	return [out_p, out_n, out_uv, idx]


## The lines of GRID the top over piece `t` is drawn on, across x and z ([xs, zs]): only
## where the brows and feet `drops`, `heaps` bend it that way. Along a straight brow the
## height stays the same, so it needs the lines across it near it (and the first one
## past its reach, where the top goes on flat), not along it; the free end of a brow (a
## corner) bends it both ways. A half (its diagonal through the grid's points) and a
## diagonal brow take the whole grid. The lines on a side depend only on the brows that
## reach it, which the cell beside sees too, so the tops meet.
static func lines(drops: PackedFloat32Array, heaps: PackedFloat32Array, t: int) -> Array:
	if t != FULL:
		return [GRID_P, GRID_P]
	var xm := 1 | 32
	var zm := 1 | 32
	for segs: PackedFloat32Array in [drops, heaps]:
		var foot := segs == heaps
		for g in range(0, segs.size(), ST):
			var r := segs[g + 6]
			if r <= 0.0 or (not foot and segs[g + 7] == WALL_ONLY):
				continue
			# A corner lies within the bands round the free ends of its brows (T1, T2).
			if segs[g + 9] >= CORNER_KIND:
				continue
			var reach := r + (0.0 if foot else segs[g + 10])
			var ax := segs[g]
			var az := segs[g + 1]
			var bx := segs[g + 2]
			var bz := segs[g + 3]
			if az == bz:
				zm |= _band(az, reach)
			elif ax == bx:
				xm |= _band(ax, reach)
			else:
				return [GRID_P, GRID_P]
			for e in 2:
				var ex := ax if e == 0 else bx
				var ez := az if e == 0 else bz
				if (ex < -reach or ex > 1.0 + reach or ez < -reach or ez > 1.0 + reach) \
						or _continued(segs, g, ex, ez, foot):
					continue
				xm |= _band(ex, reach)
				zm |= _band(ez, reach)
			if xm == ALL_LINES and zm == ALL_LINES:
				return [GRID_P, GRID_P]
	var lx := _mask_lines(xm)
	var lz := _mask_lines(zm)
	return [lx, lz]


## The lines of GRID within `reach` of `at`, and the first past it each way.
static func _band(at: float, reach: float) -> int:
	var m := 0
	var lo := -1
	var hi := -1
	for k in GN:
		var q := GRID[k]
		if absf(q - at) < reach:
			m |= 1 << k
		elif q <= at:
			lo = k
		elif hi < 0:
			hi = k
	if lo >= 0:
		m |= 1 << lo
	if hi >= 0:
		m |= 1 << hi
	return m


## Whether segment `g` of `segs` goes on straight past its end (ex, ez): another one the
## same way with the same edge starts there, so no corner rounds at it.
static func _continued(segs: PackedFloat32Array, g: int, ex: float, ez: float, foot: bool) -> bool:
	for h in range(0, segs.size(), ST):
		if h == g or segs[h + 4] != segs[g + 4] or segs[h + 5] != segs[g + 5] or segs[h + 6] != segs[g + 6] \
				or segs[h + 7] != segs[g + 7] or (not foot and segs[h + 10] != segs[g + 10]):
			continue
		if (segs[h] == ex and segs[h + 1] == ez) or (segs[h + 2] == ex and segs[h + 3] == ez):
			return true
	return false


static func _mask_lines(m: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in GN:
		if m & (1 << k):
			out.append(GRID[k])
	return out


## The top over piece `t` of a cell on the GRID, its heights from the brows and feet:
## flat squares as a plain top (with the cell's edge codes), the rest as slopes.
static func _entry(t: int, drops: PackedFloat32Array, heaps: PackedFloat32Array) -> Array:
	# What shapes the top, the same for every cell with the same edges round it.
	var key := PackedFloat32Array([t])
	key.append_array(drops)
	key.append(-9.0)
	key.append_array(heaps)
	var entry: Array = _shapes.get(key, [])
	if entry.is_empty():
		if _shapes.size() >= SHAPES_MAX:
			_shapes.clear()
		var ln := lines(drops, heaps, t)
		var ne_sw := _splits_ne_sw(t, drops, heaps)
		# Only the brows that round shape the heights.
		drops = _rounding(drops)
		heaps = _rounding(heaps)
		# The heights along the sides on the top's lines, and along the half's diagonal.
		var cuts := _corners(drops)
		var sides := []
		for s in 4:
			var hs := PackedFloat32Array()
			for q: float in ln[0] if s < 2 else ln[1]:
				hs.append(height(_moved(SIDE_A[s].lerp(SIDE_B[s], q), cuts), drops, heaps))
			sides.append(hs)
		var diag := PackedFloat32Array()
		if t >= 0 and t < FULL:
			var a := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(t + 1) & 3]) * 0.5
			var b := Vector2(0.5, 0.5) + Vector2(CORNER_DIRS[(t + 3) & 3]) * 0.5
			for q: float in GRID:
				diag.append(height(_moved(a.lerp(b, q), cuts), drops, heaps))
		sides.append(diag)
		entry = [_top_shape(t, drops, heaps, ln, ne_sw) if t != EMPTY else [], ln, sides, [null, null, null, null, null]]
		_shapes[key] = entry
	return entry


static func _side_wall(s: int) -> Array:
	return _wall_shape(SIDE_A[s], SIDE_B[s], Vector2(SIDE_OFF[s]), s, PackedFloat32Array([1.0, 1.0]),
		PackedFloat32Array([0.0, 0.0]), PackedFloat32Array([0.0, 1.0]))


## How the squares of the top over piece `t` split: along the piece's diagonal, or a
## diagonal brow's near it (NE to SW), else NW to SE.
static func _splits_ne_sw(t: int, drops: PackedFloat32Array, heaps: PackedFloat32Array) -> bool:
	if t != FULL:
		return t == 0 or t == 2
	for segs: PackedFloat32Array in [drops, heaps]:
		for g in range(0, segs.size(), ST):
			if int(segs[g + 9]) == DIAG_KIND and segs[g + 4] * segs[g + 5] > 0.0:
				return true
	return false


## The segments of `segs` that round (a radius, not a wall only).
static func _rounding(segs: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for g in range(0, segs.size(), ST):
		if segs[g + 6] > 0.0 and segs[g + 7] != WALL_ONLY:
			out.append_array(segs.slice(g, g + ST))
	return out


static func _ones(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(1.0)
	return out


static func _zeros(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	return out


## The top over piece `t` at the origin, as MeshBuffers.shape takes it.
static func _top_shape(t: int, drops: PackedFloat32Array, heaps: PackedFloat32Array, ln: Array, ne_sw: bool) -> Array:
	var xs: PackedFloat32Array = ln[0]
	var zs: PackedFloat32Array = ln[1]
	var nx := xs.size()
	var nz := zs.size()
	var dir := Vector2(CORNER_DIRS[t]) if t < FULL else Vector2.ZERO
	var hs := PackedFloat32Array()
	var ns: Array = []
	var smooth := PackedByteArray()
	var inside := PackedByteArray()
	hs.resize(nx * nz)
	ns.resize(nx * nz)
	smooth.resize(nx * nz)
	inside.resize(nx * nz)
	# Where a corner rounds the plan, the points cut off move onto its arc (or cut).
	var cuts := _corners(drops)
	var spot := PackedVector2Array()
	spot.resize(nx * nz)
	for b in nz:
		for a in nx:
			var pt := Vector2(xs[a], zs[b])
			var k := b * nx + a
			inside[k] = 1 if (t == FULL or (pt - Vector2(0.5, 0.5)).dot(dir) > -0.0001) and not _on_ledge(pt, drops) else 0
			if not cuts.is_empty():
				var pj := _project(pt, cuts)
				pt = Vector2(pj.x, pj.y)
			spot[k] = pt
			if inside[k]:
				var sf := surface(pt, drops, heaps)
				hs[k] = sf.x
				ns[k] = Vector3(-sf.y, 1.0, -sf.z).normalized()
				smooth[k] = int(sf.w)
	var out_p := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var idx := PackedInt32Array()
	# A corner's vertex as a level top's (normal up) and as a rounded one's (the curve's
	# normal), shared by the triangles round it; -1 where not made yet.
	var up_at := PackedInt32Array()
	var round_at := PackedInt32Array()
	up_at.resize(nx * nz)
	round_at.resize(nx * nz)
	up_at.fill(-1)
	round_at.fill(-1)
	var flat_at := {}
	var pos := PackedVector3Array()
	pos.resize(nx * nz)
	for k in nx * nz:
		pos[k] = Vector3(spot[k].x, hs[k], spot[k].y)
	var tri := PackedInt32Array([0, 0, 0])
	for b in nz - 1:
		for a in nx - 1:
			var k0 := b * nx + a
			var k1 := k0 + 1
			var k2 := k0 + nx + 1
			var k3 := k0 + nx
			var n_in := inside[k0] + inside[k1] + inside[k2] + inside[k3]
			if n_in < 3:
				continue
			for half in (1 if n_in == 3 else 2):
				if n_in == 3:
					var n := 0
					for k in [k0, k1, k2, k3]:
						if inside[k]:
							tri[n] = k
							n += 1
				elif ne_sw:
					tri[0] = k0 if half == 0 else k1
					tri[1] = k1 if half == 0 else k2
					tri[2] = k3
				else:
					tri[0] = k0
					tri[1] = k1 if half == 0 else k2
					tri[2] = k2 if half == 0 else k3
				var level := absf(hs[tri[0]] - 1.0) < 0.0001 and absf(hs[tri[1]] - 1.0) < 0.0001 \
						and absf(hs[tri[2]] - 1.0) < 0.0001
				var cr := (pos[tri[1]] - pos[tri[0]]).cross(pos[tri[2]] - pos[tri[0]])
				# Two corners moved onto one point of an arc: nothing to draw.
				if absf(cr.y) < 0.000001:
					continue
				# Clockwise seen from above (Godot's front faces).
				if cr.y > 0.0:
					var swap := tri[1]
					tri[1] = tri[2]
					tri[2] = swap
				if level or smooth[tri[0]] + smooth[tri[1]] + smooth[tri[2]] != 0:
					for k: int in tri:
						var at := up_at[k] if level else round_at[k]
						if at < 0:
							at = out_p.size()
							if level:
								up_at[k] = at
							else:
								round_at[k] = at
							out_p.append(pos[k])
							out_n.append(Vector3.UP if level else ns[k])
							out_uv.append(Vector2(pos[k].x, pos[k].z))
						idx.append(at)
					continue
				# A bevel: flat, the triangle's own normal.
				var nrm := cr.normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				for k: int in tri:
					var fk := Vector4(k, nrm.x, nrm.y, nrm.z)
					var at: int = flat_at.get(fk, -1)
					if at < 0:
						at = out_p.size()
						flat_at[fk] = at
						out_p.append(pos[k])
						out_n.append(nrm)
						out_uv.append(Vector2(pos[k].x, pos[k].z))
					idx.append(at)
	return [out_p, out_n, out_uv, idx]
