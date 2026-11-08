extends RefCounted
## The animals of the world. Each one only knows its species properties; who is food
## or a threat comes from AiRules. Animals wander, graze, rest outside their active
## hours (by the daylight of the Clock), flee from threats (the people among them) and
## hunt when hungry. They belong to the land: each chunk, once made, gets its own
## animals (_populate_chunk), as many of a kind as its `count` for each square of ROAM, on the
## share of the chunk that is its biomes; they stay as long as their ground is kept and
## are gone with it, and the eaten come back out of sight (_refill). The client draws
## them (Creatures) as they come, go and walk.
## The other properties shape the rest the same way for every species: those that come
## in a `flock` follow its first (the lead) and take fright together; those that like
## some plants seek them out; those that fly hop about on the ground, now and then fly
## over to another place, take off from a threat and, roosting in trees, sleep in the
## crowns, where no walker reaches them; those that swim keep to open water, a little
## under its surface, where no walker reaches them either (and one that also flies
## comes down on the water). A walker that roosts in trees climbs them: up the nearest
## one from a threat and to sleep, down again when it is safe and awake, and no walker
## reaches it up there. A species that names `biomes` comes into the world only on
## their ground (the layout tells the biome of a column; without one, anywhere).
## A swimmer that comes `ashore` also walks the land near its water (a duck, a frog),
## and one that flies too swims away from a threat and only takes off from one that
## comes close, for a short flight (`flight`) low over the water. One that `hops`
## goes on land in leaps with a rest between them. One that comes `after_rain` is
## about only while the puddles stand, as many as there is water in them.
## Bodies speed up, slow down and turn smoothly (a velocity steered toward where they
## go), stand a while where they came, and those on the ground or in the water push
## each other and the people apart by their masses (see _jostle).

