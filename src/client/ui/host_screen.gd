extends Control
## «Создать сервер» (plan/architecture/server.md, «Меню и экраны»; on a computer): the
## window of the server made in the game (Main.hosted, LocalHost.host). Before it runs:
## the world (one of the saved ones, ‹ › go through them, the one played last first),
## the server's name, its port, a password, how many players it takes and «Доступ из
## интернета» (a Cloudflare quick tunnel, Tunnel; needs cloudflared); «Запустить
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
const TestGround := preload("res://src/shared/world/test_ground.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const ServerList := preload("res://src/client/net/server_list.gd")

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
## Players a server may be set to take.
const PLAYER_COUNTS := [2, 4, 8, 16, 32]

signal cancelled
signal play

var game
var _panel: PanelContainer
var _box: VBoxContainer
## The saved worlds to choose from ({dir, seed, settings, day, …}), the one chosen.
var _worlds: Array = []
var _world := 0
var _world_label: Label
var _title: LineEdit
var _port: LineEdit
var _password: LineEdit
var _tunnel: CheckButton
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
	_panel.add_child(_box)
	var title := UiStyle.label("Сервер работает" if running() else "Создать сервер", UiStyle.ACCENT)
	title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	if running():
		_build_running()
	else:
		_build_setup()
	get_parent().resized.connect(_fit)
	_fit()


## The server made here is running.
func running() -> bool:
	return game.hosted != null


# --- Before it runs --------------------------------------------------------------

func _build_setup() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://server.cfg")
	_worlds = WorldStore.list_worlds().filter(func(w: Dictionary) -> bool: return w.seed != TestGround.SEED)
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
	_tunnel = CheckButton.new()
	_tunnel.text = "Доступ из интернета"
	_tunnel.focus_mode = Control.FOCUS_NONE
	_tunnel.button_pressed = bool(cfg.get_value("server", "tunnel", false))
	_tunnel.custom_minimum_size = Vector2(WIDTH, ROW_H)
	_box.add_child(_tunnel)
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
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, UiStyle.button(state, true))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, UiStyle.DARK_INK)
	b.pressed.connect(action)
	_box.add_child(b)
	return b


func _show_world() -> void:
	if _worlds.is_empty():
		_world_label.text = "%d · новый" % game.settings.values.world_seed
		return
	var w: Dictionary = _worlds[_world]
	_world_label.text = "%d · день %d" % [w.seed, w.day]


func _step_players(step: int) -> void:
	var i := PLAYER_COUNTS.find(_players)
	i = clampi((i if i >= 0 else 2) + step, 0, PLAYER_COUNTS.size() - 1)
	_players = PLAYER_COUNTS[i]
	_players_label.text = str(_players)


## The settings as Config takes them, and the host's name; "" in "why" when they do.
func settings() -> Dictionary:
	var port := int(_port.text) if _port.text.is_valid_int() else 0
	var out := {"title": _title.text.strip_edges(), "port": port, "max_players": _players,
		"password": _password.text, "tunnel": _tunnel.button_pressed, "player": ServerList.player_name() if ServerList.player_name() != "" else "Хозяин"}
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
	if s.title == "":
		s.title = "Survivium"
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
	var style := UiStyle.slot()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, UiStyle.WELL_PAD)
	well.add_theme_stylebox_override("panel", style)
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
	_state.text = "порт %d · игроков %d из %d%s" % [node.config.port, net.online(), node.config.max_players,
		" · пароль" if node.config.password != "" else ""]
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
	_panel.reset_size()
	var s := _panel.size
	_panel.position = Vector2(floorf((screen.x - s.x) * 0.5),
		floorf((screen.y - s.y) * 0.5) if s.y + 2 * MARGIN <= screen.y else MARGIN)
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()
