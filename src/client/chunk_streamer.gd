extends RefCounted
## The chunks of the world on screen and the level cut. The world is generated and
## meshed a chunk at a time around the player (see WorldGen for the stages): the
## chunks near the spawn before play, then the chunks within LOAD_RANGE of the
## player, nearest first, a column of cells (or a row of the generator) at a time
## within a frame budget. Edited chunks are rebuilt first; chunks that fall beyond
## UNLOAD_RANGE lose their meshes (their cells stay). The caps over the cut are kept
## on the chunks around the player, and the cut itself moves: automatic under a roof
## or in a cave, manual with the level buttons. `game` is the Main node that owns the
## scene.

const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const Foliage := preload("res://src/client/foliage.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")

## Chunk size in cells.
const CHUNK := WorldData.CHUNK
const CELL := WorldData.CELL
## Meshes are drawn up to a level height north of where they are, so culling boxes
## get this much margin.
const CULL_MARGIN := 24.0
## Play starts when the chunks within NEAR_CHUNKS of the spawn are built.
const NEAR_CHUNKS := 3
## Chunks this close to the player (in chunks) are built with the edit budget, so the
## ground the player walks onto is there before the far chunks.
const URGENT_CHUNKS := NEAR_CHUNKS + 1
## Chunks within this many chunks of the player are built, farther than any screen
## shows; beyond UNLOAD_RANGE their meshes are freed.
const LOAD_RANGE := 6
const UNLOAD_RANGE := 9
## Chunks this far (in chunks) from the player's get a cap over the level cut; farther
## ones are off the screen on any device and are built when they come near.
const CAP_RANGE := 6
## How much of a frame may go to building caps, to remeshing edited chunks and to
## generating and building the far chunks of the map, in microseconds; a chunk is
## built a column of cells at a time (ChunkMesher.step, Foliage.step, WorldGen.step),
## so what does not fit waits for the next frame.
const CAP_BUDGET_US := 3000
const EDIT_BUDGET_US := 9000
const STREAM_BUDGET_US := 3000
## Chunks whose meshes are freed in one frame at most.
const UNLOADS_PER_FRAME := 2
## How long the automatic cut must agree before the view follows it, so stepping
## under the rim of a roof does not flip the view back and forth.
const CUT_DELAY := 0.2
## The parts of a chunk's meshes, in the order of chunk_nodes' arrays.
const PARTS := ["solid", "water", "grass", "clumps", "shadows", "bushes", "drifts"]

var game
var world: WorldData
var gen: WorldGen
var chunk_nodes := {}
## Chunks within LOAD_RANGE still to build, and the chunk the player was in when
## they were listed.
var pending_chunks: Array[Vector2i] = []
var load_home := Vector2i(-1000000, 0)
var unload_queue: Array[Vector2i] = []
var near_pending := 0
var near_total := 0
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
## The cut the player's position asks for, and how long it has asked for it.
var cut_target := -1
var cut_clock := 0.0
## The level the player last stood on: a jump does not move the cut.
var ground_level := 0
var indoor := false


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


func _is_near(key: Vector2i, home: Vector2i) -> bool:
	return maxi(absi(key.x - home.x), absi(key.y - home.y)) <= NEAR_CHUNKS


## Lists the chunks within LOAD_RANGE of the player that have no meshes yet, and
## queues the ones beyond UNLOAD_RANGE to lose theirs.
func _list_pending() -> void:
	var home := _player_chunk()
	if home == load_home:
		return
	load_home = home
	pending_chunks.clear()
	for cz in range(maxi(0, home.y - LOAD_RANGE), mini(gen.chunks_z(), home.y + LOAD_RANGE + 1)):
		for cx in range(maxi(0, home.x - LOAD_RANGE), mini(gen.chunks_x(), home.x + LOAD_RANGE + 1)):
			var key := Vector2i(cx, cz)
			if not chunk_nodes.has(key) and not (has_target and key == job_key):
				pending_chunks.append(key)
	for key: Vector2i in chunk_nodes:
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > UNLOAD_RANGE and not unload_queue.has(key):
			unload_queue.append(key)
	if not pending_chunks.is_empty():
		map_done = false


## The pending chunk nearest to the player.
func next_chunk() -> Vector2i:
	var at := _player_chunk()
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
		_on_generated(need[0], need[1])
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
	job_mesh = null
	job_plants = null
	job_gen = null
	_list_pending()
	while not pending_chunks.is_empty():
		build_chunk(next_chunk())
	map_done = true
	while not unload_queue.is_empty():
		_unload_some()
	game.roof.flush()


## The next generator stage some chunk needs before `key` can be meshed: [chunk,
## stage], or empty when it can be. A chunk is meshed once it is SHAPED, which takes
## the chunks around it PLANTED, which takes the chunks around those with terrain.
func _prerequisite(key: Vector2i) -> Array:
	var m := gen.missing(key, 2, WorldGen.TERRAIN)
	if m.x >= 0:
		return [m, WorldGen.TERRAIN]
	m = gen.missing(key, 1, WorldGen.PLANTED)
	if m.x >= 0:
		return [m, WorldGen.PLANTED]
	if gen.stage_of(key) < WorldGen.SHAPED:
		return [key, WorldGen.SHAPED]
	return []