const Body := preload("res://src/shared/game/body.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Biomes := preload("res://src/shared/content/biomes.gd")
const Items := preload("res://src/shared/content/items.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Tools := preload("res://src/shared/content/tools.gd")

## Every this many seconds the chunks made since get their animals (_populate_chunk) and
## those whose ground is forgotten go (_leave); every RESPAWN_EVERY the eaten are
## made up for (_refill).
const SETTLE_EVERY := 1.0
const RESPAWN_EVERY := 15.0
const CELL := WorldData.CELL
## Animals walk slopes and hop up a sheer step of one cell, not of two.
const MAX_STEP := 0.55
## The square around each of the people where the eaten are made up for, in cells each
## way, and in world units (ROAM); the chunks within it are looked at for new ones made.
## A kind's `count` lives on each such square (ROAM_CHUNKS chunks).
const SPAWN_REACH := 80
const ROAM := SPAWN_REACH * CELL
const ROAM_CHUNKS := float(SPAWN_REACH * 2 * SPAWN_REACH * 2) / (WorldData.CHUNK * WorldData.CHUNK)
## Places tried for one animal to come.
const SPAWN_TRIES := 40
## How near the people no animal comes when its chunk is made (world units); those that
## make up for the eaten come past a screen (NEAR).
const START_AWAY := 8.0
## The biomes of a chunk are looked at on a grid of this many points each way.
const BIOME_SAMPLES := 2
## The eaten are made up for only while a kind is short by more than this.
const REFILL_SLACK := 1.0
## Animals no one looks at (`near` off) move and think in steps of FAR_STEP seconds
## instead of every frame: most of them are far away, and each step looks up the
## ground under them.
const FAR_STEP := 0.1
## World units from a player within which an animal is looked at (`near`, see
## look_from) when the player's screen is not known, and the most of a screen's half
## size taken: it moves every frame, the others step now and then. The screen of a phone
## or a desktop shows at most about 25 units from the player to a corner, so a circle of
## this radius holds what any screen shows and little else (the near ones cost: a frame
## each, and the jostle grows with their number).
const NEAR := 28.0
## The widest body's half width (see radius): past it no two animals meet.
const MOST_RADIUS := 0.6
## Flyers: how far they fly to another place, in world units, and how far from a
## threat; how high they fly above the ground and crowns, and over how much of the
## way's end they come down.
const FLIGHT := 14.0
const FLIGHT_AWAY := 12.0
const CRUISE := 2.5
const DESCENT := 4.0
## Chance a resting flyer flies over to another place each time it thinks.
const FLY_CHANCE := 0.05
## Chance a walker that likes some plants looks for them when it picks where to go.
const GRAZE_CHANCE := 0.3
## How far a climber looks for a tree to run up from a threat, in world units.
const CLIMB_REACH := 6.0
## A swimmer keeps this far under the water surface, in cells.
const DIP := 0.35
## A flock keeps within this many world units of its lead.
const FLOCK_REACH := 1.5
const FLOCK_GAP := 4.0
## How fast bodies pick up and lose speed, in their speeds a second: on the ground and
## in the water (faster in flight from a threat), and in the air.
const GRIP := 3.0
const FLEE_GRIP := 6.0
const AIR_GRIP := 2.0
## A body slows down over the last this many seconds of its way at full speed, to a
## quarter of it.
const BRAKE := 0.4
## A flyer climbs at most this much for each unit flown, and up or down at this share
## of its speed.
const CLIMB := 0.6
const RISE := 0.6
## A wanderer that got where it went stands there this many seconds, half the times.
const LINGER := Vector2(1.5, 5.0)
## A swimmer that comes ashore keeps within this many world units of the water it was
## last in, and wanders this far at a time.
const SHORE := 4.0
const SHORE_WALK := 3.0
## The share of its wanderings it may go ashore in, for one that swims and one that hops.
const SHORE_SWIM := 0.15
const SHORE_HOP := 0.7
## A flyer that swims takes off only from a threat this near, in its sights; a farther
## one it swims away from. It flies over to another place this much less often.
const SWIM_SCARE := 0.4
const SWIM_FLY := 0.1
## A leap of one that hops: how long it takes, how high it goes (world units), how
## much faster than its speed it carries, and the rest between two (seconds, half that
## in flight).
const HOP_TIME := 0.35
const HOP_HIGH := 0.25
const HOP_BURST := 2.0
const HOP_REST := Vector2(0.3, 1.2)

## An animal came into the world, or was eaten and is gone.
signal born(a: Animal)
signal gone(a: Animal)
## A paw of animal `a` came down at `at` walking along `dir` (the left one or not);
## `size` is how big the print is, by the animal's mass.
signal stepped(a: Animal, at: Vector3, dir: Vector2, left: bool, size: float)
## Animal `a` bit `who`, one of the people (see _land_bite).
signal bit(a: Animal, who)


class Animal:
	## Its number in the world, by which a client's copy knows it (see Protocol.SNAP).
	var id := 0
	var kind := ""
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	var state := "wander"
	var hunger := 0.0
	var think := 0.0
	var prey: Animal = null
	## The way it faces, 1 east and -1 west.
	var facing := 1.0
	## Way walked since the last footprint, and which foot made it.
	var stride := 0.0
	var left := false
	## Someone looks at it (within NEAR of one of the players, see look_from), so it
	## moves every frame; set by the owner before update().
	var near := true
	## Its body's half width on the ground (see radius), kept from the species.
	var radius := 0.0
	## Time gathered since the last step while not near (see FAR_STEP); 0 right after
	## a step.
	var away := 0.0
	## Time from the last step to the next one while not near: FAR_STEP, less what the
	## last one came late, so each animal keeps its own beat.
	var wait := FAR_STEP
	## It took a step this update (the client walks its picture).
	var moving := false
	## Its velocity over the ground (x east, y south), in world units a second.
	var vel := Vector2.ZERO
	## Seconds it stands where it came before it wanders on.
	var idle := 0.0
	## One that hops: how far into a leap it is, 0..1 (0 between leaps), the rest left
	## before the next one, and how high above `pos` the leap has it now.
	var hop := 0.0
	var hop_rest := 0.0
	var lift := 0.0
	## A swimmer that comes ashore: where it last was in the water.
	var home := Vector3.ZERO
	## Where its flight began: it climbs away from there.
	var from := Vector3.ZERO
	## Which of its species' tints it is drawn in.
	var tint := 0
	## A flyer is in the air, or sits in a tree crown (a climber too).
	var flying := false
	var perched := false
	## A climber on its way to the tree its target is on top of.
	var climb := false
	## The one it follows in its flock, null for a lead or one alone, and its own
	## place in the flock around the lead.
	var lead: Animal = null
	var spot := Vector3.ZERO
	## Where the threat it flees from was, for its flock to take fright too.
	var fear := Vector3.ZERO
	## Hits of power 1 it takes yet (its species' `health`; 0: it cannot be hit).
	var health := 0
	## Seconds it keeps fleeing from where it was last hit (see hurt), and that place.
	var hurt := 0.0
	var hurt_from := Vector3.ZERO
	## Eaten or killed, out of the world.
	var gone := false
	## The frame of its picture drawn (on the client, see Creatures).
	var frame := 0
	## A flyer's last cell under it and the top of the ground or crown there (see
	## _canopy), looked up again only in a new cell.
	var over := Vector2i(1 << 30, 0)
	var below := 0.0
	## Where a walker last looked up the floor under it and what it found (see _move):
	## looking it up costs the most of a step, so it is kept for the next few.
	var looked := Vector3(INF, 0.0, INF)
	var floor_y := 0.0
	## Whether that floor is the water's (a swimmer swims there).
	var floor_wet := false
	## A fish lured by the float of a fishing line swims there and stays (Fishing sets
	## and clears it); INF none.
	var bait := Vector3.INF
	## Tamed (Taming): the number of its owner (Player.id), -1 for a wild one; where it
	## was told to stay (INF: it follows its owner); how many times a wild one was fed by
	## hand, when it last ate from a hand and when it was last shorn (days of the Clock).
	var owner := -1
	var stay := Vector3.INF
	var fed := 0
	var fed_at := -INF
	var shorn_at := 0.0
	## Attacks (see _fights): the one of the people it goes for (null: none), whether it
	## hunts them (else it defends itself or its ground), the seconds its fury lasts yet,
	## the seconds it leaves the people be after a fight, the seconds of its warning left,
	## the seconds of a bite left before it lands, the seconds before it may
	## bite again, the bites it landed in this fight, and who hit it last (null: no one of
	## the people).
	var foe = null
	var hunting := false
	var rage := 0.0
	var calm := 0.0
	var warn := 0.0
	var bite := 0.0
	var bite_wait := 0.0
	var bites := 0

	## Off the ground, out of reach of those that walk.
	func aloft() -> bool:
		return flying or perched


var world
## The things placed (Placed): its burning fires and lights set down keep the animals off
## (see _find_fires); null for none.
var placed
## The layout of the land (LandLayout: `lay_out`), for the biome of a column, where
## species keep to their biomes; null when any ground will do.
var gen
## The clock, for the daylight that sets who is active.
var clock
## The rules of play (Rules): `animal_attacks` lets the animals go for the people; null
## lets them.
var rules
## Those the animals see as people (threats to the wary, see AiRules.HUMAN): anything
## with a `position` in world units. The chunks around them get their animals (see _settle_new).
var people := []
var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()
var respawn_timer := 0.0
var _settle_timer := 0.0
## The chunks that got their animals: for each, by kind, its share of a kind's `count`
## (its share of ROAM_CHUNKS times the share of it that is the kind's biomes).
var _settled := {}
var _daylight := 1.0
## What each kind is to each (see _sees), worked out from AiRules once.
var _seen := {}
## The kinds each kind looks for (see _cares), and the animals by kind (see _kin) with
## the count of `animals` they were made for.
var _caring := {}
var _by_kind := {}
var _kin_of := -1
## What the people were pushed by the animals they ran into (see _jostle), in world
## units, one for each of `people` (on the client, the player's body takes it).
var pushes: Array[Vector3] = []
## The animals that stepped in the last update, in their order: only those can have
## moved since (the server's snapshots look at them, PlayerLink._snap).
var moved: Array[Animal] = []
## The number the last animal got (Animal.id).
var _next_id := 0
## What keeps the animals off now (see _find_fires): [middle, reach in world units,
## true for a light in a hand], and the seconds until it is looked for again.
var _fires: Array = []
var _fire_timer := 0.0
## Whether start ran, and the tamed animals of a save waiting for it (see add_tamed).
var _started := false
var _kept_tame: Array = []


## Gives the chunks made so far their animals; more come as more is made.
func start(seed_value: int) -> void:
	rng.seed = seed_value
	_started = true
	add_tamed(_kept_tame)
	_kept_tame = []
	_settle_new()


## Whether chunk `key` is made to the end (its trees too), so its animals can come.
func _made(key: Vector2i) -> bool:
	if gen != null and "stages" in gen:
		return gen.stages.get(key, 0) >= gen.SHAPED
	return world.chunks.has(key)


## Gives each chunk made within ROAM of the people that has none yet its animals
## (_populate_chunk), and forgets the chunks no longer kept (their animals went with them, see
## _leave), so a chunk made again gets them again.
func _settle_new() -> void:
	for key: Vector2i in _settled.keys():
		if not world.chunks.has(key):
			_settled.erase(key)
	var r := ceili(float(SPAWN_REACH) / WorldData.CHUNK)
	for who in people:
		var c := Vector2i(floori(who.position.x / CELL), floori(who.position.z / CELL)) / WorldData.CHUNK
		for kz in range(c.y - r, c.y + r + 1):
			for kx in range(c.x - r, c.x + r + 1):
				var key := Vector2i(kx, kz)
				if not _settled.has(key) and _made(key):
					_populate_chunk(key)


## The animals of chunk `key`: of each kind as many as its `count` (wanted) on the
## chunk's share of it (_share), the fraction rolled, in flocks of its size, anywhere
## on the chunk where it lives, not at the people's feet (START_AWAY).
func _populate_chunk(key: Vector2i) -> void:
	var biomes := _chunk_biomes(key)
	var shares := {}
	_settled[key] = shares
	var cells := Rect2i(key * WorldData.CHUNK, Vector2i(WorldData.CHUNK, WorldData.CHUNK))
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var share := _biome_share(kind, biomes) / ROAM_CHUNKS
		if share <= 0.0:
			continue
		shares[kind] = share
		var flock: Array = AiRules.SPECIES[kind].flock
		var groups := wanted(kind) * share / maxf(1.0, (flock[0] + flock[1]) * 0.5)
		var n := floori(groups) + (1 if rng.randf() < groups - floorf(groups) else 0)
		for i in n:
			_spawn_group(kind, 1 << 20, cells, START_AWAY)


## The biomes at BIOME_SAMPLES × BIOME_SAMPLES points of chunk `key`; empty without a
## layout.
func _chunk_biomes(key: Vector2i) -> Array:
	var out := []
	if gen == null:
		return out
	var step := WorldData.CHUNK / BIOME_SAMPLES
	for j in BIOME_SAMPLES:
		for i in BIOME_SAMPLES:
			out.append(gen.biome_of(key.x * WorldData.CHUNK + i * step + step / 2, key.y * WorldData.CHUNK + j * step + step / 2))
	return out


## The share of `biomes` (see _chunk_biomes) that are the biomes of `kind`: 1 for a
## kind of any biome or without a layout.
func _biome_share(kind: String, biomes: Array) -> float:
	var spec: Dictionary = AiRules.SPECIES[kind]
	if spec.biomes.is_empty() or biomes.is_empty():
		return 1.0
	var n := 0
	for b: int in biomes:
		if b != Biomes.NONE and Biomes.IDS[b] in spec.biomes:
			n += 1
	return float(n) / biomes.size()


## Makes up for the eaten around each of the people: a kind short of what the chunks
## settled within ROAM hold of it (their shares of its `count`, so fewer while the
## puddles dry for one that comes after rain) by more than REFILL_SLACK gets new ones
## out of sight on the ground made there; one over by as much loses those no one sees.
func _refill() -> void:
	for who in people:
		var around: Vector3 = who.position
		var c := Vector2i(floori(around.x / CELL), floori(around.z / CELL))
		var lo := (c - Vector2i(SPAWN_REACH, SPAWN_REACH)) / WorldData.CHUNK
		var hi := (c + Vector2i(SPAWN_REACH, SPAWN_REACH)) / WorldData.CHUNK
		var shares := {}
		for key: Vector2i in _settled:
			if key.x >= lo.x and key.x <= hi.x and key.y >= lo.y and key.y <= hi.y:
				var of: Dictionary = _settled[key]
				for kind: String in of:
					shares[kind] = shares.get(kind, 0.0) + of[kind]
		var cells := Rect2i(c - Vector2i(SPAWN_REACH, SPAWN_REACH), Vector2i(SPAWN_REACH, SPAWN_REACH) * 2 + Vector2i.ONE)
		for kind: String in shares:
			var want: float = wanted(kind) * shares[kind]
			var have := _count_near(kind, around)
			if have > want + REFILL_SLACK:
				_thin(kind, have - ceili(want), around)
				continue
			for i in floori(want - REFILL_SLACK) - have:
				var n := animals.size()
				_spawn_group(kind, floori(want) - have, cells, NEAR)
				have += animals.size() - n
				if have >= floori(want):
					break


## The animals of `kind` within ROAM of `around` (on the ground: in cells, each way).
func _count_near(kind: String, around: Vector3) -> int:
	var n := 0
	for a in animals:
		if a.kind == kind and a.owner < 0 and _within(a.pos, around, ROAM):
			n += 1
	return n


static func _within(p: Vector3, around: Vector3, reach: float) -> bool:
	return absf(p.x - around.x) <= reach and absf(p.z - around.z) <= reach


## Takes out the animals no one looks at whose ground is no longer kept (forgotten far
## from the people, Session.DROP): they went with it, and come again with it.
func _leave() -> void:
	for a in animals.duplicate():
		if not a.near and a.owner < 0 and world.chunk_at(floori(a.pos.x / CELL), floori(a.pos.z / CELL)) == null:
			_remove(a)


func count(kind: String) -> int:
	var n := 0
	for a in animals:
		if a.kind == kind:
			n += 1
	return n


## Runs the animals for `delta` seconds: the near ones every call, the others every
## FAR_STEP seconds.
func update(delta: float) -> void:
	delta = minf(delta, 0.1)
	respawn_timer += delta
	if respawn_timer > RESPAWN_EVERY:
		respawn_timer = 0.0
		_refill()
	_settle_timer += delta
	if _settle_timer > SETTLE_EVERY:
		_settle_timer = 0.0
		_leave()
		_settle_new()
	_daylight = clock.daylight()
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_EVERY
		_find_fires()
	moved.clear()
	for a in animals.duplicate():
		if a.gone:
			continue
		var dt := delta
		if a.owner >= 0 and not a.near and world.chunk_at(floori(a.pos.x / CELL), floori(a.pos.z / CELL)) == null:
			# A tamed one waits where its land was forgotten until it is made again.
			continue
		if not a.near:
			a.away += delta
			if a.away < a.wait:
				continue
			dt = a.away
			# A long frame lets many animals step at once; their next steps fall on
			# their own beats again, or they would all come to step in one frame.
			a.wait = FAR_STEP - fmod(a.away - a.wait, FAR_STEP)
		a.away = 0.0
		moved.append(a)
		var spec: Dictionary = AiRules.SPECIES[a.kind]
		a.hunger = minf(1.0, a.hunger + dt * 0.012)
		a.idle = maxf(0.0, a.idle - dt)
		a.hurt = maxf(0.0, a.hurt - dt)
		a.think -= dt
		if a.think <= 0.0:
			a.think = 0.4 + rng.randf() * 0.3
			_decide(a, spec)
		if a.foe != null or a.bite > 0.0 or a.warn > 0.0 or a.calm > 0.0:
			_fight_step(a, spec, dt)
		if a.flying:
			_fly(a, spec, dt)
		else:
			_move(a, spec, dt)
	_jostle()


## How many of `kind` live around the people now: its `count`, or for one that comes
## after rain that share of it as there is water in the puddles (none in winter).
func wanted(kind: String) -> int:
	var spec: Dictionary = AiRules.SPECIES[kind]
	if not spec.after_rain:
		return spec.count
	if clock == null or clock.season == clock.WINTER:
		return 0
	return floori(spec.count * maxf(clock.wet, clock.puddles) + 0.5)


## Takes up to `n` of `kind` within ROAM of `around` out of the world, those no one
## looks at (they hid away).
func _thin(kind: String, n: int, around: Vector3) -> void:
	for a in animals.duplicate():
		if n <= 0:
			return
		if a.kind == kind and not a.near and a.owner < 0 and _within(a.pos, around, ROAM):
			_remove(a)
			n -= 1


func _decide(a: Animal, spec: Dictionary) -> void:
	if a.bait.is_finite():
		# Lured by a float: nothing else matters to it until it has bitten or let go.
		a.state = "bait"
		a.idle = 0.0
		a.target = Vector3(a.bait.x, a.pos.y, a.bait.z)
		return
	if a.state == "bite":
		# Its jaws close (see _fight_step): nothing else for that moment.
		return
	var sight: float = spec.sight
	var threat_pos: Variant = null
	var threat_d := INF
	if a.owner < 0 and AiRules.is_threat(a.kind, AiRules.HUMAN):
		# A person within 0.6 of its sight startles it; once fleeing it stays wary until
		# they are out of sight, so it does not wander back at the edge of its fear. One
		# that is tamed by hand does not flee from a person holding its food.
		var wary := sight if a.state == "flee" else sight * 0.6
		for who in people:
			if not spec.tame_food.is_empty() and a.hurt <= 0.0 and who.has_method("held") and who.held() in spec.tame_food:
				continue
			var at: Vector3 = who.position
			var d := a.pos.distance_to(at)
			if d < wary and d < threat_d:
				threat_pos = at
				threat_d = d
	var fire: Variant = _fire_near(a, spec)
	if _fights(a, spec, fire):
		return
	if fire != null and a.pos.distance_to(fire) < threat_d:
		threat_pos = fire
		threat_d = a.pos.distance_to(fire)
	if a.hurt > 0.0:
		# A hit one flees from where it was hit, whether it fears people or not.
		threat_pos = a.hurt_from
		threat_d = a.pos.distance_to(a.hurt_from)
	var prey: Animal = null
	var prey_d := INF
	var lead := _lead(a)
	var alarm: Variant = null
	# Only the kinds that are something to it, and its own for a flock's alarm, are
	# looked through (see _kin): most others are nobody to it, and there are many.
	var sees := _sees(a.kind)
	var sight2 := sight * sight
	var by_kind := _kin()
	for kind: String in _cares(a.kind):
		var what: int = sees[kind]
		if what == NOBODY and lead == null:
			continue
		for o: Animal in by_kind.get(kind, []):
			if o == a or o.gone or (what == NOBODY and o.state != "flee"):
				continue
			var d2 := a.pos.distance_squared_to(o.pos)
			if d2 > sight2:
				continue
			var d := sqrt(d2)
			if d < threat_d and what == THREAT:
				threat_pos = o.pos
				threat_d = d
			elif d < prey_d and what == FOOD and (spec.flies or not o.aloft()):
				prey = o
				prey_d = d
			elif o.state == "flee" and lead != null and _lead(o) == lead and a.pos.distance_to(o.fear) < sight:
				alarm = o.fear
	# One of the flock fleeing frightens the rest.
	if threat_pos == null and alarm != null:
		threat_pos = alarm
	if threat_pos != null:
		a.state = "flee"
		a.idle = 0.0
		a.fear = threat_pos
		var away: Vector3 = a.pos - threat_pos
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		if spec.flies:
			if a.flying:
				return
			# One that swims swims away, and takes off only from a threat close by or
			# when it is out of the water.
			if not spec.swims or threat_d < sight * SWIM_SCARE or water_top(a.pos.x, a.pos.z) == -INF:
				var reach := minf(FLIGHT_AWAY, spec.flight * CELL)
				_take_off(a, spec, a.pos + away.normalized() * reach, reach * 0.3)
			if a.flying or not spec.swims:
				return
		if spec.roost == "trees":
			# A climber stays up its tree, or runs up the nearest one.
			if a.perched or a.climb:
				return
			var tree: Variant = _tree_spot(spec, a.pos, CLIMB_REACH)
			if tree != null:
				a.target = tree
				a.climb = true
				return
		# As far as the land or the water goes (see _move).
		a.target = a.pos + away.normalized() * 6.0
		return
	if a.owner >= 0:
		_keep_by_owner(a)
		return
	if not AiRules.is_active(a.kind, _daylight):
		# Flyers sleep in the crowns, near their lead, climbers up a tree near; one
		# that found none sleeps where it is.
		var was_resting := a.state == "rest"
		a.state = "rest"
		if a.climb:
			return
		if spec.roost == "trees" and not a.aloft() and not was_resting:
			var around: Vector3 = a.pos if lead == null or lead == a else lead.target
			var tree: Variant = _tree_spot(spec, around, FLIGHT if spec.flies else CLIMB_REACH)
			if tree != null:
				a.target = tree
				if spec.flies:
					_lift_off(a)
				else:
					a.climb = true
				return
		if not a.flying:
			a.target = a.pos
		return
	if a.perched and not spec.flies:
		# Safe and awake: a climber comes down.
		a.perched = false
		a.pos.y = ground(a.pos.x, a.pos.z)
		a.target = a.pos
	if prey != null and a.hunger > 0.5:
		a.state = "hunt"
		a.prey = prey
		a.target = prey.pos
		if spec.flies:
			_lift_off(a)
		return
	if "plants" in spec.diet:
		a.hunger = maxf(0.0, a.hunger - 0.04)
	var was := a.state
	a.state = "wander"
	if a.flying:
		return
	if lead != null and lead != a:
		_follow(a, spec, lead)
		return
	if spec.flies:
		if rng.randf() < FLY_CHANCE * (SWIM_FLY if spec.swims else 1.0):
			_take_off(a, spec, a.pos, spec.flight * CELL)
			return
		if not spec.ashore:
			if not a.perched and not sits_still(spec) and a.pos.distance_to(a.target) < 0.1 and rng.randf() < 0.3:
				# Hops about and pecks.
				a.target = a.pos + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			return
	if a.idle > 0.0:
		return
	var came := a.pos.distance_to(a.target) < 0.3
	if was != "wander" or came or rng.randf() < 0.05:
		if came and was == "wander" and rng.randf() < 0.5:
			# Stands a while where it came.
			a.idle = rng.randf_range(LINGER.x, LINGER.y)
			return
		if spec.ashore:
			# Paddles about, or now and then goes out onto the shore near its water (one
			# that hops more often) and back.
			var land: bool = rng.randf() < (SHORE_HOP if spec.hops else SHORE_SWIM)
			var near: Variant = _place(spec, a.pos, SHORE_WALK * 2.0, false, 8, a.home) if land \
					else _place(spec, a.pos, SHORE_WALK, false, 4)
			a.target = near if near != null else a.pos
			return
		# A grazer looks for what it likes now and then (looking is the dear part of a
		# walker's thinking), else it wanders.
		var to: Variant = null if spec.likes.is_empty() or rng.randf() > GRAZE_CHANCE else _place(spec, a.pos, 6.0, false, 4)
		a.target = to if to != null else a.pos + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
		if _fire_near(a, spec, a.target) != null:
			# It does not wander up to a fire: it stays where it is a while instead.
			a.target = a.pos
			a.idle = rng.randf_range(LINGER.x, LINGER.y)


# --- Tamed -------------------------------------------------------------------------


## How near its owner a tamed one following keeps, and how far from where it was told to
## stay it wanders, in world units.
const TAME_FOLLOW := 1.2
const TAME_ROAM := 2.5


## A tamed animal safe from threats: it follows its owner (one of the people with its
## number), or wanders a little round where it was told to stay; with its owner not
## here it stays where it is.
func _keep_by_owner(a: Animal) -> void:
	a.state = "wander"
	if a.idle > 0.0:
		return
	if a.stay.is_finite():
		if a.pos.distance_to(a.target) < 0.3 or a.target.distance_to(a.stay) > TAME_ROAM:
			if rng.randf() < 0.4:
				a.idle = rng.randf_range(LINGER.x, LINGER.y)
				return
			a.target = a.stay + Vector3(rng.randf_range(-TAME_ROAM, TAME_ROAM), 0.0, rng.randf_range(-TAME_ROAM, TAME_ROAM))
		return
	var owner: Variant = owner_of(a)
	if owner == null:
		a.stay = a.pos
		a.target = a.pos
		return
	var at: Vector3 = owner.position
	if Vector2(at.x - a.pos.x, at.z - a.pos.z).length() > TAME_FOLLOW:
		var off := Vector2(a.pos.x - at.x, a.pos.z - at.z).normalized() * TAME_FOLLOW * 0.7
		a.target = Vector3(at.x + off.x, a.pos.y, at.z + off.y)
	else:
		a.target = a.pos


## The one of the people who owns tamed animal `a` (their `id`), null when they are not
## here.
func owner_of(a: Animal) -> Variant:
	for who in people:
		if int(who.get("id") if "id" in who else 0) == a.owner:
			return who
	return null


## The tamed animals as plain data for a save (JSON: numbers only): {kind, at: [x, y, z],
## tint, owner, stay: [x, y, z] or null (it follows), fed: when it last ate from a hand,
## shorn: when it was last shorn}.
func tamed_list() -> Array:
	var out := []
	for a in animals:
		if a.owner >= 0:
			out.append({"kind": a.kind, "at": [a.pos.x, a.pos.y, a.pos.z], "tint": a.tint, "owner": a.owner,
				"stay": [a.stay.x, a.stay.y, a.stay.z] if a.stay.is_finite() else null,
				"fed": maxf(a.fed_at, -1.0), "shorn": a.shorn_at})
	return out


## Brings back the tamed animals of a save (see tamed_list) once the animals start; ones
## of a kind no longer loaded are left out.
func add_tamed(list: Array) -> void:
	if not _started:
		_kept_tame.append_array(list)
		return
	for t in list:
		if not t is Dictionary or not t.get("kind") is String or not AiRules.SPECIES.has(t.kind):
			continue
		var at: Variant = _vector(t.get("at"))
		if at == null:
			continue
		var a := _add(t.kind, at)
		var tints: Array = AiRules.SPECIES[t.kind].tints
		a.tint = clampi(int(t.get("tint", 0)), 0, maxi(0, tints.size() - 1))
		a.owner = maxi(0, int(t.get("owner", 0)))
		var stay: Variant = _vector(t.get("stay"))
		a.stay = stay if stay != null else Vector3.INF
		a.fed_at = float(t.get("fed", -1.0))
		a.shorn_at = float(t.get("shorn", 0.0))


## A Vector3 of a list of three numbers read from a save, null for anything else.
static func _vector(v: Variant) -> Variant:
	if not v is Array or v.size() != 3:
		return null
	for n in v:
		if not (n is float or n is int) or not is_finite(float(n)):
			return null
	return Vector3(v[0], v[1], v[2])


## A young one of tamed animal `a` beside it, its owner's and staying where `a` stays.
func breed(a: Animal) -> Animal:
	var pos := a.pos + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
	pos.y = _floor(AiRules.SPECIES[a.kind], pos.x, pos.z)
	if pos.y <= 0.0:
		pos = a.pos
	var young := _add(a.kind, pos)
	young.owner = a.owner
	young.stay = a.stay
	young.tint = a.tint
	young.shorn_at = clock.now() if clock != null else 0.0
	return young


## A tame one of `kind` let out at `at` (world units; a catch of a trap, ActionsTame),
## owner `owner`'s and following them: on the ground there, or at `at` itself where the
## ground is more than a cell and a half off it.
func release(kind: String, at: Vector3, owner: int) -> Animal:
	var spec: Dictionary = AiRules.SPECIES[kind]
	var pos := at
	var y := _floor(spec, at.x, at.z)
	if y > 0.0 and absf(y - at.y) <= 1.5 * CELL:
		pos.y = y
	var a := _add(kind, pos)
	a.owner = owner
	a.stay = Vector3.INF
	a.fed = spec.tame_feeds
	a.shorn_at = clock.now() if clock != null else 0.0
	return a


# --- Fire ---------------------------------------------------------------------------


## How often the fires that keep the animals off are looked for again, in seconds.
const FIRE_EVERY := 0.5
## A fleeing animal keeps this much farther from a fire than it lets itself come.
const FIRE_WARY := 1.3
## A meat eater of a flock this hungry in winter is not kept off by a light in a hand,
## only by a fire set down (plan/design/creatures-ai.md: a hungry pack may come).
const BOLD_HUNGER := 0.7


## Notes what keeps the animals off (see _fires): the fires burning and the lights set
## down, by the `scares` of their items, and the lights the people hold, by the farthest
## `scares` of those.
func _find_fires() -> void:
	_fires.clear()
	if placed != null:
		for e: Dictionary in placed.things + placed.lights:
			var reach: float = Items.get_item(e.item).get("scares", 0.0)
			if reach > 0.0 and e.get("lit", false):
				_fires.append([Placed.center(e), reach, false])
	for who in people:
		if not who.has_method("lights_held"):
			continue
		var reach := 0.0
		for id: String in who.lights_held():
			reach = maxf(reach, Items.get_item(id).get("scares", 0.0))
		if reach > 0.0:
			_fires.append([who.position + Vector3(0.0, Body.HEIGHT * CELL * 0.5, 0.0), reach, true])


## The fire that keeps animal `a` (of species `spec`) off at `at` (its own place by
## default), null for none: the nearest whose reach `at` is within (farther once it
## flees, FIRE_WARY), when it fears fire (`fire_wariness` 0.5 or more). A hungry flock of
## meat eaters in winter comes near a light in a hand (BOLD_HUNGER).
func _fire_near(a: Animal, spec: Dictionary, at: Variant = null) -> Variant:
	if _fires.is_empty() or spec.get("fire_wariness", 1.0) < 0.5:
		return null
	var p: Vector3 = a.pos if at == null else at
	var bold: bool = a.hunger > BOLD_HUNGER and spec.flock[1] > 1 and "meat" in spec.diet \
			and clock != null and clock.season == clock.WINTER
	var wary := FIRE_WARY if a.state == "flee" else 1.0
	var best: Variant = null
	var best_d := INF
	for f: Array in _fires:
		if f[2] and bold:
			continue
		var d := p.distance_to(f[0])
		if d < f[1] * wary and d < best_d:
			best = f[0]
			best_d = d
	return best


const NOBODY := 0
const THREAT := 1
const FOOD := 2


## What every kind is to kind `kind`: kind -> THREAT, FOOD or NOBODY (see AiRules),
## worked out once.
func _sees(kind: String) -> Dictionary:
	var out: Variant = _seen.get(kind)
	if out == null:
		out = {}
		for other in AiRules.SPECIES:
			out[other] = THREAT if AiRules.is_threat(kind, other) else (FOOD if AiRules.is_food(kind, other) else NOBODY)
		_seen[kind] = out
	return out


## The kinds kind `kind` looks for around it when it decides: those that are a threat or
## food to it, and its own (a flock, whose fleeing ones frighten the rest), worked out once.
func _cares(kind: String) -> Array:
	var out: Variant = _caring.get(kind)
	if out == null:
		var sees := _sees(kind)
		out = []
		for other: String in sees:
			if sees[other] != NOBODY or other == kind:
				out.append(other)
		_caring[kind] = out
	return out


## The animals by kind, in the order of `animals`, so a decision looks through its few
## kinds, not every animal: kept by _add and _remove, made anew when the count of
## `animals` is not the one they were made for (the tests change it themselves).
func _kin() -> Dictionary:
	if _kin_of != animals.size():
		_by_kind.clear()
		for o in animals:
			var list: Variant = _by_kind.get(o.kind)
			if list == null:
				list = []
				_by_kind[o.kind] = list
			list.append(o)
		_kin_of = animals.size()
	return _by_kind


## The lead of `a`'s flock: itself when it leads, null for one that keeps alone.
func _lead(a: Animal) -> Animal:
	if a.lead != null:
		return a.lead
	return a if AiRules.SPECIES[a.kind].flock[1] > 1 else null


## A follower keeps to its place around the lead: flies after it, settles where it
## settles (in a tree when it sits in one) and hops about there; one that swims swims
## after it and flies only after a lead in the air or far off.
func _follow(a: Animal, spec: Dictionary, lead: Animal) -> void:
	var at := lead.target + a.spot
	if spec.flies:
		if lead.flying or a.pos.distance_to(lead.pos) > FLOCK_GAP * (4.0 if spec.swims else 1.0):
			a.target = _settle(spec, at, lead.target.y > _floor(spec, lead.target.x, lead.target.z) + 0.3)
			_lift_off(a)
			return
		if not spec.ashore:
			if not a.perched and not sits_still(spec) and a.pos.distance_to(a.target) < 0.1 and rng.randf() < 0.3:
				a.target = a.pos + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			return
	if a.idle > 0.0:
		return
	if a.pos.distance_to(lead.pos) > FLOCK_GAP or a.pos.distance_to(a.target) < 0.3:
		a.target = at + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))


