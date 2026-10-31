extends "res://tests/unit/test_case.gd"
## The protocol between the client and the server (plan/architecture/server.md): the
## shape of a message on the wire, the requests of a player done by the rules on the
## server's side through the loop of single player (LocalHost), a request sent twice
## done once, requests that do not fit refused.

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


## A character plays through the loop: digs, crafts, moves a stack into a chest, comes
## back from the dead; a request sent twice is done once; one that does not fit is refused.
func _test_requests() -> void:
	var w := WorldData.new(8, Vector2i(32, 32))
	for z in 32:
		for x in 32:
			w.set_cell(x, 0, z, Mat.STONE)
			w.set_cell(x, 1, z, Mat.DIRT)
	var placed := Placed.new()
	var s := Session.new(w, null, Clock.new(), Rules.of({"instant_craft": true}), placed)
	var a := Survivor.new()
	a.body = Body.new()
	a.at = Vector3(8.5, 2.0, 8.5) * WorldData.CELL
	var shop := Workshop.new(a, placed, s.rules)
	s.add_player(a, shop)
	var host := LocalHost.new(s, a, shop)
	var net := host.link()
	var r := net.request(Protocol.DIG, [Vector3i(8, 1, 7), Vector3i.UP])
	_check(r.done and r.value is Dictionary and r.value.has("swing") and w.get_cell(8, 1, 7) == Mat.AIR,
		"a dig request over the loop is done at once and answered with what the rule gave")
	var seen: Array = []
	r.then(func(v: Variant) -> void: seen.append(v))
	_check(seen.size() == 1 and seen[0] == r.value, "a callback given after the reply runs at once")
	_check(net.sent_bytes > 0 and net.received_bytes > 0 and net.pending() == 0,
		"the bytes both ways are counted (%d sent, %d received)" % [net.sent_bytes, net.received_bytes])
	_check(net.request(Protocol.EAT, ["x"]).value == null and net.request(Protocol.DIG, [Vector3i.ZERO]).value == null
		and net.request("nothing", []).value == null, "a request that does not fit is answered null and does nothing")
	a.inventory.add("resources:fiber", 3)
	_check(net.request(Protocol.CRAFT, ["materials:cord", 1]).value == 1 and shop.queue.jobs.size() == 1,
		"a recipe is started by its id")
	s.tick(0.1)
	_check(a.inventory.count("materials:cord") == 1, "the job started by the request is made by the tick")
	var cell := Vector3i(10, 2, 10)
	placed.put("tools:chest", cell)
	var chest = placed.at(cell).items
	_check(chest != null and placed.at(Vector3i(11, 2, 10)).is_empty(), "a thing placed is found by its north-west cell")
	a.inventory.add("resources:stone", 2)
	var slot := a.inventory.slots.find(["resources:stone", 2])
	_check(net.request(Protocol.BAG_MOVE, [null, slot, cell]).value == 2 and chest.count("resources:stone") == 2
		and a.inventory.count("resources:stone") == 0, "a stack moves from the bag into a chest named by its cell")
	_check(net.request(Protocol.BAG_MOVE, [cell, 0, null]).value == 2 and a.inventory.count("resources:stone") == 2,
		"and back")
	_check(net.request(Protocol.BAG_MOVE, [null, 0, Vector3i(20, 2, 20)]).value == null, "a chest at an empty cell is nobody's")
	_check(net.request(Protocol.PROP_FIRE, [cell, true]).value == false and net.request(Protocol.PROP_DESTROY, [cell]).value == false,
		"a chest is not lit or destroyed")
	_check(net.request(Protocol.PROP_TAKE, [cell]).value == true and placed.things.is_empty()
		and a.inventory.count("tools:chest") == 1, "a thing placed is taken up by its cell")
	a.die()
	_check(a.is_dead(), "the character dies")
	_check(net.request(Protocol.REVIVE, [Vector3(5.0, 2.0, 5.0) * WorldData.CELL]).value == true and not a.is_dead()
		and a.back_at == Vector3(5.0, 2.0, 5.0) * WorldData.CELL, "and comes back by request where asked")
	# Straight to the host, past the connection's count: the same bytes twice.
	a.inventory.add("resources:fiber", 3)
	var msg := Protocol.encode(Protocol.request(Protocol.CRAFT, 1000, ["materials:cord", 1]))
	var first := host.deliver(msg)
	var again := host.deliver(msg)
	_check(Protocol.decode(first) == [1000, 1] and again == first and shop.queue.jobs.size() == 1,
		"a request sent twice is answered the same and done once")
	_check(host.deliver(Protocol.encode(Protocol.request(Protocol.CRAFT, 50, ["materials:cord", 1]))) == Protocol.encode([50, null])
		and shop.queue.jobs.size() == 1, "a request older than the last answered is refused")
	_check(net.request(Protocol.CRAFT, ["materials:cord", 1]).value == null, "so is the connection's next, behind the count")
