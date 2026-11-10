extends "res://tests/unit/test_case.gd"
## What a client cannot make the server do (stage 7, docs/security/): the hands hold only
## what the bag has, the feet and the body are the server's, claims sent faster go no
## farther, the hands' work is paced, a bag counted from its end does not grow, a craft
## cancelled gives back what it took as it was, a blueprint of huge corners is not made,
## text typed is made safe, free items only when the rules allow them, and the server's door: reserved and taken names, the list's
## names bound to their keys, wrong passwords, and who may give which command.

const Protocol := preload("res://src/shared/net/protocol.gd")
const LocalHost := preload("res://src/client/net/local_host.gd")
const Server := preload("res://src/server/server.gd")
const Config := preload("res://src/server/config.gd")
const Plans := preload("res://src/shared/game/plans.gd")
const Requests := preload("res://src/server/requests.gd")
const Gestures := preload("res://src/shared/game/gestures.gd")


func run() -> void:
	_test_text()
	_test_body()
	_test_requests()
	_test_bags()
	_test_craft_cancel()
	_test_plans()
	_test_door()
	_test_commands()
	_test_cheats()


## A flat world of 32 by 32 cells with a player over the socket (check_moves, paced) and
## their requests.
func _socket_player() -> Array:
	var w := WorldData.new(8, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var s := Session.new(w, null, Clock.new(), Rules.new(), Placed.new())
	var host := LocalHost.new(s)
	host.join()
	var a = host.player
	a.check_moves = true
	host.link.requests.paced = true
	return [s, host, a]


static func _input(at: Vector3, feet: Vector3i, hands := ["", ""], air := false, facing := Vector2i(0, 1)) -> Array:
	return [at, feet, facing, hands, 0, 0, false, false, false, air, Vector3.INF,
		Vector2(1.0, 0.0), Vector2(12.0, 8.0), true, "", 0.0, 0, Vector3.INF]


func _test_text() -> void:
	_check(Protocol.clean_text("  при\u202Eвет\n\tвсем\u200B  ", 160) == "привет всем",
		"text typed loses control characters, marks that turn text around or hide it, and extra spaces")
	_check(Protocol.clean_text("Сервер\nSay: ты хозяин", 24) == "Сервер Say: ты хозяин", "a new line cannot start a line of its own")
	_check(Protocol.clean_text("x".repeat(100000), 24).length() == 24, "and is cut")


## The body and the hands as the server takes them from a client over a socket.
func _test_body() -> void:
	var p := _socket_player()
	var a = p[2]
	var start := Vector3(8.5, 2.0, 8.5) * WorldData.CELL
	a.teleport(start)
	var tool := ""
	for id: String in Items.IDS:
		if Tools.is_tool_item(id) and Tools.can_dig(Tools.of(id), Mat.STONE):
			tool = id
			break
	a.take_input(_input(start, Vector3i(8, 2, 8), [tool, tool]))
	_check(tool != "" and a.held() == "" and a.tool() == Tools.HAND, "a tool the bag does not hold works as bare hands (%s)" % tool)
	a.inventory.add(tool, 1)
	_check(a.held() == tool and a.in_hands() == [tool, ""], "one the bag holds is held, in the hand in use only")
	a.take_input(_input(start, Vector3i(30, 5, 30), ["", ""], true, Vector2i(9, -7)))
	_check(a.feet() == Vector3i(8, 2, 8) and a.facing_step() == Vector2i(1, -1) and not a.body.air_jumps,
		"the feet are where the body is, the way it faces is a step, and the playtest's air jumps are not taken")
	# Claims of two cells each, faster than any legs: each would pass the tolerance alone.
	var claim := start
	for i in 40:
		claim += Vector3(2.0, 0.0, 0.0) * WorldData.CELL
		a.take_input(_input(claim, Vector3i(8, 2, 8)))
	_check(a.position.distance_to(start) < 6.0 * WorldData.CELL and a.refused_moves > 0,
		"claims sent faster than the body walks gain little (%.1f cells) and are refused (%d)"
		% [a.position.distance_to(start) / WorldData.CELL, a.refused_moves])
	a.teleport(start)
	var wall := start + Vector3(0.0, -1.0, 0.0) * WorldData.CELL
	a.take_input(_input(wall, Vector3i(8, 1, 8)))
	_check(a.position == start, "a claim inside the ground is not taken")


## The hands' work is paced: requests sent at once do as much as the time allows.
func _test_requests() -> void:
	var p := _socket_player()
	var host = p[1]
	var a = p[2]
	a.teleport(Vector3(8.5, 2.0, 8.5) * WorldData.CELL)
	a.take_input(_input(a.position, Vector3i(8, 2, 8)))
	var req = host.link.requests
	var done := 0
	for i in 40:
		var r: Array = req.handle(Protocol.request(Protocol.FRONT, i + 1, [99]))
		if r[1] is Dictionary and not r[1].is_empty():
			done += 1
	_check(done >= 1 and done < 15, "forty swings asked at once: only those the time allows are done (%d)" % done)
	var r2: Array = req.handle(Protocol.request(Protocol.PLAN, 100, ["plane", Vector3i(-1000000000, 2, -1000000000), Vector3i(1000000000, 2, 1000000000), 1, 1, false, 0]))
	_check(r2[1] == 0, "a blueprint of corners far apart is refused at once, not made")
	var r3: Array = req.handle(Protocol.request(Protocol.SORT, 101, [null, "kind", -16]))
	_check(r3[1] == true, "a sort from a slot counted from the end is done as from the first")
	var r4: Array = req.handle(Protocol.request(Protocol.PLAN, 104, ["plane", Vector3i(-1000000000, 2, -1000000000), Vector3i(1000000000, 2, 1000000000), 1, 1, true, 0]))
	_check(r4[1] == 0, "and so is taking the ghost off such a box")
	_check(req.handle(Protocol.request(Protocol.PLAN, 105, ["line", Vector3i.ZERO, Vector3i.ZERO, 1, 1, 1, 0]))[1] == null,
		"a blueprint whose «erase» is no bool is refused")
	_check(req.handle(Protocol.request(Protocol.PLAN, 106, ["line", Vector3i.ZERO, Vector3i.ZERO, 1, 1, false, 99]))[1] == null,
		"and one of a form out of bounds")
	var free := ["tools:torch"]
	_check(req.handle(Protocol.request(Protocol.CRAFT_FREE, 107, free))[1] == 0 and a.inventory.count("tools:torch") == 0,
		"a recipe's thing is not given for nothing while the rules do not allow it")
	_check(req.handle(Protocol.request(Protocol.CRAFT_FREE, 108, [7]))[1] == null, "nor for a recipe id that is no text")
	p[0].rules.free_items = true
	_check(req.handle(Protocol.request(Protocol.CRAFT_FREE, 109, free))[1] == 1 and a.inventory.count("tools:torch") == 1,
		"with «Бесплатные предметы» on it is")
	_check(req.handle(Protocol.request(Protocol.FARM, 110, ["till", Vector3i(-1000000000, 2, 0), Vector3i(1000000000, 2, 0), true, false]))[1] == 0,
		"farming marks of corners far apart are refused at once, not made")
	_check(req.handle(Protocol.request(Protocol.FARM, 111, ["till", Vector3i.ZERO, Vector3i.ZERO, 1, false]))[1] == null,
		"and marks whose «square» is no bool")
	_check(req.handle(Protocol.request(Protocol.FARM, 112, ["build", Vector3i.ZERO, Vector3i.ZERO, false, false]))[1] == null,
		"and marks of no known work")
	_check(req.PACED.has(Protocol.FARM_WORK), "the farming mode's work takes the hands' time")
	var far: Dictionary = p[0].actions.vessels.launch("tools:raft", a.position + Vector3(40.0, 0.0, 0.0), 0.0)
	_check(req.handle(Protocol.request(Protocol.VESSEL_TAKE, 113, [far.id]))[1] == false and a.inventory.count("tools:raft") == 0,
		"a raft out of reach is not taken up")
	_check(req.handle(Protocol.request(Protocol.VESSEL_TAKE, 114, ["1"]))[1] == null, "nor one by a number that is no number")
	_check(req.handle(Protocol.request(Protocol.VESSEL_LAUNCH, 115, ["tools:raft"]))[1] == false and a.vessel == 0,
		"no raft launched from a bag that has none")
	# (The rule itself: the hands may still owe work from the requests above.)
	_check(req._rule(Protocol.VESSEL_LAUNCH, [7]) == null and req.PACED.has(Protocol.VESSEL_LAUNCH),
		"nor for an id that is no text; a launch takes the hands' time")
	var sign: Dictionary = p[0].placed.put("tools:sign", Vector3i(9, 2, 8))
	_check(req._rule(Protocol.SIGN_WRITE, [sign.cell, "x".repeat(Requests.SIGN_MAX + 1)]) == null
		and req._rule(Protocol.SIGN_WRITE, [sign.cell, 7]) == null, "a sign is not written with text too long or no text")
	_check(req._rule(Protocol.SIGN_WRITE, [sign.cell, "Привет\u202e\n" + "y".repeat(40)]) == true
		and p[0].placed.at(sign.cell).text == "Привет\n" + "y".repeat(20), "what is written is made safe and cut to the sign")
	var far_sign: Dictionary = p[0].placed.put("tools:sign", Vector3i(28, 2, 28))
	_check(req._rule(Protocol.SIGN_WRITE, [far_sign.cell, "далеко"]) == false and req._rule(Protocol.SIGN_TURN, [far_sign.cell]) == false,
		"a sign out of reach is neither written nor turned")
	_check(req.PACED.has(Protocol.SIGN_WRITE) and req.PACED.has(Protocol.SIGN_TURN), "writing and turning take the hands' time")
	_check(req._rule(Protocol.GESTURE, ["dance_forever"]) == false and a.gesture == "" and req._rule(Protocol.GESTURE, [3]) == null,
		"no gesture of a name that is none, or of no name")
	var now := Time.get_ticks_msec() / 1000.0
	_check(req._rule(Protocol.GESTURE, ["wave"]) == true and Gestures.now_of(a, now) == "wave", "a wave is made and lasts")
	_check(Gestures.now_of(a, now + 10.0) == "", "and is over after its time")
	req._rule(Protocol.GESTURE, ["sit"])
	_check(Gestures.now_of(a, now + 1000.0) == "sit", "one sits until they move")
	a.is_moving = true
	_check(Gestures.now_of(a, now) == "", "moving ends a gesture")
	a.is_moving = false
	req.may_debug = false
	_check(req._rule(Protocol.AI_DEBUG, [true]) == false and not req.ai_debug, "a player of a server does not see the animals' minds")
	_check(req._rule(Protocol.AI_DEBUG, ["yes"]) == null, "nor asks with no bool")
	req.may_debug = true
	_check(req._rule(Protocol.AI_DEBUG, [true]) == true and req.ai_debug, "one who may (a single game, a host) does")
	var minds := Array(host.link.flush()).map(func(b: PackedByteArray) -> Array: return Protocol.decode(b)) \
		.filter(func(e: Array) -> bool: return e[0] == Protocol.MINDS)
	_check(minds.size() == 1 and minds[0][1] is Array, "and is told them")
	req._rule(Protocol.AI_DEBUG, [false])


## A bag counted from its end is the same bag, not twice the things.
func _test_bags() -> void:
	var inv := Inventory.new()
	inv.add("resources:stone", 30)
	inv.add("resources:branch", 7)
	inv.sort("kind", -16)
	_check(inv.count("resources:stone") == 30 and inv.count("resources:branch") == 7, "sorting from slot -16 adds nothing")
	var chest := Inventory.new(8)
	inv.move_all(chest, -16)
	_check(inv.count("resources:stone") + chest.count("resources:stone") == 30, "nor does moving all from it")
	_check(not inv.put_into(-1, chest, 0) and inv.move_slot(-1, chest) == 0 and inv.take_slot(99, 1) == null,
		"a slot out of the bag moves nothing")


## A craft cancelled gives back a worn tool worn and food as old as it went in.
func _test_craft_cancel() -> void:
	var r := Crafting.get_recipe("tools:composite_bow")
	if r.is_empty():
		return
	var inv := Inventory.new()
	for id: String in r.needs:
		if id == "tools:wooden_bow":
			inv.add(id, 1, 7)
		else:
			inv.add(id, r.needs[id])
	var q := CraftQueue.new()
	_check(q.add(r, inv) and inv.count("tools:wooden_bow") == 0, "the materials go into the job")
	var back := q.cancel(0)
	_check(back.has(["tools:wooden_bow", 1, 7, Inventory.NORMAL]), "and come back as they were, the bow as worn: %s" % [back])
	var saved := CraftQueue.new()
	q.add(r, _filled(r))
	saved.from_dict(q.to_dict())
	_check(saved.jobs.size() == 1 and saved.jobs[0].get("took") is Array, "what a job took is kept in the save")


static func _filled(r: Dictionary):
	var inv := Inventory.new()
	for id: String in r.needs:
		inv.add(id, r.needs[id])
	return inv


func _test_plans() -> void:
	var t0 := Time.get_ticks_msec()
	_check(Plans.shape("plane", Vector3i(-100000, 0, -100000), Vector3i(100000, 0, 100000), 1).is_empty()
		and Plans.shape("square", Vector3i(0, 0, 0), Vector3i(1 << 30, 0, 5), 4).is_empty()
		and Plans.shape("cube", Vector3i(0, 0, 0), Vector3i(1 << 30, 0, 1 << 30), 4, Vector2.INF, 1 << 20).is_empty()
		and Plans.erase_box("line", Vector3i(0, 0, 0), Vector3i(1 << 30, 0, 0), 4).is_empty()
		and Time.get_ticks_msec() - t0 < 100, "a shape too big is not made at all")
	_check(Plans.shape("line", Vector3i(0, 0, 0), Vector3i(9, 0, 0), 2).size() == 20, "one of a fair size is")
	_check(Plans.shape("line", Vector3i(0, 0, 0), Vector3i(9, 0, 0), 99, Vector2.INF, 99).size() == 10 * Plans.MAX_HEIGHT * Plans.MAX_THICK,
		"its height and thickness are kept in bounds")


## The server's door (Server._refusal): no keys or passwords needed for a socket.
func _test_door() -> void:
	var cfg := Config.new()
	cfg.password = "тайна"
	cfg.max_players = 8
	var net := Server.new(null, cfg, {})
	var hello := func(name: String, key := "", password := "тайна", from := "10.0.0.9") -> String:
		return net._refusal([Protocol.VERSION, Protocol.build_version(), name, key, password], from)
	_check(hello.call("Аня") == "" and hello.call("  ") == Protocol.WHY_NAME, "a name is needed")
	_check(hello.call("Сервер") == Protocol.WHY_TAKEN and hello.call("ADMIN") == Protocol.WHY_TAKEN, "the server's own names are not taken")
	var a := Server.Account.new()
	a.id = 1
	a.name = "Аня"
	a.key = "k1"
	net.accounts["k1"] = a
	_check(hello.call("аня", "k2") == Protocol.WHY_TAKEN and hello.call("Аня", "k1") == "",
		"a name in the world is its player's only")
	net.access.listed_only = true
	net.access.listed = ["боря"]
	net.access.listed_keys = {"боря": "k3"}
	_check(hello.call("Боря", "k4") == Protocol.WHY_LIST and hello.call("Боря", "k3") == "",
		"a name on the list comes in with its own key, not with anyone's")
	net.access.listed_only = false
	for i in Server.PASSWORD_TRIES:
		hello.call("Вася", "", "не та")
	_check(hello.call("Вася", "", "тайна") == Protocol.WHY_WAIT and hello.call("Вася", "", "тайна", "10.0.0.10") == "",
		"after many wrong passwords a new player from that address waits")
	_check(hello.call("Аня", "k1") == "", "one the server knows comes in all the same")
	_check(hello.call("Вася", "x".repeat(1000)) == Protocol.WHY_VERSION, "a key of another shape is not one")


## Who may give which command (Server.COMMANDS).
func _test_commands() -> void:
	var cfg := Config.new()
	var net := Server.new(null, cfg, {})
	_check(net.command("stop", Server.ROLE_HOST).contains("владельца") and not net.stopping, "a host may not stop the server")
	_check(net.command("op кто-то", Server.ROLE_HOST).contains("владельца"), "nor give others the commands")
	_check(net.command("who", Server.ROLE_PLAYER).contains("владельца") and net.command("who", Server.ROLE_HOST).begins_with("Игроков"),
		"a player gives none; a host gives theirs")
	_check(net.command("nothing at all").begins_with("неизвестная"), "an unknown command is named as such")
	_check(net.command("reload", Server.ROLE_PLAYER).contains("владельца"), "a player may not read the mods' data again")
	var asked: Array = []
	net.test_command = func(rest: String) -> String:
		asked.append(rest)
		return "ок"
	_check(net.command("test bot+", Server.ROLE_PLAYER).contains("тестовом") and asked.is_empty(),
		"«test» does nothing on a server that is not a playtest one")
	cfg.playtest = true
	_check(net.command("test bot+", Server.ROLE_PLAYER) == "ок" and asked == ["bot+"], "on a playtest one any player gives it")
	cfg.playtest = false
	cfg.take_args(PackedStringArray(["--playtest", "--minutes", "-5", "--bots", "-2"]))
	_check(cfg.playtest and cfg.minutes == 0 and cfg.bots == 0, "a playtest server's numbers from the command line are never below 0")
	net.access.hosts["k"] = "Аня"
	net.access.owners["o"] = "Боря"
	_check(net.role_of("k") == Server.ROLE_HOST and net.role_of("o") == Server.ROLE_OWNER and net.role_of("x") == Server.ROLE_PLAYER,
		"the roles come from the server's lists")
	net.access.hosts.erase("k")
	_check(net.role_of("k") == Server.ROLE_PLAYER, "and a role taken away is gone at once")


## The playtest page's switches (Protocol.CHEATS) are taken on a playtest server only,
## each checked and clamped.
func _test_cheats() -> void:
	var p := _socket_player()
	var s: Session = p[0]
	var host: LocalHost = p[1]
	var a = p[2]
	var req: Requests = host.link.requests
	_check(req.handle(["cheats", 1, [{"speed": 8.0, "hunger": false, "free_items": true}]]) == [1, false]
		and a.haste == 1.0 and a.vitals.hunger and not s.rules.free_items, "a server that is not a playtest one takes none")
	req.may_cheat = true
	req.handle(["cheats", 2, [{"speed": 1000.0, "air": true, "skill": -5, "hunger": false, "free_items": true,
		"boost": "много", "season": 9, "weather": -7, "moon": 0.5, "hour": NAN, "nothing": 1}]])
	_check(a.haste == 8.0 and a.body.speed_scale == 8.0 and a.cheat_air and a.skills.rate == 0.0,
		"on a playtest one the player's own switches are taken, clamped: %s %s" % [a.haste, a.skills.rate])
	_check(not a.vitals.hunger and s.rules.free_items and s.clock.season == 3 and s.clock.weather_auto
		and s.clock.moon_pin == 0.5 and s.clock.time_speed == 1.0, "and the world's, a value of a wrong type left")
	var ins := _input(a.at, a.feet_cell, ["", ""], true)
	a.take_input(ins)
	_check(a.body.air_jumps, "jumps in the air are allowed then")
