extends Control
## The game screen interface (plan/design/ui.md): clock, level cutaway, statistics and
## menu buttons, hotbar with both hands, joystick and action buttons on touch screens,
## key hints with a mouse, short messages, the hover hint and the pause menu.
##
## The root is scaled by a whole number so one UI pixel is one pixel of the world, and
## the layout follows the shape of the screen: wide, tablet-like and portrait screens
## place the hotbar beside or above the touch controls, and portrait shows fewer slots.

const UiStyle := preload("res://src/client/ui_style.gd")
const HotbarSlot := preload("res://src/client/hotbar_slot.gd")
const PerfPanel := preload("res://src/client/perf_panel.gd")
const TouchStick := preload("res://src/client/touch_stick.gd")
const TouchButton := preload("res://src/client/touch_button.gd")
const SettingsMenu := preload("res://src/client/settings_menu.gd")
const Minimap := preload("res://src/client/minimap.gd")
const Mat := preload("res://src/shared/materials.gd")

const MARGIN := 8.0
const CELL := 0.5
const GAP := 4.0
const SLOT := 40
## UI height the scale aims for on the shorter side of the screen.
const TARGET_SIDE := 400.0
const TOAST_TIME := 4.0
const MAX_TOASTS := 3
const KEYS := "WASD — ходить, Пробел — прыжок\nЛКМ — копать, ПКМ — поставить\n1–7, колесо — блок\nQ / E — срез ниже / выше, R — к игроку\nF3 — статистика, Esc — меню\nH — скрыть подсказку"

var game
var touch := false
var portrait := false
## The interface scale setting: whole steps above the scale picked from the screen.
var scale_bonus := 0

var _left: VBoxContainer
var _clock_icon: TextureRect
var _clock: Label
var _toasts: VBoxContainer
var perf: PanelContainer
var _top: HBoxContainer
var _stats_button: Button
var _test_button: Button
var _menu_button: Button
var _level: BoxContainer
var minimap: Minimap
var _level_label: Button
var _bar: PanelContainer
var _hand_left
var _hand_right
var _slots := []
var _next_button: Button
var _page := 0
var _visible_slots := 7
var stick
var _action: Button
var _jump: Button
var _keys: PanelContainer
var _tip: PanelContainer
var _tip_label: Label
var _loading: PanelContainer
var _loading_label: Label
var _menu: PanelContainer
var _settings: SettingsMenu
## Dims the game behind the menu and keeps taps from reaching it.
var _shade: ColorRect
var _menu_buttons := {}