## Sends flyer `a` into the air to a place within `reach` of `around` (see _place),
## or nearer itself when there is none there; it stays when there is none at all.
func _take_off(a: Animal, spec: Dictionary, around: Vector3, reach: float) -> void:
	var to: Variant = _place(spec, around, reach, spec.roost == "trees" and rng.randf() < 0.3)
	if to == null:
		to = _place(spec, a.pos, reach * 0.5, false)
	if to == null:
		return
	a.target = to
	_lift_off(a)


## True for a flyer with no frames to hop on the ground (`hop` 0, a butterfly): it
## either flies or sits still where it landed, beating its wings (see Creatures); it
## neither hops about nor is shoved by those near it.
static func sits_still(spec: Dictionary) -> bool:
	return spec.flies and int(spec.get("hop", 0)) <= 0


## Flyer `a` goes up into the air from where it is (it climbs away from there).
func _lift_off(a: Animal) -> void:
	if not a.flying:
		a.from = a.pos
		a.flying = true
	a.perched = false


## A place to go within `reach` of `around`: of `tries` tried, one where something the
## species likes grows, else any open ground (open water for a swimmer, or for one
## that comes ashore the ground within SHORE of `home`, rather than water); a spot in a crown when
## `tree` and there is a tree near. Null when all of those tried are water or under
## crowns (land, for a swimmer).
func _place(spec: Dictionary, around: Vector3, reach: float, tree: bool, tries := 8, home: Variant = null) -> Variant:
	if tree:
		var spot: Variant = _tree_spot(spec, around, reach)
		if spot != null:
			return spot
	var best := around
	var best_score := -1
	for i in tries:
		var p := around + Vector3(rng.randf_range(-reach, reach), 0.0, rng.randf_range(-reach, reach))
		var x := floori(p.x / CELL)
		var z := floori(p.z / CELL)
		var y: int = world.surface_y(x, z)
		if spec.swims:
			# Open water only, or the shore near home.
			if y != -1 and (home == null or y <= 0 or p.distance_to(home) > SHORE or world.leaf_col(x, z) >> y != 0):
				continue
		# Not over water or under a crown.
		elif y <= 0 or world.leaf_col(x, z) >> y != 0:
			continue
		# The shore, when it may go there, is where it goes.
		var score := 1 if spec.swims and y != -1 else 0
		if not spec.likes.is_empty() and y > 0:
			for plant in Grass.plants_on(world, x, y - 1, z):
				if plant in spec.likes:
					score = 1
		if score > best_score:
			best_score = score
			best = p
			if score > 0:
				break
	if best_score < 0:
		return null
	best.y = _floor(spec, best.x, best.z)
	return best


