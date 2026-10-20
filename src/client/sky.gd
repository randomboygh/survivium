extends RefCounted
## Time of day, seasons and weather: the sun and the moon with its phases, the ambient
## light and the background, the colour grade, snow, wetness, the tints of leaves and
## grass, clouds, wind, fog and lightning. Everything the shaders need goes out as
## global shader parameters. `game` is the Main node that owns the scene.

const WorldGen := preload("res://src/shared/world_gen.gd")
const WorldData := preload("res://src/shared/world_data.gd")

const DAY_LENGTH := 240.0
const DAYS_PER_SEASON := 2.0
const SEASONS := ["Весна", "Лето", "Осень", "Зима"]
const WINTER := 3
const FOLIAGE := [Vector3(0.95, 1.1, 0.8), Vector3(1.0, 1.0, 1.0), Vector3(2.2, 1.05, 0.55), Vector3(1.3, 0.9, 0.7)]
const GRASS := [Vector3(0.95, 1.08, 0.85), Vector3(1.0, 1.0, 1.0), Vector3(1.1, 0.9, 0.66), Vector3(0.9, 0.85, 0.72)]
const LEAF_AMOUNT := [1.0, 1.0, 0.8, 0.55]
## Share of the berries ripe on bushes.
const BERRY_AMOUNT := [0.0, 1.0, 0.55, 0.0]
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

var game
var sun: DirectionalLight3D
var env: Environment

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
## Brightness of a lightning flash, 0 most of the time.
var flash := 0.0
var flash_clock := 6.0
## Moonlight 0 (new moon) .. 1 (full moon), and the playtest override (-1 = by phase).
var moon := 1.0
var moon_override := -1.0
## How bright the open sky is, 0 on a moonless night .. 1 by day; the torch and the
## weather particles follow it.
var sky_light := 1.0
## Biome under the player, checked now and then for the weather (deserts).
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
var snow := 0.0
var wet := 0.0
var foliage := Vector3.ONE
var grass := Vector3.ONE
var leaf_amount := 1.0
var berry_amount := 1.0
var clouds := 0.3
var cloud_pos := Vector2.ZERO
var wind_clock := 0.0
var daylight := 1.0


func _init(g) -> void:
	game = g


## Puts the environment and the sun into the scene.
func build(parent: Node3D) -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = game.view.CAMERA_HEIGHT + 20.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	parent.add_child(sun)


func update(delta: float) -> void:
	_update_time(delta)
	_update_weather(delta)


func _update_time(delta: float) -> void:
	var step := delta * time_speed / DAY_LENGTH
	time_of_day += step
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
	season_clock += step
	if season_clock >= DAYS_PER_SEASON:
		next_season()
	var h := -cos(time_of_day * TAU)
	daylight = clampf(h * 1.6 + 0.35, 0.0, 1.0)
	moon = moon_override if moon_override >= 0.0 else moon_phase_light(day + time_of_day)
	# Clouds hide the moon; snow on the ground gives its light back.
	var overcast := clampf((clouds - 0.3) / 0.6, 0.0, 1.0)
	var moonlight := moon * (1.0 - 0.75 * overcast) * (1.0 + 0.5 * snow)
	# Low warm light near sunrise and sunset, full light at midday.
	var golden := clampf(1.0 - absf(h) * 3.0, 0.0, 1.0) if h > -0.25 else 0.0
	# The sun and the moon fade out towards the horizon, so the light swaps from one
	# to the other while neither shines and the shadows never jump; the long shadows
	# of a low sun come in faint and grow with the light.
	var rise := smoothstep(0.0, 0.3, absf(h))
	if h > 0.0:
		# The sun crosses the southern sky from east to west, a little off south at
		# noon so shadows fall to the side and stay visible.
		_aim_sun((time_of_day - 0.5) * 180.0 - 25.0, lerpf(14.0, 55.0, h))
		sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.38), golden)
		sun.light_energy = 0.85 * rise
	else:
		_aim_sun((fmod(time_of_day + 0.5, 1.0) - 0.5) * 180.0 - 25.0, lerpf(14.0, 50.0, -h))
		sun.light_color = Color(0.6, 0.7, 1.0)
		sun.light_energy = 0.35 * rise * minf(moonlight, 1.0)
	var night := 1.0 - daylight
	# A moonless night is black but for what fires and the torch light.
	var night_ambient := Color(0.14, 0.15, 0.22).lerp(Color(0.16, 0.2, 0.36), minf(moonlight, 1.0))
	var night_energy := lerpf(0.85, 0.9, minf(moonlight, 1.0))
	env.ambient_light_color = Color(0.55, 0.62, 0.78).lerp(Color(0.6, 0.5, 0.6), golden).lerp(night_ambient, night)
	env.ambient_light_energy = lerpf(0.45, night_energy, night) + flash * 1.5
	env.background_color = Color(0.2, 0.32, 0.38).lerp(Color(0.04, 0.06, 0.12).lerp(Color(0.01, 0.012, 0.02), 1.0 - minf(moonlight, 1.0)), night)
	sky_light = clampf(daylight + 0.45 * moonlight * night, 0.0, 1.0) * (1.0 - 0.35 * overcast)
	# Levels far below the player fade into the background outdoors and into darkness
	# under a roof (see depth_fade in common.gdshaderinc).
	var cut_on: bool = game.chunks.cut_level < game.world.size_y
	var haze := (Color(0.02, 0.02, 0.03) if cut_on else env.background_color).srgb_to_linear()
	RenderingServer.global_shader_parameter_set("depth_haze", Vector3(haze.r, haze.g, haze.b))
	game.creatures.daylight = daylight
	if game.player != null:
		var dark := 1.0 if game.chunks.indoor else clampf((0.55 - sky_light) * 4.0, 0.0, 1.0)
		game.player.torch.light_energy = 1.3 * dark
	_update_grade(golden, night, minf(moonlight, 1.0))


