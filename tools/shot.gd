extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [name ...]
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png. The spots are
## searched in cells (half a world unit); the player stands in world units.

const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const CELL := 0.5
## How far around the player (in cells) the shore, water and lone tree searches look:
## the world has no edge, only the chunks generated around.
const SEARCH := 120

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
	"torch-meadow": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow"},
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
	"mist-morning": {"time": 0.27, "season": 1},
	"mist-shore": {"time": 0.27, "season": 1, "shore": true},
	"mist-lake": {"time": 0.27, "season": 1, "place": "lake"},
	"mist-off": {"time": 0.27, "season": 1, "rays": false, "mist": false},
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
	# Moss and mushrooms in the shade of a forest, and glowing mushrooms by night.
	"mushrooms": {"time": 0.42, "season": 1, "find": "core:mushrooms"},
	"glow-day": {"time": 0.42, "season": 1, "find": "core:glow_mushrooms"},
	"glow-night": {"time": 0.95, "season": 1, "moon": 0.0, "find": "core:glow_mushrooms"},
	"glow-moon": {"time": 0.95, "season": 1, "moon": 1.0, "find": "core:glow_mushrooms"},
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
	# Gathering on the felled clearing with berry bushes: some things picked up and
	# berries picked; then the bag open on a touch screen and with a mouse.
	"gather": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true},
	"bag": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true},
	"bag-pc": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "bag": true},
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
	"hands-chop": {"time": 0.42, "season": 1, "hands": {"tool": "core:stone_axe", "facing": "e", "work": "chop", "strike": true}},
	"hands-front": {"time": 0.42, "season": 1, "hands": {"tool": "core:stone_axe", "facing": "s", "right": true}},
	"hands-dig": {"time": 0.42, "season": 1, "hands": {"tool": "core:wooden_shovel", "facing": "se", "work": "dig"}},
	"hands-slash": {"time": 0.42, "season": 1, "hands": {"tool": "core:wooden_sword", "facing": "w", "work": "slash", "strike": true}},
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
	"craft-scythe": {"time": 0.42, "season": 1, "touch": true, "craft": true, "recipe": "core:stone_scythe"},
	"craft-unknown": {"time": 0.42, "season": 1, "touch": true, "craft": true, "unknown": true},
	# The spawn campfire opened: the craft tab with its buttons by the cross.
	"campfire": {"time": 0.42, "season": 1, "touch": true, "campfire": true},
	# The same workbench, kiln and chest with the window closed.
	"stations": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true},
	# The same with the player standing on the chest, by the front edge of its lid, and on
	# the workbench as far back as its planks hold.
	"stations-top": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true,
		"on": ["core:chest", Vector3(1.0, 1.5, 1.6)]},
	"bench-top": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true,
		"on": ["core:workbench", Vector3(1.0, 1.5, 0.2)]},
	# The death screen: dead of hunger by the spawn with a few things in the bag.
	"death": {"time": 0.42, "season": 1, "touch": true, "death": true},
	"death-pc": {"time": 0.42, "season": 1, "death": true},
	# Back after that death beside the sack, glowing where the character fell.
	"sack": {"time": 0.42, "season": 1, "death": true, "revive": true},
	"sack-night": {"time": 0.95, "season": 1, "death": true, "revive": true},
	# The interface: with a mouse, on a touch screen, with the statistics and the menu.
	"ui": {"time": 0.45, "season": 1, "stats": true},
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
	"ui-settings-big": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings", "ui_scale": 2},
	# The first screen (the world to make) and the whole map of what is explored.
	"ui-setup": {"time": 0.45, "season": 1, "touch": true, "setup": true},
	"ui-map": {"time": 0.45, "season": 1, "touch": true, "map": true},
	# The workbench, kiln, chest and campfire by the spawn marked on the map, close up.
	"ui-map-marks": {"time": 0.45, "season": 1, "touch": true, "craft": true, "closed": true, "map": true, "map_zoom": 8},
	# The sacks of two deaths: one near, marked on the map and the minimap, and one far
	# beyond the minimap's edge, kept at its edge.
	"ui-map-sack": {"time": 0.45, "season": 1, "touch": true, "sacks": [[6.0, -3.0], [-120.0, 40.0]], "map": true, "map_zoom": 8},
	"ui-minimap-sack": {"time": 0.45, "season": 1, "touch": true, "sacks": [[6.0, -3.0], [-120.0, 40.0]]},
	# The main menu over the live world, over the painted sky it shows while the world is
	# built, and with the setup screen of a new world open over it.
	"ui-main-menu": {"time": 0.42, "season": 1, "touch": true, "main_menu": "live"},
	"ui-main-menu-pc": {"time": 0.42, "season": 1, "main_menu": "live"},
	"ui-main-menu-sky": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky"},
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
	"ground-bushes": {"time": 0.42, "season": 1, "at": [78, 4]},
	"ground-relief-west": {"time": 0.42, "season": 1, "at": [-46, 64]},
	"ground-relief-middle": {"time": 0.42, "season": 1, "at": [2, 64]},
	"ground-relief-east": {"time": 0.42, "season": 1, "at": [50, 64]},
	"ground-relief-winter": {"time": 0.42, "season": 3, "at": [2, 64]},
}

const TEST_SAVES := "user://shot_ground"

var main: Node
var out_dir := "user://shots"
var names: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	names = args.slice(1) if args.size() > 1 else SHOTS.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ground: bool = names.any(func(n: String) -> bool: return n.begins_with("ground-"))
	if ground:
		_test_world()
	main = load("res://scenes/main.tscn").instantiate()
	if ground:
		main.save_root = TEST_SAVES
	main.skip_setup = true
	root.add_child(main)
	_run()


## Starts the run in the test world, in a folder of saves of its own made anew.
func _test_world() -> void:
	var store := load("res://src/shared/world/world_store.gd")
	store._erase_dir(TEST_SAVES)
	store.root = TEST_SAVES
	DirAccess.make_dir_recursive_absolute(TEST_SAVES)
	store.write_current(-1, {})


