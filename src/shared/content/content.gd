extends RefCounted
## Mods, their bundles and their data files. A mod is a folder under `content/` with
## `mod.yaml`; what it adds comes in bundles, a folder per thing (`content/animals/wolf/`
## with `bundle.yaml`), each with its own `data/<kind>.yaml` (materials, items, creatures,
## trees, bushes, recipes, plants, sounds, starts, eras) and its pictures, models, textures and sounds
## beside them (`sprites/`, `models/`, `icons/`, `textures/`, `sounds/`: a sound's files are
## `<name>.wav`, or `<name>_1.wav` ... for its variants; what a bundle lacks is looked for in
## the mod's `common/`, see `asset`). A mod without bundle folders is one bundle with its
## files at its root. A bundle's id is `mod/bundle` (`animals/wolf`), or the mod's id for a
## mod of one bundle (`plants`). Records are namespaced by the mod whatever bundle holds
## them: `wolf` in `animals/wolf` is `animals:wolf`, and a reference without a namespace
## means the mod of the file it is written in (a patch of another mod's record too). A
## later bundle may replace a record of an earlier one by id when
## it says so (`replaces: true`; the same id again without it is a problem), or patch it:
## a record with `patch: true` changes only the fields it gives, and a key with a `+` at
## the end (`diet+: [plants]`, `needs+: {materials:cord: 1}`) adds to a list or an
## amounts field instead of replacing it. Every record may have the COMMON fields
## (`description`, `tags`, `provisional`) besides those of its kind.
##
## What a bundle depends on is read from its records: a reference to a record of another
## bundle (`needs: {materials:clay: 2}`) makes that bundle load first, and when the field
## is hard (the schema's default) and no bundle of the set has the record, the bundle is
## left out with the one that has it as the reason (`dropped`), so a world is made only
## of things that work. A field marked `soft` in the schema (`likes`, `seed`, `fruit`,
## `gives`, `era`, a creature's `biomes` and more: see SCHEMAS) only orders the load: the reference is
## dropped from the record when its target is not loaded, a problem only when `strict` (the
## validator checking the full set). A patch of another bundle's record loads after it and
## is skipped when it is not loaded. Roles (`land`, `prop`, `kind`, `roost`) bind nothing.
## `requires` (hard) and `wants` (order only) in mod.yaml or bundle.yaml add what the
## records do not show, as bundle or mod ids. BUNDLES is the set a world plays with (the
## world remembers it, see WorldStore); `all_bundles()` finds every bundle under
## `content/`. Switch sets through mods.gd, which also refreshes the registries.
##
## Records are checked against SCHEMAS on load: wrong types, values out of range,
## unknown fields, missing fields without a default and broken references are
## reported with the file and the id. The game loads what it can and reports the
## problems; `tools/validate.gd` runs the same checks in CI and fails on any. Names that
## break the naming rules (docs/specifications/BUNDLE_SYSTEM.md, section 3) are only
## `warnings`. Every reference field names its link (`rel`, one of RELATIONS: what the
## record is to the one it names) and, where an action makes it, which (`via`, ACTIONS),
## for the content graph.
## The registries (materials.gd, items.gd, ai_rules.gd, trees.gd, bushes.gd, biomes.gd,
## crafting.gd, plants.gd, starts.gd, eras.gd, tools.gd) read their kind with
## `records(kind)` when their class loads, so the rest of the code keeps using
## `Mat.GRASS`, `Trees.SPECIES` or `AiRules.SPECIES` as before.

const Yaml := preload("res://src/shared/content/yaml.gd")
## The mods' YAML files parsed when the game was built (tools/content_cache.gd, run by CI
## before an export; not in git): md5 of a file's text → its value. A file whose text is
## not in it (edited since, or no cache at all, as in the editor) is parsed as before.
const PARSED := "res://content_cache.bin"

const ROOT := "res://content"
## The bundles to load, as asked for; `loaded` has the order they were loaded in after
## their dependencies, without the ones left out: those are in `dropped` with the bundle
## they needed.
static var BUNDLES: Array = _all_on_disk()
static var loaded: Array = []
static var dropped := {}
## The validator's mode: a soft reference to nothing is a problem too.
static var strict := false

