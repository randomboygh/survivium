extends Node
## Technical prototype entry point. Generates the world, builds chunk meshes, and runs
## the player, animals, camera, time of day, seasons, weather and the level cutaway.
## The 3D scene renders into a low-resolution SubViewport (about 360 px tall) in an
## oblique 3/4 view, is colour graded and scaled up by a whole number without
## filtering (see PixelView); the interface (Hud) is scaled by a whole number too.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const PlayerScript := preload("res://src/client/player.gd")
const CreaturesScript := preload("res://src/client/creatures.gd")
const Hud := preload("res://src/client/hud.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Foliage := preload("res://src/client/foliage.gd")
const EffectsScript := preload("res://src/client/effects.gd")
const TracksScript := preload("res://src/client/tracks.gd")
const RoofMap := preload("res://src/client/roof_map.gd")
const Drifts := preload("res://src/client/drifts.gd")
const WorldShader := preload("res://shaders/world.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")
const LeavesShader := preload("res://shaders/leaves.gdshader")
const LeafShadowShader := preload("res://shaders/leaf_shadow.gdshader")
const GradeShader := preload("res://shaders/grade.gdshader")

const WORLD_SEED := 20261018
## Chunk size in cells.
const CHUNK := 16
const CELL := WorldData.CELL
## Meshes are drawn up to a level height north of where they are, so culling boxes
## get this much margin.
const CULL_MARGIN := 24.0
## Smallest UI height in UI units; the UI scale is lowered on short screens to keep it.
const DAY_LENGTH := 240.0
const DAYS_PER_SEASON := 2.0
const REACH := 7.0
## Chunks this far (in chunks) from the player's get a cap over the level cut; farther
## ones are off the screen on any device and are built when they come near.
const CAP_RANGE := 6
## How much of a frame may go to building caps and to remeshing edited chunks, in
## microseconds; what does not fit waits for the next frame.
const CAP_BUDGET_US := 3000
const EDIT_BUDGET_US := 6000
## How long the automatic cut must agree before the view follows it, so stepping
## under the rim of a roof does not flip the view back and forth.
const CUT_DELAY := 0.2
const SEASONS := ["Весна", "Лето", "Осень", "Зима"]
const WINTER := 3
const FOLIAGE := [Vector3(0.95, 1.1, 0.8), Vector3(1.0, 1.0, 1.0), Vector3(2.2, 1.05, 0.55), Vector3(1.3, 0.9, 0.7)]
const GRASS := [Vector3(0.95, 1.08, 0.85), Vector3(1.0, 1.0, 1.0), Vector3(1.1, 0.9, 0.66), Vector3(0.9, 0.85, 0.72)]
const LEAF_AMOUNT := [1.0, 1.0, 0.8, 0.55]
## How often the hint under the mouse pointer is updated, in seconds.
const TIP_INTERVAL := 0.1

var world
var player
var creatures
var container: SubViewportContainer
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var world_mat: ShaderMaterial
var water_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var leaves_mat: ShaderMaterial
var leaf_shadow_mat: ShaderMaterial
var grade_mat: ShaderMaterial
var grass_mesh: ArrayMesh
var clump_mesh: ArrayMesh
var disc_mesh: ArrayMesh
var chunk_nodes := {}
var pending_chunks: Array[Vector2i] = []
## Play starts when the chunks within NEAR_CHUNKS of the spawn are built; the rest of
## the map is built in the background, nearest to the player first.
const NEAR_CHUNKS := 3
var near_pending := 0
var near_total := 0
## One cap over the cut per chunk (see _update_caps): nodes, the level each was
## built for, and the chunks within CAP_RANGE of the player, nearest first.
var cap_nodes := {}
var cap_levels := {}
var cap_order: Array[Vector2i] = []
var cap_home := Vector2i(-1000000, 0)
## Chunks that changed since they were last meshed, remeshed a few a frame, and the
## time meshing took this frame.
var dirty_chunks := {}
var edit_spent_us := 0
var bushes: MultiMeshInstance3D
var bush_shade: MultiMeshInstance3D
var bush_cells: Array[Vector3i] = []
var effects
var tracks
var roof: RoofMap
var drifts: MultiMeshInstance3D
## Where the player's last footprint was left, and which foot made it.
var last_print := Vector3.ZERO
var left_foot := false
var hud
var touch := false
var jump_held := false
var tip_clock := 0.0
var mouse_pos := Vector2(-1, -1)
var last_touch_ms := -100000
## Touch indices now on the screen.
var fingers := {}
var atlas: Texture2D
var image_size := Vector2i(640, 360)
var safe_rect := Rect2()
var safe_clock := 0.0
var ready_to_play := false

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
var clouds := 0.3
var cloud_pos := Vector2.ZERO
var wind_clock := 0.0
var daylight := 1.0
var cut_level := -1
var manual_level := -1
## The cut the player's position asks for, and how long it has asked for it.
var cut_target := -1
var cut_clock := 0.0
## The level the player last stood on: a jump does not move the cut.
var ground_level := 0
var indoor := false
var selected := 0
var show_help := true
var dig_mode := true
## Screen-plane point the camera follows smoothly (see PixelView.screen_plane).
var cam_target := Vector2.ZERO
var view_scale := 1
var fps_clock := 0.0
var mesh_ms := 0


func _ready() -> void:
	touch = DisplayServer.is_touchscreen_available()
	show_help = not touch
	_build_view()
	_build_ui()
	get_viewport().size_changed.connect(_on_screen_resized)
	_on_screen_resized()
	hud.set_loading("Генерация мира…")
	# Let the loading text show before the heavy generation.
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	world = WorldGen.generate(WORLD_SEED)
	print("world generated in %d ms" % (Time.get_ticks_msec() - t0))
	roof = RoofMap.new()
	roof.build(world)
	_build_materials()
	_build_scene()
	var keys: Array[Vector2i] = []
	for cz in ceili(world.size_z / float(CHUNK)):
		for cx in ceili(world.size_x / float(CHUNK)):
			keys.append(Vector2i(cx, cz))
	var spawn := Vector2(player.position.x, player.position.z) / (CHUNK * CELL)
	var nearer := func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(spawn) < Vector2(b).distance_to(spawn)
	keys.sort_custom(nearer)
	pending_chunks = keys
	var home := Vector2i(spawn.floor())
	for key in keys:
		if _is_near(key, home):
			near_total += 1
	near_pending = near_total


func _is_near(key: Vector2i, home: Vector2i) -> bool:
	return maxi(absi(key.x - home.x), absi(key.y - home.y)) <= NEAR_CHUNKS


## The pending chunk nearest to the player.
func _next_chunk() -> Vector2i:
	var at := Vector2i((Vector2(player.position.x, player.position.z) / (CHUNK * CELL)).floor())
	var best := 0
	var best_d := 1 << 30
	for i in pending_chunks.size():
		var k := pending_chunks[i]
		var d := maxi(absi(k.x - at.x), absi(k.y - at.y))
		if d < best_d:
			best_d = d
			best = i
			if d <= 1:
				break
	return pending_chunks.pop_at(best)


func _process(delta: float) -> void:
	if world == null:
		return
	if not pending_chunks.is_empty():
		var t0 := Time.get_ticks_msec()
		if ready_to_play:
			# One far chunk a frame, so the frame rate holds while the map finishes.
			_build_chunk(_next_chunk())
		else:
			var home := Vector2i((Vector2(player.position.x, player.position.z) / (CHUNK * CELL)).floor())
			while near_pending > 0 and Time.get_ticks_msec() - t0 < 40:
				var key: Vector2i = pending_chunks.pop_front()
				if _is_near(key, home):
					near_pending -= 1
				_build_chunk(key)
			hud.set_loading("Построение мира… %d%%" % int(100.0 * (near_total - near_pending) / near_total))
			if near_pending == 0:
				hud.set_loading("")
				hud.perf.world_ms = Time.get_ticks_msec()
				# Freezes while the world was being built are not the game's.
				hud.perf.reset()
				hud.perf.chunks = near_total
				_place_props()
				creatures.setup(world, player, WORLD_SEED)
				ready_to_play = true
				print("near meshes built in %d ms" % mesh_ms)
				print("world ready in %d ms" % Time.get_ticks_msec())
		if pending_chunks.is_empty():
			hud.perf.chunks = ceili(world.size_x / float(CHUNK)) * ceili(world.size_z / float(CHUNK))
			print("meshes built in %d ms" % mesh_ms)
			print("whole map ready in %d ms" % Time.get_ticks_msec())
	_update_time(delta)
	_update_weather(delta)
	if ready_to_play:
		player.move_input = _read_move()
		player.step(minf(delta, 0.05), Input.is_physical_key_pressed(KEY_SPACE) or jump_held)
		_leave_footprints()
	_update_cut(delta)
	_remesh_dirty()
	_update_caps()
	_update_camera(delta)
	if ready_to_play:
		hud.update_state()
		_update_tip(delta)
		_report_fps(delta)
	_poll_safe_rect(delta)
	# Edits made by the input of the next frame count towards that frame's budget.
	edit_spent_us = 0


## A boot print every stride on the ground, left and right in turn, none in the water.
func _leave_footprints() -> void:
	tracks.focus = player.position
	if not player.on_ground or player.water_depth > 0.0:
		last_print = player.position
		return
	var moved := Vector2(player.position.x - last_print.x, player.position.z - last_print.z)
	if moved.length() >= 0.55:
		left_foot = not left_foot
		tracks.leave(player.position, moved, left_foot, true, 1.0)
		last_print = player.position


## Prints the frame statistics every 5 seconds to the log (the browser console on the web).
func _report_fps(delta: float) -> void:
	fps_clock += delta
	if fps_clock >= 5.0:
		fps_clock = 0.0
		print("fps %d | %s" % [Engine.get_frames_per_second(), hud.perf.summary().replace("\n", " | ")])


## Touch and mouse switch the layout: the joystick and action buttons show after a
## touch, key hints and the pointer hint after the mouse moves. Browsers report a
## moving finger as mouse motion too, so motion counts as a mouse only while no finger
## is down and a while after the last touch.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = true
		else:
			fingers.erase(event.index)
		_set_touch(true)
		last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventScreenDrag:
		_set_touch(true)
		last_touch_ms = Time.get_ticks_msec()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if fingers.is_empty() and Time.get_ticks_msec() - last_touch_ms > 1000:
			_set_touch(false)
		mouse_pos = event.position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key >= KEY_1 and key < KEY_1 + Mat.PLACEABLE.size():
			select_block(key - KEY_1)
		match key:
			KEY_Q, KEY_PAGEDOWN:
				shift_cut(-1)
			KEY_E, KEY_PAGEUP:
				shift_cut(1)
			KEY_R:
				reset_view_level()
			KEY_Z:
				next_season()
			KEY_X:
				raining = not raining
			KEY_T:
				time_speed = 1.0 if time_speed > 1.0 else 20.0
			KEY_G:
				sun.shadow_enabled = not sun.shadow_enabled
			KEY_H:
				show_help = not show_help
				hud.show_keys(show_help)
	elif event is InputEventMouseButton and event.pressed:
		var n: int = Mat.PLACEABLE.size()
		# With a mouse each button is a hand: the left one digs, the right one places.
		# A tap on a touch screen uses the hand chosen on the hotbar.
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_edit(event.position, dig_mode or not touch)
			MOUSE_BUTTON_RIGHT:
				_edit(event.position, false)
			MOUSE_BUTTON_WHEEL_UP:
				select_block((selected - 1 + n) % n, false)
			MOUSE_BUTTON_WHEEL_DOWN:
				select_block((selected + 1) % n, false)


# --- Setup -----------------------------------------------------------------

func _build_view() -> void:
	container = SubViewportContainer.new()
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_mat = ShaderMaterial.new()
	grade_mat.shader = GradeShader
	container.material = grade_mat
	add_child(container)
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)


