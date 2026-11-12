extends PanelContainer
## The settings window and the playtest window, opened from the pause menu. Both are
## lists of rows "name ‹ value ›": a tap or a click on an arrow picks the next value,
## which suits a thumb as well as a mouse; the keyboard moves between rows with the
## arrows and changes a value with Left / Right or Enter. Values come from and go to
## Settings (plan/design/ui.md, section 6). Both pages are split into sections by tabs
## under the title (see PAGES): the settings into Игра, Интерфейс (sizes, the minimap,
## which HUD buttons show, the full screen, the key hints), Графика, Музыка and Звук
## (their volumes, see Sound; Графика starts with the quality preset, any change by
## hand makes it «своё»); the playtest page into Мир, Сервер, Игрок, Пещеры, Маркеры,
## Отладка, with buttons for what is done once (into the test world, the tools into the
## bag, to a marker set on the map: Маркеры lists them with their colour and column;
## Сервер: the playtest server on GitHub apart from the server played on or made here,
## see _server_rows). The playtest page also
## shows the version of the build and opens the list of recent changes ("changes" page,
## its legend of kinds above the buttons; the main menu opens it too), no taller than the
## settings and scrolling, made CHANGES_STEP changes at a time as it is scrolled down,
## and from «Отладка» the log of freezes ("freezes" page, FreezeLog): a tab for each
## band of their length, the worst first after all of them; and what a playtest report
## needs to be played again ("report" page: the world, the place, the time, the weather,
## the light, the camera, the settings, the device), to copy or share.
## All the pages are as wide: one or two columns of rows (see fit) and room for the bar.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const Settings := preload("res://src/client/settings.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Markers := preload("res://src/client/game/markers.gd")
const Sound := preload("res://src/client/audio/sound.gd")
const Vibration := preload("res://src/client/ui/vibration.gd")
const Content := preload("res://src/shared/content/content.gd")
const StartTimes := preload("res://src/client/ui/start_times.gd")
const LastLog := preload("res://src/client/ui/last_log.gd")
const GlWatch := preload("res://src/client/ui/gl_watch.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const CaveLayers := preload("res://src/client/view/cave_layers.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
## «Витрина интерфейса», loaded only when opened.
const GALLERY := "res://src/client/ui/ui_gallery.gd"

## Room for a name of 18 letters of the 8 px font; a longer one wraps onto a second line.
const NAME_WIDTH := 150
## Room for the longest value («песчаная буря»); anything longer is cut, so a value
## never widens its row and moves the window.
const VALUE_WIDTH := 112
const ARROW := 32
## How long a button that asks first (TwoTap) waits for the second tap, in seconds.
const CONFIRM_WAIT := 4.0
## The kinds of change in «Что нового» and their names (tools/build_info.py KINDS).
const CHANGE_KINDS := {
	"new": "[new_n2]", "better": "[improved]", "fix": "[fixed]", "fast": "[optimized]", "inside": "[core]",
}
## How many changes the changes page makes at once: the first ones when it opens, the
## next when it is scrolled near their end (the build holds 500, tools/build_info.py).
const CHANGES_STEP := 40
## A row across, and the room between two columns of rows (see fit).
const ROW_WIDTH := NAME_WIDTH + VALUE_WIDTH + 2 * ARROW + 3 * 2
const COLUMN_GAP := 16
## Room kept for the scroll bar on every page, so all of them are as wide: the bar and
## a gap on each side of the rows, so the bar never touches the arrows.
const BAR_GAP := UiStyle.BAR_GAP
const BAR_ROOM := UiStyle.SCROLL_BAR + 2 * BAR_GAP
const HOURS := ["[night]", "[morning]", "[day_n5]", "[evening]"]
const HOUR_OF := [0.0, 7.0, 12.0, 19.0]
## Moonlight picks of the playtest page: name and light (see Settings.set_moon).
const MOONS := [["[new_moon]", 0.0], ["[crescent]", 0.4], ["[full_moon]", 1.0]]
## The sections of the pages with tabs: key and tab name.
const PAGES := {
	"settings": [["game", "[game]"], ["interface", "[interface]"], ["graphics", "[graphics]"], ["music", "[music]"], ["sound", "[sound]"]],
	"test": [["world", "[world_n3]"], ["server", "[server_name]"], ["player", "[player_n2]"], ["caves", "[caves]"], ["marks", "[markers]"], ["debug", "[debug]"]],
	"freezes": [["all", "all"], ["critical", "from 200"], ["big", "100–200"], ["small", "50–100"]],
}
## The settings' tab of the developer mode (Settings.testing_unlocked): what is seen with
## no world too (the last run's log, the freezes, the interface's gallery, wiping the data).
const DEV_TAB := ["dev", "[debug]"]
## Sections with nothing to set yet: their tabs are dimmed, «скоро».
const SOON := []
## Sections as long as there is something in them: no taller page for them, they scroll.
const LISTS := ["marks", "all", "critical", "big", "small"]
## The room between the quality preset and the settings by hand, or the rows and a
## button.
const GAP := 8
const TAB_HEIGHT := 32
## The steps of the interface and the touch controls size.
const SIZES := ["[very_small]", "[small_ui]", "[normal_ui]", "[larger_n2]", "[large_ui]"]
## The minimap sizes (Minimap.SIDES).
const MAP_SIZES := ["[small_map]", "[normal_map]", "[large_map]"]
## The rows that are a scale from less to more (volume, sizes, speeds, quality): they
## stop at their ends instead of going round (the user's ask 2026-11-12); the rows of
## kinds (language, weather, the hour) go round.
const SCALES := ["[volume]", "[nature]", "[interface]", "[how_often]", "[interface_size]", "[controls_size]",
	"[minimap]", "[scale]", "[quality]", "[fire_shadows]", "[day_length]", "[flow_of_time]", "[player_speed]",
	"[skill_growth]", "[darkening_per_level]", "[line_height]", "[ahead_first_layers]", "[ahead_stretch]",
	"[above_first_layers]", "[above_stretch]", "[density_of_the_first]", "[shadow_map]"]

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
## «Очистить журнал» beside «Назад» on the freezes' page (two taps, TwoTap).
var _clear: Button
## «Скопировать» and «Поделиться» in the same row on the freezes' and the report page:
## the text of the page shown (_shown_text).
var _copy: Button
var _share: Button
var _shown_text := ""
## Where «Назад» goes from the changes, freezes and report pages: a page, or "" to close.
var _back_to := "test"
## The changes of the changes page not made yet (see CHANGES_STEP), and the PR made last.
var _changes_left := []
var _changes_pr := -1
var _scroll: ScrollContainer
var _list: VBoxContainer
## The kinds of change and their icons, under the changes.
var _legend: PanelContainer
var _legend_grid: GridContainer
## Rows of the page: {"key", "values": Array of String, "get": Callable, "set": Callable, "label": Label}
## The rows «name ‹ value ›» of the page shown (ChoiceRows of the kit).
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, ARROW)
## The rows, as the tests read them.
var _rows: Array[Dictionary]:
	get:
		return _choices.rows
