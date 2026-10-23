extends RefCounted
## Game settings: what the player can change and keep between runs (time speed,
## graphics, interface, the world made at the start) and the playtest switches that
## are not saved (season, weather, time of day, fast forward, player speed, free building). Every value lives here;
## `apply` pushes them into the modules, so the menu, the hotkeys and the tools all go
## through the same place.
## Saved as user://settings.cfg (IndexedDB in the browser). `game` is the Main node.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Items := preload("res://src/shared/content/items.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")

const PATH := "user://settings.cfg"
## How fast the clock runs: 1.0 is a 4 minute day (Sky.DAY_LENGTH); the default 0.1 is
## a 40 minute day, slow enough for the meditative pace.
const TIME_SPEEDS := [0.05, 0.1, 0.2, 0.5, 1.0]
## How much larger than normal the world pixel is; the image gets that much smaller.
const PIXEL_SIZES := [1.0, 1.5, 2.0]
const FPS_LIMITS := [0, 30, 60]
## The settings that are saved, with their defaults.
const DEFAULTS := {
	"time_speed": 1,
	"shadows": true,
	# Shadows of fires and the torch: 0 none, 1 drawn on the ground (FireShadows), 2
	# real ones from the nearest fire or the torch (see Effects.SHADOW_FIRE_REACH), the
	# slowest thing to draw at night, 3 mixed: the nearest fire's real shadow of the
	# player alone and the rest drawn (Effects.player_only; 74 FPS on the phone by a
	# campfire against 83 drawn and 63 real).
	"fire_shadows": 3,
	"effects": true,
	# Sun rays in the air in clear weather and after rain (Sky._update_rays).
	"sun_rays": true,
	# Fog drawn on the ground, deep in the low places (Sky._update_fog); off, a plain haze.
	"fog": true,
	"pixel_size": 0,
	"fps_limit": 0,
	# The interface and the touch controls size, «очень мелкий» to «крупный» (see
	# Hud.UI_SIZES, Hud.CONTROL_SIZES).
	"ui_size": 2,
	"control_size": 2,
	"show_help": true,
	# The camera, in steps from the default view: turned left by CameraRig.TURN_STEP
	# each (0..7), tilted steeper by CameraRig.TILT_STEP each (-2..2).
	"camera_turn": 0,
	"camera_tilt": 0,
	# Which things lying near the player fly into the bag by themselves (see Gathering):
	# WorldActions.PICKUP_ALL, _KNOWN (what the bag has), _FOOD or _NONE.
	"pickup": 0,
	# They do so past the bag's weight limit too.
	"pickup_heavy": false,
	# The camera shakes when the body is hurt (see BodyFeedback).
	"shake": true,
	# The world made at the start (see WorldSetup and WorldGen.DEFAULT_SETTINGS).
	"world_seed": 20261018,
	"world_size": 1,
	"world_water": 1,
	"world_mountains": 1,
	"world_rivers": 1,
	"world_biomes": 1,
}
## Graphics quality presets, from the lightest to draw: the graphics settings each sets.
## Any other mix of them is «своё» (see quality). The FPS limit is not part of them.
const QUALITIES := [
	{"pixel_size": 1, "shadows": false, "fire_shadows": 0, "effects": false, "sun_rays": false, "fog": false},
	{"pixel_size": 0, "shadows": true, "fire_shadows": 1, "effects": true, "sun_rays": false, "fog": true},
	{"pixel_size": 0, "shadows": true, "fire_shadows": 3, "effects": true, "sun_rays": true, "fog": true},
]
## Playtest clock: stopped, normal, or faster on top of the time speed setting.
const TIME_BOOSTS := [0.0, 1.0, 10.0, 100.0]
## What the T key switches to: a whole day in about 24 seconds.
const FAST_FORWARD := 100.0
## Playtest multipliers of the player's walking speed, for looking around the map.
const PLAYER_SPEEDS := [1.0, 2.0, 4.0, 8.0]

