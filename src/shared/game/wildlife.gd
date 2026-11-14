extends "res://src/shared/game/wildlife_fight.gd"
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
## The script is a chain of parts (decision 168), each extending the one before:
## wildlife_base (the numbers, the Animal, the ground) ← wildlife_spawn (where they come
## from, the tamed) ← wildlife_move (senses and bodies) ← wildlife_fight (hunting and
## attacks) ← this one, which runs them (update) and decides what each does (_decide).


## How often the fires that keep the animals off are looked for again, in seconds.
const FIRE_EVERY := 0.5


## Runs the animals for `delta` seconds: the near ones every call, the others every
## FAR_STEP seconds.
func update(delta: float) -> void:
	delta = minf(delta, 0.1)
	respawn_timer += delta
	if respawn_timer > RESPAWN_EVERY:
		respawn_timer = 0.0
		_plan_refill()
	_refill_some(REFILL_MOST)
	_settle_timer += delta
	if _settle_timer > SETTLE_EVERY:
		_settle_timer = 0.0
		_leave()
		if _settle_new(SETTLE_MOST):
			_settle_timer = SETTLE_EVERY
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


func _decide(a: Animal, spec: Dictionary) -> void:
	if a.bait.is_finite():
		# Lured by a float: nothing else matters to it until it has bitten or let go.
		a.state = "bait"
		a.cause = ""
		a.idle = 0.0
		a.target = Vector3(a.bait.x, a.pos.y, a.bait.z)
		return
	if a.state == "bite":
		# Its jaws close (see _fight_step): nothing else for that moment.
		return
	var sight: float = spec.sight
	var threat_pos: Variant = null
	var threat_d := INF
	var threat_what := ""
	if a.owner < 0 and AiRules.is_threat(a.kind, AiRules.HUMAN):
		# A person within 0.6 of its sight startles it; once fleeing it stays wary until
		# they are out of sight, so it does not wander back at the edge of its fear. One
		# that is tamed by hand does not flee from a person holding its food.
		var wary := sight if a.state == "flee" else sight * 0.6
		for who in people:
			if not spec.tame_food.is_empty() and a.hurt <= 0.0 and who.has_method("held") and who.held() in spec.tame_food:
				continue
			var at: Vector3 = who.position
			# Up a tree it is as near to them as its foot is: however high the crown, a
			# person by the trunk keeps it up there (it ran down and up again).
			var d := (a.foot if a.foot.is_finite() else a.pos).distance_to(at)
			if d < wary and d < threat_d:
				threat_pos = at
				threat_d = d
				threat_what = "person"
	var fire: Variant = _fire_near(a, spec)
	if _fights(a, spec, fire):
		return
	if fire != null and a.pos.distance_to(fire) < threat_d:
		threat_pos = fire
		threat_d = a.pos.distance_to(fire)
		threat_what = "fire"
	if a.hurt > 0.0:
		# A hit one flees from where it was hit, whether it fears people or not.
		threat_pos = a.hurt_from
		threat_d = a.pos.distance_to(a.hurt_from)
		threat_what = "hurt"
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
				threat_what = o.kind
			elif d < prey_d and what == FOOD and (spec.flies or not o.aloft()):
				prey = o
				prey_d = d
			elif o.state == "flee" and lead != null and _lead(o) == lead and a.pos.distance_to(o.fear) < sight:
				alarm = o.fear
	# One of the flock fleeing frightens the rest.
	if threat_pos == null and alarm != null:
		threat_pos = alarm
		threat_what = "alarm"
	if threat_pos != null:
		a.state = "flee"
		a.cause = threat_what
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
			# A climber stays up its tree (back up, if it was coming down) a while
			# after the threat is gone, or runs up the nearest one.
			if a.foot.is_finite():
				a.target = a.crown
				a.idle = rng.randf_range(STAY_UP.x, STAY_UP.y)
				return
			if a.climb:
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
		a.cause = ""
		if a.climb:
			return
		if a.foot.is_finite():
			a.target = a.crown
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
	if a.foot.is_finite():
		# Safe and awake: a climber comes down its trunk, once it has sat a while.
		a.state = "wander"
		a.cause = ""
		if a.idle <= 0.0:
			a.target = a.foot
		return
	if prey != null and a.hunger > 0.5:
		a.state = "hunt"
		a.cause = prey.kind
		a.prey = prey
		a.target = prey.pos
		if spec.flies:
			_lift_off(a)
		return
	if "plants" in spec.diet:
		a.hunger = maxf(0.0, a.hunger - 0.04)
	var was := a.state
	a.state = "wander"
	if was != "wander":
		a.cause = ""
	if a.flying:
		return
	if lead != null and lead != a:
		a.cause = "lead"
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
		a.cause = "graze" if to != null else ""
		if _fire_near(a, spec, a.target) != null:
			# It does not wander up to a fire: it stays where it is a while instead.
			a.target = a.pos
			a.idle = rng.randf_range(LINGER.x, LINGER.y)


## What animal `a` has in mind, for the AI's debug (Protocol.MINDS, decision 184):
## [id, state, cause (see Animal.cause; "hunt_person" or "defend" in a fight with a
## person), hunger 0..1, health, its species' health, where it goes (target), what it
## runs from or goes for (INF for nothing), the id of its flock's lead (-1 none, its own
## for the lead), its owner (-1 wild), seconds of rage, calm, idle and hurt left, its
## sight, how near a person frightens it (0: people do not), how near one makes it growl
## (0: it does not), whether someone sees it (`near`: it thinks every tick, else in
## FAR_STEP steps)]. Plain values, for the wire.
func mind(a: Animal) -> Array:
	var spec: Dictionary = AiRules.SPECIES.get(a.kind, {})
	var sight: float = spec.get("sight", 0.0)
	var cause := a.cause
	var toward := Vector3.INF
	if a.foe != null and a.state in ["warn", "charge", "bite"]:
		cause = "hunt_person" if a.hunting else "defend"
		toward = a.foe.position
	elif a.state == "flee":
		toward = a.fear
	elif a.state == "hunt" and a.prey != null and not a.prey.gone:
		toward = a.prey.pos
	elif a.state == "bait":
		toward = a.bait
	var lead := _lead(a)
	var wary := 0.0
	if a.owner < 0 and AiRules.is_threat(a.kind, AiRules.HUMAN):
		wary = sight if a.state == "flee" else sight * 0.6
	var close := sight * CLOSE if _fighter(a, spec) and spec.get("human_wariness", 1.0) < 0.5 else 0.0
	return [a.id, a.state, cause, a.hunger, a.health, int(spec.get("health", 0)), a.target, toward,
		lead.id if lead != null else -1, a.owner, a.rage, a.calm, a.idle, a.hurt, sight, wary, close, a.near]


## The minds (see mind) of the animals within `reach` world units of `at`, across the ground.
func minds_near(at: Vector3, reach: float) -> Array:
	var out := []
	var r2 := reach * reach
	for a in animals:
		if not a.gone and Vector2(a.pos.x - at.x, a.pos.z - at.z).length_squared() <= r2:
			out.append(mind(a))
	return out
