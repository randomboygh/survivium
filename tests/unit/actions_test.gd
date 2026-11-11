extends "res://tests/unit/test_case.gd"
## What the hands do to the world: felling, digging and building, the action in front, placed things.

const Warmth := preload("res://src/shared/game/warmth.gd")


func run() -> void:
	_test_felling()
	_test_front_choice()
	_test_world_actions()
	_test_placed()
	_test_stairs_placed()
	_test_start_camp()
	_test_lights()
	_test_drinking()
	_test_station_flags()
	_test_recipe_fields()
	_test_furniture()
	_test_openings()


func _test_felling() -> void:
	# Two oaks side by side on flat ground; the first is cut a cell above its foot.
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Growth.place(w, 15, 1, 23, Trees.first(Trees.BROAD), rng)
	Growth.place(w, 31, 1, 23, Trees.first(Trees.BROAD), rng)
	var leaves_of_second := 0
	for z in range(14, 33):
		for x in range(24, 41):
			leaves_of_second += _bits(w.leaf_col(x, z))
	# Trunks have their own girth within the species' range, thinner going up, and the
	# bark of one wider than its cell stops a body beside it.
	var girths := {}
	for i in 40:
		var box := Growth.trunk_box(Trees.first(Trees.BROAD), Vector2i(2 * i + 1, 7), 0)
		girths[box.size.x] = true
		var g: Array = Trees.SPECIES[Trees.first(Trees.BROAD)].girth
		_check(box.size.x >= g[0] and box.size.x <= g[1], "a trunk's girth is in its species' range")
	_check(girths.size() > 2, "trunks differ in girth")
	_check(Growth.trunk_box(Trees.first(Trees.BROAD), Vector2i(15, 23), 6).size.x < Growth.trunk_box(Trees.first(Trees.BROAD), Vector2i(15, 23), 0).size.x,
		"a trunk thins going up")
	var box := Growth.trunk_box(Trees.first(Trees.BROAD), Vector2i(15, 23), 1)
	_check(w.blocks_part(16, 2, 23, 0.0, 0.1, 0.4, 0.6) == (box.end.x > 8), "thick bark east of a trunk is solid")
	var past := box.end.x + 1
	_check(not w.blocks_part(15 + past / 8, 2, 23, (past % 8) / 8.0, (past % 8 + 0.8) / 8.0, 0.4, 0.6),
		"a body further from the trunk is not stopped")
	var gone := Felling.fell(w, Vector3i(15, 2, 23), Vector2(0.0, 1.0))
	_check(not gone.is_empty() and gone[0] == Vector3i(15, 2, 23), "a cut trunk is felled from the cut")
	_check(not w.blocks_part(16, 2, 23, 0.0, 0.1, 0.4, 0.6), "bark of a felled trunk stops nothing")
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
	_check(kinds.has("resources:log") and kinds.has("resources:branch") and kinds.has("plants:acorn"), "a felled oak leaves logs, branches and acorns")
	_check(Felling.fell(w, Vector3i(15, 0, 23), Vector2.ZERO).is_empty(), "only logs of noted trees are felled")


func _bits(v: int) -> int:
	var n := 0
	while v != 0:
		v &= v - 1
		n += 1
	return n


## What the action button picks round the body: the most worth gathering first, then digging
## from the head down, under the feet only once both rings round it are dug.
func _test_front_choice() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var who := Who.new()
	who.position = Vector3(30.5, 2.0, 30.5) * WorldData.CELL
	w.add_bush(Vector3i(30, 2, 29), Bushes.first(false))
	w.add_bush(Vector3i(30, 2, 28), Bushes.first(true))
	var berries := Vector3i(30, 2, 28)
	_check(actions.ripe(berries, Bushes.TYPES[Bushes.first(true)]) and actions.front_choice(who) == {"bush": berries},
		"bare hands go for the berries before the branches of a nearer bush")
	_check(actions.front_kind(who) == "gather", "and the action button says it gathers")
	_check(WorldActions._rank(["plants:mushroom"]) < WorldActions._rank(["plants:acorn"])
		and WorldActions._rank(["plants:acorn"]) < WorldActions._rank(["resources:fiber"])
		and WorldActions._rank(["resources:branch"]) < WorldActions._rank([]), "food, then seeds, then the rest, then digging")
	w.remove_bush(Vector3i(30, 2, 29))
	w.remove_bush(berries)
	w.set_cell(30, 3, 29, Mat.DIRT)
	w.set_cell(30, 2, 29, Mat.DIRT)
	_check(actions.front_choice(who) == {"dig": [Vector3i(30, 3, 29)]}, "the action button digs at the head's level first")
	_check(actions.front_kind(who) == "dig", "and says it digs once nothing is left to gather")
	w.set_cell(30, 3, 29, Mat.AIR)
	_check(actions.front_choice(who) == {"dig": [Vector3i(30, 2, 29)]}, "then at the waist")
	w.set_cell(30, 2, 29, Mat.AIR)
	_check(actions.front_choice(who).get("dig", [])[0].y == 1 and actions.front_order(who)[-1] == Vector3i(30, 1, 30),
		"then the ground in front, the cell under the feet last")
	for z in range(28, 33):
		for x in range(28, 33):
			if x != 30 or z != 30:
				w.set_cell(x, 1, z, Mat.AIR)
	_check(actions.front_choice(who) == {"dig": [Vector3i(30, 1, 30)]}, "the cell under the feet once all around is dug")
	var body := Body.new()
	body.world = w
	body.on_ground = true
	var sunk := body.step(Vector3(20.5, 1.6, 20.5) * WorldData.CELL, 1.0 / 60.0, false) / WorldData.CELL
	_check(is_equal_approx(sunk.y, 2.0), "a body found in the ground stands up onto it (%.2f)" % sunk.y)


