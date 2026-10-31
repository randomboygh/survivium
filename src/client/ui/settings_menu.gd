extends PanelContainer
## The settings window and the playtest window, opened from the pause menu. Both are
## lists of rows "name ‹ value ›": a tap or a click on an arrow picks the next value,
## which suits a thumb as well as a mouse; the keyboard moves between rows with the
## arrows and changes a value with Left / Right or Enter. Values come from and go to
## Settings (plan/design/ui.md, section 6). Both pages are split into sections by tabs
## under the title (see PAGES): the settings into Игра, Интерфейс (sizes, the minimap,
## which HUD buttons show, the full screen, the key hints), Графика, Музыка and Звук
## (their volumes, see Sound; Графика starts with the quality preset, any change by
## hand makes it «своё»); the playtest page into Мир, Игрок, Маркеры, Отладка, with buttons
## for what is done once (into the test world, the tools into the bag, to a marker set
## on the map: Маркеры lists them with their colour and column). The playtest page also
## shows the version of the build and opens the list of recent changes ("changes" page,
## its legend of kinds above the buttons), no taller than the settings and scrolling,
## and from «Отладка» the log of freezes ("freezes" page, FreezeLog): a tab for each
## band of their length, the worst first after all of them; and what a playtest report
## needs to be played again ("report" page: the world, the place, the time, the weather,
## the light, the camera, the settings, the device), to copy or share.
## All the pages are as wide: one or two columns of rows (see fit) and room for the bar.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const Settings := preload("res://src/client/settings.gd")
const Markers := preload("res://src/client/game/markers.gd")
const Sound := preload("res://src/client/audio/sound.gd")
const Vibration := preload("res://src/client/ui/vibration.gd")
const Content := preload("res://src/shared/content/content.gd")

## Room for a name of 18 letters of the 8 px font; a longer one wraps onto a second line.
const NAME_WIDTH := 150
## Room for the longest value («песчаная буря»); anything longer is cut, so a value
## never widens its row and moves the window.
const VALUE_WIDTH := 112
const ARROW := 32
## How long a button that asks first (see _confirm) waits for the second tap, in seconds.
const CONFIRM_WAIT := 4.0
## The kinds of change in «Что нового» and their names (tools/build_info.py KINDS).
const CHANGE_KINDS := {
	"new": "новое", "better": "улучшено", "fix": "исправлено", "fast": "оптимизировано", "inside": "ядро",
}
## A row across, and the room between two columns of rows (see fit).
const ROW_WIDTH := NAME_WIDTH + VALUE_WIDTH + 2 * ARROW + 3 * 2
const COLUMN_GAP := 16
## Room kept for the scroll bar on every page, so all of them are as wide: the bar and
## a gap on each side of the rows, so the bar never touches the arrows.
const BAR_GAP := 6
const BAR_ROOM := UiStyle.SCROLL_BAR + 2 * BAR_GAP
const HOURS := ["ночь", "утро", "день", "вечер"]
const HOUR_OF := [0.0, 7.0, 12.0, 19.0]
## Moonlight picks of the playtest page: name and light (see Settings.set_moon).
const MOONS := [["новолуние", 0.0], ["серп", 0.4], ["полнолуние", 1.0]]
## The sections of the pages with tabs: key and tab name.
const PAGES := {
	"settings": [["game", "Игра"], ["interface", "Интерфейс"], ["graphics", "Графика"], ["music", "Музыка"], ["sound", "Звук"]],
	"test": [["world", "Мир"], ["player", "Игрок"], ["marks", "Маркеры"], ["debug", "Отладка"]],
	"freezes": [["all", "Все"], ["critical", "от 200"], ["big", "100–200"], ["small", "50–100"]],
}
## Sections with nothing to set yet: their tabs are dimmed, «скоро».
const SOON := []
## Sections as long as there is something in them: no taller page for them, they scroll.
const LISTS := ["marks", "all", "critical", "big", "small"]
## The room between the quality preset and the settings by hand, or the rows and a
## button.
const GAP := 8
const TAB_HEIGHT := 28
## The steps of the interface and the touch controls size.
const SIZES := ["очень мелкий", "мелкий", "обычный", "крупнее", "крупный"]
## The minimap sizes (Minimap.SIDES).
const MAP_SIZES := ["маленькая", "обычная", "большая"]
## Written by tools/build_info.py in CI; a local run has none and shows "dev".
const BUILD_INFO := "res://build_info.json"

