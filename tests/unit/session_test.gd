extends "res://tests/unit/test_case.gd"
## The session of a world (the server's tick): the rules of play, and a tick that runs
## the clock, every character with their workshop, the animals around all the players
## and the wind around each of them.


func run() -> void:
	_test_rules()
	_test_session()
	_test_making()


func _test_rules() -> void:
	var r = Rules.of({"free_build": true, "instant_craft": true})
	_check(r.free_build and not r.tool_wear and r.instant_craft, "rules come from a dictionary, the rest by default")
	var again = Rules.new()
	again.from_dict(r.to_dict())
	_check(again.to_dict() == r.to_dict(), "rules go through to_dict and back")
	var w := WorldData.new(8, Vector2i(16, 16))
	for z in 16:
		for x in 16:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var who := Who.new()
	who.position = Vector3(8.5, 2.0, 8.5) * WorldData.CELL
	var free := WorldActions.new(w, Clock.new(), r)
	free.dig_at(who, Vector3i(8, 1, 7), Vector3i.UP)
	_check(w.get_cell(8, 1, 7) == Mat.AIR and w.drops.is_empty(), "under free building a block dug gives nothing")
	WorldActions.new(w, Clock.new(), Rules.new()).dig_at(who, Vector3i(8, 1, 9), Vector3i.UP)
	_check(w.get_cell(8, 1, 9) == Mat.AIR and not w.drops.is_empty(), "by the default rules it does")


## Two characters far apart play in one session: a tick runs the clock, both of them
## and their workshops; the animals come around both; the wind works around each in
## turn; the pushes of the animals are each one's own.
func _test_session() -> void:
	var size := WorldData.CHUNK * 11
	var w := WorldData.new(8, Vector2i(size, size))
	for z in size:
		for x in size:
			w.set_cell(x, 5, z, Mat.GRASS)
	var clock := Clock.new()
	var placed := Placed.new()
	var s := Session.new(w, null, clock, Rules.of({"instant_craft": true}), placed)
	_check(placed.world == w and clock.world == w and s.actions.world == w and s.wildlife.clock == clock,
		"the session fits the clock, the things, the actions and the animals to the world")
	var a := Survivor.new()
	a.body = Body.new()
	a.at = Vector3(20.5, 6.0, 20.5) * WorldData.CELL
	var b := Survivor.new()
	b.body = Body.new()
	b.at = Vector3(size - 20.5, 6.0, size - 20.5) * WorldData.CELL
	var shop_a := Workshop.new(a, placed, s.rules)
	var shop_b := Workshop.new(b, placed, s.rules)
	s.add_player(a, shop_a)
	s.add_player(b, shop_b)
	_check(a.world == w and b.clock == clock and a.placed == placed and s.wildlife.people == [a, b],
		"a player added is fitted to the world and seen by the animals as people")
	for who in [a, b]:
		who.inventory.add("resources:fiber", 3)
	var cord := Crafting.get_recipe("materials:cord")
	_check(shop_a.start(cord) == 1 and shop_b.start(cord) == 1, "both start a cord by hand")
	var time := clock.time_of_day
	s.tick(0.5)
	_check(clock.time_of_day > time, "a tick passes the time")
	_check(a.born >= 0.0 and b.born >= 0.0, "a tick runs every character")
	_check(a.inventory.count("materials:cord") == 1 and b.inventory.count("materials:cord") == 1,
		"a tick runs every workshop")
	s.start_wildlife(7)
	s.tick(0.1)
	var near_a := 0
	var near_b := 0
	var farthest := 0.0
	for animal in s.wildlife.animals:
		var da: float = animal.pos.distance_to(a.position)
		var db: float = animal.pos.distance_to(b.position)
		if da < db:
			near_a += 1
		else:
			near_b += 1
		farthest = maxf(farthest, minf(da, db) / WorldData.CELL)
	_check(near_a > 0 and near_b > 0 and farthest < Wildlife.SPAWN_REACH * 1.5,
		"the animals come around both players (%d and %d, the farthest %.0f cells from one)" % [near_a, near_b, farthest])
	_check(s.push_on(a) == Vector3.ZERO and s.push_on(Who.new()) == Vector3.ZERO,
		"no animal pushed anyone yet; one who is not playing is not pushed")
	clock.storm_wind = Storms.FULL
	var seen := {}
	for i in 4:
		s.step_storms(Storms.TICK)
		seen[s.storms.last_at] = true
	_check(seen.has(a.position) and seen.has(b.position) and seen.size() == 2, "the wind works around each player in turn")
	s.remove_player(a)
	_check(s.players == [b] and s.workshops == [shop_b], "a player removed leaves the rest")
	s.tick(0.1)
	_check(s.wildlife.people == [b], "the animals see only those still playing")


