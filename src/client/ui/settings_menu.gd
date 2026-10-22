extends PanelContainer
## The settings window and the playtest window, opened from the pause menu. Both are
## lists of rows "name ‹ value ›": a tap or a click on an arrow picks the next value,
## which suits a thumb as well as a mouse; the keyboard moves between rows with the
## arrows and changes a value with Left / Right or Enter. Values come from and go to
## Settings (plan/design/ui.md, section 6). The playtest page also shows the version
## of the build and opens the list of recent changes ("changes" page).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Settings := preload("res://src/client/settings.gd")

## Room for the longest name (18 letters of the 8 px font).
const NAME_WIDTH := 150
const VALUE_WIDTH := 100
const ARROW := 32
const HOURS := ["ночь", "утро", "день", "вечер"]
const HOUR_OF := [0.0, 7.0, 12.0, 19.0]
## Moonlight picks of the playtest page: name and light (see Settings.set_moon).
const MOONS := [["новолуние", 0.0], ["серп", 0.4], ["полнолуние", 1.0]]
## Written by tools/build_info.py in CI; a local run has none and shows "dev".
const BUILD_INFO := "res://build_info.json"

signal closed

var game
## "settings", "test" or "changes": which page is shown.
var page := ""
var _title: Label
var _version: Label
var _changes: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
## Rows of the page: {"key", "values": Array of String, "get": Callable, "set": Callable, "label": Label}
var _rows := []
var _focus := -1
var _back: Button
var _screen := Vector2.ZERO


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_title = UiStyle.label("", UiStyle.ACCENT)
	_title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_version = UiStyle.label("", UiStyle.MUTED)
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_version)
	# The rows scroll when the window is taller than a small screen with a big interface.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	_changes = Button.new()
	_changes.text = "Что нового"
	_changes.focus_mode = Control.FOCUS_NONE
	_changes.custom_minimum_size = Vector2(0, 32)
	_changes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_changes.pressed.connect(open.bind("changes"))
	buttons.add_child(_changes)
	_back = Button.new()
	_back.text = "Назад"
	_back.focus_mode = Control.FOCUS_NONE
	_back.custom_minimum_size = Vector2(0, 32)
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.pressed.connect(_go_back)
	buttons.add_child(_back)