var game
## Current values of the saved settings, by name (see DEFAULTS).
var values := {}
## Playtest switch: how many times faster the clock runs (0 stops it). Not saved.
var time_boost := 1.0
## Playtest switch: the player's speed multiplier. Not saved.
var player_speed := 1.0
## Playtest switch: blocks are placed without taking them from the bag, and digging
## gives none. Not saved.
var free_build := false
## Playtest: the stone and wooden tools the game has before crafting, into the bag.
const TOOL_SET := ["core:stone_axe", "core:stone_pickaxe", "core:wooden_shovel", "core:wooden_sword", "core:stone_scythe"]
## Playtest switch: jumps in the air too and for free, to climb out of deep caves. Not saved.
var air_jumps := false
## Playtest switch: tools wear with use and break (decision 105: only in the «суровый»
## preset, which does not exist yet). Not saved.
var tool_wear := false
## Playtest switch: the hint under the pointer (on a touch screen, at a tap, for a few
## seconds) tells what the cell is and why the hand in use does or does not work it. Not
## saved.
var debug_tips := false
## Playtest switch: the level buttons look at any level, not only a few around the
## player (see ChunkStreamer.view_range). Not saved.
var free_view := false
## Playtest switch: weight past the bag's limit does not slow the character, stop
## their jumps or their recovery (Inventory.heavy off). Not saved.
var no_overload := false
## Playtest switch: crafting takes no time (Workshop: a job a frame). Not saved.
var instant_craft := false
## Playtest switch: satiety does not fall (Vitals.hunger off). Not saved.
var no_hunger := false
## Playtest switch: the death screen also offers to come back where the character
## fell. Not saved.
var revive_at_death := false
## Sides of the sun's shadow map to compare on a phone (the map is drawn again every
## frame the sun casts shadows). The engine's default is 4096; at 16 pixels a world unit
## 2048 shows the same shadows with a quarter of its texels.
const SHADOW_MAPS := [1024, 2048, 4096]
## Playtest switch: the side of the sun's shadow map, an index into SHADOW_MAPS. Not saved.
var shadow_map := 1
## The full screen last asked for in the browser, and when (see fullscreen).
var _fullscreen_wanted := false
var _fullscreen_asked := -100000


func _init(g) -> void:
	game = g
	values = DEFAULTS.duplicate()


func load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in DEFAULTS:
		var v: Variant = cfg.get_value("game", k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]):
			values[k] = v
	# Before the kinds of pickup it was on or off.
	if not cfg.has_section_key("game", "pickup") and cfg.get_value("game", "auto_pickup", true) == false:
		values.pickup = 3
	# Before five sizes the interface had three, the normal one first.
	if not cfg.has_section_key("game", "ui_size") and cfg.has_section_key("game", "ui_scale"):
		values.ui_size = clampi(int(cfg.get_value("game", "ui_scale", 0)) + 2, 0, 4)


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("game", k, values[k])
	cfg.save(PATH)


## Changes one setting, applies it and saves.
func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save()


## The graphics quality preset the settings match (an index into QUALITIES), or -1
## when they were set by hand to a mix of their own.
func quality() -> int:
	for i in QUALITIES.size():
		var q: Dictionary = QUALITIES[i]
		if q.keys().all(func(k: String) -> bool: return values[k] == q[k]):
			return i
	return -1


## Sets the graphics settings of quality preset `i` (see QUALITIES), applies and saves.
func set_quality(i: int) -> void:
	values.merge(QUALITIES[i], true)
	apply()
	save()


## The world settings for WorldGen: size, water, mountains, rivers, biomes.
func world_options() -> Dictionary:
	var out := {}
	for k in ["size", "water", "mountains", "rivers", "biomes"]:
		out[k] = values["world_" + k]
	return out


func time_speed() -> float:
	return TIME_SPEEDS[values.time_speed]


func pixel_size() -> float:
	return PIXEL_SIZES[values.pixel_size]


## Pushes every setting into the modules. Safe to call before the world is built: what
## is not there yet is set when it appears (the clock reads the speed every frame).
func apply() -> void:
	if game.clock != null:
		game.clock.time_speed = time_speed() * time_boost
	var sky = game.sky
	if sky != null and sky.sun != null:
		sky.sun.shadow_enabled = values.shadows
	if sky != null:
		sky.rays_on = values.sun_rays
		sky.fog_on = values.fog
	if game.effects != null:
		game.effects.enabled = values.effects
		game.effects.shadows = values.shadows and values.fire_shadows >= 2
		game.effects.player_only = values.fire_shadows == 3
	if game.fire_shadows != null:
		game.fire_shadows.enabled = values.shadows and values.fire_shadows in [1, 3]
	if game.player != null:
		game.player.body.speed_scale = player_speed
		game.player.body.air_jumps = air_jumps
	if game.character != null:
		game.character.inventory.heavy = not no_overload
		game.character.vitals.hunger = not no_hunger
	Engine.max_fps = FPS_LIMITS[values.fps_limit]
	# Sixteen-bit depth, as the engine's own default map.
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_MAPS[shadow_map], true)
	game.controls.show_help = values.show_help
	var view = game.view
	if view != null and view.target_height != PixelView.TARGET_HEIGHT / pixel_size():
		view.target_height = PixelView.TARGET_HEIGHT / pixel_size()
		view.on_screen_resized()
	var hud = game.hud
	if hud != null:
		if hud.ui_size != values.ui_size or hud.control_size != values.control_size:
			hud.ui_size = values.ui_size
			hud.control_size = values.control_size
			if view != null:
				view.layout_ui(view.safe_rect)
		hud.show_keys(values.show_help)


## Puts every setting back as it comes, all but the world the setup screen makes.
func reset() -> void:
	for k in DEFAULTS:
		if not k.begins_with("world_"):
			values[k] = DEFAULTS[k]
	apply()
	save()