## Saved worlds made up for the world list, in a folder of their own.
func _fake_saves() -> void:
	main.WorldStore.root = "user://shot_saves"
	var worlds := [[main.world_seed, main.world_options, 12, "2026-10-20T18:40:00"],
		[48151623, {"size": 0, "water": 2, "mountains": 1, "rivers": 0, "biomes": 1}, 3, "2026-10-19T21:05:00"],
		[777, {"size": 1, "water": 1, "mountains": 2, "rivers": 1, "biomes": 1}, 41, "2026-10-18T12:30:00"]]
	for w: Array in worlds:
		var store = main.WorldStore.new(main.WorldStore.world_dir(w[0], w[1]))
		store.write_json(main.WorldStore.WORLD, {"format": main.WorldStore.FORMAT, "seed": w[0], "settings": w[1],
			"sky": {"day": w[2]}, "saved": w[3], "played": 1800.0})


func _run() -> void:
	while not main.ready_to_play:
		await process_frame
	var spawn: Vector3 = main.player.position
	var added_fires := []
	for shot_name in names:
		main.player.position = spawn
		var shot: Dictionary = SHOTS[shot_name]
		main.clock.time_of_day = shot.time
		main.clock.time_speed = 0.0
		main.clock.season = shot.season
		main.clock.raining = shot.get("rain", false)
		if shot.has("weather"):
			main.clock.set_weather(_weather_index(shot.weather))
		main.clock.wind_to = shot.get("wind", 0.0)
		main.clock.leaf_fall = shot.get("leaf_fall", 0.0)
		main.sky.moon_override = shot.get("moon", -1.0)
		main.settings.values.fire_shadows = shot.get("fire_shadows", main.settings.DEFAULTS.fire_shadows)
		main.settings.values.sun_rays = shot.get("rays", true)
		main.settings.values.mist = shot.get("mist", true)
		main.settings.set_value("shadows", shot.get("shadows", true))
		# Fires burn steadily in shots, so shots with and without shadows compare.
		main.effects.flicker_clock = -INF
		main.controls.show_help = false
		main.chunks.manual_level = -1
		if shot.get("shore", false):
			main.player.position = _shore(main.world, main.player.position)
		if shot.get("slopes", false):
			main.player.position = _hills(main.world, main.player.position)
		if shot.get("hut", false):
			main.player.position = _hut(main.world, main.player.position)
		if shot.get("underground", false):
			main.player.position = _cave(main.world, main.player.position)
		if shot.get("corners", false):
			main.player.position = _corners(main.world, main.player.position)
		if shot.get("trees", false):
			main.player.position = _lone_trees(main.world, main.player.position)
		if shot.get("forest", false):
			main.player.position = _forest(main.world, main.player.position)
		if shot.has("place"):
			main.player.position = _place(main.world, shot.place)
		if shot.has("at"):
			var at := Vector2i(shot.at[0], shot.at[1])
			main.player.position = Vector3(at.x + 0.5, main.world.size_y - 1, at.y + 0.5) * CELL
			main.chunks.build_around()
			main.player.position.y = shot.get("y", main.world.surface_y(at.x, at.y)) * CELL
		if shot.has("by_fire"):
			for e: Dictionary in main.placed.things:
				if main.placed.is_fire(e):
					main.player.position = main.placed.center(e) + shot.by_fire
					for off: Vector3 in shot.get("more_fires", []):
						var spot: Vector3i = main.placed.spot_near(main.placed.center(e) + off)
						if spot.y >= 0:
							added_fires.append(main.placed.put(main.placed.CAMPFIRE, spot, null))
					break
		# The shots look at far places too: the chunks around the new spot at once.
		main.chunks.build_around()
		if shot.has("water"):
			main.player.position = _in_water(main.world, main.player.position, shot.water)
		if shot.has("find"):
			main.player.position = _find(main.world, main.player.position, shot.find)
		if shot.get("grove", false):
			# Away from the campfire by the spawn, which melts the snow around it.
			_grove(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(0, 0, -44))
		if shot.get("clearing", false):
			_clearing(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(40, 0, 0), shot.get("fell", false))
		if shot.get("gather", false):
			_gather()
		main.controls.set_touch(shot.get("touch", false))
		if shot.get("work", false):
			_work()
		main.hud.perf.visible = shot.get("stats", false)
		main.hud.show_keys(shot_name == "ui")
		if shot.get("lab", false):
			_lab(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("wall", false):
			_wall(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("trench", false):
			main.player.position = _trench(main.world, Vector3i((main.player.position / CELL).floor()))
		if shot.has("cut"):
			main.chunks.manual_level = main.player.level() + int(shot.cut)
			main.chunks.update_cut(0.0)
		# Let snow, wetness, tints and particles settle.
		for i in 90:
			await process_frame
			main.clock.snow = 1.0 if main.clock.season == 3 else 0.0
			main.clock.settle_weather()
			main.clock.wet = 1.0 if main.clock.raining and main.clock.season != 3 else shot.get("after_rain", 0.0)
			main.sky.after_rain = shot.get("after_rain", 0.0)
			main.sky.foliage = main.sky.FOLIAGE[main.clock.season]
			main.sky.grass = main.sky.GRASS[main.clock.season]
			main.sky.berry_amount = main.sky.BERRY_AMOUNT[main.clock.season]
			main.sky.leaf_amount = lerpf(main.sky.LEAF_AMOUNT[main.clock.season], main.sky.LEAF_AMOUNT[3], main.clock.leaf_fall)
		if shot.get("windfall", false):
			# A long storm: the wind breaks branches off the trees around.
			main.clock.time_speed = 20.0
			for i in 2000:
				main.storms.step(main.storms.TICK, main.player.position)
			main.clock.time_speed = 0.0
		if shot.has("animal") and not main.wildlife.animals.is_empty():
			# Stands still where it is put until the shot is taken.
			var c = main.wildlife.animals[0]
			c.pos = main.player.position + shot.animal
			c.pos.y = main.wildlife.ground(c.pos.x, c.pos.z)
			c.target = c.pos
			c.think = 100.0
		main.effects.pick_shadow_fires(Vector2(main.player.position.x, main.player.position.z - main.player.position.y))
		for f: Dictionary in main.effects.fires:
			f.light.light_energy = f.base * lerpf(1.0, 0.15, main.sky.daylight) \
					* (main.effects.shadow_energy if f.light.shadow_enabled else 1.0)
		for at: Array in shot.get("sacks", []):
			main.character.sacks.append(main.player.position + Vector3(at[0], 0.0, at[1]) * main.CELL)
		await process_frame
		if shot.get("walk", false):
			# A walk in a hook south-east, then west, over a flat open spot, leaving
			# footprints.
			main.player.position = _flat_near(main.world, main.player.position)
			for i in 100:
				main.player.body.move_input = Vector2(0.6, 0.8) if i < 50 else Vector2(-1.0, 0.0)
				main.player.step(1.0 / 30.0, false)
				main._leave_footprints()
				await process_frame
			main.player.body.move_input = Vector2.ZERO
			for i in 10:
				await process_frame
		if shot.has("hands"):
			await _hands(shot.hands)
		if shot.has("keys"):
			# Holds the keys while the shot is taken, so the walk animation shows.
			main.player.position = _flat_near(main.world, main.player.position)
			_hold(shot.keys, true)
			for i in 12:
				await process_frame
		# Messages fade after a few seconds, longer than the settling above takes here.
		if shot.get("toast", false):
			main.hud.toast("Наступило лето")
			await process_frame
			await process_frame
		main.settings.set_value("ui_scale", shot.get("ui_scale", 0))
		if shot.has("body"):
			# What the screen shows when the body is hurt, or healed and fed.
			var v = main.character.vitals
			if shot.body == "fed":
				v.health = 60.0
				v.satiety = 30.0
				for i in 3:
					await process_frame
				v.health = 75.0
				v.satiety = 55.0
			else:
				v.health -= 12.0
			for i in 4:
				await process_frame
		if shot.get("test", false):
			main.hud.toggle_test()
			main.hud._settings.show_section(shot.get("section", "world"))
		if shot.get("menu", false):
			main.hud.toggle_menu()
			if shot.has("page"):
				main.hud.open_settings(shot.page)
				# The window keeps the section shown last: an earlier shot may have left another.
				if shot.page in ["settings", "test"]:
					main.hud._settings.show_section(shot.get("section", "game" if shot.page == "settings" else "world"))
		if shot.get("bag", false):
			main.hud.toggle_bag()
			# The window opens on the tab it was closed on; an earlier shot may have left the craft tab.
			main.hud.bag.show_tab("bag")
			main.hud.bag._let_go()
			main.hud.bag._tap(shot.get("slot", 1), true)
			if shot.has("kind"):
				main.hud.bag._kinds.pick(shot.kind)
			if shot.get("destroy", false):
				main.hud.bag._destroy.pressed.emit()
		if shot.get("chest", false):
			main.placed.chest_items.add("core:log", 3)
			main.placed.chest_items.add("core:raspberry", 12)
			main.hud.open_chest()
			main.hud.bag._kinds.pick("")
			main.hud.bag._tap(0, false)
		if shot.get("chests", false):
			main.character.inventory.add("core:chest", 1)
			main.player.facing = "e"
			main.props.put_from_bag("core:chest")
			main.placed.chest_items.add("core:raspberry", 12)
			main.hud.toggle_bag()
			main.hud.bag.show_tab("bag")
			main.hud.bag._kinds.pick("")
			main.hud.bag._tap(0, true)
		if shot.get("campfire", false):
			for e in main.placed.things:
				if main.placed.is_fire(e):
					main.hud.open_prop(e)
					break
		if shot.get("craft", false):
			_craft()
			if shot.has("recipe"):
				main.character.inventory.add("core:cord", 2)
				main.hud.bag.craft._choose(shot.recipe)
			if shot.get("unknown", false):
				while not main.workshop.queue.jobs.is_empty():
					main.workshop.queue.cancel(0)
				main.workshop.knowledge.seen.clear()
				main.workshop.knowledge._known.clear()
				main.hud.bag.craft.refresh_now()
			if shot.get("closed", false):
				main.hud.toggle_bag()
			if shot.has("on"):
				for e in main.placed.things:
					if e.item == shot.on[0]:
						main.player.position = (Vector3(e.cell) + shot.on[1]) * main.CELL
				for i in 30:
					await process_frame
		if shot.get("test", false) or shot.get("menu", false) or shot.get("bag", false) or shot.get("chest", false) \
				or shot.get("craft", false) or shot.get("chests", false) or shot.get("campfire", false):
			# The window settles its height a frame after it opens (see InventoryWindow.refresh).
			for i in 3:
				await process_frame
		if shot.get("death", false):
			for st in [["core:branch", 12], ["core:fiber", 9], ["core:raspberry", 23], ["core:stone_axe", 1], ["core:flint", 3]]:
				main.character.inventory.add(st[0], st[1])
			main.player.position += Vector3(14.0, 0.0, 9.0)
			main.player.position = _flat_near(main.world, main.player.position)
			# A life of two and a half days, the second in this world.
			var ch = main.character
			ch.life = {"walked": 1840.0, "dug": 64.0, "built": 23.0, "trees": 3.0, "got": 212.0, "eaten": 17.0,
				"crafted": 6.0, "jumps": 148.0}
			main.clock.day += 2
			ch.born = main.clock.day + main.clock.time_of_day - 2.4
			ch.deaths = 1
			ch.best_days = 1.2
			main.character.vitals.health = 0.0
			main.character.vitals.satiety = 0.0
			main.character.vitals.hurt_by = "hunger"
			for i in 10:
				await process_frame
			if shot.get("revive", false):
				var fell: Array = main.character.death.at
				main.death_screen._revive(Vector3(fell[0] - 1.5, fell[1], fell[2] + 1.0))
				for i in 30:
					await process_frame
		var setup: Control = null
		if shot.get("setup", false):
			setup = main.WorldSetup.new(main)
			main.hud.add_child(setup)
			# The map of the setup screen is drawn a few rows a frame.
			for i in 120:
				await process_frame
		if shot.has("main_menu"):
			main._build_menu()
			# Painted sky only for "sky": the world is built already, so it would fade.
			main.menu._fading = shot.main_menu == "sky"
			main.menu._backdrop.visible = shot.main_menu == "sky"
			await process_frame
			if shot.main_menu == "setup":
				main.menu._new_world()
				for i in 120:
					await process_frame
			if shot.main_menu == "worlds":
				_fake_saves()
				main.menu._open_worlds()
				await process_frame
			await process_frame
		if shot.get("map", false):
			main.hud.map_view.open()
			main.hud.map_view.zoom_index = shot.get("map_zoom", main.hud.map_view.FIRST_ZOOM)
			await process_frame
			await process_frame
		if shot.get("revive", false):
			# The key hints come back with the interface; they would hide the sack.
			main.hud.show_keys(false)
			await process_frame
		var img := root.get_texture().get_image()
		print("player at ", main.player.position)
		img.save_png(out_dir.path_join(shot_name + ".png"))
		if shot.has("keys"):
			_hold(shot.keys, false)
		if setup != null:
			setup.queue_free()
		if shot.has("main_menu"):
			main.menu.get_parent().queue_free()
			main.menu = null
			main.hud.visible = true
		if shot.get("map", false):
			main.hud.map_view.close()
		main.character.sacks.clear()
		print("saved ", shot_name)
		for e in added_fires:
			main.placed._remove(e)
		added_fires.clear()
		if shot.get("wall", false) or shot.get("trench", false):
			_unwall(main.world, Vector3i((main.player.position / CELL).floor()))
		main.settings.set_value("ui_scale", shot.get("ui_scale", 0))
		if shot.get("menu", false):
			main.hud.toggle_menu()
		if shot.get("test", false):
			main.hud.toggle_test()
		if shot.get("bag", false) or shot.get("chest", false) or shot.get("chests", false) or shot.get("campfire", false) \
				or (shot.get("craft", false) and not shot.get("closed", false)):
			main.hud.toggle_bag()
		if shot.get("craft", false):
			while not main.workshop.queue.jobs.is_empty():
				main.workshop.queue.cancel(0)
			for e in main.placed.things.duplicate():
				if e.item in ["core:workbench", "core:kiln"]:
					main.placed.take_up(main.character, e)
			main.character.inventory.take_all()
		if shot.get("chest", false):
			main.placed.chest_items.take_all()
		if shot.get("gather", false) or shot.get("work", false):
			main.character.inventory.take_all()
			main.character.vitals.revive(1.0)
		if shot.get("death", false):
			main.death_screen._revive(main.character.home)
		if shot.get("work", false):
			main.settings.set_value("auto_pickup", true)
			main.controls.hold("")
			main.controls._cursor_clock = 0.0
	quit()


## By the spawn: a workbench and a kiln set down in front of the player, what the first
## tools are made of in the bag, an axe being made and a pickaxe queued, the craft tab
## open at the workbench.
func _craft() -> void:
	var inv = main.character.inventory
	for st in [["core:fiber", 14], ["core:branch", 16], ["core:flint", 3], ["core:log", 2], ["core:clay", 6],
			["core:workbench", 1], ["core:kiln", 1], ["core:chest", 1]]:
		inv.add(st[0], st[1])
	main.player.facing = "s"
	main.props.put_from_bag("core:workbench")
	main.player.facing = "e"
	main.props.put_from_bag("core:kiln")
	main.player.facing = "w"
	main.props.put_from_bag("core:chest")
	main.player.facing = "s"
	var shop = main.workshop
	shop.start(Crafting.get_recipe("core:cord"), 2)
	shop.queue.jobs[0].left = 0.5
	shop.queue.step(0.25, func(_r: Dictionary) -> bool: return true)
	for e in main.placed.things:
		if e.item == "core:workbench":
			main.hud.open_prop(e)


## Puts the tool `h.tool` in the left hand and a stone block in the right, the right
## one in use if `h.right`, turns the player to `h.facing` and holds the work `h.work`
## still at its wind-up, or at its strike if `h.strike`.
func _hands(h: Dictionary) -> void:
	main.player.position = _flat_near(main.world, main.player.position)
	var inv = main.character.inventory
	inv.add(h.tool, 1)
	inv.add("core:stone", 10)
	# The tool in the left hand, a stone block in the right one; the tool's hand in use
	# unless the shot says the right one.
	main.controls.put_in_hand("core:stone", 1, false)
	main.controls.put_in_hand(h.tool, 0, false)
	if h.get("right", false):
		main.controls.set_active(1)
	await process_frame
	# The sheet with the new things in hand is built over a few frames.
	while main.player._build != null:
		await process_frame
	main.player.facing = h.facing
	if h.has("work"):
		main.player.work(h.work, 1000.0)
		if h.get("strike", false):
			main.player._work_time = 600.0
	await process_frame
	await process_frame


## By the spawn: a floor painted, a pit dug, berries knocked down, the tools taken but
## for those by the chest left lying, and the frame on what the action button digs.
func _work() -> void:
	var c = main.controls
	var w = main.world
	main.settings.set_value("auto_pickup", false)
	main.settings.give_tools()
	main.character.inventory.add("core:stone", 20)
	var f: Vector3i = c.feet()
	c.put_in_hand("core:stone")
	c.brush = 2
	var spot := f + Vector3i(-4, 0, -4)
	spot.y = w.surface_y(spot.x, spot.z)
	c.place_at(spot, Vector3i.UP)
	c.brush = 0
	c.hold("core:wooden_shovel")
	for i in 3:
		var cell := f + Vector3i(2 + i, 0, -5)
		cell.y = w.surface_y(cell.x, cell.z) - 1
		c._cooldown = 0.0
		c.dig_at(cell, Vector3i.UP)
	var bush := f + Vector3i(0, 0, -7)
	bush.y = w.surface_y(bush.x, bush.z)
	if not w.bushes.has(bush):
		w.add_bush(bush, Bushes.RASPBERRY)
		main.chunks.remesh_chunk(WorldData.chunk_key(bush.x, bush.z))
	c.hold("core:wooden_sword")
	main.gathering.gather({"bush": bush})
	# A patch of grass cut by the scythe west of the player: the near row cut once (short
	# grass), the next cut twice (dirt with fibre on it), the far row cut twice and sown
	# with grain (ears).
	c.put_in_hand("core:stone_scythe", 1, false)
	main.character.inventory.add("core:grain", 5)
	var mown := 0
	for i in 15:
		var cell := f + Vector3i(-7 + i % 5, 0, 1 + i / 5)
		cell.y = w.surface_y(cell.x, cell.z) - 1
		var one: Array[Vector3i] = [cell]
		for k in 1 if i < 5 else 2:
			if main.actions.can_mow(cell) and main.actions.mow(main.character, one):
				mown += 1
		if i >= 10:
			main.actions.plant_at(main.character, "core:grain", cell)
	print("grass cut %d times" % mown)
	c.put_in_hand("core:wooden_shovel", 0, false)
	c.set_active(1)
	main.player.facing = "s"
	main.cursor.show_cells(c._front_preview(), true)
	c._cursor_clock = 1000.0


## On the felled clearing: berry bushes by the player, the things lying nearest picked
## up, a bush picked, some blocks dug, and the character a little tired and hungry.
func _gather() -> void:
	var w = main.world
	var at := Vector3i((main.player.position / CELL).floor())
	for i in 3:
		var cell := at + Vector3i(-6 + i * 3, 0, 5)
		w.add_bush(cell, [Bushes.RASPBERRY, Bushes.BLUEBERRY, Bushes.SHRUB][i])
		main.chunks.remesh_chunk(WorldData.chunk_key(cell.x, cell.z))
	var a = main.actions
	var who = main.character
	a._from_bush(who, at + Vector3i(-6, 0, 5))
	a._from_bush(who, at + Vector3i(0, 0, 5))
	for key: Vector2i in w.drops.keys():
		var list: Array = w.drops[key]
		for i in range(list.size() - 1, -1, -1):
			if i < list.size() and list[i][1].x < main.player.position.x - 1.0:
				a.pick_up(who, key, i)
	main.character.inventory.add("core:dirt", 4)
	main.character.inventory.add("core:stone", 5)
	main.character.vitals.stamina = 45.0
	main.character.vitals.satiety = 35.0
	main.hud.refresh_counts()


## The nearest spot to `p` with level dry ground and no trees for 7 cells around.
func _hold(keys: Array, down: bool) -> void:
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)


func _flat_near(w, p: Vector3) -> Vector3:
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	for r in range(0, 60):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = w.surface_y(x, z)
				if y <= w.sea_level or w.get_cell(x, y - 1, z) != Mat.GRASS:
					continue
				var flat := true
				for oz in range(-7, 8):
					for ox in range(-7, 8):
						var nx := x + ox
						var nz := z + oz
						if w.surface_y(nx, nz) != y or w.leaf_col(nx, nz) != 0 \
								or w.slope_mask(nx, y - 1, nz) != WorldData.FULL:
							flat = false
							break
					if not flat:
						break
				if flat:
					return (Vector3(x, y, z) + Vector3(0.5, 0.0, 0.5)) * CELL
	return p


## The nearest spot to `p` inside a tall-grass meadow or a field of ears (see Grass):
## flat grass with the same cover for 2 cells around.
func _find(w, p: Vector3, what: String) -> Vector3:
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	if what.contains(":"):
		return _find_plant(w, cx, cz, what)
	for r in range(0, 150):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = w.surface_y(x, z)
				if y <= w.sea_level or w.get_cell(x, y - 1, z) != Mat.GRASS:
					continue
				var ok := true
				for oz in range(-2, 3):
					for ox in range(-2, 3):
						var nx := x + ox
						var nz := z + oz
						if w.surface_y(nx, nz) != y or w.get_cell(nx, y - 1, nz) != Mat.GRASS or w.leaf_col(nx, nz) != 0:
							ok = false
						elif what == "meadow" and Grass.tier_at(nx, nz) != Grass.TALL_TIER:
							ok = false
						elif what == "ears" and not Grass.ear_field_at(w, nx, y, nz):
							ok = false
						if not ok:
							break
					if not ok:
						break
				if ok:
					return (Vector3(x, y, z) + Vector3(0.5, 0.0, 0.5)) * CELL
	return p


## A spot two cells south of the nearest grass with plant `id` on it (see Grass.plants_on),
## where the plants are in front of the player; `p` when there is none.
func _find_plant(w, cx: int, cz: int, id: String) -> Vector3:
	for r in range(0, 150):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = w.surface_y(x, z)
				# Crowns to the south would hide it in the 3/4 view.
				var open := true
				for k in range(1, 7):
					open = open and w.leaf_col(x, z + k) == 0
				if open and y > w.sea_level and Grass.plants_on(w, x, y - 1, z).has(id) and w.surface_y(x, z + 2) == y \
						and not w.trees.has(Vector2i(x, z + 2)):
					return (Vector3(x, y, z + 2) + Vector3(0.5, 0.0, 0.5)) * CELL
	return Vector3(cx + 0.5, w.surface_y(cx, cz), cz + 0.5) * CELL


func _weather_index(id: String) -> int:
	for i in main.clock.WEATHERS.size():
		if main.clock.WEATHERS[i].id == id:
			return i
	return 0


## Standing spot at the nearest place of a kind (see WorldGen.find_place):
## the chunks there are built first, then a dry spot by the water is picked.
func _place(w, what: String) -> Vector3:
	var at: Vector3 = main.player.position
	var near := Vector2i(int(at.x / CELL), int(at.z / CELL))
	var p := Vector2(main.gen.find_place("mountain" if what == "mountain-cave" else what, near))
	if what == "mountain-cave":
		p = _mountain_cave(p)
	main.player.position = Vector3(p.x + 0.5, w.size_y - 1, p.y + 0.5) * CELL
	main.chunks.build_around()
	match what:
		"waterfall":
			return _falls_view(w, p, 2)
		"rapids":
			return _falls_view(w, p, 1)
		"lake", "river", "canyon", "swamp", "delta":
			return _dry_near(w, p, 24)
		"cliffs":
			return _coast(w, p, _seaward(w, p), 3.0)
		"beach":
			return _coast(w, p, _seaward(w, p), 4.0)
	return _dry_near(w, p, 20)


## Nearest dry standing spot to the cell point `p` within `radius` cells.
func _dry_near(w, p: Vector2, radius: int) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := int(p.x) + dx
			var z := int(p.y) + dz
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y >= w.size_y - 2 or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var d := Vector2(dx, dz).length()
			if d < best_d:
				best_d = d
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL if best_d < INF else main.player.position


## A spot before the mouth of the nearest cave cut into a mountain's side (see
## WorldGen._tunnels) to the cell point `p`, looking in.
func _mountain_cave(p: Vector2) -> Vector2:
	var g := Vector2i(floori(p.x / WorldGen.TUNNEL_GRID), floori(p.y / WorldGen.TUNNEL_GRID))
	for r in 8:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var t: Array = main.gen._tunnel(g.x + dx, g.y + dz)
				if not t.is_empty():
					return Vector2(t[0], t[1]) - t[2] * 3.0
	return p


## A dry spot beside a step of a river near the cell point `p` that drops `drop`
## levels or more to the south (seen from the front), with no crowns over it, level
## with its top or above, so the fall is not cut away.
func _falls_view(w, p: Vector2, drop: int) -> Vector3:
	var best := Vector3i(-1, -1, -1)
	var best_d := INF
	for dz in range(-60, 61):
		for dx in range(-60, 61):
			var x := int(p.x) + dx
			var z := int(p.y) + dz
			var y: int = w.surface_y(x, z)
			if y >= 0:
				continue
			var top: int = w.size_y - 1
			while top > 0 and w.get_cell(x, top, z) == Mat.AIR:
				top -= 1
			if w.get_cell(x, top, z) != Mat.WATER:
				continue
			# Falls to the south first, then to the east or west.
			var k := 0
			var turn := 0.0
			for o: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if k == 0 and w.get_cell(x + o.x, top, z + o.y) == Mat.AIR:
					k = 1
					while w.get_cell(x + o.x, top - k, z + o.y) == Mat.AIR:
						k += 1
					turn = 0.0 if o.y > 0 else 20.0
			if k < drop or Vector2(dx, dz).length() + turn >= best_d:
				continue
			var leafy := false
			for oz in range(-2, 7):
				for ox in range(-4, 5):
					leafy = leafy or w.leaf_col(x + ox, z + oz) != 0
			if leafy:
				continue
			best_d = Vector2(dx, dz).length() + turn
			best = Vector3i(x, top, z)
	if best.y < 0:
		return _dry_near(w, p, 24)
	for r in range(2, 16):
		for dz in range(-r, r + 1):
			for dx in [-r, r]:
				var y: int = w.surface_y(best.x + dx, best.z + dz)
				if y > best.y and y < best.y + 4 and w.get_cell(best.x + dx, y, best.z + dz) == Mat.AIR:
					return Vector3(best.x + dx + 0.5, y, best.z + dz + 0.5) * CELL
	return Vector3(best.x + 0.5, best.y + 1, best.z - 1.5) * CELL


## The one of eight directions from the cell point `p` in which the sea is nearest.
func _seaward(w, p: Vector2) -> Vector2:
	var best := Vector2.DOWN
	var best_d := INF
	for k in 8:
		var dir := Vector2.RIGHT.rotated(k * PI / 4.0)
		for i in 120:
			var q := p + dir * i
			if w.surface_y(int(q.x), int(q.y)) <= w.sea_level:
				if i < best_d:
					best_d = i
					best = dir
				break
	return best


## Walks from the cell point `from` toward `dir` until the sea, and stands `back`
## cells before it.
func _coast(w, from: Vector2, dir: Vector2, back: float) -> Vector3:
	var p := from
	for i in 200:
		var q := p + dir
		if w.surface_y(int(q.x), int(q.y)) <= w.sea_level:
			break
		p = q
	return _dry_near(w, p - dir * back, 4)


## Nearest dry cell next to open water, to look at the shore.
func _shore(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_d := INF
	for z in range(int(from.z) - SEARCH, int(from.z) + SEARCH):
		for x in range(int(from.x) - SEARCH, int(from.x) + SEARCH):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y > w.sea_level + 2:
				continue
			# Open water south of it, not a creek in a ravine.
			if w.get_cell(x, w.sea_level, z + 6) != Mat.WATER or w.get_cell(x, w.sea_level, z + 18) != Mat.WATER:
				continue
			var p := Vector3(x + 0.5, y, z + 0.5)
			if p.distance_to(from) < best_d:
				best_d = p.distance_to(from)
				best = p
	return best * CELL


## Water near `at` at the edge of a sea or lake, with the feet on the bottom (a
## swimmer floats up from there): one cell deep for `depth` 1, else at least `depth`
## deep. Open water lies south, the shore a few cells north.
func _in_water(w, at: Vector3, depth: int) -> Vector3:
	var from := at / CELL
	var sea: int = w.sea_level
	var best := at
	var best_d := INF
	for z in range(int(from.z) - SEARCH, int(from.z) + SEARCH):
		for x in range(int(from.x) - SEARCH, int(from.x) + SEARCH):
			var d := Vector2(x, z).distance_to(Vector2(from.x, from.z))
			if d >= best_d or w.get_cell(x, sea + 1 - depth, z) != Mat.WATER:
				continue
			if depth == 1 and w.get_cell(x, sea - 1, z) == Mat.WATER:
				continue
			var open := true
			for o in [Vector2i(-5, 6), Vector2i(0, 6), Vector2i(5, 6), Vector2i(-5, 10), Vector2i(5, 10)]:
				open = open and w.get_cell(x + o.x, sea - 1, z + o.y) == Mat.WATER
			if not open or w.surface_y(x, z - (2 if depth == 1 else 4)) <= sea or w.surface_y(x, z - 1) > 0 and depth == 1:
				continue
			var y := sea + 1 - depth
			while w.get_cell(x, y - 1, z) == Mat.WATER:
				y -= 1
			if w.corner_fills(x, y, z) != 0 or w.corner_fills(x, sea, z) != 0:
				continue
			best = Vector3(x + 0.5, y, z + 0.5) * CELL
			best_d = d
	return best


## The spot near `at` with the most sloping ground around it.
func _hills(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 48, int(from.z) + 49, 6):
		for x in range(int(from.x) - 48, int(from.x) + 49, 6):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-10, 11, 2):
				for dx in range(-14, 15, 2):
					var top: int = w.surface_y(x + dx, z + dz) - 1
					if top >= 0 and w.slope_mask(x + dx, top, z + dz) != w.FULL:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## The dry spot near `at` with the most cut or filled corners on the cliffs around it.
func _corners(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 80, int(from.z) + 81, 8):
		for x in range(int(from.x) - 80, int(from.x) + 81, 8):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-10, 11, 2):
				for dx in range(-16, 17, 2):
					var top: int = w.surface_y(x + dx, z + dz)
					for ty in range(maxi(0, top - 8), top):
						if w.corner_cuts(x + dx, ty, z + dz) != 0:
							n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## The cave floor near `at` deepest under the ground, under a roof the cut can find,
