extends "res://tests/unit/test_case.gd"
## The acceptance of the bundle system (docs/specifications/BUNDLE_SYSTEM.md, section 15):
## what the TZ (bundles.md) wants added without touching the engine, written as data alone
## in a mod of the test's own, the way the mods' READMEs tell it, goes through the load, the
## content graph and play. Flax: a new resource and a seed with two sources each (a bush
## picked by hand and dug out with a shovel, a by-product of scutching), and another source
## of an old one (fibre scutched from flax); a loom: a tool of a new class (a knife), a
## station that stands in for the workbench, a recipe that keeps a shuttle, wears the knife
## and gives a by-product, an alternative recipe by hand, an era, and a patch of the start
## that gives the hands a longer reach and the bag fibre. Each bundle loads alone and goes
## when what it needs goes; the base game is as it was after.

const ContentGraph := preload("res://src/shared/content/content_graph.gd")
const Eras := preload("res://src/shared/content/eras.gd")

const MOD := "res://content/_ex"
## The test's mod: bundle -> data file -> its text.
const DATA := {
	"flax": {
		"items": "- {id: flax, title: Лён, weight: 0.1, stack: 50}\n"
			+ "- {id: flax_seed, title: Льняное семя, weight: 0.05, stack: 50, plant: flax_bush}\n",
		"bushes": "- id: flax_bush\n  title: Лён-долгунец\n  tint: \"#6f8f3a\"\n  berries: \"#c8b860\"\n  cards: 6\n  rise: 0.3\n"
			+ "  spread: [0.2, 0.3, 0.2]\n  fruit: flax\n  fruit_count: [2, 3]\n  item: flax_seed\n",
		"biomes": "- {id: biomes:meadow, patch: true, bushes+: {flax_bush: 0.1}}\n",
		"recipes": "- {id: scutch, title: Трепать лён, makes: resources:fiber, count: 2, needs: {flax: 1}, "
			+ "also: [{item: flax_seed, chance: 0.5}], process: refine, time: 1}\n",
	},
	"loom": {
		"eras": "- {id: weaving, title: Ткачество, order: 10, depth: 6}\n",
		"items": "- {id: knife, title: Нож, weight: 0.3, stack: 1, tool: knife, durability: 40, era: core:primitive}\n"
			+ "- {id: shuttle, title: Челнок, weight: 0.2, stack: 1}\n"
			+ "- {id: loom, title: Ткацкий станок, weight: 12, stack: 1, prop: loom, serves: [tools:workbench], era: weaving}\n"
			+ "- {id: cloth, title: Ткань, weight: 0.5, stack: 20}\n"
			+ "- {id: bandage, title: Повязка, weight: 0.1, stack: 10, heal: 10}\n",
		"recipes": "- {id: knife, title: Нож, makes: knife, needs: {resources:flint: 1, resources:branch: 1}}\n"
			+ "- {id: shuttle, title: Челнок, makes: shuttle, needs: {resources:branch: 1}, tools: [knife], wear: 1}\n"
			+ "- {id: loom, title: Ткацкий станок, makes: loom, needs: {resources:branch: 4, materials:cord: 2}, at: tools:workbench}\n"
			+ "- {id: cloth, title: Ткань, makes: cloth, needs: {resources:fiber: 4}, at: loom, tools: [knife], keeps: {shuttle: 1}, "
			+ "wear: 1, also: [{item: resources:fiber, count: 1, chance: 0.25}], time: 4}\n"
			+ "- {id: cloth_by_hand, title: Ткань руками, makes: cloth, needs: {resources:fiber: 6}, tools: [knife], time: 10}\n"
			+ "- {id: bandage, title: Повязка, makes: bandage, count: 2, needs: {cloth: 1}}\n",
		"starts": "- {id: core:default, patch: true, hand_reach: 10, bag+: {resources:fiber: 2}}\n",
	},
}


func run() -> void:
	var before := Content.BUNDLES.duplicate()
	_write_file(MOD + "/mod.yaml", "id: _ex\ntitle: Пример\nversion: \"1\"\napi: 1\n")
	for b: String in DATA:
		_write_file("%s/%s/bundle.yaml" % [MOD, b], "title: %s\n" % ("Лён" if b == "flax" else "Ткацкий станок"))
		for kind: String in DATA[b]:
			_write_file("%s/%s/data/%s.yaml" % [MOD, b, kind], DATA[b][kind])
	Content.refresh()
	_test_load(before)
	_test_graph(before)
	_test_play(before)
	_test_alone(before)
	Mods.activate(before)
	_remove(MOD)
	Content.refresh()
	Mods.rescan()
	_check(Content.problems.is_empty() and ContentGraph.new().errors.is_empty() and Items.get_item("_ex:loom").is_empty()
		and Starts.START.bag.is_empty() and Tools.HAND.reach == 8, "without the mod the base game loads clean, as it was")


