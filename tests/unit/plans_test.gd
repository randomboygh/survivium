extends "res://tests/unit/test_case.gd"
## The blueprint (Plans): its shapes, drawing and taking off the ghost, building it cell by
## cell from the bag with the action button, and its save.

const Plans := preload("res://src/shared/game/plans.gd")
const PLANKS := "materials:planks"


func run() -> void:
	_test_shapes()
	_test_build()
	_test_forms()
	_test_flatten()


func _test_shapes() -> void:
	var wall := Plans.shape("line", Vector3i(2, 1, 3), Vector3i(6, 1, 4), 2)
	_check(wall.size() == 10 and wall.has(Vector3i(6, 2, 3)) and not wall.has(Vector3i(6, 1, 4)),
		"a wall goes along the way the stroke went farthest, two levels high: %s" % [wall])
	_check(Plans.shape("line", Vector3i(0, 1, 0), Vector3i(0, 1, 0), 9).size() == Plans.MAX_HEIGHT,
		"a wall is at most MAX_HEIGHT levels high")
	var thick := Plans.shape("line", Vector3i(2, 1, 3), Vector3i(6, 1, 3), 1, Vector2(4.5, 9.0) * WorldData.CELL, 2)
	_check(thick.size() == 10 and thick.has(Vector3i(4, 1, 2)) and not thick.has(Vector3i(4, 1, 4)),
		"a wall two cells thick grows away from the one drawing it")
	var floor := Plans.shape("plane", Vector3i(5, 1, 5), Vector3i(3, 1, 6), 1, Vector2.INF, 3)
	_check(floor.size() == 6 and floor.has(Vector3i(3, 1, 6)), "a plane one high is the rectangle, one level, whatever the thickness")
	var deep := Plans.shape("plane", Vector3i(5, 2, 5), Vector3i(3, 2, 6), 2)
	_check(deep.size() == 12 and deep.has(Vector3i(3, 3, 6)) and not deep.has(Vector3i(3, 1, 6)),
		"a higher plane goes up from the level it is laid on (2026-11-07: on the ground, as walls)")
	var square := Plans.shape("square", Vector3i(0, 1, 0), Vector3i(4, 1, 4), 3)
	_check(square.size() == 16 * 3 and square.has(Vector3i(2, 1, 4)) and not square.has(Vector3i(2, 1, 2)),
		"a square is walls round the rectangle, no gap: %d" % square.size())
	_check(Plans.shape("square", Vector3i(0, 1, 0), Vector3i(4, 1, 4), 1, Vector2.INF, 2).size() == 24,
		"walls two cells thick grow inward")
	var cube := Plans.shape("cube", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 4)
	_check(cube.size() == 16 + 16 + 12 * 2 and cube.has(Vector3i(1, 1, 1)) and cube.has(Vector3i(1, 4, 1))
		and cube.has(Vector3i(0, 3, 2)) and not cube.has(Vector3i(1, 2, 1)) and not cube.has(Vector3i(1, 5, 1)),
		"a cube four high is a floor, two levels of walls on it and a ceiling over them: %d" % cube.size())
	_check(Plans.shape("cube", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 1).size() == 16 + 16 + 12,
		"a cube is at least a floor, one level of walls and a ceiling")
	_check(Plans.erase_box("line", Vector3i(0, 1, 0), Vector3i(3, 1, 0), 2, Vector2(1.0, 9.0) * WorldData.CELL, 2).size() == 16,
		"the ghost is taken off the box round the shape")
	_check(Plans.shape("roof", Vector3i.ZERO, Vector3i.ONE, 1).is_empty(), "a shape of no known kind has no cells")


