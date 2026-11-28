extends "res://tests/unit/test_case.gd"
## The chunk streamer's scheduler (ChunkStreamer.run_jobs with ChunkJob, REND-2) over a small
## world, with a stand-in for Main: the ground first and the plants after while the screen
## has a hole, an edit while a far chunk is streamed (set aside and taken up where it
## stopped), an edit of the chunk being streamed, and a chunk the server forgets while it is
## built. After every step the job and the target agree (see ChunkStreamer.has_target).
## Most steps are taken one at a time: run_jobs given more than its budget as spent takes
## exactly one step (a column of the chunk, or one finishing part).

const ChunkJob := preload("res://src/client/world/chunk_job.gd")

## What run_jobs is told the frame spent already: over any budget, so it takes one step.
const ONE_STEP := 1 << 30
## Steps a chunk takes at most, one at a time (its columns, then its finishing parts).
const CHUNK_STEPS := 2 * WorldData.CHUNK * WorldData.CHUNK + 64


## As much of Main as the streamer reads while it builds and frees chunks.
class FakeMain extends RefCounted:
	var ready_to_play := true
	var player := FakePlayer.new()
	var view := FakeView.new()
	var world_root := Node3D.new()
	var drifts_root := Node3D.new()
	var hud := FakeHud.new()
	var props := FakeProps.new()
	var roof := FakeRoof.new()
	var world_maker := FakeMaker.new()
	var mirror := FakeMirror.new()
	var world_mat: Material = null
	var water_mat: Material = null
	var grass_mat: Material = null
	var leaves_mat: Material = null
	var leaf_shadow_mat: Material = null
	var bush_mat: Material = null
	var low_mat: Material = null
	var tree_mat: Material = null
	var tree_shadow_mat: Material = null
	var grass_mesh: Mesh = null
	var clump_mesh: Mesh = null
	var disc_mesh: Mesh = null
	var bush_mesh: Mesh = null
	var drift_mesh: Mesh = null
	var tree_mesh: Mesh = null

	func free_nodes() -> void:
		world_root.free()
		drifts_root.free()


class FakePlayer extends RefCounted:
	var position := Vector3.ZERO
	var at_level := 0

	func level() -> int:
		return at_level


## A screen of 6 × 6 world units: only the player's chunk is on it.
class FakeView extends RefCounted:
	var camera := FakeCamera.new()
	var image_size := Vector2(1, 1)
	var viewport = null
	var first_person := false


class FakeCamera extends RefCounted:
	var size := 6.0


class FakeHud extends RefCounted:
	var perf := FakePerf.new()
	var minimap = null


class FakePerf extends RefCounted:
	var chunks := 0

	func mark(_what: String) -> void:
		pass


class FakeProps extends RefCounted:
	var drop_nodes := {}
	var rebuilt := 0

	func show_drops(_key: Vector2i, _a := false, _b := false) -> void:
		pass

	func hide_drops(_key: Vector2i) -> void:
		pass

	func drops_rebuilt() -> void:
		rebuilt += 1

	func on_cell_changed(_cell: Vector3i) -> void:
		pass

	func refit_boxes() -> void:
		pass


class FakeRoof extends RefCounted:
	func fill_chunk(_w, _key: Vector2i, _part := 0) -> void:
		pass

	func touch(_w, _cell: Vector3i) -> void:
		pass

	func flush() -> void:
		pass


## The session's maker: the test world is made beforehand, nothing more is.
class FakeMaker extends RefCounted:
	var gen_us := 0

	func make_chunk(_key: Vector2i) -> void:
		pass

	func forget_far(_n: int) -> void:
		pass


class FakeMirror extends RefCounted:
	func send_input() -> void:
		pass


var game: FakeMain
var streamer
var gen: WorldGen
var home: Vector2i
## The chunks made (SHAPED): 3 × 3 round `home`.
var made: Array[Vector2i] = []
## Steps after which the job and the target did not agree, with what was wrong.
var _broken: Array[String] = []


