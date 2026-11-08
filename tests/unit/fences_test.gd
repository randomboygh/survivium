extends "res://tests/unit/test_case.gd"
## Fences, wickets and gates, hatches and ladders (stage 1, building): fences join, keep
## bodies and animals out, are built by line; a gate takes a fence's place; a hatch lies in
## a floor; a body climbs a ladder.

const Plans := preload("res://src/shared/game/plans.gd")


class Builder extends "res://tests/unit/test_case.gd".Who:
	var placed


func run() -> void:
	_test_fence_joins()
	_test_fence_line()
	_test_gate_in_fence()
	_test_hatch()
	_test_ladder()


func _flat() -> WorldData:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	return w


func _placed(w: WorldData) -> Placed:
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	return placed


func _test_fence_joins() -> void:
	var w := _flat()
	var placed := _placed(w)
	var lone := placed.put("tools:fence", Vector3i(30, 1, 30))
	_check(lone.join == 10 and Placed.is_fence(lone) and Placed.is_part(lone), "a fence alone has rails across its front: %s" % [lone])
	var a := placed.put("tools:fence", Vector3i(10, 1, 10))
	var b := placed.put("tools:fence", Vector3i(11, 1, 10))
	var c := placed.put("tools:fence", Vector3i(11, 1, 11))
	_check(a.join == 2 and b.join == 12 and c.join == 1, "fences beside each other join: %d %d %d" % [a.join, b.join, c.join])
	_check(w.blocker_part(10, 2, 10, 0.4, 0.6, 0.4, 0.6) > 0.5 and is_equal_approx(w.blocker_part(10, 1, 10, 0.0, 0.3, 0.0, 0.3), 0.0),
		"solid by its post and rails over a cell high, open in the corners")
	placed.take_up(_who(placed), b)
	_check(a.join == 10 and c.join == 10, "one taken up, those beside it are alone again: %d %d" % [a.join, c.join])
	# A row along x at z 20: a body walking north stops at it and does not jump it.
	for x in range(5, 15):
		placed.put("tools:fence", Vector3i(x, 1, 20))
	_check(not _goes_north(w, Vector3(9.5, 1.0, 21.5), 20.0, false), "a body walking into a fence stops")
	_check(not _goes_north(w, Vector3(9.5, 1.0, 21.5), 20.0, true), "and does not jump it")
	_check(not _goes_north(w, Vector3(10.0, 1.0, 21.5), 20.0, false), "not where two segments meet either")
	var wild := Wildlife.new()
	wild.world = w
	var y := 1.0 * WorldData.CELL
	_check(wild._fenced(y, 9.5 * WorldData.CELL, 20.6 * WorldData.CELL) > y + WorldData.CELL
		and is_equal_approx(wild._fenced(y, 9.5 * WorldData.CELL, 21.5 * WorldData.CELL), y),
		"an animal comes up to the fence, not over it")
	placed.put("tools:chest", Vector3i(30, 1, 10))
	_check(is_equal_approx(wild._fenced(y, 30.5 * WorldData.CELL, 10.5 * WorldData.CELL), y), "a low chest it walks over, as before")


func _test_fence_line() -> void:
	var w := _flat()
	var placed := _placed(w)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var plans := Plans.new()
	actions.plans = plans
	var who := _who(placed)
	who.position = Vector3(12.5, 1.0, 14.5) * WorldData.CELL
	who.item = "tools:fence"
	_check(Plans.drawn_with("tools:fence") and not Plans.drawn_with("tools:wicket"), "a fence is drawn as a blueprint, a wicket is not")
	_check(plans.draw(actions, who, "cube", Vector3i(10, 1, 10), Vector3i(13, 1, 12), 5) == 0, "no room of fence")
	var n := plans.draw(actions, who, "line", Vector3i(10, 1, 10), Vector3i(14, 1, 10), 4, 3)
	_check(n == 5 and plans.cells.size() == 5, "a line of fence is one segment high and thick: %d" % n)
	_check(plans.builds(who), "the action button builds it with a fence in hand")
	who.inventory.add("tools:fence", 3)
	for i in 6:
		plans.build(actions, who)
	_check(placed.things.size() == 3 and plans.cells.size() == 2 and who.inventory.count("tools:fence") == 0,
		"a segment for each fence in the bag, the rest waits: %d %d" % [placed.things.size(), plans.cells.size()])
	who.inventory.add("tools:fence", 2)
	for i in 3:
		actions.act_in_front(who, 40)
	_check(placed.things.size() == 5 and plans.cells.is_empty(), "the action button builds the rest")
	var joined := true
	for e: Dictionary in placed.things:
		joined = joined and e.join & 10 != 0
	_check(joined, "joined along the line")


