extends RefCounted
## The chunks of the world on screen and the level cut. The world is generated and
## meshed a chunk at a time around the player (see WorldGen for the stages): the
## chunks near the spawn before play, then the chunks within LOAD_RANGE of the
## player, nearest first, a column of cells (or a row of the generator) at a time
## within a frame budget. Edited chunks are rebuilt first; chunks that fall beyond
## UNLOAD_RANGE lose their meshes, and beyond DROP_RANGE their cells too unless the
## player changed them (they are made again the same). The caps over the cut are kept
## on the chunks around the player, and the cut itself moves: automatic under a roof
## or in a cave, manual with the level buttons. `game` is the Main node that owns the
## scene.

const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")

## Chunk size in cells.
const CHUNK := WorldData.CHUNK
const CELL := WorldData.CELL
## World units the shaders may move what a chunk draws past its mesh (leaves and grass
## swaying, ice raised): the margin of its culling box (see PixelView.sheared_box).
const SWAY := 1.0
## Play starts when the chunks within NEAR_CHUNKS of the spawn are built.
const NEAR_CHUNKS := 3
## Chunks this close to the player (in chunks) are built with the edit budget, so the
## ground the player walks onto is there before the far chunks.
const URGENT_CHUNKS := NEAR_CHUNKS + 1
## Chunks within this many chunks of the player are built, farther than any screen
## shows (a phone held sideways shows about three chunks each way, and the tallest
## mountains a few more to the south); beyond UNLOAD_RANGE their meshes are freed.
const LOAD_RANGE := 5
const UNLOAD_RANGE := 8
## While the game is paused (its menu open) the chunks are built this far, still
## within UNLOAD_RANGE and with their terrain within DROP_RANGE, so less is left to
## build when the player walks on.
const PAUSE_RANGE := LOAD_RANGE + 2
## Beyond this many chunks the generator forgets chunks the player has not changed. A
## chunk LOAD_RANGE away needs the terrain of chunks two farther, which must stay.
const DROP_RANGE := LOAD_RANGE + 4
## Chunks this far (in chunks) from the player's get a cap over the level cut; farther
## ones are off the screen on any device and are built when they come near.
const CAP_RANGE := 5
## How much of a frame may go to building caps, to remeshing edited chunks and to
## generating and building the far chunks of the map, in microseconds; a chunk is
## built a column of cells at a time (ChunkMesher.step, Foliage.step, WorldGen.step),
## so what does not fit waits for the next frame.
const CAP_BUDGET_US := 3000
const EDIT_BUDGET_US := 9000
## Microseconds a frame for building the near chunks behind the main menu (load_steps):
## the menu keeps moving while the world is made, a little slower than at once. Where
## the menu alone takes longer a frame (a slow screen), loading gets as long as it took,
## up to LOAD_MAX_US, so the world is still built in about twice the time at most.
const LOAD_BUDGET_US := 14000
const LOAD_MAX_US := 100000
const STREAM_BUDGET_US := 3000
## Chunks whose meshes are freed, and chunks forgotten, in one frame at most.
const UNLOADS_PER_FRAME := 2
const DROPS_PER_FRAME := 4
## How long the automatic cut must agree before the view follows it, so stepping
## under the rim of a roof does not flip the view back and forth.
const CUT_DELAY := 0.2
## How long the view waits before it closes again over the player walking out from
## behind earth that hid them: along a bumpy hill or wall the cover comes and goes
## column by column, and the trees and bushes cut with it flickered.
const UNHIDE_DELAY := 0.8
## How many levels above and below the player's the level buttons may look; from deep
## in a pit, up to the surface over it (see view_range).
const VIEW_REACH := 4
## The player is down in a ravine, a pit or a cave mouth when earth (not trunks or
## leaves) stands SUNK_RISE levels above the feet within SUNK_REACH cells on at
## least SUNK_SIDES of the eight compass directions: then the view is cut at the
## lowest rim around, so the walls and the ground beyond stay whole and only the
## trees and hills above it show as a ghost.
const SUNK_REACH := 6
const SUNK_RISE := 3
const SUNK_SIDES := 5
## Levels above the feet searched for earth that hides the player from the camera.
const HIDE_REACH := 16
const COMPASS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]
## The parts of a chunk's meshes, in the order of chunk_nodes' arrays.
const PARTS := ["solid", "water", "grass", "clumps", "shadows", "bushes", "drifts"]

