extends "res://src/client/ui/hud_menus.gd"
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
const PerfPanel := preload("res://src/client/ui/perf_panel.gd")
const TouchStick := preload("res://src/client/input/touch_stick.gd")
const TouchButton := preload("res://src/client/input/touch_button.gd")
const Warmth := preload("res://src/shared/game/warmth.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const LevelUp := preload("res://src/client/ui/level_up.gd")
const Inventory := preload("res://src/shared/game/inventory.gd")
const Body := preload("res://src/shared/game/body.gd")
## The camera cross: the width of its arms at the sides and the height of those above
## and below, and the middle (the view as text).
const DPAD_SIDE := 22
const DPAD_MIDDLE := Vector2(38, 30)


func _ready() -> void:
	theme = UiStyle.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Under the rest of the interface.
	feedback = BodyFeedback.new(game)
	add_child(feedback)
	add_child(LevelUp.new(game))

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
	# «zz» lies over the clock's right end, flush with its frame (see _align_clock): the
	# row keeps room for it.
	_sleep_room = Control.new()
	_sleep_room.custom_minimum_size = Vector2(SLEEP_SIZE.x - 8, 0)
	_sleep_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_sleep_room)
	_sleep_button = TabRow.icon_button(UiStyle.icon("sleep"), "Лечь спать",
		func() -> void: game.net.request(Protocol.SLEEP, [true]))
	_sleep_button.custom_minimum_size = SLEEP_SIZE
	add_child(_sleep_button)
	vitals = VitalsPanel.new()
	_left.add_child(vitals)
	vitals.mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the whole top of the interface, which moves down under it.
	perf = PerfPanel.new()
	perf.visible = false
	add_child(perf)
	perf.resized.connect(_place_top)
	# The toasts in a list of their own over the room it keeps under the state: the list
	# slides up as the oldest fades away (see _scroll_toasts).
	var toast_area := Control.new()
	toast_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(toast_area)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_area.add_child(_toasts)
	_toasts.minimum_size_changed.connect(func() -> void:
		_toasts.reset_size()
		toast_area.custom_minimum_size = _toasts.get_combined_minimum_size())

	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 6)
	add_child(_top)
	_stats_button = _icon_button(_top, "chart", "Статистика", toggle_stats)
	_stats_button.visible = game.settings.values.stats_button
	_test_button = _icon_button(_top, "flask", "Тестирование", toggle_test)
	_test_button.visible = game.settings.testing_unlocked
	_chat_button = _icon_button(_top, "chat", "Чат (Enter)", func() -> void: chat.toggle())
	_gesture_button = _icon_button(_top, "gesture", "Жесты (C)", toggle_gestures)
	_chat_button.visible = social(game.settings.values.solo_social)
	_gesture_button.visible = _chat_button.visible
	game.land.changed.connect(_show_land)
	game.land.entered.connect(_on_land_entered)
	game.land.painting_toggled.connect(_on_painting_toggled)
	_bag_button = _icon_button(_top, "person", "Персонаж, сумка и крафт", toggle_bag)
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
	# Each shows the arrow of the other side: the way the camera goes round, the world
	# turning under it the other way (2026-11-02).
	var turn_left := _icon_button(_camera, "turn_right", "Повернуть мир влево (держать: плавно)", Callable())
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
	var turn_right := _icon_button(_camera, "turn_left", "Повернуть мир вправо (держать: плавно)", Callable())
	for side: Array in [[turn_left, -1], [turn_right, 1]]:
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
	minimap.land = game.land
	game.land.changed.connect(map_view.redraw)
	minimap.painted.connect(map_view.redraw)
	if game.markers != null:
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
	# holds: the next tool.
	_hand_left = _slot(bar_row, tap_hand.bind(0))
	_hand_left.tag = "Л"
	_hand_right = _slot(bar_row, tap_hand.bind(1))
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
	# The hotbar's slots in a strip of the kit: arrows and a finger move them along when
	# not all fit.
	_strip = SlotStrip.new("Предыдущие ячейки", "Следующие ячейки")
	_strip.scrolled.connect(_show_page)
	bar_row.add_child(_strip)
	for i in Inventory.HOTBAR:
		var s = _slot(_strip.cells, _select_slot.bind(i))
		s.on_release = true
		_slots.append(s)
	_bag_meter = Button.new()
	_bag_meter.focus_mode = Control.FOCUS_NONE
	# In the clock's look; as wide as its divisions (_fit_bag_meter).
	_bag_meter.custom_minimum_size = Vector2(UiStyle.weight_width(40) + 16, SLEEP_SIZE.y)
	_bag_meter.size = _bag_meter.custom_minimum_size
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_bag_meter.add_theme_stylebox_override(state, UiStyle.panel(Vector4(5, 4, 5, 4)))
	_bag_meter.draw.connect(_draw_bag_meter)
	_bag_meter.pressed.connect(toggle_bag)
	add_child(_bag_meter)
	build_bar = BuildBar.new(game)
	build_bar.visible = false
	add_child(build_bar)
	farm_bar = FarmBar.new(game)
	farm_bar.visible = false
	add_child(farm_bar)

	stick = TouchStick.new()
	add_child(stick)
	_action = TouchButton.new()
	_action.custom_minimum_size = Vector2(88, 88)
	# Always the same size: words wrap onto more lines inside it (clipped past its edge,
	# never widening or heightening it); its words come close to its sides, so the
	# longest one (80 px: «Перевязать») fits whole on a line.
	_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action.clip_text = true
	_action.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	# The picture of what the hand holds, at twice its pixels.
	_action.expand_icon = true
	_action.add_theme_constant_override("icon_max_width", 24)
	_octagon_look(_action, UiStyle.ACCENT, UiStyle.ACCENT_DARK, UiStyle.DARK_INK)
	for state in ["normal", "hover", "disabled", "pressed", "hover_pressed"]:
		var box: StyleBox = _action.get_theme_stylebox(state)
		box.content_margin_left = 4
		box.content_margin_right = 4
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

	sleep = SleepScreen.new(game)
	add_child(sleep)
	chat = ChatBox.new(game)
	add_child(chat)
	person = PersonCard.new(game)
	add_child(person)
	bag = InventoryWindow.new(game)
	add_child(bag)
	# However the window closes (the button, its cross, a key), the button follows it.
	bag.visibility_changed.connect(_on_bag_shown)
	game.character.state_changed.connect(_counts_later)

	_build_menu()
	_update_hands()


