extends Node
## Technical prototype entry point. Generates the world, builds chunk meshes, and runs
## the player, animals, camera, time of day, seasons, weather and the level cutaway.
## The 3D scene renders into a low-resolution SubViewport (about 360 px tall) in an
## oblique 3/4 view, is colour graded and scaled up by a whole number without
## filtering (see PixelView); the UI is drawn at full resolution, scaled for the
## screen's pixel density.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const PlayerScript := preload("res://src/client/player.gd")
const CreaturesScript := preload("res://src/client/creatures.gd")
const TouchStick := preload("res://src/client/touch_stick.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Foliage := preload("res://src/client/foliage.gd")
const EffectsScript := preload("res://src/client/effects.gd")
const WorldShader := preload("res://shaders/world.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")
const LeavesShader := preload("res://shaders/leaves.gdshader")
const LeafShadowShader := preload("res://shaders/leaf_shadow.gdshader")
const GradeShader := preload("res://shaders/grade.gdshader")

const WORLD_SEED := 20261018
const CHUNK := 16
## Meshes are drawn up to a level height north of where they are, so culling boxes
## get this much margin.
const CULL_MARGIN := 24.0
## Smallest UI height in UI units; the UI scale is lowered on short screens to keep it.
const UI_MIN_HEIGHT := 320.0
const UI_MARGIN := 16.0
const DAY_LENGTH := 240.0
const DAYS_PER_SEASON := 2.0
const REACH := 7.0
const SEASONS := ["Весна", "Лето", "Осень", "Зима"]
const WINTER := 3
const FOLIAGE := [Vector3(0.95, 1.1, 0.8), Vector3(1.0, 1.0, 1.0), Vector3(2.2, 1.05, 0.55), Vector3(1.3, 0.9, 0.7)]
const GRASS := [Vector3(0.95, 1.08, 0.85), Vector3(1.0, 1.0, 1.0), Vector3(1.1, 0.9, 0.66), Vector3(0.9, 0.85, 0.72)]
const LEAF_AMOUNT := [1.0, 1.0, 0.8, 0.55]
const HELP := "WASD — ходить, Пробел — прыжок\nЛКМ — копать, ПКМ — поставить, 1–7 / колесо — блок\nQ / E — срез уровней вниз / вверх\nZ — следующий сезон, X — осадки, T — ускорить время\nG — тени, H — скрыть подсказку"

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
var cap_node: MeshInstance3D
var bushes: MultiMeshInstance3D
var bush_shade: MultiMeshInstance3D
var bush_cells: Array[Vector3i] = []
var effects
var ui: Control
var hud: Label
var hotbar: Label
var loading: Label
var stick
var touch_buttons: GridContainer
var mode_button: Button
var block_button: Button
var touch := false
var image_size := Vector2i(640, 360)
var safe_rect := Rect2()
var safe_clock := 0.0
var ready_to_play := false

var time_of_day := 0.3
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
	loading.text = "Генерация мира…"
	# Let the loading text show before the heavy generation.
	await get_tree().process_frame
	await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	world = WorldGen.generate(WORLD_SEED)
	print("world generated in %d ms" % (Time.get_ticks_msec() - t0))
	_build_materials()
	_build_scene()
	var keys: Array[Vector2i] = []
	for cz in ceili(world.size_z / float(CHUNK)):
		for cx in ceili(world.size_x / float(CHUNK)):
			keys.append(Vector2i(cx, cz))
	var spawn := Vector2(player.position.x, player.position.z) / CHUNK
	var nearer := func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(spawn) < Vector2(b).distance_to(spawn)
	keys.sort_custom(nearer)
	pending_chunks = keys


func _process(delta: float) -> void:
	if world == null:
		return
	if not pending_chunks.is_empty():
		var t0 := Time.get_ticks_msec()
		while not pending_chunks.is_empty() and Time.get_ticks_msec() - t0 < 40:
			_build_chunk(pending_chunks.pop_front())
		var total := ceili(world.size_x / float(CHUNK)) * ceili(world.size_z / float(CHUNK))
		loading.text = "Построение мира… %d%%" % int(100.0 * (total - pending_chunks.size()) / total)
		if pending_chunks.is_empty():
			loading.visible = false
			_place_props()
			creatures.setup(world, player, WORLD_SEED)
			ready_to_play = true
			print("meshes built in %d ms" % mesh_ms)
			print("world ready in %d ms" % Time.get_ticks_msec())
	_update_time(delta)
	_update_weather(delta)
	if ready_to_play:
		player.move_input = _read_move()
		player.step(minf(delta, 0.05), Input.is_physical_key_pressed(KEY_SPACE))
	_update_cut()
	_update_camera(delta)
	_update_hud()
	_poll_safe_rect(delta)
	if ready_to_play:
		_report_fps(delta)


## Prints the frame rate every 5 seconds to the log (the browser console on the web).
func _report_fps(delta: float) -> void:
	fps_clock += delta
	if fps_clock >= 5.0:
		fps_clock = 0.0
		print("fps %d" % Engine.get_frames_per_second())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key >= KEY_1 and key < KEY_1 + Mat.PLACEABLE.size():
			selected = key - KEY_1
			_update_block_button()
		match key:
			KEY_Q, KEY_PAGEDOWN:
				_shift_cut(-1)
			KEY_E, KEY_PAGEUP:
				_shift_cut(1)
			KEY_Z:
				_next_season()
			KEY_X:
				raining = not raining
			KEY_T:
				time_speed = 1.0 if time_speed > 1.0 else 20.0
			KEY_G:
				sun.shadow_enabled = not sun.shadow_enabled
			KEY_H:
				show_help = not show_help
			KEY_F3:
				_print_debug()
	elif event is InputEventMouseButton and event.pressed:
		var n: int = Mat.PLACEABLE.size()
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_edit(event.position, dig_mode)
			MOUSE_BUTTON_RIGHT:
				_edit(event.position, false)
			MOUSE_BUTTON_WHEEL_UP:
				selected = (selected - 1 + n) % n
				_update_block_button()
			MOUSE_BUTTON_WHEEL_DOWN:
				selected = (selected + 1) % n
				_update_block_button()


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
	add_child(layer)
	# All UI lives under one scaled root, so anchors work in UI units.
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	hud = _label(ui, Vector2(UI_MARGIN, UI_MARGIN * 0.5))
	hotbar = _label(ui, Vector2.ZERO)
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	hotbar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading = _label(ui, Vector2.ZERO)
	loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading.add_theme_font_size_override("font_size", 28)
	if touch:
		# On touch screens the selected block is shown on its button instead of a hotbar.
		hotbar.visible = false
		stick = TouchStick.new()
		ui.add_child(stick)
		stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, UI_MARGIN)
		stick.grow_vertical = Control.GROW_DIRECTION_BEGIN
		touch_buttons = GridContainer.new()
		touch_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		touch_buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
		touch_buttons.add_theme_constant_override("h_separation", 6)
		touch_buttons.add_theme_constant_override("v_separation", 6)
		ui.add_child(touch_buttons)
		mode_button = _button(touch_buttons, "Копать", _toggle_dig_mode)
		block_button = _button(touch_buttons, "", _next_block)
		# The default font has no arrow glyphs.
		_button(touch_buttons, "Ниже", func() -> void: _shift_cut(-1))
		_button(touch_buttons, "Выше", func() -> void: _shift_cut(1))
		_button(touch_buttons, "Сезон", _next_season)
		_button(touch_buttons, "Осадки", func() -> void: raining = not raining)
		_update_block_button()


