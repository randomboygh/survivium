extends RefCounted
## What the meshers share: the tables of the cell faces and the words packed into a
## vertex for the world shader (see world.gdshader), the constants of edges, flags and
## corner curves, and the primitives every mesh is drawn with: a quad or a polygon
## wound clockwise (`_wound`), a piece of a cell's top (`_piece`), a curved diagonal
## wall (`_diag_wall`), a cell face (`_add`). ChunkMesher, SlopeMesher, WaterMesher and
## TrunkMesher extend it and keep its static tables between them.


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
## Vertex alpha of a waterfall's sheet, of the spray at its foot and of the foam where
## it lands (see WaterMesher.fall_faces).
const FALL_SHEET := 0.0
const FALL_SPRAY := 0.3
const FALL_FOAM := 0.5
## Half the width of a fall's spray and the most it rises, in cells.
const SPRAY_HALF := 0.75
const SPRAY_HIGH := 2.5
## Vertex alpha of the sea's water (WorldData.SEA_WATER; other water has 1).
const SEA_ALPHA := 0.85
## How far out from the step a waterfall's sheet reaches at its foot, in cells.
const FALL_SPREAD := 0.75
static var AIR: int = Mat.AIR
static var WATER: int = Mat.WATER
static var LEAVES: int = Mat.LEAVES
## Tile index meaning "no texture" (voxels) or "no neighbour" (transitions).
const NO_TILE := 255
## A material code in UV2 (see pack): NO_MATERIAL for a face drawn in its vertex colour
## (NO_TILE), and the lanes of UV2.y with no neighbour's top (NO_TILES, see
## ChunkMesher._around_tiles).
const NO_MATERIAL := 63
const NO_TILES := NO_MATERIAL * 0x41041
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
## The same bit on a textured face: it shows its material's sides' tile (see pack).
const SIDE_TILE := 1
const OPEN_TOP := 2
const SLOPE := 4
const DIAG := 8
const DIAG_CORNER := 64
const CORNER_DIRS := WorldData.CORNER_DIRS
## Pieces of a top (see _piece): a whole quarter of the cell, the half of the cell
## beyond the diagonal across corner q (a fill), and from CUT_BY on what is left of
## quarter q of a cell cut at corner CUT_BY + k (see cut_kind).
const QUARTER := 0
const CORNER := 2
const CUT_BY := 4
## Old slopes (see old_slopes): the part of quarter q away from its cut corner.
const OLD_CUT := 1
## Cut and filled corners run along the diagonal of the cell across the corner, from
## one neighbouring corner to the other (WorldData.corner_cut); with old slopes they
## take half a cell along each side, curved by CORNER_P and CURVE_STEPS (see
## old_slopes, Mat.corner_shape).
const CORNER_P := [1.0, 1.5, 2.0]
const CURVE_STEPS := 4
## Diagonals reach past their line, so the texels it runs through belong to the ground
## side and the shader's edge texels match what is drawn. A straight diagonal runs
## right through the middles of its pixels: an eighth of a pixel each way, well over
## the rounding of a phone's GPU, which would otherwise give those pixels to one side
## or the other from frame to frame (the light rims flickered).
const EPS := 1.0 / 64.0
## Cells around the chunk copied for neighbour lookups: corners look two cells away.
const PAD := 2
## The two corners on the sides E, W, S, N (in DIRS order), the one nearer the origin first.
const SIDE_CORNERS := [[1, 2], [0, 3], [], [], [3, 2], [0, 1]]
## Half edges of a top, 2 * edge + half (edges N, S, W, E; halves west/east or north/south):
## the corner of the neighbour across each, and the two half edges of each quarter.
const HALF_CORNER := [3, 2, 0, 1, 1, 2, 0, 3]
const QUARTER_HALVES := [[0, 4], [1, 6], [3, 7], [2, 5]]
## A log pillar that is no noted tree is drawn as a trunk 6 texels wide in its 8-texel
## cell; a tree's trunk has its own girth (see Growth.trunk_box).
const PILLAR := Rect2i(1, 1, 6, 6)
## What tops a piece of a trunk (see _bark).
const CAP_NONE := 0
const CAP_CUT := 1
const CAP_BARK := 2
const CELL := WorldData.CELL

static var _faces: Array = []
static var _covers_lut := PackedByteArray()
## Points of the corner curves, by corner and shape (see corner_curve).
static var _curves := {}
## The world being drawn has old slopes (WorldData.old_slopes): cut and filled corners
## take a triangle half a cell along each side, from the middle of one side to the
## middle of the next, along a curve by the material's corner shape (see corner_curve);
## a cell may be cut at several corners, each quarter on its own (OLD_CUT). Set from
## the world when a mesh job starts (ChunkMesher.start_rect, build_cap).
static var old_slopes := false


## Takes the materials of the bundles now loaded (Mods.activate): leaves are a role a
## bundle may give, so their number may differ from the last scene's.
static func forget() -> void:
	AIR = Mat.AIR
	WATER = Mat.WATER
	LEAVES = Mat.LEAVES
	_covers_lut = PackedByteArray()


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