## Whether the game can fill the whole screen here: a computer's window, or a browser
## that lets a page hide its own bars (not Safari on an iPhone).
func can_fullscreen() -> bool:
	if OS.has_feature("web"):
		# Some phone browsers have only the older webkit names.
		return JavaScriptBridge.eval("""(function () {
			var e = document.documentElement;
			return !!(document.fullscreenEnabled || document.webkitFullscreenEnabled
				|| e.requestFullscreen || e.webkitRequestFullscreen);
		})()""", true) == true
	return not OS.has_feature("mobile")


func fullscreen() -> bool:
	if OS.has_feature("web"):
		# The browser goes full screen a moment after it is asked.
		if Time.get_ticks_msec() - _fullscreen_asked < 1500:
			return _fullscreen_wanted
		return JavaScriptBridge.eval("!!(document.fullscreenElement || document.webkitFullscreenElement)", true) == true
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


## Not saved: a browser lets a page take the whole screen only right after a tap.
func set_fullscreen(on: bool) -> void:
	if OS.has_feature("web"):
		_fullscreen_wanted = on
		_fullscreen_asked = Time.get_ticks_msec()
		JavaScriptBridge.eval("""(function (on) {
			var e = document.documentElement;
			if (on) {
				var go = e.requestFullscreen || e.webkitRequestFullscreen;
				if (go) { var p = go.call(e); if (p && p.catch) p.catch(function () {}); }
			} else {
				var back = document.exitFullscreen || document.webkitExitFullscreen;
				if (back && (document.fullscreenElement || document.webkitFullscreenElement)) back.call(document);
			}
		})(%s)""" % ("true" if on else "false"), true)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


# --- Playtest switches --------------------------------------------------------------

func set_season(s: int) -> void:
	var clock = game.clock
	clock.season = posmod(s, 4)
	clock.season_clock = 0.0
	print("season: %s" % clock.SEASONS[clock.season])
	if game.actions != null:
		game.actions.on_season(clock.season)


func set_raining(on: bool) -> void:
	set_weather(game.clock.RAIN if on else game.clock.CLEAR)


## Pins the weather to Clock.WEATHERS[`index`]; -1 lets it change by itself again.
func set_weather(index: int) -> void:
	if index < 0:
		game.clock.weather_auto = true
	else:
		game.clock.set_weather(index)


## Pins the moonlight (0 new moon .. 1 full moon); -1 follows the phase of the moon.
func set_moon(light: float) -> void:
	game.sky.moon_override = light


## Moves the clock to `hour` (0-24) of the current day.
func set_hour(hour: float) -> void:
	game.clock.time_of_day = fposmod(hour / 24.0, 1.0)


func set_time_boost(k: float) -> void:
	time_boost = k
	apply()


func set_player_speed(k: float) -> void:
	player_speed = k
	apply()


func set_air_jumps(on: bool) -> void:
	air_jumps = on
	apply()


## Free building places blocks without spending them, but a block is taken in the hand
## from the bag, so turning it on puts one of each block the bag lacks into it.
func set_free_build(on: bool) -> void:
	free_build = on
	if on and game.character != null:
		for m in Mat.PLACEABLE:
			if game.character.inventory.count(Items.placed_by[m]) == 0:
				game.character.give(Items.placed_by[m], 1)
	if game.hud != null:
		game.hud.refresh_counts()


func set_tool_wear(on: bool) -> void:
	tool_wear = on


func set_no_overload(on: bool) -> void:
	no_overload = on
	apply()


func set_no_hunger(on: bool) -> void:
	no_hunger = on
	apply()


## Puts the living character where they last fell; says so when they have not died
## in this world yet.
func go_to_death() -> void:
	var c = game.character
	if c.is_dead():
		return
	if not c.fell_at.is_finite():
		c.say("В этом мире вы ещё не умирали")
		return
	c.teleport(c.fell_at)


func set_shadow_map(i: int) -> void:
	shadow_map = i
	apply()


## Puts one of each tool of TOOL_SET the bag lacks into it.
func give_tools() -> void:
	for id in TOOL_SET:
		if game.character.inventory.count(id) == 0:
			game.character.give(id, 1)


func in_test_world() -> bool:
	return game.world_seed == TestGround.SEED


## Saves the world and goes over to the test world, or from it back to the world
## saved last before it (the one set up on the first screen when there is none).
func switch_test_world() -> void:
	var seed_value := TestGround.SEED
	var options: Dictionary = game.world_options
	if in_test_world():
		seed_value = values.world_seed
		options = world_options()
		for w: Dictionary in WorldStore.list_worlds():
			if w.seed != TestGround.SEED:
				seed_value = w.seed
				options = w.settings
				break
	game.save.switch_world(seed_value, options)
	game.restart()


## Forgets the test world's save, so it is laid out anew from TestGround; when it is
## the world being played, goes into it again at once without saving it first.
func reset_test_world() -> void:
	if in_test_world() and game.save.store != null:
		game.save.active = false
		game.save.store.erase()
		WorldStore.write_current(TestGround.SEED, game.world_options)
		game.restart()
	else:
		WorldStore.new(WorldStore.world_dir(TestGround.SEED, {})).erase()