## The rules of the hands run on the world model alone, with a stand-in for the one who
## acts: what the server will do.
func _test_world_actions() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var changed: Array[Vector3i] = []
	actions.cell_changed.connect(func(c: Vector3i) -> void: changed.append(c))
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	who.item = "tools:wooden_shovel"
	var swing := actions.dig_at(who, Vector3i(10, 1, 10), Vector3i.UP)
	var dirt := 0
	for key in w.drops:
		for d: Array in w.drops[key]:
			dirt += WorldActions.count(d) if d[0] == "resources:dirt" else 0
	_check(not swing.is_empty() and w.get_cell(10, 1, 10) == Mat.AIR and dirt >= 1 and changed.has(Vector3i(10, 1, 10)),
		"a shovel digs dirt, which falls on the ground")
	_check(actions.dig_at(who, Vector3i(10, 0, 10), Vector3i.UP).is_empty(), "the bottom level is not dug")
	# Free building (a playtest switch) only spares the bag's blocks: what is dug still
	# falls, to fly into the bag (it gave nothing, 2026-11-07, and looked like pickup broken).
	actions.rules.free_build = true
	var before := 0
	for key in w.drops:
		for d: Array in w.drops[key]:
			before += WorldActions.count(d) if d[0] == "resources:dirt" else 0
	actions.dig_at(who, Vector3i(9, 1, 10), Vector3i.UP)
	var after := 0
	for key in w.drops:
		for d: Array in w.drops[key]:
			after += WorldActions.count(d) if d[0] == "resources:dirt" else 0
	actions.rules.free_build = false
	_check(w.get_cell(9, 1, 10) == Mat.AIR and after > before, "with free building digging still gives what it digs")
	who.item = "tools:wooden_sword"
	_check(not actions.dig_at(who, Vector3i(11, 1, 10), Vector3i.UP).is_empty() and w.get_cell(11, 1, 10) == Mat.DIRT,
		"a sword swings at the ground it cannot dig")
	# Grass with something tall on it, within reach: a sword cuts what is tall and
	# bare hands the grass itself, in a swing of one cell (the scythe's is an arc).
	var tall := Vector3i(-1, -1, -1)
	for z in range(13, 16):
		for x in range(6, 16):
			w.set_cell(x, 1, z, Mat.GRASS)
			if tall.x < 0 and Grass.has_tall(w, Vector3i(x, 1, z)) and not actions.too_far(who, Vector3i(x, 1, z), 6):
				tall = Vector3i(x, 1, z)
	_check(tall.x >= 0 and not actions.dig_at(who, tall, Vector3i.UP).is_empty() and not Grass.has_tall(w, tall)
		and w.get_cell(tall.x, 1, tall.z) == Mat.GRASS, "a sword cuts the tall grass it is aimed at")
	who.item = ""
	_check(not actions.dig_at(who, tall, Vector3i.UP).is_empty() and w.get_cell(tall.x, 1, tall.z) == Mat.DIRT,
		"bare hands cut the grass down to the ground")
	who.item = "resources:stone"
	who.inventory.add("resources:stone", 3)
	var placed := actions.place_at(who, Vector3i(12, 2, 10), Vector3i.UP, 40)
	_check(placed.get("placed", 0) == 1 and w.get_cell(12, 2, 10) == Mat.STONE and who.inventory.count("resources:stone") == 2,
		"a block is placed from the bag")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Growth.place(w, 15, 2, 23, Trees.first(Trees.BROAD), rng)
	who.position = Vector3(13.5, 2.0, 23.5) * WorldData.CELL
	who.item = "tools:stone_axe"
	var logs := w.log_col(15, 23)
	var hits := 0
	while w.log_col(15, 23) == logs and hits < 50:
		actions.chop(who, actions.trunk_cell(who, Vector2i(15, 23)))
		hits += 1
	_check(hits > 1 and hits <= Trees.SPECIES[Trees.first(Trees.BROAD)].hits and not w.drops.is_empty(), "an oak falls after its hits")
	# Moss grows on bare stone in damp patches, where world.gdshader draws it: bare
	# hands pick it, and the stone stays.
	var rock := WorldData.new(8, Vector2i(96, 96))
	var mossy := Vector3i(-1, -1, -1)
	var dry := 0
	for z in 96:
		for x in 96:
			rock.set_cell(x, 1, z, Mat.STONE)
	for z in 96:
		for x in 96:
			if Grass.stone_moss(rock, x, 1, z):
				if mossy.x < 0:
					mossy = Vector3i(x, 1, z)
			else:
				dry += 1
	_check(mossy.x >= 0 and dry > 0, "some stone is mossy, some is not")
	var picker := WorldActions.new(rock, {"season": 1, "day": 0}, Rules.new())
	_check(picker.can_mow(mossy, Tools.of("")) and picker.picking(mossy) != "", "bare hands can pick moss off stone")
	_check(picker.mow(who, [mossy] as Array[Vector3i]) and rock.get_cell(mossy.x, mossy.y, mossy.z) == Mat.STONE
		and not Grass.stone_moss(rock, mossy.x, mossy.y, mossy.z) and not rock.drops.is_empty()
		and (rock.drops.values()[0][0][0] as String).ends_with("moss"), "picking it gives moss and leaves the stone bare")
	_check(not picker.can_mow(mossy, Tools.of("")), "and there is no more to pick there")


