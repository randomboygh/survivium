extends RefCounted
## The first time a thing is drawn under lights it was not drawn under before (the
## torch at dusk, the shadow of the nearest fire), the renderer builds the shaders for
## it, and on a phone that stops the game for 100 ms or more (2026-10-24; under software
## GL the first night took 10 s). So a small view no one sees draws one of each kind of
## thing in the world under each mix of those lights, and the shaders are built before
## they are needed. Things that are not there yet at the start are drawn too: the
## particles (dust, rain, sparks) as one particle each, the lightning's material on a
## face, a label and a letter "z" over a figure, and a line and a polygon of the
## interface (the wind's arrow, the sound marks, the joystick), which the canvas builds
## its own shaders for.
##
## Ahead, behind the loading screen (step, a mix a frame, every kind at once): the day's
## mixes, and the night's too when the world starts at dusk or at night. The night's are
## those with a fire's shadow, drawn only when it is dark and the fire shadows setting
## gives a real one (Effects.shadows); with it off they are never built. Later, in the
## game (update): what the moment may soon need and was not built yet, a kind at a time
## so each stop is short (most 0.3-0.5 s, a few 1-2 s under software GL): the night's
## mixes slowly by day while the player stands, faster once evening comes; the day's
## anew when the sun's shadow is switched in the settings. On a phone the whole warm-up
## ahead took 50 s (2026-11-06).

