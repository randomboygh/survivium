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
const UI_SCALES := [0, 1, 2]
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
	# Mist in the low places in the morning (Sky._update_mist).
	"mist": true,
	"pixel_size": 0,
	"fps_limit": 0,
	"ui_scale": 0,
	"show_help": true,
	# Things lying near the player fly into the bag by themselves (see Gathering).
	"auto_pickup": true,
	# The world made at the start (see WorldSetup and WorldGen.DEFAULT_SETTINGS).
	"world_seed": 20261018,
	"world_size": 1,
	"world_water": 1,
	"world_mountains": 1,
	"world_rivers": 1,
	"world_biomes": 1,
}
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
## Sides of the sun's shadow map to compare on a phone (the map is drawn again every
## frame the sun casts shadows). The engine's default is 4096; at 16 pixels a world unit
## 2048 shows the same shadows with a quarter of its texels.
const SHADOW_MAPS := [1024, 2048, 4096]
## Playtest switch: the side of the sun's shadow map, an index into SHADOW_MAPS. Not saved.
var shadow_map := 1


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
		sky.mist_on = values.mist
	if game.effects != null:
		game.effects.enabled = values.effects
		game.effects.shadows = values.shadows and values.fire_shadows >= 2
		game.effects.player_only = values.fire_shadows == 3
	if game.fire_shadows != null:
		game.fire_shadows.enabled = values.shadows and values.fire_shadows in [1, 3]
	if game.player != null:
		game.player.body.speed_scale = player_speed
		game.player.body.air_jumps = air_jumps
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
		if hud.scale_bonus != values.ui_scale:
			hud.scale_bonus = values.ui_scale
			if view != null:
				view.layout_ui(view.safe_rect)
		hud.show_keys(values.show_help)


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