## with room to stand around it.
static func _cave(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_depth := 0
	for z in range(int(from.z) - 80, int(from.z) + 81, 2):
		for x in range(int(from.x) - 80, int(from.x) + 81, 2):
			var top: int = w.surface_y(x, z)
			for y in range(1, top - 6):
				if w.get_cell(x, y, z) != Mat.AIR or w.get_cell(x, y + 1, z) != Mat.AIR \
						or w.get_cell(x, y - 1, z) == Mat.AIR or w.get_cell(x, y - 1, z) == Mat.WATER:
					continue
				# A roof within the levels the cut looks at (see ChunkStreamer.update_cut),
				# or the spot is the floor of a tall cavern and the view stays uncut.
				var roofed := false
				for ry in range(y + 2, mini(y + 18, top)):
					if Mat.is_roof(w.get_cell(x, ry, z)):
						roofed = true
						break
				if not roofed:
					continue
				var room := 0
				for dz in range(-3, 4):
					for dx in range(-3, 4):
						if w.get_cell(x + dx, y, z + dz) == Mat.AIR and w.get_cell(x + dx, y + 1, z + dz) == Mat.AIR:
							room += 1
				if room >= 30 and top - y > best_depth:
					best_depth = top - y
					best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## Builds a plank hut on flat grass near `at` with the most trees around and puts the
## player in it, so the cut under its roof shows the walls and crowns above as ghosts.
func _hut(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := Vector3i(from.floor())
	var best_n := -1
	for z in range(int(from.z) - 60, int(from.z) + 61, 4):
		for x in range(int(from.x) - 60, int(from.x) + 61, 4):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y + 8 >= w.size_y:
				continue
			var flat := true
			for dz in range(-4, 4):
				for dx in range(-4, 4):
					if w.surface_y(x + dx, z + dz) != y or w.get_cell(x + dx, y - 1, z + dz) != Mat.GRASS:
						flat = false
			if not flat:
				continue
			var n := 0
			for dz in range(-14, 15, 2):
				for dx in range(-20, 21, 2):
					for dy in range(4, 16, 2):
						if w.get_cell(x + dx, y + dy, z + dz) == Mat.LEAVES:
							n += 1
			if n > best_n:
				best_n = n
				best = Vector3i(x, y, z)
	for dz in range(-4, 4):
		for dx in range(-4, 4):
			var wall := dx == -4 or dx == 3 or dz == -4 or dz == 3
			var door := dz == 3 and (dx == -1 or dx == 0)
			for dy in 5:
				var m := Mat.PLANKS if dy == 4 or wall and not (door and dy < 2) else Mat.AIR
				w.set_cell(best.x + dx, best.y + dy, best.z + dz, m)
	# Bushes inside would hide the player.
	for c: Vector3i in w.bushes.keys():
		if absi(c.x - best.x) <= 5 and absi(c.z - best.z) <= 5:
			w.remove_bush(c)
	for dz in range(-8, 9, 8):
		for dx in range(-8, 9, 8):
			main.chunks.on_cell_changed(best + Vector3i(dx, 0, dz))
	return (Vector3(best) + Vector3(0.5, 0.0, 0.5)) * CELL


## Replaces the ground around cell `at` with test shapes for corners: a diagonal creek,
## a stone plateau with outer and inner corners, a channel two cells wide with a bend.
## A stone wall three levels high two cells south of the player, between them and
## the camera, to look at how the player shows through what hides them.
## The cells a wall replaced, to put back after its shot: the world is shared by all
## the shots of one run.
var wall_cells: Array = []


func _wall(w, at: Vector3i) -> void:
	for z in range(at.z + 2, at.z + 4):
		for x in range(at.x - 5, at.x + 6):
			for y in range(at.y, at.y + 3):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.STONE)
				w.set_natural(x, y, z, false)
	_wall_changed(at)


func _unwall(w, at: Vector3i) -> void:
	for c in wall_cells:
		w.set_cell(c[0].x, c[0].y, c[0].z, c[1])
		w.set_natural(c[0].x, c[0].y, c[0].z, c[2])
	wall_cells.clear()
	_wall_changed(at)
	main.roof.build(w)


## Digs a trench three cells wide and four deep running north to south through `at`
## (kept in wall_cells to be filled again) and returns the spot on its floor.
func _trench(w, at: Vector3i) -> Vector3:
	for z in range(at.z - 10, at.z + 11):
		for x in range(at.x - 1, at.x + 2):
			for y in range(at.y - 4, at.y):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.AIR)
	for z in range(at.z - 16, at.z + 17, 8):
		_wall_changed(Vector3i(at.x, at.y, z - 2))
	main.roof.build(w)
	return Vector3(at.x + 0.5, at.y - 4, at.z + 0.5) * CELL


