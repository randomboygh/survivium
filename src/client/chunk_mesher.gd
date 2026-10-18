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
const AIR := Mat.AIR
const WATER := Mat.WATER

static var _faces: Array = []
## (tile * 6 + direction) -> 4 atlas UVs
static var _uv_cache := {}


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
## Reads the cell bytes directly (outside the map is air, below it is stone), which is
## several times faster than get_cell() per neighbour.
static func build_chunk(w, x0: int, z0: int, size: int) -> Array:
	var faces := face_table()
	var solid := MeshBuffers.new()
	var water := MeshBuffers.new()
	var cells: PackedByteArray = w.cells
	var sx: int = w.size_x
	var sy: int = w.size_y
	var sz: int = w.size_z
	var layer := sx * sz
	var x1 := mini(x0 + size, sx)
	var z1 := mini(z0 + size, sz)
	var nb := PackedByteArray()
	nb.resize(6)
	for y in sy:
		for z in range(z0, z1):
			var row := y * layer + z * sx
			for x in range(x0, x1):
				var i := row + x
				var m := cells[i]
				if m == AIR:
					continue
				# Neighbours in DIRS order: +x, -x, +y, -y, +z, -z.
				nb[0] = cells[i + 1] if x + 1 < sx else AIR
				nb[1] = cells[i - 1] if x > 0 else AIR
				nb[2] = cells[i + layer] if y + 1 < sy else AIR
				nb[3] = cells[i - layer] if y > 0 else Mat.STONE
				nb[4] = cells[i + sx] if z + 1 < sz else AIR
				nb[5] = cells[i - sx] if z > 0 else AIR
				var base := Vector3(x, y, z)
				if m == WATER:
					var h := WATER_TOP if nb[2] == AIR else 1.0
					for d in 6:
						if d != FACE_BOTTOM and nb[d] == AIR:
							add_face(water, faces[d], base, m, d, 1.0, h)
					continue
				for d in 6:
					var n := nb[d]
					if n == AIR or n == WATER:
						add_face(solid, faces[d], base, m, d, 1.0, 1.0)
	return [null if solid.is_empty() else solid.to_mesh(), null if water.is_empty() else water.to_mesh()]


## Dark tops of solid cells on `level` that are covered by solid cells above:
## what you see in the cut when looking into a mountain.
static func build_cap(w, level: int) -> ArrayMesh:
	if level < 0 or level >= w.size_y - 1:
		return null
	var top: Dictionary = face_table()[FACE_TOP]
	var buf := MeshBuffers.new()
	var cells: PackedByteArray = w.cells
	var sx: int = w.size_x
	var layer: int = sx * w.size_z
	var row := level * layer
	for z in w.size_z:
		for x in sx:
			var i := row + z * sx + x
			var m := cells[i]
			var above := cells[i + layer]
			if m != AIR and m != WATER and above != AIR and above != WATER:
				add_face(buf, top, Vector3(x, level, z), m, FACE_TOP, 0.4, 1.0)
	return null if buf.is_empty() else buf.to_mesh()


static func add_face(buf, face: Dictionary, base: Vector3, m: int, d: int, shade: float, height: float) -> void:
	var kind := 1
	if d == FACE_TOP:
		kind = 0
	elif d == FACE_BOTTOM:
		kind = 2
	var tile := m * 3 + kind
	var key := tile * 6 + d
	var uvs: Array = _uv_cache.get(key, [])
	if uvs.is_empty():
		var tx := float(tile % ATLAS_TILES)
		var ty := float(floori(tile / float(ATLAS_TILES)))
		for uv in face.uvs:
			uvs.append(Vector2(
				(tx + UV_EPS + uv.x * (1.0 - 2.0 * UV_EPS)) / ATLAS_TILES,
				(ty + UV_EPS + uv.y * (1.0 - 2.0 * UV_EPS)) / ATLAS_TILES))
		_uv_cache[key] = uvs
	var corners: Array = face.corners
	var pts := []
	if height == 1.0:
		for c in corners:
			pts.append(base + c)
	else:
		for i in 4:
			var c: Vector3 = corners[i]
			pts.append(base + Vector3(c.x, c.y * height, c.z))
	var flag := 0.0
	if m == Mat.LEAVES:
		flag = 1.0
	elif m == Mat.GRASS and d == FACE_TOP:
		flag = 2.0
	buf.quad(pts, face.normal, uvs, Color(shade, shade, shade), flag)
