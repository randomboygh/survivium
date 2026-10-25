extends "res://tests/unit/test_case.gd"
## The body on the cells: raycast, walking, water and bogs, slopes, steps, the test ground, pits.


func run() -> void:
	_test_raycast()
	_test_walking_rules()
	_test_water()
	_test_bog()
	_test_slopes()
	_test_steps()
	_test_ground()


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
	player.body.world = w
	player.position = Vector3(3.5, 4.0, 2.5) * WorldData.CELL
	player.body.on_ground = true
	player.step(1.0 / 60.0, false)
	_check(player.body.on_ground and not player.body.swimming and is_equal_approx(player.body.water_depth, 0.5),
		"water one cell deep is waded on the bottom")
	player.body.move_input = Vector2(1, 0)
	var swam := false
	for i in 40:
		player.step(1.0 / 60.0, false)
		var p: Vector3 = player.position / WorldData.CELL
		swam = swam or player.body.swimming and absf(p.y - (4.5 - Body.SWIM_DEPTH)) < 0.05 and p.x > 4.5
	_check(swam, "deeper water is swum with the head above the surface")
	for i in 240:
		player.step(1.0 / 60.0, false)
	var out: Vector3 = player.position / WorldData.CELL
	_check(out.x > 9.0 and is_equal_approx(out.y, 6.0) and player.body.on_ground,
		"a swimmer pulls out onto a bank one level above the water")
	player.body.move_input = Vector2(-1, 0)
	for i in 360:
		player.step(1.0 / 60.0, false)
	_check(player.position.x / WorldData.CELL > 2.4, "a bank two levels above the water cannot be climbed")
	_check(player.body.swimming or player.body.water_depth > 0.0, "the swimmer stays in the water below a high bank")
	w.water_frozen = true
	player.step(1.0 / 60.0, false)
	player.step(1.0 / 60.0, false)
	_check(is_equal_approx(player.position.y / WorldData.CELL, 5.0) and player.body.on_ground,
		"a swimmer caught by the frost stands on the ice")
	player.body.move_input = Vector2(1, 0)
	for i in 120:
		player.step(1.0 / 60.0, false)
	_check(is_equal_approx(player.position.y / WorldData.CELL, 5.0) and player.position.x / WorldData.CELL > 7.0,
		"ice is walked on")
	player.free()