## Field types: bool, int, float, string, word (a lowercase word, an open class: a tool's,
## a station's; a mod may bring a new one), color ("#rrggbb"), vec3 ([x, y, z]),
## enum (one of `values`), list (of `of`, with `len` or at `least` so many items),
## ref:<kind> (an id of a record of that kind; an empty default means none; `soft` when
## the record lives without it; `rel` names the link and `via` the action, see RELATIONS),
## sound (the bare name of a sound, found at play time in
## the last loaded bundle that has one), amounts (a mapping of ids of `of` to how many,
## at least 1 each), shares (a mapping to shares 0..1: of the names in `keys`, or of ids of
## `of`), entries (a list of mappings, each with the fields of `fields`, checked like a
## record's: the camp of a start). `min`/`max` bound numbers, in a list each item. A field
## without `default` is required. `id` and `title` are implied for every kind.
const SCHEMAS := {
	"materials": {
		"solid": {"type": "bool", "default": true},
		"roof": {"type": "bool", "default": true},
		"slope": {"type": "bool", "default": false},
		"hotbar": {"type": "int", "min": 0, "default": 0},
		"corners": {"type": "enum", "values": ["sharp", "soft", "round"], "default": "sharp"},
		"role": {"type": "enum", "values": ["none", "beach", "bank", "scree", "snow", "peat", "salt", "ice", "ore", "trunk", "crown"], "default": "none"},
		# An ore's share of the veins in the rock, against the other ores' (role ore).
		"veins": {"type": "float", "min": 0.0, "default": 1.0},
		"priority": {"type": "int", "min": 0, "max": 15, "default": 0},
		"ground": {"type": "enum", "values": ["none", "soil", "sand", "rock"], "default": "none"},
		"drains": {"type": "bool", "default": false},
		"layers": {"type": "int", "min": 0, "max": 8, "default": 0},
		"texture": {"type": "string", "default": ""},
		"item": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "dig"},
		"dig": {"type": "enum", "values": ["hand", "shovel", "pickaxe", "axe", "none"], "default": "pickaxe"},
		"hardness": {"type": "int", "min": 0, "default": 1},
		"bonus": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "dig"},
		"bonus_chance": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"mow": {"type": "ref:materials", "default": "", "rel": "becomes", "via": "mow"},
		"mow_gives": {"type": "amounts", "of": "ref:items", "soft": true, "default": {}, "rel": "drops", "via": "mow"},
		"step": {"type": "sound", "default": ""},
		"hit": {"type": "sound", "default": ""},
	},
	"items": {
		"weight": {"type": "float", "min": 0.0},
		"stack": {"type": "int", "min": 1},
		"food": {"type": "float", "min": 0.0, "default": 0.0},
		"heal": {"type": "float", "min": 0.0, "default": 0.0},
		"place": {"type": "ref:materials", "default": "", "rel": "builds", "via": "place"},
		"model": {"type": "string", "default": ""},
		"icon": {"type": "string", "default": ""},
		# The tool's class: the engine knows the work in the world of Tools.WORLD_KINDS; any
		# other works there as bare hands and is asked for by recipes.
		"tool": {"type": "word", "default": "none"},
		"power": {"type": "int", "min": 0, "default": 0},
		"area": {"type": "int", "min": 1, "default": 1},
		"mows": {"type": "enum", "values": ["none", "tall", "all"], "default": "none"},
		"swing": {"type": "float", "min": 0.05, "default": 0.5},
		"plant": {"type": "ref:bushes", "default": "", "rel": "grows_into", "via": "plant"},
		"sow": {"type": "ref:materials", "default": "", "rel": "grows_into", "via": "sow"},
		"crop": {"type": "ref:plants", "default": "", "rel": "grows_into", "via": "sow"},
		"reach": {"type": "int", "min": 1, "default": 8},
		"durability": {"type": "int", "min": 0, "default": 0},
		# A weapon that shoots or is thrown: how far, in cells, and what it shoots (one of
		# it out of the bag a shot; none: the weapon itself is thrown).
		"range": {"type": "int", "min": 0, "default": 0},
		"ammo": {"type": "ref:items", "default": "", "rel": "consumes"},
		"repair": {"type": "amounts", "of": "ref:items", "soft": true, "default": {}, "rel": "repaired_with", "via": "repair"},
		# Set down on two by two cells, a thing of this class (its model, its solid parts); a
		# station unless it stores. What it does besides is in its flags: `storage` slots it
		# holds things in, `fire` it burns (put out, lit again with fuel, it burns a body),
		# `repairs` tools are mended at it, `serves` the stations it stands in for (their
		# recipes are made at it, tools mended if they mend them), `place_tool` the class of
		# tool it is set down with (one in the bag).
		"prop": {"type": "word", "default": "none"},
		"storage": {"type": "int", "min": 0, "default": 0},
		"fire": {"type": "bool", "default": false},
		"repairs": {"type": "bool", "default": false},
		"serves": {"type": "list", "of": "ref:items", "default": [], "rel": "serves"},
		"place_tool": {"type": "word", "default": "none"},
		"fuel": {"type": "bool", "default": false},
		"sprite": {"type": "string", "default": ""},
		"anim": {"type": "string", "default": "reach"},
		"hands": {"type": "int", "min": 1, "max": 2, "default": 1},
		"light": {"type": "float", "min": 0.0, "default": 0.0},
		# `special`: had in ways the content graph does not see (a quest, a trade), so it is
		# no item without a source.
		"source": {"type": "enum", "values": ["", "special"], "default": ""},
		# The era of progress the item opens (a station, the first tool of a new material, a new
		# material); the content graph derives the era of the rest and holds it to this one.
		"era": {"type": "ref:eras", "soft": true, "default": "", "rel": "in_era"},
	},
	"creatures": {
		"mass": {"type": "float", "min": 0.01},
		"diet": {"type": "list", "of": "enum", "values": ["plants", "meat"], "least": 1},
		"speed": {"type": "float", "min": 0.0},
		"sight": {"type": "float", "min": 0.0},
		"human_wariness": {"type": "float", "min": 0.0, "max": 1.0},
		"active": {"type": "enum", "values": ["day", "night", "any"]},
		"count": {"type": "int", "min": 0, "default": 0},
		"sprite": {"type": "string", "default": ""},
		"frames": {"type": "int", "min": 1, "default": 1},
		"flies": {"type": "bool", "default": false},
		"swims": {"type": "bool", "default": false},
		"ashore": {"type": "bool", "default": false},
		"hops": {"type": "bool", "default": false},
		"after_rain": {"type": "bool", "default": false},
		"flight": {"type": "float", "min": 1.0, "default": 28.0},
		"tints": {"type": "list", "of": "color", "default": []},
		"flock": {"type": "list", "of": "int", "len": 2, "min": 1, "default": [1, 1]},
		"roost": {"type": "enum", "values": ["ground", "trees"], "default": "ground"},
		"likes": {"type": "list", "of": "ref:plants", "soft": true, "default": [], "rel": "feeds_on"},
		"biomes": {"type": "list", "of": "ref:biomes", "soft": true, "default": [], "rel": "lives_in"},
		"calls": {"type": "sound", "default": ""},
		"alarm": {"type": "sound", "default": ""},
		# Hunting: the hits of power 1 it takes (0: it cannot be hit) and what its
		# body leaves (a carcass to butcher).
		"health": {"type": "int", "min": 0, "default": 0},
		"carcass": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "hunt"},
	},
	"trees": {
		"leaves": {"type": "enum", "values": ["broad", "needles"]},
		"shape": {"type": "enum", "values": ["", "round", "lobed", "column", "weeping", "umbrella", "cone", "palm"], "default": ""},
		"leaf": {"type": "enum", "values": ["", "pointed", "soft", "curly", "scales", "needles"], "default": ""},
		"blossom": {"type": "color", "default": null},
		"dead": {"type": "bool", "default": false},
		"trunk": {"type": "list", "of": "int", "len": 2, "min": 0},
		"girth": {"type": "list", "of": "int", "len": 2, "min": 2, "max": 24, "default": [6, 6]},
		"taper": {"type": "float", "min": 0.0, "default": 0.0},
		"crook": {"type": "int", "min": 0, "default": 0},
		"roots": {"type": "list", "of": "int", "len": 2, "min": 0, "default": [0, 0]},
		# How many texels up the trunk the roots stand on stilts (mangrove), 0 low roots.
		"stilts": {"type": "int", "min": 0, "max": 8, "default": 0},
		"branches": {"type": "float", "min": 0.2, "max": 2.0, "default": 1.0},
		"crown": {"type": "list", "of": "float", "len": 3, "min": 0.0},
		"tints": {"type": "list", "of": "color", "least": 1},
		"bark": {"type": "string", "default": ""},
		"bare": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"seed": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "gather"},
		"log": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "fell"},
		"twig": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "gather"},
		"hits": {"type": "int", "min": 1, "default": 4},
		"twigs": {"type": "int", "min": 0, "default": 0},
		"seeds": {"type": "int", "min": 0, "default": 0},
	},
	"bushes": {
		"tint": {"type": "color"},
		"berries": {"type": "color", "default": null},
		"berry_cards": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"cards": {"type": "int", "min": 1},
		"rise": {"type": "float", "min": 0.0},
		"spread": {"type": "vec3"},
		"small": {"type": "bool", "default": false},
		"fruit": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "gather"},
		"fruit_count": {"type": "list", "of": "int", "len": 2, "min": 0, "default": [0, 0]},
		"twigs": {"type": "int", "min": 0, "default": 0},
		"twig": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "gather"},
		"item": {"type": "ref:items", "default": "", "rel": "drops", "via": "dig_out"},
	},
	"biomes": {
		"where": {"type": "enum", "values": ["climate", "sea", "beach", "rock", "plateau", "swamp", "alpine", "glacier"], "default": "climate"},
		# The climate zone the biome belongs to (with climate 1 a zone's biomes lie side by
		# side): a label for the map, the reports and the test world, not a rule.
		"zone": {"type": "enum", "values": ["", "polar", "north", "temperate", "steppe", "hot", "tropic", "mountain"], "default": ""},
		"warmth": {"type": "list", "of": "float", "len": 2, "min": 0.0, "max": 1.0, "default": [0.0, 1.0]},
		"moisture": {"type": "list", "of": "float", "len": 2, "min": 0.0, "max": 1.0, "default": [0.0, 1.0]},
		"top": {"type": "enum", "values": ["grass", "dirt", "stone", "sand", "clay", "snow", "peat", "salt", "ice"], "default": "grass"},
		"stone_below": {"type": "float", "min": -1.0, "max": 1.0, "default": -1.0},
		"clay_above": {"type": "float", "min": -1.0, "max": 1.0, "default": 1.0},
		# The ground that shows where the soil noise is above clay_above.
		"clay_as": {"type": "enum", "values": ["grass", "dirt", "stone", "sand", "clay", "snow", "peat", "salt", "ice"], "default": "clay"},
		"dunes": {"type": "float", "min": 0.0, "default": 0.0},
		"trees": {"type": "shares", "of": "ref:trees", "soft": true, "default": {}, "rel": "spawns"},
		"tree_chance": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"groves": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		# Grounds besides grass trees grow on here (palms on the sand of a tropical beach).
		"trees_on": {"type": "list", "of": "enum", "values": ["dirt", "stone", "sand", "clay", "snow", "peat", "salt"], "default": []},
		"bushes": {"type": "shares", "of": "ref:bushes", "soft": true, "default": {}, "rel": "spawns"},
		"bush_sparsity": {"type": "int", "min": 0, "default": 0},
		# What bites in the water by this biome, caught with a rod from its shore: shares of
		# the items (the rest of a cast catches nothing).
		"fish": {"type": "shares", "of": "ref:items", "soft": true, "default": {}, "rel": "drops", "via": "fish"},
		"spawn": {"type": "bool", "default": false},
		"sandstorms": {"type": "bool", "default": false},
		"color": {"type": "color"},
		# The colour the biome's ground and water take instead of their own, by the names
		# of the `top` field and water (white sand and turquoise water by a tropical beach,
		# yellow grass in a savanna): the client tints the texture toward it.
		"tints": {"type": "colors", "keys": ["grass", "dirt", "sand", "clay", "snow", "peat", "salt", "water"], "default": {}},
	},
	# What a recipe makes and its by-products (`also`, each with its chance, decided by the
	# job: Crafting.outputs), what it uses up (`needs`), what must be in the bag and is not
	# used up (`keeps`), its station (`at`, or one that serves it), the classes of tools in
	# the bag (`tools`, one of each, worn by `wear` swings an item when wear is on), what
	# kind of work it is for the graph and the reports (`process`) and its time.
	"recipes": {
		"makes": {"type": "ref:items", "rel": "produces"},
		"count": {"type": "int", "min": 1, "default": 1},
		"also": {"type": "entries", "default": [], "fields": {
			"item": {"type": "ref:items", "rel": "produces"},
			"count": {"type": "int", "min": 1, "default": 1},
			"chance": {"type": "float", "min": 0.0, "max": 1.0, "default": 1.0},
		}},
		"needs": {"type": "amounts", "of": "ref:items", "rel": "consumes"},
		"keeps": {"type": "amounts", "of": "ref:items", "default": {}, "rel": "requires"},
		"at": {"type": "ref:items", "default": "", "rel": "requires_station"},
		"tools": {"type": "list", "of": "word", "default": []},
		"wear": {"type": "int", "min": 0, "default": 0},
		"process": {"type": "enum", "values": ["craft", "refine", "smelt", "cook"], "default": "craft"},
		"time": {"type": "float", "min": 0.0, "default": 2.0},
	},
	"sounds": {
		"variants": {"type": "int", "min": 1, "default": 1},
		"volume": {"type": "float", "min": 0.0, "max": 4.0, "default": 1.0},
		"loop": {"type": "bool", "default": false},
	},
	# How a new world starts (Starts): what bare hands do (Tools.HAND: their power, the
	# cells a swing takes, the seconds it lasts, the cells they reach, the grass they cut,
	# and how many times slower than they swing they dig soft ground), what the bag holds
	# and what stands by the spawn, each thing `at` so many cells east and south of it.
	"starts": {
		"hand_power": {"type": "int", "min": 0, "default": 1},
		"hand_area": {"type": "int", "min": 1, "default": 1},
		"hand_swing": {"type": "float", "min": 0.05, "default": 0.45},
		"hand_reach": {"type": "int", "min": 1, "default": 8},
		"hand_mows": {"type": "enum", "values": ["none", "tall", "all"], "default": "all"},
		"hand_slow": {"type": "float", "min": 1.0, "default": 2.0},
		"bag": {"type": "amounts", "of": "ref:items", "default": {}, "rel": "starts_with"},
		"camp": {"type": "entries", "default": [], "fields": {
			"item": {"type": "ref:items", "rel": "starts_with"},
			"at": {"type": "list", "of": "int", "len": 2},
		}},
	},
	# The eras of progress (Eras): their order, from 0, and the most steps of making from
	# the start their things are expected to take (0: not checked). A label the content
	# graph checks: it locks nothing in play.
	"eras": {
		"order": {"type": "int", "min": 0},
		"depth": {"type": "int", "min": 0, "default": 0},
	},
	"plants": {
		"kind": {"type": "enum", "values": ["tuft", "tall_grass", "flowers", "herbs", "ears", "reeds", "moss",
			"mushrooms", "glow_mushrooms", "custom"]},
		"gives": {"type": "amounts", "of": "ref:items", "soft": true, "rel": "drops", "via": "mow"},
		"chance": {"type": "float", "min": 0.0, "max": 1.0, "default": 1.0},
		"pick": {"type": "bool", "default": false},
		"winter": {"type": "bool", "default": true},
		"sprite": {"type": "string", "default": ""},
		"frames": {"type": "int", "min": 1, "default": 1},
		"grows": {"type": "enum", "values": ["meadow", "shade", "bank"], "default": "meadow"},
		"cover": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.3},
		"clumps": {"type": "float", "min": -1.0, "max": 1.0, "default": -1.0},
		# Only in these biomes (none: anywhere its `grows` says).
		"biomes": {"type": "list", "of": "ref:biomes", "soft": true, "default": [], "rel": "lives_in"},
	},
}
## The links a reference field names (`rel` in its spec), read from the record that has
## the field to the record it names: what the content graph and its reports are made of.
## The links of mechanics still to come (wearing, ammunition, power) are named before any
## field has them; a field brings its link with it otherwise.
const RELATIONS := {
	"drops": "gives the named items when acted on (`via`)",
	"becomes": "turns into the named record when acted on",
	"builds": "puts the named cell into the world",
	"grows_into": "planted or sown, grows into the named record",
	"repaired_with": "is mended with the named items",
	"feeds_on": "eats or seeks out the named records",
	"lives_in": "appears in the named biomes",
	"spawns": "grows the named records over its land",
	"produces": "makes the named item",
	"consumes": "uses the named items up",
	"requires": "needs the named items in the bag and does not use them up",
	"requires_station": "is made at the named station",
	"serves": "does the work of the named stations: their recipes are made at it too",
	"starts_with": "a new world starts with the named items, in the bag or set down by the spawn",
	"equips": "is worn in the named place",
	"ammo_for": "is shot by the named item",
	"requires_power": "works only with power",
	"powered_by": "runs on the named source of power",
	"in_era": "opens the named era of progress (a label the content graph checks; it locks nothing in play)",
}
## The actions a link comes about by (`via`): the rules of the hands
## (src/shared/game/world_actions.gd, tools.gd) decide what each one takes.
const ACTIONS := ["dig", "mow", "fell", "gather", "dig_out", "place", "plant", "sow", "repair", "hunt", "fish"]
## Fields every record may have besides its kind's: a text for the player, tags for
## reports and search (they decide nothing in the engine), which of the record's numbers
## are provisional, still to be balanced, and the ids it had before (`was`), so a save
## that names one finds it (see canon).
const COMMON := {
	"description": {"type": "string", "default": ""},
	"tags": {"type": "list", "of": "string", "default": []},
	"provisional": {"type": "list", "of": "string", "default": []},
	"was": {"type": "list", "of": "string", "default": []},
}
const MOD_SCHEMA := {
	"title": {"type": "string"},
	"version": {"type": "string"},
	"api": {"type": "int", "min": 1, "max": 1},
	"requires": {"type": "list", "of": "string", "default": []},
	"wants": {"type": "list", "of": "string", "default": []},
}
const BUNDLE_SCHEMA := {
	"title": {"type": "string"},
	"requires": {"type": "list", "of": "string", "default": []},
	"wants": {"type": "list", "of": "string", "default": []},
}


