extends RefCounted
## One player on the server (plan/architecture/server.md): their character (Player)
## and workshop in the session, their requests (Requests), and the events that go back
## to the client's copies: of the player's own state (Protocol.YOU, VITALS, KNOWLEDGE,
## SHOP, SAY, MADE, DROPS, TELEPORT, KNOCK, PUSH), of the things placed (PROPS, PROP,
## PROP_GONE, PROP_LIT, CHEST), of the clock (CLOCK) and of the animals (ANIMAL,
## ANIMAL_GONE, SNAP, STEP). What changed is noted from the rules' signals and sent
## once per flush: after a request, so the client sees the state before the reply, and
## after each tick. The methods are connected, not lambdas, so the link is freed with
## the session; what is connected to the session's own objects is disconnected on leave.

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
## Seconds between the clock's snapshots (CLOCK); the client runs the time between them.
const CLOCK_EVERY := 0.25
## Seconds between the animals' snapshots (SNAP): 0 sends one every flush (the loop);
## over a socket the server sets a few a second.
var snap_every := 0.0
var _snap_sent := -1.0

var _you := true
var _shop := true
var _knowledge := true
var _vitals: Array = []
## On joining, every thing placed and every animal there is goes in one flush.
var _all := true
var _clock_sent := -1.0
## The last SNAP entry sent of each animal, by its id: one that did not move is not sent again.
var _snapped := {}


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
	var placed = session.placed
	placed.added.connect(_on_placed)
	placed.removed.connect(_on_removed)
	placed.lit_changed.connect(_on_lit)
	for e: Dictionary in placed.things:
		_watch_chest(e)
	var wild = session.wildlife
	wild.born.connect(_on_born)
	wild.gone.connect(_on_gone)
	wild.stepped.connect(_on_stepped)


## Takes the player out of the session, and the link off the session's signals.
func leave() -> void:
	session.remove_player(who)
	var placed = session.placed
	placed.added.disconnect(_on_placed)
	placed.removed.disconnect(_on_removed)
	placed.lit_changed.disconnect(_on_lit)
	for e: Dictionary in placed.things:
		if e.items != null and e.items.changed.is_connected(_chest_call(e)):
			e.items.changed.disconnect(_chest_call(e))
	var wild = session.wildlife
	wild.born.disconnect(_on_born)
	wild.gone.disconnect(_on_gone)
	wild.stepped.disconnect(_on_stepped)


## The player comes back on a new connection (a page reloaded): the requests count
## from one again, and the next flush brings everything, as on joining.
func rejoin() -> void:
	requests.last_seq = -1
	requests.last_reply = []
	_you = true
	_shop = true
	_knowledge = true
	_all = true
	_clock_sent = -1.0
	_snap_sent = -1.0


## Takes message `bytes` from the client: the reply's bytes for a request, null for an
## event.
func handle(bytes: PackedByteArray) -> Variant:
	var msg := Protocol.decode(bytes)
	if msg.size() == 3:
		return Protocol.encode(requests.handle(msg))
	if msg.size() == 2 and msg[0] == Protocol.INPUT and msg[1] is Array:
		who.take_input(msg[1])
	return null


## A line for the player (the host's `say`).
func tell(text: String) -> void:
	_push(Protocol.SAY, [text])


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
	var now := Time.get_ticks_msec() / 1000.0
	if _clock_sent < 0.0 or now - _clock_sent >= CLOCK_EVERY:
		_clock_sent = now
		out.append(_event(Protocol.CLOCK, [session.clock.snapshot()]))
	if _all:
		_all = false
		out.append(_event(Protocol.PROPS, [session.placed.to_list()]))
		for a in session.wildlife.animals:
			out.append(_event(Protocol.ANIMAL, [a.id, a.kind, a.tint, a.pos]))
		_snapped.clear()
	out.append_array(outbox)
	outbox = []
	if snap_every <= 0.0 or _snap_sent < 0.0 or now - _snap_sent >= snap_every:
		_snap_sent = now
		var snap := _snap()
		if not snap.is_empty():
			out.append(_event(Protocol.SNAP, snap))
	var push: Vector3 = session.push_on(who)
	if push != Vector3.ZERO:
		out.append(_event(Protocol.PUSH, [push]))
	return out


## The entries of a SNAP: the animals that stepped since the last flush and are not
## where they were last told to be.
func _snap() -> Array:
	var out := []
	for a in session.wildlife.animals:
		if a.away != 0.0 and _snapped.has(a.id):
			continue
		var s := [a.id, a.pos, a.lift, a.facing, a.flying, a.perched, a.moving, a.hop, a.left, a.near, a.state]
		if _snapped.get(a.id) != s:
			_snapped[a.id] = s
			out.append(s)
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


func _on_placed(e: Dictionary) -> void:
	_watch_chest(e)
	_push(Protocol.PROP, [session.placed.record(e)])


func _on_removed(e: Dictionary) -> void:
	if e.items != null and e.items.changed.is_connected(_chest_call(e)):
		e.items.changed.disconnect(_chest_call(e))
	_push(Protocol.PROP_GONE, [e.cell])


func _on_lit(e: Dictionary) -> void:
	_push(Protocol.PROP_LIT, [e.cell, e.lit])


## Listens to what thing `e` holds, if it stores; the cell names it (not the record:
## an inventory holding a callable to a record that holds it would never be freed).
func _watch_chest(e: Dictionary) -> void:
	if e.items != null and not e.items.changed.is_connected(_chest_call(e)):
		e.items.changed.connect(_chest_call(e))


func _chest_call(e: Dictionary) -> Callable:
	return _on_chest.bind(e.cell)


func _on_chest(cell: Vector3i) -> void:
	var e: Dictionary = session.placed.at(cell)
	if not e.is_empty() and e.items != null:
		_push(Protocol.CHEST, [cell, e.items.to_dict()])


func _on_born(a) -> void:
	# On joining the next flush names every animal there is (the server lets them in
	# with the first player): not twice.
	if not _all:
		_push(Protocol.ANIMAL, [a.id, a.kind, a.tint, a.pos])


func _on_gone(a) -> void:
	_snapped.erase(a.id)
	_push(Protocol.ANIMAL_GONE, [a.id])


func _on_stepped(a, at: Vector3, dir: Vector2, left: bool, size: float) -> void:
	_push(Protocol.STEP, [a.id, at, dir, left, size])
