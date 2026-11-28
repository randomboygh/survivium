extends "res://src/client/world/streamer_nodes.gd"
## The chunk streamer's jobs (see chunk_streamer.gd): building chunks a column at a time
## within the frame's budgets (run_jobs), the job set aside while an edit is rebuilt
## (stash), the chunks near the player kept for patching (kept), and unloading.

## Chunks this close to the player (in chunks) are built with the edit budget, so the
## ground the player walks onto is there before the far chunks (the session makes them
## with its near budget too).
const URGENT_CHUNKS := Session.NEAR

## How much of a frame may go to remeshing edited chunks and to
## generating and building the far chunks of the map, in microseconds; a chunk is
## built a column of cells at a time (ChunkMesher.step, Foliage.step, WorldGen.step),
## so what does not fit waits for the next frame. The session's generation (before the
## frame, see gen_budgets) comes out of the same budget: run_jobs takes what it spent.
const EDIT_BUDGET_US := 9000

## Microseconds a frame for building the near chunks behind the main menu (load_steps):
## the menu keeps moving while the world is made, a little slower than at once. Where
## the menu alone takes longer a frame (a slow screen), loading gets as long as it took,
## up to LOAD_MAX_US, so the world is still built in about twice the time at most. Up to
## 2026-11-15 that was 100 ms: where the loading screen took a second a frame (software GL
## on a slow CI runner, 1.1-1.2 s), 24 s of building took 300 s and the phone smoke test
## failed again and again.
const LOAD_BUDGET_US := 14000

const LOAD_MAX_US := 1000000

const STREAM_BUDGET_US := 3000

## While a chunk on screen has no ground yet (the player outran the building: running,
## a fast playtest speed, a boat down a river), building it and making it may take this
## much of a frame: the frame rate drops a while, and less of the world is missing.
const LAG_BUDGET_US := 16000

## ...and for JUMP_SECONDS after a jump (a teleport, coming back to life somewhere not
## built), this much: the frame rate drops to some 30 a second for a moment, and the
## holes close about twice as fast (user's pick, 2026-11-16).
const JUMP_BUDGET_US := 30000

const JUMP_SECONDS := 3.0

## Seconds of the player's way ahead the chunks are built for: the chunks on the screen
## seen from there and from the player come first (see _screen_score).
const LOOK_AHEAD := 1.5

## How far ahead (world units) the look may go at most: three chunks.
const LEAD_MOST := 24.0

## The player's way (see `way`) is taken once the look ahead (lead) is this long (world
## units), and taken again when it turns more than about 20° (the cosine).
const WAY_FROM := 2.0

const WAY_TURN := 0.94

## Chunks this near the player's keep what their meshes and plants were built from (see
## `kept`), so an edit there rebuilds only the columns around it (ChunkMesher.patch):
## every chunk streamed in, so the first tree felled at a new place does not wait for
## whole chunks (a few seconds on a phone). About 0.25 MB a chunk, some 30 MB in all.
const KEEP_CHUNKS := LOAD_RANGE

## Chunks this near the player's that keep nothing (built while it was far, in the ring
## beyond KEEP_CHUNKS that stays drawn) are built again in idle frames to keep it.
const REFILL_CHUNKS := 1

## Chunks whose meshes are freed in one frame at most.
const UNLOADS_PER_FRAME := 2

## Kept jobs of chunks now far let go of in one frame at most: after a long way (a
## teleport, a fall into a cave) all of them are far, and freeing 121 at once took 5 ms
## and more outside the budgets (frame_test, 2026-11-08).
const FORGETS_PER_FRAME := 4

## The near chunks are built by run_jobs a step at a time within LOAD_BUDGET_US
## (behind the main menu) instead of whole by build_near (the loading screen, tools).
var load_steps := false

var near_pending := 0

## When run_jobs ended last frame, and the budget for loading this frame (see LOAD_MAX_US).
var _jobs_end := 0

