extends PanelContainer
## The settings window and the playtest window, opened from the pause menu. Both are
## lists of rows "name ‹ value ›": a tap or a click on an arrow picks the next value,
## which suits a thumb as well as a mouse; the keyboard moves between rows with the
## arrows and changes a value with Left / Right or Enter. Values come from and go to
## Settings (plan/design/ui.md, section 6). Both pages are split into sections by tabs
## under the title (see PAGES): the settings into Игра, Графика, and Музыка, Звук dimmed
## until the game has sound (Графика starts with the quality preset, any change by hand
## makes it «своё»); the playtest page into Мир, Игрок, Маркеры, Отладка, with buttons
## for what is done once (into the test world, the tools into the bag, to a marker set
## on the map: Маркеры lists them with their colour and column). The playtest page also
## shows the version of the build and opens the list of recent changes ("changes" page,
## its legend of kinds above the buttons), no taller than the settings and scrolling.
## All the pages are as wide: one or two columns of rows (see fit) and room for the bar.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const Settings := preload("res://src/client/settings.gd")
const Markers := preload("res://src/client/game/markers.gd")

## Room for a name of 18 letters of the 8 px font; a longer one wraps onto a second line.
const NAME_WIDTH := 150
const VALUE_WIDTH := 100
const ARROW := 32
## The kinds of change in «Что нового» and their names (tools/build_info.py KINDS).
const CHANGE_KINDS := {
	"new": "новое", "better": "улучшено", "fix": "исправлено", "fast": "быстрее", "inside": "внутри",
}
## A row across, and the room between two columns of rows (see fit).
const ROW_WIDTH := NAME_WIDTH + VALUE_WIDTH + 2 * ARROW + 3 * 2
const COLUMN_GAP := 16
## Room kept for the scroll bar on every page, so all of them are as wide.
const BAR_ROOM := UiStyle.SCROLL_BAR + 4
const HOURS := ["ночь", "утро", "день", "вечер"]
const HOUR_OF := [0.0, 7.0, 12.0, 19.0]
## Moonlight picks of the playtest page: name and light (see Settings.set_moon).
const MOONS := [["новолуние", 0.0], ["серп", 0.4], ["полнолуние", 1.0]]
## The sections of the pages with tabs: key and tab name.
const PAGES := {
	"settings": [["game", "Игра"], ["graphics", "Графика"], ["music", "Музыка"], ["sound", "Звук"]],
	"test": [["world", "Мир"], ["player", "Игрок"], ["marks", "Маркеры"], ["debug", "Отладка"]],
}
## Sections with nothing to set yet: their tabs are dimmed, «скоро».
const SOON := ["music", "sound"]
## Sections as long as there is something in them: no taller page for them, they scroll.
const LISTS := ["marks"]
## The room between the quality preset and the settings by hand, or the rows and a
## button.
const GAP := 8
const TAB_HEIGHT := 28
## Written by tools/build_info.py in CI; a local run has none and shows "dev".
const BUILD_INFO := "res://build_info.json"

signal closed

var game
## "settings", "test" or "changes": which page is shown.
var page := ""
## The section shown on each page with tabs (see PAGES); kept between openings.
var sections := {"settings": "game", "test": "world"}
var _title: Label
var _tabs: HBoxContainer
var _tab_buttons := {}
## The page the tabs were made for.
var _tabs_page := ""
var _version: Label
var _changes: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
## The kinds of change and their icons, under the changes.
var _legend: PanelContainer
var _legend_grid: GridContainer
## Rows of the page: {"key", "values": Array of String, "get": Callable, "set": Callable, "label": Label}
var _rows := []
var _focus := -1
var _back: Button
var _screen := Vector2.ZERO
## Rows side by side: 2 on a wide screen too low for them in one column (see fit).
var _columns := 1


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
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_tabs)
	# The rows scroll when the window is taller than a small screen with a big interface.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_legend = PanelContainer.new()
	_legend.add_theme_stylebox_override("panel", UiStyle.field())
	box.add_child(_legend)
	_legend_grid = GridContainer.new()
	_legend_grid.add_theme_constant_override("h_separation", 12)
	_legend_grid.add_theme_constant_override("v_separation", 4)
	_legend_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_legend.add_child(_legend_grid)
	for k in CHANGE_KINDS:
		_legend_grid.add_child(_change_line(k, CHANGE_KINDS[k], UiStyle.MUTED, 0))
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
	_fill()