## The buttons that ask first: «Очистить журнал», «По умолчанию», the actions with "confirm".
var _asks := TwoTap.new(CONFIRM_WAIT)
var _back: Button
## «По умолчанию» on the settings page: the first tap asks, the second puts every
## setting back as it comes (Settings.reset).
var _defaults: Button
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
	_title = Kit.title("")
	box.add_child(_title)
	_version = UiStyle.label("", UiStyle.MUTED)
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_version)
	# The tabs joined as one, as tall as the window's buttons (TabRow.tabs).
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", -2)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_tabs)
	# The rows scroll when the window is taller than a small screen with a big interface.
	# The rows keep their place whether the bar shows or not: a little room on the left,
	# the bar's on the right.
	_list = Kit.column(4)
	_scroll = Kit.scroll(_list)
	box.add_child(_scroll)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
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
	_defaults = Kit.button("[defaults]", Callable(), 0, 32)
	_asks.guard(_defaults, _reset)
	box.add_child(_defaults)
	var buttons := Kit.row(6)
	box.add_child(buttons)
	_changes = _bottom(buttons, "[whats_new]", open.bind("changes", "test"))
	_copy = _bottom(buttons, "[copy]", _copy_shown)
	_share = _bottom(buttons, "[share]", _share_shown)
	_clear = _bottom(buttons, "[clear_the_log]", Callable())
	_asks.guard(_clear, _clear_freezes)
	_back = _bottom(buttons, "[back]", _go_back)
	_choices.scroll = _scroll
	_choices.stepped.connect(_stepped)


## A row was stepped: the window fits its values again.
func _stepped(_index: int) -> void:
	reset_size()


## A button of the bottom row, sharing its width with the others.
func _bottom(row: Node, text: String, action: Callable) -> Button:
	var b := Kit.button(text, action, 0, 32)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	return b


## Opens «Витрина интерфейса» (ui_gallery.gd, made when asked) over this window, which
## hides meanwhile (its rows would scroll under a finger dragged over the gallery).
## Returns the gallery.
func open_gallery() -> Control:
	var gallery: Control = load(GALLERY).new(game)
	gallery.closed.connect(func() -> void: visible = true)
	visible = false
	get_parent().add_child(gallery)
	return gallery


## Opens page `which`; from the changes, freezes and report pages «Назад» goes to page
## `back`, or closes the window when it is "".
func open(which: String, back := "test") -> void:
	page = which
	if which in ["changes", "freezes", "report", "crash"]:
		_back_to = back
	_fill()


## Shows section `key` of the page shown (see PAGES).
func show_section(key: String) -> void:
	sections[page] = key
	_fill()


