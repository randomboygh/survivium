extends RefCounted
## The sky drawn for the world's time and weather (Clock, src/shared): the sun and the
## moon with its phases, the ambient light and the background, the colour grade, the
## tints of leaves and grass in each season, clouds, wind, fog, lightning, snow and ice
## on the ground, puddles after rain, sun rays in the air and the fog on the ground. Everything the shaders need goes out as global shader parameters.
## `game` is the Main node that owns the scene.

const Bushes := preload("res://src/shared/content/bushes.gd")
const Clock := preload("res://src/shared/game/clock.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const FOLIAGE := [Vector3(0.95, 1.1, 0.8), Vector3(1.0, 1.0, 1.0), Vector3(2.2, 1.05, 0.55), Vector3(1.3, 0.9, 0.7)]
const GRASS := [Vector3(0.95, 1.08, 0.85), Vector3(1.0, 1.0, 1.0), Vector3(1.1, 0.9, 0.66), Vector3(0.9, 0.85, 0.72)]
const LEAF_AMOUNT := [1.0, 1.0, 0.8, 0.55]
## Share of the berries ripe on bushes.
const BERRY_AMOUNT := Bushes.BERRY_AMOUNT
## How bright the sun rays (god rays) are at most, added in the air over the picture.
## Steps a day the sun and the moon move in: a step every 1/6 s of a 4-minute day,
## a quarter of a degree, about a texel at the tip of a tree's shadow.
const SUN_STEPS := 1440
const RAYS_BRIGHTNESS := 0.45
## How far, in degrees, the sun or the moon goes past the border of its eighth of the
## sky before the lit edges of the cells turn to the next one (see _light_side).
const LIGHT_SIDE_MARGIN := 7.5
## How long the air after rain shows the rays through the breaking clouds, in days.
const AFTER_RAIN_DAYS := 0.08

var game
var sun: DirectionalLight3D
## Steps a day the sun and the moon move in (see _update_light); 0 smoothly.
var sun_steps := SUN_STEPS
var env: Environment

## Brightness of a lightning flash, 0 most of the time.
var flash := 0.0
var flash_clock := 6.0
## Moonlight 0 (new moon) .. 1 (full moon), and the playtest override (-1 = by phase).
var moon := 1.0
var moon_override := -1.0
## How bright the open sky is, 0 on a moonless night .. 1 by day; the torch and the
## weather particles follow it.
var sky_light := 1.0
var rng := RandomNumberGenerator.new()
var foliage := Vector3.ONE
var grass := Vector3.ONE
var leaf_amount := 1.0
var berry_amount := 1.0
## How much of the trees' blossom is out: all of it in spring, none after.
const BLOSSOM_AMOUNT := [1.0, 0.0, 0.0, 0.0]
var blossom_amount := 0.0
var cloud_pos := Vector2.ZERO
var wind_clock := 0.0
var daylight := 1.0
## Sun rays are drawn (the «Солнечные лучи» setting).
var rays_on := true
## Fog is drawn on the ground (the «Туман» setting); without it the fog is a plain
## haze over the picture.
var fog_on := true
## How far the fog's banks have drifted with the wind.
var fog_drift := Vector2.ZERO
## 1 while it rains, fading to 0 over AFTER_RAIN_DAYS once it stops.
var after_rain := 0.0
## Towards the sun or the moon in the sky, as _aim_sun last put it.
var to_sun := Vector3.UP
## The side of the sky the light is on, in eighths of a turn from south toward west
## (see _light_side): the edges of the cells toward it are lit.
var light_side := 0


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


## Draws the sky of the clock now, `delta` seconds after the last frame.
func update(delta: float) -> void:
	_update_light(delta)
	_update_weather(delta)


func _update_light(delta: float) -> void:
	var clock = game.clock
	var time_of_day: float = clock.time_of_day
	var snow: float = clock.snow
	var h := -cos(time_of_day * TAU)
	daylight = clock.daylight()
	moon = moon_override if moon_override >= 0.0 else Clock.moon_phase_light(clock.day + time_of_day)
	# Clouds hide the moon; snow on the ground gives its light back.
	var overcast := clampf((clock.clouds - 0.3) / 0.6, 0.0, 1.0)
	var moonlight := moon * (1.0 - 0.75 * overcast) * (1.0 + 0.5 * snow)
	# Low warm light near sunrise and sunset, full light at midday.
	var golden := clampf(1.0 - absf(h) * 3.0, 0.0, 1.0) if h > -0.25 else 0.0
	# The sun and the moon fade out towards the horizon, so the light swaps from one
	# to the other while neither shines and the shadows never jump; the long shadows
	# of a low sun come in faint and grow with the light.
	var rise := smoothstep(0.0, 0.3, absf(h))
	# The sun and the moon move in steps: a shadow map drawn anew from a light turned a
	# little every frame puts the texels of each shadow's edge in other places each time,
	# and the edges shimmer as they creep.
	var sun_time := floorf(time_of_day * sun_steps) / sun_steps if sun_steps > 0 else time_of_day
	if h > 0.0:
		# The sun crosses the southern sky from east to west, a little off south at
		# noon so shadows fall to the side and stay visible.
		_aim_sun((sun_time - 0.5) * 180.0 - 25.0, lerpf(14.0, 55.0, -cos(sun_time * TAU)))
		sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.38), golden)
		sun.light_energy = 0.85 * rise
		_update_rays(rise, golden)
	else:
		_update_rays(0.0, 0.0)
		_aim_sun((fmod(sun_time + 0.5, 1.0) - 0.5) * 180.0 - 25.0, lerpf(14.0, 50.0, cos(sun_time * TAU)))
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
	if game.player != null:
		var dark := 1.0 if game.chunks.indoor else clampf((0.55 - sky_light) * 4.0, 0.0, 1.0)
		dark *= 1.0 - game.effects.torch_off(game.player.position)
		var shadows: bool = dark > 0.0 and game.effects.shadows and not game.effects.player_only \
				and not game.effects.fire_shadowing
		game.player.torch.shadow_enabled = shadows
		game.player.torch.light_energy = 1.3 * dark * (game.effects.shadow_energy if shadows else 1.0)
	_update_grade(golden, night, minf(moonlight, 1.0))
	_update_fog(golden, delta)


