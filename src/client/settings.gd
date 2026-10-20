extends RefCounted
## Game settings: what the player can change and keep between runs (time speed,
## graphics, interface, the world made at the start) and the playtest switches that
## are not saved (season, weather, time of day, fast forward). Every value lives here;
## `apply` pushes them into the modules, so the menu, the hotkeys and the tools all go
## through the same place.
## Saved as user://settings.cfg (IndexedDB in the browser). `game` is the Main node.

const PixelView := preload("res://src/client/pixel_view.gd")

const PATH := "user://settings.cfg"
## Game minutes per real second: ×1 is a 4 minute day (see Sky.DAY_LENGTH).
const TIME_SPEEDS := [0.5, 1.0, 2.0, 5.0]
## How much larger than normal the world pixel is; the image gets that much smaller.
const PIXEL_SIZES := [1.0, 1.5, 2.0]
const FPS_LIMITS := [0, 30, 60]
const UI_SCALES := [0, 1, 2]
## The settings that are saved, with their defaults.
const DEFAULTS := {
	"time_speed": 1,
	"shadows": true,
	"effects": true,
	"pixel_size": 0,
	"fps_limit": 0,
	"ui_scale": 0,
	"show_help": true,
	# The world made at the start (see WorldSetup and WorldGen.DEFAULT_SETTINGS).
	"world_seed": 20261018,
	"world_size": 1,
	"world_water": 1,
	"world_mountains": 1,
	"world_rivers": 1,
	"world_biomes": 1,
}
## Playtest fast forward, on top of the time speed setting.
const FAST_FORWARD := 20.0

var game
## Current values of the saved settings, by name (see DEFAULTS).
var values := {}
## Playtest switch: time runs FAST_FORWARD times faster. Not saved.
var fast_forward := false
## Playtest switch: the clock stands still. Not saved.
var time_stopped := false


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
## is not there yet is set when it appears (the sky reads the speed every frame).
func apply() -> void:
	var sky = game.sky
	if sky != null:
		sky.time_speed = 0.0 if time_stopped else time_speed() * (FAST_FORWARD if fast_forward else 1.0)
		if sky.sun != null:
			sky.sun.shadow_enabled = values.shadows
	if game.effects != null:
		game.effects.enabled = values.effects
	Engine.max_fps = FPS_LIMITS[values.fps_limit]
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
	var sky = game.sky
	sky.season = posmod(s, 4)
	sky.season_clock = 0.0
	print("season: %s" % sky.SEASONS[sky.season])


func set_raining(on: bool) -> void:
	game.sky.raining = on


## Moves the clock to `hour` (0-24) of the current day.
func set_hour(hour: float) -> void:
	game.sky.time_of_day = fposmod(hour / 24.0, 1.0)


func set_fast_forward(on: bool) -> void:
	fast_forward = on
	apply()


func set_time_stopped(on: bool) -> void:
	time_stopped = on
	apply()