var load_budget := LOAD_BUDGET_US

## Chunks that changed since they were last meshed, and the chunk being built now
## (see run_jobs): its key, whether it is an edit, its budget, and its mesh and plant
## jobs (none while the session is still making the chunk).
var dirty_chunks := {}

## The chunks among them whose own cells changed (the column of a dug cell, of a felled
## tree), not only a neighbour's: they go before the others, and things fallen near
## them wait for them to be drawn (Props.show_drops).
var edited := {}

## The columns of each of them to build again (Rect2i in cells; the whole chunk for a
## change of how it looks with no cell changed).
var dirty_rects := {}

## The finished mesh and plant jobs of the chunks within KEEP_CHUNKS of the player
## ([ChunkMesher.Job, Foliage.Job] by key), which an edit patches; the chunks within
## REFILL_CHUNKS with none, in the order to build them again, for idle frames;
## and the player's chunk they were listed around.
var kept := {}

var keep_queue: Array[Vector2i] = []

## The kept chunks found far when the player came to another chunk, to let go of a few
## a frame (FORGETS_PER_FRAME).
var forget_queue: Array[Vector2i] = []

var kept_home := Vector2i(-1000000, 0)

## The kept jobs the job being built patches ([] for a whole chunk), and whether it builds
## a chunk only to keep its jobs (it gives way to edits).
var job_old := []

var job_keep := false

## How many edits were built by patching kept jobs (tests).
var patches := 0

## The chunks set aside so far, by key (the last one): a fast machine sets one aside and
## takes it up again within a frame, where `stashed` alone would not show it (frame_test).
var last_stashed := Vector2i(0x7fffffff, 0)

var job_budget := 0

var job_plants: Foliage.Job

## Once the columns of the chunk are built: the part being finished (see run_jobs; -1
## while the columns are still being built) and what the parts made so far.
var job_part := -1

## The chunk being built is new on screen: its ground and water are shown as soon as
## they are built, and its plants (Foliage) are built after (job_part -2, see
## _finish_part). A chunk of `bare` has its ground and waits for its plants.
var job_ground := false

var _last_at := Vector2.INF

var _last_ms := 0

## When the player last jumped more than a chunk in a frame (Time.get_ticks_msec, see
## _track_motion and lag_budget).
var _jumped_ms := -1000000

var job_meshes := []

var job_plant_parts := {}

## Time spent building, for the log.
var mesh_us := 0

## Time spent on each kind of work since take_work last read it, for the loading
## screens (see Main.loading_phase): "meshes", with the session's kinds.
var work_us := {}


## Follows the player's way (lead): its speed over the last frames, LOOK_AHEAD seconds
## of it; a jump of more than a chunk in a frame (a teleport, the respawn) starts over.
func _track_motion() -> void:
	if game.player == null:
		return
	var now := Time.get_ticks_msec()
	var at := _at()
	var dt := (now - _last_ms) / 1000.0
	if not _last_at.is_finite() or dt > 1.0 or at.distance_to(_last_at) > CHUNK * CELL:
		lead = Vector2.ZERO
		if _last_at.is_finite() and at.distance_to(_last_at) > CHUNK * CELL:
			_jumped_ms = now
			if (has_target or job_mesh != null) and not job_edit and not job_keep \
					and _screen_score(job_key, at, _screen_half()) > 0.0:
				# The chunk being built where the player was: it went on at the stream
				# budget a step a frame while the new screen waited (some 250 frames,
				# 2026-11-16), and the server may forget it under the job.
				has_target = false
				_drop_job()
	elif dt > 0.0:
		var want := ((at - _last_at) / dt * LOOK_AHEAD).limit_length(LEAD_MOST)
		lead = lead.lerp(want, 1.0 - exp(-dt * 4.0))
		if lead.length() > WAY_FROM:
			var dir := lead.normalized()
			if way == Vector2.ZERO or dir.dot(way) < WAY_TURN:
				way = dir
	_last_at = at
	_last_ms = now