## Stairs (a thing of one cell with `steps`) are set down in the cell in front, turned
## to rise away from the one who set them, solid by their steps; the next goes over air
## a level higher, and taking one up frees its cell; a chest set down looking east faces
## west and takes its turned cells.
func _test_stairs_placed() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	var who := Who.new()
	who.position = Vector3(10.5, 1.0, 12.5) * WorldData.CELL
	who.inventory.add("tools:stairs", 3)
	_check(placed.put_from_bag(who, "tools:stairs", -1, 40), "stairs are set down from the bag")
	var first: Dictionary = placed.things[-1]
	_check(first.cell == Vector3i(10, 1, 11) and first.turn == 0 and w.blockers.get(first.cell) is Array
		and is_equal_approx(w.blocker_part(10, 1, 11, 0.0, 1.0, 0.6, 1.0), 0.5) and is_equal_approx(w.blocker_top(10, 1, 11), 1.0),
		"in the cell in front, rising away to the north: the near step half a cell, the far one whole: %s" % [first])
	who.position = Vector3(10.5, 2.0, 11.5) * WorldData.CELL
	_check(placed.put_from_bag(who, "tools:stairs", -1, 40) and placed.things[-1].cell == Vector3i(10, 2, 10),
		"standing on them, the next stairs go a level up over air")
	who.position = Vector3(20.5, 1.0, 20.5) * WorldData.CELL
	who.facing = Vector2i(1, 0)
	_check(placed.put_from_bag(who, "tools:stairs", -1, 40) and placed.things[-1].turn == 1 and placed.things[-1].cell == Vector3i(21, 1, 20)
		and is_equal_approx(w.blocker_part(21, 1, 20, 0.0, 0.4, 0.0, 1.0), 0.5),
		"looking east, the stairs rise to the east, their low step to the west")
	_check(placed.take_up(who, placed.things[-1]) and not w.blockers.has(Vector3i(21, 1, 20)), "taken up, their cell is free")
	who.inventory.add("tools:chest", 1)
	_check(placed.put_from_bag(who, "tools:chest", -1, 40) and placed.things[-1].turn == 1
		and Placed.record(placed.things[-1]).turn == 1 and placed.cells_of(placed.things[-1]).size() == 4,
		"a chest set down looking east is turned to face west, and keeps its turn in the save")
	# A door in a gap two cells tall, set down looking north: shut, its leaf along the
	# north edge; a tap opens it to stand along the west edge, another shuts it.
	for y in range(1, 4):
		for x in [29, 31]:
			w.set_cell(x, y, 20, Mat.STONE)
	w.set_cell(30, 3, 20, Mat.STONE)
	who.facing = Vector2i(0, -1)
	who.position = Vector3(30.5, 1.0, 21.5) * WorldData.CELL
	who.inventory.add("tools:door", 1)
	_check(placed.put_from_bag(who, "tools:door", -1, 40), "a door is set into a gap two cells tall")
	var door: Dictionary = placed.things[-1]
	_check(door.cell == Vector3i(30, 1, 20) and Placed.is_door(door) and not door.open
		and w.blocker_part(30, 1, 20, 0.0, 1.0, 0.0, 0.2) > 0.0 and w.blocker_part(30, 2, 20, 0.0, 1.0, 0.0, 0.2) > 0.0
		and is_equal_approx(w.blocker_part(30, 1, 20, 0.0, 1.0, 0.5, 1.0), 0.0),
		"shut, it closes the gap along its north edge, two cells high: %s" % [door])
	_check(not _walks_north(w, Vector3(30.5, 1.0, 21.5), 19.5), "shut, a body walking north stops at it")
	who.position = Vector3(30.5, 1.0, 20.5) * WorldData.CELL
	_check(placed.swing(who, door) and door.open and Placed.record(door).open and not w.blockers.has(door.cell),
		"a tap opens it even standing in the doorway: open, it is solid nowhere")
	_check(_walks_north(w, Vector3(30.5, 1.0, 20.5), 19.5) and _walks_north(w, Vector3(30.5, 1.0, 21.5), 19.5),
		"from the doorway and from before it, a body walks through")
	who.position = Vector3(30.5, 1.0, 20.5) * WorldData.CELL
	_check(placed.swing(who, door) and not door.open, "and shuts it again")
	who.inventory.add("tools:window", 1)
	who.position = Vector3(30.5, 1.0, 22.5) * WorldData.CELL
	_check(placed.put_from_bag(who, "tools:window", -1, 40) and placed.things[-1].cell != door.cell and Placed.is_part(placed.things[-1]),
		"a window is set down too, and taken up at a tap")


