extends RefCounted
## One player on the server (plan/architecture/server.md): their character (Player)
## and workshop in the session, their requests (Requests), and the events that go back
## to the client's copies: of the player's own state (Protocol.YOU, VITALS, KNOWLEDGE,
## SHOP, SAY, MADE, DROPS, TELEPORT, KNOCK, PUSH; HEARD, the chat), of the things placed (PROPS, PROP,
## PROP_GONE, PROP_LIT, CHEST), of the clock (CLOCK) and of the animals (ANIMAL,
## ANIMAL_GONE, SNAP, STEP). What changed is noted from the rules' signals and sent
## once per flush: after a request, so the client sees the state before the reply, and
## after each tick. Over a socket (send_world) the link also brings the client its copy
## of the world (С3.2): the chunks made within Session.ZONE of the body, nearest first
## (CHUNK, a few a flush; FORGET beyond Session.DROP; a chunk whose looks changed is sent
## again), the cells changed in the chunks it holds (CELLS), the things on the ground
## with their list (DROPS) and what was taken (TAKEN); over the loop the client reads
## the one world itself. The methods are connected, not lambdas, so the link is freed
## with the session; what is connected to the session's own objects is disconnected on
## leave.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Player := preload("res://src/server/player.gd")
const Requests := preload("res://src/server/requests.gd")
const Workshop := preload("res://src/shared/game/workshop.gd")
const Session := preload("res://src/shared/game/session.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")

## Chunks sent in one flush at most (each a few KB zstd).
const CHUNKS_PER_FLUSH := 2

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
## Seconds between the other players' snapshots (PEOPLE); 0 every flush.
var people_every := 0.0
var _people_sent := -1.0
## The last PEOPLE entry sent of each other player, by id.
var _people := {}
## The client gets its copy of the world from here (a socket); false over the loop.
var send_world := false
## The chunks the client holds (sent and not forgotten), and those to send again.
var _sent := {}
var _again := {}
## Cells changed since the last flush, and the chunks whose things on the ground changed.
var _cells := {}
var _drops := {}

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
	# The server's body walks the world when the client's claims are checked (3А).
	who.body.world = session.world
	who.body.clock = session.clock
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
	var actions = session.actions
	actions.cell_changed.connect(_on_cell)
	placed.cell_changed.connect(_on_cell)
	actions.drops_changed.connect(_on_drops)
	actions.looks_changed.connect(_on_looks)
	actions.taken.connect(_on_taken)


## Takes the player out of the session, and the link off the session's signals.
func leave() -> void:
	session.remove_player(who)
	var placed = session.placed
	placed.added.disconnect(_on_placed)
	placed.removed.disconnect(_on_removed)
	placed.lit_changed.disconnect(_on_lit)
	placed.cell_changed.disconnect(_on_cell)
	var actions = session.actions
	actions.cell_changed.disconnect(_on_cell)
	actions.drops_changed.disconnect(_on_drops)
	actions.looks_changed.disconnect(_on_looks)
	actions.taken.disconnect(_on_taken)
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
	_people_sent = -1.0
	_people.clear()
	_sent.clear()
	_again.clear()
	_cells.clear()
	_drops.clear()


## Takes message `bytes` from the client: the reply's bytes for a request, null for an
## event.
func handle(bytes: PackedByteArray) -> Variant:
	var msg := Protocol.decode(bytes)
	if msg.size() == 3:
		return Protocol.encode(requests.handle(msg))
	if msg.size() == 2 and msg[0] == Protocol.INPUT and msg[1] is Array:
		who.take_input(msg[1])
	return null


## A line for the player (the rules' words, as their own SAY).
func tell(text: String) -> void:
	_push(Protocol.SAY, [text])


## A line of chat the player hears: said by player `id` named `name` (0 and "" the
## server).
func hear(id: int, name: String, text: String) -> void:
	_push(Protocol.HEARD, [id, name, text])


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
	elif _vitals_changed():
		_vitals = _vitals_now()
		out.append(_event(Protocol.VITALS, _vitals))
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
	if send_world:
		_world_events(out)
	for key: Vector2i in _drops:
		out.append(_event(Protocol.DROPS, [key, session.world.drops.get(key, [])] if send_world else [key]))
	_drops.clear()
	out.append_array(outbox)
	outbox = []
	if snap_every <= 0.0 or _snap_sent < 0.0 or now - _snap_sent >= snap_every:
		_snap_sent = now
		var snap := _snap()
		if not snap.is_empty():
			out.append(_event(Protocol.SNAP, snap))
	if people_every <= 0.0 or _people_sent < 0.0 or now - _people_sent >= people_every:
		_people_sent = now
		_people_events(out)
	var push: Vector3 = session.push_on(who)
	if push != Vector3.ZERO:
		out.append(_event(Protocol.PUSH, [push]))
	return out


