extends Node3D
## Small effects of the air and the light (the user's pick, 2026-11-15): the air
## trembling over burning fires and, in a hot noon, over the open ground (grade.gdshader
## `heat_*`); drops of rain on the screen's edges in a downpour and for a while after
## coming out of water (grade.gdshader `drops`); breath steaming from the player, other
## players and the beasts in a frost and on cold mornings (puffs of particles); and the
## sun's path glittering on the water from the player towards a low sun at sunrise and
## sunset (water.gdshader `sun_path`). Held by Effects (`air`) and stepped by Sky, like
## Wisps. All of it stops with the effects setting, and each can be hidden on its own in
## «Тестирование» → «Отладка» → «Что рисуется» (parts). Cheap: the shimmer, the drops and
## the sun's path are a few lines in passes the picture makes anyway, set only when they
## change; the breath is a few short puffs from a small pool of emitters, looked for five
## times a second and only in the cold.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Warmth := preload("res://src/shared/game/warmth.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")

const PX := 1.0 / 16.0
## The fires whose air trembles at once (grade.gdshader heat_spots), the nearest to the
## middle of the view; how far from it a fire may be, screen-plane units.
const HEAT_FIRES := 4
const HEAT_REACH := 16.0
## The trembling air over a fire, world units: as wide each way from its middle, as high
## over its flames.
const HEAT_HALF := 0.4
const HEAT_HIGH := 1.4
## The ground's air trembles at noon from this many degrees, in full at HAZE_FULL.
const HAZE_FROM := 27.0
const HAZE_FULL := 34.0
## Drops come on the screen in rain this strong (Clock.rain: a downpour or a storm),
## come and go thicker and thinner at DROPS_RATE a second; out of the water they stay
## WET_TIME seconds. When they stop, no more come and the ones on the screen run off
## within DRY_RUN seconds (grade.gdshader screen_drop).
const DROPS_RAIN := 0.7
const DROPS_RATE := 0.5
const DRY_RUN := 1.6
const SWIM_LEFT := 0.6
const WET_TIME := 5.0
## Breath steams at this many degrees and below in full, fading out up to BREATH_MILD;
## on a morning (from an hour before sunrise to MORNING_SPAN of a day after it) up to
## BREATH_MORNING degrees, fainter.
const BREATH_COLD := 2.0
const BREATH_MILD := 7.0
const BREATH_MORNING := 12.0
const MORNING_SPAN := 0.1
## The puffs in the air at once (emitters used in turn), how many breathe (the nearest
## to the view, within BREATH_REACH screen-plane units), how often they are looked for.
const PUFFS := 8
const BREATHERS := 6
const BREATH_REACH := 12.0
const BREATH_LOOK := 0.2
## Seconds between two breaths standing and moving, and the beasts lighter than this
## (kg) breathe out too little to see.
const BREATH_REST := 3.4
const BREATH_RUN := 1.7
const BREATH_MASS := 1.5
## The sun's path shows while the sun is lower than this (Sky.sun_height), and fades in
## as it rises; the moon's is this strong under a full moon.
const PATH_HIGH := 0.35
## The sun's path moves slowly: looked at this often, seconds.
const PATH_LOOK := 0.25
const MOON_PATH := 0.6

## The parts as «Что рисуется» names them (RenderToggles), and the ones hidden there.
const HEAT := "effects: heat shimmer"
const DROPS := "effects: drops on the screen"
const BREATH := "effects: breath steam"
const SUN_PATH := "effects: sun path on water"
var hidden := {}
## The settings of each (see Settings.apply).
var heat_on := true
var drops_on := true
var breath_on := true
var path_on := true

var game
## The effects (Effects): the setting, the fires, the emitter maker.
var fx
var _puffs: Array[CPUParticles3D] = []
var _puff_next := 0
var _look := 0.0
## Each one breathing (by key): where in its breath it was when last looked at, 0..1.
var _breaths := {}
var _breath := 0.0
var _now := false
## The air where the player is (Warmth.air), looked at every BREATH_LOOK seconds.
var _air := 15.0
## Seconds to the next look at the sun's path, and whether heat spots were given.
var _path_in := 0.0
var _heat_shown := true
var _drops := 0.0
## The drops' clock, and when on it the screen began to dry (-1 while it does not) and
## how thick the drops were then.
var _drop_clock := 0.0
var _dry_at := -1.0
var _dry_was := 0.0
var _wet := 0.0
var _was_swimming := false
## Seconds since the player was last swimming.
var _out_for := 100.0
## What was last given to the shaders, so they are set only on a change.
var _set := {}


