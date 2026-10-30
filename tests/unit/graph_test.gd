extends "res://tests/unit/test_case.gd"
## The content graph (src/shared/content/content_graph.gd): the full set comes to every item
## and recipe from the start by the rules of the hands; on bundles made for the test it finds
## each dead end of section 18 of the TZ (bundles.md): an axe made of logs only an axe gets,
## a workbench that needs a tool made at it, a kiln that needs metal from itself, a station
## that needs a tool only it makes, an item nothing gives, a plant whose seeds cannot be had,
## an animal whose food never grows; and its warnings: dead ends, stations of one recipe,
## twins, a loop of recipes that gives back more than it takes; and a station that stands
## in for another, set down with a tool.

const ContentGraph := preload("res://src/shared/content/content_graph.gd")

## The bundles of the test mod, each loaded with core alone: file -> records.
const DEAD := {
	"axe": {
		"materials": "- {id: trunk, title: Ствол, role: trunk, dig: axe, item: wood}\n- {id: crown, title: Крона, role: crown, dig: hand}\n",
		"items": "- {id: wood, title: Дерево, weight: 1, stack: 10}\n- {id: axe, title: Топор, weight: 1, stack: 1, tool: axe, power: 1}\n",
		"trees": "- id: big\n  title: Большое\n  leaves: broad\n  trunk: [4, 6]\n  crown: [2.0, 2.0, 2.0]\n  tints: [\"#336633\"]\n  log: wood\n",
		"biomes": "- id: woods\n  title: Лес\n  color: \"#336633\"\n  trees: {big: 1.0}\n  tree_chance: 0.5\n",
		"recipes": "- {id: axe, title: Топор, makes: axe, needs: {wood: 2}}\n",
	},
	"bench": {
		"items": "- {id: rod, title: Прут, weight: 0.5, stack: 20}\n- {id: bench, title: Верстак, weight: 5, stack: 1, prop: workbench}\n"
			+ "- {id: pick, title: Кирка, weight: 1, stack: 1, tool: pickaxe, power: 1}\n",
		"recipes": "- {id: bench, title: Верстак, makes: bench, needs: {rod: 2}, tool: pickaxe}\n- {id: pick, title: Кирка, makes: pick, needs: {rod: 1}, at: bench}\n",
		"starts": "- {id: core:default, patch: true, bag+: {_dead:rod: 10}}\n",
	},
	"kiln": {
		"items": "- {id: clod, title: Ком, weight: 1, stack: 20}\n- {id: oven, title: Печь, weight: 5, stack: 1, prop: kiln}\n- {id: bar, title: Слиток, weight: 1, stack: 10}\n",
		"recipes": "- {id: oven, title: Печь, makes: oven, needs: {clod: 4, bar: 1}}\n- {id: bar, title: Слиток, makes: bar, needs: {clod: 2}, at: oven}\n",
		"starts": "- {id: core:default, patch: true, bag+: {_dead:clod: 10}}\n",
	},
	"anvil": {
		"items": "- {id: chip, title: Щепа, weight: 0.1, stack: 20}\n- {id: anvil, title: Наковальня, weight: 9, stack: 1, prop: forge}\n"
			+ "- {id: blade, title: Клинок, weight: 1, stack: 1, tool: sword, power: 1}\n",
		"recipes": "- {id: anvil, title: Наковальня, makes: anvil, needs: {chip: 3}, tool: sword}\n- {id: blade, title: Клинок, makes: blade, needs: {chip: 1}, at: anvil}\n",
		"starts": "- {id: core:default, patch: true, bag+: {_dead:chip: 10}}\n",
	},
	"ammo": {
		"items": "- {id: powder, title: Порох, weight: 0.1, stack: 50}\n- {id: shot, title: Заряд, weight: 0.1, stack: 50}\n"
			+ "- {id: token, title: Знак, weight: 0.1, stack: 1, source: special}\n- {id: charm, title: Оберег, weight: 0.1, stack: 1, light: 1}\n",
		"recipes": "- {id: shot, title: Заряд, makes: shot, needs: {powder: 1}}\n- {id: charm, title: Оберег, makes: charm, needs: {token: 1}}\n",
	},
	"crop": {
		"items": "- {id: wheat_seed, title: Семя, weight: 0.1, stack: 50, sow: core:grass, crop: wheat}\n- {id: husk, title: Шелуха, weight: 0.1, stack: 50, fuel: true}\n",
		"plants": "- {id: wheat, title: Пшеница, kind: ears, gives: {husk: 1}}\n- {id: wild, title: Дикий колос, kind: ears, gives: {husk: 1}}\n",
		"creatures": "- id: goat\n  title: Коза\n  mass: 30\n  diet: [plants]\n  speed: 2\n  sight: 8\n  human_wariness: 0.5\n  active: day\n  likes: [wheat]\n",
	},
	"loop": {
		"items": "- {id: ore2, title: Руда, weight: 1, stack: 10, fuel: true}\n- {id: dust, title: Пыль, weight: 0.1, stack: 50, fuel: true}\n"
			+ "- {id: pebble_a, title: Галька, weight: 0.2, stack: 30}\n- {id: pebble_b, title: Голыш, weight: 0.2, stack: 30}\n"
			+ "- {id: wall, title: Стенка, weight: 2, stack: 10}\n",
		"recipes": "- {id: dust, title: Пыль, makes: dust, count: 3, needs: {ore2: 1}}\n- {id: ore2_from_dust, title: Руда, makes: ore2, needs: {dust: 2}}\n"
			+ "- {id: wall, title: Стенка, makes: wall, needs: {pebble_a: 1, pebble_b: 1}}\n",
		"starts": "- {id: core:default, patch: true, bag+: {_dead:ore2: 1, _dead:pebble_a: 5, _dead:pebble_b: 5}}\n",
	},
	# Not a dead end: the bench needs pegs made only at a bench, but a rack set down (with a
	# knife in the bag) stands in for it.
	"serve": {
		"items": "- {id: rod, title: Прут, weight: 0.5, stack: 20}\n- {id: knife, title: Нож, weight: 0.3, stack: 1, tool: knife}\n"
			+ "- {id: bench, title: Верстак, weight: 5, stack: 1, prop: workbench}\n- {id: peg, title: Колышек, weight: 0.1, stack: 20, fuel: true}\n"
			+ "- {id: rack, title: Стойка, weight: 4, stack: 1, prop: rack, serves: [bench], place_tool: knife}\n",
		"recipes": "- {id: knife, title: Нож, makes: knife, needs: {rod: 1}}\n- {id: rack, title: Стойка, makes: rack, needs: {rod: 2}}\n"
			+ "- {id: peg, title: Колышек, makes: peg, needs: {rod: 1}, at: bench}\n- {id: bench, title: Верстак, makes: bench, needs: {peg: 2}}\n",
		"starts": "- {id: core:default, patch: true, bag+: {_dead:rod: 10}}\n",
	},
}


