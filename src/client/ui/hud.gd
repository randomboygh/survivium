extends Control
## The game screen interface (plan/design/ui.md): clock, level cutaway, statistics and
## menu buttons, hotbar with both hands, joystick and action buttons on touch screens,
## key hints with a mouse, short messages, the hover hint, the pause menu, the
## character's state (VitalsPanel), what the body goes through (BodyFeedback) and the
## bag (InventoryWindow).
##
## The root is scaled by a whole number so one UI pixel is one pixel of the world, and
## the layout follows the shape of the screen: wide, tablet-like and portrait screens
## place the hotbar beside or above the touch controls. When the slots do not all fit
## (portrait shows four), arrows on both sides and a finger dragged along them scroll
## a slot at a time. A tab on the hotbar shows how many of the bag's slots are taken
## and its load; the minimap sits under the buttons in the corner with the level
## buttons on its left and the camera cross under it, each of them hidden and the map
## sized by the settings (set_corner).

const PixelView := preload("res://src/client/view/pixel_view.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const HotbarSlot := preload("res://src/client/ui/hotbar_slot.gd")
const PerfPanel := preload("res://src/client/ui/perf_panel.gd")
const TouchStick := preload("res://src/client/input/touch_stick.gd")
const TouchButton := preload("res://src/client/input/touch_button.gd")
const SettingsMenu := preload("res://src/client/ui/settings_menu.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")
const MapView := preload("res://src/client/ui/map_view.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const VitalsPanel := preload("res://src/client/ui/vitals_panel.gd")
const BodyFeedback := preload("res://src/client/ui/body_feedback.gd")
const InventoryWindow := preload("res://src/client/ui/inventory_window.gd")
const ChatBox := preload("res://src/client/ui/chat_box.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Body := preload("res://src/shared/game/body.gd")

const MARGIN := 8.0
const CELL := 0.5
const GAP := 4.0
const SLOT := 40
## UI height the scale aims for on the shorter side of the screen: on a phone exactly,
## so its windows fit any phone as they do the reference one (1200 px wide at ×3).
const TARGET_SIDE := 400.0
## The interface size setting, «очень мелкий» to «крупный»: on a phone the share of the
## scale picked from the screen, on a computer whole steps around it (UI_STEPS).
const UI_SIZES := [0.67, 0.83, 1.0, 1.33, 1.67]
const UI_STEPS := [-2, -1, 0, 1, 2]
## The size of the joystick and the touch buttons, the same five steps.
const CONTROL_SIZES := [0.7, 0.85, 1.0, 1.2, 1.4]
## The width of the level buttons beside the minimap: one button's; the arrows'
## height and the least of the level's between them.
const LEVEL_WIDTH := 40
const LEVEL_ARROW := 24
const LEVEL_MIDDLE := 34
## The camera cross: the width of its arms at the sides and the height of those above
## and below, and the middle (the view as text).
const DPAD_SIDE := 22
const DPAD_MIDDLE := Vector2(38, 30)
## The room round the buttons and panels on the screen, in UI pixels, where a tap
## that just misses one does not reach the world (see covers).
const SAFE_ZONE := 8
## The tab on the hotbar with the bag's slots and load, in UI pixels.
const METER_WIDTH := 108
const TOAST_TIME := 4.0
const MAX_TOASTS := 3
const KEYS := "WASD — ходить, Пробел — прыжок\nЛКМ — левой рукой, ПКМ — правой (держи — мазком)\nF — активной рукой перед собой\nV — инструмент в руку, C — кисть\n1–8, колесо — ячейка панели в руку\nI — сумка и крафт, «В руку» — что угодно\nQ / E — срез ниже / выше, R — к игроку\n[ ] — повернуть камеру, - = — наклон, \\ — сброс\nF3 — статистика, Esc — меню\nH — скрыть подсказку"

var game
var touch := false
var portrait := false
## The interface and the touch controls size settings, indices into UI_SIZES and
## CONTROL_SIZES.
var ui_size := 2
var control_size := 2
## The minimap size setting (an index into Minimap.SIDES) and whether the level buttons
## and the camera cross are shown (see set_corner).
var minimap_size := 1
var level_buttons := true
var camera_buttons := true
## The scale picked from the screen before the interface size setting (see fit).
var _screen_scale := 1.0

var _left: VBoxContainer
var _clock_icon: TextureRect
## An arrow by the weather icon where the wind blows while it is strong enough to
## slow walking against it.
var _wind: Control
var _wind_step := -1
var _clock: Label
## The season and the time, under the right end of the hotbar.
var _clock_panel: PanelContainer
var _toasts: VBoxContainer
## How wide a toast may be, in UI px: up to the buttons and the minimap on the right
## (see _place_top); a longer one wraps.
var _toast_room := 200.0
var perf: PanelContainer
var vitals: VitalsPanel
## The red frame and the numbers over the player when the body is hurt, healed or fed.
var feedback: BodyFeedback
var bag: InventoryWindow
## The chat on a server (hidden in single player), and its button.
var chat: ChatBox
var _chat_button: Button
var _bag_button: Button
## The tab on the hotbar with how many slots are taken and the load (a tap opens the
## bag).
var _bag_meter: Button
var _top: HBoxContainer
var _stats_button: Button
var _test_button: Button
var _menu_button: Button
var _level: BoxContainer
var minimap: Minimap
var map_view: MapView
var _level_label: Button
## The arrows beside it, dimmed past the levels that may be looked at (see
## ChunkStreamer.view_range).
var _level_up: Button
var _level_down: Button
## The camera buttons under the minimap: turn, tilt, and back to the default view
## (it shows the turn and the tilt).
var _camera: GridContainer
var _camera_reset: Button
## The text of the middle (and of the level), a label over the button so the text
## never makes it wider (see _fixed_label).
var _camera_label: Label
var _level_text: Label
var _camera_text := ""
## The colour last given to the level label's text (none yet: transparent).
var _level_ink := Color(0, 0, 0, 0)
var _bar: PanelContainer
var _hand_left
var _hand_right
var _slots := []
var _bar_row: HBoxContainer
var _prev_button: Button
var _next_button: Button
## The first hotbar slot shown and how many are shown.
var _first := 0
var _visible_slots := 8
## The finger dragging the hotbar slots along (-1 none), its x in the bar where the
## slots last moved, and whether it has moved far enough to be a drag, not a tap.
var _swipe := -1
var _swipe_x := 0.0
var _swiped := false
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
	# Under the rest of the interface.
	feedback = BodyFeedback.new(game)
	add_child(feedback)

	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left)
	var clock := _panel(self)
	_clock_panel = clock
	# A tap on the clock or the state does not reach the world under them.
	clock.mouse_filter = Control.MOUSE_FILTER_STOP
	# Under the hotbar: kept thin.
	clock.add_theme_stylebox_override("panel", UiStyle.panel(Vector4(5, 4, 5, 4)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	clock.add_child(row)
	_clock_icon = TextureRect.new()
	_clock_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_clock_icon.custom_minimum_size = Vector2(10, 10)
	row.add_child(_clock_icon)
	_wind = Control.new()
	_wind.custom_minimum_size = Vector2(11, 11)
	_wind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wind.draw.connect(_draw_wind)
	row.add_child(_wind)
	_clock = UiStyle.label()
	row.add_child(_clock)
	vitals = VitalsPanel.new()
	_left.add_child(vitals)
	vitals.mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the whole top of the interface, which moves down under it.
	perf = PerfPanel.new()
	perf.visible = false
	add_child(perf)
	perf.resized.connect(_place_top)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_toasts)

	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 6)
	add_child(_top)
	_stats_button = _icon_button(_top, "chart", "Статистика", toggle_stats)
	_test_button = _icon_button(_top, "flask", "Тестирование", toggle_test)
	_chat_button = _icon_button(_top, "chat", "Чат (Enter)", func() -> void: chat.toggle())
	_chat_button.visible = game != null and game.join_url != ""
	_bag_button = _icon_button(_top, "bag", "Сумка", toggle_bag)
	_menu_button = _icon_button(_top, "menu", "Меню", toggle_menu)

	# The level buttons in a column beside the minimap, as tall as it.
	_level = BoxContainer.new()
	_level.vertical = true
	_level.add_theme_constant_override("separation", 2)
	add_child(_level)
	var up := _icon_button(_level, "up", "Уровень выше", func() -> void: game.chunks.shift_cut(1))
	# The level itself is a button: a tap on a chosen cut returns to the player's level.
	_level_label = Button.new()
	_level_label.focus_mode = Control.FOCUS_NONE
	_level_label.custom_minimum_size = Vector2(LEVEL_WIDTH, LEVEL_MIDDLE)
	_level_label.tooltip_text = "Вернуться к уровню игрока"
	_level_label.pressed.connect(func() -> void: game.chunks.reset_view_level())
	_level.add_child(_level_label)
	_level_text = _fixed_label(_level_label)
	var down := _icon_button(_level, "down", "Уровень ниже", func() -> void: game.chunks.shift_cut(-1))
	for b in [up, down]:
		b.custom_minimum_size = Vector2(LEVEL_WIDTH, LEVEL_ARROW)
	_level_up = up
	_level_down = down
	for b: Button in [up, _level_label, down]:
		_see_through(b)
	minimap = Minimap.new()
	add_child(minimap)
	# The camera buttons as a cross under the minimap: turn at the sides, tilt above
	# and below, the view in the middle (a tap puts it back).
	_camera = GridContainer.new()
	_camera.columns = 3
	_camera.add_theme_constant_override("h_separation", 2)
	_camera.add_theme_constant_override("v_separation", 2)
	add_child(_camera)
	var pad := func() -> void:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_camera.add_child(c)
	pad.call()
	var tilt_up := _icon_button(_camera, "tilt_up", "Наклонить камеру круче", func() -> void: game.view.tilt_by(1))
	pad.call()
	# Held, a turn button turns the camera on smoothly (see CameraRig.hold_turn).
	var turn_left := _icon_button(_camera, "turn_left", "Повернуть камеру влево (держать: плавно)", Callable())
	_camera_reset = Button.new()
	_camera_reset.focus_mode = Control.FOCUS_NONE
	_camera_reset.custom_minimum_size = Vector2(DPAD_MIDDLE.x, DPAD_MIDDLE.y)
	_camera_reset.tooltip_text = "Вернуть камеру как была"
	_camera_reset.pressed.connect(func() -> void: game.view.reset_turn())
	_camera.add_child(_camera_reset)
	_camera_label = _fixed_label(_camera_reset)
	# The letters a pixel closer, so «315°» fits inside the frame of the middle and the
	# cross stays as wide as the minimap.
	var tight := FontVariation.new()
	tight.base_font = UiStyle.font()
	tight.spacing_glyph = -1
	_camera_label.add_theme_font_override("font", tight)
	var turn_right := _icon_button(_camera, "turn_right", "Повернуть камеру вправо (держать: плавно)", Callable())
	for side: Array in [[turn_left, 1], [turn_right, -1]]:
		var dir: int = side[1]
		side[0].button_down.connect(func() -> void: game.view.hold_turn(dir))
		side[0].button_up.connect(func() -> void: game.view.release_turn(dir))
	pad.call()
	var tilt_down := _icon_button(_camera, "tilt_down", "Наклонить камеру ниже", func() -> void: game.view.tilt_by(-1))
	pad.call()
	for b: Button in [tilt_up, tilt_down]:
		b.custom_minimum_size = Vector2(DPAD_MIDDLE.x, DPAD_SIDE)
	for b: Button in [turn_left, turn_right]:
		b.custom_minimum_size = Vector2(DPAD_SIDE, DPAD_MIDDLE.y)
	for b: Button in [tilt_up, turn_left, turn_right, tilt_down, _camera_reset]:
		_see_through(b)
	map_view = MapView.new()
	map_view.minimap = minimap
	map_view.game = game
	add_child(map_view)
	minimap.open_map.connect(map_view.open)
	minimap.painted.connect(map_view.redraw)
	if game != null and game.markers != null:
		minimap.markers = game.markers
		map_view.markers = game.markers
		game.markers.changed.connect(minimap.redraw)
		game.markers.changed.connect(map_view.redraw)

	_bar = _panel(self)
	_bar.add_theme_stylebox_override("panel", _bar_box())
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", int(GAP))
	_bar.add_child(bar_row)
	_bar_row = bar_row
	# A tap on a hand makes it the hand in use; on the hand in use it changes what it
	# holds: the next brush for a block, else the next tool.
	_hand_left = _slot(bar_row, _tap_hand.bind(0))
	_hand_left.tag = "Л"
	_hand_right = _slot(bar_row, _tap_hand.bind(1))
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
	_prev_button = _icon_button(bar_row, "prev", "Предыдущие ячейки", _prev_page)
	_prev_button.custom_minimum_size = Vector2(28, SLOT)
	for i in Inventory.HOTBAR:
		var s = _slot(bar_row, _select_slot.bind(i))
		s.on_release = true
		_slots.append(s)
	_next_button = _icon_button(bar_row, "next", "Следующие ячейки", _next_page)
	_next_button.custom_minimum_size = Vector2(28, SLOT)
	_bag_meter = Button.new()
	_bag_meter.focus_mode = Control.FOCUS_NONE
	_bag_meter.custom_minimum_size = Vector2(METER_WIDTH, 16)
	_bag_meter.size = _bag_meter.custom_minimum_size
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_bag_meter.add_theme_stylebox_override(state, _bar_box())
	_bag_meter.draw.connect(_draw_bag_meter)
	_bag_meter.pressed.connect(toggle_bag)
	add_child(_bag_meter)

	stick = TouchStick.new()
	add_child(stick)
	_action = TouchButton.new()
	_action.custom_minimum_size = Vector2(84, 84)
	_action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_octagon_look(_action, UiStyle.ACCENT, UiStyle.ACCENT_DARK, UiStyle.DARK_INK)
	_action.held.connect(func(on: bool) -> void: game.controls.action_held = on)
	add_child(_action)
	_jump = TouchButton.new()
	_jump.text = "Прыжок"
	_jump.icon = UiStyle.icon("up")
	_jump.custom_minimum_size = Vector2(56, 56)
	_jump.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jump.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_octagon_look(_jump, UiStyle.BUTTON, UiStyle.BUTTON_SHADE, UiStyle.INK)
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

	chat = ChatBox.new(game)
	add_child(chat)
	bag = InventoryWindow.new(game)
	add_child(bag)
	game.character.state_changed.connect(refresh_counts)

	_build_menu()
	_update_hands()


func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.world == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if bag.visible:
					toggle_bag()
				else:
					toggle_menu()
				get_viewport().set_input_as_handled()
			KEY_F3:
				toggle_stats()
				game.print_debug()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				if _chat_button.visible and not bag.visible:
					chat.open()
					get_viewport().set_input_as_handled()


# --- Layout --------------------------------------------------------------------

## Fits the UI into `rect` (screen pixels) and places everything for the screen's
## shape and the input in use. On a computer the scale is a whole number picked from
## the shorter side; on a phone or a tablet (`turning`) it is a fraction of the whole
## `screen`'s shorter side (the whole screen, `rect` by default), so browser toolbars
## coming and going do not change it.
func fit(rect: Rect2, turning := false, screen := Vector2.ZERO) -> void:
	var s: float
	if turning:
		var side := minf(screen.x, screen.y) if screen != Vector2.ZERO else minf(rect.size.x, rect.size.y)
		_screen_scale = side / TARGET_SIDE
		s = maxf(1.0, _screen_scale * UI_SIZES[ui_size])
	else:
		_screen_scale = maxi(1, roundi(minf(rect.size.x, rect.size.y) / TARGET_SIDE))
		s = maxi(1, _screen_scale + UI_STEPS[ui_size])
	scale = Vector2(s, s)
	position = rect.position
	size = (rect.size / s).floor()
	portrait = size.x < size.y
	_place()


## Sizes the minimap (an index into Minimap.SIDES) and shows or hides the level buttons
## and the camera cross, as the interface settings say; lays the HUD out again when
## something changed.
func set_corner(map_size: int, level: bool, camera: bool) -> void:
	if map_size == minimap_size and level == level_buttons and camera == camera_buttons \
			and minimap.side == Minimap.SIDES[map_size]:
		return
	minimap_size = map_size
	level_buttons = level
	camera_buttons = camera
	minimap.set_side(Minimap.SIDES[map_size])
	# Up, the level and down are as tall as the minimap, or as tall as they can be
	# beside a small one.
	_level_label.custom_minimum_size.y = maxf(LEVEL_MIDDLE, minimap.size.y - 2 * LEVEL_ARROW - 4)
	_level.visible = level
	_camera.visible = camera
	if size != Vector2.ZERO:
		_place()


func set_touch(on: bool) -> void:
	if on == touch:
		return
	touch = on
	_place()


func _place() -> void:
	var w := size.x
	var h := size.y
	_place_top()

	stick.visible = touch
	_action.visible = touch
	_jump.visible = touch
	_keys.visible = not touch and game != null and game.controls.show_help and not bag.visible
	var bottom := h - MARGIN
	# The controls' own size setting, whatever the interface's: undo the latter.
	var k: float = CONTROL_SIZES[control_size] * _screen_scale / scale.x
	for c: Control in [stick, _action, _jump]:
		c.scale = Vector2(k, k)
	var stick_size: Vector2 = stick.size * k
	stick.position = Vector2(MARGIN + 4, bottom - stick_size.y)
	_action.size = _action.custom_minimum_size
	_action.position = Vector2(w - MARGIN - _action.size.x * k, bottom - _action.size.y * k)
	_jump.size = _jump.custom_minimum_size
	_jump.position = Vector2(_action.position.x - 6 - _jump.size.x * k, bottom - _jump.size.y * k)

	# All the slots when they fit across the screen beside the hands and the separator,
	# else as many as fit between the two arrows, four at most in portrait.
	var fixed := 2 * SLOT + 12 + 3 * GAP + 8
	var room := w - 2 * MARGIN - fixed
	if floori(room / (SLOT + GAP)) >= _slots.size():
		_visible_slots = _slots.size()
	else:
		_visible_slots = clampi(floori((room - 2 * (28 + GAP)) / (SLOT + GAP)), 1, 4 if portrait else _slots.size())
	_first = clampi(_first, 0, _slots.size() - _visible_slots)
	_show_page()
	_bar.reset_size()
	var bw := _bar.size.x
	var bh := _bar.size.y
	var x := floorf((w - bw) * 0.5)
	var y := bottom - bh
	if touch:
		var free_left: float = stick.position.x + stick_size.x + 8
		var free_right := _jump.position.x - 8
		if free_right - free_left >= bw:
			x = clampf(x, free_left, free_right - bw)
		else:
			y = minf(stick.position.y, _jump.position.y) - 8 - bh
	# The clock under the hotbar's right end, overlapping its outline.
	_clock_panel.reset_size()
	var clock_room := _clock_panel.size.y - 2
	y -= clock_room
	_bar.position = Vector2(x, y)
	_clock_panel.position.y = y + bh - 2
	_align_clock()
	# The tab sits on the hotbar's frame at its right end, overlapping its outline.
	_bag_meter.position = Vector2(x + bw - METER_WIDTH, y - _bag_meter.size.y + 2)

	_keys.reset_size()
	_keys.position = Vector2(w - MARGIN - _keys.size.x, bottom - _keys.size.y)
	if _keys.position.x < x + bw + 8:
		_keys.position.y = y - 8 - _keys.size.y
	# Off the camera cross under the minimap, on the left of a short window.
	if _camera.visible and Rect2(_keys.position, _keys.size).intersects(Rect2(_camera.position, _camera.size).grow(4)):
		_keys.position.x = MARGIN
	# The chat in the bottom left corner: over the stick, over the hotbar where they
	# share the left of the screen.
	var chat_bottom: float = stick.position.y - 6 if touch else bottom
	if x < MARGIN + ChatBox.WIDTH + 8:
		chat_bottom = minf(chat_bottom, _bag_meter.position.y - 4)
	chat.place(Vector2(MARGIN, chat_bottom), w - 2 * MARGIN)
	_loading.reset_size()
	_loading.position = ((size - _loading.size) * 0.5).floor()
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()
	_settings.fit(size)
	bag.fit(size)
	map_view.fit(size, touch)
	refresh_counts()


func _show_page() -> void:
	for i in _slots.size():
		_slots[i].visible = i >= _first and i < _first + _visible_slots
	_next_button.visible = _visible_slots < _slots.size()
	_prev_button.visible = _next_button.visible
	# The arrows stop at the ends: the slots do not go round.
	_prev_button.disabled = _first <= 0
	_next_button.disabled = _first >= _slots.size() - _visible_slots


## The next slot (as a finger dragging the slots one along); none past the last.
func _next_page() -> void:
	_scroll(1)


## The slot before; none before the first.
func _prev_page() -> void:
	_scroll(-1)


## Moves the shown slots `by` slots along.
func _scroll(by: int) -> void:
	_first = clampi(_first + by, 0, _slots.size() - _visible_slots)
	_show_page()


## A finger dragged along the hotbar slots moves them a slot for each slot it passes;
## the tap it began with picks nothing.
func _input(event: InputEvent) -> void:
	if _bar == null or not _prev_button.visible or not _bar.is_visible_in_tree():
		_swipe = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _swipe < 0 and _in_slots(event.position):
			_swipe = event.index
			_swipe_x = _bar_x(event.position)
			_swiped = false
		elif not event.pressed and event.index == _swipe:
			_swipe = -1
	elif event is InputEventScreenDrag and event.index == _swipe:
		var x := _bar_x(event.position)
		if not _swiped and absf(x - _swipe_x) > 6.0:
			_swiped = true
			for s in _slots:
				s.cancel_tap()
		if _swiped:
			var step := SLOT + GAP
			while _swipe_x - x >= step:
				_scroll(1)
				_swipe_x -= step
			while x - _swipe_x >= step:
				_scroll(-1)
				_swipe_x += step


## Screen point `pos` in UI pixels of the hotbar row.
func _bar_point(pos: Vector2) -> Vector2:
	return _bar_row.get_global_transform_with_canvas().affine_inverse() * pos


func _bar_x(pos: Vector2) -> float:
	return _bar_point(pos).x


## Whether screen point `pos` is on the slots between the arrows.
func _in_slots(pos: Vector2) -> bool:
	var p := _bar_point(pos)
	return p.y >= 0.0 and p.y <= _bar_row.size.y and p.x >= _prev_button.position.x \
		and p.x <= _next_button.position.x + _next_button.size.x


# --- Per-frame state -------------------------------------------------------------

## Gives the item pictures the terrain atlas, for blocks without a picture of their own.
func set_block_icons(atlas: Texture2D, tile: int, tiles: int) -> void:
	ItemIcons.use_atlas(atlas, tile, tiles)
	refresh_counts()


## Shows the bag's first row on the hotbar: each item with how many there are and its
## number (its key with a keyboard, as in the bag); then the hands and the bag button.
func refresh_counts() -> void:
	if game == null:
		return
	var slots: Array = game.character.inventory.slots
	for i in _slots.size():
		var s = slots[i]
		_slots[i].texture = ItemIcons.of_item(s[0]) if s != null else null
		_slots[i].number = "×%d" % s[1] if s != null and s[1] > 1 else ""
		_slots[i].key = str(i + 1)
	_update_hands()
	_bag_meter.queue_redraw()


## The top of the interface: the statistics over it when shown, under them the state
## on the left, the buttons on the right, the minimap under the buttons with the level
## buttons on its left and the camera cross under it (under both when the map is small,
## kept on the screen). The statistics take the room
## left of the buttons when PerfPanel.WIDTH fits there (a wide screen); else they go
## across the whole top and everything moves down under them (a phone held upright).
## Their width stays as it is while their numbers change.
func _place_top() -> void:
	var w := size.x
	_top.reset_size()
	var column := _top.size.x
	_level.reset_size()
	var level := _level.size.x + 6 if _level.visible else 0.0
	column = maxf(column, minimap.size.x + level)
	var top := MARGIN
	var left := MARGIN
	if perf.visible:
		var beside := w - 3 * MARGIN - column
		perf.width = perf.WIDTH if perf.WIDTH <= beside else w - 2 * MARGIN
		perf.position = Vector2(MARGIN, MARGIN)
		perf.size = Vector2(perf.width, 0)
		left += perf.size.y + 6
		if perf.width > beside:
			top = left
	_left.position = Vector2(MARGIN, left)
	_top.position = Vector2(w - MARGIN - _top.size.x, top)
	minimap.position = Vector2(w - MARGIN - minimap.size.x, _top.position.y + _top.size.y + 6)
	_level.position = Vector2(minimap.position.x - 6 - _level.size.x, minimap.position.y)
	_camera.reset_size()
	var cx := minf(minimap.position.x + floorf((minimap.size.x - _camera.size.x) * 0.5), w - MARGIN - _camera.size.x)
	var below := minimap.position.y + minimap.size.y
	if _level.visible and cx < _level.position.x + _level.size.x:
		below = maxf(below, _level.position.y + _level.size.y)
	_camera.position = Vector2(cx, below + 6)
	var room := minf(_top.position.x, minimap.position.x - level) - 6 - MARGIN
	if room != _toast_room:
		_toast_room = room
		for p: PanelContainer in _toasts.get_children():
			_fit_toast(p)


## Keeps the clock's right edge on the hotbar's as its text and icons change width.
func _align_clock() -> void:
	var wide := _clock_panel.get_combined_minimum_size().x
	if not is_equal_approx(_clock_panel.size.x, wide):
		_clock_panel.size.x = wide
	_clock_panel.position.x = _bar.position.x + _bar.size.x - wide


## The season, the day and the time, as the clock under the hotbar shows them.
func clock_text() -> String:
	var hours := int(game.clock.time_of_day * 24.0)
	var minutes := int(fmod(game.clock.time_of_day * 24.0 * 60.0, 60.0))
	return "%s · д. %d · %02d:%02d" % [game.clock.SEASONS[game.clock.season], game.clock.day, hours, minutes]


func update_state() -> void:
	var winter: bool = game.clock.season == game.clock.WINTER
	_clock.text = clock_text()
	# The state stays in sight while the bag is open, by the food it may be eaten from.
	vitals.pinned = bag.visible
	vitals.update(game.character.vitals, get_process_delta_time())
	if bag.visible:
		bag.refresh_state()
	minimap.set_player(Vector2i(floori(game.player.position.x / CELL), floori(game.player.position.z / CELL)))
	minimap.set_marks(game.placed.things, game.character.sacks)
	minimap.set_view_up(PixelView.up)
	_set_icon(_clock_icon, game.sky.icon())
	_wind.visible = game.clock.storm_wind >= Body.WIND_FELT
	_align_clock()
	# Eight ways, so the arrow stays on the pixel grid.
	# The way it blows on the screen, as the camera is turned.
	var blow := PixelView.screen_dir(Vector2.from_angle(game.clock.wind_angle)).angle()
	var step := posmod(roundi(blow / (PI / 4.0)), 8)
	if step != _wind_step:
		_wind_step = step
		_wind.queue_redraw()
	var view = game.view
	# The turn in degrees, and the tilt in steps under it when there is one: "90°", "90°\n+1".
	var text := "%d°" % view.turn_degrees()
	if view.tilt_steps != 0:
		text += "\n%+d" % view.tilt_steps
	if text != _camera_text:
		_camera_text = text
		_camera_label.text = text
		_camera_label.add_theme_color_override("font_color", UiStyle.INK if view.is_default() else UiStyle.ACCENT)
	var cut: bool = game.chunks.manual_level >= 0
	var reach: Vector2i = game.chunks.view_range()
	_level_up.disabled = game.chunks.cut_base() + 1 > reach.y
	_level_down.disabled = game.chunks.cut_base() - 1 < reach.x
	# On two lines, so the column is one button wide.
	_level_text.text = "Срез\n%d" % game.chunks.cut_level if cut else "Ур.\n%d" % game.player.level()
	var ink := UiStyle.ACCENT if cut else UiStyle.INK
	# A colour set anew tells the label its theme changed, which lays it out again.
	if _level_ink != ink:
		_level_ink = ink
		_level_text.add_theme_color_override("font_color", ink)


## Shows what each hand holds and marks the hand in use and the blocks in the hands;
## called when any of it changes.
func _update_hands() -> void:
	if game == null:
		return
	var c = game.controls
	var free: bool = game.rules.free_build
	for h in 2:
		var slot = _hand_left if h == 0 else _hand_right
		var id: String = c.hands[h]
		slot.selected = c.active == h
		slot.texture = ItemIcons.of_item(id) if id != "" else ItemIcons.picture("hand")
		var n: int = game.character.inventory.count(id) if id != "" else 0
		slot.modulate = Color(1, 1, 1, 0.5) if id != "" and n == 0 and not (free and c.use_of(h) == "place") else Color.WHITE
		var brush: Dictionary = c.brush_record()
		if c.use_of(h) == "place":
			slot.number = brush.title if brush.title != "1×1" else ""
		else:
			slot.number = "×%d" % n if n > 1 else ""
	var slots: Array = game.character.inventory.slots
	for i in _slots.size():
		var item: String = slots[i][0] if slots[i] != null else ""
		_slots[i].selected = item != "" and c.held() == item
		_slots[i].tag = "" if item == "" else ("Л" if c.hands[0] == item else ("П" if c.hands[1] == item else ""))
	_action.text = c.action_name()
	_action.icon = UiStyle.icon("place_dark" if c.use_of() in ["place", "plant", "sow", "prop"] else "pick_dark")


func refresh_hands() -> void:
	_update_hands()


## A tap on hand `hand` of the hotbar.
func _tap_hand(hand: int) -> void:
	var c = game.controls
	if c.active != hand:
		c.set_active(hand)
	elif c.use_of() == "place":
		c.cycle_brush()
	else:
		c.cycle_tool()


func _select_slot(i: int) -> void:
	game.controls.select_slot(i)


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
	_fit_toast(p)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(TOAST_TIME)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Wraps toast `p`'s text when it is wider than the room left of the buttons.
func _fit_toast(p: PanelContainer) -> void:
	var l: Label = p.get_child(0)
	var frame := p.get_theme_stylebox("panel").get_minimum_size().x
	var room := floorf(_toast_room - frame)
	var font := l.get_theme_font("font")
	var wide := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	var wrap := wide + 1.0 > room
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = room if wrap else 0.0


## Hint next to the mouse pointer (`screen_pos` in screen pixels); empty text hides it.
func show_tip(screen_pos: Vector2, text: String, on_touch := false) -> void:
	_tip.visible = text != "" and (on_touch or not touch)
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
	_keys.visible = on and not touch and not bag.visible


# --- Statistics and menu ---------------------------------------------------------

## Opens the bag with the chest by the spawn beside it.
func open_chest() -> void:
	for e: Dictionary in game.placed.things:
		if e.items != null and e.items == game.placed.chest_items:
			open_prop(e)


## Opens the bag at placed thing `e` (see Props.placed): a chest beside the bag, the
## craft tab at a station.
func open_prop(e: Dictionary) -> void:
	if not bag.visible:
		toggle_bag()
	if e.items != null:
		bag.show_chest(e)
	else:
		bag.show_station(e)


## Opens or closes the bag over the running game.
func toggle_bag() -> void:
	bag.toggle()
	_bag_button.modulate = UiStyle.ACCENT if bag.visible else Color.WHITE
	_place()


func toggle_stats() -> void:
	perf.visible = not perf.visible
	_stats_button.modulate = UiStyle.ACCENT if perf.visible else Color.WHITE
	if perf.visible:
		perf.refresh()
	_place_top()
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
	# A game on this device stops while the menu is open (a server game will not),
	# and is saved.
	get_tree().paused = _menu.visible
	if _menu.visible:
		game.save.flush()
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


## The window of the server made here, over the main menu (the world goes on).
func _to_server() -> void:
	toggle_menu()
	game.menu.open()
	game.menu.open_host()


## Leaves the pause for the main menu over the running world.
func _to_main_menu() -> void:
	toggle_menu()
	game.menu.open()


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
	_menu_buttons["test"] = _add_menu_button(box, "Тестирование", open_settings.bind("test"))
	_menu_buttons["server"] = _add_menu_button(box, "Сервер", _to_server)
	_menu_buttons["main"] = _add_menu_button(box, "Главное меню", _to_main_menu)
	_settings = SettingsMenu.new(game)
	_settings.closed.connect(func() -> void:
		if get_tree().paused:
			_menu.visible = true
			_update_menu())
	add_child(_settings)


func _update_menu() -> void:
	if game == null or not _menu.visible:
		return
	# Tests and tools play without the main menu.
	_menu_buttons["main"].visible = game.menu != null
	# The window of the server made here (Main.hosted), the world going on meanwhile.
	_menu_buttons["server"].visible = game.menu != null and game.hosted != null
	_menu.reset_size()
	_menu.position = ((size - _menu.size) * 0.5).floor()


## Whether a tap at `screen_pos` (screen pixels) is on or within SAFE_ZONE of the
## buttons and panels on the screen: such a tap that just misses one is not a tap on
## the world (no digging, no «Слишком далеко»).
func covers(screen_pos: Vector2) -> bool:
	var room := SAFE_ZONE * scale.x
	for c: Control in [_top, _level, minimap, _camera, _bar, _bag_meter, _clock_panel, vitals, stick, _action, _jump]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().grow(room).has_point(screen_pos):
			return true
	return false


## Screen rectangles of the controls, for the F3 debug line and the browser smoke test.
func debug_rects() -> Dictionary:
	var out := {}
	var items := {"stick": stick, "buttons": _action, "jump": _jump, "hotbar": _bar, "menu": _menu_button,
		"test": _test_button, "bag": _bag_button}
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


## The look of a big touch button: an octagon of `fill` with a lip of `shade`, pressed
## down while held; `ink` for its words.
func _octagon_look(b: Button, fill: Color, shade: Color, ink: Color) -> void:
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)


## Frames a helper button like the others but see-through inside, so it hides little
## of the world: the level and camera buttons.
func _see_through(b: Button) -> void:
	for state in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, UiStyle.frame())
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.frame(true))
	b.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))