## Packs a face's tile (material * 3 + kind: 0 the top's, 1 the sides', 2 the
## underside's; NO_TILE for its vertex colour), edge codes and flag into UV2.x (see
## world.gdshader): the material in 6 bits, the sides' tile as flag bit SIDE_TILE, the
## underside's by the face looking down.
static func pack(tile: int, edges: int, flag: int) -> float:
	if tile == NO_TILE:
		return float(NO_MATERIAL + 64 * edges + 16384 * flag)
	return float(tile / 3 + 64 * edges + 16384 * (flag | (SIDE_TILE if tile % 3 == 1 else 0)))


## Flag of a face with a diagonal across corner k: its corner side (or the other) is
## the face, and `code` is drawn along the diagonal.
static func _diag(k: int, corner_side: bool, code: int) -> int:
	return DIAG | k << 4 | (DIAG_CORNER if corner_side else 0) | code << 7


## The line of corner k's cut or fill on the top of a cell: the diagonal across it,
## from the neighbouring corner along x to the one along z. `shape` is kept for the
## materials' rounding (not drawn yet).
static func corner_curve(k: int, shape := 0) -> PackedVector2Array:
	if old_slopes:
		return _old_curve(k, shape)
	if _curves.has(k):
		return _curves[k]
	var o := Vector2(CORNER_DIRS[k])
	var pts := PackedVector2Array([Vector2(0.5, 0.5) + Vector2(-o.x, o.y) * 0.5,
		Vector2(0.5, 0.5) + Vector2(o.x, -o.y) * 0.5])
	_curves[k] = pts
	return pts


## Old slopes: the curve of corner k for corner shape `shape` (see CORNER_P) on the top
## of a cell, from the middle of its west or east side to the middle of its north or
## south side: u^p + v^p = 0.5^p around the cell's middle, p 1 a straight diagonal
## (stone), 1.5 a little rounded (soil), 2 a quarter circle (sand), in CURVE_STEPS
## straight pieces.
static func _old_curve(k: int, shape: int) -> PackedVector2Array:
	var key := 16 + k * 4 + shape
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


## The kind of piece for quarter q of a top cut at corners `cuts`: with old slopes each
## quarter by its own corner (OLD_CUT), else as cut_kind.
static func quarter_kind(cuts: int, q: int) -> int:
	if old_slopes:
		return OLD_CUT if cuts & (1 << q) else QUARTER
	return cut_kind(cuts)


## The kind of piece for quarter q of a top whose cut corners are `cuts` (one at most).
static func cut_kind(cuts: int) -> int:
	if cuts == 0:
		return QUARTER
	return CUT_BY + WorldData.level_of(cuts & -cuts)


## A flat piece of quarter `q` of a cell at height `h` (see QUARTER, CORNER, CUT_BY).
## `corners`, when given, are colours at the cell's corners NW, NE, SE, SW, blended
## across the piece.
static func _piece(buf, base: Vector3, h: float, q: int, kind: int, n: Vector3, color: Color, packed: Vector2,
		shape := 0, corners := PackedColorArray()) -> void:
	var o := Vector2(CORNER_DIRS[q])
	var corner := Vector2(0.5, 0.5) + o * 0.5
	var pts: Array
	if kind == OLD_CUT or kind == CORNER and old_slopes:
		# A fan from the middle of the cell (a cut) or from the corner (the corner beyond
		# the curve).
		var hub := Vector2(0.5, 0.5) if kind == OLD_CUT else corner
		var curve := _old_curve(q, shape)
		var off := o * (EPS if kind == OLD_CUT else -EPS)
		for j in curve.size() - 1:
			pts = [hub, curve[j] + off, curve[j + 1] + off]
			var tri := []
			for p: Vector2 in pts:
				tri.append(base + Vector3(p.x, h, p.y))
			_wound(buf, tri, n, pts, color, packed, _blend(corners, pts))
		return
	if kind == CORNER:
		# The corner and the two beside it, the diagonal a little past its line.
		var line := corner_curve(q)
		pts = [corner, line[0] - o * EPS, line[1] - o * EPS]
	elif kind == QUARTER:
		pts = [Vector2(0.5, 0.5), Vector2(0.5, corner.y), corner, Vector2(corner.x, 0.5)]
	else:
		var k := kind - CUT_BY
		if k == q:
			return
		if k == (q + 2) & 3:
			pts = [Vector2(0.5, 0.5), Vector2(0.5, corner.y), corner, Vector2(corner.x, 0.5)]
		else:
			# A quarter beside the cut corner: the triangle of it away from the diagonal,
			# which runs through its own corner and the middle of the cell.
			var ok := Vector2(CORNER_DIRS[k])
			var mid_side := Vector2(0.5, corner.y) if ok.x == o.x else Vector2(corner.x, 0.5)
			var off := -ok * EPS
			pts = [Vector2(0.5, 0.5) + off, corner + off, mid_side]
	var vs := []
	for p: Vector2 in pts:
		vs.append(base + Vector3(p.x, h, p.y))
	_wound(buf, vs, n, pts, color, packed, _blend(corners, pts))