signal closed

var game
## "settings", "test", "changes", "freezes" or "report": which page is shown.
var page := ""
## The section shown on each page with tabs (see PAGES); kept between openings.
var sections := {"settings": "game", "test": "world", "freezes": "all"}
var _title: Label
var _tabs: HBoxContainer
var _tab_buttons := {}
## The page the tabs were made for.
var _tabs_page := ""
var _version: Label
var _changes: Button
## «Очистить журнал» beside «Назад» on the freezes' page (two taps, see _confirm).
var _clear: Button
## «Скопировать» and «Поделиться» in the same row on the freezes' and the report page:
## the text of the page shown (_shown_text).
var _copy: Button
var _share: Button
var _shown_text := ""
var _scroll: ScrollContainer
var _list: VBoxContainer
## The kinds of change and their icons, under the changes.
var _legend: PanelContainer
var _legend_grid: GridContainer
## Rows of the page: {"key", "values": Array of String, "get": Callable, "set": Callable, "label": Label}
var _rows := []
var _focus := -1
var _back: Button
## «По умолчанию» on the settings page: the first tap asks, the second puts every
## setting back as it comes (Settings.reset).
var _defaults: Button
var _asking_reset := false
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
	# The rows keep their place whether the bar shows or not: a little room on the left,
	# the bar's on the right.
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", BAR_GAP)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(inset)
	inset.add_child(_list)
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
	_defaults = Button.new()
	_defaults.focus_mode = Control.FOCUS_NONE
	_defaults.custom_minimum_size = Vector2(0, 32)
	_defaults.pressed.connect(_reset_pressed)
	box.add_child(_defaults)
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
	_copy = Button.new()
	_copy.text = "Скопировать"
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.custom_minimum_size = Vector2(0, 32)
	_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy.pressed.connect(_copy_shown)
	buttons.add_child(_copy)
	_share = Button.new()
	_share.text = "Поделиться"
	_share.focus_mode = Control.FOCUS_NONE
	_share.custom_minimum_size = Vector2(0, 32)
	_share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_share.pressed.connect(_share_shown)
	buttons.add_child(_share)
	_clear = Button.new()
	_clear.text = "Очистить журнал"
	_clear.focus_mode = Control.FOCUS_NONE
	_clear.custom_minimum_size = Vector2(0, 32)
	_clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear.pressed.connect(_confirm.bind(_clear, _clear.text, _clear_freezes))
	buttons.add_child(_clear)
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
		if which == "freezes":
			# Their counts grow: the tabs share the window's width and never widen it.
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
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
	_clear.visible = which == "freezes"
	_copy.visible = which in ["freezes", "report"]
	_copy.text = "Скопировать"
	UiStyle.succeed(_copy, false)
	# The phone's sharing, where the browser has it.
	_share.visible = which == "report" and OS.has_feature("web") \
			and int(JavaScriptBridge.eval("typeof navigator.share === 'function' ? 1 : 0", true)) == 1
	_defaults.visible = which == "settings"
	_ask_reset(false)
	_tabs.visible = PAGES.has(which)
	_legend.visible = which == "changes" and not info.changes.is_empty()
	_make_tabs(which)
	if which == "changes":
		_title.text = "Что нового"
		_add_changes(info.changes)
	elif which == "freezes":
		_title.text = "Журнал фризов"
		_add_freezes(sections[which])
	elif which == "report":
		_title.text = "Данные для теста"
		_add_report()
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
			elif r is Dictionary and r.has("place"):
				_add_place(r.color, r.place, r.cell, r.tip)
			elif r is Dictionary and r.has("note"):
				_grid().add_child(_note(r.note))
			elif r is Dictionary:
				_add_action(r.action, r.do, r.get("confirm", false))
			else:
				_add_row(r[0], r[1], r[2], r[3], r[4] if r.size() > 4 else "", r[5] if r.size() > 5 else Callable())
	visible = true
	refresh()
	_set_focus(0)
	_scroll.scroll_vertical = 0
	if _screen != Vector2.ZERO:
		fit(_screen)