## The rules of placed things and crafting run without the client: a workbench put
## down from the bag is solid and lets a stone axe be made near it, and a campfire is
## solid, burns only the one in its very middle, is put out, lit again for a branch and
## destroyed.
func _test_placed() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var placed := Placed.new()
	placed.world = w
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	who.inventory.add("tools:workbench", 1)
	_check(not placed.put_from_bag(who, "tools:workbench", -1, 1), "nothing is placed above the level cut")
	_check(placed.put_from_bag(who, "tools:workbench", -1, 40) and placed.things.size() == 1
		and who.inventory.count("tools:workbench") == 0, "a workbench is placed from the bag")
	var bench: Vector3i = placed.things[0].cell
	_check(bench.y == 2 and bench.z < 12 and w.blockers.has(bench), "in front of the one who placed it, and solid")
	var shop := Workshop.new(who, placed, Rules.new())
	var axe := Crafting.get_recipe("tools:stone_axe")
	for id in ["resources:flint", "materials:cord"]:
		who.inventory.add(id, 1)
	who.inventory.add("resources:branch", 2)
	_check(shop.start(axe) == 1, "a stone axe is started by the workbench")
	who.position = Vector3(40.5, 2.0, 40.5) * WorldData.CELL
	shop.update(axe.time + 1.0)
	_check(who.inventory.count("tools:stone_axe") == 0 and shop.waiting(), "away from the workbench the work waits")
	who.position = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	shop.update(axe.time + 1.0)
	_check(who.inventory.count("tools:stone_axe") == 1 and who.said.any(func(x: String) -> bool: return Lang.t(x) == "Done: Stone axe"), "near it the axe is made")
	for id in ["resources:flint", "materials:cord"]:
		who.inventory.add(id, 1)
	who.inventory.add("resources:branch", 2)
	var quick := Workshop.new(who, placed, Rules.of({"instant_craft": true}))
	_check(quick.start(axe) == 1, "another axe is started")
	quick.update(0.01)
	_check(who.inventory.count("tools:stone_axe") == 2, "with instant crafting it is made in a frame")
	placed.read_footprints()
	var fire := placed.put(Placed.CAMPFIRE, Vector3i(20, 2, 20))
	_check(placed.stations_near(Placed.center(fire), 1.0).has(Placed.CAMPFIRE), "a campfire that burns is a station")
	var cook := Survivor.new()
	cook.world = w
	cook.clock = Clock.new()
	cook.body = Body.new()
	cook.body.world = w
	cook.placed = placed
	cook.at = Vector3(18.0, 2.0, 21.0) * WorldData.CELL
	cook.update(0.5)
	_check(cook.vitals.health == Vitals.MAX, "standing away from a campfire does not burn")
	cook.body.move_input = Vector2(1.0, 0.0)
	var nearest := 0.0
	for i in 90:
		cook.at = cook.body.step(cook.at, 1.0 / 30.0, false)
		cook.update(1.0 / 30.0)
		nearest = maxf(nearest, cook.at.x / WorldData.CELL + Body.HALF_WIDTH)
	_check(nearest > 20.2 and nearest <= 20.5 + 0.001,
		"a campfire is solid in its middle only: walking into it stops at its logs, over its stones")
	_check(cook.vitals.health < Vitals.MAX and cook.vitals.hurt_by == "fire",
		"and walking into its logs burns: the flames are as big as what stops the body")
	cook.vitals.health = Vitals.MAX
	cook._burn_wait = 0.0
	cook.body.move_input = Vector2.ZERO
	cook.at = Vector3(22.5, 2.0, 20.5) * WorldData.CELL
	_check(not placed.burns(cook.at), "where one comes back by it (Character.find_home) does not burn")
	var mid: Vector3 = Placed.center(fire)
	cook.at = Vector3(mid.x + 1.05 * WorldData.CELL, 2.0 * WorldData.CELL, mid.z)
	_check(not placed.burns(cook.at), "nor standing on its stones a step off the logs")
	cook.at = Vector3(mid.x + 0.9 * WorldData.CELL, 3.0 * WorldData.CELL, mid.z)
	_check(placed.burns(cook.at), "standing over the edge of its logs burns")
	var hurt := cook.vitals.health
	cook.update(1.0 / 30.0)
	_check(cook.vitals.health < hurt and cook.vitals.hurt_by == "fire" and cook.body.shove.length() > 0.0,
		"a little, and throws the body back")
	placed.put_out(fire)
	_check(not placed.burns(cook.at) and w.blockers.has(fire.cell), "a campfire put out does not burn, and is still solid")
	_check(not fire.lit and not placed.light(who, fire), "a campfire put out needs a branch to burn again")
	who.inventory.add("resources:branch", 1)
	_check(placed.light(who, fire) and fire.lit and who.inventory.count("resources:branch") == 0, "it is lit for a branch")
	var rec := Items.get_item(Placed.CAMPFIRE)
	_check(is_equal_approx(fire.fuel, rec.fuel_start + Items.fuel_time("resources:branch")),
		"a new campfire has fuel for a while, and the branch it was lit for burns on with it")
	who.inventory.add("resources:log", 1)
	who.inventory.add("resources:branch", 1)
	fire.fuel = 100.0
	_check(placed.feed(who, fire) and who.inventory.count("resources:branch") == 0
		and is_equal_approx(fire.fuel, 100.0 + Items.fuel_time("resources:branch")), "a fire is fed a branch before a log")
	_check(placed.feed(who, fire) and who.inventory.count("resources:log") == 0, "and a log when there is no branch")
	who.inventory.add("resources:branch", 1)
	fire.fuel = rec.fuel_max - 10.0
	_check(not placed.feed(who, fire) and who.inventory.count("resources:branch") == 1, "a full one takes no more")
	var copy := Placed.new()
	copy.world = w
	copy.from_list(JSON.parse_string(JSON.stringify(placed.to_list())))
	var saved: Dictionary = copy.at(fire.cell)
	_check(not saved.is_empty() and is_equal_approx(saved.fuel, fire.fuel), "what a fire has left is saved")
	fire.fuel = 15.0
	placed.step(10.0)
	_check(fire.lit and is_equal_approx(fire.fuel, 5.0), "a fire burns its fuel down")
	placed.step(10.0)
	_check(not fire.lit and fire.fuel == 0.0 and not placed.stations_near(Placed.center(fire), 1.0).has(Placed.CAMPFIRE),
		"and goes out once it has burned: no station then")
	_check(placed.light(who, fire) and is_equal_approx(fire.fuel, Items.fuel_time("resources:branch")), "lit again, it burns the new branch")
	for i in 12:
		placed.step(10.0, 0.5)
	_check(fire.lit and fire.wet == 0.0, "a light rain does not put it out")
	for i in 5:
		placed.step(10.0, 1.0)
	_check(fire.lit, "fifty seconds of a downpour do not put it out yet")
	placed.step(10.0, 1.0)
	_check(not fire.lit and fire.fuel > 0.0, "a minute of a downpour under the open sky does, and leaves its fuel")
	who.inventory.add("resources:branch", 1)
	placed.light(who, fire)
	for z in range(fire.cell.z - 1, fire.cell.z + 3):
		for x in range(fire.cell.x - 1, fire.cell.x + 3):
			w.set_cell(x, 6, z, Mat.STONE)
	for i in 12:
		placed.step(10.0, 1.0)
	_check(fire.lit, "under a roof the rain does not reach it")
	placed.put_out(fire)
	_check(placed.destroy(fire) and not placed.things.has(fire), "and destroyed once it is out")


## The camp of a new world stands by the spawn even when its own spots are taken: a
## thing goes to the nearest free level spot, off the spawn and off the other thing;
## where none is near at the spawn's level, none is put.
func _test_start_camp() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var home := Vector3i(24, 2, 24)
	# Stone where the campfire and the chest would stand, water by the chest.
	for e: Dictionary in Starts.START.camp:
		for dz in 3:
			for dx in 3:
				w.set_cell(home.x + e.at[0] + dx - 1, 2, home.z + e.at[1] + dz - 1, Mat.STONE)
	w.set_cell(home.x + 6, 1, home.z + 2, Mat.WATER)
	var placed := Placed.new()
	placed.world = w
	placed.start_camp((Vector3(home) + Vector3(0.5, 0.0, 0.5)) * WorldData.CELL)
	var items := placed.things.map(func(e: Dictionary) -> String: return e.item)
	_check(items == Starts.START.camp.map(func(e: Dictionary) -> String: return e.item),
		"every thing of the camp is set down though its spot is taken: %s" % [items])
	for e: Dictionary in placed.things:
		var c: Vector3i = e.cell
		_check(c.y == 2 and maxi(absi(c.x - home.x), absi(c.z - home.z)) <= 12
			and (c.x > home.x + 1 or c.x + 1 < home.x - 1 or c.z > home.z + 1 or c.z + 1 < home.z - 1),
			"%s stands near the spawn on the ground, off the spawn: %s" % [e.item, c])
	var a: Vector3i = placed.things[0].cell
	var b: Vector3i = placed.things[1].cell
	_check(absi(a.x - b.x) >= 2 or absi(a.z - b.z) >= 2, "the two do not share cells")