## Where to sit at x, z of `at`: on the crown there when `tree` and there is one,
## else on the ground, or in the water for a swimmer (at the height of `at` where
## there is neither).
func _settle(spec: Dictionary, at: Vector3, tree: bool) -> Vector3:
	if tree:
		var leaves: int = world.leaf_col(floori(at.x / CELL), floori(at.z / CELL))
		if leaves != 0:
			return Vector3(at.x, (WorldData.top_level(leaves) + 1) * CELL, at.z)
	var y := _floor(spec, at.x, at.z)
	return Vector3(at.x, y if y > 0.0 else at.y, at.z)


## A spot on the top of a tree crown within `reach` of `around`, or null: a few trees
## tried at random from the chunks there that have any (a forest chunk has dozens, too
## many to look through on a phone each time).
func _tree_spot(spec: Dictionary, around: Vector3, reach: float) -> Variant:
	var r := ceili(reach / CELL)
	var cx := floori(around.x / CELL)
	var cz := floori(around.z / CELL)
	var wooded := []
	for kz in range((cz - r) >> WorldData.SHIFT, ((cz + r) >> WorldData.SHIFT) + 1):
		for kx in range((cx - r) >> WorldData.SHIFT, ((cx + r) >> WorldData.SHIFT) + 1):
			var trees: Dictionary = world.tree_chunks.get(Vector2i(kx, kz), {})
			if not trees.is_empty():
				wooded.append(trees)
	if wooded.is_empty():
		return null
	for attempt in 8:
		var trees: Dictionary = wooded[rng.randi() % wooded.size()]
		var t: Vector2i = trees.keys()[rng.randi() % trees.size()]
		if absi(t.x - cx) <= r and absi(t.y - cz) <= r and world.leaf_col(t.x, t.y) != 0:
			var at := (Vector3(t.x, 0.0, t.y) + Vector3(rng.randf_range(0.0, 1.0), 0.0, rng.randf_range(0.0, 1.0))) * CELL
			return _settle(spec, at, true)
	return null


