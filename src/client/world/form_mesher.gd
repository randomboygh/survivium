extends "res://src/client/world/mesh_faces.gd"
## Draws the built blocks that are not whole cubes (WorldData.forms: the build mode's
## ramps, upturned ramps and stairs) for ChunkMesher: each form is laid out rising
## toward the north and turned to the side it faces. A face on the side of the cell is
## left out where a cell that hides what is behind it lies beside, unless that one is a
## form too that leaves its side open (`covers_side`); the sloping and inner faces are
## always drawn.

const RAMP := WorldData.FORM_RAMP
const UPPER := WorldData.FORM_UPPER
const STAIRS := WorldData.FORM_STAIRS
## The faces of each form rising north: [direction (DIRS) of the side of the cell the
## face lies on, -1 inside the cell; the normal; the corners]. The normal of a slope is
## worked out from its corners.
const SHAPES := {
	RAMP: [
		[3, Vector3.DOWN, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[5, Vector3.FORWARD, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[-1, Vector3.ZERO, [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[1, Vector3.LEFT, [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]],
		[0, Vector3.RIGHT, [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 0, 1)]],
	],
	UPPER: [
		[2, Vector3.UP, [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[5, Vector3.FORWARD, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[-1, Vector3.ZERO, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]],
		[1, Vector3.LEFT, [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1)]],
		[0, Vector3.RIGHT, [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)]],
	],
	STAIRS: [
		[3, Vector3.DOWN, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]],
		[5, Vector3.FORWARD, [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)]],
		[2, Vector3.UP, [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 0.5), Vector3(0, 1, 0.5)]],
		[-1, Vector3.BACK, [Vector3(0, 0.5, 0.5), Vector3(1, 0.5, 0.5), Vector3(1, 1, 0.5), Vector3(0, 1, 0.5)]],
		[-1, Vector3.UP, [Vector3(0, 0.5, 0.5), Vector3(1, 0.5, 0.5), Vector3(1, 0.5, 1), Vector3(0, 0.5, 1)]],
		[4, Vector3.BACK, [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0.5, 1), Vector3(0, 0.5, 1)]],
		[1, Vector3.LEFT, [Vector3(0, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0.5, 1), Vector3(0, 0, 1)]],
		[1, Vector3.LEFT, [Vector3(0, 0.5, 0), Vector3(0, 1, 0), Vector3(0, 1, 0.5), Vector3(0, 0.5, 0.5)]],
		[0, Vector3.RIGHT, [Vector3(1, 0, 0), Vector3(1, 0.5, 0), Vector3(1, 0.5, 1), Vector3(1, 0, 1)]],
		[0, Vector3.RIGHT, [Vector3(1, 0.5, 0), Vector3(1, 1, 0), Vector3(1, 1, 0.5), Vector3(1, 0.5, 0.5)]],
	],
}


## Point `v` of a cell turned `turns` quarter turns about its middle, north to east.
static func turn(v: Vector3, turns: int) -> Vector3:
	for k in turns:
		v = Vector3(1.0 - v.z, v.y, v.x)
	return v


## Direction `d` (DIRS) turned as `turn` turns the points.
static func turn_dir(d: int, turns: int) -> int:
	if d < 0 or d == 2 or d == 3:
		return d
	var v: Vector3i = DIRS[d]
	for k in turns:
		v = Vector3i(-v.z, 0, v.x)
	return DIRS.find(v)


## Whether a block of form `form` has its side `d` (DIRS) wholly closed: then a cube
## beside it there hides its face, as beside a cube.
static func covers_side(form: int, d: int) -> bool:
	var kind := form & 3
	if kind == WorldData.FORM_CUBE:
		return true
	var turns := form >> 2 & 3
	if d == turn_dir(5, turns):
		return true
	return d == (2 if kind == UPPER else 3)


## Adds the faces of the block of material `m` and form `form` at `base`; `c` the padded
## cells round it (index `i`), `offsets` the steps to its neighbours in DIRS order,
## `forms` the forms of the padded cells by index.
static func form_faces(buf, c: PackedByteArray, cov: PackedByteArray, forms: Dictionary, offsets: PackedInt32Array,
		i: int, base: Vector3, m: int, form: int) -> void:
	var turns := form >> 2 & 3
	var none := float(NO_TILES)
	for f: Array in SHAPES.get(form & 3, []):
		var d := turn_dir(f[0], turns)
		if d >= 0:
			var j := i + offsets[d]
			if cov[c[j]] and (not forms.has(j) or covers_side(forms[j], d ^ 1)):
				continue
		var pts := []
		for v: Vector3 in f[2]:
			pts.append(turn(v, turns))
		var n: Vector3 = turn(f[1] + Vector3(0.5, 0, 0.5), turns) - Vector3(0.5, 0, 0.5)
		var flag := 0
		var tile := m * 3 + 1
		var uv_face := d
		if n == Vector3.ZERO:
			# The slope: its normal from its corners, its tile the top's (or the
			# underside's), textured in screen texels so it is not stretched.
			var a: Vector3 = pts[0]
			n = (pts[1] - a).cross(pts[2] - a).normalized()
			if n.y < 0.0:
				n = -n
			if (form & 3) == UPPER:
				n = -n
			flag = SLOPE
			tile = m * 3 + (2 if n.y < 0.0 else 0)
			uv_face = FACE_TOP if n.y > 0.0 else FACE_BOTTOM
		elif n.y > 0.5:
			tile = m * 3
			uv_face = FACE_TOP
		elif n.y < -0.5:
			tile = m * 3 + 2
			uv_face = FACE_BOTTOM
		else:
			uv_face = DIRS.find(Vector3i(roundi(n.x), 0, roundi(n.z)))
		var uvs := []
		var vs := []
		for v: Vector3 in pts:
			uvs.append(face_uv(uv_face, v))
			vs.append(base + v)
		_wound(buf, vs, n, uvs, Color(1, 1, 1), Vector2(pack(tile, 0, flag), none))