## Has the session make what a chunk needs and builds its meshes and plants at once
## (the loading screen and tools).
func build_chunk(key: Vector2i) -> void:
	_whole = true
	game.world_maker.make_chunk(key)
	_whole = false
	var t0 := Time.get_ticks_usec()
	var jm := ChunkMesher.start(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	while not ChunkMesher.step(jm, 1 << 30):
		pass
	var meshes: Array = ChunkMesher.finish(jm)
	var jp := Foliage.start(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	while not Foliage.step(jp, 1 << 30):
		pass
	var plants: Dictionary = Foliage.finish(jp)
	mesh_us += Time.get_ticks_usec() - t0
	_note_work("meshes", Time.get_ticks_usec() - t0)
	dirty_chunks.erase(key)
	dirty_rects.erase(key)
	edited.erase(key)
	_keep(key, jm, jp)
	_apply_chunk(key, meshes, plants)
	_apply_lit(key, jm)


## Generates and builds every chunk within reach of the player at once and
## frees the far ones (tools that move the player around): the server is told where
## the body is first, so the session makes and forgets around it.
func build_around() -> void:
	load_home = Vector2i(-1000000, 0)
	has_target = false
	stashed = []
	_drop_job()
	while not paint_queue.is_empty():
		_paint(_next_paint())
	game.mirror.send_input()
	_list_pending()
	while not pending_chunks.is_empty():
		build_chunk(next_chunk())
	map_done = true
	while not unload_queue.is_empty():
		_unload_some()
	game.world_maker.forget_far(1 << 30)
	game.roof.flush()


## Adds `us` to the time spent on a kind of work (see work_us).
func _note_work(kind: String, us: int) -> void:
	work_us[kind] = work_us.get(kind, 0) + us


## The time spent on each kind of work since the last call (usec by kind, the
## session's kinds with "meshes"), and the count starts anew.
func take_work() -> Dictionary:
	var spent := work_us
	work_us = {}
	var made: Dictionary = game.world_maker.take_work()
	for kind: String in made:
		spent[kind] = spent.get(kind, 0) + made[kind]
	return spent


## The budgets for the session's generation next frame (Runner.near_us, far_us):
## loading or paused, the loading budget; playing, the edit budget for the chunks
## near the player and the stream budget for the rest, as for the meshes.
## While edits wait, the far chunks take a step a frame: the edits get the frame.
func gen_budgets() -> Vector2i:
	if not game.ready_to_play or paused:
		return Vector2i(load_budget, load_budget)
	var near := lag_budget() if lagging or focus.is_finite() else EDIT_BUDGET_US
	if lagging and (has_target or job_mesh != null or _ready_on_screen()):
		# A chunk of the screen is made: building it takes half the frame, or the making
		# of the rest of the screen took it all and the first ground came after the last
		# (2 s after a teleport, 2026-11-16).
		near /= 2
	return Vector2i(near, 0 if not dirty_chunks.is_empty() else STREAM_BUDGET_US)


## The budget of building and making while a chunk on the screen has no ground, or the
## world is built ahead where the player is about to go (focus): JUMP_BUDGET_US for a
## while after a jump, else LAG_BUDGET_US.
func lag_budget() -> int:
	return JUMP_BUDGET_US if Time.get_ticks_msec() - _jumped_ms < JUMP_SECONDS * 1000.0 else LAG_BUDGET_US


## The share of the chunks on the screen round the focus (where the player is about to
## go) built, 0..1; 1 with no focus.
func focus_built() -> float:
	if not focus.is_finite():
		return 1.0
	var at := Vector2(focus.x, focus.z)
	var half := _screen_half()
	var size := CHUNK * CELL
	var home := Vector2i((at / size).floor())
	var r := ceili(half.length() / size) + 1
	var all := 0
	var built := 0
	for cz in range(home.y - r, home.y + r + 1):
		for cx in range(home.x - r, home.x + r + 1):
			var key := Vector2i(cx, cz)
			if _screen_score(key, at, half) <= 0.0:
				all += 1
				if chunk_nodes.has(key):
					built += 1
	return float(built) / maxf(1.0, all)


## Does part `job_part` of finishing the chunk being built (the meshes, the plants,
## then handing them to the renderer); true after the last. A chunk new on screen
## (job_ground) shows its ground and water after the meshes' parts, then builds its
## plants (job_part -2, see run_jobs) and finishes them.
func _finish_part() -> bool:
	var i := job_part
	var plants_from := ChunkMesher.FINISH_PARTS + (1 if job_ground else 0)
	if i < ChunkMesher.FINISH_PARTS:
		job_meshes.append(ChunkMesher.finish_part(job_mesh, i))
	elif job_ground and i == ChunkMesher.FINISH_PARTS:
		_chunk_nodes(job_key)
		_apply_ground(job_key, job_meshes)
		_apply_lit(job_key, job_mesh)
		bare[job_key] = true
		if lagging and not job_edit:
			# Behind the player's walk the plants wait (a third of a chunk's building) and
			# the next hole on the screen gets its ground sooner; they are built once the
			# screen has its ground (see run_jobs).
			plants_wait[job_key] = job_mesh
			pending_chunks.append(job_key)
			_drop_job()
			return true
		job_part = -2
		return false
	elif i < plants_from + Foliage.FINISH_PARTS:
		Foliage.finish_part(job_plants, i - plants_from, job_plant_parts)
	else:
		_keep(job_key, job_mesh, job_plants)
		if job_ground:
			_apply_plants(job_key, job_plant_parts)
		else:
			_apply_chunk(job_key, job_meshes, job_plant_parts)
			_apply_lit(job_key, job_mesh)
		bare.erase(job_key)
		plants_wait.erase(job_key)
		_drop_job()
		if job_edit and not dirty_chunks.has(job_key):
			edited.erase(job_key)
		# Things fallen that waited for the ground to change on screen (a felled tree).
		game.props.drops_rebuilt()
		return true
	job_part += 1
	return false


## Forgets the mesh and plant jobs of the chunk being built.
func _drop_job() -> void:
	job_mesh = null
	job_plants = null
	job_old = []
	job_keep = false
	job_ground = false
	job_part = -1
	job_meshes = []
	job_plant_parts = {}


## Sets the chunk being streamed aside for the edits (see stashed).
func _stash_job() -> void:
	stashed = [job_key, job_mesh, job_plants, job_part, job_meshes, job_plant_parts, job_keep, job_budget, job_ground]
	last_stashed = job_key
	has_target = false
	_drop_job()


## Takes the chunk set aside back up where it stopped.
func _unstash_job() -> void:
	job_key = stashed[0]
	job_mesh = stashed[1]
	job_plants = stashed[2]
	job_part = stashed[3]
	job_meshes = stashed[4]
	job_plant_parts = stashed[5]
	job_keep = stashed[6]
	job_budget = stashed[7]
	job_ground = stashed[8]
	job_edit = false
	has_target = not job_keep
	stashed = []


## Forgets the chunk set aside if it is `key` (its cells changed, or it went): a chunk
## being streamed is listed again, one built to keep its jobs is rebuilt for the edit.
func _unstash(key: Vector2i) -> void:
	if stashed.is_empty() or stashed[0] != key:
		return
	if not stashed[6]:
		pending_chunks.append(key)
	stashed = []


## Keeps the finished jobs of chunk `key` for patching if it is within KEEP_CHUNKS of the
## player, forgets them if not.
func _keep(key: Vector2i, jm: ChunkMesher.Job, jp: Foliage.Job) -> void:
	var home := _player_chunk() if game.player != null else kept_home
	if maxi(absi(key.x - home.x), absi(key.y - home.y)) > KEEP_CHUNKS:
		kept.erase(key)
		return
	ChunkMesher.keep(jm)
	kept[key] = [jm, jp]
	keep_queue.erase(key)


## Once the player is in another chunk: forgets the kept jobs of the chunks now far, and
## lists the chunks now near with none to build again when nothing else is to be built,
## the player's first.
func _keep_around() -> void:
	if game.player == null:
		return
	var home := _player_chunk()
	if home == kept_home:
		return
	kept_home = home
	forget_queue.clear()
	for key: Vector2i in kept.keys():
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > KEEP_CHUNKS:
			forget_queue.append(key)
	keep_queue.clear()
	for r in REFILL_CHUNKS + 1:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var key := home + Vector2i(dx, dz)
				if maxi(absi(dx), absi(dz)) == r and chunk_nodes.has(key) and not kept.has(key):
					keep_queue.append(key)


## Builds chunks a step at a time within the frame's budget: edited chunks first (the
## chunk of the edit before its neighbours), then the chunks nearest to the player,
## each once the session has made it; `spent` is what the session's generation took
## this frame already (Runner.take_spent), which comes out of the budget. At least
## one step is taken a frame, so a job always ends. The pieces of work that cost more
## than a step (painting a shaped chunk into the roof map or the minimap, making a
## mesh or the plant buffers, handing them to the renderer) go one a frame, before
## anything else in it; an edit may do several while its budget lasts.
func run_jobs(spent := 0) -> void:
	var t0 := Time.get_ticks_usec() - spent
	budget_us += spent
	if not game.ready_to_play or paused:
		load_budget = clampi(t0 - _jobs_end, LOAD_BUDGET_US, LOAD_MAX_US) if _jobs_end > 0 else LOAD_BUDGET_US
		if not job_edit and (job_mesh != null or has_target):
			job_budget = load_budget
	_list_pending()
	_keep_around()
	_track_motion()
	_check_lag()
	if lagging and not job_edit and job_mesh != null and _on_screen(job_key):
		# A chunk started before the screen reached it (at the stream budget) gets the lag
		# budget from the frame the lag starts, not a step a frame.
		job_budget = lag_budget()
	if not dirty_chunks.is_empty() and game.ready_to_play and not paused:
		# Edits wait: the frame has their budget, whatever was built before (a far chunk
		# at the stream budget, which the making of the world could use up before a
		# single step of the edits, 2026-11-08).
		job_budget = EDIT_BUDGET_US
	var worked := false
	if not paint_queue.is_empty() and not lagging:
		var tp := Time.get_ticks_usec()
		_paint(_next_paint())
		budget_us += Time.get_ticks_usec() - tp
		worked = true
	while true:
		var t1 := Time.get_ticks_usec()
		if t1 - t0 >= job_budget and worked:
			break
		if job_mesh != null and not job_edit and not dirty_chunks.is_empty() and stashed.is_empty() \
				and game.ready_to_play:
			# A chunk being streamed, or built to keep its jobs, waits for the edits.
			_stash_job()
		if job_mesh == null:
			var rect := Rect2i()
			if not dirty_chunks.is_empty():
				if has_target and not dirty_chunks.has(job_key):
					# A chunk being streamed whose job an edit dropped: back into the
					# queue, or it would never be built.
					pending_chunks.append(job_key)
				job_key = dirty_chunks.keys()[0]
				dirty_chunks.erase(job_key)
				rect = dirty_rects.get(job_key, Rect2i())
				dirty_rects.erase(job_key)
				job_edit = true
				job_budget = EDIT_BUDGET_US
				has_target = false
			elif not stashed.is_empty():
				# The chunk set aside for the edits, where it stopped.
				_unstash_job()
				continue
			elif (game.ready_to_play or load_steps) and (has_target or not pending_chunks.is_empty()):
				if not has_target:
					# Behind the player's walk the frame goes to the screen alone: a chunk
					# off it waits until the screen has its ground.
					if lagging and not _ready_on_screen():
						break
					job_key = next_chunk()
					has_target = true
				job_edit = false
				var at := _load_chunk()
				var near := maxi(absi(job_key.x - at.x), absi(job_key.y - at.y)) <= URGENT_CHUNKS
				job_budget = EDIT_BUDGET_US if near else STREAM_BUDGET_US
				if lagging and _screen_score(job_key, _at(), _screen_half()) <= 0.0:
					job_budget = lag_budget()
				elif focus.is_finite() and _screen_score(job_key, Vector2(focus.x, focus.z), _screen_half()) <= 0.0:
					# Where the player is about to go: they wait for it (Trip).
					job_budget = lag_budget()
				if not game.ready_to_play or paused:
					job_budget = load_budget
				if not gen.needed(job_key).is_empty():
					# The session has not made it yet: back into the queue, nearest
					# first again next frame (the player may have walked on), and
					# another one now if some other is not waited for (see waiting).
					pending_chunks.append(job_key)
					has_target = false
					if waiting.has(job_key):
						break
					waiting[job_key] = true
					continue
			elif game.ready_to_play and not paused and not keep_queue.is_empty():
				# Nothing else to build: a chunk near the player built before it came,
				# again, to keep its jobs, at the stream budget.
				job_key = keep_queue.pop_front()
				if not chunk_nodes.has(job_key) or kept.has(job_key):
					continue
				job_edit = false
				job_keep = true
				job_budget = STREAM_BUDGET_US
			else:
				break
			var whole := Rect2i(job_key * CHUNK, Vector2i(CHUNK, CHUNK))
			if job_edit and kept.has(job_key) and rect.has_area() and rect != whole:
				# Only the columns around the change, put into the chunk's kept meshes
				# and plants once built (ChunkMesher.patch).
				job_old = kept[job_key]
				job_mesh = ChunkMesher.start_rect(world, rect.position.x, rect.position.y, rect.end.x, rect.end.y, true)
				job_plants = Foliage.start_part(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK,
					Foliage.part_columns(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK, rect))
			elif not job_edit and not job_keep and plants_wait.has(job_key) and bare.has(job_key):
				# Its ground is shown: only the plants (see plants_wait).
				job_mesh = plants_wait[job_key]
				plants_wait.erase(job_key)
				job_plants = Foliage.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
				job_ground = true
				job_part = -2
			else:
				job_mesh = ChunkMesher.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
				job_plants = Foliage.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
				# Not on screen yet: the ground first, the plants after.
				job_ground = not job_edit and not job_keep and not chunk_nodes.has(job_key)
		var done := false
		if job_part < 0:
			while not done and (Time.get_ticks_usec() - t0 < job_budget or not worked):
				if job_part == -2:
					done = Foliage.step(job_plants, 1)
				elif job_ground:
					done = ChunkMesher.step(job_mesh, 1)
				else:
					done = ChunkMesher.step(job_mesh, 1) and Foliage.step(job_plants, 1)
				worked = true
				if done and not job_old.is_empty():
					# The columns around the change are built: into the kept meshes, then
					# (a step later, each costs a few columns) into the kept plants, then
					# the shadows of the chunk's trees again (Foliage.step).
					if job_old.size() == 2:
						job_mesh = ChunkMesher.patch(job_old[0], job_mesh)
						job_old = [job_old[1]]
					else:
						job_plants = Foliage.patch(job_old[0], job_plants)
						job_old = []
						patches += 1
					done = false
			budget_us += Time.get_ticks_usec() - t1
			_note_work("meshes", Time.get_ticks_usec() - t1)
			if not done:
				break
			job_part = ChunkMesher.FINISH_PARTS + 1 if job_part == -2 else 0
			continue
		# Loading behind the menu or the pause, the parts go on while the budget lasts.
		if worked and not job_edit and game.ready_to_play and not paused:
			break
		var finished := _finish_part()
		worked = true
		budget_us += Time.get_ticks_usec() - t1
		_note_work("meshes", Time.get_ticks_usec() - t1)
		if finished:
			has_target = false
			if not game.ready_to_play and not job_edit and _is_near(job_key, _player_chunk()):
				near_pending = maxi(0, near_pending - 1)
			if not job_edit:
				game.hud.perf.chunks = chunk_nodes.size()
			if not job_edit and pending_chunks.is_empty() and not map_done:
				map_done = true
				print("chunks around built in %d ms (generation %d ms, meshes %d ms)" % [Time.get_ticks_msec(), game.world_maker.gen_us / 1000, mesh_us / 1000])
	if lagging and not paint_queue.is_empty() and Time.get_ticks_usec() - t0 < job_budget:
		# Behind the player's walk or a jump the maps are painted with what is left of the
		# frame: first, a chunk a frame, they held the screen's ground back (a paint and a
		# part of a mesh a frame; after a teleport some 240 frames, 4 s at 60 a second).
		var tp := Time.get_ticks_usec()
		_paint(_next_paint())
		budget_us += Time.get_ticks_usec() - tp
	mesh_us += Time.get_ticks_usec() - t0 - spent
	_unload_some()
	_forget_some()
	_update_haze()
	_jobs_end = Time.get_ticks_usec()


## Lets go of the kept jobs of a few chunks now far (see forget_queue).
func _forget_some() -> void:
	var n := 0
	while not forget_queue.is_empty() and n < FORGETS_PER_FRAME:
		var key: Vector2i = forget_queue.pop_back()
		if maxi(absi(key.x - kept_home.x), absi(key.y - kept_home.y)) > KEEP_CHUNKS and kept.has(key):
			kept.erase(key)
			n += 1


## Frees the meshes of chunk `key` now (the server told the client to forget it).
func unload_chunk(key: Vector2i) -> void:
	if (job_mesh != null or has_target) and job_key == key:
		_drop_job()
		has_target = false
	_unstash(key)
	pending_chunks.erase(key)
	dirty_chunks.erase(key)
	dirty_rects.erase(key)
	edited.erase(key)
	kept.erase(key)
	if not chunk_nodes.has(key):
		return
	_free_chunk(key)
	game.hud.perf.chunks = chunk_nodes.size()


## Frees the meshes of a couple of far chunks a frame.
func _unload_some() -> void:
	var n := 0
	while not unload_queue.is_empty() and n < UNLOADS_PER_FRAME:
		var key: Vector2i = unload_queue.pop_front()
		if not chunk_nodes.has(key):
			continue
		var at := _player_chunk()
		if maxi(absi(key.x - at.x), absi(key.y - at.y)) <= reach():
			continue
		_free_chunk(key)
		n += 1
	if n > 0:
		game.hud.perf.chunks = chunk_nodes.size()


## Frees the nodes of shown chunk `key`: its meshes, its drops and its cap.
func _free_chunk(key: Vector2i) -> void:
	if (job_mesh != null or has_target) and job_key == key and not job_edit:
		# Its ground shown, its plants still being built (job_ground).
		_drop_job()
		has_target = false
	for node: Node in chunk_nodes[key]:
		node.queue_free()
	chunk_nodes.erase(key)
	_standing.erase(key)
	nodes_changes += 1
	bare.erase(key)
	plants_wait.erase(key)
	_unstash(key)
	game.props.hide_drops(key)
	var fx = game.get("effects")
	if fx != null and fx.glows != null:
		fx.glows.set_spots(key, PackedVector3Array())
		fx.lit.set_spots(key, PackedVector3Array())
	dirty_chunks.erase(key)
	dirty_rects.erase(key)
	edited.erase(key)
	kept.erase(key)
	if cap_nodes.has(key):
		cap_nodes[key].queue_free()
		cap_nodes.erase(key)
		cap_levels.erase(key)
	cap_cache.erase(key)
	_caps_ready = -1