func _test_build() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 10.5) * WorldData.CELL
	_check(plans.draw(actions, who, "line", Vector3i(12, 2, 8), Vector3i(12, 2, 12), 2) == 0 and plans.cells.is_empty(),
		"no ghost is drawn without a block in hand")
	who.item = PLANKS
	_check(plans.draw(actions, who, "line", Vector3i(12, 2, 8), Vector3i(12, 2, 12), 2) == 10 and plans.cells.get(Vector3i(12, 3, 8)) == PLANKS,
		"a wall's ghost is drawn with the block in hand")
	_check(plans.draw(actions, who, "plane", Vector3i(8, 1, 9), Vector3i(9, 1, 10), 1) == 4,
		"a floor's ghost goes on the ground")
	_check(actions.front_kind(who) == "build", "the action button builds with a block in hand by the ghost")
	var swing := actions.act_in_front(who, 40)
	_check(swing.is_empty() or not swing.has("placed"), "with no planks in the bag nothing is built")
	_check(who.said.any(func(s: String) -> bool: return s.contains("Not in the bag")), "and the player is told so")
	who.inventory.add(PLANKS, 20)
	var built: Array[Vector3i] = []
	for i in 14:
		var before: Dictionary = plans.cells.duplicate()
		# The level cut under the wall's top (inside a house: under its ceiling) does not
		# keep it from being built.
		swing = actions.act_in_front(who, 2)
		if not swing.has("placed"):
			break
		for c: Vector3i in before:
			if not plans.cells.has(c):
				built.append(c)
	_check(built.size() == 14 and plans.cells.is_empty() and who.inventory.count(PLANKS) == 6,
		"the ghost is built cell by cell, a plank each: %d" % built.size())
	_check(built[0].y == 1 and w.get_cell(8, 1, 9) == Mat.index("materials:planks") and who.inventory.count(Mat.RECORDS[Mat.DIRT].item) == 4,
		"the floor first, flush with the ground, the dirt it takes the place of into the bag")
	var lowest := true
	for i in range(1, built.size()):
		lowest = lowest and built[i].y >= built[i - 1].y
	_check(lowest and w.get_cell(12, 3, 12) == Mat.index("materials:planks"), "lower cells before higher, the wall stands")
	# Erasing, a stroke takes the ghost off.
	plans.draw(actions, who, "line", Vector3i(20, 2, 8), Vector3i(24, 2, 8), 1)
	_check(plans.draw(actions, who, "line", Vector3i(22, 2, 8), Vector3i(24, 2, 8), 1, 1, true) == 3 and plans.cells.size() == 2,
		"an erasing stroke takes the ghost off")
	var copy := Plans.new()
	copy.from_list(plans.to_list())
	_check(copy.cells == plans.cells, "the ghost is saved and read back")
	_check(plans.draw(actions, who, "plane", Vector3i(0, 1, 0), Vector3i(40, 1, 40), 1) == 0, "a shape too big is not drawn")
	_check(plans.clear(actions, who) == 2 and plans.cells.is_empty(), "the ghost near is cleared at once")
	# Uneven ground: a floor is not drawn under a bump, a wall over a dip is told.
	w.set_cell(30, 2, 12, Mat.DIRT)
	var block := Mat.index("materials:planks")
	var sorted: Dictionary = plans.sort(actions, who, "plane", Vector3i(29, 1, 12),
		Plans.shape("plane", Vector3i(29, 1, 12), Vector3i(31, 1, 12), 1), block)
	_check(sorted.fit.size() == 2 and sorted.blocked == [Vector3i(30, 1, 12)], "a floor's cell under a bump is blocked: %s" % [sorted])
	sorted = plans.sort(actions, who, "line", Vector3i(29, 2, 12), Plans.shape("line", Vector3i(29, 2, 12), Vector3i(31, 2, 12), 2), block)
	_check(sorted.blocked == [Vector3i(30, 2, 12)] and sorted.hanging.is_empty(), "a wall's cell inside the bump is blocked")
	sorted = plans.sort(actions, who, "line", Vector3i(29, 3, 14), Plans.shape("line", Vector3i(29, 3, 14), Vector3i(31, 3, 14), 1), block)
	_check(sorted.hanging.size() == 3, "a wall over open air hangs")
	_check(plans.draw(actions, who, "plane", Vector3i(29, 1, 12), Vector3i(31, 1, 12), 1) == 2 and not plans.cells.has(Vector3i(30, 1, 12)),
		"and the blocked cells are not drawn")


