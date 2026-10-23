extends "res://tools/shot.gd"
## Measures where a frame goes, scene by scene: each of the game's modules on its own,
## the engine around them, and what the renderer draws (calls, objects, triangles,
## lights). Without a screen it gives the CPU time of the game's own code; with one it
## adds the renderer's numbers:
## godot --headless --path . --script res://tools/profile.gd -- [scene ...]
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/profile.gd -- [scene ...]
## The game's frame (Main._process and the nodes that run every frame) is played by
## this script piece by piece with a clock around each piece. With `spikes` it times
## the things that happen once instead (a window opening, a crafted thing arriving):
## godot --headless --path . --script res://tools/profile.gd -- spikes
## A phone runs the game's code about ten times slower than these numbers.

## Frames measured in a scene: fewer with a screen, where a software renderer takes a
## fifth of a second a frame and the counts do not vary.
var frames := 240
const SETTLE := 60

const SCENES := {
	"day": {"time": 0.45, "season": 1},
	"forest": {"time": 0.42, "season": 1, "forest": true},
	"walk": {"time": 0.45, "season": 1, "keys": [KEY_D]},
	"night-moon": {"time": 0.95, "season": 1, "moon": 1.0},
	"fire-off": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 0},
	"fire-drawn": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 1},
	"fire-mixed": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 3},
	"fire-real": {"time": 0.95, "season": 1, "moon": 0.0, "by_fire": Vector3(0.6, 0.0, -1.4), "fire_shadows": 2},
	"torch-forest-drawn": {"time": 0.95, "season": 1, "moon": 0.0, "forest": true, "fire_shadows": 1},
	"torch-forest-real": {"time": 0.95, "season": 1, "moon": 0.0, "forest": true, "fire_shadows": 2},
	"no-sun-shadows": {"time": 0.45, "season": 1, "shadows": false},
	"rain": {"time": 0.5, "season": 1, "weather": "downpour"},
	"winter": {"time": 0.45, "season": 3, "rain": true},
	"cave": {"time": 0.45, "season": 1, "underground": true},
	"bag": {"time": 0.45, "season": 1, "bag": true},
	"stats": {"time": 0.45, "season": 1, "stats": true},
	# The camera turned (steps of 15 degrees) or tilted (steps of 5 degrees), and
	# turning a step every 20 frames (`spin`).
	"day-turn-45": {"time": 0.45, "season": 1, "turn": 3},
	"day-turn-180": {"time": 0.45, "season": 1, "turn": 12},
	"day-tilt-low": {"time": 0.45, "season": 1, "tilt": -3},
	"day-tilt-steep": {"time": 0.45, "season": 1, "tilt": 3},
	"day-turning": {"time": 0.45, "season": 1, "spin": true},
}

## Microseconds spent in each piece over the measured frames, by name, in the order
## the pieces run.
var acc := {}
var order: Array[String] = []
var t_last := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var spikes := args.has("spikes")
	args.erase("spikes")
	names = args if not args.is_empty() else SCENES.keys()
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_setup = true
	root.add_child(main)
	if spikes:
		_spikes()
	else:
		_profile()


func _lap(what: String) -> void:
	var now := Time.get_ticks_usec()
	if not acc.has(what):
		acc[what] = 0
		order.append(what)
	acc[what] += now - t_last
	t_last = now


## One frame of Main._process with the world ready, and the nodes that run every
## frame, each piece timed.
func _frame(delta: float) -> void:
	var g = main
	var d := minf(delta, 0.05)
	t_last = Time.get_ticks_usec()
	var pl = g.player
	g.clock.step(delta, pl.position)
	g.sky._update_light(1.0 / 60.0)
	# The weather without Effects, which it calls: Effects is timed on its own.
	g.player = null
	g.sky._update_weather(delta)
	g.player = pl
	_lap("clock + sky")
	g.effects.update(delta, g.view.cam_target, pl.position.y, g.sky, g.clock, g.chunks.indoor)
	_lap("effects")
	pl.body.move_input = g.controls.read_move()
	var jump: bool = g.controls.jump() and (pl.body.air_jumps or g.character.can_jump())
	pl.step(d, jump)
	_lap("player")
	g.character.update(d)
	_lap("character")
	g.workshop.update(d)
	_lap("workshop")
	g.controls.update(d)
	_lap("controls")
	g.gathering.update(delta)
	_lap("gathering")
	g.hands.update()
	_lap("hands")
	g._leave_footprints()
	g.save.update(delta)
	_lap("footprints + save")
	g.chunks.update_cut(delta)
	g.chunks.run_jobs()
	g.chunks.update_caps()
	g.roof.flush()
	g.hud.minimap.flush()
	_lap("chunks (cut, jobs, caps, flush)")
	g.view.update(delta)
	g.view.poll_safe_rect(delta)
	_lap("camera")
	g.hud.update_state()
	_lap("hud.update_state")
	g.controls.update_tip(delta)
	_lap("tips")
	g.creatures._process(delta)
	_lap("creatures")
	g.fire_shadows._process(delta)
	_lap("fire_shadows")
	g.tracks._process(delta)
	_lap("tracks")
	g.hud._process(delta)
	_lap("hud._process (perf panel)")


