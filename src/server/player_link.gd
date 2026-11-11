extends RefCounted
## One player on the server (plan/architecture/server.md): their character (Player)
## and workshop in the session, their requests (Requests), and the events that go back
## to the client's copies: of the player's own state (Protocol.YOU, VITALS, KNOWLEDGE,
## SKILLS, SHOP, SAY, MADE, DROPS, TELEPORT, KNOCK, PUSH, LINE, FLOW; HEARD, the chat; TEAM and INVITES, the
## team; CLAIMS, SQUARES and LAND, the territory), of the things placed (PROPS, PROP,
## PROP_GONE, PROP_LIT, PROP_OPENED, PROP_FUEL, CHEST), of the blueprint (PLANS, PLAN_CELLS), of the rafts and boats
## (VESSELS, VESSEL, VESSEL_GONE), of the clock (CLOCK) and of the animals (ANIMAL,
## ANIMAL_GONE, SNAP, STEP). What changed is noted from the rules' signals and sent
## once per flush: after a request, so the client sees the state before the reply, and
## after each tick. Over a socket (send_world) the link also brings the client its copy
## of the world (С3.2): the chunks made within Session.ZONE of the body (farther for a larger screen, Session.reach_for), nearest first
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
const Vessels := preload("res://src/shared/game/vessels.gd")
const Gestures := preload("res://src/shared/game/gestures.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")

## Chunks sent in one flush at most (each a few KB zstd).
const CHUNKS_PER_FLUSH := 2

## The points of the skills, growing with each swing, are told no more often than this
## (seconds), and at once when a level rose.
const SKILLS_EVERY := 1.0
## Seconds between the minds of the animals near (Protocol.MINDS) while the player asked
## for them, and how far round the body they are told (world units).
const MINDS_EVERY := 0.25
const MINDS_REACH := 30.0
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
var _team := true
var _invites := true
## The claims are told again (made, gone, a team changed); squares changed since the last
## flush (all of them when `_squares_all`); the land told last ([used, budget]).
var _claims := true
var _squares_all := true
var _squares: Array = []
var _land: Array = []
var _fight: Array = []
## The fishing line last told ([float, bite]).
var _line: Array = [Vector3.INF, false]
var _flow := Vector2.ZERO
## How much the current where the player is changes before it is told again (cells a
## second).
const FLOW_TOLD := 0.05
var _shop := true
var _knowledge := true
## The skills: changed since told (`_skills`), a level rose (`_skills_now`), when last told.
var _skills := true
var _skills_now := false
var _skills_sent := -1.0
var _vitals: Array = []
## On joining, every thing placed and every animal there is goes in one flush.
var _all := true
var _clock_sent := -1.0
var _minds_sent := -1.0
## The last SNAP entry sent of each animal, by its id: one that did not move is not sent again.
var _snapped := {}
## The next snapshot looks at every animal (on joining), else at those that stepped and
## those born since the last one (see _snap).
var _snap_all := true
var _born := []


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
	who.skills.changed.connect(_on_skills)
	who.skills.leveled.connect(_on_leveled)
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
	placed.fuel_changed.connect(_on_fuel)
	placed.opened.connect(_on_opened)
	for e: Dictionary in placed.things:
		_watch_chest(e)
	session.plans.changed.connect(_on_plan)
	var wild = session.wildlife
	wild.born.connect(_on_born)
	wild.gone.connect(_on_gone)
	wild.stepped.connect(_on_stepped)
	var actions = session.actions
	actions.cell_changed.connect(_on_cell)
	actions.cells_set.connect(_on_cells)
	placed.cell_changed.connect(_on_cell)
	actions.drops_changed.connect(_on_drops)
	actions.looks_changed.connect(_on_looks)
	actions.taken.connect(_on_taken)
	actions.vessels.changed.connect(_on_vessel)
	actions.vessels.gone.connect(_on_vessel_gone)
	session.teams.changed.connect(_on_team)
	session.teams.invited.connect(_on_invited)
	session.territory.claims_changed.connect(_on_claims)
	session.territory.squares_changed.connect(_on_squares)


