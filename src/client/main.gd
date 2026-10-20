extends Node
## Technical prototype entry point: generates the world, builds the scene and runs the
## frame. The work is split between modules that each hold their own state and get
## `self` as `game`: ChunkStreamer (chunk meshes, streaming, the level cut), Sky (time
## of day, seasons, weather, light and colour grade), Controls (keys, mouse, touch and
## the edits they make), CameraRig (the pixel-perfect view and the camera), Props
## (bushes, drifts, the chest and the campfire) and Settings (the saved settings and
## the playtest switches). The 3D scene renders into a low-resolution SubViewport
## (about 360 px tall) in an oblique 3/4 view, is colour graded and scaled up by a
## whole number without filtering (see PixelView); the interface (Hud) is scaled by a
## whole number too.

const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const ChunkStreamer := preload("res://src/client/chunk_streamer.gd")
const SkyScript := preload("res://src/client/sky.gd")
const Controls := preload("res://src/client/controls.gd")
const CameraRig := preload("res://src/client/camera_rig.gd")
const Props := preload("res://src/client/props.gd")
const SettingsScript := preload("res://src/client/settings.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const PlayerScript := preload("res://src/client/player.gd")
const CreaturesScript := preload("res://src/client/creatures.gd")
const Hud := preload("res://src/client/hud.gd")
const Foliage := preload("res://src/client/foliage.gd")
const EffectsScript := preload("res://src/client/effects.gd")
const TracksScript := preload("res://src/client/tracks.gd")
const RoofMap := preload("res://src/client/roof_map.gd")
const WorldShader := preload("res://shaders/world.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")
const LeavesShader := preload("res://shaders/leaves.gdshader")
const LeafShadowShader := preload("res://shaders/leaf_shadow.gdshader")

const WORLD_SEED := 20261018
const CELL := WorldData.CELL

var world
var player
var creatures
var effects
var tracks
var roof: RoofMap
var hud
var chunks: ChunkStreamer
var sky: SkyScript
var controls: Controls
var view: CameraRig
var props: Props
var settings: SettingsScript
## The 3D scene, inside the view's SubViewport.
var world_root: Node3D
var atlas: Texture2D
var world_mat: ShaderMaterial
var water_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var leaves_mat: ShaderMaterial
var leaf_shadow_mat: ShaderMaterial
var grass_mesh: ArrayMesh
var clump_mesh: ArrayMesh
var disc_mesh: ArrayMesh
var ready_to_play := false
## Where the player's last footprint was left, and which foot made it.
var last_print := Vector3.ZERO
var left_foot := false
var fps_clock := 0.0


func _ready() -> void:
	controls = Controls.new(self)
	settings = SettingsScript.new(self)
	settings.load()
	view = CameraRig.new(self)
	chunks = ChunkStreamer.new(self)
	sky = SkyScript.new(self)
	props = Props.new(self)
	view.build(self)
	world_root = view.world_root
	_build_ui()
	get_viewport().size_changed.connect(view.on_screen_resized)
	view.on_screen_resized()
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
	settings.apply()
	chunks.prepare(world)


func _process(delta: float) -> void:
	if world == null:
		return
	if not ready_to_play:
		if chunks.build_near(40):
			hud.set_loading("")
			hud.perf.world_ms = Time.get_ticks_msec()
			# Freezes while the world was being built are not the game's.
			hud.perf.reset()
			hud.perf.chunks = chunks.near_total
			props.place()
			creatures.setup(world, player, WORLD_SEED)
			ready_to_play = true
			print("near meshes built in %d ms" % (chunks.mesh_us / 1000))
			print("world ready in %d ms" % Time.get_ticks_msec())
		else:
			hud.set_loading("Построение мира… %d%%" % int(100.0 * (chunks.near_total - chunks.near_pending) / chunks.near_total))
	sky.update(delta)
	if ready_to_play:
		player.move_input = controls.read_move()
		player.step(minf(delta, 0.05), controls.jump())
		_leave_footprints()
	chunks.update_cut(delta)
	chunks.run_jobs()
	chunks.update_caps()
	view.update(delta)
	if ready_to_play:
		hud.update_state()
		controls.update_tip(delta)
		_report_fps(delta)
	view.poll_safe_rect(delta)


func _input(event: InputEvent) -> void:
	controls.input(event)


func _unhandled_input(event: InputEvent) -> void:
	controls.unhandled_input(event)


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


## F3: prints the view and UI layout and the player state to the log.
func print_debug() -> void:
	var r: Dictionary = hud.debug_rects()
	var p: Vector3 = player.position if player != null else Vector3.ZERO
	print("debug: screen %s, density %.2f, image %s x%d, ui %s, ui scale %.2f, stick %s, buttons %s, jump %s, hotbar %s, menu %s, test %s, season %s, player (%.2f, %.2f, %.2f), season now %s, touch %s, stick value (%.2f, %.2f)" % [
		get_viewport().get_visible_rect().size, DisplayServer.screen_get_scale(), view.viewport.size,
		view.container.stretch_shrink, view.safe_rect, hud.scale.x, r.stick, r.buttons, r.jump, r.hotbar, r.menu, r.test, r.season,
		p.x, p.y, p.z, SkyScript.SEASONS[sky.season], controls.touch, hud.stick.value.x, hud.stick.value.y])


# --- Setup -----------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	# The interface keeps running while the pause menu stops the game.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_touch(controls.touch)


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
	sky.build(world_root)
	view.build_camera()

	player = PlayerScript.new()
	player.world = world
	world_root.add_child(player)
	var spawn: Vector3i = WorldGen.find_spawn(world)
	player.position = (Vector3(spawn) + Vector3(0.5, 0.0, 0.5)) * CELL
	view.look_at_player()

	tracks = TracksScript.new()
	tracks.world = world
	world_root.add_child(tracks)

	creatures = CreaturesScript.new()
	creatures.tracks = tracks
	world_root.add_child(creatures)

	effects = EffectsScript.new()
	world_root.add_child(effects)
