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
## gives a playtest server an hour more (PlaytestHost), and nothing says how it stands;
## `mod on`, `mod off`, `mod next` play with the test mod (TestMod: files put over the
## server's own, so the games that join have files to take, decision 189), without it,
## and with its next step (a reload the games in the world take).
## A bot is a process of the game where one can be started (a computer), else the
## server plays it itself (ServerBot: a server made on a phone).

const WorldStore := preload("res://src/shared/world/world_store.gd")
const Content := preload("res://src/shared/content/content.gd")
const TestMod := preload("res://src/server/test_mod.gd")
const ServerBot := preload("res://src/server/server_bot.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Server := preload("res://src/server/server.gd")

## Bots at most.
const MOST_BOTS := 5
## Worlds `worlds` names at most, the latest first.
const WORLDS_SHOWN := 12

## The server's scene (server_main.gd): its `server`, `config`, `say`, `renew`.
var main: Node
## The bots running, the newest last: [number, process id, null] each, or [number, 0,
## ServerBot] for one the server plays itself.
var bots: Array = []
## Bots to start again once a new world is up.
var _respawn := 0
## The step of the test mod the server plays with, 0 without it.
var mod_step := 0


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
		_end(b)
	bots.clear()


## Stops bot `b` (an entry of `bots`).
func _end(b: Array) -> void:
	if b[2] != null:
		if main.server != null:
			main.server.remove_bot(b[2].account)
	elif b[1] > 0:
		OS.kill(b[1])


## The bots the server plays itself take their steps.
func _process(delta: float) -> void:
	for b: Array in bots:
		if b[2] != null:
			b[2].step(delta)


## «/test `rest`» from one of `role`: the answer to the one who sent it.
func command(rest: String, role: int) -> String:
	var playtest: bool = main.config.playtest
	if not playtest and role < Server.ROLE_HOST:
		return "«test» is only for the server's host, or on a test server"
	var words := rest.strip_edges().split(" ", false)
	var first := words[0] if words.size() > 0 else ""
	var arg := words[1] if words.size() > 1 else ""
	# Another world or other mods change the server under everyone, as stopping it does:
	# off a playtest server they are the owner's.
	if first in ["world", "new", "mod"] and not playtest and role < Server.ROLE_OWNER:
		return "Only the server's owner can change its world or mods"
	match first:
		"bot+":
			if bots.size() >= MOST_BOTS:
				return "There are %d bots already, no more" % bots.size()
			var n := add_bot()
			return "Bot%d is coming to the server" % n if n > 0 else "The bot could not start"
		"bot-":
			if bots.is_empty():
				return "There are no bots"
			var b: Array = bots.pop_back()
			_end(b)
			main.say("bot %d removed" % b[0])
			return "Bot%d left" % b[0]
		"hour":
			var host: Node = main.playtest_host
			if host == null:
				return "The server has no time limit"
			return host.extend()
		"stop":
			if not playtest and role < Server.ROLE_OWNER:
				return "Only the server's owner can stop it"
			main.say("server stopped by a player")
			main.server.stop()
			return "The server is stopping"
		"worlds":
			return worlds_text()
		"mod":
			return _mod(arg)
		"world":
			var w := find_world(arg)
			if w.is_empty():
				return "No such world: «%s»; test worlds — the list" % arg.left(40)
			return _renew(int(w.seed), str(w.dir).get_file())
		"new":
			if arg == "test":
				return _renew(WorldStore.TEST_SEED, "")
			var seed_value := randi_range(1, 99999999)
			if arg != "":
				if not arg.is_valid_int() or arg.length() > 10:
					return "A world's seed is a number"
				seed_value = int(arg)
			return _renew(seed_value, "")
		"":
			var host: Node = main.playtest_host
			return "%d bots, world %d%s" % [bots.size(), main.seed_value, ", " + host.left_text() if host != null else ""]
	return "test bot+ | bot- | worlds | world <name> | new [seed] | new test | mod on|off|next | stop" + (" | hour" if playtest else "")


## «/test mod `what`»: the server plays with the test mod, without it, or with its next
## step; everyone in the world is given the mod's item (and loses it with the mod).
func _mod(what: String) -> String:
	if main.hosted:
		return "The test mod is only for a server run on its own, not one made in the game"
	match what:
		"on":
			if mod_step > 0:
				return "The test mod is on already (step %d)" % mod_step
			mod_step = 1
		"off":
			if mod_step == 0:
				return "The test mod is off already"
			mod_step = 0
		"next":
			if mod_step == 0:
				return "The test mod is off: test mod on"
			mod_step += 1
		_:
			return "test mod on | off | next (now: %s)" % ("step %d" % mod_step if mod_step > 0 else "off")
	var players: Array = main.server.players()
	if mod_step == 0:
		for a in players:
			a.link.who.inventory.remove(TestMod.ITEM, 1 << 20)
	var answer: String = main.server.mods_over(TestMod.write(Content.ROOT, mod_step) if mod_step > 0 else {})
	if mod_step > 0:
		for a in players:
			a.link.who.give(TestMod.ITEM, 1)
	main.say("test mod: %s" % ("step %d" % mod_step if mod_step > 0 else "off"))
	return ("The test mod is on, step %d" % mod_step if mod_step > 0 else "The test mod is off") + "; " + answer


## Plays the world of `seed_value` (or the saved one in the folder `folder`, a name
## under WorldStore.root) in place of this one; the answer.
func _renew(seed_value: int, folder: String) -> String:
	_respawn = bots.size()
	stop_bots()
	if not main.renew(seed_value, folder):
		_respawn = 0
		return "The world cannot be changed here"
	var name := "test world" if seed_value == WorldStore.TEST_SEED else "world %d" % seed_value
	return "The server is moving to %s: the game will come in again by itself" % name


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
		return "No saved worlds; test new — a new world"
	var out: Array[String] = ["Worlds (test world <name>):"]
	for w: Dictionary in all.slice(0, WORLDS_SHOWN):
		var now := " ← now" if int(w.seed) == main.seed_value else ""
		out.append("  %s — day %d%s" % [str(w.dir).get_file(), int(w.day), now])
	return "\n".join(out)


## The new world is up (server_main.renew): the new server takes «/test», and the bots
## come again.
func _on_renewed() -> void:
	main.server.test_command = command
	for i in _respawn:
		add_bot()
	_respawn = 0


## Whether a bot can be a process of this game: not in the browser, nor on a phone.
static func can_start_bots() -> bool:
	return OS.get_name() in ["Linux", "Windows", "macOS", "FreeBSD"]


## Starts a bot with the first number no bot running has; its number, 0 when it did not
## start. On Linux it runs below the server's priority with its log in Config.bot_logs;
## where no process can be started, or `here` asks, the server plays it itself (ServerBot).
func add_bot(here := false) -> int:
	var n := 1
	while bots.any(func(b: Array) -> bool: return b[0] == n):
		n += 1
	if here or not can_start_bots():
		if main.server == null or main.server.session == null:
			return 0
		var a = main.server.add_bot("Bot%d" % n)
		bots.append([n, 0, ServerBot.new(a, main.server.session)])
		main.say("bot %d plays on the server itself" % n)
		return n
	var game := [OS.get_executable_path(), "--headless"]
	# From the project's folder (the editor's binary) the game needs its path; an export
	# carries it.
	if not OS.has_feature("template"):
		game += ["--path", ProjectSettings.globalize_path("res://")]
	game += ["--", "--join", "ws://localhost:%d" % main.config.port, "--name", "Bot%d" % n, "--bot"]
	# The password goes by the environment the bot is started with, never its command line
	# (any user of the machine can read that).
	OS.set_environment(Protocol.PASSWORD_ENV, main.config.password)
	var pid := -1
	if OS.get_name() == "Linux":
		var dir: String = main.config.bot_logs if main.config.bot_logs != "" else ProjectSettings.globalize_path("user://")
		var log_path := dir.path_join("bot%d.log" % n)
		pid = OS.create_process("sh", ['-c', 'exec nice -n 10 "$@" >"$0" 2>&1 </dev/null', log_path] + game)
	else:
		pid = OS.create_process(game[0], game.slice(1))
	OS.unset_environment(Protocol.PASSWORD_ENV)
	if pid <= 0:
		main.say("bot %d did not start" % n)
		return 0
	bots.append([n, pid, null])
	main.say("bot %d started (process %d)" % [n, pid])
	return n
