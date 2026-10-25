extends "res://tests/unit/test_case.gd"
## The data: yaml, the schemas, mods and patches, items, tools, recipes, and the layer rule.


func run() -> void:
	_test_yaml()
	_test_content()
	_test_mods()
	_test_items()
	_test_tools()
	_test_crafting()
	_test_layers()


func _test_yaml() -> void:
	var yaml := Yaml.new()
	var doc: Variant = yaml.parse("""
# a comment
id: core
version: "0.1"
deps: [a, 'b c', 3, 2.5, true, ~]
colors:
  - "#aabbcc"   # not a comment
items:
  - id: grass
    title: Трава
    spread: {x: 1, y: -2.5}
  - id: dirt
    nested:
      - 1
      - 2
  -
    id: stone
empty:
flat:
- a
- "b: c"
""", "test.yaml")
	_check(yaml.error == "", "yaml parses: " + yaml.error)
	_check(doc is Dictionary and doc.get("id") == "core" and doc.get("version") == "0.1", "yaml reads scalars")
	_check(doc.get("deps") == ["a", "b c", 3, 2.5, true, null], "yaml reads flow lists")
	_check(doc.get("colors") == ["#aabbcc"], "yaml keeps # inside quotes")
	var items: Array = doc.get("items", [])
	_check(items.size() == 3 and items[0] == {"id": "grass", "title": "Трава", "spread": {"x": 1, "y": -2.5}},
		"yaml reads mappings in a list")
	_check(items.size() == 3 and items[1].get("nested") == [1, 2] and items[2] == {"id": "stone"},
		"yaml reads nested lists and items on their own line")
	_check(doc.get("empty") == null and doc.has("empty"), "an empty value is null")
	_check(doc.get("flat") == ["a", "b: c"], "a list may sit at its key's indent")
	for bad in ["a: [1, 2", "a: 1\n\tb: 2", "a: 1\na: 2", "- 1\n  - 2", "x: \"abc", "a: 1\n b: 2"]:
		yaml.parse(bad, "bad.yaml")
		_check(yaml.error.begins_with("bad.yaml:"), "yaml rejects %s" % bad.c_escape())


