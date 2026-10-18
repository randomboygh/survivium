extends Node
## Technical prototype entry point. Generates the world, builds chunk meshes, and runs
## the player, animals, pixel-snapped camera, time of day, seasons, weather and the
## level cutaway. The 3D scene renders into a low-resolution SubViewport (about 360 px
## tall) that is scaled up without filtering; the UI stays at full resolution.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const VoxelRaycast := preload("res://src/shared/voxel_raycast.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const PlayerScript := preload("res://src/client/player.gd")
const CreaturesScript := preload("res://src/client/creatures.gd")
const TouchStick := preload("res://src/client/touch_stick.gd")
const WorldShader := preload("res://shaders/world.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")

const WORLD_SEED := 20261018
const CHUNK := 16
const TARGET_HEIGHT := 360.0
const CAMERA_SIZE := 22.0
const CAMERA_DISTANCE := 40.0
const DAY_LENGTH := 240.0
const DAYS_PER_SEASON := 2.0
const REACH := 7.0
const SEASONS := ["Весна", "Лето", "Осень", "Зима"]
const WINTER := 3
const FOLIAGE := [Vector3(0.9, 1.12, 0.75), Vector3(1.0, 1.0, 1.0), Vector3(1.5, 0.95, 0.35), Vector3(0.8, 0.68, 0.5)]
const GRASS := [Vector3(0.95, 1.1, 0.85), Vector3(1.0, 1.0, 1.0), Vector3(1.2, 1.0, 0.55), Vector3(0.85, 0.82, 0.7)]
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
var voxel_mat: ShaderMaterial
var water_mat: ShaderMaterial
var chunk_nodes := {}
var pending_chunks: Array[Vector2i] = []
var cap_node: MeshInstance3D
var bushes: MultiMeshInstance3D
var bush_cells: Array[Vector3i] = []
var rain: CPUParticles3D
var snowfall: CPUParticles3D
var hud: Label
var hotbar: Label
var loading: Label
var stick
var mode_button: Button
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
var cut_level := -1
var manual_level := -1
var indoor := false
var selected := 0
var show_help := true
var dig_mode := true
var cam_target := Vector3.ZERO
var fps_clock := 0.0


func _ready() -> void:
	_build_view()
	_build_ui()
	loading.text = "Генерация мира…"
	# Let the loading text show before the heavy generation.
	await get_tree().process_frame
	await get_tree().process_frame
	world = WorldGen.generate(WORLD_SEED)
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
		while not pending_chunks.is_empty() and Time.get_ticks_msec() - t0 < 12:
			_build_chunk(pending_chunks.pop_front())
		var total := ceili(world.size_x / float(CHUNK)) * ceili(world.size_z / float(CHUNK))
		loading.text = "Построение мира… %d%%" % int(100.0 * (total - pending_chunks.size()) / total)
		if pending_chunks.is_empty():
			loading.visible = false
			_place_props()
			creatures.setup(world, player, WORLD_SEED)
			ready_to_play = true
			print("world ready in %d ms" % Time.get_ticks_msec())
	_update_time(delta)
	_update_weather(delta)
	if ready_to_play:
		player.move_input = _read_move()
		player.step(minf(delta, 0.05), Input.is_physical_key_pressed(KEY_SPACE))
	_update_cut()
	_update_camera(delta)
	_update_hud()
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
	elif event is InputEventMouseButton and event.pressed:
		var n: int = Mat.PLACEABLE.size()
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_edit(event.position, dig_mode)
			MOUSE_BUTTON_RIGHT:
				_edit(event.position, false)
			MOUSE_BUTTON_WHEEL_UP:
				selected = (selected - 1 + n) % n
			MOUSE_BUTTON_WHEEL_DOWN:
				selected = (selected + 1) % n


# --- Setup -----------------------------------------------------------------

func _build_view() -> void:
	container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(viewport)
	get_viewport().size_changed.connect(_update_shrink)
	_update_shrink()
	world_root = Node3D.new()
	viewport.add_child(world_root)