## Problems found by the last load, "file: id.field: what".
static var problems: PackedStringArray = []
## Names the last load found against the naming rules (see _check_names): reported by
## the validator, never failing it.
static var warnings: PackedStringArray = []
## Where each loaded record comes from, by "kind/id": {"bundle" that defined it first,
## "replaced" (the bundles whose `replaces` took its place, in order), "patched" (the
## bundles that patched it)}.
static var origins := {}
## kind -> an id a record had before (its `was`) -> its id now.
static var _renamed := {}
## kind -> Array of records in load order; a record's `mod` names its mod (its
## namespace) and `bundle` the bundle its files are in.
static var _kinds := {}
## kind -> id -> the place of its record in `_kinds[kind]`, so `find` is a lookup.
static var _at := {}
static var _schemas := {}
## kind -> id -> the record as written (before conversion), for patches to build on.
static var _raw := {}
static var _loaded := false
## Everything under content/, read once per run (refresh reads it again): bundle ->
## {"mod", "info" (its manifest), "records" (kind -> raw records), "owns", "hard", "soft",
## "patches", "replaces" (sets of "kind/id"), "requires", "wants" (bundle ids)}, mod -> its mod.yaml,
## the bundles in their order (core first, then by name), who owns which record, and
## the problems found reading each bundle.
static var _universe := {}
static var _mods := {}
static var _order: Array = []
static var _owners := {}
static var _scan_problems := {}
## How long the last reading of everything under content/ took (_scan: the files read and
## their records parsed), and the last load of a set after it (load_all), in ms: what the
## mods' data costs a start of the game, shown in the playtest report.
static var read_ms := 0.0
static var load_ms := 0.0
## Counts the loads (load_all): the registries (Mods) know from it whether they hold the
## arrays of the last one.
static var generation := 0
## PARSED, read on the first file (null until then, {} without one).
static var _parsed: Variant = null
## How many files _read took from PARSED and how many it parsed, for the report.
static var cached_files := 0
## refs by kind.
static var _refs := {}
static var parsed_files := 0


