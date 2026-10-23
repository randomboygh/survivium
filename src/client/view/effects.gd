extends Node3D
## Pixel particle effects and lights: campfires, rain, downpours, hail, snow,
## blizzards, blowing sand, lightning, fireflies, falling leaves, leaves torn off by
## an autumn gale and floating pollen. The weather's particles fly with the wind
## (Clock.wind_dir).
## Everything is drawn with particle.gdshader as 1-2 px squares (a lightning bolt as
## 1 px lines). Weather emitters follow the view; `update()` switches them by weather,
## season and time of day.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const VoxelModel := preload("res://src/client/view/voxel_model.gd")
const ParticleShader := preload("res://shaders/particle.gdshader")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## See _place_fireflies.
const FIREFLY_MOVE := 4.0
const FIREFLY_TRIES := 120
## Bits flying off worked material (see burst): emitters used in turn, bits in each, and
## their colour by material id ("" for any other).
const BURSTS := 4
const BURST_BITS := 8
const BITS := {
	"core:grass": Color(0.42, 0.62, 0.26), "core:dirt": Color(0.5, 0.36, 0.22), "core:stone": Color(0.58, 0.58, 0.6),
	"core:sand": Color(0.86, 0.77, 0.52), "core:clay": Color(0.62, 0.48, 0.38), "core:log": Color(0.72, 0.55, 0.33),
	"core:leaves": Color(0.3, 0.55, 0.22), "core:planks": Color(0.7, 0.53, 0.3), "core:copper_ore": Color(0.66, 0.5, 0.38),
	"core:brick": Color(0.64, 0.32, 0.26), "": Color(0.55, 0.5, 0.45),
}
## The pixels of a star sparkle (see _star).
const STAR := [
	"..x..",
	"..x..",
	"xxoxx",
	"..x..",
	"..x..",
]
## World units around a fire where snow melts and the ground stays dry.
const HEAT_RADIUS := 3.0
## One light at a time casts shadows: the fire nearest to the view within this many
## world units of it, else the torch. Each light with shadows draws what is around it
## into a shadow map whenever something there moves, and lights it again in a pass
## of its own; on the phone two of them took the frame from 60 to about 30 FPS.
const SHADOW_FIRE_REACH := 10.0
## What a fire's real shadow falls from: all but the shadow discs under crowns and
## bushes (see PixelView.LAYER_SUN_CASTER).
const FIRE_CASTERS := 0xFFFFF & ~PixelView.LAYER_SUN_CASTER
## A light with shadows is added to the picture in a pass of its own, in screen colours
## rather than in light, and comes out brighter over the ambient light and the moon
## than the same light drawn with the rest: such a fire or torch burns lower, by the
## first factor on a dark night and by the second under a full moon or by day
## (see shadow_energy).
const SHADOW_ENERGY := Vector2(0.8, 0.6)
## Fires cast shadows only while the light of the sky (sky.gd sky_light) is below this:
## by day their faint light, drawn in a pass of its own, would glare yellow over the
## sunlit ground.
const SHADOW_SKY := 0.5
## Around a fire the torch goes out (see torch_off), world units from the fire.
const TORCH_OFF_NEAR := 3.0
const TORCH_OFF_FAR := 5.5