## Fits the UI root into `rect` (screen pixels) at the screen's pixel density.
func _layout_ui(rect: Rect2) -> void:
	safe_rect = rect
	var s := maxf(1.0, DisplayServer.screen_get_scale())
	s = clampf(rect.size.y / UI_MIN_HEIGHT, 1.0, s)
	ui.scale = Vector2(s, s)
	ui.position = rect.position
	ui.size = rect.size / s
	if touch_buttons != null:
		# Three columns fit next to the stick in landscape, two in portrait.
		touch_buttons.columns = 3 if ui.size.x >= 520.0 else 2
		touch_buttons.reset_size()
		touch_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UI_MARGIN)


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


func _toggle_dig_mode() -> void:
	dig_mode = not dig_mode
	mode_button.text = "Копать" if dig_mode else "Ставить"


func _next_block() -> void:
	selected = (selected + 1) % Mat.PLACEABLE.size()
	_update_block_button()


func _update_block_button() -> void:
	if block_button != null:
		block_button.text = Mat.NAMES[Mat.PLACEABLE[selected]]


## F3: prints the view and UI layout and the player state to the log.
func _print_debug() -> void:
	var stick_rect := Rect2()
	var buttons_rect := Rect2()
	if stick != null:
		stick_rect = stick.get_global_rect()
		buttons_rect = touch_buttons.get_global_rect()
	var p: Vector3 = player.position if player != null else Vector3.ZERO
	print("debug: screen %s, density %.2f, image %s x%d, ui %s, ui scale %.2f, stick %s, buttons %s, player (%.2f, %.2f, %.2f), season %s" % [
		get_viewport().get_visible_rect().size, DisplayServer.screen_get_scale(), viewport.size,
		container.stretch_shrink, safe_rect, ui.scale.x, stick_rect, buttons_rect, p.x, p.y, p.z,
		SEASONS[season]])