## Every mod under `content/`: the folders with a mod.yaml, core first, then by name.
## Folders starting with `_` are the tests' and are left out. Read from the scan
## (universe); refresh sees new folders.
static func available() -> Array:
	universe()
	return _mods.keys().filter(func(m: String) -> bool: return not m.begins_with("_"))


static func _folders(hidden: bool) -> Array:
	var out := []
	for name in DirAccess.get_directories_at(ROOT):
		if (name.begins_with("_") and not hidden) or not FileAccess.file_exists("%s/%s/mod.yaml" % [ROOT, name]):
			continue
		out.append(name)
	out.sort()
	if "core" in out:
		out.erase("core")
		out.push_front("core")
	return out


## The bundles of mod `mod`: its folders with a bundle.yaml by name, or the mod itself
## when it has none. Read from the scan (universe).
static func bundles_of(mod: String) -> Array:
	universe()
	var out := _order.filter(func(b: String) -> bool: return mod_of(b) == mod)
	return out if not out.is_empty() else [mod]


## bundles_of as the folders on disk say now, for the scan.
static func _bundles_on_disk(mod: String) -> Array:
	var out := []
	for name in DirAccess.get_directories_at("%s/%s" % [ROOT, mod]):
		if FileAccess.file_exists("%s/%s/%s/bundle.yaml" % [ROOT, mod, name]):
			out.append("%s/%s" % [mod, name])
	out.sort()
	return out if not out.is_empty() else [mod]


## Every bundle of every mod, in load order before dependencies (from the scan).
static func all_bundles() -> Array:
	universe()
	return _order.filter(func(b: String) -> bool: return not b.begins_with("_"))


## all_bundles as the folders on disk say, without the scan: BUNDLES' first value, set
## before the scan's own static vars exist.
static func _all_on_disk() -> Array:
	var out := []
	for mod in _folders(false):
		out.append_array(_bundles_on_disk(mod))
	return out


## The mod bundle `bundle` belongs to.
static func mod_of(bundle: String) -> String:
	return bundle.get_slice("/", 0)


## The mod.yaml of `mod` as a Dictionary with its fields checked, empty when it cannot
## be read.
static func info(mod: String) -> Dictionary:
	if universe().is_empty() or not _mods.has(mod):
		return _manifest("%s/%s/mod.yaml" % [ROOT, mod], MOD_SCHEMA, mod, "%s/mod.yaml" % mod)
	return _mods[mod]


## The bundle.yaml of `bundle` (title, requires, wants) with its `mod`; a mod of one
## bundle gives its mod.yaml.
static func bundle_info(bundle: String) -> Dictionary:
	if universe().has(bundle):
		return _universe[bundle].info
	return {}


static func _manifest(path: String, schema: Dictionary, mod: String, file: String) -> Dictionary:
	var d: Variant = _read(path)
	if not d is Dictionary:
		if d != null:
			problems.append("%s: expected a mapping" % file)
		return {}
	if schema == MOD_SCHEMA and d.get("id") != mod:
		problems.append("%s: id must be `%s`" % [file, mod])
	var out: Dictionary = d.duplicate()
	_check_fields(out, schema, mod, file, "mod" if schema == MOD_SCHEMA else "bundle")
	out.erase("id")
	return out


## Everything under content/ (see _universe), read on the first call.
static func universe() -> Dictionary:
	if _universe.is_empty():
		_scan()
	return _universe


## Reads every manifest and data file under content/ once: what each bundle owns,
## references and patches, for `resolve` and the load.
static func _scan() -> void:
	var t := Time.get_ticks_usec()
	cached_files = 0
	parsed_files = 0
	var kept := problems
	_universe = {}
	_mods = {}
	_order = []
	_owners = {}
	_scan_problems = {}
	for mod in _folders(true):
		problems = []
		var mod_info := _manifest("%s/%s/mod.yaml" % [ROOT, mod], MOD_SCHEMA, mod, "%s/mod.yaml" % mod)
		var mod_problems := problems
		_mods[mod] = mod_info
		var bundles := _bundles_on_disk(mod)
		if bundles != [mod] and DirAccess.dir_exists_absolute("%s/%s/data" % [ROOT, mod]):
			mod_problems.append("%s/data: a mod with bundles keeps its records in them" % mod)
		for b in bundles:
			problems = mod_problems.duplicate() if b == bundles[0] else []
			var bi := mod_info.duplicate() if b == mod else _manifest("%s/%s/bundle.yaml" % [ROOT, b], BUNDLE_SCHEMA, mod, "%s/bundle.yaml" % b)
			if mod_info.is_empty():
				problems.append("%s/mod.yaml: cannot read the mod" % mod)
			bi["mod"] = mod
			var u := {"mod": mod, "info": bi, "records": {}, "owns": {}, "hard": {}, "soft": {}, "patches": {}, "replaces": {},
				"requires": _named(bi.get("requires", []), mod), "wants": _named(bi.get("wants", []), mod)}
			# One listing of the bundle's data/ instead of asking for a file of every kind.
			var present := DirAccess.get_files_at("%s/%s/data" % [ROOT, b])
			for kind in SCHEMAS:
				if not ("%s.yaml" % kind) in present:
					u.records[kind] = []
					continue
				var list := _read_records(b, mod, kind)
				u.records[kind] = list
				for r in list:
					var key := "%s/%s" % [kind, r.id]
					if r.get("patch") == true:
						u.patches[key] = true
					else:
						if r.get("replaces") == true:
							u.replaces[key] = true
						u.owns[key] = true
						if not _owners.has(key):
							_owners[key] = []
						_owners[key].append(b)
					for ref in _refs_of(r, kind, mod):
						(u.soft if ref[2] else u.hard)["%s/%s" % [ref[0], ref[1]]] = true
			_universe[b] = u
			_order.append(b)
			_scan_problems[b] = problems
	problems = kept
	read_ms = (Time.get_ticks_usec() - t) / 1000.0