func open(which: String) -> void:
	page = which
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	_focus = -1
	var s = game.settings
	var sky = game.sky
	var clock = game.clock
	var info := build_info()
	_version.text = "Версия %s · %s · %s" % [info.version, info.commit, info.date]
	_version.visible = which != "settings"
	_changes.visible = which == "test"
	if which == "changes":
		_title.text = "Что нового"
		_add_changes(info.changes)
	elif which == "settings":
		_title.text = "Настройки"
		_add_row("Длина суток", Settings.TIME_SPEEDS.map(func(v: float) -> String: return "%d мин" % roundi(clock.DAY_LENGTH / v / 60.0)),
			func() -> int: return s.values.time_speed,
			func(i: int) -> void: s.set_value("time_speed", i))
		_add_row("Пиксель", ["обычный", "крупный", "огромный"],
			func() -> int: return s.values.pixel_size,
			func(i: int) -> void: s.set_value("pixel_size", i))
		_add_row("Интерфейс", ["обычный", "крупнее", "крупный"],
			func() -> int: return s.values.ui_scale,
			func(i: int) -> void: s.set_value("ui_scale", i))
		_add_row("Тени", ["выкл", "вкл"],
			func() -> int: return int(s.values.shadows),
			func(i: int) -> void: s.set_value("shadows", i == 1))
		_add_row("Тени от огня", ["выкл", "нарисованные", "настоящие"],
			func() -> int: return s.values.fire_shadows,
			func(i: int) -> void: s.set_value("fire_shadows", i))
		_add_row("Эффекты", ["выкл", "вкл"],
			func() -> int: return int(s.values.effects),
			func(i: int) -> void: s.set_value("effects", i == 1))
		_add_row("Предел FPS", Settings.FPS_LIMITS.map(func(v: int) -> String: return "нет" if v == 0 else str(v)),
			func() -> int: return s.values.fps_limit,
			func(i: int) -> void: s.set_value("fps_limit", i))
		_add_row("Автоподбор", ["выкл", "вкл"],
			func() -> int: return int(s.values.auto_pickup),
			func(i: int) -> void: s.set_value("auto_pickup", i == 1))
		if not game.controls.touch:
			_add_row("Подсказка клавиш", ["выкл", "вкл"],
				func() -> int: return int(s.values.show_help),
				func(i: int) -> void: s.set_value("show_help", i == 1))
	else:
		_title.text = "Тестирование"
		_add_row("Сезон", clock.SEASONS,
			func() -> int: return clock.season,
			func(i: int) -> void: s.set_season(i))
		_add_row("Погода", ["сама"] + clock.WEATHERS.map(func(w: Dictionary) -> String: return w.name.to_lower()),
			func() -> int: return 0 if clock.weather_auto else clock.weather + 1,
			func(i: int) -> void: s.set_weather(i - 1))
		_add_row("Луна", ["по фазе"] + MOONS.map(func(m: Array) -> String: return m[0]),
			func() -> int:
				for i in MOONS.size():
					if is_equal_approx(sky.moon_override, MOONS[i][1]):
						return i + 1
				return 0,
			func(i: int) -> void: s.set_moon(-1.0 if i == 0 else MOONS[i - 1][1]))
		_add_row("Время суток", HOURS,
			func() -> int:
				var h: float = clock.time_of_day * 24.0
				var best := 0
				for i in HOUR_OF.size():
					if h >= HOUR_OF[i] - 0.5:
						best = i
				return best,
			func(i: int) -> void: s.set_hour(HOUR_OF[i]))
		_add_row("Час", range(24).map(func(h: int) -> String: return "%02d:00" % h),
			func() -> int: return int(clock.time_of_day * 24.0) % 24,
			func(i: int) -> void: s.set_hour(i))
		_add_row("Ход времени", Settings.TIME_BOOSTS.map(func(v: float) -> String: return "стоит" if v == 0.0 else ("обычный" if v == 1.0 else "×%d" % int(v))),
			func() -> int: return Settings.TIME_BOOSTS.find(s.time_boost),
			func(i: int) -> void: s.set_time_boost(Settings.TIME_BOOSTS[i]))
		_add_row("Скорость игрока", Settings.PLAYER_SPEEDS.map(func(v: float) -> String: return "×%d" % int(v)),
			func() -> int: return Settings.PLAYER_SPEEDS.find(s.player_speed),
			func(i: int) -> void: s.set_player_speed(Settings.PLAYER_SPEEDS[i]))
		_add_row("Прыжки", ["с земли", "и в воздухе"],
			func() -> int: return int(s.air_jumps),
			func(i: int) -> void: s.set_air_jumps(i == 1))
		_add_row("Стройка", ["из сумки", "бесплатно"],
			func() -> int: return int(s.free_build),
			func(i: int) -> void: s.set_free_build(i == 1))
		# Not a switch: either arrow puts the tools into the bag.
		_add_row("Инструменты", ["выдать", "выдать"],
			func() -> int: return 0,
			func(_i: int) -> void: s.give_tools())
		_add_row("Износ инструментов", ["выкл", "вкл"],
			func() -> int: return int(s.tool_wear),
			func(i: int) -> void: s.set_tool_wear(i == 1))
		_add_row("Карта теней", Settings.SHADOW_MAPS.map(func(v: int) -> String: return str(v)),
			func() -> int: return s.shadow_map,
			func(i: int) -> void: s.set_shadow_map(i))
		_add_row("Статистика", ["выкл", "вкл"],
			func() -> int: return int(game.hud.perf.visible),
			func(i: int) -> void:
				if game.hud.perf.visible != (i == 1):
					game.hud.toggle_stats())
	visible = true
	refresh()
	_set_focus(0)
	_scroll.scroll_vertical = 0
	if _screen != Vector2.ZERO:
		fit(_screen)


## The version of this build and its recent changes, newest first:
## {"version", "commit", "date", "changes": [{"pr", "date", "text"}]}.
static func build_info() -> Dictionary:
	var info := {"version": "dev", "commit": "", "date": "", "changes": []}
	if FileAccess.file_exists(BUILD_INFO):
		var data = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO))
		if data is Dictionary:
			info.merge(data, true)
	return info


