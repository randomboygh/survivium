extends RefCounted
## The shots tools/shot.gd takes, by name: the time of day, season, weather and moon,
## where the player stands (an offset from the spawn, a place found in the world or a
## scene built for the shot, see tools/shot/places.gd), what they hold and do, and the
## settings of the picture. A new shot is a new entry here.


const SHOTS := {
	"day": {"time": 0.45, "season": 1},
	"morning": {"time": 0.29, "season": 0},
	"evening": {"time": 0.72, "season": 1},
	"night": {"time": 0.95, "season": 1},
	"rain": {"time": 0.5, "season": 1, "rain": true},
	"autumn": {"time": 0.42, "season": 2},
	"winter": {"time": 0.45, "season": 3, "rain": true},
	"winter-dusk": {"time": 0.74, "season": 3},
	"winter-night": {"time": 0.97, "season": 3},
	# Nights by the moon, dawn, and the kinds of weather.
	"night-dark": {"time": 0.95, "season": 1, "moon": 0.0},
	"night-full": {"time": 0.95, "season": 1, "moon": 1.0},
	# The player a step north-east of the campfire by the spawn: shadows of the player,
	# animals and trunks drawn on the ground (the fire shadows setting on "drawn").
	"fire-shadows": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 1},
	"fire-shadows-moon": {"time": 0.95, "season": 1, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 1},
	# The same on "mixed", the default: the player's shadow real, the rest drawn.
	"fire-shadows-mixed": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 3},
	# The player east of the fire, in line with it: the real shadow still as wide as the body.
	"fire-inline": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(1.4, 0.0, 0.0), "fire_shadows": 3},
	# The same with real shadows: of the player, the grass, bushes and trees.
	"fire-shadows-real": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 2},
	# The torch among lone trees on a dark night: shadows of the trunks, drawn and real.
	"torch-shadows": {"time": 0.95, "season": 1, "moon": 0.0, "trees": true, "fire_shadows": 1},
	"torch-shadows-real": {"time": 0.95, "season": 1, "moon": 0.0, "trees": true, "fire_shadows": 2},
	# Two more campfires by the one at the spawn and an animal by the player: drawn
	# shadows from every fire.
	"three-fires": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4),
		"more_fires": [Vector3(4.5, 0.0, -4.0), Vector3(-3.5, 0.0, -5.0)], "animal": Vector3(-1.6, 0.0, -2.6),
		"fire_shadows": 1},
	# The same three fires close round the player, so the shadows cross.
	"three-fires-close": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.6),
		"more_fires": [Vector3(1.4, 0.0, -4.6), Vector3(-1.8, 0.0, -2.8)], "animal": Vector3(1.0, 0.0, -0.8),
		"fire_shadows": 1},
	# A dozen campfires round the player: more lights than one chunk takes by default, so
	# chunks each lit by a different few showed square edges (bug 2026-10-24).
	"many-fires": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4),
		"more_fires": [Vector3(-7.5, 0.0, -4.0), Vector3(-7.5, 0.0, -9.0), Vector3(-4.5, 0.0, -4.0), Vector3(-4.5, 0.0, -9.0), Vector3(-1.5, 0.0, -4.0), Vector3(-1.5, 0.0, -9.0), Vector3(1.5, 0.0, -4.0), Vector3(1.5, 0.0, -9.0), Vector3(4.5, 0.0, -4.0), Vector3(4.5, 0.0, -9.0), Vector3(7.5, 0.0, -4.0), Vector3(7.5, 0.0, -9.0)], "fire_shadows": 3},
	"torch-meadow": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow"},
	# Blocks (a wall, a low wall, a pillar, a lone block), a chest and a workbench round
	# the campfire by the spawn, and an animal in the player's shadow: their shadows
	# drawn ("drawn", and "mixed" with the player's real), and the real ones to compare.
	"fire-blocks": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_blocks": true,
		"animal": Vector3(0.4, 0.0, -1.0), "fire_shadows": 1},
	"fire-blocks-mixed": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_blocks": true,
		"animal": Vector3(0.4, 0.0, -1.0), "fire_shadows": 3},
	"fire-blocks-real": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_blocks": true,
		"animal": Vector3(0.4, 0.0, -1.0), "fire_shadows": 2},
	# The sun moving over lone trees in the morning, frame by frame (see "sweep").
	"sun-sweep": {"time": 0.36, "season": 1, "trees": true, "sweep": 30},
	"sun-still": {"time": 0.36, "season": 1, "trees": true, "sweep": 30, "sweep_step": 0.0},
	"sun-smooth": {"time": 0.36, "season": 1, "trees": true, "sweep": 30, "sun_steps": 0},
	"sun-pcf13": {"time": 0.36, "season": 1, "trees": true, "sweep": 30, "sun_steps": 0, "shadow_filter": 4},
	"sun-hard": {"time": 0.36, "season": 1, "trees": true, "sweep": 30, "sun_steps": 0, "shadow_filter": 0},
	"moon-sweep": {"time": 0.9, "season": 1, "moon": 1.0, "trees": true, "sweep": 30, "fire_shadows": 0},
	# An animal in the player's shadow by day, in the morning and at sunrise.
	"animal-shadow": {"time": 0.36, "season": 1, "animal": Vector3(-0.55, 0.0, -0.45)},
	"animal-shadow-sunrise": {"time": 0.27, "season": 1, "animal": Vector3(-0.9, 0.0, 0.3)},
	"animal-shadow-trees": {"time": 0.45, "season": 1, "trees": true, "animal": Vector3(-1.0, 0.0, -0.6)},
	# The torch by the same blocks, the fire put out.
	"torch-blocks": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(-3.0, 0.0, 3.4), "fire_blocks": true,
		"fire_out": true, "fire_shadows": 1},
	# The torch by the campfire put out: its shadow round and low like the fire, not a cube.
	"torch-campfire": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(-1.2, 0.0, 1.4), "fire_out": true,
		"fire_shadows": 1},
	# The campfire at dusk, when its shadows start.
	"fire-dusk": {"time": 0.78, "season": 1, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 2},
	"fire-dusk-before": {"time": 0.78, "season": 1, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 0},
	# The same with the shadows setting off.
	"fire-no-shadows": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "shadows": false},
	"fire-no-shadows-moon": {"time": 0.95, "season": 1, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "shadows": false},
	# Only the moon casts shadows, as before fires did.
	"fire-moon-before": {"time": 0.95, "season": 1, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 0},
	"dawn": {"time": 0.255, "season": 1, "moon": 1.0},
	"sunrise": {"time": 0.28, "season": 1, "moon": 1.0},
	# Sun rays: a clear day, a low sun, and the breaking clouds after rain.
	"rays-day": {"time": 0.45, "season": 1},
	"rays-evening": {"time": 0.72, "season": 1},
	"rays-after-rain": {"time": 0.4, "season": 1, "weather": "cloudy", "after_rain": 1.0},
	# Fog on the ground: a light morning one in the low places and over water, a thick
	# morning one, the weather's fog and thick fog, and fog without the setting.
	"fog-morning": {"time": 0.27, "season": 1, "morning_fog": 1},
	"fog-morning-hills": {"time": 0.27, "season": 1, "morning_fog": 1, "slopes": true},
	"fog-morning-lake": {"time": 0.27, "season": 1, "morning_fog": 1, "place": "lake"},
	"fog-morning-dense": {"time": 0.27, "season": 1, "morning_fog": 2},
	"fog-dense-forest": {"time": 0.33, "season": 2, "weather": "dense_fog", "forest": true},
	"fog-dense-river": {"time": 0.33, "season": 2, "weather": "dense_fog", "place": "river"},
	"fog-simple": {"time": 0.33, "season": 2, "weather": "fog", "fog": false},
	# Puddles: just after rain, half dried, and in the rain.
	"puddles": {"time": 0.42, "season": 1, "puddles": 1.0, "after_rain": 1.0},
	"puddles-drying": {"time": 0.42, "season": 1, "puddles": 0.35},
	"puddles-rain": {"time": 0.5, "season": 1, "rain": true, "puddles": 1.0},
	"rays-off": {"time": 0.45, "season": 1, "rays": false},
	"fog": {"time": 0.33, "season": 2, "weather": "fog"},
	"downpour": {"time": 0.5, "season": 1, "weather": "downpour"},
	"storm": {"time": 0.6, "season": 1, "weather": "storm"},
	"hail": {"time": 0.45, "season": 0, "weather": "hail"},
	"blizzard": {"time": 0.45, "season": 3, "weather": "blizzard"},
	"sandstorm": {"time": 0.45, "season": 1, "weather": "sandstorm"},
	# The wind: its side, the autumn gale stripping the
	# leaves and breaking branches, the leaves fallen under the crowns.
	"blizzard-north": {"time": 0.45, "season": 3, "weather": "blizzard", "wind": -2.0},
	"gale-autumn": {"time": 0.45, "season": 2, "forest": true, "weather": "storm", "wind": 0.6, "leaf_fall": 0.6, "windfall": true},
	"litter-autumn": {"time": 0.42, "season": 2, "forest": true, "leaf_fall": 1.0},
	"cave": {"time": 0.45, "season": 1, "cut": -4},
	"underground": {"time": 0.45, "season": 1, "underground": true},
	"underground-winter": {"time": 0.45, "season": 3, "rain": true, "underground": true},
	"hut": {"time": 0.42, "season": 1, "hut": true},
	"shore": {"time": 0.4, "season": 1, "shore": true},
	"slopes": {"time": 0.42, "season": 1, "slopes": true},
	"corners": {"time": 0.42, "season": 1, "corners": true},
	# The shore and the rounded corners by the full moon, the moon moving (see "sweep").
	"shore-moon": {"time": 0.9, "season": 1, "moon": 1.0, "shore": true, "sweep": 20, "fire_shadows": 0},
	"corners-moon": {"time": 0.9, "season": 1, "moon": 1.0, "corners": true, "sweep": 20, "fire_shadows": 0},
	"corners-winter": {"time": 0.45, "season": 3, "corners": true},
	"lab": {"time": 0.42, "season": 1, "lab": true},
	"trees": {"time": 0.42, "season": 1, "trees": true},
	"forest": {"time": 0.42, "season": 1, "forest": true},
	"forest-autumn": {"time": 0.42, "season": 2, "forest": true},
	"forest-winter": {"time": 0.45, "season": 3, "forest": true},
	"river": {"time": 0.42, "season": 1, "place": "river"},
	"canyon": {"time": 0.42, "season": 1, "place": "canyon"},
	"lake": {"time": 0.42, "season": 1, "place": "lake"},
	"swamp": {"time": 0.42, "season": 1, "place": "swamp"},
	"cliffs": {"time": 0.42, "season": 1, "place": "cliffs"},
	"beach": {"time": 0.42, "season": 1, "place": "beach"},
	"lake-morning": {"time": 0.36, "season": 1, "place": "lake"},
	"beach-morning": {"time": 0.33, "season": 1, "place": "beach"},
	"slopes-winter-morning": {"time": 0.33, "season": 3, "slopes": true},
	"beach-winter": {"time": 0.33, "season": 3, "place": "beach"},
	"plateau": {"time": 0.42, "season": 1, "place": "plateau"},
	"pit-mouth": {"time": 0.42, "season": 1, "place": "pit"},
	"adit": {"time": 0.42, "season": 1, "place": "adit"},
	"mountain": {"time": 0.42, "season": 1, "place": "mountain"},
	"mountain-winter": {"time": 0.45, "season": 3, "place": "mountain"},
	"peak": {"time": 0.42, "season": 1, "place": "peak"},
	"waterfall": {"time": 0.42, "season": 1, "place": "waterfall"},
	"rapids": {"time": 0.42, "season": 1, "place": "rapids"},
	"delta": {"time": 0.42, "season": 1, "place": "delta"},
	"mountain-cave": {"time": 0.42, "season": 1, "place": "mountain-cave"},
	"tracks": {"time": 0.42, "season": 1, "walk": true},
	"meadow": {"time": 0.42, "season": 1, "find": "meadow"},
	"meadow-autumn": {"time": 0.42, "season": 2, "find": "meadow"},
	"ears": {"time": 0.42, "season": 1, "find": "ears"},
	# A flock of sparrows (the animals mod) about the player: on the ground, in the air
	# and in the crowns near.
	"birds": {"time": 0.42, "season": 1, "find": "ears", "birds": true},
	"birds-forest": {"time": 0.42, "season": 1, "forest": true, "birds": true},
	# Moss and mushrooms in the shade of a forest, and glowing mushrooms by night.
	"mushrooms": {"time": 0.42, "season": 1, "find": "plants:mushrooms"},
	"glow-day": {"time": 0.42, "season": 1, "find": "plants:glow_mushrooms"},
	"glow-night": {"time": 0.95, "season": 1, "moon": 0.0, "find": "plants:glow_mushrooms"},
	"glow-moon": {"time": 0.95, "season": 1, "moon": 1.0, "find": "plants:glow_mushrooms"},
	# Moss on stone, a few tops of it picked: the moss left has a ragged edge.
	"moss-picked": {"time": 0.42, "season": 1, "place": "mountain", "pick_moss": true},
	# A patch of copper ore amid stone moss: the copper has a ragged edge, no moss on it.
	"copper-moss": {"time": 0.42, "season": 1, "place": "mountain", "copper_moss": true},
	"hidden": {"time": 0.42, "season": 1, "wall": true},
	# A trench four levels deep in a forest: the view is cut at the player's level.
	"ravine": {"time": 0.42, "season": 1, "forest": true, "trench": true},
	"pit": {"time": 0.42, "season": 1, "place": "canyon", "cut": -3},
	"pit-winter": {"time": 0.45, "season": 3, "place": "canyon", "cut": -3},
	"tracks-winter": {"time": 0.45, "season": 3, "walk": true},
	# The character walking in a direction, caught mid-stride.
	"walk-s": {"time": 0.42, "season": 1, "keys": [KEY_S]},
	"walk-e": {"time": 0.42, "season": 1, "keys": [KEY_D]},
	"walk-ne": {"time": 0.42, "season": 1, "keys": [KEY_D, KEY_W]},
	"walk-w": {"time": 0.42, "season": 1, "keys": [KEY_A]},
	"wade": {"time": 0.42, "season": 1, "water": 1},
	"swim": {"time": 0.42, "season": 1, "water": 2},
	"ice": {"time": 0.45, "season": 3, "water": 2},
	"grove": {"time": 0.42, "season": 1, "grove": true},
	"grove-autumn": {"time": 0.42, "season": 2, "grove": true},
	"grove-winter": {"time": 0.45, "season": 3, "grove": true},
	"grove-spring": {"time": 0.42, "season": 0, "grove": true},
	"grove-autumn-morning": {"time": 0.31, "season": 2, "grove": true},

	# A clearing with an oak and a spruce, then the same after both are felled.
	"clearing": {"time": 0.42, "season": 1, "clearing": true},
	"felled": {"time": 0.42, "season": 1, "clearing": true, "fell": true},
	# The oak and the spruce of the clearing by the full moon and by a low sun: the shape
	# of their shadows.
	"clearing-moon": {"time": 0.95, "season": 1, "moon": 1.0, "clearing": true},
	"clearing-low-sun": {"time": 0.3, "season": 1, "clearing": true},
	# North of the spruce by the full moon, its shadow falling toward the player.
	"spruce-moon": {"time": 0.85, "season": 1, "moon": 1.0, "clearing": true, "offset": Vector3(0.5, 0.0, -5.0)},
	# Gathering on the felled clearing with berry bushes: some things picked up and
	# berries picked; then the bag open on a touch screen and with a mouse.
	"gather": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true},
	"bag": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true},
	"bag-pc": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "bag": true},
	# A chest chosen in the bag: its wide button sets it down.
	"bag-put": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"give": "tools:chest"},
	# A bush dug up chosen in the bag: its wide button plants it.
	"bag-plant": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"give": "plants:raspberry_bush"},
	# The same bag with only the food lit and the chosen stack about to be destroyed.
	"bag-destroy": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"kind": "food", "slot": 0, "destroy": true},
	# Working by the spawn: the tools lying by the chest, a stone floor painted with the
	# 3x3 brush, a pit dug with the shovel and berries knocked off a bush with the sword
	# lying about, the cursor frame on what the action button digs next.
	"work": {"time": 0.42, "season": 1, "touch": true, "work": true},
	"work-pc": {"time": 0.42, "season": 1, "work": true},
	# What the hands hold, by the spawn: an axe in the left hand chopping facing east, the
	# same standing facing us with a stone block in the right hand, a shovel winding up
	# to dig facing south-east, a sword striking facing west.
	"hands-chop": {"time": 0.42, "season": 1, "hands": {"tool": "tools:stone_axe", "facing": "e", "work": "chop", "strike": true}},
	"hands-front": {"time": 0.42, "season": 1, "hands": {"tool": "tools:stone_axe", "facing": "s", "right": true}},
	"hands-dig": {"time": 0.42, "season": 1, "hands": {"tool": "tools:wooden_shovel", "facing": "se", "work": "dig"}},
	"hands-slash": {"time": 0.42, "season": 1, "hands": {"tool": "tools:wooden_sword", "facing": "w", "work": "slash", "strike": true}},
	# A sword carried facing south-east and north-west: up against the shoulder.
	"hands-sword": {"time": 0.42, "season": 1, "hands": {"tool": "tools:wooden_sword", "facing": "se", "right": false}},
	"hands-sword-nw": {"time": 0.42, "season": 1, "hands": {"tool": "tools:wooden_sword", "facing": "nw"}},
	# Bits of a trunk chopped flying off it.
	"burst-chop": {"time": 0.42, "season": 1, "hands": {"tool": "tools:stone_axe", "facing": "e", "work": "chop", "strike": true}, "burst": "plants:log"},
	# The chest by the spawn opened beside the bag.
	"chest": {"time": 0.42, "season": 1, "touch": true, "work": true, "chest": true},
	# A second chest set down beside the player: the bag button opens the bag with both
	# chests, a tab each.
	"chests": {"time": 0.42, "season": 1, "touch": true, "work": true, "chests": true},
	# A workbench, a kiln and a chest placed by the spawn, the craft tab open at the workbench
	# with an axe being made and more queued.
	"craft": {"time": 0.42, "season": 1, "touch": true, "craft": true},
	"craft-pc": {"time": 0.42, "season": 1, "craft": true},
	# A recipe with many facts (a stone scythe) on a narrow phone screen, and the craft tab
	# before any recipe is known: no queue then.
	"craft-scythe": {"time": 0.42, "season": 1, "touch": true, "craft": true, "recipe": "tools:stone_scythe"},
	"craft-unknown": {"time": 0.42, "season": 1, "touch": true, "craft": true, "unknown": true},
	# The craft tab with nothing queued: no queue panel under the recipe.
	"craft-idle": {"time": 0.42, "season": 1, "touch": true, "craft": true, "idle": true},
	# The spawn campfire opened: the craft tab with its buttons by the cross.
	"campfire": {"time": 0.42, "season": 1, "touch": true, "campfire": true},
	# The same workbench, kiln and chest with the window closed.
	"stations": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true},
	# A forge set down with the rest, closed; and open, a copper bar being smelted in it.
	"forge": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true, "forge": true},
	"craft-forge": {"time": 0.42, "season": 1, "touch": true, "craft": true, "forge": true, "recipe": "tools:copper_bar"},
	# A copper pickaxe at its strike, and copper tools lying on the ground.
	"hands-copper": {"time": 0.42, "season": 1, "hands": {"tool": "tools:copper_pickaxe", "facing": "e", "work": "chop", "strike": true},
		"drops": ["tools:copper_axe", "tools:copper_sword", "tools:copper_scythe", "tools:copper_shovel", "materials:copper_bar", "materials:charcoal"]},
	# The same with the player standing on the chest, by the front edge of its lid, and on
	# the workbench as far back as its planks hold.
	"stations-top": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true,
		"on": ["tools:chest", Vector3(1.0, 1.5, 1.6)]},
	"bench-top": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true,
		"on": ["tools:workbench", Vector3(1.0, 1.5, 0.2)]},
	# The death screen: dead of hunger by the spawn with a few things in the bag.
	"death": {"time": 0.42, "season": 1, "touch": true, "death": true},
	"death-pc": {"time": 0.42, "season": 1, "death": true},
	# Back after that death beside the sack, glowing where the character fell.
	"sack": {"time": 0.42, "season": 1, "death": true, "revive": true},
	"sack-night": {"time": 0.95, "season": 1, "death": true, "revive": true},
	# The interface: with a mouse, on a touch screen, with the statistics and the menu.
	"ui": {"time": 0.45, "season": 1, "stats": true},
	"ui-touch-stats": {"time": 0.45, "season": 1, "touch": true, "stats": true},
	# The camera turned (steps of 45 degrees to the left) and tilted (steps of a wall
	# 2 px shorter): by day among trees, and the camera buttons under the minimap.
	"turn-45": {"time": 0.45, "season": 1, "trees": true, "turn": 1},
	"turn-90": {"time": 0.45, "season": 1, "trees": true, "turn": 2},
	"turn-180": {"time": 0.45, "season": 1, "trees": true, "turn": 4},
	"turn-trees": {"time": 0.45, "season": 1, "trees": true},
	"tilt-low": {"time": 0.45, "season": 1, "trees": true, "tilt": -2},
	"tilt-steep": {"time": 0.45, "season": 1, "trees": true, "tilt": 2},
	"turn-hut": {"time": 0.45, "season": 1, "hut": true, "turn": 3, "tilt": -1},
	"turn-ui": {"time": 0.45, "season": 1, "turn": 7, "tilt": 1, "touch": true},
	"turn-fire": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 1, "turn": 2},
	"turn-forest": {"time": 0.45, "season": 1, "forest": true, "turn": 4},
	"ui-touch": {"time": 0.45, "season": 1, "touch": true, "toast": true},
	"ui-menu": {"time": 0.45, "season": 1, "touch": true, "menu": true},
	"ui-settings": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings"},
	"ui-test": {"time": 0.45, "season": 1, "touch": true, "test": true},
	"ui-settings-pc": {"time": 0.45, "season": 1, "menu": true, "page": "settings"},
	# The graphics section of the settings: the quality preset over the settings by hand.
	"ui-settings-graphics": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings", "section": "graphics"},
	"ui-settings-graphics-pc": {"time": 0.45, "season": 1, "menu": true, "page": "settings", "section": "graphics"},
	"ui-test-pc": {"time": 0.45, "season": 1, "menu": true, "page": "test"},
	# The playtest page's other tabs: the player's switches and the tools button, debugging.
	"ui-test-player": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "player"},
	"ui-test-debug": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug"},
	# The screen's answer to a hurt (red edges, the number over the head), and to a heal with food.
	"ui-hurt": {"time": 0.45, "season": 1, "touch": true, "body": "hurt"},
	"ui-fed": {"time": 0.45, "season": 1, "touch": true, "body": "fed"},
	"ui-changes": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "changes"},
	# The interface a step smaller and the joystick and buttons the smallest.
	"ui-small": {"time": 0.45, "season": 1, "touch": true, "ui_size": 1, "control_size": 0},
	"ui-settings-big": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings", "ui_size": 4},
	# The interface section of the settings, and the corner of the HUD by its settings:
	# the minimap small or large, the level and camera buttons hidden.
	"ui-settings-interface": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings", "section": "interface"},
	"ui-minimap-small": {"time": 0.45, "season": 1, "touch": true, "settings": {"minimap_size": 0}},
	"ui-minimap-large": {"time": 0.45, "season": 1, "touch": true, "settings": {"minimap_size": 2}},
	"ui-corner-hidden": {"time": 0.45, "season": 1, "touch": true, "settings": {"level_buttons": false, "camera_buttons": false}},
	# The first screen (the world to make) and the whole map of what is explored.
	"ui-setup": {"time": 0.45, "season": 1, "touch": true, "setup": true},
	"ui-setup-mods": {"time": 0.45, "season": 1, "touch": true, "setup": "mods"},
	# The page of one mod: a row per bundle (its animals), each switched on its own.
	"ui-setup-mod": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:animals"},
	"ui-setup-mod-plants": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:plants"},
	"ui-setup-mod-resources": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:resources"},
	"ui-setup-mod-tools": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:tools"},
	"ui-setup-mod-sounds": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:sounds"},
	"ui-setup-mod-biomes": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:biomes"},
	"ui-map": {"time": 0.45, "season": 1, "touch": true, "map": true},
	# The workbench, kiln, chest and campfire by the spawn marked on the map, close up.
	"ui-map-marks": {"time": 0.45, "season": 1, "touch": true, "craft": true, "closed": true, "map": true, "map_zoom": 8},
	# The sacks of two deaths: one near, marked on the map and the minimap, and one far
	# beyond the minimap's edge, kept at its edge.
	"ui-map-sack": {"time": 0.45, "season": 1, "touch": true, "sacks": [[6.0, -3.0], [-120.0, 40.0]], "map": true, "map_zoom": 8},
	"ui-minimap-sack": {"time": 0.45, "season": 1, "touch": true, "sacks": [[6.0, -3.0], [-120.0, 40.0]]},
	# A campfire set down by the camp by the spawn: its dot is drawn beside theirs.
	"ui-minimap-placed": {"time": 0.45, "season": 1, "touch": true, "put_fire": [-2.0, -8.0]},
	# Markers of every colour (dx, dz in cells, colour): flags on the map, the window of a
	# new one open; dots on the minimap, the far ones at its edge; listed on the playtest page.
	"ui-map-markers": {"time": 0.45, "season": 1, "touch": true, "map": true, "map_zoom": 4,
		"markers": [[30, -20, 0], [-40, 10, 1], [12, 36, 2], [-24, -44, 3], [140, 30, 4], [-70, -60, 5]], "map_tap": [-20, 20]},
	"ui-map-markers-pc": {"time": 0.45, "season": 1, "map": true, "map_zoom": 2,
		"markers": [[30, -20, 0], [-40, 10, 1], [12, 36, 2], [-24, -44, 3], [140, 30, 4], [-70, -60, 5]], "map_tap": [30, -20]},
	"ui-minimap-markers": {"time": 0.45, "season": 1, "touch": true,
		"markers": [[30, -20, 0], [-40, 10, 1], [12, 36, 2], [-24, -44, 3], [140, 30, 4], [-70, -60, 5]]},
	"ui-test-marks": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "marks",
		"markers": [[30, -20, 0], [-40, 10, 1], [12, 36, 2], [-24, -44, 3], [140, 30, 4], [-70, -60, 5]]},
	# The main menu over the live world, over the painted sky it shows while the world is
	# built, and with the setup screen of a new world open over it.
	"ui-main-menu": {"time": 0.42, "season": 1, "touch": true, "main_menu": "live"},
	"ui-main-menu-pc": {"time": 0.42, "season": 1, "main_menu": "live"},
	"ui-main-menu-sky": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky"},
	# The clouds parting once the world is built, caught halfway.
	"ui-main-menu-part": {"time": 0.42, "season": 1, "touch": true, "main_menu": "part"},
	"ui-main-menu-loading": {"time": 0.42, "season": 1, "touch": true, "main_menu": "loading"},
	"ui-main-menu-loading-pc": {"time": 0.42, "season": 1, "main_menu": "loading"},
	"ui-main-menu-setup": {"time": 0.42, "season": 1, "touch": true, "main_menu": "setup"},
	# The list of saved worlds, over a few saves made up for it.
	"ui-main-menu-worlds": {"time": 0.42, "season": 1, "touch": true, "main_menu": "worlds"},
	# The grounds of the test world (TestGround), a run of their own: the player at
	# `at` (cells). Named "ground-*", they switch the run to the test world.
	"ground-spawn": {"time": 0.42, "season": 1, "at": [0, 0]},
	"ground-steps": {"time": 0.42, "season": 1, "at": [-28, -24]},
	# In the trench between the loose and the stone ledges of 3 and 5 cells: the cut hides
	# them, their rounded corners cut.
	"ground-steps-cut": {"time": 0.42, "season": 1, "at": [-22, -35]},
	"ground-steps-cut-n": {"time": 0.42, "season": 1, "at": [-18, -35]},
	"ground-pits": {"time": 0.42, "season": 1, "at": [0, -32]},
	"ground-cave": {"time": 0.42, "season": 1, "at": [27, -20]},
	"ground-cave-inside": {"time": 0.42, "season": 1, "at": [27, -38], "y": 23},
	"ground-forest": {"time": 0.42, "season": 1, "at": [-30, 2]},
	"ground-materials": {"time": 0.42, "season": 1, "at": [32, 12]},
	"ground-hut": {"time": 0.42, "season": 1, "at": [54, 7]},
	"ground-pond": {"time": 0.42, "season": 1, "at": [-30, 12]},
	"ground-biomes": {"time": 0.42, "season": 1, "at": [20, 26]},
	# The swamp strip: pools in the north, a pond running into a bog in the south, and
	# the player wading the bog.
	"ground-swamp": {"time": 0.42, "season": 1, "at": [18, 26]},
	"ground-bog": {"time": 0.42, "season": 1, "at": [19, 33], "y": 23},
	# Swimming in the deep end of the pond and in the deep corner of the swamp's pond.
	"ground-swim": {"time": 0.42, "season": 1, "at": [-20, 26], "y": 18},
	"ground-swim-swamp": {"time": 0.42, "season": 1, "at": [19, 27], "y": 21},
	"ground-bushes": {"time": 0.42, "season": 1, "at": [78, 4]},
	"ground-relief-west": {"time": 0.42, "season": 1, "at": [-46, 64]},
	"ground-relief-middle": {"time": 0.42, "season": 1, "at": [2, 64]},
	"ground-relief-east": {"time": 0.42, "season": 1, "at": [50, 64]},
	"ground-relief-winter": {"time": 0.42, "season": 3, "at": [2, 64]},
	# The stream down its terraces, from the meadow south of it and from its top.
	"ground-stream": {"time": 0.42, "season": 1, "at": [72, 37]},
	"ground-stream-top": {"time": 0.42, "season": 1, "at": [58, 20]},
	"ground-ears": {"time": 0.42, "season": 1, "at": [116, 13]},
	# The grove's floor: moss, mushrooms, and the mushrooms that glow at night.
	"ground-grove": {"time": 0.42, "season": 1, "at": [112, 26]},
	"ground-grove-night": {"time": 0.95, "season": 1, "moon": 0.0, "at": [124, 26]},
	# The camp for FPS and freezes: things on the ground, sacks, stations, campfires.
	"ground-camp": {"time": 0.42, "season": 1, "at": [76, -12]},
	"ground-camp-night": {"time": 0.95, "season": 1, "moon": 0.0, "at": [76, -12]},
	"ground-mountain-top": {"time": 0.42, "season": 1, "at": [121, 64]},
}