## The tabs of page `which` (see PAGES), made when the page changes.
func _make_tabs(which: String) -> void:
	var tabs := _tabs_of(which)
	if _tabs_page == which + str(tabs.size()):
		return
	_tabs_page = which + str(tabs.size())
	for b in _tabs.get_children():
		_tabs.remove_child(b)
		b.queue_free()
	_tab_buttons.clear()
	for sec in tabs:
		var key: String = sec[0]
		var b := TabRow.small_button(sec[1], show_section.bind(key))
		b.custom_minimum_size.y = TAB_HEIGHT
		b.disabled = key in SOON
		b.tooltip_text = "[soon_n2]" if b.disabled else ""
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
	_choices.clear()
	_asks.disarm()
	var which := page
	var info := build_info()
	_version.text = Lang.f("[version]", [info.version, info.commit, info.date])
	_version.visible = which != "settings"
	_changes.visible = which == "test"
	_clear.visible = which == "freezes"
	_copy.visible = which in ["freezes", "report", "crash"]
	_copy.text = "[copy]"
	UiStyle.succeed(_copy, false)
	# The phone's sharing, where the browser has it.
	_share.visible = which == "report" and OS.has_feature("web") \
			and int(JavaScriptBridge.eval("typeof navigator.share === 'function' ? 1 : 0", true)) == 1
	_defaults.visible = which == "settings"
	_tabs.visible = PAGES.has(which)
	_legend.visible = which == "changes" and not info.changes.is_empty()
	_make_tabs(which)
	if which == "changes":
		_title.text = "[whats_new]"
		_add_changes(info.changes)
	elif which == "freezes":
		_title.text = "[freeze_log]"
		_add_freezes(sections[which])
	elif which == "report":
		_title.text = "[test_data]"
		_add_report()
	elif which == "crash":
		_title.text = "[crash_log]" if LastLog.crashed else "[last_run_log]"
		_shown_text = LastLog.tail()
		if _shown_text == "":
			_shown_text = Lang.t("[no_log_yet]")
		_list.add_child(_paragraph(_shown_text, UiStyle.INK))
	else:
		_title.text = "[settings]" if which == "settings" else "[testing]"
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
			elif r is Dictionary and r.has("section"):
				_list.add_child(Kit.section(r.section, r.title, r.title))
			elif r is Dictionary and r.has("note"):
				_grid().add_child(_note(r.note))
			elif r is Dictionary:
				_add_action(r.action, r.do, r.get("confirm", false))
			else:
				_add_row(r[0], r[1], r[2], r[3], r[4] if r.size() > 4 else "", r[5] if r.size() > 5 else Callable())
	visible = true
	refresh()
	_choices.set_focus(0)
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
	# On a server its clock and weather are the server's (HostScreen «Настройки»): the
	# rows that set them here are faded; in a game of this device they all work.
	var solo := func() -> bool: return game.join_url == ""
	var solo_time := func() -> bool: return solo.call() and game_time.call()
	match key:
		"world":
			return [
				_section("clock", "[time_and_weather]"),
				["[season]", clock.SEASONS,
					func() -> int: return clock.season,
					func(i: int) -> void: s.set_season(i), "", game_season],
				["[weather]", ["[by_itself]"] + clock.WEATHERS.map(func(w: Dictionary) -> String: return w.name.to_lower()),
					func() -> int: return 0 if clock.weather_auto else clock.weather + 1,
					func(i: int) -> void: s.set_weather(i - 1), "", game_weather],
				["[moon]", ["[by_phase]"] + MOONS.map(func(m: Array) -> String: return m[0]),
					func() -> int:
						for i in MOONS.size():
							if is_equal_approx(clock.moon_pin, MOONS[i][1]):
								return i + 1
						return 0,
					func(i: int) -> void: s.set_moon(-1.0 if i == 0 else MOONS[i - 1][1])],
				["[time_of_day]", HOURS,
					func() -> int:
						var h: float = clock.time_of_day * 24.0
						var best := 0
						for i in HOUR_OF.size():
							if h >= HOUR_OF[i] - 0.5:
								best = i
						return best,
					func(i: int) -> void: s.set_hour(HOUR_OF[i]), "", game_time],
				["[hour]", range(24).map(func(h: int) -> String: return "%02d:00" % h),
					func() -> int: return int(clock.time_of_day * 24.0) % 24,
					func(i: int) -> void: s.set_hour(i), "", game_time],
				["[flow_of_time]", Settings.TIME_BOOSTS.map(func(v: float) -> String: return "[stopped]" if v == 0.0 else ("[normal_ui]" if v == 1.0 else "×%d" % int(v))),
					func() -> int: return Settings.TIME_BOOSTS.find(s.time_boost),
					func(i: int) -> void: s.set_time_boost(Settings.TIME_BOOSTS[i]), "", game_time],
			] + ([
				_section("flag", "[test_world_n2]"),
				{"action": "[back_to_your_world]" if s.in_test_world() else "[go_to_the_test_world]",
					"do": func() -> void: s.switch_test_world()},
			] if game.join_url == "" else [])
		"server":
			return _server_rows()
		"player":
			return [
				_section("person", "[movement]"),
				["[player_speed]", Settings.PLAYER_SPEEDS.map(func(v: float) -> String: return "×%d" % int(v)),
					func() -> int: return Settings.PLAYER_SPEEDS.find(s.player_speed),
					func(i: int) -> void: s.set_player_speed(Settings.PLAYER_SPEEDS[i])],
				["[skill_growth]", Settings.SKILL_RATES.map(func(v: float) -> String: return "×%d" % int(v)),
					func() -> int: return Settings.SKILL_RATES.find(s.skill_rate),
					func(i: int) -> void: s.set_skill_rate(Settings.SKILL_RATES[i])],
				["[jumps]", ["[from_the_ground]", "[and_in_the_air]"],
					func() -> int: return int(s.air_jumps),
					func(i: int) -> void: s.set_air_jumps(i == 1)],
				["[respawn_n2]", ["[at_the_campfire]", "[and_where_you_fell]"],
					func() -> int: return int(s.revive_at_death),
					func(i: int) -> void: s.revive_at_death = i == 1],
				_section("hammer", "[work_and_things]"),
				["[building]", ["[from_the_bag]", "[free]"],
					func() -> int: return int(s.free_build),
					func(i: int) -> void: s.set_free_build(i == 1)],
				["[tool_wear]", ["[off]", "[on]"],
					func() -> int: return int(s.tool_wear),
					func(i: int) -> void: s.set_tool_wear(i == 1)],
				["[overload]", ["[on]", "[off]"],
					func() -> int: return int(s.no_overload),
					func(i: int) -> void: s.set_no_overload(i == 1)],
				["[crafting]", ["[takes_time]", "[instant]"],
					func() -> int: return int(s.instant_craft),
					func(i: int) -> void: s.set_instant_craft(i == 1)],
				["[free_items]", ["[off]", "[on]"],
					func() -> int: return int(s.free_items),
					func(i: int) -> void: s.set_free_items(i == 1)],
				_section("shield", "[survival]"),
				["[hunger]", ["[on]", "[off]"],
					func() -> int: return int(s.no_hunger),
					func(i: int) -> void: s.set_no_hunger(i == 1)],
				["[thirst]", ["[on]", "[off]"],
					func() -> int: return int(s.no_thirst),
					func(i: int) -> void: s.set_no_thirst(i == 1)],
				["[fatigue]", ["[on]", "[off]"],
					func() -> int: return int(s.no_fatigue),
					func(i: int) -> void: s.set_no_fatigue(i == 1)],
				["[cold_and_heat]", ["[on]", "[off]"],
					func() -> int: return int(s.no_cold),
					func(i: int) -> void: s.set_no_cold(i == 1)],
				["[fall_damage]", ["[on]", "[off]"],
					func() -> int: return int(s.no_fall_damage),
					func(i: int) -> void: s.set_no_fall_damage(i == 1)],
				["[animal_attacks]", ["[off]", "[on]"],
					func() -> int: return int(s.animal_attacks),
					func(i: int) -> void: s.set_animal_attacks(i == 1)],
				_section("go", "[actions]"),
				{"action": "[give_tools]", "do": func() -> void: s.give_tools()},
				{"action": "[to_the_place_of_the]", "do": func() -> void: s.go_to_death()},
				{"action": "[clear_territory]", "do": func() -> void: s.clear_land(), "confirm": true},
			]
		"caves":
			var counts: Array = CaveLayers.FIRSTS.map(func(v: int) -> String: return str(v))
			var stretches: Array = CaveLayers.STRETCHES.map(func(v: int) -> String: return str(v))
			var lines: Array = CaveLayers.LINES.map(func(v: int) -> String: return "%+d" % v if v != 0 else "[0_feet]")
			var percents := func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
			var rows := [
				# For the whole world: how much darker each level under the sea gets.
				_section("moon", "[depth]"),
				["[darkening_per_level]", CaveLayers.DEPTH_STEPS.map(percents),
					func() -> int: return s.values.cut_depth,
					func(i: int) -> void: s.set_value("cut_depth", i)],
				_section("cells", "[layers]"),
			]
			# The view in layers (CaveLayers).
			var settings := [["[line_height]", "layer_line", lines],
				["[ahead_first_layers]", "layer_front_from", counts],
				["[ahead_stretch]", "layer_front_stretch", stretches],
				["[above_first_layers]", "layer_above_from", counts],
				["[above_stretch]", "layer_above_stretch", stretches],
				["[density_of_the_first]", "layer_density", CaveLayers.DENSITIES.map(percents)]]
			var note := "[only_what_is_in_front]"
			for r: Array in settings:
				var setting: String = r[1]
				rows.append([r[0], r[2],
					func() -> int: return s.values[setting],
					func(i: int) -> void: s.set_value(setting, i)])
			rows.append({"note": note})
			return rows
		"marks":
			var marks := []
			for p: Array in game.character.respawn_points():
				var at: Vector3 = p[1] / game.character.CELL
				marks.append({"place": p[0], "cell": Vector2i(floori(at.x), floori(at.z)),
					"color": UiStyle.INK, "tip": "[teleport_to_a_respawn_point]"})
			if game.markers != null:
				for i in game.markers.list.size():
					marks.append({"marker": i})
			if game.markers == null or game.markers.list.is_empty():
				marks.append({"note": "[no_markers_put_them_on]"})
			return marks
		"dev":
			var dev := []
			if not OS.has_feature("web"):
				dev.append({"action": "[last_run_log]", "do": func() -> void: open("crash", "settings")})
			dev.append({"action": "[freeze_log]", "do": func() -> void: open("freezes", "settings")})
			dev.append({"action": "[ui_gallery]", "do": func() -> void: open_gallery()})
			dev.append(_section("trash", "[danger]"))
			dev.append({"action": "[clear_all_data]", "do": func() -> void: s.wipe_all(), "confirm": true})
			return dev
		"debug":
			return [
				_section("chart", "[on_screen]"),
				["[shadow_map]", Settings.SHADOW_MAPS.map(func(v: int) -> String: return str(v)),
					func() -> int: return s.shadow_map,
					func(i: int) -> void: s.set_shadow_map(i)],
				["[statistics]", ["[off]", "[on]"],
					func() -> int: return int(game.hud.perf.visible),
					func(i: int) -> void:
						if game.hud.perf.visible != (i == 1):
							game.hud.toggle_stats()],
				["[debug_hints]", ["[off]", "[on]"],
					func() -> int: return int(s.debug_tips),
					func(i: int) -> void: s.debug_tips = i == 1],
				["[animal_ai_debug]", ["[off]", "[on]"],
					func() -> int: return int(s.ai_debug),
					func(i: int) -> void: s.set_ai_debug(i == 1)],
				["[key_log]", ["[off]", "[on]"],
					func() -> int: return int(s.keys_log),
					func(i: int) -> void: s.keys_log = i == 1],
				["[level_overview]", ["±%d" % game.chunks.VIEW_REACH, "[all_n2]"],
					func() -> int: return int(s.free_view),
					func(i: int) -> void: s.free_view = i == 1],
				_section("hammer", "[tools]"),
				{"action": "[break_down_draw_calls]", "do": func() -> void:
					close()
					if get_tree().paused:
						game.hud.toggle_menu()
					game.draw_census.start()},
				{"action": "[freeze_log]", "do": func() -> void: open("freezes")},
				{"action": "[test_data]", "do": func() -> void: open("report")},
				{"action": "[ui_gallery]", "do": func() -> void: open_gallery()},
				{"action": "[reload_mod_data]", "do": func() -> void: s.reload_mods()},
				_section("trash", "[danger]"),
				{"action": "[clear_all_data]", "do": func() -> void: s.wipe_all(), "confirm": true},
			]
		"game":
			return [
				_section("chat", "[language]"),
				["[language]", Lang.LANGS.map(func(l: Array) -> String: return l[1]),
					func() -> int: return maxi(0, Lang.LANGS.map(func(l: Array) -> String: return l[0]).find(Lang.code)),
					func(i: int) -> void:
						s.set_language(Lang.LANGS[i][0])
						_fill.call_deferred()],
				_section("clock", "[time_and_weather]"),
				["[day_length]", Settings.TIME_SPEEDS.map(func(v: float) -> String: return Lang.f("[min]", [roundi(clock.DAY_LENGTH / v / 60.0)])),
					func() -> int: return s.values.time_speed,
					func(i: int) -> void: s.set_value("time_speed", i), "", solo_time],
				["[time_of_day]", ["[in_game_time]", "[as_in_real_life]"],
					func() -> int: return int(s.values.real_time),
					func(i: int) -> void: s.set_value("real_time", i == 1), "", solo],
				["[season]", ["[in_game_season]", "[as_in_real_life]"],
					func() -> int: return int(s.values.real_season),
					func(i: int) -> void: s.set_value("real_season", i == 1), "", solo],
				["[weather]", ["[in_game_weather]", "[as_in_real_life]"],
					func() -> int: return int(s.values.real_weather),
					func(i: int) -> void: s.set_value("real_weather", i == 1), "", solo],
			] + ([{"note": "[set_by_the_server]"}] if game.join_url != "" else []) + [
				_section("bag", "[picking_up]"),
				["[auto_pickup]", ["[everything]", "[whats_there]", "[food_n2]", "[nothing]"],
					func() -> int: return s.values.pickup,
					func(i: int) -> void: s.set_value("pickup", i)],
				["[over_the_load]", ["[dont_take]", "[take]"],
					func() -> int: return int(s.values.pickup_heavy),
					func(i: int) -> void: s.set_value("pickup_heavy", i == 1)],
				_section("person", "[feel]"),
				["[screen_shake]", ["[off]", "[on]"],
					func() -> int: return int(s.values.shake),
					func(i: int) -> void: s.set_value("shake", i == 1)],
				# Faded and «нет» where the browser or device cannot buzz (a computer,
				# Safari, some phones' own browsers).
				["[vibration]", ["[off]", "[on]"],
					func() -> int: return int(s.values.vibrate) if Vibration.supported() else -1,
					func(i: int) -> void: s.set_value("vibrate", i == 1), "[no_n2]", Vibration.supported],
			]
		"interface":
			var rows := [
				_section("cells", "[sizes]"),
				["[interface_size]", SIZES,
					func() -> int: return s.values.ui_size,
					func(i: int) -> void: s.set_value("ui_size", i)],
			]
			if game.controls.touch:
				rows.append(["[controls_size]", SIZES,
					func() -> int: return s.values.control_size,
					func(i: int) -> void: s.set_value("control_size", i)])
			rows.append_array([
				["[minimap]", MAP_SIZES,
					func() -> int: return s.values.minimap_size,
					func(i: int) -> void: s.set_value("minimap_size", i)],
			])
			if s.can_fullscreen():
				rows.append(["[full_screen]", ["[off]", "[on]"],
					func() -> int: return int(s.fullscreen()),
					func(i: int) -> void: s.set_fullscreen(i == 1)])
			rows.append_array([
				_section("menu", "[buttons_n2]"),
				["[level_and_cut]", ["[off]", "[on]"],
					func() -> int: return int(s.values.level_buttons),
					func(i: int) -> void: s.set_value("level_buttons", i == 1)],
				["[camera_buttons]", ["[off]", "[on]"],
					func() -> int: return int(s.values.camera_buttons),
					func(i: int) -> void: s.set_value("camera_buttons", i == 1)],
				["[chat_and_gestures]", ["[online]", "[always]"],
					func() -> int: return int(s.values.solo_social),
					func(i: int) -> void: s.set_value("solo_social", i == 1)],
				["[stats_button]", ["[hidden]", "[shown]"],
					func() -> int: return int(s.values.stats_button),
					func(i: int) -> void: s.set_value("stats_button", i == 1)],
			])
			if game.controls.touch:
				rows.append(["[second_hand_upright]", ["[hidden]", "[shown]"],
					func() -> int: return int(s.values.second_hand),
					func(i: int) -> void: s.set_value("second_hand", i == 1)])
			if not game.controls.touch:
				rows.append(["[key_hints]", ["[off]", "[on]"],
					func() -> int: return int(s.values.show_help),
					func(i: int) -> void: s.set_value("show_help", i == 1)])
			return rows
		"music":
			return [
				_volume_row("[volume]", "music_volume"),
				["[how_often]", ["[rarely]", "[sometimes]", "[often]"],
					func() -> int: return s.values.music_often,
					func(i: int) -> void: s.set_value("music_often", i)],
			]
		"sound":
			return [
				_volume_row("[volume]", "sound_volume"),
				null,
				_volume_row("[nature]", "nature_volume"),
				_volume_row("[interface]", "ui_volume"),
			]
		"graphics":
			# From the lightest to draw to the heaviest; mixed (3) came after real (2).
			var fire_order := [0, 1, 3, 2]
			return [
				# «Авто» first, then the presets from the best (Settings.QUALITIES goes the other
				# way, «авто» past them); «своё» when the settings are a mix of the player's own.
				["[quality]", ["[auto_quality]", "[high]", "[medium_quality]", "[low]"],
					func() -> int: return -1 if s.quality() < 0 else Settings.QUALITIES.size() - s.quality(),
					func(i: int) -> void: s.set_quality(Settings.QUALITIES.size() - i), "[custom_quality]"],
				_section("cells", "[screen_n2]"),
				["[scale]", SIZES,
					func() -> int: return s.values.pixel_scale,
					func(i: int) -> void: s.set_value("pixel_scale", i)],
				["[fps_limit]", Settings.FPS_LIMITS.map(func(v: int) -> String: return "[no_n2]" if v == 0 else str(v)),
					func() -> int: return s.values.fps_limit,
					func(i: int) -> void: s.set_value("fps_limit", i)],
				_section("sun", "[light_and_shadows]"),
				["[shadows]", ["[off]", "[on]"],
					func() -> int: return int(s.values.shadows),
					func(i: int) -> void: s.set_value("shadows", i == 1)],
				["[fire_shadows]", ["[off]", "[drawn]", "[mixed]", "[real]"],
					func() -> int: return fire_order.find(s.values.fire_shadows),
					func(i: int) -> void: s.set_value("fire_shadows", fire_order[i])],
				["[shadow_on_things]", ["[off]", "[on]"],
					func() -> int: return int(s.values.shadow_on_things),
					func(i: int) -> void: s.set_value("shadow_on_things", i == 1)],
				["[sun_rays]", ["[off]", "[on]"],
					func() -> int: return int(s.values.sun_rays),
					func(i: int) -> void: s.set_value("sun_rays", i == 1)],
				_section("fog", "[effects]"),
				["[effects]", ["[off]", "[on]"],
					func() -> int: return int(s.values.effects),
					func(i: int) -> void: s.set_value("effects", i == 1)],
				["[fog]", ["[simple]", "[on_the_ground]"],
					func() -> int: return int(s.values.fog),
					func(i: int) -> void: s.set_value("fog", i == 1)],
				["[haze_at_the_edge]", ["[off]", "[on]"],
					func() -> int: return int(s.values.edge_mist),
					func(i: int) -> void: s.set_value("edge_mist", i == 1)],
				["[crt]", ["[off]", "[crt_soft]", "[crt_old]", "[crt_tape]"],
					func() -> int: return s.values.crt,
					func(i: int) -> void: s.set_value("crt", i)],
			]
	return []


