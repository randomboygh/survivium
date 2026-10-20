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
const Trees := preload("res://src/shared/trees.gd")
const Foliage := preload("res://src/client/foliage.gd")
const Bushes := preload("res://src/shared/bushes.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const PlayerArt := preload("res://src/client/player_art.gd")
const Yaml := preload("res://src/shared/yaml.gd")
const Content := preload("res://src/shared/content.gd")

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
	_test_sprite_sheet()
	_test_yaml()
	_test_content()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _test_generation() -> void:
	var a := WorldGen.generate(42, 64, 40, 64)
	var b := WorldGen.generate(42, 64, 40, 64)
	var c := WorldGen.generate(43, 64, 40, 64)
	_check(a.cells == b.cells, "same seed gives the same world")
	_check(a.cells != c.cells, "different seeds give different worlds")
	var counts := {}
	for m in a.cells:
		counts[m] = counts.get(m, 0) + 1
	for m in [Mat.GRASS, Mat.STONE, Mat.WATER, Mat.DIRT]:
		_check(counts.get(m, 0) > 0, "world contains %s" % Mat.NAMES[m])
	var spawn := WorldGen.find_spawn(a, Vector3i(32, 0, 32))
	_check(spawn.y > a.sea_level, "spawn is above the sea")
	_check(a.get_cell(spawn.x, spawn.y, spawn.z) == Mat.AIR, "spawn cell is free")
	# The world does not depend on the order its chunks are made in: generated
	# chunk by chunk around a point, stage by stage, it is the same as generated whole.
	var gen := WorldGen.new(42, 64, 40, 64)
	for cz in range(gen.chunks_z() - 1, -1, -1):
		for cx in range(gen.chunks_x() - 1, -1, -1):
			_ensure_stage(gen, Vector2i(cx, cz), WorldGen.SHAPED)
	_check(gen.world.cells == a.cells, "chunks made in another order give the same cells")
	_check(gen.world.trees == a.trees and gen.world.bushes == a.bushes, "and the same trees and bushes")
	_check(gen.world.shapes == a.shapes, "and the same shapes")
	# Water above the sea never leaks: nothing open under it, and the only air beside
	# it is a river's step down.
	var leaks := 0
	var layer := a.size_x * a.size_z
	for col in layer:
		var water: int = a.water_cols[col]
		var x := col % a.size_x
		var z := col / a.size_x
		while water != 0:
			var bit := water & -water
			water ^= bit
			var y := WorldData.level_of(bit)
			if y <= a.sea_level:
				continue
			if a.get_cell(x, y - 1, z) == Mat.AIR:
				leaks += 1
			for d: Vector2i in WorldData.SIDES:
				if a.get_cell(x + d.x, y, z + d.y) == Mat.AIR and a.water_cols[(z + d.y) * a.size_x + x + d.x] & (bit - 1) == 0:
					leaks += 1
	_check(leaks == 0, "water above the sea does not leak (%d leaks)" % leaks)


## Brings a chunk to `stage` the way the game does: its own earlier stages first,
## then the chunks around it to the stage before.
func _ensure_stage(gen, key: Vector2i, stage: int) -> void:
	if gen.stage_of(key) >= stage:
		return
	_ensure_stage(gen, key, stage - 1)
	if stage > WorldGen.TERRAIN:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var k: Vector2i = key + Vector2i(dx, dz)
				if gen.in_map(k):
					_ensure_stage(gen, k, stage - 1)
	gen.run(key, stage)


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
	_check(verts[0].distance_to(verts[2]) < 0.75, "meshes are in world units, half a unit per cell")
	# A flat floor: its tops away from the edges are merged into rows.
	var f := WorldData.new(8, 4, 8)
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
	var pond := WorldData.new(8, 3, 8)
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
	var w := WorldData.new(4, 4, 4)
	w.set_cell(1, 0, 1, Mat.STONE)
	w.set_cell(1, 1, 1, Mat.STONE)
	w.set_cell(2, 0, 1, Mat.STONE)
	var cap := ChunkMesher.build_cap(w, 0)
	_check(cap != null and cap.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 4,
		"cap closes only cells covered from above")
	# The cap built chunk by chunk has the same tops as the one built at once.
	w = WorldData.new(8, 4, 8)
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
	_check(not w.blocks_body(1, 0, 1), "open water can be entered")
	_check(not w.blocks_body(1, 1, 1), "no invisible floor over the water")
	_check(w.surface_y(1, 1) == -1, "open water has no surface to stand on")
	w.water_frozen = true
	_check(w.blocks_body(1, 0, 1), "ice cannot be entered")
	_check(w.surface_y(1, 1) == 1, "ice is a surface")
	_check(w.blocks_body(-1, 1, 1), "map edge blocks")


## A pool along x on a stone floor: water in levels 3..4 (open surface at 4.5) over
## x 3..8, shallow (level 4 only) at x = 3; a bank one level above the water (top 6)
## at x >= 9 and one two levels above it (top 7) at x <= 2.
func _pool_world() -> WorldData:
	var w := WorldData.new(12, 10, 6)
	for z in 6:
		for x in 12:
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
	var w := WorldData.new(10, 6, 10)
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
			climbed = climbed and p.y > 1.3 and p.y < 1.95
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
	var w := WorldData.new(10, 6, 10)
	for z in 10:
		for x in 10:
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


## Wild stone floor with a two-level wild stone block at x, z 3..6 missing its
## north-east quarter (x 5..6, z 3..4), so it has outer corners and one inner corner.
func _corner_world() -> WorldData:
	var w := WorldData.new(10, 6, 10)
	w.natural.fill(WorldData.WILD)
	for z in 10:
		for x in 10:
			w.cells[x] = Mat.STONE
			w.cells[z * 10 + x] = Mat.STONE
			if x >= 3 and x <= 6 and z >= 3 and z <= 6 and not (x >= 5 and z <= 4):
				for y in range(1, 3):
					w.cells[(y * 10 + z) * 10 + x] = Mat.STONE
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
	_check(player._collides(Vector3(5.6, 1.0, 4.3)) and not player._collides(Vector3(5.9, 1.0, 4.0)),
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
	var g := WorldGen.generate(7, 64, 40, 64)
	_check(_shapes_match(g), "shapes of a generated world follow the rules")
	var slopes := 0
	var cuts := 0
	var fills := 0
	for col in g.size_x * g.size_z:
		slopes += int(g.sloped_cols[col] != 0)
	for i in g.shapes.size():
		cuts += int(g.shapes[i] >= 16 and Mat.is_solid(g.cells[i]))
		fills += int(g.shapes[i] >= 16 and not Mat.is_solid(g.cells[i]))
	_check(slopes > 0 and cuts > 0 and fills > 0, "generated ground has slopes and cut and filled corners")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 300:
		var x := rng.randi_range(0, g.size_x - 1)
		var z := rng.randi_range(0, g.size_z - 1)
		var y := clampi(g.surface_y(x, z) + rng.randi_range(-2, 1), 0, g.size_y - 1)
		g.set_cell(x, y, z, [Mat.AIR, Mat.DIRT, Mat.STONE][i % 3])
	_check(_shapes_match(g), "shapes follow the rules after digging and building")


func _shapes_match(w: WorldData) -> bool:
	for y in w.size_y:
		for z in w.size_z:
			for x in w.size_x:
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


func _ref_slope(w: WorldData, x: int, y: int, z: int) -> int:
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
	return w.in_bounds(x, y, z) and w.natural[(y * w.size_z + z) * w.size_x + x] == WorldData.WILD \
		and Mat.can_slope(w.get_cell(x, y, z)) and w.get_cell(x, y + 1, z) == Mat.AIR


func _ref_low(w: WorldData, x: int, y: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= w.size_x or z >= w.size_z:
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
	var mask := _ref_slope(w, x, y, z)
	return mask == WorldData.FULL or mask & (1 << k) == 0


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
		and w.is_natural(x + o.x, y, z + o.y) and _ref_slope(w, x + o.x, y, z) == WorldData.FULL \
		and _ref_slope(w, x, y, z + o.y) == WorldData.FULL


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
				var w := WorldData.new(32, 40, 32)
				Trees.place(w, 15, 1, 15, species, rng, scale)
				var top := 0
				for col in 32 * 32:
					for y in 40:
						if (w.leaf_cols[col] | w.log_cols[col]) & (1 << y):
							top = maxi(top, y)
				fits = fits and top <= Trees.height(species, scale)
	_check(fits, "trees stay within Trees.height")
	var w := _north_strip()
	var kinds := {}
	for at in w.trees:
		kinds[w.trees[at]] = true
		_check(w.log_cols[at.y * w.size_x + at.x] != 0, "a noted tree has a trunk")
	_check(kinds.size() == Trees.SPECIES.size(), "the generator grows every species")
	# Crowns of spruces take needle cards, of oaks leaf cards.
	var chunk: Dictionary = Foliage.build_chunk(w, STRIP_X0 * 16, STRIP_Z * 16, STRIP_CHUNKS * 16)
	var buf: PackedFloat32Array = chunk.clumps[1]
	var rows := {}
	for i in chunk.clumps[0]:
		var row := int(buf[i * 20 + 19]) % Foliage.DEEP_ROW
		rows[row >= 3] = true
	_check(rows.size() == 2, "crowns have both broad leaves and needles")



## A strip of chunks across the taiga of the north of the island, where both species
## of tree and every type of bush grow: the world the tree and bush tests look at.
const STRIP_X0 := 26
const STRIP_Z := 8
const STRIP_CHUNKS := 12


func _north_strip() -> WorldData:
	var gen := WorldGen.new(42)
	for x in range(STRIP_X0, STRIP_X0 + STRIP_CHUNKS):
		_ensure_stage(gen, Vector2i(x, STRIP_Z), WorldGen.SHAPED)
	return gen.world


func _test_bushes() -> void:
	var w := _north_strip()
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


func _test_sprite_sheet() -> void:
	_check(SpriteSheet.direction_of(Vector2(0, 1)) == "s", "pushing south faces south")
	_check(SpriteSheet.direction_of(Vector2(1, 0)) == "e", "pushing east faces east")
	_check(SpriteSheet.direction_of(Vector2(-1, -1)) == "nw", "pushing north-west faces north-west")
	_check(SpriteSheet.direction_of(Vector2(0.3, -1)) == "n", "a push mostly north faces north")
	var s := PlayerArt.sheet(["body", "hair", "shirt", "trousers", "boots", "axe"])
	_check(s.columns == 5, "player sheet has five columns")
	_check(s.texture.get_width() == 5 * 14 and s.texture.get_height() == 5 * 18, "player sheet is five by five frames")
	var img := s.texture.get_image()
	var drawn := 0
	for y in 18:
		for x in 14:
			if img.get_pixel(x, y).a > 0.5:
				drawn += 1
	_check(drawn > 80 and drawn < 14 * 18, "the standing frame is drawn with room around it")
	_check(img.get_pixel(5, 17).a > 0.5, "the feet stand on the bottom row of the frame")
	var uv := s.frame_uv("s", "idle", 0.0)
	_check(uv == Vector4(0.0, 0.0, 0.2, 0.2), "the first frame is the top-left fifth")
	var w := s.frame_uv("w", "walk", 0.0)
	_check(w.z < 0.0 and is_equal_approx(w.y, 0.4), "west is east mirrored")
	_check(s.frame_uv("s", "walk", 0.25) != s.frame_uv("s", "walk", 0.0), "walking changes frames in time")
	var bare := PlayerArt.sheet(["body"])
	_check(bare.texture.get_image().get_pixel(5, 17).a < 0.5, "without boots the bottom row is empty")
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
	Content.MODS.append("_test")
	Content.refresh()
	var found := {}
	for p in Content.problems:
		for what in ["Bad Id", "glass.solid", "glass.weight", "duplicate id", "bear.mass", "bear.diet",
				"bear.human_wariness", "bear.active", "pine.trunk", "pine.tints"]:
			if what in p:
				found[what] = true
	_check(found.size() == 10, "the loader reports every kind of mistake (%d of 10): %s" % [found.size(), Content.problems])
	_check(Content.find("materials", "_test:glass").title == "Стекло", "a duplicate id within a mod is skipped")
	Content.MODS.assign(before)
	for f in ["data/materials.yaml", "data/creatures.yaml", "data/trees.yaml", "mod.yaml"]:
		DirAccess.remove_absolute(mod + "/" + f)
	DirAccess.remove_absolute(mod + "/data")
	DirAccess.remove_absolute(mod)
	Content.refresh()
	_check(Content.problems.is_empty(), "core content loads clean again")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