## Shows section `key` of the page shown (see PAGES).
func show_section(key: String) -> void:
	sections[page] = key
	_fill()


## The tabs of page `which` (see PAGES), made when the page changes.
func _make_tabs(which: String) -> void:
	if _tabs_page == which:
		return
	_tabs_page = which
	for b in _tabs.get_children():
		_tabs.remove_child(b)
		b.queue_free()
	_tab_buttons.clear()
	for sec in PAGES.get(which, []):
		var key: String = sec[0]
		var b := TabRow.small_button(sec[1], show_section.bind(key))
		b.custom_minimum_size.y = TAB_HEIGHT
		b.disabled = key in SOON
		b.tooltip_text = "Скоро" if b.disabled else ""
		_tabs.add_child(b)
		_tab_buttons[key] = b


## Builds the rows of the page (and section) shown and shows them.
func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	_focus = -1
	var which := page
	var info := build_info()
	_version.text = "Версия %s · %s · %s" % [info.version, info.commit, info.date]
	_version.visible = which != "settings"
	_changes.visible = which == "test"
	_tabs.visible = PAGES.has(which)
	_legend.visible = which == "changes" and not info.changes.is_empty()
	_make_tabs(which)
	if which == "changes":
		_title.text = "Что нового"
		_add_changes(info.changes)
	else:
		_title.text = "Настройки" if which == "settings" else "Тестирование"
		for k in _tab_buttons:
			TabRow.light(_tab_buttons[k], k == sections[which])
		for r in _section_rows(sections[which]):
			if r == null:
				var gap := Control.new()
				gap.custom_minimum_size.y = GAP
				_list.add_child(gap)
			elif r is Dictionary and r.has("marker"):
				_add_marker(r.marker)
			elif r is Dictionary and r.has("note"):
				_grid().add_child(_note(r.note))
			elif r is Dictionary:
				_add_action(r.action, r.do)
			else:
				_add_row(r[0], r[1], r[2], r[3], r[4] if r.size() > 4 else "")
	visible = true
	refresh()
	_set_focus(0)
	_scroll.scroll_vertical = 0
	if _screen != Vector2.ZERO:
		fit(_screen)


