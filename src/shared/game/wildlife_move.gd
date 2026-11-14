extends "res://src/shared/game/wildlife_spawn.gd"
## Wildlife, what an animal senses and how its body goes: the fires that keep it off,
## whom it sees and cares about, its kin and the lead of its flock; walking, leaping,
## flying, climbing a tree and settling there, catching its prey, and the bodies pushing
## each other apart.


## A fleeing animal keeps this much farther from a fire than it lets itself come.
const FIRE_WARY := 1.3
## A meat eater of a flock this hungry in winter is not kept off by a light in a hand,
## only by a fire set down (plan/design/creatures-ai.md: a hungry pack may come).
const BOLD_HUNGER := 0.7

const NOBODY := 0
const THREAT := 1
const FOOD := 2


## Notes what keeps the animals off (see _fires): the fires burning and the lights set
## down, by the `scares` of their items, and the lights the people hold, by the farthest
## `scares` of those.
func _find_fires() -> void:
	_fires.clear()
	if placed != null:
		# Only those that can scare (Placed.scarers), not every thing set down.
		for e: Dictionary in placed.scarers:
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