## What a thing set down does goes by its item's flags, its class an open word (a mod of
## the test's own): a rack that serves the workbench makes the workbench's recipes and is
## set down only with a knife in the bag, a tool of a class the world does not know that
## works there as bare hands; a crate of four slots stores and is no station; tools are
## mended where the workbench's flag says, at the rack too. And what the checks say of
## flags out of place.
## A torch set down in front burns there what it has left and is gone; taken back, what it
## burned goes with it; it is saved with the things.
func _test_lights() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var placed := Placed.new()
	placed.world = w
	var who := Survivor.new()
	who.world = w
	who.at = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	var id := "tools:torch"
	var lasts := Items.burns(id)
	who.give(id, 2)
	who.burning[id] = [100.0]
	_check(Placed.is_light_item(id) and not Placed.is_light_item("tools:workbench"), "a torch is a light to set down")
	_check(not placed.put_light_from_bag(who, id, 1), "nothing is set down above the level cut")
	_check(placed.put_light_from_bag(who, id, 40) and placed.lights.size() == 1 and who.inventory.count(id) == 1
		and placed.things.is_empty(), "a torch is set down from the bag, apart from the things")
	var e: Dictionary = placed.lights[0]
	_check(e.cell == Vector3i(10, 2, 11) and is_equal_approx(e.burnt, 100.0) and who.burning[id].is_empty()
		and not w.blockers.has(e.cell), "on the cell in front, the burning one with what it burned, not solid")
	_check(placed.at(e.cell) == e and placed.light_spot(who, 40) == Vector3i(10, 2, 10), "found by its cell; the next goes farther")
	placed.step(10.0)
	_check(is_equal_approx(e.burnt, 110.0), "it burns where it stands")
	var copy := Placed.new()
	copy.world = w
	copy.from_list(JSON.parse_string(JSON.stringify(placed.to_list())))
	_check(copy.lights.size() == 1 and copy.lights[0].cell == e.cell and is_equal_approx(copy.lights[0].burnt, 110.0),
		"it is saved with the things")
	_check(placed.take_up(who, e) and placed.lights.is_empty() and who.inventory.count(id) == 2
		and who.burning[id] == [110.0], "taken back, it goes on burning from where it was")
	_check(placed.put_light_from_bag(who, id, 40), "set down again")
	placed.step(lasts)
	_check(placed.lights.is_empty() and who.inventory.count(id) == 1, "burned out, it is gone")


## An empty hand drinks at the water in front, an empty waterskin is filled there, a
## full one is not drunk by a body that is not thirsty.
func _test_drinking() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.WATER if z <= 11 else Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, Rules.new())
	var who := Survivor.new()
	who.world = w
	who.at = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	who.vitals.water = 30.0
	var done := actions.act_in_front(who, 40)
	_check(who.vitals.water == 30.0 + WorldActions.DRINK and done.get("stuff", -1) == Mat.WATER, "an empty hand drinks at the water in front")
	who.vitals.water = Vitals.MAX
	actions.act_in_front(who, 40)
	_check(who.vitals.water == Vitals.MAX, "a body that is not thirsty does not drink")
	who.give("tools:waterskin", 1)
	who.hands = ["tools:waterskin", ""]
	actions.act_in_front(who, 40)
	_check(who.inventory.count("tools:waterskin_full") == 1 and who.inventory.count("tools:waterskin") == 0, "an empty waterskin is filled")
	who.hands = ["", ""]
	who.vitals.water = 30.0
	_check(not actions.dig_at(who, Vector3i(10, 1, 11), Vector3i.UP).is_empty() and who.vitals.water > 30.0, "a tap on the water drinks too")


