extends "res://src/client/ui/kit/window.gd"
## «Создать сервер» (plan/architecture/server.md, «Меню и экраны»; on a computer): the
## window of the server made in the game (Main.hosted, LocalHost.host). Before it runs:
## the world (one of the saved ones, ‹ › go through them, the one played last first; the
## test world always among them, a new one when none of the player's own is saved),
## the server's name, its port, a password, how many players it takes, where players
## may fight players («PvP»: выключен, по правам территорий, везде) and «Доступ из
## интернета» (a Cloudflare quick tunnel, Tunnel; needs cloudflared), «Погода с улицы»
## (the real weather where the computer is, RealWeather); «Запустить
## сервер» starts the game again with the server made and joined (Main.host_server),
## «Назад» (or Escape) says `cancelled`. While it runs: the port and the players, the
## addresses for friends in the home network (one is copied by «Скопировать адрес»), the
## address from the internet once the tunnel gives it («Скопировать ссылку»: the game's
## page that opens «Присоединиться» with it), the
## players with «Выгнать», the server's last lines and a field for the host's commands
## (Server.command: give, tp, ban, whitelist…); «Играть» says `play` (into its world),
## «Остановить сервер» asks again and stops it (Main.stop_server), «Назад» leaves it
## running. It covers the whole screen over a shade of the world behind (a window of the
## UI kit, its choices ChoiceRows, «Остановить сервер» a TwoTap). `game` is the Main node.

