extends RefCounted
## What a strong wind does to the plants around a place (plan/design/time-seasons.md):
## it breaks branches off the trees, which lie on the ground under them, a little
## downwind, and knocks the ripe berries off the bushes. A tree gives no more branches
## than its hands can break off in a year, so after a storm the forest has firewood
## lying about. The rules of each are WorldActions (blow_branch, blow_berries); this
## picks which, one chunk of those around one of the places a tick (the players, each in
## turn), so a storm costs the same little every frame. The autumn wind's leaf fall is
## the Clock's (leaf_fall).

const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Chunks around the place each way that the wind works in.
const REACH := 2
## Seconds between two chunks.
const TICK := 0.25
## The wind (Clock.storm_wind) breaks and knocks from GALE, fully at FULL (a blizzard).
const GALE := 0.9
const FULL := 2.5
## In a full wind, how often a day a tree loses a branch and a ripe bush its berries.
const BRANCH_RATE := 4.0
const BERRY_RATE := 3.0
## A broken branch lands this many cells from the trunk at most, and this much downwind.
const BRANCH_SPREAD := 3.5
const DOWNWIND := 1.0

var world
var clock
var actions
var rng := RandomNumberGenerator.new()
var _clock := 0.0
## Which chunk of the square around the place comes next.
var _next := 0
## Which of the places comes next (see step_around).
var _who := 0
## Where the wind worked last, in world units; INF before it did.
var last_at := Vector3.INF


func _init(w, c, a) -> void:
	world = w
	clock = c
	actions = a
	rng.seed = 7177


## Runs the wind for `delta` seconds around world point `at`.
func step(delta: float, at: Vector3) -> void:
	step_around(delta, [at])


## Runs the wind for `delta` seconds around the world points `around` (the players),
## one of them a tick in turn; a tick does as much as the chunk waited for, so each
## chunk gets the same wind however many places there are.
func step_around(delta: float, around: Array) -> void:
	_clock += delta
	if _clock < TICK:
		return
	var waited := _clock
	_clock = 0.0
	var wind: float = clampf((clock.storm_wind - GALE) / (FULL - GALE), 0.0, 1.0)
	if wind <= 0.0 or around.is_empty():
		return
	var at: Vector3 = around[_who % around.size()]
	_who = (_who + 1) % around.size()
	if at == Vector3.INF:
		return
	last_at = at
	var side := 2 * REACH + 1
	var i := _next
	_next = (_next + 1) % (side * side)
	var key := WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)) + Vector2i(i % side - REACH, i / side - REACH)
	var c = world.chunks.get(key)
	if c == null or not c.final:
		return
	# Each chunk comes round once in side * side ticks of its place.
	var days: float = clock.days(waited * side * side * around.size()) * wind
	var dir: Vector2 = clock.wind_dir()
	for col: Vector2i in world.tree_chunks.get(key, {}).keys():
		if rng.randf() < BRANCH_RATE * days:
			_break_branch(col, dir)
	for cell: Vector3i in world.bushes_in(key.x << WorldData.SHIFT, key.y << WorldData.SHIFT):
		if rng.randf() < BERRY_RATE * days:
			actions.blow_berries(cell)


## Breaks a branch off the tree in `col`, to fall under it downwind of `dir`.
func _break_branch(col: Vector2i, dir: Vector2) -> void:
	var a := rng.randf() * TAU
	var off := Vector2(cos(a), sin(a)) * rng.randf_range(1.5, BRANCH_SPREAD) + dir * DOWNWIND
	var x := col.x + 0.5 + off.x
	var z := col.y + 0.5 + off.y
	var cx := floori(x)
	var cz := floori(z)
	# Not on a trunk, and not into open water.
	if world.log_col(cx, cz) != 0 or world.chunk_at(cx, cz) == null:
		return
	var y: int = world.surface_y(cx, cz)
	if y <= 0:
		return
	actions.blow_branch(col, Vector3(x, y, z) * CELL, rng.randf() * TAU)