func _test_station_flags() -> void:
	var before := Content.BUNDLES.duplicate()
	var mod := "res://content/_k"
	DirAccess.make_dir_recursive_absolute(mod + "/data")
	_write_file(mod + "/mod.yaml", "id: _k\ntitle: K\nversion: \"1\"\napi: 1\n")
	_write_file(mod + "/data/items.yaml", "- {id: knife, title: Knife, weight: 0.3, stack: 1, tool: knife}\n"
		+ "- {id: stone_knife, title: Stone knife, weight: 0.3, stack: 1, tool: knife}\n"
		+ "- {id: rack, title: Rack, weight: 4, stack: 1, prop: rack, serves: [tools:workbench], place_tool: knife}\n"
		+ "- {id: crate, title: Crate, weight: 4, stack: 1, prop: crate, storage: 4}\n"
		+ "- {id: odd, title: Odd, weight: 1, stack: 1, fire: true, tool: Big}\n"
		+ "- {id: shelf, title: Shelf, weight: 1, stack: 1, prop: shelf, serves: [crate], place_tool: saw}\n")
	_write_file(mod + "/data/recipes.yaml", "- {id: crate, title: Crate, makes: crate, needs: {resources:branch: 2}, at: crate}\n")
	Content.refresh()
	Mods.activate(Mods.all() + ["_k"])
	var said := "\n".join(Content.problems + Items.check() + Crafting.check())
	_check("_k:odd.tool: expected a lowercase word" in said and "`_k:odd`.fire: only a thing set down" in said
		and "`_k:shelf`.serves: `_k:crate` is no other station" in said and "`_k:shelf`.place_tool: no item is a `saw`" in said
		and "_k:crate.at: `_k:crate` is no station" in said,
		"a class is a lowercase word, flags are a thing's set down, a thing serves stations and is set down with a tool some item is; what stores is no station: %s" % said)
	_check(Tools.of("_k:knife") == Tools.HAND and Lang.t(Items.tool_title("knife")) == "knife" and Lang.t(Items.tool_title("axe")) == "axe"
		and Items.is_station("_k:rack") and not Items.is_station("_k:crate") and Items.most_storage() == 48,
		"a knife works in the world as bare hands; a class is named by the last word its items share")
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var placed := Placed.new()
	placed.world = w
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	who.inventory.add("_k:rack", 1)
	_check(not placed.put_from_bag(who, "_k:rack", -1, 40) and placed.things.is_empty()
		and who.said.back() == "To place it you need a tool: knife", "a rack is set down only with a knife in the bag")
	who.inventory.add("_k:stone_knife", 1)
	_check(placed.put_from_bag(who, "_k:rack", -1, 40) and placed.things.size() == 1, "with a knife it is")
	var rack: Dictionary = placed.things[0]
	var near := placed.stations_near(Placed.center(rack), 1.0)
	_check(near.has("_k:rack") and near.has("tools:workbench") and rack.items == null and rack.lit,
		"a rack set down is a station and stands in for the workbench")
	var shop := Workshop.new(who, placed, Rules.of({"instant_craft": true}))
	for id in ["resources:flint", "materials:cord"]:
		who.inventory.add(id, 1)
	who.inventory.add("resources:branch", 2)
	_check(shop.start(Crafting.get_recipe("tools:stone_axe")) == 1, "a stone axe is started at the rack")
	shop.update(0.01)
	_check(who.inventory.count("tools:stone_axe") == 1, "and made there")
	var crate := placed.put("_k:crate", Vector3i(20, 2, 20))
	_check(crate.items != null and crate.items.slots.size() == 4 and not placed.stations_near(Placed.center(crate), 1.0).has("_k:crate")
		and not Placed.is_fire(crate) and Placed.is_fire({"item": Placed.CAMPFIRE}), "a crate holds four slots and is no station; the campfire burns by its flag")
	who.inventory.wear_tool("tools:stone_axe", 100)
	var slot := -1
	for i in who.inventory.slots.size():
		if who.inventory.slots[i] != null and who.inventory.slots[i][0] == "tools:stone_axe":
			slot = i
	var by_rack := Lang.t(shop.why_not_repair(slot))
	who.position = Vector3(40.5, 2.0, 40.5) * WorldData.CELL
	_check(by_rack.begins_with("Missing") and Lang.t(shop.why_not_repair(slot)) == "Repaired at a station: Workbench",
		"tools are mended at a station that repairs (the workbench), or one that stands in for it: %s" % by_rack)
	Mods.activate(before)
	for f in ["data/items.yaml", "data/recipes.yaml", "mod.yaml"]:
		DirAccess.remove_absolute(mod + "/" + f)
	DirAccess.remove_absolute(mod + "/data")
	DirAccess.remove_absolute(mod)
	Content.refresh()
	Mods.rescan()
	_check(Content.problems.is_empty() and Items.check().is_empty(), "the full set loads clean again")


## The fields of a recipe beyond what it uses up (a mod of the test's own): what it keeps is
## needed in the bag and stays there, also while the job is worked on; its tools are
## classes, one of each in the bag, worn by its `wear` an item made when wear is on; its
## by-products come by their chance, decided by the job's serial; and what the checks say
## of a class that is no word and of wear with no tool.
func _test_recipe_fields() -> void:
	var before := Content.BUNDLES.duplicate()
	var mod := "res://content/_r"
	DirAccess.make_dir_recursive_absolute(mod + "/data")
	_write_file(mod + "/mod.yaml", "id: _r\ntitle: R\nversion: \"1\"\napi: 1\n")
	_write_file(mod + "/data/items.yaml", "- {id: knife, title: Knife, weight: 0.3, stack: 1, tool: knife, durability: 3}\n"
		+ "- {id: mould, title: Mould, weight: 1, stack: 1}\n- {id: chips, title: Chips, weight: 0.1, stack: 50, fuel: true}\n"
		+ "- {id: cup, title: Cup, weight: 0.2, stack: 10}\n")
	_write_file(mod + "/data/recipes.yaml", "- {id: cup, title: Cup, makes: cup, needs: {resources:branch: 1}, keeps: {mould: 1}, "
		+ "tools: [knife], wear: 1, also: [{item: chips, count: 2}, {item: resources:fiber, chance: 0.5}], time: 1}\n"
		+ "- {id: chips, title: Chips, makes: chips, needs: {resources:branch: 1}, tools: [Saw], wear: 2}\n")
	Content.refresh()
	Mods.activate(Mods.all() + ["_r"])
	var said := "\n".join(Content.problems + Crafting.check())
	_check("_r:chips.tools: expected a lowercase word" in said and "_r:chips.wear: it needs no tool to wear" in said,
		"a class of tool is a lowercase word, and wear wants a tool: %s" % said)
	var cup := Crafting.get_recipe("_r:cup")
	var who := Who.new()
	var placed := Placed.new()
	placed.world = WorldData.new(4, Vector2i(16, 16))
	var shop := Workshop.new(who, placed, Rules.of({"tool_wear": true, "instant_craft": true}))
	who.inventory.add("resources:branch", 5)
	_check(Lang.t(shop.why_not(cup)) == "Needs a tool: knife", "a cup needs a knife in the bag: %s" % Lang.t(shop.why_not(cup)))
	who.inventory.add("_r:knife", 1)
	_check(Lang.t(shop.why_not(cup)) == "Missing: 1 Mould", "and a mould: %s" % Lang.t(shop.why_not(cup)))
	who.inventory.add("_r:mould", 1)
	_check(shop.why_not(cup) == "" and shop.start(cup, 3) == 3 and who.inventory.count("resources:branch") == 2
		and who.inventory.count("_r:mould") == 1, "three cups are queued: a branch each is used up, the mould is kept")
	who.inventory.remove("_r:mould", 1)
	shop.update(0.01)
	_check(who.inventory.count("_r:cup") == 0 and shop.waiting() and shop.waits_for(cup) == "Mould",
		"without the mould in the bag the work waits for it")
	who.inventory.add("_r:mould", 1)
	shop.update(0.01)
	var knife := -1
	for i in who.inventory.slots.size():
		if who.inventory.slots[i] != null and who.inventory.slots[i][0] == "_r:knife":
			knife = i
	_check(who.inventory.count("_r:cup") == 1 and who.inventory.count("_r:chips") == 2 and knife >= 0 and who.inventory.worn(knife) == 1,
		"with it a cup is made with two chips, and the knife wears by one")
	shop.update(0.01)
	shop.update(0.01)
	_check(who.inventory.count("_r:cup") == 3 and who.inventory.count("_r:chips") == 6 and who.inventory.count("_r:knife") == 0
		and who.said.has("Broke: Knife"), "a knife that lasts three swings breaks with the third cup")
	var fiber := 0
	for n in 3:
		fiber += Crafting.outputs(cup, n).get("resources:fiber", 0)
	var hits := 0
	for n in 200:
		if Crafting.comes(cup, n, 1):
			hits += 1
	_check(who.inventory.count("resources:fiber") == fiber and hits > 80 and hits < 120 and Crafting.comes(cup, 0, 0),
		"a by-product of chance 0.5 comes with about half the jobs, decided by their serials (%d of 200); one of chance 1 with each" % hits)
	Mods.activate(before)
	for f in ["data/items.yaml", "data/recipes.yaml", "mod.yaml"]:
		DirAccess.remove_absolute(mod + "/" + f)
	DirAccess.remove_absolute(mod + "/data")
	DirAccess.remove_absolute(mod)
	Content.refresh()
	Mods.rescan()
	_check(Content.problems.is_empty() and Crafting.check().is_empty(), "the full set loads clean again")