## A walker looks the floor up again after this much of a cell walked within one
## cell: a slope under its feet is followed a step late, less than a pixel.
const LOOK_AGAIN := 0.2 * CELL


## Whether the floor `a` last looked up (Animal.looked, floor_y) still serves at a world
## point: the same cell, within LOOK_AGAIN of where it looked.
func _looked(a: Animal, x: float, z: float) -> bool:
	return floori(x / CELL) == floori(a.looked.x / CELL) and floori(z / CELL) == floori(a.looked.z / CELL) \
			and absf(x - a.looked.x) + absf(z - a.looked.z) < LOOK_AGAIN


## Walks (or swims) `a` toward its target: a walker over ground up to MAX_STEP up or
## down a step, a swimmer through open water, where DIP under the surface it floats
## (and one that comes ashore over the land too). Its velocity is steered toward the
## way at its pace, slowing over the last BRAKE seconds, so it starts, stops and turns
## smoothly; one that hops goes on land in leaps instead (see _leap). A walker whose
## way ends at water, and a swimmer whose way ends at land, stops.
func _move(a: Animal, spec: Dictionary, delta: float) -> void:
	a.moving = false
	if a.perched or sits_still(spec):
		a.vel = Vector2.ZERO
		return
	var speed: float = spec.speed
	match a.state:
		"rest":
			# A climber on its way up to sleep.
			speed = speed * 0.3 if a.climb else 0.0
		"wander":
			# Flyers only hop about on the ground, or paddle about on the water.
			speed *= (0.15 if spec.ashore else 0.1) if spec.flies else 0.3
		"bait":
			speed *= 0.4
		"warn", "bite":
			# Stands its ground growling, or its jaws close.
			speed = 0.0
	if a.idle > 0.0 and a.state == "wander":
		speed = 0.0
	var to := Vector2(a.target.x - a.pos.x, a.target.z - a.pos.z)
	var d := to.length()
	if a.climb and d < 0.3:
		# At the trunk: up into the crown.
		a.pos = a.target
		a.perched = true
		a.climb = false
		a.vel = Vector2.ZERO
		return
	var want := Vector2.ZERO
	if speed > 0.0 and d > 0.05:
		want = to / d * speed * clampf(d / (speed * BRAKE), 0.25, 1.0)
	if spec.hops and not a.floor_wet:
		_leap(a, spec, want, delta)
	else:
		a.hop = 0.0
		a.lift = 0.0
		var grip: float = spec.speed * (FLEE_GRIP if a.state == "flee" or a.state == "charge" else GRIP)
		a.vel = a.vel.move_toward(want, grip * delta)
	var v := a.vel * delta
	if v.length_squared() < 1e-10:
		a.vel = Vector2.ZERO
		_catch(a, spec)
		return
	if v.length() > d and a.hop == 0.0:
		# There: it stops on the spot.
		v = to
		a.vel = Vector2.ZERO
	var np := a.pos + Vector3(v.x, 0.0, v.y)
	var ny: float
	if _looked(a, np.x, np.z):
		ny = a.floor_y
	else:
		ny = _look_floor(a, spec, np)
	if ny > 0.0 and ((spec.swims and not spec.ashore) or absf(ny - a.pos.y) <= MAX_STEP):
		a.pos = Vector3(np.x, lerpf(a.pos.y, ny, minf(1.0, delta * 12.0)), np.z)
		a.moving = v.length() > speed * delta * 0.2 or a.hop > 0.0
		# Turns round only when it really goes the other way, not on a wobble.
		if absf(a.vel.x) > 0.15 * spec.speed + 0.05 and signf(a.vel.x) != a.facing:
			a.facing = signf(a.vel.x)
		a.stride += v.length()
		var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
		if a.stride >= 0.25 + 0.3 * size and a.hop == 0.0:
			a.stride = 0.0
			a.left = not a.left
			if not a.floor_wet:
				stepped.emit(a, Vector3(a.pos.x, ny, a.pos.z), v, a.left, size)
				# Paths of the animals in the snow are trails the player walks easier.
				if clock != null and clock.snow > Body.SNOW_DEEP.x:
					world.tread(floori(a.pos.x / CELL), floori(a.pos.z / CELL), clock.now())
	else:
		a.target = a.pos
		a.climb = false
		a.vel = Vector2.ZERO
		a.hop = 0.0
		a.lift = 0.0
	_catch(a, spec)


## One that hops, on land: a leap along `want` (its velocity steered there), up and
## down over HOP_TIME, then a rest of HOP_REST on the ground before the next one; the
## paw prints of a leap are left where it lands.
func _leap(a: Animal, spec: Dictionary, want: Vector2, delta: float) -> void:
	if a.hop > 0.0:
		a.hop += delta / HOP_TIME
		if a.hop >= 1.0:
			a.hop = 0.0
			a.lift = 0.0
			a.vel = Vector2.ZERO
			var rest := rng.randf_range(HOP_REST.x, HOP_REST.y)
			a.hop_rest = rest * (0.3 if a.state == "flee" else 1.0)
			var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
			a.left = not a.left
			stepped.emit(a, a.pos, Vector2(a.facing, 0.0), a.left, size)
		else:
			a.lift = sin(PI * a.hop) * HOP_HIGH
		return
	a.vel = Vector2.ZERO
	a.hop_rest -= delta
	if want != Vector2.ZERO and a.hop_rest <= 0.0:
		# The leap carries HOP_BURST times its pace, no farther than the way's end.
		var far := minf(want.length() * HOP_BURST * HOP_TIME, Vector2(a.target.x - a.pos.x, a.target.z - a.pos.z).length())
		a.vel = want.normalized() * far / HOP_TIME
		a.hop = 0.001