func _ready() -> void:
	theme = UiStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left)
	var clock := _panel(_left)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	clock.add_child(row)
	_clock_icon = TextureRect.new()
	_clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_clock_icon.custom_minimum_size = Vector2(10, 10)
	row.add_child(_clock_icon)
	_clock = UiStyle.label()
	row.add_child(_clock)
	clock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	perf = PerfPanel.new()
	perf.visible = false
	perf.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(perf)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_toasts)

	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 6)
	add_child(_top)
	_stats_button = _icon_button(_top, "chart", "Статистика", toggle_stats)
	_test_button = _icon_button(_top, "flask", "Для проверки", toggle_test)
	_menu_button = _icon_button(_top, "menu", "Меню", toggle_menu)

	_level = BoxContainer.new()
	_level.add_theme_constant_override("separation", 0)
	add_child(_level)
	var up := _icon_button(_level, "up", "Уровень выше", func() -> void: game.chunks.shift_cut(1))
	# The level itself is a button: a tap on a chosen cut returns to the player's level.
	_level_label = Button.new()
	_level_label.focus_mode = Control.FOCUS_NONE
	_level_label.custom_minimum_size = Vector2(60, 36)
	_level_label.tooltip_text = "Вернуться к уровню игрока"
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_level_label.add_theme_stylebox_override(state, UiStyle.panel())
	_level_label.pressed.connect(func() -> void: game.chunks.reset_view_level())
	_level.add_child(_level_label)
	var down := _icon_button(_level, "down", "Уровень ниже", func() -> void: game.chunks.shift_cut(-1))
	for b in [up, down]:
		b.custom_minimum_size = Vector2(36, 36)
	minimap = Minimap.new()
	add_child(minimap)

	_bar = _panel(self)
	_bar.add_theme_stylebox_override("panel", _bar_box())
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", int(GAP))
	_bar.add_child(bar_row)
	_hand_left = _slot(bar_row, func() -> void: game.controls.set_dig_mode(true))
	_hand_left.tag = "Л"
	_hand_left.texture = UiStyle.icon("pick")
	_hand_left.icon_size = Vector2(24, 22)
	_hand_right = _slot(bar_row, func() -> void: game.controls.set_dig_mode(false))
	_hand_right.tag = "П"
	var sep := ColorRect.new()
	sep.color = UiStyle.HIGHLIGHT
	sep.custom_minimum_size = Vector2(4, 30)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_box := MarginContainer.new()
	sep_box.add_theme_constant_override("margin_left", 4)
	sep_box.add_theme_constant_override("margin_right", 4)
	sep_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep_box.add_child(sep)
	bar_row.add_child(sep_box)
	for i in Mat.PLACEABLE.size():
		var s = _slot(bar_row, _select_slot.bind(i))
		_slots.append(s)
	_next_button = _icon_button(bar_row, "next", "Следующие ячейки", _next_page)
	_next_button.custom_minimum_size = Vector2(28, SLOT)

	stick = TouchStick.new()
	add_child(stick)
	_action = TouchButton.new()
	_action.custom_minimum_size = Vector2(84, 84)
	_action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		_action.add_theme_stylebox_override(state, UiStyle.octagon(UiStyle.ACCENT if not state.ends_with("pressed") else UiStyle.ACCENT_DARK))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_action.add_theme_color_override(c, UiStyle.DARK_INK)
	_action.held.connect(func(on: bool) -> void:
		if on:
			game.controls.set_dig_mode(not game.controls.dig_mode))
	add_child(_action)
	_jump = TouchButton.new()
	_jump.text = "Прыжок"
	_jump.icon = UiStyle.icon("up")
	_jump.custom_minimum_size = Vector2(56, 56)
	_jump.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jump.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_jump.add_theme_stylebox_override("normal", UiStyle.panel())
	_jump.add_theme_stylebox_override("hover", UiStyle.panel())
	_jump.held.connect(func(on: bool) -> void: game.controls.jump_held = on)
	add_child(_jump)

	_keys = _panel(self)
	_keys.add_child(UiStyle.label(KEYS, UiStyle.MUTED))

	_tip = _panel(self)
	_tip_label = UiStyle.label()
	_tip.add_child(_tip_label)
	_tip.visible = false

	_loading = _panel(self)
	_loading_label = UiStyle.label()
	_loading_label.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	_loading.add_child(_loading_label)

	_build_menu()
	_update_hands()


