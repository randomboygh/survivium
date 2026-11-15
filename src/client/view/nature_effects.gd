extends Node3D
## Small life in the air and on the ground (the user's pick, 2026-11-15): dandelion fluff
## drifting on the wind on summer days, flashing white as it turns in the sun; midges
## dancing in a cloud by the water on warm evenings, and over the head of one who stands
## still there; dragonflies hovering and darting over the water on summer days; and dust
## (or snow) kicked up from under the feet on dry sand, dirt and snow. Held by Effects
## (`nature`), stepped by Sky. The settings «Жизнь в воздухе» (`on`) and «Дыхание и
## пыль» (`dust_on`); each part can be hidden on its own in «Что рисуется» (parts).
## Cheap: three emitters and a pool of four for the dust, three small quads for the
## dragonflies, their spots picked again only when the view has moved.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Warmth := preload("res://src/shared/game/warmth.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const ParticleShader := preload("res://shaders/particle.gdshader")

const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## Midges come out on evenings this warm and over (degrees), a cloud over one standing
## still this many seconds.
const MIDGE_WARM := 12.0
const MIDGE_IDLE := 4.0
## Dragonflies at once; how far from their spot over the water they go (world units),
## how long they hover between two darts (seconds) and how fast a dart is.
const DRAGONFLIES := 3
const FLY_ROAM := 1.6
const FLY_HOVER := Vector2(0.4, 2.2)
const FLY_DART := 5.0
## Spots by the water are looked for again when the view moved this far, from this many
## columns.
const SPOTS_MOVE := 5.0
const SPOTS_TRIES := 60
## Dust: emitters used in turn, and world units walked from one puff to the next.
const DUSTS := 4
const DUST_STEP := 1.0
## The step sounds of the materials that raise dust when dry or lie as snow
## (the materials' `step`, Mat.RECORDS).
const DUSTY_STEPS := ["step_dirt", "step_sand"]
const SNOWY_STEPS := ["step_snow"]
## A dragonfly: its wings up, then down (x the body, o the wings, h the head).
const FLY_UP := ["o.o..", "xxxxh", "....."]
const FLY_DOWN := [".....", "xxxxh", "o.o.."]

## The parts as «Что рисуется» names them (RenderToggles).
const FLUFF_PART := "effects: fluff in the sun"
const MIDGES_PART := "effects: midges"
const FLIES_PART := "effects: dragonflies"
const DUST_PART := "effects: dust under the feet"
var hidden := {}

var game
var fx
## The settings: life in the air, and the dust under the feet.
var on := true
var dust_on := true
var fluff: CPUParticles3D
## The midges by the water, and over the head of one standing still.
var midges: CPUParticles3D
var head_midges: CPUParticles3D
var flies: Array[MeshInstance3D] = []
## Each dragonfly: {"home": its spot, "to": where it darts, "wait": seconds left to
## hover, "flap": seconds to the next wing beat}.
var _fly_state: Array[Dictionary] = []
var _fly_shapes: Array[Texture2D] = []
## Spots over water near the view (world points), and where the view was when they were picked.
var _spots: Array[Vector3] = []
var _spots_home := Vector2.INF
var _dusts: Array[CPUParticles3D] = []
var _dust_next := 0
## Each one walking (by key): [where it was, world units walked since its last puff].
var _walkers := {}
## The air where the player is (Warmth.air), and seconds to the next look at it.
var _air := 15.0
var _air_in := 0.0


func _init(g, effects) -> void:
	game = g
	fx = effects