## Moonlight (0..1) on day `t` of the game: full every MOON_DAYS days, dark for a few
## nights around the new moon.
static func moon_phase_light(t: float) -> float:
	var phase := fposmod(t / MOON_DAYS + MOON_START, 1.0)
	return smoothstep(-0.5, 0.7, cos(phase * TAU))


## Points the sun (or the moon) from `azimuth` degrees (0 = south, negative = east)
## at `elevation` degrees above the horizon.
func _aim_sun(azimuth: float, elevation: float) -> void:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	var to_sun := Vector3(-sin(az) * cos(el), sin(el), cos(az) * cos(el))
	sun.global_transform.basis = Basis.looking_at(-to_sun, Vector3.UP)


## The colour grade sets the mood: warm at sunrise and sunset, blue and muted under
## the moon, near black and colourless without it, grey in rain, cool in winter. Fog,
## blizzards and sand storms lay a drifting haze over the picture.
func _update_grade(golden: float, night: float, moonlight: float) -> void:
	var tint := Vector3(1.02, 1.0, 0.97).lerp(Vector3(1.08, 0.97, 0.88), golden).lerp(Vector3(0.82, 0.92, 1.15), night)
	var saturation := lerpf(lerpf(0.92, 1.05, golden), lerpf(0.45, 0.6, moonlight), night)
	var exposure := lerpf(1.0, lerpf(1.0, 1.15, moonlight), night)
	var contrast := 1.06
	var wet_k := clampf(rain + snowing * 0.6 + hail, 0.0, 1.0)
	var rain_k := maxf(wet, wet_k) if season != WINTER else wet_k
	saturation *= 1.0 - 0.3 * rain_k
	tint *= Vector3.ONE.lerp(Vector3(0.95, 0.98, 1.03), rain_k)
	exposure *= 1.0 - 0.08 * rain_k - 0.08 * clampf(rain - 0.5, 0.0, 0.5)
	if season == WINTER:
		tint *= Vector3(0.97, 1.0, 1.04)
	exposure += flash * 1.2
	var indoor_k := 0.25 if game.chunks.indoor else 1.0
	# Haze: grey fog, white blizzard, ochre sand; as dark as the sky around it.
	var haze_col := Vector3(0.62, 0.66, 0.7)
	var white := clampf(snowing * 2.0 - 1.0, 0.0, 1.0)
	haze_col = haze_col.lerp(Vector3(0.88, 0.9, 0.94), white).lerp(Vector3(0.78, 0.6, 0.38), sand)
	haze_col *= lerpf(0.12, 1.0, sky_light)
	var haze_amount := clampf(fog + sand * 0.2, 0.0, 0.85) * indoor_k
	var grade_mat: ShaderMaterial = game.view.grade_mat
	grade_mat.set_shader_parameter("tint", Color(tint.x, tint.y, tint.z))
	grade_mat.set_shader_parameter("saturation", saturation * (1.0 - 0.3 * sand))
	grade_mat.set_shader_parameter("exposure", exposure)
	grade_mat.set_shader_parameter("contrast", contrast)
	grade_mat.set_shader_parameter("keep_highlights", lerpf(0.0, 0.8, night))
	var deep := Color(0.02, 0.03, 0.09).lerp(Color(0.006, 0.01, 0.022), 1.0 - moonlight)
	grade_mat.set_shader_parameter("shadow_tint", Color(0.0, 0.01, 0.04).lerp(deep, night))
	grade_mat.set_shader_parameter("haze_color", Color(haze_col.x, haze_col.y, haze_col.z))
	grade_mat.set_shader_parameter("haze_amount", haze_amount)
	# Fog lies in banks; a storm is thick everywhere and streams with the wind.
	grade_mat.set_shader_parameter("haze_patchy", lerpf(0.7, 0.3, maxf(sand, white)))
	grade_mat.set_shader_parameter("haze_offset", cloud_pos * Vector2(1.5, 0.6) * (1.0 + 3.0 * storm_wind))


