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
## Flyers: how far they fly to another place, in world units, and how far from a
## threat; how high they fly above the ground and crowns, and over how much of the
## way's end they come down.
const FLIGHT := 14.0
const FLIGHT_AWAY := 12.0
const CRUISE := 2.5
const DESCENT := 4.0
## Chance a resting flyer flies over to another place each time it thinks.
const FLY_CHANCE := 0.05
## How far a climber looks for a tree to run up from a threat, in world units.
const CLIMB_REACH := 6.0
## A swimmer keeps this far under the water surface, in cells.
const DIP := 0.35
## A flock keeps within this many world units of its lead.
const FLOCK_REACH := 1.5
const FLOCK_GAP := 4.0

## An animal came into the world, or was eaten and is gone.
signal born(a: Animal)
signal gone(a: Animal)
## A paw of animal `a` came down at `at` walking along `dir` (the left one or not);
## `size` is how big the print is, by the animal's mass.
signal stepped(a: Animal, at: Vector3, dir: Vector2, left: bool, size: float)


class Animal:
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
	## Someone looks at it (on the client: it is on the screen), so it moves every
	## frame; set by the owner before update().
	var near := true
	## Time gathered since the last step while not near (see FAR_STEP); 0 right after
	## a step.
	var away := 0.0
	## Time from the last step to the next one while not near: FAR_STEP, less what the
	## last one came late, so each animal keeps its own beat.
	var wait := FAR_STEP
	## It took a step this update (the client walks its picture).
	var moving := false
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
## with a `position` in world units. Animals appear around the first of them.
var people := []
var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()
var respawn_timer := 0.0
var _daylight := 1.0
## What each kind is to each (see _sees), worked out from AiRules once.
var _seen := {}


## Lets the animals of every species come into the world around the people.
func start(seed_value: int) -> void:
	rng.seed = seed_value
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		var want: int = AiRules.SPECIES[kind].count
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
			if kind != AiRules.HUMAN and count(kind) < AiRules.SPECIES[kind].count:
				_spawn_group(kind, AiRules.SPECIES[kind].count - count(kind), true)
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
		a.think -= dt
		if a.think <= 0.0:
			a.think = 0.4 + rng.randf() * 0.3
			_decide(a, spec)
		if a.flying:
			_fly(a, spec, dt)
		else:
			_move(a, spec, dt)


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
		a.fear = threat_pos
		var away: Vector3 = a.pos - threat_pos
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		if spec.flies:
			if not a.flying:
				_take_off(a, spec, a.pos + away.normalized() * FLIGHT_AWAY, FLIGHT_AWAY * 0.3)
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
					a.flying = true
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
		if spec.flies and not a.flying:
			a.flying = true
			a.perched = false
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
		if rng.randf() < FLY_CHANCE:
			_take_off(a, spec, a.pos, FLIGHT)
		elif not a.perched and a.pos.distance_to(a.target) < 0.1 and rng.randf() < 0.3:
			# Hops about and pecks.
			a.target = a.pos + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		return
	if was != "wander" or a.pos.distance_to(a.target) < 0.3 or rng.randf() < 0.05:
		var to: Variant = null if spec.likes.is_empty() else _place(spec, a.pos, 6.0, false)
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
## settles (in a tree when it sits in one) and hops about there.
func _follow(a: Animal, spec: Dictionary, lead: Animal) -> void:
	var at := lead.target + a.spot
	if spec.flies:
		if lead.flying or a.pos.distance_to(lead.pos) > FLOCK_GAP:
			a.target = _settle(spec, at, lead.target.y > _floor(spec, lead.target.x, lead.target.z) + 0.3)
			a.flying = true
			a.perched = false
		elif not a.perched and a.pos.distance_to(a.target) < 0.1 and rng.randf() < 0.3:
			a.target = a.pos + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
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
	a.flying = true
	a.perched = false


## A place to go within `reach` of `around`: of a few tried, one where something the
## species likes grows, else any open ground (open water for a swimmer); a spot in a
## crown when `tree` and there is a tree near. Null when all of those tried are water
## or under crowns (land, for a swimmer).
func _place(spec: Dictionary, around: Vector3, reach: float, tree: bool) -> Variant:
	if tree:
		var spot: Variant = _tree_spot(spec, around, reach)
		if spot != null:
			return spot
	var best := around
	var best_score := -1
	for i in 8:
		var p := around + Vector3(rng.randf_range(-reach, reach), 0.0, rng.randf_range(-reach, reach))
		var x := floori(p.x / CELL)
		var z := floori(p.z / CELL)
		var y: int = world.surface_y(x, z)
		if spec.swims:
			# Open water only.
			if y != -1:
				continue
		# Not over water or under a crown.
		elif y <= 0 or world.leaf_col(x, z) >> y != 0:
			continue
		var score := 0
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


