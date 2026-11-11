extends Node
## «/test …» on any server (the «Сервер» tab of «Тестирование» sends it; Server
## `test_command`), a child of the server's scene (server_main.gd): on a playtest server
## (Config.playtest) any player may send it, elsewhere only a host (Server.ROLE_HOST).
## `bot+` and `bot-` start a bot (a game joined with `--bot`, src/client/input/bot.gd) as
## a process beside the server, below its priority on Linux, and take the last one away
## (Config.bots start with the server); `worlds` lists the worlds saved where the server
## keeps them, `world <name>` plays one of them, `new [seed]` a new world, `new test` the
## test world (server_main.renew: the world is saved, everyone comes in again, the bots
## too); `stop` stops the server (on a playtest one anyone, elsewhere its owner), `hour`
## gives a playtest server an hour more (PlaytestHost), and nothing says how it stands.
## Bots need a computer: in the browser no process is started.

const WorldStore := preload("res://src/shared/world/world_store.gd")

## Bots at most.
const MOST_BOTS := 5
## Worlds `worlds` names at most, the latest first.
const WORLDS_SHOWN := 12
## Roles of Server (its enum), not loaded from here to keep this file apart.
const ROLE_HOST := 1
const ROLE_OWNER := 2

## The server's scene (server_main.gd): its `server`, `config`, `say`, `renew`.
var main: Node
## The bots running, the newest last: [number, process id] each.
var bots: Array = []
## Bots to start again once a new world is up.
var _respawn := 0


func _init(m: Node) -> void:
	main = m


func _ready() -> void:
	main.server.test_command = command
	main.renewed.connect(_on_renewed)
	for i in mini(main.config.bots, MOST_BOTS):
		add_bot()


func _exit_tree() -> void:
	stop_bots()


## Stops every bot.
func stop_bots() -> void:
	for b: Array in bots:
		OS.kill(b[1])
	bots.clear()


## «/test `rest`» from one of `role`: the answer to the one who sent it.
func command(rest: String, role: int) -> String:
	var playtest: bool = main.config.playtest
	if not playtest and role < ROLE_HOST:
		return "«test» — только для хозяина сервера или на тестовом сервере"
	var words := rest.strip_edges().split(" ", false)
	var first := words[0] if words.size() > 0 else ""
	var arg := words[1] if words.size() > 1 else ""
	match first:
		"bot+":
			if bots.size() >= MOST_BOTS:
				return "Ботов уже %d, больше нельзя" % bots.size()
			if not can_start_bots():
				return "Ботов запускает только сервер на компьютере"
			var n := add_bot()
			return "Бот%d идёт на сервер" % n if n > 0 else "Бота не запустить"
		"bot-":
			if bots.is_empty():
				return "Ботов нет"
			var b: Array = bots.pop_back()
			OS.kill(b[1])
			main.say("bot %d removed" % b[0])
			return "Бот%d ушёл" % b[0]
		"hour":
			var host: Node = main.playtest_host
			if host == null:
				return "Сервер без срока"
			return host.extend()
		"stop":
			if not playtest and role < ROLE_OWNER:
				return "Остановить сервер может только его владелец"
			main.say("server stopped by a player")
			main.server.stop()
			return "Сервер останавливается"
		"worlds":
			return worlds_text()
		"world":
			var w := find_world(arg)
			if w.is_empty():
				return "Нет такого мира: «%s»; test worlds — список" % arg.left(40)
			return _renew(int(w.seed), str(w.dir).get_file())
		"new":
			if arg == "test":
				return _renew(WorldStore.TEST_SEED, "")
			var seed_value := randi_range(1, 99999999)
			if arg != "":
				if not arg.is_valid_int() or arg.length() > 10:
					return "Зерно мира — число"
				seed_value = int(arg)
			return _renew(seed_value, "")
		"":
			var host: Node = main.playtest_host
			return "Ботов %d, мир %d%s" % [bots.size(), main.seed_value, ", " + host.left_text() if host != null else ""]
	return "test bot+ | bot- | worlds | world <имя> | new [зерно] | new test | stop" + (" | hour" if playtest else "")


## Plays the world of `seed_value` (or the saved one in the folder `folder`, a name
## under WorldStore.root) in place of this one; the answer.
func _renew(seed_value: int, folder: String) -> String:
	_respawn = bots.size()
	stop_bots()
	if not main.renew(seed_value, folder):
		_respawn = 0
		return "Мир здесь не сменить"
	var name := "тестовый мир" if seed_value == WorldStore.TEST_SEED else "мир %d" % seed_value
	return "Сервер переходит в %s: игра войдёт снова сама" % name


## The worlds saved where the server keeps them (WorldStore.root), the latest first.
static func saved_worlds() -> Array:
	return WorldStore.list_worlds()


## The saved world of the folder named `name` (only a name under WorldStore.root, never a
## path), or {}.
static func find_world(name: String) -> Dictionary:
	if name == "" or name.contains("/") or name.contains("\\") or name.contains(".."):
		return {}
	for w: Dictionary in saved_worlds():
		if str(w.dir).get_file() == name:
			return w
	return {}


func worlds_text() -> String:
	var all := saved_worlds()
	if all.is_empty():
		return "Сохранённых миров нет; test new — новый мир"
	var out: Array[String] = ["Миры (test world <имя>):"]
	for w: Dictionary in all.slice(0, WORLDS_SHOWN):
		var now := " ← сейчас" if int(w.seed) == main.seed_value else ""
		out.append("  %s — день %d%s" % [str(w.dir).get_file(), int(w.day), now])
	return "\n".join(out)


## The new world is up (server_main.renew): the new server takes «/test», and the bots
## come again.
func _on_renewed() -> void:
	main.server.test_command = command
	for i in _respawn:
		add_bot()
	_respawn = 0


## A bot is a process of this game: not in the browser, nor on a phone.
static func can_start_bots() -> bool:
	return OS.get_name() in ["Linux", "Windows", "macOS", "FreeBSD"]


## Starts a bot with the first number no bot running has; its number, 0 when it did not
## start. On Linux it runs below the server's priority with its log in Config.bot_logs.
func add_bot() -> int:
	if not can_start_bots():
		return 0
	var n := 1
	while bots.any(func(b: Array) -> bool: return b[0] == n):
		n += 1
	var game := [OS.get_executable_path(), "--headless"]
	# From the project's folder (the editor's binary) the game needs its path; an export
	# carries it.
	if not OS.has_feature("template"):
		game += ["--path", ProjectSettings.globalize_path("res://")]
	game += ["--", "--join", "ws://localhost:%d" % main.config.port, "--name", "Бот%d" % n, "--bot"]
	if main.config.password != "":
		game += ["--password", main.config.password]
	var pid := -1
	if OS.get_name() == "Linux":
		var dir: String = main.config.bot_logs if main.config.bot_logs != "" else ProjectSettings.globalize_path("user://")
		var log_path := dir.path_join("bot%d.log" % n)
		pid = OS.create_process("sh", ['-c', 'exec nice -n 10 "$@" >"$0" 2>&1 </dev/null', log_path] + game)
	else:
		pid = OS.create_process(game[0], game.slice(1))
	if pid <= 0:
		main.say("bot %d did not start" % n)
		return 0
	bots.append([n, pid])
	main.say("bot %d started (process %d)" % [n, pid])
	return n