const ChoiceRows := preload("res://src/client/ui/kit/choice_rows.gd")
const TwoTap := preload("res://src/client/ui/kit/two_tap.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const ServerList := preload("res://src/client/net/server_list.gd")
const Lang := preload("res://src/shared/content/lang.gd")

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
## Players a server may be set to take.
const PLAYER_COUNTS := [2, 4, 8, 16, 32]

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
## The world, players and PvP rows.
var _choices := ChoiceRows.new(NAME_WIDTH, VALUE_WIDTH, ARROW)
var _title: LineEdit
var _port: LineEdit
var _password: LineEdit
## Where players may fight players (Config.pvp): a place in PVP_MODES.
var _pvp := 1
var _tunnel: CheckButton
## The world's weather is the real one where the computer is (Config.real_weather).
var _weather: CheckButton
## The tunnel's state and its link's button while the server runs.
var _tunnel_label: Label
var _tunnel_copy: Button
var _players := 8
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


func _init(g) -> void:
	game = g


func _ready() -> void:
	build()
	_box = Kit.column(6)
	_box.add_child(Kit.title("[server_running]" if running() else "[create_a_server]"))
	# The rows scroll when they are taller than the screen (layout), the bar's room
	# beside them only then.
	_room = MarginContainer.new()
	_room.add_child(_box)
	_scroll = Kit.scroll(_room, false)
	box.add_child(_scroll)
	if running():
		_build_running()
	else:
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
	_choices.add(_box, "[world_n3]", _worlds.map(_world_title), func() -> int: return _world,
		func(i: int) -> void: _world = i)
	_title = _field("[title]", str(cfg.get_value("server", "title", "Survivium")))
	_title.max_length = 32
	_port = _field("[port]", str(cfg.get_value("server", "port", Protocol.PORT)))
	_port.max_length = 5
	_port.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_password = _field("[password]", str(cfg.get_value("server", "password", "")))
	_password.placeholder_text = "[no_password]"
	_players = int(cfg.get_value("server", "players", 8))
	if not _players in PLAYER_COUNTS:
		_players = 8
	_choices.add(_box, "[players_max]", PLAYER_COUNTS.map(func(n: int) -> String: return str(n)),
		func() -> int: return PLAYER_COUNTS.find(_players),
		func(i: int) -> void: _players = PLAYER_COUNTS[i], {"stop": true})
	_pvp = maxi(PVP_MODES.find(str(cfg.get_value("rules", "pvp", "land"))), 0)
	_choices.add(_box, "PvP", PVP_TITLES, func() -> int: return _pvp, func(i: int) -> void: _pvp = i)
	_tunnel = Kit.check("[access_from_the_internet]", bool(cfg.get_value("server", "tunnel", false)), WIDTH, ROW_H)
	_box.add_child(_tunnel)
	_weather = Kit.check("[real_weather_outside]", bool(cfg.get_value("server", "real_weather", false)), WIDTH, ROW_H)
	_weather.tooltip_text = "[the_weather_in_the_world]"
	_box.add_child(_weather)
	_box.add_child(Kit.note("[players_from_the_home_network]", WIDTH))
	_error = Kit.note(game.host_error, WIDTH, UiStyle.DANGER)
	_error.visible = game.host_error != ""
	_box.add_child(_error)
	_button("[start_the_server]", _start, true)
	_button("[back]", back)
	_choices.refresh()


## A row with `caption` on its left.
func _row(caption: String) -> HBoxContainer:
	var row := Kit.row(4)
	var l := _choices.name_label(caption)
	l.custom_minimum_size.y = ROW_H
	row.add_child(l)
	_box.add_child(row)
	_choices.add_custom(l)
	return row


func _field(caption: String, text: String) -> LineEdit:
	var row := _row(caption)
	var f := Kit.field("", WIDTH - NAME_WIDTH - 4, 0, ROW_H)
	f.text = text
	f.text_submitted.connect(func(_t: String) -> void: f.release_focus())
	row.add_child(f)
	return f


func _button(text: String, action: Callable, accent := false) -> Button:
	var b: Button = (Kit.accent_button if accent else Kit.button).call(text, action, WIDTH, ROW_H + 4)
	_box.add_child(b)
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
	var out := {"title": _title.text.strip_edges(), "port": port, "max_players": _players,
		"password": _password.text, "tunnel": _tunnel.button_pressed, "real_weather": _weather.button_pressed, "pvp": PVP_MODES[_pvp], "player": ServerList.player_name() if ServerList.player_name() != "" else "[host]"}
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
		out.why = "[the_port_is_a_number]"
	elif out.title == "":
		out.why = "[enter_a_title]"
	return out


func _start() -> void:
	var s := settings()
	if s.why != "":
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
	_state = UiStyle.label("", UiStyle.INK)
	_box.add_child(_state)
	_box.add_child(Kit.caption("[address_for_friends_on_the]"))
	var addresses := addresses_of(node.config.port)
	for a: String in addresses:
		_box.add_child(UiStyle.label(a, UiStyle.ACCENT))
	if addresses.is_empty():
		_box.add_child(Kit.caption("[no_network_this_computer_only]"))
	else:
		var copy := _button("[copy_the_address]", func() -> void:
			DisplayServer.clipboard_set(addresses[0]))
		copy.tooltip_text = addresses[0]
	if node.tunnel != null:
		_box.add_child(Kit.caption("[from_the_internet]"))
		_tunnel_label = Kit.note("", WIDTH, UiStyle.ACCENT)
		_box.add_child(_tunnel_label)
		_tunnel_copy = _button("[copy_the_link]", func() -> void:
			DisplayServer.clipboard_set(node.tunnel.link()))
	_box.add_child(Kit.caption("[players]"))
	_people = Kit.column(4)
	_box.add_child(_people)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiStyle.well())
	_box.add_child(well)
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
	_box.add_child(command)
	_button("[play]", play.emit, true)
	_stop = _button("[stop_the_server]", Callable())
	_asks.paint = _paint_stop
	_asks.guard(_stop, _stop_server)
	_button("[back]", back)
	_refresh()


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
			l.custom_minimum_size = Vector2(WIDTH - 100, ROW_H)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.clip_text = true
			row.add_child(l)
			var id: int = p[1]
			row.add_child(Kit.button("[kick]", func() -> void: node.command("kick %d" % id), 96, ROW_H))
			_people.add_child(row)
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
