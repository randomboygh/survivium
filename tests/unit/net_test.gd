extends "res://tests/unit/test_case.gd"
## The protocol between the client and the server (plan/architecture/server.md): the
## shape of a message on the wire, the requests of a player done by the rules on the
## server's side through the loop of single player (LocalHost), the events of their
## state back (PlayerLink), a request sent twice done once, requests that do not fit
## refused.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Requests := preload("res://src/server/requests.gd")
const ServerPlayer := preload("res://src/server/player.gd")
const Connection := preload("res://src/client/net/connection.gd")
const LocalHost := preload("res://src/client/net/local_host.gd")
const RemotePlaced := preload("res://src/client/net/remote_placed.gd")
const RemoteClock := preload("res://src/client/net/remote_clock.gd")
const RemoteWildlife := preload("res://src/client/net/remote_wildlife.gd")
const RemoteWorkshop := preload("res://src/client/net/remote_workshop.gd")
const ServerList := preload("res://src/client/net/server_list.gd")
const Mirror := preload("res://src/client/net/mirror.gd")
const Playtest := preload("res://src/client/net/playtest.gd")
const Bot := preload("res://src/client/input/bot.gd")


func run() -> void:
	_test_protocol()
	_test_requests()
	_test_server_list()
	_test_remote_workshop()
	_test_cells()
	_test_felled_tree()
	_test_playtest()
	_test_glide()


## Over a socket the animals glide between the server's snapshots; a far one is put
## there at once; over the loop each snapshot is taken as it is.
func _test_glide() -> void:
	var kind: String = AiRules.SPECIES.keys()[0]
	var wild := RemoteWildlife.new()
	wild.smooth = true
	wild.take_born([1, kind, 0, Vector3.ZERO])
	var a = wild.by_id(1)
	wild.take_snap([[1, Vector3(1.0, 0.0, 0.0), 0.0, 1.0, false, false, true, 0.0, false, true, "wander"]])
	_check(a.pos == Vector3.ZERO and a.gliding, "a snapshot near starts a glide from where the animal is drawn")
	a.since -= a.span * 0.5
	wild.glide()
	_check(a.pos.x > 0.2 and a.pos.x < 0.8 and a.gliding, "half way through, half way there: %s" % a.pos)
	a.since -= a.span
	wild.glide()
	_check(a.pos == Vector3(1.0, 0.0, 0.0) and not a.gliding, "and then there")
	wild.take_snap([[1, Vector3(10.0, 0.0, 0.0), 0.0, 1.0, false, false, true, 0.0, false, true, "wander"]])
	_check(a.pos == Vector3(10.0, 0.0, 0.0) and not a.gliding, "a far one is put there at once")
	var loop := RemoteWildlife.new()
	loop.take_born([1, kind, 0, Vector3.ZERO])
	loop.take_snap([[1, Vector3(1.0, 0.0, 0.0), 0.0, 1.0, false, false, true, 0.0, false, true, "wander"]])
	_check(loop.by_id(1).pos == Vector3(1.0, 0.0, 0.0), "over the loop a snapshot is taken as it is")


## The playtest server's address read out of the link its workflow leaves (a status), and
## the bot's weapon one it strikes with, not throws.
func _test_playtest() -> void:
	_check(Playtest.address_of("https://randomboygh.github.io/survivium/?server=wss://quiet-river.trycloudflare.com")
		== "wss://quiet-river.trycloudflare.com", "the playtest link gives the server's address")
	_check(Playtest.address_of("https://x/?a=1&server=wss%3A%2F%2Fa.b&c=2") == "wss://a.b", "a coded address among others")
	_check(Playtest.address_of("https://x/") == "", "no address in a link without one")
	var arm: String = Bot._best_weapon()
	_check(arm == "" or Tools.weapon(arm).tool in ["sword", "knife"], "the bot hunts with a blade: %s" % arm)


## A cell the server changed, on the client's copy of the world: a bed watered keeps its
## crop; ground dug out loses it.
func _test_cells() -> void:
	var w := WorldData.new(16, Vector2i(16, 16))
	var bed := Vector3i(4, 1, 4)
	w.set_cell(bed.x, bed.y, bed.z, Mat.BED)
	w.set_field(bed, ["plants:wheat", 1.0, 0.0])
	Mirror.take_cell(w, bed, Mat.BED_WET)
	_check(w.get_cell(bed.x, bed.y, bed.z) == Mat.BED_WET and w.field_at(bed) == ["plants:wheat", 1.0, 0.0],
		"a bed watered on the server keeps its crop on the client: %s" % [w.field_at(bed)])
	Mirror.take_cell(w, bed, Mat.AIR)
	_check(w.field_at(bed) == null, "a bed dug out loses it")


