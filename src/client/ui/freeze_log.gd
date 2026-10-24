extends Node
## The log of the last freezes, for finding where they come from on the device itself:
## marks what the game did in each frame (a jump, cells dug or built, the torch lit,
## the sun gone, the weather turned...) on the statistics (PerfPanel.mark), which keeps
## them with every freeze, and shows the freezes kept, the newest first, over the screen
## from the playtest page («Отладка») until it is tapped.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Lines in the list at most.
const LINES := 20

var game
var _panel: PanelContainer
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
	_mark("клетки")


func _on_placed(_e: Dictionary) -> void:
	_mark("постройка")


func _on_lit(_e: Dictionary) -> void:
	_mark("огонь")


func _on_season(_season: int) -> void:
	_mark("сезон")


func _mark(what: String) -> void:
	game.hud.perf.mark(what)


## Marks what changed in this frame that the rules do not tell of; called every frame.
func update() -> void:
	if not game.ready_to_play:
		return
	var player = game.player
	var torch: bool = player.torch.light_energy > 0.0
	if torch != _torch:
		_mark("факел" if torch else "факел погас")
	_torch = torch
	var sun: bool = game.sky.sun.light_energy > 0.0
	if sun != _sun:
		_mark("солнце" if sun else "без солнца")
	_sun = sun
	if game.clock.weather != _weather and _weather >= 0:
		_mark("погода")
	_weather = game.clock.weather
	var ground: bool = player.body.on_ground
	if ground != _ground:
		_mark("приземление" if ground else "прыжок")
	_ground = ground
	if player.body.swimming != _swimming:
		_mark("вода")
	_swimming = player.body.swimming
	var view := Vector2i(game.view.turn_steps, game.view.tilt_steps)
	if view != _view:
		_mark("поворот")
	_view = view
	var paused := get_tree().paused
	if paused != _paused:
		_mark("пауза")
	_paused = paused


## Shows the freezes kept over the screen until it is tapped.
func show_log() -> void:
	if _panel != null:
		_panel.queue_free()
	var perf = game.hud.perf
	var lines := ["Фризы, последние сверху:"]
	var kept: Array = perf.freeze_log
	if kept.is_empty():
		lines.append("пока не было")
	for i in range(kept.size() - 1, maxi(-1, kept.size() - 1 - LINES), -1):
		var f: Array = kept[i]
		var at := int(f[0])
		var parts := []
		for p: Array in f[2].slice(0, 2):
			parts.append("%s %d" % [p[0], roundi(p[1])])
		var line := "%d:%02d  %d мс: %s" % [at / 60, at % 60, roundi(f[1]), ", ".join(parts)]
		if not f[3].is_empty():
			line += " · " + ", ".join(f[3])
		lines.append(line)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := UiStyle.label("\n".join(lines))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = game.hud.size.x - 16.0
	_panel.add_child(label)
	_panel.position = Vector2(8, game.hud.size.y * 0.3)
	_panel.gui_input.connect(_on_panel_input)
	game.hud.add_child(_panel)


func _on_panel_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_panel.queue_free()
		_panel = null