## Takes the player out of the session, and the link off the session's signals.
func leave() -> void:
	session.remove_player(who)
	var placed = session.placed
	placed.added.disconnect(_on_placed)
	placed.removed.disconnect(_on_removed)
	placed.lit_changed.disconnect(_on_lit)
	placed.fuel_changed.disconnect(_on_fuel)
	placed.opened.disconnect(_on_opened)
	placed.cell_changed.disconnect(_on_cell)
	var actions = session.actions
	actions.cell_changed.disconnect(_on_cell)
	actions.cells_set.disconnect(_on_cells)
	actions.drops_changed.disconnect(_on_drops)
	actions.looks_changed.disconnect(_on_looks)
	actions.taken.disconnect(_on_taken)
	actions.vessels.changed.disconnect(_on_vessel)
	actions.vessels.gone.disconnect(_on_vessel_gone)
	session.teams.changed.disconnect(_on_team)
	session.teams.invited.disconnect(_on_invited)
	session.territory.claims_changed.disconnect(_on_claims)
	session.territory.squares_changed.disconnect(_on_squares)
	session.plans.changed.disconnect(_on_plan)
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
	_team = true
	_invites = true
	_claims = true
	_squares_all = true
	_squares.clear()
	_land = []
	_fight = []
	_line = [Vector3.INF, false]
	_flow = Vector2.ZERO
	_shop = true
	_knowledge = true
	_skills = true
	_skills_now = true
	_all = true
	_clock_sent = -1.0
	_snap_sent = -1.0
	_people_sent = -1.0
	_people.clear()
	_sent.clear()
	_again.clear()
	_cells.clear()
	_drops.clear()
	# What piled up while the player was away is in the full flush; sent again after
	# it, a thing placed meanwhile would be put twice.
	outbox.clear()


## Takes message `bytes` from the client: the reply's bytes for a request, null for an
## event.
func handle(bytes: PackedByteArray) -> Variant:
	return handle_msg(Protocol.decode(bytes))


## handle for a message already decoded (Protocol.decode), as the server has it.
func handle_msg(msg: Array) -> Variant:
	if msg.size() == 3:
		return Protocol.encode(requests.handle(msg))
	if msg.size() == 2 and msg[0] is String and msg[0] == Protocol.INPUT and msg[1] is Array:
		who.take_input(msg[1])
	return null


## A line of chat the player hears: said by player `id` named `name` (0 and "" the
## server).
func hear(id: int, name: String, text: String, team := false) -> void:
	_push(Protocol.HEARD, [id, name, text, team])


