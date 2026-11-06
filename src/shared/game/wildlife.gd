extends RefCounted
## The animals of the world. Each one only knows its species properties; who is food
## or a threat comes from AiRules. Animals wander, graze, rest outside their active
## hours (by the daylight of the Clock), flee from threats (the people among them) and
## hunt when hungry. Each kind lives at its `count` in the square around each of the
## people, less where little of it is its biomes, spread over the ground made there;
## the eaten and those left far behind are gone and new ones come in their place out
## of sight (_populate). The client draws them (Creatures) as they come, go and walk.
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

## Every this many seconds the animals around the people are counted again (see
## _populate).
const RESPAWN_EVERY := 5.0
const CELL := WorldData.CELL
## Animals walk slopes and hop up a sheer step of one cell, not of two.
const MAX_STEP := 0.55
## Animals appear within this many cells of the people, where the world is made
## (Session.ZONE chunks), each way; ROAM is the same in world units: the square around
## each of the people where its species' `count` live. Past LEAVE of every one of the
## people they go away (before Session.DROP forgets the ground under them).
const SPAWN_REACH := 80
const ROAM := SPAWN_REACH * CELL
const LEAVE := ROAM * 1.5
## Places tried for one animal to come.
const SPAWN_TRIES := 40
## How near the people no animal comes at the start (world units), so they do not all
## stand around the spawn; later they come past a screen (NEAR).
const START_AWAY := 8.0
## The biomes around each of the people are looked at on a grid of this many points
## each way (see _biome_share).
const BIOME_SAMPLES := 6
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

	## Off the ground, out of reach of those that walk.
	func aloft() -> bool:
		return flying or perched


var world
## The layout of the land (LandLayout: `lay_out`), for the biome of a column, where
## species keep to their biomes; null when any ground will do.
var gen
## The clock, for the daylight that sets who is active.
var clock
## Those the animals see as people (threats to the wary, see AiRules.HUMAN): anything
## with a `position` in world units. Animals live around each of them (see _populate).
var people := []
var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()
var respawn_timer := 0.0
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


## Lets the animals of every species come into the world around the people.
func start(seed_value: int) -> void:
	rng.seed = seed_value
	_populate(false)


## Keeps each kind as many around each of the people as its `count` (see wanted) on
## the share of the ground around them that is its biomes (see _biome_share): those
## short come on the ground made there (more as more of it is made), those over go
## away where no one looks, and those past LEAVE of every one of the people go away
## too, so the animals are spread over the world the people walk, not left where they
## first were. The new ones keep `away` from the people (START_AWAY at the start, past
## a screen later).
func _populate(later: bool) -> void:
	if people.is_empty():
		return
	if later:
		_leave()
	for who in people:
		var around: Vector3 = who.position
		var biomes := _biomes_around(around)
		for kind in AiRules.SPECIES:
			if kind == AiRules.HUMAN:
				continue
			var want := roundi(wanted(kind) * _biome_share(kind, biomes))
			var have := _count_near(kind, around)
			if have > want and later:
				_thin(kind, have - want, around)
				continue
			# A try for each one short: a place on ground not made yet is a try spent,
			# so they come spread over the square as its ground is made, not crowded
			# on the first made.
			for i in want - have:
				if have >= want:
					break
				var n := animals.size()
				_spawn_group(kind, want - have, around, NEAR if later else START_AWAY)
				have += animals.size() - n


## The animals of `kind` within ROAM of `around` (on the ground: in cells, each way).
func _count_near(kind: String, around: Vector3) -> int:
	var n := 0
	for a in animals:
		if a.kind == kind and _within(a.pos, around, ROAM):
			n += 1
	return n


static func _within(p: Vector3, around: Vector3, reach: float) -> bool:
	return absf(p.x - around.x) <= reach and absf(p.z - around.z) <= reach


## Takes out the animals past LEAVE of every one of the people that no one looks at:
## they went off into the world no one is in.
func _leave() -> void:
	for a in animals.duplicate():
		if a.near:
			continue
		var kept := false
		for who in people:
			if _within(a.pos, who.position, LEAVE):
				kept = true
				break
		if not kept:
			_remove(a)