## A chunk reached a stage: once it is SHAPED its columns are final, so the roof
## map and the minimap take them.
func _on_generated(key: Vector2i, stage: int) -> void:
	if stage == WorldGen.SHAPED:
		game.roof.fill_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
		if game.hud != null and game.hud.minimap != null:
			game.hud.minimap.paint_chunk(world, key)


## Generates and builds chunks a step at a time within the frame's budget: edited
## chunks first (the chunk of the edit before its neighbours), then the chunks
## nearest to the player, generating what each needs before its meshes. At least one
## step is taken a frame, so a job always ends.
func run_jobs() -> void:
	var t0 := Time.get_ticks_usec()
	_list_pending()
	while true:
		var t1 := Time.get_ticks_usec()
		if job_mesh == null and job_gen == null:
			if not dirty_chunks.is_empty():
				job_key = dirty_chunks.keys()[0]
				dirty_chunks.erase(job_key)
				job_edit = true
				job_budget = EDIT_BUDGET_US
				has_target = false
			elif game.ready_to_play and (has_target or not pending_chunks.is_empty()):
				if not has_target:
					job_key = next_chunk()
					has_target = true
				job_edit = false
				var at := _player_chunk()
				var near := maxi(absi(job_key.x - at.x), absi(job_key.y - at.y)) <= URGENT_CHUNKS
				job_budget = EDIT_BUDGET_US if near else STREAM_BUDGET_US
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
			while not done and Time.get_ticks_usec() - t0 < job_budget:
				done = gen.step(job_gen, 1)
			gen_us += Time.get_ticks_usec() - tg
			budget_us += Time.get_ticks_usec() - t1
			if done:
				_on_generated(job_gen.key, job_gen.stage)
				job_gen = null
			if not done or Time.get_ticks_usec() - t0 >= job_budget:
				break
			continue
		while not done and Time.get_ticks_usec() - t0 < job_budget:
			done = ChunkMesher.step(job_mesh, 1) and Foliage.step(job_plants, 1)
		budget_us += Time.get_ticks_usec() - t1
		# Making the meshes and handing them to the renderer costs a few milliseconds
		# more: with the budget spent, that waits for the next frame.
		if not done or Time.get_ticks_usec() - t0 >= job_budget:
			break
		_apply_chunk(job_key, ChunkMesher.finish(job_mesh), Foliage.finish(job_plants))
		job_mesh = null
		job_plants = null
		has_target = false
		if not job_edit:
			game.hud.perf.chunks = chunk_nodes.size()
		if not job_edit and pending_chunks.is_empty() and not map_done:
			map_done = true
			print("chunks around built in %d ms (generation %d ms, meshes %d ms)" % [Time.get_ticks_msec(), gen_us / 1000, mesh_us / 1000])
	mesh_us += Time.get_ticks_usec() - t0
	_unload_some()


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
		var bushes := Foliage.multimesh(game.bush_mesh, game.bush_mat, true, true)
		bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var drifts := Foliage.multimesh(game.drift_mesh, game.world_mat, false, false)
		var parts: Array = [solid, water, tufts, crowns, shade, bushes, drifts]
		for n in parts:
			n.extra_cull_margin = CULL_MARGIN
			if n == drifts:
				game.drifts_root.add_child(n)
			else:
				game.world_root.add_child(n)
		chunk_nodes[key] = parts
	var nodes: Array = chunk_nodes[key]
	nodes[0].mesh = meshes[0]
	nodes[1].mesh = meshes[1]
	for i in range(2, PARTS.size()):
		var part: Array = plants[PARTS[i]]
		var mm: MultiMesh = nodes[i].multimesh
		mm.instance_count = part[0]
		if part[0] > 0:
			mm.buffer = part[1]


## Queues the chunks a changed cell touches for a rebuild, the chunk of the cell
## first, and tells the roof map and the props.
func on_cell_changed(cell: Vector3i) -> void:
	game.roof.touch(world, cell)
	if game.hud != null and game.hud.minimap != null:
		game.hud.minimap.touch(world, cell)
	# Slopes and corners look at the neighbours, and edges of a top at theirs. The
	# chunk of the cell goes first in the queue, its neighbours after (see run_jobs).
	var home := Vector2i(floori(cell.x / float(CHUNK)), floori(cell.z / float(CHUNK)))
	var keys := {}
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			keys[Vector2i(floori((cell.x + dx) / float(CHUNK)), floori((cell.z + dz) / float(CHUNK)))] = true
	if job_mesh != null and keys.has(job_key):
		# The chunk being built changed under the job: start it over.
		job_mesh = null
		job_plants = null
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


# --- Level cutaway -----------------------------------------------------------

func update_cut(delta: float) -> void:
	var player = game.player
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
	var base: int = cut_level if cut_level < world.size_y else game.player.level() + 1
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
			node.material_override = game.world_mat
			node.extra_cull_margin = CULL_MARGIN
			game.world_root.add_child(node)
			cap_nodes[key] = node
		cap_nodes[key].mesh = ChunkMesher.build_cap(world, want, key.x * CHUNK, key.y * CHUNK, CHUNK)
		cap_levels[key] = want
		if Time.get_ticks_usec() - t0 > CAP_BUDGET_US:
			break
	budget_us += Time.get_ticks_usec() - t0