## The rows of section `key` (see PAGES): [name, values, getter, setter] each, and
## [..., the value shown when the getter gives -1] for the quality preset; null is a
## gap; {"action": text, "do": Callable} a button that does something once;
## {"marker": index} a marker with its button that takes the player there; {"note":
## text} a line of text.
func _section_rows(key: String) -> Array:
	var s = game.settings
	var sky = game.sky
	var clock = game.clock
	match key:
		"world":
			return [
				["Сезон", clock.SEASONS,
					func() -> int: return clock.season,
					func(i: int) -> void: s.set_season(i)],
				["Погода", ["сама"] + clock.WEATHERS.map(func(w: Dictionary) -> String: return w.name.to_lower()),
					func() -> int: return 0 if clock.weather_auto else clock.weather + 1,
					func(i: int) -> void: s.set_weather(i - 1)],
				["Луна", ["по фазе"] + MOONS.map(func(m: Array) -> String: return m[0]),
					func() -> int:
						for i in MOONS.size():
							if is_equal_approx(sky.moon_override, MOONS[i][1]):
								return i + 1
						return 0,
					func(i: int) -> void: s.set_moon(-1.0 if i == 0 else MOONS[i - 1][1])],
				["Время суток", HOURS,
					func() -> int:
						var h: float = clock.time_of_day * 24.0
						var best := 0
						for i in HOUR_OF.size():
							if h >= HOUR_OF[i] - 0.5:
								best = i
						return best,
					func(i: int) -> void: s.set_hour(HOUR_OF[i])],
				["Час", range(24).map(func(h: int) -> String: return "%02d:00" % h),
					func() -> int: return int(clock.time_of_day * 24.0) % 24,
					func(i: int) -> void: s.set_hour(i)],
				["Ход времени", Settings.TIME_BOOSTS.map(func(v: float) -> String: return "стоит" if v == 0.0 else ("обычный" if v == 1.0 else "×%d" % int(v))),
					func() -> int: return Settings.TIME_BOOSTS.find(s.time_boost),
					func(i: int) -> void: s.set_time_boost(Settings.TIME_BOOSTS[i])],
				null,
				{"action": "Вернуться в свой мир" if s.in_test_world() else "Перейти в тестовый мир",
					"do": func() -> void: s.switch_test_world()},
			]
		"player":
			return [
				["Скорость игрока", Settings.PLAYER_SPEEDS.map(func(v: float) -> String: return "×%d" % int(v)),
					func() -> int: return Settings.PLAYER_SPEEDS.find(s.player_speed),
					func(i: int) -> void: s.set_player_speed(Settings.PLAYER_SPEEDS[i])],
				["Прыжки", ["с земли", "и в воздухе"],
					func() -> int: return int(s.air_jumps),
					func(i: int) -> void: s.set_air_jumps(i == 1)],
				["Стройка", ["из сумки", "бесплатно"],
					func() -> int: return int(s.free_build),
					func(i: int) -> void: s.set_free_build(i == 1)],
				["Износ инструментов", ["выкл", "вкл"],
					func() -> int: return int(s.tool_wear),
					func(i: int) -> void: s.set_tool_wear(i == 1)],
				null,
				{"action": "Выдать инструменты", "do": func() -> void: s.give_tools()},
			]
		"marks":
			var marks := []
			if game.markers != null:
				for i in game.markers.list.size():
					marks.append({"marker": i})
			if marks.is_empty():
				marks.append({"note": "Маркеров нет: поставьте их на карте (M)."})
			return marks
		"debug":
			return [
				["Карта теней", Settings.SHADOW_MAPS.map(func(v: int) -> String: return str(v)),
					func() -> int: return s.shadow_map,
					func(i: int) -> void: s.set_shadow_map(i)],
				["Статистика", ["выкл", "вкл"],
					func() -> int: return int(game.hud.perf.visible),
					func(i: int) -> void:
						if game.hud.perf.visible != (i == 1):
							game.hud.toggle_stats()],
				["Отладочные подсказки", ["выкл", "вкл"],
					func() -> int: return int(s.debug_tips),
					func(i: int) -> void: s.debug_tips = i == 1],
			]
		"game":
			var rows := [
				["Длина суток", Settings.TIME_SPEEDS.map(func(v: float) -> String: return "%d мин" % roundi(clock.DAY_LENGTH / v / 60.0)),
					func() -> int: return s.values.time_speed,
					func(i: int) -> void: s.set_value("time_speed", i)],
				["Автоподбор", ["выкл", "вкл"],
					func() -> int: return int(s.values.auto_pickup),
					func(i: int) -> void: s.set_value("auto_pickup", i == 1)],
				["Интерфейс", ["обычный", "крупнее", "крупный"],
					func() -> int: return s.values.ui_scale,
					func(i: int) -> void: s.set_value("ui_scale", i)],
			]
			if not game.controls.touch:
				rows.append(["Подсказка клавиш", ["выкл", "вкл"],
					func() -> int: return int(s.values.show_help),
					func(i: int) -> void: s.set_value("show_help", i == 1)])
			return rows
		"graphics":
			# From the lightest to draw to the heaviest; mixed (3) came after real (2).
			var fire_order := [0, 1, 3, 2]
			return [
				["Качество", ["низкое", "среднее", "высокое"],
					func() -> int: return s.quality(),
					func(i: int) -> void: s.set_quality(i), "своё"],
				null,
				["Масштаб", ["обычный", "крупный", "огромный"],
					func() -> int: return s.values.pixel_size,
					func(i: int) -> void: s.set_value("pixel_size", i)],
				["Тени", ["выкл", "вкл"],
					func() -> int: return int(s.values.shadows),
					func(i: int) -> void: s.set_value("shadows", i == 1)],
				["Тени от огня", ["выкл", "нарисованные", "смешанные", "настоящие"],
					func() -> int: return fire_order.find(s.values.fire_shadows),
					func(i: int) -> void: s.set_value("fire_shadows", fire_order[i])],
				["Эффекты", ["выкл", "вкл"],
					func() -> int: return int(s.values.effects),
					func(i: int) -> void: s.set_value("effects", i == 1)],
				["Солнечные лучи", ["выкл", "вкл"],
					func() -> int: return int(s.values.sun_rays),
					func(i: int) -> void: s.set_value("sun_rays", i == 1)],
				["Утренняя дымка", ["выкл", "вкл"],
					func() -> int: return int(s.values.mist),
					func(i: int) -> void: s.set_value("mist", i == 1)],
				["Предел FPS", Settings.FPS_LIMITS.map(func(v: int) -> String: return "нет" if v == 0 else str(v)),
					func() -> int: return s.values.fps_limit,
					func(i: int) -> void: s.set_value("fps_limit", i)],
			]
	return []


