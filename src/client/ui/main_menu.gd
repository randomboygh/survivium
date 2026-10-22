extends Control
## The main menu (plan/design/ui.md, section 2): the first screen, over the live world
## played last (see SaveGame), which is built behind it meanwhile. "Играть" goes into
## that world (as soon as it is built), "Продолжить" once it has a save; "Новый мир"
## opens WorldSetup over the menu and restarts the game when the world asked for is
## another one (a world made before comes back from its save), "Миры" lists the saved
## worlds to go back to one or delete it (WorldList), "Настройки" opens the settings
## page.
## The network game and the editor are not there yet, so their buttons are disabled,
## and "Выход" is disabled in the browser. Until the world is built a painted sky
## stands in for it and then fades out. The game's interface is hidden while the menu
## is open; the menu takes the scale and the safe rect the interface was fitted to.
## `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const WorldSetup := preload("res://src/client/ui/world_setup.gd")
const SettingsMenu := preload("res://src/client/ui/settings_menu.gd")
const WorldList := preload("res://src/client/ui/world_list.gd")

const WIDTH := 200
const BUTTON_H := 30
const MARGIN := 24
const TITLE_SIZE := 32
## Seconds the painted sky takes to fade once the world is built.
const FADE := 1.2
## The painted sky from the top down to the horizon, and the two ranges of hills.
const SKY := [Color("#22384a"), Color("#2c4a5a"), Color("#3a5d68"), Color("#4f7273"), Color("#6c857a"),
	Color("#93977f"), Color("#b8a383")]
const HILLS := [Color("#35503f"), Color("#263b2f")]

signal opened
signal closed

var game
## True while the menu takes the screen (the sky may still be fading after that).
var is_open := false
var _screen: Control
var _backdrop: Control
var _column: VBoxContainer
var _seed_label: Label
var _status: Label
## Buttons by name, and the names in order of the keyboard focus.
var _buttons := {}
var _order := []
var _focus := 0
var _settings: SettingsMenu
## The screen open over the menu: WorldSetup or WorldList.
var _setup: Control
## "Играть" was pressed before the world was built: go in once it is.
var _want_play := false
## The player has been in the world: Escape goes back there.
var _entered := false
var _fading := false
var _shown := false
var _fit_for := Rect2()


func _init(g) -> void:
	game = g