## The rows of section `key` (see PAGES): [name, values, getter, setter] each, and
## [..., the value shown when the getter gives -1] for the quality preset, [..., "",
## a Callable telling whether the row works now] for a row that is dimmed and does
## nothing while another setting overrides it; null is a
## gap; {"action": text, "do": Callable} a button that does something once (with
## "confirm": true only on a second tap, see _add_action);
## {"marker": index} a marker with its button that takes the player there; {"place":
## name, "cell", "color", "tip"} the same for another place; {"note": text} a line of text.
func _section_rows(key: String) -> Array:
	var s = game.settings
	var sky = game.sky
	var clock = game.clock
	# What the clock decides by itself while it follows the device's time or calendar.
	var game_time := func() -> bool: return not s.values.real_time
	var game_season := func() -> bool: return not s.values.real_season
	var game_weather := func() -> bool: return not s.values.real_weather
	match key:
		"world":
			return [
				["Сезон", clock.SEASONS,
					func() -> int: return clock.season,
					func(i: int) -> void: s.set_season(i), "", game_season],
				["Погода", ["сама"] + clock.WEATHERS.map(func(w: Dictionary) -> String: return w.name.to_lower()),
					func() -> int: return 0 if clock.weather_auto else clock.weather + 1,
					func(i: int) -> void: s.set_weather(i - 1), "", game_weather],
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
					func(i: int) -> void: s.set_hour(HOUR_OF[i]), "", game_time],
				["Час", range(24).map(func(h: int) -> String: return "%02d:00" % h),
					func() -> int: return int(clock.time_of_day * 24.0) % 24,
					func(i: int) -> void: s.set_hour(i), "", game_time],
				["Ход времени", Settings.TIME_BOOSTS.map(func(v: float) -> String: return "стоит" if v == 0.0 else ("обычный" if v == 1.0 else "×%d" % int(v))),
					func() -> int: return Settings.TIME_BOOSTS.find(s.time_boost),
					func(i: int) -> void: s.set_time_boost(Settings.TIME_BOOSTS[i]), "", game_time],
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
				["Перегруз", ["вкл", "выкл"],
					func() -> int: return int(s.no_overload),
					func(i: int) -> void: s.set_no_overload(i == 1)],
				["Изготовление", ["по времени", "сразу"],
					func() -> int: return int(s.instant_craft),
					func(i: int) -> void: s.set_instant_craft(i == 1)],
				["Голод", ["вкл", "выкл"],
					func() -> int: return int(s.no_hunger),
					func(i: int) -> void: s.set_no_hunger(i == 1)],
				["Возрождение", ["у костра", "и где упали"],
					func() -> int: return int(s.revive_at_death),
					func(i: int) -> void: s.revive_at_death = i == 1],
				null,
				{"action": "Выдать инструменты", "do": func() -> void: s.give_tools()},
				{"action": "К месту последней смерти", "do": func() -> void: s.go_to_death()},
			]
		"marks":
			var marks := []
			for p: Array in game.character.respawn_points():
				var at: Vector3 = p[1] / game.character.CELL
				marks.append({"place": p[0], "cell": Vector2i(floori(at.x), floori(at.z)),
					"color": UiStyle.INK, "tip": "Телепорт к точке возрождения"})
			if game.markers != null:
				for i in game.markers.list.size():
					marks.append({"marker": i})
			if game.markers == null or game.markers.list.is_empty():
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
				["Обзор уровней", ["±%d" % game.chunks.VIEW_REACH, "все"],
					func() -> int: return int(s.free_view),
					func(i: int) -> void: s.free_view = i == 1],
				null,
				{"action": "Разобрать вызовы отрисовки", "do": func() -> void:
					close()
					if get_tree().paused:
						game.hud.toggle_menu()
					game.draw_census.start()},
				{"action": "Журнал фризов", "do": func() -> void: open("freezes")},
				{"action": "Данные для теста", "do": func() -> void: open("report")},
				{"action": "Перечитать данные модов", "do": func() -> void: s.reload_mods()},
				null,
				{"action": "Очистить все данные", "do": func() -> void: s.wipe_all(), "confirm": true},
			]
		"game":
			return [
				["Длина суток", Settings.TIME_SPEEDS.map(func(v: float) -> String: return "%d мин" % roundi(clock.DAY_LENGTH / v / 60.0)),
					func() -> int: return s.values.time_speed,
					func(i: int) -> void: s.set_value("time_speed", i), "", game_time],
				["Время суток", ["игровое", "как в жизни"],
					func() -> int: return int(s.values.real_time),
					func(i: int) -> void: s.set_value("real_time", i == 1)],
				["Сезон", ["игровой", "как в жизни"],
					func() -> int: return int(s.values.real_season),
					func(i: int) -> void: s.set_value("real_season", i == 1)],
				["Погода", ["игровая", "как в жизни"],
					func() -> int: return int(s.values.real_weather),
					func(i: int) -> void: s.set_value("real_weather", i == 1)],
				["Автоподбор", ["всё", "что есть", "еду", "ничего"],
					func() -> int: return s.values.pickup,
					func(i: int) -> void: s.set_value("pickup", i)],
				["Сверх груза", ["не брать", "брать"],
					func() -> int: return int(s.values.pickup_heavy),
					func(i: int) -> void: s.set_value("pickup_heavy", i == 1)],
				["Тряска экрана", ["выкл", "вкл"],
					func() -> int: return int(s.values.shake),
					func(i: int) -> void: s.set_value("shake", i == 1)],
				# Faded and «нет» where the browser or device cannot buzz (a computer,
				# Safari, some phones' own browsers).
				["Вибрация", ["выкл", "вкл"],
					func() -> int: return int(s.values.vibrate) if Vibration.supported() else -1,
					func(i: int) -> void: s.set_value("vibrate", i == 1), "нет", Vibration.supported],
			]
		"interface":
			var rows := [
				["Размер интерфейса", SIZES,
					func() -> int: return s.values.ui_size,
					func(i: int) -> void: s.set_value("ui_size", i)],
			]
			if game.controls.touch:
				rows.append(["Размер управления", SIZES,
					func() -> int: return s.values.control_size,
					func(i: int) -> void: s.set_value("control_size", i)])
			rows.append_array([
				["Миникарта", MAP_SIZES,
					func() -> int: return s.values.minimap_size,
					func(i: int) -> void: s.set_value("minimap_size", i)],
				["Уровень и срез", ["выкл", "вкл"],
					func() -> int: return int(s.values.level_buttons),
					func(i: int) -> void: s.set_value("level_buttons", i == 1)],
				["Кнопки камеры", ["выкл", "вкл"],
					func() -> int: return int(s.values.camera_buttons),
					func(i: int) -> void: s.set_value("camera_buttons", i == 1)],
			])
			if s.can_fullscreen():
				rows.append(["Полный экран", ["выкл", "вкл"],
					func() -> int: return int(s.fullscreen()),
					func(i: int) -> void: s.set_fullscreen(i == 1)])
			if not game.controls.touch:
				rows.append(["Подсказка клавиш", ["выкл", "вкл"],
					func() -> int: return int(s.values.show_help),
					func(i: int) -> void: s.set_value("show_help", i == 1)])
			return rows
		"music":
			return [
				_volume_row("Громкость", "music_volume"),
				["Как часто", ["редко", "иногда", "часто"],
					func() -> int: return s.values.music_often,
					func(i: int) -> void: s.set_value("music_often", i)],
			]
		"sound":
			return [
				_volume_row("Громкость", "sound_volume"),
				null,
				_volume_row("Природа", "nature_volume"),
				_volume_row("Интерфейс", "ui_volume"),
			]
		"graphics":
			# From the lightest to draw to the heaviest; mixed (3) came after real (2).
			var fire_order := [0, 1, 3, 2]
			return [
				["Качество", ["низкое", "среднее", "высокое"],
					func() -> int: return s.quality(),
					func(i: int) -> void: s.set_quality(i), "своё"],
				null,
				["Масштаб", SIZES,
					func() -> int: return s.values.pixel_scale,
					func(i: int) -> void: s.set_value("pixel_scale", i)],
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
				["Туман", ["простой", "по земле"],
					func() -> int: return int(s.values.fog),
					func(i: int) -> void: s.set_value("fog", i == 1)],
				["Предел FPS", Settings.FPS_LIMITS.map(func(v: int) -> String: return "нет" if v == 0 else str(v)),
					func() -> int: return s.values.fps_limit,
					func(i: int) -> void: s.set_value("fps_limit", i)],
			]
	return []


