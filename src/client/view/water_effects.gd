extends Node3D
## Small effects on the water (the user's pick, 2026-11-15): rings spreading where a fish
## jumps, a thing shot or thrown lands, one wades or swims; a splash where a body comes
## into the water from a fall or a jump; steam rising off open water on cold mornings
## and in frost; fires, torches and lamps glittering on the water in a path towards the
## viewer (water.gdshader `fire_glints`); and the people and the beasts by the water
## mirrored in it (sprite_mirror.gdshader). Held by Effects (`water`), stepped by Sky.
## The setting «Вода» (Settings `water_fx`): 0 none, 1 all but the mirroring, 2 all; each
## can be hidden on its own in «Что рисуется» (parts). Cheap: rings and splashes come
## from a small pool of emitters used in turn, the steam is one emitter whose spots are
## picked again only when the view has moved, the glints are a few lines of the water's
## shader, and at most MIRRORS figures are mirrored.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Warmth := preload("res://src/shared/game/warmth.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const MirrorShader := preload("res://shaders/sprite_mirror.gdshader")

const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## Rings and splashes at once (emitters used in turn).
const RINGS := 6
## How far from the middle of the view (screen-plane units) a fish may jump, and the
## seconds between two jumps.
const FISH_REACH := 12.0
const FISH_GAP := Vector2(3.0, 10.0)
## World units walked in shallow water from one ring to the next, seconds between two
## rings of one swimming.
const WADE_STEP := 0.9
const SWIM_RING := 1.1
## The glowing wake: a point of it every WAKE_STEP units swum, at most WAKE_POINTS, each
## fading out over WAKE_LIFE seconds.
const WAKE_STEP := 0.5
const WAKE_POINTS := 8
const WAKE_LIFE := 3.5
## Falling this fast (world units a second) into the water splashes.
const SPLASH_FALL := 3.0
## The steam: emitter spots looked for again when the view moved this far, from this many
## columns; it rises at this many degrees and below in full, none over STEAM_MILD.
const STEAM_MOVE := 4.0
const STEAM_TRIES := 90
const STEAM_COLD := 2.0
const STEAM_MILD := 9.0
## The lights that glitter on the water at once, how far from the view they may be.
const GLINTS := 4
const GLINT_REACH := 16.0
## Figures mirrored at once, the nearest the view within MIRROR_REACH; a figure is
## mirrored while there is open water within MIRROR_LOOK cells round its feet.
const MIRRORS := 8
const MIRROR_REACH := 14.0
const MIRROR_LOOK := 3
## How far over the feet the water may come (a swimmer's feet hang under it) and how
## far under them it may lie (one standing up the bank), world units.
const MIRROR_DEEP := 1.6
const MIRROR_HIGH := 1.2

## Seconds between two looks at the steam and the glints.
const SLOW_LOOK := 0.2

## The parts as «Что рисуется» names them (RenderToggles).
const RINGS_PART := "effects: rings and splashes"
const STEAM_PART := "effects: steam over water"
const GLINTS_PART := "effects: lights glittering on water"
const MIRRORS_PART := "effects: reflections in water"
var hidden := {}

var game
var fx
## The setting «Вода»: 0 none, 1 all but the mirroring, 2 all.
var level := 2
var _rings: Array[CPUParticles3D] = []
var _splashes: Array[CPUParticles3D] = []
var _ring_next := 0
var _fish_in := 2.0
## Each one watched (by key): {"was": [in water, swimming], "fall": the speed it fell,
## "walked": world units walked in water since its last ring, "last": where it was}.
var _bodies := {}
## How brightly the plankton glows at the swimmer, 0..1, by their speed, smoothed, and
## the points of the way they swam, newest first (see _wake).
var _wake_k := 0.0
var _trail: Array[Vector4] = []
var _trail_sent := false
var steam: CPUParticles3D
var _steam_home := Vector2.INF
## Each figure mirrored: its sprite -> its mirror (MeshInstance3D).
var _mirrors := {}
## Each mirror: the sprite's material its picture was last taken from.
var _from := {}
var _look := 0.0
var _slow := 0.0
var _set := {}


func _init(g, effects) -> void:
	game = g
	fx = effects