## Colours at points `pts` of a cell (x, z in 0..1) blended from those at its corners
## NW, NE, SE, SW; none without corners.
static func _blend(corners: PackedColorArray, pts: Array) -> Array:
	if corners.is_empty():
		return []
	var out := []
	for p: Vector2 in pts:
		out.append(corners[0].lerp(corners[1], p.x).lerp(corners[3].lerp(corners[2], p.x), p.y))
	return out


## The wall along the diagonal of corner k (see corner_curve), a cell high, facing the
## corner (a cut) or away from it (a fill). It stands EPS inside the solid side, so
## where it meets the ground below on the line the ground is in front and the pixels on
## the line are the ground's. `shape` is kept for the materials' rounding.
static func _diag_wall(buf, base: Vector3, k: int, outward: bool, color: Color, packed: Vector2, shape := 0,
		h0 := 1.0, h1 := 1.0) -> void:
	if old_slopes:
		_old_diag_wall(buf, base, k, outward, color, packed, shape)
		return
	var o := Vector2(CORNER_DIRS[k])
	var curve := corner_curve(k)
	var inside := o * (-EPS if outward else EPS)
	var p1 := curve[0] + inside
	var p2 := curve[1] + inside
	var n := Vector3(o.x, 0.0, o.y).normalized() * (1.0 if outward else -1.0)
	var vs := [base + Vector3(p1.x, 0.0, p1.y), base + Vector3(p2.x, 0.0, p2.y)]
	var uvs := [Vector2(p1.x, 1.0), Vector2(p2.x, 1.0)]
	if h1 > 0.0:
		vs.append(base + Vector3(p2.x, h1, p2.y))
		uvs.append(Vector2(p2.x, 1.0 - h1))
	if h0 > 0.0:
		vs.append(base + Vector3(p1.x, h0, p1.y))
		uvs.append(Vector2(p1.x, 1.0 - h0))
	if vs.size() < 3:
		return
	_wound(buf, vs, n, uvs, color, packed)


## Old slopes: the wall along the curve of corner k (see _old_curve), a straight piece
## per piece of the curve; a round one has the curve's own normals at its points, so
## the light runs smoothly around it.
static func _old_diag_wall(buf, base: Vector3, k: int, outward: bool, color: Color, packed: Vector2,
		shape: int) -> void:
	var o := Vector2(CORNER_DIRS[k])
	var curve := _old_curve(k, shape)
	var inside := o * (-EPS if outward else EPS)
	for j in curve.size() - 1:
		var p1 := curve[j] + inside
		var p2 := curve[j + 1] + inside
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


## Adds a triangle or quad with corners in either order, turned to face along `n`;
## `cols`, when given, are the colours of the corners.
static func _wound(buf, vs: Array, n: Vector3, uvs: Array, color: Color, packed: Vector2, cols := []) -> void:
	var a: Vector3 = vs[0]
	var b: Vector3 = vs[1]
	var e: Vector3 = vs[2]
	if (b - a).cross(e - a).dot(n) > 0.0:
		vs.reverse()
		uvs.reverse()
		cols.reverse()
	if vs.size() == 4:
		buf.quad(vs, n, uvs, color, packed, cols)
	else:
		buf.tri(vs, n, uvs, color, packed, cols)


## Adds a face of the box `offset`..`offset + size` inside the cell at `base`.
static func _add(buf, face: Dictionary, d: int, base: Vector3, size: Vector3, offset: Vector3, color: Color, packed: Vector2) -> void:
	var pts := []
	var uvs := []
	for c in face.corners:
		var v: Vector3 = offset + c * size
		pts.append(base + v)
		uvs.append(face_uv(d, v))
	buf.quad(pts, face.normal, uvs, color, packed)


## 1 for materials that hide what is behind them (not air, water or leaves).
static func covers_table() -> PackedByteArray:
	if _covers_lut.is_empty():
		_covers_lut.resize(256)
		for m in 256:
			_covers_lut[m] = 1 if _covers(m) else 0
	return _covers_lut


## Cells that hide what is behind them; leaves and water do not.
static func _covers(m: int) -> bool:
	return m != AIR and m != WATER and m != LEAVES


## Materials of the cells beside a wall of padded cell `i` on its plane, packed like
## _around_tiles for UV2.y in the order of the wall's edges: above, below, and the
## ends of its texture row (W at i - s, E at i + s), each where its own side shows on
## the same plane (the cell before it, `f` on, open), else NO_MATERIAL. The shader
## lets their texels reach in over the boundary (the materials' `side_fray`).
static func _side_tiles(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, f: int, s: int) -> int:
	var m := c[i]
	var a := c[i + dy]
	var b := c[i - dy]
	var w := c[i - s]
	var e := c[i + s]
	var tn := a if a != m and cov[a] and not cov[c[i + dy + f]] else NO_MATERIAL
	var ts := b if b != m and cov[b] and not cov[c[i - dy + f]] else NO_MATERIAL
	var tw := w if w != m and cov[w] and not cov[c[i - s + f]] else NO_MATERIAL
	var te := e if e != m and cov[e] and not cov[c[i + s + f]] else NO_MATERIAL
	return tn | ts << 6 | tw << 12 | te << 18