## Bundle ids out of `names` (bundle or mod ids, a bare name a bundle of `mod`).
static func _named(names: Array, mod: String) -> Array:
	var out := []
	for n in names:
		if not n is String:
			continue
		out.append("%s/%s" % [mod, n] if not "/" in n and FileAccess.file_exists("%s/%s/%s/bundle.yaml" % [ROOT, mod, n]) else n)
	return out


## The records of `bundle/data/<kind>.yaml` as written, ids qualified, duplicates and
## malformed ones left out with a problem.
static func _read_records(bundle: String, mod: String, kind: String) -> Array:
	var out := []
	var path := "%s/%s/data/%s.yaml" % [ROOT, bundle, kind]
	if not FileAccess.file_exists(path):
		return out
	var file := "%s/data/%s.yaml" % [bundle, kind]
	var list: Variant = _read(path)
	if list == null:
		return out
	if not list is Array:
		problems.append("%s: expected a list of records" % file)
		return out
	var seen := {}
	for i in list.size():
		var r: Variant = list[i]
		if not r is Dictionary or not r.get("id") is String or r.id == "":
			problems.append("%s: record %d: expected a mapping with an `id`" % [file, i + 1])
			continue
		var id: String = qualify(r.id, mod)
		if not _valid_id(id):
			problems.append("%s: `%s`: id must be `mod:name`, lowercase letters, digits and `_`" % [file, r.id])
			continue
		if seen.has(id):
			problems.append("%s: `%s`: duplicate id" % [file, id])
			continue
		seen[id] = true
		var rec: Dictionary = r.duplicate()
		rec.id = id
		out.append(rec)
	return out


## The references of raw record `r` of `kind`: [kind, qualified id, soft] each.
static func _refs_of(r: Dictionary, kind: String, mod: String) -> Array:
	var out := []
	for ref: Array in refs(kind):
		var field: String = ref[0].get_slice(".", 0)
		for key in [field, field + "+"]:
			if r.has(key):
				for id: String in named({field: r[key]}, ref[0]):
					out.append([target(ref[1]), qualify(id, mod), ref[1].get("soft", false)])
	return out


## Raw record `r` of `kind` with what its references name qualified by `mod`, the mod of
## the file it is written in: a patch names records as its own mod does, not as the one
## it patches.
static func _qualified(r: Dictionary, kind: String, mod: String) -> Dictionary:
	var out := r.duplicate(true)
	for ref: Array in refs(kind):
		var field: String = ref[0].get_slice(".", 0)
		var sub: String = ref[0].get_slice(".", 1) if "." in ref[0] else ""
		for key in [field, field + "+"]:
			if out.has(key):
				out[key] = _qualify_all(out[key], sub, mod)
	return out


## Value `v` of a reference field with its ids qualified by `mod`; `sub` the field of its
## entries that names one, "" for the value itself.
static func _qualify_all(v: Variant, sub: String, mod: String) -> Variant:
	var q := func(id: Variant) -> Variant: return qualify(id, mod) if id is String and id != "" else id
	if sub != "":
		for e: Variant in (v if v is Array else []):
			if e is Dictionary and e.has(sub):
				e[sub] = q.call(e[sub])
		return v
	if v is Array:
		return v.map(q)
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[q.call(k)] = v[k]
		return out
	return q.call(v)


## Which of `set` load, in what order, and which are left out and why: {"order",
## "dropped": bundle -> the bundle it needs}. A bundle is dropped when a hard field of
## its records names a record no bundle of the set has (while some bundle under content/
## does: a record nobody has is a mistake reported by the load), or when something it
## `requires` is not in the set; what depended on it goes with it. `report` adds the
## problems found (an unknown requirement, a circle) to `problems`.
static func resolve(set: Array, report := false) -> Dictionary:
	universe()
	var kept := {}
	for b in set:
		if _universe.has(b):
			kept[b] = true
	var out_dropped := {}
	var changed := true
	while changed:
		changed = false
		for b in kept.keys():
			var need := _missing(b, kept)
			if need != "":
				kept.erase(b)
				out_dropped[b] = need
				changed = true
				if report and not _universe.has(need):
					problems.append("%s: requires `%s`, which is not loaded" % [b, need])
	# Kahn's order: each step places the ready bundle (all it depends on placed) that
	# comes first in _order, so the order is the one of the scan where nothing forces
	# another. The dependencies are found once per bundle.
	var order := []
	var placed := {}
	var waits := {}
	var after := {}
	var ready: Array[int] = []
	for i in _order.size():
		var b: String = _order[i]
		if not kept.has(b):
			continue
		var deps := _deps(b, kept)
		waits[b] = deps.size()
		for d in deps:
			if not after.has(d):
				after[d] = []
			after[d].append(i)
		if deps.is_empty():
			ready.append(i)
	while not ready.is_empty():
		var i: int = ready.pop_front()
		var b: String = _order[i]
		order.append(b)
		placed[b] = true
		for j: int in after.get(b, []):
			var next: String = _order[j]
			waits[next] -= 1
			if waits[next] == 0:
				ready.insert(ready.bsearch(j), j)
	if placed.size() < kept.size():
		var rest := _order.filter(func(b: String) -> bool: return kept.has(b) and not placed.has(b))
		if report:
			problems.append("%s: bundles require each other in a circle" % ", ".join(rest))
		order.append_array(rest)
	return {"order": order, "dropped": out_dropped}


## What `b` needs that `kept` lacks: the first owner of a hard reference's record when
## none of its owners is kept, a requirement that is not kept, or "".
static func _missing(b: String, kept: Dictionary) -> String:
	var u: Dictionary = _universe[b]
	for key in u.hard:
		var owners: Array = _owners.get(key, [])
		if owners.is_empty() or u.owns.has(key):
			continue
		if not owners.any(func(o: String) -> bool: return kept.has(o)):
			return owners[0]
	for need in u.requires:
		for nb in _expand_need(need):
			if not kept.has(nb):
				return nb
	return ""


## A requirement as bundles: a bundle id itself, a mod id all its bundles.
static func _expand_need(need: String) -> Array:
	if _universe.has(need):
		return [need]
	if _mods.has(need):
		return _order.filter(func(b: String) -> bool: return mod_of(b) == need)
	return [need]


## The bundles of `kept` that load before `b`: the owners of what it references, patches
## or replaces, and what it requires or wants.
static func _deps(b: String, kept: Dictionary) -> Array:
	var u: Dictionary = _universe[b]
	var out := {}
	# A soft reference orders nothing: it is looked up once everything is loaded.
	for group in [u.hard, u.patches]:
		for key in group:
			for o in _owners.get(key, []):
				if o != b and kept.has(o):
					out[o] = true
	# A replacement loads after the record it replaces (not after other replacements).
	for key in u.replaces:
		for o in _owners.get(key, []):
			if o != b and kept.has(o) and not _universe[o].replaces.has(key):
				out[o] = true
	for need in u.requires + u.wants:
		for nb in _expand_need(need):
			if nb != b and kept.has(nb):
				out[nb] = true
	return out.keys()


## The bundles `bundle` cannot do without, itself last, in load order: the base game,
## the owners of its hard references and its requirements, and theirs. Out of `all`
## (every bundle unless given); the first owner when several have a record.
static func closure(bundle: String, all: Array = []) -> Array:
	universe()
	if all.is_empty():
		all = _order
	var set := {}
	var stack := ["core", bundle]
	while not stack.is_empty():
		var b: String = stack.pop_back()
		if set.has(b) or not _universe.has(b) or not b in all:
			continue
		set[b] = true
		var u: Dictionary = _universe[b]
		for key in u.hard:
			var owners: Array = _owners.get(key, []).filter(func(o: String) -> bool: return o in all)
			if not owners.is_empty() and not u.owns.has(key):
				stack.append(owners[0])
		for need in u.requires:
			stack.append_array(_expand_need(need))
	return resolve(set.keys()).order