func _update_shrink() -> void:
	var h := get_viewport().get_visible_rect().size.y
	container.stretch_shrink = maxi(1, roundi(h / TARGET_HEIGHT))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = _label(layer, Vector2(12, 8))
	hotbar = _label(layer, Vector2(12, 0))
	hotbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	hotbar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading = _label(layer, Vector2.ZERO)
	loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading.add_theme_font_size_override("font_size", 28)
	if DisplayServer.is_touchscreen_available():
		stick = TouchStick.new()
		layer.add_child(stick)
		stick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
		var buttons := HBoxContainer.new()
		layer.add_child(buttons)
		mode_button = _button(buttons, "Копать", _toggle_dig_mode)
		_button(buttons, "Блок", func() -> void: selected = (selected + 1) % Mat.PLACEABLE.size())
		_button(buttons, "Срез ▼", func() -> void: _shift_cut(-1))
		_button(buttons, "Срез ▲", func() -> void: _shift_cut(1))
		_button(buttons, "Сезон", _next_season)
		_button(buttons, "Осадки", func() -> void: raining = not raining)
		buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
		hotbar.offset_bottom -= 64.0
		hotbar.offset_top -= 64.0


func _toggle_dig_mode() -> void:
	dig_mode = not dig_mode
	mode_button.text = "Копать" if dig_mode else "Ставить"


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
	b.custom_minimum_size = Vector2(96, 56)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _build_materials() -> void:
	var atlas := PixelTextures.build_atlas()
	world_mat = ShaderMaterial.new()
	world_mat.shader = WorldShader
	world_mat.set_shader_parameter("atlas", atlas)
	voxel_mat = world_mat.duplicate() as ShaderMaterial
	voxel_mat.set_shader_parameter("use_atlas", false)
	water_mat = ShaderMaterial.new()
	water_mat.shader = WaterShader
	water_mat.set_shader_parameter("atlas", atlas)


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
	sun.directional_shadow_max_distance = 50.0
	world_root.add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.near = 0.1
	camera.far = 200.0
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	world_root.add_child(camera)
	camera.current = true

	cap_node = MeshInstance3D.new()
	cap_node.material_override = world_mat
	world_root.add_child(cap_node)

	player = PlayerScript.new()
	player.world = world
	world_root.add_child(player)
	var spawn: Vector3i = WorldGen.find_spawn(world)
	player.position = Vector3(spawn.x + 0.5, spawn.y, spawn.z + 0.5)
	cam_target = player.position

	creatures = CreaturesScript.new()
	world_root.add_child(creatures)

	rain = _precipitation(Vector2(0.04, 0.5), Color(0.7, 0.8, 1.0, 0.6), 15.0, 9.8, 5.0)
	snowfall = _precipitation(Vector2(0.09, 0.09), Color(1, 1, 1, 0.9), 2.0, 1.0, 30.0)


func _precipitation(size: Vector2, color: Color, speed: float, gravity: float, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 500
	p.lifetime = 14.0 / (speed + gravity)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18.0, 0.5, 18.0)
	p.direction = Vector3(0.0, -1.0, 0.0)
	p.spread = spread
	p.initial_velocity_min = speed
	p.initial_velocity_max = speed * 1.1
	p.gravity = Vector3(0.0, -gravity, 0.0)
	p.local_coords = false
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	quad.material = mat
	p.mesh = quad
	world_root.add_child(p)
	return p


func _place_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED + 100
	for i in 400:
		var x := rng.randi_range(1, world.size_x - 2)
		var z := rng.randi_range(1, world.size_z - 2)
		var y: int = world.surface_y(x, z)
		if y > 0 and y < world.size_y and world.get_cell(x, y - 1, z) == Mat.GRASS and world.get_cell(x, y, z) == Mat.AIR:
			bush_cells.append(Vector3i(x, y, z))
	bushes = MultiMeshInstance3D.new()
	bushes.material_override = voxel_mat
	world_root.add_child(bushes)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = VoxelProps.bush(rng).build_mesh()
	bushes.multimesh = mm
	_refresh_bushes()

	# A chest next to the spawn point.
	var c: Vector3 = player.position + Vector3(2.0, 0.0, 1.0)
	var cell := Vector3i(floori(c.x), floori(c.y), floori(c.z))
	if world.get_cell(cell.x, cell.y, cell.z) == Mat.AIR and world.is_solid(cell.x, cell.y - 1, cell.z):
		var chest := MeshInstance3D.new()
		chest.mesh = VoxelProps.chest().build_mesh()
		chest.material_override = voxel_mat
		chest.scale = Vector3.ONE / 16.0
		chest.position = Vector3(cell)
		world_root.add_child(chest)


