extends RefCounted
## Builds meshes from the cell grid: one textured quad per visible cell face.
## A chunk mesh holds all levels of a 16x16 column; the cutaway hides upper levels
## in the shader, and `build_cap` closes the cut with dark tops.

const Mat := preload("res://src/shared/materials.gd")
const MeshBuffers := preload("res://src/client/mesh_buffers.gd")

## The texture atlas is 8x8 tiles of 16 px; each material has top, side and bottom tiles.
const ATLAS_TILES := 8
const UV_EPS := 0.002
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
const WATER_TOP := 0.875

static var _faces: Array = []


## Per direction: corners in clockwise order seen from outside, their UVs and the normal.
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
		var uvs := []
		for p in c:
			var v: Vector3 = p
			if d == FACE_TOP or d == FACE_BOTTOM:
				uvs.append(Vector2(v.x, v.z))
			elif d < 2:
				uvs.append(Vector2(v.z, 1.0 - v.y))
			else:
				uvs.append(Vector2(v.x, 1.0 - v.y))
		_faces.append({"corners": c, "uvs": uvs, "normal": n})
	return _faces


## Returns [solid_mesh_or_null, water_mesh_or_null] for the column of cells x0..x0+size, z0..z0+size.
static func build_chunk(w, x0: int, z0: int, size: int) -> Array:
	var faces := face_table()
	var solid := MeshBuffers.new()
	var water := MeshBuffers.new()
	var x1 := mini(x0 + size, w.size_x)
	var z1 := mini(z0 + size, w.size_z)
	for y in w.size_y:
		for z in range(z0, z1):
			for x in range(x0, x1):
				var m: int = w.get_cell(x, y, z)
				if m == Mat.AIR:
					continue
				var base := Vector3(x, y, z)
				if m == Mat.WATER:
					var top_open: bool = w.get_cell(x, y + 1, z) == Mat.AIR
					var h := WATER_TOP if top_open else 1.0
					for d in 6:
						var dir: Vector3i = DIRS[d]
						if d != FACE_BOTTOM and w.get_cell(x + dir.x, y + dir.y, z + dir.z) == Mat.AIR:
							add_face(water, faces[d], base, m, d, 1.0, h)
					continue
				for d in 6:
					var dir: Vector3i = DIRS[d]
					if d == FACE_BOTTOM and y == 0:
						continue
					if Mat.is_solid(w.get_cell(x + dir.x, y + dir.y, z + dir.z)):
						continue
					add_face(solid, faces[d], base, m, d, 1.0, 1.0)
	return [null if solid.is_empty() else solid.to_mesh(), null if water.is_empty() else water.to_mesh()]


## Dark tops of solid cells on `level` that are covered by solid cells above:
## what you see in the cut when looking into a mountain.
static func build_cap(w, level: int) -> ArrayMesh:
	if level < 0 or level >= w.size_y - 1:
		return null
	var top: Dictionary = face_table()[FACE_TOP]
	var buf := MeshBuffers.new()
	for z in w.size_z:
		for x in w.size_x:
			var m: int = w.get_cell(x, level, z)
			if Mat.is_solid(m) and w.is_solid(x, level + 1, z):
				add_face(buf, top, Vector3(x, level, z), m, FACE_TOP, 0.4, 1.0)
	return null if buf.is_empty() else buf.to_mesh()


static func add_face(buf, face: Dictionary, base: Vector3, m: int, d: int, shade: float, height: float) -> void:
	var kind := 1
	if d == FACE_TOP:
		kind = 0
	elif d == FACE_BOTTOM:
		kind = 2
	var tile := m * 3 + kind
	var tx := float(tile % ATLAS_TILES)
	var ty := float(floori(tile / float(ATLAS_TILES)))
	var corners: Array = face.corners
	var fuv: Array = face.uvs
	var pts := []
	var uvs := []
	for i in 4:
		var c: Vector3 = corners[i]
		pts.append(base + Vector3(c.x, c.y * height, c.z))
		var uv: Vector2 = fuv[i]
		uvs.append(Vector2(
			(tx + UV_EPS + uv.x * (1.0 - 2.0 * UV_EPS)) / ATLAS_TILES,
			(ty + UV_EPS + uv.y * (1.0 - 2.0 * UV_EPS)) / ATLAS_TILES))
	var flag := 0.0
	if m == Mat.LEAVES:
		flag = 1.0
	elif m == Mat.GRASS and d == FACE_TOP:
		flag = 2.0
	buf.quad(pts, face.normal, uvs, Color(shade, shade, shade), flag)
