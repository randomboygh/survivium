extends "res://tests/unit/test_case.gd"
## The blueprint (Plans): its shapes, drawing and taking off the ghost, building it cell by
## cell from the bag with the action button, and its save.

const Plans := preload("res://src/shared/game/plans.gd")
const PlanHistory := preload("res://src/shared/game/plan_history.gd")
const PLANKS := "materials:planks"


## One drawing and building with the things it sets down (Plans.put_thing: Placed.ghost_spot).
class Builder extends "res://tests/unit/test_case.gd".Who:
	var placed


func run() -> void:
	_test_shapes()
	_test_build()
	_test_forms()
	_test_flights()
	_test_bands()
	_test_turn_form()
	_test_flatten()
	_test_earthwork()
	_test_replace()
	_test_ghost_things()
	_test_undo()


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
	var in_turn := true
	for i in range(1, built.size()):
		if built[i].y == built[i - 1].y:
			in_turn = in_turn and Vector3(built[i]).distance_to(built[i - 1]) <= 1.01
	_check(in_turn, "on a level one cell after another, each beside the one before (2026-11-26): %s" % [built])
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


## A line, a plane or a square drawn with slopes or stairs is a flight (Plans.flight):
## from the first corner one level high to the last `height` levels high, an upturned one
## hanging from the top; a room stays cubes.
func _test_flights() -> void:
	var ramp := WorldData.FORM_RAMP
	var east := ramp | 1 << 2
	var up := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(5, 1, 0), 6, Vector2.INF, 1, ramp)
	var right := up.size() == 21
	for x in 6:
		right = right and up.get(Vector3i(x, 1 + x, 0)) == east and not up.has(Vector3i(x, 2 + x, 0)) \
			and (x == 0 or up.get(Vector3i(x, x, 0)) == 0)
	_check(right, "a line of ramps climbs a level a column from the first corner to the height at the last: %s" % [up])
	var back := Plans.flight("line", Vector3i(5, 1, 0), Vector3i(0, 1, 0), 6, Vector2.INF, 1, ramp)
	_check(back.get(Vector3i(5, 1, 0)) == ramp | 3 << 2 and back.get(Vector3i(0, 6, 0)) == ramp | 3 << 2
		and not back.has(Vector3i(5, 2, 0)), "drawn the other way it climbs the other way")
	var long := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(8, 1, 0), 3, Vector2.INF, 2, WorldData.FORM_STAIRS)
	var formed := 0
	for c: Vector3i in long:
		formed += 1 if long[c] != 0 else 0
	_check(long.has(Vector3i(8, 3, 0)) and long.has(Vector3i(8, 3, 1)) and not long.has(Vector3i(8, 4, 0))
		and long.get(Vector3i(0, 1, 0)) == WorldData.FORM_STAIRS | 1 << 2 and not long.has(Vector3i(0, 2, 0))
		and formed == 6, "a long flight goes up in even steps, with flat cubes between, each row the same: %s" % [long])
	var upper := WorldData.FORM_UPPER | 1 << 2
	var under := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(5, 1, 0), 6, Vector2.INF, 1, WorldData.FORM_UPPER)
	right = under.size() == 21
	for x in 6:
		right = right and under.get(Vector3i(x, 6 - x, 0)) == upper and under.get(Vector3i(x, 6, 0)) != null \
			and not under.has(Vector3i(x, 5 - x, 0))
	_check(right, "an upturned flight hangs from the height at the first corner down to the ground at the last: %s" % [under])
	var square := Plans.flight("square", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 4, Vector2.INF, 1, WorldData.FORM_STAIRS)
	_check(square.get(Vector3i(0, 1, 0)) == WorldData.FORM_STAIRS | 1 << 2 and not square.has(Vector3i(0, 2, 0))
		and square.has(Vector3i(3, 4, 3)) and not square.has(Vector3i(3, 5, 3))
		and square.get(Vector3i(3, 3, 0)) == WorldData.FORM_STAIRS | 1 << 2 and not square.has(Vector3i(3, 4, 0))
		and square.get(Vector3i(0, 3, 3)) == WorldData.FORM_STAIRS | 2 << 2
		and square.get(Vector3i(0, 2, 1)) == WorldData.FORM_STAIRS | 2 << 2
		and not square.has(Vector3i(1, 1, 1)), "a square climbs along both sides from the first corner to the far one: %s" % [square])
	var lone := Plans.flight("line", Vector3i(2, 1, 2), Vector3i(2, 1, 2), 2, Vector2.INF, 1, ramp | 3 << 2)
	_check(lone == {Vector3i(2, 1, 2): 0, Vector3i(2, 2, 2): ramp | 3 << 2}, "a lone column rises to the side given: %s" % [lone])
	var plane := Plans.flight("plane", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 2, Vector2.INF, 1, ramp)
	right = plane.size() == 24
	for z in 4:
		right = right and plane.get(Vector3i(0, 1, z)) == east and plane.get(Vector3i(2, 2, z)) == east \
			and plane.get(Vector3i(3, 2, z)) == 0 and plane.get(Vector3i(3, 1, z)) == 0 and not plane.has(Vector3i(1, 2, z))
	_check(right and Plans.shape("plane", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 2, Vector2.INF, 1, east).size() == 24,
		"a plane climbs along the way the stroke went, all across its width: %s" % [plane])
	_check(Plans.shape("cube", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 4, Vector2.INF, 1, east)
			== Plans.shape("cube", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 4)
		and Plans.flight("cube", Vector3i(0, 1, 0), Vector3i(3, 1, 3), 2, Vector2.INF, 1, east).is_empty(),
		"a room takes no slopes or stairs")
	var w := WorldData.new(40, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(10.5, 1.0, 10.5) * WorldData.CELL
	who.item = PLANKS
	_check(plans.draw(actions, who, "plane", Vector3i(12, 1, 9), Vector3i(13, 1, 10), 1, 1, false, east) == 4
		and plans.forms == {Vector3i(12, 1, 9): east, Vector3i(12, 1, 10): east},
		"a plane drawn with a ramp chosen is a flight of them")
	plans.erase(actions, who, plans.cells.keys())
	_check(plans.draw(actions, who, "line", Vector3i(14, 1, 9), Vector3i(17, 1, 9), 4, 1, false, WorldData.FORM_UPPER) == 10
		and plans.forms.get(Vector3i(14, 4, 9)) == upper and plans.forms.get(Vector3i(17, 1, 9)) == upper
		and plans.forms.size() == 4, "an upturned flight is drawn with its forms")
	var sorted := plans.sort(actions, who, "line", Vector3i(14, 1, 12),
		Plans.shape("line", Vector3i(14, 1, 12), Vector3i(17, 1, 12), 4, Vector2.INF, 1, WorldData.FORM_UPPER),
		Mat.index(Plans.Items.get_item(PLANKS).get("place", "")), true)
	_check(sorted.fit.size() == 10 and sorted.hanging.is_empty(), "and its hanging cells are not told as uneven ground")


## A double tap on the ghost of a slope turns it (Plans.turn_form, the user's pick of
## 2026-11-26 in place of the turn button): every formed cell of the column joined to the
## cell tapped turns a quarter, the copies hear of it; a column of cubes, one out of reach
## and one apart over a gap do not.
func _test_turn_form() -> void:
	var w := WorldData.new(40, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(10.5, 1.0, 10.5) * WorldData.CELL
	who.item = PLANKS
	var east := WorldData.FORM_RAMP | 1 << 2
	_check(plans.draw(actions, who, "line", Vector3i(12, 1, 9), Vector3i(12, 1, 9), 3, 1, false, east) == 3
		and plans.forms == {Vector3i(12, 3, 9): east}, "a lone column of a ramp three high: %s" % [plans.forms])
	# A second column apart, over a gap of air in the same column.
	plans.cells[Vector3i(12, 5, 9)] = PLANKS
	plans.forms[Vector3i(12, 5, 9)] = east
	var heard := []
	plans.changed.connect(func(cells: Array, item: String) -> void: heard.append([cells, item]))
	_check(plans.formed_at(Vector3i(12, 1, 9)) and plans.column_of(Vector3i(12, 1, 9)).size() == 3,
		"the column of the cell tapped holds the ramp, the cells over the gap apart")
	_check(plans.turn_form(actions, who, Vector3i(12, 1, 9)) == 1
		and plans.forms[Vector3i(12, 3, 9)] == WorldData.FORM_RAMP | 2 << 2 and plans.forms[Vector3i(12, 5, 9)] == east
		and heard.size() == 1 and heard[0][0] == [Vector3i(12, 3, 9)] and heard[0][1] == PLANKS,
		"a tap twice on its foot turns its top a quarter, the column over the gap stays: %s" % [plans.forms])
	for i in 3:
		plans.turn_form(actions, who, Vector3i(12, 3, 9))
	_check(plans.forms[Vector3i(12, 3, 9)] == east, "four quarters bring it back")
	var band := WorldData.FORM_RAMP | 1 << 2
	var under := WorldData.FORM_UPPER | 3 << 2
	plans.cells[Vector3i(20, 1, 9)] = PLANKS
	plans.cells[Vector3i(20, 2, 9)] = PLANKS
	plans.forms[Vector3i(20, 2, 9)] = band
	plans.forms[Vector3i(20, 1, 9)] = under
	plans.turn_form(actions, who, Vector3i(20, 2, 9))
	_check(plans.forms[Vector3i(20, 2, 9)] == WorldData.FORM_RAMP | 2 << 2 and plans.forms[Vector3i(20, 1, 9)] == WorldData.FORM_UPPER,
		"a band's underside turns with its top, still the other way: %s" % [plans.forms])
	plans.draw(actions, who, "line", Vector3i(14, 1, 12), Vector3i(14, 1, 12), 2, 1, false, 0)
	_check(not plans.formed_at(Vector3i(14, 1, 12)) and plans.turn_form(actions, who, Vector3i(14, 1, 12)) == 0,
		"a column of cubes has nothing to turn")
	who.position = Vector3(100.5, 1.0, 100.5) * WorldData.CELL
	_check(plans.turn_form(actions, who, Vector3i(12, 3, 9)) == 0 and plans.forms[Vector3i(12, 3, 9)] == east,
		"nor is a ghost out of reach turned")


## A flight drawn as a band (Plans.BAND): one block thick along its slope, the underside
## a slope turned the other way, or notches under stairs, so it steps as the top does.
func _test_bands() -> void:
	var east := 1 << 2
	var west := 3 << 2
	var ramps := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(5, 1, 0), 6, Vector2.INF, 1,
		WorldData.FORM_RAMP | Plans.BAND)
	var right := ramps.size() == 11
	for x in 6:
		right = right and ramps.get(Vector3i(x, 1 + x, 0)) == WorldData.FORM_RAMP | east \
			and (x == 0 or ramps.get(Vector3i(x, x, 0)) == WorldData.FORM_UPPER | west) \
			and not ramps.has(Vector3i(x, x - 1, 0))
	_check(right, "a band of ramps is a ramp over an upturned one turned back, a column each: %s" % [ramps])
	var stairs := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(5, 1, 0), 6, Vector2.INF, 1,
		WorldData.FORM_STAIRS | Plans.BAND)
	right = stairs.size() == 11
	for x in range(1, 6):
		right = right and stairs.get(Vector3i(x, 1 + x, 0)) == WorldData.FORM_STAIRS | east \
			and stairs.get(Vector3i(x, x, 0)) == WorldData.FORM_NOTCH | east
	_check(right, "a band of stairs has a notch under each step: %s" % [stairs])
	var under := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(5, 1, 0), 6, Vector2.INF, 1,
		WorldData.FORM_UPPER | Plans.BAND)
	right = under.size() == 11
	for x in 6:
		right = right and under.get(Vector3i(x, 6 - x, 0)) == WorldData.FORM_UPPER | east \
			and (x == 0 or under.get(Vector3i(x, 7 - x, 0)) == WorldData.FORM_RAMP | west) \
			and not under.has(Vector3i(x, 8 - x, 0))
	_check(right, "an upturned band hangs from the height with a ramp over each column: %s" % [under])
	var flat := Plans.flight("line", Vector3i(0, 1, 0), Vector3i(8, 1, 0), 3, Vector2.INF, 1,
		WorldData.FORM_RAMP | Plans.BAND)
	_check(flat.size() == 11 and flat.get(Vector3i(8, 3, 0)) == 0 and not flat.has(Vector3i(8, 2, 0)),
		"a long band goes one block thick between its steps: %s" % [flat])
	_check(Plans.hangs_by_shape(WorldData.FORM_RAMP | Plans.BAND) and not Plans.hangs_by_shape(WorldData.FORM_RAMP),
		"a band hangs by its shape")
	var notch := WorldData.FORM_NOTCH
	_check(WorldData.form_kind(notch | east) == notch and WorldData.form_kind(WorldData.FORM_STAIRS | east) == WorldData.FORM_STAIRS
		and is_equal_approx(WorldData.form_top(notch, 0.0, 1.0, 0.6, 1.0), 1.0)
		and is_equal_approx(WorldData.form_top(notch, 0.0, 1.0, 0.0, 0.4), 0.0),
		"a notch is flat on top over the half away from the side it faces")
	var w := WorldData.new(40, Vector2i(16, 16))
	w.set_cell(3, 2, 3, Mat.STONE)
	w.set_form(3, 2, 3, notch | east)
	var copy := Plans.new()
	copy.from_list([[Vector3i(1, 1, 1), PLANKS, notch | west]])
	_check(w.form_at(3, 2, 3) == notch | east and copy.forms.get(Vector3i(1, 1, 1)) == notch | west,
		"a notch is kept by the world and by a saved blueprint")


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
	# A stroke of one column rises to the side it is given (away from the player, turned).
	_check(plans.draw(actions, who, "line", Vector3i(12, 2, 9), Vector3i(12, 2, 9), 1, 1, false, ramp) == 1
		and plans.draw(actions, who, "line", Vector3i(12, 2, 10), Vector3i(12, 2, 10), 1, 1, false, ramp) == 1
		and plans.forms.get(Vector3i(12, 2, 9)) == ramp, "a ramp's ghost keeps its form")
	var copy := Plans.new()
	copy.from_list(plans.to_list())
	_check(copy.forms == plans.forms, "and the form is saved with the ghost")
	# A world's file is JSON (WorldStore.write_json): a cell comes back as "(x, y, z)", a form as a float.
	var saved := Plans.new()
	saved.from_list(JSON.parse_string(JSON.stringify(plans.to_list(), "\t")))
	_check(saved.cells == plans.cells and saved.forms == plans.forms and not saved.cells.is_empty(),
		"the ghost and its forms come back from the world's file: %s" % [saved.cells])
	_check(Plans.cell_of("(-3, 2, 7)") == Vector3i(-3, 2, 7) and Plans.cell_of([4.0, -1.0, 0.0]) == Vector3i(4, -1, 0)
		and Plans.cell_of("(1, 2)") == null and Plans.cell_of("(a, 2, 3)") == null and Plans.cell_of(5) == null,
		"a cell is read from the words JSON keeps it as, not from others")
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