var game
var world: WorldData
var gen: WorldGen
var chunk_nodes := {}
## Chunks within LOAD_RANGE still to build, and the chunk they were listed around
## (the player's, see focus).
var pending_chunks: Array[Vector2i] = []
var load_home := Vector2i(-1000000, 0)
var unload_queue: Array[Vector2i] = []
var drop_queue: Array[Vector2i] = []
## The near chunks are built by run_jobs a step at a time within LOAD_BUDGET_US
## (behind the main menu) instead of whole by build_near (the loading screen, tools).
var load_steps := false
var near_pending := 0
## When run_jobs ended last frame, and the budget for loading this frame (see LOAD_MAX_US).
var _jobs_end := 0
var _load_budget := LOAD_BUDGET_US
## The game is paused: run_jobs builds within PAUSE_RANGE on the loading budget.
var paused := false
var load_reach := LOAD_RANGE
var near_total := 0
## While the character lies dead, the respawn point the death screen offers first
## (world units), else Vector3.INF: the chunks are built around it instead of around
## the body, so coming back there lands in a world already made, and none are freed
## meanwhile (the place of death stays behind the screen). See set_focus.
var focus := Vector3.INF
## One cap over the cut per chunk (see update_caps): nodes, the level each was built
## for, and the chunks within CAP_RANGE of the player, nearest first.
var cap_nodes := {}
var cap_levels := {}
var cap_order: Array[Vector2i] = []
var cap_home := Vector2i(-1000000, 0)
## Chunks that changed since they were last meshed, and the chunk being built now
## (see run_jobs): its key, whether it is an edit, its budget, the generator job
## making it or a neighbour ready, and its mesh and plant jobs.
var dirty_chunks := {}
var job_key := Vector2i.ZERO
var job_edit := false
var job_budget := 0
var has_target := false
var job_gen: WorldGen.Job
var job_mesh: ChunkMesher.Job
var job_plants: Foliage.Job
## Once the columns of the chunk are built: the part being finished (see run_jobs; -1
## while the columns are still being built) and what the parts made so far.
var job_part := -1
var job_meshes := []
var job_plant_parts := {}
## Chunks just made whose columns the roof map (part 0) and the minimap (part 1)
## still have to take, one a frame: Vector3i(key.x, key.y, part).
var paint_queue: Array[Vector3i] = []
## True once every chunk within LOAD_RANGE of the player is built.
var map_done := false
## Time spent in the budgeted loops (chunk steps, caps), for tests/frame_test.gd to
## tell it from what a frame does outside a budget.
var budget_us := 0
## Time spent generating and building, for the log.
var mesh_us := 0
var gen_us := 0

var cut_level := -1
var manual_level := -1
## The column whose surface was found last, and that surface (see view_range).
var _surface_at := Vector3i(1 << 30, 0, 0)
var _surface := 0
## The cut the player's position asks for, and how long it has asked for it.
var cut_target := -1
var cut_clock := 0.0
## The level the player last stood on: a jump does not move the cut.
var ground_level := 0
var indoor := false
## The player stands well below the ground around (see SUNK_SIDES), and where that
## was last worked out: Vector3i(x, level, z); the level of the lowest rim around.
var sunk := false
var sunk_rim := 0
var sunk_at := Vector3i(0, -1000, 0)
## The lowest level of earth between the camera and the player's body, -1 for none
## (see _hiding_level); worked out with sunk.
var hidden_by := -1
## True while the cut in force is the one earth hiding the player asked for.
var cut_hides := false
## The view hidden_by was worked out for (up and slope, see _hiding_level).
var _hidden_view := Vector3.ZERO