func _ready() -> void:
	theme = UiStyle.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = Control.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_sky)
	add_child(_backdrop)
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.draw.connect(_draw_focus)
	add_child(_screen)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	_screen.add_child(_column)
	var title := UiStyle.label("SURVIVIUM", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	_seed_label = UiStyle.label("", UiStyle.INK)
	_seed_label.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	_seed_label.add_theme_constant_override("outline_size", 4)
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_seed_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	_column.add_child(gap)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_add_button(box, "play", "Играть", play)
	_status = UiStyle.label("", UiStyle.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	_add_button(box, "new", "Новый мир", _new_world)
	_add_button(box, "worlds", "Миры", _open_worlds)
	_add_button(box, "net", "Сетевая игра", Callable(), "скоро")
	_add_button(box, "editor", "Редактор", Callable(), "скоро")
	_add_button(box, "settings", "Настройки", _open_settings)
	if OS.has_feature("web"):
		_add_button(box, "quit", "Выход", Callable(), "вкладка")
		_buttons.quit.tooltip_text = "В браузере игра закрывается вместе с вкладкой"
	else:
		_add_button(box, "quit", "Выход", func() -> void:
			game.save.flush()
			get_tree().quit())
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_buttons.play.add_theme_stylebox_override(state, UiStyle.button(state, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_buttons.play.add_theme_color_override(c, UiStyle.DARK_INK)

	_settings = SettingsMenu.new(game)
	_settings.closed.connect(func() -> void:
		_column.visible = true
		_fit())
	_screen.add_child(_settings)
	visible = false
	_screen.visible = false


func _add_button(parent: Node, key: String, text: String, action: Callable, tag := "") -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH, BUTTON_H)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if action.is_valid():
		b.pressed.connect(action)
		b.mouse_entered.connect(func() -> void: _set_focus(_order.find(key)))
		_order.append(key)
	else:
		b.disabled = true
	if tag != "":
		# What the disabled button waits for, at its right edge.
		var l := UiStyle.label(tag, Color(UiStyle.MUTED, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.offset_right = -10
		l.offset_bottom = -2
		b.add_child(l)
	parent.add_child(b)
	_buttons[key] = b


## Shows the menu over the game and hides the game's interface.
func open() -> void:
	is_open = true
	visible = true
	_screen.visible = true
	_column.visible = true
	_want_play = false
	_seed_label.text = "мир · зерно %d" % game.world_seed
	if game.save.has_save:
		_seed_label.text += " · день %d" % game.sky.day
	_buttons.play.text = "Продолжить" if game.save.has_save else "Играть"
	game.hud.visible = false
	_set_focus(0)
	_fit()
	opened.emit()


func close() -> void:
	is_open = false
	_want_play = false
	_entered = true
	_screen.visible = false
	if _setup != null:
		_setup.queue_free()
		_setup = null
	_settings.visible = false
	game.hud.visible = true
	visible = _backdrop.visible
	closed.emit()


## "Играть": into the world now, or as soon as it is built.
func play() -> void:
	if game.ready_to_play:
		close()
	else:
		_want_play = true


## The menu opened on the new world's setup (from the death screen).
func new_world() -> void:
	open()
	_new_world()


func _new_world() -> void:
	_column.visible = false
	_setup = WorldSetup.new(game)
	_screen.add_child(_setup)
	_setup.cancelled.connect(_close_setup)
	_setup.done.connect(func() -> void:
		_close_setup()
		# The world behind the menu is the one asked for: just go in.
		_go_to(game.settings.values.world_seed, game.settings.world_options()))


## Into the world of `seed_value` and `options`: the one behind the menu at once, any
## other by a restart (from its save if it has one).
func _go_to(seed_value: int, options: Dictionary) -> void:
	if seed_value == game.world_seed and options == game.world_options:
		play()
	else:
		game.save.switch_world(seed_value, options)
		game.restart()


func _open_worlds() -> void:
	_column.visible = false
	_setup = WorldList.new(game)
	_screen.add_child(_setup)
	_setup.cancelled.connect(_close_setup)
	_setup.chosen.connect(func(seed_value: int, options: Dictionary) -> void:
		_close_setup()
		_go_to(seed_value, options))


func _close_setup() -> void:
	if _setup != null:
		_setup.queue_free()
		_setup = null
	_column.visible = true
	_fit()


func _open_settings() -> void:
	_column.visible = false
	_settings.open("settings")
	_settings.fit(_screen.size)


func _process(delta: float) -> void:
	var hud: Control = game.hud
	var rect := Rect2(hud.position, hud.size * hud.scale)
	if rect != _fit_for or scale != hud.scale:
		_fit()
	if game.ready_to_play and _backdrop.visible and not _fading:
		_fading = true
		var tw := _backdrop.create_tween()
		tw.tween_property(_backdrop, "modulate:a", 0.0, FADE)
		tw.tween_callback(func() -> void:
			_backdrop.visible = false
			visible = is_open)
	if not is_open:
		return
	if game.ready_to_play:
		_status.visible = false
		if _want_play:
			close()
			return
	else:
		var total: int = game.chunks.near_total
		var done: int = total - game.chunks.near_pending
		var pct := int(100.0 * done / total) if total > 0 else 0
		_status.text = ("Вход в мир… %d%%" if _want_play else "Мир строится… %d%%") % pct
		_status.visible = true
	if not _shown and _column.is_visible_in_tree():
		# Laid out by now; the browser test taps the buttons from this line.
		_shown = true
		print("main menu shown: play %s, new %s" % [_buttons.play.get_global_rect(), _buttons.new.get_global_rect()])
	_screen.queue_redraw()


## The interface's scale and rect: the column on the left of a wide screen, in the
## middle of a tall one, below the centre.
func _fit() -> void:
	var hud: Control = game.hud
	_fit_for = Rect2(hud.position, hud.size * hud.scale)
	scale = hud.scale
	position = hud.position
	size = hud.size
	_screen.size = size
	_backdrop.size = size
	_backdrop.queue_redraw()
	_column.reset_size()
	var c := _column.size
	if size.x >= size.y * 1.2:
		_column.position = Vector2(MARGIN, (size.y - c.y) * 0.5).floor()
	else:
		_column.position = Vector2((size.x - c.x) * 0.5, maxf(MARGIN, (size.y - c.y) * 0.55)).floor()
	if _settings.visible:
		_settings.fit(size)
	_screen.queue_redraw()


func _set_focus(i: int) -> void:
	if i < 0:
		return
	_focus = posmod(i, _order.size())
	_screen.queue_redraw()


## A small accent arrow left of the button the keyboard is on (not with touch).
func _draw_focus() -> void:
	if game.controls.touch or not _column.visible:
		return
	var b: Button = _buttons[_order[_focus]]
	var at: Vector2 = _screen.get_global_transform().affine_inverse() * b.global_position
	var y := floorf(at.y + b.size.y * 0.5)
	var x := at.x - 10
	for i in 4:
		_screen.draw_rect(Rect2(x + i, y - 3 + i, 1, 7 - 2 * i), UiStyle.ACCENT)


## The painted sky until the world is built: bands down to the horizon with a row of
## dithered pixels between them, then two ranges of hills. It covers the whole window,
## past the safe rect.
func _draw_sky() -> void:
	var s: float = scale.x
	var full := Rect2(-position / s, get_viewport_rect().size / s).grow(2)
	var top := full.position.y
	var horizon := top + full.size.y * 0.62
	var band := (horizon - top) / SKY.size()
	for i in SKY.size():
		var y0 := floorf(top + i * band)
		_backdrop.draw_rect(Rect2(full.position.x, y0, full.size.x, ceilf(band) + 1), SKY[i])
		if i > 0:
			# Every other pixel of the band above, along the seam.
			for x in range(int(full.position.x), int(full.end.x), 2):
				_backdrop.draw_rect(Rect2(x, y0, 1, 1), SKY[i - 1])
	_backdrop.draw_rect(Rect2(full.position.x, horizon, full.size.x, full.end.y - horizon), SKY[SKY.size() - 1])
	for h in HILLS.size():
		var base := horizon + (h + 1) * full.size.y * 0.1
		var x := int(full.position.x)
		while x < int(full.end.x):
			var t := float(x) * (0.012 + h * 0.008) + h * 2.0
			var y := floorf(base - (sin(t) * 0.6 + sin(t * 2.3 + 1.0) * 0.3 + 1.0) * full.size.y * (0.06 - h * 0.015))
			_backdrop.draw_rect(Rect2(x, y, 2, full.end.y - y), HILLS[h])
			x += 2


## Up and down pick a button, Enter presses it, Escape goes back into the world. Every
## key stops here while the menu is open, so the game behind it gets none.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey):
		return
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo or not _column.visible:
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_set_focus(_focus - 1)
		KEY_DOWN, KEY_S:
			_set_focus(_focus + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_buttons[_order[_focus]].pressed.emit()
		KEY_ESCAPE:
			if _entered:
				play()
