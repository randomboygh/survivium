extends Node
## The server run from the terminal (plan/architecture/server.md, С3): the root of
## scenes/server.tscn, which main.gd changes to on `--server` before building anything
## of the client (`godot --headless --path . -- --server [--port N] [--world <folder>]
## [--seed N] [--players N] [--password <word>] [--config <file>] [--tunnel]`, see
## Config; with `--tunnel` it runs cloudflared beside it and logs the address friends
## join from the internet, Tunnel, С7). It opens
## the world the way the game does (a save under user://saves: the bundles it was made
## with, its materials, clock and things; else a new world of the seed and settings),
## makes the ground round the spawn and the camp there in a new world, lets the animals
## come, and listens (Server). The server's loop (src/server/runner.gd, never paused)
## ticks the session before each frame; then the connections are polled, the terminal's
## lines done (Console) and the events of the tick sent. The animals come when the
## first player does (Server). The world and the players are saved (ServerStore, С4)
## every Config.autosave seconds, when a character leaves and on stop.
## The same node is the server made from the menu on a computer («Создать сервер», С5.2;
## `hosted`, made by LocalHost.host): its settings are given, not read; it is started
## at once (`start`), lives under the tree's root over the game's restarts, does not
## cap the frames nor read the terminal, goes on while the game is paused, and keeps
## the last lines of its log for the window; once stopped it says `stopped`.

