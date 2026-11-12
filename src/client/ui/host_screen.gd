extends "res://src/client/ui/kit/window.gd"
## «Создать сервер» (plan/architecture/server.md, «Меню и экраны»; on a computer): the
## window of the server made in the game (Main.hosted, LocalHost.host). Before it runs:
## two tabs joined as one (TabRow.tabs). «Создание»: the world (one of the saved ones,
## ‹ › go through them, the one played last first; the test world always among them, a
## new one when none of the player's own is saved), the server's name, a password and
## «Доступ из интернета» (a Cloudflare quick tunnel, Tunnel; needs cloudflared).
## «Настройки»: everything else a server takes (Config and its rules, Rules): the port,
## how many players, how often the world is saved, how long a day lasts, «Погода с
## улицы» (RealWeather), animal attacks, tool wear, where players may fight players
## («PvP»: выключен, по правам территорий, везде) and the fights' numbers, the land's
## numbers and its decay, «По умолчанию» (two taps); all from the server's settings file
## (LocalHost.server_settings), which the server writes back. «Запустить
## сервер» (under either tab) starts the game again with the server made and joined (Main.host_server),
## «Назад» (or Escape) says `cancelled`. While it runs: the port and the players, the
## addresses for friends in the home network (one is copied by «Скопировать адрес»), the
## address from the internet once the tunnel gives it («Скопировать ссылку»: the game's
## page that opens «Присоединиться» with it), the
## players with «Выгнать» and «В бан» (two taps), the server's last lines and a field for
## the host's commands (Server.command: give, tp, ban, whitelist…) on the tab «Сервер»;
## on the tab «Доступ» «Только по списку», the list with «Убрать» and «Добавить», the
## blocked with «Разбанить» and «Заблокировать» (the same commands); «Играть» says `play` (into its world),
## «Остановить сервер» asks again and stops it (Main.stop_server), «Назад» leaves it
## running. It covers the whole screen over a shade of the world behind (a window of the
## UI kit, its choices ChoiceRows, «Остановить сервер» a TwoTap). `game` is the Main node.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const ServerList := preload("res://src/client/net/server_list.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")
const Clock := preload("res://src/shared/game/clock.gd")

const WIDTH := 300
const NAME_WIDTH := 80
const ROW_H := 30
const ARROW := 30
## The value between a choice's arrows: the rest of the window's width.
const VALUE_WIDTH := WIDTH - NAME_WIDTH - 2 * ARROW - 3 * 2
## Lines of the server's log kept in its well (scrolled to the newest), the well's
## height in lines, and seconds between two looks at the server.
const LOG_SHOWN := 20
const LOG_TALL := 5
const REFRESH := 0.5
## Where players may fight players (Config.pvp), and their words.
const PVP_MODES := ["off", "land", "all"]
const PVP_TITLES := ["[off_pvp]", "[by_territories]", "[everywhere]"]
## The width of the button beside a name («Доступ»), of «Выгнать» and «В бан».
const NAME_BUTTON := 124
const PLAYER_BUTTON := 72
## Players a server may be set to take.
const PLAYER_COUNTS := [2, 4, 8, 16, 32]
## «Настройки»: the rows' names and values narrower, more of them in a row's width.
const SET_NAME := 110
const SET_VALUE := WIDTH - SET_NAME - 2 * ARROW - 3 * 2
## The choices of the tab «Настройки» (a value of the settings file that is none of them
## is shown among them): seconds between saves, minutes of a day, health a blow takes for
## each point of the weapon's power, minutes a newcomer is protected, seconds a fight
## holds, the land (Rules: territory_*), hours before abandoned land decays and between
## its stages, how it decays.
const SAVE_SECONDS := [10.0, 30.0, 60.0, 300.0]
const DAY_MINUTES := [4.0, 8.0, 20.0, 40.0, 80.0, 120.0, 240.0, 1440.0]
const PVP_DAMAGE := [1, 2, 4, 6, 8]
const NEWCOMER_MINUTES := [0, 30, 60, 120, 240, 480]
const FIGHT_SECONDS := [15.0, 30.0, 45.0, 60.0, 90.0, 120.0]
const TERRITORY_START := [16, 32, 64, 128, 256]
const TERRITORY_PER_LEVEL := [0, 4, 8, 16]
const TERRITORY_RADIUS := [8, 12, 16, 24, 32, 48]
const TERRITORY_LEVELS := [2, 4, 8, 16]
const ABANDON_HOURS := [24.0, 48.0, 72.0, 120.0, 168.0]
const DECAY_HOURS := [6.0, 12.0, 24.0, 48.0]
const DECAY_MODES := ["rights", "radius", "both"]
const DECAY_TITLES := ["[rights]", "[radius]", "[rights_and_radius]"]
const DAY_LENGTH := Clock.DAY_LENGTH