## A row of the volume setting `key`, «выкл» to «100%» in Sound.STEPS steps.
## The «Сервер» tab: the playtest server on GitHub (started, joined, given an hour more,
## stopped) apart from the server this game is on or makes of its world (bots, its
## world, the switches as cheats), each under its own heading.
func _server_rows() -> Array:
	var s = game.settings
	var joined: bool = game.join_url != ""
	var playtest: bool = joined and game.welcome.get("playtest") == true
	var host: bool = joined and (game.hosted != null or game.welcome.get("host") == true)
	var rows := [_section("server", "[test_server_github]")]
	if playtest:
		rows += [
			{"action": "[keep_the_server_an_hour]", "do": func() -> void: s.test_server("hour")},
			{"action": "[stop_the_test_server]", "do": func() -> void: s.test_server("stop"), "confirm": true},
		]
	else:
		rows += [
			{"action": "[start_the_test_server]", "do": func() -> void: s.start_test_server()},
			{"action": "[join_the_test_server]", "do": func() -> void: s.join_test_server()},
		]
	rows.append(_section("power", "[this_server]" if joined else "[your_own_server]"))
	if not joined:
		if s.can_host():
			rows += [{"note": "[bots_only_come_to_a]"},
				{"action": "[make_the_world_a_server]", "do": func() -> void: s.host_with_bot()}]
		else:
			rows.append({"note": "[your_own_server_and_bots]"})
		return rows
	if not playtest and not host:
		rows.append({"note": "[the_bots_and_the_world]"})
		return rows
	rows += [
		{"action": "[add_a_bot]", "do": func() -> void: s.test_server("bot+")},
		{"action": "[remove_a_bot]", "do": func() -> void: s.test_server("bot-")},
		null,
		{"action": "[test_world_on_the_server]", "do": func() -> void: s.test_server("new test"), "confirm": true},
		{"action": "[new_world_on_the_server]", "do": func() -> void: s.test_server("new"), "confirm": true},
	]
	if game.hosted != null:
		# The server is made here: its worlds are this device's.
		for w: Dictionary in s.server_worlds():
			rows.append({"action": Lang.f("[world_day]", [w.seed, w.day]) if w.seed != WorldStore.TEST_SEED else "[test_world_n2]",
				"do": func() -> void: s.test_server("world " + str(w.dir).get_file()), "confirm": true})
	else:
		rows.append({"action": "[the_servers_worlds_list_in]", "do": func() -> void: s.test_server("worlds")})
	if game.hosted != null:
		rows.append({"action": "[stop_the_server]", "do": func() -> void: game.stop_server(), "confirm": true})
	elif not playtest:
		rows.append({"action": "[stop_the_server]", "do": func() -> void: s.test_server("stop"), "confirm": true})
	rows += [_section("star", "[cheats]"),
		["[cheats_on_the_server]", ["[off]", "[on]"],
			func() -> int: return int(s.cheats),
			func(i: int) -> void: s.set_cheats(i == 1)],
	]
	return rows