const Config := preload("res://src/server/config.gd")
const Console := preload("res://src/server/console.gd")
const Server := preload("res://src/server/server.gd")
const Runner := preload("res://src/server/runner.gd")
const ServerStore := preload("res://src/server/server_store.gd")
const Tunnel := preload("res://src/server/tunnel.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Session := preload("res://src/shared/game/session.gd")
const Clock := preload("res://src/shared/game/clock.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Rules := preload("res://src/shared/game/rules.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
## The test world's plan, compiled only for the test world (WorldStore.TEST_SEED).
const TEST_GROUND := "res://src/shared/world/test_ground.gd"
const Mods := preload("res://src/shared/content/mods.gd")
const Mat := preload("res://src/shared/content/materials.gd")

## Frames a second: the tick's steps, and the time the world is made in (Runner).
const FPS := 60
## Chunks each way round the spawn made before the server listens: the spawn is looked
## for within 24 cells of the guess (WorldGen.find_spawn).
const SPAWN_REACH := 2
## Seconds to wait for the connections to close after stop.
const STOP_WAIT := 1.0
## Lines of the log kept for the window.
const LOG_LINES := 60

## The server has stopped (the connections closed, the world saved).
signal stopped

## The settings; a test sets them before adding the node to the tree.
var config := Config.new()
var session: Session
var runner: Runner
var server: Server
var console: Console
var store: WorldStore
## The save, null with `--no-save`.
var saves: ServerStore
## The world's seed and WorldGen settings, and where the players start, in world units.
var seed_value := 0
var settings := {}
## The bundles the world is played with, in order (Mods.activate).
var mods: Array = []
var spawn := Vector3.ZERO
## The world had a save (its clock and things came from it).
var had_save := false
## The process ends once the server stopped (a test keeps it).
var quit_on_stop := true
## Made in the game from the menu (see the top).
var hosted := false
## Why it could not start, "" when it did (or has not tried).
var failed := ""
## The last lines of the log, the newest last.
var log_lines: Array[String] = []
## The tunnel from the internet (С7), null without `tunnel` in the settings.
var tunnel: Tunnel
var _started := false
var _stop_at := -1.0
var _meta := {}


func _ready() -> void:
	if hosted:
		process_mode = Node.PROCESS_MODE_ALWAYS
	if not _started and not start():
		get_tree().quit(1)


## Opens the world and listens; false (and `failed` says why) when it cannot.
func start() -> bool:
	_started = true
	if not hosted:
		Engine.max_fps = FPS
		config.read()
		config.take_args(OS.get_cmdline_user_args())
	say("Survivium, сборка %s, протокол %d" % [Protocol.build_version(), Protocol.VERSION])
	if not _open_world():
		failed = "Мир не открыть: " + (str(log_lines.back()).get_slice("] ", 1) if not log_lines.is_empty() else "")
		return false
	server = Server.new(session, config, {"seed": seed_value, "settings": settings, "mods": mods,
		"materials": Array(Mat.IDS), "spawn": spawn})
	if config.save:
		saves = ServerStore.new(store, session, {"seed": seed_value, "settings": settings, "mods": mods}, _meta)
		saves.every = config.autosave
		var left := saves.clean()
		if left > 0:
			say("сохранение было прервано: %d недописанных файлов убрано, мир — с прошлого сохранения" % left)
		server.store = saves
		server.load_access()
		server.next_id = saves.next_player()
	else:
		say("мир не сохраняется (--no-save)")
	if config.console and not hosted and OS.get_stdin_type() != OS.STD_HANDLE_INVALID:
		console = Console.new()
		console.start()
	var err := server.listen()
	if err != OK:
		say("не могу слушать порт %d (%s)" % [config.port, error_string(err)])
		failed = "Порт %d занят" % config.port
		server = null
		return false
	say("слушаю порт %d, игроков не больше %d%s" % [config.port, config.max_players,
		", вход по паролю" if config.password != "" else ""])
	if config.tunnel:
		open_tunnel()
	return true


## Starts the tunnel from the internet (Tunnel); its address comes a few seconds later.
func open_tunnel() -> void:
	if tunnel != null:
		return
	tunnel = Tunnel.new()
	if tunnel.start(config.port, config.cloudflared):
		say("туннель: запускаю %s…" % tunnel.program)
	else:
		say("туннель: " + tunnel.failed)


func close_tunnel() -> void:
	if tunnel != null:
		tunnel.stop()
		tunnel = null


## Opens the save or makes the world; false when the save cannot be read.
func _open_world() -> bool:
	store = WorldStore.new(config.world_path())
	var meta := {}
	seed_value = config.seed_value
	settings = config.settings.duplicate()
	if store.exists():
		meta = store.read_json(WorldStore.WORLD)
		if meta.get("format") != float(WorldStore.FORMAT) or not meta.get("seed") is float:
			say("сохранение %s не прочитать (формат %s, нужен %d)" % [store.dir, meta.get("format"), WorldStore.FORMAT])
			return false
		had_save = true
		_meta = meta
		seed_value = int(meta.seed)
		settings = {}
		for k: String in WorldGen.DEFAULT_SETTINGS:
			settings[k] = int(meta.get("settings", {}).get(k, WorldGen.DEFAULT_SETTINGS[k]))
		say("мир %s: %d чанков сохранено" % [store.dir, store.chunk_count()])
	elif config.world != "":
		say("мира %s нет" % store.dir)
		return false
	else:
		say("новый мир %d %s" % [seed_value, settings])
	mods = Mods.of_world(meta) if had_save else Mods.resolve(config.mods if not config.mods.is_empty() else Mods.all()).order
	for problem in Mods.activate(mods):
		say("контент: " + str(problem))
	var t0 := Time.get_ticks_msec()
	var maker: GDScript = load(TEST_GROUND) if seed_value == WorldStore.TEST_SEED else WorldGen
	var gen = maker.new(seed_value, 48, settings)
	gen.saved = store
	if had_save:
		gen.material_map = Mat.remap(WorldStore.materials_of(meta))
	var clock := Clock.new()
	if had_save and meta.get("sky") is Dictionary:
		clock.from_dict(meta.sky)
	var placed := Placed.new()
	placed.read_footprints()
	session = Session.new(gen.world, gen, clock, Rules.new(), placed)
	# The ground round the spawn, so the players start on it and the camp has a place.
	var guess: Vector3i = gen.spawn_guess
	var key := WorldData.chunk_key(guess.x, guess.z)
	for dz in range(-SPAWN_REACH, SPAWN_REACH + 1):
		for dx in range(-SPAWN_REACH, SPAWN_REACH + 1):
			session.make_chunk(key + Vector2i(dx, dz))
	var cell := WorldGen.find_spawn(gen.world, guess)
	spawn = (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * WorldData.CELL
	if had_save and meta.get("placed") is Array:
		placed.from_list(meta.placed)
	else:
		placed.start_camp(spawn)
		if gen.has_method("plan_things"):
			for t: Array in gen.plan_things():
				placed.put(t[0], t[1])
	runner = Runner.new(session)
	runner.pausable = false
	runner.playing = true
	add_child(runner)
	say("место старта %d, %d, %d; земля вокруг сделана за %d мс" % [cell.x, cell.y, cell.z, Time.get_ticks_msec() - t0])
	return true


func _process(delta: float) -> void:
	if server == null:
		return
	if console != null:
		for line in console.lines():
			var out := server.command(line)
			if out != "":
				print(out)
	server.poll()
	server.flush()
	if tunnel != null and tunnel.failed == "":
		if tunnel.poll():
			say("из интернета: %s" % tunnel.url)
			say("ссылка для друзей: %s" % tunnel.link())
		elif tunnel.failed != "":
			say("туннель: " + tunnel.failed)
	if saves != null and not server.stopping:
		saves.update(delta, server)
	for line in server.lines:
		say(line)
	server.lines.clear()
	if server.stopping:
		var now := Time.get_ticks_msec() / 1000.0
		if _stop_at < 0.0:
			_stop_at = now + STOP_WAIT
		if server.done() or now >= _stop_at:
			_quit()


## The world is saved when the window closes (a server made from the game's menu, which
## has a window) or the app is sent to the background: the autosave may be seconds away.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] \
			and saves != null and server != null and not server.stopping:
		saves.save(server)


func _exit_tree() -> void:
	close_tunnel()


func _quit() -> void:
	if console != null:
		console.stop()
	close_tunnel()
	say("сервер остановлен")
	set_process(false)
	stopped.emit()
	if quit_on_stop and not hosted:
		get_tree().quit()


## Does the host's command `line` as the terminal would; the words it printed.
func command(line: String) -> String:
	var out := server.command(line)
	if out != "":
		print(out)
	return out


## A line of the server's log, with the time.
func say(text: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), text]
	print(line)
	log_lines.append(line)
	if log_lines.size() > LOG_LINES:
		log_lines.pop_front()