## Furniture (decision 163, 7А): its size by its model, turned, no station; a stool rests
## a body by it, a barrel keeps food longer, a cupboard stores, a rug is walked over.
func _test_furniture() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	for id in ["tools:table", "tools:stool", "tools:wooden_bed", "tools:cupboard", "tools:barrel", "tools:rug"]:
		_check(not Items.is_station(id), "%s is no station" % id)
	_check(Placed.size_of("tools:table") == 2 and Placed.size_of("tools:stool") == 1 and Placed.size_of("tools:cupboard") == 1
		and Placed.size_of("tools:rug") == 2 and Placed.size_of("tools:wooden_bed") == 2, "furniture takes the cells of its model")
	var stool := placed.put("tools:stool", Vector3i(10, 1, 10))
	_check(Placed.is_part(stool) and is_equal_approx(w.blocker_top(10, 1, 10), 0.5), "a stool is half a cell high, taken up at a tap")
	_check(placed.seat_near(Vector3(11.3, 1.0, 10.5) * WorldData.CELL) == 2.0 and placed.seat_near(Vector3(13.5, 1.0, 10.5) * WorldData.CELL) == 1.0,
		"by a stool the body rests twice as fast, a few cells off it does not")
	var v := Vitals.new()
	v.stamina = 10.0
	v.rest_rate = 2.0
	var calm := Vitals.new()
	calm.stamina = 10.0
	v.step(1.0, 0.0, false)
	calm.step(1.0, 0.0, false)
	_check(v.stamina - 10.0 > (calm.stamina - 10.0) * 1.9, "stamina comes back faster at the seat's rate")
	var rug := placed.put("tools:rug", Vector3i(20, 1, 20))
	_check(w.blocker_top(20, 1, 20) <= 0.2 and Placed.is_part(rug), "a rug lies flat, walked over")
	var cupboard := placed.put("tools:cupboard", Vector3i(30, 1, 30))
	_check(cupboard.items != null and cupboard.items.slots.size() == 24 and not Placed.is_part(cupboard)
		and w.blocker_top(30, 2, 30) > 0.5, "a cupboard two cells tall stores more than a chest")
	var barrel := placed.put("tools:barrel", Vector3i(34, 1, 30))
	var chest := placed.put("tools:chest", Vector3i(36, 1, 30))
	var food := ""
	for id in Items.IDS:
		if Items.get_item(id).get("spoils", 0.0) > 0.0:
			food = id
			break
	barrel.items.add(food, 1)
	chest.items.add(food, 1)
	placed.spoil(Items.get_item(food).spoils * 1.5, false)
	_check(barrel.items.count(food) == 1 and chest.items.count(food) == 0,
		"food in a barrel keeps when the same in a chest has gone off: %s" % food)