func _on_screen_resized() -> void:
	var screen := get_viewport().get_visible_rect().size
	var view: Array = PixelView.layout(screen)
	var scale: int = view[0]
	# A margin of pixels around the screen leaves room for the sub-pixel camera shift.
	image_size = view[1] + Vector2i(2, 2) * PixelView.MARGIN
	view_scale = scale
	container.stretch_shrink = scale
	container.position = -Vector2.ONE * PixelView.MARGIN * scale
	container.size = Vector2(image_size * scale)
	if camera != null:
		camera.size = PixelView.camera_size(image_size.y)
	_layout_ui(_safe_rect())


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	# The interface keeps running while the pause menu stops the game.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_touch(touch)


func _layout_ui(rect: Rect2) -> void:
	safe_rect = rect
	hud.fit(rect)


func _set_touch(on: bool) -> void:
	if on != touch:
		touch = on
		hud.set_touch(on)
		if on:
			hud.show_tip(Vector2.ZERO, "")


## The part of the screen the player can see. Mobile browsers can lay the page out
## under their toolbars, so on the web this is the canvas clipped to the browser's
## visual viewport; elsewhere it is the whole window.
func _safe_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	if not OS.has_feature("web"):
		return full
	var js: Variant = JavaScriptBridge.eval("""(function () {
		var c = document.querySelector('canvas'), v = window.visualViewport;
		if (!c || !v) return '';
		var b = c.getBoundingClientRect();
		if (b.width <= 0 || b.height <= 0) return '';
		var k = c.width / b.width;
		var x0 = Math.max(b.left, v.offsetLeft), y0 = Math.max(b.top, v.offsetTop);
		var x1 = Math.min(b.right, v.offsetLeft + v.width), y1 = Math.min(b.bottom, v.offsetTop + v.height);
		return [(x0 - b.left) * k, (y0 - b.top) * k, (x1 - x0) * k, (y1 - y0) * k].join(',');
	})()""", true)
	if typeof(js) != TYPE_STRING or js == "":
		return full
	var v: PackedFloat64Array = String(js).split_floats(",")
	if v.size() != 4:
		return full
	var r := full.intersection(Rect2(v[0], v[1], v[2], v[3]))
	return r if r.size.x > 100.0 and r.size.y > 100.0 else full


