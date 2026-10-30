extends Node
## Technical prototype entry point: starts the world of the saved settings and shows
## the main menu over it while it is built (MainMenu; a new world from its WorldSetup
## screen restarts the scene), builds the scene and runs the frame. The work is
## split between modules that each hold their own state and get `self` as `game`:
## ChunkStreamer (chunk meshes, streaming, the level cut), Sky (the light, colour grade
## and weather drawn for the clock), Controls (keys, mouse, touch and the edits they
## make), CameraRig (the pixel-perfect view and the camera), Props (the chests,
## workbenches, kilns and campfires drawn, the things on the ground), Character (the
## player's character on this device; DeathScreen shows a death), Gathering (what a tap
## gathers, things taken up by themselves), Hands (what the player is drawn holding),
## Sound (the buses, the ear and the sounds), Settings (the saved settings and the
## playtest switches) and SaveGame (the saved world
## and player). The rules live in src/shared: Clock (time of day, seasons and weather),
## Character (the bag, health, satiety, stamina, death), WorldActions (what the hands do
## to the world), Placed (the things placed on two by two cells) and Workshop (recipes
## known, the crafting queue, tool wear); their signals redraw the chunks and the things.
## The 3D scene renders into a low-resolution SubViewport (about 360 px
## tall) in an oblique 3/4 view, is colour graded and scaled up by a whole number
## without filtering (see PixelView); the interface (Hud) is scaled by a whole number
## too.