func _label(parent: Node, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 44)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _build_materials() -> void:
	RenderingServer.global_shader_parameter_set("terrain_atlas", PixelTextures.build_atlas())
	RenderingServer.global_shader_parameter_set("cloud_noise", PixelTextures.build_cloud_noise())
	RenderingServer.global_shader_parameter_set("world_size", Vector2(world.size_x, world.size_z))
	world_mat = _material(WorldShader)
	water_mat = _material(WaterShader)
	grass_mat = _material(GrassShader)
	grass_mat.set_shader_parameter("tuft_texture", PixelTextures.build_tufts())
	leaves_mat = _material(LeavesShader)
	leaves_mat.set_shader_parameter("clump_texture", PixelTextures.build_clumps())
	leaves_mat.set_shader_parameter("clump_size", Foliage.CLUMP_SIZE)
	leaf_shadow_mat = _material(LeafShadowShader)
	grass_mesh = Foliage.quad_mesh(Foliage.TUFT_SIZE, false)
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

	cap_node = MeshInstance3D.new()
	cap_node.material_override = world_mat
	cap_node.extra_cull_margin = CULL_MARGIN
	world_root.add_child(cap_node)

	player = PlayerScript.new()
	player.world = world
	world_root.add_child(player)
	var spawn: Vector3i = WorldGen.find_spawn(world)
	player.position = Vector3(spawn.x + 0.5, spawn.y, spawn.z + 0.5)
	cam_target = PixelView.screen_plane(player.position + Vector3(0.0, 0.5, 0.0))

	creatures = CreaturesScript.new()
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
	bush_mat.set_shader_parameter("clump_texture", PixelTextures.build_clumps(Foliage.BUSH_CLUMP))
	bush_mat.set_shader_parameter("clump_size", Foliage.BUSH_CLUMP / 16.0)
	bushes = _multimesh(Foliage.quad_mesh(Foliage.BUSH_CLUMP / 16.0, true), bush_mat, true, true)
	bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bushes.extra_cull_margin = CULL_MARGIN
	world_root.add_child(bushes)
	bush_shade = _multimesh(Foliage.disc_mesh(Foliage.BUSH_DISC), leaf_shadow_mat, false, false)
	bush_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	bush_shade.extra_cull_margin = CULL_MARGIN
	world_root.add_child(bush_shade)
	_refresh_bushes()

	# A chest and a campfire next to the spawn point.
	var c: Vector3 = player.position + Vector3(2.0, 0.0, 1.0)
	var cell := Vector3i(floori(c.x), floori(c.y), floori(c.z))
	if world.get_cell(cell.x, cell.y, cell.z) == Mat.AIR and world.is_solid(cell.x, cell.y - 1, cell.z):
		_level_ground(cell - Vector3i(0, 1, 0))
		var chest := MeshInstance3D.new()
		chest.mesh = VoxelProps.chest().build_mesh()
		chest.material_override = world_mat
		chest.scale = Vector3.ONE / 16.0
		chest.position = Vector3(cell)
		chest.extra_cull_margin = CULL_MARGIN
		world_root.add_child(chest)
	var f: Vector3 = player.position + Vector3(-2.0, 0.0, 2.0)
	var fire := Vector3i(floori(f.x), floori(f.y), floori(f.z))
	if world.get_cell(fire.x, fire.y, fire.z) == Mat.AIR and world.is_solid(fire.x, fire.y - 1, fire.z):
		_level_ground(fire - Vector3i(0, 1, 0))
		effects.add_campfire(fire, world_mat)
	RenderingServer.global_shader_parameter_set("heat_map", effects.heat_map(world.size_x, world.size_z))


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
		Foliage.put(discs, Vector3(cell) + Vector3(0.5, 0.5, 0.5))
	bush_shade.multimesh.instance_count = bush_cells.size()
	if not bush_cells.is_empty():
		bush_shade.multimesh.buffer = discs


# --- World edits -----------------------------------------------------------

func _build_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_msec()
	var meshes: Array = ChunkMesher.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	var plants: Dictionary = Foliage.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	mesh_ms += Time.get_ticks_msec() - t0
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
		var shade := _multimesh(disc_mesh, leaf_shadow_mat, false, false)
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