## The bundles loaded that `bundle` loads after (see _deps).
static func deps(bundle: String) -> Array:
	var kept := {}
	for b in loaded:
		kept[b] = true
	return _deps(bundle, kept) if _universe.has(bundle) else []


## The fields of a record of `kind`: its kind's and the COMMON ones.
static func schema(kind: String) -> Dictionary:
	if not _schemas.has(kind):
		var all: Dictionary = SCHEMAS[kind].duplicate()
		all.merge(COMMON)
		_schemas[kind] = all
	return _schemas[kind]


## The reference fields of records of `kind`, those of their entries too: [key, spec]
## each, `key` the field's name or "field.sub" for field `sub` of the entries of `field`
## (see named), `spec` the reference's own (with its `rel`).
static func refs(kind: String) -> Array:
	# SCHEMAS is constant: worked out once a kind (every record of the start asks).
	if _refs.has(kind):
		return _refs[kind]
	var out := []
	for key: String in SCHEMAS[kind]:
		var spec: Dictionary = SCHEMAS[kind][key]
		if spec.type == "entries":
			for sub: String in spec.fields:
				if target(spec.fields[sub]) != "":
					out.append(["%s.%s" % [key, sub], spec.fields[sub]])
		elif target(spec) != "":
			out.append([key, spec])
	_refs[kind] = out
	return out


## The kind the reference field of `spec` names (`items` for a `ref:items`, a list or a
## mapping of them), "" when it is no reference.
static func target(spec: Dictionary) -> String:
	var type: String = spec.get("of", "") if spec.type in ["list", "amounts", "shares"] else spec.type
	return type.substr(4) if type.begins_with("ref:") else ""


## The ids record `r` names by its reference field `key` (see refs), "" left out.
static func named(r: Dictionary, key: String) -> Array:
	var values := []
	if "." in key:
		var sub := key.get_slice(".", 1)
		var entries: Variant = r.get(key.get_slice(".", 0))
		for e: Variant in (entries if entries is Array else []):
			if e is Dictionary:
				values.append(e.get(sub))
	else:
		var v: Variant = r.get(key)
		values = v.duplicate() if v is Array else (v.keys() if v is Dictionary else [v])
	return values.filter(func(id: Variant) -> bool: return id is String and id != "")


## Records of `kind` from every bundle, checked and with defaults filled in.
static func records(kind: String) -> Array:
	if not _loaded:
		load_all()
	return _kinds.get(kind, [])


## How many records the set loaded has, of every kind.
static func record_count() -> int:
	var n := 0
	for kind in SCHEMAS:
		n += records(kind).size()
	return n


## The record with `id` of `kind`, or an empty Dictionary.
static func find(kind: String, id: String) -> Dictionary:
	var list := records(kind)
	var at: int = _at.get(kind, {}).get(id, -1)
	return list[at] if at >= 0 else {}


## Id `id` of `kind` as it is called now: the id of the record whose `was` names it, any
## other as it is. The registries' own tables of older renames (Items.RENAMED...) go first.
static func canon(kind: String, id: String) -> String:
	if not _loaded:
		load_all()
	return _renamed.get(kind, {}).get(id, id)


## Where the record `id` of `kind` comes from (see origins), empty when it is not loaded.
static func origin(kind: String, id: String) -> Dictionary:
	if not _loaded:
		load_all()
	return origins.get("%s/%s" % [kind, id], {})


## Where record `rec` keeps file `rel` (`sprites/creatures/wolf.png`): in its bundle,
## else in its mod's `common/`; the bundle's path when neither has it.
static func asset(rec: Dictionary, rel: String) -> String:
	var own := "%s/%s/%s" % [ROOT, rec.get("bundle", rec.get("mod", "core")), rel]
	if ResourceLoader.exists(own) or FileAccess.file_exists(own):
		return own
	var common := "%s/%s/common/%s" % [ROOT, rec.get("mod", "core"), rel]
	if ResourceLoader.exists(common) or FileAccess.file_exists(common):
		return common
	return own


## The files of sound record `rec` (see the `sounds` kind): one, or one per variant.
static func sound_files(rec: Dictionary) -> PackedStringArray:
	var name: String = rec.id.get_slice(":", 1)
	if rec.variants == 1:
		return [asset(rec, "sounds/%s.wav" % name)]
	var out: PackedStringArray = []
	for i in rec.variants:
		out.append(asset(rec, "sounds/%s_%d.wav" % [name, i + 1]))
	return out


## Reads everything under content/ again and loads the set; the registries call their
## own `refresh` after this.
static func refresh() -> void:
	_universe = {}
	_loaded = false
	load_all()


## Loads BUNDLES: what they need in order, the rest left out (see resolve).
static func load_all() -> void:
	_loaded = true
	generation += 1
	problems = []
	warnings = []
	origins = {}
	_renamed = {}
	_kinds = {}
	_at = {}
	_raw = {}
	dropped = {}
	for kind in SCHEMAS:
		_kinds[kind] = []
		_at[kind] = {}
		_raw[kind] = {}
	universe()
	var t := Time.get_ticks_usec()
	var set := []
	for b in BUNDLES:
		if _universe.has(b):
			set.append(b)
			problems.append_array(_scan_problems.get(b, []))
		else:
			problems.append("%s: no such bundle" % b)
	var res := resolve(set, true)
	dropped = res.dropped
	loaded = res.order
	for b in loaded:
		_load_bundle(b)
	_check_refs()
	_check_renames()
	_check_names()
	for p in problems:
		push_error("content: " + p)
	load_ms = (Time.get_ticks_usec() - t) / 1000.0


static func _load_bundle(bundle: String) -> void:
	var u: Dictionary = _universe[bundle]
	for kind in SCHEMAS:
		var file := "%s/data/%s.yaml" % [bundle, kind]
		for r in u.records[kind]:
			var rec: Dictionary = r.duplicate()
			var id: String = rec.id
			var raw: Dictionary = _raw[kind]
			for own in ["mod", "bundle"]:
				# Where a record comes from is the folder it lies in, never a field it writes.
				if rec.has(own):
					problems.append("%s: %s.%s: unknown field" % [file, id, own])
					rec.erase(own)
			if rec.get("patch") == true:
				rec.erase("patch")
				if not raw.has(id):
					# The record's bundle is not in the set: the patch waits for it.
					if _owners.get("%s/%s" % [kind, id], []).is_empty():
						problems.append("%s: %s: patches a record no mod has" % [file, id])
					continue
				rec = _patched(raw[id], _qualified(rec, kind, u.mod), file, id, kind)
				origins["%s/%s" % [kind, id]].patched.append(bundle)
			else:
				var replaces: bool = rec.get("replaces") == true
				rec.erase("replaces")
				if raw.has(id) and not replaces:
					# The first record stays: another bundle's is never swapped silently.
					problems.append("%s: %s: %s has it already; a record of the same id replaces it only with `replaces: true`"
						% [file, id, raw[id].bundle])
					continue
				elif replaces and not raw.has(id) and _owners.get("%s/%s" % [kind, id], []).size() < 2:
					problems.append("%s: %s: replaces a record no mod has" % [file, id])
				rec.mod = u.mod
				rec.bundle = bundle
				var key := "%s/%s" % [kind, id]
				if origins.has(key):
					origins[key].replaced.append(bundle)
				else:
					origins[key] = {"bundle": bundle, "replaced": [], "patched": []}
			raw[id] = rec.duplicate()
			if not rec.get("title") is String or rec.title == "":
				problems.append("%s: %s.title: expected a string" % [file, id])
				rec.title = id
			_check_fields(rec, schema(kind), rec.mod, file, id)
			for f in rec.provisional:
				if not SCHEMAS[kind].has(f):
					problems.append("%s: %s.provisional: `%s` is no field of %s" % [file, id, f, kind])
			var list_of_kind: Array = _kinds[kind]
			var at: int = _at[kind].get(id, -1)
			if at >= 0:
				list_of_kind[at] = rec
			else:
				_at[kind][id] = list_of_kind.size()
				list_of_kind.append(rec)