var rain: CPUParticles3D
## More rain on top of `rain` in a downpour or a storm.
var downpour: CPUParticles3D
var hail: CPUParticles3D
var snowfall: CPUParticles3D
## Snow driven sideways by the wind of a blizzard.
var blizzard: CPUParticles3D
var sand: CPUParticles3D
## Weather emitters, dimmed with the light of the sky (particles are unshaded).
var weather_emitters: Array[CPUParticles3D] = []
## The lightning bolt: a jagged line from the clouds, shown for a moment.
var bolt: MeshInstance3D
var bolt_mesh: ImmediateMesh
var bolt_light: OmniLight3D
var bolt_time := 0.0
var fireflies: CPUParticles3D
## The world the fireflies fly over (WorldData): only over grass, bushes and under the
## crowns, not over water, sand or stone. Their spots are picked around the view when it
## has moved FIREFLY_MOVE world units, from FIREFLY_TRIES columns.
var world
var _firefly_home := Vector2.INF
## Bits flying off what the hands work (see burst): the emitters, used in turn, and the
## bursts waiting for the strike, [seconds left, where, material] each.
var _bursts: Array[CPUParticles3D] = []
var _burst_next := 0
var _burst_wait := []
var leaves: CPUParticles3D
## Leaves an autumn gale tears off the trees, flying low and fast.
var gale: CPUParticles3D
var pollen: CPUParticles3D
## Each fire: {"light": OmniLight3D, "base": float, "unit": Vector3i (the world unit it
## stands in), "at": Vector3 (its middle on the ground)}
var fires: Array = []
## The effects setting: off stops the weather and the ambient particles.
var enabled := true
## The fire shadows setting: the nearest fire or the torch casts shadows (see
## SHADOW_FIRE_REACH).
var shadows := true
## The fire shadows setting is on "mixed": the fire's real shadow falls from the player
## alone, FireShadows draws the rest, and the torch casts none.
var player_only := false
## True while a fire casts shadows, and the torch then casts none.
var fire_shadowing := false
## What a fire or the torch with shadows burns at, as a share (see SHADOW_ENERGY).
var shadow_energy := SHADOW_ENERGY.x
## True while the sky is dark enough for fires to cast shadows (see SHADOW_SKY).
var dark := true
var flicker_clock := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 99
	rain = _emitter(420, 0.9, Vector2(PX, 4.0 * PX), 1.2)
	rain.direction = Vector3(0.15, -1.0, 0.0)
	rain.spread = 3.0
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 16.0
	rain.gravity = Vector3.ZERO
	rain.color = Color(0.75, 0.85, 1.0, 0.75)
	rain.emission_box_extents = Vector3(22.0, 0.5, 26.0)

	downpour = _emitter(520, 0.7, Vector2(PX, 5.0 * PX), 1.1)
	downpour.direction = Vector3(0.3, -1.0, 0.0)
	downpour.spread = 4.0
	downpour.initial_velocity_min = 18.0
	downpour.initial_velocity_max = 21.0
	downpour.gravity = Vector3.ZERO
	downpour.color = Color(0.7, 0.8, 0.95, 0.7)
	downpour.emission_box_extents = Vector3(22.0, 0.5, 26.0)

	hail = _emitter(260, 0.8, Vector2(PX, PX), 1.4)
	hail.direction = Vector3(0.2, -1.0, 0.0)
	hail.spread = 4.0
	hail.initial_velocity_min = 11.0
	hail.initial_velocity_max = 14.0
	hail.gravity = Vector3(0.0, -8.0, 0.0)
	hail.color = Color(0.92, 0.96, 1.0, 1.0)
	hail.scale_amount_min = 1.0
	hail.scale_amount_max = 2.0
	hail.emission_box_extents = Vector3(22.0, 0.5, 26.0)

	blizzard = _emitter(700, 2.5, Vector2(PX, PX), 1.0)
	blizzard.direction = Vector3(1.0, -0.25, 0.1)
	blizzard.spread = 12.0
	blizzard.initial_velocity_min = 7.0
	blizzard.initial_velocity_max = 11.0
	blizzard.gravity = Vector3(0.0, -0.5, 0.0)
	blizzard.color = Color(0.95, 0.97, 1.0, 0.9)
	blizzard.emission_box_extents = Vector3(30.0, 3.0, 30.0)

	sand = _emitter(600, 2.5, Vector2(PX, PX), 1.0)
	sand.direction = Vector3(1.0, 0.05, 0.1)
	sand.spread = 8.0
	sand.initial_velocity_min = 8.0
	sand.initial_velocity_max = 12.0
	sand.gravity = Vector3.ZERO
	sand.emission_box_extents = Vector3(30.0, 2.0, 30.0)
	sand.color_initial_ramp = _ramp([Color(0.85, 0.66, 0.4, 0.9), Color(0.72, 0.52, 0.3, 0.9), Color(0.93, 0.78, 0.52, 0.8)])

	snowfall = _emitter(320, 9.0, Vector2(PX, PX), 1.0)
	snowfall.direction = Vector3(0.2, -1.0, 0.0)
	snowfall.spread = 25.0
	snowfall.initial_velocity_min = 0.8
	snowfall.initial_velocity_max = 1.4
	snowfall.gravity = Vector3(0.0, -0.3, 0.0)
	snowfall.color = Color(0.95, 0.97, 1.0, 0.95)
	snowfall.emission_box_extents = Vector3(22.0, 0.5, 26.0)

	fireflies = _emitter(40, 5.0, Vector2(PX, PX), 1.6)
	fireflies.direction = Vector3(0.0, 1.0, 0.0)
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.35
	fireflies.gravity = Vector3.ZERO
	fireflies.emission_box_extents = Vector3(18.0, 1.0, 12.0)
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	fireflies.color_ramp = _ramp([Color(0.8, 1.0, 0.45, 0.0), Color(0.85, 1.0, 0.5, 1.0), Color(0.85, 1.0, 0.5, 1.0), Color(0.8, 1.0, 0.45, 0.0)])

	leaves = _emitter(30, 7.0, Vector2(PX, PX), 1.0)
	leaves.direction = Vector3(1.0, -0.4, 0.2)
	leaves.spread = 30.0
	leaves.initial_velocity_min = 0.4
	leaves.initial_velocity_max = 0.9
	leaves.gravity = Vector3(0.0, -0.25, 0.0)
	leaves.emission_box_extents = Vector3(22.0, 1.0, 26.0)
	leaves.color_initial_ramp = _ramp([Color(0.85, 0.55, 0.2), Color(0.8, 0.35, 0.15), Color(0.9, 0.75, 0.3)])
	leaves.scale_amount_min = 1.0
	leaves.scale_amount_max = 2.0

	gale = _emitter(160, 3.0, Vector2(PX, PX), 1.0)
	gale.direction = Vector3(1.0, -0.1, 0.1)
	gale.spread = 15.0
	gale.initial_velocity_min = 4.0
	gale.initial_velocity_max = 7.0
	gale.gravity = Vector3(0.0, -0.4, 0.0)
	gale.emission_box_extents = Vector3(26.0, 2.5, 28.0)
	gale.color_initial_ramp = leaves.color_initial_ramp
	gale.scale_amount_min = 1.0
	gale.scale_amount_max = 2.0

	pollen = _emitter(24, 6.0, Vector2(PX, PX), 1.0)
	pollen.direction = Vector3(1.0, 0.2, 0.0)
	pollen.spread = 60.0
	pollen.initial_velocity_min = 0.1
	pollen.initial_velocity_max = 0.3
	pollen.gravity = Vector3.ZERO
	pollen.emission_box_extents = Vector3(18.0, 1.5, 12.0)
	pollen.color_ramp = _ramp([Color(1, 1, 0.85, 0.0), Color(1, 1, 0.85, 0.7), Color(1, 1, 0.85, 0.0)])
	weather_emitters = [rain, downpour, hail, snowfall, blizzard, sand, leaves, gale]

	bolt_mesh = ImmediateMesh.new()
	bolt = MeshInstance3D.new()
	bolt.mesh = bolt_mesh
	var bolt_mat := ShaderMaterial.new()
	bolt_mat.shader = ParticleShader
	bolt_mat.set_shader_parameter("brightness", 2.0)
	bolt.material_override = bolt_mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.extra_cull_margin = 64.0
	bolt.visible = false
	add_child(bolt)
	bolt_light = OmniLight3D.new()
	bolt_light.light_color = Color(0.8, 0.88, 1.0)
	bolt_light.omni_range = 10.0
	bolt_light.omni_attenuation = 0.0
	bolt_light.light_energy = 0.0
	add_child(bolt_light)


