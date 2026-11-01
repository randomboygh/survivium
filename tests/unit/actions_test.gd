extends "res://tests/unit/test_case.gd"
## What the hands do to the world: felling, digging and building, the action in front, placed things.


func run() -> void:
	_test_felling()
	_test_front_choice()
	_test_world_actions()
	_test_placed()
	_test_start_camp()
	_test_station_flags()
	_test_recipe_fields()


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
	_check(who.inventory.count("tools:stone_axe") == 1 and who.said.has("Готово: %s" % axe.title), "near it the axe is made")
	for id in ["resources:flint", "materials:cord"]:
		who.inventory.add(id, 1)
	who.inventory.add("resources:branch", 2)
	var quick := Workshop.new(who, placed, Rules.of({"instant_craft": true}))
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
func _test_station_flags() -> void:
	var before := Content.BUNDLES.duplicate()
	var mod := "res://content/_k"
	DirAccess.make_dir_recursive_absolute(mod + "/data")
	_write_file(mod + "/mod.yaml", "id: _k\ntitle: K\nversion: \"1\"\napi: 1\n")
	_write_file(mod + "/data/items.yaml", "- {id: knife, title: Нож, weight: 0.3, stack: 1, tool: knife}\n"
		+ "- {id: stone_knife, title: Каменный нож, weight: 0.3, stack: 1, tool: knife}\n"
		+ "- {id: rack, title: Стойка, weight: 4, stack: 1, prop: rack, serves: [tools:workbench], place_tool: knife}\n"
		+ "- {id: crate, title: Ящик, weight: 4, stack: 1, prop: crate, storage: 4}\n"
		+ "- {id: odd, title: Странное, weight: 1, stack: 1, fire: true, tool: Big}\n"
		+ "- {id: shelf, title: Полка, weight: 1, stack: 1, prop: shelf, serves: [crate], place_tool: saw}\n")
	_write_file(mod + "/data/recipes.yaml", "- {id: crate, title: Ящик, makes: crate, needs: {resources:branch: 2}, at: crate}\n")
	Content.refresh()
	Mods.activate(Mods.all() + ["_k"])
	var said := "\n".join(Content.problems + Items.check() + Crafting.check())
	_check("_k:odd.tool: expected a lowercase word" in said and "`_k:odd`.fire: only a thing set down" in said
		and "`_k:shelf`.serves: `_k:crate` is no other station" in said and "`_k:shelf`.place_tool: no item is a `saw`" in said
		and "_k:crate.at: `_k:crate` is no station" in said,
		"a class is a lowercase word, flags are a thing's set down, a thing serves stations and is set down with a tool some item is; what stores is no station: %s" % said)
	_check(Tools.of("_k:knife") == Tools.HAND and Items.tool_title("knife") == "нож" and Items.tool_title("axe") == "топор"
		and Items.is_station("_k:rack") and not Items.is_station("_k:crate") and Items.most_storage() == 16,
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
		and who.said.back() == "Чтобы поставить, нужен инструмент: нож", "a rack is set down only with a knife in the bag")
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
	var by_rack := shop.why_not_repair(slot)
	who.position = Vector3(40.5, 2.0, 40.5) * WorldData.CELL
	_check(by_rack.begins_with("Не хватает") and shop.why_not_repair(slot) == "Чинят у станка: Верстак",
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
	_write_file(mod + "/data/items.yaml", "- {id: knife, title: Нож, weight: 0.3, stack: 1, tool: knife, durability: 3}\n"
		+ "- {id: mould, title: Форма, weight: 1, stack: 1}\n- {id: chips, title: Щепа, weight: 0.1, stack: 50, fuel: true}\n"
		+ "- {id: cup, title: Чашка, weight: 0.2, stack: 10}\n")
	_write_file(mod + "/data/recipes.yaml", "- {id: cup, title: Чашка, makes: cup, needs: {resources:branch: 1}, keeps: {mould: 1}, "
		+ "tools: [knife], wear: 1, also: [{item: chips, count: 2}, {item: resources:fiber, chance: 0.5}], time: 1}\n"
		+ "- {id: chips, title: Щепа, makes: chips, needs: {resources:branch: 1}, tools: [Saw], wear: 2}\n")
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
	_check(shop.why_not(cup) == "Нужен инструмент: нож", "a cup needs a knife in the bag: %s" % shop.why_not(cup))
	who.inventory.add("_r:knife", 1)
	_check(shop.why_not(cup) == "Не хватает: 1 Форма", "and a mould: %s" % shop.why_not(cup))
	who.inventory.add("_r:mould", 1)
	_check(shop.why_not(cup) == "" and shop.start(cup, 3) == 3 and who.inventory.count("resources:branch") == 2
		and who.inventory.count("_r:mould") == 1, "three cups are queued: a branch each is used up, the mould is kept")
	who.inventory.remove("_r:mould", 1)
	shop.update(0.01)
	_check(who.inventory.count("_r:cup") == 0 and shop.waiting() and shop.waits_for(cup) == "Форма",
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
		and who.said.has("Сломалось: Нож"), "a knife that lasts three swings breaks with the third cup")
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