signal cancelled
signal play

var game
## Holds the window's rows: it scrolls when they are taller than the screen (a landscape
## phone, a large interface).
var _scroll: ScrollContainer
## Between the scroll and the rows: room for its bar while it scrolls.
var _room: MarginContainer
var _box: VBoxContainer
## The saved worlds to choose from ({dir, seed, settings, day, …}), the one chosen.
var _worlds: Array = []
var _world := 0
## The rows of the tab shown (up and down, left and right go through them).
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, ARROW)
## The tabs, their pages and their rows; the tab shown.
var _tabs: HBoxContainer
var _pages: Array[VBoxContainer] = []
var _rows: Array = []
var _tab := 0
## The settings as the window has them (LocalHost.server_settings: Config's, `rules`
## Rules.to_dict), the switches of «Настройки» by their keys.
var _set := {}
var _checks := {}
var _title: LineEdit
var _port: LineEdit
var _password: LineEdit
var _tunnel: CheckButton
## The tunnel's state and its link's button while the server runs.
var _tunnel_label: Label
var _tunnel_copy: Button
var _error: Label
## While the server runs: its state, its players and its log, looked at every REFRESH.
var _state: Label
var _people: VBoxContainer
var _log: Label
var _stop: Button
## «Остановить сервер» asks first.
var _asks := TwoTap.new()
var _clock := 0.0
var _shown_people = null
var _log_scroll: ScrollContainer
## Where `_button` puts its buttons: the page being made, else the rows.
var _into: VBoxContainer = null
## «Доступ»: the switch «Только по списку», the names on the list and those blocked, as
## shown ([listed_only, listed, blocked]); «В бан» on a player's row asks first.
var _listed_only: CheckButton
var _listed: VBoxContainer
var _banned: VBoxContainer
var _shown_access = null
var _bans := TwoTap.new(3.0)


func _init(g) -> void:
	game = g


func _ready() -> void:
	build()
	_box = Kit.column(6)
	# The rows scroll when they are taller than the screen (layout), the bar's room
	# beside them only then; the setup's tabs over them and its buttons under them.
	_room = MarginContainer.new()
	_room.add_child(_box)
	_scroll = Kit.scroll(_room, false)
	if running():
		box.add_child(Kit.title("[server_running]"))
		_build_running()
	else:
		box.add_child(Kit.title("[create_a_server]"))
		_build_setup()
	show_fitted()
	# Rows shown or added later (an error, the players) fit the window again.
	_box.minimum_size_changed.connect(fit, CONNECT_DEFERRED)


func back() -> void:
	cancelled.emit()


## The server made here is running.
func running() -> bool:
	return game.hosted != null


# --- Before it runs --------------------------------------------------------------