## Doors and windows of other sizes are set into gaps of their size, a double door swings
## both its leaves; a wide cupboard stores; a fireplace is set down cold, lit for fuel,
## warms, burns nobody pressing against it, cooks what a campfire does and is taken up
## only put out.
func _test_openings() -> void:
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var placed := Placed.new()
	placed.world = w
	placed.read_footprints()
	_check(Placed.size_of("tools:door_2x3") == 2 and Placed.size_of("tools:door_2x2") == 2 and Placed.size_of("tools:window_3x2") == 3
		and Placed.size_of("tools:window_1x2") == 1 and Placed.size_of("tools:window_2x1") == 2 and Placed.size_of("tools:window_2x2") == 2
		and Placed.size_of("tools:fireplace") == 2 and Placed.size_of("tools:wide_cupboard") == 2, "the new things take the cells of their models")
	# A wall along x at z 20, three high: a gap two wide and three high at x 14..15, one
	# three wide and two high at x 18..20.
	for x in range(10, 24):
		for y in range(1, 4):
			var door_gap := x >= 14 and x <= 15
			var window_gap := x >= 18 and x <= 20 and y <= 2
			if not door_gap and not window_gap:
				w.set_cell(x, y, 20, Mat.STONE)
	var who := Who.new()
	who.facing = Vector2i(0, -1)
	who.position = Vector3(14.9, 1.0, 21.5) * WorldData.CELL
	who.inventory.add("tools:door_2x3", 1)
	_check(placed.put_from_bag(who, "tools:door_2x3", -1, 40), "a double door is set into a gap of its size")
	var door: Dictionary = placed.things[-1]
	_check(door.cell == Vector3i(14, 1, 20) and placed.cells_of(door).size() == 2
		and w.blocker_part(14, 2, 20, 0.0, 1.0, 0.0, 0.2) > 0.0 and w.blocker_part(15, 2, 20, 0.0, 1.0, 0.0, 0.2) > 0.0
		and placed.cells_of(door).size() == 2 and w.blockers.get(door.cell).end.y > 2.5
		and is_equal_approx(w.blocker_part(14, 1, 20, 0.0, 1.0, 0.5, 1.0), 0.0),
		"shut, it closes both cells along their north edge, its leaves three high: %s" % [door])
	_check(not _walks_north(w, Vector3(15.0, 1.0, 21.5), 19.5), "shut, a body walking north stops at it")
	_check(placed.swing(who, door) and door.open and not w.blockers.has(Vector3i(14, 1, 20)) and not w.blockers.has(Vector3i(15, 1, 20))
		and _walks_north(w, Vector3(15.0, 1.0, 21.5), 19.5) and _walks_north(w, Vector3(14.5, 1.0, 21.5), 19.5),
		"a tap opens both leaves and the gap is walked through, in the middle and off it")
	_check(not placed.put_from_bag(_with(who, "tools:stool"), "tools:stool", -1, 40) or placed.things[-1].cell.z != 20,
		"nothing is set down in an open doorway")
	who.position = Vector3(15.0, 1.0, 22.5) * WorldData.CELL
	_check(Placed.center(door).is_equal_approx(Vector3(15.0, 1.5, 20.5) * WorldData.CELL), "it is tapped in the middle of its cells")
	who.position = Vector3(19.5, 1.0, 21.5) * WorldData.CELL
	who.inventory.add("tools:window_3x2", 1)
	_check(placed.put_from_bag(who, "tools:window_3x2", -1, 40) and placed.things[-1].cell == Vector3i(18, 1, 20)
		and placed.cells_of(placed.things[-1]).size() == 3 and Placed.is_part(placed.things[-1]),
		"a window three wide is set into its gap, taken up at a tap: %s" % [placed.things[-1]])
	var wide := placed.put("tools:wide_cupboard", Vector3i(30, 1, 10))
	_check(wide.items != null and wide.items.slots.size() == 48 and placed.cells_of(wide).size() == 2
		and w.blocker_top(30, 2, 10) > 0.5, "a wide cupboard two by two stores the most")
	var fire := placed.put("tools:fireplace", Vector3i(30, 1, 30))
	_check(not fire.lit and Placed.is_fire(fire) and Placed.is_hearth(fire) and placed.cells_of(fire).size() == 2,
		"a fireplace is set down cold, on the two cells of its row")
	who.inventory.add("resources:branch", 1)
	_check(placed.light(who, fire) and fire.lit and fire.fuel > 0.0, "it is lit for a branch and burns on it")
	var front := Placed.center(fire) + Vector3(0.0, -0.5, 1.0) * WorldData.CELL
	_check(Warmth.fire_heat(placed, front) > 0.0 and placed.burning(front + Vector3(0.0, 0.0, -0.45) * WorldData.CELL).is_empty(),
		"it warms the one before it and burns nobody pressing against it")
	_check(placed.stations_near(Placed.center(fire), 1.0).has(Placed.CAMPFIRE), "what is cooked at a campfire is cooked at it")
	_check(not placed.take_up(who, fire) and not placed.destroy(fire), "burning, it is not taken up")
	placed.put_out(fire)
	_check(placed.take_up(who, fire) and who.inventory.count("tools:fireplace") == 1, "put out, it is taken up whole")
	# The build mode: a door tapped into a wall with no gap cuts its opening, the blocks
	# falling as if dug; a stool set down where tapped.
	who.position = Vector3(11.5, 1.0, 22.5) * WorldData.CELL
	who.inventory.add("tools:door", 1)
	var before := 0
	for k in w.drops:
		before += w.drops[k].size()
	_check(placed.put_at(who, "tools:door", Vector3i(11, 1, 20), 40) and placed.things[-1].item == "tools:door"
		and w.get_cell(11, 1, 20) == Mat.AIR and w.get_cell(11, 2, 20) == Mat.AIR and w.get_cell(11, 3, 20) == Mat.STONE
		and who.inventory.count("tools:door") == 0, "a door tapped into a wall cuts its opening: %s" % [placed.things[-1]])
	var after := 0
	for k in w.drops:
		after += w.drops[k].size()
	_check(after > before, "and the blocks taken out lie on the ground")
	# A door aimed at the floor of a house it stands on (the bug of 2026-11-07: it sank
	# into the floor, cut as a wall's blocks are) stands on the floor.
	for z in range(36, 43):
		for x in range(30, 37):
			w.set_cell(x, 1, z, Mat.STONE)
	who.position = Vector3(33.5, 2.0, 40.5) * WorldData.CELL
	who.inventory.add("tools:door", 1)
	_check(placed.put_at(who, "tools:door", Vector3i(33, 1, 38), 40) and placed.things[-1].item == "tools:door"
		and placed.things[-1].cell.y == 2 and w.get_cell(33, 1, 38) == Mat.STONE,
		"a door aimed at the floor stands on it, the floor whole: %s" % [placed.things[-1]])
	who.position = Vector3(11.5, 1.0, 22.5) * WorldData.CELL
	_check(not placed.put_at(_with(who, "tools:stool"), "tools:stool", Vector3i(40, 1, 40), 40), "nothing is set down out of reach")
	_check(placed.put_at(who, "tools:stool", Vector3i(12, 1, 23), 40) and placed.things[-1].item == "tools:stool"
		and placed.cells_of(placed.things[-1]).has(Vector3i(12, 1, 23)), "a stool is set down where tapped")


## True when a body standing at `from` (in cells) walking north for two seconds gets north
## of z `past`.
func _walks_north(w: WorldData, from: Vector3, past: float) -> bool:
	var body := Body.new()
	body.world = w
	body.on_ground = true
	body.move_input = Vector2(0.0, -1.0)
	var at := from * WorldData.CELL
	for i in 120:
		at = body.step(at, 1.0 / 60.0, false)
	return at.z / WorldData.CELL < past


## `who` with one more `id` in the bag.
func _with(who, id: String):
	who.inventory.add(id, 1)
	return who