func _wall_changed(at: Vector3i) -> void:
	for x in range(at.x - 8, at.x + 9, 8):
		main.chunks.on_cell_changed(Vector3i(x, at.y, at.z + 2))


func _lab(w, at: Vector3i) -> void:
	var h := at.y
	for z in range(at.z - 18, at.z + 20):
		for x in range(at.x - 28, at.x + 30):
			var lx := x - at.x
			var lz := z - at.z
			var top := h
			var water := -1
			if lx - lz >= 8 and lx - lz <= 13:
				top = h - 8
				water = h - 5
			elif lx + lz >= 18 and lx + lz <= 21 and lx < 20:
				top = h - 4
				water = h - 3
			elif lx >= -24 and lx <= -11 and lz >= -14 and lz <= -3 and not (lx >= -16 and lz <= -9):
				top = h + 4
			elif (lz == 8 or lz == 9) and lx >= -24 and lx <= -3 or (lx == -4 or lx == -3) and lz >= 8 and lz <= 17:
				top = h - 4
			for y in w.size_y:
				var m := Mat.AIR
				if y < top:
					m = Mat.STONE if top > h or y < top - 4 else Mat.DIRT
					if y == top - 1 and top <= h:
						m = Mat.GRASS
				elif y <= water:
					m = Mat.WATER
				w.set_cell(x, y, z, m)
				w.set_natural(x, y, z, true)
	for z in range(at.z - 22, at.z + 25, 8):
		for x in range(at.x - 32, at.x + 35, 8):
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5) * CELL