## `base` with the fields of `patch` over it; a key ending in `+` adds its list or
## mapping to the field's (to its default when `base` does not write it). The record
## stays its first bundle's (its pictures and sounds are looked for there).
static func _patched(base: Dictionary, patch: Dictionary, file: String, id: String, kind: String) -> Dictionary:
	var out := base.duplicate(true)
	for key in patch:
		if key == "id":
			continue
		var v: Variant = patch[key]
		if key.ends_with("+"):
			var field: String = key.trim_suffix("+")
			var had: Variant = out.get(field, schema(kind).get(field, {}).get("default"))
			if had is Array and v is Array:
				out[field] = had + v
			elif had is Dictionary and v is Dictionary:
				var merged: Dictionary = had.duplicate()
				merged.merge(v, true)
				out[field] = merged
			else:
				problems.append("%s: %s.%s: `+` adds to a list or a mapping the record has" % [file, id, field])
		else:
			out[key] = v
	return out


## `name` -> `mod:name`; an id that already has a namespace stays as it is.
static func qualify(id: String, mod: String) -> String:
	return id if ":" in id else "%s:%s" % [mod, id]


static func _valid_id(id: String) -> bool:
	var parts := id.split(":")
	if parts.size() != 2:
		return false
	for p in parts:
		if p == "" or not p.is_valid_ascii_identifier() or p != p.to_lower():
			return false
	return true


## Checks the fields of `rec` against `schema`, converting values to their engine
## types (Color, Vector3, qualified ids) and filling in defaults.
static func _check_fields(rec: Dictionary, schema: Dictionary, mod: String, file: String, id: String) -> void:
	for key in rec:
		if key != "id" and key != "title" and key != "mod" and key != "bundle" and not schema.has(key):
			problems.append("%s: %s.%s: unknown field" % [file, id, key])
	for key in schema:
		var spec: Dictionary = schema[key]
		if not rec.has(key) or rec[key] == null:
			if not spec.has("default"):
				problems.append("%s: %s.%s: missing" % [file, id, key])
				rec[key] = _zero(spec)
			else:
				rec[key] = spec.default
			continue
		var out := [null]
		var what := _convert(rec[key], spec, mod, out)
		if what != "":
			problems.append("%s: %s.%s: %s" % [file, id, key, what])
			rec[key] = spec.default if spec.has("default") else _zero(spec)
		else:
			rec[key] = out[0]


## Converts `v` by `spec` into out[0]; returns what is wrong, or "".
static func _convert(v: Variant, spec: Dictionary, mod: String, out: Array) -> String:
	var type: String = spec.type
	match type:
		"bool":
			if not v is bool:
				return "expected true or false"
			out[0] = v
		"int":
			if not v is int:
				return "expected a whole number"
			out[0] = v
			return _bounds(v, spec)
		"float":
			if not (v is float or v is int):
				return "expected a number"
			out[0] = float(v)
			return _bounds(v, spec)
		"string":
			if not v is String:
				return "expected a string"
			out[0] = v
		"sound":
			# The name of a sound, kept as written: the client finds the record of that
			# name in the last loaded mod that has one (Sound.resolve), silence when none,
			# so a mod may name sounds no mod it requires gives.
			if not v is String:
				return "expected the name of a sound"
			out[0] = v
		"word":
			if not v is String or not v.is_valid_ascii_identifier() or v != v.to_lower():
				return "expected a lowercase word, like axe"
			out[0] = v
		"enum":
			if not v is String or not v in spec["values"]:
				return "expected one of %s" % ", ".join(spec["values"])
			out[0] = v
		"color":
			if not v is String or not Color.html_is_valid(v) or not v.begins_with("#"):
				return "expected a colour like \"#5a8f3c\""
			out[0] = Color.html(v)
		"vec3":
			if not v is Array or v.size() != 3:
				return "expected [x, y, z]"
			for n in v:
				if not (n is float or n is int):
					return "expected [x, y, z] of numbers"
			out[0] = Vector3(v[0], v[1], v[2])
		"list":
			if not v is Array:
				return "expected a list"
			if spec.has("len") and v.size() != spec.len:
				return "expected %d items" % spec.len
			if spec.has("least") and v.size() < spec.least:
				return "expected at least %d items" % spec.least
			var items := []
			var item_spec := spec.duplicate()
			item_spec.type = spec.of
			item_spec.erase("len")
			item_spec.erase("least")
			for n in v:
				var one := [null]
				var what := _convert(n, item_spec, mod, one)
				if what != "":
					return what
				items.append(one[0])
			out[0] = items
		"amounts":
			if not v is Dictionary or v.is_empty():
				return "expected a mapping of ids to how many, like {branch: 2}"
			var amounts := {}
			for k in v:
				if not k is String or k == "":
					return "expected ids as keys"
				if not v[k] is int or v[k] < 1:
					return "`%s`: expected a whole number of at least 1" % k
				amounts[qualify(k, mod)] = v[k]
			out[0] = amounts
		"shares":
			var named: bool = spec.has("keys")
			if not v is Dictionary or (v.is_empty() and named):
				return "expected a mapping of %s to shares 0..1, like {%s: 0.5}" % [", ".join(spec.keys), spec.keys[0]] if named \
					else "expected a mapping of ids to shares 0..1, like {oak: 0.5}"
			var shares := {}
			for k in v:
				if not k is String or k == "" or (named and not k in spec.keys):
					return "`%s`: expected one of %s" % [k, ", ".join(spec.keys)] if named else "expected ids as keys"
				if not (v[k] is float or v[k] is int) or v[k] < 0.0 or v[k] > 1.0:
					return "`%s`: expected a share from 0 to 1" % k
				shares[k if named else qualify(k, mod)] = float(v[k])
			out[0] = shares
		"colors":
			if not v is Dictionary:
				return "expected a mapping of %s to colours, like {%s: \"#e8e0c8\"}" % [", ".join(spec.keys), spec.keys[0]]
			var colors := {}
			for k in v:
				if not k is String or not k in spec.keys:
					return "`%s`: expected one of %s" % [k, ", ".join(spec.keys)]
				if not v[k] is String or not Color.html_is_valid(v[k]) or not v[k].begins_with("#"):
					return "`%s`: expected a colour like \"#5a8f3c\"" % k
				colors[k] = Color.html(v[k])
			out[0] = colors
		"entries":
			if not v is Array:
				return "expected a list of mappings, like [{%s}]" % ", ".join(spec.fields.keys().map(func(k: String) -> String: return k + ": …"))
			var entries := []
			for i in v.size():
				if not v[i] is Dictionary:
					return "entry %d: expected a mapping" % (i + 1)
				var e: Dictionary = v[i].duplicate()
				var what := _entry(e, spec.fields, mod)
				if what != "":
					return "entry %d: %s" % [i + 1, what]
				entries.append(e)
			out[0] = entries
		_:
			if type.begins_with("ref:"):
				if not v is String or v == "":
					return "expected an id"
				out[0] = qualify(v, mod)
			else:
				return "unknown type %s in the schema" % type
	return ""