func _test_content() -> void:
	_check(Content.problems.is_empty(), "core content loads without problems")
	_check(Mat.check().is_empty() and AiRules.check().is_empty() and Trees.check().is_empty() and Bushes.check().is_empty(),
		"core content satisfies the engine")
	_check(Mat.AIR == 0 and Mat.IDS[Mat.GRASS] == "core:grass" and Mat.NAMES[Mat.GRASS] == "Трава", "materials get their indices")
	var planks := Mat.index("materials:planks")
	_check(Mat.PLACEABLE == [Mat.STONE, Mat.DIRT, planks, Mat.index("materials:brick"), Mat.BEACH, Mat.BANK, Mat.LOG],
		"hotbar order comes from the data across the mods: %s" % [Mat.PLACEABLE])
	_check(Mat.IDS[Mat.BEACH] == "resources:sand" and Mat.IDS[Mat.BANK] == "resources:clay" and Mat.IDS[Mat.SCREE] == "resources:scree"
		and Mat.IDS[Mat.ORE] == "materials:copper_ore" and Mat.IDS[Mat.LOG] == "plants:log" and Mat.IDS[Mat.LEAVES] == "plants:leaves"
		and Mat.of_role("beach", Mat.DIRT) == Mat.BEACH and Mat.COUNT == 13, "the engine finds materials by their roles")
	_check(Mat.shader_bits[Mat.GRASS] == 6 and Mat.shader_bits[Mat.BEACH] == 3 | Mat.DRAINS | (2 << Mat.GROUND_SHIFT)
		and Mat.shader_bits[Mat.STONE] == 1 | (3 << Mat.GROUND_SHIFT), "the shader's word per material comes from the data")
	_check(Mat.texture_path(Mat.BEACH) == "res://content/resources/soil/textures/sand.png" and ResourceLoader.exists(Mat.texture_path(Mat.LOG)),
		"a material's texture is a PNG of its mod")
	var old: PackedStringArray = ["core:air", "core:stone", "materials:sand", "nobody:glass"]
	_check(Mat.remap(old) == PackedByteArray([Mat.AIR, Mat.STONE, Mat.BEACH, Mat.STONE]) and Mat.remap(Mat.IDS).is_empty(),
		"cells of a save numbered in another order are translated, renamed ones by their new names, unknown ones to stone")
	_check(Mat.is_solid(Mat.STONE) and not Mat.is_solid(Mat.WATER) and not Mat.is_roof(Mat.LEAVES) and Mat.can_slope(Mat.BEACH),
		"material flags come from the data")
	_check(Trees.SPECIES[Trees.first(Trees.NEEDLES)].leaves == Trees.NEEDLES and Trees.SPECIES[Trees.first(Trees.BROAD)].tints[0] is Color, "trees get their looks")
	_check(Bushes.TYPES[Bushes.first(false)].berries == Color.BLACK and Bushes.TYPES[Bushes.first(true, 1)].spread is Vector3, "bushes get their looks")
	_check(AiRules.SPECIES["animals:wolf"].diet == ["meat"] and AiRules.SPECIES["animals:wolf"].sprite == "wolf", "creatures get their properties")
	# The checks catch what a mod author gets wrong.
	var before := Content.BUNDLES.duplicate()
	var mod := "res://content/_test"
	DirAccess.make_dir_recursive_absolute(mod + "/data")
	_write(mod + "/mod.yaml", "id: _test\ntitle: Test\nversion: \"1\"\napi: 1\n")
	_write(mod + "/data/materials.yaml", "- id: Bad Id\n  title: x\n- id: glass\n  title: Стекло\n  solid: maybe\n  weight: 3\n- id: glass\n  title: again\n")
	_write(mod + "/data/creatures.yaml", "- id: bear\n  title: Медведь\n  mass: -1\n  diet: [stones]\n  speed: 1\n  sight: 1\n  human_wariness: 2\n  active: dusk\n")
	_write(mod + "/data/trees.yaml", "- id: pine\n  title: Сосна\n  leaves: needles\n  trunk: [1]\n  crown: [1, 2, 3]\n  tints: []\n")
	_write(mod + "/data/recipes.yaml", "- id: rope\n  title: x\n  makes: materials:cord\n  needs: {resources:fiber: 0}\n- id: dust\n  title: y\n  makes: materials:cord\n  needs: {stone_dust: 1}\n")
	Content.BUNDLES.append("_test")
	Content.refresh()
	var found := {}
	for p in Content.problems:
		for what in ["Bad Id", "glass.solid", "glass.weight", "duplicate id", "bear.mass", "bear.diet",
				"bear.human_wariness", "bear.active", "pine.trunk", "pine.tints", "rope.needs", "`_test:stone_dust`"]:
			if what in p:
				found[what] = true
	_check(found.size() == 12, "the loader reports every kind of mistake (%d of 12): %s" % [found.size(), Content.problems])
	_check(Content.find("materials", "_test:glass").title == "Стекло", "a duplicate id within a mod is skipped")
	Content.BUNDLES.assign(before)
	for f in ["data/materials.yaml", "data/creatures.yaml", "data/trees.yaml", "data/recipes.yaml", "mod.yaml"]:
		DirAccess.remove_absolute(mod + "/" + f)
	DirAccess.remove_absolute(mod + "/data")
	DirAccess.remove_absolute(mod)
	Content.refresh()
	_check(Content.problems.is_empty(), "core content loads clean again")


## Mods are folders of bundles; a bundle loads after what its records refer to, a hard
## reference to a bundle left out leaves it out too, a soft one is dropped, patches wait
## for their records, and a world's set can leave bundles out (see content.gd, mods.gd).
## Whether every bundle of `order` comes after the bundles it depends on.
func _ordered(order: Array) -> bool:
	for i in order.size():
		for need in Content.deps(order[i]):
			if order.find(need) > i or order.find(need) < 0:
				return false
	return true


