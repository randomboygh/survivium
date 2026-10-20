extends RefCounted
## The chunks of the world on screen and the level cut. Builds the chunks around the
## spawn before play, streams the rest of the map a column of cells at a time within a
## frame budget, rebuilds edited chunks first, keeps a cap over the cut on the chunks
## around the player, and moves the cut itself: automatic under a roof or in a cave,
## manual with the level buttons. `game` is the Main node that owns the scene.

const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const Foliage := preload("res://src/client/foliage.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")

## Chunk size in cells.
const CHUNK := 16
const CELL := WorldData.CELL
## Meshes are drawn up to a level height north of where they are, so culling boxes
## get this much margin.
const CULL_MARGIN := 24.0
## Play starts when the chunks within NEAR_CHUNKS of the spawn are built; the rest of
## the map is built in the background, nearest to the player first.
const NEAR_CHUNKS := 3
## Chunks this close to the player (in chunks) are built with the edit budget, so the
## ground the player walks onto is there before the far chunks.
const URGENT_CHUNKS := NEAR_CHUNKS + 1
## Chunks this far (in chunks) from the player's get a cap over the level cut; farther
## ones are off the screen on any device and are built when they come near.
const CAP_RANGE := 6
## How much of a frame may go to building caps, to remeshing edited chunks and to
## building the far chunks of the map, in microseconds; a chunk is built a column of
## cells at a time (ChunkMesher.step, Foliage.step), so what does not fit waits for
## the next frame.
const CAP_BUDGET_US := 3000
const EDIT_BUDGET_US := 9000
const STREAM_BUDGET_US := 3000
## How long the automatic cut must agree before the view follows it, so stepping
## under the rim of a roof does not flip the view back and forth.
const CUT_DELAY := 0.2

var game
var world
var chunk_nodes := {}
var pending_chunks: Array[Vector2i] = []
var near_pending := 0
var near_total := 0
## One cap over the cut per chunk (see update_caps): nodes, the level each was built
## for, and the chunks within CAP_RANGE of the player, nearest first.
var cap_nodes := {}
var cap_levels := {}
var cap_order: Array[Vector2i] = []
var cap_home := Vector2i(-1000000, 0)
## Chunks that changed since they were last meshed, and the chunk being built now
## (see run_jobs): its key, its mesh and plant jobs, and whether it is an edit.
var dirty_chunks := {}
var job_key := Vector2i.ZERO
var job_mesh: ChunkMesher.Job
var job_plants: Foliage.Job
var job_edit := false
var job_budget := 0
var map_done := false
## Time spent in the budgeted loops (chunk steps, caps), for tests/frame_test.gd to
## tell it from what a frame does outside a budget.
var budget_us := 0
## Time spent building meshes, for the log.
var mesh_us := 0

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


## Queues every chunk of the map, nearest to the spawn first, and counts the near ones
## that must be built before play.
func prepare(w) -> void:
	world = w
	ground_level = game.player.level()
	var keys: Array[Vector2i] = []
	for cz in ceili(world.size_z / float(CHUNK)):
		for cx in ceili(world.size_x / float(CHUNK)):
			keys.append(Vector2i(cx, cz))
	var spawn := _player_chunk_pos()
	var nearer := func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(spawn) < Vector2(b).distance_to(spawn)
	keys.sort_custom(nearer)
	pending_chunks = keys
	var home := Vector2i(spawn.floor())
	for key in keys:
		if _is_near(key, home):
			near_total += 1
	near_pending = near_total


## Builds the near chunks for up to `ms` milliseconds (the loading screen); true once
## they are all built.
func build_near(ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	var home := _player_chunk()
	while near_pending > 0 and Time.get_ticks_msec() - t0 < ms:
		var key: Vector2i = pending_chunks.pop_front()
		if _is_near(key, home):
			near_pending -= 1
		build_chunk(key)
	return near_pending == 0


func _player_chunk_pos() -> Vector2:
	return Vector2(game.player.position.x, game.player.position.z) / (CHUNK * CELL)


func _player_chunk() -> Vector2i:
	return Vector2i(_player_chunk_pos().floor())


func _is_near(key: Vector2i, home: Vector2i) -> bool:
	return maxi(absi(key.x - home.x), absi(key.y - home.y)) <= NEAR_CHUNKS


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

## Builds the meshes and plants of a chunk at once (the loading screen and tools).
func build_chunk(key: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var meshes: Array = ChunkMesher.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	var plants: Dictionary = Foliage.build_chunk(world, key.x * CHUNK, key.y * CHUNK, CHUNK)
	mesh_us += Time.get_ticks_usec() - t0
	dirty_chunks.erase(key)
	_apply_chunk(key, meshes, plants)


## Builds chunks a column of cells at a time within the frame's budget: edited
## chunks first (the chunk of the edit before its neighbours), then the far chunks of
## the map nearest to the player. At least one column is built a frame, so a job
## always ends.
func run_jobs() -> void:
	var t0 := Time.get_ticks_usec()
	while true:
		var t1 := Time.get_ticks_usec()
		if job_mesh == null:
			if not dirty_chunks.is_empty():
				job_key = dirty_chunks.keys()[0]
				dirty_chunks.erase(job_key)
				job_edit = true
				job_budget = EDIT_BUDGET_US
			elif game.ready_to_play and not pending_chunks.is_empty():
				job_key = next_chunk()
				job_edit = false
				var at := _player_chunk()
				var near := maxi(absi(job_key.x - at.x), absi(job_key.y - at.y)) <= URGENT_CHUNKS
				job_budget = EDIT_BUDGET_US if near else STREAM_BUDGET_US
			else:
				break
			job_mesh = ChunkMesher.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
			job_plants = Foliage.start(world, job_key.x * CHUNK, job_key.y * CHUNK, CHUNK)
		var done := false
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
		if not job_edit:
			game.hud.perf.chunks = chunk_nodes.size()
		if not job_edit and pending_chunks.is_empty() and not map_done:
			map_done = true
			print("meshes built in %d ms" % (mesh_us / 1000))
			print("whole map ready in %d ms" % Time.get_ticks_msec())
	mesh_us += Time.get_ticks_usec() - t0


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
		var parts: Array = [solid, water, tufts, crowns, shade]
		for n in parts:
			n.extra_cull_margin = CULL_MARGIN
			game.world_root.add_child(n)
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


## Queues the chunks a changed cell touches for a rebuild, the chunk of the cell
## first, and tells the roof map and the props.
func on_cell_changed(cell: Vector3i) -> void:
	game.roof.touch(world, cell)
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
			pending_chunks.append(job_key)
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
