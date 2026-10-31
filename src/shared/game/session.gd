extends RefCounted
## A world being played (plan/architecture/server.md): the world, the rules of play over
## it and the characters in it, run by a tick. It takes what the rules need (the world,
## its generator, the clock, the rules, the things placed) and makes the rest: what the
## hands do to the world (WorldActions), the wind (Storms) and the animals (Wildlife). A
## tick runs the clock, every character with their workshop, the animals around all
## the players and the wind around each of them in turn; the runner (src/server/
## runner.gd) calls the steps every frame or tick. It also orders the world made: the
## chunks within ZONE of each player are generated a step at a time within a budget
## (make_chunks), nearest first, and the chunks far from everyone are forgotten
## (forget_far); the client only meshes what is made (ChunkStreamer). It knows nothing
## of the network or the screen: tests run it alone.

const Clock := preload("res://src/shared/game/clock.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const Storms := preload("res://src/shared/game/storms.gd")
const Wildlife := preload("res://src/shared/game/wildlife.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")

## Seconds a step of a character or a workshop covers at most: a long frame does not
## starve or craft for all of it.
const STEP_MAX := 0.05
## Chunks within this many chunks of a player (their zone) are made, farther than any
## screen shows (a phone held sideways shows about three chunks each way, and the
## tallest mountains a few more to the south).
const ZONE := 5
## Chunks this close to a player are made with the near budget (make_chunks), so the
## ground they walk onto is there before the far chunks.
const NEAR := 4
## While the game is paused (its menu open, single player) the chunks are made this
## far, still within DROP, so less is left to make when the player walks on.
const PAUSE_ZONE := ZONE + 2
## Beyond this many chunks from every player the generator forgets chunks nobody
## changed. A chunk ZONE away needs the terrain of chunks two farther, which must stay.
const DROP := ZONE + 4
## Chunks forgotten in one call of forget_far at most.
const DROPS_PER_CALL := 4

var world
## The layout of the land (WorldGen), for the biomes; null when any ground will do.
var gen
var clock: Clock
## The rules of play (Rules).
var rules
## The things placed on cells (Placed).
var placed
var actions: WorldActions
var storms: Storms
var wildlife: Wildlife
## The characters playing (Character) and the workshop of each (Workshop), in one
## order; the animals see the characters as people.
var players: Array = []
var workshops: Array = []
var _wild := false
## The generator job going on (WorldGen.Job), kept across calls of make_chunks.
var _gen_job: WorldGen.Job
## The chunks the zones were last worked out around (see _zones), the reach then, and
## whether every chunk within it was made: nothing to scan until a zone moves or a
## chunk is forgotten.
var _zones: Array[Vector2i] = []
var _zone_reach := 0
var _all_made := false
## Chunks beyond DROP of every zone, listed when the zones move (see forget_far).
var _drop_queue: Array[Vector2i] = []
## Time spent generating, and on each kind of work since take_work last read it
## (usec by kind): "terrain", "saved", "trees", "shapes".
var gen_us := 0
var work_us := {}


func _init(w, g, c: Clock, r, p) -> void:
	world = w
	gen = g
	clock = c
	rules = r
	placed = p
	clock.world = world
	clock.gen = gen
	placed.world = world
	actions = WorldActions.new(world, clock, rules)
	storms = Storms.new(world, clock, actions)
	wildlife = Wildlife.new()
	wildlife.world = world
	wildlife.gen = gen
	wildlife.clock = clock
	wildlife.people = players


## Brings `who` (Character) into the world with their `workshop` (Workshop).
func add_player(who, workshop) -> void:
	who.world = world
	who.clock = clock
	who.placed = placed
	players.append(who)
	workshops.append(workshop)


func remove_player(who) -> void:
	var i := players.find(who)
	if i >= 0:
		players.remove_at(i)
		workshops.remove_at(i)


## Lets the animals come into the world around the players (Wildlife.start); they step
## from then on.
func start_wildlife(seed_value: int) -> void:
	wildlife.start(seed_value)
	_wild = true


## One tick of the world, `delta` seconds, every step in order.
func tick(delta: float) -> void:
	step_clock(delta)
	step_players(delta)
	step_wildlife(delta)
	step_storms(delta)


## Time and weather; the weather felt (a desert's sand storms) is the first player's,
## until the weather goes by districts of climate.
func step_clock(delta: float) -> void:
	clock.step(delta, players[0].position if not players.is_empty() else Vector3.INF)


## Every character's state and their workshop's queue.
func step_players(delta: float) -> void:
	var d := minf(delta, STEP_MAX)
	for i in players.size():
		players[i].update(d)
		workshops[i].update(d)


## The animals: those on a player's screen move every step, the rest now and then
## (Wildlife.look_from).
func step_wildlife(delta: float) -> void:
	if _wild:
		var around: Array = []
		for who in players:
			around.append([who.position, who.view_right, who.view_half])
		wildlife.look_from(around)
		wildlife.update(delta)


## The wind around the players, one of them a tick (Storms.step_around).
func step_storms(delta: float) -> void:
	var around: Array = []
	for who in players:
		around.append(who.position)
	storms.step_around(delta, around)


## What the animals pushed `who` by since the last call (Wildlife.pushes), in world
## units; nothing for one who is not playing. Taken once: the next call gives nothing
## until the animals step again.
func push_on(who) -> Vector3:
	var i := players.find(who)
	if i < 0 or i >= wildlife.pushes.size():
		return Vector3.ZERO
	var push: Vector3 = wildlife.pushes[i]
	wildlife.pushes[i] = Vector3.ZERO
	return push


# --- The world made around the players ------------------------------------------


## The chunks the world is made around: each player's, and the first respawn point of
## one lying dead, so coming back there lands in a world already made (the place of
## death stays too).
func zones() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for who in players:
		var at: Vector3 = who.position
		_add_zone(out, at)
		if who.is_dead():
			var points: Array = who.respawn_points()
			if not points.is_empty():
				_add_zone(out, points[0][1])
	return out


func _add_zone(out: Array[Vector2i], at: Vector3) -> void:
	var key := WorldData.chunk_key(floori(at.x / WorldData.CELL), floori(at.z / WorldData.CELL))
	if not out.has(key):
		out.append(key)


## Takes note of where the zones are now: a move lists the chunks to forget and
## makes make_chunks look again.
func _look(reach: int) -> void:
	var now := zones()
	if now == _zones and reach == _zone_reach:
		return
	_zones = now
	_zone_reach = reach
	_all_made = false
	_drop_queue.clear()
	if gen == null:
		return
	for key: Vector2i in gen.stages:
		if _distance(key) > DROP:
			_drop_queue.append(key)


## Chunks from `key` to the nearest zone (Chebyshev); far when there is none.
func _distance(key: Vector2i) -> int:
	var best := 1 << 30
	for z in _zones:
		best = mini(best, maxi(absi(key.x - z.x), absi(key.y - z.y)))
	return best


## The next stage some chunk within `reach` of a zone needs ([chunk, stage], see
## WorldGen.needed), the nearest chunk not SHAPED first, then the terrain and trees
## of the chunks around the zone's edge; empty when the zones are made.
func _next_needed(reach: int) -> Array:
	if _all_made or gen == null:
		return []
	for r in range(0, reach + 1):
		for z in _zones:
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) != r:
						continue
					var key := Vector2i(z.x + dx, z.y + dz)
					if gen.stage_of(key) < WorldGen.SHAPED:
						return gen.needed(key)
	for z in _zones:
		var m: Variant = gen.missing(z, reach + 2, WorldGen.TERRAIN)
		if m != null:
			return [m, WorldGen.TERRAIN]
		m = gen.missing(z, reach + 1, WorldGen.PLANTED)
		if m != null:
			return [m, WorldGen.PLANTED]
	_all_made = true
	return []