func _test_mods() -> void:
	var mods := Content.available()
	var all := Content.all_bundles()
	_check(mods.size() >= 3 and mods[0] == "core" and "animals" in mods and not "birds" in mods, "the mods under content/ are found, core first: %s" % [mods])
	_check(all[0] == "core" and "animals/wolf" in all and "animals/sparrow" in all and "plants/oak" in all and "music" in all and "tools/axe" in all and "sounds/ui" in all
		and Content.mod_of("animals/wolf") == "animals" and Content.mod_of("music") == "music" and not "sounds" in all,
		"a mod's bundles are its folders with a bundle.yaml, a mod without them is one bundle: %s" % [all])
	_check(Mods.title("animals/wolf") == "Волк" and Mods.title("plants/oak") == "Дуб" and Mods.title("music") == "Музыка" and Mods.title("tools/kiln") == "Печь для обжига"
		and Mods.mod_title("plants") == "Растения" and Mods.bundles("animals").size() == 16 and Mods.bundles("plants").size() == 21
		and Mods.bundles("resources") == ["resources/fiber", "resources/soil", "resources/stone", "resources/wood"]
		and Mods.bundles("materials").size() == 5 and Mods.bundles("tools").size() == 9 and Mods.bundles("sounds") == ["sounds/nature", "sounds/player", "sounds/ui"], "bundles have titles")
	var after_needs := Content.loaded.size() == all.size()
	for i in Content.loaded.size():
		for need in Content.deps(Content.loaded[i]):
			after_needs = after_needs and Content.loaded.find(need) < i
	_check(after_needs and Content.loaded[0] == "core"
		and Content.loaded.find("materials/cord") < Content.loaded.find("tools/workbench") and Content.loaded.find("tools/kiln") < Content.loaded.find("plants/ears")
		and Content.loaded.find("plants/wood") < Content.loaded.find("plants/oak") and Content.loaded.find("resources/wood") < Content.loaded.find("tools/workbench"),
		"every bundle loads after what its records refer to: %s" % [Content.loaded])
	_check(Content.dropped.is_empty() and Content.problems.is_empty(), "the full set loads whole")
	var ears := Mods.closure("plants/ears")
	_check(Mods.closure("animals/sparrow") == ["core", "animals/sparrow"] and Mods.closure("plants/oak") == ["core", "plants/wood", "plants/oak"]
		and Mods.closure("resources/soil") == ["core", "resources/soil"] and Mods.closure("materials/cord") == ["core", "resources/fiber", "materials/cord"]
		and _ordered(ears) and ears[0] == "core" and ears[-1] == "plants/ears" and "tools/kiln" in ears and "tools/workbench" in ears and "resources/wood" in ears and not "plants/oak" in ears,
		"a bundle's closure is it with what it cannot do without, in load order (a soft reference binds nothing, `requires` does): %s" % [ears])
	_check(Mods.expand(["core", "birds", "plants", "animals/wolf", "nobody"]) == ["core", "animals/sparrow", "animals/wolf"] + Mods.bundles("plants"),
		"a list of mods and bundles expands to bundles, a renamed mod to what it became: %s" % [Mods.expand(["core", "birds", "plants", "animals/wolf", "nobody"])])
	_check(Mods.summary(["core", "animals/wolf"] + Mods.bundles("plants")) == "Животные (1 из 16), Растения" and Mods.summary(["core"]) == "только основа"
		and Mods.summary(["core", "plants/oak"]) == "Растения (1 из 21)", "a set is summed up by mods")
	var before := Content.BUNDLES.duplicate()
	for m in ["_a", "_b", "_c", "_d"]:
		DirAccess.make_dir_recursive_absolute("res://content/%s/data" % m)
	_write("res://content/_a/mod.yaml", "id: _a\ntitle: A\nversion: \"1\"\napi: 1\nrequires: [_b]\n")
	_write("res://content/_b/mod.yaml", "id: _b\ntitle: B\nversion: \"1\"\napi: 1\nrequires: [core]\n")
	_write("res://content/_c/mod.yaml", "id: _c\ntitle: C\nversion: \"1\"\napi: 1\nrequires: [_missing]\n")
	_write("res://content/_d/mod.yaml", "id: _d\ntitle: D\nversion: \"1\"\napi: 1\n")
	_write("res://content/_b/data/creatures.yaml",
		"- id: animals:wolf\n  patch: true\n  speed: 1.5\n  diet+: [plants]\n- id: core:nobody\n  patch: true\n  speed: 1\n- id: animals:rabbit\n  patch: true\n  diet+: 3\n- id: animals:deer\n  patch: true\n  speed: 9\n")
	_write("res://content/_a/data/creatures.yaml", "- id: animals:wolf\n  patch: true\n  sight: 99\n")
	_write("res://content/_c/data/creatures.yaml", "- id: ghost\n  title: x\n  mass: 1\n  diet: [meat]\n  speed: 1\n  sight: 1\n  human_wariness: 0\n  active: any\n")
	# A recipe out of grain (a hard reference to the plants bundle) and a tree that gives
	# a cone (soft).
	_write("res://content/_d/data/recipes.yaml", "- id: porridge\n  title: x\n  makes: resources:fiber\n  needs: {plants:grain: 2}\n")
	_write("res://content/_d/data/trees.yaml", "- id: fir\n  title: x\n  leaves: needles\n  trunk: [1, 1]\n  crown: [2, 3, 4]\n  tints: [\"#224422\"]\n  seed: plants:cone\n")
	# And a bush whose fruit (soft) is a record nobody has.
	_write("res://content/_d/data/bushes.yaml", "- id: thorn\n  title: x\n  tint: \"#224422\"\n  cards: 3\n  rise: 0.3\n  spread: [0.2, 0.2, 0.2]\n  fruit: plants:nothing\n")
	Content.refresh()
	Mods.activate(["core", "animals/wolf", "animals/rabbit", "animals/sparrow", "_a", "_c", "_d", "_b"])
	_check(Content.loaded == ["core", "_b", "_a", "animals/rabbit", "animals/sparrow", "animals/wolf"] or Content.loaded == ["core", "animals/rabbit", "animals/sparrow", "animals/wolf", "_b", "_a"],
		"a bundle loads after what it requires and patches, one missing its requirement is left out: %s" % [Content.loaded])
	_check(Content.loaded.find("_b") > Content.loaded.find("animals/wolf") and Content.loaded.find("_a") > Content.loaded.find("_b"), "patches load after their records")
	var wolf: Dictionary = AiRules.SPECIES["animals:wolf"]
	_check(wolf.speed == 1.5 and wolf.diet == ["meat", "plants"] and wolf.sight == 99 and wolf.mod == "animals" and wolf.bundle == "animals/wolf",
		"patches change only the fields they give, `+` adds to a list, and stack: %s" % [wolf])
	_check(not AiRules.SPECIES.has("_c:ghost") and not AiRules.SPECIES.has("animals:cat") and Content.dropped.get("_c") == "_missing",
		"records of bundles left out are not loaded: %s" % [Content.dropped])
	_check(Content.dropped.get("_d") == "resources/fiber" and Crafting.get_recipe("_d:porridge").is_empty() and Trees.index("_d:fir") < 0,
		"a bundle whose hard reference names a record of a bundle not in the set is left out with that bundle as the reason: %s" % [Content.dropped])
	var sparrow: Dictionary = AiRules.SPECIES["animals:sparrow"]
	_check(sparrow.likes.is_empty() and Trees.SPECIES.is_empty(), "a soft reference to a record not loaded is dropped: the sparrow lives without ears or trees")
	var found := {}
	for p in Content.problems:
		for what in ["requires `_missing`", "core:nobody: patches", "rabbit.diet: `+`"]:
			if what in p:
				found[what] = true
	_check(found.size() == 3, "the loader reports a missing requirement, a patch of nothing and a bad `+` (%d of 3): %s" % [found.size(), Content.problems])
	_check(not Array(Content.problems).any(func(p: String) -> bool: return "deer" in p or "likes" in p or "cone" in p),
		"a patch of a record not loaded and a soft reference dropped are no problems: %s" % [Content.problems])
	var with_d := Mods.expand(["core", "plants/ears", "plants/spruce", "plants/wood", "tools", "materials", "resources"]) + ["_d"]
	Mods.activate(with_d)
	_check(Content.dropped.is_empty() and Content.problems.is_empty() and Crafting.get_recipe("_d:porridge").needs == {"plants:grain": 2}
		and Trees.SPECIES[Trees.index("_d:fir")].seed == "plants:cone" and Bushes.TYPES[Bushes.index("_d:thorn")].fruit == "",
		"with the bundle it needs in the set, the bundle loads whole, a soft reference to nothing dropped in silence: %s %s" % [Content.dropped, Content.problems])
	var d_closure := Mods.closure("_d", with_d)
	_check(_ordered(d_closure) and d_closure[0] == "core" and d_closure[-1] == "_d" and "plants/ears" in d_closure and "tools/kiln" in d_closure
		and "resources/fiber" in d_closure and not "plants/spruce" in d_closure,
		"a bundle's closure follows hard references through the bundles they lead to: %s" % [d_closure])
	Content.strict = true
	Mods.activate(Mods.all() + ["_d"])
	_check(Array(Content.problems).any(func(p: String) -> bool: return "thorn.fruit" in p and "plants:nothing" in p), "strict, a soft reference to nothing is a problem too: %s" % [Content.problems])
	Content.strict = false
	for m in ["_a", "_b", "_c", "_d"]:
		for f in DirAccess.get_files_at("res://content/%s/data" % m):
			DirAccess.remove_absolute("res://content/%s/data/%s" % [m, f])
		DirAccess.remove_absolute("res://content/%s/data" % m)
		DirAccess.remove_absolute("res://content/%s/mod.yaml" % m)
		DirAccess.remove_absolute("res://content/%s" % m)
	Content.refresh()
	# Without the plants mod the world knows no tree, bush or plant and grows nothing.
	Mods.activate(["core"])
	var bare := WorldData.new(8, Vector2i(8, 8))
	for x in 8:
		for z in 8:
			bare.set_cell(x, 0, z, Mat.GRASS)
	var bare_rng := RandomNumberGenerator.new()
	_check(Trees.SPECIES.is_empty() and Bushes.TYPES.is_empty() and Biomes.RECORDS.is_empty() and Biomes.tree(Biomes.pick(0.5, 0.5), 0.5) == -1 and Plants.TUFT == ""
		and Grass.kinds(bare, 3, 0, 3, Mat.GRASS, true, bare_rng).is_empty() and Grass.plants_on(bare, 3, 0, 3).is_empty(),
		"with core alone no tree, bush or plant is picked and grass grows nothing")
	# Nor any material but the engine's five: the generator lays dirt and stone for the roles.
	var bare_gen := WorldGen.new(20261018, 48)
	_check(Mat.COUNT == 5 and Mat.BEACH == -1 and Mat.LOG == -1 and bare_gen.beach == Mat.DIRT and bare_gen.scree == Mat.STONE
		and Mat.check().is_empty() and Trees.check().is_empty(), "with core alone the landscape roles fall back to dirt and stone")
	Mods.activate(before)
	var forest := Biomes.named("forest")
	var taiga := Biomes.named("taiga")
	_check(Biomes.pick(0.5, 0.5) == Biomes.named("meadow") and Biomes.pick(0.5, 0.8) == forest and Biomes.pick(0.25, 0.6) == taiga
		and Biomes.pick(0.1, 0.9) == Biomes.named("tundra") and Biomes.pick(0.8, 0.3) == Biomes.named("desert") and Biomes.SWAMP >= 0 and Biomes.ROCK >= 0
		and Biomes.pick(0.4, 0.4) == Biomes.named("pine_wood") and Biomes.pick(0.45, 0.6) == Biomes.named("birch_grove")
		and Biomes.pick(0.6, 0.2) == Biomes.named("steppe"),
		"a column's climate picks the biome whose windows hold it, the most specific first")
	_check(Biomes.tree(forest, 0.0) == Trees.index("plants:oak") and Biomes.tree(taiga, 0.0) == Trees.index("plants:spruce")
		and Biomes.tree(forest, 0.99) == Trees.index("plants:spruce") and Biomes.tree(Biomes.named("desert"), 0.0) == -1
		and Biomes.bush(taiga, 0.1) == Bushes.index("plants:blueberry") and Biomes.bush(taiga, 0.95) == Bushes.index("plants:shrub")
		and Biomes.bush(Biomes.named("meadow"), 0.1) == Bushes.index("plants:raspberry") and Plants.of_kind(Plants.KINDS.EARS) == Plants.EARS,
		"a biome grows its trees and bushes by their shares, nothing where the roll misses; plants are picked by kind")
	_check(Content.problems.is_empty() and AiRules.SPECIES.has("animals:sparrow") and AiRules.SPECIES["animals:wolf"].speed != 1.5,
		"the full set loads clean again")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_items() -> void:
	_check(Items.check().is_empty(), "core items satisfy the engine")
	_check(Items.dug[Mat.GRASS] == "resources:dirt" and Items.dug[Mat.STONE] == "resources:stone" and Items.dug[Mat.LEAVES] == "",
		"dug cells give their items")
	for m in Mat.PLACEABLE:
		_check(Items.get_item(Items.placed_by[m]).place == Mat.IDS[m], "an item places hotbar block %s" % Mat.IDS[m])
	_check(Items.get_item("campfire").id == "core:campfire" and Items.title("resources:branch") == "Ветка" and Items.canon("core:branch") == "resources:branch"
		and Items.canon("plants:acorn") == "plants:acorn", "a bare name is a core item, an old id is renamed")
	_check(Trees.SPECIES[Trees.first(Trees.BROAD)].seed == "plants:acorn" and Items.has(Trees.SPECIES[Trees.first(Trees.NEEDLES)].seed), "tree seeds are items")
	_check(Bushes.TYPES[Bushes.index("plants:raspberry")].fruit == "plants:raspberry" and Items.food(Bushes.TYPES[Bushes.first(true, 1)].fruit) > 0.0,
		"berries are food")
	_check(Bushes.TYPES[Bushes.first(false)].fruit == "" and Bushes.TYPES[Bushes.first(false)].twigs > 0, "a plain bush gives branches only")