## The session makes the chunks within reach of each player a step at a time within a
## budget, nearest first, keeps a job across calls, makes a chunk whole on demand and
## forgets the chunks far from everyone; the counts of the work and the stages left go
## with it.
func _test_making() -> void:
	var gen := WorldGen.new(42, 40)
	var s := Session.new(gen.world, gen, Clock.new(), Rules.new(), Placed.new())
	var a := Survivor.new()
	a.body = Body.new()
	a.at = Vector3(8.0, 20.0, 8.0) * WorldData.CELL
	s.add_player(a, Workshop.new(a, s.placed, s.rules))
	var zones: Array[Vector2i] = s.zones()
	_check(zones.size() == 1 and zones[0] == Vector2i.ZERO, "the zone of a player is their chunk")
	var made: Array = []
	gen.made.connect(func(key: Vector2i, stage: int) -> void: made.append([key, stage]))
	var spent: int = s.make_chunks(1, 1, 1)
	_check(spent > 0 and s._gen_job != null and made.is_empty(), "a step is taken on a tiny budget, and the job waits for the next call")
	var calls := 1
	while s.stages_left(1) > 0 and calls < 100000:
		s.make_chunks(2000, 500, 1)
		calls += 1
	_check(s.stages_left(1) == 0 and gen.around(Vector2i.ZERO, 1, WorldGen.SHAPED) and gen.around(Vector2i.ZERO, 2, WorldGen.PLANTED)
		and gen.around(Vector2i.ZERO, 3, WorldGen.TERRAIN), "within reach 1 the chunks are shaped, around them planted, around those terrain (%d calls)" % calls)
	_check(made[0][0] == Vector2i.ZERO and made[0][1] == WorldGen.TERRAIN
		and made.any(func(m: Array) -> bool: return m[0] == Vector2i.ZERO and m[1] == WorldGen.SHAPED),
		"the player's own chunk is made first, and every stage is told")
	var work: Dictionary = s.take_work()
	_check(work.get("terrain", 0) > 0 and work.get("trees", 0) >= 0 and work.get("shapes", 0) > 0 and s.take_work().is_empty(),
		"the work is counted by kind and taken once")
	s.make_chunks(2000, 500, 1)
	_check(s._all_made and s._gen_job == null, "nothing is left to make around the player")
	var far := Vector2i(6, 6)
	s.make_chunk(far)
	_check(gen.needed(far).is_empty() and gen.stage_of(far) == WorldGen.SHAPED, "a chunk asked for is made whole with what it needs")
	s.forget_far(100)
	_check(gen.stage_of(far) == WorldGen.SHAPED and gen.stage_of(Vector2i.ZERO) == WorldGen.SHAPED,
		"nothing within Session.DROP of the player is forgotten")
	a.at = Vector3(16.0 * (Session.DROP + 2) + 8.0, 20.0, 8.0) * WorldData.CELL
	s.forget_far(100)
	_check(gen.stage_of(Vector2i.ZERO) == 0, "a player moved away: the chunk they left beyond DROP is forgotten")
	_check(gen.stage_of(Vector2i(Session.DROP + 2, 0)) == 0 and s.stages_left(1) > 0, "and the new place is still to make")
	s.remove_player(a)
	s.make_chunks(2000, 500, 1)
	_check(s.zones().is_empty() and s._all_made and s._gen_job == null, "with no player there is nothing to make")