## A label over button `b`, filling it, its text centred and outlined like the
## see-through buttons': a long text spills over the frame instead of widening the
## button, so the buttons of the corner keep their size.
func _fixed_label(b: Button) -> Label:
	var l := UiStyle.label()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its two lines apart, the font's own lines touch.
	l.add_theme_constant_override("line_spacing", 4)
	l.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	l.add_theme_constant_override("outline_size", 4)
	b.add_child(l)
	return l


func _icon_button(parent: Node, icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon) if icon != "" else null
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 40)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", UiStyle.panel())
	b.add_theme_stylebox_override("hover", UiStyle.panel())
	if action.is_valid():
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


## The tab on the hotbar: the bag, how many of its slots are taken (amber when all),
## and a bar of the load against the limit (amber near it, red past it).
func _draw_bag_meter() -> void:
	if game == null:
		return
	var inv = game.character.inventory
	var c: Control = _bag_meter
	var w := c.size.x
	var icon := UiStyle.icon("bag")
	c.draw_texture(icon, Vector2(5, 4))
	var taken := 0
	for s in inv.slots:
		if s != null:
			taken += 1
	var text := "%d/%d" % [taken, inv.slots.size()]
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	c.draw_string(font, Vector2(17, 4 + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		UiStyle.ACCENT if taken >= inv.slots.size() else UiStyle.INK)
	var share: float = inv.load_share()
	var bar := Rect2(61, 6, w - 66, 5)
	c.draw_rect(bar.grow(1), UiStyle.EDGE)
	c.draw_rect(bar, UiStyle.WELL)
	c.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(share, 0.0, 1.0)), bar.size.y)),
		UiStyle.DANGER if share > 1.0 else (UiStyle.ACCENT if share > 0.9 else UiStyle.GOOD))
	c.tooltip_text = "Сумка: %d из %d ячеек, %.1f из %d кг" % [taken, inv.slots.size(), inv.weight(), inv.weight_limit]


func _draw_wind() -> void:
	var a := _wind_step * PI / 4.0
	var d := Vector2(roundf(cos(a)), roundf(sin(a)))
	var mid := (_wind.size * 0.5).floor() + Vector2(0.5, 0.5)
	var tip := mid + d * 4.0
	_wind.draw_line(mid - d * 5.0, tip, UiStyle.INK, 1.0)
	for side: float in [-1.0, 1.0]:
		var back := Vector2(roundf(cos(a + side * PI * 0.75)), roundf(sin(a + side * PI * 0.75)))
		_wind.draw_line(tip, tip + back * 3.0, UiStyle.INK, 1.0)


func _set_icon(rect: TextureRect, name: String) -> void:
	var t := UiStyle.icon(name)
	if rect.texture != t:
		rect.texture = t