## Flyer `a` flies toward its target: up over the ground and crowns on the way (no
## higher than a quarter of its `flight` above them, up to CRUISE, and climbing away
## from where it took off by CLIMB a unit), down onto the target over the last DESCENT
## units; it picks up speed and slows down to land (a hunter does not), and sits there
## once it gets there, in a crown, on the ground or on the water.
func _fly(a: Animal, spec: Dictionary, delta: float) -> void:
	var speed: float = spec.speed * (1.0 if a.state == "flee" or a.state == "hunt" else 0.7)
	if a.state == "hunt" and a.prey != null:
		a.target = a.prey.pos
	var to := Vector2(a.target.x - a.pos.x, a.target.z - a.pos.z)
	var d := to.length()
	var want := Vector2.ZERO
	if d > 0.001:
		want = to / d * speed
		if a.state != "hunt":
			want *= clampf(d / (speed * BRAKE), 0.25, 1.0)
	a.vel = a.vel.move_toward(want, spec.speed * AIR_GRIP * delta)
	var step := a.vel * delta
	if step.length() >= d:
		step = to
		a.vel = a.vel.limit_length(speed * 0.3)
	a.pos.x += step.x
	a.pos.z += step.y
	if absf(a.vel.x) > 0.15 * spec.speed + 0.05 and signf(a.vel.x) != a.facing:
		a.facing = signf(a.vel.x)
	d = maxf(0.0, d - step.length())
	var cell := Vector2i(floori(a.pos.x / CELL), floori(a.pos.z / CELL))
	if cell != a.over:
		a.over = cell
		a.below = _canopy(a.pos.x, a.pos.z)
	var below := a.below
	var high := maxf(below, a.target.y) + minf(CRUISE, spec.flight * CELL * 0.25)
	var height := lerpf(a.target.y, high, clampf(d / DESCENT, 0.0, 1.0))
	# Up from where it took off a little at a time, not straight up.
	height = minf(height, maxf(a.from.y, a.target.y) + 0.3 + Vector2(a.pos.x - a.from.x, a.pos.z - a.from.z).length() * CLIMB)
	if d > 0.5:
		height = maxf(height, below + 0.3)
	a.pos.y = move_toward(a.pos.y, height, speed * RISE * delta)
	if d < 0.01 and absf(a.pos.y - a.target.y) < 0.01:
		a.pos = a.target
		a.flying = false
		a.vel = Vector2.ZERO
		a.perched = a.target.y > _floor(spec, a.pos.x, a.pos.z) + 0.3
	_catch(a, spec)


## The top of what is under x, z: the ground or a tree crown, in world units.
func _canopy(x: float, z: float) -> float:
	var top := ground(x, z)
	var leaves: int = world.leaf_col(floori(x / CELL), floori(z / CELL))
	if leaves != 0:
		top = maxf(top, (WorldData.top_level(leaves) + 1) * CELL)
	return top


## A hunter catches its prey when it gets to it, and gives up on one gone or out of
## its reach.
func _catch(a: Animal, spec: Dictionary) -> void:
	if a.state != "hunt" or a.prey == null:
		return
	if a.prey.gone or (a.prey.aloft() and not spec.flies):
		a.prey = null
		a.state = "wander"
	elif a.pos.distance_to(a.prey.pos) < 0.7:
		_remove(a.prey)
		a.prey = null
		a.hunger = 0.0
		a.state = "wander"


# --- Hunting ----------------------------------------------------------------------------

## How long a hit animal flees from the place of the hit, in seconds.
const HURT_FLEE := 8.0
## How far in front of the one who strikes a blow lands, in world units, and how wide
## (the cosine of the half angle): one right by their side is hit whichever way they face.
const STRIKE_REACH := 1.4
const STRIKE_CLOSE := 0.5
const STRIKE_CONE := 0.35


## The animal a blow from `at` toward `dir` (over the ground, x east and y south)
## lands on: the nearest on the ground within `reach` (STRIKE_REACH) in front, within
## the angle whose cosine is `cone`, one that can be hit (its species has `health`); null
## for none.
func in_front(at: Vector3, dir: Vector2, reach := STRIKE_REACH, cone := STRIKE_CONE) -> Animal:
	var best: Animal = null
	var best_d := INF
	var way := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	for a in animals:
		if a.gone or a.health <= 0 or a.aloft() or absf(a.pos.y - at.y) > 1.5:
			continue
		var off := Vector2(a.pos.x - at.x, a.pos.z - at.z)
		var d := maxf(0.0, off.length() - a.radius)
		if d > reach or d >= best_d:
			continue
		if d > STRIKE_CLOSE and off.normalized().dot(way) < cone:
			continue
		best = a
		best_d = d
	return best


## Animal `a` is hit with `power` from world point `from` (by `by`, one of the people,
## or null): it loses that much health and flees (its flock with it), or, when it fights
## back (see _fights_back), goes for `by`; at none it dies and is taken out of the world.
## Whether it died.
func hurt(a: Animal, power: int, from: Vector3, by = null) -> bool:
	if a.gone or a.health <= 0:
		return false
	a.health -= maxi(1, power)
	if a.health <= 0:
		_remove(a)
		return true
	if by != null and _fights_back(a, AiRules.SPECIES[a.kind], by):
		if a.foe != by:
			a.bites = 0
		a.foe = by
		a.rage = maxf(a.rage, DEFEND_RAGE)
		a.calm = 0.0
		a.warn = 0.0
		a.hurt = 0.0
		if a.state != "bite":
			a.state = "charge"
		a.idle = 0.0
		return false
	if a.foe != null:
		# Too hurt to fight on: it runs, and lets the people be a while.
		a.foe = null
		a.calm = CALM
	a.hurt = HURT_FLEE
	a.hurt_from = from
	a.idle = 0.0
	a.think = 0.0
	return false


# --- Attacks ----------------------------------------------------------------------
# (plan/design/creatures-ai.md: rules for all, kinds differ only by their properties.)
# Only a kind with a `bite` goes for the people. One that does not fear them
# (`human_wariness` under 0.5) keeps its ground: one who comes within CLOSE of its
# sight is growled at for WARN seconds (it stands, facing them), and gone for if
# they stay; it fights back when hit. A meat eater hunts a person when it is very
# hungry (BOLD_HUNGER) and awake, and its flock is stronger than the person (see
# _strong_enough: a wounded one is weaker, an armed one stronger, a flock stronger in
# winter). A fire near keeps them off as it does any threat (a light in a hand not a
# hungry flock in winter, see _fire_near). A walker does not follow into the water nor
# up where it cannot step. One that defends gives up after DEFEND_BITES bites or
# its fury, one that hunts when its prey is dead, out of reach, or it is hurt to half
# its health; then it lets the people be for CALM seconds.

## The share of its sight within which one that does not fear people warns them off,
## and the seconds it warns before it goes for them.
const CLOSE := 0.25
const WARN := 1.5
## Seconds of fury: of one that defends itself (anew each time it is hit), and of one
## that hunts (anew each bite it lands); seconds it lets the people be after a fight.
const DEFEND_RAGE := 8.0
const HUNT_RAGE := 15.0
const CALM := 20.0
## Bites one that defends lands before it is done.
const DEFEND_BITES := 2
## The jaws: seconds from the leap to the bite (its `attack` frames), seconds between
## two bites, and how far past both bodies it reaches (world units).
const BITE_TIME := 0.4
const BITE_EVERY := 1.4
const BITE_REACH := 0.35
## A person's body for the bites: its radius and how far up or down a bite reaches it
## (world units).
const PERSON_RADIUS := 0.25
const BITE_HIGH := 1.0
## How a bite throws the one bitten (Body.knock).
const KNOCK := 2.5
const KNOCK_HOP := 1.0
## A person's strength against a flock (see _strong_enough): their mass times this (wits
## and hands), at full health; a wounded one has PERSON_WEAK of it plus the rest by
## the health left; a weapon in hand adds ARMED. A flock is WINTER_BOLD stronger in winter.
const PERSON_WITS := 2.0
const PERSON_WEAK := 0.4
const ARMED := 1.3
const WINTER_BOLD := 1.25


## Whether the animals may go for the people now (the rules' `animal_attacks`).
func _attacks_on() -> bool:
	return rules == null or not "animal_attacks" in rules or rules.animal_attacks


## Whether animal `a` (of `spec`) is a fighter: its kind bites, it is wild and the
## rules let the animals attack.
func _fighter(a: Animal, spec: Dictionary) -> bool:
	return float(spec.get("bite", 0.0)) > 0.0 and a.owner < 0 and _attacks_on()


