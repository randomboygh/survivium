extends "res://tests/unit/test_case.gd"
## What the hands do to the world: felling, digging and building, the action in front, placed things.


func run() -> void:
	_test_felling()
	_test_front_choice()
	_test_world_actions()
	_test_placed()


func _test_felling() -> void:
	# Two oaks side by side on flat ground; the first is cut a cell above its foot.
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Trees.place(w, 15, 1, 23, Trees.first(Trees.BROAD), rng)
	Trees.place(w, 31, 1, 23, Trees.first(Trees.BROAD), rng)
	var leaves_of_second := 0
	for z in range(14, 33):
		for x in range(24, 41):
			leaves_of_second += _bits(w.leaf_col(x, z))
	# Trunks have their own girth within the species' range, thinner going up, and the
	# bark of one wider than its cell stops a body beside it.
	var girths := {}
	for i in 40:
		var box := Trees.trunk_box(Trees.first(Trees.BROAD), Vector2i(2 * i + 1, 7), 0)
		girths[box.size.x] = true
		var g: Array = Trees.SPECIES[Trees.first(Trees.BROAD)].girth
		_check(box.size.x >= g[0] and box.size.x <= g[1], "a trunk's girth is in its species' range")
	_check(girths.size() > 2, "trunks differ in girth")
	_check(Trees.trunk_box(Trees.first(Trees.BROAD), Vector2i(15, 23), 6).size.x < Trees.trunk_box(Trees.first(Trees.BROAD), Vector2i(15, 23), 0).size.x,
		"a trunk thins going up")
	var box := Trees.trunk_box(Trees.first(Trees.BROAD), Vector2i(15, 23), 1)
	_check(w.blocks_part(16, 2, 23, 0.0, 0.1, 0.4, 0.6) == (box.end.x > 8), "thick bark east of a trunk is solid")
	var past := box.end.x + 1
	_check(not w.blocks_part(15 + past / 8, 2, 23, (past % 8) / 8.0, (past % 8 + 0.8) / 8.0, 0.4, 0.6),
		"a body further from the trunk is not stopped")
	var gone := Trees.fell(w, Vector3i(15, 2, 23), Vector2(0.0, 1.0))
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
	_check(Trees.fell(w, Vector3i(15, 0, 23), Vector2.ZERO).is_empty(), "only logs of noted trees are felled")


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
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, {"free_build": false})
	var who := Who.new()
	who.position = Vector3(30.5, 2.0, 30.5) * WorldData.CELL
	w.add_bush(Vector3i(30, 2, 29), Bushes.first(false))
	w.add_bush(Vector3i(30, 2, 28), Bushes.first(true))
	var berries := Vector3i(30, 2, 28)
	_check(actions.ripe(berries, Bushes.TYPES[Bushes.first(true)]) and actions.front_choice(who) == {"bush": berries},
		"bare hands go for the berries before the branches of a nearer bush")
	_check(WorldActions._rank(["plants:mushroom"]) < WorldActions._rank(["plants:acorn"])
		and WorldActions._rank(["plants:acorn"]) < WorldActions._rank(["resources:fiber"])
		and WorldActions._rank(["resources:branch"]) < WorldActions._rank([]), "food, then seeds, then the rest, then digging")
	w.remove_bush(Vector3i(30, 2, 29))
	w.remove_bush(berries)
	w.set_cell(30, 3, 29, Mat.DIRT)
	w.set_cell(30, 2, 29, Mat.DIRT)
	_check(actions.front_choice(who) == {"dig": [Vector3i(30, 3, 29)]}, "the action button digs at the head's level first")
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
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, {"free_build": false})
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
	Trees.place(w, 15, 2, 23, Trees.first(Trees.BROAD), rng)
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
	var picker := WorldActions.new(rock, {"season": 1, "day": 0}, {"free_build": false})
	_check(picker.can_mow(mossy, Tools.of("")) and picker.picking(mossy) != "", "bare hands can pick moss off stone")
	_check(picker.mow(who, [mossy] as Array[Vector3i]) and rock.get_cell(mossy.x, mossy.y, mossy.z) == Mat.STONE
		and not Grass.stone_moss(rock, mossy.x, mossy.y, mossy.z) and not rock.drops.is_empty()
		and (rock.drops.values()[0][0][0] as String).ends_with("moss"), "picking it gives moss and leaves the stone bare")
	_check(not picker.can_mow(mossy, Tools.of("")), "and there is no more to pick there")


## The rules of placed things and crafting run without the client: a workbench put
## down from the bag is solid and lets a stone axe be made near it, and a campfire is
## solid, burns the one who walks into it, is put out, lit again for a branch and
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
	var shop := Workshop.new(who, placed, {"tool_wear": false})
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
	_check(who.inventory.count("tools:stone_axe") == 1 and who.said.has("Готово: %s" % axe.title), "near it the axe is made")
	for id in ["resources:flint", "materials:cord"]:
		who.inventory.add(id, 1)
	who.inventory.add("resources:branch", 2)
	var quick := Workshop.new(who, placed, {"tool_wear": false, "instant_craft": true})
	_check(quick.start(axe) == 1, "another axe is started")
	quick.update(0.01)
	_check(who.inventory.count("tools:stone_axe") == 2, "with instant crafting it is made in a frame")
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
	var thrown := false
	for i in 30:
		cook.at = cook.body.step(cook.at, 1.0 / 30.0, false)
		cook.update(1.0 / 30.0)
		nearest = maxf(nearest, cook.at.x / WorldData.CELL + Body.HALF_WIDTH)
		thrown = thrown or cook.body.shove.x < 0.0
	_check(nearest <= 20.0 + 0.001, "a campfire is solid: walking into it stops at it")
	_check(cook.vitals.health < Vitals.MAX and cook.vitals.health >= Vitals.MAX - Vitals.BURN * 3.0
		and cook.vitals.hurt_by == "fire", "and pushing against it burns a little")
	_check(thrown, "and throws the body back")
	cook.body.move_input = Vector2.ZERO
	cook.at = Vector3(22.5, 2.0, 20.5) * WorldData.CELL
	_check(not placed.burns(cook.at), "where one comes back by it (Character.find_home) does not burn")
	cook.at = Vector3(22.46, 2.0, 21.0) * WorldData.CELL
	_check(placed.burns(cook.at), "standing close by its side burns")
	cook.at = Vector3(Placed.center(fire).x, 3.0 * WorldData.CELL, Placed.center(fire).z)
	_check(placed.burns(cook.at), "and standing on top of it")
	placed.put_out(fire)
	_check(not placed.burns(cook.at) and w.blockers.has(fire.cell), "a campfire put out does not burn, and is still solid")
	_check(not fire.lit and not placed.light(who, fire), "a campfire put out needs a branch to burn again")
	who.inventory.add("resources:branch", 1)
	_check(placed.light(who, fire) and fire.lit and who.inventory.count("resources:branch") == 0, "it is lit for a branch")
	placed.put_out(fire)
	_check(placed.destroy(fire) and not placed.things.has(fire), "and destroyed once it is out")
