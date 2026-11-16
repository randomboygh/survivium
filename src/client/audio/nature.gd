extends RefCounted
## The sounds of the world around the player, always there (decision 89): the wind by
## its strength, rain, hail and the blizzard's whistle, thunder after the lightning,
## the water near (a river, a lake, the sea) from where it is, a burning campfire from
## where it is, birds in the trees by day and an owl at night, crickets on warm nights:
## a barely heard far chorus and now and then one or two near ones, each in its own spot in the grass with its own
## pitch, pace and loudness, singing a few seconds and resting long, hushed when the player comes up.
## Under a roof or in a cave the weather is heard muffled. The land around is looked
## over a row a frame (SCAN cells each way), never all at once. `game` is the Main node;
## Sound runs it each frame.

const Clock := preload("res://src/shared/game/clock.gd")
const Vibration := preload("res://src/client/ui/vibration.gd")
const ThunderShape := preload("res://src/client/audio/thunder_shape.gd")
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
## The most near crickets at once in summer (one in spring), often none; seconds between new counts.
const CRICKETS_MOST := 2
const CRICKETS_RECOUNT := Vector2(30.0, 90.0)
## Where a near cricket sits, world units from the player; one farther away is replaced,
## one nearer than HUSH falls silent for a while.
const CRICKET_NEAR := Vector2(5.0, 16.0)
const CRICKET_GONE := 20.0
const CRICKET_HUSH := 2.5
## Seconds a cricket sings, and rests between.
const CRICKET_BOUT := Vector2(2.0, 7.0)
const CRICKET_REST := Vector2(10.0, 45.0)
## Thunder nearer than this (0 far .. 1 near) rumbles in the phone; nearer than
## STRIKE_FELT a strong lightning is felt as it strikes (Vibration).
const THUNDER_FELT := 0.5
const STRIKE_FELT := 0.85
## How loud a thunder is, far and near (times the flash's strength), and one whose bolt
## is on the screen; the latter heard STRUCK_LEAD s before its peak.
const THUNDER_LOUD := Vector2(0.55, 0.85)
const STRUCK_LOUD := 1.0
const STRUCK_LEAD := 0.05
## While a peal roars the rain, hail and wind are held down to this (Sound.duck): far
## and near, and for a bolt on the screen; for this many seconds, then they come back.
const THUNDER_DUCK := Vector2(0.6, 0.4)
const STRUCK_DUCK := 0.3
const DUCK_SECONDS := 2.5
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
## The near crickets: {at, pitch, loud, period, next, until (the end of the song)}, and
## how many there are to be until the next count; seconds of this clock.
var _crickets: Array[Dictionary] = []
var _cricket_count := 0
var _recount := 0.0
var _time := 0.0


func _init(g) -> void:
	game = g
	rng.randomize()


func update(delta: float) -> void:
	var sound = game.sound
	var clock = game.clock
	_time += delta
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
	_near_crickets(sound, crickets, clock.season != Clock.SPRING, delta)
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