## How tall `rows` (see _section_rows) stand in the list in `columns` columns: the rows
## between gaps fill a grid.
static func _height(rows: Array, columns: int) -> int:
	var h := 0
	var children := 0
	var n := 0
	for r in rows + [null]:
		if r != null:
			n += 1
			continue
		if n > 0:
			var k := ceili(float(n) / columns)
			h += k * ARROW + (k - 1) * 4
			children += 1
			n = 0
	for r in rows:
		if r == null:
			h += GAP
			children += 1
	return h + maxi(0, children - 1) * 4


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
		r.label.text = r.other if i < 0 and r.other != "" else r.values[clampi(i, 0, r.values.size() - 1)]
	reset_size()


## Sizes the window for a screen `screen` UI pixels large and centres it. The settings
## page puts its rows in two columns on a wide screen too low for them in one; the
## playtest and changes pages are no taller than the settings and scroll, a bar at the
## side.
func fit(screen: Vector2) -> void:
	_screen = screen
	var rest := _title.size.y + _back.size.y + 2 * 6 + 2 * 6
	# As on the settings page, whose tabs the changes page has not.
	var room := screen.y - 2 * 8 - rest - TAB_HEIGHT - 6
	# Every page takes the columns the settings need, so all are as wide.
	var n := 2 if _page_height("settings", 1) > room \
			and screen.x - 2 * 8 - 2 * UiStyle.PAD.x - BAR_ROOM >= 2 * ROW_WIDTH + COLUMN_GAP else 1
	if n != _columns and page == "changes":
		_columns = n
		_fill()
		return
	_set_columns(n)
	_legend_grid.columns = CHANGE_KINDS.size() if n > 1 else 3
	if _version.visible:
		room -= _version.size.y + 6
	if _legend.visible:
		room -= _legend.get_combined_minimum_size().y + 6
	if not _tabs.visible:
		room += TAB_HEIGHT + 6
	if page != "settings":
		room = minf(room, _page_height("settings", n))
	_list.reset_size()
	_scroll.custom_minimum_size = Vector2(content_width() + BAR_ROOM, minf(_list.size.y, room))
	reset_size()
	position = ((screen - size) * 0.5).floor()


## How wide the rows of every page stand: one or two columns.
func content_width() -> int:
	return _columns * ROW_WIDTH + (_columns - 1) * COLUMN_GAP


## Puts the rows in `n` columns; a page with tabs is as tall as its longest section, so
## the tabs do not move.
func _set_columns(n: int) -> void:
	_columns = n
	for c in _list.get_children():
		if c is GridContainer:
			c.columns = n
	_list.custom_minimum_size.y = _page_height(page, n)