## The events for the client since the last flush: the state noted as changed first,
## then what the rules told meanwhile (a teleport after a death undone, a line after
## the bag it speaks of).
func flush() -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	if _you:
		_you = false
		_vitals = _vitals_now()
		if who.is_dead():
			# Where to come back is asked of the dead only (the death screen shows it).
			who.find_respawns(session.placed, session.teams)
		out.append(_event(Protocol.YOU, {"inventory": who.inventory.to_dict(), "vitals": _vitals, "state": who.to_dict(),
			"home": who.home, "respawns": who.respawns, "held_back": Array(who.held_back)}))
	elif _vitals_changed():
		_vitals = _vitals_now()
		out.append(_event(Protocol.VITALS, _vitals))
	if _team:
		_team = false
		out.append(_event(Protocol.TEAM, [session.teams.view(who.id)]))
	if _invites:
		_invites = false
		var now := Time.get_ticks_msec() / 1000.0
		out.append(_event(Protocol.INVITES, [session.teams.invites_of(who.id, now), session.teams.sent_of(who.id, now)]))
	if _claims:
		_claims = false
		out.append(_event(Protocol.CLAIMS, [session.territory.claims_view()]))
	if _squares_all:
		_squares_all = false
		_squares.clear()
		out.append(_event(Protocol.SQUARES, [session.territory.squares_view(), true]))
	elif not _squares.is_empty():
		out.append(_event(Protocol.SQUARES, [_squares, false]))
		_squares = []
	var land := [session.territory.used(who.id), session.territory.budget(who.id)]
	if land != _land:
		_land = land
		out.append(_event(Protocol.LAND, land))
	if who.line != _line[0] or who.bite != _line[1]:
		_line = [who.line, who.bite]
		out.append(_event(Protocol.LINE, _line))
	if who.flow.distance_to(_flow) > FLOW_TOLD:
		_flow = who.flow
		out.append(_event(Protocol.FLOW, [_flow]))
	var fight: Array = session.fights.view(who.id)
	if fight != _fight:
		_fight = fight
		out.append(_event(Protocol.FIGHT, fight))
	if _knowledge:
		_knowledge = false
		out.append(_event(Protocol.KNOWLEDGE, [workshop.knowledge.to_dict()]))
	var now_s := Time.get_ticks_msec() / 1000.0
	if _skills and (_skills_now or now_s - _skills_sent >= SKILLS_EVERY):
		_skills = false
		_skills_now = false
		_skills_sent = now_s
		out.append(_event(Protocol.SKILLS, [who.skills.to_dict()]))
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
		out.append(_event(Protocol.PLANS, [session.plans.to_list()]))
		out.append(_event(Protocol.VESSELS, [session.actions.vessels.records()]))
		for a in session.wildlife.animals:
			out.append(_event(Protocol.ANIMAL, [a.id, a.kind, a.tint, a.pos]))
		_snapped.clear()
		_snap_all = true
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
	if requests.ai_debug and (_minds_sent < 0.0 or now - _minds_sent >= MINDS_EVERY):
		_minds_sent = now
		out.append(_event(Protocol.MINDS, session.wildlife.minds_near(who.position, MINDS_REACH)))
	var push: Vector3 = session.push_on(who)
	if push != Vector3.ZERO:
		out.append(_event(Protocol.PUSH, [push]))
	return out


## The client's copy of the world: the cells changed in the chunks it holds, the chunks
## within the zone its screen needs (Session.reach_for) of the body it lacks (nearest first, CHUNKS_PER_FLUSH a flush)
## or whose looks changed, and the chunks it holds beyond its drop range.
func _world_events(out: Array[PackedByteArray]) -> void:
	var cells := []
	for cell: Vector3i in _cells:
		if _sent.has(WorldData.chunk_key(cell.x, cell.z)):
			# The material, and the form of a built block over it (WorldData.forms).
			var w = session.world
			cells.append([cell, w.get_cell(cell.x, cell.y, cell.z) | w.form_at(cell.x, cell.y, cell.z) << 8])
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
	# As far as this player's screen needs (Session.reach_for), not every player's.
	var reach := Session.reach_for(who.view_half)
	var drop := reach + Session.DROP - Session.ZONE
	for r in range(0, reach + 1):
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
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > drop:
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
	var now := Time.get_ticks_msec() / 1000.0
	for p in session.players:
		if p == who or p.get("player_name") == null or p.is_dead():
			continue
		var pp: Vector3 = p.position
		var key := WorldData.chunk_key(floori(pp.x / WorldData.CELL), floori(pp.z / WorldData.CELL))
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > Session.ZONE:
			continue
		var e := [p.id, p.player_name, pp, p.facing, p.hands.duplicate(), p.active, p.is_moving, p.body.swimming,
			p.on_ground, p.work[0], p.work[1], p.work[2], p.work[3], p.inventory.gear.duplicate(),
			session.teams.together(who.id, p.id), p.line, p.riding, Gestures.now_of(p, now)]
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


## The teams of players `ids` changed: this player's own when among them (the PEOPLE
## entries say who is in it).
func _on_team(ids: Array) -> void:
	# A claim's name is its team's.
	_claims = true
	if ids.has(who.id):
		_team = true
		_invites = true
	# The dead may come back at other fires now (Character.find_respawns).
	if who.is_dead():
		_you = true


func _on_claims() -> void:
	_claims = true


func _on_squares(list: Array) -> void:
	if not _squares_all:
		_squares.append_array(list)


## Player `to` was invited to a team (or by this one).
func _on_invited(to: int, from: int, _name: String) -> void:
	if to == who.id or from == who.id:
		_invites = true