## A campfire one world unit square with its north-west corner at `corner`: stones,
## logs, flames, sparks, smoke and a flickering light, the model drawn with `material`.
## Returns its record for put_out and remove_campfire: {"model", "parts" (what burns),
## "fire" (its entry in fires, null once put out)}.
func add_campfire(corner: Vector3, material: Material) -> Dictionary:
	var model := MeshInstance3D.new()
	model.mesh = _campfire_model().build_mesh()
	model.material_override = material
	model.scale = Vector3.ONE / 16.0
	model.position = corner
	# 24 world units in the model's 1/16 scale, against the shear of the view.
	model.extra_cull_margin = 24.0 * 16.0
	add_child(model)
	var c := corner + Vector3(0.5, 0.15, 0.5)

	var flames := _emitter(36, 0.7, Vector2(2.0 * PX, 2.0 * PX), 1.0)
	flames.local_coords = false
	flames.position = c
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.14
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.initial_velocity_min = 0.5
	flames.initial_velocity_max = 0.9
	flames.gravity = Vector3(0.0, 0.6, 0.0)
	flames.scale_amount_min = 0.5
	flames.scale_amount_max = 1.0
	flames.scale_amount_curve = _curve([1.0, 0.5])
	flames.color_ramp = _ramp([Color(1.0, 0.95, 0.65, 1.0), Color(1.0, 0.7, 0.25, 1.0), Color(0.9, 0.32, 0.1, 1.0), Color(0.5, 0.15, 0.08, 0.0)])
	flames.emitting = true

	var sparks := _emitter(8, 1.6, Vector2(PX, PX), 1.0)
	sparks.position = c + Vector3(0.0, 0.3, 0.0)
	sparks.direction = Vector3.UP
	sparks.spread = 35.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.6
	sparks.gravity = Vector3(0.3, 0.2, 0.0)
	sparks.color_ramp = _ramp([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.55, 0.2, 1.0), Color(0.8, 0.3, 0.1, 0.0)])
	sparks.emitting = true

	var smoke := _emitter(14, 3.5, Vector2(2.0 * PX, 2.0 * PX), 1.0)
	smoke.position = c + Vector3(0.0, 0.7, 0.0)
	smoke.direction = Vector3.UP
	smoke.spread = 10.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3(0.25, 0.05, 0.0)
	smoke.scale_amount_curve = _curve([0.5, 1.0])
	smoke.color_ramp = _ramp([Color(0.5, 0.5, 0.52, 0.0), Color(0.55, 0.55, 0.58, 0.45), Color(0.6, 0.6, 0.62, 0.0)])
	smoke.emitting = true

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.47, 0.18)
	light.omni_range = 8.0
	# No falloff of its own: the shaders step the light into rings (see toon_light).
	light.omni_attenuation = 0.0
	light.shadow_caster_mask = FIRE_CASTERS
	light.position = PixelView.shear(c + Vector3(0.0, 0.6, 0.0))
	add_child(light)
	var fire := {"light": light, "base": 1.8, "unit": Vector3i(c.floor()), "at": c}
	fires.append(fire)
	return {"model": model, "parts": [flames, sparks, smoke, light], "fire": fire}