## Browsers do not always report toolbars appearing or hiding, so the visible part
## of the screen is re-checked twice a second.
func _poll_safe_rect(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	safe_clock += delta
	if safe_clock < 0.5:
		return
	safe_clock = 0.0
	var r := _safe_rect()
	if not r.is_equal_approx(safe_rect):
		_layout_ui(r)


func set_dig_mode(on: bool) -> void:
	dig_mode = on
	hud.refresh_hands()


## Takes block `i` of the hotbar into the right hand; `use` also makes it the hand in use.
func select_block(i: int, use := true) -> void:
	selected = i
	if use:
		dig_mode = false
	hud.refresh_hands()


## F3: prints the view and UI layout and the player state to the log.
func print_debug() -> void:
	var r: Dictionary = hud.debug_rects()
	var p: Vector3 = player.position if player != null else Vector3.ZERO
	print("debug: screen %s, density %.2f, image %s x%d, ui %s, ui scale %.2f, stick %s, buttons %s, jump %s, hotbar %s, menu %s, season %s, player (%.2f, %.2f, %.2f), season now %s, touch %s, stick value (%.2f, %.2f)" % [
		get_viewport().get_visible_rect().size, DisplayServer.screen_get_scale(), viewport.size,
		container.stretch_shrink, safe_rect, hud.scale.x, r.stick, r.buttons, r.jump, r.hotbar, r.menu, r.season,
		p.x, p.y, p.z, SEASONS[season], touch, hud.stick.value.x, hud.stick.value.y])


func _build_materials() -> void:
	atlas = PixelTextures.build_atlas()
	RenderingServer.global_shader_parameter_set("terrain_atlas", atlas)
	hud.set_block_icons(atlas, PixelTextures.TILE, PixelTextures.TILES)
	RenderingServer.global_shader_parameter_set("cloud_noise", PixelTextures.build_cloud_noise())
	RenderingServer.global_shader_parameter_set("world_size", Vector2(world.size_x, world.size_z) * CELL)
	world_mat = _material(WorldShader)
	water_mat = _material(WaterShader)
	grass_mat = _material(GrassShader)
	grass_mat.set_shader_parameter("plant_texture", PixelTextures.build_plants())
	leaves_mat = _material(LeavesShader)
	leaves_mat.set_shader_parameter("clump_texture", PixelTextures.build_clumps())
	leaves_mat.set_shader_parameter("clump_size", Foliage.CLUMP_SIZE)
	leaves_mat.set_shader_parameter("clump_rows", PixelTextures.CLUMP_ROWS)
	leaves_mat.set_shader_parameter("branch_row", PixelTextures.BRANCH_ROW)
	leaf_shadow_mat = _material(LeafShadowShader)
	grass_mesh = Foliage.plant_mesh(Foliage.PLANT_W, Foliage.PLANT_H)
	clump_mesh = Foliage.quad_mesh(Foliage.CLUMP_SIZE, true)
	disc_mesh = Foliage.disc_mesh(Foliage.SHADOW_DISC)


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _build_scene() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	world_root.add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = PixelView.CAMERA_HEIGHT + 20.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	world_root.add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = PixelView.camera_size(image_size.y)
	camera.near = 1.0
	camera.far = PixelView.CAMERA_HEIGHT + 10.0
	world_root.add_child(camera)
	camera.current = true

	player = PlayerScript.new()
	player.world = world
	world_root.add_child(player)
	var spawn: Vector3i = WorldGen.find_spawn(world)
	player.position = (Vector3(spawn) + Vector3(0.5, 0.0, 0.5)) * CELL
	ground_level = player.level()
	cam_target = PixelView.screen_plane(player.position + Vector3(0.0, 0.5, 0.0))

	tracks = TracksScript.new()
	tracks.world = world
	world_root.add_child(tracks)

	creatures = CreaturesScript.new()
	creatures.tracks = tracks
	world_root.add_child(creatures)

	effects = EffectsScript.new()
	world_root.add_child(effects)


func _place_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED + 100
	for i in 400:
		var x := rng.randi_range(1, world.size_x - 2)
		var z := rng.randi_range(1, world.size_z - 2)
		var y: int = world.surface_y(x, z)
		if y > 0 and y < world.size_y and world.get_cell(x, y - 1, z) == Mat.GRASS and world.get_cell(x, y, z) == Mat.AIR \
				and world.slope_mask(x, y - 1, z) == world.FULL:
			bush_cells.append(Vector3i(x, y, z))
	var bush_mat := _material(LeavesShader)
	bush_mat.set_shader_parameter("clump_texture", PixelTextures.build_clumps(Foliage.BUSH_CLUMP, [Foliage.BUSH_CLUMP], false))
	bush_mat.set_shader_parameter("clump_size", Foliage.BUSH_CLUMP / 16.0)
	bushes = _multimesh(Foliage.quad_mesh(Foliage.BUSH_CLUMP / 16.0, true), bush_mat, true, true)
	bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bushes.extra_cull_margin = CULL_MARGIN
	world_root.add_child(bushes)
	bush_shade = _multimesh(Foliage.disc_mesh(Foliage.BUSH_DISC), leaf_shadow_mat, false, true)
	bush_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	bush_shade.extra_cull_margin = CULL_MARGIN
	world_root.add_child(bush_shade)
	_refresh_bushes()
	# Snowdrifts, shown with the snow cover.
	drifts = _multimesh(Drifts.mound_mesh(), world_mat, false, false)
	var mounds: Array = Drifts.build(world)
	drifts.multimesh.instance_count = mounds[0]
	if mounds[0] > 0:
		drifts.multimesh.buffer = mounds[1]
	drifts.visible = false
	drifts.extra_cull_margin = CULL_MARGIN
	world_root.add_child(drifts)

	# A chest and a campfire next to the spawn point, each on two by two cells.
	var chest_spot := _prop_spot(player.position + Vector3(2.0, 0.0, 1.0))
	if chest_spot.y >= 0:
		var chest := MeshInstance3D.new()
		chest.mesh = VoxelProps.chest().build_mesh()
		chest.material_override = world_mat
		chest.scale = Vector3.ONE / 16.0
		chest.position = Vector3(chest_spot) * CELL
		chest.extra_cull_margin = CULL_MARGIN
		world_root.add_child(chest)
	var fire := _prop_spot(player.position + Vector3(-2.0, 0.0, 2.0))
	if fire.y >= 0:
		effects.add_campfire(Vector3(fire) * CELL, world_mat)
	RenderingServer.global_shader_parameter_set("heat_map", effects.heat_map(ceili(world.size_x * CELL), ceili(world.size_z * CELL)))


## The north-west cell of two by two free cells on ground at one level near the world
## point `p`, the ground under them levelled; y = -1 when there is no such spot.
func _prop_spot(p: Vector3) -> Vector3i:
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	var y: int = world.surface_y(x, z)
	if y <= 0:
		return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			if world.get_cell(x + dx, y, z + dz) != Mat.AIR or not world.is_solid(x + dx, y - 1, z + dz):
				return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			_level_ground(Vector3i(x + dx, y - 1, z + dz))
	return Vector3i(x, y, z)


## Props stand on level ground: a slope under them becomes a whole cube.
func _level_ground(cell: Vector3i) -> void:
	if world.slope_mask(cell.x, cell.y, cell.z) != world.FULL:
		world.set_natural(cell.x, cell.y, cell.z, false)
		_on_cell_changed(cell)


func _refresh_bushes() -> void:
	var part: Array = Foliage.bushes(bush_cells)
	bushes.multimesh.instance_count = part[0]
	if part[0] > 0:
		bushes.multimesh.buffer = part[1]
	var discs := PackedFloat32Array()
	for cell in bush_cells:
		Foliage.put(discs, (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, 0.5, 0.0))
		discs.append_array([Foliage.BERRIES, 0.0, 0.0, 0.0])
	bush_shade.multimesh.instance_count = bush_cells.size()
	if not bush_cells.is_empty():
		bush_shade.multimesh.buffer = discs


# --- World edits -----------------------------------------------------------

func _build_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var meshes: Array = ChunkMesher.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	var plants: Dictionary = Foliage.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	edit_spent_us += Time.get_ticks_usec() - t0
	mesh_ms += (Time.get_ticks_usec() - t0) / 1000
	dirty_chunks.erase(key)
	cap_levels.erase(key)
	if not chunk_nodes.has(key):
		var solid := MeshInstance3D.new()
		solid.material_override = world_mat
		var water := MeshInstance3D.new()
		water.material_override = water_mat
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tufts := _multimesh(grass_mesh, grass_mat, false, true)
		tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var crowns := _multimesh(clump_mesh, leaves_mat, true, true)
		crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shade := _multimesh(disc_mesh, leaf_shadow_mat, false, true)
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var parts: Array = [solid, water, tufts, crowns, shade]
		for n in parts:
			n.extra_cull_margin = CULL_MARGIN
			world_root.add_child(n)
		chunk_nodes[key] = parts
	var nodes: Array = chunk_nodes[key]
	nodes[0].mesh = meshes[0]
	nodes[1].mesh = meshes[1]
	for i in 3:
		var part: Array = plants[["grass", "clumps", "shadows"][i]]
		var mm: MultiMesh = nodes[2 + i].multimesh
		mm.instance_count = part[0]
		if part[0] > 0:
			mm.buffer = part[1]


func _multimesh(mesh: Mesh, material: Material, colors: bool, custom: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	return node


## The cell under a screen point, as VoxelRaycast.cast returns it (empty if none).
func _pick(screen_pos: Vector2) -> Dictionary:
	if not ready_to_play:
		return {}
	var vp_pos := (screen_pos - container.global_position) / float(container.stretch_shrink)
	var center := Vector2(camera.global_position.x, camera.global_position.z)
	var ray: Array = PixelView.view_ray(center, vp_pos - Vector2(image_size) * 0.5, world.size_y * CELL + 1.0)
	var max_level: int = mini(cut_level, world.size_y - 1)
	return VoxelRaycast.cast(world, ray[0] / CELL, ray[1], 500.0, max_level)


func _edit(screen_pos: Vector2, dig: bool) -> void:
	var hit := _pick(screen_pos)
	if hit.is_empty():
		return
	var cell: Vector3i = hit.cell
	if dig:
		if cell.y == 0 or _too_far(cell):
			return
		world.set_cell(cell.x, cell.y, cell.z, Mat.AIR)
	else:
		var normal: Vector3i = hit.normal
		cell += normal
		if not world.in_bounds(cell.x, cell.y, cell.z) or _too_far(cell):
			return
		var cur: int = world.get_cell(cell.x, cell.y, cell.z)
		if cur != Mat.AIR and cur != Mat.WATER or player.overlaps_cell(cell):
			return
		world.set_cell(cell.x, cell.y, cell.z, Mat.PLACEABLE[selected])
	_on_cell_changed(cell)


func _too_far(cell: Vector3i) -> bool:
	var center := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	return center.distance_to(player.position + Vector3(0.0, 0.5, 0.0)) > REACH


func _on_cell_changed(cell: Vector3i) -> void:
	roof.touch(world, cell)
	# Slopes and corners look at the neighbours, and edges of a top at theirs. The
	# chunk of the cell is remeshed at once so the edit shows this frame; the
	# neighbours follow in the next frames (see _remesh_dirty).
	var home := Vector2i(floori(cell.x / float(CHUNK)), floori(cell.z / float(CHUNK)))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var key := Vector2i(floori((cell.x + dx) / float(CHUNK)), floori((cell.z + dz) / float(CHUNK)))
			if chunk_nodes.has(key):
				dirty_chunks[key] = true
	if chunk_nodes.has(home):
		_build_chunk(home)
	# A bush disappears when its cell is filled or the ground under it is dug.
	var above := cell + Vector3i(0, 1, 0)
	if bush_cells.has(cell) or bush_cells.has(above):
		bush_cells.erase(cell)
		bush_cells.erase(above)
		_refresh_bushes()


## Remeshes edited chunks while the frame's meshing budget lasts, at least one a frame
## when nothing else was meshed this frame.
func _remesh_dirty() -> void:
	while not dirty_chunks.is_empty() and edit_spent_us < EDIT_BUDGET_US:
		_build_chunk(dirty_chunks.keys()[0])


# --- Level cutaway -----------------------------------------------------------

func _update_cut(delta: float) -> void:
	if world == null or player == null:
		return
	if player.on_ground:
		ground_level = player.level()
	# The player stands on `level` and is two cells tall.
	var level := ground_level
	var px := floori(player.position.x / CELL)
	var pz := floori(player.position.z / CELL)
	indoor = false
	for y in range(level + 2, mini(level + 18, world.size_y)):
		if Mat.is_roof(world.get_cell(px, y, pz)):
			indoor = true
			break
	var target: int = world.size_y
	if manual_level >= 0:
		target = manual_level
	elif indoor:
		target = level + 1
	if target != cut_target:
		cut_target = target
		cut_clock = 0.0
	if target == cut_level:
		return
	# A chosen level applies at once; the automatic one once it has held for a moment.
	cut_clock += delta
	if cut_level < 0 or manual_level >= 0 or cut_clock >= CUT_DELAY:
		cut_level = target
		_apply_cut()


func shift_cut(d: int) -> void:
	if world == null:
		return
	var base: int = cut_level if cut_level < world.size_y else player.level() + 1
	manual_level = clampi(base + d, 1, world.size_y)
	if manual_level >= world.size_y - 1:
		manual_level = -1


## Back to the automatic cut that follows the player.
func reset_view_level() -> void:
	manual_level = -1


func _apply_cut() -> void:
	var h := 1000.0 if cut_level >= world.size_y else (cut_level + 1) * CELL
	RenderingServer.global_shader_parameter_set("cut_height", h)
	RenderingServer.global_shader_parameter_set("cut_ghost", 1.0 if manual_level < 0 else 0.0)
	# The caps follow in _update_caps, nearest chunk first; with no cut they go at once.
	if cut_level >= world.size_y - 1:
		for key in cap_levels:
			cap_nodes[key].mesh = null
		cap_levels.clear()


## Brings the caps of the chunks around the player to the current cut, nearest first,
## a few a frame. The cap of a chunk is rebuilt when the cut moves or the chunk is
## edited (its entry in cap_levels goes); chunks out of range lose theirs.
func _update_caps() -> void:
	if not ready_to_play:
		return
	var home := Vector2i((Vector2(player.position.x, player.position.z) / (CHUNK * CELL)).floor())
	if home != cap_home:
		cap_home = home
		cap_order.clear()
		for cz in range(maxi(0, home.y - CAP_RANGE), mini(ceili(world.size_z / float(CHUNK)), home.y + CAP_RANGE + 1)):
			for cx in range(maxi(0, home.x - CAP_RANGE), mini(ceili(world.size_x / float(CHUNK)), home.x + CAP_RANGE + 1)):
				cap_order.append(Vector2i(cx, cz))
		var nearer := func(a: Vector2i, b: Vector2i) -> bool:
			return maxi(absi(a.x - home.x), absi(a.y - home.y)) < maxi(absi(b.x - home.x), absi(b.y - home.y))
		cap_order.sort_custom(nearer)
		for key in cap_levels.keys():
			if maxi(absi(key.x - home.x), absi(key.y - home.y)) > CAP_RANGE:
				cap_nodes[key].mesh = null
				cap_levels.erase(key)
	var want: int = cut_level if cut_level < world.size_y - 1 else -1
	if want < 0:
		return
	var t0 := Time.get_ticks_usec()
	for key in cap_order:
		if cap_levels.get(key, -1) == want or not chunk_nodes.has(key):
			continue
		if not cap_nodes.has(key):
			var node := MeshInstance3D.new()
			node.material_override = world_mat
			node.extra_cull_margin = CULL_MARGIN
			world_root.add_child(node)
			cap_nodes[key] = node
		cap_nodes[key].mesh = ChunkMesher.build_cap(world, want, key.x * CHUNK, key.y * CHUNK, CHUNK)
		cap_levels[key] = want
		if Time.get_ticks_usec() - t0 > CAP_BUDGET_US:
			break


# --- Time, seasons, weather --------------------------------------------------

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
	var haze := (Color(0.02, 0.02, 0.03) if cut_level < world.size_y else env.background_color).srgb_to_linear()
	RenderingServer.global_shader_parameter_set("depth_haze", Vector3(haze.r, haze.g, haze.b))
	creatures.daylight = daylight
	if player != null:
		player.torch.light_energy = 1.1 if indoor else 1.1 * clampf(night * 2.5 - 1.5, 0.0, 1.0)
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
	hud.toast("Наступила %s" % SEASONS[season].to_lower() if season != 1 else "Наступило лето")


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
	g.global_shader_parameter_set("cloud_cover", clouds)
	g.global_shader_parameter_set("cloud_offset", cloud_pos)
	g.global_shader_parameter_set("wind", wind)
	var ice := clampf((snow - 0.3) / 0.5, 0.0, 1.0)
	water_mat.set_shader_parameter("ice_amount", ice)
	world.water_frozen = ice > 0.8
	if player != null:
		effects.update(delta, cam_target, player.position.y, raining, winter, season, daylight, indoor)
	if tracks != null:
		tracks.snow = snow
		tracks.wet = wet
	if drifts != null:
		drifts.visible = snow > 0.6


# --- Camera, input, HUD ----------------------------------------------------

## The camera renders from a whole pixel; the leftover fraction of a pixel shifts the
## upscaled image, so the view glides smoothly while the pixel art stays on its grid.
func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target := PixelView.screen_plane(player.position + Vector3(0.0, 0.5, 0.0))
	cam_target = cam_target.lerp(target, minf(1.0, delta * 6.0))
	var snapped := PixelView.snap_plane(cam_target)
	camera.global_transform = PixelView.camera_transform(snapped)
	var frac := (cam_target - snapped) * PixelView.PIXELS_PER_UNIT
	container.position = (-Vector2.ONE * PixelView.MARGIN - frac) * view_scale
	container.position = container.position.round()
	player.place_sprite()
	RenderingServer.global_shader_parameter_set("player_pos", player.position)
	# The levels below fade from the player's feet, or from a level picked by hand.
	if manual_level >= 0:
		RenderingServer.global_shader_parameter_set("view_height", (manual_level + 1) * CELL)
	elif player.on_ground or player.swimming:
		RenderingServer.global_shader_parameter_set("view_height", player.level() * CELL)


func _read_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if touch:
		v += hud.stick.value
	return v


## With a mouse, names the cell under the pointer and what the buttons do with it.
func _update_tip(delta: float) -> void:
	tip_clock += delta
	if touch or tip_clock < TIP_INTERVAL or mouse_pos.x < 0.0:
		return
	tip_clock = 0.0
	var hit := _pick(mouse_pos)
	if hit.is_empty():
		hud.show_tip(mouse_pos, "")
		return
	var cell: Vector3i = hit.cell
	var text: String = "%s · уровень %d" % [Mat.NAMES[world.get_cell(cell.x, cell.y, cell.z)], cell.y]
	if _too_far(cell):
		text += "\nдалеко"
	else:
		text += "\nЛКМ копать · ПКМ поставить"
	hud.show_tip(mouse_pos, text)
