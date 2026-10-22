extends RefCounted
## The animals of the world. Each one only knows its species properties; who is food
## or a threat comes from AiRules. Animals wander, graze, rest outside their active
## hours (by the daylight of the Clock), flee from threats (the people among them) and
## hunt when hungry; the eaten are gone and new ones come in their place around the
## people. The client draws them (Creatures) as they come, go and walk.

const Body := preload("res://src/shared/game/body.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

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


var world
## The clock, for the daylight that sets who is active.
var clock
## Those the animals see as people (threats to the wary, see AiRules.HUMAN): anything
## with a `position` in world units. Animals appear around the first of them.
var people := []
var animals: Array[Animal] = []
var rng := RandomNumberGenerator.new()
var respawn_timer := 0.0
var _daylight := 1.0


## Lets the animals of every species come into the world around the people.
func start(seed_value: int) -> void:
	rng.seed = seed_value
	for kind in AiRules.SPECIES:
		if kind == AiRules.HUMAN:
			continue
		for i in AiRules.SPECIES[kind].count:
			_spawn(kind, false)


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
				_spawn(kind, true)
	_daylight = clock.daylight()
	for a in animals.duplicate():
		if not animals.has(a):
			continue
		var dt := delta
		if not a.near:
			a.away += delta
			if a.away < FAR_STEP:
				continue
			dt = a.away
		a.away = 0.0
		var spec: Dictionary = AiRules.SPECIES[a.kind]
		a.hunger = minf(1.0, a.hunger + dt * 0.012)
		a.think -= dt
		if a.think <= 0.0:
			a.think = 0.4 + rng.randf() * 0.3
			_decide(a, spec)
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
	for o in animals:
		if o == a:
			continue
		var d := a.pos.distance_to(o.pos)
		if d > sight:
			continue
		if d < threat_d and AiRules.is_threat(a.kind, o.kind):
			threat_pos = o.pos
			threat_d = d
		elif d < prey_d and AiRules.is_food(a.kind, o.kind):
			prey = o
			prey_d = d
	if threat_pos != null:
		a.state = "flee"
		var away: Vector3 = a.pos - threat_pos
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
		a.target = a.pos + away.normalized() * 6.0
		return
	if not AiRules.is_active(a.kind, _daylight):
		a.state = "rest"
		a.target = a.pos
		return
	if prey != null and a.hunger > 0.5:
		a.state = "hunt"
		a.prey = prey
		a.target = prey.pos
		return
	if "plants" in spec.diet:
		a.hunger = maxf(0.0, a.hunger - 0.04)
	if a.state != "wander" or a.pos.distance_to(a.target) < 0.3 or rng.randf() < 0.05:
		a.state = "wander"
		a.target = a.pos + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))


func _move(a: Animal, spec: Dictionary, delta: float) -> void:
	var speed: float = spec.speed
	match a.state:
		"rest":
			speed = 0.0
		"wander":
			speed *= 0.3
	var to := a.target - a.pos
	to.y = 0.0
	if speed > 0.0 and to.length() > 0.1:
		var step := to.normalized() * minf(speed * delta, to.length())
		var np := a.pos + step
		var ny := ground(np.x, np.z)
		if ny > 0.0 and absf(ny - a.pos.y) <= MAX_STEP:
			a.pos = Vector3(np.x, lerpf(a.pos.y, ny, minf(1.0, delta * 12.0)), np.z)
			if absf(step.x) > 0.001:
				a.facing = -1.0 if step.x < 0.0 else 1.0
			a.stride += step.length()
			var size: float = clampf(0.5 + spec.mass / 80.0, 0.5, 1.0)
			if a.stride >= 0.25 + 0.3 * size:
				a.stride = 0.0
				a.left = not a.left
				stepped.emit(a, Vector3(a.pos.x, ny, a.pos.z), Vector2(step.x, step.z), a.left, size)
				# Paths of the animals in the snow are trails the player walks easier.
				if clock != null and clock.snow > Body.SNOW_DEEP.x:
					world.tread(floori(a.pos.x / CELL), floori(a.pos.z / CELL), clock.now())
		else:
			a.target = a.pos
	if a.state == "hunt" and a.prey != null:
		if not animals.has(a.prey):
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


func _remove(a: Animal) -> void:
	animals.erase(a)
	gone.emit(a)


func _spawn(kind: String, away_from_people: bool) -> void:
	# Within the ground made around the first of the people (on the client the
	# player, see ChunkStreamer.LOAD_RANGE).
	var around: Vector3 = people[0].position
	var px := floori(around.x / CELL)
	var pz := floori(around.z / CELL)
	for attempt in 40:
		var x := px + rng.randi_range(-SPAWN_REACH, SPAWN_REACH)
		var z := pz + rng.randi_range(-SPAWN_REACH, SPAWN_REACH)
		var y: int = world.surface_y(x, z)
		if y <= world.sea_level or y >= world.size_y or world.get_cell(x, y - 1, z) != Mat.GRASS:
			continue
		var pos := Vector3(x + 0.5, 0.0, z + 0.5) * CELL
		pos.y = ground(pos.x, pos.z)
		if away_from_people and pos.distance_to(around) < 20.0:
			continue
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
		return
