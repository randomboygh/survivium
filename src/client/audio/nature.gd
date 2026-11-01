extends RefCounted
## The sounds of the world around the player, always there (decision 89): the wind by
## its strength, rain, hail and the blizzard's whistle, thunder after the lightning,
## the water near (a river, a lake, the sea) from where it is, a burning campfire from
## where it is, birds in the trees by day and an owl at night, crickets on warm nights.
## Under a roof or in a cave the weather is heard muffled. The land around is looked
## over a row a frame (SCAN cells each way), never all at once. `game` is the Main node;
## Sound runs it each frame.

const Clock := preload("res://src/shared/game/clock.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## How far round the player the land is looked over for water and trees, in cells, and
## every how many cells.
const SCAN := 28
const SCAN_STEP := 2
## How much of the weather comes through a roof.
const MUFFLED := 0.3
## Water columns in the scan that make the water as loud as it gets.
const WATER_FULL := 40.0
## How often a bird sings, a second, in the woods and in the open; at dawn more.
const BIRDS_WOODS := 0.5
const BIRDS_OPEN := 0.08
const DAWN_CHORUS := 2.0
## An owl, a second, at night in the woods.
const OWL_RATE := 0.025
## Seconds from a lightning flash to its thunder: near and far.
const THUNDER_DELAY := Vector2(0.4, 3.0)

var game
var rng := RandomNumberGenerator.new()
## The scan: the row looked over next, and what the rows so far found.
var _row := -SCAN
var _water := 0
var _water_at := Vector3.ZERO
var _water_weight := 0.0
var _leaves := 0
var _columns := 0
## What the last whole scan found: water columns and where they are, the share of the
## columns under crowns.
var water := 0.0
var water_at := Vector3.INF
var woods := 0.0
## World units from the player to the nearest burning campfire (INF for none), as the last
## tick found it; the music reads it too.
var fire_d := INF


func _init(g) -> void:
	game = g
	rng.randomize()


func update(delta: float) -> void:
	var sound = game.sound
	var clock = game.clock
	_scan()
	var indoor: bool = game.chunks.indoor
	var open := MUFFLED if indoor else 1.0
	var winter: bool = clock.season == Clock.WINTER
	var wind: float = clock.storm_wind
	# The wind is always a little there, and roars in a storm.
	sound.loop("wind", open * clampf(0.12 + 0.3 * wind, 0.0, 1.0))
	sound.loop("rain", open * (0.0 if winter else clampf(clock.rain, 0.0, 1.0)))
	sound.loop("hail", open * clampf(clock.hail, 0.0, 1.0))
	sound.loop("blizzard", open * clampf(maxf(clock.snowing, clock.sand * 0.6) * (wind - 0.8) / 1.7, 0.0, 1.0))
	# Water heard from where most of it is; ice and snow on it keep it quiet.
	var w := clampf(water / WATER_FULL, 0.0, 1.0)
	if w > 0.0:
		w = maxf(w, 0.3) * (1.0 - clock.ice())
	if game.player.body.water_depth > 0.0:
		w = maxf(w, 0.6)
	sound.spot("water", water_at, w)
	_fire(sound)
	var daylight: float = clock.daylight()
	# Spring and summer.
	var warm: bool = clock.season < Clock.AUTUMN
	var calm: bool = clock.rain < 0.2 and clock.snowing < 0.2 and wind < 1.2
	var crickets := 0.0
	if warm and calm and not indoor and daylight < 0.3:
		crickets = (1.0 - woods * 0.5) * smoothstep(0.3, 0.05, daylight)
	sound.loop("crickets", crickets)
	if indoor or not calm:
		return
	# Birds by day, most at dawn and fewest in winter; an owl in the woods at night.
	if daylight > 0.4:
		var rate := lerpf(BIRDS_OPEN, BIRDS_WOODS, woods) * (0.3 if winter else 1.0)
		var dawn: float = absf(clock.sun_time() - 0.27)
		if dawn < 0.06:
			rate *= DAWN_CHORUS
		if rng.randf() < rate * delta:
			sound.play("bird", _around(6.0, 16.0, 2.0), rng.randf_range(0.5, 1.0), rng.randf_range(0.9, 1.15), "Nature")
	elif daylight < 0.15 and woods > 0.15 and rng.randf() < OWL_RATE * delta:
		sound.play("owl", _around(10.0, 18.0, 3.0), rng.randf_range(0.6, 1.0), 1.0, "Nature")


## Thunder for a lightning flash of `strength` (0..1), late as it is far.
func thunder(strength: float) -> void:
	var delay := rng.randf_range(THUNDER_DELAY.x, THUNDER_DELAY.y)
	var near := 1.0 - (delay - THUNDER_DELAY.x) / (THUNDER_DELAY.y - THUNDER_DELAY.x)
	var muffle := MUFFLED if game.chunks.indoor else 1.0
	game.sound.play_later(delay, "thunder", Vector3.INF, muffle * strength * lerpf(0.5, 1.0, near),
		lerpf(0.85, 1.0, near), "Nature")


## The nearest burning campfire crackles from where it is.
func _fire(sound) -> void:
	var p: Vector3 = game.player.position
	var best := Vector3.INF
	var best_d := INF
	for e in game.placed.things:
		if not e.lit or not Placed.is_fire(e):
			continue
		var at := Placed.center(e)
		var d := at.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = at
	fire_d = sqrt(best_d)
	sound.spot("fire", best, 1.0 if best_d <= sound.HEAR_RANGE * sound.HEAR_RANGE else 0.0)


## A point round the player `near`..`far` world units away, `up` above.
func _around(near: float, far: float, up: float) -> Vector3:
	var a := rng.randf() * TAU
	var d := rng.randf_range(near, far)
	return game.player.position + Vector3(cos(a) * d, up, sin(a) * d)


## Looks over a row of the land round the player for water and crowns; at the last row
## the counts are kept and a new scan begins.
func _scan() -> void:
	var world = game.world
	var p: Vector3 = game.player.position
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	var z := cz + _row
	for dx in range(-SCAN, SCAN + 1, SCAN_STEP):
		var x := cx + dx
		_columns += 1
		if world.water_col(x, z) != 0:
			_water += 1
			var near := 1.0 / (1.0 + float(dx * dx + _row * _row))
			_water_at += Vector3(x + 0.5, 0.0, z + 0.5) * CELL * near
			_water_weight += near
		if world.leaf_col(x, z) != 0:
			_leaves += 1
	_row += SCAN_STEP
	if _row <= SCAN:
		return
	water = _water
	water_at = Vector3.INF if _water_weight <= 0.0 else _water_at / _water_weight
	if water_at.is_finite():
		water_at.y = p.y
	woods = float(_leaves) / maxf(_columns, 1.0)
	_row = -SCAN
	_water = 0
	_water_at = Vector3.ZERO
	_water_weight = 0.0
	_leaves = 0
	_columns = 0