## Points the sun (or the moon) from `azimuth` degrees (0 = south, negative = east)
## at `elevation` degrees above the horizon.
func _aim_sun(azimuth: float, elevation: float) -> void:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	to_sun = Vector3(-sin(az) * cos(el), sin(el), cos(az) * cos(el))
	# The light shines in the drawn world: turned with the view, so the shadows stay
	# where they fall in the default view, while faces are lit as in it (sun_view).
	sun.global_transform.basis = Basis.looking_at(-PixelView.light_dir(to_sun), Vector3.UP)
	var view := PixelView.camera_transform(Vector2.ZERO).basis
	RenderingServer.global_shader_parameter_set("sun_view", view.transposed() * to_sun)
	_light_side(azimuth)


## Keeps light_side, the eighth of the sky the light is in, until it is well into the
## next one, so the lit edges of the cells change all at once a few times a day and
## never flicker on a side's border.
func _light_side(azimuth: float) -> void:
	var off := wrapf(azimuth - light_side * 45.0, -180.0, 180.0)
	if absf(off) < 22.5 + LIGHT_SIDE_MARGIN:
		return
	light_side = posmod(roundi(azimuth / 45.0), 8)
	var a := deg_to_rad(light_side * 45.0)
	RenderingServer.global_shader_parameter_set("light_side", Vector2(-sin(a), cos(a)))


## Sun rays in the air: by day in clear weather, and brighter in the wet air after
## rain as the clouds break up; none while anything falls, in fog and under a roof.
## Brighter and warmer when the sun is low. `rise` is how far the sun is up (0..1).
func _update_rays(rise: float, golden: float) -> void:
	var clock = game.clock
	var grade_mat: ShaderMaterial = game.view.grade_mat
	var clouds: float = clock.clouds
	var clear := clampf((0.8 - clouds) / 0.4, 0.0, 1.0)
	var breaking := after_rain * clampf((1.0 - clouds) / 0.3, 0.0, 1.0)
	var falling: float = clock.rain + clock.snowing + clock.hail + clock.sand
	var amount := rise * maxf(clear * 0.9, breaking) * (1.0 + 0.3 * golden)
	amount *= clampf(1.0 - falling * 4.0, 0.0, 1.0) * clampf(1.0 - clock.fog * 1.5, 0.0, 1.0)
	if not rays_on or game.chunks.indoor:
		amount = 0.0
	grade_mat.set_shader_parameter("rays_amount", amount * RAYS_BRIGHTNESS)
	if amount <= 0.0:
		return
	# The shafts come down from the sky, which is up on the image in this view, and
	# lean the way the light runs east or west, as the shadows do, never further
	# than about 30 degrees off straight down.
	var dir := Vector2(clampf(-to_sun.x * 1.2, -0.6, 0.6), 1.0).normalized()
	grade_mat.set_shader_parameter("rays_dir", dir)
	grade_mat.set_shader_parameter("rays_color", Color(1.0, 0.96, 0.82).lerp(Color(1.0, 0.72, 0.45), golden))
	# They fall on the sun's side of the image: the right in the morning, the left
	# after noon, sliding across around noon.
	grade_mat.set_shader_parameter("rays_anchor", 0.5 - 0.3 * clampf(dir.x * 6.0, -1.0, 1.0))
	grade_mat.set_shader_parameter("rays_time", wind_clock)


