extends Node3D
## Pixel particle effects and lights: campfires, rain, snow, fireflies, falling
## leaves and floating pollen. Everything is drawn with particle.gdshader as 1-2 px
## squares. Weather emitters follow the view; `update()` switches them by weather,
## season and time of day.

const PixelView := preload("res://src/client/pixel_view.gd")
const VoxelModel := preload("res://src/client/voxel_model.gd")
const ParticleShader := preload("res://shaders/particle.gdshader")

const PX := 1.0 / 16.0
## World units around a fire where snow melts and the ground stays dry.
const HEAT_RADIUS := 3.0

var rain: CPUParticles3D
var snowfall: CPUParticles3D
var fireflies: CPUParticles3D
var leaves: CPUParticles3D
var pollen: CPUParticles3D
## Each fire: {"light": OmniLight3D, "base": float, "unit": Vector3i (the world unit it stands in)}
var fires: Array = []
## The effects setting: off stops the weather and the ambient particles.
var enabled := true
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

	pollen = _emitter(24, 6.0, Vector2(PX, PX), 1.0)
	pollen.direction = Vector3(1.0, 0.2, 0.0)
	pollen.spread = 60.0
	pollen.initial_velocity_min = 0.1
	pollen.initial_velocity_max = 0.3
	pollen.gravity = Vector3.ZERO
	pollen.emission_box_extents = Vector3(18.0, 1.5, 12.0)
	pollen.color_ramp = _ramp([Color(1, 1, 0.85, 0.0), Color(1, 1, 0.85, 0.7), Color(1, 1, 0.85, 0.0)])


## A campfire one world unit square with its north-west corner at `corner`: stones,
## logs, flames, sparks, smoke and a flickering light, the model drawn with `material`.
func add_campfire(corner: Vector3, material: Material) -> void:
	var model := MeshInstance3D.new()
	model.mesh = _campfire_model().build_mesh()
	model.material_override = material
	model.scale = Vector3.ONE / 16.0
	model.position = corner
	model.extra_cull_margin = 16.0
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
	light.omni_attenuation = 1.2
	light.position = PixelView.shear(c + Vector3(0.0, 0.6, 0.0))
	add_child(light)
	fires.append({"light": light, "base": 1.8, "unit": Vector3i(c.floor())})


## Moves the weather emitters over the view and turns them on and off.
## `view` is the screen-plane centre; `ground` the height the player stands on.
## Warmth around the fires for the shaders (heat_map, see common.gdshaderinc): one
## texel per world unit, r = heat falling off over HEAT_RADIUS units, g = the height of
## the fire's unit. Snow melts and rain dries there.
func heat_map(size_x: int, size_z: int) -> ImageTexture:
	var img := Image.create_empty(size_x, size_z, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var r := ceili(HEAT_RADIUS)
	for f in fires:
		var c: Vector3i = f.unit
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := c.x + dx
				var z := c.z + dz
				if x < 0 or z < 0 or x >= size_x or z >= size_z:
					continue
				var heat := clampf(1.3 - Vector2(dx, dz).length() / HEAT_RADIUS, 0.0, 1.0)
				if heat > img.get_pixel(x, z).r:
					img.set_pixel(x, z, Color(heat, c.y / 64.0, 0.0, 1.0))
	return ImageTexture.create_from_image(img)


func update(delta: float, view: Vector2, ground: float, raining: bool, winter: bool, season: int, daylight: float, indoor: bool) -> void:
	var sky := ground + 7.0
	# A point at height h shows at screen-plane y = z - h, so emitters sit further south.
	rain.position = Vector3(view.x, sky, view.y + sky)
	snowfall.position = rain.position
	leaves.position = Vector3(view.x, ground + 5.0, view.y + ground + 5.0)
	fireflies.position = Vector3(view.x, ground + 1.0, view.y + ground + 1.0)
	pollen.position = Vector3(view.x, ground + 1.5, view.y + ground + 1.5)
	rain.emitting = enabled and raining and not winter and not indoor
	snowfall.emitting = enabled and raining and winter and not indoor
	leaves.emitting = enabled and season == 2 and not indoor
	fireflies.emitting = enabled and daylight < 0.3 and (season == 0 or season == 1) and not raining
	pollen.emitting = enabled and daylight > 0.6 and (season == 0 or season == 1) and not raining and not indoor
	flicker_clock += delta
	if flicker_clock > 0.09:
		flicker_clock = 0.0
		# Fires matter at night; by day they only warm the ground a little.
		for f in fires:
			f.light.light_energy = f.base * lerpf(1.0, 0.15, daylight) * rng.randf_range(0.8, 1.1)


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


func _campfire_model() -> VoxelModel:
	var m := VoxelModel.new()
	var stone := Color(0.55, 0.55, 0.58)
	var log_color := Color(0.45, 0.3, 0.2)
	var ember := Color(1.0, 0.5, 0.2)
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