func _test_gate_in_fence() -> void:
	var w := _flat()
	var placed := _placed(w)
	for x in range(5, 15):
		placed.put("tools:fence", Vector3i(x, 1, 20))
	var who := _who(placed)
	who.position = Vector3(9.5, 1.0, 22.5) * WorldData.CELL
	who.inventory.add("tools:wicket", 1)
	_check(placed.put_at(who, "tools:wicket", Vector3i(9, 1, 20), 40), "a wicket tapped onto a fence is set down")
	var gate: Dictionary = placed.things[-1]
	_check(gate.item == "tools:wicket" and gate.cell == Vector3i(9, 1, 20) and who.inventory.count("tools:fence") == 1
		and placed.things.size() == 10, "in the fence's place, the segment back in the bag: %s" % [gate])
	_check(placed.at(Vector3i(8, 1, 20)).join & 2 != 0 and placed.at(Vector3i(10, 1, 20)).join & 8 != 0, "the fence joins it")
	_check(not _goes_north(w, Vector3(9.5, 1.0, 21.5), 20.0, true), "shut, nobody gets through or over")
	var wild := Wildlife.new()
	wild.world = w
	_check(wild._fenced(WorldData.CELL, 9.5 * WorldData.CELL, 20.5 * WorldData.CELL) > WorldData.CELL * 2.0, "nor an animal")
	_check(placed.swing(who, gate) and gate.open and _goes_north(w, Vector3(9.5, 1.0, 21.5), 19.5, false), "open, it is walked through")
	_check(Placed.swung_voxels("tools:wicket", [Vector3i(0, 0, 3), Vector3i(7, 5, 4)])
		== [Vector3i(0, 0, 4), Vector3i(1, 5, 11)], "its leaf swings out on the hinge at its west end")
	who.inventory.add("tools:gate", 1)
	_check(placed.put_at(who, "tools:gate", Vector3i(6, 1, 20), 40) and placed.things[-1].item == "tools:gate"
		and placed.cells_of(placed.things[-1]).size() == 2 and who.inventory.count("tools:fence") == 3,
		"a gate takes two segments: %s" % [placed.things[-1]])
	_check(Placed.size_of("tools:door_3x3") == 3, "the big gates for a wall are three cells wide")


func _test_hatch() -> void:
	var w := _flat()
	# A floor of planks two levels up over a cellar, on walls.
	for z in range(8, 15):
		for x in range(8, 15):
			w.set_cell(x, 3, z, Mat.STONE)
	var placed := _placed(w)
	var who := _who(placed)
	who.position = Vector3(11.5, 4.0, 12.5) * WorldData.CELL
	who.inventory.add("tools:hatch", 1)
	_check(placed.put_at(who, "tools:hatch", Vector3i(11, 3, 11), 40), "a hatch tapped into a floor is set down")
	var hatch: Dictionary = placed.things[-1]
	_check(hatch.cell == Vector3i(11, 3, 11) and w.get_cell(11, 3, 11) == Mat.AIR and is_equal_approx(w.blocker_top(11, 3, 11), 1.0),
		"in place of the block, solid as a floor: %s" % [hatch])
	var body := Body.new()
	body.world = w
	_check(body.standing(Vector3(11.5, 4.0, 11.5) * WorldData.CELL), "it is stood on")
	_check(placed.swing(who, hatch) and hatch.open and not w.blockers.has(Vector3i(11, 3, 11)), "a tap opens it")
	_check(Placed.swung_voxels("tools:hatch", [Vector3i(2, 7, 0), Vector3i(2, 7, 7)]) == [Vector3i(2, 8, 6), Vector3i(2, 15, 0)]
		or Placed.swung_voxels("tools:hatch", [Vector3i(2, 7, 0)]) == [Vector3i(2, 8, 0)], "its lid stands up over the hole")
	# Up a ladder under it, through the open hatch, onto the floor.
	placed.put("tools:ladder", Vector3i(11, 1, 11))
	placed.put("tools:ladder", Vector3i(11, 2, 11))
	var at := Vector3(11.5, 1.0, 11.5) * WorldData.CELL
	body.on_ground = true
	body.move_input = Vector2(0.0, -1.0)
	var up := false
	for i in 120:
		at = body.step(at, 1.0 / 60.0, false)
		up = up or is_equal_approx(at.y / WorldData.CELL, 4.0) and at.z / WorldData.CELL < 11.0
	_check(up, "a ladder under it climbs through the hole onto the floor: %s" % [at / WorldData.CELL])
	who.inventory.add("tools:hatch_2x2", 1)
	_check(placed.put_at(who, "tools:hatch_2x2", Vector3i(9, 3, 9), 40) and placed.cells_of(placed.things[-1]).size() == 4,
		"a wide hatch takes two by two cells of the floor")
	_check(not placed.put_at(_with(who, "tools:hatch"), "tools:hatch", Vector3i(30, 1, 30), 40), "nothing to set a hatch in on open ground")


