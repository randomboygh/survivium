extends SceneTree
## Plays the game without a screen and fails when a frame takes longer than the
## budgets allow, so a freeze on digging, on streaming chunks or on a cut change is
## caught in CI instead of on a phone. Run:
## godot --headless --path . --script res://tests/frame_test.gd
##
## The budgets in main.gd are wall-clock, so their part of a frame costs about the
## same on any machine; the rest scales with the machine, and a phone runs GDScript
## about ten times slower than a desktop. So each frame is judged in two parts, with
## main.budget_us telling them apart: the budgeted loops may take the budgets plus one
## step, and the rest may take an idle frame of the finished map plus a quarter of
## what a whole chunk costs here. Chunk-sized work slipping into one frame fails the
## test on any machine, and a slow runner does not.

const Mat := preload("res://src/shared/materials.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const Foliage := preload("res://src/client/foliage.gd")
const Shot := preload("res://tools/shot.gd")
const CELL := 0.5
const CHUNK := 16
## Frames over a limit allowed in a scenario, one plus one per this many frames: the
## OS stalls the process now and then, a real freeze comes back with every chunk.
const STALLS_PER_FRAMES := 500

var main: Node
var checks := 0
var failures := 0
var chunk_ms := 0.0
## What the scenarios' callables count (a lambda gets its own copy of a local).
var moved := 0.0
var flips := 0
## Each scenario's name, frame times and the budgeted part of each, judged once the
## idle frame of the finished map is known.
var runs: Array = []


func _initialize() -> void:
	# Without a screen the engine sleeps 6.9 ms a frame (low_processor_usage_mode_sleep_usec),
	# which would hide the game's own time.
	OS.low_processor_usage_mode_sleep_usec = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func _run() -> void:
	# Loading as in the game: the near chunks, 40 ms a frame.
	while not main.ready_to_play:
		await process_frame
	var w = main.world
	var home := Vector2i((Vector2(main.player.position.x, main.player.position.z) / (CHUNK * CELL)).floor())
	# What a whole chunk costs on this machine: the unit the limits are set in.
	var t := Time.get_ticks_usec()
	for i in 3:
		ChunkMesher.build_chunk(w, home.x * CHUNK, home.y * CHUNK, CHUNK)
		Foliage.build_chunk(w, home.x * CHUNK, home.y * CHUNK, CHUNK)
	chunk_ms = (Time.get_ticks_usec() - t) / 3000.0
	print("a chunk costs %.1f ms here" % chunk_ms)

	# The smallest step a job takes must stay far below a chunk, or the budgets
	# cannot be kept: a column, or a tree's shadow, never a phase of the whole chunk.
	var worst_step := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var job := ChunkMesher.start(w, (home.x + dx) * CHUNK, (home.y + dz) * CHUNK, CHUNK)
			var plants := Foliage.start(w, (home.x + dx) * CHUNK, (home.y + dz) * CHUNK, CHUNK)
			var done := false
			while not done:
				t = Time.get_ticks_usec()
				done = ChunkMesher.step(job, 1) and Foliage.step(plants, 1)
				worst_step = maxi(worst_step, Time.get_ticks_usec() - t)
	print("longest step of a job %.2f ms" % (worst_step / 1000.0))
	_check(worst_step / 1000.0 < chunk_ms / 4.0, "a step of a job is under a quarter of a chunk")

	# Streaming the whole map while walking a square (the keys, as the game reads
	# them), so the chunks ahead of the player are urgent and the caps' home moves.
	var start: Vector3 = main.player.position
	var legs: Array[Key] = [KEY_D, KEY_S, KEY_A, KEY_W]
	await _scenario("streaming while walking", 100000, func(i: int) -> bool:
		if i % 500 == 0:
			_key(legs[(i / 500 + 3) % 4], false)
			_key(legs[(i / 500) % 4], true)
		moved = maxf(moved, main.player.position.distance_to(start))
		return main.pending_chunks.is_empty() and main.job_mesh == null)
	for k in legs:
		_key(k, false)
	_check(main.map_done, "the whole map streams in")
	_check(moved > 8.0, "the player walked while the map streamed (%.1f units away at most)" % moved)

	# Standing still on the finished map.
	await _scenario("idle", 120, func(_i: int) -> bool: return false)

	# Digging a ring around the feet and the ground under the nearest bush, then
	# filling it all back, a cell every tenth frame: each edit remeshes the chunk and
	# its neighbours, and the bush goes.
	var p := Vector3i((main.player.position / CELL).floor())
	var cells: Array[Vector3i] = []
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if maxi(absi(dx), absi(dz)) == 2:
				cells.append(Vector3i(p.x + dx, w.surface_y(p.x + dx, p.z + dz) - 1, p.z + dz))
	var bush := Vector3i.ZERO
	for c: Vector3i in main.bush_cells:
		if bush == Vector3i.ZERO or (c - p).length_squared() < (bush - p).length_squared():
			bush = c
	var bushes_before: int = main.bush_cells.size()
	_check(bushes_before > 0, "the map has bushes")
	cells.append(bush - Vector3i(0, 1, 0))
	var before: Array[int] = []
	for c in cells:
		before.append(w.get_cell(c.x, c.y, c.z))
	await _scenario("digging", cells.size() * 10 + 60, func(i: int) -> bool:
		if i % 10 == 0 and i / 10 < cells.size():
			var c: Vector3i = cells[i / 10]
			w.set_cell(c.x, c.y, c.z, Mat.AIR)
			main._on_cell_changed(c)
		return false)
	await _scenario("filling", cells.size() * 10 + 60, func(i: int) -> bool:
		if i % 10 == 0 and i / 10 < cells.size():
			var c: Vector3i = cells[i / 10]
			w.set_cell(c.x, c.y, c.z, before[i / 10])
			main._on_cell_changed(c)
		return false)
	_check(main.dirty_chunks.is_empty() and main.job_mesh == null, "edits are all built")
	_check(main.bush_cells.size() == bushes_before - 1 and not main.world.bushes.has(bush), "the bush dug under is gone")

	# The cut moving up and down every half second, as when walking in and out of a
	# cave: the caps of the chunks around are rebuilt each time.
	var level: int = main.player.level()
	await _scenario("cut changes", 240, func(i: int) -> bool:
		if i % 30 == 0:
			main.manual_level = level - 4 if (i / 30) % 2 == 0 else -1
		return false)
	main.manual_level = -1

	# Jumping in a cave: the view stays cut at the floor level the whole time.
	main.player.position = Shot._cave(w, main.player.position)
	main.player.on_ground = false
	for i in 60:
		await process_frame
	_check(main.indoor and main.cut_level < w.size_y, "the view is cut in the cave")
	var cut: int = main.cut_level
	await _scenario("jumping in a cave", 240, func(i: int) -> bool:
		main.jump_held = i % 40 < 5
		if main.cut_level != cut:
			flips += 1
		return false)
	main.jump_held = false
	_check(flips == 0, "jumping in a cave does not move the cut (%d flips)" % flips)

	# An idle frame of the finished map is the engine's own share: it grows with the
	# chunks on the map and the machine, not with the game's work.
	var idle_ms := 0.0
	for r in runs:
		if r[0] == "idle":
			idle_ms = _mean(r[1])
	var step_limit: float = (main.EDIT_BUDGET_US + main.CAP_BUDGET_US) / 1000.0 + 0.25 * chunk_ms
	var free_limit: float = idle_ms + 2.0 + 0.25 * chunk_ms
	print("a frame may spend %.1f ms in the budgeted loops and %.1f ms outside them (an idle frame is %.1f ms)" % [
		step_limit, free_limit, idle_ms])
	for r in runs:
		var frames: PackedFloat32Array = r[1]
		var steps: PackedFloat32Array = r[2]
		var worst := 0.0
		var worst_in := 0.0
		var worst_free := 0.0
		var over_step := 0
		var over_free := 0
		for i in frames.size():
			worst = maxf(worst, frames[i])
			worst_in = maxf(worst_in, steps[i])
			worst_free = maxf(worst_free, frames[i] - steps[i])
			if steps[i] > step_limit:
				over_step += 1
			if frames[i] - steps[i] > free_limit:
				over_free += 1
		print("%s: %d frames, average %.1f ms, worst %.1f ms; worst budgeted %.1f ms (%d over), worst outside %.1f ms (%d over)" % [
			r[0], frames.size(), _mean(frames), worst, worst_in, over_step, worst_free, over_free])
		var stalls := 1 + frames.size() / STALLS_PER_FRAMES
		_check(over_step <= stalls, "%s keeps the budgeted loops under %.1f ms" % [r[0], step_limit])
		_check(over_free <= stalls, "%s keeps the rest of a frame under %.1f ms" % [r[0], free_limit])
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


## Runs up to `frames` frames calling `act(i)` before each, until it returns true,
## and keeps the time of each frame and its budgeted part for the verdict at the end.
func _scenario(what: String, frames: int, act: Callable) -> void:
	var times := PackedFloat32Array()
	var steps := PackedFloat32Array()
	for i in frames:
		if act.call(i):
			break
		var t := Time.get_ticks_usec()
		var b: int = main.budget_us
		await process_frame
		times.append((Time.get_ticks_usec() - t) / 1000.0)
		steps.append((main.budget_us - b) / 1000.0)
	runs.append([what, times, steps])


## Presses or releases a key for the game, which reads the keyboard through Input.
func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _mean(times: PackedFloat32Array) -> float:
	var total := 0.0
	for ms in times:
		total += ms
	return total / maxi(times.size(), 1)