## "Назад": the changes go back to the playtest page, the other pages close.
func _go_back() -> void:
	if page == "changes":
		open("test")
	else:
		close()


func close() -> void:
	visible = false
	page = ""
	closed.emit()


## Updates every value label from the game state (values change by hotkeys too).
func refresh() -> void:
	for r in _rows:
		var i: int = r.get.call()
		r.label.text = r.values[clampi(i, 0, r.values.size() - 1)]
	reset_size()


## Sizes the window for a screen `screen` UI pixels large and centres it.
func fit(screen: Vector2) -> void:
	_screen = screen
	_list.reset_size()
	var rows_h := _list.size.y
	var rest := _title.size.y + _back.size.y + 2 * 6 + 2 * 6
	if _version.visible:
		rest += _version.size.y + 6
	_scroll.custom_minimum_size = Vector2(_list.size.x, minf(rows_h, screen.y - 2 * 8 - rest))
	reset_size()
	position = ((screen - size) * 0.5).floor()


## One wrapped paragraph a change, as wide as the rows of the other pages.
func _add_changes(changes: Array) -> void:
	if changes.is_empty():
		_list.add_child(_paragraph("Список изменений появится в сборке с сайта.", UiStyle.MUTED))
	for c in changes:
		_list.add_child(_paragraph("#%d · %s" % [int(c.pr), c.date], UiStyle.ACCENT))
		_list.add_child(_paragraph(str(c.text), UiStyle.INK))


func _paragraph(text: String, color: Color) -> Label:
	var l := UiStyle.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(NAME_WIDTH + VALUE_WIDTH + 2 * ARROW + 3 * 2, 0)
	return l


func _add_row(name: String, values: Array, getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_list.add_child(row)
	var label := UiStyle.label(name)
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var index := _rows.size()
	var left := _arrow(row, "prev", index, -1)
	var value := UiStyle.label()
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	var right := _arrow(row, "next", index, 1)
	_rows.append({"name": label, "values": values, "get": getter, "set": setter, "label": value,
		"left": left, "right": right})


func _arrow(parent: Node, icon: String, row: int, dir: int) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW, ARROW)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func() -> void:
		_set_focus(row)
		_step(row, dir))
	parent.add_child(b)
	return b


## Picks the next (`dir` = 1) or the previous value of row `i`, wrapping around.
func _step(i: int, dir: int) -> void:
	var r: Dictionary = _rows[i]
	var n: int = r.values.size()
	var cur: int = clampi(r.get.call(), 0, n - 1)
	r.set.call(posmod(cur + dir, n))
	refresh()


func _set_focus(i: int) -> void:
	if _rows.is_empty():
		return
	_focus = posmod(i, _rows.size())
	for j in _rows.size():
		_rows[j].name.add_theme_color_override("font_color", UiStyle.ACCENT if j == _focus else UiStyle.INK)


## Arrows and Enter on the keyboard, Escape closes.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed):
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if not event.echo:
				_go_back()
		KEY_UP, KEY_W, KEY_DOWN, KEY_S when _rows.is_empty():
			var down: bool = event.physical_keycode in [KEY_DOWN, KEY_S]
			_scroll.scroll_vertical += 24 if down else -24
		KEY_UP, KEY_W:
			_set_focus(_focus - 1)
			_scroll.ensure_control_visible(_rows[_focus].name)
		KEY_DOWN, KEY_S:
			_set_focus(_focus + 1)
			_scroll.ensure_control_visible(_rows[_focus].name)
		KEY_LEFT, KEY_A when not _rows.is_empty():
			_step(_focus, -1)
		KEY_RIGHT, KEY_D, KEY_ENTER, KEY_SPACE when not _rows.is_empty():
			_step(_focus, 1)
		_:
			return
	get_viewport().set_input_as_handled()


## Screen rectangles of the arrows, for the F3 debug line and the browser smoke test.
func debug_rects() -> Dictionary:
	var out := {}
	for r in _rows:
		var b: Button = r.right
		out[r.name.text] = b.get_global_rect() if b.is_visible_in_tree() else Rect2()
	return out