## The near crickets at `level` (0..1) for the next `ahead` seconds: their count changes
## now and then, each chirps at its own pace through a song and rests after it, and the
## chirps are laid out within the coming tick so the pace is not the tick's.
func _near_crickets(sound, level: float, summer: bool, ahead: float) -> void:
	if level < 0.05:
		_crickets.clear()
		_recount = 0.0
		return
	_recount -= ahead
	if _recount <= 0.0:
		_recount = rng.randf_range(CRICKETS_RECOUNT.x, CRICKETS_RECOUNT.y)
		var most := roundi((CRICKETS_MOST if summer else 1) * level)
		_cricket_count = rng.randi_range(0, most)
	while _crickets.size() > _cricket_count:
		_crickets.remove_at(rng.randi() % _crickets.size())
	while _crickets.size() < _cricket_count:
		_crickets.append(_new_cricket())
	var p: Vector3 = game.player.position
	for i in _crickets.size():
		var c := _crickets[i]
		var d: float = Vector2(c.at.x - p.x, c.at.z - p.z).length()
		if d > CRICKET_GONE:
			c = _new_cricket()
			_crickets[i] = c
		elif d < CRICKET_HUSH:
			c.next = maxf(c.next, _time + rng.randf_range(4.0, 10.0))
			c.until = maxf(c.until, c.next + 2.0)
			continue
		c.next = maxf(c.next, _time)
		while c.next < _time + ahead:
			if c.next > c.until:
				c.next += rng.randf_range(CRICKET_REST.x, CRICKET_REST.y)
				c.until = c.next + rng.randf_range(CRICKET_BOUT.x, CRICKET_BOUT.y)
				c.period = clampf(c.period * rng.randf_range(0.85, 1.15), 0.6, 1.8)
				continue
			sound.play_later(c.next - _time, "cricket", c.at, level * c.loud * rng.randf_range(0.75, 1.0),
				c.pitch, "Nature")
			c.next += c.period * rng.randf_range(0.9, 1.1)


## A cricket somewhere in the grass round the player, beginning its song in a while.
func _new_cricket() -> Dictionary:
	var start := _time + rng.randf_range(2.0, 20.0)
	return {"at": _around(CRICKET_NEAR.x, CRICKET_NEAR.y, 0.3), "pitch": rng.randf_range(0.85, 1.15),
		"loud": rng.randf_range(0.4, 1.0), "period": rng.randf_range(0.7, 1.6), "next": start,
		"until": start + rng.randf_range(CRICKET_BOUT.x, CRICKET_BOUT.y)}


## Thunder for a lightning flash of `strength` (0..1), late and quieter as it is far;
## `struck` when its bolt is on the screen: then it is heard at once and at its loudest,
## the peal started at its peak (ThunderShape.peak), so the flash, the roar and the
## strike felt in the phone come together.
func thunder(strength: float, struck := false) -> void:
	var muffle := MUFFLED if game.chunks.indoor else 1.0
	if struck:
		var count: int = game.sound.streams("thunder").size()
		var v := randi() % maxi(count, 1)
		var from := 0.0
		if count == ThunderShape.ENVELOPES.size():
			from = maxf(ThunderShape.peak(v) - STRUCK_LEAD, 0.0)
		var played: Dictionary = game.sound.play("thunder", Vector3.INF, muffle * STRUCK_LOUD, 1.0, "Nature", v, from)
		if not played.is_empty():
			game.sound.duck(STRUCK_DUCK, DUCK_SECONDS)
			Vibration.rumble(game, played, muffle, true)
		return
	var delay := rng.randf_range(THUNDER_DELAY.x, THUNDER_DELAY.y)
	var near := 1.0 - (delay - THUNDER_DELAY.x) / (THUNDER_DELAY.y - THUNDER_DELAY.x)
	# Felt as well: a near one rolls in the phone as it is heard (Vibration.rumble), and
	# the strike itself of a very near one; the rain is held down under it (_heard).
	var felt := muffle * strength * near if near > THUNDER_FELT else 0.0
	game.sound.play_later(delay, "thunder", Vector3.INF, muffle * strength * lerpf(THUNDER_LOUD.x, THUNDER_LOUD.y, near),
		lerpf(0.85, 1.0, near), "Nature", _heard.bind(felt, lerpf(THUNDER_DUCK.x, THUNDER_DUCK.y, near)))
	if near > STRIKE_FELT and strength > 0.7:
		Vibration.play(game, "strike", 0.0, muffle)


## A peal heard (see thunder): the weather held down under it to `duck`, and felt as
## strong as `felt` (0: not felt).
func _heard(played: Dictionary, felt: float, duck: float) -> void:
	game.sound.duck(duck, DUCK_SECONDS)
	if felt > 0.0:
		Vibration.rumble(game, played, felt)


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