func _test_ladder() -> void:
	var w := _flat()
	# A wall four high along x at z 9.
	for x in range(8, 13):
		for y in range(1, 5):
			w.set_cell(x, y, 9, Mat.STONE)
	var placed := _placed(w)
	var who := _who(placed)
	who.position = Vector3(10.5, 1.0, 12.5) * WorldData.CELL
	who.inventory.add("tools:ladder", 4)
	_check(placed.put_at(who, "tools:ladder", Vector3i(10, 1, 10), 40), "a ladder is set down against a wall")
	_check(w.ladders.get(Vector3i(10, 1, 10)) == 0 and not w.blockers.has(Vector3i(10, 1, 10)),
		"leaning on it, its back to the north, not solid: %s" % [w.ladders])
	_check(not placed.put_at(who, "tools:ladder", Vector3i(20, 3, 20), 40) or not w.ladders.has(Vector3i(20, 3, 20)),
		"not on air")
	for y in range(2, 5):
		who.position = Vector3(10.5, float(y) - 1.0, 12.5) * WorldData.CELL
		_check(placed.put_at(who, "tools:ladder", Vector3i(10, y, 10), 40) and w.ladders.has(Vector3i(10, y, 10)),
			"segment over segment, level %d" % y)
	var body := Body.new()
	body.world = w
	var at := Vector3(10.5, 1.0, 10.5) * WorldData.CELL
	body.on_ground = true
	body.move_input = Vector2(0.0, -1.0)
	_check(body.on_ladder(at), "a body in its cell is on it")
	var over := false
	for i in 240:
		at = body.step(at, 1.0 / 60.0, false)
		over = over or at.y / WorldData.CELL > 4.99 and at.z / WorldData.CELL < 9.5 and body.on_ground
	_check(over, "the stick toward it climbs it and steps off onto the top of the wall: %s" % [at / WorldData.CELL])
	# Down: back into the ladder from the top, the stick away from it.
	at = Vector3(10.5, 3.0, 10.5) * WorldData.CELL
	body.move_input = Vector2.ZERO
	for i in 30:
		at = body.step(at, 1.0 / 60.0, false)
	_check(is_equal_approx(at.y / WorldData.CELL, 3.0), "let go of the stick, it holds on: %s" % [at / WorldData.CELL])
	body.move_input = Vector2(0.0, 1.0)
	for i in 32:
		at = body.step(at, 1.0 / 60.0, false)
	_check(at.y / WorldData.CELL < 1.01 and at.z / WorldData.CELL < 11.0, "away from it climbs down: %s" % [at / WorldData.CELL])
	for i in 30:
		at = body.step(at, 1.0 / 60.0, false)
	_check(at.z / WorldData.CELL > 11.0, "and at the foot walks off: %s" % [at / WorldData.CELL])
	# The server climbs where the client says it went (Body.climb).
	at = Vector3(10.5, 1.0, 10.5) * WorldData.CELL
	body.move_input = Vector2.ZERO
	body.climb = 1.0
	for i in 15:
		at = body.step(at, 1.0 / 60.0, false)
	_check(at.y / WorldData.CELL > 1.5, "climbs on the server's word")
	body.climb = NAN
	who.position = Vector3(10.5, 1.0, 12.5) * WorldData.CELL
	_check(not placed.put_at(_with(who, "tools:stool"), "tools:stool", Vector3i(10, 1, 10), 40) or placed.things[-1].cell != Vector3i(10, 1, 10),
		"nothing is set down in a ladder's cell")


## True when a body standing at `from` (cells) walking north for two seconds, jumping all
## the way with `jump`, gets north of z `past`.
func _goes_north(w: WorldData, from: Vector3, past: float, jump: bool) -> bool:
	var body := Body.new()
	body.world = w
	body.on_ground = true
	body.move_input = Vector2(0.0, -1.0)
	var at := from * WorldData.CELL
	for i in 120:
		at = body.step(at, 1.0 / 60.0, jump and i % 2 == 0)
	return at.z / WorldData.CELL < past


func _who(placed: Placed) -> Builder:
	var who := Builder.new()
	who.placed = placed
	who.facing = Vector2i(0, -1)
	return who


func _with(who, id: String):
	who.inventory.add(id, 1)
	return who