func run() -> void:
	_setup()
	_test_ground_first()
	_test_edit_while_streaming()
	_test_edit_of_streamed()
	_test_edit_beside_streamed()
	_test_keep_job()
	_test_unload_during_job()
	_check(_broken.is_empty(), "the job and the target agree after every step: %s" % [_broken.slice(0, 5)])
	game.free_nodes()


func _setup() -> void:
	gen = WorldGen.new(20261128, 40)
	home = WorldData.chunk_key(gen.spawn_guess.x, gen.spawn_guess.z)
	gen.generate_area(home - Vector2i(1, 1), home + Vector2i(2, 2))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			made.append(home + Vector2i(dx, dz))
	game = FakeMain.new()
	var mid := (Vector2(home) + Vector2(0.5, 0.5)) * (WorldData.CHUNK * WorldData.CELL)
	game.player.position = Vector3(mid.x, 20.0, mid.y)
	game.player.at_level = gen.world.surface_y(int(mid.x / WorldData.CELL), int(mid.y / WorldData.CELL))
	streamer = ChunkStreamer.new(game)
	streamer.prepare(gen)


## One step of run_jobs, then the agreement of the job and the target.
func _step(spent := ONE_STEP) -> void:
	streamer.run_jobs(spent)
	_agree("run_jobs")


func _agree(after: String) -> void:
	var s = streamer
	var j: ChunkJob = s.job
	if j != null:
		if s.has_target != (not j.edit and not j.keep):
			_broken.append("%s: has_target %s with a job edit %s keep %s" % [after, s.has_target, j.edit, j.keep])
		elif s.has_target and s.target != j.key:
			_broken.append("%s: target %s, job %s" % [after, s.target, j.key])
	if s.stashed != null and s.stashed.edit:
		_broken.append("%s: an edit set aside" % after)
	if s.stashed != null and s.stashed == j:
		_broken.append("%s: the job set aside is built too" % after)


## Steps until `done` holds (true) or `most` steps pass (false).
func _steps_until(done: Callable, most: int, spent := ONE_STEP) -> bool:
	for i in most:
		if done.call():
			return true
		_step(spent)
	return done.call()


func _all_built() -> bool:
	for key in made:
		if not streamer.chunk_nodes.has(key) or streamer.bare.has(key):
			return false
	return streamer.job == null and streamer.dirty_chunks.is_empty() and streamer.stashed == null


## The chunk on the screen comes first, its ground shown before its plants are built;
## while the screen has a hole (lagging) its plants wait (plants_wait) and are built once
## it has its ground, the job then building the plants only (ChunkJob.PLANTS_ONLY).
func _test_ground_first() -> void:
	var plants_waited := false
	var plants_only := false
	var first_shown := Vector2i(1 << 20, 0)
	for i in CHUNK_STEPS * 2:
		_step()
		if streamer.plants_wait.has(home):
			plants_waited = true
		var j: ChunkJob = streamer.job
		if j != null and j.key == home and j.part == ChunkJob.PLANTS_ONLY:
			plants_only = true
		if first_shown.x == 1 << 20 and not streamer.chunk_nodes.is_empty():
			first_shown = streamer.chunk_nodes.keys()[0]
		if streamer.chunk_nodes.has(home) and not streamer.bare.has(home):
			break
	_check(first_shown == home, "the chunk on the screen is shown first: %s, home %s" % [first_shown, home])
	_check(plants_waited, "its plants wait while the screen has no ground (plants_wait)")
	_check(plants_only, "they are built by a job of the plants only (ChunkJob.PLANTS_ONLY)")
	_check(streamer.chunk_nodes.has(home) and not streamer.bare.has(home) and not streamer.plants_wait.has(home),
		"the chunk on the screen gets its plants")
	_check(_steps_until(_all_built, CHUNK_STEPS * made.size() * 2, 0), "every chunk made is built")
	_check(streamer.kept.has(home) and streamer.kept.has(made[0]), "the chunks near the player keep their jobs (kept)")