func _profile() -> void:
	while not main.ready_to_play:
		await process_frame
	# The whole map first: streaming is not what is measured here.
	while not (main.chunks.map_done and main.chunks.pending_chunks.is_empty() and main.chunks.job_mesh == null):
		await process_frame
	OS.low_processor_usage_mode_sleep_usec = 0
	var headless := DisplayServer.get_name() == "headless"
	if not headless:
		frames = 60
	var vp: RID = root.get_viewport_rid()
	var sub: RID = main.view.viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	RenderingServer.viewport_set_measure_render_time(sub, true)
	var spawn: Vector3 = main.player.position
	var nodes: Array = [main, main.creatures, main.fire_shadows, main.tracks, main.hud]
	print("scene | frame ms | game code ms | engine ms | calls | objects | tris k | lights (shadowed) | nodes | top pieces")
	for scene_name in names:
		var s: Dictionary = SCENES[scene_name]
		for n in nodes:
			n.set_process(true)
		main.player.position = spawn
		main.clock.time_of_day = s.time
		main.clock.time_speed = 0.0
		main.clock.season = s.season
		main.clock.raining = s.get("rain", false)
		main.clock.set_weather(_weather_index(s.get("weather", "clear")))
		main.sky.moon_override = s.get("moon", -1.0)
		main.settings.values.fire_shadows = s.get("fire_shadows", main.settings.DEFAULTS.fire_shadows)
		main.settings.set_value("shadows", s.get("shadows", true))
		main.chunks.manual_level = -1
		main.settings.values.camera_turn = s.get("turn", 0)
		main.settings.values.camera_tilt = s.get("tilt", 0)
		main.view.look_at_player()
		main.hud.perf.visible = s.get("stats", false)
		if main.hud.bag.visible:
			main.hud.toggle_bag()
		if s.get("forest", false):
			main.player.position = _forest(main.world, main.player.position)
		if s.get("underground", false):
			main.player.position = _cave(main.world, main.player.position)
		if s.has("by_fire"):
			for e: Dictionary in main.placed.things:
				if main.placed.is_fire(e):
					main.player.position = main.placed.center(e) + s.by_fire
					break
		if s.has("keys"):
			main.player.position = _flat_near(main.world, main.player.position)
		main.chunks.build_around()
		if s.get("bag", false):
			main.hud.toggle_bag()
		for i in SETTLE:
			await process_frame
			main.clock.snow = 1.0 if main.clock.season == 3 else 0.0
			main.clock.settle_weather()
			main.clock.wet = 1.0 if main.clock.raining and main.clock.season != 3 else 0.0
		if s.has("keys"):
			_hold(s.keys, true)
		for n in nodes:
			n.set_process(false)
		acc.clear()
		order.clear()
		var frame_us := 0
		var cpu_us := 0.0
		var gpu_us := 0.0
		var calls := 0.0
		var objects := 0.0
		var tris := 0.0
		var last := Time.get_ticks_usec()
		for i in frames:
			if s.get("spin", false) and i % 20 == 0:
				main.view.turn_by(1)
			_frame(main.get_process_delta_time())
			await process_frame
			var now := Time.get_ticks_usec()
			frame_us += now - last
			last = now
			cpu_us += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.viewport_get_measured_render_time_cpu(sub)
			gpu_us += RenderingServer.viewport_get_measured_render_time_gpu(vp) + RenderingServer.viewport_get_measured_render_time_gpu(sub)
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		if s.has("keys"):
			_hold(s.keys, false)
		var game_us := 0
		for k in acc:
			game_us += acc[k]
		var top := order.duplicate()
		top.sort_custom(func(a: String, b: String) -> bool: return acc[a] > acc[b])
		var parts := []
		for k in top.slice(0, 6):
			parts.append("%s %.3f" % [k, acc[k] / 1000.0 / frames])
		var lights := _lights()
		print("%s | %.2f | %.3f | %.2f | %d | %d | %d | %d (%d) | %d | %s" % [scene_name, frame_us / 1000.0 / frames,
			game_us / 1000.0 / frames, (frame_us - game_us) / 1000.0 / frames, roundi(calls / frames),
			roundi(objects / frames), roundi(tris / frames / 1000.0), lights.x, lights.y,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), ", ".join(parts)])
		if not headless:
			print("    render cpu %.2f ms, gpu %.2f ms (software GL: only the share means anything)" % [
				cpu_us / frames, gpu_us / frames])
	for n in nodes:
		n.set_process(true)
	print("full breakdown of the last scene (ms a frame):")
	for k in order:
		print("    %s %.3f" % [k, acc[k] / 1000.0 / frames])
	quit()