func _init(g, effects) -> void:
	game = g
	fx = effects


## The parts of the picture this draws, for «Что рисуется»: [name, Callable(hide)].
func parts() -> Array:
	var out := []
	for name: String in [HEAT, DROPS, BREATH, SUN_PATH]:
		out.append([name, func(hide: bool) -> void:
			if hide:
				hidden[name] = true
			else:
				hidden.erase(name)])
	return out


## Steps the effects by `delta` seconds: `sky` (Sky) gives the light and the sun, `clock`
## (Clock) the weather and the time; `indoor` is true under a roof or in a cave.
func update(delta: float, sky, clock, indoor: bool) -> void:
	if game.player == null:
		return
	_heat(heat_on and not hidden.has(HEAT), sky, clock, indoor)
	_rain_drops(delta, drops_on and not hidden.has(DROPS), clock, indoor)
	_path_in -= delta
	if _path_in <= 0.0:
		_path_in = PATH_LOOK
		_sun_path(path_on and not hidden.has(SUN_PATH), sky, clock, indoor)
	_breathe(delta, breath_on and not hidden.has(BREATH), sky, clock)


## Gives a shader parameter to `mat` only when it changed.
func _give(mat: ShaderMaterial, key: String, value) -> void:
	if mat == null or _set.get(key) == value:
		return
	_set[key] = value
	mat.set_shader_parameter(key, value)


## The air over the HEAT_FIRES burning fires nearest the view trembles, and in a hot
## noon under the open sky the air over the ground in patches.
func _heat(on: bool, sky, clock, indoor: bool) -> void:
	var view = game.view
	if view == null or view.camera == null:
		return
	var mat: ShaderMaterial = view.grade_mat
	var spots := PackedVector4Array()
	var power := Vector4.ZERO
	if on and not fx.fires.is_empty():
		var at: Vector2 = view.cam_target
		var near: Array = []
		for f: Dictionary in fx.fires:
			var d := PixelView.screen_plane(f.at).distance_to(at)
			if d < HEAT_REACH:
				near.append([d, f])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var cam: Camera3D = view.camera
		for n: Array in near.slice(0, HEAT_FIRES):
			var f: Dictionary = n[1]
			# The flames' base and the top of the trembling air, as pixels of the picture
			# (a world unit is PIXELS_PER_UNIT of them across).
			# The more wood in it, the stronger, higher and wider the air trembles over it
			# (Effects.fire_strength keeps its fuel share; a fire without one is full).
			var fuel: float = f.get("fuel", 1.0)
			var high := HEAT_HIGH * lerpf(0.35, 1.3, fuel)
			var base: Vector2 = cam.unproject_position(PixelView.shear(f.at + Vector3(0.0, 0.25, 0.0)))
			var top: Vector2 = cam.unproject_position(PixelView.shear(f.at + Vector3(0.0, 0.25 + high, 0.0)))
			if fuel <= 0.02:
				continue
			power[spots.size()] = snappedf(lerpf(0.15, 1.0, fuel), 0.05)
			spots.append(Vector4(roundf(base.x), roundf(base.y), roundf(HEAT_HALF * lerpf(0.6, 1.2, fuel) * PixelView.PIXELS_PER_UNIT),
				roundf(maxf(3.0, base.y - top.y))))
	# No fire near: the spots are cleared once.
	if not spots.is_empty() or _heat_shown:
		_heat_shown = not spots.is_empty()
		while spots.size() < HEAT_FIRES:
			spots.append(Vector4(-1000.0, -1000.0, 1.0, 1.0))
		_give(mat, "heat_spots", spots)
		_give(mat, "heat_power", power)
	# The air is looked at with the breath (BREATH_LOOK), not every frame.
	var haze := 0.0
	if on and not indoor:
		haze = clampf((_air - HAZE_FROM) / (HAZE_FULL - HAZE_FROM), 0.0, 1.0) \
			* smoothstep(0.6, 0.95, sky.sun_light) * (1.0 - clampf(clock.clouds, 0.0, 1.0)) * (1.0 - clock.rain)
	_give(mat, "heat_haze", snappedf(haze, 0.02))