## Lists `key` again for streaming after the server forgot it (as a long walk does).
func _restream(key: Vector2i) -> void:
	streamer.unload_chunk(key)
	_agree("unload_chunk")
	streamer.load_home = Vector2i(-1000000, 0)


## Steps until chunk `key` is being streamed and has built `columns` columns.
func _stream_into(key: Vector2i, columns: int) -> bool:
	var started := _steps_until(func() -> bool:
		return streamer.job != null and not streamer.job.edit and streamer.job.key == key, CHUNK_STEPS)
	for i in columns:
		_step()
	return started and streamer.job != null and streamer.job.key == key and streamer.job.part == ChunkJob.BUILD


## An edit while a far chunk is streamed: the far chunk is set aside (stashed), the edit is
## built at once by patching the kept jobs, and the far chunk goes on where it stopped.
func _test_edit_while_streaming() -> void:
	var far := made[0]
	_restream(far)
	_check(_stream_into(far, 20), "a far chunk is streamed again")
	var streamed: ChunkJob = streamer.job
	var mesh_job: ChunkMesher.Job = streamed.mesh
	var patches: int = streamer.patches
	var cell := Vector3i(home.x * WorldData.CHUNK + 8, game.player.at_level, home.y * WorldData.CHUNK + 8)
	streamer.on_cell_changed(cell)
	_agree("on_cell_changed")
	_check(streamer.dirty_chunks.has(home) and not streamer.dirty_chunks.has(far), "the edit marks the player's chunk only")
	_step()
	_check(streamer.stashed == streamed and streamer.last_stashed == far, "the far chunk is set aside for the edit")
	_check(streamer.job != null and streamer.job.edit and streamer.job.key == home and streamer.job.patching(),
		"the edit is built at once, patching the kept jobs")
	_check(_steps_until(func() -> bool: return streamer.job == streamed, CHUNK_STEPS), "the far chunk is taken up again")
	_check(streamed.mesh == mesh_job and streamed.part == ChunkJob.BUILD and not streamed.edit,
		"where it stopped (the same mesh job), still a stream")
	_check(streamer.patches == patches + 1 and not streamer.edited.has(home), "the edit is built by patching")
	_check(_steps_until(_all_built, CHUNK_STEPS * 2, 0), "the far chunk is built after it")


## An edit of the chunk being streamed while its ground is shown and its plants are built:
## its job is dropped and the chunk is built whole as an edit.
func _test_edit_of_streamed() -> void:
	var far := made[2]
	_restream(far)
	var ground := _steps_until(func() -> bool:
		var j: ChunkJob = streamer.job
		return j != null and j.key == far and j.part == ChunkJob.PLANTS_ONLY, CHUNK_STEPS * 2)
	_check(ground and streamer.bare.has(far) and streamer.chunk_nodes.has(far),
		"a chunk new on screen shows its ground first, then builds its plants")
	streamer.on_cell_changed(Vector3i(far.x * WorldData.CHUNK + 8, 10, far.y * WorldData.CHUNK + 8))
	_agree("on_cell_changed")
	_check(streamer.job == null and streamer.has_target and streamer.target == far, "its job is dropped, it stays the target")
	_step()
	_check(streamer.job != null and streamer.job.edit and streamer.job.key == far and not streamer.has_target,
		"it is built again as an edit")
	_check(_steps_until(_all_built, CHUNK_STEPS * 4, 0), "and shown whole with its plants")
	_check(streamer.pending_chunks.count(far) == 0, "and not listed to stream again")