const MeshBuffers := preload("res://src/client/world/mesh_buffers.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const PlayerView := preload("res://src/client/view/player.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Effects := preload("res://src/client/view/effects.gd")

## The mixes of lights: [a light without a shadow (the torch, the far fires), a light
## with a shadow (the nearest fire)], all under the sun with its shadow as the settings
## have it. The sun alone (the land beyond the torch's glow) was once left to the first
## frames of the game, but the world is not drawn behind the menu, so it came mid-game
## (six shaders of up to 370 ms on a phone, 2026-11-01). The sun is never out: at dusk
## and on a moonless night its energy is 0, but the renderer still draws with it and
## picks the same shaders (measured 2026-11-06: the four mixes without it built nothing
## new when it was dimmed to 0, and were a quarter of the warm-up when it was hidden).
const DAY := [[true, false], [false, false]]
const NIGHT := [[true, true], [false, true]]
## How far apart the copies stand, in world units, and the lights' reach over them all.
const SPACING := 4.0
const REACH := 64.0
## How much lighter than Effects.SHADOW_SKY the sky is when evening comes: the night's
## mixes are then built ahead at the start, and in the game at the EVENING_PACE.
const EVENING := 0.35
## In the game, ms between two kinds drawn: by day, and once evening has come (or the
## settings asked for a mix not built yet).
const DAY_PACE := 2500
const EVENING_PACE := 400

var game
var viewport: SubViewport
var sun: DirectionalLight3D
var lamp: OmniLight3D
var fire: OmniLight3D
## The copies, one of each kind, in the hidden view.
var copies: Array[GeometryInstance3D] = []
## The interface's line and polygon, drawn on the world's canvas with no colour.
var canvas: RID
## The mixes built, by [the sun's shadow, lamp, fire's shadow].
var done := {}
## Ahead: the mixes left to draw, a frame each; how many there were.
var ahead: Array = []
var ahead_total := 0
## The frame start() ran in: the first mix is drawn at its end, so step() then waits.
var start_frame := -1
## Later: the mix being built a kind at a time, the next kind, when the last was drawn.
var mix_later: Array = []
var next_kind := 0
var drawn_at := 0


func _init(g) -> void:
	game = g


## The mixes the game may need: the day's always, the night's when a fire can cast a
## real shadow (Effects.shadows); with `soon` only those the sky may need soon, the
## night's once it is dark or getting dark (EVENING).
func wanted(soon: bool) -> Array:
	var shadow: bool = game.sky.sun.shadow_enabled
	var mixes: Array = []
	for m: Array in DAY:
		mixes.append([shadow, m[0], m[1]])
	if game.effects.shadows and (not soon or _evening()):
		for m: Array in NIGHT:
			mixes.append([shadow, m[0], m[1]])
	return mixes


func _evening() -> bool:
	return game.sky.sun_light < Effects.SHADOW_SKY + EVENING


## Starts the warm-up ahead, when the world is ready: the mixes the moment needs.
func start() -> void:
	ahead = wanted(true)
	ahead_total = ahead.size()
	start_frame = Engine.get_process_frames()
	_build()
	_mix(ahead[0])
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Builds the hidden view in a world of its own, with a copy of one thing of each kind
## found under the main view (the same mesh and material, so the same shaders).
func _build() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.msaa_3d = game.view.viewport.msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game.view.world_root.add_child(viewport)
	var kinds := {}
	_collect(game.view.world_root, kinds)
	# What may not be around yet: the ground's, water's and the low things' material on a
	# face like the chunks have.
	for mat: Material in [game.world_mat, game.low_mat, game.water_mat]:
		var face := MeshInstance3D.new()
		face.mesh = _face()
		face.material_override = mat
		var key := _key(face)
		if not kinds.has(key):
			kinds[key] = face
	# The names over the others and the letters "z" over a sleeper, shown only later.
	var label := Label3D.new()
	label.font = UiStyle.font()
	label.outline_size = 4
	label.pixel_size = 1.0 / PixelView.PIXELS_PER_UNIT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = 2
	label.text = "z"
	kinds["label"] = label
	var z: Sprite3D = PlayerView.snore_letter()
	z.modulate.a = 0.5
	kinds["snore"] = z
	# On the world's own canvas: the interface is hidden behind the menu while the
	# warm-up runs, and nothing under it is drawn.
	var world_2d: World2D = game.get_viewport().find_world_2d()
	if world_2d != null:
		var clear := Color(0, 0, 0, 0)
		canvas = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(canvas, world_2d.canvas)
		RenderingServer.canvas_item_add_line(canvas, Vector2.ZERO, Vector2(2.0, 0.0), clear, 1.0)
		RenderingServer.canvas_item_add_polygon(canvas, PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(0, 2)]),
			PackedColorArray([clear, clear, clear]))
	var side := ceili(sqrt(kinds.size()))
	var i := 0
	copies.clear()
	for copy: GeometryInstance3D in kinds.values():
		copy.extra_cull_margin = 16384.0
		viewport.add_child(copy)
		copy.position = Vector3((i % side) * SPACING, 0.0, (i / side) * SPACING)
		copies.append(copy)
		i += 1
	var middle := Vector3(side, 0.0, side) * SPACING * 0.5
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = side * SPACING + 8.0
	camera.near = 1.0
	camera.far = 200.0
	camera.environment = game.sky.env
	viewport.add_child(camera)
	camera.look_at_from_position(middle + Vector3(0.0, 100.0, 0.01), middle)
	camera.current = true
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = game.sky.sun.shadow_enabled
	sun.directional_shadow_mode = game.sky.sun.directional_shadow_mode
	viewport.add_child(sun)
	sun.look_at_from_position(middle + Vector3(1.0, 10.0, 1.0), middle)
	lamp = _light(middle + Vector3(-2.0, 3.0, 0.0), false)
	fire = _light(middle + Vector3(2.0, 3.0, 0.0), true)


## A unit face on the ground, like the chunks' cells have.
static func _face() -> ArrayMesh:
	var b := MeshBuffers.new()
	b.quad([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], Vector3.UP,
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], Color.WHITE, Vector2.ZERO)
	return b.to_mesh()


func _light(at: Vector3, shadow: bool) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.omni_range = REACH
	light.omni_attenuation = 0.0
	light.shadow_enabled = shadow
	viewport.add_child(light)
	light.position = at
	return light


func _mix(m: Array) -> void:
	sun.shadow_enabled = m[0]
	lamp.visible = m[1]
	fire.visible = m[2]


