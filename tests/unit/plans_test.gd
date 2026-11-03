extends "res://tests/unit/test_case.gd"
## The blueprint (Plans): its shapes, drawing and taking off the ghost, building it cell by
## cell from the bag with the action button, and its save.

const Plans := preload("res://src/shared/game/plans.gd")
const PLANKS := "materials:planks"


func run() -> void:
	_test_shapes()
	_test_build()


func _test_shapes() -> void:
	var wall := Plans.shape("wall", Vector3i(2, 1, 3), Vector3i(6, 1, 4), 2)
	_check(wall.size() == 10 and wall.has(Vector3i(6, 2, 3)) and not wall.has(Vector3i(6, 1, 4)),
		"a wall goes along the way the stroke went farthest, two levels high: %s" % [wall])
	_check(Plans.shape("wall", Vector3i(0, 1, 0), Vector3i(0, 1, 0), 9).size() == Plans.MAX_HEIGHT,
		"a wall is at most four levels high")
	var floor := Plans.shape("floor", Vector3i(5, 1, 5), Vector3i(3, 1, 6), 3)
	_check(floor.size() == 6 and floor.has(Vector3i(3, 1, 6)), "a floor is the rectangle, one level")
	# A room 5×5 cells, the one drawing south of it: the door's gap in the middle of the
	# south side, two levels of it.
	var room := Plans.shape("room", Vector3i(0, 1, 0), Vector3i(4, 1, 4), 3, Vector2(2.5, 9.0) * WorldData.CELL)
	_check(room.size() == 16 * 3 - 2 and not room.has(Vector3i(2, 1, 4)) and not room.has(Vector3i(2, 2, 4))
		and room.has(Vector3i(2, 3, 4)) and not room.has(Vector3i(2, 1, 2)),
		"a room is walls round the rectangle with a door's gap on the side nearest: %d" % room.size())
	var east := Plans.shape("room", Vector3i(0, 1, 0), Vector3i(4, 1, 4), 2, Vector2(12.0, 2.5) * WorldData.CELL)
	_check(not east.has(Vector3i(4, 1, 2)) and east.has(Vector3i(2, 1, 4)), "standing east, the gap is in the east side")


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
	_check(plans.draw(actions, who, "wall", Vector3i(12, 2, 8), Vector3i(12, 2, 12), 2) == 0 and plans.cells.is_empty(),
		"no ghost is drawn without a block in hand")
	who.item = PLANKS
	_check(plans.draw(actions, who, "wall", Vector3i(12, 2, 8), Vector3i(12, 2, 12), 2) == 10 and plans.cells.get(Vector3i(12, 3, 8)) == PLANKS,
		"a wall's ghost is drawn with the block in hand")
	_check(plans.draw(actions, who, "floor", Vector3i(8, 1, 9), Vector3i(9, 1, 10), 1) == 4,
		"a floor's ghost goes on the ground")
	_check(actions.front_kind(who) == "build", "the action button builds with a block in hand by the ghost")
	var swing := actions.act_in_front(who, 40)
	_check(swing.is_empty() or not swing.has("placed"), "with no planks in the bag nothing is built")
	_check(who.said.any(func(s: String) -> bool: return s.contains("В сумке нет")), "and the player is told so")
	who.inventory.add(PLANKS, 20)
	var built: Array[Vector3i] = []
	for i in 14:
		var before: Dictionary = plans.cells.duplicate()
		swing = actions.act_in_front(who, 40)
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
	# Drawn again from a ghost cell, the shape takes the ghost off.
	plans.draw(actions, who, "wall", Vector3i(20, 2, 8), Vector3i(24, 2, 8), 1)
	_check(plans.draw(actions, who, "wall", Vector3i(22, 2, 8), Vector3i(24, 2, 8), 1) == 3 and plans.cells.size() == 2,
		"a stroke that starts on the ghost takes it off")
	var copy := Plans.new()
	copy.from_list(plans.to_list())
	_check(copy.cells == plans.cells, "the ghost is saved and read back")
	_check(plans.draw(actions, who, "floor", Vector3i(0, 1, 0), Vector3i(30, 1, 30), 1) == 0, "a shape too big is not drawn")
