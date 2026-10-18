extends SceneTree
## Headless tests. Run: godot --headless --path . --script res://tests/run_tests.gd

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const AiRules := preload("res://src/shared/ai_rules.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")

var checks := 0
var failures := 0


func _init() -> void:
	_test_generation()
	_test_mesher()
	_test_cap()
	_test_raycast()
	_test_walking_rules()
	_test_ai_relations()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _test_generation() -> void:
	var a := WorldGen.generate(42, 64, 20, 64)
	var b := WorldGen.generate(42, 64, 20, 64)
	var c := WorldGen.generate(43, 64, 20, 64)
	_check(a.cells == b.cells, "same seed gives the same world")
	_check(a.cells != c.cells, "different seeds give different worlds")
	var counts := {}
	for m in a.cells:
		counts[m] = counts.get(m, 0) + 1
	for m in [Mat.GRASS, Mat.STONE, Mat.WATER, Mat.DIRT]:
		_check(counts.get(m, 0) > 0, "world contains %s" % Mat.NAMES[m])
	var spawn := WorldGen.find_spawn(a)
	_check(spawn.y > a.sea_level, "spawn is above the sea")
	_check(a.get_cell(spawn.x, spawn.y, spawn.z) == Mat.AIR, "spawn cell is free")


func _test_mesher() -> void:
	var w := WorldData.new(4, 4, 4)
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


func _test_cap() -> void:
	var w := WorldData.new(4, 4, 4)
	w.set_cell(1, 0, 1, Mat.STONE)
	w.set_cell(1, 1, 1, Mat.STONE)
	w.set_cell(2, 0, 1, Mat.STONE)
	var cap := ChunkMesher.build_cap(w, 0)
	_check(cap != null and cap.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 4,
		"cap closes only cells covered from above")


func _test_raycast() -> void:
	var w := WorldData.new(8, 8, 8)
	for z in 8:
		for x in 8:
			w.set_cell(x, 0, z, Mat.STONE)
	w.set_cell(4, 5, 4, Mat.DIRT)
	var hit := VoxelRaycast.cast(w, Vector3(4.5, 7.5, 4.5), Vector3.DOWN, 20.0, 7)
	_check(not hit.is_empty() and hit.cell == Vector3i(4, 5, 4), "ray hits the first block")
	_check(not hit.is_empty() and hit.normal == Vector3i(0, 1, 0), "hit normal points up")
	hit = VoxelRaycast.cast(w, Vector3(4.5, 7.5, 4.5), Vector3.DOWN, 20.0, 3)
	_check(not hit.is_empty() and hit.cell == Vector3i(4, 0, 4), "cells above the cut are ignored")
	hit = VoxelRaycast.cast(w, Vector3(4.5, 7.5, 4.5), Vector3.UP, 20.0, 7)
	_check(hit.is_empty(), "ray into the sky hits nothing")


func _test_walking_rules() -> void:
	var w := WorldData.new(4, 4, 4)
	w.set_cell(1, 0, 1, Mat.WATER)
	_check(w.blocks_body(1, 0, 1), "water cannot be entered")
	_check(w.blocks_body(1, 1, 1), "open water cannot be walked over")
	_check(w.surface_y(1, 1) == -1, "open water has no surface to stand on")
	w.water_frozen = true
	_check(not w.blocks_body(1, 1, 1), "frozen water can be walked over")
	_check(w.surface_y(1, 1) == 1, "ice is a surface")
	_check(w.blocks_body(-1, 1, 1), "map edge blocks")


func _test_ai_relations() -> void:
	# The example from the design: a cat is food for a wolf, the wolf is a threat
	# to the cat, and the cat hunts squirrels, with no rule written for the cat.
	_check(AiRules.is_food("wolf", "cat"), "wolf sees a cat as food")
	_check(AiRules.is_threat("cat", "wolf"), "cat sees a wolf as a threat")
	_check(not AiRules.is_food("cat", "wolf"), "cat does not hunt wolves")
	_check(AiRules.is_food("cat", "squirrel"), "cat hunts squirrels")
	_check(AiRules.is_food("cat", "rabbit"), "cat hunts rabbits")
	_check(AiRules.is_threat("squirrel", "cat"), "squirrel fears a cat")
	_check(not AiRules.is_threat("cat", "deer"), "cat ignores deer")
	_check(not AiRules.is_food("deer", "rabbit"), "herbivores hunt nobody")
	_check(not AiRules.is_food("wolf", "human"), "a lone wolf does not see a human as food")
	_check(AiRules.is_threat("rabbit", "human"), "rabbit fears people")
	_check(AiRules.is_active("wolf", 0.0) and not AiRules.is_active("wolf", 1.0), "wolves are active at night")