## A figure drawn on uneven ground with `level` levels it as «выровнять» would (the user's
## item 11 and picks, 2026-11-26): the natural bump in its footprint over its level is dug
## out (the figure's own cells in it are dug, then built), a dip under it down to solid
## ground (FLAT_DOWN at most) filled with soil; ground over the figure's top stays (2Б), so it does not hang; a deeper dip is left;
## a flight only has its dips filled; the eraser takes the earth's ghost with the figure.
func _test_earthwork() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
			w.set_natural(x, 1, z, true)
	# Along the wall at z 10: a stone bump two high at x 11, a dip one deep at x 13, a hole
	# deeper than FLAT_DOWN at x 15.
	for y in [2, 3]:
		w.set_cell(11, y, 10, Mat.STONE)
		w.set_natural(11, y, 10, true)
	w.set_cell(13, 1, 10, Mat.AIR)
	for y in range(0, 2):
		w.set_cell(15, y, 10, Mat.AIR)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(12.5, 2.0, 12.5) * WorldData.CELL
	who.item = PLANKS
	var soil: String = Mat.RECORDS[Mat.DIRT].item
	var a := Vector3i(10, 2, 10)
	var b := Vector3i(15, 2, 10)
	var flat := Plans.new()
	var as_is := flat.sort(actions, who, "line", a, Plans.shape("line", a, b, 1), Mat.index(PLANKS))
	_check(as_is.blocked.has(Vector3i(11, 2, 10)) and as_is.hanging.has(Vector3i(13, 2, 10)),
		"without levelling the bump blocks the wall and it hangs over the dip")
	var n := plans.draw(actions, who, "line", a, b, 1, 1, false, 0, true)
	_check(plans.cells.get(Vector3i(11, 2, 10)) == PLANKS and not plans.cells.has(Vector3i(11, 3, 10))
		and plans.cells.get(Vector3i(13, 1, 10)) == soil and plans.cells.get(Vector3i(13, 2, 10)) == PLANKS
		and not plans.cells.has(Vector3i(15, 1, 10)) and not plans.cells.has(Vector3i(15, 0, 10)) and n == 7,
		"the wall's cell in the bump is drawn, the bump over the wall's top left (2Б), the dip filled, the deep hole left: %s" % [plans.cells])
	var tall := plans.earthwork(actions, who, "line", a, b, Plans.shape("line", a, b, 2))
	_check(tall.dig.has(Vector3i(11, 3, 10)) and tall.cut.is_empty(), "a wall two high digs the bump to its top")
	var work := plans.earthwork(actions, who, "line", a, b, Plans.shape("line", a, b, 1))
	var sorted := plans.sort(actions, who, "line", a, Plans.shape("line", a, b, 1), Mat.index(PLANKS), false, work)
	_check(sorted.hanging.size() == 0 and sorted.blocked.size() == 0,
		"what is drawn already is in none; nothing hangs over a filled dip: %s" % [sorted])
	who.inventory.add(PLANKS, 6)
	who.inventory.add(soil, 1)
	who.inventory.add("tools:stone_pickaxe", 1)
	for i in 20:
		plans.build(actions, who)
	_check(w.get_cell(11, 3, 10) == Mat.STONE and w.get_cell(11, 2, 10) == Mat.index(PLANKS)
		and w.get_cell(13, 1, 10) == Mat.DIRT and w.get_cell(13, 2, 10) == Mat.index(PLANKS),
		"building digs the wall's cell in the bump, fills the dip and sets the wall")
	_check(plans.cells.keys().all(func(c: Vector3i) -> bool: return c == Vector3i(15, 2, 10)),
		"all is built but, maybe, the cell over the deep hole: %s" % [plans.cells])
	# A square levels the ground inside its walls too; the eraser takes the earth's ghost.
	w.set_cell(22, 2, 22, Mat.DIRT)
	w.set_natural(22, 2, 22, true)
	who.position = Vector3(20.5, 2.0, 20.5) * WorldData.CELL
	plans.draw(actions, who, "square", Vector3i(20, 2, 20), Vector3i(24, 2, 24), 1, 1, false, 0, true)
	_check(plans.cells.get(Vector3i(22, 2, 22)) == Plans.CUT, "a square levels the ground inside its walls")
	plans.cells[Vector3i(22, 6, 22)] = PLANKS
	plans.draw(actions, who, "square", Vector3i(20, 2, 20), Vector3i(24, 2, 24), 1, 1, true, 0, true)
	_check(not plans.cells.has(Vector3i(22, 2, 22)) and not plans.cells.has(Vector3i(20, 2, 20))
		and plans.cells.get(Vector3i(22, 6, 22)) == PLANKS,
		"the eraser takes the figure and its earthwork, a ghost block over it stays")
	# A flight only fills: the bump at its foot is not cut.
	w.set_cell(31, 2, 30, Mat.DIRT)
	w.set_natural(31, 2, 30, true)
	w.set_cell(33, 1, 30, Mat.AIR)
	who.position = Vector3(31.5, 2.0, 31.5) * WorldData.CELL
	var ramp := WorldData.FORM_RAMP
	var fw := plans.earthwork(actions, who, "line", Vector3i(30, 2, 30), Vector3i(34, 2, 30),
		Plans.shape("line", Vector3i(30, 2, 30), Vector3i(34, 2, 30), 3, Vector2.INF, 1, ramp), ramp)
	_check(fw.cut.is_empty() and fw.dig.is_empty() and fw.fill == [Vector3i(33, 1, 30)],
		"a flight's dips are filled, the ground over it not cut: %s" % [fw])