## The pool of _pool_world made a cell deep and a bog: the body walks in and wades it
## like shallow water, only slower, and steps out onto the bank.
func _test_bog() -> void:
	var w := _pool_world()
	for z in 16:
		for x in range(3, 9):
			w.set_cell(x, 3, z, Mat.STONE)
			var c: WorldData.Chunk = w.chunk_at(x, z)
			c.natural[(4 << 8) | ((z & WorldData.MASK) << WorldData.SHIFT) | (x & WorldData.MASK)] |= WorldData.BOG
	_check(w.murk(5, 4, 5) == 2 and w.is_bog(5, 4, 5) and w.murk(5, 5, 5) == 0, "bog water is the murkiest")
	var player = PlayerScript.new()
	player.body.world = w
	player.position = Vector3(6.5, 5.0, 2.5) * WorldData.CELL
	for i in 60:
		player.step(1.0 / 60.0, false)
	var p: Vector3 = player.position / WorldData.CELL
	_check(player.body.in_bog and player.body.on_ground and not player.body.swimming
		and is_equal_approx(p.y, 4.0), "a body wades a bog on its bottom, as shallow water")
	var bog_pace: float = player.body.speed_at(player.position)
	_check(bog_pace < Body.SPEED * Body.WADE and bog_pace > Body.SPEED * Body.SWIM * 0.9,
		"a bog is waded a little slower than water")
	player.body.move_input = Vector2(1, 0)
	for i in 300:
		player.step(1.0 / 60.0, false)
	var out: Vector3 = player.position / WorldData.CELL
	_check(out.x > 9.0 and is_equal_approx(out.y, 6.0) and not player.body.in_bog, "a body climbs out of a bog onto the bank")
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
	w.set_cell(4, 2, 3, Mat.index("materials:planks"))
	_check(w.slope_mask(4, 1, 3) == WorldData.FULL, "ground under a block does not slope")
	var meshes: Array = ChunkMesher.build_chunk(w, 0, 0, 16)
	var normals: PackedVector3Array = (meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var tilted := false
	for n in normals:
		tilted = tilted or (n.y > 0.6 and n.y < 0.8 and n.x < -0.6)
	_check(tilted, "ramps are drawn tilted toward the low side")
	# Walk east up the ramp without jumping, and stop at the cliff.
	var player = PlayerScript.new()
	player.body.world = w
	player.position = Vector3(2.5, 1.0, 5.5) * WorldData.CELL
	player.body.on_ground = true
	player.body.move_input = Vector2(1, 0)
	var climbed := true
	for i in 60:
		player.step(1.0 / 60.0, false)
		var p: Vector3 = player.position / WorldData.CELL
		if p.x > 4.2 and p.x < 4.6:
			climbed = climbed and p.y > 1.3 and p.y < 1.995
	_check(climbed and is_equal_approx(player.position.y / WorldData.CELL, 2.0), "walking up a ramp needs no jump")
	_check(player.position.x / WorldData.CELL < 5.6, "a two-cell cliff stops the walker")
	player.body.move_input = Vector2(-1, 0)
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
	player.body.world = w
	player.position = Vector3(2.5, 1.0, 5.5) * WorldData.CELL
	player.body.on_ground = true
	player.body.move_input = Vector2(1, 0)
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
	# Models are PNG slices in the item's mod and come back the same from their image.
	var drawn := VoxelProps.drop(Items.get_item("resources:branch"))
	var again = VoxelModel.from_image(drawn.to_image(true), true)
	_check(drawn != null and drawn.voxels.size() > 20 and again.voxels.keys() == drawn.voxels.keys() and again.foliage == drawn.foliage
		and not drawn.foliage.is_empty() and VoxelProps.drop({"model": "nothing", "mod": "core"}) == null,
		"a model read from its mod's PNG survives a round trip through the image, leaves and all")
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
	player.body.world = w
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
	player.body.world = w
	player.position = Vector3(3.0, 1.0, z) * WorldData.CELL
	player.body.on_ground = true
	player.body.move_input = Vector2(1, 0)
	for i in 24:
		player.step(1.0 / 60.0, jump and i == 0)
	player.body.move_input = Vector2.ZERO
	for i in 60:
		player.step(1.0 / 60.0, false)
	var p: Vector3 = player.position / WorldData.CELL
	player.free()
	return p


## The test world: its grounds are where the plan says, made the same in any order.
func _test_ground() -> void:
	var gen := TestGround.new()
	gen.generate_area(Vector2i(-4, -4), Vector2i(4, 3))
	var w: WorldData = gen.world
	var g: int = gen.ground
	_check(gen.spawn_guess == Vector3i(0, g + 1, 0) and w.get_cell(0, g, 0) == Mat.GRASS
		and w.get_cell(0, g + 1, 0) == Mat.AIR, "the test world starts on the meadow")
	_check(w.surface_y(3, -39) == g - 11 and w.get_cell(-5, g - 4, -39) == Mat.DIRT,
		"the test world has a pit 4 deep and a shaft 12 deep")
	_check(w.get_cell(27, g + 1, -30) == Mat.AIR and w.get_cell(27, g + 3, -30) == Mat.STONE
		and w.get_cell(27, g, -30) == Mat.DIRT and w.get_cell(27, g + 4, -38) == Mat.AIR,
		"the hill of the test world has a tunnel into a hall")
	_check(w.get_cell(-40, g, 20) == Mat.WATER and w.get_cell(-40, g - 1, 20) == Mat.BEACH
		and w.get_cell(-15, g - 4, 20) == Mat.WATER, "the pond goes from wading to swimming")
	_check(w.is_bog(18, g, 33) and w.get_cell(18, g - 1, 33) == Mat.BANK and w.murk(18, g, 28) == 1
		and w.get_cell(16, g, 16) == Mat.WATER and w.murk(16, g, 16) == 1,
		"the swamp strip has pools and a pond running into a bog, all at one level")
	_check(w.get_cell(21, g - 3, 0) == Mat.DIRT and w.get_cell(37, g - 3, 0) == Mat.ORE,
		"the material strips are 4 cells deep")
	_check(w.get_cell(50, g + 2, 0) == Mat.index("materials:planks") and w.get_cell(53, g + 1, 3) == Mat.AIR
		and w.get_cell(54, g + 4, 0) == Mat.STONE, "the hut has walls, a door and a roof")
	_check(w.trees.size() == gen.plan_trees().filter(func(t: Array) -> bool: return t[0] < 64 and t[1] < 48).size(),
		"every tree of the plan grows")
	# The bush garden lies east, beyond the area above.
	gen.generate_area(Vector2i(3, -1), Vector2i(8, 2))
	_check(w.bushes.size() == gen.plan_bushes().size(), "every bush of the plan grows")
	# The stream falls from terrace to terrace into its pool (it lies east of the grove);
	# the field and the grove grow what the plan sets, whatever the noises say.
	gen.generate_area(Vector2i(8, 1), Vector2i(11, 2))
	_check(w.get_cell(145, g + 10, 24) == Mat.WATER and w.get_cell(146, g + 10, 24) == Mat.AIR
		and w.get_cell(146, g + 6, 24) == Mat.WATER and w.get_cell(137, g + 10, 24) == Mat.STONE
		and w.get_cell(174, g, 24) == Mat.WATER, "the stream of the test world comes down in falls")
	_check(Grass.plants_on(w, 110, g, 0).has(Plants.EARS) and Grass.plants_on(w, 105, g, 25).has(Plants.MOSS),
		"the test world has its field of ears and the moss of its grove")
	var grove := {}
	for z in range(14, 38):
		for x in range(100, 132):
			for id in Grass.plants_on(w, x, g, z):
				grove[id] = true
	_check(grove.has(Plants.MUSHROOMS) and grove.has(Plants.GLOW), "the grove has mushrooms and glowing ones")
	gen.generate_area(Vector2i(-5, 3), Vector2i(1, 6))
	gen.generate_area(Vector2i(6, 2), Vector2i(8, 5))
	# The camp: everything of the plan lies on the ground with its chunks, sacks too.
	gen.generate_area(Vector2i(3, -2), Vector2i(6, -1))
	var lying := 0
	var sacks := 0
	for key: Vector2i in w.drops:
		for d: Array in w.drops[key]:
			if gen.CAMP.has_point(Vector2i(floori(d[1].x / WorldData.CELL), floori(d[1].z / WorldData.CELL))):
				lying += 1
				sacks += 1 if d[0] == Items.SACK else 0
	_check(lying == gen.plan_drops().size() and sacks >= 10 and gen.plan_things().size() >= 15,
		"the camp of the test world has its things on the ground (%d), sacks (%d) and placed things" % [lying, sacks])
	_check(w.surface_y(TestGround.PEAK.x, TestGround.PEAK.y) == g + TestGround.PEAK_RISE + 1
		and w.peak_snow(g + TestGround.PEAK_RISE + 1) == 1.0, "the mountain of the test world rises into the snow")
	# The relief ground: the lone cell of grass rises a cell, the ring's hollow does not,
	# the cliff steps one cell then two; the row of stone is stone.
	var rx: int = TestGround.RELIEF_X
	var rz: int = TestGround.RELIEF_Z
	var plot: int = TestGround.RELIEF_STRIDE
	_check(w.get_cell(rx + 4, g + 1, rz + 4) == Mat.GRASS and w.get_cell(rx + 3, g + 1, rz + 4) == Mat.AIR
		and w.get_cell(rx + 3 * plot + 4, g + 1, rz + 4) == Mat.AIR and w.get_cell(rx + 3 * plot + 2, g + 1, rz + 2) == Mat.GRASS
		and w.get_cell(rx + 7 * plot + 4, g + 1, rz + 4) == Mat.GRASS and w.get_cell(rx + 7 * plot + 7, g + 2, rz + 4) == Mat.GRASS
		and w.get_cell(rx + 4, g + 1, rz + 3 * plot + 4) == Mat.STONE, "the relief ground has its shapes")
	_check(w.slope_mask(rx + plot + 4, g + 1, rz + 3) != WorldData.FULL, "the grass square of the relief ground slopes down at its edge")
	var other := TestGround.new()
	var keys: Array[Vector2i] = []
	for cz in range(-4, 3):
		for cx in range(-4, 4):
			keys.append(Vector2i(cx, cz))
	for i in range(keys.size() - 1, -1, -1):
		_ensure_stage(other, keys[i], WorldGen.SHAPED)
	var near := {}
	for t: Vector2i in w.trees:
		if t.x < 64 and t.y < 48:
			near[t] = w.trees[t]
	_check(_same(other.world, w, keys) and other.world.trees == near,
		"the test world is the same made in another order")
	_check(WorldStore.world_dir(TestGround.SEED, {}).ends_with("/test"), "the test world is saved apart")


## Presses jump again and again for 5 s at the bottom of a pit four cells deep and one
## cell wide, walking east; returns the highest the feet got, in cells.
func _climb_pit(air_jumps: bool) -> float:
	var w := WorldData.new(10, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			for y in (1 if x == 5 and z == 5 else 5):
				w.set_cell(x, y, z, Mat.STONE)
	var player = PlayerScript.new()
	player.body.world = w
	player.body.air_jumps = air_jumps
	player.position = Vector3(5.5, 1.0, 5.5) * WorldData.CELL
	player.body.on_ground = true
	player.body.move_input = Vector2(1, 0)
	var top := 0.0
	for i in 300:
		player.step(1.0 / 60.0, i % 20 < 3)
		top = maxf(top, player.position.y / WorldData.CELL)
	player.free()
	return top