func _unhandled_input(event: InputEvent) -> void:
	if game.world == null:
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
			KEY_F4:
				game.settings.set_ai_debug(not game.settings.ai_debug)
				get_viewport().set_input_as_handled()
			KEY_C:
				if _gesture_button.visible and not bag.visible:
					toggle_gestures()
					get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				if _chat_button.visible and not bag.visible:
					chat.open()
					get_viewport().set_input_as_handled()


# --- Layout --------------------------------------------------------------------


## The season, the day and the time, as the clock under the hotbar shows them.
func clock_text() -> String:
	var hours := int(game.clock.time_of_day * 24.0)
	var minutes := int(fmod(game.clock.time_of_day * 24.0 * 60.0, 60.0))
	return Lang.f("%s · %d° · д. %d · %02d:%02d", [game.clock.SEASONS[game.clock.season], roundi(air()), game.clock.day,
		hours, minutes])


## The air where the player stands, degrees (Warmth.air: biome, season, time, weather;
## a roof keeps the weather off), without the fires and clothes.
func air() -> float:
	var p: Vector3 = game.player.position
	var c := (p / WorldData.CELL).floor()
	var roofed: bool = game.world != null and game.world.roof_level(int(c.x), int(c.z)) > int(c.y) + 1
	return Warmth.air(game.world, game.clock, p, roofed)


## Gives the minimap the marks of the things placed and the sacks only when something
## was placed or taken or a sack moved, not every frame.
## Whether the vessels marked last (_vessels_seen) are the same and in the same cells.
func _same_cells(vessels: Array) -> bool:
	for i in vessels.size():
		var a: Vector3 = vessels[i][1] / WorldData.CELL
		var b: Vector3 = _vessels_seen[i][1] / WorldData.CELL
		if vessels[i][0] != _vessels_seen[i][0] or floori(a.x) != floori(b.x) or floori(a.z) != floori(b.z):
			return false
	return true


func _update_marks() -> void:
	if _marks_of != game.placed:
		if _marks_of != null:
			_marks_of.added.disconnect(_on_marks_changed)
			_marks_of.removed.disconnect(_on_marks_changed)
		_marks_of = game.placed
		_marks_of.added.connect(_on_marks_changed)
		_marks_of.removed.connect(_on_marks_changed)
		_marks_dirty = true
	var sacks: Array[Vector3] = game.character.sacks
	# The rafts and boats on the water, but the one the player sits in.
	var vessels := []
	if game.boats != null:
		for id: int in game.boats.vessels:
			if id != game.character.vessel:
				vessels.append([game.boats.vessels[id].item, game.boats.vessels[id].at])
	if not _marks_dirty and sacks == _sacks_seen and vessels.size() == _vessels_seen.size() and _same_cells(vessels):
		return
	minimap.set_marks(game.placed.things, sacks, vessels)
	_marks_dirty = false
	_sacks_seen = sacks.duplicate()
	_vessels_seen = vessels


func _on_marks_changed(_e: Dictionary) -> void:
	_marks_dirty = true


## Seconds between updates of the clock's line, and the time left to the next.
const CLOCK_EVERY := 0.25
var _clock_left := 0.0


func update_state() -> void:
	var winter: bool = game.clock.season == game.clock.WINTER
	# The clock's line (with the air's warmth) changes by the game's minute: a few times a second is enough.
	_clock_left -= get_process_delta_time()
	if _clock_left <= 0.0:
		_clock_left = CLOCK_EVERY
		_clock.text = clock_text()
	# The action button comes up (and says «Строить» again) as soon as the build or the
	# farming mode stops working, or the fishing line is out of the water, not at the bag's
	# next change.
	if _action.latched != _action_latched():
		_update_hands()
	# The state stays in sight while the bag is open, by the food it may be eaten from.
	vitals.pinned = bag.visible
	vitals.update(game.character.vitals, get_process_delta_time())
	sleep.update(get_process_delta_time())
	# The moon is bright when the body would sleep.
	_sleep_button.modulate = Color.WHITE if game.character.vitals.energy < game.character.vitals.SLEEP_BELOW else Color(1, 1, 1, 0.4)
	if bag.visible:
		bag.refresh_state()
	minimap.set_player(Vector2i(floori(game.player.position.x / game.CELL), floori(game.player.position.z / game.CELL)))
	_update_marks()
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
	_level_text.text = Lang.f("Срез\n%d", [game.chunks.cut_level]) if cut else Lang.f("Ур.\n%d", [game.player.level()])
	var ink := UiStyle.ACCENT if cut else UiStyle.INK
	# A colour set anew tells the label its theme changed, which lays it out again.
	if _level_ink != ink:
		_level_ink = ink
		_level_text.add_theme_color_override("font_color", ink)
