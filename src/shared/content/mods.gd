extends RefCounted
## The set of bundles the game plays with. A world remembers its bundles (WorldStore, the
## `mods` of world.json; `of_world` reads them back, with the bundles that joined it since)
## and a new one takes the set chosen on «Новый мир»; `activate`
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
const Tools := preload("res://src/shared/content/tools.gd")
const Eras := preload("res://src/shared/content/eras.gd")

## Mods of older saves and settings that live on as bundles of another mod (the old sounds
## mod held the notes too).
const RENAMED := {"birds": ["animals/sparrow"], "sounds": ["sounds/nature", "sounds/player", "sounds/ui", "music"]}
## Mods split out of the base game: a world saved before the `content` mark of its
## world.json reached the number had their things in the base game, so it gets the mod.
const SPLITS := [[2, "plants"], [3, "tools"], [4, "sounds"], [4, "music"], [5, "materials"], [7, "resources"],
	[7, "materials"], [8, "biomes"]]
## The kinds of records a bundle may hold to join a world saved without it (`additive`):
## things to make and their sounds, nothing that changes the land or the numbers of its cells.
const ADDITIVE := ["items", "recipes", "eras", "starts", "sounds"]
## The bundles that may join a world (`additive`) there were before world.json kept the
## bundles a world knew (`known`): a world saved before knew them all, the torch only
## from `content` 9 on.
const OLD_ADDITIVE := ["materials/charcoal", "materials/cord", "music", "resources/fiber", "resources/wood",
	"sounds/nature", "sounds/player", "sounds/ui", "tools/axe", "tools/chest", "tools/forge", "tools/kiln",
	"tools/pickaxe", "tools/scythe", "tools/shovel", "tools/sword", "tools/torch", "tools/workbench"]


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
	Tools.refresh()
	Eras.refresh()


## `bundle` with everything it cannot do without, in load order, out of `all` (every
## bundle unless given); see Content.closure.
static func closure(bundle: String, all: Array = []) -> Array:
	return Content.closure(bundle, all)


## Which of `on` load and which are left out and why (see Content.resolve).
static func resolve(on: Array) -> Dictionary:
	return Content.resolve(on)


## Why `bundle` is left out of a set, out of `dropped` of `resolve`: what it needs, then
## what that one needs in turn while it is left out too, to the one not in the set at all
## (switched off, or not there): ["materials/cord", "resources/fiber"]. Empty when it is in.
static func why(bundle: String, dropped: Dictionary) -> Array:
	var out := []
	var b := bundle
	while dropped.has(b) and not dropped[b] in out and dropped[b] != bundle:
		b = dropped[b]
		out.append(b)
	return out


## Whether `bundle` only adds things to make (its records and patches all of ADDITIVE
## kinds): no cells, trees, bushes, plants, biomes or creatures, so it may join a world
## saved without it and the land stays the same.
static func additive(bundle: String) -> bool:
	var u: Dictionary = Content.universe().get(bundle, {})
	if u.is_empty():
		return false
	for kind: String in u.records:
		if not kind in ADDITIVE and not u.records[kind].is_empty():
			return false
	return true


## The bundles of a world saved with world.json `meta`, in the order of `all` (decision
## 4А, docs/specifications/BUNDLE_SYSTEM.md, section 14): the mods and bundles it lists (a
## mod stands for all its bundles, see expand; one from before mods were kept had every
## mod), a mod split out of the base game since (SPLITS), and a bundle new to it that only
## adds things to make (`additive`), when the world has a bundle of its mod and what the
## new one needs. A bundle the world knew (`known`, every bundle there was when it was
## saved; OLD_ADDITIVE before it kept them) and left out stays out; one with cells, trees
## or creatures never joins, so the land and the numbers of its cells stay.
static func of_world(meta: Dictionary) -> Array:
	var content := int(meta.get("content", 1))
	var mods: Array = Array(meta.get("mods", available())).filter(func(m) -> bool: return m is String)
	for split: Array in SPLITS:
		if content < split[0] and not split[1] in mods and split[1] in available():
			mods.insert(1, split[1])
	var bundles := expand(mods)
	var listed: Variant = meta.get("known")
	var known: Array = expand(listed) if listed is Array \
		else OLD_ADDITIVE.filter(func(b: String) -> bool: return content >= 9 or b != "tools/torch")
	var theirs := {}
	for b: String in bundles:
		theirs[mod_of(b)] = true
	var new := all().filter(func(b: String) -> bool:
		return theirs.has(mod_of(b)) and not b in bundles and not b in known and additive(b))
	if new.is_empty():
		return bundles
	var kept: Array = resolve(bundles + new).order
	return expand(bundles + new.filter(func(b: String) -> bool: return b in kept))


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
