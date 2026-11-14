extends "res://tests/unit/test_case.gd"
## The chunk meshes: cells, slopes and cut caps.


func run() -> void:
	_test_mesher()
	_test_cap()
	_test_bank_trunk()
	_test_patch()


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
	# UV2.x holds the material and the sides' tile as a flag bit; the shader takes the
	# underside's tile for a face looking down (see MeshFaces.pack, world.gdshader).
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var tiles_right := true
	for v in verts.size():
		var tile := _shader_tile(uv2[v].x, normals[v])
		var want := Mat.STONE * 3 + (0 if normals[v].y > 0.5 else (2 if normals[v].y < -0.5 else 1))
		tiles_right = tiles_right and tile == want
	_check(tiles_right, "each face of a cube draws its material's top, side or underside tile")
	_check(_shader_tile(ChunkMesher.pack(62 * 3 + 1, 255, 0), Vector3.FORWARD) == 62 * 3 + 1
		and _shader_tile(ChunkMesher.pack(62 * 3 + 2, 0, ChunkMesher.DIAG), Vector3.DOWN) == 62 * 3 + 2
		and _shader_tile(ChunkMesher.pack(40 * 3, 0, ChunkMesher.SLOPE), Vector3(0.6, 0.4, 0.0)) == 40 * 3
		and _shader_tile(ChunkMesher.pack(ChunkMesher.NO_TILE, 0, ChunkMesher.FOLIAGE_VOXEL), Vector3.UP) == -1
		and ChunkMesher.pack(62 * 3 + 1, 255, 511) < float(1 << 24),
		"the last of %d materials packs, a voxel has no tile, UV2.x stays a whole float" % PixelTextures.MOST_MATERIALS)
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


