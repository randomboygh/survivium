extends RefCounted
## The world's time and weather: the time of day, days and seasons, the phases of the
## moon, and the weather that comes by the season and the land (deserts have sand
## storms), with how hard it rains, snows, hails and blows now, the snow lying on the
## ground and how wet it is; water freezes under deep snow. The wind blows from a side
## that turns with each change of weather, and in autumn it strips the leaves off the
## trees. The client draws all this (Sky: the light, the colour grade, the clouds and
## the shaders' tints).

const WorldGen := preload("res://src/shared/world/world_gen.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const DAY_LENGTH := 240.0
const DAYS_PER_SEASON := 2.0
const SEASONS := ["Весна", "Лето", "Осень", "Зима"]
const SPRING := 0
const AUTUMN := 2
const WINTER := 3
## Days from one full moon to the next. The first night of a world is a bright one.
const MOON_DAYS := 8.0
const MOON_START := 0.75

## Kinds of weather, what each brings and how often it comes in each season (spring,
## summer, autumn, winter). Strengths are 0..1: clouds is the share of the sky under
## clouds, rain and snow how hard it falls (in winter rain and hail fall as snow),
## sand blows in deserts only, fog is the haze over everything, wind adds to the gusts
## and lightning strikes now and then.
const WEATHERS := [
	{"id": "clear", "name": "Ясно", "icon": "sun", "clouds": 0.28, "chance": [4, 6, 3, 3]},
	{"id": "cloudy", "name": "Пасмурно", "icon": "cloud", "clouds": 0.75, "wind": 0.3, "chance": [3, 2, 3, 3]},
	{"id": "fog", "name": "Туман", "icon": "fog", "clouds": 0.5, "fog": 0.75, "chance": [2, 0.5, 3, 1]},
	{"id": "rain", "name": "Дождь", "icon": "rain", "clouds": 0.8, "rain": 0.5, "wind": 0.8, "chance": [3, 2, 3, 0]},
	{"id": "downpour", "name": "Ливень", "icon": "rain", "clouds": 0.95, "rain": 1.0, "wind": 1.2, "fog": 0.3, "chance": [1, 1, 1.5, 0]},
	{"id": "storm", "name": "Гроза", "icon": "storm", "clouds": 0.95, "rain": 0.9, "wind": 1.8, "fog": 0.2, "lightning": 1.0, "chance": [1, 1.5, 0.5, 0]},
	{"id": "hail", "name": "Град", "icon": "hail", "clouds": 0.85, "rain": 0.3, "hail": 1.0, "wind": 1.0, "chance": [0.5, 0.5, 0.3, 0]},
	{"id": "snow", "name": "Снегопад", "icon": "snow", "clouds": 0.8, "snow": 0.6, "wind": 0.4, "chance": [0, 0, 0, 4]},
	{"id": "blizzard", "name": "Метель", "icon": "snow", "clouds": 0.95, "snow": 1.0, "wind": 2.5, "fog": 0.55, "chance": [0, 0, 0, 1.5]},
	{"id": "sandstorm", "name": "Песчаная буря", "icon": "sand", "clouds": 0.4, "sand": 1.0, "wind": 2.5, "fog": 0.5, "chance": [0, 0, 0, 0]},
]
const CLEAR := 0
const RAIN := 3
## In a desert the precipitation turns into sand storms that often.
const DESERT_SAND_CHANCE := 2.0
## How long one weather lasts, in days of the game.
const WEATHER_DAYS := Vector2(0.15, 0.5)
## The wind mostly blows east (angle 0, x east, y south): a new weather turns it by a
## random angle about that, this spread (radians), and it turns towards it this fast
## (radians a second).
const WIND_SPREAD := 0.9
const WIND_TURN := 0.05
## In autumn wind above LEAF_WIND strips the leaves: this share of them a day for each
## unit of wind above it (a storm takes about half in a third of a day).
const LEAF_WIND := 0.6
const LEAF_FALL_RATE := 1.4

## A new season began (see next_season).
signal season_changed(season: int)

## The world whose water freezes in winter.
var world
## The generator, for the land under the place the weather is felt (see step).
var gen

var time_of_day := 0.3
var day := 1
var time_speed := 1.0
var season := 1
var season_clock := 0.0
## Index in WEATHERS of the weather now.
var weather := CLEAR
## The weather changes by itself; the playtest page can pin one.
var weather_auto := true
## Days of the game until the weather changes.
var weather_left := 0.3
## Strengths of the weather now, moving smoothly towards what `weather` brings.
var rain := 0.0
var snowing := 0.0
var hail := 0.0
var sand := 0.0
var fog := 0.0
var storm_wind := 0.0
## Where the wind blows to (radians, 0 east, PI / 2 south), and where it turns to.
var wind_angle := 0.0
var wind_to := 0.0
## Share of the leaves the autumn wind has taken off the trees this year, 0..1 (see
## LEAF_FALL_RATE); spring grows them back.
var leaf_fall := 0.0
## The share of the sky under clouds, moving towards what the weather brings.
var clouds := 0.3
## Snow lying on the ground and how wet it is, 0..1.
var snow := 0.0
var wet := 0.0
## Biome under the place the weather is felt, checked now and then (deserts).
var biome := -1
var biome_clock := 0.0
var rng := RandomNumberGenerator.new()
## Precipitation of any kind is falling (rain, snow, hail). Setting it is the old
## playtest switch: rain or clear.
var raining: bool:
	get:
		var w: Dictionary = WEATHERS[weather]
		return w.get("rain", 0.0) > 0.0 or w.get("snow", 0.0) > 0.0 or w.get("hail", 0.0) > 0.0
	set(on):
		weather = RAIN if on else CLEAR


## Runs time and weather for `delta` seconds; the weather is the one felt at world
## point `at` (the player's place on the client).
func step(delta: float, at := Vector3.INF) -> void:
	_pass_time(delta)
	_change_weather(delta, at)


## The days of the game `delta` seconds of play make.
func days(delta: float) -> float:
	return delta * time_speed / DAY_LENGTH


func _pass_time(delta: float) -> void:
	var d := days(delta)
	time_of_day += d
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	season_clock += d
	if season_clock >= DAYS_PER_SEASON:
		next_season()


## How much of the day's light there is now, 0 at night and 1 by day (dawn and dusk
## between).
func daylight() -> float:
	return clampf(-cos(time_of_day * TAU) * 1.6 + 0.35, 0.0, 1.0)


## Moonlight (0..1) on day `t` of the game: full every MOON_DAYS days, dark for a few
## nights around the new moon.
static func moon_phase_light(t: float) -> float:
	var phase := fposmod(t / MOON_DAYS + MOON_START, 1.0)
	return smoothstep(-0.5, 0.7, cos(phase * TAU))


## The time in days of the game since the world began.
func now() -> float:
	return day + time_of_day


## Where the wind blows to, as a unit vector (x east, y south).
func wind_dir() -> Vector2:
	return Vector2(cos(wind_angle), sin(wind_angle))


func next_season() -> void:
	season = (season + 1) % 4
	season_clock = 0.0
	if season == SPRING:
		leaf_fall = 0.0
	season_changed.emit(season)


## The name of the weather's icon: rain and hail fall as snow in winter.
func weather_icon() -> String:
	var name: String = WEATHERS[weather].icon
	if season == WINTER and (name == "rain" or name == "hail"):
		return "snow"
	return name


## Pins the weather (`auto` lets it change by itself again from `index`).
func set_weather(index: int, auto := false) -> void:
	weather = clampi(index, 0, WEATHERS.size() - 1)
	weather_auto = auto
	weather_left = rng.randf_range(WEATHER_DAYS.x, WEATHER_DAYS.y)


## Jumps the weather strengths to what the weather brings (tools, screenshots).
func settle_weather() -> void:
	var w: Dictionary = WEATHERS[weather]
	var winter := season == WINTER
	rain = 0.0 if winter else w.get("rain", 0.0)
	hail = 0.0 if winter else w.get("hail", 0.0)
	snowing = maxf(w.get("snow", 0.0), maxf(w.get("rain", 0.0), w.get("hail", 0.0)) if winter else 0.0)
	sand = w.get("sand", 0.0)
	fog = w.get("fog", 0.0)
	storm_wind = w.get("wind", 0.0)
	wind_angle = wind_to
	clouds = w.clouds


## Picks the next weather by the season and the biome.
func _next_weather() -> void:
	var weights := PackedFloat32Array()
	var total := 0.0
	var desert := biome == WorldGen.DESERT
	for w: Dictionary in WEATHERS:
		var c: float = w.chance[season]
		if desert:
			# Deserts are dry: no rain or snow, sand storms instead.
			if w.has("rain") or w.has("snow") or w.has("hail") or w.id == "fog":
				c = 0.0
			elif w.id == "sandstorm":
				c = DESERT_SAND_CHANCE
		weights.append(c)
		total += c
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			weather = i
			break
	weather_left = rng.randf_range(WEATHER_DAYS.x, WEATHER_DAYS.y)
	wind_to = clampf(rng.randfn(0.0, WIND_SPREAD), -PI, PI)


func _change_weather(delta: float, at: Vector3) -> void:
	var winter := season == WINTER
	if at != Vector3.INF:
		biome_clock -= delta
		if biome_clock <= 0.0:
			biome_clock = 5.0
			biome = gen.lay_out(floori(at.x / WorldData.CELL), floori(at.z / WorldData.CELL), 1, 1).biome[0]
	if weather_auto:
		weather_left -= days(delta)
		if weather_left <= 0.0:
			_next_weather()
	var w: Dictionary = WEATHERS[weather]
	var falls: float = w.get("rain", 0.0)
	var flakes: float = w.get("snow", 0.0)
	var stones: float = w.get("hail", 0.0)
	if winter:
		# Winter turns rain and hail into snow.
		flakes = maxf(flakes, maxf(falls, stones))
		falls = 0.0
		stones = 0.0
	var k := minf(1.0, delta * 0.25)
	rain = lerpf(rain, falls, k)
	snowing = lerpf(snowing, flakes, k)
	hail = lerpf(hail, stones, k)
	sand = lerpf(sand, w.get("sand", 0.0), k)
	fog = lerpf(fog, w.get("fog", 0.0), k)
	storm_wind = lerpf(storm_wind, w.get("wind", 0.0), k)
	clouds = lerpf(clouds, w.clouds, minf(1.0, delta * 0.3))
	wind_angle = move_toward(wind_angle, wind_to, WIND_TURN * delta)
	if season == AUTUMN and storm_wind > LEAF_WIND:
		leaf_fall = minf(1.0, leaf_fall + days(delta) * LEAF_FALL_RATE * (storm_wind - LEAF_WIND))
	if winter or snowing > 0.3:
		snow = move_toward(snow, 1.0, delta * (0.02 + 0.06 * snowing))
	else:
		snow = move_toward(snow, 0.0, delta * 0.03)
	wet = move_toward(wet, 1.0 if rain > 0.2 else 0.0, delta * (0.15 * rain if rain > 0.2 else 0.03))
	world.water_frozen = ice() > 0.8


## The time of the clock as plain data for the save.
func to_dict() -> Dictionary:
	return {"day": day, "time": time_of_day, "season": season, "season_clock": season_clock, "leaf_fall": leaf_fall}


## Puts back the time of a save (see to_dict).
func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", day))
	time_of_day = fposmod(d.get("time", time_of_day), 1.0)
	season = posmod(int(d.get("season", season)), 4)
	season_clock = d.get("season_clock", season_clock)
	leaf_fall = clampf(d.get("leaf_fall", 0.0), 0.0, 1.0)


## How much of the water is ice, 0..1, by the snow lying.
func ice() -> float:
	return clampf((snow - 0.3) / 0.5, 0.0, 1.0)
