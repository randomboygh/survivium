extends Control
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
## running. It covers the whole screen over a shade of the world behind. `game` is the
## Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const ServerList := preload("res://src/client/net/server_list.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const TextField := preload("res://src/client/ui/text_field.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")

const WIDTH := 300
const NAME_WIDTH := 80
const ROW_H := 30
const ARROW := 30
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)
const MARGIN := 8
## Lines of the server's log kept in its well (scrolled to the newest), the well's
## height in lines, and seconds between two looks at the server.
const LOG_SHOWN := 20
const LOG_TALL := 5
const REFRESH := 0.5
## Where players may fight players (Config.pvp), and their words.
const PVP_MODES := ["off", "land", "all"]
const PVP_TITLES := ["выключен", "по территориям", "везде"]
## Players a server may be set to take.
const PLAYER_COUNTS := [2, 4, 8, 16, 32]

signal cancelled
signal play

var game
var _panel: PanelContainer
## Holds the window's rows: it scrolls when they are taller than the screen (a landscape
## phone, a large interface).
var _scroll: ScrollContainer
## Between the scroll and the rows: room for its bar while it scrolls.
var _room: MarginContainer
var _box: VBoxContainer
## The saved worlds to choose from ({dir, seed, settings, day, …}), the one chosen.
var _worlds: Array = []
var _world := 0
var _world_label: Label
var _title: LineEdit
var _port: LineEdit
var _password: LineEdit
## Where players may fight players (Config.pvp): a place in PVP_MODES, and its label.
var _pvp := 1
var _pvp_label: Label
var _tunnel: CheckButton
## The world's weather is the real one where the computer is (Config.real_weather).
var _weather: CheckButton
## The tunnel's state and its link's button while the server runs.
var _tunnel_label: Label
var _tunnel_copy: Button
var _players := 2
var _players_label: Label
var _error: Label
## While the server runs: its state, its players and its log, looked at every REFRESH.
var _state: Label
var _people: VBoxContainer
var _log: Label
var _stop: Button
var _clock := 0.0
var _shown_people = null
var _log_scroll: ScrollContainer


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	DragScroll.attach(_scroll)
	_room = MarginContainer.new()
	_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_room)
	_room.add_child(_box)
	var title := UiStyle.label("Сервер работает" if running() else "Создать сервер", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	if running():
		_build_running()
	else:
		_build_setup()
	get_parent().resized.connect(_fit)
	# Rows shown or added later (an error, the players) fit the window again.
	_box.minimum_size_changed.connect(_fit, CONNECT_DEFERRED)
	_fit()


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
	var row := _row("Мир")
	_arrow(row, "prev", -1)
	_world_label = UiStyle.label()
	_world_label.custom_minimum_size = Vector2(WIDTH - NAME_WIDTH - 2 * ARROW - 8, ROW_H)
	_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_world_label.clip_text = true
	row.add_child(_world_label)
	_arrow(row, "next", 1)
	_title = _field("Название", str(cfg.get_value("server", "title", "Survivium")))
	_title.max_length = 32
	_port = _field("Порт", str(cfg.get_value("server", "port", Protocol.PORT)))
	_port.max_length = 5
	_port.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_password = _field("Пароль", str(cfg.get_value("server", "password", "")))
	_password.placeholder_text = "без пароля"
	_players = int(cfg.get_value("server", "players", 8))
	row = _row("Игроков")
	var fewer := _arrow_button(row, "prev")
	fewer.pressed.connect(_step_players.bind(-1))
	_players_label = UiStyle.label()
	_players_label.custom_minimum_size = Vector2(WIDTH - NAME_WIDTH - 2 * ARROW - 8, ROW_H)
	_players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_players_label)
	var more := _arrow_button(row, "next")
	more.pressed.connect(_step_players.bind(1))
	_pvp = PVP_MODES.find(str(cfg.get_value("rules", "pvp", "land")))
	row = _row("PvP")
	_arrow_button(row, "prev").pressed.connect(_step_pvp.bind(-1))
	_pvp_label = UiStyle.label()
	_pvp_label.custom_minimum_size = Vector2(WIDTH - NAME_WIDTH - 2 * ARROW - 8, ROW_H)
	_pvp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pvp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pvp_label.clip_text = true
	row.add_child(_pvp_label)
	_arrow_button(row, "next").pressed.connect(_step_pvp.bind(1))
	_tunnel = CheckButton.new()
	_tunnel.text = "Доступ из интернета"
	_tunnel.focus_mode = Control.FOCUS_NONE
	_tunnel.button_pressed = bool(cfg.get_value("server", "tunnel", false))
	_tunnel.custom_minimum_size = Vector2(WIDTH, ROW_H)
	_box.add_child(_tunnel)
	_weather = CheckButton.new()
	_weather.text = "Погода с улицы"
	_weather.tooltip_text = "Погода в мире — настоящая, там, где этот компьютер"
	_weather.focus_mode = Control.FOCUS_NONE
	_weather.button_pressed = bool(cfg.get_value("server", "real_weather", false))
	_weather.custom_minimum_size = Vector2(WIDTH, ROW_H)
	_box.add_child(_weather)
	var note := UiStyle.label("Игроки из домашней сети входят по адресу этого компьютера; "
		+ "из интернета — через туннель Cloudflare: нужна программа cloudflared рядом с игрой, "
		+ "аккаунт и роутер не нужны, адрес новый при каждом запуске.", UiStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(WIDTH, 0)
	_box.add_child(note)
	_error = UiStyle.label(game.host_error, UiStyle.DANGER)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size = Vector2(WIDTH, 0)
	_error.visible = game.host_error != ""
	_box.add_child(_error)
	_button("Запустить сервер", _start, true)
	_button("Назад", cancelled.emit)
	_show_world()
	_step_players(0)
	_step_pvp(0)


## A row with `caption` on its left.
func _row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var l := UiStyle.label(caption, UiStyle.MUTED)
	l.custom_minimum_size = Vector2(NAME_WIDTH, ROW_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_box.add_child(row)
	return row


func _field(caption: String, text: String) -> LineEdit:
	var row := _row(caption)
	var f := LineEdit.new()
	f.text = text
	f.custom_minimum_size = Vector2(WIDTH - NAME_WIDTH - 4, ROW_H)
	f.text_submitted.connect(func(_t: String) -> void: f.release_focus())
	TextField.fit(f)
	row.add_child(f)
	return f


func _arrow_button(row: Control, icon: String) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ARROW, ARROW)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(b)
	return b


func _arrow(row: Control, icon: String, step: int) -> void:
	_arrow_button(row, icon).pressed.connect(func() -> void:
		if not _worlds.is_empty():
			_world = posmod(_world + step, _worlds.size())
			_show_world())


func _button(text: String, action: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH, ROW_H + 4)
	if accent:
		UiStyle.accent(b)
	b.pressed.connect(action)
	_box.add_child(b)
	return b


func _show_world() -> void:
	if _worlds.is_empty():
		_world_label.text = Lang.f("%d · новый", [game.settings.values.world_seed])
		return
	var w: Dictionary = _worlds[_world]
	if w.get("new", false):
		_world_label.text = Lang.f("%d · новый", [w.seed])
		return
	if w.seed == WorldStore.TEST_SEED:
		_world_label.text = Lang.f("тестовый · день %d", [w.day])
		return
	_world_label.text = Lang.f("%d · день %d", [w.seed, w.day])


func _step_players(step: int) -> void:
	var i := PLAYER_COUNTS.find(_players)
	i = clampi((i if i >= 0 else 2) + step, 0, PLAYER_COUNTS.size() - 1)
	_players = PLAYER_COUNTS[i]
	_players_label.text = str(_players)


func _step_pvp(step: int) -> void:
	_pvp = posmod((_pvp if _pvp >= 0 else 1) + step, PVP_MODES.size())
	_pvp_label.text = PVP_TITLES[_pvp]


## The settings as Config takes them, and the host's name; "" in "why" when they do.
func settings() -> Dictionary:
	var port := int(_port.text) if _port.text.is_valid_int() else 0
	var out := {"title": _title.text.strip_edges(), "port": port, "max_players": _players,
		"password": _password.text, "tunnel": _tunnel.button_pressed, "real_weather": _weather.button_pressed, "pvp": PVP_MODES[_pvp], "player": ServerList.player_name() if ServerList.player_name() != "" else "Хозяин"}
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
		out.why = "Порт — число от 1024 до 65535"
	elif out.title == "":
		out.why = "Введите название"
	return out


func _start() -> void:
	var s := settings()
	if s.why != "":
		_error.text = s.why
		_error.visible = true
		_fit.call_deferred()
		return
	s.erase("why")
	print("host: %s" % [s])
	game.host_server(s)


# --- While it runs ---------------------------------------------------------------

func _build_running() -> void:
	var node: Node = game.hosted
	_state = UiStyle.label("", UiStyle.INK)
	_box.add_child(_state)
	var where := UiStyle.label("Адрес для друзей в домашней сети:", UiStyle.MUTED)
	_box.add_child(where)
	var addresses := addresses_of(node.config.port)
	for a: String in addresses:
		_box.add_child(UiStyle.label(a, UiStyle.ACCENT))
	if addresses.is_empty():
		_box.add_child(UiStyle.label("сети нет: только этот компьютер", UiStyle.MUTED))
	else:
		var copy := _button("Скопировать адрес", func() -> void:
			DisplayServer.clipboard_set(addresses[0]))
		copy.tooltip_text = addresses[0]
	if node.tunnel != null:
		_box.add_child(UiStyle.label("Из интернета:", UiStyle.MUTED))
		_tunnel_label = UiStyle.label("", UiStyle.ACCENT)
		_tunnel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tunnel_label.custom_minimum_size = Vector2(WIDTH, 0)
		_box.add_child(_tunnel_label)
		_tunnel_copy = _button("Скопировать ссылку", func() -> void:
			DisplayServer.clipboard_set(node.tunnel.link()))
	_box.add_child(UiStyle.label("Игроки", UiStyle.MUTED))
	_people = VBoxContainer.new()
	_people.add_theme_constant_override("separation", 4)
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
	var command := LineEdit.new()
	command.placeholder_text = "команда: help — список"
	command.custom_minimum_size = Vector2(WIDTH, ROW_H)
	command.text_submitted.connect(func(line: String) -> void:
		if line.strip_edges() == "":
			return
		node.say("> " + line)
		for out in node.command(line).split("\n", false):
			node.say(out)
		command.clear()
		_clock = 0.0)
	TextField.fit(command)
	_box.add_child(command)
	_button("Играть", play.emit, true)
	_stop = _button("Остановить сервер", _ask_stop)
	_button("Назад", cancelled.emit)
	_refresh()


## The addresses of this computer in its networks, as a friend there types them.
static func addresses_of(port: int) -> Array[String]:
	var out: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append("ws://%s:%d" % [ip, port])
	out.sort()
	return out


## The first tap asks, the second stops the server.
func _ask_stop() -> void:
	if _stop.text != "Точно остановить?":
		_stop.text = "Точно остановить?"
		UiStyle.arm(_stop, true)
		return
	_stop.disabled = true
	_stop.text = "Останавливается…"
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
	_state.text = Lang.f("порт %d · игроков %d из %d%s", [node.config.port, net.online(), node.config.max_players,
		" · пароль" if node.config.password != "" else ""])
	if _tunnel_label != null:
		var t = node.tunnel
		var said: String = t.url if t.url != "" else ("ещё запускается…" if t.failed == "" else t.failed)
		if said != _tunnel_label.text:
			_tunnel_label.text = said
			_tunnel_label.add_theme_color_override("font_color", UiStyle.ACCENT if t.url != "" else (UiStyle.MUTED if t.failed == "" else UiStyle.DANGER))
			_tunnel_copy.visible = t.url != ""
			_tunnel_copy.tooltip_text = t.link()
			_fit.call_deferred()
	var people := []
	for a in net.players():
		people.append([a.name, a.id, a.peer != null])
	if people != _shown_people:
		_shown_people = people
		for c in _people.get_children():
			c.queue_free()
			_people.remove_child(c)
		if people.is_empty():
			_people.add_child(UiStyle.label("пока никого", UiStyle.MUTED))
		for p: Array in people:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			var l := UiStyle.label("%s%s" % [p[0], "" if p[2] else " (нет связи)"])
			l.custom_minimum_size = Vector2(WIDTH - 100, ROW_H)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.clip_text = true
			row.add_child(l)
			var kick := Button.new()
			kick.text = "Выгнать"
			kick.focus_mode = Control.FOCUS_NONE
			kick.custom_minimum_size = Vector2(96, ROW_H)
			var id: int = p[1]
			kick.pressed.connect(func() -> void: node.command("kick %d" % id))
			row.add_child(kick)
			_people.add_child(row)
		_fit.call_deferred()
	var lines: Array = node.log_lines.slice(-LOG_SHOWN)
	var text := "\n".join(lines.map(func(t: String) -> String: return t.get_slice("] ", 1)))
	if text != _log.text:
		_log.text = text
		_to_newest.call_deferred()


## The log's well scrolled to its last line.
func _to_newest() -> void:
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# --- Common ----------------------------------------------------------------------

## The panel in the middle; at the top when it is taller than the screen.
func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	# As tall as its rows, or as the screen lets it: then the rows scroll.
	# No scrolling (and no bar) unless the rows need it.
	UiStyle.bar_room(_room, false)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = 0.0
	var rows := _box.get_combined_minimum_size().y
	_panel.reset_size()
	var s := _panel.size
	if s.y + 2 * MARGIN > screen.y:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.custom_minimum_size.y = maxf(rows - (s.y + 2 * MARGIN - screen.y), 60.0)
		UiStyle.bar_room(_room, true, _scroll)
		_panel.reset_size()
		s = _panel.size
	_panel.position = Vector2(floorf((screen.x - s.x) * 0.5), floorf(maxf((screen.y - s.y) * 0.5, MARGIN)))
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()
