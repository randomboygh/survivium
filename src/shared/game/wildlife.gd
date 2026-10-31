extends RefCounted
## The animals of the world. Each one only knows its species properties; who is food
## or a threat comes from AiRules. Animals wander, graze, rest outside their active
## hours (by the daylight of the Clock), flee from threats (the people among them) and
## hunt when hungry; the eaten are gone and new ones come in their place around the
## people. The client draws them (Creatures) as they come, go and walk.
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

const RESPAWN_EVERY := 15.0
const CELL := WorldData.CELL
## Animals walk slopes and hop up a sheer step of one cell, not of two.
const MAX_STEP := 0.55
## Animals appear within this many cells of the people, where the world is made.
const SPAWN_REACH := 80
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
	## Eaten, out of the world.
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
## with a `position` in world units. Animals appear around any of them (see _someone).
var people := []
var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()
var respawn_timer := 0.0
var _daylight := 1.0
## What each kind is to each (see _sees), worked out from AiRules once.
var _seen := {}
## What the people were pushed by the animals they ran into (see _jostle), in world
## units, one for each of `people` (on the client, the player's body takes it).
var pushes: Array[Vector3] = []
## The number the last animal got (Animal.id).
var _next_id := 0


## Lets the animals of every species come into the world around the people.
func start(seed_value: int) -> void:
	rng.seed = seed_value
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var want := wanted(kind)
		for i in want:
			if count(kind) >= want:
				break
			_spawn_group(kind, want - count(kind), false)


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
		for kind in AiRules.SPECIES:
			if kind == AiRules.HUMAN:
				continue
			var want := wanted(kind)
			if count(kind) < want:
				_spawn_group(kind, want - count(kind), true)
			elif count(kind) > want:
				_thin(kind, count(kind) - want)
	_daylight = clock.daylight()
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
		var spec: Dictionary = AiRules.SPECIES[a.kind]
		a.hunger = minf(1.0, a.hunger + dt * 0.012)
		a.idle = maxf(0.0, a.idle - dt)
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


## Takes up to `n` of `kind` out of the world, those no one looks at (they hid away).
func _thin(kind: String, n: int) -> void:
	for a in animals.duplicate():
		if n <= 0:
			return
		if a.kind == kind and not a.near:
			_remove(a)
			n -= 1


func _decide(a: Animal, spec: Dictionary) -> void:
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
	var prey: Animal = null
	var prey_d := INF
	var lead := _lead(a)
	var alarm: Variant = null
	# Most others are nobody to it: those are passed by first, as there are many.
	var sees := _sees(a.kind)
	var sight2 := sight * sight
	for o in animals:
		var what: int = sees[o.kind]
		if (what == NOBODY and (lead == null or o.state != "flee")) or o == a:
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
		ny = _floor(spec, np.x, np.z)
		a.looked = np
		a.floor_y = ny
		a.floor_wet = spec.swims and (not spec.ashore or water_top(np.x, np.z) > -INF)
		if spec.ashore and a.floor_wet:
			a.home = np
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


## Height of the ground at a world point, in world units; below 0 over open water.
func ground(x: float, z: float) -> float:
	return world.ground_height(x / CELL, z / CELL) * CELL


## Height of the water surface at a world point, in world units; -INF where the
## column's top is not open (unfrozen) water.
func water_top(x: float, z: float) -> float:
	var cx := floori(x / CELL)
	var cz := floori(z / CELL)
	if world.surface_y(cx, cz) != -1:
		return -INF
	return (WorldData.top_level(world.water_col(cx, cz)) + WorldData.WATER_TOP) * CELL


## Where an animal of species `spec` stands at a world point, in world units: the
## ground for a walker, DIP under the water surface for a swimmer (the ground out of
## the water for one that comes ashore); 0 or below where it cannot be (water for the
## one, land for the other).
func _floor(spec: Dictionary, x: float, z: float) -> float:
	if spec.swims:
		var top := water_top(x, z)
		if top == -INF and spec.ashore:
			return ground(x, z)
		return top - DIP * CELL
	return ground(x, z)


func _remove(a: Animal) -> void:
	animals.erase(a)
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


## Brings a group of `kind` into the world: one alone, or a flock of the species'
## size (at most `most`) around its lead.
func _spawn_group(kind: String, most: int, away_from_people: bool) -> void:
	var lead := _spawn(kind, away_from_people)
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


func _spawn(kind: String, away_from_people: bool) -> Animal:
	# Within the ground made around one of the people (on the client the player, see
	# ChunkStreamer.LOAD_RANGE).
	var around: Vector3 = _someone().position
	var px := floori(around.x / CELL)
	var pz := floori(around.z / CELL)
	var spec: Dictionary = AiRules.SPECIES[kind]
	for attempt in 40:
		var x := px + rng.randi_range(-SPAWN_REACH, SPAWN_REACH)
		var z := pz + rng.randi_range(-SPAWN_REACH, SPAWN_REACH)
		var y: int = world.surface_y(x, z)
		if not spec.biomes.is_empty() and gen != null:
			var b: int = gen.lay_out(x, z, 1, 1).biome[0]
			if b == Biomes.NONE or not Biomes.IDS[b] in spec.biomes:
				continue
		if spec.swims:
			# Open water, a cell deep at least.
			if y != -1 or WorldData.top_level(world.water_col(x, z)) < 1 \
					or world.get_cell(x, WorldData.top_level(world.water_col(x, z)) - 1, z) != Mat.WATER:
				continue
		elif y <= world.sea_level or y >= world.size_y or world.get_cell(x, y - 1, z) != Mat.GRASS:
			continue
		var pos := Vector3(x + 0.5, 0.0, z + 0.5) * CELL
		pos.y = _floor(spec, pos.x, pos.z)
		if away_from_people and pos.distance_to(around) < 20.0:
			continue
		return _add(kind, pos)
	return null


## One of the people for the animals to come around: the only one, else any; the roll is
## spared with one, so a world played alone keeps its animals.
func _someone():
	return people[0] if people.size() == 1 else people[rng.randi() % people.size()]


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
	var tints: Array = AiRules.SPECIES[kind].tints
	if tints.size() > 1:
		a.tint = rng.randi() % tints.size()
	# Those far away take their steps in different frames.
	a.away = rng.randf() * FAR_STEP
	animals.append(a)
	born.emit(a)
	return a


## Marks the animals on one of the players' screens as looked at (`near`), the rest
## not: `from` has for each player [where they stand (Vector3), the way their screen's
## width lies over the ground (Vector2, unit) and half its width and height in world
## units (Vector2; see Character.view_half)]. A screen not told (zero) is a circle of
## NEAR; a screen is taken as at most NEAR each way.
func look_from(from: Array) -> void:
	var near2 := NEAR * NEAR
	for a in animals:
		a.near = false
		for view: Array in from:
			var at: Vector3 = view[0]
			var dx := a.pos.x - at.x
			var dz := a.pos.z - at.z
			var half: Vector2 = view[2]
			if half == Vector2.ZERO:
				if dx * dx + dz * dz < near2:
					a.near = true
					break
				continue
			var right: Vector2 = view[1]
			if absf(dx * right.x + dz * right.y) < minf(half.x, NEAR) \
					and absf(dz * right.x - dx * right.y) < minf(half.y, NEAR):
				a.near = true
				break


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
		y = _floor(spec, x, z)
		a.looked = Vector3(x, 0.0, z)
		a.floor_y = y
	if y <= 0.0 or (not (spec.swims and not spec.ashore) and absf(y - a.pos.y) > MAX_STEP):
		return false
	a.pos = Vector3(x, y, z)
	return true