## Puts out campfire `rec` (see add_campfire): the flames, smoke and light go, its warmth
## too (the caller remakes the heat map), and grey ash lies on the cold logs.
func put_out(rec: Dictionary) -> void:
	for node: Node in rec.parts:
		node.queue_free()
	rec.parts = []
	fires.erase(rec.fire)
	rec.fire = null
	(rec.model as MeshInstance3D).mesh = _campfire_model(false).build_mesh()


## Takes campfire `rec` (see add_campfire) out of the world.
func remove_campfire(rec: Dictionary) -> void:
	put_out(rec)
	rec.model.queue_free()


## Warmth around the fires for the shaders (heat_map, see common.gdshaderinc): one
## texel per world unit, r = heat falling off over HEAT_RADIUS units, g = the height of
## the fire's unit. Snow melts and rain dries there. Like the roof map it repeats every
## `size` units (see RoofMap.WRAP).
func heat_map(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var r := ceili(HEAT_RADIUS)
	for f in fires:
		var c: Vector3i = f.unit
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := posmod(c.x + dx, size)
				var z := posmod(c.z + dz, size)
				var heat := clampf(1.3 - Vector2(dx, dz).length() / HEAT_RADIUS, 0.0, 1.0)
				if heat > img.get_pixel(x, z).r:
					img.set_pixel(x, z, Color(heat, c.y / 64.0, 0.0, 1.0))
	return ImageTexture.create_from_image(img)


## Moves the weather emitters over the view and turns them on and off by the weather
## of `clock` (Clock) and the light of `sky` (sky.gd). `view` is the screen-plane
## centre; `ground` the height the player stands on.
func update(delta: float, view: Vector2, ground: float, sky, clock, indoor: bool) -> void:
	var top := ground + 7.0
	# A point at height h shows at screen-plane y = z - h, so emitters sit further south.
	rain.position = Vector3(view.x, top, view.y + top)
	for p in [downpour, hail, snowfall]:
		p.position = rain.position
	# Storms blow low over the ground, so they start upwind of the view.
	var dir: Vector2 = clock.wind_dir()
	var wind: float = clock.storm_wind
	var low := ground + 1.5
	blizzard.position = Vector3(view.x - dir.x * 10.0, low, view.y + low - dir.y * 10.0)
	sand.position = blizzard.position
	gale.position = blizzard.position
	leaves.position = Vector3(view.x, ground + 5.0, view.y + ground + 5.0)
	_blow(rain, dir, 0.1 + 0.1 * wind, -1.0)
	_blow(downpour, dir, 0.15 + 0.12 * wind, -1.0)
	_blow(hail, dir, 0.1 + 0.1 * wind, -1.0)
	_blow(snowfall, dir, 0.15 + 0.2 * wind, -1.0)
	_blow(blizzard, dir, 1.0, -0.25)
	_blow(sand, dir, 1.0, 0.05)
	_blow(gale, dir, 1.0, -0.1)
	_blow(leaves, dir, 1.0, -0.4)
	_blow(pollen, dir, 1.0, 0.2)
	_place_fireflies(view, ground)
	for i in range(_burst_wait.size() - 1, -1, -1):
		var b: Array = _burst_wait[i]
		b[0] -= delta
		if b[0] <= 0.0:
			_burst_now(b[1], b[2])
			_burst_wait.remove_at(i)
	pollen.position = Vector3(view.x, ground + 1.5, view.y + ground + 1.5)
	var outside := enabled and not indoor
	var season: int = clock.season
	var daylight: float = sky.daylight
	rain.emitting = outside and clock.rain > 0.15
	downpour.emitting = outside and clock.rain > 0.7
	hail.emitting = outside and clock.hail > 0.3
	snowfall.emitting = outside and clock.snowing > 0.15
	blizzard.emitting = outside and clock.snowing > 0.8
	sand.emitting = outside and clock.sand > 0.3
	var calm: bool = clock.rain < 0.15 and clock.snowing < 0.15 and clock.sand < 0.3 and clock.storm_wind < 1.5
	leaves.emitting = outside and season == 2
	gale.emitting = outside and season == 2 and wind > 0.8 and sky.leaf_amount > 0.57
	fireflies.emitting = enabled and daylight < 0.3 and (season == 0 or season == 1) and calm \
		and not fireflies.emission_points.is_empty()
	pollen.emitting = outside and daylight > 0.6 and (season == 0 or season == 1) and calm
	# Particles are unshaded: on a dark night rain shows only near the torch light.
	var light := clampf(maxf(sky.sky_light, sky.flash), 0.12, 1.0)
	for p in weather_emitters:
		var m: ShaderMaterial = (p.mesh as QuadMesh).material
		m.set_shader_parameter("light", light)
	bolt_time -= delta
	if bolt_time <= 0.0 and bolt.visible:
		bolt.visible = false
		bolt_light.light_energy = 0.0
	shadow_energy = lerpf(SHADOW_ENERGY.x, SHADOW_ENERGY.y, clampf(sky.sky_light / 0.45, 0.0, 1.0))
	dark = sky.sky_light < SHADOW_SKY
	# At dusk the shadows darken in over a short while instead of popping in.
	var opacity := clampf((SHADOW_SKY - sky.sky_light) / 0.08, 0.0, 1.0)
	for f in fires:
		f.light.shadow_opacity = opacity
	flicker_clock += delta
	if flicker_clock > 0.09:
		flicker_clock = 0.0
		# Fires matter at night; by day they only warm the ground a little.
		pick_shadow_fires(view)
		for f in fires:
			var energy: float = f.base * lerpf(1.0, 0.15, daylight) * rng.randf_range(0.8, 1.1)
			f.light.light_energy = energy * (shadow_energy if f.light.shadow_enabled else 1.0)


## Points emitter `p` `down` (negative falls) and `side` along the wind `dir` (x east,
## y south).
func _blow(p: CPUParticles3D, dir: Vector2, side: float, down: float) -> void:
	p.direction = Vector3(dir.x * side, down, dir.y * side)


## How much the torch gives way to the fires around world point `p`: 1 within
## TORCH_OFF_NEAR world units of a burning fire, 0 beyond TORCH_OFF_FAR. A light with
## shadows is added to the picture in a pass of its own, in screen colours rather than in
## light, so where the torch and a fire overlap they would glare twice as bright.
func torch_off(p: Vector3) -> float:
	var off := 0.0
	for f in fires:
		var d := Vector2(p.x - f.at.x, p.z - f.at.z).length()
		if absf(p.y - f.at.y) < 3.0:
			off = maxf(off, clampf((TORCH_OFF_FAR - d) / (TORCH_OFF_FAR - TORCH_OFF_NEAR), 0.0, 1.0))
	return off


## Lets the fire nearest to the screen-plane point `view`, if within SHADOW_FIRE_REACH,
## cast shadows.
func pick_shadow_fires(view: Vector2) -> void:
	var best = null
	if shadows and dark:
		var best_d := SHADOW_FIRE_REACH * SHADOW_FIRE_REACH
		for f in fires:
			var d := PixelView.screen_plane(f.unit).distance_squared_to(view)
			if d < best_d:
				best_d = d
				best = f
	for f in fires:
		f.light.shadow_enabled = f == best
	if best != null:
		best.light.shadow_caster_mask = PixelView.LAYER_PLAYER if player_only else FIRE_CASTERS
	fire_shadowing = best != null


## A lightning bolt somewhere around the screen-plane point `view`: a jagged line
## from high above down to the ground, lit for a moment.
func strike(view: Vector2, ground: float, power: float) -> void:
	if not enabled:
		return
	var x := view.x + rng.randf_range(-10.0, 10.0)
	var z := view.y + ground + rng.randf_range(-4.0, 6.0)
	var p := Vector3(x, ground, z)
	bolt_mesh.clear_surfaces()
	bolt_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var top := ground + 22.0
	var a := p
	var forks := 0
	while a.y < top:
		var b := a + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.6, 1.4), rng.randf_range(-0.2, 0.2))
		_bolt_line(a, b)
		if forks < 3 and rng.randf() < 0.18:
			forks += 1
			var c := a + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.4, 1.0), 0.0)
			_bolt_line(a, c)
			_bolt_line(c, c + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.4, 1.0), 0.0))
		a = b
	bolt_mesh.surface_end()
	bolt.visible = true
	bolt_time = 0.12 + 0.1 * power
	bolt_light.position = PixelView.shear(p + Vector3(0.0, 1.0, 0.0))
	bolt_light.light_energy = 3.0 * power