func run() -> void:
	_test_links()
	_test_full_set()
	_test_dead_ends()


## Every reference field is a link the graph knows how to follow (LINKS).
func _test_links() -> void:
	var unknown := []
	for kind in Content.SCHEMAS:
		for ref: Array in Content.refs(kind):
			if not ContentGraph.LINKS.has("%s.%s" % [kind, ref[0]]):
				unknown.append("%s.%s" % [kind, ref[0]])
	_check(unknown.is_empty(), "the graph knows every reference field: %s" % [unknown])


## The content as it is: everything can be had from the start, and what a tool gets is
## as deep as the tool.
func _test_full_set() -> void:
	var g := ContentGraph.new()
	_check(g.errors.is_empty(), "the full set has no dead end and no cycle that blocks: %s" % [g.errors])
	for id in ["tools:stone_axe", "tools:stone_pickaxe", "tools:wooden_shovel", "tools:wooden_sword", "tools:stone_scythe",
			"tools:stone_sword", "tools:wooden_pickaxe", "tools:wooden_scythe", "tools:workbench", "tools:kiln", "materials:brick",
			"plants:grain", "plants:grass_seeds", "plants:flatbread", "tools:copper_axe", "tools:chest"]:
		_check(g.reached.has("items/" + id), "%s can be had from a new world" % id)
	var axe: int = g.reached.get("items/tools:stone_axe", -1)
	_check(g.reached.get("items/resources:log") == axe and g.how["items/resources:log"].via == "fell"
		and g.reached.get("items/materials:copper_ore") == g.reached.get("items/tools:stone_pickaxe")
		and g.reached.get("items/plants:raspberry_bush") == g.reached.get("items/tools:wooden_shovel"),
		"what a tool gets is as deep as the tool: logs by the axe, ore by the pickaxe, a bush dug out by the shovel")
	_check(g.reached.get("items/resources:branch") == 0 and g.reached.get("items/resources:stone") == 0
		and g.reached.get("items/materials:cord") == 1 and g.reached.get("tools:workbench", g.reached.get("items/tools:workbench")) == 2
		and g.reached.get("placed/core:campfire") == 0,
		"bare hands get branches and stone off scree, cord is one step and a workbench two; the campfire stands from the start")
	var said := "\n".join(g.warnings)
	_check("`plants:acorn` is a dead end" in said and "`plants:cone` is a dead end" in said
		and "`tools:forge` is the station of one recipe only" in said, "acorns and cones are dead ends, the forge makes one thing: %s" % said)
	_check(g.cycles().is_empty(), "no cycle blocks anything in the full set")
	_check(g.findings.size() == g.errors.size() + g.warnings.size() and g.findings.all(func(f: Dictionary) -> bool:
		return ContentGraph.CHECKS.has(f.check) and not f.keys.is_empty() and f.keys.all(func(k: String) -> bool: return g.records.has(k))),
		"each error and warning is a finding of a known check about records of the set")
	var log_from: Array = g.basis("items/resources:log")
	_check(log_from.has("items/tools:stone_axe") and log_from[0].begins_with("trees/")
		and g.basis("items/tools:stone_axe") == ["recipes/tools:stone_axe"]
		and g.basis("recipes/tools:stone_axe").has("placed/tools:workbench") and g.basis("recipes/tools:stone_axe").has("items/materials:cord"),
		"a log comes of a tree and the stone axe that fells it, the axe of its recipe, the recipe of cord and a workbench set down: %s" % [log_from])


## The dead ends of the TZ on bundles of a test mod, each loaded with core alone; core's
## campfire has no recipe there (the resources mod has it), so what is said of it is left out.
func _test_dead_ends() -> void:
	var before := Content.BUNDLES.duplicate()
	var mod := "res://content/_dead"
	_write(mod, "mod.yaml", "id: _dead\ntitle: Тупики\nversion: \"1\"\napi: 1\n")
	for b: String in DEAD:
		_write("%s/%s" % [mod, b], "bundle.yaml", "title: %s\n" % b)
		for kind: String in DEAD[b]:
			_write("%s/%s/data" % [mod, b], kind + ".yaml", DEAD[b][kind])
	Content.refresh()
	var errors := _errors_with("_dead/axe")
	_expect(errors, ["items: `_dead:wood` can never be had", "felled from tree `_dead:big`, lacking a tool that can fell it (`_dead:axe`)",
		"recipes: `_dead:axe` can never be made", "items: `_dead:axe` can never be had", "a blocking cycle"], 4,
		"an axe made of logs that only an axe gets is a blocking cycle")
	_check(errors.any(func(e: String) -> bool: return e.begins_with("a blocking cycle") and "`_dead:wood`" in e and "recipe `_dead:axe`" in e),
		"the cycle names the logs and the axe's recipe: %s" % [errors])
	_expect(_errors_with("_dead/bench"), ["recipes: `_dead:bench` can never be made: lacking a `pickaxe` tool",
		"recipes: `_dead:pick` can never be made: lacking `_dead:bench` set down", "a blocking cycle"], 5,
		"a workbench that needs a pickaxe made only at it is a blocking cycle")
	_expect(_errors_with("_dead/kiln"), ["recipes: `_dead:oven` can never be made: lacking `_dead:bar`", "a blocking cycle"], 5,
		"a kiln that needs a bar made only in it is a blocking cycle")
	_expect(_errors_with("_dead/anvil"), ["recipes: `_dead:anvil` can never be made: lacking a `sword` tool", "a blocking cycle"], 5,
		"a station that needs a tool made only at it is a blocking cycle")
	errors = _errors_with("_dead/ammo")
	_expect(errors, ["items: `_dead:powder` has no source", "recipes: `_dead:shot` can never be made", "items: `_dead:shot` can never be had"], 3,
		"shot of powder nothing gives can never be made")
	_check(not errors.any(func(e: String) -> bool: return "token" in e or "charm" in e),
		"an item of a special source is had, and what is made of it: %s" % [errors])
	_expect(_errors_with("_dead/crop"), ["items: `_dead:wheat_seed` has no source", "plants: `_dead:wheat` never grows in the world",
		"creatures: `_dead:goat` feeds on `_dead:wheat`, and none of them ever grows"], 3,
		"a crop whose seeds cannot be had never grows, and an animal that eats only it has no food")
	Mods.activate(["core", "_dead/loop"])
	var g := ContentGraph.new()
	var said := "\n".join(g.warnings)
	_check(Array(g.errors).all(func(e: String) -> bool: return "`core:campfire`" in e)
		and "gives back ×1.50 of `_dead:ore2`" in said and "`_dead:pebble_a`, `_dead:pebble_b` are alike" in said
		and "gives back ×1.50 of `_dead:dust`" in said and "`_dead:wall` is a dead end" in said and g.reached.get("items/_dead:dust") == 1,
		"a loop of recipes that gives back more than it takes, twins and a dead end are warnings: %s %s" % [g.errors, said])
	var errors_served := _errors_with("_dead/serve")
	g = ContentGraph.new()
	_check(errors_served.is_empty() and g.how["placed/_dead:bench"].via == "serves" and g.how["placed/_dead:rack"].needs == ["tool/knife"]
		and g.reached.get("placed/_dead:rack") == 1 and g.reached.get("items/_dead:peg") == 2 and g.reached.get("items/_dead:bench") == 3,
		"a station set down stands in for those it serves, and is set down with its tool: %s" % [errors_served])
	Mods.activate(before)
	_remove(mod)
	Content.refresh()
	Mods.rescan()
	_check(Content.problems.is_empty() and ContentGraph.new().errors.is_empty(), "the full set loads clean again")


## The graph's errors with core and `bundle` loaded, but those about core's campfire.
func _errors_with(bundle: String) -> Array:
	Mods.activate(["core", bundle])
	return Array(ContentGraph.new().errors).filter(func(e: String) -> bool: return not "`core:campfire`" in e)


## Checks that each of `wants` is in one of `errors` and that there are `count` errors.
func _expect(errors: Array, wants: Array, count: int, what: String) -> void:
	var missing := wants.filter(func(w: String) -> bool: return not errors.any(func(e: String) -> bool: return w in e))
	_check(missing.is_empty() and errors.size() == count, "%s (%d errors of %d; not said: %s): %s" % [what, errors.size(), count, missing, errors])


func _write(dir: String, file: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open("%s/%s" % [dir, file], FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Removes folder `dir` with all it holds.
func _remove(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove("%s/%s" % [dir, sub])
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute("%s/%s" % [dir, f])
	DirAccess.remove_absolute(dir)