## Data alone loads clean: records, the patches of a biome and of the start, the era, the
## class of the knife named from its item; the loom's bundle adds only things, recipes, an
## era and the start, so it would join a saved world, the flax's grows a bush over the land,
## so it would not.
func _test_load(before: Array) -> void:
	Mods.activate(before + ["_ex/flax", "_ex/loom"])
	var said := Content.problems + Items.check() + Crafting.check() + Starts.check() + Eras.check() + Bushes.check()
	_check(said.is_empty(), "the mod written by the READMEs loads with no problem: %s" % [said])
	_check(Items.tool_title("knife") == "нож" and Items.is_station("_ex:loom") and Bushes.index("_ex:flax_bush") >= 0
		and Biomes.of(Biomes.index("biomes:meadow")).bushes.has("_ex:flax_bush") and Eras.title(Eras.rank("_ex:weaving")) == "10. Ткачество",
		"a knife is a class of tool by its item's title, the loom a station, the flax a bush of the meadow, weaving an era")
	_check(Starts.START.bag.get("resources:fiber") == 2 and Tools.HAND.reach == 10 and Tools.HAND.power == 1,
		"a new world starts with fibre in the bag, and bare hands reach ten cells: %s" % [Tools.HAND])
	_check(Mods.additive("_ex/loom") and not Mods.additive("_ex/flax"),
		"the loom's bundle only adds things, recipes, an era and to the start (it joins old worlds), the flax's grows on the land (it does not)")


## The content graph reaches it all from the start of a new world, by its sources and the
## shallowest way, and derives the eras: the cloth comes by hand before the loom's era.
func _test_graph(before: Array) -> void:
	Mods.activate(before + ["_ex/flax", "_ex/loom"])
	var g := ContentGraph.new()
	var said := "\n".join(g.warnings)
	_check(g.errors.is_empty() and not "_ex:" in said, "the graph finds no dead end, no cycle and nothing to warn of in the mod: %s\n%s" % [g.errors, said])
	var seeds: Array = g.sources.get("items/_ex:flax_seed", []).map(func(w: Dictionary) -> String: return "%s %s" % [w.via, w.from])
	_check(seeds.has("dig_out bushes/_ex:flax_bush") and seeds.has("also recipes/_ex:scutch")
		and g.how["items/_ex:flax"].via == "gather" and g.reached.get("items/_ex:flax") == 0
		and g.sources["items/resources:fiber"].any(func(w: Dictionary) -> bool: return w.from == "recipes/_ex:scutch"),
		"flax is picked by hand off a bush the meadow grows, its seed is dug out or falls out of scutching, which makes fibre too: %s" % [seeds])
	_check(g.reached.get("items/_ex:knife") == 1 and g.reached.get("items/_ex:shuttle") == 2 and g.reached.get("placed/_ex:loom") == 3
		and g.reached.get("recipes/_ex:cloth") == 3 and g.reached.get("items/_ex:cloth") == 2 and g.how["items/_ex:cloth"].from == "recipes/_ex:cloth_by_hand"
		and g.reached.get("items/_ex:bandage") == 3,
		"a knife is one step, the loom three, cloth two by hand rather than four at the loom, bandages of it three")
	var weaving := Eras.rank("_ex:weaving")
	var primitive := Eras.rank("core:primitive")
	_check(g.era.get("items/_ex:loom") == weaving and g.era.get("recipes/_ex:cloth") == weaving and g.era.get("items/_ex:knife") == primitive
		and g.era.get("items/_ex:cloth") == primitive and g.era.get("items/_ex:bandage") == primitive and g.era.get("items/_ex:flax") == 0,
		"the loom opens weaving and its cloth is of it; cloth by hand comes earlier, in the knife's primitive era, as do bandages; flax in the first")