func _process(delta: float) -> void:
	perf.add_frame(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				toggle_menu()
				get_viewport().set_input_as_handled()
			KEY_F3:
				toggle_stats()
				game.print_debug()
				get_viewport().set_input_as_handled()


# --- Layout --------------------------------------------------------------------

## Fits the UI into `rect` (screen pixels): picks a whole-number scale from the shorter
## side and places everything for the screen's shape and the input in use.
func fit(rect: Rect2) -> void:
	var s := maxi(1, roundi(minf(rect.size.x, rect.size.y) / TARGET_SIDE)) + scale_bonus
	scale = Vector2(s, s)
	position = rect.position
	size = (rect.size / s).floor()
	portrait = size.x < size.y
	_place()


func set_touch(on: bool) -> void:
	if on == touch:
		return
	touch = on
	_place()


func _place() -> void:
	var w := size.x
	var h := size.y
	_left.position = Vector2(MARGIN, MARGIN)
	_top.reset_size()
	_top.position = Vector2(w - MARGIN - _top.size.x, MARGIN)
	_level.vertical = portrait
	_level.reset_size()
	if portrait:
		_level.position = Vector2(w - MARGIN - _level.size.x, MARGIN + _top.size.y + 6)
	else:
		_level.position = Vector2(_top.position.x - 6 - _level.size.x, MARGIN)
	# The minimap under the buttons in the corner (under the level buttons in portrait).
	var under: Control = _level if portrait else _top
	minimap.position = Vector2(w - MARGIN - minimap.size.x, under.position.y + under.size.y + 6)

	stick.visible = touch
	_action.visible = touch
	_jump.visible = touch
	_keys.visible = not touch and game != null and game.controls.show_help
	var bottom := h - MARGIN
	stick.position = Vector2(MARGIN + 4, bottom - stick.size.y)
	_action.size = _action.custom_minimum_size
	_action.position = Vector2(w - MARGIN - _action.size.x, bottom - _action.size.y)
	_jump.size = _jump.custom_minimum_size
	_jump.position = Vector2(_action.position.x - 6 - _jump.size.x, bottom - _jump.size.y)

	# As many slots as fit across the screen (hands, separator and paging take the rest).
	var fixed := 2 * SLOT + 12 + 3 * GAP + 8
	var fit_slots := floori((w - 2 * MARGIN - fixed - 28 - GAP) / (SLOT + GAP))
	_visible_slots = clampi(fit_slots, 1, _slots.size())
	if fit_slots >= _slots.size():
		_visible_slots = _slots.size()
	_page = mini(_page, _pages() - 1)
	_show_page()
	_bar.reset_size()
	var bw := _bar.size.x
	var bh := _bar.size.y
	var x := floorf((w - bw) * 0.5)
	var y := bottom - bh
	if touch:
		var free_left: float = stick.position.x + stick.size.x + 8
		var free_right := _jump.position.x - 8
		if free_right - free_left >= bw:
			x = clampf(x, free_left, free_right - bw)
		else:
			y = minf(stick.position.y, _jump.position.y) - 8 - bh
	_bar.position = Vector2(x, y)

	_keys.reset_size()
	_keys.position = Vector2(w - MARGIN - _keys.size.x, bottom - _keys.size.y)
	if _keys.position.x < x + bw + 8:
		_keys.position.y = y - 8 - _keys.size.y
	_loading.reset_size()
	_loading.position = ((size - _loading.size) * 0.5).floor()
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()
	_settings.fit(size)


func _pages() -> int:
	return ceili(_slots.size() / float(_visible_slots))


func _show_page() -> void:
	for i in _slots.size():
		var first := _page * _visible_slots
		_slots[i].visible = i >= first and i < first + _visible_slots
	_next_button.visible = _visible_slots < _slots.size()


func _next_page() -> void:
	_page = (_page + 1) % _pages()
	_show_page()


# --- Per-frame state -------------------------------------------------------------

## Fills the hotbar with block icons cut from the terrain atlas.
func set_block_icons(atlas: Texture2D, tile: int, tiles: int) -> void:
	for i in _slots.size():
		var m: int = Mat.PLACEABLE[i]
		var t := m * 3
		var icon := AtlasTexture.new()
		icon.atlas = atlas
		# The middle 12x12 of the 16 px tile, drawn twice as large.
		icon.region = Rect2((t % tiles) * tile + 2, floori(t / float(tiles)) * tile + 2, 12, 12)
		_slots[i].texture = icon
		_slots[i].number = str(i + 1)
	_update_hands()


func update_state() -> void:
	var hours := int(game.sky.time_of_day * 24.0)
	var minutes := int(fmod(game.sky.time_of_day * 24.0 * 60.0, 60.0))
	var winter: bool = game.sky.season == game.sky.WINTER
	_clock.text = "%s · день %d · %02d:%02d" % [game.sky.SEASONS[game.sky.season], game.sky.day, hours, minutes]
	var icon := "sun" if game.sky.daylight > 0.35 else "moon"
	minimap.set_player(Vector2i(floori(game.player.position.x / CELL), floori(game.player.position.z / CELL)))
	if game.sky.raining:
		icon = "snow" if winter else "rain"
	_set_icon(_clock_icon, icon)
	if game.chunks.manual_level >= 0:
		_level_label.text = "Срез %d" % game.chunks.cut_level
		_level_label.add_theme_color_override("font_color", UiStyle.ACCENT)
		_level_label.add_theme_color_override("font_hover_color", UiStyle.ACCENT)
	else:
		_level_label.text = "Ур. %d" % game.player.level()
		_level_label.add_theme_color_override("font_color", UiStyle.INK)
		_level_label.add_theme_color_override("font_hover_color", UiStyle.INK)


## Marks the hand in use and the selected block; called when either changes.
func _update_hands() -> void:
	if game == null:
		return
	_hand_left.selected = game.controls.dig_mode
	_hand_right.selected = not game.controls.dig_mode
	for i in _slots.size():
		_slots[i].selected = i == game.controls.selected
		_slots[i].tag = "П" if i == game.controls.selected else ""
	if not _slots.is_empty():
		_hand_right.texture = _slots[game.controls.selected].texture
	_action.text = "Копать" if game.controls.dig_mode else "Ставить"
	_action.icon = UiStyle.icon("pick_dark" if game.controls.dig_mode else "place_dark")


func refresh_hands() -> void:
	_update_hands()


func _select_slot(i: int) -> void:
	game.controls.select_block(i)


func set_loading(text: String) -> void:
	_loading.visible = text != ""
	_loading_label.text = text
	_loading.reset_size()
	_loading.position = ((size - _loading.size) * 0.5).floor()


## A short message under the clock that fades after a few seconds.
func toast(text: String) -> void:
	var p := _panel(_toasts)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(UiStyle.label(text))
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Hint next to the mouse pointer (`screen_pos` in screen pixels); empty text hides it.
func show_tip(screen_pos: Vector2, text: String) -> void:
	_tip.visible = text != "" and not touch
	if not _tip.visible:
		return
	_tip_label.text = text
	_tip.reset_size()
	var p := ((screen_pos - position) / scale.x + Vector2(12, 8)).floor()
	p.x = minf(p.x, size.x - _tip.size.x - 2)
	p.y = minf(p.y, size.y - _tip.size.y - 2)
	_tip.position = p


func show_keys(on: bool) -> void:
	_place()
	_keys.visible = on and not touch


# --- Statistics and menu ---------------------------------------------------------

func toggle_stats() -> void:
	perf.visible = not perf.visible
	_stats_button.modulate = UiStyle.ACCENT if perf.visible else Color.WHITE
	if perf.visible:
		perf.refresh()
	_update_menu()


func toggle_menu() -> void:
	if _settings.visible:
		_settings.close()
		return
	_menu.visible = not _menu.visible
	_shade.visible = _menu.visible
	# Over the hotbar and the touch buttons.
	_shade.move_to_front()
	_menu.move_to_front()
	# A game on this device stops while the menu is open (a server game will not).
	get_tree().paused = _menu.visible
	_update_menu()


## Opens the settings or the playtest page in place of the pause menu.
func open_settings(page: String) -> void:
	_menu.visible = false
	_settings.move_to_front()
	_settings.open(page)
	_settings.fit(size)


## The flask button: the playtest page over the running game, without the pause.
func toggle_test() -> void:
	if _settings.visible and _settings.page == "test":
		_settings.close()
	else:
		open_settings("test")


func _build_menu() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.4)
	_shade.visible = false
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_menu = _panel(self)
	_menu.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_menu.add_child(box)
	var title := UiStyle.label("Пауза", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_menu_buttons["resume"] = _add_menu_button(box, "Продолжить", toggle_menu)
	_menu_buttons["settings"] = _add_menu_button(box, "Настройки", open_settings.bind("settings"))
	_menu_buttons["stats"] = _add_menu_button(box, "", toggle_stats)
	_menu_buttons["test"] = _add_menu_button(box, "Для проверки", open_settings.bind("test"))
	_settings = SettingsMenu.new(game)
	_settings.closed.connect(func() -> void:
		if get_tree().paused:
			_menu.visible = true
			_update_menu())
	add_child(_settings)


func _update_menu() -> void:
	if game == null or not _menu.visible:
		return
	_menu_buttons["stats"].text = "Статистика: %s" % ("вкл" if perf.visible else "выкл")
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()


## Screen rectangles of the controls, for the F3 debug line and the browser smoke test.
func debug_rects() -> Dictionary:
	var out := {}
	var items := {"stick": stick, "buttons": _action, "jump": _jump, "hotbar": _bar, "menu": _menu_button,
		"test": _test_button}
	for k in items:
		var c: Control = items[k]
		out[k] = c.get_global_rect() if c.is_visible_in_tree() else Rect2()
	# The "next" arrow of the season row while the playtest page is open.
	out["season"] = _settings.debug_rects().get("Сезон", Rect2()) if _settings.visible else Rect2()
	return out


# --- Helpers -----------------------------------------------------------------------

func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## The hotbar frame is thinner than a panel so the slots sit close to its edge.
func _bar_box() -> StyleBox:
	var b := UiStyle.panel()
	b.content_margin_left = 4
	b.content_margin_top = 4
	b.content_margin_right = 4
	b.content_margin_bottom = 4
	return b


func _slot(parent: Node, action: Callable):
	var s = HotbarSlot.new(SLOT)
	s.pressed.connect(action)
	parent.add_child(s)
	return s


func _icon_button(parent: Node, icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", UiStyle.panel())
	b.add_theme_stylebox_override("hover", UiStyle.panel())
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _add_menu_button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200, 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _set_icon(rect: TextureRect, name: String) -> void:
	var t := UiStyle.icon(name)
	if rect.texture != t:
		rect.texture = t