## A tree felled on the server goes from the client's copy too: every cell of its trunk
## and crown comes in CELLS, not only each column's lowest (which the server's own chunks
## are drawn again from).
func _test_felled_tree() -> void:
	var w := WorldData.new(40, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	Growth.place(w, 15, 1, 15, Trees.first(Trees.BROAD), rng)
	var s := Session.new(w, null, Clock.new(), Rules.of({}), Placed.new())
	var host := LocalHost.new(s)
	var net := host.join()
	var a = host.player
	host.link.send_world = true
	for z in 32:
		for x in 32:
			host.link._sent[WorldData.chunk_key(x, z)] = true
	host.flush(net)
	var cells: Array = []
	net.event.connect(func(kind: String, args: Variant) -> void:
		if kind == Protocol.CELLS:
			cells.append_array(args))
	var trunk := Vector3i(15, 1, 15)
	var solid := 0
	for z in 32:
		for x in 32:
			for y in range(1, 40):
				if w.get_cell(x, y, z) != Mat.AIR:
					solid += 1
	a.position = Vector3(12.5, 1.0, 15.5) * WorldData.CELL
	_check(s.actions.fell(a, trunk), "the tree is felled on the server")
	host.flush(net)
	var gone := cells.filter(func(c: Array) -> bool: return c[1] & 255 == Mat.AIR)
	var cols := {}
	for c: Array in gone:
		cols[Vector2i(c[0].x, c[0].z)] = true
	_check(gone.size() >= solid / 2 and gone.size() > cols.size() and gone.any(func(c: Array) -> bool: return c[0] == trunk + Vector3i.UP * 2),
		"every cell of its trunk and crown goes to the client, not only each column's lowest: %d cells in %d columns of %d" \
			% [gone.size(), cols.size(), solid])


## The client's copy of the workshop counts the first job down between the server's
## events (sent only when the queue changes), so its time and bar move; it finishes
## nothing itself and stands still while paused.
func _test_remote_workshop() -> void:
	var r := Crafting.get_recipe("materials:cord")
	var copy := RemoteWorkshop.new(ServerPlayer.new(), Placed.new(), Rules.new())
	copy.take({"queue": {"jobs": [{"recipe": "materials:cord", "left": r.time, "n": 0}], "serial": 1}, "paused": false})
	_check(copy.queue.progress() == 0.0, "a job the server has just started shows no progress")
	copy.update(r.time / 2.0)
	_check(is_equal_approx(copy.queue.progress(), 0.5), "half its time later the copy shows it half done")
	copy.update(r.time * 2.0)
	_check(copy.queue.jobs.size() == 1 and copy.queue.progress() == 1.0, "the copy never finishes a job: the server tells")
	copy.take({"queue": {"jobs": [{"recipe": "materials:cord", "left": r.time, "n": 1}], "serial": 2}, "paused": true})
	copy.update(r.time / 2.0)
	_check(copy.queue.progress() == 0.0, "paused, the copy stands still")


## An address typed by hand as the socket takes it, what is wrong with one, and what
## the device keeps of the servers joined: keys, the recent ones newest first (at most
## ServerList.RECENT), the player's name.
func _test_server_list() -> void:
	var typed := {
		"192.168.1.5": "ws://192.168.1.5:7777",
		" 192.168.1.5:8000/ ": "ws://192.168.1.5:8000",
		"localhost": "ws://localhost:7777",
		"ws://10.0.0.2": "ws://10.0.0.2:7777",
		"https://quiet-river.trycloudflare.com/": "wss://quiet-river.trycloudflare.com",
		"quiet-river.trycloudflare.com": "wss://quiet-river.trycloudflare.com",
		"http://box:7000": "ws://box:7000",
		"wss://a.b": "wss://a.b",
		"": "",
	}
	var wrong := []
	for t: String in typed:
		if ServerList.normalize(t) != typed[t]:
			wrong.append("%s -> %s" % [t, ServerList.normalize(t)])
	_check(wrong.is_empty(), "addresses typed by hand are read as the socket takes them: %s" % [wrong])
	_check(ServerList.problem("", false) != "" and ServerList.problem("wss://", false) != ""
		and ServerList.problem("ws://192.168.1.5:7777", true) != "" and ServerList.problem("ws://192.168.1.5:7777", false) == ""
		and ServerList.problem("ws://localhost:7777", true) == "" and ServerList.problem("wss://a.b", true) == "",
		"no address, or ws:// from a page over https, is said to be wrong")
	var was := ServerList.path
	ServerList.path = "user://servers_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerList.path))
	_check(ServerList.key("ws://a:1") == "" and ServerList.recent().is_empty() and ServerList.player_name() == "",
		"nothing is kept before the first server")
	for i in ServerList.RECENT + 2:
		ServerList.remember("ws://s%d:1" % i, "key%d" % i, "Сервер %d" % i)
		# The recent ones are told apart by the second they were joined.
		var cfg := ConfigFile.new()
		cfg.load(ServerList.path)
		cfg.set_value("recent", "ws://s%d:1" % i, ["Сервер %d" % i, 1000 + i])
		cfg.save(ServerList.path)
	ServerList.remember("ws://s9:1", "key9", "Девятый")
	var recent := ServerList.recent()
	_check(recent.size() == ServerList.RECENT and recent[0].url == "ws://s9:1" and recent[0].title == "Девятый"
		and recent[1].url == "ws://s%d:1" % (ServerList.RECENT + 1) and ServerList.key("ws://s0:1") == "key0",
		"the recent servers newest first, at most %d, the keys of all kept" % ServerList.RECENT)
	ServerList.forget("ws://s9:1")
	ServerList.set_player_name("Аня")
	_check(ServerList.recent()[0].url != "ws://s9:1" and ServerList.key("ws://s9:1") == "key9"
		and ServerList.player_name() == "Аня", "a server forgotten leaves the list but keeps its key; the name is kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerList.path))
	ServerList.path = was


func _test_protocol() -> void:
	var req := Protocol.request(Protocol.DIG, 7, [Vector3i(1, 2, 3), Vector3i.UP])
	_check(Protocol.decode(Protocol.encode(req)) == req, "a request goes through the wire as it was")
	var rep := Protocol.reply(7, {"swing": 0.5, "at": Vector3(1.5, 2.0, 3.5), "stuff": 3})
	_check(Protocol.decode(Protocol.encode(rep)) == rep, "a reply with a dictionary of a rule goes through as it was")
	_check(Protocol.decode(var_to_bytes("x")) == [] and Protocol.decode(var_to_bytes({})) == [],
		"bytes that are not a message decode to nothing")
	_check(Protocol.decode(Protocol.encode([Protocol.BAG_MOVE, 1, [null, 3, Vector3i(4, 5, 6)]]))[2][0] == null,
		"a null in the args (the player's own bag) goes through")
	_check(Protocol.decode(Protocol.encode(Protocol.event(Protocol.SAY, ["Привет"]))) == [Protocol.SAY, ["Привет"]],
		"an event goes through as it was")


## A character plays through the loop: joins the server in the game, tells it where
## the body is, digs, crafts, moves a stack into a chest, comes back from the dead; the
## server's events bring the client its state before the reply, and the client's copies
## of the things placed, the clock and the animals follow the server's; a request sent
## twice is done once; one that does not fit is refused.
func _test_requests() -> void:
	var w := WorldData.new(8, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var placed := Placed.new()
	var s := Session.new(w, null, Clock.new(), Rules.of({"instant_craft": true}), placed)
	s.clock.weather = Clock.RAIN
	s.clock.time_of_day = 0.4
	var host := LocalHost.new(s)
	var net := host.join()
	var a = host.player
	var shop = host.workshop
	_check(s.players == [a] and s.workshops == [shop], "the player who joins is in the session with their workshop")
	var events: Array = []
	net.event.connect(func(kind: String, args: Variant) -> void: events.append([kind, args]))
	# The client's copies, fed as Mirror feeds them.
	var copy := RemotePlaced.new()
	copy.world = w
	var clock := RemoteClock.new()
	var wild := RemoteWildlife.new()
	net.event.connect(_feed.bind(copy, clock, wild))
	var at := Vector3(8.5, 2.0, 8.5) * WorldData.CELL
	net.send(Protocol.INPUT, [at, Vector3i(8, 2, 8), Vector2i(0, -1), ["", ""], 0, 0, false, false, false, false, Vector3.INF,
		Vector2(0.0, 1.0), Vector2(12.0, 8.0), true, "", 0.0, 0, Vector3.INF])
	_check(a.position == at and a.feet() == Vector3i(8, 2, 8) and a.facing_step() == Vector2i(0, -1) and a.held() == "",
		"the server's character stands where the client's body is, with its hands")
	_check(a.view_right == Vector2(0.0, 1.0) and a.view_half == Vector2(12.0, 8.0), "and with the player's screen")
	net.send(Protocol.INPUT, [at, Vector3i(8, 2, 8)])
	_check(a.position == at, "an input that does not fit changes nothing")
	host.flush(net)
	var you: Array = events.filter(func(e: Array) -> bool: return e[0] == Protocol.YOU)
	_check(you.size() == 1 and you[0][1].inventory == a.inventory.to_dict() and you[0][1].vitals[0] == a.vitals.health,
		"the first flush brings the player their state")
	_check(events.has([Protocol.CLOCK, [s.clock.snapshot()]]) and clock.weather == Clock.RAIN and clock.time_of_day == 0.4
		and events.has([Protocol.PROPS, [[]]]) and copy.things.is_empty(), "and the clock and the things placed (none yet)")
	clock.advance(Clock.DAY_LENGTH * 0.1)
	_check(is_equal_approx(clock.time_of_day, 0.5) and clock.weather == Clock.RAIN, "the copy of the clock runs the time of day between snapshots")
	_check(not clock.from_snapshot([1, 2]) and not clock.from_snapshot(s.clock.snapshot().map(func(_v: Variant) -> String: return "x")),
		"a snapshot of another shape or of strings is refused")
	var pinned := RemoteClock.new()
	s.clock.moon_pin = 0.25
	_check(pinned.from_snapshot(s.clock.snapshot()) and pinned.moon_pin == 0.25, "the moon the playtest page pins comes with the clock")
	s.clock.moon_pin = -1.0
	var told: Array[int] = []
	var fresh := RemoteClock.new()
	fresh.season_changed.connect(func(season: int) -> void: told.append(season))
	var server_clock := Clock.new()
	server_clock.season = Clock.WINTER
	fresh.from_snapshot(server_clock.snapshot())
	server_clock.season = Clock.SPRING
	fresh.from_snapshot(server_clock.snapshot())
	_check(told == [Clock.SPRING] and fresh.season == Clock.SPRING,
		"the copy takes the season of its first snapshot quietly and tells the next one")
	# INPUT's layout is kept in three places (Mirror, Player.take_input, server_test):
	# one of Protocol.INPUT_SIZE in Mirror's types is taken, a short one is not.
	var input: Array = [Vector3(4, 2, 4), Vector3i(1, 0, 1), Vector2i(0, 1), ["a", "b"], 1, 0, true, false, false, false,
		Vector3.INF, Vector2(1.0, 0.0), Vector2(12.0, 8.0), true, "", 0.0, 0, Vector3.INF]
	var taker := ServerPlayer.new()
	taker.take_input(input.slice(0, input.size() - 1))
	var refused := taker.hands == ["", ""]
	taker.take_input(input)
	_check(input.size() == Protocol.INPUT_SIZE and refused and taker.hands == ["a", "b"] and taker.feet_cell == Vector3i(1, 0, 1),
		"an INPUT of Protocol.INPUT_SIZE fields is taken, a short one is not")
	events.clear()
	var r = net.request(Protocol.DIG, [Vector3i(8, 1, 7), Vector3i.UP])
	_check(r.done and r.value is Dictionary and r.value.has("swing") and w.get_cell(8, 1, 7) == Mat.AIR,
		"a dig request over the loop is done at once and answered with what the rule gave")
	a.haste = 4.0
	a.vitals.stamina = a.vitals.MAX
	var fast = net.request(Protocol.DIG, [Vector3i(9, 1, 7), Vector3i.UP])
	a.haste = 1.0
	_check(fast.value is Dictionary and fast.value.has("time") and is_equal_approx(fast.value.swing * 4.0, r.value.swing)
		and is_equal_approx(fast.value.time * 4.0, r.value.time),
		"at the playtest pace of work ×4 the swing comes back four times shorter: %s" % [fast.value])
	var seen: Array = []
	r.then(func(v: Variant) -> void: seen.append(v))
	_check(seen.size() == 1 and seen[0] == r.value, "a callback given after the reply runs at once")
	_check(net.sent_bytes > 0 and net.received_bytes > 0 and net.pending() == 0,
		"the bytes both ways are counted (%d sent, %d received)" % [net.sent_bytes, net.received_bytes])
	_check(net.request(Protocol.EAT, ["x"]).value == null and net.request(Protocol.DIG, [Vector3i.ZERO]).value == null
		and net.request("nothing", []).value == null, "a request that does not fit is answered null and does nothing")
	events.clear()
	a.inventory.add("resources:fiber", 3)
	var order: Array = []
	net.event.connect(func(kind: String, _args: Variant) -> void: order.append(kind))
	var craft = net.request(Protocol.CRAFT, ["materials:cord", 1]).then(func(_v: Variant) -> void: order.append("reply"))
	_check(craft.value == 1 and shop.queue.jobs.size() == 1, "a recipe is started by its id")
	_check(order.has(Protocol.YOU) and order.has(Protocol.SHOP) and order.back() == "reply",
		"the state changed comes before the reply: %s" % [order])
	_check(events.any(func(e: Array) -> bool: return e[0] == Protocol.KNOWLEDGE and e[1][0].seen.has("resources:fiber"))
		and not events.any(func(e: Array) -> bool: return e[0] == Protocol.YOU and e[1].has("knowledge")),
		"what is known goes out as its own event when it is learned, not with the bag")
	events.clear()
	s.tick(0.1)
	host.flush(net)
	_check(a.inventory.count("materials:cord") == 1 and events.any(func(e: Array) -> bool: return e[0] == Protocol.MADE and e[1] == ["materials:cord"])
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.YOU and e[1].inventory == a.inventory.to_dict()),
		"the job started by the request is made by the tick, and the flush tells it")
	events.clear()
	host.flush(net)
	_check(events.is_empty(), "a flush with nothing changed sends nothing")
	a.vitals.stamina -= 1.0
	host.flush(net)
	_check(events.size() == 1 and events[0][0] == Protocol.VITALS and events[0][1][2] == a.vitals.stamina,
		"the body's state goes out when it changes, by itself")
	events.clear()
	a.vitals.see_visions(30.4)
	host.flush(net)
	_check(events.size() == 1 and events[0][0] == Protocol.VITALS and events[0][1][10] == 31,
		"visions go out in whole seconds left")
	events.clear()
	a.vitals.visions -= 0.2
	host.flush(net)
	_check(events.is_empty(), "less than a second of visions gone sends nothing")
	a.vitals.visions = 0.0
	host.flush(net)
	events.clear()
	var cell := Vector3i(10, 2, 10)
	placed.put("tools:chest", cell)
	var chest = placed.at(cell).items
	_check(chest != null and placed.at(Vector3i(11, 2, 10)).is_empty(), "a thing placed is found by its north-west cell")
	host.flush(net)
	_check(events == [[Protocol.PROP, [placed.record(placed.at(cell))]]] and copy.at(cell).item == "tools:chest"
		and copy.at(cell).items != null and copy.chest_items == copy.at(cell).items and w.blockers.has(cell),
		"the thing placed reaches the client's copy with its cells")
	events.clear()
	a.inventory.add("resources:stone", 2)
	var slot: int = a.inventory.slots.find(["resources:stone", 2])
	_check(net.request(Protocol.BAG_MOVE, [null, slot, cell]).value == 2 and chest.count("resources:stone") == 2
		and events.has([Protocol.CHEST, [cell, chest.to_dict()]]) and copy.at(cell).items.count("resources:stone") == 2
		and a.inventory.count("resources:stone") == 0, "a stack moves from the bag into a chest named by its cell")
	_check(net.request(Protocol.BAG_MOVE, [cell, 0, null]).value == 2 and a.inventory.count("resources:stone") == 2,
		"and back")
	_check(net.request(Protocol.BAG_MOVE, [null, 0, Vector3i(20, 2, 20)]).value == null, "a chest at an empty cell is nobody's")
	# A bag lying in the bag is named by its slot: things go in and out of it there.
	var inv = a.inventory
	inv.add("tools:wicker_bag", 1)
	var pack: int = inv.slots.find(["tools:wicker_bag", 1])
	var rock: int = inv.slots.find(["resources:stone", 2])
	var kg: float = inv.weight()
	_check(net.request(Protocol.BAG_MOVE, [null, rock, pack]).value == 2 and inv.count("resources:stone") == 0
		and inv.contents(pack) is Dictionary and inv.open(pack).count("resources:stone") == 2
		and is_equal_approx(inv.weight(), kg),
		"a stack goes into a bag lying in the bag, and weighs there: %s" % [inv.slots[pack]])
	_check(net.request(Protocol.BAG_MOVE, [null, pack, pack]).value == 0 and net.request(Protocol.BAG_PUT, [pack, 0, null, pack]).value == false
		and net.request(Protocol.BAG_MOVE, [null, pack, cell]).value == 0 and chest.count("tools:wicker_bag") == 0,
		"a bag does not go into itself, nor a bag with things into a chest")
	_check(net.request(Protocol.BAG_ALL, [pack, null, 0]).value == 2 and inv.count("resources:stone") == 2
		and inv.slots[pack] == ["tools:wicker_bag", 1], "all out of it: the bag is empty again")
	_check(net.request(Protocol.BAG_ALL, [null, pack, 0]).value >= 1 and inv.slots[pack] != null and inv.slots[pack][0] == "tools:wicker_bag"
		and inv.open(pack).count("resources:stone") == 2, "all into it but itself")
	_check(net.request(Protocol.BAG_MOVE, [null, 0, 99]).value == null and net.request(Protocol.SORT, [pack, "kind", 0]).value == true,
		"a slot with no bag in it names none")
	net.request(Protocol.BAG_ALL, [pack, null, 0])
	inv.remove("tools:wicker_bag", 1)
	# Out of the hand's reach (С6): a chest, a thing on the ground, a bush are as none.
	var far_cell := Vector3i(28, 2, 28)
	var far_chest = placed.put("tools:chest", far_cell).items
	far_chest.add("resources:stone", 1)
	_check(net.request(Protocol.BAG_MOVE, [far_cell, 0, null]).value == null and net.request(Protocol.BAG_ALL, [null, far_cell, 0]).value == null
		and net.request(Protocol.PROP_TAKE, [far_cell]).value == false and far_chest.count("resources:stone") == 1
		and not placed.at(far_cell).is_empty(), "a chest out of the hand's reach is as none: nothing goes in or out, it is not taken")
	placed._remove(placed.at(far_cell))
	w.add_drop("resources:stone", Vector3(14.0, 1.0, 14.0), 0.0, 1)
	var far_key := WorldData.chunk_key(28, 28)
	_check(net.request(Protocol.GATHER, [{"drop": [far_key, w.drops[far_key].size() - 1]}]).value == false
		and w.drops.has(far_key), "a thing on the ground out of reach is not picked up")
	w.drops.erase(far_key)
	_check(net.request(Protocol.GATHER, [{"drop": [Vector2i(0, 0), 99]}]).value == false
		and net.request(Protocol.GATHER, [{"drop": "x"}]).value == false and net.request(Protocol.GATHER, [{"bush": "x"}]).value == false
		and net.request(Protocol.GATHER, [{"tree": Vector2i(1, 1)}]).value == false and net.request(Protocol.GATHER, [{"tree": 3}]).value == false,
		"a target of another shape, or a tree that is not there, is refused")
	# The chat: a line is told on to the server, trimmed and cut; no more than a few at once.
	var lines: Array = []
	host.link.requests.chatted.connect(func(t: String) -> void: lines.append(t))
	var said: Array = []
	for i in Requests.CHAT_LINES + 1:
		said.append(net.request(Protocol.CHAT, ["  строка %d  " % i]).value)
	_check(lines.size() == Requests.CHAT_LINES and lines[0] == "строка 0" and said.count(true) == Requests.CHAT_LINES and said.back() == false,
		"lines of chat are told on trimmed, %d at most in a while: %s" % [Requests.CHAT_LINES, said])
	host.link.requests._chat_times.clear()
	_check(net.request(Protocol.CHAT, ["x".repeat(500)]).value == true and lines.back().length() == Requests.CHAT_MAX
		and net.request(Protocol.CHAT, ["   "]).value == false, "a long line is cut, an empty one not said")
	_check(net.request(Protocol.PROP_FIRE, [cell, true]).value == false and net.request(Protocol.PROP_DESTROY, [cell]).value == false,
		"a chest is not lit or destroyed")
	_check(net.request(Protocol.PROP_TAKE, [cell]).value == true and placed.things.is_empty()
		and a.inventory.count("tools:chest") == 1, "a thing placed is taken up by its cell")
	_check(events.has([Protocol.PROP_GONE, [cell]]) and copy.things.is_empty() and copy.chest_items == null
		and not w.blockers.has(cell), "and leaves the copy")
	events.clear()
	var bed_cell := Vector3i(a.feet().x + 1, a.feet().y, a.feet().z)
	var bed := placed.put("tools:grass_mat", bed_cell)
	var stood: Vector3 = a.position
	a.vitals.energy = Vitals.MAX
	var mats: int = a.inventory.count("tools:grass_mat")
	_check(net.request(Protocol.LIE_IN, [Vector3i(bed_cell.x + 5, bed_cell.y, bed_cell.z)]).value == false,
		"no one lies down in a bed that is not there")
	_check(net.request(Protocol.LIE_IN, [bed_cell]).value == false and a.position == stood and not a.vitals.asleep
		and placed.things.has(bed) and a.inventory.count("tools:grass_mat") == mats,
		"a rested player tapping a mat does not lie down, nor takes it (that is the build mode's)")
	a.vitals.energy = 10.0
	_check(net.request(Protocol.LIE_IN, [bed_cell]).value == true and a.vitals.asleep and a.position == placed.lying_spot(bed)
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.TELEPORT and e[1] == [placed.lying_spot(bed)]),
		"a sleepy player tapping a mat lies down on it asleep, and the client is told where")
	a.vitals.sleep(false)
	a.teleport(stood)
	placed._remove(bed)
	events.clear()
	var fire_cell := Vector3i(12, 2, 12)
	var fire := placed.put(Placed.CAMPFIRE, fire_cell)
	placed.put_out(fire)
	host.flush(net)
	var start: float = Items.get_item(Placed.CAMPFIRE).fuel_start
	_check(events.has([Protocol.PROP, [{"item": Placed.CAMPFIRE, "cell": [12, 2, 12], "fuel": start}]])
		and events.has([Protocol.PROP_LIT, [fire_cell, false]]) and not copy.at(fire_cell).lit,
		"a fire put out is told to the copy")
	events.clear()
	a.inventory.add("resources:branch", 1)
	placed.light(a, fire)
	placed.step(Placed.FUEL_TELL)
	host.flush(net)
	_check(events.has([Protocol.PROP_FUEL, [fire_cell, fire.fuel]]) and is_equal_approx(copy.at(fire_cell).fuel, fire.fuel)
		and copy.at(fire_cell).lit, "a fire lit again and burning down is told to the copy with what it has left")
	events.clear()
	# A door by the player is opened through the server, and the copy opens it too.
	var door_cell := Vector3i(a.feet().x + 1, a.feet().y, a.feet().z + 1)
	placed.put("tools:door", door_cell, null, true, -1.0, null, 1)
	host.flush(net)
	_check(net.request(Protocol.PROP_OPEN, [door_cell]).value == true and placed.at(door_cell).open,
		"a tap on a door opens it")
	host.flush(net)
	_check(events.has([Protocol.PROP_OPENED, [door_cell, true]]) and copy.at(door_cell).open
		and copy.at(door_cell).turn == 1, "and the copy is told, turned as it stands")
	_check(net.request(Protocol.PROP_OPEN, [fire_cell]).value == false, "a fire is no door")
	events.clear()
	# A wall of the blueprint drawn through the server: the ghost is told, and built.
	a.hands = ["materials:planks", ""]
	a.active = 0
	a.inventory.add("materials:planks", 4)
	var g0 := Vector3i(a.feet().x - 3, a.feet().y, a.feet().z - 3)
	# Ramps rising east (WorldData.FORM_RAMP, side 1).
	var ramp := WorldData.FORM_RAMP | 1 << 2
	_check(net.request(Protocol.PLAN, ["line", g0, g0 + Vector3i(2, 0, 0), 1, 1, false, ramp]).value == 3 and s.plans.cells.size() == 3,
		"a wall of the blueprint is drawn on the server")
	_check(s.plans.forms.size() == 3 and s.plans.forms.values().all(func(f: int) -> bool: return f == ramp),
		"with the form chosen for its blocks")
	host.flush(net)
	_check(events.any(func(e: Array) -> bool: return e[0] == Protocol.PLAN_CELLS and e[1][1] == "materials:planks" \
		and e[1][0].size() == 3 and e[1][2] == [ramp, ramp, ramp]), "and the ghost is told to the client, forms too")
	_check(net.request(Protocol.PLAN, ["roof", g0, g0, 1, 1, false, 0]).value == null, "a shape of no known kind is refused")
	_check(net.request(Protocol.BUILD, []).value is Dictionary, "the build mode's button builds through the server")
	_check(net.request(Protocol.PLAN_CLEAR, []).value >= 2 and s.plans.cells.is_empty(), "and the ghost near is cleared")
	_check(net.request(Protocol.FARM, ["dig", g0, g0, false, false]).value == null, "a farming work of no known kind is refused")
	_check(net.request(Protocol.FARM, ["till", g0, g0 + Vector3i(2, 0, 0), false, false]).value is int,
		"the farming mode's marks are drawn through the server")
	_check(net.request(Protocol.FARM_WORK, []).value is Dictionary, "and its button works them through the server")
	_check(net.request(Protocol.FARM_CLEAR, []).value is int, "and they are cleared near")
	a.hands = ["", ""]
	events.clear()
	# An animal comes by the player, moves, and leaves.
	var rabbit = s.wildlife._add("animals:rabbit", at + Vector3(0.2, 0.0, 0.0))
	host.flush(net)
	_check(events.has([Protocol.ANIMAL, [rabbit.id, "animals:rabbit", rabbit.tint, rabbit.pos]])
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.SNAP and e[1].size() == 1 and e[1][0][0] == rabbit.id)
		and wild.animals.size() == 1 and wild.animals[0].pos == rabbit.pos and wild.animals[0].near,
		"an animal born reaches the copy, and where it stands")
	events.clear()
	host.flush(net)
	_check(not events.any(func(e: Array) -> bool: return e[0] == Protocol.SNAP), "one that did not move is not told again")
	# It thinks within 0.5 s, then a hop takes 0.35 s: its first paw prints come within a second.
	for i in 24:
		s.wildlife.update(0.05)
		host.flush(net)
	var snaps: Array = events.filter(func(e: Array) -> bool: return e[0] == Protocol.SNAP)
	_check(rabbit.pos != at + Vector3(0.2, 0.0, 0.0) and not snaps.is_empty() and wild.animals[0].pos == rabbit.pos
		and wild.animals[0].state == rabbit.state and wild.animals[0].fresh,
		"the rabbit runs from the player, and the copy follows it (%d snapshots)" % snaps.size())
	var pushed: Array = events.filter(func(e: Array) -> bool: return e[0] == Protocol.PUSH)
	_check(not pushed.is_empty() and pushed[0][1][0] is Vector3 and pushed[0][1][0] != Vector3.ZERO,
		"the rabbit the player stood on pushed the body, the client is told")
	_check(events.any(func(e: Array) -> bool: return e[0] == Protocol.STEP and e[1][0] == rabbit.id), "its paw prints are told")
	events.clear()
	s.wildlife._remove(rabbit)
	host.flush(net)
	_check(events == [[Protocol.ANIMAL_GONE, [rabbit.id]]] and wild.animals.is_empty() and wild.by_id(rabbit.id) == null,
		"an animal gone leaves the copy")
	events.clear()
	var stone: int = a.inventory.slots.find(["resources:stone", 2])
	net.request(Protocol.THROW, [stone, 2])
	_check(a.inventory.count("resources:stone") == 0 and events.any(func(e: Array) -> bool: return e[0] == Protocol.DROPS and e[1] == [Vector2i(0, 0)])
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.YOU and e[1].held_back == [at]),
		"a thing thrown away lies in the chunk the event names, and the bag holds back from it")
	events.clear()
	var back := Vector3(5.0, 2.0, 5.0) * WorldData.CELL
	a.home = back
	a.die()
	_check(a.is_dead(), "the character dies")
	_check(net.request(Protocol.REVIVE, [back]).value == true and not a.is_dead() and a.position == back
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.TELEPORT and e[1] == [back]),
		"and comes back by request at its respawn point, the client told to put the body there")
	events.clear()
	a.nag("test", "Hot!")
	a.nag("test", "Hot!")
	host.flush(net)
	_check(events.filter(func(e: Array) -> bool: return e[0] == Protocol.SAY and e[1] == ["Hot!"]).size() == 1,
		"what the rules say reaches the client once")
	# Straight to the host, past the connection's count: the same bytes twice.
	a.inventory.add("resources:fiber", 3)
	var msg := Protocol.encode(Protocol.request(Protocol.CRAFT, 1000, ["materials:cord", 1]))
	var first: Array = host.deliver(msg)
	var again: Array = host.deliver(msg)
	_check(Protocol.decode(first.back()) == [1000, 1] and again.back() == first.back() and again.size() == 1 and shop.queue.jobs.size() == 1,
		"a request sent twice is answered the same and done once, with nothing changed to tell")
	_check(host.deliver(Protocol.encode(Protocol.request(Protocol.CRAFT, 50, ["materials:cord", 1]))) == [Protocol.encode([50, null])]
		and shop.queue.jobs.size() == 1, "a request older than the last answered is refused")
	_check(net.request(Protocol.CRAFT, ["materials:cord", 1]).value == null, "so is the connection's next, behind the count")
	host.link.leave()
	_check(s.players.is_empty(), "a player who leaves is out of the session")
	events.clear()
	placed.put("tools:chest", cell)
	s.wildlife._add("animals:rabbit", at)
	host.flush(net)
	_check(not events.any(func(e: Array) -> bool: return e[0] in [Protocol.PROP, Protocol.ANIMAL]),
		"and is told nothing of the world any more")


## Feeds the copies of the things placed, the clock and the animals as Mirror does.
func _feed(kind: String, args: Variant, copy: RemotePlaced, clock: RemoteClock, wild: RemoteWildlife) -> void:
	match kind:
		Protocol.PROPS:
			copy.take_all(args[0])
		Protocol.PROP:
			copy.take_prop(args[0])
		Protocol.PROP_GONE:
			copy.take_gone(args[0])
		Protocol.PROP_LIT:
			copy.take_lit(args[0], args[1])
		Protocol.PROP_OPENED:
			copy.take_open(args[0], args[1])
		Protocol.PROP_FUEL:
			copy.take_fuel(args[0], args[1])
		Protocol.CHEST:
			copy.take_chest(args[0], args[1])
		Protocol.CLOCK:
			clock.from_snapshot(args[0])
		Protocol.ANIMAL:
			wild.take_born(args)
		Protocol.ANIMAL_GONE:
			wild.take_gone(args)
		Protocol.SNAP:
			wild.take_snap(args)
		Protocol.STEP:
			wild.take_step(args)
