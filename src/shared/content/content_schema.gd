extends RefCounted
## The first part of the mods' data (content.gd, which says how mods, bundles and their
## records are laid out and loaded): the schema of every kind of record (SCHEMAS), the
## links a reference names (RELATIONS, ACTIONS), the fields every record and manifest
## has, and the questions about a kind's fields: its whole schema, its reference fields,
## the kind a reference names, the ids a record names, a qualified id.
##
## The mods' data is one script split by topic (decision 168, as decision 145):
## content_schema.gd <- content_fields.gd <- content_mods.gd <- content.gd; each part
## extends the one before and calls only what it or an earlier part defines, and callers
## know only content.gd.

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
		# Texels the boundary of the material with another goes ragged over, both ways.
		"fray": {"type": "int", "min": 0, "max": 7, "default": 0},
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
		# Set down on cells (the square its model's slices cover: 16 voxels two by two, 8 one
		# cell; turned to face who set it), a thing of this class (its model, its solid parts); a
		# station unless it stores. What it does besides is in its flags: `storage` slots it
		# holds things in, `fire` it burns (put out, lit again with fuel, it burns a body),
		# `repairs` tools are mended at it, `serves` the stations it stands in for (their
		# recipes are made at it, tools mended if they mend them), `place_tool` the class of
		# tool it is set down with (one in the bag), `claims` it is a territory's centre.
		"prop": {"type": "word", "default": "none"},
		"storage": {"type": "int", "min": 0, "default": 0},
		"fire": {"type": "bool", "default": false},
		"repairs": {"type": "bool", "default": false},
		"serves": {"type": "list", "of": "ref:items", "default": [], "rel": "serves"},
		"place_tool": {"type": "word", "default": "none"},
		# A thing set down that claims land: the centre of a territory of who set it and
		# their team (Territory, decision 15).
		"claims": {"type": "bool", "default": false},
		# Stairs: the thing is solid by the steps of its model (a box for each quarter of a
		# cell), so a body walks up them; set down also over air, as blocks are.
		"steps": {"type": "bool", "default": false},
		# A door: a tap opens and shuts it (Placed.swing; Territory's "doors"); its model is
		# the leaf shut along the north edge of its square, it swings open on the hinge at
		# the north-west corner.
		"door": {"type": "bool", "default": false},
		# A window: set into a wall, solid, taken up at a tap (as stairs are), no station.
		"window": {"type": "bool", "default": false},
		# Furniture (decision 163, 7А): set down turned to face who sets it, no station; a
		# tap takes it up unless it stores. `seat`: a body standing still on it or by it
		# gets its stamina back this many times faster (Placed.seat_near); `keeps`: what it
		# stores goes off at this share of the pace (a barrel; Placed.spoil).
		"furniture": {"type": "bool", "default": false},
		"seat": {"type": "float", "min": 1.0, "default": 1.0},
		"keeps": {"type": "float", "min": 0.0, "max": 1.0, "default": 1.0},
		# Food that spoils: it keeps this many game days (slower in the cold, see
		# Inventory.spoil), then turns into `rots_to` (nothing if none); 0 keeps for ever.
		"spoils": {"type": "float", "min": 0.0, "default": 0.0},
		"rots_to": {"type": "ref:items", "default": "", "rel": "becomes"},
		# Drink: `drink` water it gives when drunk (Vitals.drink); a vessel drunk from becomes
		# `empties_to` (an empty waterskin); an empty one filled at fresh water becomes
		# `fills_to` (WorldActions.drink).
		"drink": {"type": "float", "min": 0.0, "default": 0.0},
		"empties_to": {"type": "ref:items", "default": "", "rel": "becomes"},
		"fills_to": {"type": "ref:items", "default": "", "rel": "becomes"},
		# A fire (`fire`) burns on fuel: it holds at most `fuel_max` seconds of burning and
		# a new one is set down with `fuel_start` of them (`fuel_max` 0 burns for ever;
		# `fuel_start` 0 is set down cold, a fireplace). Fuel (`fuel`) lights a fire and
		# feeds it `fuel_time` seconds.
		"fuel_max": {"type": "float", "min": 0.0, "default": 0.0},
		"fuel_start": {"type": "float", "min": 0.0, "default": 0.0},
		"fuel": {"type": "bool", "default": false},
		"fuel_time": {"type": "float", "min": 0.0, "default": 120.0},
		"sprite": {"type": "string", "default": ""},
		"anim": {"type": "string", "default": "reach"},
		"hands": {"type": "int", "min": 1, "max": 2, "default": 1},
		"light": {"type": "float", "min": 0.0, "default": 0.0},
		# A light is used up as it burns: once lit in a hand, one of the stack burns this
		# many seconds and is gone (Character.burning); 0 burns for ever.
		"burns": {"type": "float", "min": 0.0, "default": 0.0},
		# Worn on the body (Inventory.wear): the slot it goes in; a bag on the back adds
		# `bag_slots` to the slots of the bag the character always has.
		"wear_on": {"type": "enum", "values": ["", "head", "body", "legs", "feet", "back"], "default": ""},
		# Clothes: how many degrees warmer the body is in it (Warmth.clothes; half when wet).
		"warmth": {"type": "float", "min": 0.0, "default": 0.0},
		# Clothes on the figure: the picture sprites/worn/<look>.png of the bundle, laid
		# over the body by where it is worn (Figure.dressed); none: not seen on it.
		"look": {"type": "string", "default": ""},
		"bag_slots": {"type": "int", "min": 0, "default": 0},
		# Bedding: kept in the bag, sleep rests this many times faster (the best one counts,
		# Character.sleep_rate); 1 is none.
		"bedding": {"type": "float", "min": 1.0, "default": 1.0},
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
		# Fishing: what a swimmer becomes in the bag when it is pulled out on a rod's line
		# (WorldActions.fish, Fishing); "" none bites.
		"catch": {"type": "ref:items", "soft": true, "default": "", "rel": "drops", "via": "fish"},
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
	# The skills (Skills, decision 164): what kind of work each grows from and speeds up
	# (`role`, the engine asks by it), its place in the window (`order`), its levels and the
	# points of work the first one takes, each next `growth` times more, how much faster
	# the work is at the last level (`speed`: the share of pace added, 1 = twice as fast),
	# the points a whole thing gives where the work has no time of its own
	# (`each`: a beast killed, a fish caught), the chance at the last level of one more of
	# what the work gives (`yield`) and how much longer a thing made lasts (`quality`: a
	# share of its `durability` more).
	"skills": {
		"role": {"type": "enum", "values": ["gather", "chop", "dig", "craft", "build", "cook", "hunt", "fish", "swim"]},
		"order": {"type": "int", "min": 0, "default": 0},
		"levels": {"type": "int", "min": 1, "max": 20, "default": 10},
		"first": {"type": "float", "min": 1.0, "default": 180.0},
		"growth": {"type": "float", "min": 1.0, "max": 4.0, "default": 1.6},
		"speed": {"type": "float", "min": 0.0, "max": 4.0, "default": 1.0},
		"each": {"type": "float", "min": 0.0, "default": 0.0},
		"yield": {"type": "float", "min": 0.0, "max": 1.0, "default": 0.0},
		"quality": {"type": "float", "min": 0.0, "max": 2.0, "default": 0.0},
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
## kind -> id -> the place of its record in `_kinds[kind]`, so `find` is a lookup.
static var _at := {}
static var _schemas := {}
## refs by kind.
static var _refs := {}


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