## The client's copy of the world: the cells changed in the chunks it holds, the chunks
## within Session.ZONE of the body it lacks (nearest first, CHUNKS_PER_FLUSH a flush)
## or whose looks changed, and the chunks it holds beyond Session.DROP.
func _world_events(out: Array[PackedByteArray]) -> void:
	var cells := []
	for cell: Vector3i in _cells:
		if _sent.has(WorldData.chunk_key(cell.x, cell.z)):
			cells.append([cell, session.world.get_cell(cell.x, cell.y, cell.z)])
	_cells.clear()
	if not cells.is_empty():
		out.append(_event(Protocol.CELLS, cells))
	var gen = session.gen
	if gen == null:
		return
	var at: Vector3 = who.position
	var home := WorldData.chunk_key(floori(at.x / WorldData.CELL), floori(at.z / WorldData.CELL))
	var n := 0
	for key: Vector2i in _again:
		if _sent.has(key) and gen.stage_of(key) >= WorldGen.SHAPED:
			out.append(_event(Protocol.CHUNK, _packed(key)))
			n += 1
	_again.clear()
	for r in range(0, Session.ZONE + 1):
		if n >= CHUNKS_PER_FLUSH:
			break
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r or n >= CHUNKS_PER_FLUSH:
					continue
				var key := Vector2i(home.x + dx, home.y + dz)
				if _sent.has(key) or gen.stage_of(key) < WorldGen.SHAPED:
					continue
				out.append(_event(Protocol.CHUNK, _packed(key)))
				_sent[key] = true
				n += 1
	for key: Vector2i in _sent.keys():
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > Session.DROP:
			_sent.erase(key)
			out.append(_event(Protocol.FORGET, [key]))


## The other players within Session.ZONE chunks of the body, those whose entry changed
## since last told (PEOPLE), and those gone out of it or out of the world, or dead
## (PERSON_GONE).
func _people_events(out: Array[PackedByteArray]) -> void:
	var at: Vector3 = who.position
	var home := WorldData.chunk_key(floori(at.x / WorldData.CELL), floori(at.z / WorldData.CELL))
	var here := {}
	var changed := []
	for p in session.players:
		if p == who or p.get("player_name") == null or p.is_dead():
			continue
		var pp: Vector3 = p.position
		var key := WorldData.chunk_key(floori(pp.x / WorldData.CELL), floori(pp.z / WorldData.CELL))
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > Session.ZONE:
			continue
		var e := [p.id, p.player_name, pp, p.facing, p.hands.duplicate(), p.active, p.is_moving, p.body.swimming,
			p.on_ground, p.work[0], p.work[1], p.work[2], p.work[3]]
		here[p.id] = true
		if _people.get(p.id) != e:
			_people[p.id] = e
			changed.append(e)
	for id in _people.keys():
		if not here.has(id):
			_people.erase(id)
			out.append(_event(Protocol.PERSON_GONE, [id]))
	if not changed.is_empty():
		out.append(_event(Protocol.PEOPLE, changed))


## The CHUNK args of chunk `key`: its record, var_to_bytes and zstd.
func _packed(key: Vector2i) -> Array:
	var raw := var_to_bytes(session.gen.pack(key))
	return [key, raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)]


## The entries of a SNAP: the animals that stepped since the last flush and are not
## where they were last told to be.
func _snap() -> Array:
	var out := []
	for a in session.wildlife.animals:
		var old: Variant = _snapped.get(a.id)
		if old != null and (a.away != 0.0 or _same_snap(old, a)):
			continue
		var s := [a.id, a.pos, a.lift, a.facing, a.flying, a.perched, a.moving, a.hop, a.left, a.near, a.state]
		if _snapped.get(a.id) != s:
			_snapped[a.id] = s
			out.append(s)
	return out


## Whether animal `a` stands as entry `old` told: no Array is made for one that did
## not move (most stand still most frames, and over the loop this runs every frame).
static func _same_snap(old: Array, a) -> bool:
	return old[1] == a.pos and old[10] == a.state and old[3] == a.facing and old[6] == a.moving \
		and old[7] == a.hop and old[2] == a.lift and old[4] == a.flying and old[5] == a.perched \
		and old[8] == a.left and old[9] == a.near


## Whether the body's state differs from the last told (no Array made a frame).
func _vitals_changed() -> bool:
	var v = who.vitals
	return _vitals.size() != 5 or _vitals[0] != v.health or _vitals[1] != v.satiety or _vitals[2] != v.stamina \
		or _vitals[3] != v.hunger or _vitals[4] != v.hurt_by


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
	_drops[key] = true


func _on_drops(key: Vector2i) -> void:
	_drops[key] = true


func _on_cell(cell: Vector3i) -> void:
	if send_world:
		_cells[cell] = true


func _on_looks(key: Vector2i) -> void:
	if send_world:
		_again[key] = true


func _on_taken(id: String, from: Vector3) -> void:
	if send_world:
		_push(Protocol.TAKEN, [id, from])


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