func _build_setup() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://server.cfg")
	_set = game.LocalHost.server_settings()
	if not cfg.has_section_key("server", "day_minutes"):
		# Never hosted yet: the day as long as in the host's own game («Длина суток»).
		_set.day_minutes = roundf(DAY_LENGTH / game.settings.time_speed() / 60.0)
	_worlds = WorldStore.list_worlds()
	if not _worlds.any(func(w: Dictionary) -> bool: return w.seed != WorldStore.TEST_SEED):
		# No world of its own saved yet: the one the first screen sets up, new.
		_worlds.push_front({"dir": "", "seed": int(game.settings.values.world_seed),
			"settings": game.settings.world_options(), "day": 0, "new": true})
	if not _worlds.any(func(w: Dictionary) -> bool: return w.seed == WorldStore.TEST_SEED):
		# The test world may be a server too, laid out anew when it has no save.
		_worlds.append({"dir": "", "seed": WorldStore.TEST_SEED, "settings": {}, "day": 1})
	for i in _worlds.size():
		if _worlds[i].seed == game.world_seed and _worlds[i].settings == game.world_options:
			_world = i
	_make_tabs(["[create]", "[settings]"])
	_rows = [_choices, ChoiceRows.new(SET_NAME, SET_VALUE, ARROW)]
	_build_making(_pages[0], _rows[0])
	_build_settings(_pages[1], _rows[1])
	_error = Kit.note(game.host_error, WIDTH, UiStyle.DANGER)
	_error.visible = game.host_error != ""
	box.add_child(_error)
	box.add_child(_button("[start_the_server]", _start, true, false))
	box.add_child(_button("[back]", back, false, false))
	show_tab(0)


## «Создание»: the world, the name, the password and the access from the internet.
func _build_making(page: VBoxContainer, rows: ChoiceRows) -> void:
	rows.add(page, "[world_n3]", _worlds.map(_world_title), func() -> int: return _world,
		func(i: int) -> void: _world = i)
	_title = _field(page, rows, "[title]", str(_set.title))
	_title.max_length = 32
	_password = _field(page, rows, "[password]", str(_set.password))
	_password.placeholder_text = "[no_password]"
	_tunnel = Kit.check("[access_from_the_internet]", bool(_set.tunnel), WIDTH, ROW_H)
	page.add_child(_tunnel)
	page.add_child(Kit.note("[players_from_the_home_network]", WIDTH))
	page.add_child(Kit.note("[port_player_count_day_length]", WIDTH))
	rows.refresh()


## «Настройки»: everything else the server takes (Config, its rules: Rules), each row
## with its value from the server's settings file, «По умолчанию» back to the defaults.
func _build_settings(page: VBoxContainer, rows: ChoiceRows) -> void:
	page.add_child(Kit.caption("[server_name]"))
	_port = _field(page, rows, "[port]", str(_set.port))
	_port.max_length = 5
	_port.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_pick(page, rows, "[players_max]", "max_players", PLAYER_COUNTS, _count)
	_pick(page, rows, "[save_every]", "autosave", SAVE_SECONDS, _seconds)
	page.add_child(Kit.caption("[world_n3]"))
	_pick(page, rows, "[day_length]", "day_minutes", DAY_MINUTES, _minutes)
	_check(page, "[real_weather_outside]", "real_weather", "[the_weather_in_the_world]")
	_check(page, "[animals_attack]", "animal_attacks", "[predators_guard_their_ground_and]")
	_check(page, "[tool_wear]", "tool_wear", "[tools_wear_out_from_work]")
	page.add_child(Kit.caption("[fights]"))
	_pick(page, rows, "PvP", "pvp", PVP_MODES, func(m: String) -> String: return PVP_TITLES[PVP_MODES.find(m)])
	_pick(page, rows, "[fight_damage]", "pvp_damage", PVP_DAMAGE, _count)
	_pick(page, rows, "[newcomer_shield]", "newcomer_minutes", NEWCOMER_MINUTES, _minutes)
	_pick(page, rows, "[fight_lasts]", "fight_tag", FIGHT_SECONDS, _seconds)
	page.add_child(Kit.caption("[land]"))
	_pick(page, rows, "[starting_land]", "territory_start", TERRITORY_START, _count)
	_pick(page, rows, "[per_level]", "territory_per_level", TERRITORY_PER_LEVEL, _count)
	_pick(page, rows, "[reach]", "territory_radius", TERRITORY_RADIUS, _count)
	_pick(page, rows, "[levels]", "territory_levels", TERRITORY_LEVELS, _count)
	_pick(page, rows, "[abandoned_after]", "territory_abandon_hours", ABANDON_HOURS, _hours)
	_pick(page, rows, "[decay_step]", "territory_decay_hours", DECAY_HOURS, _hours)
	_pick(page, rows, "[decay]", "territory_decay", DECAY_MODES, func(m: String) -> String: return DECAY_TITLES[DECAY_MODES.find(m)])
	page.add_child(Kit.note("[starting_land_is_a_new]", WIDTH))
	var defaults := Kit.button("[defaults]", Callable(), WIDTH, ROW_H + 4)
	_asks.guard(defaults, _defaults)
	page.add_child(defaults)
	rows.refresh()