## Animal `a`'s fight with the people, when it thinks (from _decide): true when it
## took the decision (it goes for a person, keeps on at one, or warns one off). `fire`
## is the fire that keeps it off, if any: it breaks off then.
func _fights(a: Animal, spec: Dictionary, fire: Variant) -> bool:
	if not _fighter(a, spec) or fire != null or a.flying or a.perched:
		if a.foe != null or a.state == "warn" or a.state == "charge":
			_calm_down(a)
		return false
	if a.foe != null:
		if a.rage > 0.0 and _reachable(a, a.foe):
			a.state = "charge"
			a.idle = 0.0
			a.target = a.foe.position
			return true
		if a.hunting and a.foe in people and a.foe.has_method("is_dead") and a.foe.is_dead():
			# It got its prey.
			a.hunger = 0.0
		_calm_down(a)
		return false
	if a.calm > 0.0 or a.hurt > 0.0:
		return false
	var hungry: bool = "meat" in spec.diet and a.hunger > BOLD_HUNGER and AiRules.is_active(a.kind, _daylight)
	var bold: bool = spec.human_wariness < 0.5
	var near_d := INF
	var near_who = null
	for who in people:
		if not _reachable(a, who):
			continue
		var d := a.pos.distance_to(who.position)
		if d < near_d:
			near_d = d
			near_who = who
	if near_who != null and hungry and near_d < spec.sight and _strong_enough(a, spec, near_who):
		_go_for(a, near_who, true)
		return true
	if near_who != null and bold and near_d < spec.sight * CLOSE:
		if a.state == "warn" and a.warn <= 0.0:
			_go_for(a, near_who, false)
			return true
		if a.state != "warn":
			# It growls (its alarm) and stands, facing them.
			a.state = "warn"
			a.warn = WARN
			a.idle = 0.0
			if near_who.has_method("nag"):
				near_who.nag("beast_warn", "%s угрожает: отойдите" % spec.title)
		a.target = a.pos
		a.facing = signf(near_who.position.x - a.pos.x) if absf(near_who.position.x - a.pos.x) > 0.01 else a.facing
		return true
	if a.state == "warn":
		# They went away: it lets them be.
		a.state = "wander"
		a.warn = 0.0
	return false


## Animal `a` goes for `who`: to hunt them (`hunting`), or to drive them off.
func _go_for(a: Animal, who, hunting: bool) -> void:
	if a.foe != who:
		a.bites = 0
	a.foe = who
	a.hunting = hunting
	a.rage = HUNT_RAGE if hunting else DEFEND_RAGE
	a.state = "charge"
	a.warn = 0.0
	a.idle = 0.0
	a.target = who.position


## Animal `a` is done with its fight: it lets the people be for CALM seconds.
func _calm_down(a: Animal) -> void:
	a.foe = null
	a.hunting = false
	a.rage = 0.0
	a.warn = 0.0
	a.bites = 0
	a.calm = CALM
	if a.state in ["charge", "warn", "bite"]:
		a.state = "wander"
		a.target = a.pos


## Whether animal `a`, hit by `who`, goes for them rather than run: a fighter that still
## has half its health and does not fear people, or is in a fight already.
func _fights_back(a: Animal, spec: Dictionary, who) -> bool:
	if not _fighter(a, spec) or a.health * 2 < int(spec.health) or not _reachable(a, who):
		return false
	return spec.human_wariness < 0.5 or a.foe != null


## Whether animal `a` can get at `who`: one of the people, alive, with a body, on land a
## walker stands on (not in the water nor in a boat), not much above or below it.
func _reachable(a: Animal, who) -> bool:
	if who == null or not who in people or not "vitals" in who:
		return false
	if who.has_method("is_dead") and who.is_dead():
		return false
	var at: Vector3 = who.position
	if absf(at.y - a.pos.y) > MAX_STEP * 3.0 or ground(at.x, at.z) <= 0.0:
		return false
	if "riding" in who and str(who.riding) != "":
		return false
	return true


## Whether the flock of animal `a` (it and those of its flock within its sight) is
## strong enough to hunt person `who`: its masses, WINTER_BOLD in winter, taken as
## prey are (AiRules.PREY_RATIO) against the person's strength (PERSON_WITS times
## their mass, less as they are hurt, more with a weapon in hand).
func _strong_enough(a: Animal, spec: Dictionary, who) -> bool:
	var pack := 0.0
	var lead := _lead(a)
	if lead == null:
		pack = spec.mass
	else:
		for o: Animal in _kin().get(a.kind, []):
			if not o.gone and _lead(o) == lead and a.pos.distance_to(o.pos) < spec.sight:
				pack += float(spec.mass)
	if clock != null and clock.season == clock.WINTER:
		pack *= WINTER_BOLD
	var share: float = clampf(float(who.vitals.health) / 100.0, 0.0, 1.0)
	var person: float = float(AiRules.SPECIES[AiRules.HUMAN].mass) * PERSON_WITS * (PERSON_WEAK + (1.0 - PERSON_WEAK) * share)
	if who.has_method("held") and not Tools.weapon(str(who.held())).is_empty():
		person *= ARMED
	return pack * AiRules.PREY_RATIO >= person


## The timers of a fight, every step of animal `a`: its warning, its fury and its calm
## run out; one going for a person runs at them and, once near, leaps (`bite`, its
## attack frames) and bites when the leap ends, if they are still in reach.
func _fight_step(a: Animal, spec: Dictionary, dt: float) -> void:
	a.warn = maxf(0.0, a.warn - dt)
	a.calm = maxf(0.0, a.calm - dt)
	a.rage = maxf(0.0, a.rage - dt)
	a.bite_wait = maxf(0.0, a.bite_wait - dt)
	if a.bite > 0.0 and a.state != "bite":
		# Set off its leap by something else (a test, a hit).
		a.bite = 0.0
	if a.bite > 0.0:
		a.bite -= dt
		a.vel = Vector2.ZERO
		if a.bite > 0.0:
			return
		a.bite = 0.0
		if a.foe == null:
			a.state = "wander"
			a.target = a.pos
			return
		a.state = "charge"
		a.bite_wait = BITE_EVERY
		if _reachable(a, a.foe) and _in_reach(a, a.foe, 1.3):
			_land_bite(a, spec, a.foe)
		return
	if a.foe == null or a.state != "charge":
		return
	if not _reachable(a, a.foe):
		return
	a.target = a.foe.position
	if a.bite_wait <= 0.0 and _in_reach(a, a.foe):
		a.state = "bite"
		a.bite = BITE_TIME
		a.vel = Vector2.ZERO
		a.idle = 0.0


## Whether `who` is within the bite of animal `a` (BITE_REACH past both bodies, `more`
## times as far).
func _in_reach(a: Animal, who, more := 1.0) -> bool:
	var at: Vector3 = who.position
	var d := Vector2(at.x - a.pos.x, at.z - a.pos.z).length()
	return d <= (a.radius + PERSON_RADIUS + BITE_REACH) * more and absf(at.y - a.pos.y) <= BITE_HIGH


## Animal `a` bites `who`: they lose its kind's `bite` of health and are thrown back;
## one that hunts is furious anew, one that defends is done after DEFEND_BITES.
func _land_bite(a: Animal, spec: Dictionary, who) -> void:
	who.vitals.wound(float(spec.bite), "animal:" + a.kind)
	var away := Vector2(who.position.x - a.pos.x, who.position.z - a.pos.z)
	if away.length() > 0.01 and "body" in who and who.body != null:
		who.body.knock(away, KNOCK, KNOCK_HOP)
	if who.has_method("nag"):
		who.nag("beast_bite", "%s нападает!" % spec.title)
	a.bites += 1
	bit.emit(a, who)
	if a.hunting:
		a.rage = HUNT_RAGE
	elif a.bites >= DEFEND_BITES:
		_calm_down(a)


## Height of the ground at a world point, in world units; below 0 over open water.
func ground(x: float, z: float) -> float:
	return world.ground_height(x / CELL, z / CELL) * CELL


## Takes animal `a` out of the world (a fish pulled out on a line, Fishing).
func take(a: Animal) -> void:
	if not a.gone:
		_remove(a)


## Height of the water surface at a world point, in world units; -INF where the
## column's top is not open (unfrozen) water.
func water_top(x: float, z: float) -> float:
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	if world.surface_y(cx, cz) != -1:
		return -INF
	return (WorldData.top_level(world.water_col(cx, cz)) + WorldData.WATER_TOP) * CELL


## Where frozen water has open water under its ice, at a world point: the bottom of the
## ice (the top cell of the water frozen), in world units, where the water is two cells
## deep at least; -INF elsewhere, and where the water is not frozen.
func under_ice(x: float, z: float) -> float:
	if not world.water_frozen:
		return -INF
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	var bits: int = world.water_col(cx, cz)
	if bits == 0:
		return -INF
	var top := WorldData.top_level(bits)
	if top < 1 or world.surface_y(cx, cz) != top + 1 or world.get_cell(cx, top - 1, cz) != Mat.WATER:
		return -INF
	return top * CELL


## Whether species `spec` swims under the ice of frozen water (a fish: one that swims
## and neither flies nor comes ashore).
static func under_ice_swimmer(spec: Dictionary) -> bool:
	return spec.swims and not spec.flies and not spec.ashore


## Where an animal of species `spec` stands at a world point, in world units: the
## ground for a walker, DIP under the water surface for a swimmer (the ground out of
## the water for one that comes ashore), DIP under the ice for a fish in frozen water;
## 0 or below where it cannot be (water for the one, land for the other).
func _floor(spec: Dictionary, x: float, z: float) -> float:
	if spec.swims:
		var top := water_top(x, z)
		if top == -INF and spec.ashore:
			return ground(x, z)
		if top == -INF and under_ice_swimmer(spec):
			top = under_ice(x, z)
		return top - DIP * CELL
	return ground(x, z)


func _remove(a: Animal) -> void:
	var kept := _kin_of == animals.size()
	animals.erase(a)
	if kept:
		_by_kind[a.kind].erase(a)
		_kin_of = animals.size()
	a.gone = true
	# The first of its flock leads the rest from now on.
	var next: Animal = null
	for o in animals:
		if o.lead == a:
			if next == null:
				next = o
				o.lead = null
			else:
				o.lead = next
	gone.emit(a)