func _edit(screen_pos: Vector2, dig: bool) -> void:
	if not ready_to_play:
		return
	var vp_pos := (screen_pos - container.global_position) / float(container.stretch_shrink)
	var center := Vector2(camera.global_position.x, camera.global_position.z)
	var ray: Array = PixelView.view_ray(center, vp_pos - Vector2(image_size) * 0.5, world.size_y + 1.0)
	var max_level: int = mini(cut_level, world.size_y - 1)
	var hit := VoxelRaycast.cast(world, ray[0], ray[1], 250.0, max_level)
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
	var center := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
	return center.distance_to(player.position + Vector3(0.0, 0.5, 0.0)) > REACH


func _on_cell_changed(cell: Vector3i) -> void:
	var cx := floori(cell.x / float(CHUNK))
	var cz := floori(cell.z / float(CHUNK))
	var keys := {Vector2i(cx, cz): true}
	if cell.x % CHUNK == 0:
		keys[Vector2i(cx - 1, cz)] = true
	if cell.x % CHUNK == CHUNK - 1:
		keys[Vector2i(cx + 1, cz)] = true
	if cell.z % CHUNK == 0:
		keys[Vector2i(cx, cz - 1)] = true
	if cell.z % CHUNK == CHUNK - 1:
		keys[Vector2i(cx, cz + 1)] = true
	for key in keys:
		if chunk_nodes.has(key):
			_build_chunk(key)
	# A bush disappears when its cell is filled or the ground under it is dug.
	var above := cell + Vector3i(0, 1, 0)
	if bush_cells.has(cell) or bush_cells.has(above):
		bush_cells.erase(cell)
		bush_cells.erase(above)
		_refresh_bushes()
	if cut_level < world.size_y:
		_apply_cut()


# --- Level cutaway -----------------------------------------------------------

func _update_cut() -> void:
	if world == null or player == null:
		return
	var level: int = player.level()
	var px := floori(player.position.x)
	var pz := floori(player.position.z)
	indoor = false
	for y in range(level + 1, mini(level + 9, world.size_y)):
		if Mat.is_roof(world.get_cell(px, y, pz)):
			indoor = true
			break
	var target: int = world.size_y
	if manual_level >= 0:
		target = manual_level
	elif indoor:
		target = level
	if target != cut_level:
		cut_level = target
		_apply_cut()


func _shift_cut(d: int) -> void:
	if world == null:
		return
	var base: int = cut_level if cut_level < world.size_y else player.level()
	manual_level = clampi(base + d, 1, world.size_y)
	if manual_level >= world.size_y - 1:
		manual_level = -1


func _apply_cut() -> void:
	var h := 1000.0 if cut_level >= world.size_y else float(cut_level) + 1.0
	RenderingServer.global_shader_parameter_set("cut_height", h)
	creatures.cut_height = h
	cap_node.mesh = ChunkMesher.build_cap(world, cut_level) if cut_level < world.size_y - 1 else null


# --- Time, seasons, weather --------------------------------------------------

func _update_time(delta: float) -> void:
	var step := delta * time_speed / DAY_LENGTH
	time_of_day = fmod(time_of_day + step, 1.0)
	season_clock += step
	if season_clock >= DAYS_PER_SEASON:
		_next_season()
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


func _next_season() -> void:
	season = (season + 1) % 4
	season_clock = 0.0
	print("season: %s" % SEASONS[season])


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
		effects.update(delta, cam_target, float(player.level()), raining, winter, season, daylight, indoor)


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
	if stick != null:
		v += stick.value
	return v


func _update_hud() -> void:
	if not ready_to_play:
		return
	var hours := int(time_of_day * 24.0)
	var minutes := int(fmod(time_of_day * 24.0 * 60.0, 60.0))
	var weather := "ясно"
	if raining:
		weather = "снегопад" if season == WINTER else "дождь"
	var cut := "" if cut_level >= world.size_y else " · срез %d" % cut_level
	var text := "%s · %02d:%02d · %s\nУровень %d%s · FPS %d" % [
		SEASONS[season], hours, minutes, weather, player.level(), cut, Engine.get_frames_per_second()]
	if show_help:
		text += "\n\n" + HELP
	hud.text = text
	var parts := []
	for i in Mat.PLACEABLE.size():
		var block: String = Mat.NAMES[Mat.PLACEABLE[i]]
		parts.append("[%d %s]" % [i + 1, block] if i == selected else "%d %s" % [i + 1, block])
	hotbar.text = "   ".join(parts)