## A flat meadow at `at` with trees of every species: oaks in the back row (some go
## bare in winter, the others keep their leaves), spruces of three sizes in front,
## bushes of every type between them.
## Grown once; later grove shots reuse it.
func _grove(w, at: Vector3i) -> void:
	var h := at.y
	var oaks := [-24, -8, 8, 24]
	var spruces := [-16, 0, 16]
	if w.get_cell(at.x, h - 1, at.z - 30) != Mat.GRASS or w.get_cell(at.x, h, at.z - 30) != Mat.AIR:
		for z in range(at.z - 34, at.z + 30):
			for x in range(at.x - 44, at.x + 46):
				for y in w.size_y:
					var m := Mat.AIR
					if y < h:
						m = Mat.GRASS if y == h - 1 else Mat.DIRT
					w.set_cell(x, y, z, m)
					w.set_natural(x, y, z, true)
		for key: Vector2i in w.trees.keys():
			if absi(key.x - at.x) < 52 and absi(key.y - at.z) < 40:
				w.remove_tree(key.x, key.y)
		for b: Vector3i in w.bushes.keys():
			if absi(b.x - at.x) <= 46 and absi(b.z - at.z) <= 36:
				w.remove_bush(b)
		# Bushes of every type in turn in a row before the spruces, blueberries between
		# them.
		var k := 0
		for dx in range(-21, 22, 6):
			Bushes.place(w, at.x + dx, h, at.z + 10 + (k % 2), k % Bushes.TYPES.size())
			k += 1
		for dx in [-9, -7, 7, 9]:
			Bushes.place(w, at.x + dx, h, at.z + 4 + absi(dx) % 3, Bushes.BLUEBERRY)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		# Oaks that go bare in winter and oaks that keep their leaves, in turn.
		for i in oaks.size():
			var x: int = (at.x + oaks[i]) | 1
			while Foliage.goes_bare(Vector2i(x, (at.z - 8) | 1), Trees.OAK) != (i % 2 == 0):
				x += 2
			Trees.place(w, x, h, (at.z - 8) | 1, Trees.OAK, rng)
		var sizes := [0.75, 1.0, 1.2]
		for i in spruces.size():
			Trees.place(w, (at.x + spruces[i]) | 1, h, (at.z + 6) | 1, Trees.SPRUCE, rng, sizes[i])
		for z in range(at.z - 38, at.z + 34, 8):
			for x in range(at.x - 48, at.x + 50, 8):
				main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5) * CELL