## The setting `key` of `_set` (or its rules), as the server's settings file has it.
func _value(key: String) -> Variant:
	return _set.rules[key] if _set.rules.has(key) else _set[key]


func _put(key: String, v: Variant) -> void:
	if _set.rules.has(key):
		_set.rules[key] = v
	else:
		_set[key] = v


## A row «name ‹ value ›» choosing setting `key` among `options` (the file's value among
## them, in its place, when it is none of them), each shown by `word`.
func _pick(page: VBoxContainer, rows: ChoiceRows, caption: String, key: String, options: Array, word: Callable) -> void:
	var list := options.duplicate()
	var now: Variant = _value(key)
	if not _has(list, now):
		list.append(now)
		if not now is String:
			list.sort()
	rows.add(page, caption, list.map(word), func() -> int: return _find(list, _value(key)),
		func(i: int) -> void: _put(key, list[i]), {"stop": true})


## Where `v` is in `list`, numbers compared as numbers (the file gives 40.0 for 40).
static func _find(list: Array, v: Variant) -> int:
	for i in list.size():
		if typeof(v) == typeof(list[i]) and v == list[i]:
			return i
		if (v is int or v is float) and (list[i] is int or list[i] is float) and is_equal_approx(float(v), float(list[i])):
			return i
	return -1


static func _has(list: Array, v: Variant) -> bool:
	return _find(list, v) >= 0


## A switch for setting `key`.
func _check(page: VBoxContainer, caption: String, key: String, tip: String) -> void:
	var c := Kit.check(caption, bool(_value(key)), WIDTH, ROW_H)
	c.tooltip_text = tip
	c.toggled.connect(func(on: bool) -> void: _put(key, on))
	page.add_child(c)
	_checks[key] = c


## «По умолчанию» (second tap): the settings of the tab back to the server's defaults;
## the world, the name, the password and the tunnel stay.
func _defaults() -> void:
	var d: Dictionary = game.LocalHost.server_settings(false)
	for k in ["max_players", "autosave", "day_minutes", "real_weather"]:
		_set[k] = d[k]
	_set.rules = d.rules
	_port.text = str(d.port)
	for k: String in _checks:
		_checks[k].set_pressed_no_signal(bool(_value(k)))
	_rows[1].refresh()


## The tabs `names` joined as one, a button tall, over the rows (TabRow.tabs), and a
## page of rows for each.
func _make_tabs(names: Array) -> void:
	var parts := []
	for i in names.size():
		parts.append([names[i], "", show_tab.bind(i)])
	_tabs = TabRow.tabs(parts, ROW_H)
	_tabs.custom_minimum_size.x = WIDTH
	for b: Button in _tabs.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	box.add_child(_scroll)
	for i in names.size():
		_pages.append(Kit.column(6))
		_box.add_child(_pages[i])


## Shows tab `i` (before it runs: 0 «Создание», 1 «Настройки»; while it runs: 0 «Сервер»,
## 1 «Доступ»), its tab lit, its rows from the top.
func show_tab(i: int) -> void:
	_tab = i
	for j in _pages.size():
		_pages[j].visible = j == i
		TabRow.light(_tabs.get_child(j), j == i)
	_choices = _rows[i]
	_choices.scroll = _scroll
	_scroll.scroll_vertical = 0
	fit.call_deferred()


static func _count(n: Variant) -> String:
	return str(int(n))


static func _seconds(n: Variant) -> String:
	var s := int(n)
	return Lang.f("[min]", [s / 60]) if s >= 60 and s % 60 == 0 else Lang.f("[s]", [s])


static func _minutes(n: Variant) -> String:
	var m := int(n)
	if m == 0:
		return "[no_n2]"
	return Lang.f("[h]", [m / 60]) if m >= 120 and m % 60 == 0 else Lang.f("[min]", [m])


static func _hours(n: Variant) -> String:
	var h := roundi(float(n))
	return Lang.f("[h]", [h])