## A row of the volume setting `key`, «выкл» to «100%» in Sound.STEPS steps.
func _volume_row(name: String, key: String) -> Array:
	var s = game.settings
	var steps := ["выкл"]
	for i in range(1, Sound.STEPS + 1):
		steps.append("%d%%" % (100 * i / Sound.STEPS))
	return [name, steps,
		func() -> int: return s.values[key],
		func(i: int) -> void: s.set_value(key, i)]


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
## The first tap on «По умолчанию» asks, the second resets.
func _reset_pressed() -> void:
	if not _asking_reset:
		_ask_reset(true)
		return
	game.settings.reset()
	_fill()


func _ask_reset(on: bool) -> void:
	_asking_reset = on
	_defaults.text = "По умолчанию"
	UiStyle.arm(_defaults, on)


func _go_back() -> void:
	if page in ["changes", "freezes", "report"]:
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
		var on := _works(r)
		r.left.disabled = not on
		r.right.disabled = not on
		r.row.modulate.a = 1.0 if on else 0.4
	reset_size()


func _works(r: Dictionary) -> bool:
	return not r.works.is_valid() or r.works.call()


## Sizes the window for a screen `screen` UI pixels large and centres it. The settings
## page puts its rows in two columns on a wide screen too low for them in one; the
## playtest and changes pages are no taller than the settings and scroll, a bar at the
## side.
func fit(screen: Vector2) -> void:
	_screen = screen
	var rest := _title.size.y + _back.size.y + 2 * 6 + 2 * 6
	if _defaults.visible:
		rest += _defaults.size.y + 6
	# As on the settings page, whose tabs the changes page has not.
	var room := screen.y - 2 * 8 - rest - TAB_HEIGHT - 6
	# Every page takes the columns the settings need, so all are as wide.
	var n := 2 if _page_height("settings", 1) > room \
			and screen.x - 2 * 8 - 2 * UiStyle.PAD.x - BAR_ROOM >= 2 * ROW_WIDTH + COLUMN_GAP else 1
	if n != _columns and page in ["changes", "freezes", "report"]:
		_columns = n
		_fill()
		return
	_set_columns(n)
	_legend_grid.columns = CHANGE_KINDS.size() if n > 1 else 2
	if _version.visible:
		room -= _version.size.y + 6
	if _legend.visible:
		room -= _legend.get_combined_minimum_size().y + 6
	if not _tabs.visible:
		room += TAB_HEIGHT + 6
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
			_list.add_child(_paragraph("#%d · %s" % [pr, merged_at(c)], UiStyle.ACCENT))
		_list.add_child(_change_line(str(c.get("kind", "new")), str(c.text), UiStyle.INK, content_width()))