## Slopes and stairs (WorldData.forms): drawn as a form of the ghost, built so, saved
## with the chunk, walked up, and a cube again once the cell changes.
func _test_forms() -> void:
	var w := WorldData.new(40, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 10.5) * WorldData.CELL
	who.item = PLANKS
	who.inventory.add(PLANKS, 10)
	var ramp := WorldData.FORM_RAMP | 1 << 2
	_check(plans.draw(actions, who, "line", Vector3i(12, 2, 9), Vector3i(12, 2, 10), 1, 1, false, ramp) == 2
		and plans.forms.get(Vector3i(12, 2, 9)) == ramp, "a ramp's ghost keeps its form")
	var copy := Plans.new()
	copy.from_list(plans.to_list())
	_check(copy.forms == plans.forms, "and the form is saved with the ghost")
	for i in 2:
		actions.act_in_front(who, 2)
	_check(plans.cells.is_empty() and plans.forms.is_empty() and w.form_at(12, 2, 9) == ramp and w.form_at(12, 2, 10) == ramp,
		"the ramps are built so")
	_check(is_equal_approx(w.ground_height(12.0, 9.5), 2.0) and is_equal_approx(w.ground_height(12.75, 9.5), 2.75),
		"the ground rises along the ramp to the side it faces: %s, %s" % [w.ground_height(12.0, 9.5), w.ground_height(12.75, 9.5)])
	_check(is_equal_approx(WorldData.form_top(WorldData.FORM_STAIRS, 0.0, 1.0, 0.6, 1.0), 0.5)
		and is_equal_approx(WorldData.form_top(WorldData.FORM_STAIRS, 0.0, 1.0, 0.0, 0.4), 1.0),
		"stairs are two steps rising north")
	var packed := w.pack_chunk(Vector2i.ZERO)
	var again := WorldData.new(40, Vector2i(16, 16))
	again.unpack_chunk(packed)
	_check(again.form_at(12, 2, 9) == ramp and again.form_chunks.size() == 1, "the forms are saved with the chunk")
	again.remove_chunk(Vector2i.ZERO)
	_check(again.forms.is_empty(), "and forgotten with it")
	w.set_cell(12, 2, 9, Mat.AIR)
	_check(w.form_at(12, 2, 9) == WorldData.FORM_CUBE and w.forms.size() == 1, "a cell dug out forgets its form")
	w.set_form(12, 2, 9, ramp)
	_check(w.forms.size() == 1, "air takes no form")


## Flattening (the build mode's «выровнять»): the natural ground over the level is dug
## out with the best tool in the bag, the holes under it filled with soil from the bag;
## what players built stays.
func _test_flatten() -> void:
	var w := WorldData.new(40, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
			w.set_natural(x, 1, z, true)
	# A bump of two levels, a hole of one, a built block on the ground.
	for y in [2, 3]:
		w.set_cell(12, y, 10, Mat.DIRT)
		w.set_natural(12, y, 10, true)
	w.set_cell(13, 1, 10, Mat.AIR)
	w.set_cell(11, 2, 11, Mat.STONE)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 10.5) * WorldData.CELL
	var n := plans.draw(actions, who, "flatten", Vector3i(10, 1, 9), Vector3i(13, 1, 11), 1)
	var soil: String = Mat.RECORDS[Mat.DIRT].item
	_check(n == 3 and plans.cells.get(Vector3i(12, 2, 10)) == Plans.CUT and plans.cells.get(Vector3i(12, 3, 10)) == Plans.CUT
		and plans.cells.get(Vector3i(13, 1, 10)) == soil and not plans.cells.has(Vector3i(11, 2, 11)),
		"the bump is marked to dig, the hole to fill, the built block left: %s" % [plans.cells])
	var copy := Plans.new()
	copy.from_list(plans.to_list())
	_check(copy.cells == plans.cells, "and it is saved")
	var done := plans.build(actions, who)
	_check(done.has("swing") and w.get_cell(12, 3, 10) == Mat.AIR and w.get_cell(12, 2, 10) == Mat.DIRT,
		"the top of the bump is dug first")
	plans.build(actions, who)
	_check(w.get_cell(12, 2, 10) == Mat.AIR and plans.cells.size() == 1, "then the rest of it")
	plans.build(actions, who)
	_check(w.get_cell(13, 1, 10) == Mat.AIR and who.said.any(func(t: String) -> bool: return t.contains("Not in the bag")),
		"with no soil in the bag the hole waits")
	who.inventory.add(soil, 1)
	plans.build(actions, who)
	_check(w.get_cell(13, 1, 10) == Mat.DIRT and plans.cells.is_empty() and who.inventory.count(soil) == 0,
		"and is filled with soil from the bag")
	_check(Plans.best_tool(who, Mat.DIRT) == "", "bare hands dig soil when the bag has no shovel")
	who.inventory.add("tools:wooden_shovel", 1)
	_check(Plans.best_tool(who, Mat.DIRT) == "tools:wooden_shovel", "a shovel in the bag digs it faster")
	_check(Plans.best_tool(who, Mat.STONE) == null, "nothing in the bag digs stone")
