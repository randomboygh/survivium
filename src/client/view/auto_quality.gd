extends RefCounted
## The graphics quality chosen by the game itself («Качество → Авто»): while the world is
## played it counts the frames on the clock and moves the graphics settings a step along
## STEPS, down when the game runs below DOWN_FPS for a while, up (a try) when it has
## stayed near the screen's rate for a minute. A try that brings the frames down again is
## taken back, and the step stays the highest the device is let have («auto_ceiling»,
## until «Авто» is picked again). Any graphics setting changed by hand turns it off
## (Settings.set_value). Frames longer than GAP_MS (a freeze, a hidden tab), the loading,
## the shader warm-up, the menu and the death screen are not counted, nor a game the
## tests and the tools run (Main not the current scene: they keep the settings they set).
## `game` is the Main node; Main calls update() every frame of the game.

const Lang := preload("res://src/shared/content/lang.gd")
const Settings := preload("res://src/client/settings.gd")

## The steps from the best picture to the lightest to draw, each what it changes from
## the one before; the first is the «высокое» preset (Settings.QUALITIES[2]) and the
## whole list passes through «среднее» (3) and ends at «низкое» (8). First go the things
## least missed: the fires' real shadows, the sun's rays, the shadows on the things set
## down, the fog on the ground; then a larger pixel (a smaller image); the sun's shadows
## and the effects last. The pixel never gets smaller than the normal one by itself.
const STEPS := [
	{},
	{"fire_shadows": 1},
	{"sun_rays": false},
	{"shadow_on_things": false},
	{"fog": false},
	{"pixel_scale": 3},
	{"pixel_scale": 4},
	{"shadows": false, "fire_shadows": 0},
	{"effects": false},
]
## The game's frames are counted in windows this long (ms of the clock).
const WINDOW_MS := 5000
## A frame longer than this is a freeze or a hidden tab: left out of the count.
const GAP_MS := 250
## Below this many frames a second (or 80 % of the FPS limit, if lower) the game is too
## slow; DOWN_WINDOWS such windows in a row bring the graphics a step down.
const DOWN_FPS := 28.0
const DOWN_WINDOWS := 2
## At this many (or 90 % of the screen's rate or the FPS limit, if lower) for UP_WINDOWS
## windows in a row the next step up is tried.
const UP_FPS := 50.0
const UP_WINDOWS := 12
## For this many windows after a try up, one slow window takes it back.
const TRY_WINDOWS := 4

var game
## Whether the last change of step was down: told on the screen (Hud.toast) and in the
## statistics.
var last_change := ""
var _start := 0
var _last := 0
var _frames := 0
var _slow := 0
var _fast := 0
## Windows left in which a try up is still watched (0 none).
var _trying := 0
## The frames a second of the last window counted (0 none yet).
var fps := 0.0


func _init(main) -> void:
	game = main


## The graphics settings of step `i`: the «высокое» preset with every change up to `i`.
static func step_values(i: int, high: Dictionary) -> Dictionary:
	var v := high.duplicate()
	for k in range(1, i + 1):
		v.merge(STEPS[k], true)
	return v


## The step the settings are on (an index into STEPS), or -1 when they are a mix of
## their own.
static func step_of(values: Dictionary, high: Dictionary) -> int:
	for i in STEPS.size():
		var v := step_values(i, high)
		if v.keys().all(func(k: String) -> bool: return values[k] == v[k]):
			return i
	return -1


func _settings():
	return game.settings


func _high() -> Dictionary:
	return Settings.QUALITIES[2]


## The step the game is on now (-1 a mix of the player's own).
func step() -> int:
	return step_of(_settings().values, _high())


## The rate the frames are held to: the FPS limit, else the screen's (60 where unknown).
func _cap() -> float:
	var limit: int = Engine.max_fps
	if limit > 0:
		return float(limit)
	var rate := DisplayServer.screen_get_refresh_rate()
	return rate if rate > 0.0 else 60.0


func down_fps() -> float:
	return minf(DOWN_FPS, _cap() * 0.8)


func up_fps() -> float:
	return minf(UP_FPS, _cap() * 0.9)


## Whether the frames now are the game's own: the world drawn and played.
func _counting() -> bool:
	if not _settings().values.auto_quality or not game.ready_to_play or game.warmup != null:
		return false
	if game.menu != null and game.menu.is_open:
		return false
	if game.get_tree().current_scene != game:
		return false
	return game.character == null or not game.character.is_dead()


## Called every frame of the game.
func update() -> void:
	var now := Time.get_ticks_msec()
	if not _counting():
		_restart()
		return
	if _last == 0:
		_last = now
		_start = now
		return
	var ms := now - _last
	_last = now
	if ms > GAP_MS:
		# Not the game's pace: the window goes on as if the frame was not there.
		_start += ms
		return
	_frames += 1
	if now - _start >= WINDOW_MS:
		window(_frames * 1000.0 / (now - _start))
		_frames = 0
		_start = now
		if game.hud != null:
			game.hud.perf.auto_quality = summary()


## Forgets the window being counted (the next frame starts a new one).
func _restart() -> void:
	_last = 0
	_frames = 0


## One window counted at `rate` frames a second: moves the step when it is time.
func window(rate: float) -> void:
	fps = rate
	var at := step()
	if at < 0:
		return
	if rate < down_fps():
		_fast = 0
		_slow += 1
		if _trying > 0:
			# The try up was too much: back, and no higher from now on.
			_settings().values.auto_ceiling = at + 1
			_move(at + 1, rate)
		elif _slow >= DOWN_WINDOWS:
			_move(at + 1, rate)
		return
	_slow = 0
	if _trying > 0:
		_trying -= 1
	if rate >= up_fps():
		_fast += 1
		if _fast >= UP_WINDOWS and at - 1 >= clampi(int(_settings().values.auto_ceiling), 0, STEPS.size() - 1):
			_move(at - 1, rate)
			_trying = TRY_WINDOWS
	else:
		_fast = 0


func _move(to: int, rate: float) -> void:
	_slow = 0
	_fast = 0
	_trying = 0
	if to < 0 or to >= STEPS.size():
		return
	var down := to > step()
	var s = _settings()
	s.values.merge(step_values(to, _high()), true)
	s.apply()
	s.save()
	last_change = "%s to step %d at %d FPS" % ["down" if down else "up", to, roundi(rate)]
	print("auto quality: " + last_change)
	_restart()
	if game.hud != null:
		game.hud.toast(Lang.line("[graphics_lowered_fps]" if down else "[graphics_raised_fps]", [roundi(rate)]))


## «Авто» picked: from the step the settings are nearest to (the «высокое» preset when
## they are a mix of their own), with no ceiling and the count from the start.
func turn_on() -> void:
	var s = _settings()
	s.values.auto_quality = true
	s.values.auto_ceiling = 0
	if step() < 0:
		s.values.merge(_high(), true)
	_slow = 0
	_fast = 0
	_trying = 0
	_restart()
	s.apply()
	s.save()


## A line for the statistics panel: the step and the last count.
func summary() -> String:
	if not _settings().values.auto_quality:
		return ""
	return "auto quality: step %d/%d, %d FPS%s" % [step(), STEPS.size() - 1, roundi(fps),
		(", last " + last_change) if last_change != "" else ""]