func _test_tools() -> void:
	var hand := Tools.of("")
	var axe := Tools.of("tools:stone_axe")
	var pick := Tools.of("tools:stone_pickaxe")
	var shovel := Tools.of("tools:wooden_shovel")
	_check(hand == Tools.HAND and Tools.of("resources:branch") == Tools.HAND and axe.tool == "axe", "items that are no tools are bare hands")
	_check(Tools.can_dig(hand, Mat.DIRT) and Tools.can_dig(hand, Mat.LEAVES) and not Tools.can_dig(hand, Mat.STONE),
		"hands dig soft ground and leaves, not stone")
	_check(Tools.swing_time(hand, Mat.DIRT) > Tools.swing_time(shovel, Mat.DIRT), "a shovel digs faster than hands")
	_check(Tools.can_dig(pick, Mat.STONE) and Tools.can_dig(pick, Mat.ORE) and not Tools.can_dig(shovel, Mat.STONE),
		"stone and ore only with a pickaxe")
	_check(Tools.can_dig(axe, Mat.index("materials:planks")) and not Tools.can_dig(pick, Mat.LOG) and not Tools.can_dig(hand, Mat.WATER),
		"wood with an axe, water never")
	_check(Tools.why_not(hand, Mat.STONE) != "" and Tools.why_not(pick, Mat.STONE) == "", "a reason when a tool cannot dig")
	_check(Tools.step_of(Vector2(0, 1)) == Vector2i(0, 1) and Tools.step_of(Vector2(-0.7, -0.7)) == Vector2i(-1, -1),
		"facing snaps to 8 steps")
	var f := Vector3i(5, 3, 5)
	var order := Tools.front_cells(f, Vector2i(1, 0))
	_check(order.slice(0, 6) == [Vector3i(6, 4, 5), Vector3i(7, 4, 5), Vector3i(6, 4, 6), Vector3i(6, 4, 4), Vector3i(7, 4, 6), Vector3i(7, 4, 4)],
		"the action button digs at the head's level first: in front, beyond it, left and right of it, beyond those")
	_check(order[6] == Vector3i(6, 3, 5) and order[12] == Vector3i(6, 2, 5) and order.size() == 19,
		"then at the waist, then the ground in front of the feet")
	_check(order[18] == f + Vector3i(0, 2, 0) and not f + Vector3i.DOWN in order, "last over the head, not under the feet")
	var diagonal := Tools.front_ring(Vector2i(1, 1))
	_check(diagonal[0] == Vector3i(1, 0, 1) and diagonal[1] == Vector3i(2, 0, 2) and Vector3i(1, 0, 0) in diagonal \
		and Vector3i(0, 0, 1) in diagonal, "facing a diagonal, the sides are the columns touching both")
	_check(Tools.sweep(Vector3i(6, 2, 5), Vector2i(1, 0)) == [Vector3i(6, 2, 5), Vector3i(6, 2, 6), Vector3i(6, 2, 4)],
		"a scythe sweeps an arc in front")
	var sector := Tools.sector(Vector2i(0, 1))
	_check(sector[0] == Vector2i(0, 1) and Vector2i(1, 0) in sector and Vector2i(2, 1) in sector and not Vector2i(0, -1) in sector \
		and not Vector2i(1, -1) in sector, "trees and bushes are found ahead and beside, not behind")
	_check(Tools.use_of("") == "hand" and Tools.use_of("tools:stone_axe") == "tool" and Tools.use_of("resources:stone") == "place" \
		and Tools.use_of("plants:raspberry_bush") == "plant" and Tools.use_of("plants:grass_seeds") == "sow" \
		and Tools.use_of("core:campfire") == "prop" and Tools.use_of("plants:raspberry") == "eat" and Tools.use_of("resources:branch") == "hand",
		"what a held item is used for")
	var scythe := Tools.of("tools:stone_scythe")
	_check(Tools.mown(Mat.GRASS) == Mat.DIRT and Tools.mown(Mat.DIRT) == -1, "cutting grass leaves dirt")
	_check(Tools.mows(hand) and Tools.mows(scythe) and Tools.mows(Tools.of("tools:wooden_sword")) and not Tools.mows(shovel),
		"hands, a sword and a scythe cut grass")
	_check(Tools.mows_low(hand) and Tools.mows_low(scythe) and not Tools.mows_low(Tools.of("tools:wooden_sword")),
		"a sword cuts only what grows tall on grass, hands and a scythe the grass too")
	_check(shovel.area == 1 and pick.area == 1, "a tool digs one cell a swing")
	_check(scythe.area > 1 and not Tools.can_dig(scythe, Mat.DIRT), "a scythe mows wide and does not dig")
	_check(Items.has(Mat.RECORDS[Mat.GRASS].mow_gives.keys()[0]), "cut grass gives fibre")
	var rng := RandomNumberGenerator.new()
	_check(Plants.check().is_empty() and Plants.harvest([Plants.EARS, Plants.EARS], rng).get("plants:grain", 0) == 4,
		"ears give grain")
	_check(Tools.use_of("plants:grain") == "sow" and Items.get_item("plants:grain").crop == Plants.EARS, "grain is sown into ears")
	_check(Plants.harvest(["core:nothing"], rng).is_empty(), "an unknown plant gives nothing")
	_check(Trees.SPECIES[Trees.first(Trees.BROAD)].twigs > 0 and Trees.SPECIES[Trees.first(Trees.BROAD)].seeds > 0, "a standing oak gives branches and acorns by hand")
	var wall := Tools.area_cells(f, Vector3i(-1, 0, 0))
	_check(wall[0] == f and wall[1] == f + Vector3i.UP and wall.size() == 9, "a swing at a wall takes the cell above next (a passage)")
	for c in wall:
		_check(c.x == f.x, "a swing at a wall stays in the wall")
	var floor_cells := Tools.brush_cells(f, Vector3i.UP, 3)
	_check(floor_cells.size() == 9 and floor_cells[0] == f, "a brush starts at its centre")
	for c in floor_cells:
		_check(c.y == f.y and absi(c.x - f.x) <= 1 and absi(c.z - f.z) <= 1, "a brush on a floor lies flat around its centre")
	_check(Tools.brush_cells(f, Vector3i.BACK, 2).size() == 4 and Tools.brush_cells(f, Vector3i.BACK, 1) == [f], "brush sizes")
	_check(Tools.brush_shape(f, Vector3i.UP, Tools.BRUSHES[3]) == [f, f + Vector3i.UP], "the tall brush is two cells one on another")
	_check(Tools.brush_shape(f, Vector3i.UP, Tools.BRUSHES[4]) == [f], "the line brush places one cell at a time")
	_check(hand.reach < pick.reach and Tools.of("tools:wooden_sword").reach < pick.reach and Tools.PLACE_REACH >= pick.reach,
		"tools reach farther than hands and a sword")
	_check(Items.has(Mat.RECORDS[Mat.GRASS].bonus) and Mat.RECORDS[Mat.GRASS].bonus_chance > 0.0 and Mat.RECORDS[Mat.STONE].bonus == "",
		"grass sometimes gives fibre")
	_check(Trees.SPECIES[Trees.first(Trees.BROAD)].hits > axe.power, "an oak takes more than one swing")
	var b: Dictionary = Bushes.TYPES[Bushes.first(true)]
	_check(Items.get_item(b.item).plant == b.id, "a dug-out bush is an item that plants it again")
	var w := WorldData.new(2, Vector2i(2, 2))
	w.heap_drop("resources:dirt", Vector3(1.0, 1.0, 1.0), 1)
	w.heap_drop("resources:dirt", Vector3(1.1, 1.0, 1.0), 2)
	w.heap_drop("resources:stone", Vector3(1.1, 1.0, 1.0), 1)
	w.heap_drop("resources:dirt", Vector3(3.0, 1.0, 1.0), 1)
	var list: Array = w.drops[Vector2i.ZERO]
	_check(list.size() == 3 and list[0][3] == 3, "what is dug together lies in one heap")