## Walks (or swims) `a` toward its target: a walker over ground up to MAX_STEP up or
## down a step, a swimmer through open water, where DIP under the surface it floats.
## A walker whose way ends at water, and a swimmer whose way ends at land, stops.
func _move(a: Animal, spec: Dictionary, delta: float) -> void:
	a.moving = false
	if a.perched:
		return
	var speed: float = spec.speed
	match a.state:
		"rest":
			# A climber on its way up to sleep.
			speed = speed * 0.3 if a.climb else 0.0
		"wander":
			# Flyers only hop about on the ground.
			speed *= 0.1 if spec.flies else 0.3
	var to := a.target - a.pos
	to.y = 0.0
	if a.climb and to.length() < 0.3:
		# At the trunk: up into the crown.
		a.pos = a.target
		a.perched = true
		a.climb = false
		return
	if speed > 0.0 and to.length() > 0.1:
		var step := to.normalized() * minf(speed * delta, to.length())
		var np := a.pos + step
		var ny: float
		if floori(np.x / CELL) == floori(a.looked.x / CELL) and floori(np.z / CELL) == floori(a.looked.z / CELL) \
				and absf(np.x - a.looked.x) + absf(np.z - a.looked.z) < LOOK_AGAIN:
			ny = a.floor_y
		else:
			ny = _floor(spec, np.x, np.z)
			a.looked = np
			a.floor_y = ny
		if ny > 0.0 and (spec.swims or absf(ny - a.pos.y) <= MAX_STEP):
			a.pos = Vector3(np.x, lerpf(a.pos.y, ny, minf(1.0, delta * 12.0)), np.z)
			a.moving = true
			if absf(step.x) > 0.001:
				a.facing = -1.0 if step.x < 0.0 else 1.0
			a.stride += step.length()
			var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
			if a.stride >= 0.25 + 0.3 * size:
				a.stride = 0.0
				a.left = not a.left
				if not spec.swims:
					stepped.emit(a, Vector3(a.pos.x, ny, a.pos.z), Vector2(step.x, step.z), a.left, size)
					# Paths of the animals in the snow are trails the player walks easier.
					if clock != null and clock.snow > Body.SNOW_DEEP.x:
						world.tread(floori(a.pos.x / CELL), floori(a.pos.z / CELL), clock.now())
		else:
			a.target = a.pos
			a.climb = false
	_catch(a, spec)


## Flyer `a` flies toward its target: up over the ground and crowns on the way, down
## onto the target over the last DESCENT units; it sits there once it gets there, in a
## crown or on the ground.
func _fly(a: Animal, spec: Dictionary, delta: float) -> void:
	var speed: float = spec.speed * (1.0 if a.state == "flee" or a.state == "hunt" else 0.7)
	if a.state == "hunt" and a.prey != null:
		a.target = a.prey.pos
	var to := Vector2(a.target.x - a.pos.x, a.target.z - a.pos.z)
	var d := to.length()
	if d > 0.001:
		var step := to / d * minf(speed * delta, d)
		a.pos.x += step.x
		a.pos.z += step.y
		if absf(step.x) > 0.001:
			a.facing = -1.0 if step.x < 0.0 else 1.0
		d -= step.length()
	var cell := Vector2i(floori(a.pos.x / CELL), floori(a.pos.z / CELL))
	if cell != a.over:
		a.over = cell
		a.below = _canopy(a.pos.x, a.pos.z)
	var below := a.below
	var high := maxf(below, a.target.y) + CRUISE
	var want := lerpf(a.target.y, high, clampf(d / DESCENT, 0.0, 1.0))
	if d > 0.5:
		want = maxf(want, below + 0.3)
	a.pos.y = move_toward(a.pos.y, want, speed * delta)
	if d < 0.01 and absf(a.pos.y - a.target.y) < 0.01:
		a.pos = a.target
		a.flying = false
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
## ground for a walker, DIP under the water surface for a swimmer; 0 or below where
## it cannot be (water for the one, land for the other).
func _floor(spec: Dictionary, x: float, z: float) -> float:
	if spec.swims:
		return water_top(x, z) - DIP * CELL
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
	# Within the ground made around the first of the people (on the client the
	# player, see ChunkStreamer.LOAD_RANGE).
	var around: Vector3 = people[0].position
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


func _add(kind: String, pos: Vector3) -> Animal:
	var a := Animal.new()
	a.kind = kind
	a.pos = pos
	a.target = pos
	a.hunger = rng.randf() * 0.5
	a.think = rng.randf() * 0.5
	# Those far away take their steps in different frames.
	a.away = rng.randf() * FAR_STEP
	animals.append(a)
	born.emit(a)
	return a
