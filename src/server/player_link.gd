extends RefCounted
## One player on the server (plan/architecture/server.md): their character (Player)
## and workshop in the session, their requests (Requests), and the events that go back
## to the client's copies (Protocol.YOU, VITALS, KNOWLEDGE, SHOP, SAY, MADE, DROPS,
## TELEPORT, KNOCK). What changed is noted from the rules' signals and sent once per flush: after
## a request, so the client sees the state before the reply, and after each tick. The
## methods are connected, not lambdas, so the link is freed with the session.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Player := preload("res://src/server/player.gd")
const Requests := preload("res://src/server/requests.gd")
const Workshop := preload("res://src/shared/game/workshop.gd")

var session
var who: Player
var workshop: Workshop
var requests: Requests
## Events encoded, waiting for the next flush.
var outbox: Array[PackedByteArray] = []
var _you := true
var _shop := true
var _knowledge := true
var _vitals: Array = []


func _init(s) -> void:
	session = s
	who = Player.new()
	workshop = Workshop.new(who, session.placed, session.rules)
	who.tool_used.connect(workshop.use_tool)
	requests = Requests.new(session, who, workshop)
	session.add_player(who, workshop)
	who.inventory.changed.connect(_mark_you)
	who.state_changed.connect(_mark_you)
	workshop.knowledge.learned.connect(_on_learned)
	workshop.changed.connect(_mark_shop)
	workshop.made.connect(_on_made)
	who.said.connect(_on_said)
	who.laid.connect(_on_laid)
	who.moved.connect(_on_moved)
	who.knocked.connect(_on_knocked)


## Takes the player out of the session.
func leave() -> void:
	session.remove_player(who)


## Takes message `bytes` from the client: the reply's bytes for a request, null for an
## event.
func handle(bytes: PackedByteArray) -> Variant:
	var msg := Protocol.decode(bytes)
	if msg.size() == 3:
		return Protocol.encode(requests.handle(msg))
	if msg.size() == 2 and msg[0] == Protocol.INPUT and msg[1] is Array:
		who.take_input(msg[1])
	return null


## The events for the client since the last flush: the state noted as changed first,
## then what the rules told meanwhile (a teleport after a death undone, a line after
## the bag it speaks of).
func flush() -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	if _you:
		_you = false
		_vitals = _vitals_now()
		out.append(_event(Protocol.YOU, {"inventory": who.inventory.to_dict(), "vitals": _vitals, "state": who.to_dict(),
			"home": who.home, "held_back": Array(who.held_back)}))
	else:
		var v := _vitals_now()
		if v != _vitals:
			_vitals = v
			out.append(_event(Protocol.VITALS, v))
	if _knowledge:
		_knowledge = false
		out.append(_event(Protocol.KNOWLEDGE, [workshop.knowledge.to_dict()]))
	if _shop:
		_shop = false
		out.append(_event(Protocol.SHOP, {"queue": workshop.queue.to_dict(), "paused": workshop.paused}))
	out.append_array(outbox)
	outbox = []
	return out


func _vitals_now() -> Array:
	var v = who.vitals
	return [v.health, v.satiety, v.stamina, v.hunger, v.hurt_by]


func _push(kind: String, args: Variant) -> void:
	outbox.append(_event(kind, args))


static func _event(kind: String, args: Variant) -> PackedByteArray:
	return Protocol.encode(Protocol.event(kind, args))


func _mark_you() -> void:
	_you = true


func _mark_shop() -> void:
	_shop = true


func _on_learned(_id: String) -> void:
	_knowledge = true


func _on_made(r: Dictionary) -> void:
	_push(Protocol.MADE, [r.id])


func _on_said(text: String) -> void:
	_push(Protocol.SAY, [text])


func _on_laid(key: Vector2i) -> void:
	_push(Protocol.DROPS, [key])


func _on_moved(at: Vector3) -> void:
	_push(Protocol.TELEPORT, [at])


func _on_knocked(dir: Vector2, speed: float, hop: float) -> void:
	_push(Protocol.KNOCK, [dir, speed, hop])