const Mat := preload("res://src/shared/content/materials.gd")
const Mods := preload("res://src/shared/content/mods.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const TestGround := preload("res://src/shared/world/test_ground.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const ChunkStreamer := preload("res://src/client/world/chunk_streamer.gd")
const SkyScript := preload("res://src/client/view/sky.gd")
const Clock := preload("res://src/shared/game/clock.gd")
const RealWeather := preload("res://src/shared/game/real_weather.gd")
const Controls := preload("res://src/client/input/controls.gd")
const CameraRig := preload("res://src/client/view/camera_rig.gd")
const Props := preload("res://src/client/game/props.gd")
const CharacterScript := preload("res://src/client/game/character.gd")
const Gathering := preload("res://src/client/game/gathering.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const Storms := preload("res://src/shared/game/storms.gd")
const Workshop := preload("res://src/shared/game/workshop.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const Wildlife := preload("res://src/shared/game/wildlife.gd")
const HandsScript := preload("res://src/client/view/hands.gd")
const CursorScript := preload("res://src/client/input/cursor.gd")
const SettingsScript := preload("res://src/client/settings.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const Plants := preload("res://src/shared/content/plants.gd")
const PlayerScript := preload("res://src/client/view/player.gd")
const CreaturesScript := preload("res://src/client/game/creatures.gd")
const Hud := preload("res://src/client/ui/hud.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Drifts := preload("res://src/client/world/drifts.gd")
const EffectsScript := preload("res://src/client/view/effects.gd")
const FireShadowsScript := preload("res://src/client/view/fire_shadows.gd")
const SunRaysScript := preload("res://src/client/view/sun_rays.gd")
const TracksScript := preload("res://src/client/world/tracks.gd")
const RoofMap := preload("res://src/client/world/roof_map.gd")
const WorldSetup := preload("res://src/client/ui/world_setup.gd")
const MainMenu := preload("res://src/client/ui/main_menu.gd")
const DeathScreen := preload("res://src/client/ui/death_screen.gd")
const SaveGame := preload("res://src/client/save_game.gd")
const SoundScript := preload("res://src/client/audio/sound.gd")
const Markers := preload("res://src/client/game/markers.gd")
const DrawCensus := preload("res://src/client/view/draw_census.gd")
const ShaderWarmup := preload("res://src/client/view/shader_warmup.gd")
const FreezeLog := preload("res://src/client/ui/freeze_log.gd")
const WorldStore := preload("res://src/shared/world/world_store.gd")
const WorldShader := preload("res://shaders/world.gdshader")
const WaterShader := preload("res://shaders/water.gdshader")
const GrassShader := preload("res://shaders/grass.gdshader")
const LeavesShader := preload("res://shaders/leaves.gdshader")
const LeafShadowShader := preload("res://shaders/leaf_shadow.gdshader")

const CELL := WorldData.CELL
## While the land around is built, the loading screens name, each once, the kinds of work
## that took at least LOADING_SHARE of the time (ChunkStreamer.take_work), each caption
## kept LOADING_HOLD at least (msec) so it can be read.
const LOADING_HOLD := 1500
const LOADING_SHARE := 0.05
const LOADING_WORK := {
	"terrain": "Холмы, вода и пещеры",
	"saved": "Участки из сохранения",
	"trees": "Растут деревья",
	"shapes": "Склоны и кусты",
	"meshes": "Земля и трава",
}

var world
var gen: WorldGen
var player
var creatures
var effects
var fire_shadows
## Shafts of sunlight among the trees, flecks of sun and dust in them (SunRays).
var sun_rays
var tracks
var roof: RoofMap
var hud
## The hidden view that builds the night's shaders as the game starts (see shader_warmup.gd).
var warmup: ShaderWarmup
var chunks: ChunkStreamer
var sky: SkyScript
var clock: Clock
## The real world's weather pinned on the clock, when the setting asks (settings.gd).
var real_weather: RealWeather
var controls: Controls
var view: CameraRig
var props: Props
var character: CharacterScript
var gathering: Gathering
## The markers the player set on the map.
var markers: Markers
## The rules of what the hands do to the world (dig, build, chop, gather), once the
## world is made.
var actions: WorldActions
## What strong wind does to the trees and bushes around the player.
var storms: Storms
var workshop: Workshop
var placed: Placed
var wildlife: Wildlife
var hands: HandsScript
var cursor: CursorScript
var settings: SettingsScript
## The buses, the ear, one-off sounds and the loops of nature.
var sound: SoundScript
var save: SaveGame
var menu: MainMenu
var death_screen: DeathScreen
## Counts the frame's draw calls by what is drawn (the playtest page, «Отладка»).
var draw_census: DrawCensus
## Marks what the game did for the freezes' log, and shows the log («Отладка»).
var freeze_log: FreezeLog
## The 3D scene, inside the view's SubViewport, and the snowdrifts of every chunk,
## shown with the snow cover.
var world_root: Node3D
var drifts_root: Node3D
var atlas: Texture2D
var world_mat: ShaderMaterial
## The world shader for low things (chests, workbenches, campfires, things on the
## ground, snow drifts): the player's silhouette does not show behind them.
var low_mat: ShaderMaterial
var water_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var leaves_mat: ShaderMaterial
var leaf_shadow_mat: ShaderMaterial
var bush_mat: ShaderMaterial
var grass_mesh: ArrayMesh
var clump_mesh: ArrayMesh
var disc_mesh: ArrayMesh
var bush_mesh: ArrayMesh
var drift_mesh: ArrayMesh
var ready_to_play := false
## Where the player's last footprint was left, and which foot made it.
var last_print := Vector3.ZERO
var left_foot := false
var fps_clock := 0.0
## Tests and tools start the world from the saved settings without the main menu,
## and nothing is saved unless they give a `save_root` (see WorldStore.root).
var skip_setup := false
var save_root := ""
## The seed and WorldGen settings of the world being played.
var world_seed := 0
var world_options := {}
## The bundles of the mods the world is played with (see Mods).
var world_mods: Array = []
## When the scene started, for the load time.
var start_ms := 0
## What start_world is doing before the chunks are built, for the loading screens.
var loading_stage := ""
## The kind of work the loading screens name while the land is built, and since when
## (msec, see loading_phase).
var _work_shown := ""
var _work_since := 0
## When each kind of work was last named (msec).
var _work_named := {}
## Set before a restart for another world: the scene that comes up goes straight in.
static var play_at_once := false


func _ready() -> void:
	start_ms = Time.get_ticks_msec()
	controls = Controls.new(self)
	settings = SettingsScript.new(self)
	settings.load()
	sound = SoundScript.new(self)
	add_child(sound)
	save = SaveGame.new(self)
	save.enabled = not skip_setup or save_root != ""
	if save_root != "":
		WorldStore.root = save_root
	save.choose_world()
	Mods.activate(world_mods)
	view = CameraRig.new(self)
	chunks = ChunkStreamer.new(self)
	get_tree().process_frame.connect(_build_while_paused)
	sky = SkyScript.new(self)
	clock = Clock.new()
	clock.season_changed.connect(sky.on_season)
	real_weather = RealWeather.new()
	real_weather.clock = clock
	add_child(real_weather)
	save.restore_clock()
	props = Props.new(self)
	placed = Placed.new()
	props.watch(placed)
	placed.cell_changed.connect(chunks.on_cell_changed)
	character = CharacterScript.new(self)
	character.clock = clock
	save.track("inventory", character.inventory)
	save.track("vitals", character.vitals)
	save.track("character", character)
	gathering = Gathering.new(self)
	hands = HandsScript.new(self)
	workshop = Workshop.new(character, placed, settings)
	save.track("knowledge", workshop.knowledge)
	save.track("crafting", workshop.queue)
	save.track("hands", controls)
	markers = Markers.new()
	save.track("markers", markers)
	workshop.settle()
	view.build(self)
	world_root = view.world_root
	_build_ui()
	get_viewport().size_changed.connect(view.on_screen_resized)
	view.on_screen_resized()
	if not skip_setup:
		_build_menu()
	start_world()


## Starts the game again for the world the settings now ask for, past the menu.
func restart() -> void:
	play_at_once = true
	# The pause menu may be open (the playtest page goes to the test world from it).
	get_tree().paused = false
	get_tree().reload_current_scene()


## Generates the world chosen (see SaveGame.choose_world) and builds the scene around
## the spawn, or where the player was when it was saved.
func start_world() -> void:
	# Each heavy part says what it does and lets it show first; `world` is set only once
	# they are done, so nothing runs on a world half made.
	await _loading_stage("Материки и реки…")
	var t0 := Time.get_ticks_msec()
	# The test world is laid out by hand (see TestGround), every other one from noise.
	var maker: GDScript = TestGround if world_seed == TestGround.SEED else WorldGen
	gen = maker.new(world_seed, 48, world_options)
	gen.saved = save.store
	if not save.saved_materials.is_empty():
		# The save numbered its materials in its own order (its mods then): translate.
		gen.material_map = Mat.remap(save.saved_materials)
	print("world %d %s: spawn found in %d ms" % [world_seed, world_options, Time.get_ticks_msec() - t0])
	await _loading_stage("Карта и материалы…")
	roof = RoofMap.new()
	roof.prepare()
	hud.minimap.setup(gen)
	if save.has_save:
		hud.minimap.load_regions(save.store.read_maps())
	_build_materials()
	await _loading_stage("Игрок и вещи…" if save.has_save else "Игрок и небо…")
	world = gen.world
	placed.world = world
	character.world = world
	character.placed = placed
	clock.world = world
	clock.gen = gen
	wildlife = Wildlife.new()
	wildlife.world = world
	wildlife.gen = gen
	wildlife.clock = clock
	actions = WorldActions.new(world, clock, settings)
	actions.cell_changed.connect(chunks.on_cell_changed)
	actions.looks_changed.connect(chunks.remesh_chunk)
	actions.drops_changed.connect(props.show_drops)
	actions.taken.connect(props.fly)
	storms = Storms.new(world, clock, actions)
	freeze_log.watch()
	_build_scene()
	save.restore_player()
	settings.apply()
	chunks.prepare(gen)
	loading_stage = ""


## The part of the loading going on, in a few words for the loading screens: what
## start_world does, then the work going on while the land around is built, each
## caption kept LOADING_HOLD at least so it can be read (see _next_work), then the last
## preparations (the shaders built ahead, see ShaderWarmup).
func loading_phase() -> String:
	if ready_to_play:
		return "Последний штрих"
	if loading_stage != "":
		return loading_stage.trim_suffix("…")
	var now := Time.get_ticks_msec()
	if _work_shown == "" or now - _work_since >= LOADING_HOLD:
		var work := _next_work(chunks.take_work())
		if work != "":
			_work_shown = work
			_work_since = now
			_work_named[work] = now
	return LOADING_WORK.get(_work_shown, "Строим окрестности")


## Of the kinds of work that took a fair share (LOADING_SHARE) of the time `spent`
## (usec by kind, see ChunkStreamer.take_work) and were not named yet, the one that
## took the most, so each caption is shown once, in the order the work comes; "" when
## there is none (the caption shown stays).
func _next_work(spent: Dictionary) -> String:
	var total := 0
	for kind: String in spent:
		total += spent[kind]
	var best := ""
	for kind: String in spent:
		if spent[kind] < LOADING_SHARE * total or _work_named.has(kind):
			continue
		if best == "" or spent[kind] > spent[best]:
			best = kind
	return best


## How far the loading has gone, 0 to 1: a little for start_world's parts, most for the
## near chunks, the rest for the last preparations.
func loading_progress() -> float:
	if ready_to_play:
		return 0.95 if warmup != null else 1.0
	if loading_stage != "" or chunks.near_total == 0:
		return 0.05
	return 0.1 + 0.85 * (chunks.near_total - chunks.near_pending) / chunks.near_total


## Says what start_world does next (`text`) and lets it show for two frames.
func _loading_stage(text: String) -> void:
	loading_stage = text
	hud.set_loading(text)
	await get_tree().process_frame
	await get_tree().process_frame


## While the game is paused (its menu open) the world goes on being built around the
## player, so less is left to build when the game goes on (see ChunkStreamer.paused).
func _build_while_paused() -> void:
	if not get_tree().paused or not ready_to_play or world == null:
		return
	chunks.paused = true
	chunks.run_jobs()
	chunks.update_caps()


func _process(delta: float) -> void:
	# The frame before is over: the statistics take its time and what its parts took.
	var perf = hud.perf
	perf.add_frame(delta)
	if world == null:
		return
	var t := Time.get_ticks_usec()
	chunks.paused = false
	if not ready_to_play:
		# Behind the main menu the chunks are built a step at a time (run_jobs below),
		# so the menu does not stutter; else whole, as fast as it goes.
		chunks.load_steps = menu != null and menu.is_open
		if chunks.near_pending == 0 if chunks.load_steps else chunks.build_near(40):
			hud.set_loading("")
			hud.perf.world_ms = Time.get_ticks_msec() - start_ms
			# Freezes while the world was being built are not the game's.
			hud.perf.reset()
			hud.perf.chunks = chunks.near_total
			if not save.player_placed:
				# The ground is known now: the exact spawn, on level grass.
				var spawn: Vector3i = WorldGen.find_spawn(world, Vector3i((player.position / CELL).floor()))
				player.position = (Vector3(spawn) + Vector3(0.5, 0.0, 0.5)) * CELL
			view.look_at_player()
			props.place()
			character.find_home(placed)
			player.visible = not character.is_dead()
			wildlife.people = [character]
			wildlife.start(world_seed)
			creatures.watch(wildlife)
			ready_to_play = true
			warmup = ShaderWarmup.new(self)
			warmup.start()
			print("near chunks generated in %d ms, meshed in %d ms" % [chunks.gen_us / 1000, chunks.mesh_us / 1000])
			print("world ready in %d ms" % (Time.get_ticks_msec() - start_ms))
		else:
			hud.set_loading("%s… %d%%" % [loading_phase(), roundi(100.0 * loading_progress())])
		t = perf.note("чанки", t)
	clock.step(delta, player.position if player != null else Vector3.INF)
	sky.update(delta)
	t = perf.note("небо", t)
	if ready_to_play:
		# The player stands still behind the main menu, and lies dead behind the death screen.
		var playing: bool = (menu == null or not menu.is_open) and not character.is_dead()
		player.body.move_input = controls.read_move() if playing else Vector2.ZERO
		# An animal the player ran into pushes back by its mass.
		var push: Vector3 = wildlife.pushes[0] if not wildlife.pushes.is_empty() else Vector3.ZERO
		player.body.nudge = Vector2(push.x, push.z) / CELL
		wildlife.pushes.fill(Vector3.ZERO)
		var jump: bool = controls.jump() and playing and (player.body.air_jumps or character.can_jump())
		player.step(minf(delta, 0.05), jump)
		character.update(minf(delta, 0.05))
		workshop.update(minf(delta, 0.05))
		if playing:
			controls.update(minf(delta, 0.05))
			gathering.update(delta)
		hands.update()
		t = perf.note("игрок", t)
		storms.step(delta, player.position)
		_leave_footprints()
		t = perf.note("ветер и следы", t)
		save.update(delta)
		t = perf.note("сохранение", t)
	chunks.update_cut(delta)
	# Behind the death screen the world is made ready where the character comes back.
	chunks.set_focus(character.respawn_points()[0][1] if ready_to_play and character.is_dead() else Vector3.INF)
	chunks.run_jobs()
	chunks.update_caps()
	t = perf.note("чанки", t)
	if roof.flush():
		perf.mark("крыши")
	if hud.minimap.flush():
		perf.mark("карта")
	t = perf.note("карты", t)
	view.update(delta)
	# While the world is built behind the menu's painted sky it is not drawn: in a slow
	# browser drawing the chunks already built took most of each frame of the loading.
	var unseen := not ready_to_play and menu != null and menu.hides_world()
	view.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if unseen else SubViewport.UPDATE_WHEN_VISIBLE
	if warmup != null and warmup.step():
		warmup = null
		hud.perf.warmed_up()
		hud.set_loading("")
	elif warmup != null and (menu == null or not menu.is_open):
		hud.set_loading("%s…" % loading_phase())
	freeze_log.update()
	t = perf.note("камера", t)
	if ready_to_play:
		hud.update_state()
		death_screen.update()
		controls.update_tip(delta)
		_report_fps(delta)
	view.poll_safe_rect(delta)
	perf.note("интерфейс", t)


## The game is saved when the window closes or loses focus (a phone app sent to the
## background, a hidden browser tab).
func _notification(what: int) -> void:
	if save != null and what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT,
			NOTIFICATION_APPLICATION_PAUSED]:
		save.flush()


func _input(event: InputEvent) -> void:
	sound.input(event)
	controls.input(event)


func _unhandled_input(event: InputEvent) -> void:
	if world != null and not character.is_dead():
		controls.unhandled_input(event)


## A boot print every stride on the ground, left and right in turn, none in the water.
func _leave_footprints() -> void:
	tracks.focus = player.position
	if not player.body.on_ground or player.body.water_depth > 0.0:
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
	print("debug: screen %s, density %.2f, image %s x%.2f, ui %s, ui scale %.2f, stick %s, buttons %s, jump %s, hotbar %s, menu %s, test %s, season %s, player (%.2f, %.2f, %.2f), season now %s, touch %s, stick value (%.2f, %.2f)" % [
		get_viewport().get_visible_rect().size, DisplayServer.screen_get_scale(), view.viewport.size,
		view.view_scale, view.safe_rect, hud.scale.x, r.stick, r.buttons, r.jump, r.hotbar, r.menu, r.test, r.season,
		p.x, p.y, p.z, Clock.SEASONS[clock.season], controls.touch, hud.stick.value.x, hud.stick.value.y])


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
	var over := CanvasLayer.new()
	over.layer = layer.layer
	over.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(over)
	death_screen = DeathScreen.new(self)
	over.add_child(death_screen)
	draw_census = DrawCensus.new(self)
	add_child(draw_census)
	freeze_log = FreezeLog.new(self)
	add_child(freeze_log)


## The main menu in a layer over the interface, open from the start.
func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	menu = MainMenu.new(self)
	layer.add_child(menu)
	menu.opened.connect(save.flush)
	menu.closed.connect(save.begin)
	menu.open()
	if play_at_once:
		play_at_once = false
		menu.play()


func _build_materials() -> void:
	atlas = PixelTextures.build_atlas()
	RenderingServer.global_shader_parameter_set("terrain_atlas", atlas)
	hud.set_block_icons(atlas, PixelTextures.TILE, PixelTextures.TILES)
	RenderingServer.global_shader_parameter_set("cloud_noise", PixelTextures.build_cloud_noise())
	world_mat = _material(WorldShader)
	var shapes := PackedInt32Array()
	var bits := PackedInt32Array()
	shapes.resize(21)
	bits.resize(21)
	for m in mini(Mat.COUNT, 21):
		shapes[m] = Mat.corner_shape[m]
		bits[m] = Mat.shader_bits[m]
	# The barks of the trees are materials to the shader too, like the log; both clear
	# round the player like crowns (TRUNK in world.gdshader).
	if Mat.LOG >= 0 and Mat.LOG < 21:
		bits[Mat.LOG] |= Mat.TRUNK
	for m in range(Mat.COUNT, mini(PixelTextures.material_count(), 21)):
		shapes[m] = Mat.corner_shape[Mat.LOG] if Mat.LOG >= 0 else 0
		bits[m] = Mat.shader_bits[Mat.LOG] | Mat.TRUNK if Mat.LOG >= 0 else 0
	world_mat.set_shader_parameter("corner_shapes", shapes)
	world_mat.set_shader_parameter("material_bits", bits)
	low_mat = _material(low_variant(WorldShader))
	low_mat.set_shader_parameter("corner_shapes", shapes)
	low_mat.set_shader_parameter("material_bits", bits)
	water_mat = _material(WaterShader)
	grass_mat = _material(GrassShader)
	grass_mat.set_shader_parameter("plant_texture", PixelTextures.build_plants())
	grass_mat.set_shader_parameter("plant_count", float(PixelTextures.PLANTS + Plants.custom_frames()))
	leaves_mat = _material(LeavesShader)
	var clumps := PixelTextures.build_clumps()
	leaves_mat.set_shader_parameter("clump_texture", clumps)
	leaves_mat.set_shader_parameter("row_reach", PixelTextures.row_reach(clumps.get_image(), PixelTextures.CLUMP))
	leaves_mat.set_shader_parameter("clump_size", Foliage.CLUMP_SIZE)
	leaves_mat.set_shader_parameter("clump_rows", PixelTextures.CLUMP_ROWS)
	leaves_mat.set_shader_parameter("branch_row", PixelTextures.BRANCH_ROW)
	var blossoms := PackedVector3Array()
	blossoms.resize(Trees.BLOSSOMS + 1)
	for s: Dictionary in Trees.SPECIES:
		if s.blossom_slot > 0:
			var c: Color = s.blossom
			blossoms[s.blossom_slot] = Vector3(c.r, c.g, c.b)
	leaves_mat.set_shader_parameter("blossom_colors", blossoms)
	leaf_shadow_mat = _material(LeafShadowShader)
	bush_mat = _material(low_variant(LeavesShader))
	bush_mat.set_shader_parameter("clump_texture", PixelTextures.build_bush_clumps(Foliage.BUSH_CLUMP))
	bush_mat.set_shader_parameter("clump_size", Foliage.BUSH_CLUMP / 16.0)
	bush_mat.set_shader_parameter("clump_rows", PixelTextures.BUSH_ROWS)
	bush_mat.set_shader_parameter("branch_row", PixelTextures.BUSH_TWIG_ROW)
	var berry_colors := PackedVector3Array()
	for b: Dictionary in Bushes.TYPES:
		var c: Color = b.berries
		berry_colors.append(Vector3(c.r, c.g, c.b))
	bush_mat.set_shader_parameter("berry_colors", berry_colors)
	grass_mesh = Foliage.plant_mesh(Foliage.PLANT_W, Foliage.PLANT_H)
	clump_mesh = Foliage.quad_mesh(Foliage.CLUMP_SIZE, true)
	disc_mesh = Foliage.disc_mesh(Foliage.SHADOW_DISC)
	bush_mesh = Foliage.quad_mesh(Foliage.BUSH_CLUMP / 16.0, true)
	drift_mesh = Drifts.mound_mesh()


## A copy of `shader` (world or leaves, which mark what they draw as solid or as a
## crown in the stencil buffer) that marks it low (2), so the player's silhouette
## (sprite_xray) does not show behind it.
static func low_variant(shader: Shader) -> Shader:
	var low := Shader.new()
	low.code = shader.code.replace("stencil_mode write, compare_always, 1;", "stencil_mode write, compare_always, 2;") \
		.replace("stencil_mode write, compare_always, 3;", "stencil_mode write, compare_always, 2;")
	return low


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


func _build_scene() -> void:
	sky.build(world_root)
	view.build_camera()
	sound.build(world_root)

	drifts_root = Node3D.new()
	drifts_root.visible = false
	world_root.add_child(drifts_root)
	player = PlayerScript.new()
	player.body.world = world
	player.body.clock = clock
	character.body = player.body
	world_root.add_child(player)
	# A guess from the laid-out columns; the exact spot is found once the ground is made.
	player.position = (Vector3(gen.spawn_guess) + Vector3(0.5, 0.0, 0.5)) * CELL
	view.look_at_player()

	tracks = TracksScript.new()
	tracks.world = world
	world_root.add_child(tracks)

	creatures = CreaturesScript.new()
	creatures.tracks = tracks
	creatures.perf = hud.perf
	world_root.add_child(creatures)
	player.perf = hud.perf

	effects = EffectsScript.new()
	effects.world = world
	effects.perf = hud.perf
	world_root.add_child(effects)
	fire_shadows = FireShadowsScript.new()
	fire_shadows.game = self
	world_root.add_child(fire_shadows)
	sun_rays = SunRaysScript.new()
	sun_rays.game = self
	world_root.add_child(sun_rays)
	cursor = CursorScript.new()
	cursor.world = world
	world_root.add_child(cursor)