## Brings a group of `kind` into the world on `cells`: one alone, or a flock of the
## species' size (at most `most`) around its lead, at least `away` from the people.
func _spawn_group(kind: String, most: int, cells: Rect2i, away: float) -> void:
	var lead := _spawn(kind, cells, away)
	if lead == null:
		return
	var flock: Array = AiRules.SPECIES[kind].flock
	if flock[1] <= 1:
		return
	var n := mini(rng.randi_range(flock[0], flock[1]), most)
	for i in n - 1:
		var spot := Vector3(rng.randf_range(-FLOCK_REACH, FLOCK_REACH), 0.0, rng.randf_range(-FLOCK_REACH, FLOCK_REACH))
		var pos := lead.pos + spot
		pos.y = _floor(AiRules.SPECIES[kind], pos.x, pos.z)
		if pos.y <= 0.0:
			pos = lead.pos
		var a := _add(kind, pos)
		a.lead = lead
		a.spot = spot


## One of `kind` on a place of its own on `cells`, at least `away` from every one of
## the people, or null when none of the places tried will do. Only on the ground made:
## the first place tried on ground not made yet ends the try.
func _spawn(kind: String, cells: Rect2i, away: float) -> Animal:
	var spec: Dictionary = AiRules.SPECIES[kind]
	for attempt in SPAWN_TRIES:
		var x := cells.position.x + rng.randi_range(0, cells.size.x - 1)
		var z := cells.position.y + rng.randi_range(0, cells.size.y - 1)
		if world.chunk_at(x, z) == null:
			return null
		var y: int = world.surface_y(x, z)
		if spec.swims:
			# Open water, a cell deep at least; a fish also under ice.
			var top := WorldData.top_level(world.water_col(x, z))
			var open := y == -1 or (under_ice_swimmer(spec) and under_ice((x + 0.5) * CELL, (z + 0.5) * CELL) > -INF)
			if not open or top < 1 or world.get_cell(x, top - 1, z) != Mat.WATER:
				continue
		elif y <= world.sea_level or y >= world.size_y or world.get_cell(x, y - 1, z) != Mat.GRASS:
			continue
		var pos := Vector3(x + 0.5, 0.0, z + 0.5) * CELL
		if _near_people(pos, away):
			continue
		# The biome last: the cheap tests above leave most places out first.
		if not spec.biomes.is_empty() and gen != null:
			var b: int = gen.biome_of(x, z)
			if b == Biomes.NONE or not Biomes.IDS[b] in spec.biomes:
				continue
		pos.y = _floor(spec, pos.x, pos.z)
		return _add(kind, pos)
	return null


## Whether `pos` is within `away` of any of the people (on the ground).
func _near_people(pos: Vector3, away: float) -> bool:
	for who in people:
		var d: Vector3 = who.position - pos
		if Vector2(d.x, d.z).length() < away:
			return true
	return false


func _add(kind: String, pos: Vector3) -> Animal:
	var a := Animal.new()
	_next_id += 1
	a.id = _next_id
	a.kind = kind
	a.pos = pos
	a.target = pos
	a.hunger = rng.randf() * 0.5
	a.think = rng.randf() * 0.5
	a.home = pos
	a.floor_wet = AiRules.SPECIES[kind].swims
	a.radius = radius(AiRules.SPECIES[kind])
	a.health = AiRules.SPECIES[kind].health
	var tints: Array = AiRules.SPECIES[kind].tints
	if tints.size() > 1:
		a.tint = rng.randi() % tints.size()
	# Those far away take their steps in different frames.
	a.away = rng.randf() * FAR_STEP
	if _kin_of == animals.size():
		_by_kind.get_or_add(kind, []).append(a)
		_kin_of += 1
	animals.append(a)
	born.emit(a)
	return a


## Marks the animals on one of the players' screens as looked at (`near`), the rest
## not: `from` has for each player [where they stand (Vector3), the way their screen's
## width lies over the ground (Vector2, unit) and half its width and height in world
## units (Vector2; see Character.view_half)]. A screen not told (zero) is a circle of
## NEAR; a screen is taken as at most NEAR each way.
func look_from(from: Array) -> void:
	# The screens unpacked once: this runs for every animal every frame.
	var near2 := NEAR * NEAR
	var n := from.size()
	var ats := PackedVector2Array()
	var rights := PackedVector2Array()
	var halves := PackedVector2Array()
	for view: Array in from:
		var at: Vector3 = view[0]
		var half: Vector2 = view[2]
		ats.append(Vector2(at.x, at.z))
		rights.append(view[1])
		# A screen not told is a circle (see below).
		halves.append(Vector2.ZERO if half == Vector2.ZERO else Vector2(minf(half.x, NEAR), minf(half.y, NEAR)))
	for a in animals:
		var near := false
		var px := a.pos.x
		var pz := a.pos.z
		for i in n:
			var dx := px - ats[i].x
			var dz := pz - ats[i].y
			var half := halves[i]
			if half == Vector2.ZERO:
				if dx * dx + dz * dz < near2:
					near = true
					break
				continue
			var right := rights[i]
			if absf(dx * right.x + dz * right.y) < half.x and absf(dz * right.x - dx * right.y) < half.y:
				near = true
				break
		a.near = near


## A body's half width on the ground, in world units, by its mass.
static func radius(spec: Dictionary) -> float:
	return clampf(0.12 * pow(spec.mass, 1.0 / 3.0), 0.05, 0.6)


## The animals someone looks at, on the ground or in the water, push each other apart
## where their bodies (see radius) meet, and the people too: each gives way by the
## other's share of their masses, an animal only onto ground it can stand on, else the
## other takes it all. What the people are pushed is left in `pushes`.
func _jostle() -> void:
	pushes.resize(people.size())
	pushes.fill(Vector3.ZERO)
	var low: Array[Animal] = []
	for a in animals:
		if a.near and not a.aloft() and not a.gone and not sits_still(AiRules.SPECIES[a.kind]):
			low.append(a)
	if low.is_empty():
		return
	# Sorted west to east, so each one is tried only against those within reach east of
	# it, not every other one.
	low.sort_custom(_wester)
	var n := low.size()
	var people_mass: float = AiRules.SPECIES[AiRules.HUMAN].mass
	var people_radius := Body.HALF_WIDTH * CELL
	for i in n:
		var a := low[i]
		var sa: Dictionary = AiRules.SPECIES[a.kind]
		var ra := a.radius
		for j in range(i + 1, n):
			var b := low[j]
			var dx := b.pos.x - a.pos.x
			if dx >= ra + MOST_RADIUS:
				break
			var dz := b.pos.z - a.pos.z
			var reach := ra + b.radius
			if dx >= reach or absf(dz) >= reach or absf(b.pos.y - a.pos.y) > reach + 0.5:
				continue
			var sb: Dictionary = AiRules.SPECIES[b.kind]
			var d := sqrt(dx * dx + dz * dz)
			if d >= reach:
				continue
			var dir := Vector2(dx, dz) / d if d > 0.001 else Vector2.RIGHT.rotated(rng.randf() * TAU)
			var over := reach - d
			var share: float = sb.mass / (sa.mass + sb.mass)
			if not _shove(a, sa, -dir * over * share):
				share = 0.0
			if not _shove(b, sb, dir * over * (1.0 - share)):
				_shove(a, sa, -dir * over * (1.0 - share))
		for k in people.size():
			var at: Vector3 = people[k].position
			var dx := a.pos.x - at.x
			var dz := a.pos.z - at.z
			var reach := ra + people_radius
			if absf(dx) >= reach or absf(dz) >= reach or absf(a.pos.y - at.y) > Body.HEIGHT * CELL:
				continue
			var d := sqrt(dx * dx + dz * dz)
			if d >= reach:
				continue
			var dir := Vector2(dx, dz) / d if d > 0.001 else Vector2.RIGHT
			var over := reach - d
			var share: float = people_mass / (sa.mass + people_mass)
			if not _shove(a, sa, dir * over * share):
				share = 0.0
			var back := -dir * over * (1.0 - share)
			pushes[k] += Vector3(back.x, 0.0, back.y)


static func _wester(a: Animal, b: Animal) -> bool:
	return a.pos.x < b.pos.x


## Looks up the floor of animal `a` at `at` (world units, its height unused) and keeps
## it: the level, whether it is water to swim in, and where an ashore swimmer last swam.
func _look_floor(a: Animal, spec: Dictionary, at: Vector3) -> float:
	var y := _floor(spec, at.x, at.z)
	a.looked = at
	a.floor_y = y
	a.floor_wet = spec.swims and (not spec.ashore or water_top(at.x, at.z) > -INF)
	if spec.ashore and a.floor_wet:
		a.home = at
	return y


## Moves animal `a` over the ground by `by` (world units) when it can stand there;
## whether it did.
func _shove(a: Animal, spec: Dictionary, by: Vector2) -> bool:
	if by.length_squared() < 1e-8:
		return true
	var x := a.pos.x + by.x
	var z := a.pos.z + by.y
	var y: float
	if _looked(a, x, z):
		y = a.floor_y
	else:
		# One shoved about on the spot (a flock standing) looks the floor up once.
		y = _look_floor(a, spec, Vector3(x, a.pos.y, z))
	if y <= 0.0 or (not (spec.swims and not spec.ashore) and absf(y - a.pos.y) > MAX_STEP):
		return false
	a.pos = Vector3(x, y, z)
	return true