## The freezes of band `key` (FreezeLog.BANDS) under an ordinary frame, a wrapped
## paragraph each, the longest in red; each tab tells how many its band holds.
func _add_freezes(key: String) -> void:
	for sec in PAGES.freezes:
		var b: Button = _tab_buttons[sec[0]]
		# No « · » before the count: four tabs of two-figure counts fit an upright phone.
		b.text = "%s %d" % [sec[1], game.freeze_log.lines(sec[0]).size()]
		TabRow.light(b, sec[0] == key)
	_list.add_child(_paragraph(game.freeze_log.usual_line(), UiStyle.MUTED))
	var lines: Array = game.freeze_log.lines(key)
	var shown := [game.freeze_log.usual_line()]
	for l: Array in lines:
		shown.append(l[1])
	_shown_text = "\n".join(shown)
	if lines.is_empty():
		_list.add_child(_paragraph("Фризов нет" if key == "all" else "Таких фризов нет", UiStyle.MUTED))
	for l: Array in lines:
		_list.add_child(_paragraph(l[1], UiStyle.DANGER if l[0] >= 200.0 else (UiStyle.ACCENT if l[0] >= 100.0 else UiStyle.INK)))


func _clear_freezes() -> void:
	game.freeze_log.clear()
	_unarm(_clear, "Очистить журнал")
	_fill()