## Generates the chunks within `reach` of the zones a step at a time: `near_us`
## microseconds when the chunk being made is within NEAR of a zone, else `far_us`.
## At least one step is taken, so a job always ends. Returns the time spent.
func make_chunks(near_us: int, far_us: int, reach := ZONE) -> int:
	var t0 := Time.get_ticks_usec()
	_look(reach)
	var worked := false
	while true:
		if _gen_job == null:
			var need := _next_needed(reach)
			if need.is_empty():
				break
			_gen_job = gen.start(need[0], need[1])
			if _gen_job == null:
				break
		var budget := near_us if _distance(_gen_job.key) <= NEAR else far_us
		var tg := Time.get_ticks_usec()
		var done := false
		while not done and (Time.get_ticks_usec() - t0 < budget or not worked):
			done = gen.step(_gen_job, 1)
			worked = true
		_note_work(_gen_job, Time.get_ticks_usec() - tg)
		if done:
			_gen_job = null
		if Time.get_ticks_usec() - t0 >= budget:
			break
	var spent := Time.get_ticks_usec() - t0
	gen_us += spent
	return spent


## Generates what chunk `key` needs to be meshed at once (the loading screen, tools),
## after the job going on.
func make_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	if _gen_job != null:
		var tg := Time.get_ticks_usec()
		while not gen.step(_gen_job, 1 << 30):
			pass
		_note_work(_gen_job, Time.get_ticks_usec() - tg)
		_gen_job = null
	var need: Array = gen.needed(key)
	while not need.is_empty():
		var job: WorldGen.Job = gen.start(need[0], need[1])
		if job == null:
			break
		var tg := Time.get_ticks_usec()
		while not gen.step(job, 1 << 30):
			pass
		_note_work(job, Time.get_ticks_usec() - tg)
		need = gen.needed(key)
	gen_us += Time.get_ticks_usec() - t0


## Forgets up to `n` chunks beyond DROP of every zone (WorldGen.forget); chunks the
## players changed stay.
func forget_far(n := DROPS_PER_CALL) -> void:
	_look(_zone_reach if _zone_reach > 0 else ZONE)
	while not _drop_queue.is_empty() and n > 0:
		var key: Vector2i = _drop_queue.pop_back()
		if _distance(key) > DROP and gen.forget(key):
			_all_made = false
			n -= 1


## Adds the time a job took to its kind of work: a chunk from the save comes back
## SHAPED in place of its terrain.
func _note_work(job: WorldGen.Job, us: int) -> void:
	var kind := "shapes"
	if job.stage == WorldGen.TERRAIN:
		kind = "terrain"
	elif job.stage == WorldGen.PLANTED:
		kind = "trees"
	if not job.restore.is_empty():
		kind = "saved"
	work_us[kind] = work_us.get(kind, 0) + us


## The time spent on each kind of work since the last call (usec by kind), and the
## count starts anew.
func take_work() -> Dictionary:
	var spent := work_us
	work_us = {}
	return spent


## How many stages are still to be made for the chunks within `reach` of the zones
## (the loading screens' progress).
func stages_left(reach := ZONE) -> int:
	if gen == null:
		return 0
	var seen := {}
	var left := 0
	for z in zones():
		for dz in range(-reach - 2, reach + 3):
			for dx in range(-reach - 2, reach + 3):
				var key := Vector2i(z.x + dx, z.y + dz)
				if seen.has(key):
					continue
				seen[key] = true
				var d := maxi(absi(dx), absi(dz))
				var want := WorldGen.SHAPED if d <= reach else (WorldGen.PLANTED if d <= reach + 1 else WorldGen.TERRAIN)
				left += maxi(0, want - gen.stage_of(key))
	return left