func _volume_row(name: String, key: String) -> Array:
	var s = game.settings
	var steps := ["[off]"]
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
		if r != null and not _is_section(r):
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
		elif _is_section(r):
			h += Kit.SECTION_H
			children += 1
	return h + maxi(0, children - 1) * 4


static func _is_section(r: Variant) -> bool:
	return r is Dictionary and r.has("section")


## A section strip of a page (Kit.section): its icon and name.
static func _section(icon: String, title: String) -> Dictionary:
	return {"section": icon, "title": title}


## The version of this build and its recent changes, newest first:
## {"version", "commit", "date", "changes": [{"pr", "date", "text", "texts": {code: text}}]}.
static func build_info() -> Dictionary:
	var info := {"version": "dev", "commit": "", "date": "", "changes": []}
	info.merge(Protocol.build_info(), true)
	return info


## "Назад": the changes, freezes and report pages go back to where they were opened
## from (see open), the other pages close.
## «По умолчанию», on its second tap: the settings as they come.
func _reset() -> void:
	game.settings.reset()
	_fill()


func _go_back() -> void:
	if page in ["changes", "freezes", "report", "crash"] and _back_to != "":
		open(_back_to)
	else:
		close()


func close() -> void:
	visible = false
	page = ""
	closed.emit()


## Updates every value label from the game state (values change by hotkeys too, and the
## clock runs while the playtest page is open); the window is laid out again only when
## a label changed.
func refresh() -> void:
	if _choices.refresh():
		reset_size()