## An edit beside a chunk being streamed, not on screen yet: its job is dropped (the edit
## reaches its columns) and it goes back into the queue, or it would never be built (the
## bug client-world-2 of an earlier audit).
func _test_edit_beside_streamed() -> void:
	var far := made[8]
	_restream(far)
	_check(_stream_into(far, 10) and not streamer.chunk_nodes.has(far), "a chunk is streamed, not shown yet")
	var corner := Vector3i(far.x * WorldData.CHUNK - 1, game.player.at_level, far.y * WorldData.CHUNK - 1)
	streamer.on_cell_changed(corner)
	_agree("on_cell_changed")
	_check(streamer.job == null and streamer.has_target and streamer.target == far
		and not streamer.dirty_chunks.has(far), "an edit at its corner drops its job")
	_step()
	_check(streamer.job != null and streamer.job.edit and streamer.pending_chunks.has(far),
		"the edit is built, the chunk is back in the queue")
	_check(_steps_until(_all_built, CHUNK_STEPS * 4, 0), "and it is built after")


## A chunk near the player shown without its jobs kept is built again in idle frames to
## keep them (ChunkJob.keep, no target); an edit sets it aside like a streamed one, and it
## is taken up again still to keep, not to stream.
func _test_keep_job() -> void:
	var near := made[1]
	# Idle frames: nothing is left to stream (here the ring round the chunks made never
	# comes, so it is let go of; listing the chunks again brings it back).
	streamer.pending_chunks.clear()
	streamer.kept.erase(near)
	streamer.kept_home = Vector2i(-1000000, 0)
	var keeping := _steps_until(func() -> bool:
		return streamer.job != null and streamer.job.keep and streamer.job.key == near, CHUNK_STEPS)
	_check(keeping and not streamer.has_target, "a chunk near the player is built again to keep its jobs")
	for i in 10:
		_step()
	streamer.on_cell_changed(Vector3i(home.x * WorldData.CHUNK + 8, game.player.at_level, home.y * WorldData.CHUNK + 8))
	_step()
	_check(streamer.stashed != null and streamer.stashed.keep and streamer.stashed.key == near,
		"an edit sets it aside")
	_check(_steps_until(func() -> bool: return streamer.job != null and streamer.job.key == near, CHUNK_STEPS),
		"it is taken up again after the edit")
	_check(streamer.job != null and streamer.job.keep and not streamer.has_target, "still to keep its jobs")
	_check(_steps_until(_all_built, CHUNK_STEPS * 4, 0) and streamer.kept.has(near), "and its jobs are kept")


## A chunk the server forgets while it is built: its job goes, it is not built again
## until it is listed again; forgotten while its plants are built, its nodes go too.
func _test_unload_during_job() -> void:
	var far := made[6]
	_restream(far)
	_check(_stream_into(far, 10), "a chunk is streamed")
	streamer.unload_chunk(far)
	_agree("unload_chunk")
	_check(streamer.job == null and not streamer.has_target and not streamer.pending_chunks.has(far),
		"forgotten while it is built, its job and its place in the queue go")
	for i in CHUNK_STEPS:
		_step(0)
	_check(not streamer.chunk_nodes.has(far) and (streamer.job == null or streamer.job.key != far),
		"and it is not built again")
	streamer.load_home = Vector2i(-1000000, 0)
	var plants := _steps_until(func() -> bool:
		var j: ChunkJob = streamer.job
		return j != null and j.key == far and j.part == ChunkJob.PLANTS_ONLY, CHUNK_STEPS * 2)
	_check(plants and streamer.bare.has(far), "listed again, it is streamed and its ground shown")
	streamer.unload_chunk(far)
	_agree("unload_chunk")
	_check(streamer.job == null and not streamer.chunk_nodes.has(far) and not streamer.bare.has(far)
		and not streamer.plants_wait.has(far), "forgotten while its plants are built, its nodes go")
	streamer.load_home = Vector2i(-1000000, 0)
	_check(_steps_until(_all_built, CHUNK_STEPS * 4, 0), "listed again, it is built whole")
