extends SceneTree
## The server over the network (plan/architecture/server.md, С3): the headless server's
## scene in this process, listening on a port of its own, and bots that come in over
## WebSockets with the client's socket: hello and the welcome, the refusals (the
## version, the password, a full server, no hello), the events of joining, a request
## answered after its events, a connection lost and the character waiting for the key
## to come back, a goodbye, the host's commands (who, say, kick, stop); then the game
## itself joins (Main over a socket): the world comes from the server as chunks, the
## cells dug by anyone change in its copy, the things dropped come with their list;
## then the server is started again over the world it saved (С4).
## Run: godot --headless --path . --script res://tests/server_test.gd

const Protocol := preload("res://src/shared/net/protocol.gd")
const Socket := preload("res://src/client/net/socket.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const ServerStore := preload("res://src/server/server_store.gd")
const LocalHost := preload("res://src/client/net/local_host.gd")

const ROOT := "user://test_saves/server"
const PORT := 7791
const PASSWORD := "пароль"
## Seconds to wait for a reply or an event.
const WAIT := 15.0

var checks := 0
var failures := 0
var server: Node
## The sockets polled every frame.
var sockets: Array = []


## A player over a socket: what the server sent it.
class Bot extends RefCounted:
	var socket
	var name := ""
	var events: Array = []
	var welcome: Dictionary = {}
	var reply

	func _init(s, n: String) -> void:
		socket = s
		name = n
		socket.net.event.connect(_on_event)

	func _on_event(kind: String, args: Variant) -> void:
		events.append([kind, args])

	func kinds() -> Array:
		return events.map(func(e: Array) -> String: return e[0])

	func of(kind: String) -> Array:
		return events.filter(func(e: Array) -> bool: return e[0] == kind)


func _initialize() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0
	_run()


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


## Polls the sockets each frame until `cond` holds or `timeout` seconds pass.
func _until(cond: Callable, timeout := WAIT) -> bool:
	var t0 := Time.get_ticks_msec()
	while true:
		for s in sockets:
			s.poll()
		if cond.call():
			return true
		if Time.get_ticks_msec() - t0 > timeout * 1000.0:
			return false
		await process_frame
	return false


func _bot(name: String, key := "", password := PASSWORD, port := PORT) -> Bot:
	var s = Socket.new()
	sockets.append(s)
	var b := Bot.new(s, name)
	s.open("ws://127.0.0.1:%d" % port)
	b.reply = s.hello(name, key, password)
	return b


func _input_at(b: Bot, at: Vector3) -> void:
	var cell := Vector3i((at / WorldData.CELL).floor())
	b.socket.net.send(Protocol.INPUT, [at, cell, Vector2i(0, 1), ["", ""], 0, 0, false, false, false, false,
		Vector3.INF, Vector2(1.0, 0.0), Vector2(12.0, 8.0), true, "", 0.0, 0, Vector3.INF])


## Polls the sockets for `n` frames.
func _frames(n: int) -> void:
	for i in n:
		for s in sockets:
			s.poll()
		await process_frame


func _run() -> void:
	WorldStore.root = ROOT
	WorldStore.new(ROOT + "/5-11111").erase()
	server = load("res://scenes/server.tscn").instantiate()
	server.config.port = PORT
	server.config.max_players = 2
	server.config.password = PASSWORD
	server.config.console = false
	server.config.seed_value = 5
	server.config.world = ""
	server.quit_on_stop = false
	server.config.autosave = 2.0
	root.add_child(server)
	# The scene is readied with the first frame.
	await _until(func() -> bool: return server.server != null)
	var net = server.server
	_check(net != null and net.listening and server.session != null and server.runner.playing and not server.had_save,
		"the server opens a new world, makes the ground round the spawn and listens")
	_check(server.session.players.is_empty() and server.session.wildlife.animals.is_empty(),
		"nobody is in the world yet, and no animals: they come with the first player")

	# Hello and the welcome; the events of joining follow it.
	var anya := _bot("Аня")
	_check(await _until(func() -> bool: return anya.reply.done), "the hello is answered over the socket")
	var w: Dictionary = anya.reply.value if anya.reply.value is Dictionary else {}
	_check(w.get("ok") == true and w.get("id") == 1 and w.get("name") == "Аня" and str(w.get("key", "")).length() == 32,
		"the welcome names the player and gives a key: %s" % [w.keys()])
	_check(w.get("seed") == 5 and w.get("settings") is Dictionary and w.get("mods") is Array and not w.mods.is_empty()
		and w.get("materials") == Array(Mat.IDS) and w.get("spawn") is Vector3 and w.get("at") == w.get("spawn"),
		"and tells the world: its seed, settings, bundles, materials and the spawn")
	_check(server.session.players.size() == 1 and server.session.players[0].position == w.spawn,
		"the character stands at the spawn on the server")
	_check(await _until(func() -> bool: return anya.kinds().has(Protocol.ANIMAL)), "the animals come with the first player")
	var kinds: Array = anya.kinds()
	_check(kinds.has(Protocol.YOU) and kinds.has(Protocol.CLOCK) and kinds.has(Protocol.PROPS) and kinds.has(Protocol.TELEPORT)
		and kinds.find(Protocol.YOU) < kinds.find(Protocol.ANIMAL), "joining brings the player's state, the clock, the things and the body's place")
	var you: Dictionary = anya.of(Protocol.YOU)[0][1]
	_check(you.inventory.slots is Array and you.inventory.slots == server.session.players[0].inventory.to_dict().slots,
		"a new character's bag is told as it is (the start's, empty by the data)")
	var animal_ids: Array = anya.of(Protocol.ANIMAL).map(func(e: Array) -> int: return e[1][0])
	_check(animal_ids.size() == server.session.wildlife.animals.size() and animal_ids.size() == _unique(animal_ids).size(),
		"every animal is told once (%d)" % animal_ids.size())
	_check(anya.of(Protocol.PROPS)[0][1][0].size() > 0, "the camp of a new world is placed at the spawn")

	# Refusals: another version, the wrong password, a full server, no hello.
	var old = Socket.new()
	sockets.append(old)
	old.open("ws://127.0.0.1:%d" % PORT)
	var old_reply = old.net.request(Protocol.HELLO, [Protocol.VERSION + 1, Protocol.build_version(), "Дед", "", PASSWORD])
	_check(await _until(func() -> bool: return old_reply.done and old.ended),
		"a hello of another protocol version is answered and the socket closed")
	_check(old_reply.value is Dictionary and old_reply.value.get("ok") == false and old_reply.value.get("why") == Protocol.WHY_VERSION
		and old.close_code == 4000, "with the refusal 'version': %s, code %d" % [old_reply.value, old.close_code])
	var wrong := _bot("Боря", "", "не тот")
	_check(await _until(func() -> bool: return wrong.reply.done and wrong.socket.ended)
		and wrong.reply.value.get("why") == Protocol.WHY_PASSWORD, "the wrong password is refused")
	var borya := _bot("Боря")
	_check(await _until(func() -> bool: return borya.reply.done) and borya.reply.value.get("ok") == true
		and borya.reply.value.get("id") == 2, "the right password lets the second player in")
	var third := _bot("Вася")
	_check(await _until(func() -> bool: return third.reply.done) and third.reply.value.get("why") == Protocol.WHY_FULL,
		"a third player is refused: the server is full")
	var mute := WebSocketPeer.new()
	mute.connect_to_url("ws://127.0.0.1:%d" % PORT)
	var mute_sent := false
	_check(await _until(func() -> bool:
		mute.poll()
		if mute.get_ready_state() == WebSocketPeer.STATE_OPEN and not mute_sent:
			mute_sent = true
			mute.put_packet(Protocol.encode(Protocol.event(Protocol.INPUT, [])))
		return mute.get_ready_state() == WebSocketPeer.STATE_CLOSED) and mute.get_close_code() == 4000,
		"a connection that speaks before its hello is closed")

	# The body and a request: the events of what changed come before the reply.
	_input_at(anya, w.spawn)
	var feet := Vector3i((w.spawn / WorldData.CELL).floor())
	_check(await _until(func() -> bool: return server.session.players[0].feet() == feet),
		"the server's character takes the body from the input")
	var ground := feet + Vector3i(0, -1, 1)
	var was: int = server.session.world.get_cell(ground.x, ground.y, ground.z)
	var dig = anya.socket.net.request(Protocol.DIG, [ground, Vector3i.UP])
	_check(await _until(func() -> bool: return dig.done), "a dig request is answered over the socket")
	_check(dig.value is Dictionary and dig.value.has("swing") and was != Mat.AIR
		and server.session.world.get_cell(ground.x, ground.y, ground.z) != was, "and the cell is dug on the server")
	var order: Array = []
	anya.socket.net.event.connect(func(kind: String, _args: Variant) -> void: order.append(kind))
	var pause = anya.socket.net.request(Protocol.CRAFT_PAUSE, [true]).then(func(_v: Variant) -> void: order.append("reply"))
	_check(await _until(func() -> bool: return pause.done) and pause.value == true, "the queue is paused over the socket")
	_check(order.has(Protocol.SHOP) and order.back() == "reply", "the state changed comes before the reply: %s" % [order])
	_check(await _until(func() -> bool: return anya.of(Protocol.SNAP).size() > 2), "the animals' snapshots keep coming")
	_check(await _until(func() -> bool: return anya.of(Protocol.CLOCK).size() > 2), "and the clock's")

	# The connection lost: the character waits for the key; the player comes back to it.
	var who: String = server.command("who")
	_check(who.contains("Аня (1)") and who.contains("Боря (2)") and who.contains("2 из 2"), "who lists the players: %s" % who)
	var on_server = server.session.players[0]
	on_server.inventory.add("resources:branch", 3)
	anya.socket.ws.close()
	_check(await _until(func() -> bool: return net.online() == 1), "the server sees the connection lost")
	_check(server.session.players.size() == 2 and net.accounts.has(w.key), "the character waits in the world")
	var back := _bot("Аня", w.key)
	_check(await _until(func() -> bool: return back.reply.done) and back.reply.value.get("ok") == true
		and back.reply.value.get("id") == 1, "the key brings the player back as the same one")
	_check(await _until(func() -> bool: return back.of(Protocol.YOU).size() > 0)
		and back.of(Protocol.YOU)[0][1].inventory == on_server.inventory.to_dict()
		and back.of(Protocol.YOU)[0][1].inventory.slots.any(func(s: Variant) -> bool: return s is Array and s[0] == "resources:branch"),
		"with the character as it was, the branches in the bag")
	_check(server.session.players.size() == 2 and net.online() == 2, "and nobody new in the world")
	var again = back.socket.net.request(Protocol.CRAFT_PAUSE, [false])
	_check(await _until(func() -> bool: return again.done) and again.value == false, "requests count from one again on the new connection")
	var chunk_events: Array = anya.of(Protocol.CHUNK)
	var record: Variant = null
	if not chunk_events.is_empty() and chunk_events[0][1].size() == 3:
		record = bytes_to_var(chunk_events[0][1][2].decompress(chunk_events[0][1][1], FileAccess.COMPRESSION_ZSTD))
	_check(record is Dictionary and record.get("key") == chunk_events[0][1][0] and server.session.world.can_unpack(record),
		"the chunks round the body come to a player over a socket, each a record of the world (%d)" % chunk_events.size())

	# The game itself joins: the world comes from the server.
	server.config.max_players = 3
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.skip_setup = true
	main.join_url = "ws://127.0.0.1:%d" % PORT
	main.player_name = "Клиент"
	main.join_password = PASSWORD
	root.add_child(main)
	_check(await _until(func() -> bool: return main.ready_to_play or main.join_error != "", 180.0) and main.join_error == "",
		"the game joins the server and builds the world it sends: %s" % main.join_error)
	if main.ready_to_play:
		_check(main.host == null and main.session == null and main.socket != null and main.welcome.get("id") == 3
			and main.world_seed == 5, "over a socket the game has no server inside, and the world is the server's")
		var recent: Array = main.ServerList.recent()
		_check(not recent.is_empty() and recent[0].url == main.join_url and recent[0].title == server.config.title
			and main.ServerList.key(main.join_url) == main.welcome.key,
			"the server joined goes first in the recent ones, under its name, its key kept: %s" % [recent])
		var at: Vector3 = main.welcome.at
		var spawn_key := WorldData.chunk_key(floori(at.x / WorldData.CELL), floori(at.z / WorldData.CELL))
		_check(main.player.position.distance_to(at) < WorldData.CELL and main.world.has_chunk(spawn_key) and main.chunks.chunk_nodes.has(spawn_key)
			and main.chunks.chunk_nodes.size() >= 9, "the body stands where the server put it (%s vs %s), on chunks the server sent (%d built, spawn %s)"
			% [main.player.position, at, main.chunks.chunk_nodes.size(), main.chunks.chunk_nodes.has(spawn_key)])
		_check(main.world.get_cell(floori(at.x / WorldData.CELL), floori(at.y / WorldData.CELL) - 1, floori(at.z / WorldData.CELL))
			== server.session.world.get_cell(floori(at.x / WorldData.CELL), floori(at.y / WorldData.CELL) - 1, floori(at.z / WorldData.CELL)),
			"the cells are the server's")
		_check(main.placed.things.size() == server.session.placed.things.size() and main.placed.things.size() > 0
			and main.wildlife.animals.size() == server.session.wildlife.animals.size() and main.clock.season == server.session.clock.season,
			"the copies of the things, the animals and the clock are full")
		var one: Vector3i = Vector3i((at / WorldData.CELL).floor()) + Vector3i(1, -1, 0)
		var before: int = main.world.get_cell(one.x, one.y, one.z)
		var dug = back.socket.net.request(Protocol.DIG, [one, Vector3i.UP])
		_check(await _until(func() -> bool: return dug.done) and dug.value is Dictionary and dug.value.has("swing")
			and before != Mat.AIR, "another player digs beside the character")
		_check(await _until(func() -> bool: return main.world.get_cell(one.x, one.y, one.z) != before),
			"and the cell changes in the game's copy (%d -> %d)" % [before, main.world.get_cell(one.x, one.y, one.z)])
		var two: Vector3i = Vector3i((at / WorldData.CELL).floor()) + Vector3i(-1, -1, 0)
		var mine = main.net.request(Protocol.DIG, [two, Vector3i.UP])
		_check(await _until(func() -> bool: return mine.done) and mine.value is Dictionary, "the game digs through the socket")
		_check(await _until(func() -> bool: return main.world.get_cell(two.x, two.y, two.z) != before and not main.world.drops.get(spawn_key, []).is_empty()),
			"the cell changes and what it gave lies on the ground in the copy")
		# The other players (С3.3): Боря steps aside and shows on the game's screen, a
		# figure with his name, where the server says; the game's own body passes the
		# server's check (3А) with no correction.
		var fixes: Array = []
		main.net.event.connect(func(kind: String, _a: Variant) -> void: fixes.append(kind))
		var aside: Vector3 = at + Vector3(1.5 * WorldData.CELL, 0.0, 0.0)
		_input_at(borya, aside)
		_check(await _until(func() -> bool: return main.others.people.has(2) and main.others.people[2].figure.position.distance_to(aside) < 0.5 * WorldData.CELL),
			"another player's figure stands where the server says (%s)" % [main.others.people.get(2, {}).get("figure", null)])
		_check(main.others.people.has(2) and main.others.people[2].label.text == "Боря" and main.others.people.has(1)
			and not main.others.people.has(3), "with his name over his head; the game itself is not among the others (%s)" % [main.others.people.keys()])
		_check(back.of(Protocol.PEOPLE).any(func(e: Array) -> bool: return e[1].any(func(p: Array) -> bool: return p[0] == 3 and p[1] == "Клиент")),
			"the game's player is told to the others")
		# A leap across the land is refused: the server's body walks instead, and the
		# client is put where it is.
		var leaps: int = borya.of(Protocol.TELEPORT).size()
		var far: Vector3 = at + Vector3(200.0 * WorldData.CELL, 0.0, 0.0)
		for i in 12:
			_input_at(borya, far)
			await _frames(1)
		_check(await _until(func() -> bool: return borya.of(Protocol.TELEPORT).size() > leaps),
			"a body claimed far away is put back by the server")
		var put: Vector3 = borya.of(Protocol.TELEPORT)[-1][1][0] if borya.of(Protocol.TELEPORT).size() > leaps else Vector3.INF
		_check(put.is_finite() and put.distance_to(far) > 100.0 * WorldData.CELL and server.session.players[1].position.distance_to(far) > 100.0 * WorldData.CELL,
			"to where its body got walking (%s from %s)" % [put, aside])
		# A walk at the body's pace is taken as told.
		leaps = borya.of(Protocol.TELEPORT).size()
		var walked: Vector3 = server.session.players[1].position
		for i in 10:
			walked += Vector3(0.0, 0.0, 0.3 * WorldData.CELL)
			_input_at(borya, walked)
			await _frames(1)
		_check(server.session.players[1].position == walked and borya.of(Protocol.TELEPORT).size() == leaps,
			"a walk at the body's pace is taken as told (%s vs %s)" % [server.session.players[1].position, walked])
		_check(fixes.count(Protocol.TELEPORT) == 0, "the game's own body is not put back")
	# The game leaves as the menu's exit does: a goodbye, then the scene goes.
	main.socket.leave()
	_check(await _until(func() -> bool: return main.socket.ended and net.online() == 2), "the game's goodbye closes its connection")
	var game_account = net.accounts.values().filter(func(a) -> bool: return a.id == 3)
	_check(game_account.size() == 1 and game_account[0].linger == net.BYE_LINGER, "its character waits a short while")
	game_account[0].left_at -= net.BYE_LINGER
	_check(await _until(func() -> bool: return server.session.players.size() == 2), "and then leaves the world")
	_check(await _until(func() -> bool: return back.of(Protocol.PERSON_GONE).any(func(e: Array) -> bool: return e[1] == [3])),
		"and the others are told it went")
	root.remove_child(main)
	main.free()

	# A goodbye: the character waits a short while; the host's say, kick and stop.
	borya.socket.leave()
	_check(await _until(func() -> bool: return net.online() == 1), "a goodbye closes the connection")
	var borya_account = net.accounts.values().filter(func(a) -> bool: return a.id == 2)
	_check(borya_account.size() == 1 and borya_account[0].linger == net.BYE_LINGER, "after a goodbye the character waits less")
	borya_account[0].left_at -= net.BYE_LINGER
	_check(await _until(func() -> bool: return server.session.players.size() == 1), "and so does Боря's")
	server.command("say всем привет")
	_check(await _until(func() -> bool: return back.of(Protocol.HEARD).any(func(e: Array) -> bool: return e[1] == [0, "Сервер", "всем привет"])),
		"say reaches the players' chat from the server")
	_check(server.command("kick Аня").contains("Аня"), "kick names the player")
	_check(await _until(func() -> bool: return back.socket.ended) and back.socket.close_code == 4001
		and back.of(Protocol.KICK).size() == 1 and server.session.players.is_empty(),
		"a kicked player is told, closed with 4001 and out of the world (code %d, kicks %d, players %d)"
		% [back.socket.close_code, back.of(Protocol.KICK).size(), server.session.players.size()])
	_check(server.command("nothing").contains("help"), "an unknown command says where the list is")
	_check(server.saves != null and server.saves.saves > 0, "the world is saved as it goes (%d saves)" % (server.saves.saves if server.saves != null else 0))
	var anya_file := ServerStore.player_file(w.key)
	_check(server.store.read_json(anya_file).get("name") == "Аня" and not FileAccess.get_file_as_string(server.store.dir + "/" + anya_file).contains(w.key),
		"a player who leaves is saved, in a file that does not hold the key")
	var dug_at: int = server.session.world.get_cell(ground.x, ground.y, ground.z)
	var things: int = server.session.placed.things.size()
	var dir: String = server.store.dir
	server.command("stop")
	_check(net.stopping and not net.listening, "stop closes the port")
	_check(await _until(func() -> bool: return net.done()), "and the connections")
	var late := _bot("Поздний")
	_check(await _until(func() -> bool: return late.socket.ended, 5.0) and not late.reply.done,
		"nobody comes in after stop")
	root.remove_child(server)
	server.free()
	await _restart(w, ground, dug_at, things, dir)
	await _hosted()
	print("server_test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


## The server again over the world it saved (С4): a save cut off (files left beside
## their place) is cleaned away, the world is the one left (the cell dug, the things
## placed), and Аня comes back with her key to her character as it was, with the same
## number; a new player gets the next one.
func _restart(w: Dictionary, ground: Vector3i, dug_at: int, things: int, dir: String) -> void:
	WorldStore.write_json_beside(dir + "/" + WorldStore.WORLD, {"format": 1, "seed": 99})
	WorldStore.write_json_beside(dir + "/" + ServerStore.player_file(w.key), {"format": 1, "id": 7, "name": "ложь"})
	server = load("res://scenes/server.tscn").instantiate()
	server.config.port = PORT
	server.config.password = PASSWORD
	server.config.console = false
	server.config.seed_value = 5
	server.config.world = ""
	server.quit_on_stop = false
	root.add_child(server)
	await _until(func() -> bool: return server.server != null)
	var net = server.server
	_check(server.had_save and server.seed_value == 5 and not FileAccess.file_exists(dir + "/" + WorldStore.WORLD + ".tmp"),
		"the server opens the world it saved; what a save cut off left is cleaned away")
	_check(server.session.world.get_cell(ground.x, ground.y, ground.z) == dug_at and server.session.placed.things.size() == things,
		"the cell dug and the things placed are as they were (%d things)" % server.session.placed.things.size())
	var p: Array = WorldStore.read_json_at(dir + "/" + ServerStore.player_file(w.key)).get("position", [0, 0, 0])
	var left_at := Vector3(p[0], p[1], p[2])
	var anya := _bot("Аня", w.key)
	_check(await _until(func() -> bool: return anya.reply.done) and anya.reply.value.get("ok") == true
		and anya.reply.value.get("id") == 1 and anya.reply.value.get("key") == w.key, "Аня comes back by her key after the restart: %s" % [anya.reply.value])
	var who = server.session.players[0] if not server.session.players.is_empty() else null
	_check(who != null and who.inventory.count("resources:branch") >= 3 and anya.reply.value.get("at") == left_at,
		"to her character as it was: the branches in the bag, the body where it was left (%s, %s)"
		% [who.inventory.count("resources:branch") if who != null else -1, anya.reply.value.get("at")])
	var newcomer := _bot("Новый")
	_check(await _until(func() -> bool: return newcomer.reply.done) and newcomer.reply.value.get("id") == 4,
		"a new player gets the next number (%s)" % [newcomer.reply.value.get("id")])
	server.command("stop")
	await _until(func() -> bool: return net.done())
	root.remove_child(server)
	server.free()


## The server the menu makes on a computer (С5.2, LocalHost.host): started at once with
## the settings given, listening, under the tree's root at the end of the frame and
## going on while the game is paused, its settings written for the terminal; a second
## one on the same port says the port is taken; stopped, it says so and stays (the
## game frees it).
func _hosted() -> void:
	var values := {"title": "Дача", "port": PORT + 1, "max_players": 4, "password": "", "world": "",
		"seed_value": 6, "settings": {"size": 1, "water": 1, "mountains": 1, "rivers": 1, "biomes": 1, "caves": 0, "relief": 1}}
	var node: Node = LocalHost.host(values, root)
	_check(node.failed == "" and node.server.listening and node.hosted and node.config.title == "Дача"
		and node.config.max_players == 4, "a server made in the game starts at once: %s" % node.failed)
	await process_frame
	_check(node.get_parent() == root and node.process_mode == Node.PROCESS_MODE_ALWAYS,
		"it lives under the tree's root and goes on while the game is paused")
	var cfg := ConfigFile.new()
	_check(cfg.load("user://server.cfg") == OK and cfg.get_value("server", "title") == "Дача"
		and cfg.get_value("server", "port") == PORT + 1, "its settings are written for the server from the terminal")
	var twin: Node = LocalHost.host(values, root)
	_check(twin.failed == "Порт %d занят" % (PORT + 1), "a second one on the same port says it is taken: %s" % twin.failed)
	twin.free()
	var host := _bot("Хозяин", "", "", PORT + 1)
	_check(await _until(func() -> bool: return host.reply.done) and host.reply.value.get("ok") == true
		and host.reply.value.get("title") == "Дача", "a player comes in, told the server's name")
	var pair: Array = await _commands(node, host)
	await _chat(node, pair[0], pair[1])
	await _trades(node, pair[0], pair[1])
	var said := [false]
	node.stopped.connect(func() -> void: said[0] = true)
	node.command("stop")
	_check(await _until(func() -> bool: return said[0]) and node.is_inside_tree() and node.log_lines.size() > 3,
		"stopped, it says so and keeps its log; the game frees it")
	root.remove_child(node)
	node.free()


## The host's commands (С5.3): give into a bag (by the item's id, its end or its
## name), tp to cells or to another player, ban (the player put out, the key and the
## name refused, kept in the world's save), unban, whitelist (only the names on it).
func _commands(node: Node, host: Bot) -> Array:
	var who = node.session.players[0]
	var before: int = who.inventory.count("resources:branch")
	var out: String = node.command("/give Хозяин branch 3")
	_check(who.inventory.count("resources:branch") == before + 3 and out.begins_with("выдано"),
		"give puts the item into the player's bag: %s" % out)
	_check(node.command("give Хозяин nothing_like_it").begins_with("нет такого предмета"), "give names a missing item")
	out = node.command("tp 1 4 30 -5")
	_check(who.position.distance_to(Vector3(4.5, 30, -4.5) * WorldData.CELL) < 0.01 and out.contains("4, 30, -5"),
		"tp puts the player at the cells: %s" % out)
	var key: String = host.reply.value.key
	out = node.command("ban Хозяин")
	_check(await _until(func() -> bool: return host.socket.ended) and node.server.accounts.is_empty(),
		"ban puts the player out: %s" % out)
	var again := _bot("Хозяин", key, "", PORT + 1)
	var renamed := _bot("Другой", key, "", PORT + 1)
	var by_name := _bot("хозяин", "", "", PORT + 1)
	_check(await _until(func() -> bool: return again.reply.done and renamed.reply.done and by_name.reply.done)
		and [again, renamed, by_name].all(func(b: Bot) -> bool: return b.reply.value.get("why") == Protocol.WHY_BANNED),
		"a banned player is refused by the key, under another name too, and by the name")
	var kept: Dictionary = node.saves.read_access()
	_check(kept.get("banned_keys", {}).has(key) and node.command("bans").contains("хозяин"), "bans are kept in the world's save")
	node.command("unban Хозяин")
	var back := _bot("Хозяин", key, "", PORT + 1)
	_check(await _until(func() -> bool: return back.reply.done) and back.reply.value.get("ok") == true, "unban lets them in again")
	node.command("whitelist on")
	var stranger := _bot("Чужой", "", "", PORT + 1)
	_check(await _until(func() -> bool: return stranger.reply.done) and stranger.reply.value.get("why") == Protocol.WHY_LIST,
		"with the list on, a name not on it is refused (those here were put on it)")
	node.command("whitelist add чужой")
	var friend := _bot("Чужой", "", "", PORT + 1)
	_check(await _until(func() -> bool: return friend.reply.done) and friend.reply.value.get("ok") == true,
		"a name added to the list comes in")
	node.command("whitelist off")
	return [back, friend]


## The chat (С6): a line is heard by the players near, the speaker too, not by one far
## away; "/" is a command for a host only (op makes one), answered in the chat.
func _chat(node: Node, a: Bot, b: Bot) -> void:
	var server = node.server
	var spawn: Vector3 = a.reply.value.spawn
	var pa = server._find("Хозяин").link.who
	var pb = server._find("Чужой").link.who
	pa.teleport(spawn)
	pb.teleport(spawn + Vector3(2.0, 0.0, 0.0))
	var hi = a.socket.net.request(Protocol.CHAT, ["  привет  "])
	var heard := func(bot: Bot, what: Array) -> bool: return bot.of(Protocol.HEARD).any(func(e: Array) -> bool: return e[1] == what)
	var id_a: int = a.reply.value.id
	_check(await _until(func() -> bool: return hi.done and heard.call(a, [id_a, "Хозяин", "привет"]) and heard.call(b, [id_a, "Хозяин", "привет"]))
		and hi.value == true, "a line of chat is heard by the player near and by the speaker, trimmed")
	_check(node.log_lines.any(func(l: String) -> bool: return l.contains("Хозяин (%d): привет" % id_a)), "and written to the server's log")
	pb.teleport(spawn + Vector3(server.CHAT_RANGE + 5.0, 0.0, 0.0))
	var far = a.socket.net.request(Protocol.CHAT, ["далеко"])
	_check(await _until(func() -> bool: return far.done and heard.call(a, [id_a, "Хозяин", "далеко"])), "the speaker hears their own line")
	await _frames(10)
	_check(not heard.call(b, [id_a, "Хозяин", "далеко"]), "a player beyond the chat's reach does not hear it")
	var cmd = b.socket.net.request(Protocol.CHAT, ["/who"])
	_check(await _until(func() -> bool: return cmd.done and b.of(Protocol.HEARD).any(func(e: Array) -> bool: return e[1][0] == 0 and str(e[1][2]).contains("хозяина"))),
		"a command from a player who is not a host is refused in the chat")
	_check(node.command("op Чужой").contains("Чужой") and server.is_host(b.reply.value.key)
		and node.saves.read_access().get("hosts", {}).has(b.reply.value.key), "op makes a host, kept in the world's save")
	var who = b.socket.net.request(Protocol.CHAT, ["/who"])
	_check(await _until(func() -> bool: return who.done and b.of(Protocol.HEARD).any(func(e: Array) -> bool: return e[1][0] == 0 and str(e[1][2]).begins_with("Игроков на связи"))),
		"a host's command in the chat is done and answered there")
	_check(not a.of(Protocol.HEARD).any(func(e: Array) -> bool: return str(e[1][2]).begins_with("Игроков на связи")), "to them alone")
	node.command("deop Чужой")
	_check(not server.is_host(b.reply.value.key), "deop takes it back")
	_check(not (await _said(b, "")) and not (await _said(b, "   ")), "an empty line is not said")


func _said(b: Bot, text: String) -> bool:
	var r = b.socket.net.request(Protocol.CHAT, [text])
	await _until(func() -> bool: return r.done)
	return r.value == true


## Things moved between players and a chest (С6): two players taking the same stack at
## once, a request sent twice, a connection lost while a transfer is on its way: the
## things are never more than they were. A chest out of reach is as none.
func _trades(node: Node, a: Bot, b: Bot) -> void:
	var server = node.server
	var spawn: Vector3 = a.reply.value.spawn
	var pa = server._find("Хозяин").link.who
	var pb = server._find("Чужой").link.who
	pa.teleport(spawn)
	pb.teleport(spawn + Vector3(0.5, 0.0, 0.0))
	var stone := "resources:stone"
	pa.inventory.remove(stone, pa.inventory.count(stone))
	pb.inventory.remove(stone, pb.inventory.count(stone))
	var cell := Vector3i((spawn / WorldData.CELL).floor()) + Vector3i(2, 0, 2)
	var e: Dictionary = node.session.placed.put("tools:chest", cell)
	var chest = e.items
	chest.add(stone, 10)
	var total := func() -> int: return pa.inventory.count(stone) + pb.inventory.count(stone) + chest.count(stone)
	var slot: int = chest.slots.find([stone, 10])
	# Both ask in the same frame: the server does one request whole, then the other.
	var ra = a.socket.net.request(Protocol.BAG_MOVE, [cell, slot, null])
	var rb = b.socket.net.request(Protocol.BAG_MOVE, [cell, slot, null])
	_check(await _until(func() -> bool: return ra.done and rb.done), "two players take the same stack at once")
	_check(total.call() == 10 and chest.count(stone) == 0 and (pa.inventory.count(stone) == 10) != (pb.inventory.count(stone) == 10)
		and [ra.value, rb.value].count(10) == 1, "one gets it all, the other nothing: %s, %s (total %d)" % [ra.value, rb.value, total.call()])
	var holder = pa if pa.inventory.count(stone) == 10 else pb
	var bot: Bot = a if holder == pa else b
	var other: Bot = b if holder == pa else a
	# The same request twice, as a client sends it again after no answer.
	var from: int = holder.inventory.slots.find([stone, 10])
	var twice := Protocol.encode(Protocol.request(Protocol.BAG_PUT, 1 << 20, [null, from, cell, 0]))
	bot.socket.ws.put_packet(twice)
	bot.socket.ws.put_packet(twice)
	_check(await _until(func() -> bool: return chest.count(stone) > 0) and total.call() == 10,
		"a request sent twice moves the stack once (chest %d, total %d)" % [chest.count(stone), total.call()])
	await _frames(10)
	_check(total.call() == 10 and chest.count(stone) == 10, "and nothing more comes of it (chest %d)" % chest.count(stone))
	# Far from the chest it is as none: nothing goes in or out.
	pb.teleport(spawn + Vector3(30.0, 0.0, 0.0))
	pa.teleport(spawn + Vector3(30.0, 0.0, 0.0))
	var reach = other.socket.net.request(Protocol.BAG_MOVE, [cell, chest.slots.find([stone, 10]), null])
	var take = other.socket.net.request(Protocol.PROP_TAKE, [cell])
	_check(await _until(func() -> bool: return reach.done and take.done) and reach.value == null and take.value == false
		and chest.count(stone) == 10 and node.session.placed.at(cell) == e, "a chest out of reach is as none: nothing moves, it stays")
	# The connection lost right after a request: the stack is either moved or not, never both.
	pa.teleport(spawn)
	pb.teleport(spawn + Vector3(0.5, 0.0, 0.0))
	var lost: Bot = other
	var lost_who = pa if lost == a else pb
	var key: String = lost.reply.value.key
	lost.socket.net.request(Protocol.BAG_MOVE, [cell, chest.slots.find([stone, 10]), null])
	lost.socket.ws.poll()
	lost.socket.ws.close()
	_check(await _until(func() -> bool: return server.online() == 1), "the connection is lost mid-transfer")
	_check(total.call() == 10, "the stack is in one place: bag %d, chest %d" % [lost_who.inventory.count(stone), chest.count(stone)])
	var again := _bot(lost.name, key, "", PORT + 1)
	_check(await _until(func() -> bool: return again.reply.done and again.of(Protocol.YOU).size() > 0) and again.reply.value.get("ok") == true,
		"the player comes back")
	var told: Dictionary = again.of(Protocol.YOU)[0][1].inventory if again.of(Protocol.YOU).size() > 0 else {}
	_check(told == lost_who.inventory.to_dict() and total.call() == 10, "to the bag as the server keeps it, the stones %d in all" % total.call())


static func _unique(a: Array) -> Array:
	var out := []
	for v in a:
		if not out.has(v):
			out.append(v)
	return out