## Replacing the material (the user's idea 6, 2026-11-26): a stroke over a wall players built
## marks its blocks of another material with the block in hand, keeping their forms; natural
## ground and blocks of that material are left; ghost blocks in the box are repainted. The
## action button swaps an old block (to the bag) for the new one in one work, with the new one
## in the bag and a tool for the old.
func _test_replace() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
			w.set_natural(x, 1, z, true)
	# The wall is of brick (knocked out with a pickaxe), replaced by planks (`fresh`).
	var old := Mat.index("materials:brick")
	var fresh := PLANKS
	# A brick wall two high along z 10, x 10..13, its top east cell a ramp; a natural stone
	# at x 14; a planks block at x 12 level 2; a ghost of brick over the wall.
	for x in range(10, 14):
		for y in [2, 3]:
			w.set_cell(x, y, 10, old)
	w.set_form(13, 3, 10, WorldData.FORM_RAMP)
	w.set_cell(12, 2, 10, Mat.index(fresh))
	w.set_cell(14, 2, 10, Mat.STONE)
	w.set_natural(14, 2, 10, true)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := Who.new()
	who.position = Vector3(12.5, 2.0, 12.5) * WorldData.CELL
	who.item = fresh
	plans.cells[Vector3i(11, 4, 10)] = "materials:brick"
	var n := plans.draw(actions, who, "line", Vector3i(10, 2, 10), Vector3i(14, 2, 10), 3, 1, false, 0, false, true)
	_check(n == 8 and plans.cells.get(Vector3i(10, 2, 10)) == fresh and plans.cells.get(Vector3i(13, 3, 10)) == fresh
		and plans.cells.get(Vector3i(11, 4, 10)) == fresh and not plans.cells.has(Vector3i(12, 2, 10))
		and not plans.cells.has(Vector3i(14, 2, 10)) and not plans.cells.has(Vector3i(10, 1, 10)),
		"the brick blocks and the ghost are marked planks; planks, natural stone and ground left: %d %s" % [n, plans.cells])
	_check(plans.forms.get(Vector3i(13, 3, 10)) == WorldData.FORM_RAMP and not plans.forms.has(Vector3i(10, 2, 10)),
		"a replaced slope keeps its form: %s" % [plans.forms])
	plans.build(actions, who)
	_check(w.get_cell(10, 2, 10) == old, "with no planks in the bag nothing is swapped")
	who.inventory.add(fresh, 10)
	for i in 3:
		plans.build(actions, who)
	_check(w.get_cell(10, 2, 10) == old and who.inventory.count(fresh) == 9,
		"with no tool for brick nothing is swapped (the ghost over the wall is built): %d" % who.inventory.count(fresh))
	who.inventory.add("tools:stone_pickaxe", 1)
	var hole := false
	for i in 30:
		plans.build(actions, who)
		for x in range(10, 14):
			hole = hole or w.get_cell(x, 2, 10) == Mat.AIR or w.get_cell(x, 3, 10) == Mat.AIR
	_check(not hole, "each block is swapped in one work: no hole is left in the wall")
	_check(w.get_cell(10, 2, 10) == Mat.index(fresh) and w.get_cell(13, 3, 10) == Mat.index(fresh)
		and w.form_at(13, 3, 10) == WorldData.FORM_RAMP and w.get_cell(14, 2, 10) == Mat.STONE,
		"the wall is rebuilt of planks, the slope a planks slope")
	_check(who.inventory.count("materials:brick") == 7 and plans.cells.is_empty(),
		"the old blocks went to the bag, the ghost over the wall built too: %d %s"
		% [who.inventory.count("materials:brick"), plans.cells])