## The fog on the ground (Clock.ground_fog, see fog_at in common.gdshaderinc): the
## weather's or the morning's, and a light one after rain; outdoors only. Its colour
## follows the light, its banks drift slowly with the wind.
func _update_fog(golden: float, delta: float) -> void:
	var clock = game.clock
	var f: Vector2 = clock.ground_fog()
	var falling: float = clock.rain + clock.snowing + clock.hail + clock.sand
	var wet: float = after_rain * 0.35 * clampf(1.0 - falling * 3.0, 0.0, 1.0)
	if wet > f.x:
		f = Vector2(wet, 0.6)
	if not fog_on or game.chunks.indoor or game.player == null:
		f.x = 0.0
	var g := RenderingServer
	g.global_shader_parameter_set("fog", f.x)
	if f.x <= 0.0:
		return
	var col := Color(0.9, 0.92, 0.96).lerp(Color(1.0, 0.9, 0.8), golden * 0.6)
	col = (col * lerpf(0.6, 1.1, sky_light)).srgb_to_linear()
	g.global_shader_parameter_set("fog_color", Vector3(col.r, col.g, col.b))
	g.global_shader_parameter_set("fog_depth", f.y)
	fog_drift -= clock.wind_dir() * delta * (0.15 + 0.3 * clock.storm_wind)
	g.global_shader_parameter_set("fog_drift", fog_drift)
	g.global_shader_parameter_set("fog_sea", (game.gen.sea + 1) * WorldData.CELL if game.gen != null else 0.0)


## The colour grade sets the mood: warm at sunrise and sunset, blue and muted under
## the moon, near black and colourless without it, grey in rain, cool in winter. Fog,
## blizzards and sand storms lay a drifting haze over the picture.
func _update_grade(golden: float, night: float, moonlight: float) -> void:
	var clock = game.clock
	var rain: float = clock.rain
	var snowing: float = clock.snowing
	var sand: float = clock.sand
	var winter: bool = clock.season == Clock.WINTER
	var tint := Vector3(1.02, 1.0, 0.97).lerp(Vector3(1.08, 0.97, 0.88), golden).lerp(Vector3(0.82, 0.92, 1.15), night)
	var saturation := lerpf(lerpf(0.92, 1.05, golden), lerpf(0.45, 0.6, moonlight), night)
	var exposure := lerpf(1.0, lerpf(1.0, 1.15, moonlight), night)
	var contrast := 1.06
	var wet_k := clampf(rain + snowing * 0.6 + clock.hail, 0.0, 1.0)
	var rain_k := maxf(clock.wet, wet_k) if not winter else wet_k
	saturation *= 1.0 - 0.3 * rain_k
	tint *= Vector3.ONE.lerp(Vector3(0.95, 0.98, 1.03), rain_k)
	exposure *= 1.0 - 0.08 * rain_k - 0.08 * clampf(rain - 0.5, 0.0, 0.5)
	if winter:
		tint *= Vector3(0.97, 1.0, 1.04)
	exposure += flash * 1.2
	var indoor_k := 0.25 if game.chunks.indoor else 1.0
	# Haze: grey fog, white blizzard, ochre sand; as dark as the sky around it.
	var haze_col := Vector3(0.62, 0.66, 0.7)
	var white := clampf(snowing * 2.0 - 1.0, 0.0, 1.0)
	haze_col = haze_col.lerp(Vector3(0.88, 0.9, 0.94), white).lerp(Vector3(0.78, 0.6, 0.38), sand)
	haze_col *= lerpf(0.12, 1.0, sky_light)
	# Fog without the «Туман» setting is a plain haze too.
	var fog_haze: float = 0.0 if fog_on else clock.ground_fog().x * 0.6
	var haze_amount := clampf(clock.haze + fog_haze + sand * 0.2, 0.0, 0.85) * indoor_k
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
	grade_mat.set_shader_parameter("haze_offset", cloud_pos * Vector2(1.5, 0.6) * (1.0 + 3.0 * clock.storm_wind))