## A copy of each thing under `node` that differs from the ones in `kinds` in what
## picks its shaders: how it is drawn (a mesh, many instances, with colours or custom
## data) and its materials.
func _collect(node: Node, kinds: Dictionary) -> void:
	for child in node.get_children():
		if child == viewport:
			continue
		if child is MeshInstance3D and child.mesh != null:
			var mi: MeshInstance3D = child
			var key := _key(mi)
			if not kinds.has(key):
				var copy := MeshInstance3D.new()
				# A mesh drawn later (the lightning's) has no surfaces yet: its material on a face.
				copy.mesh = mi.mesh if mi.mesh.get_surface_count() > 0 or mi.material_override == null else _face()
				copy.material_override = mi.material_override
				for s in mi.get_surface_override_material_count():
					copy.set_surface_override_material(s, mi.get_surface_override_material(s))
				copy.cast_shadow = mi.cast_shadow
				kinds[key] = copy
		elif child is MultiMeshInstance3D and child.multimesh != null and child.multimesh.mesh != null:
			var mmi: MultiMeshInstance3D = child
			var mm := mmi.multimesh
			var key := ["multimesh", mmi.material_override, mm.mesh, mm.use_colors, mm.use_custom_data, mm.transform_format]
			if not kinds.has(key):
				var copy := MultiMeshInstance3D.new()
				var one := MultiMesh.new()
				one.transform_format = mm.transform_format
				one.use_colors = mm.use_colors
				one.use_custom_data = mm.use_custom_data
				one.mesh = mm.mesh
				one.instance_count = 1
				if mm.use_colors:
					one.set_instance_color(0, Color.WHITE)
				copy.multimesh = one
				copy.material_override = mmi.material_override
				copy.cast_shadow = mmi.cast_shadow
				kinds[key] = copy
		elif child is CPUParticles3D and child.mesh != null:
			# Drawn as instances of its mesh once it emits: one particle, there from the start.
			var cp: CPUParticles3D = child
			var key := ["particles", cp.mesh, cp.mesh.surface_get_material(0) if cp.mesh.get_surface_count() > 0 else null,
				cp.cast_shadow]
			if not kinds.has(key):
				var copy := CPUParticles3D.new()
				copy.mesh = cp.mesh
				copy.amount = 1
				copy.lifetime = 60.0
				copy.explosiveness = 1.0
				copy.preprocess = 1.0
				copy.local_coords = cp.local_coords
				copy.cast_shadow = cp.cast_shadow
				copy.emitting = true
				kinds[key] = copy
		_collect(child, kinds)


func _key(mi: MeshInstance3D) -> Array:
	var key := ["mesh", mi.material_override, mi.mesh.get_surface_count()]
	for s in mi.mesh.get_surface_count():
		key.append(mi.get_active_material(s))
		key.append(mi.mesh.surface_get_format(s) if mi.mesh is ArrayMesh else 0)
	return key


## How far the warm-up ahead has gone, 0 to 1 (the loading screen's strip).
func progress() -> float:
	return clampf(1.0 - float(ahead.size()) / maxi(ahead_total, 1), 0.0, 1.0)


## Called every frame of the warm-up ahead; true once every mix it had was drawn (the
## hidden view then waits, empty, for what is built later, see update).
func step() -> bool:
	# Called in the frame start() ran in too, before its mix was drawn (until 2026-11-06
	# the first mix was never drawn).
	if Engine.get_process_frames() == start_frame:
		return false
	done[ahead.pop_front()] = true
	if not ahead.is_empty():
		_mix(ahead[0])
		return false
	for copy in copies:
		copy.visible = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return true


## Called every frame of the game: builds a kind at a time of the mixes the game may
## need and were not built yet (see wanted), and lets the hidden view go once all are.
func update() -> void:
	if mix_later.is_empty():
		for m: Array in wanted(false):
			if not done.has(m):
				mix_later = m
				next_kind = 0
				break
		if mix_later.is_empty():
			_free()
			return
	# The night's slowly by day, and only while the player stands (some kinds stop the
	# game for a second or two on slow devices); at dusk, or the day's (the sun's shadow
	# switched), faster and whatever the player does.
	var now := Time.get_ticks_msec()
	var by_day: bool = mix_later[2] and not _evening()
	if by_day and game.player.body.move_input != Vector2.ZERO:
		return
	if now - drawn_at < (DAY_PACE if by_day else EVENING_PACE):
		return
	drawn_at = now
	if viewport == null:
		_build()
		for copy in copies:
			copy.visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if next_kind > 0:
		copies[next_kind - 1].visible = false
	if next_kind >= copies.size():
		done[mix_later] = true
		mix_later = []
		return
	_mix(mix_later)
	copies[next_kind].visible = true
	next_kind += 1
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	game.hud.perf.mark("прогрев")


## Lets the hidden view go.
func _free() -> void:
	if viewport != null:
		viewport.queue_free()
		viewport = null
	copies.clear()
	if canvas.is_valid():
		RenderingServer.free_rid(canvas)
		canvas = RID()
