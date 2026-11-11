extends Node
## The log of the last freezes, for finding where they come from on the device itself:
## marks what the game did in each frame (a jump, cells dug or built, the torch lit,
## the sun gone, the weather turned...) on the statistics (PerfPanel.mark), which keeps
## them with every freeze, and tells the freezes kept as lines, the newest first, for
## the window of the playtest page («Отладка» → «Журнал фризов», SettingsMenu), each
## band of length (BANDS) on a tab of its own, so the worst can be fixed first.


## The bands of freezes the window shows apart, by the tabs' keys (SettingsMenu.PAGES):
## from, to ms (a freeze is over PerfPanel.FREEZE_MS).
const Lang := preload("res://src/shared/content/lang.gd")

const BANDS := {"all": [0.0, INF], "critical": [200.0, INF], "big": [100.0, 200.0], "small": [0.0, 100.0]}
## The parts of an ordinary frame, in the order of PerfPanel.usual after the frame itself.
const PARTS := ["game", "engine", "drawing", "input", "browser", "frame end"]

var game
var _torch := false
var _sun := true
var _weather := -1
var _ground := true
var _swimming := false
var _view := Vector2i.ZERO
var _paused := false


func _init(g) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS


## Listens to the rules for what they change; called once they exist.
func watch() -> void:
	game.actions.cell_changed.connect(_on_cell)
	game.placed.added.connect(_on_placed)
	game.placed.removed.connect(_on_placed)
	game.placed.lit_changed.connect(_on_lit)
	game.clock.season_changed.connect(_on_season)


func _on_cell(_cell: Vector3i) -> void:
	_mark("cells")


func _on_placed(_e: Dictionary) -> void:
	_mark("building")


func _on_lit(_e: Dictionary) -> void:
	_mark("fire")


func _on_season(_season: int) -> void:
	_mark("season")


func _mark(what: String) -> void:
	game.hud.perf.mark(what)


## Marks what changed in this frame that the rules do not tell of; called every frame.
func update() -> void:
	if not game.ready_to_play:
		return
	var player = game.player
	var torch: bool = player.torch.light_energy > 0.0
	if torch != _torch:
		_mark("torch" if torch else "torch out")
	_torch = torch
	var sun: bool = game.sky.sun.light_energy > 0.0
	if sun != _sun:
		_mark("sun" if sun else "no sun")
	_sun = sun
	if game.clock.weather != _weather and _weather >= 0:
		_mark("weather")
	_weather = game.clock.weather
	var ground: bool = player.body.on_ground
	if ground != _ground:
		_mark("landing" if ground else "jump")
	_ground = ground
	if player.body.swimming != _swimming:
		_mark("water")
	_swimming = player.body.swimming
	var view := Vector2i(game.view.turn_steps, game.view.tilt_steps)
	if view != _view:
		_mark("turn")
	_view = view
	var paused := get_tree().paused
	if paused != _paused:
		_mark("pause")
	_paused = paused


## An ordinary frame and its parts, heading the log.
func usual_line() -> String:
	var perf = game.hud.perf
	var u: PackedFloat32Array = perf.usual
	var told := []
	for i in 6:
		# The three parts of the rest are told where the browser gives them (see PerfPanel._parts).
		if i < 3 or u[i + 1] >= 0.05:
			told.append("%s %.1f" % [PARTS[i], u[i + 1]])
	var line := Lang.f("Usual frame %.1f ms: %s", [u[0], ", ".join(told)])
	if OS.has_feature("web"):
		line += Lang.f(" · full garbage collections %d", [perf.collections])
	return line


## The freezes kept in band `key` (see BANDS), the newest first: [ms, line] each.
func lines(key: String) -> Array:
	var band: Array = BANDS[key]
	var out := []
	var kept: Array = game.hud.perf.freeze_log
	for i in range(kept.size() - 1, -1, -1):
		var f: Array = kept[i]
		if f[1] < band[0] or f[1] >= band[1]:
			continue
		var at := int(f[0])
		var parts := []
		for p: Array in f[2]:
			if roundi(p[1]) > 0:
				parts.append("%s %d" % [p[0], roundi(p[1])])
		var line := Lang.f("%d:%02d  %d ms: %s", [at / 60, at % 60, roundi(f[1]), ", ".join(parts)])
		if not f[3].is_empty():
			line += " · " + ", ".join(f[3])
		if f.size() > 4:
			line += Lang.f(" · calls %d", [f[4]])
		out.append([f[1], line])
	return out


## Forgets the freezes kept, so the next ones stand alone.
func clear() -> void:
	game.hud.perf.freeze_log.clear()