## The playtest report (report_text), which the buttons under the page copy or share.
func _add_report() -> void:
	_shown_text = report_text()
	_list.add_child(_paragraph(_shown_text, UiStyle.INK))


## «Скопировать»: the text of the page shown into the clipboard.
func _copy_shown() -> void:
	DisplayServer.clipboard_set(_shown_text)
	_copy.text = "Скопировано"
	UiStyle.succeed(_copy, true)


## «Поделиться»: the text of the page shown to the phone's sharing.
func _share_shown() -> void:
	JavaScriptBridge.eval("navigator.share({text: %s}).catch(function () {})" % JSON.stringify(_shown_text), true)


## What a playtest report needs for the moment to be played again, a line each: the
## build, the world, where the player stands and looks, the time, the weather, the light,
## the settings, the device and how long the start took (the engine to the game's scene,
## the mods' data read and loaded, the world built).
func report_text() -> String:
	var info := build_info()
	var s = game.settings
	var clock = game.clock
	var sky = game.sky
	var p: Vector3 = game.player.position
	var cell := Vector3i((p / game.CELL).floor())
	var minutes := int(clock.time_of_day * 24.0 * 60.0)
	var lines := [
		"Survivium %s · %s · %s" % [info.version, info.commit, info.date],
		"Мир: %s, настройки %s" % ["тестовый" if s.in_test_world() else "зерно %d" % game.world_seed,
			JSON.stringify(game.world_options)],
		"Игрок: x %d, y %d, уровень %d, срез %d" % [cell.x, cell.z, cell.y, game.chunks.cut_level],
		"Камера: поворот %d°, наклон %d" % [posmod(game.view.turn_steps * 45, 360), game.view.tilt_steps],
		"Время: день %d, %s, %02d:%02d, ход ×%s%s%s" % [clock.day, clock.SEASONS[clock.season], minutes / 60, minutes % 60,
			str(clock.time_speed * s.time_boost), ", как в жизни" if clock.real_time else "",
			", сезон как в жизни" if clock.real_season else ""],
		"Погода: %s%s, облака %.2f, дождь %.2f, снег %.2f, туман %.2f, ветер %.2f к %d°, снег лежит %.2f, лужи %.2f" % [
			clock.WEATHERS[clock.weather].name, "" if clock.weather_auto else " (выбрана)", clock.clouds, clock.rain,
			clock.snowing, clock.fog, clock.storm_wind, roundi(rad_to_deg(clock.wind_angle)), clock.snow, clock.puddles],
		"Свет: день %.2f, луна %.2f%s" % [sky.daylight, sky.moon, " (выбрана)" if sky.moon_override >= 0.0 else ""],
		"Настройки: %s" % JSON.stringify(s.values),
		"Устройство: %s, экран %dx%d, окно %dx%d, %s" % [OS.get_name(), DisplayServer.screen_get_size().x,
			DisplayServer.screen_get_size().y, get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y, RenderingServer.get_video_adapter_name()],
		"Кадр: обычный %.1f мс, фризов в журнале %d" % [game.hud.perf.usual[0], game.hud.perf.freeze_log.size()],
		"Загрузка: запуск %.1f с (данные модов: записей %d, чтение %d мс, набор %d мс), мир %.1f с" % [game.start_ms / 1000.0,
			Content.record_count(), roundi(Content.read_ms), roundi(Content.load_ms), game.hud.perf.world_ms / 1000.0],
	]
	if game.net != null:
		lines.append("Сервер: %s, запросов %d, байт туда %d, обратно %d, кодирование %.1f мс, ждут %d" % [
			"по сети " + game.join_url if game.socket != null else "в игре (петля)",
			game.net.requests, game.net.sent_bytes, game.net.received_bytes, game.net.coding_us / 1000.0, game.net.pending()])
	return "\n".join(lines)