## Drops on the screen in a downpour under the open sky, and for WET_TIME seconds after
## the player comes out of the water.
func _rain_drops(delta: float, on: bool, clock, indoor: bool) -> void:
	var view = game.view
	if view == null:
		return
	# Out of the water only after SWIM_LEFT seconds out: a jump in the water is still a swim.
	if game.player.body != null and game.player.body.swimming:
		_out_for = 0.0
	else:
		_out_for += delta
	var swimming := _out_for < SWIM_LEFT
	if _was_swimming and not swimming:
		_wet = WET_TIME
	_was_swimming = swimming
	_wet = maxf(0.0, _wet - delta)
	var want := 0.0
	if on and not swimming:
		if not indoor and clock.rain > DROPS_RAIN:
			want = clampf((clock.rain - DROPS_RAIN) / (1.0 - DROPS_RAIN) + 0.4, 0.0, 1.0)
		if _wet > 0.0:
			want = maxf(want, 0.8)
	if want <= 0.0 and _drops > 0.0:
		# The rain has stopped (or one went under a roof, into the water): no more drops
		# come, the ones there run off. Those still running off from before keep running.
		if _dry_at < 0.0:
			_dry_at = _drop_clock
			_dry_was = _drops
		_drops = 0.0
	elif want > 0.0:
		# New drops come thin and thicken; the ones running off finish their run.
		_drops = move_toward(_drops, want, delta * DROPS_RATE)
	if _dry_at >= 0.0 and _drop_clock - _dry_at > DRY_RUN:
		_dry_at = -1.0
	var active := _drops > 0.0 or _dry_at >= 0.0
	if active:
		_drop_clock += delta
	elif _drop_clock > 0.0:
		_drop_clock = 0.0
	_give(view.grade_mat, "drop_state", Vector4(_drop_clock, snappedf(_drops, 0.02), _dry_at, _dry_was) if active
		else Vector4(0.0, 0.0, -1.0, 0.0))
	_give(view.grade_mat, "view_margin", float(PixelView.MARGIN))


## The sun's path on the water: from the player towards the sun along the ground, while
## it is low, the sky clear enough and the water not frozen; at night the moon's, silver
## and fainter, by how full it is.
func _sun_path(on: bool, sky, clock, indoor: bool) -> void:
	var mat: ShaderMaterial = game.water_mat
	var path := Vector4.ZERO
	var h: float = sky.sun_height
	var c := Color(1.0, 0.82, 0.5)
	if on and not indoor:
		var k := 0.0
		if h > 0.0:
			k = smoothstep(0.0, 0.05, h) * smoothstep(PATH_HIGH, PATH_HIGH * 0.5, h)
			# Golden higher up, red as it touches the horizon.
			c = Color(1.0, 0.45, 0.25).lerp(Color(1.0, 0.82, 0.5), clampf(h / PATH_HIGH, 0.0, 1.0))
		else:
			k = smoothstep(-0.1, -0.3, h) * MOON_PATH * sky.moon
			c = Color(0.72, 0.8, 1.0)
		k *= (1.0 - 0.9 * clampf(clock.clouds, 0.0, 1.0)) * (1.0 - clock.ice()) * (1.0 - clock.rain)
		var flat := Vector2(sky.to_sun.x, sky.to_sun.z)
		if k > 0.02 and flat.length() > 0.01:
			# How steeply the light comes down, for what stands in its way (water.gdshader).
			var rise: float = maxf(sky.to_sun.y, 0.0) / flat.length()
			flat = flat.normalized()
			path = Vector4(snappedf(flat.x, 0.01), snappedf(flat.y, 0.01), snappedf(k, 0.02), snappedf(rise, 0.02))
	_give(mat, "sun_path", path)
	if path.z > 0.0:
		_give(mat, "sun_path_color", Vector3(snappedf(c.r, 0.02), snappedf(c.g, 0.02), snappedf(c.b, 0.02)))


## How much breath steams now, 0..1: by the air where the player is, more on a morning.
func breath_strength(sky, clock) -> float:
	var air := _air
	var k := clampf((BREATH_MILD - air) / (BREATH_MILD - BREATH_COLD), 0.0, 1.0)
	var since: float = fposmod(clock.time_of_day - clock.sunrise() / 24.0 + 0.04, 1.0)
	if since < 0.04 + MORNING_SPAN:
		k = maxf(k, 0.6 * clampf((BREATH_MORNING - air) / (BREATH_MORNING - BREATH_COLD), 0.0, 1.0))
	return k