func _ready() -> void:
	fluff = _own(fx._emitter(14, 9.0, Vector2(PX, PX), 1.0))
	fluff.direction = Vector3(1.0, 0.15, 0.0)
	fluff.spread = 40.0
	fluff.initial_velocity_min = 0.25
	fluff.initial_velocity_max = 0.5
	fluff.gravity = Vector3(0.0, -0.01, 0.0)
	fluff.emission_box_extents = Vector3(18.0, 1.2, 12.0)
	fluff.scale_amount_min = 1.0
	fluff.scale_amount_max = 2.0
	# Turning in the wind it catches the sun now and then: a flash in its drift.
	fluff.color_ramp = fx._ramp([Color(1, 1, 1, 0.0), Color(0.95, 0.95, 0.92, 0.75), Color(1, 1, 1, 1.0),
		Color(0.95, 0.95, 0.92, 0.6), Color(1, 1, 1, 1.0), Color(0.95, 0.95, 0.92, 0.7), Color(1, 1, 1, 0.0)])
	fx._brightness(fluff, 1.25)

	midges = _midge_cloud()
	head_midges = _midge_cloud()

	_fly_shapes = [_shape(FLY_UP), _shape(FLY_DOWN)]
	for i in DRAGONFLIES:
		var m := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(5.0, 3.0) * PX
		quad.center_offset = Vector3(0.0, 1.5 * PX, 0.0)
		var mat := ShaderMaterial.new()
		mat.shader = ParticleShader
		mat.set_shader_parameter("shape", _fly_shapes[0])
		mat.set_shader_parameter("sky_only", 0.0)
		quad.material = mat
		m.mesh = quad
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.extra_cull_margin = 16.0
		m.visible = false
		add_child(m)
		flies.append(m)
		_fly_state.append({"home": Vector3.INF, "to": Vector3.ZERO, "wait": 0.0, "flap": 0.0})


## Moves emitter `e` made by Effects under this node.
func _own(e: CPUParticles3D) -> CPUParticles3D:
	fx.remove_child(e)
	add_child(e)
	return e