## The biomes at BIOME_SAMPLES × BIOME_SAMPLES points over the square of ROAM around
## `around` (the layout tells them without the ground made); empty without a layout.
func _biomes_around(around: Vector3) -> Array:
	var out := []
	if gen == null:
		return out
	for j in BIOME_SAMPLES:
		for i in BIOME_SAMPLES:
			var k := (Vector2(i, j) + Vector2(0.5, 0.5)) / BIOME_SAMPLES * 2.0 - Vector2.ONE
			out.append(gen.biome_of(floori((around.x + k.x * ROAM) / CELL), floori((around.z + k.y * ROAM) / CELL)))
	return out


## The share of `biomes` (see _biomes_around) that are the biomes of `kind`: 1 for a
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
		_populate(true)
	_daylight = clock.daylight()
	moved.clear()
	for a in animals.duplicate():
		if a.gone:
			continue
		var dt := delta
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
		if a.kind == kind and not a.near and _within(a.pos, around, ROAM):
			_remove(a)
			n -= 1


func _decide(a: Animal, spec: Dictionary) -> void:
	if a.bait.is_finite():
		# Lured by a float: nothing else matters to it until it has bitten or let go.
		a.state = "bait"
		a.idle = 0.0
		a.target = Vector3(a.bait.x, a.pos.y, a.bait.z)
		return
	var sight: float = spec.sight
	var threat_pos: Variant = null
	var threat_d := INF
	if AiRules.is_threat(a.kind, AiRules.HUMAN):
		# A person within 0.6 of its sight startles it; once fleeing it stays wary until
		# they are out of sight, so it does not wander back at the edge of its fear.
		var wary := sight if a.state == "flee" else sight * 0.6
		for who in people:
			var at: Vector3 = who.position
			var d := a.pos.distance_to(at)
			if d < wary and d < threat_d:
				threat_pos = at
				threat_d = d
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
			if not a.perched and a.pos.distance_to(a.target) < 0.1 and rng.randf() < 0.3:
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
			if not a.perched and a.pos.distance_to(a.target) < 0.1 and rng.randf() < 0.3:
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
	if a.perched:
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
		var grip: float = spec.speed * (FLEE_GRIP if a.state == "flee" else GRIP)
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


## Animal `a` is hit with `power` from world point `from`: it loses that much health
## and flees (its flock with it); at none it dies and is taken out of the world. Whether
## it died.
func hurt(a: Animal, power: int, from: Vector3) -> bool:
	if a.gone or a.health <= 0:
		return false
	a.health -= maxi(1, power)
	if a.health <= 0:
		_remove(a)
		return true
	a.hurt = HURT_FLEE
	a.hurt_from = from
	a.idle = 0.0
	a.think = 0.0
	return false


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


## Brings a group of `kind` into the world around `around`: one alone, or a flock of
## the species' size (at most `most`) around its lead, at least `away` from the people.
func _spawn_group(kind: String, most: int, around: Vector3, away: float) -> void:
	var lead := _spawn(kind, around, away)
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


## One of `kind` on a place of its own within ROAM of `around`, at least `away` from
## every one of the people, or null when none of the places tried will do. Only on
## the ground made (around the people, see Session.ZONE): the first place tried on
## ground not made yet ends the try, so at the start, with only the ground near the
## spawn made, most do not come yet and the rest come as the ground around is made.
func _spawn(kind: String, around: Vector3, away: float) -> Animal:
	var px := floori(around.x / CELL)
	var pz := floori(around.z / CELL)
	var spec: Dictionary = AiRules.SPECIES[kind]
	for attempt in SPAWN_TRIES:
		var x := px + rng.randi_range(-SPAWN_REACH, SPAWN_REACH)
		var z := pz + rng.randi_range(-SPAWN_REACH, SPAWN_REACH)
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
		if a.near and not a.aloft() and not a.gone:
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