## The breath of the BREATHERS nearest the view: each breathes out every BREATH_REST
## seconds (BREATH_RUN on the move) on a clock of its own, a puff from its mouth.
func _breathe(delta: float, on: bool, sky, clock) -> void:
	_look -= delta
	if _look > 0.0:
		return
	var step := BREATH_LOOK - _look
	_look = BREATH_LOOK
	_air = Warmth.air(game.world, clock, game.player.position)
	_breath = breath_strength(sky, clock) if on else 0.0
	if _breath <= 0.0:
		_breaths.clear()
		return
	var light := clampf(maxf(sky.sky_light, sky.flash), 0.25, 1.0)
	var view: Vector2 = game.view.cam_target
	var found := []
	_figure_mouths(found, view)
	_beast_mouths(found, view)
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var kept := {}
	for one: Array in found.slice(0, BREATHERS):
		var key = one[1]
		var period: float = BREATH_RUN if one[4] else BREATH_REST
		var was: float = _breaths.get(key, randf())
		var now := was + step / period
		kept[key] = fposmod(now, 1.0)
		if (now >= 1.0 or _now) and one[2].is_finite():
			_puff(one[2], one[3], light)
	_breaths = kept
	_now = false


## Everyone near breathes out at the next look (tools/shot.gd).
func breathe_now() -> void:
	_now = true
	_look = 0.0


## The mouths of the player and the other players: [distance from the view, key, mouth
## (world), way it faces (world xz), moving].
func _figure_mouths(out: Array, view: Vector2) -> void:
	var figures := [["me", game.player]]
	if game.others != null:
		for id in game.others.people:
			figures.append([id, game.others.people[id].figure])
	for f: Array in figures:
		var fig = f[1]
		if fig == null or not is_instance_valid(fig) or not fig.visible:
			continue
		var d := PixelView.screen_plane(fig.position).distance_to(view)
		if d > BREATH_REACH:
			continue
		var turn: float = SpriteSheet.COMPASS.find(fig.facing) / 8.0 * TAU
		var face := Vector2(-sin(turn), cos(turn))
		var high := 0.25 if fig.anim == "sleep" else 0.74
		var mouth: Vector3 = fig.position + Vector3(face.x * 0.2, high, face.y * 0.2)
		out.append([d, f[0], mouth, face, fig.anim == "walk" or fig.anim == "swim" or fig.anim == "jump"])


## The mouths of the beasts drawn (Creatures.muzzle), as _figure_mouths; not birds, fish
## nor the small.
func _beast_mouths(out: Array, view: Vector2) -> void:
	var creatures = game.creatures
	if creatures == null or creatures.wildlife == null:
		return
	for a in creatures.wildlife.animals:
		var spec: Dictionary = AiRules.SPECIES.get(a.kind, {})
		if spec.is_empty() or spec.get("flies", false) or spec.get("swims", false) or spec.get("mass", 0.0) < BREATH_MASS:
			continue
		var d := PixelView.screen_plane(a.pos).distance_to(view)
		if d > BREATH_REACH:
			continue
		var m: Array = creatures.muzzle(a)
		if m.is_empty():
			continue
		out.append([d, "a%d" % a.id, m[0], m[1], a.moving])


## A puff of breath out of `mouth` (world) the way `face` (world xz), lit by `light`.
func _puff(mouth: Vector3, face: Vector2, light: float) -> void:
	if _puffs.size() < PUFFS:
		var e: CPUParticles3D = fx._emitter(8, 1.6, Vector2(PX, PX), 1.0)
		fx.remove_child(e)
		add_child(e)
		e.one_shot = true
		e.explosiveness = 0.75
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.02
		e.spread = 35.0
		e.initial_velocity_min = 0.5
		e.initial_velocity_max = 0.85
		e.damping_min = 0.6
		e.damping_max = 0.9
		e.gravity = Vector3(0.0, 0.1, 0.0)
		e.scale_amount_min = 1.0
		e.scale_amount_max = 3.0
		e.scale_amount_curve = fx._curve([0.5, 1.0])
		(e.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
		_puffs.append(e)
	var p := _puffs[_puff_next]
	_puff_next = (_puff_next + 1) % PUFFS
	var a := 0.75 * _breath
	p.color_ramp = fx._ramp([Color(0.94, 0.96, 1.0, 0.0), Color(0.94, 0.96, 1.0, a), Color(0.92, 0.94, 0.98, a * 0.6),
		Color(0.9, 0.92, 0.96, 0.0)])
	(p.mesh as QuadMesh).material.set_shader_parameter("light", light)
	p.direction = Vector3(face.x, 0.35, face.y)
	p.position = mouth
	p.restart()