## A row with `caption` on its left, on `page`.
func _row(page: VBoxContainer, rows: ChoiceRows, caption: String) -> HBoxContainer:
	var row := Kit.row(4)
	var l := rows.name_label(caption)
	l.custom_minimum_size.y = ROW_H
	row.add_child(l)
	page.add_child(row)
	rows.add_custom(l)
	return row


func _field(page: VBoxContainer, rows: ChoiceRows, caption: String, text: String) -> LineEdit:
	var row := _row(page, rows, caption)
	var f := Kit.field("", WIDTH - rows.name_width - 4, 0, ROW_H)
	f.text = text
	f.text_submitted.connect(func(_t: String) -> void: f.release_focus())
	row.add_child(f)
	return f


## A button of the window: in its rows (`in_rows`) or for the caller to place.
func _button(text: String, action: Callable, accent := false, in_rows := true) -> Button:
	var b: Button = (Kit.accent_button if accent else Kit.button).call(text, action, WIDTH, ROW_H + 4)
	if in_rows:
		(_into if _into != null else _box).add_child(b)
	return b


## The words for world `w` of the list.
func _world_title(w: Dictionary) -> String:
	if w.get("new", false):
		return Lang.f("[new]", [w.seed])
	if w.seed == WorldStore.TEST_SEED:
		return Lang.f("[test_day]", [w.day])
	return Lang.f("[day_n3]", [w.seed, w.day])


## The settings as Config takes them, and the host's name; "" in "why" when they do.
func settings() -> Dictionary:
	var port := int(_port.text) if _port.text.is_valid_int() else 0
	var out := {"title": _title.text.strip_edges(), "port": port, "max_players": int(_set.max_players),
		"password": _password.text, "tunnel": _tunnel.button_pressed, "real_weather": bool(_set.real_weather),
		"autosave": float(_set.autosave), "day_minutes": float(_set.day_minutes), "rules": _set.rules.duplicate(),
		"player": ServerList.player_name() if ServerList.player_name() != "" else "[host]"}
	if _worlds.is_empty():
		out.world = ""
		out.seed_value = int(game.settings.values.world_seed)
		out.settings = game.settings.world_options()
	else:
		out.world = str(_worlds[_world].dir)
		out.seed_value = int(_worlds[_world].seed)
		out.settings = _worlds[_world].settings
	out.why = ""
	if port < 1024 or port > 65535:
		out.why = "[the_port_is_a_number_n2]"
	elif out.title == "":
		out.why = "[enter_a_title]"
	return out


func _start() -> void:
	var s := settings()
	if s.why != "":
		if not s.port in range(1024, 65536):
			show_tab(1)
			_port.grab_focus()
		_error.text = s.why
		_error.visible = true
		fit.call_deferred()
		return
	s.erase("why")
	print("host: %s" % [s])
	game.host_server(s)


# --- While it runs ---------------------------------------------------------------

func _build_running() -> void:
	var node: Node = game.hosted
	_make_tabs(["[server_name]", "[access]"])
	_rows = [_choices, ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, ARROW)]
	var p := _pages[0]
	_into = p
	_state = UiStyle.label("", UiStyle.INK)
	p.add_child(_state)
	p.add_child(Kit.caption("[address_for_friends_on_the]"))
	var addresses := addresses_of(node.config.port)
	for a: String in addresses:
		p.add_child(UiStyle.label(a, UiStyle.ACCENT))
	if addresses.is_empty():
		p.add_child(Kit.caption("[no_network_this_computer_only]"))
	else:
		var copy := _button("[copy_the_address]", func() -> void:
			DisplayServer.clipboard_set(addresses[0]))
		copy.tooltip_text = addresses[0]
	if node.tunnel != null:
		p.add_child(Kit.caption("[from_the_internet]"))
		_tunnel_label = Kit.note("", WIDTH, UiStyle.ACCENT)
		p.add_child(_tunnel_label)
		_tunnel_copy = _button("[copy_the_link]", func() -> void:
			DisplayServer.clipboard_set(node.tunnel.link()))
	p.add_child(Kit.caption("[players]"))
	_people = Kit.column(4)
	p.add_child(_people)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiStyle.well())
	p.add_child(well)
	_log_scroll = ScrollContainer.new()
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.custom_minimum_size = Vector2(WIDTH - 2 * UiStyle.WELL_PAD,
		LOG_TALL * UiStyle.font().get_height(UiStyle.FONT_SIZE))
	well.add_child(_log_scroll)
	_log = UiStyle.label("", UiStyle.MUTED)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(WIDTH - 2 * UiStyle.WELL_PAD - UiStyle.SCROLL_BAR - 2, 0)
	_log_scroll.add_child(_log)
	# The host's commands, as in the terminal; what they answer goes into the log.
	var command := Kit.field("[command_help_the_list]", WIDTH, 0, ROW_H)
	command.text_submitted.connect(func(line: String) -> void:
		if line.strip_edges() == "":
			return
		node.say("> " + line)
		for out in node.command(line).split("\n", false):
			node.say(out)
		command.clear()
		_clock = 0.0)
	p.add_child(command)
	_build_access(_pages[1])
	box.add_child(_button("[play]", play.emit, true, false))
	_stop = _button("[stop_the_server]", Callable(), false, false)
	box.add_child(_stop)
	_asks.paint = _paint_stop
	_asks.guard(_stop, _stop_server)
	box.add_child(_button("[back]", back, false, false))
	show_tab(0)
	_refresh()