## In play: flax picked off its bush, the bush dug out for its seed, flax scutched, a knife,
## a shuttle and a loom made, the loom set down, cloth woven at it with the shuttle kept and
## the knife worn, and a workbench's recipe made at the loom once the workbench is gone.
func _test_play(before: Array) -> void:
	Mods.activate(before + ["_ex/flax", "_ex/loom"])
	var w := WorldData.new(40, Vector2i(48, 48))
	for z in 48:
		for x in 48:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var actions := WorldActions.new(w, {"season": 1, "day": 0}, {"free_build": false})
	var who := Who.new()
	who.position = Vector3(10.5, 2.0, 12.5) * WorldData.CELL
	var bush := Vector3i(10, 2, 11)
	w.add_bush(bush, Bushes.index("_ex:flax_bush"))
	_check(actions.gather(who, {"bush": bush}) and who.inventory.count("_ex:flax") >= 2, "bare hands pick flax off its bush in summer")
	who.item = "tools:wooden_shovel"
	_check(actions.gather(who, {"bush": bush}) and not w.bushes.has(bush), "a shovel digs the flax out")
	var seed := []
	for key: Vector2i in w.drops:
		for i in w.drops[key].size():
			if w.drops[key][i][0] == "_ex:flax_seed":
				seed = [key, i]
	_check(not seed.is_empty() and actions.pick_up(who, seed[0], seed[1]) and who.inventory.count("_ex:flax_seed") == 1,
		"and it lies as a seed to plant again")
	who.item = ""
	var placed := Placed.new()
	placed.world = w
	var shop := Workshop.new(who, placed, {"tool_wear": true, "instant_craft": true})
	var scutch := Crafting.get_recipe("_ex:scutch")
	var flax := who.inventory.count("_ex:flax")
	_check(shop.start(scutch, 2) == 2 and who.inventory.count("_ex:flax") == flax - 2, "two bundles of flax are scutched")
	shop.update(0.01)
	shop.update(0.01)
	var seeds := 1
	for n in 2:
		seeds += Crafting.outputs(scutch, n).get("_ex:flax_seed", 0)
	_check(who.inventory.count("resources:fiber") == 4 and who.inventory.count("_ex:flax_seed") == seeds
		and who.said.has("Новый рецепт: Ткань") and who.said.has("Новый рецепт: Ткань руками"),
		"into four fibres and the seeds that fall out, and fibre in the bag teaches both recipes of cloth: %s" % [who.said])
	who.inventory.add("resources:flint", 2)
	who.inventory.add("resources:branch", 8)
	who.inventory.add("materials:cord", 3)
	shop.start(Crafting.get_recipe("_ex:knife"))
	shop.update(0.01)
	var shuttle := Crafting.get_recipe("_ex:shuttle")
	_check(who.inventory.count("_ex:knife") == 1 and shop.start(shuttle) == 1, "a knife is made by hand, and a shuttle with it")
	shop.update(0.01)
	var loom := Crafting.get_recipe("_ex:loom")
	_check(who.inventory.count("_ex:shuttle") == 1 and shop.why_not(loom) == "Нужен станок: Верстак", "a loom wants a workbench")
	var bench := placed.put("tools:workbench", Vector3i(12, 2, 12))
	_check(shop.start(loom) == 1, "and is made at one")
	shop.update(0.01)
	_check(who.inventory.count("_ex:loom") == 1 and placed.put_from_bag(who, "_ex:loom", -1, 40) and placed.things.size() == 2,
		"the loom is set down from the bag")
	var cloth := Crafting.get_recipe("_ex:cloth")
	var job: int = shop.queue.serial
	_check(placed.take_up(who, bench) and shop.why_not(cloth) == "" and shop.start(cloth) == 1, "with the workbench taken up, cloth is woven at the loom")
	shop.update(0.01)
	var knife := -1
	for i in who.inventory.slots.size():
		if who.inventory.slots[i] != null and who.inventory.slots[i][0] == "_ex:knife":
			knife = i
	_check(who.inventory.count("_ex:cloth") == 1 and who.inventory.count("_ex:shuttle") == 1 and knife >= 0 and who.inventory.worn(knife) == 2
		and who.inventory.count("resources:fiber") == Crafting.outputs(cloth, job).get("resources:fiber", 0),
		"a cloth is woven, the shuttle kept, the knife worn by the shuttle and the cloth, a fibre back by chance")
	var axe := Crafting.get_recipe("tools:stone_axe")
	_check(shop.start(axe) == 1, "the loom stands in for the workbench: a stone axe is made at it")
	shop.update(0.01)
	_check(who.inventory.count("tools:stone_axe") == 1, "and comes out")


## Each bundle loads with the base game alone, with what it needs; the loom's falls out with
## the workbench it is made at and stands in for, and the «Моды» page says why.
func _test_alone(before: Array) -> void:
	for b: String in ["_ex/flax", "_ex/loom"]:
		Mods.activate(before + [b])
		var g := ContentGraph.new()
		_check(Content.problems.is_empty() and g.errors.is_empty(), "%s loads alone, its graph clean: %s %s" % [b, Content.problems, g.errors])
	var r := Mods.resolve(before.filter(func(b: String) -> bool: return b != "tools/workbench") + ["_ex/flax", "_ex/loom"])
	_check(r.dropped.get("_ex/loom") == "tools/workbench" and not r.dropped.has("_ex/flax") and Mods.why("_ex/loom", r.dropped) == ["tools/workbench"],
		"without the workbench the loom's bundle is left out, and the flax stays: %s" % [r.dropped])