func _ready() -> void:
	steam = fx._emitter(48, 4.5, Vector2(2.0 * PX, 2.0 * PX), 1.0)
	fx.remove_child(steam)
	add_child(steam)
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	steam.direction = Vector3.UP
	steam.spread = 20.0
	steam.initial_velocity_min = 0.08
	steam.initial_velocity_max = 0.18
	steam.gravity = Vector3(0.0, 0.02, 0.0)
	steam.scale_amount_min = 1.0
	steam.scale_amount_max = 2.0
	steam.scale_amount_curve = fx._curve([0.5, 1.0])
	(steam.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)


## The parts of the picture this draws, for «Что рисуется»: [name, Callable(hide)].
func parts() -> Array:
	var out := []
	for name: String in [RINGS_PART, STEAM_PART, GLINTS_PART, MIRRORS_PART]:
		out.append([name, func(hide: bool) -> void:
			if hide:
				hidden[name] = true
			else:
				hidden.erase(name)])
	return out


func _on(part: String) -> bool:
	return level > 0 and game.player != null and not hidden.has(part) and (part != MIRRORS_PART or level >= 2)


## Steps the effects by `delta` seconds (`sky` Sky, `clock` Clock).
func update(delta: float, sky, clock, indoor: bool) -> void:
	_watch_bodies(delta)
	_fish(delta)
	# The steam and the glints change slowly: looked at a few times a second.
	_slow -= delta
	if _slow <= 0.0:
		_slow = SLOW_LOOK
		_steam(sky, clock, indoor)
		_glints(sky)
	_mirror(delta, sky)


## The top of the open water of column (x, z) of cells at or under level `y` + 2, world
## units; -INF when there is none.
func water_top(x: int, z: int, y := 1 << 20) -> float:
	var w = game.world
	if w == null or w.water_frozen:
		return -INF
	var bits: int = w.water_col(x, z)
	if y < (1 << 20):
		bits &= (1 << mini(y + 3, 62)) - 1
	if bits == 0:
		return -INF
	var top: int = w.top_level(bits)
	if w.get_cell(x, top + 1, z) != Mat.AIR:
		return -INF
	return (top + WorldData.WATER_TOP) * CELL