## The CHUNK args of chunk `key`: its record, var_to_bytes and zstd.
func _packed(key: Vector2i) -> Array:
	var raw := var_to_bytes(session.gen.pack(key))
	return [key, raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)]


## The entries of a SNAP: the animals that stepped since the last flush and are not
## where they were last told to be.
func _snap() -> Array:
	var out := []
	# Only those that stepped in the last tick (Wildlife.moved) and those born since can
	# have moved: not every animal, every flush. After a full flush, all of them.
	var wild = session.wildlife
	var those: Array = wild.animals if _snap_all else wild.moved + _born
	_snap_all = false
	_born = []
	for a in those:
		if a.gone:
			continue
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
	return _vitals.size() != 10 or _vitals[8] != v.energy or _vitals[9] != v.asleep or _vitals[0] != v.health or _vitals[1] != v.satiety or _vitals[2] != v.stamina \
		or _vitals[3] != v.hunger or _vitals[4] != v.hurt_by or _vitals[5] != v.warmth or _vitals[6] != v.wet or _vitals[7] != v.water


func _vitals_now() -> Array:
	var v = who.vitals
	return [v.health, v.satiety, v.stamina, v.hunger, v.hurt_by, v.warmth, v.wet, v.water, v.energy, v.asleep]


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


func _on_cells(cells: Array[Vector3i]) -> void:
	if send_world:
		for cell in cells:
			_cells[cell] = true


func _on_looks(key: Vector2i) -> void:
	if send_world:
		_again[key] = true


## Only the one who took it sees it fly into their bag.
func _on_taken(id: String, from: Vector3, by: Object) -> void:
	if send_world and by == who:
		_push(Protocol.TAKEN, [id, from])


func _on_moved(at: Vector3) -> void:
	_push(Protocol.TELEPORT, [at])


func _on_vessel(v: Dictionary) -> void:
	_push(Protocol.VESSEL, Vessels.record(v))


func _on_vessel_gone(id: int) -> void:
	_push(Protocol.VESSEL_GONE, [id])


func _on_knocked(dir: Vector2, speed: float, hop: float) -> void:
	_push(Protocol.KNOCK, [dir, speed, hop])


func _on_placed(e: Dictionary) -> void:
	_watch_chest(e)
	_push(Protocol.PROP, [session.placed.record(e)])
	_fire_moved(e)


## A fire came or went: the dead are told where they may come back now.
func _fire_moved(e: Dictionary) -> void:
	if e.has("by") and who.is_dead():
		_you = true


func _on_removed(e: Dictionary) -> void:
	if e.items != null and e.items.changed.is_connected(_chest_call(e)):
		e.items.changed.disconnect(_chest_call(e))
	_push(Protocol.PROP_GONE, [e.cell])
	_fire_moved(e)


func _on_lit(e: Dictionary) -> void:
	_push(Protocol.PROP_LIT, [e.cell, e.lit])


func _on_opened(e: Dictionary) -> void:
	_push(Protocol.PROP_OPENED, [e.cell, e.open])


## Ghost cells of the blueprint came or went (Plans.changed; none: all read anew, on loading).
func _on_plan(cells: Array, item: String) -> void:
	if not _all and not cells.is_empty():
		_push(Protocol.PLAN_CELLS, [cells, item, session.plans.forms_of(cells) if item != "" else []])


func _on_fuel(e: Dictionary) -> void:
	_push(Protocol.PROP_FUEL, [e.cell, e.fuel])


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
	_born.append(a)
	# On joining the next flush names every animal there is (the server lets them in
	# with the first player): not twice.
	if not _all:
		_push(Protocol.ANIMAL, [a.id, a.kind, a.tint, a.pos])


func _on_gone(a) -> void:
	_snapped.erase(a.id)
	_push(Protocol.ANIMAL_GONE, [a.id])


func _on_stepped(a, at: Vector3, dir: Vector2, left: bool, size: float) -> void:
	_push(Protocol.STEP, [a.id, at, dir, left, size])


func _on_skills() -> void:
	_skills = true


func _on_leveled(_id: String, _level: int) -> void:
	_skills = true
	_skills_now = true