## Seconds between the updates of the shown values while the window is open.
const REFRESH_EVERY := 0.5
var _refresh_in := 0.0


func _process(delta: float) -> void:
	if not visible or _rows.is_empty():
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_EVERY
		refresh()


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
	if n != _columns and page in ["changes", "freezes", "report", "crash"]:
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


## The tabs of page `which`: PAGES', and on the settings the developer mode's.
func _tabs_of(which: String) -> Array:
	var tabs: Array = PAGES.get(which, [])
	if which == "settings" and game.settings.testing_unlocked:
		tabs = tabs + [DEV_TAB]
	return tabs


## How tall the longest section of page `which` (see PAGES) stands in `n` columns.
func _page_height(which: String, n: int) -> int:
	var tallest := 0
	for sec in _tabs_of(which):
		if not sec[0] in LISTS:
			tallest = maxi(tallest, _height(_section_rows(sec[0]), n))
	return tallest


## One wrapped paragraph a change, as wide as the rows of the other pages.
func _add_changes(changes: Array) -> void:
	if changes.is_empty():
		_list.add_child(_paragraph("[the_list_of_changes_appears]", UiStyle.MUTED))
		return
	_changes_left = changes.duplicate()
	_changes_pr = -1
	_more_changes()


## The text of a change in the game's language, else English, else the one `text` holds (Russian
## in the lines written first; PRs give "What's new (xx)" lines per language, tools/build_info.py).
static func change_text(c: Dictionary) -> String:
	var texts = c.get("texts", {})
	if texts is Dictionary:
		for code: String in [Lang.code, "en"]:
			if texts.has(code):
				return str(texts[code])
	return str(c.get("text", ""))