## Rings spreading from world point `at` on the water's surface (its height is found),
## `big` with a splash of drops thrown up (a fall, a jump of a fish, a thing landing).
## Nothing where there is no open water.
func ring(at: Vector3, big := false) -> void:
	if not _on(RINGS_PART):
		return
	var top := water_top(floori(at.x / CELL), floori(at.z / CELL), floori(at.y / CELL))
	if top == -INF:
		return
	if _rings.size() < RINGS:
		var r: CPUParticles3D = fx._emitter(24, 1.2, Vector2(PX, PX), 1.0)
		fx.remove_child(r)
		add_child(r)
		r.one_shot = true
		r.explosiveness = 1.0
		r.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
		r.direction = Vector3(1.0, 0.0, 0.0)
		r.spread = 180.0
		r.flatness = 1.0
		r.gravity = Vector3.ZERO
		r.damping_min = 0.5
		r.damping_max = 0.5
		r.color_ramp = fx._ramp([Color(0.86, 0.94, 0.96, 0.85), Color(0.8, 0.9, 0.94, 0.5), Color(0.8, 0.9, 0.94, 0.0)])
		(r.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
		_rings.append(r)
		var s: CPUParticles3D = fx._emitter(12, 0.55, Vector2(PX, PX), 1.0)
		fx.remove_child(s)
		add_child(s)
		s.one_shot = true
		s.explosiveness = 0.9
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = 0.08
		s.direction = Vector3.UP
		s.spread = 35.0
		s.initial_velocity_min = 1.0
		s.initial_velocity_max = 2.0
		s.gravity = Vector3(0.0, -9.0, 0.0)
		s.color_ramp = fx._ramp([Color(0.95, 0.98, 1.0), Color(0.82, 0.92, 0.97), Color(0.7, 0.84, 0.92, 0.6)])
		(s.mesh as QuadMesh).material.set_shader_parameter("sky_only", 0.0)
		_splashes.append(s)
	var r := _rings[_ring_next]
	var s := _splashes[_ring_next]
	_ring_next = (_ring_next + 1) % RINGS
	var light := _light()
	var surface := Vector3(at.x, top + 0.02, at.z)
	r.initial_velocity_min = 0.75 if big else 0.45
	r.initial_velocity_max = r.initial_velocity_min
	(r.mesh as QuadMesh).material.set_shader_parameter("light", light)
	r.position = surface
	r.restart()
	if big:
		(s.mesh as QuadMesh).material.set_shader_parameter("light", light)
		s.position = surface
		s.restart()


func _light() -> float:
	var sky = game.sky
	return 1.0 if sky == null else clampf(maxf(sky.sky_light, sky.flash), 0.25, 1.0)


## The player and the other players: a splash where one falls or jumps into the water,
## rings as one wades or swims.
func _watch_bodies(delta: float) -> void:
	var figures := [["me", game.player]]
	if game.others != null:
		for id in game.others.people:
			figures.append([id, game.others.people[id].figure])
	var seen := {}
	for f: Array in figures:
		var fig = f[1]
		if fig == null or not is_instance_valid(fig) or fig.body == null:
			continue
		var key = f[0]
		seen[key] = true
		var b = fig.body
		var at: Vector3 = fig.position
		var st: Dictionary = _bodies.get(key, {"was": false, "walked": 0.0, "last": at, "fall": 0.0})
		var wet: bool = b.water_depth > 0.0 or b.swimming
		var fall: float = (st.last.y - at.y) / maxf(delta, 0.001)
		if wet and not st.was and maxf(fall, st.fall) > SPLASH_FALL:
			ring(at + Vector3(0.0, 0.5, 0.0), true)
		if wet:
			st.walked += Vector2(at.x - st.last.x, at.z - st.last.z).length()
			if st.walked > (WADE_STEP if not b.swimming else SWIM_RING * 0.8):
				st.walked = 0.0
				ring(at + Vector3(0.0, 0.5, 0.0))
		if fig == game.player:
			_wake(at, Vector2(at.x - st.last.x, at.z - st.last.z), delta, wet)
		st.was = wet
		st.fall = fall
		st.last = at
		_bodies[key] = st
	for key in _bodies.keys():
		if not seen.has(key):
			_bodies.erase(key)


## The glowing plankton's wake along the way the player swam (water.gdshader
## wake_trail): a point left every WAKE_STEP units moved in the water, each fading out
## over WAKE_LIFE seconds; how bright at the swimmer by how fast they go, eased.
func _wake(at: Vector3, moved: Vector2, delta: float, wet: bool) -> void:
	var speed := moved.length() / maxf(delta, 0.001)
	var want := clampf(speed / 2.0, 0.0, 1.0) if wet else 0.0
	_wake_k = move_toward(_wake_k, want, delta * 2.0)
	for i in range(_trail.size() - 1, -1, -1):
		var p: Vector4 = _trail[i]
		p.z -= delta / WAKE_LIFE
		if p.z <= 0.0:
			_trail.remove_at(i)
		else:
			_trail[i] = p
	var water_y := at.y + 0.25
	if wet and _wake_k > 0.05:
		if _trail.is_empty() or Vector2(_trail[0].x, _trail[0].y).distance_to(Vector2(at.x, at.z)) >= WAKE_STEP:
			_trail.insert(0, Vector4(at.x, at.z, _wake_k, water_y))
			if _trail.size() > WAKE_POINTS:
				_trail.resize(WAKE_POINTS)
	if _trail.is_empty() and not _trail_sent and _wake_k <= 0.0 and _set.get("wake_now", 0.0) == 0.0:
		return
	_trail_sent = not _trail.is_empty()
	var points := PackedVector4Array(_trail)
	while points.size() < WAKE_POINTS:
		points.append(Vector4(0.0, 0.0, 0.0, -1000.0))
	game.water_mat.set_shader_parameter("wake_trail", points)
	var now := snappedf(_wake_k, 0.05)
	if _set.get("wake_now", 0.0) != now:
		_set["wake_now"] = now
		game.water_mat.set_shader_parameter("wake_now", now)


## Now and then a fish near the view jumps: a splash and rings over it.
func _fish(delta: float) -> void:
	_fish_in -= delta
	if _fish_in > 0.0:
		return
	_fish_in = randf_range(FISH_GAP.x, FISH_GAP.y)
	var creatures = game.creatures
	if creatures == null or creatures.wildlife == null or game.view == null:
		return
	var view: Vector2 = game.view.cam_target
	var near := []
	for a in creatures.wildlife.animals:
		if not AiRules.SPECIES.get(a.kind, {}).get("swims", false):
			continue
		if PixelView.screen_plane(a.pos).distance_to(view) < FISH_REACH:
			near.append(a)
	if not near.is_empty():
		ring(near.pick_random().pos + Vector3(0.0, 0.6, 0.0), true)


## Steam rising thinly off the open water near the view in a frost and on cold mornings.
func _steam(sky, clock, indoor: bool) -> void:
	var k := 0.0
	if _on(STEAM_PART) and not indoor:
		var air := Warmth.air(game.world, clock, game.player.position)
		k = clampf((STEAM_MILD - air) / (STEAM_MILD - STEAM_COLD), 0.0, 1.0)
		var since: float = fposmod(clock.time_of_day - clock.sunrise() / 24.0 + 0.04, 1.0)
		if since > 0.16:
			k *= 0.5
		k *= 1.0 - clock.ice()
	var view: Vector2 = game.view.cam_target
	if k > 0.05 and (_steam_home.distance_to(view) >= STEAM_MOVE or steam.emission_points.is_empty()):
		_place_steam(view, game.player.position.y)
	var on := k > 0.05 and not steam.emission_points.is_empty()
	if on:
		var a := 0.5 * k
		var c := Color(0.92, 0.95, 1.0)
		var key := snappedf(a, 0.02)
		if _set.get("steam") != key:
			_set["steam"] = key
			steam.color_ramp = fx._ramp([Color(c, 0.0), Color(c, key), Color(c, key * 0.7), Color(c, 0.0)])
		(steam.mesh as QuadMesh).material.set_shader_parameter("light", _light())
		var dir: Vector2 = clock.wind_dir()
		steam.gravity = Vector3(dir.x * 0.05, 0.02, dir.y * 0.05)
	if steam.emitting != on:
		steam.emitting = on


## Picks the steam's spots: on open water round the screen-plane point `view`.
func _place_steam(view: Vector2, ground: float) -> void:
	_steam_home = view
	var at := Vector3(view.x, ground, view.y + ground)
	steam.position = at
	var spots := PackedVector3Array()
	for i in STEAM_TRIES:
		var x := floori((at.x + randf_range(-16.0, 16.0)) / CELL)
		var z := floori((at.z + randf_range(-10.0, 12.0)) / CELL)
		var top := water_top(x, z)
		if top == -INF:
			continue
		spots.append(Vector3((x + randf()) * CELL, top + 0.05, (z + randf()) * CELL) - at)
	steam.emission_points = spots


## The GLINTS lights nearest the view glitter on the water: the fires, the lights set
## down and the torches in the player's hands, brighter the darker it is.
func _glints(sky) -> void:
	var mat: ShaderMaterial = game.water_mat
	if mat == null:
		return
	var glints := PackedVector4Array()
	if _on(GLINTS_PART):
		var view: Vector2 = game.view.cam_target
		var dark := clampf(1.0 - sky.sun_light * 1.3, 0.15, 1.0)
		var lights := []
		for f: Dictionary in fx.fires:
			lights.append([f.at, clampf(f.base / fx.FIRE_ENERGY, 0.3, 1.0)])
		for rec: Dictionary in fx.lamps:
			if rec.light.visible:
				lights.append([rec.at, 0.6])
		for flame: CPUParticles3D in fx.torch_flames:
			if flame.emitting:
				lights.append([flame.position, 0.7])
		var near := []
		for l: Array in lights:
			var d := PixelView.screen_plane(l[0]).distance_to(view)
			if d < GLINT_REACH:
				near.append([d, l])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for n: Array in near.slice(0, GLINTS):
			var p: Vector3 = n[1][0]
			glints.append(Vector4(snappedf(p.x, 0.05), snappedf(p.z, 0.05), snappedf(p.y, 0.05), snappedf(n[1][1] * dark, 0.05)))
	while glints.size() < GLINTS:
		glints.append(Vector4(0.0, 0.0, -1000.0, 0.0))
	if _set.get("glints") != glints:
		_set["glints"] = glints
		mat.set_shader_parameter("fire_glints", glints)
	# The way from the world toward the viewer along the ground: the glitter runs that way.
	var toward := Vector2(-PixelView.up.x, -PixelView.up.y)
	if _set.get("toward") != toward:
		_set["toward"] = toward
		mat.set_shader_parameter("glint_toward", toward)


## The MIRRORS figures nearest the view standing by the water are mirrored in it: the
## player, the other players and the beasts but the birds in the air and the fish.
func _mirror(delta: float, sky) -> void:
	_look -= delta
	var on := _on(MIRRORS_PART)
	if _look <= 0.0 or not on:
		_look = 0.25
		var want := {}
		if on:
			want = _mirrored()
		for sprite in _mirrors.keys():
			if not want.has(sprite) or not is_instance_valid(sprite):
				_from.erase(_mirrors[sprite])
				_mirrors[sprite].queue_free()
				_mirrors.erase(sprite)
		for sprite in want:
			if not _mirrors.has(sprite):
				var m := MeshInstance3D.new()
				var mat := ShaderMaterial.new()
				mat.shader = MirrorShader
				# Over the part of the body under the water (Player.underwater, 1), so the
				# legs in the water do not cover their mirrored picture.
				mat.render_priority = 2
				m.material_override = mat
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(m)
				_mirrors[sprite] = m
			_mirrors[sprite].set_meta("level", want[sprite])
	var light := _light()
	for sprite in _mirrors.keys():
		var m: MeshInstance3D = _mirrors[sprite]
		# A sprite freed between the looks (an animal gone) takes its mirror along.
		if not is_instance_valid(sprite):
			_from.erase(m)
			m.queue_free()
			_mirrors.erase(sprite)
			continue
		var level_y: float = m.get_meta("level")
		m.visible = sprite.is_visible_in_tree()
		m.mesh = sprite.mesh
		var mat: ShaderMaterial = m.material_override
		var from: ShaderMaterial = sprite.material_override
		if from != null and _from.get(m) != from:
			_from[m] = from
			mat.set_shader_parameter("sprite_texture", from.get_shader_parameter("sprite_texture"))
			mat.set_shader_parameter("frame_uv", from.get_shader_parameter("frame_uv"))
			var tint = from.get_shader_parameter("tint")
			mat.set_shader_parameter("tint", tint if tint != null else Vector3.ONE)
		elif from != null:
			# The player's own material changes its frame in place.
			mat.set_shader_parameter("frame_uv", from.get_shader_parameter("frame_uv"))
		mat.set_shader_parameter("level", level_y)
		mat.set_shader_parameter("light", light)
		var p: Vector3 = sprite.global_position
		var at := Vector3(p.x, 2.0 * level_y - p.y, p.z)
		# The box follows the shear too: turning or tilting the camera moves the picture.
		var view := Vector3(PixelView.up.x, PixelView.up.y, PixelView.slope)
		if at != m.position or m.scale.x != sprite.scale.x or m.get_meta("view", Vector3.ZERO) != view:
			m.set_meta("view", view)
			m.position = at
			m.scale = Vector3(sprite.scale.x, -1.0, 1.0)
			# Its box where the shear draws it (the shear moves a point by its height), as
			# the sprites' (Creatures._fit): the box in the world, back into the node's own.
			var world_box := PixelView.sheared_box(AABB(at - Vector3(1.0, 2.0, 1.0), Vector3(2.0, 2.0, 2.0)), 0.5)
			m.custom_aabb = m.transform.affine_inverse() * world_box


## The sprites to mirror now: sprite -> the level of the water it stands by.
func _mirrored() -> Dictionary:
	var view: Vector2 = game.view.cam_target
	var found := []
	var sprites := [game.player.sprite]
	if game.others != null:
		for id in game.others.people:
			sprites.append(game.others.people[id].figure.sprite)
	var creatures = game.creatures
	if creatures != null and creatures.wildlife != null:
		for a in creatures.wildlife.animals:
			var spec: Dictionary = AiRules.SPECIES.get(a.kind, {})
			if spec.get("swims", false) or a.flying:
				continue
			var s = creatures.sprite_of(a)
			if s != null:
				sprites.append(s)
	for s in sprites:
		if s == null or not is_instance_valid(s) or not s.is_visible_in_tree():
			continue
		var p: Vector3 = s.global_position
		var d := PixelView.screen_plane(p).distance_to(view)
		if d < MIRROR_REACH:
			found.append([d, s])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := {}
	for one: Array in found:
		if out.size() >= MIRRORS:
			break
		var p: Vector3 = one[1].global_position
		var c := Vector3i((p / CELL).floor())
		# The nearest open water round the feet, any way the camera looks: from a swimmer
		# (the feet deep under it) to one a cell or two up the bank.
		for r in range(0, MIRROR_LOOK + 1):
			var top := _water_ring(c, r, p.y)
			if top != -INF:
				out[one[1]] = top
				break
	return out


## The top of open water among the cells `r` from cell `c` (a square ring), within
## reach of feet at height `feet`; -INF when there is none.
func _water_ring(c: Vector3i, r: int, feet: float) -> float:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if maxi(absi(dx), absi(dz)) != r:
				continue
			var top := water_top(c.x + dx, c.z + dz, c.y + 2)
			if top != -INF and top <= feet + MIRROR_DEEP and top > feet - MIRROR_HIGH:
				return top
	return -INF
