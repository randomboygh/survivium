extends SceneTree
## Headless tests. Run: godot --headless --path . --script res://tests/run_tests.gd

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const AiRules := preload("res://src/shared/ai_rules.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const PlayerScript := preload("res://src/client/player.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const Trees := preload("res://src/shared/trees.gd")
const Foliage := preload("res://src/client/foliage.gd")
const Bushes := preload("res://src/shared/bushes.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const Figure := preload("res://src/client/figure.gd")
const Yaml := preload("res://src/shared/yaml.gd")
const Content := preload("res://src/shared/content.gd")
const Items := preload("res://src/shared/items.gd")
const Inventory := preload("res://src/shared/inventory.gd")
const Vitals := preload("res://src/shared/vitals.gd")
const Tools := preload("res://src/shared/tools.gd")
const Crafting := preload("res://src/shared/crafting.gd")
const Plants := preload("res://src/shared/plants.gd")
const CraftQueue := preload("res://src/shared/craft_queue.gd")
const Knowledge := preload("res://src/shared/knowledge.gd")
const WorldStore := preload("res://src/shared/world_store.gd")
const Tracks := preload("res://src/client/tracks.gd")
const ChunkStreamer := preload("res://src/client/chunk_streamer.gd")

var checks := 0
var failures := 0


func _init() -> void:
	_test_generation()
	_test_mesher()
	_test_cap()
	_test_raycast()
	_test_walking_rules()
	_test_water()
	_test_slopes()
	_test_steps()
	_test_corners()
	_test_shapes()
	_test_ai_relations()
	_test_pixel_view()
	_test_trees()
	_test_bushes()
	_test_felling()
	_test_save()
	_test_sprite_sheet()
	_test_yaml()
	_test_content()
	_test_items()
	_test_inventory()
	_test_tools()
	_test_crafting()
	_test_wear()
	_test_vitals()
	_test_tracks()
	_test_hidden()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _test_generation() -> void:
	var a := _land(42)
	var b := _land(42)
	var c := _land(43)
	var keys: Array = a.area
	_check(_same(a.world, b.world, keys), "same seed gives the same world")
	_check(not _same(a.world, c.world, keys), "different seeds give different worlds")
	var counts := {}
	for key: Vector2i in keys:
		for m in a.world.chunks[key].cells:
			counts[m] = counts.get(m, 0) + 1
	for m in [Mat.GRASS, Mat.STONE, Mat.WATER, Mat.DIRT]:
		_check(counts.get(m, 0) > 0, "world contains %s" % Mat.NAMES[m])
	var w: WorldData = a.world
	var spawn := WorldGen.find_spawn(w, a.gen.spawn_guess)
	_check(spawn.y > w.sea_level, "spawn is above the sea")
	_check(w.get_cell(spawn.x, spawn.y, spawn.z) == Mat.AIR, "spawn cell is free")
	# The world does not depend on the order its chunks are made in: generated
	# chunk by chunk from the other corner, stage by stage, it is the same as
	# generated at once.
	var gen := WorldGen.new(42, 40)
	for i in range(keys.size() - 1, -1, -1):
		_ensure_stage(gen, keys[i], WorldGen.SHAPED)
	_check(_same(gen.world, w, keys), "chunks made in another order give the same cells and shapes")
	_check(gen.world.trees == w.trees and gen.world.bushes == w.bushes, "and the same trees and bushes")
	# Chunks dropped far away are made again the same, with the crowns of the trees
	# around that reach into them: a chunk of the area, a planted one beside it and
	# one with terrain only beyond that.
	var first: Vector2i = keys[0]
	var dropped: Array[Vector2i] = [first + Vector2i(1, 1), first + Vector2i(-1, 1), first + Vector2i(-2, 2)]
	var stages: Array[int] = []
	for k in dropped:
		stages.append(gen.stage_of(k))
		gen.forget(k)
	for i in dropped.size():
		_ensure_stage(gen, dropped[i], stages[i])
	for k in keys:
		_ensure_stage(gen, k, WorldGen.SHAPED)
	_check(_same_cells(gen.world, w, keys + dropped) and _same_view(gen, gen.world, w, keys + dropped),
		"chunks dropped and made again are the same")
	_check(gen.world.trees == w.trees and gen.world.bushes == w.bushes, "and so are their trees and bushes")
	# Water above the sea never leaks: nothing open under it, and no air beside it.
	var leaks := 0
	for key: Vector2i in keys:
		var ch: WorldData.Chunk = w.chunks[key]
		for col in WorldData.LAYER:
			var water: int = ch.water[col]
			var x: int = key.x * 16 + (col & 15)
			var z: int = key.y * 16 + (col >> 4)
			while water != 0:
				var bit := water & -water
				water ^= bit
				var y := WorldData.level_of(bit)
				if y <= w.sea_level:
					continue
				if w.get_cell(x, y - 1, z) == Mat.AIR:
					leaks += 1
				for d: Vector2i in WorldData.SIDES:
					if w.get_cell(x + d.x, y, z + d.y) == Mat.AIR and w.water_col(x + d.x, z + d.y) & (bit - 1) == 0:
						leaks += 1
	_check(leaks == 0, "water above the sea does not leak (%d leaks)" % leaks)
	# Settings change the world: more water, a different world.
	var wet := WorldGen.new(42, 40, {"water": 2})
	_check(wet.coast_level > a.gen.coast_level, "more water lifts the coast")
	# A river runs into a lake without a step in its bed: where a river column
	# meets the lake, the lake floor is seldom higher (only beside the channel).
	var mouth := WorldGen.new(20261018).lay_out(72, -1844, 256, 256)
	var meets := 0
	var steps := 0
	for j in mouth.feature.size():
		if mouth.feature[j] != WorldGen.RIVER or j < 256 or j >= 255 * 256 or j % 256 == 0 or j % 256 == 255:
			continue
		for dj: int in [-1, 1, -256, 256]:
			if mouth.feature[j + dj] in [WorldGen.LAKE, WorldGen.OCEAN]:
				meets += 1
				if mouth.heights[j + dj] > mouth.heights[j]:
					steps += 1
	_check(meets > 0 and steps * 4 < meets, "rivers flow into lakes without a step (%d of %d higher)" % [steps, meets])


## A world of `seed` made at once over four by four chunks at its spawn: {"gen", "world",
## "area" (the chunk keys, row by row)}.
func _land(seed_value: int) -> Dictionary:
	var gen := WorldGen.new(seed_value, 40)
	var from := WorldData.chunk_key(gen.spawn_guess.x, gen.spawn_guess.z) - Vector2i(2, 2)
	gen.generate_area(from, from + Vector2i(4, 4))
	var area := []
	for cz in range(from.y, from.y + 4):
		for cx in range(from.x, from.x + 4):
			area.append(Vector2i(cx, cz))
	return {"gen": gen, "world": gen.world, "area": area}


## True when the chunks `keys` have the same cells and shapes in both worlds.
func _same(a: WorldData, b: WorldData, keys: Array) -> bool:
	for key: Vector2i in keys:
		var ca: WorldData.Chunk = a.chunks.get(key)
		var cb: WorldData.Chunk = b.chunks.get(key)
		if ca == null or cb == null or ca.cells != cb.cells or ca.shapes != cb.shapes:
			return false
	return true


func _same_cells(a: WorldData, b: WorldData, keys: Array) -> bool:
	for key: Vector2i in keys:
		var ca: WorldData.Chunk = a.chunks.get(key)
		var cb: WorldData.Chunk = b.chunks.get(key)
		if ca == null or cb == null or ca.cells != cb.cells:
			return false
	return true


## The shapes the meshes of the shaped chunks among `keys` read: the chunk and a
## column around it (the shapes of a chunk not shaped yet are only a draft).
func _same_view(gen, a: WorldData, b: WorldData, keys: Array) -> bool:
	for key: Vector2i in keys:
		if gen.stage_of(key) < WorldGen.SHAPED:
			continue
		var x0 := key.x * WorldData.CHUNK
		var z0 := key.y * WorldData.CHUNK
		var x1 := x0 + WorldData.CHUNK
		var z1 := z0 + WorldData.CHUNK
		if a.padded(true, 0, x0 - 1, z0 - 1, x1 + 1, z1 + 1) != b.padded(true, 0, x0 - 1, z0 - 1, x1 + 1, z1 + 1):
			return false
	return true


## Brings a chunk to `stage` the way the game does: its own earlier stages first,
## then the chunks around it to the stage before.
func _ensure_stage(gen, key: Vector2i, stage: int) -> void:
	if gen.stage_of(key) >= stage:
		return
	_ensure_stage(gen, key, stage - 1)
	if stage > WorldGen.TERRAIN:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				_ensure_stage(gen, key + Vector2i(dx, dz), stage - 1)
	gen.run(key, stage)


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


func _test_raycast() -> void:
	var w := WorldData.new(8, Vector2i(8, 8))
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
	var w := WorldData.new(4, Vector2i(4, 4))
	w.set_cell(1, 0, 1, Mat.WATER)
	_check(not w.blocks_body(1, 0, 1), "open water can be entered")
	_check(not w.blocks_body(1, 1, 1), "no invisible floor over the water")
	_check(w.surface_y(1, 1) == -1, "open water has no surface to stand on")
	w.water_frozen = true
	_check(w.blocks_body(1, 0, 1), "ice cannot be entered")
	_check(w.surface_y(1, 1) == 1, "ice is a surface")
	_check(w.blocks_body(-1, 1, 1), "nothing walks where no chunk is kept")


## A pool along x on a stone floor: water in levels 3..4 (open surface at 4.5) over
## x 3..8, shallow (level 4 only) at x = 3; a bank one level above the water (top 6)
## at x >= 9 and one two levels above it (top 7) at x <= 2.
func _pool_world() -> WorldData:
	var w := WorldData.new(10, Vector2i(16, 6))
	for z in 16:
		for x in 16:
			var top := 6 if x <= 2 else (5 if x >= 9 else (3 if x == 3 else 2))
			for y in top + 1:
				w.set_cell(x, y, z, Mat.STONE)
			for y in range(top + 1, 5):
				w.set_cell(x, y, z, Mat.WATER)
	return w


func _test_water() -> void:
	var w := _pool_world()
	var player = PlayerScript.new()
	player.world = w
	player.position = Vector3(3.5, 4.0, 2.5) * WorldData.CELL
	player.on_ground = true
	player.step(1.0 / 60.0, false)
	_check(player.on_ground and not player.swimming and is_equal_approx(player.water_depth, 0.5),
		"water one cell deep is waded on the bottom")
	player.move_input = Vector2(1, 0)
	var swam := false
	for i in 40:
		player.step(1.0 / 60.0, false)
		var p: Vector3 = player.position / WorldData.CELL
		swam = swam or player.swimming and absf(p.y - (4.5 - PlayerScript.SWIM_DEPTH)) < 0.05 and p.x > 4.5
	_check(swam, "deeper water is swum with the head above the surface")
	for i in 240:
		player.step(1.0 / 60.0, false)
	var out: Vector3 = player.position / WorldData.CELL
	_check(out.x > 9.0 and is_equal_approx(out.y, 6.0) and player.on_ground,
		"a swimmer pulls out onto a bank one level above the water")
	player.move_input = Vector2(-1, 0)
	for i in 360:
		player.step(1.0 / 60.0, false)
	_check(player.position.x / WorldData.CELL > 2.4, "a bank two levels above the water cannot be climbed")
	_check(player.swimming or player.water_depth > 0.0, "the swimmer stays in the water below a high bank")
	w.water_frozen = true
	player.step(1.0 / 60.0, false)
	player.step(1.0 / 60.0, false)
	_check(is_equal_approx(player.position.y / WorldData.CELL, 5.0) and player.on_ground,
		"a swimmer caught by the frost stands on the ice")
	player.move_input = Vector2(1, 0)
	for i in 120:
		player.step(1.0 / 60.0, false)
	_check(is_equal_approx(player.position.y / WorldData.CELL, 5.0) and player.position.x / WorldData.CELL > 7.0,
		"ice is walked on")
	player.free()


## Natural dirt one level higher for x >= 4 (a step facing west) and two levels higher
## for x >= 6 (a cliff), on a dirt floor.
func _slope_world() -> WorldData:
	var w := WorldData.new(6, Vector2i(10, 10))
	for z in 10:
		for x in 10:
			for y in range(0, 1 + int(x >= 4) + 2 * int(x >= 6)):
				w.set_cell(x, y, z, Mat.DIRT)
				w.set_natural(x, y, z, true)
	return w


func _test_slopes() -> void:
	var w := _slope_world()
	_check(w.slope_mask(4, 1, 5) == WorldData.NE | WorldData.SE, "a one-level step of loose ground is a ramp")
	_check(w.slope_mask(5, 3, 5) == WorldData.FULL and w.slope_mask(5, 1, 5) == WorldData.FULL,
		"a drop of two levels stays a cliff")
	_check(is_equal_approx(w.ground_height(4.5, 5.5), 1.5), "ground halfway up a ramp is half a cell higher")
	_check(w.slope_mask(4, 1, 0) == WorldData.NE | WorldData.SE, "a ramp at the map edge still slopes")
	w.set_cell(4, 1, 7, Mat.STONE)
	_check(w.slope_mask(4, 1, 7) == WorldData.FULL, "stone and built blocks never slope")
	w.set_cell(4, 2, 3, Mat.PLANKS)
	_check(w.slope_mask(4, 1, 3) == WorldData.FULL, "ground under a block does not slope")
	var meshes: Array = ChunkMesher.build_chunk(w, 0, 0, 16)
	var normals: PackedVector3Array = (meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var tilted := false
	for n in normals:
		tilted = tilted or (n.y > 0.6 and n.y < 0.8 and n.x < -0.6)
	_check(tilted, "ramps are drawn tilted toward the low side")
	# Walk east up the ramp without jumping, and stop at the cliff.
	var player = PlayerScript.new()
	player.world = w
	player.position = Vector3(2.5, 1.0, 5.5) * WorldData.CELL
	player.on_ground = true
	player.move_input = Vector2(1, 0)
	var climbed := true
	for i in 60:
		player.step(1.0 / 60.0, false)
		var p: Vector3 = player.position / WorldData.CELL
		if p.x > 4.2 and p.x < 4.6:
			climbed = climbed and p.y > 1.3 and p.y < 1.995
	_check(climbed and is_equal_approx(player.position.y / WorldData.CELL, 2.0), "walking up a ramp needs no jump")
	_check(player.position.x / WorldData.CELL < 5.6, "a two-cell cliff stops the walker")
	player.move_input = Vector2(-1, 0)
	var smooth := true
	var last_y: float = player.position.y / WorldData.CELL
	for i in 60:
		player.step(1.0 / 60.0, false)
		smooth = smooth and last_y - player.position.y / WorldData.CELL < 0.2
		last_y = player.position.y / WorldData.CELL
	_check(smooth and is_equal_approx(player.position.y / WorldData.CELL, 1.0), "walking down a ramp keeps the feet on it")
	player.free()


## Walks east from x = 2 toward a sheer step of `height` cells of stone at x >= 5,
## jumping if `jump`; returns where the feet end, in cells.
func _walk_to_step(height: int, jump: bool) -> Vector3:
	var w := WorldData.new(6, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			for y in 1 + (height if x >= 5 else 0):
				w.set_cell(x, y, z, Mat.STONE)
	var player = PlayerScript.new()
	player.world = w
	player.position = Vector3(2.5, 1.0, 5.5) * WorldData.CELL
	player.on_ground = true
	player.move_input = Vector2(1, 0)
	for i in 90:
		player.step(1.0 / 60.0, jump and i == 20)
	var p: Vector3 = player.position / WorldData.CELL
	player.free()
	return p


func _test_steps() -> void:
	_check(_walk_to_step(1, false).x < 4.6, "a sheer step of one cell is not walked up")
	var up := _walk_to_step(1, true)
	_check(up.x > 6.0 and is_equal_approx(up.y, 2.0), "a jump gets up onto a step of one cell")
	_check(_walk_to_step(2, true).x < 4.6, "a step of two cells cannot be jumped up")
	_check(_climb_pit(false) < 3.0, "jumping cannot get out of a pit four cells deep")
	_check(_climb_pit(true) > 4.9, "air jumps get out of a pit four cells deep")
	var chest := VoxelProps.footprint(VoxelProps.prop("chest"))
	_check(is_equal_approx(chest[0].position.x, 0.125) and is_equal_approx(chest[3].end.x, 0.875)
		and is_equal_approx(chest[0].position.z, 0.375) and is_equal_approx(chest[3].end.z, 0.75)
		and is_equal_approx(chest[0].end.y, 1.25), "a chest's boxes are the model's, not its whole cells")
	var bench := VoxelProps.footprint(VoxelProps.prop("workbench"))
	_check(is_equal_approx(bench[0].end.y, 1.0) and is_equal_approx(bench[3].end.y, 1.0)
		and is_equal_approx(VoxelProps.footprint(VoxelProps.prop("kiln"))[0].end.y, 1.75),
		"a workbench is stood on at its planks, not on what lies on them; the kiln's dome counts")
	_check(_walk_to_thing(false, 5.9).x < 4.7, "a chest is not walked through")
	_check(_walk_to_thing(false, 7.3).x > 6.0, "the strip south of a chest's lock is walked along")
	_check(_walk_to_thing(false, 4.85).x > 6.0, "the strip north of a chest's back is walked along")
	var on_top := _walk_to_thing(true, 5.9)
	_check(is_equal_approx(on_top.y, 2.25), "a jump gets up onto a chest")
	_check(is_equal_approx(_walk_to_thing(true, 7.0).y, 1.0), "a jump by the chest's front does not stand on air")
	_check(is_equal_approx(_walk_to_thing(true, 5.1).y, 1.0), "a jump by the chest's back does not stand on air")
	_check(is_equal_approx(_walk_to_thing(true, 5.5).y, 2.25), "a jump just inside the chest's back edge stands on its lid")
	_check(is_equal_approx(_drop_by_block(4.7), 1.0) and is_equal_approx(_drop_by_block(4.9), 2.0),
		"the feet stand on a block only near its north edge, not a body's depth beyond it")


## Drops the player at `z` from above a stone block on cell (5, 1, 5) of a stone floor;
## returns the height the feet come to rest at, in cells.
func _drop_by_block(z: float) -> float:
	var w := WorldData.new(6, Vector2i(16, 16))
	for cz in 16:
		for cx in 16:
			w.set_cell(cx, 0, cz, Mat.STONE)
	w.set_cell(5, 1, 5, Mat.STONE)
	var player = PlayerScript.new()
	player.world = w
	player.position = Vector3(5.5, 2.5, z) * WorldData.CELL
	for i in 60:
		player.step(1.0 / 60.0, false)
	var y: float = player.position.y / WorldData.CELL
	player.free()
	return y


## Walks east at `z` past a chest standing on cells x 5..6, z 5..6 (see
## WorldData.blockers), jumping at the start when `jump`; returns where the feet end
## up after 0.4 s, in cells.
func _walk_to_thing(jump: bool, z: float) -> Vector3:
	var w := WorldData.new(6, Vector2i(16, 16))
	for cz in 16:
		for cx in 16:
			w.set_cell(cx, 0, cz, Mat.STONE)
	var boxes := VoxelProps.footprint(VoxelProps.prop("chest"))
	for i in 4:
		w.blockers[Vector3i(5 + (i & 1), 1, 5 + (i >> 1))] = boxes[i]
	_check(w.blocks_body(5, 1, 5) and w.blocks_body(5, 2, 5) and not w.blocks_body(5, 3, 5) and w.blocker_top(5, 2, 5) == 0.25,
		"a thing 1.25 cells high fills its cell and a quarter of the one above")
	var player = PlayerScript.new()
	player.world = w
	player.position = Vector3(3.0, 1.0, z) * WorldData.CELL
	player.on_ground = true
	player.move_input = Vector2(1, 0)
	for i in 24:
		player.step(1.0 / 60.0, jump and i == 0)
	player.move_input = Vector2.ZERO
	for i in 60:
		player.step(1.0 / 60.0, false)
	var p: Vector3 = player.position / WorldData.CELL
	player.free()
	return p


## Presses jump again and again for 5 s at the bottom of a pit four cells deep and one
## cell wide, walking east; returns the highest the feet got, in cells.
func _climb_pit(air_jumps: bool) -> float:
	var w := WorldData.new(10, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			for y in (1 if x == 5 and z == 5 else 5):
				w.set_cell(x, y, z, Mat.STONE)
	var player = PlayerScript.new()
	player.world = w
	player.air_jumps = air_jumps
	player.position = Vector3(5.5, 1.0, 5.5) * WorldData.CELL
	player.on_ground = true
	player.move_input = Vector2(1, 0)
	var top := 0.0
	for i in 300:
		player.step(1.0 / 60.0, i % 20 < 3)
		top = maxf(top, player.position.y / WorldData.CELL)
	player.free()
	return top


## Wild stone floor with a two-level wild stone block at x, z 3..6 missing its
## north-east quarter (x 5..6, z 3..4), so it has outer corners and one inner corner.
func _corner_world() -> WorldData:
	var w := WorldData.new(6, Vector2i(10, 10))
	var c: WorldData.Chunk = w.chunks[Vector2i.ZERO]
	c.natural.fill(WorldData.WILD)
	for z in 10:
		for x in 10:
			c.cells[z * 16 + x] = Mat.STONE
			if x >= 3 and x <= 6 and z >= 3 and z <= 6 and not (x >= 5 and z <= 4):
				for y in range(1, 3):
					c.cells[(y * 16 + z) * 16 + x] = Mat.STONE
	w.rebuild_columns()
	return w


func _test_corners() -> void:
	var w := _corner_world()
	_check(w.corner_cut(3, 2, 3, 0) and w.corner_cut(3, 1, 3, 0), "an outer corner of a cliff is cut on every level")
	_check(not w.corner_cut(4, 2, 3, 0) and not w.corner_cut(3, 2, 3, 2), "straight edges and inner sides are not cut")
	_check(w.corner_fill(5, 1, 4, 3) and w.corner_fill(5, 2, 4, 3), "an inner corner is filled on every level")
	_check(w.corner_fills(5, 3, 4) == 0, "nothing is filled above the cliff")
	_check(is_equal_approx(w.ground_height(3.05, 3.05), 1.0) and is_equal_approx(w.ground_height(3.4, 3.4), 3.0),
		"a cut corner leaves the ground below it open")
	_check(is_equal_approx(w.ground_height(5.1, 4.9), 3.0), "a filled corner is ground up to the cliff top")
	var player = PlayerScript.new()
	player.world = w
	_check(not player._collides(Vector3(2.6, 1.0, 2.6)) and player._collides(Vector3(3.05, 1.0, 3.05)),
		"a walker fits into a cut corner but not into the cliff")
	_check(player._collides(Vector3(5.6, 1.0, 4.55)) and not player._collides(Vector3(5.9, 1.0, 4.0)),
		"a filled corner blocks a walker")
	var meshes: Array = ChunkMesher.build_chunk(w, 0, 0, 16)
	var normals: PackedVector3Array = (meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var diagonal := false
	for n in normals:
		diagonal = diagonal or (absf(n.x) > 0.6 and absf(n.z) > 0.6 and absf(n.y) < 0.01)
	_check(diagonal, "cut and filled corners get diagonal walls")
	# Placed blocks keep their corners.
	w.set_cell(3, 2, 3, Mat.STONE)
	_check(not w.corner_cut(3, 2, 3, 0) and not w.corner_cut(3, 1, 3, 0), "placed blocks stay square")
	player.free()


## The shapes the world works out a column at a time match the rules written out for
## one cell at a time (below), on a generated world and after digging and building.
func _test_shapes() -> void:
	var land := _land(7)
	var g: WorldData = land.world
	var keys: Array = land.area
	var from: Vector2i = keys[0] * 16
	var to: Vector2i = keys[keys.size() - 1] * 16 + Vector2i(16, 16)
	_check(_shapes_match(g, from, to), "shapes of a generated world follow the rules")
	_check(_patches_match(g, from, to), "the mesher's slope surfaces are those the walkers stand on")
	_check(_sides_meet(g, from, to), "slopes that share their corners meet along the whole side")
	var slopes := 0
	var cuts := 0
	var fills := 0
	for key: Vector2i in keys:
		var c: WorldData.Chunk = g.chunks[key]
		for col in WorldData.LAYER:
			slopes += int(c.sloped[col] != 0)
		for i in c.shapes.size():
			cuts += int(c.shapes[i] >= 16 and Mat.is_solid(c.cells[i]))
			fills += int(c.shapes[i] >= 16 and not Mat.is_solid(c.cells[i]))
	_check(slopes > 0 and cuts > 0 and fills > 0, "generated ground has slopes and cut and filled corners")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 300:
		var x := rng.randi_range(from.x, to.x - 1)
		var z := rng.randi_range(from.y, to.y - 1)
		var y := clampi(g.surface_y(x, z) + rng.randi_range(-2, 1), 0, g.size_y - 1)
		g.set_cell(x, y, z, [Mat.AIR, Mat.DIRT, Mat.STONE][i % 3])
	_check(_shapes_match(g, from, to), "shapes follow the rules after digging and building")


## True when the mesher builds the same surface for every sloping top of the columns
## from..to as the world does, and some slopes go down two levels.
func _patches_match(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	var c := w.padded(false, Mat.STONE, from.x - 2, from.y - 2, to.x + 2, to.y + 2)
	var sh := w.padded(true, 0, from.x - 2, from.y - 2, to.x + 2, to.y + 2)
	var dz := to.x - from.x + 4
	var dy := dz * (to.y - from.y + 4)
	var deep := 0
	for y in w.size_y:
		for z in range(from.y, to.y):
			for x in range(from.x, to.x):
				if w.slope_mask(x, y, z) == WorldData.FULL or not w.get_cell(x, y + 1, z) in [Mat.AIR, Mat.WATER]:
					continue
				var i := (y + 1) * dy + (z - from.y + 2) * dz + x - from.x + 2
				var a: PackedFloat32Array = ChunkMesher.patch(c, sh, i, dy, dz)
				var b: PackedFloat32Array = w.surface_patch(x, y, z)
				for k in 12:
					if not is_equal_approx(a[k], b[k]):
						printerr("patch differs at %s: %s / %s" % [Vector3i(x, y, z), a, b])
						return false
				deep += int(w.corner_heights(x, y, z).has(-1))
	return deep > 0


## True when every two sloping tops side by side whose corners meet at both ends of
## the side they share have the same curve along it (no gap to see through).
func _sides_meet(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	var shared := 0
	for z in range(from.y, to.y - 1):
		for x in range(from.x, to.x - 1):
			var y := w.surface_y(x, z) - 1
			if not _ref_can_slope(w, x, y, z) or w.slope_mask(x, y, z) == WorldData.FULL:
				continue
			var p := w.surface_patch(x, y, z)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for dl in [0, -1, 1]:
					if not _ref_can_slope(w, x + d.x, y + dl, z + d.y):
						continue
					var q := w.surface_patch(x + d.x, y + dl, z + d.y)
					var a := PackedFloat32Array()
					var b := PackedFloat32Array()
					for t in 5:
						var f := t / 4.0
						a.append(WorldData.patch_height(p, 1.0, f) if d.x == 1 else WorldData.patch_height(p, f, 1.0))
						b.append((WorldData.patch_height(q, 0.0, f) if d.x == 1 else WorldData.patch_height(q, f, 0.0)) + dl)
					if absf(a[0] - b[0]) < 0.01 and absf(a[4] - b[4]) < 0.01:
						shared += 1
						for t in 5:
							if absf(a[t] - b[t]) > 0.01:
								printerr("sides differ at %s toward %s: %s / %s" % [Vector3i(x, y, z), d, a, b])
								return false
					break
	return shared > 0


## True when the shapes of the columns from..to follow the rules.
func _shapes_match(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	for y in w.size_y:
		for z in range(from.y, to.y):
			for x in range(from.x, to.x):
				var corners := 0
				var m := w.get_cell(x, y, z)
				for k in 4:
					if _ref_cut(w, x, y, z, k) or _ref_fill(w, x, y, z, k):
						corners |= 1 << k
				if w.slope_mask(x, y, z) != _ref_slope(w, x, y, z) \
						or w.corner_cuts(x, y, z) | w.corner_fills(x, y, z) != corners:
					printerr("shape differs at %s (%s): slope %d / %d, corners %d / %d" % [Vector3i(x, y, z), Mat.NAMES[m],
						w.slope_mask(x, y, z), _ref_slope(w, x, y, z), w.corner_cuts(x, y, z) | w.corner_fills(x, y, z), corners])
					return false
	return true


## Slope mask of a cell: its sloping top's, or for a covered cell the corners the
## slope above goes down into.
func _ref_slope(w: WorldData, x: int, y: int, z: int) -> int:
	var top := _ref_top_slope(w, x, y, z)
	return top if top != WorldData.FULL else WorldData.FULL & ~_ref_deep(w, x, y, z)


## Corners of the slope above covered cell (x, y, z) that go down into it: low there,
## and every other column around meets it a level lower, is a slope on its level low
## there and going down too, is open further down, or (east or west only) stands as
## high or higher (at least one meets it lower); the cells going down are loose wild
## ground.
func _ref_deep(w: WorldData, x: int, y: int, z: int) -> int:
	var mask := _ref_top_slope(w, x, y + 1, z)
	if mask == WorldData.FULL or not _ref_deepable(w, x, y, z):
		return 0
	var out := 0
	for k in 4:
		if mask & (1 << k):
			continue
		var o: Vector2i = WorldData.CORNER_DIRS[k]
		var ok := true
		var lower := false
		for n: Vector2i in [Vector2i(o.x, 0), Vector2i(0, o.y), o]:
			var kk := k
			if n.x != 0:
				kk ^= 1
			if n.y != 0:
				kk = 3 - kk
			var nx := x + n.x
			var nz := z + n.y
			if w.get_cell(nx, y + 1, nz) in [Mat.AIR, Mat.WATER]:
				if w.get_cell(nx, y, nz) in [Mat.AIR, Mat.WATER]:
					# Open further down than the corner: no part in it unless its top is high.
					lower = lower or _ref_ground(w, nx, y - 1, nz) and _ref_top_slope(w, nx, y - 1, nz) & (1 << kk) != 0
				else:
					ok = ok and _ref_ground(w, nx, y, nz) and _ref_top_slope(w, nx, y, nz) & (1 << kk) == 0
					lower = true
			elif n.y != 0:
				# A column east or west as high or higher has no part in it.
				ok = ok and _ref_ground(w, nx, y + 1, nz) and _ref_top_slope(w, nx, y + 1, nz) & (1 << kk) == 0 \
					and _ref_deepable(w, nx, y, nz)
		if ok and lower:
			out |= 1 << k
	return out


func _ref_deepable(w: WorldData, x: int, y: int, z: int) -> bool:
	return w.in_bounds(x, y, z) and w.chunk_at(x, z).natural[y * WorldData.LAYER + WorldData.col_of(x, z)] == WorldData.WILD \
		and Mat.can_slope(w.get_cell(x, y, z))


func _ref_top_slope(w: WorldData, x: int, y: int, z: int) -> int:
	if not _ref_can_slope(w, x, y, z):
		return WorldData.FULL
	var low := 0
	for k in 4:
		var o: Vector2i = WorldData.SIDES[k]
		if _ref_low(w, x + o.x, y, z + o.y):
			low |= 1 << k
	if low != 0:
		return WorldData.RAMPS[low]
	var mask := WorldData.FULL
	for k in 4:
		var o: Vector2i = WorldData.CORNER_DIRS[k]
		if _ref_low(w, x + o.x, y, z + o.y) and _ref_can_slope(w, x + o.x, y, z) and _ref_can_slope(w, x, y, z + o.y):
			if mask != WorldData.FULL:
				return WorldData.FULL
			mask = WorldData.FULL & ~(1 << k)
	return mask


func _ref_can_slope(w: WorldData, x: int, y: int, z: int) -> bool:
	return w.in_bounds(x, y, z) and w.chunk_at(x, z).natural[y * WorldData.LAYER + WorldData.col_of(x, z)] == WorldData.WILD \
		and Mat.can_slope(w.get_cell(x, y, z)) and w.get_cell(x, y + 1, z) in [Mat.AIR, Mat.WATER]


func _ref_low(w: WorldData, x: int, y: int, z: int) -> bool:
	if w.chunk_at(x, z) == null:
		return false
	var m := w.get_cell(x, y, z)
	return (m == Mat.AIR or m == Mat.WATER) and w.get_cell(x, y - 1, z) != Mat.AIR


func _ref_ground(w: WorldData, x: int, y: int, z: int) -> bool:
	var m := w.get_cell(x, y, z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != Mat.LOG


func _ref_cut_here(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = WorldData.CORNER_DIRS[k]
	var a := w.get_cell(x + o.x, y, z)
	if a != Mat.AIR and a != Mat.WATER or w.get_cell(x, y, z + o.y) != a or w.get_cell(x + o.x, y, z + o.y) != a:
		return false
	if not (_ref_ground(w, x, y, z) and w.is_natural(x, y, z) and w.is_natural(x + o.x, y, z) \
			and w.is_natural(x, y, z + o.y) and w.is_natural(x + o.x, y, z + o.y)):
		return false
	var mask := _ref_top_slope(w, x, y, z)
	return mask == WorldData.FULL or mask & (1 << k) == 0 and _ref_deep(w, x, y - 1, z) & (1 << k) == 0


func _ref_cut(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	while _ref_cut_here(w, x, y, z, k):
		var above := w.get_cell(x, y + 1, z)
		if above == Mat.AIR or above == Mat.WATER or above == Mat.LEAVES:
			return true
		y += 1
	return false


func _ref_fill_here(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = WorldData.CORNER_DIRS[k]
	var m := w.get_cell(x, y, z)
	if m != Mat.AIR and m != Mat.WATER:
		return false
	return _ref_ground(w, x + o.x, y, z) and _ref_ground(w, x, y, z + o.y) and _ref_ground(w, x + o.x, y, z + o.y) \
		and w.is_natural(x, y, z) and w.is_natural(x + o.x, y, z) and w.is_natural(x, y, z + o.y) \
		and w.is_natural(x + o.x, y, z + o.y) and _ref_top_slope(w, x + o.x, y, z) == WorldData.FULL \
		and _ref_top_slope(w, x, y, z + o.y) == WorldData.FULL


func _ref_fill(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	while _ref_fill_here(w, x, y, z, k):
		var below := w.get_cell(x, y - 1, z)
		if below != Mat.AIR and below != Mat.WATER and below != Mat.LEAVES:
			return true
		y -= 1
	return false


func _test_ai_relations() -> void:
	# The example from the design: a cat is food for a wolf, the wolf is a threat
	# to the cat, and the cat hunts squirrels, with no rule written for the cat.
	_check(AiRules.is_food("core:wolf", "core:cat"), "wolf sees a cat as food")
	_check(AiRules.is_threat("core:cat", "core:wolf"), "cat sees a wolf as a threat")
	_check(not AiRules.is_food("core:cat", "core:wolf"), "cat does not hunt wolves")
	_check(AiRules.is_food("core:cat", "core:squirrel"), "cat hunts squirrels")
	_check(AiRules.is_food("core:cat", "core:rabbit"), "cat hunts rabbits")
	_check(AiRules.is_threat("core:squirrel", "core:cat"), "squirrel fears a cat")
	_check(not AiRules.is_threat("core:cat", "core:deer"), "cat ignores deer")
	_check(not AiRules.is_food("core:deer", "core:rabbit"), "herbivores hunt nobody")
	_check(not AiRules.is_food("core:wolf", "core:human"), "a lone wolf does not see a human as food")
	_check(AiRules.is_threat("core:rabbit", "core:human"), "rabbit fears people")
	_check(AiRules.is_active("core:wolf", 0.0) and not AiRules.is_active("core:wolf", 1.0), "wolves are active at night")


func _test_pixel_view() -> void:
	var screens := [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080), Vector2(2532, 1170),
		Vector2(1170, 2532), Vector2(2400, 1008), Vector2(375, 667), Vector2(3840, 2160)]
	var whole := true
	for screen in screens:
		var view: Array = PixelView.layout(screen)
		var scale: int = view[0]
		var image: Vector2i = view[1]
		var covered := Vector2(image * scale)
		whole = whole and image.x % 2 == 0 and image.y % 2 == 0 \
			and covered.x >= screen.x and covered.y >= screen.y \
			and covered.x - screen.x < 2 * scale and covered.y - screen.y < 2 * scale \
			and absf(image.y - PixelView.TARGET_HEIGHT) <= PixelView.TARGET_HEIGHT * 0.25
	_check(whole, "low-res image is scaled by a whole number and covers the screen")
	_check(is_equal_approx(PixelView.camera_size(360), 22.5), "16 pixels per world unit")
	# A cell's top and its south wall both cover 16 x 16 pixels on screen.
	var top := PixelView.screen_plane(Vector3(3, 2, 5)) - PixelView.screen_plane(Vector3(3, 2, 4))
	var wall := PixelView.screen_plane(Vector3(3, 1, 5)) - PixelView.screen_plane(Vector3(3, 2, 5))
	_check(top == Vector2(0, 1) and wall == Vector2(0, 1), "top and wall of a cell are equally tall on screen")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var on_grid := true
	for i in 50:
		var p := Vector3(rng.randf_range(-100, 100), rng.randf_range(0, 20), rng.randf_range(-100, 100))
		var c := PixelView.screen_plane(PixelView.snap(p)) * PixelView.PIXELS_PER_UNIT
		on_grid = on_grid and absf(c.x - roundf(c.x)) < 0.001 and absf(c.y - roundf(c.y)) < 0.001
		on_grid = on_grid and PixelView.snap(p).distance_to(p) < 0.06
	_check(on_grid, "snapped points land on whole pixels")
	# A view ray through a pixel passes every point drawn on that pixel.
	var cell := Vector3(10.5, 4.0, 20.25)
	var ray: Array = PixelView.view_ray(PixelView.screen_plane(cell), Vector2.ZERO, 30.0)
	var t: float = (ray[0].y - cell.y) / -ray[1].y
	_check((ray[0] + ray[1] * t).distance_to(cell) < 0.001, "view ray hits the point under the pixel")


func _test_trees() -> void:
	# Every species at every scale stays within the height it promises, so the
	# generator can tell whether a tree fits under the top of the world.
	var rng := RandomNumberGenerator.new()
	var fits := true
	for species in Trees.SPECIES.size():
		for scale in [0.6, 0.8, 1.0, 1.3]:
			for k in 6:
				rng.seed = k
				var w := WorldData.new(40, Vector2i(32, 32))
				Trees.place(w, 15, 1, 15, species, rng, scale)
				var top := 0
				for c: WorldData.Chunk in w.chunks.values():
					for col in WorldData.LAYER:
						top = maxi(top, WorldData.top_level(c.leaf[col] | c.logs[col]))
				fits = fits and top <= Trees.height(species, scale)
	_check(fits, "trees stay within Trees.height")
	var strips := _woods()
	var w: WorldData = strips.world
	var kinds := {}
	var trunks := true
	for at in w.trees:
		kinds[w.trees[at]] = true
		trunks = trunks and w.log_col(at.x, at.y) != 0
	_check(not w.trees.is_empty() and trunks, "every noted tree has a trunk")
	_check(kinds.size() == Trees.SPECIES.size(), "the generator grows every species")
	# Crowns of spruces take needle cards, of oaks leaf cards.
	var rows := {}
	for key: Vector2i in strips.keys:
		var chunk: Dictionary = Foliage.build_chunk(w, key.x * 16, key.y * 16, 16)
		var buf: PackedFloat32Array = chunk.clumps[1]
		for i in chunk.clumps[0]:
			var row := int(buf[i * 20 + 19]) % Foliage.DEEP_ROW
			rows[row >= 3] = true
	_check(rows.size() == 2, "crowns have both broad leaves and needles")


## Strips of chunks across a taiga and a forest near the spawn, where both species of
## tree and every type of bush grow: the world the tree and bush tests look at
## ({"world", "keys"}).
const STRIP_CHUNKS := 6


func _woods() -> Dictionary:
	var gen := WorldGen.new(42)
	var keys: Array[Vector2i] = []
	var near := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	for what in ["taiga", "forest"]:
		var at := WorldData.chunk_key(gen.find_place(what, near).x, gen.find_place(what, near).y)
		for x in range(at.x - STRIP_CHUNKS / 2, at.x + STRIP_CHUNKS / 2):
			_ensure_stage(gen, Vector2i(x, at.y), WorldGen.SHAPED)
			keys.append(Vector2i(x, at.y))
	return {"world": gen.world, "keys": keys}


func _test_bushes() -> void:
	var w: WorldData = _woods().world
	var kinds := {}
	var on_grass := true
	for at: Vector3i in w.bushes:
		kinds[w.bushes[at]] = true
		on_grass = on_grass and w.get_cell(at.x, at.y - 1, at.z) == Mat.GRASS and w.get_cell(at.x, at.y, at.z) == Mat.AIR
	_check(on_grass, "bushes stand in air on grass")
	_check(kinds.size() == Bushes.TYPES.size(), "the generator grows every type of bush")
	# Each bush draws its type's clusters, berry bushes some with berries.
	var cells: Array[Vector3i] = []
	cells.assign(w.bushes.keys())
	var part: Array = Foliage.bushes(cells, w.bushes)
	var want := 0
	for at in cells:
		want += Bushes.TYPES[w.bushes[at]].cards
	_check(part[0] == want, "bushes draw their clusters")
	var buf: PackedFloat32Array = part[1]
	var ripe := false
	for i in part[0]:
		ripe = ripe or int(buf[i * 20 + 19]) % Foliage.DEEP_ROW >= PixelTextures.BERRY_ROW
	_check(ripe, "berry bushes have clusters with berries")
	# The plants on grass, for what cutting it gives, are the ones drawn there.
	var found := {}
	var same := true
	for at: Vector3i in w.bushes:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var c := at + Vector3i(dx, -1, dz)
				var ids := Foliage.plants_on(w, c.x, c.y, c.z)
				same = same and ids == Foliage.plants_on(w, c.x, c.y, c.z)
				for id in ids:
					found[id] = true
	_check(same and found.has(Plants.TUFT), "grass has its plants, the same each time")
	# Cut short, grass keeps only its low tufts; sown with grain, ears stand on it.
	var tall := Vector3i(-1, -1, -1)
	for at: Vector3i in w.bushes:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var c := at + Vector3i(dx, -1, dz)
				if tall.y < 0 and Foliage.plants_on(w, c.x, c.y, c.z).any(func(id) -> bool: return id != Plants.TUFT):
					tall = c
	_check(tall.y >= 0, "some grass has more than tufts on it")
	if tall.y >= 0:
		w.set_turf(tall, "")
		var short := Foliage.plants_on(w, tall.x, tall.y, tall.z)
		_check(not short.is_empty() and short.all(func(id) -> bool: return id == Plants.TUFT), "grass cut short has only tufts")
		w.set_turf(tall, Plants.EARS)
		_check(Foliage.plants_on(w, tall.x, tall.y, tall.z).count(Plants.EARS) >= 2, "sown grass grows ears")
		w.set_cell(tall.x, tall.y, tall.z, Mat.DIRT)
		_check(w.turf_at(tall) == null, "a changed cell forgets what grew on it")


func _test_sprite_sheet() -> void:
	_check(SpriteSheet.direction_of(Vector2(0, 1)) == "s", "pushing south faces south")
	_check(SpriteSheet.direction_of(Vector2(1, 0)) == "e", "pushing east faces east")
	_check(SpriteSheet.direction_of(Vector2(-1, -1)) == "nw", "pushing north-west faces north-west")
	_check(SpriteSheet.direction_of(Vector2(0.3, -1)) == "n", "a push mostly north faces north")
	var look := ["body", "hair", "shirt", "trousers", "boots"]
	var s := Figure.sheet(look)
	var cols := s.columns
	var fw := s.frame_size.x
	var fh := s.frame_size.y
	_check(cols == 40 and fw == 32 and fh == 32, "player sheet: standing, walking, jumping, swimming, seven works of four; 32 by 32 frames")
	_check(s.texture.get_width() == cols * fw and s.texture.get_height() == 8 * fh, "player sheet has eight directions")
	var img := s.texture.get_image()
	var drawn := 0
	for y in fh:
		for x in fw:
			if img.get_pixel(x, y).a > 0.5:
				drawn += 1
	_check(drawn > 80 and drawn < fw * fh / 2, "the standing frame is drawn with room around it")
	_check(img.get_pixel(fw / 2, fh - 1).a > 0.5, "the feet stand on the bottom row of the frame")
	var uv := s.frame_uv("s", "idle", 0.0)
	_check(uv == Vector4(0.0, 0.0, 1.0 / cols, 1.0 / 8.0), "the first frame is the top-left one")
	_check(s.frame_uv("s", "walk", 0.25) != s.frame_uv("s", "walk", 0.0), "walking changes frames in time")
	var w := s.frame_uv("w", "idle", 0.0)
	_check(w.z > 0.0 and is_equal_approx(w.y, 6.0 / 8.0), "west has a row of its own")
	var east := img.get_region(Rect2i(0, 2 * fh, fw, fh))
	east.flip_x()
	_check(east.get_data() == img.get_region(Rect2i(0, 6 * fh, fw, fh)).get_data(), "west is east mirrored when the hands are empty")
	_check(Figure.sheet(["body"]).texture.get_image().get_pixel(fw / 2, fh - 2) != img.get_pixel(fw / 2, fh - 2), "without boots the feet are bare")
	# The bare figure knows where its hands are; the one in use moves in the works.
	var anchors: Array = Figure.anchors()
	var works: Dictionary = Figure.data().works
	var chop: Array = works.chop.columns
	_check(anchors[0][chop[0]].right.at != anchors[0][chop[1]].right.at, "the hand in use winds up and strikes")
	_check(anchors[0][chop[0]].left.at == anchors[0][0].left.at, "the other hand stays put")
	_check(anchors[2][0].right.front and not anchors[2][0].left.front, "facing east the right hand is near, the left far")
	_check(not anchors[4][0].right.front, "with the back turned a hand is behind the body")
	_check(anchors[0][works.mow.columns[1]].left.is_empty(), "in a two-handed work the left hand holds the same thing")
	_check(Figure.opposite("se") == "sw" and Figure.opposite("w") == "e" and Figure.opposite("n") == "n", "opposite directions")
	# Things held have sheets of their own, put at the hands.
	var held_dir := Figure.SPRITES + "/held/"
	var axe := {"sprite": held_dir + "axe.png", "anim": "chop"}
	var cell := Vector2i(Figure.data().held.cell[0], Figure.data().held.cell[1])
	_check(Figure.held_sheet(axe.sprite).get_size() == Vector2i(5, 8) * cell, "a tool's sheet: carried and its four frames, in eight directions")
	var armed := Figure.sheet(look, {"right": axe, "active": "right"})
	var with_axe := armed.texture.get_image()
	_check(with_axe.get_region(Rect2i(0, 0, fw, fh)).get_data() != img.get_region(Rect2i(0, 0, fw, fh)).get_data(), "a held tool shows")
	_check(with_axe.get_region(Rect2i(chop[0] * fw, 0, fw, fh)).get_data() != with_axe.get_region(Rect2i(chop[1] * fw, 0, fw, fh)).get_data(), "a chop winds up and strikes")
	var slash: Array = works.slash.columns
	_check(with_axe.get_region(Rect2i(slash[0] * fw, 0, fw, fh)).get_data() != img.get_region(Rect2i(slash[0] * fw, 0, fw, fh)).get_data(), "in another work a tool is carried")
	var west := with_axe.get_region(Rect2i(0, 6 * fh, fw, fh))
	west.flip_x()
	_check(west.get_data() != with_axe.get_region(Rect2i(0, 2 * fh, fw, fh)).get_data(), "a tool stays in its hand when the body turns west")
	# The left hand in use: each direction is the opposite one, mirrored, hands swapped.
	var lefty := Figure.sheet(look, {"left": axe, "active": "left"}).texture.get_image()
	var mirrored := with_axe.get_region(Rect2i(chop[1] * fw, 6 * fh, fw, fh))
	mirrored.flip_x()
	_check(lefty.get_region(Rect2i(chop[1] * fw, 2 * fh, fw, fh)).get_data() == mirrored.get_data(), "an axe in the left hand chops as the right one mirrored")
	var lump := {"icon": "test:nothing", "picture": null, "anim": "reach"}
	var steps = Figure.new(look, {"left": axe, "right": lump, "active": "left"})
	var count := 0
	while not steps.step():
		count += 1
	_check(count == 8 * ceili(cols / float(Figure.PART)) and steps.target.texture.get_image().get_data() == Figure.sheet(look, steps.held).texture.get_image().get_data(),
		"a sheet built a part of a row a step is the one built at once")
	_check(Figure.icon_turns("test:nothing", null)[0].get_used_rect().has_area(), "a thing without a picture is a lump")
	# A thing without a sheet is its icon, made small and turned with the hand.
	var icon := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	icon.fill_rect(Rect2i(5, 1, 2, 10), Color.RED)
	var turns: Array = Figure.icon_turns("test:stick", icon)
	var small: Image = turns[0]
	_check(small.get_width() <= Figure.data().held.icon and small.get_height() <= Figure.data().held.icon, "an icon in a hand is made small")
	var lying: Rect2i = turns[2].get_used_rect()
	_check(lying.size.x > lying.size.y and small.get_used_rect().size.y > small.get_used_rect().size.x, "an icon turns a quarter on its side")
	var stick := {"icon": "test:stick", "picture": icon, "anim": "chop"}
	var swung := Figure.sheet(look, {"right": stick, "active": "right"}).texture.get_image()
	_check(swung.get_region(Rect2i(chop[0] * fw, 2 * fh, fw, fh)).get_data() != swung.get_region(Rect2i(chop[2] * fw, 2 * fh, fw, fh)).get_data(),
		"an icon swings with the hand in its work")
	# Nothing spills over a frame's edge: what is on it is outline next to the figure.
	var spilled := 0
	for row in 8:
		for c in cols:
			var r := Rect2i(c * fw, row * fh, fw, fh)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var edge := x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
					if not edge or with_axe.get_pixel(x, y).a < 0.5:
						continue
					var inside := false
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n := Vector2i(x, y) + d
						inside = inside or (r.has_point(n) and with_axe.get_pixelv(n).a > 0.5 and with_axe.get_pixelv(n) != SpriteSheet.OUTLINE)
					if not inside:
						spilled += 1
	_check(spilled == 0, "the outline keeps within each frame")
	# The player plays the work of the thing in the hand in use once, then stands again.
	var p = PlayerScript.new()
	p.sheet = s
	p.on_ground = true
	p.held = {"left": {"sprite": held_dir + "shovel.png", "anim": "dig"}, "right": axe, "active": "left"}
	p.work("", 0.4, Vector3(-5.0, 0.0, 0.0))
	_check(p.work_kind == "dig" and p.facing == "w", "a shovel digs, turned towards the cell")
	p._animate(Vector2.ZERO, 0.0, 0.1)
	_check(p.anim == "dig", "the work plays")
	p._animate(Vector2.ZERO, 0.0, 0.5)
	_check(p.anim == "idle" and p.work_kind == "", "after the swing the body stands again")
	p.held.active = "right"
	p.work("", 0.4)
	_check(p.work_kind == "chop", "an axe chops")
	p.held.active = "left"
	p.held.left = {}
	p.work_kind = ""
	p.work("", 0.4)
	_check(p.work_kind == "reach", "bare hands reach")
	p.work_kind = ""
	p.on_ground = false
	p.velocity_y = 1.0
	p._animate(Vector2.ZERO, 0.0, 0.1)
	var rising := s.frame_uv(p.facing, p.anim, p.anim_time)
	p.velocity_y = -1.0
	p._animate(Vector2.ZERO, 0.0, 0.1)
	_check(p.anim == "jump" and rising != s.frame_uv(p.facing, p.anim, p.anim_time), "a jump goes up, then comes down")
	p.swimming = true
	p._animate(Vector2.ZERO, 0.0, 0.1)
	_check(p.anim == "swim", "in deep water the body swims")
	p.free()


func _test_yaml() -> void:
	var yaml := Yaml.new()
	var doc: Variant = yaml.parse("""
# a comment
id: core
version: "0.1"
deps: [a, 'b c', 3, 2.5, true, ~]
colors:
  - "#aabbcc"   # not a comment
items:
  - id: grass
    title: Трава
    spread: {x: 1, y: -2.5}
  - id: dirt
    nested:
      - 1
      - 2
  -
    id: stone
empty:
flat:
- a
- "b: c"
""", "test.yaml")
	_check(yaml.error == "", "yaml parses: " + yaml.error)
	_check(doc is Dictionary and doc.get("id") == "core" and doc.get("version") == "0.1", "yaml reads scalars")
	_check(doc.get("deps") == ["a", "b c", 3, 2.5, true, null], "yaml reads flow lists")
	_check(doc.get("colors") == ["#aabbcc"], "yaml keeps # inside quotes")
	var items: Array = doc.get("items", [])
	_check(items.size() == 3 and items[0] == {"id": "grass", "title": "Трава", "spread": {"x": 1, "y": -2.5}},
		"yaml reads mappings in a list")
	_check(items.size() == 3 and items[1].get("nested") == [1, 2] and items[2] == {"id": "stone"},
		"yaml reads nested lists and items on their own line")
	_check(doc.get("empty") == null and doc.has("empty"), "an empty value is null")
	_check(doc.get("flat") == ["a", "b: c"], "a list may sit at its key's indent")
	for bad in ["a: [1, 2", "a: 1\n\tb: 2", "a: 1\na: 2", "- 1\n  - 2", "x: \"abc", "a: 1\n b: 2"]:
		yaml.parse(bad, "bad.yaml")
		_check(yaml.error.begins_with("bad.yaml:"), "yaml rejects %s" % bad.c_escape())


func _test_content() -> void:
	_check(Content.problems.is_empty(), "core content loads without problems")
	_check(Mat.check().is_empty() and AiRules.check().is_empty() and Trees.check().is_empty() and Bushes.check().is_empty(),
		"core content satisfies the engine")
	_check(Mat.AIR == 0 and Mat.IDS[Mat.GRASS] == "core:grass" and Mat.NAMES[Mat.GRASS] == "Трава", "materials get their indices")
	_check(Mat.PLACEABLE == [Mat.STONE, Mat.DIRT, Mat.PLANKS, Mat.BRICK, Mat.SAND, Mat.CLAY, Mat.LOG], "hotbar order comes from the data")
	_check(Mat.is_solid(Mat.STONE) and not Mat.is_solid(Mat.WATER) and not Mat.is_roof(Mat.LEAVES) and Mat.can_slope(Mat.SAND),
		"material flags come from the data")
	_check(Trees.SPECIES[Trees.SPRUCE].leaves == Trees.NEEDLES and Trees.SPECIES[Trees.OAK].tints[0] is Color, "trees get their looks")
	_check(Bushes.TYPES[Bushes.SHRUB].berries == Color.BLACK and Bushes.TYPES[Bushes.BLUEBERRY].spread is Vector3, "bushes get their looks")
	_check(AiRules.SPECIES["core:wolf"].diet == ["meat"] and AiRules.SPECIES["core:wolf"].sprite == "wolf", "creatures get their properties")
	# The checks catch what a mod author gets wrong.
	var before := Content.MODS.duplicate()
	var mod := "res://content/_test"
	DirAccess.make_dir_recursive_absolute(mod + "/data")
	_write(mod + "/mod.yaml", "id: _test\ntitle: Test\nversion: \"1\"\napi: 1\n")
	_write(mod + "/data/materials.yaml", "- id: Bad Id\n  title: x\n- id: glass\n  title: Стекло\n  solid: maybe\n  weight: 3\n- id: glass\n  title: again\n")
	_write(mod + "/data/creatures.yaml", "- id: bear\n  title: Медведь\n  mass: -1\n  diet: [stones]\n  speed: 1\n  sight: 1\n  human_wariness: 2\n  active: dusk\n")
	_write(mod + "/data/trees.yaml", "- id: pine\n  title: Сосна\n  leaves: needles\n  trunk: [1]\n  crown: [1, 2, 3]\n  tints: []\n")
	_write(mod + "/data/recipes.yaml", "- id: rope\n  title: x\n  makes: core:cord\n  needs: {core:fiber: 0}\n- id: dust\n  title: y\n  makes: core:cord\n  needs: {stone_dust: 1}\n")
	Content.MODS.append("_test")
	Content.refresh()
	var found := {}
	for p in Content.problems:
		for what in ["Bad Id", "glass.solid", "glass.weight", "duplicate id", "bear.mass", "bear.diet",
				"bear.human_wariness", "bear.active", "pine.trunk", "pine.tints", "rope.needs", "`_test:stone_dust`"]:
			if what in p:
				found[what] = true
	_check(found.size() == 12, "the loader reports every kind of mistake (%d of 12): %s" % [found.size(), Content.problems])
	_check(Content.find("materials", "_test:glass").title == "Стекло", "a duplicate id within a mod is skipped")
	Content.MODS.assign(before)
	for f in ["data/materials.yaml", "data/creatures.yaml", "data/trees.yaml", "data/recipes.yaml", "mod.yaml"]:
		DirAccess.remove_absolute(mod + "/" + f)
	DirAccess.remove_absolute(mod + "/data")
	DirAccess.remove_absolute(mod)
	Content.refresh()
	_check(Content.problems.is_empty(), "core content loads clean again")


func _test_items() -> void:
	_check(Items.check().is_empty(), "core items satisfy the engine")
	_check(Items.dug[Mat.GRASS] == "core:dirt" and Items.dug[Mat.STONE] == "core:stone" and Items.dug[Mat.LEAVES] == "",
		"dug cells give their items")
	for m in Mat.PLACEABLE:
		_check(Items.get_item(Items.placed_by[m]).place == Mat.IDS[m], "an item places hotbar block %s" % Mat.IDS[m])
	_check(Items.get_item("log").id == "core:log" and Items.title("core:branch") == "Ветка", "bare drop names are core items")
	_check(Trees.SPECIES[Trees.OAK].seed == "core:acorn" and Items.has(Trees.SPECIES[Trees.SPRUCE].seed), "tree seeds are items")
	_check(Bushes.TYPES[Bushes.RASPBERRY].fruit == "core:raspberry" and Items.food(Bushes.TYPES[Bushes.BLUEBERRY].fruit) > 0.0,
		"berries are food")
	_check(Bushes.TYPES[Bushes.SHRUB].fruit == "" and Bushes.TYPES[Bushes.SHRUB].twigs > 0, "a plain bush gives branches only")


func _test_tools() -> void:
	var hand := Tools.of("")
	var axe := Tools.of("core:stone_axe")
	var pick := Tools.of("core:stone_pickaxe")
	var shovel := Tools.of("core:wooden_shovel")
	_check(hand == Tools.HAND and Tools.of("core:branch") == Tools.HAND and axe.tool == "axe", "items that are no tools are bare hands")
	_check(Tools.can_dig(hand, Mat.DIRT) and Tools.can_dig(hand, Mat.LEAVES) and not Tools.can_dig(hand, Mat.STONE),
		"hands dig soft ground and leaves, not stone")
	_check(Tools.swing_time(hand, Mat.DIRT) > Tools.swing_time(shovel, Mat.DIRT), "a shovel digs faster than hands")
	_check(Tools.can_dig(pick, Mat.STONE) and Tools.can_dig(pick, Mat.COPPER_ORE) and not Tools.can_dig(shovel, Mat.STONE),
		"stone and ore only with a pickaxe")
	_check(Tools.can_dig(axe, Mat.PLANKS) and not Tools.can_dig(pick, Mat.LOG) and not Tools.can_dig(hand, Mat.WATER),
		"wood with an axe, water never")
	_check(Tools.why_not(hand, Mat.STONE) != "" and Tools.why_not(pick, Mat.STONE) == "", "a reason when a tool cannot dig")
	_check(Tools.step_of(Vector2(0, 1)) == Vector2i(0, 1) and Tools.step_of(Vector2(-0.7, -0.7)) == Vector2i(-1, -1),
		"facing snaps to 8 steps")
	var f := Vector3i(5, 3, 5)
	var order := Tools.front_cells(f, Vector2i(1, 0))
	_check(order.slice(0, 6) == [Vector3i(6, 3, 5), Vector3i(7, 3, 5), Vector3i(6, 3, 6), Vector3i(6, 3, 4), Vector3i(7, 3, 6), Vector3i(7, 3, 4)],
		"the action button digs in front, beyond it, left and right of it, beyond those")
	_check(order[6] == Vector3i(6, 2, 5) and order[12] == Vector3i(6, 4, 5) and order.size() == 20,
		"then a level lower, then a level higher")
	_check(order[18] == f + Vector3i(0, 2, 0) and order[19] == f + Vector3i.DOWN, "and last over the head and under the feet")
	var diagonal := Tools.front_ring(Vector2i(1, 1))
	_check(diagonal[0] == Vector3i(1, 0, 1) and diagonal[1] == Vector3i(2, 0, 2) and Vector3i(1, 0, 0) in diagonal \
		and Vector3i(0, 0, 1) in diagonal, "facing a diagonal, the sides are the columns touching both")
	_check(Tools.sweep(Vector3i(6, 2, 5), Vector2i(1, 0)) == [Vector3i(6, 2, 5), Vector3i(6, 2, 6), Vector3i(6, 2, 4)],
		"a scythe sweeps an arc in front")
	var sector := Tools.sector(Vector2i(0, 1))
	_check(sector[0] == Vector2i(0, 1) and Vector2i(1, 0) in sector and Vector2i(2, 1) in sector and not Vector2i(0, -1) in sector \
		and not Vector2i(1, -1) in sector, "trees and bushes are found ahead and beside, not behind")
	_check(Tools.use_of("") == "hand" and Tools.use_of("core:stone_axe") == "tool" and Tools.use_of("core:stone") == "place" \
		and Tools.use_of("core:raspberry_bush") == "plant" and Tools.use_of("core:grass_seeds") == "sow" \
		and Tools.use_of("core:campfire") == "prop" and Tools.use_of("core:raspberry") == "eat" and Tools.use_of("core:branch") == "hand",
		"what a held item is used for")
	var scythe := Tools.of("core:stone_scythe")
	_check(Tools.mown(Mat.GRASS) == Mat.DIRT and Tools.mown(Mat.DIRT) == -1, "cutting grass leaves dirt")
	_check(Tools.mows(hand) and Tools.mows(scythe) and Tools.mows(Tools.of("core:wooden_sword")) and not Tools.mows(shovel),
		"hands, a sword and a scythe cut grass")
	_check(Tools.mows_low(hand) and Tools.mows_low(scythe) and not Tools.mows_low(Tools.of("core:wooden_sword")),
		"a sword cuts only what grows tall on grass, hands and a scythe the grass too")
	_check(shovel.area == 1 and pick.area == 1, "a tool digs one cell a swing")
	_check(scythe.area > 1 and not Tools.can_dig(scythe, Mat.DIRT), "a scythe mows wide and does not dig")
	_check(Items.has(Mat.RECORDS[Mat.GRASS].mow_gives.keys()[0]), "cut grass gives fibre")
	var rng := RandomNumberGenerator.new()
	_check(Plants.check().is_empty() and Plants.harvest([Plants.EARS, Plants.EARS], rng).get("core:grain", 0) == 4,
		"ears give grain")
	_check(Tools.use_of("core:grain") == "sow" and Items.get_item("core:grain").crop == Plants.EARS, "grain is sown into ears")
	_check(Plants.harvest(["core:nothing"], rng).is_empty(), "an unknown plant gives nothing")
	_check(Trees.SPECIES[Trees.OAK].twigs > 0 and Trees.SPECIES[Trees.OAK].seeds > 0, "a standing oak gives branches and acorns by hand")
	var wall := Tools.area_cells(f, Vector3i(-1, 0, 0))
	_check(wall[0] == f and wall[1] == f + Vector3i.UP and wall.size() == 9, "a swing at a wall takes the cell above next (a passage)")
	for c in wall:
		_check(c.x == f.x, "a swing at a wall stays in the wall")
	var floor_cells := Tools.brush_cells(f, Vector3i.UP, 3)
	_check(floor_cells.size() == 9 and floor_cells[0] == f, "a brush starts at its centre")
	for c in floor_cells:
		_check(c.y == f.y and absi(c.x - f.x) <= 1 and absi(c.z - f.z) <= 1, "a brush on a floor lies flat around its centre")
	_check(Tools.brush_cells(f, Vector3i.BACK, 2).size() == 4 and Tools.brush_cells(f, Vector3i.BACK, 1) == [f], "brush sizes")
	_check(Tools.brush_shape(f, Vector3i.UP, Tools.BRUSHES[3]) == [f, f + Vector3i.UP], "the tall brush is two cells one on another")
	_check(Tools.brush_shape(f, Vector3i.UP, Tools.BRUSHES[4]) == [f], "the line brush places one cell at a time")
	_check(hand.reach < pick.reach and Tools.of("core:wooden_sword").reach < pick.reach and Tools.PLACE_REACH >= pick.reach,
		"tools reach farther than hands and a sword")
	_check(Items.has(Mat.RECORDS[Mat.GRASS].bonus) and Mat.RECORDS[Mat.GRASS].bonus_chance > 0.0 and Mat.RECORDS[Mat.STONE].bonus == "",
		"grass sometimes gives fibre")
	_check(Trees.SPECIES[Trees.OAK].hits > axe.power, "an oak takes more than one swing")
	var b: Dictionary = Bushes.TYPES[Bushes.RASPBERRY]
	_check(Items.get_item(b.item).plant == b.id, "a dug-out bush is an item that plants it again")
	var w := WorldData.new(2, Vector2i(2, 2))
	w.heap_drop("core:dirt", Vector3(1.0, 1.0, 1.0), 1)
	w.heap_drop("core:dirt", Vector3(1.1, 1.0, 1.0), 2)
	w.heap_drop("core:stone", Vector3(1.1, 1.0, 1.0), 1)
	w.heap_drop("core:dirt", Vector3(3.0, 1.0, 1.0), 1)
	var list: Array = w.drops[Vector2i.ZERO]
	_check(list.size() == 3 and list[0][3] == 3, "what is dug together lies in one heap")


func _test_crafting() -> void:
	_check(Crafting.check().is_empty(), "every recipe can be made, at a real station: %s" % Crafting.check())
	var have := Crafting.reachable()
	for id in ["core:stone_axe", "core:stone_pickaxe", "core:wooden_shovel", "core:wooden_sword", "core:stone_scythe", "core:stone_sword", "core:wooden_pickaxe", "core:wooden_scythe",
			"core:workbench",
			"core:kiln", "core:brick", "core:grain", "core:grass_seeds", "core:flatbread"]:
		_check(have.has(id), "%s can be had from a new world" % id)
	_check(Items.get_item(Mat.RECORDS[Mat.DIRT].bonus).id == "core:flint", "digging soil now and then gives flint for the first tools")
	var cord := Crafting.get_recipe("core:cord")
	var axe := Crafting.get_recipe("core:stone_axe")
	var planks := Crafting.get_recipe("core:planks")
	_check(cord.at == "" and cord.needs == {"core:fiber": 3} and axe.at == "core:workbench", "recipes come from the data")
	var inv := Inventory.new()
	var knows := Knowledge.new()
	knows.look_at(inv)
	_check(not knows.knows(cord) and knows.recipes().is_empty(), "nothing is known with an empty bag")
	var heard := []
	knows.learned.connect(func(id: String) -> void: heard.append(id))
	inv.add("core:fiber", 7)
	knows.look_at(inv)
	_check(knows.knows(cord) and heard == ["core:cord"], "a recipe is learned when its materials have been in the bag")
	var copy := Knowledge.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(knows.to_dict())))
	_check(copy.knows(cord) and copy.seen.has("core:fiber"), "knowledge survives a save")
	_check(Crafting.why_not(cord, inv, {}) == "" and Crafting.why_not(axe, inv, {}).begins_with("Нужен станок"),
		"by hand anywhere, at a station only near it")
	_check(Crafting.why_not(planks, inv, {"core:workbench": true}).begins_with("Нужен инструмент"), "planks need an axe in the bag")
	var q := CraftQueue.new()
	_check(q.add(cord, inv) and q.add(cord, inv) and not q.add(cord, inv), "the queue takes the materials of each job")
	_check(inv.count("core:fiber") == 1, "materials are gone while queued")
	var stacks := q.cancel(1)
	for st in stacks:
		inv.add(st[0], st[1])
	_check(inv.count("core:fiber") == 4 and q.jobs.size() == 1, "a cancel gives the materials back")
	var made := q.step(cord.time * 0.5, func(_r: Dictionary) -> bool: return false)
	_check(made.is_empty() and q.progress() == 0.0, "a job waits while it cannot be worked on")
	q.step(cord.time * 0.5, func(_r: Dictionary) -> bool: return true)
	_check(is_equal_approx(q.progress(), 0.5), "a job takes its time")
	made = q.step(cord.time, func(_r: Dictionary) -> bool: return true)
	_check(made.size() == 1 and made[0].makes == "core:cord" and q.jobs.is_empty(), "a job is done when its time is up")
	var q2 := CraftQueue.new()
	q2.add(cord, inv)
	q2.step(0.5, func(_r: Dictionary) -> bool: return true)
	var q3 := CraftQueue.new()
	q3.from_dict(JSON.parse_string(JSON.stringify(q2.to_dict())))
	_check(q3.jobs.size() == 1 and is_equal_approx(q3.jobs[0].left, cord.time - 0.5), "the queue survives a save")


func _test_wear() -> void:
	var inv := Inventory.new(4)
	var d: int = Items.get_item("core:stone_axe").durability
	_check(d > 0 and Items.get_item("core:stone_axe").repair.has("core:flint"), "tools wear and are repaired with materials")
	inv.add("core:stone_axe", 1)
	for i in d - 1:
		inv.wear_tool("core:stone_axe", d)
	_check(inv.worn(0) == d - 1 and inv.count("core:stone_axe") == 1, "a tool wears with each swing")
	var copy := Inventory.new(4)
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(copy.worn(0) == d - 1, "wear survives a save")
	var chest := Inventory.new(4)
	_check(copy.move_slot(0, chest) == 1 and chest.worn(0) == d - 1, "a worn tool keeps its wear in the chest")
	inv.add("core:stone_axe", 1)
	_check(inv.slots[1] != null and inv.worn(1) == 0, "a new tool does not join a worn one")
	_check(inv.wear_tool("core:stone_axe", d) and inv.count("core:stone_axe") == 1, "a worn-out tool breaks")
	inv.wear_tool("core:stone_axe", d)
	var at := inv.slots.find(inv.slots.filter(func(x) -> bool: return x != null)[0])
	inv.mend(at)
	_check(inv.worn(at) == 0, "a repaired tool is as good as new")


func _test_inventory() -> void:
	var inv := Inventory.new(3)
	var log_stack := Items.stack_size("core:log")
	_check(inv.add("core:branch", 5) == 5 and inv.count("core:branch") == 5, "items go into the bag")
	_check(inv.add("core:branch", 3) == 3 and inv.slots[1] == null, "a stack is topped up before a new slot")
	_check(inv.add("core:log", log_stack * 3) == log_stack * 2, "only what fits goes in")
	_check(inv.room_for("core:log") == 0 and inv.room_for("core:branch") == Items.stack_size("core:branch") - 8, "room is counted by stacks")
	var w := 8 * Items.weight("core:branch") + log_stack * 2 * Items.weight("core:log")
	_check(is_equal_approx(inv.weight(), w), "the bag weighs its items")
	_check(inv.remove("core:log", 1) == 1 and inv.count("core:log") == log_stack * 2 - 1, "items come out of the bag")
	var heavy := Inventory.new()
	_check(heavy.speed_factor() == 1.0, "an empty bag does not slow")
	heavy.add("core:stone", ceili(Inventory.WEIGHT_LIMIT * 1.25 / Items.weight("core:stone")))
	var f := heavy.speed_factor()
	_check(heavy.overloaded() and f < 1.0 and f > Inventory.OVERLOAD_PACE, "overload slows the pace")
	heavy.add("core:stone", 200)
	_check(heavy.speed_factor() == Inventory.OVERLOAD_PACE, "heavy overload almost stops")
	var copy := Inventory.new(3)
	copy.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	_check(copy.count("core:branch") == 8 and copy.count("core:log") == inv.count("core:log"), "the bag survives a save as JSON")
	copy.from_dict({"slots": [["core:nothing", 3], ["core:branch", 2]]})
	_check(copy.slots[0] == null and copy.count("core:branch") == 2, "unknown items are left out on load")
	var all := inv.take_all()
	_check(inv.is_empty() and all.size() == 3, "a death empties the bag into a sack")
	_check(Items.category("core:stone_axe") == "tools" and Items.category("core:workbench") == "stations"
		and Items.category("core:raspberry") == "food" and Items.category("core:grain") == "plants"
		and Items.category("core:stone") == "blocks" and Items.category("core:fiber") == "materials",
		"an item's kind follows from what it does")
	var mess := Inventory.new(8)
	mess.slots = [["core:fiber", 1], null, ["core:stone", 3], ["core:fiber", 2], null, ["core:stone_axe", 1, 5],
		["core:raspberry", 4], ["core:fiber", 4]]
	mess.sort("kind", 1)
	_check(mess.slots[0] == ["core:fiber", 1] and mess.slots[1] == ["core:stone_axe", 1, 5]
		and mess.slots[2] == ["core:fiber", 6] and mess.slots[3] == ["core:stone", 3]
		and mess.slots[4] == ["core:raspberry", 4] and mess.slots[5] == null and mess.slots[7] == null,
		"sorting by kind tops up stacks, keeps a worn tool apart and leaves the first slots alone")
	mess.sort("weight")
	_check(mess.slots[0] == ["core:stone", 3] and mess.slots[1] == ["core:stone_axe", 1, 5] and mess.count("core:fiber") == 7,
		"sorting by weight puts the heaviest stacks first")
	var box := Inventory.new(2)
	mess.slots = [["core:fiber", 7], ["core:stone", 3], null]
	mess.put_into(0, mess, 2)
	_check(mess.slots[0] == null and mess.slots[2] == ["core:fiber", 7], "a stack moves to an empty slot")
	mess.put_into(1, mess, 2)
	_check(mess.slots[1] == ["core:fiber", 7] and mess.slots[2] == ["core:stone", 3], "two stacks swap")
	box.slots = [["core:fiber", Items.stack_size("core:fiber") - 2], null]
	mess.put_into(1, box, 0)
	_check(box.count("core:fiber") == Items.stack_size("core:fiber") and mess.slots[1] == ["core:fiber", 5],
		"onto a stack of the same item, as much as it takes")
	# A chest taken up with things in it keeps them and weighs them.
	var chest := Inventory.new(4)
	chest.nests = false
	chest.add("core:stone", 5)
	var bag := Inventory.new(4)
	_check(bag.add("core:chest", 1, 0, chest.to_dict()) == 1 and bag.contents(0) != null, "a chest goes into the bag with what it holds")
	_check(is_equal_approx(bag.weight(), Items.weight("core:chest") + 5 * Items.weight("core:stone")), "and weighs it too")
	_check(bag.add("core:chest", 1) == 1 and bag.slots[1] != null and bag.slots[1].size() == 2, "an empty chest takes a slot of its own")
	_check(bag.remove("core:chest", 2) == 1 and bag.contents(0) != null, "a chest with things in it is not used up")
	_check(bag.move_slot(0, chest) == 0, "a chest with things in it does not go into a chest")
	var kept := Inventory.new(4)
	kept.from_dict(JSON.parse_string(JSON.stringify(bag.to_dict())))
	var inner := Inventory.new(4)
	inner.from_dict(kept.contents(0))
	_check(inner.count("core:stone") == 5, "the chest's things survive a save")
	_check(not bag.put_into(0, chest, 1) and bag.contents(0) != null and chest.slots[1] == null,
		"nor is it moved into a chest's slot")
	var put = bag.take_slot(0, 1)
	_check(put.size() == 4 and put[3] is Dictionary and bag.is_empty(), "a chest taken out of the bag brings its things")
	var spread := Inventory.new(4)
	spread.slots = [["core:fiber", 3], ["core:stone", 2], ["core:fiber", 4], null]
	var into := Inventory.new(4)
	_check(spread.move_all(into, 1) == 6 and spread.slots[0] == ["core:fiber", 3] and spread.slots[1] == null
		and into.count("core:fiber") == 4 and into.count("core:stone") == 2, "«all into the chest» leaves the first slots be")


func _test_vitals() -> void:
	var v := Vitals.new()
	v.satiety = 30.0
	v.step(0.0, 20.0 / Vitals.HUNGER_PER_DAY, false)
	_check(is_equal_approx(v.satiety, 10.0) and v.health == Vitals.MAX, "hunger empties satiety over game days")
	v.step(0.0, 0.5, false)
	_check(v.health < Vitals.MAX and v.hurt_by == "hunger", "only starving hurts")
	_check(v.stamina_cap() < Vitals.MAX, "hunger lowers stamina")
	_check(v.eat(40.0) and v.satiety == 40.0, "food fills satiety")
	v.satiety = Vitals.MAX
	_check(not v.eat(5.0), "a full character does not eat")
	var h := v.health
	v.step(0.0, 0.2, false)
	_check(v.health > h, "a well fed body heals")
	v.stamina = 2.0
	_check(not v.spend("chop") and v.stamina == 2.0, "a tired body cannot chop a tree")
	v.step(1.0, 0.0, false)
	_check(v.stamina > 2.0 and v.speed_factor() < 1.0 or v.stamina >= Vitals.TIRED, "stamina comes back at rest")
	v.stamina = 0.0
	h = v.health
	v.step(1.0, 0.0, true)
	_check(v.health < h and v.hurt_by == "water", "a swimmer out of breath loses health")
	v.health = 0.0
	_check(v.is_dead(), "no health is death")
	v.revive(0.5)
	_check(v.health == Vitals.MAX * 0.5 and v.stamina == Vitals.MAX, "a revived body starts afresh")
	var copy := Vitals.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	_check(copy.health == v.health and copy.satiety == v.satiety, "the body survives a save as JSON")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_felling() -> void:
	# Two oaks side by side on flat ground; the first is cut a cell above its foot.
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Trees.place(w, 15, 1, 23, Trees.OAK, rng)
	Trees.place(w, 31, 1, 23, Trees.OAK, rng)
	var leaves_of_second := 0
	for z in range(14, 33):
		for x in range(24, 41):
			leaves_of_second += _bits(w.leaf_col(x, z))
	var gone := Trees.fell(w, Vector3i(15, 2, 23), Vector2(0.0, 1.0))
	_check(not gone.is_empty() and gone[0] == Vector3i(15, 2, 23), "a cut trunk is felled from the cut")
	_check(w.log_col(15, 23) == 0b10, "the stump stays below the cut")
	var left := 0
	for z in range(10, 37):
		for x in range(6, 24):
			left += _bits(w.leaf_col(x, z))
	_check(left == 0, "the felled crown is gone")
	var second := 0
	for z in range(14, 33):
		for x in range(24, 41):
			second += _bits(w.leaf_col(x, z))
	_check(second == leaves_of_second, "the neighbouring crown stays")
	var kinds := {}
	for key in w.drops:
		for d: Array in w.drops[key]:
			kinds[d[0]] = true
			_check(d[1].z > 23 * WorldData.CELL, "the tree falls away from the axe")
	_check(kinds.has("core:log") and kinds.has("core:branch") and kinds.has("core:acorn"), "a felled oak leaves logs, branches and acorns")
	_check(Trees.fell(w, Vector3i(15, 0, 23), Vector2.ZERO).is_empty(), "only logs of noted trees are felled")


func _bits(v: int) -> int:
	var n := 0
	while v != 0:
		v &= v - 1
		n += 1
	return n


## A forest chunk the player changed (a tree felled, a hole dug, a block placed, a bush
## gone) is saved, and a new run of the same world brings it back as it was, whatever
## order the chunks around are made in; its trees grow again into the chunks around.
func _test_save() -> void:
	var a := WorldGen.new(42)
	var at := a.find_place("forest", Vector2i(a.spawn_guess.x, a.spawn_guess.z))
	var home := WorldData.chunk_key(at.x, at.y)
	var area: Array[Vector2i] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			area.append(home + Vector2i(dx, dz))
	for k in area:
		_ensure_stage(a, k, WorldGen.SHAPED)
	var w := a.world
	_check(w.unsaved.is_empty(), "the generator's writes are not changes to save")
	var trunks: Array = w.tree_chunks.get(home, {}).keys()
	_check(not trunks.is_empty(), "the forest chunk has trees")
	if trunks.is_empty():
		return
	var trunk: Vector2i = trunks[0]
	var foot := w.surface_y(trunk.x, trunk.y)
	for y in range(w.size_y - 1, 0, -1):
		if w.get_cell(trunk.x, y, trunk.y) == Mat.LOG and w.get_cell(trunk.x, y - 1, trunk.y) != Mat.LOG:
			foot = y
			break
	Trees.fell(w, Vector3i(trunk.x, foot + 1, trunk.y), Vector2(1.0, 0.0))
	var x0 := home.x * WorldData.CHUNK
	var z0 := home.y * WorldData.CHUNK
	var top := w.surface_y(x0 + 1, z0 + 1)
	for y in range(top - 3, top):
		w.set_cell(x0 + 1, y, z0 + 1, Mat.AIR)
	w.set_cell(x0 + 14, w.surface_y(x0 + 14, z0 + 8), z0 + 8, Mat.STONE)
	var bushes: Array = w.bush_chunks.get(home, {}).keys()
	if not bushes.is_empty():
		w.remove_bush(bushes[0])
	w.tree_twigs[trunk] = 2
	var lawn := Vector3i(x0 + 8, w.surface_y(x0 + 8, z0 + 3) - 1, z0 + 3)
	w.set_turf(lawn, "")
	# Grass cut off a natural slope leaves dirt of the same shape.
	var cut := Vector3i(-1, -1, -1)
	for z in range(z0, z0 + WorldData.CHUNK):
		for x in range(x0, x0 + WorldData.CHUNK):
			var y := w.surface_y(x, z) - 1
			if cut.y < 0 and w.get_cell(x, y, z) == Mat.GRASS and w.is_natural(x, y, z) and w.slope_mask(x, y, z) != WorldData.FULL:
				cut = Vector3i(x, y, z)
	if cut.y >= 0:
		var mask := w.slope_mask(cut.x, cut.y, cut.z)
		w.set_material(cut.x, cut.y, cut.z, Mat.DIRT)
		w.refresh_shapes()
		_check(w.get_cell(cut.x, cut.y, cut.z) == Mat.DIRT and w.slope_mask(cut.x, cut.y, cut.z) == mask, "cut grass keeps its slope")
	_check(w.unsaved.has(home) and not a.forget(home), "a changed chunk is kept and waits to be saved")
	var store := WorldStore.new("user://test_saves/save")
	store.erase()
	store = WorldStore.new("user://test_saves/save")
	for k: Vector2i in w.unsaved:
		_check(store.write_chunk(k, a.pack(k)), "chunk %s is written" % k)
	var written := w.unsaved.size()
	w.unsaved.clear()
	var again := WorldStore.new("user://test_saves/save")
	_check(again.chunk_count() == written, "the save lists its chunks")
	# A new run, the chunks made from the far corner: the changed chunk comes back
	# after some of its neighbours have their terrain.
	var b := WorldGen.new(42)
	b.saved = again
	for i in range(area.size() - 1, -1, -1):
		_ensure_stage(b, area[i], WorldGen.SHAPED)
	_check(_same_cells(b.world, w, area) and _same_view(b, b.world, w, area), "changed chunks come back from the save")
	_check(b.world.trees == w.trees and b.world.bushes == w.bushes and b.world.drops == w.drops and b.world.tree_twigs == w.tree_twigs
		and b.world.turf_at(lawn) == "", "with their trees, bushes, what was gathered and cut and what lies on the ground")
	_check(b.world.unsaved.is_empty() and b.world.chunks[home].edited, "and stay kept without a new save")
	# A neighbour dropped and made again regrows the crowns of the saved chunk's trees.
	var remade := 0
	for side in area:
		if not b.world.chunks[side].edited:
			b.forget(side)
			_ensure_stage(b, side, WorldGen.SHAPED)
			remade += 1
	_check(remade > 0 and _same_cells(b.world, w, area), "neighbours made again get the saved chunk's crowns")
	# The rest of the files.
	_check(store.write_json("world.json", {"seed": 42.0}) and store.exists() and store.read_json("world.json").seed == 42.0,
		"world.json is written and read")
	_check(WorldStore.world_dir(42, {"size": 2, "water": 0}) == WorldStore.root + "/42-20111", "a world's directory names its seed and settings")
	store.erase()
	_check(not DirAccess.dir_exists_absolute("user://test_saves/save"), "a save is erased")


## Footprints: stone takes them only under a roof (the dust of a cave floor).
func _test_tracks() -> void:
	var w := WorldData.new(8, Vector2i(4, 4))
	for z in 4:
		for x in 4:
			w.set_cell(x, 0, z, Mat.STONE)
	var t := Tracks.new()
	t.world = w
	t._ready()
	var feet := Vector3(0.75, WorldData.CELL, 0.75)
	t.leave(feet, Vector2(0, 1), true, true, 1.0)
	_check(t.next == 0, "no prints on stone in the open")
	w.set_cell(1, 3, 1, Mat.STONE)
	t.leave(feet, Vector2(0, 1), true, true, 1.0)
	_check(t.next == 1, "prints on the stone floor of a cave")
	t.free()


## The cut finds earth that hides the player from the camera: the near wall of a
## ravine running diagonally across the view, not a wall the head looks over.
func _test_hidden() -> void:
	var cs := ChunkStreamer.new(null)
	cs.world = WorldData.new(12, Vector2i(32, 32))
	# Ground up to level 7 except a ravine one cell wide along x == z, floor level 1.
	for z in 32:
		for x in 32:
			for y in (1 if x == z else 7):
				cs.world.set_cell(x, y, z, Mat.STONE)
	_check(cs._hiding_level(16, 1, 16) == 3, "the near wall of a diagonal ravine hides the player")
	# Two levels deep: the head shows over the wall.
	cs.world = WorldData.new(12, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			for y in (1 if x == z else 3):
				cs.world.set_cell(x, y, z, Mat.STONE)
	_check(cs._hiding_level(16, 1, 16) == -1, "a wall the head looks over does not cut the view")