## The next CHANGES_STEP changes at the end of the changes page.
func _more_changes() -> void:
	for c: Dictionary in _changes_left.slice(0, CHANGES_STEP):
		if int(c.pr) != _changes_pr:
			_changes_pr = int(c.pr)
			_list.add_child(_paragraph("#%d · %s" % [_changes_pr, merged_at(c)], UiStyle.ACCENT))
		_list.add_child(_change_line(str(c.get("kind", "new")), change_text(c), UiStyle.INK, content_width()))
	_changes_left = _changes_left.slice(CHANGES_STEP)


## Scrolled within a screen of the end of the changes made: the next ones.
func _on_scrolled(value: float) -> void:
	if page != "changes" or _changes_left.is_empty():
		return
	var bar := _scroll.get_v_scroll_bar()
	if value + bar.page >= bar.max_value - _scroll.size.y:
		_more_changes()


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
		_list.add_child(_paragraph("[no_freezes]" if key == "all" else "[no_such_freezes]", UiStyle.MUTED))
	for l: Array in lines:
		_list.add_child(_paragraph(l[1], UiStyle.DANGER if l[0] >= 200.0 else (UiStyle.ACCENT if l[0] >= 100.0 else UiStyle.INK)))


func _clear_freezes() -> void:
	game.freeze_log.clear()
	_asks.disarm()
	_fill()


## The playtest report (report_text), which the buttons under the page copy or share.
func _add_report() -> void:
	_shown_text = report_text()
	_list.add_child(_paragraph(_shown_text, UiStyle.INK))


## «Скопировать»: the text of the page shown into the clipboard.
func _copy_shown() -> void:
	DisplayServer.clipboard_set(_shown_text)
	_copy.text = "[copied]"
	UiStyle.succeed(_copy, true)


## «Поделиться»: the text of the page shown to the phone's sharing.
func _share_shown() -> void:
	JavaScriptBridge.eval("navigator.share({text: %s}).catch(function () {})" % JSON.stringify(_shown_text), true)