func next_season() -> void:
	season = (season + 1) % 4
	season_clock = 0.0
	print("season: %s" % SEASONS[season])
	game.hud.toast("Наступила %s" % SEASONS[season].to_lower() if season != 1 else "Наступило лето")


## Name of the HUD icon for the sky now: the weather, or the moon by its phase at
## night when the sky is clear.
func icon() -> String:
	var w: Dictionary = WEATHERS[weather]
	var name: String = w.icon
	if name == "rain" and season == WINTER or name == "hail" and season == WINTER:
		return "snow"
	if name != "sun":
		return name
	if daylight > 0.35:
		return "sun"
	return "moon_full" if moon > 0.7 else ("moon" if moon > 0.2 else "moon_new")


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
	clouds = w.clouds


## Picks the next weather by the season and the biome under the player.
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


func _update_weather(delta: float) -> void:
	var winter := season == WINTER
	if game.player != null:
		biome_clock -= delta
		if biome_clock <= 0.0:
			biome_clock = 5.0
			var p: Vector3 = game.player.position / WorldData.CELL
			biome = game.gen.lay_out(floori(p.x), floori(p.z), 1, 1).biome[0]
	if weather_auto:
		weather_left -= delta * time_speed / DAY_LENGTH
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
	_update_lightning(delta, w.get("lightning", 0.0) > 0.0 and not winter)
	if winter or snowing > 0.3:
		snow = move_toward(snow, 1.0, delta * (0.02 + 0.06 * snowing))
	else:
		snow = move_toward(snow, 0.0, delta * 0.03)
	wet = move_toward(wet, 1.0 if rain > 0.2 else 0.0, delta * (0.15 * rain if rain > 0.2 else 0.03))
	var k2 := minf(1.0, delta * 0.4)
	foliage = foliage.lerp(FOLIAGE[season], k2)
	grass = grass.lerp(GRASS[season], k2)
	leaf_amount = lerpf(leaf_amount, LEAF_AMOUNT[season], k2)
	berry_amount = lerpf(berry_amount, BERRY_AMOUNT[season], k2)
	clouds = lerpf(clouds, w.clouds, minf(1.0, delta * 0.3))
	wind_clock += delta
	var gust := 0.25 + 0.25 * sin(wind_clock * 0.35) + 0.15 * sin(wind_clock * 1.3)
	var wind := Vector2(gust * (1.0 + storm_wind * 0.5) + storm_wind, 0.15)
	cloud_pos += Vector2(-0.6, -0.25) * delta * (1.0 + wind.x)
	var g := RenderingServer
	g.global_shader_parameter_set("snow_amount", snow)
	g.global_shader_parameter_set("wetness", wet)
	g.global_shader_parameter_set("foliage_tint", foliage)
	g.global_shader_parameter_set("grass_tint", grass)
	g.global_shader_parameter_set("leaf_amount", leaf_amount)
	g.global_shader_parameter_set("berry_amount", berry_amount)
	g.global_shader_parameter_set("cloud_cover", clouds)
	g.global_shader_parameter_set("cloud_offset", cloud_pos)
	g.global_shader_parameter_set("wind", wind)
	var ice := clampf((snow - 0.3) / 0.5, 0.0, 1.0)
	game.water_mat.set_shader_parameter("ice_amount", ice)
	game.world.water_frozen = ice > 0.8
	if game.player != null:
		game.effects.update(delta, game.view.cam_target, game.player.position.y, self, game.chunks.indoor)
	if game.tracks != null:
		game.tracks.snow = snow
		game.tracks.wet = wet
	if game.drifts_root != null:
		game.drifts_root.visible = snow > 0.6


## Lightning in a storm: every few seconds a flash, sometimes twice, and a bolt
## striking somewhere on the screen.
func _update_lightning(delta: float, on: bool) -> void:
	flash = move_toward(flash, 0.0, delta * 5.0)
	flash_clock -= delta
	if flash_clock > 0.0:
		return
	if not on:
		flash_clock = 1.0
		return
	flash_clock = rng.randf_range(3.0, 11.0)
	# A quick second flicker now and then.
	if rng.randf() < 0.4:
		flash_clock = rng.randf_range(0.12, 0.25)
	flash = rng.randf_range(0.6, 1.0)
	if game.player != null and not game.chunks.indoor and rng.randf() < 0.7:
		game.effects.strike(game.view.cam_target, game.player.position.y, flash)
