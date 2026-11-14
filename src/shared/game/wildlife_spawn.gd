extends "res://src/shared/game/wildlife_base.gd"
## Wildlife, where the animals come from: each chunk made gets its own, the eaten come
## back out of sight, those whose ground is forgotten go; and the tamed ones, which are
## kept by their owners, bred and let go.


## How near its owner a tamed one following keeps, and how far from where it was told to
## stay it wanders, in world units.
const TAME_FOLLOW := 1.2
const TAME_ROAM := 2.5


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
## At most `most` chunks are given theirs in a call, the nearest first; true when some
## were left for the next (update then calls again in the next frame, not a second later:
## after a teleport or a respawn some hundred chunks come at once, not in one frame).
func _settle_new(most := 1 << 30) -> bool:
	for key: Vector2i in _settled.keys():
		if not world.chunks.has(key):
			_settled.erase(key)
	var r := ceili(float(SPAWN_REACH) / WorldData.CHUNK)
	for who in people:
		var c := Vector2i(floori(who.position.x / CELL), floori(who.position.z / CELL)) / WorldData.CHUNK
		for ring in r + 1:
			for kz in range(c.y - ring, c.y + ring + 1):
				for kx in range(c.x - ring, c.x + ring + 1):
					if maxi(absi(kx - c.x), absi(kz - c.y)) != ring:
						continue
					var key := Vector2i(kx, kz)
					if not _settled.has(key) and _made(key):
						if most <= 0:
							return true
						most -= 1
						_populate_chunk(key)
	return false


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
## All at once here; update does it a kind or two a frame (_plan_refill, _refill_some),
## since one kind's tries at places can take milliseconds (4-5 ms on CI for the whole).
func _refill() -> void:
	_plan_refill()
	_refill_some(1 << 30)


## Notes what _refill_some is to do: for each of the people each kind the chunks around
## them hold a share of, with where.
func _plan_refill() -> void:
	_refills.clear()
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
			_refills.append([kind, shares[kind], around, cells])


## Does up to `most` of what _plan_refill noted: a kind short around one of the people
## gets new ones, one over loses some.
func _refill_some(most: int) -> void:
	while most > 0 and not _refills.is_empty():
		most -= 1
		var job: Array = _refills.pop_back()
		var kind: String = job[0]
		if not AiRules.SPECIES.has(kind):
			continue
		var around: Vector3 = job[2]
		var cells: Rect2i = job[3]
		var want: float = wanted(kind) * job[1]
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


## Takes out the animals no one looks at whose ground is no longer kept (forgotten far
## from the people, Session.DROP): they went with it, and come again with it.
func _leave() -> void:
	for a in animals.duplicate():
		if not a.near and a.owner < 0 and world.chunk_at(floori(a.pos.x / CELL), floori(a.pos.z / CELL)) == null:
			_remove(a)


## Takes up to `n` of `kind` within ROAM of `around` out of the world, those no one
## looks at (they hid away).
func _thin(kind: String, n: int, around: Vector3) -> void:
	for a in animals.duplicate():
		if n <= 0:
			return
		if a.kind == kind and not a.near and a.owner < 0 and _within(a.pos, around, ROAM):
			_remove(a)
			n -= 1


## A tamed animal safe from threats: it follows its owner (one of the people with its
## number), or wanders a little round where it was told to stay; with its owner not
## here it stays where it is.
func _keep_by_owner(a: Animal) -> void:
	a.state = "wander"
	a.cause = "owner"
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