## Lights on and how many of them cast shadows: Vector2i(on, shadowed).
func _lights() -> Vector2i:
	var on := 0
	var shadowed := 0
	for l in main.world_root.find_children("*", "Light3D", true, false):
		if l.is_visible_in_tree() and l.light_energy > 0.01:
			on += 1
			if l.shadow_enabled:
				shadowed += 1
	return Vector2i(on, shadowed)


## Things that happen once and can freeze a frame on a slow phone even when the
## average frame is fine: windows opening, a crafted item arriving, a fire put down.
## Prints the time of the call itself and of the two frames after it.
func _spikes() -> void:
	while not main.ready_to_play:
		await process_frame
	while not (main.chunks.map_done and main.chunks.pending_chunks.is_empty() and main.chunks.job_mesh == null):
		await process_frame
	OS.low_processor_usage_mode_sleep_usec = 0
	for i in 30:
		await process_frame
	var hud = main.hud
	var inv = main.character.inventory
	inv.add("core:fiber", 30)
	inv.add("core:branch", 30)
	inv.add("core:flint", 3)
	inv.add("core:campfire", 2)
	print("action | call ms | next frame ms | frame after ms")
	await _spike("open the bag", func() -> void: hud.toggle_bag())
	await _spike("craft tab", func() -> void: hud.bag.show_tab("craft"))
	await _spike("bag tab", func() -> void: hud.bag.show_tab("bag"))
	await _spike("an item into the bag, bag open", func() -> void: main.character.give("core:fiber", 1))
	hud.bag.show_tab("craft")
	await _frames(3)
	await _spike("an item into the bag, craft tab open", func() -> void: main.character.give("core:fiber", 1))
	await _spike("a cord crafted, craft tab open", func() -> void:
		main.workshop.start(Crafting.get_recipe("core:cord"), 1)
		main.workshop.queue.jobs[0].left = 0.0
		main.workshop.update(0.01))
	await _spike("close the bag", func() -> void: hud.toggle_bag())
	await _spike("open the bag again", func() -> void: hud.toggle_bag())
	await _spike("close the bag again", func() -> void: hud.toggle_bag())
	await _spike("an item into the bag, bag closed", func() -> void: main.character.give("core:fiber", 1))
	await _spike("a cord crafted, bag closed", func() -> void:
		main.workshop.start(Crafting.get_recipe("core:cord"), 1)
		main.workshop.queue.jobs[0].left = 0.0
		main.workshop.update(0.01))
	await _spike("select hotbar slot 2", func() -> void: main.controls.select_slot(1))
	await _spike("open the map", func() -> void: hud.map_view.open())
	await _frames(10)
	await _spike("close the map", func() -> void: hud.map_view.close())
	await _spike("open the menu", func() -> void: hud.toggle_menu())
	await _spike("close the menu", func() -> void: hud.toggle_menu())
	await _spike("stats panel on", func() -> void: hud.toggle_stats())
	await _spike("stats panel off", func() -> void: hud.toggle_stats())
	await _spike("a toast", func() -> void: hud.toast("Готово: Верёвка"))
	main.player.facing = "e"
	await _spike("a campfire put down", func() -> void: main.props.put_from_bag("core:campfire"))
	main.clock.time_of_day = 0.95
	await _spike("night falls (torch on)", func() -> void: pass)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _spike(what: String, act: Callable) -> void:
	await _frames(5)
	var t := Time.get_ticks_usec()
	act.call()
	var call_ms := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	await process_frame
	var next_ms := (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	await process_frame
	var after_ms := (Time.get_ticks_usec() - t) / 1000.0
	print("%s | %.2f | %.2f | %.2f" % [what, call_ms, next_ms, after_ms])