## When change `c` was merged, in this device's time: "2026-10-23 18:32"; only the date
## for a build from before the time was kept.
static func merged_at(c: Dictionary) -> String:
	var utc := str(c.get("merged", ""))
	if utc == "":
		return str(c.get("date", ""))
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	if OS.has_feature("web"):
		# The browser knows the player's time zone surely.
		bias = int(JavaScriptBridge.eval("-new Date().getTimezoneOffset()", true))
	var t := Time.get_unix_time_from_datetime_string(utc.trim_suffix("Z")) + bias * 60
	return Time.get_datetime_string_from_unix_time(t, true).left(16)


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


## A row "name ‹ value ›"; `other` is shown when `getter` gives -1 (none of `values`);
## while `works` (if given) says false the row is faded and its arrows do nothing.
func _add_row(name: String, values: Array, getter: Callable, setter: Callable, other := "", works := Callable()) -> void:
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
	value.clip_text = true
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	var right := _arrow(row, "next", index, 1)
	_rows.append({"name": label, "values": values, "get": getter, "set": setter, "label": value,
		"left": left, "right": right, "other": other, "works": works, "row": row})


## A button as wide as a row that does `action` once (a way into the test world); with
## `confirm` only when tapped twice. Returns the button.
func _add_action(text: String, action: Callable, confirm := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	if confirm:
		b.pressed.connect(_confirm.bind(b, text, action))
	else:
		b.pressed.connect(action)
	_grid().add_child(b)
	return b


## A button that asks first: the first tap turns it red (for a few seconds, its text
## as it was), the second does `action`.
func _confirm(b: Button, text: String, action: Callable) -> void:
	if not b.get_meta("armed", false):
		b.set_meta("armed", true)
		UiStyle.arm(b, true)
		get_tree().create_timer(CONFIRM_WAIT, true).timeout.connect(_unarm.bind(b, text))
		return
	action.call()


func _unarm(b: Button, text: String) -> void:
	if is_instance_valid(b):
		b.text = text
		b.set_meta("armed", false)
		UiStyle.arm(b, false)


## A marker (game.markers, `i`) as a row: its colour, its name and column, and a
## button that takes the player there and back into the game.
func _add_marker(i: int) -> void:
	var m: Dictionary = game.markers.list[i]
	_add_place(Markers.color_of(m), (Markers.COLORS[m.color][0] as String).capitalize(), m.cell, "Телепорт к маркеру")


## A place as a row: a swatch of `color`, `name` and the column `cell`, and a button
## that takes the player there (its tooltip `tip`) and back into the game.
func _add_place(color: Color, name: String, cell: Vector2i, tip: String) -> void:
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
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(10, 10)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.add_child(fill)
	row.add_child(swatch)
	var label := UiStyle.label("%s · X %d, Y %d" % [name, cell.x, cell.y])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	var b := Button.new()
	b.text = "Перейти"
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ARROW)
	b.pressed.connect(func() -> void:
		game.character.go_to_column(cell)
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
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	if not _works(r):
		return
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
