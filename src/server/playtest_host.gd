extends Node
## The playtest server's own part (Config.playtest: .github/workflows/playtest.yml,
## docs/systems/network.md «Сервер для проверки»), a child of the server's scene: it
## starts the bots (games joined with `--bot`, src/client/input/bot.gd) as processes
## beside the server, below its priority, stops the server when its minutes are over,
## and does «/test …», which any player may send there (the buttons of «Тестирование»
## send it): `bot+` and `bot-` add a bot and take the last one away, `hour` gives the
## server an hour more (at most MOST_MINUTES from its start), `stop` stops it, `new`
## plays a new world of a random seed (`new test` the test world anew; server_main.renew:
## everyone comes in again, the bots too), and nothing says how it stands.

const WorldStore := preload("res://src/shared/world/world_store.gd")

## Bots at most, and minutes a server lives at most (the workflow's job ends at 320).
const MOST_BOTS := 5
const MOST_MINUTES := 300
const HOUR := 60
## Minutes before the end when the players are told.
const WARN := 5

## The server's scene (server_main.gd): its `server`, `config` and `say`.
var main: Node
## The bots running, the newest last: [number, process id] each.
var bots: Array = []
var _start := 0.0
var _end := 0.0
var _warned := false
var _clock := 0.0
## Bots to start again once a new world is up.
var _respawn := 0


func _init(m: Node) -> void:
	main = m


func _ready() -> void:
	_start = Time.get_unix_time_from_system()
	_end = _start + main.config.minutes * 60.0 if main.config.minutes > 0 else 0.0
	main.server.test_command = command
	main.renewed.connect(_on_renewed)
	for i in mini(main.config.bots, MOST_BOTS):
		add_bot()
	main.say("тестовый сервер: %s, ботов %d; «/test» — для всех" % [_left_text(), bots.size()])


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 1.0 or _end <= 0.0 or main.server.stopping:
		return
	_clock = 0.0
	var left := _end - Time.get_unix_time_from_system()
	if left <= 0.0:
		main.say("время тестового сервера вышло")
		main.server.stop()
	elif left <= WARN * 60.0 and not _warned:
		_warned = true
		_tell_all("Тестовый сервер остановится через %d мин" % ceili(left / 60.0))


func _exit_tree() -> void:
	for b: Array in bots:
		OS.kill(b[1])
	bots.clear()


## «/test `rest`»: the answer to the one who sent it.
func command(rest: String) -> String:
	match rest:
		"bot+":
			if bots.size() >= MOST_BOTS:
				return "Ботов уже %d, больше нельзя" % bots.size()
			var n := add_bot()
			return "Бот%d идёт на сервер" % n if n > 0 else "Бота не запустить"
		"bot-":
			if bots.is_empty():
				return "Ботов нет"
			var b: Array = bots.pop_back()
			OS.kill(b[1])
			main.say("бот %d убран" % b[0])
			return "Бот%d ушёл" % b[0]
		"hour":
			if _end <= 0.0:
				return "Сервер без срока"
			var most := _start + MOST_MINUTES * 60.0
			if _end >= most - 60.0:
				return "Дольше нельзя: %s" % _left_text()
			_end = minf(_end + HOUR * 60.0, most)
			_warned = false
			main.say("тестовый сервер продлён: " + _left_text())
			return "Продлено: " + _left_text()
		"stop":
			main.say("тестовый сервер остановлен игроком")
			main.server.stop()
			return "Сервер останавливается"
		"new", "new test":
			var seed_value := WorldStore.TEST_SEED if rest == "new test" else randi_range(1, 99999999)
			_respawn = bots.size()
			_exit_tree()
			if not main.renew(seed_value):
				return "Новый мир здесь не сделать"
			return "Новый мир %d: зайдите снова через минуту" % seed_value
		"":
			return "Ботов %d, %s" % [bots.size(), _left_text()]
	return "test bot+ | bot- | hour | stop | new | new test"


## The new world is up (server_main.renew): the new server takes «/test», and the bots
## come again.
func _on_renewed() -> void:
	main.server.test_command = command
	for i in _respawn:
		add_bot()
	_respawn = 0


## Starts a bot with the first number no bot running has; its number, 0 when it did not
## start. On Linux it runs below the server's priority with its log in Config.bot_logs.
func add_bot() -> int:
	var n := 1
	while bots.any(func(b: Array) -> bool: return b[0] == n):
		n += 1
	var game := [OS.get_executable_path(), "--headless", "--path", ProjectSettings.globalize_path("res://"), "--",
		"--join", "ws://localhost:%d" % main.config.port, "--name", "Бот%d" % n, "--bot"]
	var pid := -1
	if OS.get_name() == "Linux":
		var dir: String = main.config.bot_logs if main.config.bot_logs != "" else ProjectSettings.globalize_path("user://")
		var log_path := dir.path_join("bot%d.log" % n)
		pid = OS.create_process("sh", ['-c', 'exec nice -n 10 "$@" >"$0" 2>&1 </dev/null', log_path] + game)
	else:
		pid = OS.create_process(game[0], game.slice(1))
	if pid <= 0:
		main.say("бот %d не запустился" % n)
		return 0
	bots.append([n, pid])
	main.say("бот %d запущен (процесс %d)" % [n, pid])
	return n


## How long the server has left, in words.
func _left_text() -> String:
	if _end <= 0.0:
		return "без срока"
	return "осталось %d мин" % maxi(0, ceili((_end - Time.get_unix_time_from_system()) / 60.0))


func _tell_all(text: String) -> void:
	for key in main.server.accounts:
		main.server.accounts[key].link.hear(0, "", text)