## A flat clearing at `at` (level of the ground there) with an oak west of the player
## and a spruce east of them, grown afresh each time; `fell` fells both away from the
## player a cell above their feet, as the axe would.
func _clearing(w, at: Vector3i, fell: bool) -> void:
	var h: int = w.surface_y(at.x, at.z)
	for z in range(at.z - 24, at.z + 24):
		for x in range(at.x - 30, at.x + 30):
			for y in w.size_y:
				var m := Mat.AIR
				if y < h:
					m = Mat.GRASS if y == h - 1 else Mat.DIRT
				w.set_cell(x, y, z, m)
	for key: Vector2i in w.trees.keys():
		if absi(key.x - at.x) < 40 and absi(key.y - at.z) < 34:
			w.remove_tree(key.x, key.y)
	for b: Vector3i in w.bushes.keys():
		if absi(b.x - at.x) <= 30 and absi(b.z - at.z) <= 24:
			w.remove_bush(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var oak := Vector2i((at.x - 7) | 1, (at.z - 3) | 1)
	var spruce := Vector2i((at.x + 7) | 1, (at.z - 3) | 1)
	Trees.place(w, oak.x, h, oak.y, Trees.OAK, rng)
	Trees.place(w, spruce.x, h, spruce.y, Trees.SPRUCE, rng, 0.8)
	for z in range(at.z - 28, at.z + 28, 8):
		for x in range(at.x - 34, at.x + 34, 8):
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = (Vector3(at.x, h, at.z) + Vector3(0.5, 0.0, 0.5)) * CELL
	if fell:
		for t in [oak, spruce]:
			main.actions.fell(main.character, Vector3i(t.x, h + 1, t.y))


## The open spot near `at` with the most crowns around it.
func _forest(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 80, int(from.z) + 81, 6):
		for x in range(int(from.x) - 80, int(from.x) + 81, 6):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-16, 17, 2):
				for dx in range(-24, 25, 2):
					# Columns with leaves (surface_y looks through crowns, so it
					# cannot tell a tree from the ground under it).
					var cx := x + dx
					var cz := z + dz
					if w.leaf_col(cx, cz) != 0:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## The open spot near `at` with the most trees standing apart from the others.
func _lone_trees(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var trunks: Array[Vector2i] = []
	for z in range(int(from.z) - SEARCH, int(from.z) + SEARCH):
		for x in range(int(from.x) - SEARCH, int(from.x) + SEARCH):
			for y in range(w.surface_y(x, z) - 1, 0, -1):
				if w.get_cell(x, y, z) == Mat.LOG and w.get_cell(x, y - 1, z) != Mat.LOG:
					trunks.append(Vector2i(x, z))
					break
	var lone: Array[Vector2i] = []
	for t in trunks:
		var alone := true
		for o in trunks:
			if o != t and absi(o.x - t.x) <= 6 and absi(o.y - t.y) <= 6:
				alone = false
				break
		if alone:
			lone.append(t)
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 96, int(from.z) + 97, 4):
		for x in range(int(from.x) - 96, int(from.x) + 97, 4):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for t in lone:
				if absi(t.x - x) <= 24 and absi(t.y - z) <= 14:
					n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL
