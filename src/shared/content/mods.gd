extends RefCounted
## The set of bundles the game plays with. A world remembers its bundles (WorldStore, the
## `mods` of world.json) and a new one takes the set chosen on «Новый мир»; `activate`
## makes that set the one loaded and fills the registries from it again, so
## `Mat.GRASS`, `Items.BY_ID`, `AiRules.SPECIES` and the rest describe the bundles of
## the world being played. Materials are numbered in load order, so a world's cells
## keep their meaning as long as its set does. `rescan` reads everything under content/
## again (hot reload of the data; the meshes and sprites already built stay as they
## were until they are built again). A mod is a folder of bundles, see Content.

const Content := preload("res://src/shared/content/content.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Items := preload("res://src/shared/content/items.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const Eras := preload("res://src/shared/content/eras.gd")

## Mods of older saves and settings that live on as bundles of another mod (the old sounds
## mod held the notes too).
const RENAMED := {"birds": ["animals/sparrow"], "sounds": ["sounds/nature", "sounds/player", "sounds/ui", "music"]}


## Every mod found under `content/`, core first (see Content.available).
static func available() -> Array:
	return Content.available()


## The bundles of mod `mod` (the mod itself when it has no bundle folders).
static func bundles(mod: String) -> Array:
	return Content.bundles_of(mod)


## Every bundle of every mod.
static func all() -> Array:
	return Content.all_bundles()


static func mod_of(bundle: String) -> String:
	return Content.mod_of(bundle)


## Loads `bundles` (and nothing else) and refreshes the registries; returns a copy of the problems
## found. Does nothing when `bundles` is the set already loaded.
static func activate(bundles: Array) -> PackedStringArray:
	if bundles == Content.BUNDLES and Content.records("materials").size() > 0:
		return Content.problems.duplicate()
	Content.BUNDLES = bundles.duplicate()
	Content.load_all()
	_refresh_registries()
	return Content.problems.duplicate()


## Reads everything under content/ again and refreshes the registries; returns a copy of the
## problems found (a copy: the loader makes a new list with every set, and a method called on
## the list a static func returns crashes the engine). Not `reload`: Script.reload shadows it.
static func rescan() -> PackedStringArray:
	Content.refresh()
	_refresh_registries()
	return Content.problems.duplicate()


static func _refresh_registries() -> void:
	Mat.refresh()
	Items.refresh()
	Trees.refresh()
	Bushes.refresh()
	Biomes.refresh()
	Plants.refresh()
	AiRules.refresh()
	Crafting.refresh()
	Starts.refresh()
	Eras.refresh()


## `bundle` with everything it cannot do without, in load order, out of `all` (every
## bundle unless given); see Content.closure.
static func closure(bundle: String, all: Array = []) -> Array:
	return Content.closure(bundle, all)


## Which of `on` load and which are left out and why (see Content.resolve).
static func resolve(on: Array) -> Dictionary:
	return Content.resolve(on)


## Bundles out of a list of mods and bundles (a saved world's or the settings'): a mod
## stands for all its bundles, a renamed mod for what it became, the unknown are left
## out; in load order, each once.
static func expand(list: Array) -> Array:
	var every := all()
	var want := {}
	for name in list:
		if not name is String:
			continue
		if name in every:
			want[name] = true
		elif RENAMED.has(name):
			for b in RENAMED[name]:
				want[b] = true
		else:
			for b in every:
				if mod_of(b) == name:
					want[b] = true
	return every.filter(func(b: String) -> bool: return want.has(b))


## The title of mod `mod` from its mod.yaml.
static func mod_title(mod: String) -> String:
	return str(Content.info(mod).get("title", mod))


## The titles of `mods` from their mod.yaml, for the player.
static func titles(mods: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for m in mods:
		out.append(mod_title(m))
	return out


## The title of `bundle` from its bundle.yaml (or its mod's).
static func title(bundle: String) -> String:
	return str(Content.bundle_info(bundle).get("title", bundle))


## The mods of `bundles` for the player: the title of each mod besides core, with
## «(N из M)» when only some of its bundles are in; «только основа» when none.
static func summary(bundles: Array) -> String:
	var parts: PackedStringArray = []
	for mod in available():
		if mod == "core":
			continue
		var mine := Content.bundles_of(mod)
		var on := mine.filter(func(b: String) -> bool: return b in bundles).size()
		if on == 0:
			continue
		parts.append(mod_title(mod) if on == mine.size() else "%s (%d из %d)" % [mod_title(mod), on, mine.size()])
	return ", ".join(parts) if not parts.is_empty() else "только основа"