func _init(g) -> void:
	game = g


## Takes the generator (and its world) and counts the near chunks that must be
## built before play.
func prepare(g: WorldGen) -> void:
	gen = g
	world = g.world
	ground_level = game.player.level()
	_list_pending()
	var home := _player_chunk()
	for key in pending_chunks:
		if _is_near(key, home):
			near_total += 1
	near_pending = near_total


## Builds the near chunks for up to `ms` milliseconds (the loading screen); true once
## they are all built.
func build_near(ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	var home := _player_chunk()
	while near_pending > 0 and Time.get_ticks_msec() - t0 < ms:
		var key := Vector2i.ZERO
		var found := false
		for k in pending_chunks:
			if _is_near(k, home):
				key = k
				found = true
				break
		if not found:
			near_pending = 0
			break
		pending_chunks.erase(key)
		near_pending -= 1
		build_chunk(key)
	return near_pending == 0


func _player_chunk_pos() -> Vector2:
	return Vector2(game.player.position.x, game.player.position.z) / (CHUNK * CELL)


func _player_chunk() -> Vector2i:
	return Vector2i(_player_chunk_pos().floor())


## The chunk the chunks are built around: the player's, or the focus.
func _load_chunk() -> Vector2i:
	if not focus.is_finite():
		return _player_chunk()
	return Vector2i((Vector2(focus.x, focus.z) / (CHUNK * CELL)).floor())


## Builds the chunks around `at` (world units) instead of the player's, Vector3.INF
## for the player again (see focus).
func set_focus(at: Vector3) -> void:
	if at == focus:
		return
	focus = at
	load_home = Vector2i(-1000000, 0)


func _is_near(key: Vector2i, home: Vector2i) -> bool:
	return maxi(absi(key.x - home.x), absi(key.y - home.y)) <= NEAR_CHUNKS


## Lists the chunks within LOAD_RANGE of the player (or the focus) that have no
## meshes yet, and queues the ones beyond UNLOAD_RANGE to lose theirs.
func _list_pending() -> void:
	var home := _load_chunk()
	var reach := PAUSE_RANGE if paused else LOAD_RANGE
	if home == load_home and reach == load_reach:
		return
	load_home = home
	load_reach = reach
	pending_chunks.clear()
	for cz in range(home.y - reach, home.y + reach + 1):
		for cx in range(home.x - reach, home.x + reach + 1):
			var key := Vector2i(cx, cz)
			if not chunk_nodes.has(key) and not (has_target and key == job_key):
				pending_chunks.append(key)
	unload_queue.clear()
	drop_queue.clear()
	if focus.is_finite():
		if not pending_chunks.is_empty():
			map_done = false
		return
	for key: Vector2i in chunk_nodes:
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > UNLOAD_RANGE:
			unload_queue.append(key)
	for key: Vector2i in gen.stages:
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > DROP_RANGE:
			drop_queue.append(key)
	if not pending_chunks.is_empty():
		map_done = false


## The pending chunk nearest to the player (or the focus).
func next_chunk() -> Vector2i:
	var at := _load_chunk()
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


# --- Building ----------------------------------------------------------------

## Generates what a chunk needs and builds its meshes and plants at once (the
## loading screen and tools).
func build_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var need := _prerequisite(key)
	while not need.is_empty():
		gen.run(need[0], need[1])
		# A chunk from the save comes back SHAPED in place of its terrain.
		_on_generated(need[0], gen.stage_of(need[0]), true)
		need = _prerequisite(key)
	gen_us += Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var meshes: Array = ChunkMesher.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	var plants: Dictionary = Foliage.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	mesh_us += Time.get_ticks_usec() - t0
	dirty_chunks.erase(key)
	_apply_chunk(key, meshes, plants)


## Generates and builds every chunk within LOAD_RANGE of the player at once and
## frees the far ones (tools that move the player around).
func build_around() -> void:
	load_home = Vector2i(-1000000, 0)
	has_target = false
	_drop_job()
	job_gen = null
	while not paint_queue.is_empty():
		_paint(paint_queue.pop_front())
	_list_pending()
	while not pending_chunks.is_empty():
		build_chunk(next_chunk())
	map_done = true
	while not unload_queue.is_empty():
		_unload_some()
	while not drop_queue.is_empty():
		_drop_some()
	game.roof.flush()


## The next generator stage some chunk needs before `key` can be meshed: [chunk,
## stage], or empty when it can be. A chunk is meshed once it is SHAPED, which takes
## the chunks around it PLANTED, which takes the chunks around those with terrain.
func _prerequisite(key: Vector2i) -> Array:
	var m: Variant = gen.missing(key, 2, WorldGen.TERRAIN)
	if m != null:
		return [m, WorldGen.TERRAIN]
	m = gen.missing(key, 1, WorldGen.PLANTED)
	if m != null:
		return [m, WorldGen.PLANTED]
	if gen.stage_of(key) < WorldGen.SHAPED:
		return [key, WorldGen.SHAPED]
	return []


## A chunk reached a stage: once it is SHAPED its columns are final, so the roof
## map and the minimap take them, at once with `now` (the loading screen and tools),
## else one a frame (see run_jobs). The minimap paints its ground already at TERRAIN,
## two chunks ahead of the meshes, so the world is not seen being made at its edge;
## the trees come in with SHAPED.
func _on_generated(key: Vector2i, stage: int, now := false) -> void:
	var parts: Array
	if stage == WorldGen.SHAPED:
		parts = [0, 1]
	elif stage == WorldGen.TERRAIN:
		parts = [1]
	for part: int in parts:
		if now:
			_paint(Vector3i(key.x, key.y, part))
		else:
			paint_queue.append(Vector3i(key.x, key.y, part))


## Paints chunk (item.x, item.y) into the roof map (item.z 0) or the minimap (1).
func _paint(item: Vector3i) -> void:
	var key := Vector2i(item.x, item.y)
	if not world.has_chunk(key):
		return
	if item.z == 0:
		game.roof.fill_chunk(world, key)
	elif game.hud != null and game.hud.minimap != null:
		game.hud.minimap.paint_chunk(world, key)


## Does part `job_part` of finishing the chunk being built (the meshes, the plants,
## then handing them to the renderer); true after the last.
func _finish_part() -> bool:
	var i := job_part
	if i < ChunkMesher.FINISH_PARTS:
		job_meshes.append(ChunkMesher.finish_part(job_mesh, i))
	elif i < ChunkMesher.FINISH_PARTS + Foliage.FINISH_PARTS:
		Foliage.finish_part(job_plants, i - ChunkMesher.FINISH_PARTS, job_plant_parts)
	else:
		_apply_chunk(job_key, job_meshes, job_plant_parts)
		_drop_job()
		return true
	job_part += 1
	return false


## Forgets the mesh and plant jobs of the chunk being built.
func _drop_job() -> void:
	job_mesh = null
	job_plants = null
	job_part = -1
	job_meshes = []
	job_plant_parts = {}


## Generates and builds chunks a step at a time within the frame's budget: edited
## chunks first (the chunk of the edit before its neighbours), then the chunks
## nearest to the player, generating what each needs before its meshes. At least one
## step is taken a frame, so a job always ends. The pieces of work that cost more than
## a step (painting a shaped chunk into the roof map or the minimap, making a mesh or
## the plant buffers, handing them to the renderer) go one a frame, before anything
## else in it; an edit may do several while its budget lasts.
func run_jobs() -> void:
	var t0 := Time.get_ticks_usec()
	if not game.ready_to_play or paused:
		_load_budget = clampi(t0 - _jobs_end, LOAD_BUDGET_US, LOAD_MAX_US) if _jobs_end > 0 else LOAD_BUDGET_US
		if not job_edit and (job_mesh != null or job_gen != null or has_target):
			job_budget = _load_budget
	_list_pending()
	var worked := false
	if not paint_queue.is_empty():
		_paint(paint_queue.pop_front())
		budget_us += Time.get_ticks_usec() - t0
		worked = true
	while true:
		var t1 := Time.get_ticks_usec()
		if t1 - t0 >= job_budget and worked:
			break
		if job_mesh == null and job_gen == null:
			if not dirty_chunks.is_empty():
				job_key = dirty_chunks.keys()[0]
				dirty_chunks.erase(job_key)
				job_edit = true
				job_budget = EDIT_BUDGET_US
				has_target = false
			elif (game.ready_to_play or load_steps) and (has_target or not pending_chunks.is_empty()):
				if not has_target:
					job_key = next_chunk()
					has_target = true
				job_edit = false
				var at := _load_chunk()
				var near := maxi(absi(job_key.x - at.x), absi(job_key.y - at.y)) <= URGENT_CHUNKS
				job_budget = EDIT_BUDGET_US if near else STREAM_BUDGET_US
				if not game.ready_to_play or paused:
					job_budget = _load_budget
			else:
				break
			var need := _prerequisite(job_key)
			if need.is_empty():
				job_mesh = ChunkMesher.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
				job_plants = Foliage.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
			else:
				job_gen = gen.start(need[0], need[1])
		var done := false
		if job_gen != null:
			var tg := Time.get_ticks_usec()
			while not done and (Time.get_ticks_usec() - t0 < job_budget or not worked):
				done = gen.step(job_gen, 1)
				worked = true
			gen_us += Time.get_ticks_usec() - tg
			budget_us += Time.get_ticks_usec() - t1
			if done:
				# A chunk from the save comes back SHAPED in place of its terrain.
				_on_generated(job_gen.key, job_gen.stage)
				job_gen = null
			continue
		if job_part < 0:
			while not done and (Time.get_ticks_usec() - t0 < job_budget or not worked):
				done = ChunkMesher.step(job_mesh, 1) and Foliage.step(job_plants, 1)
				worked = true
			budget_us += Time.get_ticks_usec() - t1
			if not done:
				break
			job_part = 0
			continue
		# Loading behind the menu or the pause, the parts go on while the budget lasts.
		if worked and not job_edit and game.ready_to_play and not paused:
			break
		var finished := _finish_part()
		worked = true
		budget_us += Time.get_ticks_usec() - t1
		if finished:
			has_target = false
			if not game.ready_to_play and not job_edit and _is_near(job_key, _player_chunk()):
				near_pending = maxi(0, near_pending - 1)
			if not job_edit:
				game.hud.perf.chunks = chunk_nodes.size()
			if not job_edit and pending_chunks.is_empty() and not map_done:
				map_done = true
				print("chunks around built in %d ms (generation %d ms, meshes %d ms)" % [Time.get_ticks_msec(), gen_us / 1000, mesh_us / 1000])
	mesh_us += Time.get_ticks_usec() - t0
	_unload_some()
	_drop_some()
	_jobs_end = Time.get_ticks_usec()


## Forgets a few chunks far from the player a frame (see WorldGen.forget).
func _drop_some() -> void:
	var n := 0
	var at := _player_chunk()
	while not drop_queue.is_empty() and n < DROPS_PER_FRAME:
		var key: Vector2i = drop_queue.pop_back()
		if maxi(absi(key.x - at.x), absi(key.y - at.y)) > DROP_RANGE and gen.forget(key):
			n += 1


## Frees the meshes of a couple of far chunks a frame.
func _unload_some() -> void:
	var n := 0
	while not unload_queue.is_empty() and n < UNLOADS_PER_FRAME:
		var key: Vector2i = unload_queue.pop_front()
		if not chunk_nodes.has(key):
			continue
		var at := _player_chunk()
		if maxi(absi(key.x - at.x), absi(key.y - at.y)) <= LOAD_RANGE:
			continue
		for node: Node in chunk_nodes[key]:
			node.queue_free()
		chunk_nodes.erase(key)
		dirty_chunks.erase(key)
		if cap_nodes.has(key):
			cap_nodes[key].queue_free()
			cap_nodes.erase(key)
			cap_levels.erase(key)
		n += 1
	if n > 0:
		game.hud.perf.chunks = chunk_nodes.size()


func _apply_chunk(key: Vector2i, meshes: Array, plants: Dictionary) -> void:
	cap_levels.erase(key)
	if not chunk_nodes.has(key):
		var solid := MeshInstance3D.new()
		solid.material_override = game.world_mat
		var water := MeshInstance3D.new()
		water.material_override = game.water_mat
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tufts := Foliage.multimesh(game.grass_mesh, game.grass_mat, false, true)
		tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var crowns := Foliage.multimesh(game.clump_mesh, game.leaves_mat, true, true)
		crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shade := Foliage.multimesh(game.disc_mesh, game.leaf_shadow_mat, false, true)
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shade.layers = PixelView.LAYER_SUN_CASTER
		var bushes := Foliage.multimesh(game.bush_mesh, game.bush_mat, true, true)
		bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var drifts := Foliage.multimesh(game.drift_mesh, game.low_mat, false, false)
		var parts: Array = [solid, water, tufts, crowns, shade, bushes, drifts]
		for n in parts:
			if n == drifts:
				game.drifts_root.add_child(n)
			else:
				game.world_root.add_child(n)
		chunk_nodes[key] = parts
		# What lies on the ground of a chunk from the save.
		if world.drops.has(key) and not game.props.drop_nodes.has(key):
			game.props.show_drops(key)
	var nodes: Array = chunk_nodes[key]
	nodes[0].mesh = meshes[0]
	nodes[1].mesh = meshes[1]
	for i in range(2, PARTS.size()):
		var part: Array = plants[PARTS[i]]
		var mm: MultiMesh = nodes[i].multimesh
		mm.instance_count = part[0]
		if part[0] > 0:
			mm.buffer = part[1]
	for n: GeometryInstance3D in nodes:
		_fit_box(n)


## Fits the culling boxes of every chunk shown to the views the camera may show next
## (PixelView.box_views), when it turns or tilts.
func refit_boxes() -> void:
	for parts: Array in chunk_nodes.values():
		for n: GeometryInstance3D in parts:
			_fit_box(n)
	for n: GeometryInstance3D in cap_nodes.values():
		_fit_box(n)


## Culls a part of a chunk by what it draws, moved north as the shaders draw it, instead
## of a margin of a level's height all round, which kept nearly every chunk loaded drawn
## (636 draw calls against 301 at the spawn by day, 2026-10-21).
static func _fit_box(n: GeometryInstance3D) -> void:
	var box := AABB()
	if n is MeshInstance3D:
		if n.mesh == null:
			return
		box = n.mesh.get_aabb()
	else:
		var mm: MultiMesh = n.multimesh
		if mm.instance_count == 0:
			return
		box = mm.get_aabb()
	n.custom_aabb = PixelView.sheared_box(box, SWAY)


## Queues the chunks a changed cell touches for a rebuild, the chunk of the cell
## first, and tells the roof map and the props.
func on_cell_changed(cell: Vector3i) -> void:
	game.roof.touch(world, cell)
	# The ground around the player may have risen or gone: look again.
	sunk_at.y = -1000
	if game.hud != null and game.hud.minimap != null:
		game.hud.minimap.touch(world, cell)
	# Slopes and corners look at the neighbours, edges of a top at theirs, and the
	# surface of a slope at the slopes beside it (three columns in all). The chunk of
	# the cell goes first in the queue, its neighbours after (see run_jobs).
	var home := WorldData.chunk_key(cell.x, cell.z)
	var keys := {}
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			keys[WorldData.chunk_key(cell.x + dx, cell.z + dz)] = true
	if job_mesh != null and keys.has(job_key):
		# The chunk being built changed under the job: start it over.
		_drop_job()
		if job_edit:
			keys[job_key] = true
		else:
			has_target = true
	var queue := {}
	if chunk_nodes.has(home):
		queue[home] = true
	for key in keys:
		if chunk_nodes.has(key):
			queue[key] = true
	for key in dirty_chunks:
		queue[key] = true
	dirty_chunks = queue
	game.props.on_cell_changed(cell)


## Builds the mesh of chunk `key` again, by itself: what is drawn on it changed (the
## berries of a bush) but no cell did.
func remesh_chunk(key: Vector2i) -> void:
	if not chunk_nodes.has(key):
		return
	if job_mesh != null and job_key == key:
		_drop_job()
		if not job_edit:
			has_target = true
	dirty_chunks[key] = true


# --- Level cutaway -----------------------------------------------------------

func update_cut(delta: float) -> void:
	var player = game.player
	if world == null or player == null:
		return
	if player.body.on_ground:
		ground_level = player.level()
	else:
		# A jump does not move the cut, but a climb by jumps in the air (a playtest
		# switch) takes it along a level behind the feet, so the view leaves a cave
		# with the player instead of on landing.
		ground_level = maxi(ground_level, player.level() - 1)
	# The player stands on `level` and is two cells tall.
	var level := ground_level
	var px := floori(player.position.x / CELL)
	var pz := floori(player.position.z / CELL)
	indoor = false
	for y in range(level + 2, mini(level + 18, world.size_y)):
		if Mat.is_roof(world.get_cell(px, y, pz)):
			indoor = true
			break
	var at := Vector3i(px, level, pz)
	if at != sunk_at:
		sunk_at = at
		sunk = not indoor and _walled_sides(px, level, pz) >= SUNK_SIDES
		hidden_by = _hiding_level(px, level, pz)
	elif _hidden_view != Vector3(PixelView.up.x, PixelView.up.y, PixelView.slope):
		hidden_by = _hiding_level(px, level, pz)
	var target: int = world.size_y
	if manual_level >= 0:
		# Walking away from the levels looked at brings the view back within reach.
		var reach := view_range()
		if manual_level > reach.y:
			manual_level = -1
		else:
			manual_level = maxi(manual_level, reach.x)
	if manual_level >= 0:
		target = manual_level
	elif indoor:
		target = level + 1
	else:
		if sunk:
			target = sunk_rim
		# Whatever stands between the camera and the player goes, from any side: a
		# ravine running across the view, the near wall of a diagonal one, a hill.
		if hidden_by >= 0:
			target = mini(target, hidden_by - 1)
	if target != cut_target:
		cut_target = target
		cut_clock = 0.0
	if target == cut_level:
		return
	# A chosen level applies at once; the automatic one once it has held for a moment,
	# longer when the view closes over a player who was hidden.
	cut_clock += delta
	var wait := UNHIDE_DELAY if cut_hides and target > cut_level else CUT_DELAY
	if cut_level < 0 or manual_level >= 0 or cut_clock >= wait:
		cut_level = target
		cut_hides = manual_level < 0 and not indoor and hidden_by >= 0 and target == hidden_by - 1
		_apply_cut()


## How many of the eight compass directions from column (x, z) meet earth SUNK_RISE
## levels above `level` within SUNK_REACH cells; sunk_rim becomes the top of the
## lowest of the walls met.
func _walled_sides(x: int, level: int, z: int) -> int:
	var y := level + SUNK_RISE
	if y >= world.size_y:
		return 0
	var sides := 0
	sunk_rim = world.size_y - 1
	for d in COMPASS:
		for r in range(1, SUNK_REACH + 1):
			var cx := x + d.x * r
			var cz := z + d.y * r
			if Mat.is_roof(world.get_cell(cx, y, cz)):
				sides += 1
				# The top of the earth in that column, from the level met upward.
				var top := y
				while top + 1 < world.size_y and Mat.is_roof(world.get_cell(cx, top + 1, cz)):
					top += 1
				sunk_rim = mini(sunk_rim, top)
				break
	return sides


## The lowest level of earth (not trunks or leaves) that covers most of the body of a
## player standing on `level` in column (x, z), as the camera sees it, or -1. In the
## default 3/4 view a cell (x, y, z) covers the screen rows z - y - 1 .. z - y + 1 (its
## top and its south face) and the body, two cells tall, the rows pz - level - 1.5 ..
## pz - level + 0.5; earth above the head counts where it covers more than half of
## them. A wall the head looks over hides only the legs and is left alone. A turned or
## tilted view looks along its own way: a cell y - level up is drawn over the body
## from (y - level) * slope cells toward the camera.
func _hiding_level(x: int, level: int, z: int) -> int:
	var up := PixelView.up
	_hidden_view = Vector3(up.x, up.y, PixelView.slope)
	var body := Vector2(x + 0.5, z + 0.5)
	for y in range(level + 2, mini(level + 2 + HIDE_REACH, world.size_y)):
		var ahead := body - up * PixelView.slope * (y - level)
		for c: Vector2 in [ahead + up, ahead]:
			if Mat.is_roof(world.get_cell(floori(c.x), y, floori(c.y))):
				return y
	return -1


func shift_cut(d: int) -> void:
	if world == null:
		return
	var reach := view_range()
	# The view stays at the ends of the reach (the level button goes back to the
	# automatic cut); a cut over the whole world is none.
	manual_level = clampi(cut_base() + d, reach.x, reach.y)
	if manual_level >= world.size_y - 1:
		manual_level = -1


## The level the buttons step from: the level chosen, the cut, or above the player
## with none.
func cut_base() -> int:
	if manual_level >= 0:
		return manual_level
	return cut_level if cut_level < world.size_y else game.player.level() + 1


## The lowest and highest levels the level buttons may cut the view at: VIEW_REACH
## around the player's, and from below the surface of the column up to it, so a
## player fallen into a pit can look up out of it. The playtest switch lifts it.
func view_range() -> Vector2i:
	if game.settings.free_view:
		return Vector2i(1, world.size_y)
	var level: int = game.player.level()
	# Looked up again on a step to another column or level (a dug pit changes it).
	var at := Vector3i(floori(game.player.position.x / CELL), level, floori(game.player.position.z / CELL))
	if at != _surface_at:
		_surface_at = at
		_surface = 0
		for y in range(world.size_y - 1, 0, -1):
			if Mat.is_roof(world.get_cell(at.x, y, at.z)):
				_surface = y
				break
	return Vector2i(maxi(1, level - VIEW_REACH), maxi(level + VIEW_REACH, _surface + 1))


## Back to the automatic cut that follows the player.
func reset_view_level() -> void:
	manual_level = -1


func _apply_cut() -> void:
	var h := 1000.0 if cut_level >= world.size_y else (cut_level + 1) * CELL
	RenderingServer.global_shader_parameter_set("cut_height", h)
	RenderingServer.global_shader_parameter_set("cut_ghost", 1.0 if manual_level < 0 else 0.0)
	# The caps follow in update_caps, nearest chunk first; with no cut they go at once.
	if cut_level >= world.size_y - 1:
		for key in cap_levels:
			cap_nodes[key].mesh = null
		cap_levels.clear()


## Brings the caps of the chunks around the player to the current cut, nearest first,
## a few a frame. The cap of a chunk is rebuilt when the cut moves or the chunk is
## edited (its entry in cap_levels goes); chunks out of range lose theirs.
func update_caps() -> void:
	if not game.ready_to_play:
		return
	var home := _player_chunk()
	if home != cap_home:
		cap_home = home
		cap_order.clear()
		for cz in range(home.y - CAP_RANGE, home.y + CAP_RANGE + 1):
			for cx in range(home.x - CAP_RANGE, home.x + CAP_RANGE + 1):
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
			node.material_override = game.world_mat
			game.world_root.add_child(node)
			cap_nodes[key] = node
		cap_nodes[key].mesh = ChunkMesher.build_cap(world, want, key.x * CHUNK, key.y * CHUNK, CHUNK)
		_fit_box(cap_nodes[key])
		cap_levels[key] = want
		if Time.get_ticks_usec() - t0 > CAP_BUDGET_US:
			break
	budget_us += Time.get_ticks_usec() - t0