## A tree's foot against a bank a level higher on its west and north, as by a river: its
## bark goes down to the ground (cut corners, not a block of wood), and the bank's face
## towards it shows round the bark.
func _test_bank_trunk() -> void:
	var w := WorldData.new(8, Vector2i(8, 8))
	for z in 8:
		for x in 8:
			w.set_cell(x, 0, z, Mat.DIRT)
			if z < 3 or x < 3 and z == 3:
				w.set_cell(x, 1, z, Mat.DIRT)
	for y in range(1, 4):
		w.set_cell(3, y, 3, Mat.LOG)
	w.set_cell(3, 4, 3, Mat.LEAVES)
	w.trees[Vector2i(3, 3)] = 0
	var arrays: Array = (ChunkMesher.build_chunk(w, 0, 0, 16)[0] as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var cut := false
	var bank := false
	var c := WorldData.CELL
	for v in verts.size():
		var p := verts[v] / c
		var n := normals[v]
		var foot := p.y >= 1.0 and p.y < 1.75 and p.x >= 3.0 and p.x <= 4.0 and p.z >= 3.0 and p.z <= 4.0
		cut = cut or foot and absf(n.x) > 0.3 and absf(n.z) > 0.3
		bank = bank or n.x > 0.9 and absf(p.x - 3.0) < 0.001 and p.z >= 3.0 and p.z <= 4.0 and p.y >= 1.0
	_check(cut, "a tree's foot against a bank is bark with cut corners, not a block of wood")
	_check(bank, "the bank beside a tree's foot draws its face towards the trunk")


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


## The tile world.gdshader draws for a face with UV2.x `packed` and normal `normal`
## (-1 for none: the vertex colour).
static func _shader_tile(packed: float, normal: Vector3) -> int:
	var a := int(packed + 0.5)
	var code := a % 64
	var flag := a / 16384
	if code == ChunkMesher.NO_MATERIAL:
		return -1
	return code * 3 + (1 if flag & 1 != 0 else (2 if normal.y < -0.5 else 0))


## A chunk rebuilt only where its cells changed (ChunkMesher.patch, Foliage.patch, as
## ChunkStreamer does after an edit) is what building it whole again makes, buffer for
## buffer: after a tree is felled in a forest, and after a top is dug in its clearing.
func _test_patch() -> void:
	for place in ["forest", "taiga", "jungle"]:
		_patch_place(place)


func _patch_place(place: String) -> void:
	var gen := WorldGen.new(42)
	var near := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	var at: Vector2i = gen.find_place(place, near)
	var key := WorldData.chunk_key(at.x, at.y)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			_ensure_stage(gen, key + Vector2i(dx, dz), WorldGen.SHAPED)
	var w: WorldData = gen.world
	var x0 := key.x * 16
	var z0 := key.y * 16
	var built := _built(w, key, Rect2i())
	# Every tree standing in the chunk or beside it, one after another, each patched into
	# the chunk as patched after the one before.
	var trunks: Array[Vector2i] = []
	for col: Vector2i in w.trees:
		if col.x >= x0 - 4 and col.x < x0 + 20 and col.y >= z0 - 4 and col.y < z0 + 20 and w.log_col(col.x, col.y) != 0:
			trunks.append(col)
	_check(trunks.size() >= 2, "the %s chunk has trees around (%d)" % [place, trunks.size()])
	var all_same := true
	for trunk in trunks:
		var logs := w.log_col(trunk.x, trunk.y)
		var gone: Array[Vector3i] = Felling.fell(w, Vector3i(trunk.x, WorldData.level_of(logs & -logs), trunk.y), Vector2(1, 0))
		# The client hears of each column once, at its lowest cell (WorldActions.fell).
		var lowest := {}
		for c in gone:
			if not lowest.has(Vector2i(c.x, c.z)) or c.y < lowest[Vector2i(c.x, c.z)].y:
				lowest[Vector2i(c.x, c.z)] = c
		var cells: Array[Vector3i] = []
		cells.assign(lowest.values())
		var patched := _patch_matches(w, key, built, cells)
		if patched.is_empty():
			continue
		all_same = all_same and patched[2] == ""
		if patched[2] != "":
			printerr("  felled %s in the %s: %s" % [trunk, place, patched[2]])
		built = patched
	_check(all_same, "%s: each of %d trees felled, the chunk patched where it changed is what building it whole again makes" % [place, trunks.size()])
	# A top dug where nothing grows above it.
	var dug := Vector3i(1 << 20, 0, 0)
	for z in range(z0 + 2, z0 + 14):
		for x in range(x0 + 2, x0 + 14):
			var y := w.surface_y(x, z)
			if dug.x == 1 << 20 and y > 1 and w.get_cell(x, y - 1, z) != Mat.AIR and w.leaf_col(x, z) == 0 and w.log_col(x, z) == 0:
				dug = Vector3i(x, y - 1, z)
	if dug.x != 1 << 20:
		w.set_cell(dug.x, dug.y, dug.z, Mat.AIR)
		var patched := _patch_matches(w, key, built, [dug] as Array[Vector3i])
		_check(not patched.is_empty() and patched[2] == "", "%s: a dug top patched into the chunk: %s" % [place, patched[2] if not patched.is_empty() else "nothing to patch"])


## The mesh and plant jobs of chunk `key`, built whole (an empty `rect`) or only the
## columns of `rect` (as parts), and finished: [mesh job, plant job, meshes, plants].
func _built(w: WorldData, key: Vector2i, rect: Rect2i) -> Array:
	var part := rect.has_area()
	var jp: Foliage.Job
	if part:
		jp = Foliage.start_part(w, key.x * 16, key.y * 16, 16, Foliage.part_columns(w, key.x * 16, key.y * 16, 16, rect))
	else:
		rect = Rect2i(key * 16, Vector2i(16, 16))
		jp = Foliage.start(w, key.x * 16, key.y * 16, 16)
	var jm := ChunkMesher.start_rect(w, rect.position.x, rect.position.y, rect.end.x, rect.end.y, part)
	while not (ChunkMesher.step(jm, 1 << 20) and Foliage.step(jp, 1 << 20)):
		pass
	return [jm, jp]


## Patches `built` for `cells` changed and compares it with the chunk built whole again:
## [mesh job, plant job, "" or what differs], [] if no cell is near the chunk.
func _patch_matches(w: WorldData, key: Vector2i, built: Array, cells: Array[Vector3i]) -> Array:
	var whole := Rect2i(key * 16, Vector2i(16, 16))
	var rect := Rect2i()
	for c in cells:
		var reach := ChunkMesher.reach(w, c)
		var r := Rect2i(c.x - reach, c.z - reach, 2 * reach + 1, 2 * reach + 1).intersection(whole)
		if r.has_area():
			rect = r if not rect.has_area() else rect.merge(r)
	if not rect.has_area():
		return []
	var part := _built(w, key, rect)
	var jm := ChunkMesher.patch(built[0], part[0])
	var jp := Foliage.patch(built[1], part[1])
	while not (ChunkMesher.step(jm, 1 << 20) and Foliage.step(jp, 1 << 20)):
		pass
	var fresh := _built(w, key, Rect2i())
	var diff := ""
	for k in 2:
		var a = jm.solid if k == 0 else jm.water
		var b = fresh[0].solid if k == 0 else fresh[0].water
		if not (a.verts == b.verts and a.normals == b.normals and a.uvs == b.uvs and a.uv2s == b.uv2s
				and a.colors == b.colors and a.indices == b.indices):
			diff += "%s mesh in %s (%d vertices, whole %d); " % ["solid" if k == 0 else "water", rect, a.verts.size(), b.verts.size()]
	if jm.ends != fresh[0].ends:
		diff += "mesh ends; "
	var fp: Foliage.Job = fresh[1]
	if not (jp.grass == fp.grass and jp.ends == fp.ends and jp.ng == fp.ng):
		diff += "grass (%d, whole %d); " % [jp.ng, fp.ng]
	if not (jp.clumps == fp.clumps and jp.nc == fp.nc):
		diff += "leaf cards in %s (%d, whole %d); " % [rect, jp.nc, fp.nc]
	if not (jp.shadows == fp.shadows and jp.ns == fp.ns):
		diff += "shadows (%d, whole %d); " % [jp.ns, fp.ns]
	return [jm, jp, diff]
