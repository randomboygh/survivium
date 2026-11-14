extends RefCounted
## The game's way onto a server (С3.2, С5.2, decisions 153 and 189), kept apart from the
## scene Main builds: which server to join and as whom (`join`, set by «Присоединиться»,
## `--join` or a test), the socket to it and its welcome, why joining failed, the server
## made here from the menu (`hosted`), the server's mods' files taken before the game is
## let in (ModFetch) and joining again a server that goes over to another world. Joining,
## leaving, hosting and other mods all start the scene again (Main.restart): what must
## live over that restart is static here, the rest belongs to the scene's own link
## (`game.link`). Main asks it in order: start_hosting and read_join before anything is
## built, world_mods and use_mods for the bundles, open for the socket, wait_welcome
## while the loading screen shows.

const Socket := preload("res://src/client/net/socket.gd")
const ServerList := preload("res://src/client/net/server_list.gd")
const LocalHost := preload("res://src/client/net/local_host.gd")
const ModFetch := preload("res://src/client/net/mod_fetch.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")
const Content := preload("res://src/shared/content/content.gd")
const ModFiles := preload("res://src/shared/content/mod_files.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Clock := preload("res://src/shared/game/clock.gd")

const MODS_TRIES := 3
## Seconds to wait for a server's welcome.
const JOIN_WAIT := 15.0
## Seconds a server going over to another world (Protocol.CLOSE_RENEW) is given to come
## back, and between two tries to join it again.
const REJOIN_WAIT := 60.0
const REJOIN_EVERY := 2.0

## The bundles a server far away plays with, when they are not the ones loaded: the
## scene is started again with them (decision 153, 5А).
static var pending_mods: Array = []
## The mods' files of the server joined when they are not the game's own (decision 189):
## {"url", "digest", "table" (a path inside content/ → the file that holds it, ModFetch)},
## kept over the restarts of the scene while the game is on that server (use_mods);
## and how many times in a row the server said its files are others (a server whose
## files keep changing is given up, MODS_TRIES).
static var server_mods := {}
static var mods_tries := 0
## The set (its hash) the player was told is large to take (ModFetch.ASK_ABOVE): joining
## again takes it.
static var mods_allowed := ""
## The server to join, kept over a restart of the scene ({url, name, password}): set
## by the «Присоединиться» screen (join_server) or `--join`, emptied when the player goes
## back to a world of their own (leave_server).
static var join := {}
## The command line and the page's address are read once, at the first start.
static var _args_read := false
## The address of `?server=` on the web: the menu opens «Присоединиться» with it.
static var offered := ""
## The server made from the menu on a computer (С5.2, LocalHost.host): it lives under
## the tree's root over the restarts, and the game joins it over a socket. `host_ask`
## holds its settings over the restart that starts it; `host_error` why it did not
## start; `show_host` opens the menu on its window after that restart.
static var hosted: Node = null
static var host_ask := {}
static var host_error := ""
static var show_host := false
## Until when (msec) a server going over to another world is tried again.
static var rejoin_until := 0

## The Main node.
var game
## The socket to the server far away, null in a world of this device; the address joined
## (from `join`, or set by a test before the scene starts), the player's name, the
## password given, the welcome the server gave and why joining failed (words for the
## loading screen and «Присоединиться», MainMenu.join_failed).
var socket: Socket
var join_url := ""
var player_name := "[player_n2]"
var join_password := ""
var welcome := {}
var join_error := ""
## The server's mods' files being taken before the game is let in (_take_mods), null
## when none are.
var mod_fetch: ModFetch


func _init(game_: Node) -> void:
	game = game_


## The address to join: the one a test set, else the one of `join` (from the
## «Присоединиться» screen, or the command line's `--join <url>`, `--name`,
## `--password` read at the first start). On the web `?server=` only fills the
## «Присоединиться» screen (offered).
func read_join() -> void:
	if not _args_read:
		_args_read = true
		var args := OS.get_cmdline_user_args()
		var given := {"url": "", "name": "[player_n2]", "password": ""}
		for i in args.size() - 1:
			match args[i]:
				"--join":
					given.url = args[i + 1]
				"--name":
					given.name = args[i + 1]
				"--password":
					given.password = args[i + 1]
		if given.url != "" and given.password == "":
			given.password = OS.get_environment(Protocol.PASSWORD_ENV)
		if given.url != "":
			join = given
		if OS.has_feature("web"):
			var v: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('server') || ''", true)
			if v is String:
				offered = v
	if join_url == "" and not join.is_empty():
		join_url = join.url
		player_name = join.name
		join_password = join.password


## Starts the game again joined to the server of `url` as `name`.
func join_server(url: String, name: String, password: String) -> void:
	join = {"url": url, "name": name, "password": password}
	mods_tries = 0
	# After the tap that asked it is over (its sound played in this scene).
	game.restart.call_deferred()


## The next start is a world of this device's own again, not the server's.
func leave_server() -> void:
	join = {}


## The loading was cancelled: a server's world is left (a server made here keeps
## running and its window opens: the world loads behind it again).
func cancel() -> void:
	if hosted != null:
		show_host = true
	elif join_url != "":
		leave_server()


## Starts the game again with a server made here of the settings `values` (Config's,
## and "player": the host's name), joined to it (see start_hosting).
func host_server(values: Dictionary) -> void:
	host_ask = values.duplicate()
	game.restart.call_deferred(false)


## Before anything of the scene is built: the server of `host_ask`, when one was asked
## for, is made (its world's bundles activated), and the game joins it at its port as the
## host, with those bundles; the menu opens on the server's window.
func start_hosting() -> void:
	if host_ask.is_empty():
		return
	var values := host_ask
	host_ask = {}
	show_host = true
	var player := str(values.get("player", "[host]"))
	values.erase("player")
	# The day lasts on the server made here as its window says, else as in the host's
	# own game («Длина суток»).
	if game.settings != null and not values.has("day_minutes"):
		values["day_minutes"] = Clock.DAY_LENGTH / game.settings.time_speed() / 60.0
	var node := LocalHost.host(values, game.get_tree().root)
	if node.failed != "":
		host_error = node.failed
		node.free()
		return
	host_error = ""
	hosted = node
	join = {"url": "ws://127.0.0.1:%d" % node.config.port, "name": player, "password": node.config.password}
	pending_mods = node.mods.duplicate()
	print("hosting: port %d, world %s" % [node.config.port, node.store.dir])


## Stops the server made here: it saves the world and closes the connections, then the
## game starts again in a world of this device.
func stop_server() -> void:
	if hosted == null:
		return
	if not hosted.stopped.is_connected(_on_server_stopped):
		hosted.stopped.connect(_on_server_stopped)
	hosted.command("stop")


func _on_server_stopped() -> void:
	if hosted != null:
		hosted.queue_free()
	hosted = null
	join = {}
	game.restart(false)


## The server made here is stopping: its connections closing are not a failure.
static func server_stopping() -> bool:
	return hosted != null and hosted.server != null and hosted.server.stopping


## The bundles the world of a server plays with: those of the server made here (which a
## world it went over to may have changed; one Mods for both), else the ones a server far
## away named (`pending_mods`), else the settings' until its welcome says.
func world_mods() -> Array:
	var mods: Array = game.settings.world_mods()
	if hosted != null:
		mods = hosted.mods.duplicate()
	elif not pending_mods.is_empty():
		mods = pending_mods
	pending_mods = []
	return mods


## Loads the bundles of the world (`game.world_mods`) from the mods' files it plays with:
## on a server whose files were taken (`server_mods`), those; else the game's own. What
## was read of the other files before (phrases, models, icons, the figure's pictures, the
## sounds) is read anew.
func use_mods() -> void:
	var was := Content.served_digest
	if join_url != "" and hosted == null and server_mods.get("url", "") == join_url:
		Content.serve(server_mods.table, server_mods.digest)
	else:
		server_mods = {}
		Content.serve({})
	Mods.activate(game.world_mods)
	if Content.served_digest != was:
		game.mod_reload.forget_files()
		game.sound.read_records()


## Opens the socket to the server and says hello; the welcome comes while the scene
## is built (see wait_welcome).
func open() -> void:
	socket = Socket.new()
	socket.closed.connect(_on_socket_closed)
	if socket.open(join_url) != OK:
		join_error = "[invalid_server_address]"
		return
	game.net = socket.net
	game.mod_reload.watch_server(game.net)
	# The hello names the mods' files the game plays with, set by now (use_mods); a
	# server made here is told its own.
	# A bot comes in new each time: bots started side by side share this device's keys.
	var key: String = "" if game.bot != null else ServerList.key(join_url)
	var mods := ""
	if hosted != null and hosted.server != null:
		hosted.server.content.ready()
		mods = hosted.server.content.digest
	socket.hello(sent_name(player_name, key, hosted != null), key, join_password, mods).then(_on_welcome)


## The name the hello carries for `name`: a player's own as it is; one the game gave
## (a key, `[host]` or `[player_n2]`, when none was set) in words, since the server lets no
## key in as a name. The host's stays «Хозяин»; a player's gets a number of four figures
## (from the server's `key`, the same each time) so two without a name are not one.
static func sent_name(name: String, key: String, host: bool) -> String:
	if not Lang.is_key(name):
		return name
	var words := Lang.t(name)
	if Lang.is_key(words) or words.strip_edges() == "":
		words = "Player"
	if host:
		return words
	var n: int = (absi(key.hash()) if key != "" else randi()) % 9000 + 1000
	return "%s %d" % [words, n]


func _on_welcome(v: Variant) -> void:
	if not v is Dictionary or v.get("ok") != true:
		var why: String = v.get("why", "") if v is Dictionary else ""
		if why == Protocol.WHY_MODS and _take_mods(v):
			return
		join_error = {Protocol.WHY_VERSION: "[different_game_version_reload_the]",
			Protocol.WHY_PASSWORD: "[wrong_password]", Protocol.WHY_FULL: "[server_is_full]",
			Protocol.WHY_NAME: "[a_name_is_required]", Protocol.WHY_BANNED: "[the_server_host_has_banned]",
			Protocol.WHY_LIST: "[this_server_lets_in_only]",
			Protocol.WHY_TAKEN: "[this_name_is_already_taken]",
			Protocol.WHY_WAIT: "[too_many_attempts_wait_a]"}.get(why, "[the_server_did_not_let]")
		return
	if not v.get("seed") is int or not v.get("settings") is Dictionary or not v.get("mods") is Array \
			or not v.get("materials") is Array or not v.get("at") is Vector3:
		join_error = "[the_server_answered_in_an]"
		return
	welcome = v
	rejoin_until = 0
	mods_tries = 0
	if game.bot == null:
		ServerList.remember(join_url, str(v.get("key", "")), str(v.get("title", "")))
	# The player who made the server here is its host: commands in the chat are theirs.
	if hosted != null and hosted.server != null:
		hosted.server.make_host(str(v.get("key", "")))


## The server plays with other mods' files than this game (the refusal `v`,
## Protocol.WHY_MODS): with its own files for the server's bundles when those are the
## same, else with the server's, taken over this connection (ModFetch; wait_welcome shows
## how it goes); then the scene starts again with them and says hello anew. False when
## the refusal is not one to act on (join_error says why).
func _take_mods(v: Dictionary) -> bool:
	var list: Variant = v.get("mods")
	var digest: Variant = v.get("content")
	mods_tries += 1
	if not list is Array or list.size() > 4096 or not ModFiles.valid_hash(digest) or hosted != null:
		join_error = "[the_server_answered_in_an]"
		return true
	for b: Variant in list:
		if not b is String or b.length() > 128:
			join_error = "[the_server_answered_in_an]"
			return true
	if mods_tries > MODS_TRIES:
		join_error = "[the_servers_mod_data_keeps]"
		return true
	print("the server plays with other mod files (%s, %d KB)" % [digest, int(v.get("size", 0)) >> 10])
	pending_mods = Array(list)
	server_mods = {}
	Content.serve({})
	if Content.own_digest(pending_mods) == digest:
		# The same files, other bundles: this game's own will do.
		game.restart.call_deferred()
		return true
	mod_fetch = ModFetch.new()
	mod_fetch.no_ask = game.bot != null
	mod_fetch.finished.connect(_on_mods_taken)
	mod_fetch.begin(game.net, digest, pending_mods)
	return true


func _on_mods_taken(ok: bool) -> void:
	if not game.is_inside_tree():
		return
	if not ok:
		join_error = mod_fetch.error
		pending_mods = []
		return
	print("the server's mod files: %d taken (%d KB), %d in all" % [mod_fetch.files, mod_fetch.got >> 10, mod_fetch.table.size()])
	server_mods = {"url": join_url, "digest": mod_fetch.digest, "table": mod_fetch.table}
	game.restart.call_deferred()


func _on_socket_closed(code: int, reason: String) -> void:
	if not game.is_inside_tree():
		return
	if code == Protocol.CLOSE_RENEW and not welcome.is_empty():
		# The server goes over to another world: in again once it is up.
		print("the server goes over to another world: joining again")
		rejoin_until = Time.get_ticks_msec() + int(REJOIN_WAIT * 1000.0)
		if game.hud != null:
			game.hud.set_loading("[the_server_is_moving_to_n2]")
		game.restart.call_deferred()
		return
	if server_stopping():
		return
	if mod_fetch != null and mod_fetch.state in ["list", "ask", "files"]:
		mod_fetch.stop()
	if join_error == "" and welcome.is_empty():
		# A browser says nothing of a server that is not there but a code without words.
		join_error = "[the_server_does_not_respond]" if code < 0 or reason == "" else Lang.line("[the_server_closed_the_door]", [reason])
	elif join_error == "":
		join_error = "[connection_to_the_server_lost]" if code < 0 else (Lang.line("[server_n3]", [reason]) if reason != "" else "[the_server_closed_the_connection]")
		if game.hud != null:
			game.hud.set_loading(join_error)
		if game.menu != null:
			game.menu.join_failed(join_error)


## Waits for the server's welcome under the loading screen, taking the server's mods'
## files meanwhile when it plays with others (the scene starts again with them). True
## once the welcome is in hand; false when the scene is going (cancelled, or started
## again for the mods or for a server making its other world) or joining failed, which
## the loading screen and «Присоединиться» are told.
func wait_welcome() -> bool:
	var since := Time.get_ticks_msec()
	while welcome.is_empty() and join_error == "":
		if mod_fetch != null:
			mod_fetch.update()
			_show_mods_taken()
			if mod_fetch.state == "ask":
				# A lot to take: the player is told how much and joins again to agree.
				if mods_allowed == mod_fetch.digest:
					mod_fetch.allow()
				else:
					mods_allowed = mod_fetch.digest
					join_error = Lang.line("[the_server_asks_to_download]", [_mb(mod_fetch.want)])
		elif Time.get_ticks_msec() - since > JOIN_WAIT * 1000.0:
			join_error = "[the_server_does_not_respond]"
			break
		await game.get_tree().process_frame
		# The loading was cancelled: the scene is out of the tree, going.
		if not game.is_inside_tree():
			return false
	if join_error != "" and Time.get_ticks_msec() < rejoin_until:
		# The server is making its other world: tried again a little later.
		game.hud.set_loading("[the_server_is_moving_to_n2]")
		await game.get_tree().create_timer(REJOIN_EVERY).timeout
		if game.is_inside_tree():
			game.restart()
		return false
	if join_error != "":
		game.hud.set_loading(join_error)
		print("join %s failed: %s" % [join_url, join_error])
		if game.menu != null:
			game.menu.join_failed(join_error)
		return false
	return true


## The loading screen while the server's mods' files are taken: how much of them came.
func _show_mods_taken() -> void:
	if game.hud == null or mod_fetch == null:
		return
	var text := ""
	if mod_fetch.state == "files":
		text = Lang.line("[mod_data_s_of_s_mb]", [_mb(mod_fetch.got), _mb(mod_fetch.want)])
	elif mod_fetch.state == "list":
		text = "[mod_data]"
	if text != "" and text != game.loading_stage:
		# The menu's loading card names the stage; the plain line shows without a menu.
		game.loading_stage = text
		game.hud.set_loading(text)


## `bytes` as megabytes with one digit after the point.
static func _mb(bytes: int) -> String:
	return "%.1f" % (bytes / 1048576.0)
