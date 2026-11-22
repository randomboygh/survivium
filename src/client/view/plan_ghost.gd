extends RefCounted
## The blueprint's ghost as the shape it will make (PlanView, user 2026-11-22): the faces
## of the ghost cells merged into one see-through body per kind of work, no face between
## two cells of the same work, so a wall of five blocks is one wall. Blocks to build are
## tinted cold blue, ground to dig out (Plans.CUT) red. A block's form (Plans.forms: a
## ramp, an upturned ramp, stairs) is drawn as FormMesher lays it out; a fence is a post
## with rails to the fence cells beside it. A face to build against a solid block of the
## world is left out (it would only flicker against it). The ground to dig is a surface
## of its own, drawn through the ground over it.

const WorldData := preload("res://src/shared/world/world_data.gd")
const Forms := preload("res://src/client/world/form_mesher.gd")
const Plans := preload("res://src/shared/game/plans.gd")

const CELL := WorldData.CELL
const DIRS := Forms.DIRS
## The tints and how much they hide what is behind (alpha).
const BUILD := Color(0.45, 0.72, 1.0, 0.5)
const CUT := Color(1.0, 0.2, 0.16, 0.32)
## The light of a face by the way it faces (DIRS order: E, W, up, down, S, N), so the
## body reads as a solid.
const SHADE := [0.8, 0.8, 1.0, 0.6, 0.9, 0.9]
## A fence's half thickness round the middle of its cell and its height, in cells.
const FENCE_HALF := 0.125
const FENCE_HIGH := 0.75
## The six faces of a cube cell in DIRS order, corners 0..1 per axis.
const CUBE := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
]