## How tall the longest section of page `which` (see PAGES) stands in `n` columns.
func _page_height(which: String, n: int) -> int:
	var tallest := 0
	for sec in PAGES.get(which, []):
		if not sec[0] in LISTS:
			tallest = maxi(tallest, _height(_section_rows(sec[0]), n))
	return tallest


## One wrapped paragraph a change, as wide as the rows of the other pages.
func _add_changes(changes: Array) -> void:
	if changes.is_empty():
		_list.add_child(_paragraph("Список изменений появится в сборке с сайта.", UiStyle.MUTED))
		return
	var pr := -1
	for c in changes:
		if int(c.pr) != pr:
			pr = int(c.pr)
			_list.add_child(_paragraph("#%d · %s" % [pr, c.date], UiStyle.ACCENT))
		_list.add_child(_change_line(str(c.get("kind", "new")), str(c.text), UiStyle.INK, content_width()))


## A line of «Что нового» with the icon of its kind (CHANGE_KINDS) in front; `width` 0
## keeps it to its text.
func _change_line(kind: String, text: String, color: Color, width: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = UiStyle.icon("change_" + (kind if CHANGE_KINDS.has(kind) else "new"))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.custom_minimum_size = Vector2(8, UiStyle.FONT_SIZE)
	row.add_child(icon)
	var l := UiStyle.label(text, color)
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 8 - 6, 0)
	row.add_child(l)
	return row


func _paragraph(text: String, color: Color) -> Label:
	var l := UiStyle.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(content_width(), 0)
	return l


## A row "name ‹ value ›"; `other` is shown when `getter` gives -1 (none of `values`).
func _add_row(name: String, values: Array, getter: Callable, setter: Callable, other := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_grid().add_child(row)
	var label := UiStyle.label(name)
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		"left": left, "right": right, "other": other})


## A button as wide as a row that does `action` once (a way into the test world).
func _add_action(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	b.pressed.connect(action)
	_grid().add_child(b)


## A marker (game.markers, `i`) as a row: its colour, its name and column, and a
## button that takes the player there and back into the game.
func _add_marker(i: int) -> void:
	var m: Dictionary = game.markers.list[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	_grid().add_child(row)
	var swatch := ColorRect.new()
	swatch.color = UiStyle.DARK_INK
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Markers.color_of(m)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(10, 10)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(fill)
	row.add_child(swatch)
	var label := UiStyle.label("%s · X %d, Z %d" % [(Markers.COLORS[m.color][0] as String).capitalize(), m.cell.x, m.cell.y])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	var b := Button.new()
	b.text = "Туда"
	b.tooltip_text = "Телепорт к маркеру"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ARROW)
	var cell: Vector2i = m.cell
	b.pressed.connect(func() -> void:
		game.character.teleport(cell)
		close()
		if get_tree().paused:
			game.hud.toggle_menu())
	row.add_child(b)


## A line of muted text as wide as a row.
func _note(text: String) -> Label:
	var l := UiStyle.label(text, UiStyle.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## The grid the next row goes into (see fit): the last one, or a new one after a gap.
func _grid() -> GridContainer:
	var last: Node = _list.get_child(_list.get_child_count() - 1) if _list.get_child_count() > 0 else null
	if last is GridContainer:
		return last
	var grid := GridContainer.new()
	grid.columns = _columns
	# In the middle of the room kept for the scroll bar while it is hidden.
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", COLUMN_GAP)
	grid.add_theme_constant_override("v_separation", 4)
	_list.add_child(grid)
	return grid


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


## Picks the next (`dir` = 1) or the previous value of row `i`, wrapping around; from
## none of them (-1, «своё») the first or the last.
func _step(i: int, dir: int) -> void:
	var r: Dictionary = _rows[i]
	var n: int = r.values.size()
	var cur: int = r.get.call()
	if cur < 0:
		r.set.call(0 if dir > 0 else n - 1)
	else:
		r.set.call(posmod(mini(cur, n - 1) + dir, n))
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