func _test_crafting() -> void:
	_check(Crafting.check().is_empty(), "every recipe can be made, at a real station: %s" % Crafting.check())
	var have := Crafting.reachable()
	for id in ["tools:stone_axe", "tools:stone_pickaxe", "tools:wooden_shovel", "tools:wooden_sword", "tools:stone_scythe", "tools:stone_sword", "tools:wooden_pickaxe", "tools:wooden_scythe",
			"tools:workbench",
			"tools:kiln", "materials:brick", "plants:grain", "plants:grass_seeds", "plants:flatbread"]:
		_check(have.has(id), "%s can be had from a new world" % id)
	_check(Items.get_item(Mat.RECORDS[Mat.DIRT].bonus).id == "resources:flint", "digging soil now and then gives flint for the first tools")
	var cord := Crafting.get_recipe("materials:cord")
	var axe := Crafting.get_recipe("tools:stone_axe")
	var planks := Crafting.get_recipe("tools:planks")
	_check(cord.at == "" and cord.needs == {"resources:fiber": 3} and axe.at == "tools:workbench", "recipes come from the data")
	var inv := Inventory.new()
	var knows := Knowledge.new()
	knows.look_at(inv)
	_check(not knows.knows(cord) and knows.recipes().is_empty(), "nothing is known with an empty bag")
	var heard := []
	knows.learned.connect(func(id: String) -> void: heard.append(id))
	inv.add("resources:fiber", 7)
	knows.look_at(inv)
	_check(knows.knows(cord) and heard == ["materials:cord"], "a recipe is learned when its materials have been in the bag")
	var copy := Knowledge.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(knows.to_dict())))
	_check(copy.knows(cord) and copy.seen.has("resources:fiber"), "knowledge survives a save")
	_check(Crafting.why_not(cord, inv, {}) == "" and Crafting.why_not(axe, inv, {}).begins_with("Нужен станок"),
		"by hand anywhere, at a station only near it")
	_check(Crafting.why_not(planks, inv, {"tools:workbench": true}).begins_with("Нужен инструмент"), "planks need an axe in the bag")
	var q := CraftQueue.new()
	_check(q.add(cord, inv) and q.add(cord, inv) and not q.add(cord, inv), "the queue takes the materials of each job")
	_check(inv.count("resources:fiber") == 1, "materials are gone while queued")
	var stacks := q.cancel(1)
	for st in stacks:
		inv.add(st[0], st[1])
	_check(inv.count("resources:fiber") == 4 and q.jobs.size() == 1, "a cancel gives the materials back")
	var made := q.step(cord.time * 0.5, func(_r: Dictionary) -> bool: return false)
	_check(made.is_empty() and q.progress() == 0.0, "a job waits while it cannot be worked on")
	q.step(cord.time * 0.5, func(_r: Dictionary) -> bool: return true)
	_check(is_equal_approx(q.progress(), 0.5), "a job takes its time")
	made = q.step(cord.time, func(_r: Dictionary) -> bool: return true)
	_check(made.size() == 1 and made[0].makes == "materials:cord" and q.jobs.is_empty(), "a job is done when its time is up")
	var q2 := CraftQueue.new()
	q2.add(cord, inv)
	q2.step(0.5, func(_r: Dictionary) -> bool: return true)
	var q3 := CraftQueue.new()
	q3.from_dict(JSON.parse_string(JSON.stringify(q2.to_dict())))
	_check(q3.jobs.size() == 1 and is_equal_approx(q3.jobs[0].left, cord.time - 0.5), "the queue survives a save")


## The world model and the rules under src/shared are what the server will run, so
## nothing there may load a script from src/client.
func _test_layers() -> void:
	var bad: Array = []
	for path: String in _scripts("res://src/shared"):
		if FileAccess.get_file_as_string(path).contains("res://src/client/"):
			bad.append(path)
	_check(bad.is_empty(), "src/shared loads nothing from src/client: %s" % [bad])


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