func _bolt_line(a: Vector3, b: Vector3) -> void:
	bolt_mesh.surface_set_color(Color(0.92, 0.95, 1.0))
	bolt_mesh.surface_add_vertex(a)
	bolt_mesh.surface_set_color(Color(0.92, 0.95, 1.0))
	bolt_mesh.surface_add_vertex(b)


## A few bits of material `m` (Mat) flying off world point `at` in `delay` seconds, when
## the tool strikes: chips of a trunk, crumbs of earth and stone, leaves off a bush.
func burst(at: Vector3, m: int, delay := 0.0) -> void:
	if not enabled:
		return
	_burst_wait.append([delay, at, m])


func _burst_now(at: Vector3, m: int) -> void:
	if _bursts.size() < BURSTS:
		var e := _emitter(BURST_BITS, 0.55, Vector2(PX, PX), 1.0)
		e.one_shot = true
		e.explosiveness = 0.9
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.12
		e.direction = Vector3.UP
		e.spread = 70.0
		e.initial_velocity_min = 1.2
		e.initial_velocity_max = 2.4
		e.gravity = Vector3(0.0, -9.0, 0.0)
		e.scale_amount_min = 1.0
		e.scale_amount_max = 2.0
		(e.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
		_bursts.append(e)
	var p := _bursts[_burst_next]
	_burst_next = (_burst_next + 1) % BURSTS
	var c: Color = BITS.get(Mat.IDS[m] if m >= 0 and m < Mat.IDS.size() else "", BITS[""])
	p.color_ramp = _ramp([c.lightened(0.15), c, c.darkened(0.25)])
	p.position = at
	p.restart()


## Picks where the fireflies come out around screen-plane point `view` (see update)
## once it has moved: over grass, a bush or under a crown, a little above the ground.
func _place_fireflies(view: Vector2, ground: float) -> void:
	if world == null:
		fireflies.position = Vector3(view.x, ground + 1.0, view.y + ground + 1.0)
		return
	if _firefly_home.distance_to(view) < FIREFLY_MOVE:
		return
	_firefly_home = view
	var at := Vector3(view.x, ground + 1.0, view.y + ground + 1.0)
	fireflies.position = at
	var spots := PackedVector3Array()
	var ext := fireflies.emission_box_extents
	for i in FIREFLY_TRIES:
		var x := floori((at.x + rng.randf_range(-ext.x, ext.x)) / CELL)
		var z := floori((at.z + rng.randf_range(-ext.z, ext.z)) / CELL)
		var y: int = world.surface_y(x, z)
		if y <= 0:
			continue
		var top: int = world.get_cell(x, y - 1, z)
		if top != Mat.GRASS and not world.bushes.has(Vector3i(x, y, z)) and world.leaf_col(x, z) == 0:
			continue
		var p := Vector3((x + rng.randf()) * CELL, (y + rng.randf_range(0.5, 2.5)) * CELL, (z + rng.randf()) * CELL)
		spots.append(p - at)
	fireflies.emission_points = spots


func _emitter(amount: int, lifetime: float, size: Vector2, brightness: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = size
	var mat := ShaderMaterial.new()
	mat.shader = ParticleShader
	mat.set_shader_parameter("brightness", brightness)
	mat.set_shader_parameter("sky_only", 1.0)
	quad.material = mat
	p.mesh = quad
	p.extra_cull_margin = 32.0
	add_child(p)
	return p


## A star sparkle: a cross of pixels, its middle white (see sack_glow).
static func _star() -> ImageTexture:
	var n := STAR.size()
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			match STAR[y][x]:
				"o":
					img.set_pixel(x, y, Color(1, 1, 1, 1))
				"x":
					img.set_pixel(x, y, Color(0.8, 0.8, 0.8, 1))
	return ImageTexture.create_from_image(img)


func _ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	return g


func _curve(values: Array) -> Curve:
	var c := Curve.new()
	for i in values.size():
		c.add_point(Vector2(float(i) / (values.size() - 1), values[i]))
	return c


## The stones and logs of a campfire with glowing embers, or `lit` false cold with ash
## and charred logs.
func _campfire_model(lit := true) -> VoxelModel:
	var m := VoxelModel.new()
	var stone := Color(0.55, 0.55, 0.58)
	var log_color := Color(0.45, 0.3, 0.2) if lit else Color(0.22, 0.18, 0.16)
	var ember := Color(1.0, 0.5, 0.2) if lit else Color(0.62, 0.6, 0.58)
	for a in 16:
		var ang := a * TAU / 16.0
		var p := Vector2(7.5, 7.5) + Vector2(cos(ang), sin(ang)) * 5.5
		var s := stone * (0.8 if a % 3 == 0 else 1.0)
		m.set_voxel(Vector3i(roundi(p.x), 0, roundi(p.y)), s)
	for i in range(4, 12):
		m.set_voxel(Vector3i(i, 1, 7), log_color)
		m.set_voxel(Vector3i(i, 1, 8), log_color * 0.85)
		m.set_voxel(Vector3i(7, 2, i), log_color)
		m.set_voxel(Vector3i(8, 2, i), log_color * 0.85)
	for p in [Vector3i(6, 0, 6), Vector3i(9, 0, 9), Vector3i(7, 0, 9), Vector3i(9, 0, 6), Vector3i(6, 1, 9)]:
		m.set_voxel(p, ember)
	return m


## A glow over a sack left by a death, so it is found from afar: a few amber star
## sparkles drifting slowly out of it every way and twinkling out, and a small warm
## light on the ground at night.
func sack_glow(at: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var p := _emitter(10, 2.4, Vector2(STAR.size(), STAR.size()) * PX, 2.2)
	remove_child(p)
	root.add_child(p)
	p.position = at + Vector3(0.0, 0.25, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0.0, 0.05, 0.0)
	p.color_ramp = _ramp([Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.92, 0.55, 1.0), Color(1.0, 0.8, 0.35, 0.3),
		Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.65, 0.2, 0.0)])
	var mat: ShaderMaterial = (p.mesh as QuadMesh).material
	mat.set_shader_parameter("sky_only", 0.0)
	mat.set_shader_parameter("shape", _star())
	p.emitting = true
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.3)
	light.light_energy = 2.5
	light.omni_range = 3.0
	light.omni_attenuation = 0.0
	light.shadow_enabled = false
	light.position = PixelView.shear(at + Vector3(0.0, 0.5, 0.0))
	root.add_child(light)
	return root