## «Доступ»: «Только по списку», the names on the list with «Убрать» and a field to add
## one, the names blocked with «Разбанить» and a field to block one: the server's
## commands whitelist, ban and unban (Server.access, kept in the world's save).
func _build_access(p: VBoxContainer) -> void:
	_listed_only = Kit.check("[list_only]", false, WIDTH, ROW_H)
	_listed_only.toggled.connect(func(on: bool) -> void: _run("whitelist " + ("on" if on else "off")))
	p.add_child(_listed_only)
	p.add_child(Kit.note("[list_only_note]", WIDTH))
	p.add_child(Kit.caption("[on_the_list]"))
	_listed = Kit.column(4)
	p.add_child(_listed)
	p.add_child(_name_field("[player_name_hint]", "[add_name]", func(n: String) -> void: _run("whitelist add " + n)))
	p.add_child(Kit.caption("[banned]"))
	_banned = Kit.column(4)
	p.add_child(_banned)
	p.add_child(_name_field("[player_name_hint]", "[ban_name]", func(n: String) -> void: _run("ban " + n)))


## A field for a player's name with a button that gives the name to `action`.
func _name_field(hint: String, text: String, action: Callable) -> HBoxContainer:
	var row := Kit.row(4)
	var f := Kit.field(hint, WIDTH - NAME_BUTTON - 4, 32, ROW_H)
	var give := func() -> void:
		var n := f.text.strip_edges()
		if n != "":
			action.call(n)
			f.clear()
		f.release_focus()
	f.text_submitted.connect(func(_t: String) -> void: give.call())
	row.add_child(f)
	row.add_child(Kit.button(text, give, NAME_BUTTON, ROW_H))
	return row


## Runs the host's command `line` as the field under the log does: it and its answer
## go into the log, and the window shows what it changed at once.
func _run(line: String) -> void:
	var node: Node = game.hosted
	if node == null:
		return
	node.say("> " + line)
	for out in node.command(line).split("\n", false):
		node.say(out)
	_clock = 0.0
	_refresh()


