extends "res://tests/unit/test_case.gd"
## The protocol between the client and the server (plan/architecture/server.md): the
## shape of a message on the wire, the requests of a player done by the rules on the
## server's side through the loop of single player (LocalHost), the events of their
## state back (PlayerLink), a request sent twice done once, requests that do not fit
## refused.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Requests := preload("res://src/server/requests.gd")
const Connection := preload("res://src/client/net/connection.gd")
const LocalHost := preload("res://src/client/net/local_host.gd")


func run() -> void:
	_test_protocol()
	_test_requests()


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
## server's events bring the client its state before the reply; a request sent twice is
## done once; one that does not fit is refused.
func _test_requests() -> void:
	var w := WorldData.new(8, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var placed := Placed.new()
	var s := Session.new(w, null, Clock.new(), Rules.of({"instant_craft": true}), placed)
	var host := LocalHost.new(s)
	var net := host.join()
	var a = host.player
	var shop = host.workshop
	_check(s.players == [a] and s.workshops == [shop], "the player who joins is in the session with their workshop")
	var events: Array = []
	net.event.connect(func(kind: String, args: Variant) -> void: events.append([kind, args]))
	var at := Vector3(8.5, 2.0, 8.5) * WorldData.CELL
	net.send(Protocol.INPUT, [at, Vector3i(8, 2, 8), Vector2i(0, -1), ["", ""], 0, 0, false, false, false, false, Vector3.INF])
	_check(a.position == at and a.feet() == Vector3i(8, 2, 8) and a.facing_step() == Vector2i(0, -1) and a.held() == "",
		"the server's character stands where the client's body is, with its hands")
	net.send(Protocol.INPUT, [at, Vector3i(8, 2, 8)])
	_check(a.position == at, "an input that does not fit changes nothing")
	host.flush(net)
	var you: Array = events.filter(func(e: Array) -> bool: return e[0] == Protocol.YOU)
	_check(you.size() == 1 and you[0][1].inventory == a.inventory.to_dict() and you[0][1].vitals[0] == a.vitals.health,
		"the first flush brings the player their state")
	events.clear()
	var r = net.request(Protocol.DIG, [Vector3i(8, 1, 7), Vector3i.UP])
	_check(r.done and r.value is Dictionary and r.value.has("swing") and w.get_cell(8, 1, 7) == Mat.AIR,
		"a dig request over the loop is done at once and answered with what the rule gave")
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
	var cell := Vector3i(10, 2, 10)
	placed.put("tools:chest", cell)
	var chest = placed.at(cell).items
	_check(chest != null and placed.at(Vector3i(11, 2, 10)).is_empty(), "a thing placed is found by its north-west cell")
	a.inventory.add("resources:stone", 2)
	var slot: int = a.inventory.slots.find(["resources:stone", 2])
	_check(net.request(Protocol.BAG_MOVE, [null, slot, cell]).value == 2 and chest.count("resources:stone") == 2
		and a.inventory.count("resources:stone") == 0, "a stack moves from the bag into a chest named by its cell")
	_check(net.request(Protocol.BAG_MOVE, [cell, 0, null]).value == 2 and a.inventory.count("resources:stone") == 2,
		"and back")
	_check(net.request(Protocol.BAG_MOVE, [null, 0, Vector3i(20, 2, 20)]).value == null, "a chest at an empty cell is nobody's")
	_check(net.request(Protocol.PROP_FIRE, [cell, true]).value == false and net.request(Protocol.PROP_DESTROY, [cell]).value == false,
		"a chest is not lit or destroyed")
	_check(net.request(Protocol.PROP_TAKE, [cell]).value == true and placed.things.is_empty()
		and a.inventory.count("tools:chest") == 1, "a thing placed is taken up by its cell")
	events.clear()
	var stone: int = a.inventory.slots.find(["resources:stone", 2])
	net.request(Protocol.THROW, [stone, 2])
	_check(a.inventory.count("resources:stone") == 0 and events.any(func(e: Array) -> bool: return e[0] == Protocol.DROPS and e[1] == [Vector2i(0, 0)])
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.YOU and e[1].held_back == [at]),
		"a thing thrown away lies in the chunk the event names, and the bag holds back from it")
	events.clear()
	a.die()
	_check(a.is_dead(), "the character dies")
	var back := Vector3(5.0, 2.0, 5.0) * WorldData.CELL
	_check(net.request(Protocol.REVIVE, [back]).value == true and not a.is_dead() and a.position == back
		and events.any(func(e: Array) -> bool: return e[0] == Protocol.TELEPORT and e[1] == [back]),
		"and comes back by request where asked, the client told to put the body there")
	events.clear()
	a.nag("test", "Горячо!")
	a.nag("test", "Горячо!")
	host.flush(net)
	_check(events.filter(func(e: Array) -> bool: return e[0] == Protocol.SAY and e[1] == ["Горячо!"]).size() == 1,
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