## Doors, windows and furniture set down by the blueprint (the user's picks, 2026-11-26,
## 1А, 2А): their ghosts are set where the thing would go in the world as the blueprint will
## stand (a door into a ghost wall takes its ghost blocks' place), saved, moved, turned and
## taken off like things, and built by the action button after the blocks, from the bag.
func _test_ghost_things() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	var plans := Plans.new()
	placed.plans = plans
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	actions.plans = plans
	var who := Builder.new()
	who.placed = placed
	who.position = Vector3(14.5, 1.0, 14.5) * WorldData.CELL
	_check(not plans.put_thing(actions, who, "tools:stool", Vector3i(14, 1, 16)) and plans.things.is_empty()
		and who.said.any(func(s: String) -> bool: return s.contains("Not in the bag")),
		"no ghost of a thing the bag does not hold")
	who.inventory.add("tools:stool", 1)
	who.inventory.add("tools:door", 1)
	_check(plans.put_thing(actions, who, "tools:stool", Vector3i(14, 1, 16)) and plans.things.size() == 1,
		"a ghost stool is set where the stool would go")
	var stool: Dictionary = plans.things[0]
	_check(stool.cell == Vector3i(14, 1, 16) and stool.cells == [Vector3i(14, 1, 16)] and placed.things.is_empty()
		and not w.blockers.has(stool.cell) and who.inventory.count("tools:stool") == 1,
		"it fills its cell in the blueprint only: nothing is set down, nothing leaves the bag")
	_check(plans.put_thing(actions, who, "tools:stool", Vector3i(14, 1, 16)) and plans.things.size() == 2
		and plans.things[1].cell != stool.cell, "a second ghost goes beside the first, not into it")
	_check(plans.erase_thing(actions, who, plans.things[1].cell) and plans.things.size() == 1, "a ghost thing is taken off")
	_check(not plans.put_thing(actions, who, "tools:stool", Vector3i(14, 1, 90)) and plans.things.size() == 1,
		"not out of reach")
	# A ghost wall of planks along x at z 20, three high; the wall drawn through the stool goes round it.
	who.item = PLANKS
	_check(plans.draw(actions, who, "line", Vector3i(8, 1, 20), Vector3i(20, 1, 20), 3) == 39, "(a ghost wall)")
	_check(plans.draw(actions, who, "line", Vector3i(12, 1, 16), Vector3i(16, 1, 16), 1) == 4 and not plans.cells.has(stool.cell),
		"ghost blocks are not drawn where a ghost thing stands")
	plans.erase(actions, who, [Vector3i(12, 1, 16), Vector3i(13, 1, 16), Vector3i(15, 1, 16), Vector3i(16, 1, 16)])
	# A door into the ghost wall, the face of it looking north tapped.
	_check(plans.put_thing(actions, who, "tools:door", Vector3i(12, 1, 20), -1, false, 0) and plans.things.size() == 2,
		"a ghost door goes into the ghost wall")
	var door: Dictionary = plans.things[1]
	_check(door.cells.has(Vector3i(12, 1, 20)) and door.cells.has(Vector3i(12, 2, 20)) and door.cells.size() == 2
		and door.turn % 2 == 0, "in the wall's plane, where it was pressed: %s" % [door])
	_check(not plans.cells.has(Vector3i(12, 1, 20)) and not plans.cells.has(Vector3i(12, 2, 20)) and plans.cells.has(Vector3i(12, 3, 20))
		and door.wall.size() == 2 and door.wall.values().all(func(v: String) -> bool: return v == PLANKS),
		"its ghost blocks are taken off and kept by it (1А): %s" % [door.wall])
	# Saved and read back, through the JSON of a world's file.
	var copy := Plans.new()
	copy.from_list(JSON.parse_string(JSON.stringify(plans.to_list())))
	_check(copy.things.size() == 2 and copy.cells == plans.cells and copy.thing_at(Vector3i(12, 2, 20)).get("cell") == door.cell
		and copy.thing_at(Vector3i(12, 2, 20)).turn == door.turn and copy.thing_at(Vector3i(12, 2, 20)).wall == door.wall,
		"the ghost things are saved with the blueprint and read back")
	var told: Array = []
	var copy2 := Plans.new()
	copy2.thing_changed.connect(func(t: Dictionary, came: bool) -> void: told.append([t.cell, came]))
	copy2.take_thing(Plans.thing_record(door))
	copy2.take_thing_gone(door.cell)
	_check(told == [[door.cell, true], [door.cell, false]] and copy2.things.is_empty(), "a client's copy takes them as told")
	# Moved along the wall: its ghost wall goes back into its old cells.
	var was: Vector3i = door.cell
	_check(plans.move_thing(actions, who, Vector3i(12, 1, 20), Vector3i(14, 1, 20), door.turn, 0), "a ghost door is moved along the wall")
	door = plans.thing_at(Vector3i(14, 1, 20))
	_check(not door.is_empty() and door.cells.has(Vector3i(14, 2, 20)) and plans.cells.get(Vector3i(12, 1, 20)) == PLANKS
		and plans.cells.get(Vector3i(12, 2, 20)) == PLANKS and not plans.cells.has(Vector3i(14, 1, 20)) and door.wall.size() == 2,
		"its old place is a ghost wall again, the new one taken off")
	var cells_before: Array = door.cells.duplicate()
	cells_before.sort()
	var turn_before: int = door.turn
	_check(plans.move_thing(actions, who, door.cell, door.cell, (door.turn + 2) % 4, -1), "a ghost door is turned the other way round")
	door = plans.thing_at(Vector3i(14, 1, 20))
	var cells_after: Array = door.cells.duplicate()
	cells_after.sort()
	_check(door.turn == (turn_before + 2) % 4 and cells_after == cells_before and door.wall.size() == 2, "where it stands")
	_check(plans.move_thing(actions, who, stool.cell, Vector3i(16, 1, 16), 0) and not plans.thing_at(Vector3i(16, 1, 16)).is_empty()
		and plans.thing_at(Vector3i(14, 1, 16)).is_empty(), "a ghost stool is moved")
	stool = plans.thing_at(Vector3i(16, 1, 16))
	_check(plans.move_thing(actions, who, stool.cell, stool.cell, (stool.turn + 1) % 4)
		and plans.thing_at(stool.cell).turn == (stool.turn + 1) % 4, "and turned a quarter where it stands")
	stool = plans.thing_at(Vector3i(16, 1, 16))
	# On a ghost block: it rests on it, as on the floor that will be built.
	plans.cells[Vector3i(30, 3, 30)] = PLANKS
	_check(plans.put_thing(actions, who, "tools:stool", Vector3i(30, 4, 30)) and plans.thing_at(Vector3i(30, 4, 30)).get("cell") == Vector3i(30, 4, 30),
		"a ghost thing stands on a ghost floor")
	var raised: Dictionary = plans.thing_at(Vector3i(30, 4, 30))
	plans.drop_thing(raised)
	plans.cells.erase(Vector3i(30, 3, 30))
	# Built: the blocks first, then the things, from the bag.
	who.inventory.add(PLANKS, 60)
	who.item = PLANKS
	var things_while_blocks := false
	for i in 60:
		var cells_left := plans.cells.size()
		var things_left := plans.things.size()
		var done := plans.build(actions, who)
		if not done.has("placed"):
			break
		if plans.things.size() < things_left and cells_left > 0:
			things_while_blocks = true
	_check(plans.cells.is_empty() and plans.things.is_empty() and not things_while_blocks,
		"the action button builds the blocks, then the things: %d cells, %d things left" % [plans.cells.size(), plans.things.size()])
	var real_door: Dictionary = placed.at(Vector3i(14, 1, 20))
	_check(not real_door.is_empty() and real_door.item == "tools:door" and real_door.cell == door.cell and real_door.turn == door.turn
		and w.get_cell(14, 1, 20) == Mat.AIR and w.get_cell(14, 3, 20) == Mat.index(PLANKS),
		"the door stands where its ghost was, in the wall built round it")
	_check(real_door.get("cut", {}).size() == 2 and real_door.cut.values().all(func(v: String) -> bool: return v == Mat.IDS[Mat.index(PLANKS)]),
		"remembering the ghost blocks it took the place of as cut, to wall them up when moved: %s" % [real_door.get("cut")])
	_check(placed.at(stool.cell).get("item", "") == "tools:stool" and placed.at(stool.cell).turn == stool.turn
		and who.inventory.count("tools:stool") == 0 and who.inventory.count("tools:door") == 0, "the stool too, as it was turned")
	# A ghost thing with nothing to build it with waits; one where a thing is set down for real goes.
	_check(plans.put_thing(actions, who, "tools:door", Vector3i(20, 1, 12)) == false, "(the bag holds no door now)")
	who.inventory.add("tools:stool", 2)
	plans.put_thing(actions, who, "tools:stool", Vector3i(10, 1, 12))
	var ghost: Dictionary = plans.thing_at(Vector3i(10, 1, 12))
	_check(not ghost.is_empty() and placed.put_at(who, "tools:stool", Vector3i(10, 1, 12), 40) and plans.thing_at(Vector3i(10, 1, 12)).is_empty(),
		"a thing set down for real where a ghost thing stands takes its place")
	plans.put_thing(actions, who, "tools:stool", Vector3i(6, 1, 12))
	_check(plans.clear(actions, who) >= 1 and plans.things.is_empty(), "clearing the blueprint takes the ghost things off")
	plans.put_thing(actions, who, "tools:stool", Vector3i(6, 1, 12))
	who.item = PLANKS
	_check(plans.draw(actions, who, "line", Vector3i(4, 1, 12), Vector3i(8, 1, 12), 1, 1, true) >= 1 and plans.things.is_empty(),
		"and so does an erasing stroke over them")