## Checks entry `e` of an `entries` field against `fields` like a record's fields (see
## _check_fields), converting its values and filling in defaults; returns what is wrong,
## or "".
static func _entry(e: Dictionary, fields: Dictionary, mod: String) -> String:
	for key: Variant in e:
		if not fields.has(key):
			return "`%s`: unknown field" % key
	for key: String in fields:
		var spec: Dictionary = fields[key]
		if not e.has(key) or e[key] == null:
			if not spec.has("default"):
				return "`%s`: missing" % key
			e[key] = spec.default
			continue
		var one := [null]
		var what := _convert(e[key], spec, mod, one)
		if what != "":
			return "`%s`: %s" % [key, what]
		e[key] = one[0]
	return ""


static func _bounds(v: Variant, spec: Dictionary) -> String:
	if spec.has("min") and v < spec.min:
		return "must be at least %s" % spec.min
	if spec.has("max") and v > spec.max:
		return "must be at most %s" % spec.max
	return ""


## A harmless stand-in for a missing or broken value, so the game can go on.
static func _zero(spec: Dictionary) -> Variant:
	match spec.type:
		"bool":
			return false
		"int":
			return int(spec.get("min", 0))
		"float":
			return float(spec.get("min", 0.0))
		"enum":
			return spec["values"][0]
		"color":
			return Color.MAGENTA
		"vec3":
			return Vector3.ZERO
		"amounts", "shares", "colors":
			return {}
		"entries":
			return []
		"list":
			var items := []
			var item_spec := spec.duplicate()
			item_spec.type = spec.of
			for i in spec.get("len", spec.get("least", 0)):
				items.append(_zero(item_spec))
			return items
	return ""


## Every reference must name a record that is loaded; a soft one that does not is dropped
## from the record (an entry naming it with it), and reported when strict.
static func _check_refs() -> void:
	for kind in SCHEMAS:
		for field_ref: Array in refs(kind):
			var key: String = field_ref[0]
			var spec: Dictionary = field_ref[1]
			var of := target(spec)
			var soft: bool = spec.get("soft", false)
			for r in _kinds[kind]:
				if "." in key:
					var field := key.get_slice(".", 0)
					var sub := key.get_slice(".", 1)
					var keep := []
					for e: Dictionary in r[field]:
						var gone: bool = e[sub] != "" and find(of, e[sub]).is_empty()
						if gone:
							_broken(r, kind, key, of, e[sub], soft)
						if not (gone and soft):
							keep.append(e)
					r[field] = keep
				elif spec.type == "list":
					var keep := []
					for ref in r[key]:
						if find(of, ref).is_empty():
							_broken(r, kind, key, of, ref, soft)
						if not soft or not find(of, ref).is_empty():
							keep.append(ref)
					r[key] = keep
				elif spec.type in ["amounts", "shares"]:
					for ref in r[key].keys():
						if find(of, ref).is_empty():
							_broken(r, kind, key, of, ref, soft)
							if soft:
								r[key].erase(ref)
				else:
					var ref: String = r[key]
					if ref == "" and spec.get("default") == "":
						continue
					if find(of, ref).is_empty():
						_broken(r, kind, key, of, ref, soft)
						if soft:
							r[key] = ""


## The ids records had before (`was`): each in the record's mod unless it names one, not
## the id of a record still loaded, and claimed by one record only.
static func _check_renames() -> void:
	for kind in SCHEMAS:
		var renamed := {}
		for r in _kinds[kind]:
			for old in r.was:
				var q := qualify(old, r.mod)
				var file := "%s/data/%s.yaml" % [r.bundle, kind]
				if not _valid_id(q):
					problems.append("%s: %s.was: `%s`: an id is `mod:name`" % [file, r.id, old])
				elif not find(kind, q).is_empty():
					problems.append("%s: %s.was: `%s` is a record still" % [file, r.id, q])
				elif renamed.has(q):
					problems.append("%s: %s.was: `%s` was `%s` already" % [file, r.id, renamed[q], q])
				else:
					renamed[q] = r.id
		_renamed[kind] = renamed


## Names against the rules of docs/specifications/BUNDLE_SYSTEM.md (section 3), as
## `warnings`: a recipe is named after what it makes, or `<item>_from_<what it needs>`
## when the item has more recipes; a tool `<material>_<thing>`; ore `<metal>_ore`; a tag
## is a lowercase word, and one only one record has is likely a slip.
static func _check_names() -> void:
	var bare := {}
	for r in records("recipes"):
		var name: String = r.id.get_slice(":", 1)
		var item: String = r.makes.get_slice(":", 1)
		if name == item:
			if bare.has(r.makes):
				warnings.append("recipes: `%s` and `%s` both make `%s` by its name; name the other `%s_from_<what it needs>`"
					% [bare[r.makes], r.id, r.makes, item])
			bare[r.makes] = r.id
		elif not name.begins_with(item + "_from_"):
			warnings.append("recipes: `%s` makes `%s`: name it `%s`, or `%s_from_<what it needs>`" % [r.id, r.makes, item, item])
		elif not r.needs.keys().any(func(n: String) -> bool: return n.get_slice(":", 1) == name.trim_prefix(item + "_from_")):
			warnings.append("recipes: `%s`: `%s` is not among what it needs" % [r.id, name.trim_prefix(item + "_from_")])
	for r in records("items"):
		if r.tool != "none" and not "_" in r.id.get_slice(":", 1):
			warnings.append("items: `%s`: a tool is named `<material>_<thing>`, like `stone_axe`" % r.id)
	for r in records("materials"):
		if r.role == "ore" and not r.id.ends_with("_ore"):
			warnings.append("materials: `%s`: ore is named `<metal>_ore`" % r.id)
	var tagged := {}
	for kind in SCHEMAS:
		for r in records(kind):
			for t in r.tags:
				if not t.is_valid_ascii_identifier() or t != t.to_lower():
					warnings.append("%s: `%s`: the tag `%s` is not a lowercase word" % [kind, r.id, t])
				tagged[t] = tagged.get(t, []) + ["%s `%s`" % [kind, r.id]]
	for t in tagged:
		if tagged[t].size() == 1:
			warnings.append("%s: the tag `%s` is on nothing else" % [tagged[t][0], t])


static func _broken(r: Dictionary, kind: String, key: String, of: String, ref: String, soft: bool) -> void:
	if not soft or strict:
		problems.append("%s/data/%s.yaml: %s.%s: no %s `%s`" % [r.bundle, kind, r.id, key, of, ref])


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		problems.append("%s: cannot read" % path.trim_prefix(ROOT + "/"))
		return null
	var text := f.get_as_text()
	if _parsed == null:
		_parsed = {}
		var c := FileAccess.open(PARSED, FileAccess.READ)
		var got: Variant = c.get_var() if c != null else null
		if got is Dictionary:
			_parsed = got
	if not _parsed.is_empty():
		var key := text.md5_text()
		if _parsed.has(key):
			cached_files += 1
			# Its records are changed by who reads them (ids qualified...): a copy each time.
			var v: Variant = _parsed[key]
			return v.duplicate(true) if v is Dictionary or v is Array else v
	parsed_files += 1
	return parse_text(text, path.trim_prefix(ROOT + "/"))


## Every YAML file under content/ parsed, for PARSED: md5 of its text → its value; a
## malformed file is left out (the game parses it and reports it).
static func parsed_cache() -> Dictionary:
	var out := {}
	var files := []
	_yaml_files(ROOT, files)
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		var had := problems.size()
		var value: Variant = parse_text(text, path.trim_prefix(ROOT + "/"))
		if problems.size() > had:
			problems.resize(had)
			continue
		out[text.md5_text()] = value
	return out


static func _yaml_files(dir: String, files: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".yaml"):
			files.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_yaml_files(dir.path_join(d), files)


## The value of YAML `text` (of `file`, for the problem), null with a problem when malformed.
static func parse_text(text: String, file: String) -> Variant:
	var yaml := Yaml.new()
	var value: Variant = yaml.parse(text, file)
	if yaml.error != "":
		problems.append(yaml.error)
		return null
	return value
