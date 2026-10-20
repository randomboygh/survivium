extends RefCounted
## Time of day, seasons and weather: the sun and the moon, the ambient light and the
## background, the colour grade, snow, wetness, the tints of leaves and grass, clouds
## and wind. Everything the shaders need goes out as global shader parameters.
## `game` is the Main node that owns the scene.

const DAY_LENGTH := 240.0
const DAYS_PER_SEASON := 2.0
const SEASONS := ["Весна", "Лето", "Осень", "Зима"]
const WINTER := 3
const FOLIAGE := [Vector3(0.95, 1.1, 0.8), Vector3(1.0, 1.0, 1.0), Vector3(2.2, 1.05, 0.55), Vector3(1.3, 0.9, 0.7)]
const GRASS := [Vector3(0.95, 1.08, 0.85), Vector3(1.0, 1.0, 1.0), Vector3(1.1, 0.9, 0.66), Vector3(0.9, 0.85, 0.72)]
const LEAF_AMOUNT := [1.0, 1.0, 0.8, 0.55]
## Share of the berries ripe on bushes.
const BERRY_AMOUNT := [0.0, 1.0, 0.55, 0.0]

var game
var sun: DirectionalLight3D
var env: Environment

var time_of_day := 0.3
var day := 1
var time_speed := 1.0
var season := 1
var season_clock := 0.0
var raining := false
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
	# Low warm light near sunrise and sunset, full light at midday.
	var golden := clampf(1.0 - absf(h) * 3.0, 0.0, 1.0) if h > -0.25 else 0.0
	if h > 0.0:
		# The sun crosses the southern sky from east to west, a little off south at
		# noon so shadows fall to the side and stay visible.
		_aim_sun((time_of_day - 0.5) * 180.0 - 25.0, lerpf(12.0, 55.0, h))
		sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.38), golden)
		sun.light_energy = lerpf(0.25, 0.85, clampf(h * 4.0, 0.0, 1.0))
	else:
		_aim_sun((fmod(time_of_day + 0.5, 1.0) - 0.5) * 180.0 - 25.0, lerpf(12.0, 50.0, -h))
		sun.light_color = Color(0.6, 0.7, 1.0)
		sun.light_energy = lerpf(0.05, 0.35, clampf(-h * 4.0, 0.0, 1.0))
	var night := 1.0 - daylight
	env.ambient_light_color = Color(0.55, 0.62, 0.78).lerp(Color(0.6, 0.5, 0.6), golden).lerp(Color(0.16, 0.2, 0.36), night)
	env.ambient_light_energy = lerpf(0.45, 0.9, night)
	env.background_color = Color(0.2, 0.32, 0.38).lerp(Color(0.04, 0.06, 0.12), night)
	# Levels far below the player fade into the background outdoors and into darkness
	# under a roof (see depth_fade in common.gdshaderinc).
	var cut_on: bool = game.chunks.cut_level < game.world.size_y
	var haze := (Color(0.02, 0.02, 0.03) if cut_on else env.background_color).srgb_to_linear()
	RenderingServer.global_shader_parameter_set("depth_haze", Vector3(haze.r, haze.g, haze.b))
	game.creatures.daylight = daylight
	if game.player != null:
		game.player.torch.light_energy = 1.1 if game.chunks.indoor else 1.1 * clampf(night * 2.5 - 1.5, 0.0, 1.0)
	_update_grade(golden, night)


## Points the sun (or the moon) from `azimuth` degrees (0 = south, negative = east)
## at `elevation` degrees above the horizon.
func _aim_sun(azimuth: float, elevation: float) -> void:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	var to_sun := Vector3(-sin(az) * cos(el), sin(el), cos(az) * cos(el))
	sun.global_transform.basis = Basis.looking_at(-to_sun, Vector3.UP)


## The colour grade sets the mood: warm at sunrise and sunset, blue and muted at
## night, grey in rain, cool in winter.
func _update_grade(golden: float, night: float) -> void:
	var tint := Vector3(1.02, 1.0, 0.97).lerp(Vector3(1.08, 0.97, 0.88), golden).lerp(Vector3(0.82, 0.92, 1.15), night)
	var saturation := lerpf(lerpf(0.92, 1.05, golden), 0.6, night)
	var exposure := lerpf(1.0, 1.15, night)
	var contrast := 1.06
	var rain_k := wet if season != WINTER else (0.6 if raining else 0.0)
	saturation *= 1.0 - 0.3 * rain_k
	tint *= Vector3.ONE.lerp(Vector3(0.95, 0.98, 1.03), rain_k)
	exposure *= 1.0 - 0.08 * rain_k
	if season == WINTER:
		tint *= Vector3(0.97, 1.0, 1.04)
	var grade_mat: ShaderMaterial = game.view.grade_mat
	grade_mat.set_shader_parameter("tint", Color(tint.x, tint.y, tint.z))
	grade_mat.set_shader_parameter("saturation", saturation)
	grade_mat.set_shader_parameter("exposure", exposure)
	grade_mat.set_shader_parameter("contrast", contrast)
	grade_mat.set_shader_parameter("keep_highlights", lerpf(0.0, 0.8, night))
	grade_mat.set_shader_parameter("shadow_tint", Color(0.0, 0.01, 0.04).lerp(Color(0.02, 0.03, 0.09), night))


func next_season() -> void:
	season = (season + 1) % 4
	season_clock = 0.0
	print("season: %s" % SEASONS[season])
	game.hud.toast("Наступила %s" % SEASONS[season].to_lower() if season != 1 else "Наступило лето")


func _update_weather(delta: float) -> void:
	var winter := season == WINTER
	if winter:
		snow = move_toward(snow, 1.0, delta * (0.06 if raining else 0.02))
	else:
		snow = move_toward(snow, 0.0, delta * 0.03)
	wet = move_toward(wet, 1.0 if raining and not winter else 0.0, delta * (0.15 if raining else 0.03))
	var k := minf(1.0, delta * 0.4)
	foliage = foliage.lerp(FOLIAGE[season], k)
	grass = grass.lerp(GRASS[season], k)
	leaf_amount = lerpf(leaf_amount, LEAF_AMOUNT[season], k)
	berry_amount = lerpf(berry_amount, BERRY_AMOUNT[season], k)
	clouds = lerpf(clouds, 0.8 if raining else 0.28, minf(1.0, delta * 0.3))
	wind_clock += delta
	var gust := 0.25 + 0.25 * sin(wind_clock * 0.35) + 0.15 * sin(wind_clock * 1.3)
	var wind := Vector2(gust + (0.8 if raining else 0.0), 0.15)
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
		game.effects.update(delta, game.view.cam_target, game.player.position.y, raining, winter, season, daylight, game.chunks.indoor)
	if game.tracks != null:
		game.tracks.snow = snow
		game.tracks.wet = wet
	if game.props.drifts != null:
		game.props.drifts.visible = snow > 0.6