## What a playtest report needs for the moment to be played again, a line each: the
## build, the world, where the player stands and looks, the time, the weather, the light,
## the settings, the device, where the start went (StartTimes: the page's downloads, the
## engine's graphics, the scripts compiled, the modules, the menu, the world, the mods'
## data read and loaded) and the last starts kept on the device.
func report_text() -> String:
	var info := build_info()
	var s = game.settings
	var clock = game.clock
	var sky = game.sky
	var p: Vector3 = game.player.position
	var cell := Vector3i((p / game.CELL).floor())
	var minutes := int(clock.time_of_day * 24.0 * 60.0)
	var lines := [
		"%s %s · %s · %s" % [Protocol.game_name(), info.version, info.commit, info.date],
		Lang.f("World: %s, settings %s", ["test" if s.in_test_world() else Lang.f("seed %d", [game.world_seed]),
			JSON.stringify(game.world_options)]),
		Lang.f("Player: x %d, y %d, level %d, cut %d", [cell.x, cell.z, cell.y, game.chunks.cut_level]),
		Lang.f("Camera: turn %d°, tilt %d", [posmod(game.view.turn_steps * 45, 360), game.view.tilt_steps]),
		Lang.f("Time: day %d, %s, %02d:%02d, speed ×%s%s%s", [clock.day, clock.SEASONS[clock.season], minutes / 60, minutes % 60,
			str(clock.time_speed * s.time_boost), ", real time" if clock.real_time else "",
			", real season" if clock.real_season else ""]),
		Lang.f("Weather: %s%s, clouds %.2f, rain %.2f, snow %.2f, fog %.2f, wind %.2f to %d°, snow cover %.2f, puddles %.2f", [
			clock.WEATHERS[clock.weather].name, "" if clock.weather_auto else " (picked)", clock.clouds, clock.rain,
			clock.snowing, clock.fog, clock.storm_wind, roundi(rad_to_deg(clock.wind_angle)), clock.snow, clock.puddles]),
		Lang.f("Light: day %.2f, moon %.2f%s", [sky.daylight, sky.moon, " (picked)" if clock.moon_pin >= 0.0 or sky.moon_override >= 0.0 else ""]),
		Lang.f("Settings: %s", [JSON.stringify(s.values)]),
		Lang.f("Device: %s, screen %dx%d, window %dx%d, %s", [OS.get_name(), DisplayServer.screen_get_size().x,
			DisplayServer.screen_get_size().y, get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y, RenderingServer.get_video_adapter_name()]),
		Lang.f("Frame: usual %.1f ms, freezes in log %d", [game.hud.perf.usual[0], game.hud.perf.freeze_log.size()]),
		StartTimes.line(),
		Lang.f("Earlier starts: %s", [("; ".join(StartTimes.past().slice(0, 3)) if not StartTimes.past().is_empty() else "none")]),
	]
	if OS.has_feature("web"):
		# English only, like the other internal texts to come (decision 186).
		lines.append("Browser draws with: %s%s" % [GlWatch.renderer(), " (software, no graphics card)" if GlWatch.software() else ""])
	var last_log := LastLog.tail()
	if last_log != "":
		# English only, an internal text (decision 186).
		lines.append("Last run's log, " + last_log)
	if game.net != null:
		lines.append(Lang.f("Server: %s, requests %d, bytes out %d, in %d, coding %.1f ms, waiting %d", [
			Lang.f("over the net %s", [game.join_url]) if game.socket != null else "in the game (loop)",
			game.net.requests, game.net.sent_bytes, game.net.received_bytes, game.net.coding_us / 1000.0, game.net.pending()]))
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
## A row of SCALES stops at its ends, the arrow towards the end it is at off.
func _add_row(name: String, values: Array, getter: Callable, setter: Callable, other := "", works := Callable()) -> void:
	_choices.add(_grid(), name, values, getter, setter, {"other": other, "works": works, "wrap": true,
		"stop": name in SCALES})


## A button as wide as a row that does `action` once (a way into the test world); with
## `confirm` only when tapped twice. Returns the button.
func _add_action(text: String, action: Callable, confirm := false) -> Button:
	var b := Kit.button(text, Callable(), ROW_WIDTH, ARROW)
	if confirm:
		_asks.guard(b, action)
	else:
		b.pressed.connect(action)
	_grid().add_child(b)
	return b


## A marker (game.markers, `i`) as a row: its colour, its name and column, and a
## button that takes the player there and back into the game.
func _add_marker(i: int) -> void:
	var m: Dictionary = game.markers.list[i]
	_add_place(Markers.color_of(m), (Markers.COLORS[m.color][0] as String).capitalize(), m.cell, "[teleport_to_a_marker]")


## A place as a row: a swatch of `color`, `name` and the column `cell`, and a button
## that takes the player there (its tooltip `tip`) and back into the game.
func _add_place(color: Color, name: String, cell: Vector2i, tip: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(ROW_WIDTH, ARROW)
	_grid().add_child(row)
	row.add_child(Kit.swatch(color))
	var label := UiStyle.label("%s · X %d, Y %d" % [name, cell.x, cell.y])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	var b := Kit.button("[go]", Callable(), 0, ARROW)
	b.tooltip_text = tip
	b.pressed.connect(func() -> void:
		game.character.go_to_column(cell)
		close()
		if get_tree().paused:
			game.hud.toggle_menu())
	row.add_child(b)


## A line of muted text as wide as a row.
func _note(text: String) -> Label:
	var l := Kit.note(text, ROW_WIDTH)
	l.custom_minimum_size.y = ARROW
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
		KEY_ENTER, KEY_SPACE when not _rows.is_empty():
			_choices.step(_choices.focus, 1)
		_:
			if not _choices.key(event):
				return
	get_viewport().set_input_as_handled()


## Screen rectangles of the arrows, for the F3 debug line and the browser smoke test.
func debug_rects() -> Dictionary:
	var out := {}
	for r in _rows:
		var b: Button = r.right
		out[r.name.text] = b.get_global_rect() if b.is_visible_in_tree() else Rect2()
	return out