## A new season began (see Clock.next_season): the bushes ripen or shed, and the
## player is told.
func on_season(season: int) -> void:
	if game.actions != null:
		game.actions.on_season(season)
	print("season: %s" % Clock.SEASONS[season])
	game.hud.toast("Наступила %s" % Clock.SEASONS[season].to_lower() if season != 1 else "Наступило лето")


## Name of the HUD icon for the sky now: the weather, or the moon by its phase at
## night when the sky is clear.
func icon() -> String:
	var name: String = game.clock.weather_icon()
	if name != "sun":
		return name
	if daylight > 0.35:
		return "sun"
	return "moon_full" if moon > 0.7 else ("moon" if moon > 0.2 else "moon_new")


func _update_weather(delta: float) -> void:
	var clock = game.clock
	var season: int = clock.season
	var w: Dictionary = Clock.WEATHERS[clock.weather]
	_update_lightning(delta, w.get("lightning", 0.0) > 0.0 and season != Clock.WINTER)
	var k2 := minf(1.0, delta * 0.4)
	foliage = foliage.lerp(FOLIAGE[season], k2)
	grass = grass.lerp(GRASS[season], k2)
	# The autumn wind strips the leaves early, down to what winter leaves.
	var leaves: float = LEAF_AMOUNT[season]
	if season == Clock.AUTUMN:
		leaves = lerpf(leaves, LEAF_AMOUNT[Clock.WINTER], clock.leaf_fall)
	leaf_amount = lerpf(leaf_amount, leaves, k2)
	berry_amount = lerpf(berry_amount, BERRY_AMOUNT[season], k2)
	blossom_amount = lerpf(blossom_amount, BLOSSOM_AMOUNT[season], k2)
	wind_clock += delta
	var storm_wind: float = clock.storm_wind
	var gust := 0.25 + 0.25 * sin(wind_clock * 0.35) + 0.15 * sin(wind_clock * 1.3)
	var dir: Vector2 = clock.wind_dir()
	var strength := gust * (1.0 + storm_wind * 0.5) + storm_wind
	var wind := dir * strength + Vector2(-dir.y, dir.x) * 0.15
	if clock.rain > 0.2:
		after_rain = 1.0
	else:
		after_rain = maxf(0.0, after_rain - clock.days(delta) / AFTER_RAIN_DAYS)
	cloud_pos -= (dir * 0.6 + Vector2(0.0, 0.25)) * delta * (1.0 + strength)
	var g := RenderingServer
	g.global_shader_parameter_set("snow_amount", clock.snow)
	g.global_shader_parameter_set("snow_line", (game.world.sea_level + WorldData.SNOW_LINE) * WorldData.CELL)
	g.global_shader_parameter_set("wetness", clock.wet)
	g.global_shader_parameter_set("puddles", Vector2(0.0 if clock.season == Clock.WINTER else clock.puddles, clock.rain))
	g.global_shader_parameter_set("foliage_tint", foliage)
	g.global_shader_parameter_set("grass_tint", grass)
	g.global_shader_parameter_set("leaf_amount", leaf_amount)
	# Fallen leaves lie under the crowns as the trees lose them, under the snow in
	# winter, and are gone as the trees leaf out again.
	g.global_shader_parameter_set("leaf_litter", clampf((1.0 - leaf_amount) / (1.0 - LEAF_AMOUNT[Clock.WINTER]), 0.0, 1.0))
	g.global_shader_parameter_set("berry_amount", berry_amount)
	g.global_shader_parameter_set("blossom_amount", blossom_amount)
	g.global_shader_parameter_set("night_glow", smoothstep(0.6, 0.15, daylight))
	g.global_shader_parameter_set("cloud_cover", clock.clouds)
	g.global_shader_parameter_set("cloud_offset", cloud_pos)
	g.global_shader_parameter_set("wind", wind)
	game.water_mat.set_shader_parameter("ice_amount", clock.ice())
	if game.player != null:
		game.effects.update(delta, game.view.cam_target, game.player.position.y, self, clock, game.chunks.indoor)
	if game.tracks != null:
		game.tracks.snow = clock.snow
		game.tracks.wet = clock.wet
	if game.drifts_root != null:
		# The terrain shader shrinks them as the snow melts (drift_size).
		game.drifts_root.visible = clock.snow > 0.3


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
	if flash_clock > 1.0 and game.sound.nature != null:
		# One thunder a lightning: for its last flicker.
		game.sound.nature.thunder(flash)
	if game.player != null and not game.chunks.indoor and rng.randf() < 0.7:
		game.effects.strike(game.view.cam_target, game.player.position.y, flash)