## A cloud of midges dancing round its node: dark specks darting every way, close in.
func _midge_cloud() -> CPUParticles3D:
	# A dense little cloud of specks dancing in place, some caught by the low sun.
	var e := _own(fx._emitter(30, 0.9, Vector2(PX, PX), 1.0))
	e.local_coords = true
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.3
	e.direction = Vector3.UP
	e.spread = 180.0
	e.initial_velocity_min = 0.15
	e.initial_velocity_max = 0.4
	e.gravity = Vector3.ZERO
	var specks := Gradient.new()
	specks.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	specks.colors = PackedColorArray([Color(0.1, 0.1, 0.08), Color(0.95, 0.85, 0.6), Color(0.1, 0.1, 0.08)])
	e.color_initial_ramp = specks
	e.scale_amount_min = 1.0
	e.scale_amount_max = 2.0
	(e.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
	return e


## A picture of `rows` (x the body, h the head, o the wings), for the particle shader's `shape`.
static func _shape(rows: Array) -> ImageTexture:
	var w: int = rows[0].length()
	var img := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in w:
			match rows[y][x]:
				"x":
					img.set_pixel(x, y, Color(0.18, 0.42, 0.55))
				"h":
					img.set_pixel(x, y, Color(0.1, 0.22, 0.3))
				"o":
					img.set_pixel(x, y, Color(0.86, 0.93, 0.95))
	return ImageTexture.create_from_image(img)


## The parts of the picture this draws, for «Что рисуется»: [name, Callable(hide)].
func parts() -> Array:
	var out := []
	for name: String in [FLUFF_PART, MIDGES_PART, FLIES_PART, DUST_PART]:
		out.append([name, func(hide: bool) -> void:
			if hide:
				hidden[name] = true
			else:
				hidden.erase(name)])
	return out


## Steps the effects by `delta` seconds (`sky` Sky, `clock` Clock).
func update(delta: float, sky, clock, indoor: bool) -> void:
	var player = game.player
	if player == null or game.view == null:
		return
	var view: Vector2 = game.view.cam_target
	var ground: float = player.position.y
	var summer: bool = clock.season == 1 or (clock.season == 0 and clock.day % 30 > 15)
	var calm: bool = clock.rain < 0.15 and clock.snowing < 0.15 and clock.storm_wind < 1.2
	var outside := on and not indoor
	var light := clampf(maxf(sky.sky_light, sky.flash), 0.2, 1.0)
	# Fluff over the meadows on summer days, with the wind.
	var fluffy: bool = outside and not hidden.has(FLUFF_PART) and summer and calm and sky.daylight > 0.6
	fluff.position = Vector3(view.x, ground + 1.2, view.y + ground + 1.2)
	fx._blow(fluff, clock.wind_dir(), 1.0, 0.15)
	_emit(fluff, fluffy)
	# The air is looked at twice a second.
	_air_in -= delta
	if _air_in <= 0.0:
		_air_in = 0.5
		_air = Warmth.air(game.world, clock, player.position)
	var warm: bool = outside and calm and (summer or clock.season == 0) and _air >= MIDGE_WARM
	if (warm or outside) and (_spots_home.distance_to(view) >= SPOTS_MOVE):
		_find_spots(view, ground)
	# Midges on warm evenings, about sunset (Sky.sun_height near 0).
	var evening: bool = warm and absf(sky.sun_height) < 0.4 and clock.time_of_day > 0.5
	var by_water: bool = evening and not hidden.has(MIDGES_PART) and not _spots.is_empty()
	if by_water and not midges.emitting:
		# The spot by the water nearest the view, where they will be seen.
		var best: Vector3 = _spots[0]
		for p: Vector3 in _spots:
			if PixelView.screen_plane(p).distance_to(view) < PixelView.screen_plane(best).distance_to(view):
				best = p
		midges.position = best + Vector3(0.0, 0.7, 0.0)
	_emit(midges, by_water)
	var idle: bool = evening and not hidden.has(MIDGES_PART) and game.view.idle > MIDGE_IDLE
	head_midges.position = player.position + Vector3(0.0, 1.25, 0.0)
	_emit(head_midges, idle)
	for e: CPUParticles3D in [midges, head_midges]:
		if e.emitting:
			(e.mesh as QuadMesh).material.set_shader_parameter("light", light)
	_dragonflies(delta, outside and summer and calm and sky.daylight > 0.6 and not hidden.has(FLIES_PART), light)
	_dust(clock, dust_on and not hidden.has(DUST_PART), indoor)


## Switches emitter `e` only when it changes (each switch restarts its emission).
static func _emit(e: CPUParticles3D, want: bool) -> void:
	if e.emitting != want:
		e.emitting = want


## Picks spots over open water round the screen-plane point `view`.
func _find_spots(view: Vector2, ground: float) -> void:
	_spots_home = view
	_spots.clear()
	var water = fx.water
	if water == null:
		return
	for i in SPOTS_TRIES:
		var x := floori((view.x + randf_range(-12.0, 12.0)) / CELL)
		var z := floori((view.y + ground + randf_range(-8.0, 8.0)) / CELL)
		var top: float = water.water_top(x, z)
		if top != -INF:
			_spots.append(Vector3((x + 0.5) * CELL, top, (z + 0.5) * CELL))


## Dragonflies over the water near the view: each hovers a while over its spot, then
## darts off to another point near it, its wings beating.
func _dragonflies(delta: float, want: bool, light: float) -> void:
	for i in flies.size():
		var m := flies[i]
		var st := _fly_state[i]
		var show := want and not _spots.is_empty()
		if show and (not st.home.is_finite() or PixelView.screen_plane(st.home).distance_to(game.view.cam_target) > 16.0):
			st.home = _spots.pick_random() + Vector3(0.0, 0.5, 0.0)
			m.position = st.home
			st.to = st.home
		if m.visible != show:
			m.visible = show
		if not show:
			st.home = Vector3.INF
			continue
		var mat: ShaderMaterial = (m.mesh as QuadMesh).material
		st.flap -= delta
		if st.flap <= 0.0:
			st.flap = 0.05
			mat.set_shader_parameter("shape", _fly_shapes[1] if mat.get_shader_parameter("shape") == _fly_shapes[0] else _fly_shapes[0])
			mat.set_shader_parameter("light", light)
		var gap: Vector3 = st.to - m.position
		if gap.length() > 0.02:
			m.position += gap.limit_length(FLY_DART * delta)
			var s := PixelView.screen_dir(Vector2(gap.x, gap.z))
			if absf(s.x) > 0.01:
				m.scale.x = signf(s.x)
		else:
			st.wait -= delta
			# Hovering, it shivers in place by a pixel now and then.
			if randf() < 0.1:
				m.position = st.to + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * PX
			if st.wait <= 0.0:
				st.wait = randf_range(FLY_HOVER.x, FLY_HOVER.y)
				var a := randf() * TAU
				st.to = st.home + Vector3(cos(a), randf_range(-0.2, 0.3), sin(a)) * randf_range(0.4, FLY_ROAM)


## Dust kicked up from under the feet of the player and the other players walking on dry
## sand or dirt, snow where it lies on the open ground.
func _dust(clock, want: bool, indoor: bool) -> void:
	var figures := [["me", game.player]]
	if game.others != null:
		for id in game.others.people:
			figures.append([id, game.others.people[id].figure])
	var seen := {}
	for f: Array in figures:
		var fig = f[1]
		if fig == null or not is_instance_valid(fig) or fig.body == null:
			continue
		seen[f[0]] = true
		var at: Vector3 = fig.position
		var st: Array = _walkers.get(f[0], [at, 0.0])
		var walked: float = st[1] + Vector2(at.x - st[0].x, at.z - st[0].z).length()
		if walked > 3.0:
			walked = 0.0
		if walked >= DUST_STEP:
			walked = 0.0
			if want and fig.body.on_ground and fig.body.water_depth <= 0.0:
				_puff(at, clock, indoor)
		_walkers[f[0]] = [at, walked]
	for key in _walkers.keys():
		if not seen.has(key):
			_walkers.erase(key)


## A puff of dust (or snow) at the feet at `at`, if what they stand on raises any.
func _puff(at: Vector3, clock, indoor: bool) -> void:
	var c := Vector3i((at / CELL + Vector3(0.0, -0.1, 0.0)).floor())
	var m: int = game.world.get_cell(c.x, c.y, c.z) if game.world != null else 0
	if m <= 0 or m >= Mat.COUNT:
		return
	var step: String = Mat.RECORDS[m].get("step", "")
	var color := Color.TRANSPARENT
	if (clock.snow > 0.35 and not indoor) or step in SNOWY_STEPS:
		color = Color(0.94, 0.96, 1.0)
	elif step in DUSTY_STEPS and clock.wet < 0.3:
		color = PixelTextures.tint(m).lightened(0.25)
	if color.a == 0.0:
		return
	if _dusts.size() < DUSTS:
		var e := _own(fx._emitter(5, 0.5, Vector2(PX, PX), 1.0))
		e.one_shot = true
		e.explosiveness = 0.9
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.06
		e.direction = Vector3.UP
		e.spread = 75.0
		e.initial_velocity_min = 0.3
		e.initial_velocity_max = 0.7
		e.gravity = Vector3(0.0, -2.0, 0.0)
		e.damping_min = 1.5
		e.damping_max = 2.5
		e.scale_amount_min = 1.0
		e.scale_amount_max = 2.0
		(e.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
		_dusts.append(e)
	var p := _dusts[_dust_next]
	_dust_next = (_dust_next + 1) % DUSTS
	p.color_ramp = fx._ramp([Color(color, 0.85), Color(color, 0.6), Color(color, 0.0)])
	(p.mesh as QuadMesh).material.set_shader_parameter("light", clampf(game.sky.sky_light, 0.25, 1.0) if game.sky != null else 1.0)
	p.position = at + Vector3(0.0, 0.04, 0.0)
	p.restart()