func _refresh_bushes() -> void:
	var mm := bushes.multimesh
	mm.instance_count = bush_cells.size()
	var basis := Basis.from_scale(Vector3.ONE / 16.0)
	for i in bush_cells.size():
		mm.set_instance_transform(i, Transform3D(basis, Vector3(bush_cells[i])))


# --- World edits -----------------------------------------------------------

func _build_chunk(key: Vector2i) -> void:
	var meshes: Array = ChunkMesher.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	if not chunk_nodes.has(key):
		var solid := MeshInstance3D.new()
		solid.material_override = world_mat
		world_root.add_child(solid)
		var water := MeshInstance3D.new()
		water.material_override = water_mat
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(water)
		chunk_nodes[key] = [solid, water]
	var nodes: Array = chunk_nodes[key]
	nodes[0].mesh = meshes[0]
	nodes[1].mesh = meshes[1]


func _edit(screen_pos: Vector2, dig: bool) -> void:
	if not ready_to_play:
		return
	var vp_pos := (screen_pos - container.global_position) / float(container.stretch_shrink)
	var origin := camera.project_ray_origin(vp_pos)
	var dir := camera.project_ray_normal(vp_pos)
	var max_level: int = mini(cut_level, world.size_y - 1)
	var hit := VoxelRaycast.cast(world, origin, dir, 250.0, max_level)
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
	for m in [world_mat, voxel_mat, water_mat]:
		m.set_shader_parameter("cut_height", h)
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
	var day := clampf(h * 1.6 + 0.35, 0.0, 1.0)
	sun.rotation_degrees = Vector3(-lerpf(15.0, 75.0, maxf(h, 0.0)), 90.0 - (time_of_day - 0.25) * 360.0, 0.0)
	sun.light_energy = 1.1 * day
	sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.97, 0.9), clampf(h * 2.0, 0.0, 1.0))
	env.ambient_light_color = Color(0.25, 0.3, 0.5).lerp(Color(0.75, 0.78, 0.85), day)
	env.ambient_light_energy = lerpf(0.35, 0.6, day)
	env.background_color = Color(0.03, 0.05, 0.12).lerp(Color(0.16, 0.36, 0.55), day)
	creatures.daylight = day
	if player != null:
		player.torch.light_energy = 1.6 if indoor else 1.6 * (1.0 - day)


func _next_season() -> void:
	season = (season + 1) % 4
	season_clock = 0.0


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
	for m in [world_mat, voxel_mat]:
		m.set_shader_parameter("snow_amount", snow)
		m.set_shader_parameter("wetness", wet)
		m.set_shader_parameter("foliage_tint", foliage)
		m.set_shader_parameter("grass_tint", grass)
	var ice := clampf((snow - 0.3) / 0.5, 0.0, 1.0)
	water_mat.set_shader_parameter("ice_amount", ice)
	world.water_frozen = ice > 0.8
	rain.emitting = raining and not winter and not indoor
	snowfall.emitting = raining and winter and not indoor
	var above := cam_target + Vector3(0.0, 12.0, 0.0)
	rain.position = above
	snowfall.position = above


# --- Camera, input, HUD ----------------------------------------------------

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	cam_target = cam_target.lerp(player.position + Vector3(0.0, 0.5, 0.0), minf(1.0, delta * 6.0))
	# Snap the camera to whole low-res pixels so the pixel art does not shimmer.
	var b := camera.global_transform.basis
	var px := camera.size / float(viewport.size.y)
	var rx := snappedf(cam_target.dot(b.x), px)
	var uy := snappedf(cam_target.dot(b.y), px)
	var fz := cam_target.dot(b.z)
	camera.global_position = b.x * rx + b.y * uy + b.z * (fz + CAMERA_DISTANCE)


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
