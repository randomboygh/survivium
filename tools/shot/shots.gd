extends RefCounted
## The shots tools/shot.gd takes, by name: the time of day (the sun's, Clock.sun_time, so
## the light is the same in any season; or `clock`, the time on the clock), season, weather and moon,
## where the player stands (an offset from the spawn, a place found in the world or a
## scene built for the shot, see tools/shot/places.gd), what they hold and do, and the
## settings of the picture. A new shot is a new entry here.


const SHOTS := {
	"day": {"time": 0.45, "season": 1},
	# The old screen look (Crt.LOOKS): by day, and by a fire at night for the glow.
	"crt-soft": {"time": 0.45, "season": 1, "trees": true, "settings": {"crt": 1}},
	"crt-old": {"time": 0.45, "season": 1, "trees": true, "settings": {"crt": 2}},
	"crt-tape": {"time": 0.45, "season": 1, "trees": true, "settings": {"crt": 3}},
	"crt-off": {"time": 0.45, "season": 1, "trees": true},
	"crt-fire-soft": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "settings": {"crt": 1}},
	"crt-fire-old": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "settings": {"crt": 2}},
	"crt-fire-tape": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "settings": {"crt": 3}},
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
	# The campfire at 18:00 on the clock under a full moon in each season: the sun has
	# set at the equinox and in winter and the fire casts its shadows, in summer it is day.
	"fire-18-spring": {"time": 0.75, "clock": 0.75, "season": 0, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 3},
	"fire-18-summer": {"time": 0.75, "clock": 0.75, "season": 1, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 3},
	"fire-18-winter": {"time": 0.75, "clock": 0.75, "season": 3, "moon": 1.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 3},
	# On a meadow, a campfire set down west of the player and a chest east: the player's
	# shadow falls east over the grass onto the chest. The fire's real shadow lights the
	# ground alone, its twin the grass and the chest.
	"fire-shadow-props": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "fire_shadows": 3,
		"put_fire": [-3.0, 0.0], "put": [["tools:chest", [4.0, 0.0]]]},
	"fire-shadow-props-ground": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "fire_shadows": 3,
		"shadow_on_things": false, "put_fire": [-3.0, 0.0], "put": [["tools:chest", [4.0, 0.0]]]},
	"fire-shadow-props-real": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "fire_shadows": 2,
		"put_fire": [-3.0, 0.0], "put": [["tools:chest", [4.0, 0.0]]]},
	"fire-shadows-real": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 2},
	# The torch among lone trees on a dark night: shadows of the trunks, drawn and real.
	"torch-shadows": {"time": 0.95, "season": 1, "moon": 0.0, "trees": true, "fire_shadows": 1, "hands": {"tool": "tools:torch", "facing": "s"}},
	"torch-shadows-real": {"time": 0.95, "season": 1, "moon": 0.0, "trees": true, "fire_shadows": 2, "hands": {"tool": "tools:torch", "facing": "s"}},
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
	# Without a torch: only the faint glow round the player.
	"dim-meadow": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow"},
	"dim-trees": {"time": 0.95, "season": 1, "moon": 0.0, "trees": true, "fire_shadows": 1},
	# The torch held the other way and walking east: the flame stays at the hand.
	"torch-east": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "hands": {"tool": "tools:torch", "facing": "e", "right": true}},
	"torch-meadow-moon": {"time": 0.95, "season": 1, "moon": 1.0, "find": "meadow", "hands": {"tool": "tools:torch", "facing": "s"}},
	"torch-meadow": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "hands": {"tool": "tools:torch", "facing": "s"}},
	# The torch by a wall to the north: lit from the foot of the wall up.
	"torch-wall": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "wall": "north", "hands": {"tool": "tools:torch", "facing": "s"}},
	"glow-wall": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "wall": "north", "hands": {"tool": "resources:stone", "facing": "s"}},
	# Two torches on snowy slopes in the night's fog: the rings, the fog thinner round
	# the player, the drawn shadows of the slopes.
	"torch-snow": {"time": 0.95, "season": 3, "moon": 0.0, "slopes": true, "morning_fog": 1, "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
	# Two torches on a beach of sandy steps and in a canyon: the blocks, slopes and cut
	# corners in the way of the light hide it, in their own shapes.
	"torch-beach": {"time": 0.95, "season": 1, "moon": 0.0, "place": "beach", "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
	"torch-canyon": {"time": 0.95, "season": 1, "moon": 0.0, "place": "canyon", "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
	# A torch in each hand: a flame at each.
	"torch-two": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
	# The same with the camera tilted low and steep: the rings stay round the torch.
	"torch-two-low": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "tilt": -4,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
	"torch-two-steep": {"time": 0.95, "season": 1, "moon": 0.0, "find": "meadow", "tilt": 3,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
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
	"animal-shadows": {"time": 0.32, "season": 1, "place": "beach", "sun_steps": 0, "shadow_filter": 0,
		"shadow_zoo": [["animals:sparrow", 1, 0.8, 0], ["animals:sparrow", 3, 0.8, 1], ["animals:crow", 2, 0.8, 0],
			["animals:owl", 1, 0.8, 1], ["animals:duck", 3, 0.8, 0], ["animals:bear", 0, 0.0, 0], ["animals:wolf", 2, 0.0, 0],
			["animals:deer", 0, 0.0, 1], ["animals:rabbit", 2, 0.0, 0], ["animals:butterfly", 1, 0.5, 0]]},
	"animal-shadow-trees": {"time": 0.45, "season": 1, "trees": true, "animal": Vector3(-1.0, 0.0, -0.6)},
	# The torch by the same blocks, the fire put out.
	"torch-blocks": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(-3.0, 0.0, 3.4), "fire_blocks": true,
		"fire_out": true, "fire_shadows": 1, "hands": {"tool": "tools:torch", "facing": "s"}},
	# The torch by the campfire put out: its shadow round and low like the fire, not a cube.
	"torch-campfire": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(-1.2, 0.0, 1.4), "fire_out": true,
		"fire_shadows": 1, "hands": {"tool": "tools:torch", "facing": "s"}},
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
	# Sunlight among the trees (SunRays): a clear day, a low sun, and the breaking clouds after rain.
	"rays-day": {"time": 0.45, "season": 1},
	"rays-evening": {"time": 0.72, "season": 1},
	"rays-after-rain": {"time": 0.4, "season": 1, "weather": "cloudy", "after_rain": 1.0},
	# Shafts and flecks among the trees of a forest, in the morning, at noon and in the evening.
	"rays-forest-morning": {"time": 0.32, "season": 1, "forest": true},
	"rays-forest-noon": {"time": 0.47, "season": 1, "forest": true},
	"rays-forest-evening": {"time": 0.7, "season": 1, "forest": true},
	"rays-trees": {"time": 0.33, "season": 1, "trees": true},
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
	# The deepest cave floor near the spawn of a world with many caves (world_caves 2 in
	# settings.cfg) in the view in layers, dense, early, from the head.
	"deep-cave": {"time": 0.45, "season": 1, "underground": true},
	"deep-cave-dense": {"time": 0.45, "season": 1, "underground": true,
		"settings": {"layer_density": 2, "layer_front_from": 6, "layer_above_from": 6, "layer_above_stretch": 4}},
	"deep-cave-early": {"time": 0.45, "season": 1, "underground": true,
		"settings": {"layer_front_from": 2, "layer_above_from": 2}},
	"deep-cave-head": {"time": 0.45, "season": 1, "underground": true, "settings": {"layer_line": 12}},
	"deep-cave-turn": {"time": 0.45, "season": 1, "underground": true, "turn": 1},
	"hut": {"time": 0.42, "season": 1, "hut": true},
	# Walls and floors of every building material in a row (stone, planks, brick, log
	# wall, wattle, cut stone).
	"build-materials": {"time": 0.4, "season": 1, "walls": true},
	# The blueprint: a room of planks half built (its lowest level up, the rest a ghost)
	# with a floor's ghost inside, and a wall's ghost of brick beside it.
	"build-plan": {"time": 0.4, "season": 1, "plan": true},
	# The build mode (BuildMode): the palette in the hotbar's place, the panel over it, a
	# wall's stroke over the ghost (red where it would go inside blocks), taking the ghost
	# off, a box on the ground, the interior filter.
	"build-mode": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw"},
	"build-mode-erase": {"time": 0.4, "season": 1, "plan": true, "build_mode": "erase"},
	"build-mode-cube": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw", "kind": "cube"},
	"build-mode-interior": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw", "filter": "interior"},
	"build-forms": {"time": 0.4, "season": 1, "forms": true, "hud": false, "turn": 1, "offset": Vector3(0, 0, -3)},
	"build-forms-turned": {"time": 0.4, "season": 1, "forms": true, "hud": false, "turn": 3, "offset": Vector3(0, 0, -3)},
	"build-mode-flatten": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw", "kind": "flatten"},
	"build-mode-forms": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw", "form": 3},
	"build-mode-touch": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw", "touch": true},
	"build-mode-plane": {"time": 0.4, "season": 1, "plan": true, "build_mode": "draw", "kind": "plane", "height": 2},
	# Furniture on a floor of planks: a table with stools, a bed, a cupboard, a barrel, a rug.
	"build-furniture": {"time": 0.4, "season": 1, "furniture": true},
	# Doors and windows of every size in a brick wall, a fireplace burning, a wide cupboard
	# (places.openings): by day, at dusk, and the bag by the cupboards and the barrel.
	"build-openings": {"time": 0.4, "season": 1, "openings": "wall"},
	# Stage 1 building (places.fences): a pen of fence with a wicket and a gate, the big
	# gates in a barn wall, a ladder up a wall onto a deck with hatches.
	"build-fences": {"time": 0.4, "season": 1, "fences": true},
	# Signs (decision 183, places.signs): a sign, a signpost and a board on a wall, their text
	# over them; and the window a tap on the sign opens.
	"signs": {"time": 0.4, "season": 1, "signs": "posts"},
	"signs-board": {"time": 0.4, "season": 1, "signs": "board"},
	# Gestures (decision 183): the player waving, its icon over the head; the wheel.
	"gesture-wave": {"time": 0.4, "season": 1, "signs": "none", "gesture": "wave"},
	"gesture-clap": {"time": 0.4, "season": 1, "signs": "none", "gesture": "clap"},
	"gesture-wheel": {"time": 0.4, "season": 1, "signs": "none", "gesture_wheel": true, "settings": {"solo_social": true}},
	"signs-window": {"time": 0.4, "season": 1, "signs": "posts", "sign_window": true},
	# A cross where a death's sack was (Placed.put_grave), who died there over it.
	"grave": {"time": 0.4, "season": 1, "signs": "grave"},
	"build-openings-dusk": {"time": 0.8, "season": 1, "moon": 0.0, "openings": "wall"},
	"build-openings-bag": {"time": 0.4, "season": 1, "openings": "storage", "bag": true},
	"build-openings-bag-barrel": {"time": 0.4, "season": 1, "openings": "storage", "bag": true, "storage_at": 2},
	"build-openings-bag-cupboard": {"time": 0.4, "season": 1, "openings": "storage", "bag": true, "storage_at": 3},
	# A shut brick room, a door and two windows in its east wall (places.lit_room): the
	# morning sun and lanterns outside at night shine in through the windows always and
	# through the door only open.
	"light-room": {"time": 0.3, "clock": 0.3, "season": 1, "lit_room": "shut"},
	"light-room-door": {"time": 0.3, "clock": 0.3, "season": 1, "lit_room": "shut", "door_first": true},
	"light-room-door-open": {"time": 0.3, "clock": 0.3, "season": 1, "lit_room": "open", "door_first": true},
	"light-room-night": {"time": 0.95, "season": 1, "moon": 0.0, "lit_room": "shut", "lamps": true},
	"light-room-night-open": {"time": 0.95, "season": 1, "moon": 0.0, "lit_room": "open", "lamps": true},
	"light-room-night-real": {"time": 0.95, "season": 1, "moon": 0.0, "lit_room": "shut", "lamps": true, "fire_shadows": 2},
	# The player pressed against the walls of the hut, east, west, north and south, and
	# with the camera turned a quarter: the sprite stays out of the wall.
	"walk-into-east": {"time": 0.42, "season": 1, "hut": true, "walk_into": [1, 0], "facing": "e"},
	"walk-into-west": {"time": 0.42, "season": 1, "hut": true, "walk_into": [-1, 0], "facing": "w"},
	"walk-into-north": {"time": 0.42, "season": 1, "hut": true, "walk_into": [0, -1], "facing": "n"},
	"walk-into-south": {"time": 0.42, "season": 1, "hut": true, "walk_into": [1, 1], "facing": "se"},
	"walk-into-turned": {"time": 0.42, "season": 1, "hut": true, "walk_into": [0, -1], "facing": "n", "turn": 2},
	"walk-into-turned-corner": {"time": 0.42, "season": 1, "hut": true, "walk_into": [-1, -1], "facing": "nw", "turn": 2},
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
	# The biomes of the temperate zone of new worlds: red maples, willows and poplars by water.
	"maple-wood": {"time": 0.42, "season": 1, "place": "maple_wood"},
	"floodplain": {"time": 0.42, "season": 1, "place": "floodplain"},
	"ice-waste": {"time": 0.42, "season": 1, "place": "ice_waste"},
	"stony-tundra": {"time": 0.42, "season": 1, "place": "stony_tundra"},
	"peat-bog": {"time": 0.42, "season": 1, "place": "peat_bog"},
	"forest-steppe": {"time": 0.42, "season": 1, "place": "forest_steppe"},
	"salt-flat": {"time": 0.42, "season": 1, "place": "salt_flat"},
	# The savanna in the heart of its biggest plain near the spawn of the default world (climate 1).
	"savanna": {"time": 0.42, "season": 1, "at": [-1268, -364]},
	"red-rocks": {"time": 0.42, "season": 1, "place": "red_rocks"},
	"alpine-meadow": {"time": 0.42, "season": 1, "place": "alpine_meadow"},
	"glacier": {"time": 0.42, "season": 1, "place": "glacier"},
	# The tropical zone: jungle, mangroves in a hot swamp, palms on a warm beach.
	"jungle": {"time": 0.42, "season": 1, "place": "jungle"},
	"mangrove": {"time": 0.42, "season": 1, "place": "mangrove"},
	"tropical-beach": {"time": 0.42, "season": 1, "place": "tropical_beach"},
	"canyon": {"time": 0.42, "season": 1, "place": "canyon"},
	# Relief 1 (new worlds): a gorge across a range, a mesa with banded walls, a canyon
	# through mesas in steps, a stone tor; the camera tilted low to show the walls.
	"gorge": {"time": 0.42, "season": 1, "place": "gorge", "tilt": -2},
	"mesa": {"time": 0.42, "season": 1, "place": "mesa", "tilt": -2},
	"mesa-canyon": {"time": 0.42, "season": 1, "place": "canyon", "tilt": -2},
	"tor": {"time": 0.42, "season": 1, "place": "tor", "tilt": -2},
	"lake": {"time": 0.42, "season": 1, "place": "lake"},
	"swamp": {"time": 0.42, "season": 1, "place": "swamp"},
	"cliffs": {"time": 0.42, "season": 1, "place": "cliffs"},
	"beach": {"time": 0.42, "season": 1, "place": "beach"},
	# The tallest slope turned to the camera by a beach: its patterns a pixel a texel,
	# each level shaded toward its foot (see world.gdshader, `gp`).
	"steep-beach": {"time": 0.42, "season": 1, "place": "beach", "steep": true},
	"steep-tropical": {"time": 0.42, "season": 1, "place": "tropical_beach", "steep": true},
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
	# One of every species that walks or flies in rows on a meadow, walking; every
	# swimmer in the water of a lake.
	"animals": {"time": 0.42, "season": 1, "find": "meadow", "zoo": "land"},
	# A trap with a carrot and a hare coming to it, another with a hare caught, a caught
	# hare in the hand.
	"trap": {"time": 0.42, "season": 1, "find": "meadow", "trap": true,
		"hands": {"tool": "tools:live_rabbit", "facing": "n", "stay": true}},
	"animals-water": {"time": 0.42, "season": 1, "place": "lake", "zoo": "water"},
	# Moss and mushrooms in the shade of a forest, and glowing mushrooms by night.
	"mushrooms": {"time": 0.42, "season": 1, "find": "plants:mushrooms"},
	"glow-day": {"time": 0.42, "season": 1, "find": "plants:glow_mushrooms"},
	"glow-night": {"time": 0.95, "season": 1, "moon": 0.0, "find": "plants:glow_mushrooms"},
	"glow-moon": {"time": 0.95, "season": 1, "moon": 1.0, "find": "plants:glow_mushrooms"},
	# Moss on stone, a few tops of it picked: the moss left has a ragged edge.
	# Grass pulled up for fibre in a winter meadow: the snow's edge round the patch.
	"winter-fiber": {"time": 0.42, "season": 3, "find": "meadow", "pick_fiber": true},
	"winter-fiber-early": {"time": 0.42, "season": 3, "find": "meadow", "pick_fiber": true, "snow": 0.5},
	"winter-meadow-early": {"time": 0.42, "season": 3, "find": "meadow", "snow": 0.5},
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
	"raft": {"time": 0.42, "season": 1, "place": "lake", "water": 2, "ride": "tools:raft"},
	"boat": {"time": 0.42, "season": 1, "place": "lake", "water": 2, "ride": "tools:boat"},
	# Rowing the boat south: the rower's stroke and the oars swung in time.
	"boat-row": {"time": 0.42, "season": 1, "place": "lake", "water": 2, "ride": "tools:boat", "keys": [KEY_S], "key_frames": 50},
	"boat-row-e": {"time": 0.42, "season": 1, "place": "lake", "water": 2, "ride": "tools:boat", "keys": [KEY_D]},
	"grove": {"time": 0.42, "season": 1, "grove": true},
	"grove-autumn": {"time": 0.42, "season": 2, "grove": true},
	"grove-winter": {"time": 0.45, "season": 3, "grove": true},
	"grove-spring": {"time": 0.42, "season": 0, "grove": true},
	"grove-autumn-morning": {"time": 0.31, "season": 2, "grove": true},

	# One tree of every species in a row (with the plants of the shade under their crowns), a
	# bush of every type before them: the plants mod's bundles side by side, in summer and
	# in autumn, when the berries and the fruit are ripe.
	"orchard": {"time": 0.42, "season": 1, "orchard": true},
	"orchard-autumn": {"time": 0.42, "season": 2, "orchard": true},
	"orchard-winter": {"time": 0.42, "season": 3, "orchard": true},
	"orchard-spring": {"time": 0.42, "season": 0, "orchard": true},
	# The orchard's west and east thirds, for more species than one shot holds, by season,
	# and by a low sun.
	"orchard-west": {"time": 0.42, "season": 1, "orchard": true, "pan": -55},
	"orchard-east": {"time": 0.42, "season": 1, "orchard": true, "pan": 55},
	"orchard-west-spring": {"time": 0.42, "season": 0, "orchard": true, "pan": -55},
	"orchard-east-spring": {"time": 0.42, "season": 0, "orchard": true, "pan": 55},
	"orchard-west-autumn": {"time": 0.42, "season": 2, "orchard": true, "pan": -55},
	"orchard-east-autumn": {"time": 0.42, "season": 2, "orchard": true, "pan": 55},
	"orchard-west-winter": {"time": 0.42, "season": 3, "orchard": true, "pan": -55},
	"orchard-east-winter": {"time": 0.42, "season": 3, "orchard": true, "pan": 55},
	"orchard-morning": {"time": 0.3, "season": 1, "orchard": true},
	"orchard-west-morning": {"time": 0.3, "season": 1, "orchard": true, "pan": -55},
	"orchard-east-morning": {"time": 0.3, "season": 1, "orchard": true, "pan": 55},
	# A clearing with an oak and a spruce, then the same after both are felled.
	"clearing": {"time": 0.42, "season": 1, "clearing": true},
	# The player just behind the oak of the clearing and behind its spruce: the trunk
	# clears over them but for its foot, the crown round them, no silhouette there.
	"behind-trunk": {"time": 0.42, "season": 1, "clearing": true, "offset": Vector3(-3.5, 0.0, -2.0)},
	"behind-spruce": {"time": 0.42, "season": 1, "clearing": true, "offset": Vector3(3.5, 0.0, -2.0)},
	"felled": {"time": 0.42, "season": 1, "clearing": true, "fell": true},
	# The oak and the spruce of the clearing by the full moon and by a low sun: the shape
	# of their shadows.
	"clearing-moon": {"time": 0.95, "season": 1, "moon": 1.0, "clearing": true},
	"clearing-low-sun": {"time": 0.3, "season": 1, "clearing": true},
	# Crowns of other shapes and their shadows by a low and a high sun: a lobed maple and
	# a pine on its tall trunk, a weeping willow and a poplar, a dead tree and a larch.
	"pine-low-sun": {"time": 0.3, "season": 1, "clearing": true, "trees": ["plants:maple", "plants:pine"]},
	"pine-noon": {"time": 0.5, "season": 1, "clearing": true, "trees": ["plants:maple", "plants:pine"]},
	"willow-low-sun": {"time": 0.3, "season": 1, "clearing": true, "trees": ["plants:willow", "plants:poplar"]},
	"deadwood-noon": {"time": 0.5, "season": 1, "clearing": true, "trees": ["plants:deadwood", "plants:larch"]},
	# One spruce on bare flat sand, clear sky, no sun rays, fog or interface, the sun low in
	# the east so its shaded side shows: its shape and light alone.
	"spruce-alone": {"time": 0.33, "season": 1, "specimen": ["plants:spruce"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	# A spruce, a fir and a larch side by side, the same way.
	"palm-alone": {"time": 0.33, "season": 1, "specimen": ["plants:palm"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	"conifers-alone": {"time": 0.33, "season": 1, "specimen": ["plants:fir", "plants:spruce", "plants:larch"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	"linden-alone": {"time": 0.33, "season": 1, "specimen": ["plants:linden"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	"broad-alone": {"time": 0.33, "season": 1, "specimen": ["plants:oak", "plants:linden", "plants:birch"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	"broad-alone-2": {"time": 0.33, "season": 1, "specimen": ["plants:maple", "plants:poplar", "plants:willow"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	"broad-alone-3": {"time": 0.33, "season": 1, "specimen": ["plants:apple", "plants:rowan", "plants:cherry"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	"broad-alone-4": {"time": 0.33, "season": 1, "specimen": ["plants:bird_cherry", "plants:pine", "plants:deadwood"], "weather": "clear", "clouds": 0.0, "rays": false, "fog": false, "hud": false},
	# A linden and a fir, a cherry and a larch, side by side on the clearing.
	"linden-fir": {"time": 0.42, "season": 1, "clearing": true, "trees": ["plants:linden", "plants:fir"]},
	"cherry-larch": {"time": 0.42, "season": 1, "clearing": true, "trees": ["plants:cherry", "plants:larch"]},
	"cherry-spring": {"time": 0.42, "season": 0, "clearing": true, "trees": ["plants:cherry", "plants:bird_cherry"]},
	# North of the spruce by the full moon, its shadow falling toward the player.
	"spruce-moon": {"time": 0.85, "season": 1, "moon": 1.0, "clearing": true, "offset": Vector3(0.5, 0.0, -5.0)},
	# Gathering on the felled clearing with berry bushes: some things picked up and
	# berries picked; then the bag open on a touch screen and with a mouse.
	"gather": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true},
	"bag": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true},
	# The bag's tab on the hotbar with a canvas backpack worn: 40 divisions of the same
	# width as the 16 of the bag alone («gather»), a longer tab.
	"gather-backpack": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true,
		"wear": "tools:canvas_backpack"},
	# Food going off: freshness strips under the cells, «Свежесть» of the stack chosen.
	"bag-food": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true, "food": true},
	# Quality: a dot of its grade on each cell, «Качество» of the axe chosen, its swings and swing by it.
	"bag-quality": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "quality": true},
	# Skills learned in the character window: levels, the way to the next, an axe's power in green.
	"bag-levels": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "hold": ["", "tools:stone_axe"],
		"skills": {"gather": 4, "chop": 3, "dig": 6, "craft": 2, "build": 5, "cook": 1, "hunt": 2, "fish": 1, "swim": 3}},
	# A skill's new level: gold edges, stars rising round the player, the notice in the corner.
	"level-up": {"time": 0.42, "season": 1, "clearing": true, "level_up": "chop"},
	# A stone axe made by a skilled hand (decision 164, 4А): its swings to spare shown on
	# the wear chip, "сделано умелой рукой: прочнее на N%" in its tip.
	"bag-skilled": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true,
		"give": "tools:stone_axe", "worn": -30},
	"bag-pc": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "bag": true},
	# A canvas backpack worn (24 more slots, scrolled where they do not fit), a wicker bag
	# chosen in the bag: its wide button puts it on; then a tap on the backpack on the figure
	# takes it off (into the first free slot, with the things of its slots).
	"bag-gear": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"wear": "tools:canvas_backpack", "give": "tools:wicker_bag"},
	# A winter evening in fibre clothes, chilled and wet: the warmth bar low and blue with
	# the drop; and the bag open with them worn, one more cape chosen in the bag (its warmth).
	"cold": {"time": 0.8, "season": 3, "clearing": true, "wear": ["tools:fiber_hat", "tools:grass_cape", "tools:leg_wraps", "tools:bast_shoes"],
		"chill": [22.0, 0.7]},
	"bag-clothes": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true,
		"wear": ["tools:fiber_hat", "tools:grass_cape", "tools:leg_wraps", "tools:bast_shoes"], "give": "tools:grass_cape"},
	# Asleep at night by the spawn's campfire.
	"asleep": {"time": 0.92, "season": 1, "touch": true, "asleep": true},
	# A grass mat and a fur bedroll set down; the mat tapped: lying in it asleep, «zzZ» over the head.
	"bed": {"time": 0.42, "season": 1, "touch": true, "bed": ["tools:grass_mat", "tools:fur_bedroll"]},
	# Thirsty, a full waterskin chosen in the bag (its water).
	"bag-water": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "thirst": 15.0,
		"give": "tools:waterskin_full"},
	# Hide clothes worn, a fur coat chosen in the bag (its warmth).
	"bag-furs": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true,
		"wear": ["tools:fur_hat", "tools:fur_coat", "tools:leather_trousers", "tools:fur_boots"], "give": "tools:fur_coat"},
	"bag-worn": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"wear": "tools:canvas_backpack", "person": "back"},
	# «Выдать инструменты» pressed (Items.best_kit: the best tool of each class, a light,
	# the biggest bag put on at once), then the bag open.
	"bag-kit": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "kit": true},
	# A chest chosen in the bag: its wide button sets it down.
	"bag-put": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"give": "tools:chest"},
	# An axe and a bow held (no arrows: the bow shows inactive and adds nothing to the
	# skills), a leather sling chosen: what it shoots, none in the bag.
	"bag-skills": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "kit": true,
		"hold": ["tools:stone_axe", "tools:wooden_bow"]},
	# A worn tool chosen: the spanner by its name.
	"bag-repair": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "kit": true, "slot": 6, "worn": 40},
	# The same with nothing chosen: the panel at the bottom as tall.
	"bag-none": {"time": 0.42, "season": 1, "clearing": true, "touch": true, "bag": true, "kit": true, "slot": -1},
	# A torch chosen in the bag: «взять | поставить» joined.
	"bag-light": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "gather": true, "touch": true, "bag": true,
		"give": "tools:torch"},
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
	# chests listed under the bag.
	"chests": {"time": 0.42, "season": 1, "touch": true, "work": true, "chests": true},
	# A big chest (40 slots) set down by the spawn's chest: both under the bag.
	"chests-take": {"time": 0.42, "season": 1, "touch": true, "work": true, "chests": true, "take_all": true},
	"chests-take-worn": {"time": 0.42, "season": 1, "touch": true, "work": true, "chests": true, "take_all": true,
		"wear": ["tools:fiber_hat", "tools:grass_cape", "tools:leg_wraps", "tools:bast_shoes", "tools:wicker_bag"]},
	# A bag and a chest with things in the bag: each a grid under it, after the chest set down.
	"chests-packed": {"time": 0.42, "season": 1, "touch": true, "work": true, "chests": true, "packed": true, "scroll": 330},
	"chests-big": {"time": 0.42, "season": 1, "touch": true, "work": true, "chests": true, "box": "tools:big_chest"},
	# A workbench, a kiln and a chest placed by the spawn, the craft tab open at the workbench
	# with an axe being made and more queued.
	"craft": {"time": 0.42, "season": 1, "touch": true, "craft": true},
	"craft-pc": {"time": 0.42, "season": 1, "craft": true},
	# A recipe with many facts (a stone scythe) on a narrow phone screen, and the craft tab
	# before any recipe is known: no queue then.
	"craft-scythe": {"time": 0.42, "season": 1, "touch": true, "craft": true, "recipe": "tools:stone_scythe"},
	"craft-unknown": {"time": 0.42, "season": 1, "touch": true, "craft": true, "unknown": true},
	"craft-free": {"time": 0.42, "season": 1, "touch": true, "craft": true, "unknown": true, "free": true},
	"craft-free-tools": {"time": 0.42, "season": 1, "touch": true, "craft": true, "unknown": true, "free": true, "recipe": "materials:log_wall"},
	# The craft tab with nothing queued: no queue panel under the recipe.
	"craft-idle": {"time": 0.42, "season": 1, "touch": true, "craft": true, "idle": true},
	# The spawn campfire at night full of fuel, and nearly burned down: its flames and light
	# follow what it has left.
	"fire-full": {"time": 0.9, "season": 1, "moon": 0.0, "place": "beach", "fuel": 1.0},
	"fire-low": {"time": 0.9, "season": 1, "moon": 0.0, "place": "beach", "fuel": 0.05},
	# Standing right by the spawn campfire, over its stones: only its logs stop a body.
	"fire-close": {"time": 0.42, "season": 1, "touch": true, "fire_close": true},
	# The spawn campfire opened: the craft tab with its buttons by the cross.
	"campfire": {"time": 0.42, "season": 1, "touch": true, "campfire": true},
	# The same workbench, kiln and chest with the window closed.
	"stations": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true},
	# A forge set down with the rest, closed; and open, a copper bar being smelted in it.
	"forge": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true, "forge": true},
	"craft-forge": {"time": 0.42, "season": 1, "touch": true, "craft": true, "forge": true, "recipe": "tools:copper_bar"},
	# A loom and a potter's wheel set down by the workbench and kiln, closed, the new things of
	# flax, tar, pottery and glass lying in front; and the loom open, linen cloth being woven.
	"weave": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "craft": true, "closed": true, "weave": true,
		"drops": ["plants:flax_stalks", "plants:linen_thread", "materials:cloth", "materials:tar", "materials:glass", "tools:raw_pot", "tools:pot", "tools:lantern", "tools:tar_torch", "plants:roasted_acorns"]},
	"craft-loom": {"time": 0.42, "season": 1, "touch": true, "craft": true, "weave": true, "recipe": "plants:cloth"},
	# Logs and branches lying on the ground, as a felled tree leaves them.
	"logs": {"time": 0.42, "season": 1, "clearing": true, "drops": ["resources:log", "resources:log", "resources:branch", "resources:log", "resources:branch", "resources:log"]},
	# A copper pickaxe at its strike, and copper tools lying on the ground.
	"hands-copper": {"time": 0.42, "season": 1, "hands": {"tool": "tools:copper_pickaxe", "facing": "e", "work": "chop", "strike": true},
		"drops": ["tools:copper_axe", "tools:copper_sword", "tools:copper_scythe", "tools:copper_shovel", "materials:copper_bar", "materials:charcoal"]},
	# A bloomery and an anvil set down by the workbench and kiln, closed, the things of iron and
	# steel lying in front; and the anvil open, a steel axe being forged.
	"smith": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "craft": true, "closed": true, "smith": true,
		"drops": ["materials:iron_ore", "materials:iron_bloom", "materials:iron_bar", "materials:steel_bar", "tools:iron_axe", "tools:iron_pickaxe",
			"tools:iron_sword", "tools:steel_axe", "tools:steel_pickaxe", "tools:steel_sword", "tools:steel_scythe", "tools:steel_shovel"]},
	"craft-anvil": {"time": 0.42, "season": 1, "touch": true, "craft": true, "smith": true, "recipe": "tools:steel_axe"},
	# Every recipe known: the list cut through its fifth row, the stations' column with arrows.
	"craft-all": {"time": 0.42, "season": 1, "touch": true, "craft": true, "smith": true, "recipe": "tools:steel_axe", "know_all": true},
	# An iron knife at its strike at a deer, and what game gives lying on the ground.
	"hunt": {"time": 0.42, "season": 1, "clearing": true, "prey": ["animals:deer", 4, -1],
		"hands": {"tool": "tools:iron_knife", "facing": "e", "work": "slash", "strike": true},
		"drops": ["animals:small_carcass", "animals:carcass", "animals:raw_meat", "animals:roasted_meat", "animals:hide", "animals:bone",
			"animals:fat", "tools:flint_knife", "tools:bronze_knife", "tools:steel_knife"]},
	# Beasts going for the player (Wildlife._fights): a boar growling a warning, a wolf and
	# a bear at their bite (the last attack frame).
	"beasts": {"time": 0.42, "season": 1, "clearing": true, "hands": {"tool": "tools:iron_spear", "facing": "e"},
		"beasts": [["animals:boar", -3, 1, "warn"], ["animals:wolf", 2, 0, "bite"], ["animals:bear", 1, -3, "bite"]]},
	# A bow drawn at a deer, an arrow halfway to it, and the spears, the sling and its
	# stones, the bow and arrows lying on the ground.
	"ranged": {"time": 0.42, "season": 1, "clearing": true, "prey": ["animals:deer", 10, -1], "flight": "tools:arrow",
		"hands": {"tool": "tools:wooden_bow", "facing": "e", "work": "slash", "strike": true},
		"drops": ["tools:flint_spear", "tools:bronze_spear", "tools:iron_spear", "tools:cord_sling", "tools:sling_stone",
			"tools:wooden_bow", "tools:arrow"]},
	# A rod in hand on the shore of a lake and the fish it catches lying on the ground.
	"fishing": {"time": 0.42, "season": 1, "place": "lake", "hands": {"tool": "tools:fishing_rod", "facing": "s", "work": "slash", "strike": true},
		"drops": ["tools:fishing_rod", "animals:roach", "animals:pike", "animals:salmon", "animals:cod", "animals:parrotfish",
			"animals:catfish", "animals:perch", "animals:roasted_fish", "tools:bait"]},
	# The rod cast from the shore of a lake: the arm held out, the line and the float on the
	# water, a roach swimming up to it; then the roach biting, the float pulled under. On
	# the phone's layout, the action button stays pressed down and says what it does next.
	"fishing-cast": {"time": 0.42, "season": 1, "place": "lake", "hands": {"tool": "tools:fishing_rod", "facing": "s", "stay": true},
		"cast": "wait"},
	"fishing-bite": {"time": 0.42, "season": 1, "place": "lake", "hands": {"tool": "tools:fishing_rod", "facing": "s", "stay": true},
		"cast": "bite"},
	# A drying rack set down by the workbench and kiln, closed, a composite bow in hand, the
	# things of leather and bone lying in front; and the rack open, leather being tanned.
	"leather": {"time": 0.42, "season": 1, "clearing": true, "fell": true, "craft": true, "closed": true, "dry": true,
		"hands": {"tool": "tools:composite_bow", "facing": "s", "stay": true},
		"drops": ["materials:leather", "materials:bone_glue", "tools:bone_needle", "tools:tallow_candle", "animals:jerky", "tools:leather_sling",
			"tools:composite_bow", "animals:hide", "animals:bone", "animals:fat"]},
	"craft-dry": {"time": 0.42, "season": 1, "touch": true, "craft": true, "dry": true, "recipe": "materials:leather"},
	# A bronze pickaxe at its strike, and the things of tin and bronze lying on the ground.
	"hands-bronze": {"time": 0.42, "season": 1, "clearing": true, "hands": {"tool": "tools:bronze_pickaxe", "facing": "e", "work": "chop", "strike": true},
		"drops": ["materials:tin_ore", "materials:tin_bar", "materials:raw_crucible", "materials:crucible", "materials:bronze_bar", "tools:bronze_axe",
			"tools:bronze_sword", "tools:bronze_scythe", "tools:bronze_shovel"]},
	# The precious metals: their ores, bars and blocks lying by copper and bronze to compare.
	"metals": {"time": 0.42, "season": 1, "clearing": true, "hands": {"tool": "tools:bronze_pickaxe", "facing": "e", "stay": true},
		"drops": ["materials:silver_ore", "materials:silver_bar", "materials:gold_ore", "materials:gold_bar", "materials:platinum_ore",
			"materials:platinum_bar", "materials:copper_bar", "materials:bronze_bar", "materials:silver_block", "materials:gold_block",
			"materials:platinum_block", "tools:bronze_axe"]},
	# The same with the player standing on the chest, by the front edge of its lid, and on
	# the workbench as far back as its planks hold.
	"stations-top": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true,
		"on": ["tools:chest", Vector3(1.0, 1.5, 1.6)]},
	"bench-top": {"time": 0.42, "season": 1, "touch": true, "clearing": true, "fell": true, "craft": true, "closed": true,
		"on": ["tools:workbench", Vector3(1.0, 1.5, 0.2)]},
	# The death screen: dead of hunger by the spawn with a few things in the bag.
	"death": {"time": 0.42, "season": 1, "touch": true, "death": true},
	"death-pc": {"time": 0.42, "season": 1, "death": true},
	# Т4: come back at one's own fire or a teammate's.
	"death-fires": {"time": 0.42, "season": 1, "touch": true, "death": true, "fires": true},
	# With a bed of one's own set down: it comes first.
	"death-bed": {"time": 0.42, "season": 1, "touch": true, "death": true, "fires": true, "own_bed": true},
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
	"turn-spin": {"time": 0.45, "season": 1, "trees": true, "spin": 22},
	"turn-trees": {"time": 0.45, "season": 1, "trees": true},
	"tilt-low": {"time": 0.45, "season": 1, "trees": true, "tilt": -2},
	"tilt-steep": {"time": 0.45, "season": 1, "trees": true, "tilt": 2},
	"tilt-lowest": {"time": 0.45, "season": 1, "trees": true, "tilt": -4},
	"tilt-steepest": {"time": 0.45, "season": 1, "trees": true, "tilt": 3},
	"turn-hut": {"time": 0.45, "season": 1, "hut": true, "turn": 3, "tilt": -1},
	"turn-ui": {"time": 0.45, "season": 1, "turn": 7, "tilt": 1, "touch": true},
	"turn-fire": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 1, "turn": 2},
	"turn-forest": {"time": 0.45, "season": 1, "forest": true, "turn": 4},
	"ui-touch": {"time": 0.45, "season": 1, "touch": true, "toast": true},
	"ui-menu": {"time": 0.45, "season": 1, "touch": true, "menu": true},
	# Teams (decision 50): a member's name in the team's colour, a tapped player's card,
	# an invitation, the pause's window «Команда».
	"team-person": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "team": "person"},
	"team-chat": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "team": "chat"},
	"team-invite": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "team": "invite"},
	"team-panel": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "team": "panel", "team_panel": true},
	# Teammates on the map: Боря near, Гена far to the north-east beyond the minimap's edge.
	"team-map": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "team": "map", "map": true, "map_zoom": 4},
	"team-minimap": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "team": "map"},
	"land": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "land": false},
	# The boundary post close, its shadow on the grass in the afternoon sun.
	# The action button's label by what is in front: water to drink with bare hands.
	"label-drink": {"time": 0.45, "season": 1, "touch": true, "place": "lake", "face_water": true},
	"post-close": {"time": 0.6, "season": 1, "find": "meadow", "land": false},
	"post-snow": {"time": 0.36, "season": 3, "find": "meadow", "land": false},
	"land-paint": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "land": true},
	"land-rights": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "land": false, "rights": true},
	"land-colors": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "land": false, "rights": true, "land_end": true},
	"land-decay": {"time": 0.45, "season": 1, "touch": true, "find": "meadow", "land": false, "decay": true},
	"ui-settings": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings"},
	"ui-test": {"time": 0.45, "season": 1, "touch": true, "test": true},
	"ui-settings-pc": {"time": 0.45, "season": 1, "menu": true, "page": "settings"},
	# The graphics section of the settings: the quality preset over the settings by hand.
	"ui-settings-graphics": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings", "section": "graphics"},
	"ui-settings-graphics-pc": {"time": 0.45, "season": 1, "menu": true, "page": "settings", "section": "graphics"},
	"ui-test-pc": {"time": 0.45, "season": 1, "menu": true, "page": "test"},
	# The playtest page's other tabs: the player's switches and the tools button, debugging.
	"ui-test-player": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "player"},
	"ui-test-player-end": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "player",
		"menu_end": true},
	"ui-test-debug": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug"},
	"ui-test-server": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "server"},
	# «Витрина интерфейса» (UiGallery), each of its tabs.
	"ui-gallery-buttons": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug", "gallery": "buttons"},
	"ui-gallery-rows": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug", "gallery": "rows"},
	"ui-gallery-slots": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug", "gallery": "slots"},
	"ui-gallery-fields": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug", "gallery": "fields"},
	"ui-gallery-lists": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug", "gallery": "lists"},
	"ui-gallery-look": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "test", "section": "debug", "gallery": "look"},
	# The freezes' log and the playtest report, windows of the playtest page.
	"ui-freezes": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "freezes", "freezes": true},
	"ui-report": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "report"},
	# Two-figure counts on the tabs; «Скопировать» tapped (green), «Очистить журнал» once (red).
	"ui-freezes-press": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "freezes", "freezes": true,
		"many": 12, "press": ["_copy", "_clear"]},
	"ui-defaults-ask": {"time": 0.45, "season": 1, "touch": true, "menu": true, "page": "settings", "press": ["_defaults"]},
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
	"ui-settings-interface-pc": {"time": 0.45, "season": 1, "menu": true, "page": "settings", "section": "interface"},
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
	# The tools without the fibre's bundle: under each one left out, what it lacks, to the fibre.
	"ui-setup-mod-left-out": {"time": 0.45, "season": 1, "touch": true, "setup": "mod:tools", "mods_off": "resources/fiber"},
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
	# The main menu over the live world (the pause menu's way back to it), over the painted
	# landscape at the hours asked, the loading screen, and with the setup screen of a new
	# world open over it.
	"ui-main-menu": {"time": 0.42, "season": 1, "touch": true, "main_menu": "live"},
	"ui-main-menu-pc": {"time": 0.42, "season": 1, "main_menu": "live"},
	"ui-main-menu-sky": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 12.0},
	"ui-main-menu-loading": {"time": 0.42, "season": 1, "touch": true, "main_menu": "loading", "menu_hour": 20.5},
	"ui-main-menu-loading-pc": {"time": 0.42, "season": 1, "main_menu": "loading"},
	"ui-main-menu-sky-pc": {"time": 0.42, "season": 1, "main_menu": "sky", "menu_hour": 12.0},
	"ui-main-menu-dawn": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 6.3},
	"ui-main-menu-sunset": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 19.6},
	"ui-main-menu-night": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 23.5},
	"ui-main-menu-single-sky": {"time": 0.42, "season": 1, "touch": true, "main_menu": "single", "painted": true,
		"menu_hour": 15.0},
	# The easter egg: ten taps on the sparrow of the name burst it into feathers, caught
	# as they fly apart and later as they drift down.
	"ui-main-menu-egg": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 22.0, "egg": true,
		"egg_ms": 400},
	"ui-main-menu-egg-fall": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 13.0,
		"egg": true, "egg_ms": 2200},
	# The developer mode the egg opens: the build's version under the name.
	"ui-main-menu-dev": {"time": 0.42, "season": 1, "touch": true, "main_menu": "sky", "menu_hour": 13.0,
		"dev": true},
	"ui-main-menu-setup": {"time": 0.42, "season": 1, "touch": true, "main_menu": "setup"},
	# The list of saved worlds, over a few saves made up for it.
	"ui-main-menu-changes": {"time": 0.42, "season": 1, "touch": true, "main_menu": "changes"},
	"ui-main-menu-worlds": {"time": 0.42, "season": 1, "touch": true, "main_menu": "worlds"},
	# The pages «Одиночная игра» and «Мультиплеер» («Создать сервер» tapped on a phone),
	# and «Присоединиться» over a few servers made up for it, then saying why joining failed.
	# Opened from the pause over a running world: «Продолжить» first.
	"ui-main-menu-resume": {"time": 0.42, "season": 1, "touch": true, "main_menu": "resume"},
	"ui-main-menu-single": {"time": 0.42, "season": 1, "touch": true, "main_menu": "single"},
	"ui-main-menu-multi": {"time": 0.42, "season": 1, "touch": true, "main_menu": "multi", "press_host": true},
	"ui-main-menu-join": {"time": 0.42, "season": 1, "touch": true, "main_menu": "join"},
	# «Создать сервер» on a computer, before and while it runs.
	"ui-main-menu-host": {"time": 0.42, "season": 1, "main_menu": "host"},
	"ui-main-menu-host-settings": {"time": 0.42, "season": 1, "main_menu": "host", "host_tab": 1},
	"ui-main-menu-host-running": {"time": 0.42, "season": 1, "main_menu": "host-running"},
	# The largest interface on a landscape screen: the first page and «Создать сервер»
	# still fit (the column and the window scroll when they cannot).
	"ui-main-menu-big": {"time": 0.42, "season": 1, "touch": true, "main_menu": "resume", "ui_size": 4},
	"ui-main-menu-host-big": {"time": 0.42, "season": 1, "main_menu": "host", "ui_size": 4},
	"ui-main-menu-join-failed": {"time": 0.42, "season": 1, "touch": true, "main_menu": "join",
		"error": "[the_server_does_not_respond]"},
	# The grounds of the test world (TestGround), a run of their own: the player at
	# `at` (cells). Named "ground-*", they switch the run to the test world.
	"ground-spawn": {"time": 0.42, "season": 1, "at": [0, 0]},
	"ground-steps": {"time": 0.42, "season": 1, "at": [-28, -24]},
	# The farm: dry beds, wet beds, each crop (wheat, turnip, carrot, peas, flax) at each stage; a hoe in hand.
	"ground-farm": {"time": 0.42, "season": 1, "at": [69, 29], "hold": ["", "tools:stone_hoe"]},
	# The saplings east of the farm (TestGround.SAPLINGS): oak and spruce, each stage.
	"ground-saplings": {"time": 0.42, "season": 1, "at": [81, 30]},
	# The last oak and spruce saplings grown into young trees.
	"ground-sapling-young": {"time": 0.42, "season": 1, "at": [81, 30], "sapling_tree": "young"},
	# The last oak sapling grown into a tree, then felled: its crown's shadow goes with it.
	"ground-sapling-tree": {"time": 0.42, "season": 1, "at": [81, 30], "sapling_tree": "grown"},
	"ground-sapling-felled": {"time": 0.42, "season": 1, "at": [81, 30], "sapling_tree": "felled"},
	# The farming mode (FarmMode): the palette of seeds and bushes, the panel, marks of
	# every work, a square stroke to sow held.
	"ground-farm-mode": {"time": 0.42, "season": 1, "at": [69, 29], "farm_mode": "draw"},
	"ground-farm-mode-touch": {"time": 0.42, "season": 1, "at": [69, 29], "farm_mode": "draw", "touch": true, "work": "till"},
	# In the trench between the loose and the stone ledges of 3 and 5 cells: the cut hides
	# them, their rounded corners cut.
	# A torch at night among the steps: the drawn shadows of the slopes and cut corners.
	"ground-steps-torch": {"time": 0.95, "season": 1, "moon": 0.0, "at": [-28, -24], "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s"}},
	# A lantern in a pit a cell deep: the ground round its rim, the lantern hardly over it,
	# gets rings closing in, not a flat disc cut off sharp (bug 2026-11-08).
	"ground-lantern-pit": {"time": 0.95, "season": 1, "moon": 0.0, "at": [-22, -35], "pit": 1,
		"hands": {"tool": "tools:fishing_rod", "other": "tools:lantern", "facing": "n"}},
	"ground-stair-torch": {"time": 0.95, "season": 1, "moon": 0.0, "at": [3, 45], "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s", "stay": true}},
	"ground-pyramid-torch": {"time": 0.95, "season": 1, "moon": 0.0, "at": [-8, 49], "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s", "stay": true}},
	# The clay row of the combinations ground at the cliff and the ridge: no dashes of
	# another material spilled along the cells' north edges.
	"ground-clay-ridge": {"time": 0.72, "season": 1, "at": [-10, -176]},
	"ground-steps-cut": {"time": 0.42, "season": 1, "at": [-22, -35]},
	"ground-steps-cut-n": {"time": 0.42, "season": 1, "at": [-18, -35]},
	"ground-pits": {"time": 0.42, "season": 1, "at": [0, -32]},
	"ground-cave": {"time": 0.42, "season": 1, "at": [27, -20]},
	"ground-cave-inside": {"time": 0.42, "season": 1, "at": [27, -38], "y": 23},
	# The star cave (TestGround.STAR): its mound with the hole at the top, on its west ledge
	# (the floor of the upward tetrahedron's base), at its lower point.
	"ground-star": {"time": 0.42, "season": 1, "at": [30, -64]},
	"ground-star-inside": {"time": 0.42, "season": 1, "at": [22, -72], "y": 17},
	"ground-star-bottom": {"time": 0.42, "season": 1, "at": [28, -72], "y": 3},
	# Up the far side of the mound over the star cave: the mound stays whole.
	"ground-star-back": {"time": 0.42, "season": 1, "at": [28, -79]},
	# Behind the stone hill, the steps, the hut and in the star cave's shaft: the cut is on.
	"ground-behind-hill": {"time": 0.42, "season": 1, "at": [14, -48]},
	# Diagonal corners of slopes behind the player (behind a hill) and over them (under a roof).
	"ground-diagonals-behind": {"time": 0.42, "season": 1, "at": [47, -57], "y": 18},
	"ground-diagonals-hill": {"time": 0.42, "season": 1, "at": [14, -47], "y": 23},
	# A lantern by day in a cave 19 levels under the sea: it lights as on the surface at night.
	# The same lantern almost burned out: dimmer (Sky.charge_gain).
	"ground-lantern-burnt": {"time": 0.42, "season": 1, "at": [3, -39], "y": 1, "room": true, "burnt": 0.9, "hands": {"tool": "tools:lantern", "facing": "s", "stay": true}},
	"ground-lantern-deep": {"time": 0.42, "season": 1, "at": [3, -39], "y": 1, "room": true, "hands": {"tool": "tools:lantern", "facing": "s", "stay": true}},
	"ground-diagonals-roof": {"time": 0.42, "season": 1, "at": [43, -53], "y": 19},
	# Deep in the star cave, under its upper point.
	"ground-star-deep": {"time": 0.42, "season": 1, "at": [23, -75], "y": 17},
	"ground-behind-steps": {"time": 0.42, "season": 1, "at": [-14, -45]},
	"ground-behind-hut": {"time": 0.42, "season": 1, "at": [52, -5]},
	"ground-star-shaft": {"time": 0.42, "season": 1, "at": [28, -73], "y": 25},
	# In the pit, under the sea's surface: darker by the levels.
	"ground-pit": {"time": 0.42, "season": 1, "at": [-5, -38]},
	"ground-forest": {"time": 0.42, "season": 1, "at": [-30, 2]},
	"ground-materials": {"time": 0.42, "season": 1, "at": [32, 12]},
	# The clay: its top in the strip of materials, its walls on the row of relief.
	"ground-clay": {"time": 0.42, "season": 1, "at": [30, -4]},
	"ground-clay-relief": {"time": 0.42, "season": 1, "at": [-40, 74]},
	"ground-hut": {"time": 0.42, "season": 1, "at": [54, 7]},
	"ground-pond": {"time": 0.42, "season": 1, "at": [-30, 12]},
	# The plant garden east of the field of ears: trees, bushes and ground plants in pens.
	"ground-plants-west": {"time": 0.42, "season": 1, "at": [180, -28]},
	"ground-plants-east": {"time": 0.42, "season": 1, "at": [228, -28]},
	# The bird cherry's pen (white blossom) and the cherry's (pale pink) in spring and in summer.
	"ground-cherry-spring": {"time": 0.42, "season": 0, "at": [219, -60]},
	"ground-cherry-summer": {"time": 0.42, "season": 1, "at": [219, -60]},
	# The garden's trees up close, west to east, and in autumn and winter.
	"ground-garden-1": {"time": 0.42, "season": 1, "at": [179, -60]},
	"ground-garden-2": {"time": 0.42, "season": 1, "at": [227, -60]},
	"ground-garden-autumn": {"time": 0.42, "season": 2, "at": [227, -60]},
	"ground-garden-winter": {"time": 0.42, "season": 3, "at": [227, -60]},
	# The house of brick (TestGround.HOUSE): from the south, both floors inside, at night.
	"ground-house": {"time": 0.42, "season": 1, "at": [70, -43]},
	"ground-house-inside": {"time": 0.42, "season": 1, "at": [70, -52], "y": 23},
	"ground-house-upper": {"time": 0.42, "season": 1, "at": [70, -52], "y": 27},
	"ground-house-night": {"time": 0.95, "season": 1, "moon": 0.0, "at": [70, -52], "y": 23},
	# A lantern held in the low house at night: it burns in the hand, under the roof.
	"ground-house-lantern": {"time": 0.95, "season": 1, "moon": 0.0, "at": [70, -52], "y": 23,
		"hands": {"tool": "tools:lantern", "facing": "s", "stay": true}},
	# Its east wall from outside, turned: the double door 2×2 and the door 1×2.
	"ground-house-east": {"time": 0.42, "season": 1, "at": [80, -53], "turn": 1},
	# The descents (TestGround.DESCENT, DESCENT45): the mouths, a step down inside, the bottom.
	"ground-descent": {"time": 0.42, "season": 1, "at": [-120, -38]},
	"ground-descent-inside": {"time": 0.42, "season": 1, "at": [-143, -55], "y": 18},
	"ground-descent-bottom": {"time": 0.42, "season": 1, "at": [-236, -55], "y": 1},
	"ground-descent45": {"time": 0.42, "season": 1, "at": [-110, -12]},
	"ground-descent45-inside": {"time": 0.42, "season": 1, "at": [-138, 1], "y": 18},
	# The beach (TestGround.BEACH) going down into the sea.
	"ground-beach": {"time": 0.42, "season": 1, "at": [-125, 112]},
	"ground-beach-deep": {"time": 0.42, "season": 1, "at": [-150, 112], "y": 21},
	# The biome plots south of the relief ground, five in a row from x -70 (TestGround.BIOME_*):
	# the first row's birch grove and desert, forest and meadow, pine wood; the second
	# row's steppe and taiga, tundra, swamp and beach.
	"ground-biomes": {"time": 0.42, "season": 1, "at": [-44, 118]},
	"ground-biomes-forest": {"time": 0.42, "season": 1, "at": [-14, 118]},
	"ground-biomes-east": {"time": 0.42, "season": 1, "at": [26, 118]},
	"ground-biomes-south": {"time": 0.42, "season": 1, "at": [-44, 146]},
	"ground-biomes-tundra": {"time": 0.42, "season": 1, "at": [-2, 146]},
	# The swamp plot: pools in the north, a pond running into a bog in the south, and
	# the player wading the bog.
	"ground-swamp": {"time": 0.42, "season": 1, "at": [26, 140]},
	"ground-bog": {"time": 0.42, "season": 1, "at": [24, 147], "y": 23},
	# Swimming in the deep end of the pond and in the deep corner of the swamp's pond.
	"ground-swim": {"time": 0.42, "season": 1, "at": [-20, 26], "y": 18},
	"ground-swim-swamp": {"time": 0.42, "season": 1, "at": [22, 142], "y": 21},
	"ground-bushes": {"time": 0.42, "season": 1, "at": [78, 9]},
	"ground-relief-west": {"time": 0.42, "season": 1, "at": [-46, 64]},
	"ground-relief-middle": {"time": 0.42, "season": 1, "at": [2, 64]},
	"ground-relief-east": {"time": 0.42, "season": 1, "at": [50, 64]},
	"ground-relief-winter": {"time": 0.42, "season": 3, "at": [2, 64]},
	# The stream down its terraces, from the meadow south of it and from its top.
	# The combinations ground (TestGround.COMBO_*): its west (the shapes of the relief
	# ground) and its east (bowl, diagonal, notch, shafts, overhang, tunnel), the rows of
	# one material to the north of each band and the mixed ones to the south.
	"ground-combo-west": {"time": 0.42, "season": 1, "at": [-80, -190]},
	"ground-combo-mixed": {"time": 0.42, "season": 1, "at": [-80, -130]},
	"ground-combo-east": {"time": 0.42, "season": 1, "at": [80, -190]},
	"ground-combo-east-mixed": {"time": 0.42, "season": 1, "at": [80, -130]},
	"ground-combo-torch": {"time": 0.95, "season": 1, "moon": 0.0, "at": [84, -196], "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s", "stay": true}},
	# The diagonal shapes and the smooth ones two and three high (diamond to slope2_diag):
	# from the north-west and turned 45 degrees, at night by a torch, in water and snow.
	"ground-combo-diag": {"time": 0.42, "season": 1, "at": [134, -190]},
	"ground-combo-diag-east": {"time": 0.42, "season": 1, "at": [180, -190]},
	"ground-combo-diag-mixed": {"time": 0.42, "season": 1, "at": [134, -130]},
	"ground-combo-diag-turn": {"time": 0.42, "season": 1, "at": [134, -190], "turn": 1},
	"ground-combo-diag-torch": {"time": 0.95, "season": 1, "moon": 0.0, "at": [130, -196], "fire_shadows": 1,
		"hands": {"tool": "tools:torch", "other": "tools:torch", "facing": "s", "stay": true}},
	"ground-combo-diag-water": {"time": 0.42, "season": 1, "at": [156, -318]},
	"ground-combo-diag-snow": {"time": 0.42, "season": 3, "at": [156, -190]},
	"ground-combo-water": {"time": 0.42, "season": 1, "at": [-80, -318]},
	"ground-combo-water-east": {"time": 0.42, "season": 1, "at": [80, -318]},
	"ground-combo-ice": {"time": 0.42, "season": 3, "at": [-80, -318]},
	"ground-combo-snow": {"time": 0.42, "season": 1, "at": [-80, -446]},
	"ground-combo-snow-east": {"time": 0.42, "season": 1, "at": [80, -446]},
	"ground-combo-ramp": {"time": 0.42, "season": 1, "at": [-118, -414]},
	"ground-stream": {"time": 0.42, "season": 1, "at": [156, 37]},
	"ground-stream-top": {"time": 0.42, "season": 1, "at": [142, 20]},
	"ground-ears": {"time": 0.42, "season": 1, "at": [116, 13]},
	# The grove's floor: moss, mushrooms, and the mushrooms that glow at night.
	"ground-grove": {"time": 0.42, "season": 1, "at": [112, 26]},
	"ground-grove-night": {"time": 0.95, "season": 1, "moon": 0.0, "at": [124, 26]},
	# The camp for FPS and freezes: things on the ground, sacks, stations, campfires.
	"ground-camp": {"time": 0.42, "season": 1, "at": [76, -12]},
	"ground-camp-night": {"time": 0.95, "season": 1, "moon": 0.0, "at": [76, -12]},
	"ground-mountain-top": {"time": 0.42, "season": 1, "at": [121, 64]},
}
