extends RefCounted
## The set of mods the game plays with. A world remembers its mods (WorldStore, the
## `mods` of world.json) and a new one takes the set chosen on «Новый мир»; `activate`
## makes that set the one loaded and fills the registries from it again, so
## `Mat.GRASS`, `Items.BY_ID`, `AiRules.SPECIES` and the rest describe the mods of
## the world being played. Materials are numbered in load order, so a world's cells
## keep their meaning as long as its set of mods does. `reload` reads the same set
## again (hot reload of the data; the meshes and sprites already built stay as they
## were until they are built again).

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Items := preload("res://src/shared/content/items.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")


## Every mod found under `content/`, core first (see Content.available).
static func available() -> Array:
	return Content.available()


## Loads `mods` (and nothing else) and refreshes the registries; returns the problems
## found. Does nothing when `mods` is the set already loaded.
static func activate(mods: Array) -> PackedStringArray:
	if mods == Content.MODS and Content.records("materials").size() > 0:
		return Content.problems
	Content.MODS = mods.duplicate()
	return reload()


## Reads the loaded set of mods again and refreshes the registries.
static func reload() -> PackedStringArray:
	Content.refresh()
	Mat.refresh()
	Items.refresh()
	Trees.refresh()
	Bushes.refresh()
	Plants.refresh()
	AiRules.refresh()
	Crafting.refresh()
	return Content.problems


## `mod` with everything it requires, requirements first, out of `all` (the mods
## available unless given).
static func closure(mod: String, all: Array = []) -> Array:
	if all.is_empty():
		all = available()
	var infos := {}
	var stack := [mod]
	while not stack.is_empty():
		var m: String = stack.pop_back()
		if infos.has(m) or not m in all:
			continue
		infos[m] = Content.info(m)
		for need in infos[m].get("requires", []):
			stack.append(need)
	return Content.order(infos)


## What mod `mod` requires, by its mod.yaml.
static func requires(mod: String) -> Array:
	return Content.info(mod).get("requires", [])


## The titles of `mods` from their mod.yaml, for the player.
static func titles(mods: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for m in mods:
		out.append(str(Content.info(m).get("title", m)))
	return out
