extends "res://tests/unit/test_case.gd"
## The chunk meshes: cells, slopes and cut caps.


func run() -> void:
	_test_mesher()
	_test_cap()


func _test_mesher() -> void:
	var w := WorldData.new(4, Vector2i(4, 4))
	w.set_cell(1, 1, 1, Mat.STONE)
	var meshes: Array = ChunkMesher.build_chunk(w, 0, 0, 16)
	var arrays: Array = (meshes[0] as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(verts.size() == 24 and indices.size() == 36, "single cube has 6 faces")
	_check(meshes[1] == null, "no water mesh without water")
	# Godot treats clockwise triangles as front faces.
	var clockwise := true
	for t in range(0, indices.size(), 3):
		var p0 := verts[indices[t]]
		var p1 := verts[indices[t + 1]]
		var p2 := verts[indices[t + 2]]
		if (p1 - p0).cross(p2 - p0).dot(normals[indices[t]]) >= 0.0:
			clockwise = false
	_check(clockwise, "faces are wound clockwise")
	w.set_cell(2, 1, 1, Mat.STONE)
	meshes = ChunkMesher.build_chunk(w, 0, 0, 16)
	verts = (meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(verts.size() == 40, "shared face between neighbours is culled")
	w.set_cell(0, 0, 0, Mat.WATER)
	meshes = ChunkMesher.build_chunk(w, 0, 0, 16)
	_check(meshes[1] != null, "water gets its own mesh")
	_check(verts[0].distance_to(verts[2]) < 0.75, "meshes are in world units, half a unit per cell")
	# A flat floor: its tops away from the edges are merged into rows.
	var f := WorldData.new(4, Vector2i(8, 8))
	for z in 8:
		for x in 8:
			f.set_cell(x, 0, z, Mat.STONE)
	var tops := 0
	var rows := ChunkMesher.build_chunk(f, 0, 0, 16)[0] as ArrayMesh
	for n in rows.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		tops += int(n.y > 0.9)
	# 28 tops on the rim have edges; the 6 rows of 6 inside are one quad each.
	_check(tops == (28 + 6) * 4, "plain tops in a row are drawn as one quad")
	# A pond: water away from the shore is merged into rows too, foam stays per cell.
	var pond := WorldData.new(3, Vector2i(8, 8))
	for z in 8:
		for x in 8:
			pond.set_cell(x, 0, z, Mat.STONE)
			pond.set_cell(x, 1, z, Mat.STONE if x == 0 or z == 0 or x == 7 or z == 7 else Mat.WATER)
	var surface := ChunkMesher.build_chunk(pond, 0, 0, 16)[1] as ArrayMesh
	tops = 0
	for n in surface.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		tops += int(n.y > 0.9)
	_check(tops == (20 + 4) * 4, "open water in a row is drawn as one quad")


func _test_cap() -> void:
	var w := WorldData.new(4, Vector2i(4, 4))
	w.set_cell(1, 0, 1, Mat.STONE)
	w.set_cell(1, 1, 1, Mat.STONE)
	w.set_cell(2, 0, 1, Mat.STONE)
	var cap := ChunkMesher.build_cap(w, 0)
	_check(cap != null and cap.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 4,
		"cap closes only cells covered from above")
	# The cap built chunk by chunk has the same tops as the one built at once.
	w = WorldData.new(4, Vector2i(8, 8))
	for z in 8:
		for x in 8:
			for y in 3:
				if (x * 7 + z * 3) % 5 != 0 or y == 0:
					w.set_cell(x, y, z, Mat.STONE if (x + z) % 3 else Mat.DIRT)
	var whole := _mesh_area(ChunkMesher.build_cap(w, 1))
	var parts := 0.0
	for z0 in [0, 4]:
		for x0 in [0, 4]:
			parts += _mesh_area(ChunkMesher.build_cap(w, 1, x0, z0, 4))
	_check(whole > 0.0 and absf(parts - whole) < 0.001, "cap built chunk by chunk covers the same area")
	# West and north of the origin too: a row of whole tops there is one run.
	w = WorldData.new(4)
	w.add_chunk(WorldData.chunk_key(-6, -5))
	for x in range(-6, -2):
		w.set_cell(x, 0, -5, Mat.STONE)
		w.set_cell(x, 1, -5, Mat.STONE)
	var key := WorldData.chunk_key(-6, -5)
	var west := _mesh_area(ChunkMesher.build_cap(w, 0, key.x * WorldData.CHUNK, key.y * WorldData.CHUNK))
	_check(absf(west - 4.0 * WorldData.CELL * WorldData.CELL) < 0.001, "cap closes whole tops at negative x as well")


## Total area of the triangles of a mesh (0 for none).
func _mesh_area(mesh: ArrayMesh) -> float:
	if mesh == null:
		return 0.0
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area := 0.0
	for i in range(0, idx.size(), 3):
		area += (v[idx[i + 1]] - v[idx[i]]).cross(v[idx[i + 2]] - v[idx[i]]).length() * 0.5
	return area