## Undo and redo of the blueprint (PlanHistory; the user's picks of 2026-11-26, 1А 2А).
func _test_undo() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	var plans := Plans.new()
	placed.plans = plans
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	actions.plans = plans
	var who := Builder.new()
	who.placed = placed
	who.position = Vector3(14.5, 1.0, 14.5) * WorldData.CELL
	who.item = PLANKS
	var h := PlanHistory.new(plans)
	var step := func(work: Callable) -> Variant:
		h.begin()
		var out: Variant = work.call()
		h.end()
		return out
	_check(h.undo(actions, who) == 0 and h.redo(actions, who) == 0, "nothing to undo or redo at first")
	step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(10, 1, 20), Vector3i(14, 1, 20), 2))
	_check(plans.cells.size() == 10 and h.undos.size() == 1, "a wall drawn is one step")
	step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(30, 1, 20), Vector3i(30, 1, 20), 1, 1, true))
	_check(h.undos.size() == 1, "a request that changed nothing is no step")
	_check(h.undo(actions, who) == 10 and plans.cells.is_empty() and h.redos.size() == 1, "undone: its ghost goes")
	_check(h.redo(actions, who) == 10 and plans.cells.size() == 10 and h.undos.size() == 1 and h.redos.is_empty(),
		"redone: it comes back")
	# Erasing part of it, undone, brings that part back.
	step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(10, 1, 20), Vector3i(11, 1, 20), 2, 1, true))
	_check(plans.cells.size() == 6, "(part erased)")
	_check(h.undo(actions, who) == 4 and plans.cells.size() == 10, "an erase undone puts the ghost back")
	_check(h.redo(actions, who) == 4 and plans.cells.size() == 6, "and redone takes it off again")
	h.undo(actions, who)
	# A cell built meanwhile (gone from the blueprint) and one drawn over by someone else stay.
	plans.erase(actions, who, [Vector3i(14, 1, 20)])
	w.set_cell(14, 1, 20, Mat.index(Items.get_item(PLANKS).place))
	plans.cells[Vector3i(14, 2, 20)] = "materials:cobblestone"
	_check(h.undo(actions, who) == 8 and plans.cells.size() == 1 and plans.cells.get(Vector3i(14, 2, 20)) == "materials:cobblestone",
		"undo leaves a cell built meanwhile and one changed since: %s" % [plans.cells])
	plans.cells.clear()
	plans.forms.clear()
	_check(h.redo(actions, who) == 9 and plans.cells.size() == 9, "redo puts back what is still as it was undone, not a ghost on the block built")
	# A new step lets the undone ones go.
	h.undo(actions, who)
	step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(10, 1, 22), Vector3i(12, 1, 22), 1))
	_check(h.redos.is_empty(), "a new step lets the steps undone go")
	# At most MAX steps.
	for i in PlanHistory.MAX + 5:
		var x := 2 + i % 30
		var z := 2 + 2 * (i / 30)
		step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(x, 1, z), Vector3i(x, 1, z), 1))
	_check(h.undos.size() == PlanHistory.MAX, "at most %d steps are kept: %d" % [PlanHistory.MAX, h.undos.size()])
	h.undos.clear()
	plans.cells.clear()
	plans.forms.clear()
	# A slope turned, undone.
	step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(20, 1, 10), Vector3i(20, 1, 10), 1, 1, false,
		WorldData.FORM_RAMP))
	var slope := Vector3i(20, 1, 10)
	var form0: int = plans.forms.get(slope, 0)
	step.call(func() -> int: return plans.turn_form(actions, who, slope))
	_check(form0 != 0 and plans.forms[slope] != form0, "(a slope drawn and turned)")
	_check(h.undo(actions, who) == 1 and plans.forms[slope] == form0, "a slope's turn is undone")
	_check(h.redo(actions, who) == 1 and plans.forms[slope] != form0, "and redone")
	# Ghost things: a door set into a ghost wall, moved, taken off; «clear».
	who.inventory.add("tools:door", 1)
	who.inventory.add("tools:stool", 1)
	step.call(func() -> int: return plans.draw(actions, who, "line", Vector3i(8, 1, 30), Vector3i(20, 1, 30), 3))
	var wall: Dictionary = plans.cells.duplicate()
	step.call(func() -> bool: return plans.put_thing(actions, who, "tools:door", Vector3i(12, 1, 30), -1, false, 0))
	var door: Dictionary = plans.thing_at(Vector3i(12, 1, 30))
	_check(not door.is_empty() and not plans.cells.has(Vector3i(12, 1, 30)), "(a ghost door in the ghost wall)")
	_check(h.undo(actions, who) == 3 and plans.things.is_empty() and plans.cells == wall, "a ghost door undone: the wall is whole again")
	_check(h.redo(actions, who) == 3 and plans.things.size() == 1 and not plans.cells.has(Vector3i(12, 1, 30))
		and plans.thing_at(Vector3i(12, 2, 30)).wall.size() == 2, "redone: it is back in the wall, its wall kept")
	door = plans.thing_at(Vector3i(12, 1, 30))
	step.call(func() -> bool: return plans.move_thing(actions, who, door.cell, Vector3i(15, 1, 30), door.turn, 0))
	_check(not plans.thing_at(Vector3i(15, 1, 30)).is_empty() and plans.cells.has(Vector3i(12, 1, 30)), "(moved along the wall)")
	_check(h.undo(actions, who) > 0 and not plans.thing_at(Vector3i(12, 1, 30)).is_empty() and plans.thing_at(Vector3i(15, 1, 30)).is_empty()
		and plans.cells.has(Vector3i(15, 1, 30)) and not plans.cells.has(Vector3i(12, 1, 30)), "a move undone puts it back where it was")
	step.call(func() -> bool: return plans.put_thing(actions, who, "tools:stool", Vector3i(14, 1, 16)))
	var cells_before: Dictionary = plans.cells.duplicate()
	var things_before := plans.things.map(func(t: Dictionary) -> String: return str([t.item, t.cell, t.turn]))
	step.call(func() -> int: return plans.clear(actions, who))
	_check(plans.cells.is_empty() and plans.things.is_empty(), "(cleared)")
	h.undo(actions, who)
	var things_after := plans.things.map(func(t: Dictionary) -> String: return str([t.item, t.cell, t.turn]))
	things_before.sort()
	things_after.sort()
	_check(plans.things.size() == 2 and things_after == things_before and plans.cells == cells_before,
		"«clear» undone brings every ghost back")
	# Out of reach: the step stays, the player is told.
	who.position = Vector3(14.5, 1.0, 400.5) * WorldData.CELL
	var steps := h.redos.size()
	_check(h.redo(actions, who) == -1 and h.redos.size() == steps and who.said.any(func(s: String) -> bool: return s.contains("closer")),
		"a step far off is not done; it waits, and the player is told")