## The ghost of the blueprint cells `cells` (cell -> item, Plans.cells) that `pick` lets
## through, with forms `forms`, against world `world` (null: no world): a surface of what
## is built in material `built`, one of the ground dug out in `dug`; null when there is
## nothing to draw.
static func build(cells: Dictionary, forms: Dictionary, world, pick: Callable, built: Material, dug: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var cut_verts := PackedVector3Array()
	var cut_colors := PackedColorArray()
	# The kind of work in each cell drawn: 0 build, 1 dig out, 2 fence.
	var work := {}
	for c: Vector3i in cells:
		if pick.call(c):
			var v: String = cells[c]
			work[c] = 1 if v == Plans.CUT else (2 if Plans.is_fence(v) else 0)
	for c: Vector3i in work:
		match work[c]:
			0:
				_block(verts, colors, c, int(forms.get(c, 0)), work, forms, world)
			1:
				_cut(cut_verts, cut_colors, c, work)
			2:
				_fence(verts, colors, c, work)
	if verts.is_empty() and cut_verts.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for part: Array in [[verts, colors, built], [cut_verts, cut_colors, dug]]:
		if part[0].is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part[0]
		arrays[Mesh.ARRAY_COLOR] = part[1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[2])
	return mesh


## A block to build at `c` of form `form`.
static func _block(verts: PackedVector3Array, colors: PackedColorArray, c: Vector3i, form: int, work: Dictionary,
		forms: Dictionary, world) -> void:
	var kind := form & 3
	if kind == WorldData.FORM_CUBE:
		for d in 6:
			if not _hidden(c, d, -1, work, forms, world):
				_face(verts, colors, c, CUBE[d], DIRS[d], BUILD, d)
		return
	var turns := form >> 2 & 3
	for f: Array in Forms.SHAPES[kind]:
		var d := Forms.turn_dir(f[0], turns)
		if d >= 0 and _hidden(c, d, form if f[0] <= 1 else -1, work, forms, world):
			continue
		var pts: Array = []
		for p: Vector3 in f[2]:
			pts.append(Forms.turn(p, turns))
		var n: Vector3 = f[1]
		for k in turns:
			n = Vector3(-n.z, n.y, n.x)
		_face(verts, colors, c, pts, n, BUILD, d)


## Whether the face of block `c` on side `d` is hidden: a block to build beside it closes
## that side (or, `same` a form, the same form lies beside, its side the same face), or
## the world has a solid block there that is not to be dug out.
static func _hidden(c: Vector3i, d: int, same: int, work: Dictionary, forms: Dictionary, world) -> bool:
	var n: Vector3i = c + DIRS[d]
	var w: int = work.get(n, -1)
	if w == 0:
		var nf: int = forms.get(n, 0)
		return nf == same or Forms.covers_side(nf, d ^ 1)
	return w == -1 and world != null and world.is_solid(n.x, n.y, n.z)


## Ground to dig out at `c`: the faces not against more of it.
static func _cut(verts: PackedVector3Array, colors: PackedColorArray, c: Vector3i, work: Dictionary) -> void:
	for d in 6:
		if work.get(c + DIRS[d], -1) != 1:
			_face(verts, colors, c, CUBE[d], DIRS[d], CUT, d)


## A fence at `c`: a post in the middle with rails to the fence cells on each side (both
## ways along x when there are none).
static func _fence(verts: PackedVector3Array, colors: PackedColorArray, c: Vector3i, work: Dictionary) -> void:
	var arms := []
	for d in [0, 1, 4, 5]:
		arms.append(work.get(c + DIRS[d], -1) == 2)
	if not arms.has(true):
		arms[0] = true
		arms[1] = true
	var lo := 0.5 - FENCE_HALF
	var hi := 0.5 + FENCE_HALF
	# The post, its sides where no rail goes on.
	_box(verts, colors, c, Vector3(lo, 0, lo), Vector3(hi, FENCE_HIGH, hi), [arms[0], arms[1], false, false, arms[2], arms[3]])
	# The rails: x from the post to the cell's side, open toward the post and toward the
	# next fence cell.
	var spans := [[Vector3(hi, 0, lo), Vector3(1, FENCE_HIGH, hi), 0], [Vector3(0, 0, lo), Vector3(lo, FENCE_HIGH, hi), 1],
		[Vector3(lo, 0, hi), Vector3(hi, FENCE_HIGH, 1), 4], [Vector3(lo, 0, 0), Vector3(hi, FENCE_HIGH, lo), 5]]
	for i in 4:
		if not arms[i]:
			continue
		var d: int = spans[i][2]
		var open := [false, false, false, false, false, false]
		open[d] = work.get(c + DIRS[d], -1) == 2
		open[d ^ 1] = true
		_box(verts, colors, c, spans[i][0], spans[i][1], open)


## A box from `a` to `b` (0..1 in cell `c`) without the sides `open` (DIRS order).
static func _box(verts: PackedVector3Array, colors: PackedColorArray, c: Vector3i, a: Vector3, b: Vector3,
		open: Array) -> void:
	for d in 6:
		if open[d]:
			continue
		var pts: Array = []
		for p: Vector3 in CUBE[d]:
			pts.append(Vector3(lerpf(a.x, b.x, p.x), lerpf(a.y, b.y, p.y), lerpf(a.z, b.z, p.z)))
		_face(verts, colors, c, pts, DIRS[d], BUILD, d)


## Adds the face with corners `pts` (0..1 in cell `c`, 3 or 4) facing `n` (zero: worked
## out from the corners, away from the middle of the cell), as triangles wound so that
## it faces out, in tint `tint` lit as side `d` (DIRS; -1 inside the cell: by its normal).
static func _face(verts: PackedVector3Array, colors: PackedColorArray, c: Vector3i, pts: Array, n: Vector3, tint: Color,
		d: int) -> void:
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[1]
	var e: Vector3 = pts[2]
	var cross := (b - a).cross(e - a)
	if n == Vector3.ZERO:
		var mid := Vector3.ZERO
		for p: Vector3 in pts:
			mid += p
		n = cross if cross.dot(mid / pts.size() - Vector3(0.5, 0.5, 0.5)) > 0.0 else -cross
	var shade: float
	if d >= 0:
		shade = SHADE[d]
	else:
		# A slope or a step inside the cell: lit as a top the more it faces up.
		var u := n.normalized()
		shade = lerpf(0.85, 1.0, maxf(u.y, 0.0)) if u.y >= 0.0 else 0.6
	var col := Color(tint.r * shade, tint.g * shade, tint.b * shade, tint.a)
	# Godot's front faces wind clockwise as seen from the front.
	var flip: bool = cross.dot(n) > 0.0
	var base := Vector3(c)
	for i in range(1, pts.size() - 1):
		var tri := [pts[0], pts[i + 1], pts[i]] if flip else [pts[0], pts[i], pts[i + 1]]
		for p: Vector3 in tri:
			verts.append((base + p) * CELL)
			colors.append(col)