## Names under a caption, each with a button doing `action` with it; «никого» for none.
func _fill_names(column: VBoxContainer, names: Array, text: String, action: Callable) -> void:
	for c in column.get_children():
		column.remove_child(c)
		c.queue_free()
	if names.is_empty():
		column.add_child(Kit.caption("[nobody_listed]"))
	for n: String in names:
		var row := Kit.row(4)
		var l := UiStyle.label(n)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.custom_minimum_size = Vector2(WIDTH - NAME_BUTTON - 4, ROW_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		row.add_child(l)
		row.add_child(Kit.button(text, func() -> void: action.call(n), NAME_BUTTON, ROW_H))
		column.add_child(row)


## The addresses of this computer in its networks, as a friend there types them.
static func addresses_of(port: int) -> Array[String]:
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append("ws://%s:%d" % [ip, port])
	out.sort()
	return out


## «Остановить сервер» waiting for its second tap: red, asking.
func _paint_stop(b: Button, on: bool) -> void:
	UiStyle.arm(b, on)
	b.text = "[stop_it_for_sure]" if on else "[stop_the_server]"


## Stops the server (on the second tap).
func _stop_server() -> void:
	_stop.disabled = true
	_stop.text = "[stopping]"
	game.stop_server()


func _process(delta: float) -> void:
	if _state == null or not running():
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = REFRESH
		_refresh()


## The port, the players and the log as the server has them now.
func _refresh() -> void:
	var node: Node = game.hosted
	if node == null or node.server == null:
		return
	var net = node.server
	_state.text = Lang.f("[port_players_of]", [node.config.port, net.online(), node.config.max_players,
		"[password_n2]" if node.config.password != "" else ""])
	if _tunnel_label != null:
		var t = node.tunnel
		var said: String = t.url if t.url != "" else ("[still_starting]" if t.failed == "" else t.failed)
		if said != _tunnel_label.text:
			_tunnel_label.text = said
			_tunnel_label.add_theme_color_override("font_color", UiStyle.ACCENT if t.url != "" else (UiStyle.MUTED if t.failed == "" else UiStyle.DANGER))
			_tunnel_copy.visible = t.url != ""
			_tunnel_copy.tooltip_text = t.link()
			fit.call_deferred()
	var people := []
	for a in net.players():
		people.append([a.name, a.id, a.peer != null])
	if people != _shown_people:
		_shown_people = people
		for c in _people.get_children():
			c.queue_free()
			_people.remove_child(c)
		if people.is_empty():
			_people.add_child(Kit.caption("[nobody_yet]"))
		for p: Array in people:
			var row := Kit.row(4)
			var l := UiStyle.label("%s%s" % [p[0], "" if p[2] else "[no_connection]"])
			l.custom_minimum_size = Vector2(WIDTH - 2 * PLAYER_BUTTON - 8, ROW_H)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.clip_text = true
			row.add_child(l)
			var id: int = p[1]
			row.add_child(Kit.button("[kick]", _run.bind("kick %d" % id), PLAYER_BUTTON, ROW_H))
			row.add_child(_bans.guard(Kit.button("[ban_player]", Callable(), PLAYER_BUTTON, ROW_H), _run.bind("ban %d" % id)))
			_people.add_child(row)
		fit.call_deferred()
	var acc: Dictionary = net.access
	var blocked: Array = acc.banned_names.duplicate()
	for key in acc.banned_keys:
		var n := str(acc.banned_keys[key]).to_lower()
		if not n in blocked:
			blocked.append(n)
	var shown := [acc.listed_only, acc.listed.duplicate(), blocked]
	if shown != _shown_access:
		_shown_access = shown
		_listed_only.set_pressed_no_signal(acc.listed_only)
		_fill_names(_listed, acc.listed, "[take_off_list]", func(n: String) -> void: _run("whitelist remove " + n))
		_fill_names(_banned, blocked, "[unban]", func(n: String) -> void: _run("unban " + n))
		fit.call_deferred()
	var lines: Array = node.log_lines.slice(-LOG_SHOWN)
	var text := "\n".join(lines.map(func(t: String) -> String: return t.get_slice("] ", 1)))
	if text != _log.text:
		_log.text = text
		_to_newest.call_deferred()


## The log's well scrolled to its last line.
func _to_newest() -> void:
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# --- Common ----------------------------------------------------------------------

## As tall as its rows, or as the screen lets it: then the rows scroll, the bar's room
## beside them (none, and no bar, unless the rows need it).
func layout(screen: Vector2) -> void:
	UiStyle.bar_room(_room, false)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = 0.0
	var rows := _box.get_combined_minimum_size().y
	panel.reset_size()
	var s := panel.size
	if s.y + 2 * MARGIN > screen.y:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.custom_minimum_size.y = maxf(rows - (s.y + 2 * MARGIN - screen.y), 60.0)
		UiStyle.bar_room(_room, true, _scroll)


func _unhandled_input(event: InputEvent) -> void:
	if _choices.key(event):
		get_viewport().set_input_as_handled()
		return
	super(event)
