extends RefCounted
## The first part of the chunk streamer (chunk_streamer.gd is the last; callers load that one):
## the order the chunks are built in. Which chunks are wanted around the player (reach, the
## pending list), which come first (on the screen, along the player's way, see _build_score),
## and whether the player has outrun the building (_check_lag). Holds the streamer's
## constants and the state the later parts share.

const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const TreeSprites := preload("res://src/client/world/tree_sprites.gd")
const Growth := preload("res://src/shared/world/growth.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const SolidMap := preload("res://src/client/world/solid_map.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Session := preload("res://src/shared/game/session.gd")
const EdgeHaze := preload("res://src/client/world/edge_haze.gd")
const ChunkJob := preload("res://src/client/world/chunk_job.gd")

## Chunk size in cells.
const CHUNK := WorldData.CHUNK
const CELL := WorldData.CELL
## Play starts when the chunks within NEAR_CHUNKS of the spawn are built.
const NEAR_CHUNKS := 3
## Chunks within this many chunks of the player are built at least: the session's zone,
## which it makes; a larger screen builds farther (reach, Session.reach_for). Beyond
## UNLOAD_EXTRA more their meshes are freed.
const LOAD_RANGE := Session.ZONE
const UNLOAD_EXTRA := 3
## While the game is paused (its menu open) the chunks are built this much farther, as
## the session makes them then, still within the unload range.
const PAUSE_EXTRA := Session.PAUSE_ZONE - Session.ZONE
const PAUSE_RANGE := LOAD_RANGE + PAUSE_EXTRA
## World units past the screen's edge the server counts as seen (Mirror.SEEN_MARGIN):
## the reach is worked out from the same screen the server is told.
const SEEN_MARGIN := 4.0
## What the order of building (see _build_score) adds to a chunk off the screen.
const OFF_SCREEN := 100000.0
## How many chunks the session is told to make first at most (see wanted).
const WANTED_MOST := 4
const COMPASS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

var game
var world: WorldData
var gen: WorldGen
var chunk_nodes := {}
## Chunks within reach still to build, and the chunk they were listed around
## (the player's, see focus).
var pending_chunks: Array[Vector2i] = []
var load_home := Vector2i(-1000000, 0)
## Pending chunks whose cells (or their neighbours') have not been made yet: next_chunk
## passes them over until the generator makes something (_on_generated). Over a socket
## the server sends only its zone, so a ring past it never comes: the best one
## on the screen, waited for, kept the near chunks at the sides from being built and the
## loading screen stood at half on a phone held upright (2026-11-10).
var waiting := {}
var unload_queue: Array[Vector2i] = []
## The game is paused: run_jobs builds within PAUSE_RANGE on the loading budget.
var paused := false
var load_reach := LOAD_RANGE
## While the character lies dead, the respawn point the death screen offers first
## (world units), else Vector3.INF: the chunks are built around it instead of around
## the body, so coming back there lands in a world already made, and none are freed
## meanwhile (the place of death stays behind the screen). See set_focus.
var focus := Vector3.INF
## The chunk being built a column at a time (see run_jobs), null for none.
var job: ChunkJob
## A chunk being streamed (or built to keep its jobs) set aside for an edit, to go on
## where it stopped once the edits are built; null for none. Before 2026-11-08 the edit
## waited for it: a far chunk at the stream budget kept a felled tree standing for seconds
## on a phone.
var stashed: ChunkJob
## The chunk being streamed: picked by next_chunk, built by `job` once the session has
## made it. An edit may drop its job, and it is started again. While a job is built,
## has_target is true exactly when the job is neither an edit nor built to keep, and
## `target` is then its key (tests/unit/chunk_job_test.gd checks this every step).
var has_target := false
var target := Vector2i.ZERO
## Chunks whose ground and water are shown and whose plants are still to be built
## (ChunkJob.ground).
var bare := {}
## Chunks of `bare` whose plants wait while the screen has a hole (see _finish_part):
## the job that built their meshes, kept for patching once the plants are built too.
var plants_wait := {}
## Where the player is going: world units (x, z) ahead of it, LOOK_AHEAD seconds of its
## way, smoothed (see _track_motion).
var lead := Vector2.ZERO
## The way the player went last (a unit vector on the ground, x z; zero before it has
## moved): the chunks along it come first, then those beside them (see _way_score).
var way := Vector2.ZERO
## A chunk on the screen has no ground yet (see _check_lag): building gets lag_budget().
var lagging := false
## True once every chunk within reach of the player is built.
var map_done := false
## The solid cells round the player, for the rock the view in layers fills in.
var solid := SolidMap.new()


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


## Lists the chunks within reach of the player (or the focus) that have no
## meshes yet, and queues the ones beyond the unload range (UNLOAD_EXTRA past reach) to lose theirs.
func _list_pending() -> void:
	var home := _load_chunk()
	var far := reach() + (PAUSE_EXTRA if paused else 0)
	if home == load_home and far == load_reach:
		return
	load_home = home
	load_reach = far
	pending_chunks.clear()
	waiting.clear()
	for cz in range(home.y - far, home.y + far + 1):
		for cx in range(home.x - far, home.x + far + 1):
			var key := Vector2i(cx, cz)
			if (not chunk_nodes.has(key) or bare.has(key)) and not (has_target and key == target):
				pending_chunks.append(key)
	unload_queue.clear()
	if focus.is_finite():
		if not pending_chunks.is_empty():
			map_done = false
		return
	for key: Vector2i in chunk_nodes:
		if maxi(absi(key.x - home.x), absi(key.y - home.y)) > reach() + UNLOAD_EXTRA:
			unload_queue.append(key)
	if not pending_chunks.is_empty():
		map_done = false


## The pending chunks the session has not made yet, in the order they are built (see
## _build_score), the one being built first, WANTED_MOST at most: the session makes them
## first (Session.wanted). Walking into new land a phone needs about a second of
## building a second for the whole zone round the player and has a third of it
## (2026-11-15): the screen comes first, the way ahead on it first, the rest of the zone
## when the player stops.
func wanted() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not game.ready_to_play or paused or focus.is_finite() or game.player == null:
		return out
	if has_target and not gen.needed(target).is_empty():
		out.append(target)
	var shaped := WorldGen.SHAPED
	var keys: Array[Vector2i] = []
	var scores := PackedFloat32Array()
	var ctx := _score_context()
	for k in pending_chunks:
		# A chunk made to the end needs nothing more (gen.needed looks at its neighbours).
		if gen.stages.get(k, 0) < shaped:
			keys.append(k)
			scores.append(_build_score(k, ctx))
	# The best few, a pass for each (a sort of all of them every frame costs more).
	var tries := 0
	while out.size() < WANTED_MOST and tries < WANTED_MOST * 3 and not keys.is_empty():
		tries += 1
		var best := 0
		for i in scores.size():
			if scores[i] < scores[best]:
				best = i
		var k := keys[best]
		keys.remove_at(best)
		scores.remove_at(best)
		if not gen.needed(k).is_empty():
			out.append(k)
	return out


## Whether chunk `k` is on the screen, seen from the player or from where it is going.
func _on_screen(k: Vector2i) -> bool:
	var half := _screen_half()
	var here := _at()
	return minf(_screen_score(k, here, half), _screen_score(k, here + lead, half)) <= 0.0


## Whether a pending chunk on the screen can be built now (the session has made it).
func _ready_on_screen() -> bool:
	for k in pending_chunks:
		if not waiting.has(k) and not plants_wait.has(k) and _on_screen(k):
			return true
	return false


## The pending chunk to build next: the one first in the order of building (see
## _build_score) the session has made, of all of them waited for (see waiting) the first;
## around the focus, the nearest. Behind the player's walk (lagging) the chunks whose
## ground is shown and whose plants wait (plants_wait) go last.
func next_chunk() -> Vector2i:
	var at := _load_chunk()
	var all_wait := true
	for k in pending_chunks:
		if not waiting.has(k):
			all_wait = false
			break
	var ctx := _score_context()
	var best := 0
	var best_d := INF
	for i in pending_chunks.size():
		var k := pending_chunks[i]
		if not all_wait and waiting.has(k):
			continue
		var d: float
		if focus.is_finite():
			d = maxi(absi(k.x - at.x), absi(k.y - at.y))
		else:
			d = _build_score(k, ctx)
			if lagging and plants_wait.has(k):
				# The holes on the screen first (see plants_wait).
				d += OFF_SCREEN * 10.0
		if d < best_d:
			best_d = d
			best = i
	return pending_chunks.pop_at(best)


## What _build_score looks from: the middle of the player's chunk, the player, where it is
## going, the screen's half and the way.
func _score_context() -> Array:
	if game.player == null:
		return []
	var size := CHUNK * CELL
	var c := _player_chunk()
	var mid := (Vector2(c) + Vector2(0.5, 0.5)) * size
	return [mid, _at(), _at() + lead, _screen_half(), way, game.view != null and game.ready_to_play]


## Where chunk `key` comes in the order of building (lower first), user 2026-11-15: what
## the screen shows (seen from the player or from where it is going) before the rest
## (OFF_SCREEN), each in the order of the way (see _way_score) from the player's chunk.
static func _build_score(key: Vector2i, ctx: Array) -> float:
	if ctx.is_empty():
		return 0.0
	var score := _way_score(key, ctx[0], ctx[4])
	if ctx[5]:
		var half: Vector2 = ctx[3]
		if minf(_screen_score(key, ctx[1], half), _screen_score(key, ctx[2], half)) > 0.0:
			score += OFF_SCREEN
	return score


## Where chunk `key` comes along the way, seen from `from` (world units x, z: the middle
## of the player's chunk, so its row is the way's) going `dir`: the chunks along the way first, from the player's onwards, those ahead
## before those behind as far, then the row beside them on either side, and so on out
## (1000 a row); before the player has moved, ring by ring round it, nearest first.
static func _way_score(key: Vector2i, from: Vector2, dir: Vector2) -> float:
	var size := CHUNK * CELL
	var d := (Vector2(key) + Vector2(0.5, 0.5)) * size - from
	if dir == Vector2.ZERO:
		return floorf(maxf(absf(d.x), absf(d.y)) / size + 0.5) * 1000.0 + d.length() / size
	var across := floorf(absf(d.cross(dir)) / size + 0.5)
	var along := d.dot(dir) / size
	return across * 1000.0 + (along if along >= 0.0 else 0.5 - along)


## The player's place on the ground plane (world units x, z).
func _at() -> Vector2:
	return Vector2(game.player.position.x, game.player.position.z)


## Half the width and the height of the world the camera shows, in world units (along
## PixelView.right and up).
func _screen_half() -> Vector2:
	var view = game.view
	if view == null or view.camera == null:
		return Vector2(32.0, 18.0)
	var size: float = view.camera.size
	return Vector2(size * view.image_size.x / maxf(1.0, view.image_size.y), size) * 0.5


## How many chunks around the player's are built for the screen as it is now: the
## session's zone for a phone's, farther for a larger window (Session.reach_for); the
## caps over the cut reach as far.
func reach() -> int:
	var view = game.view
	if view == null or view.viewport == null:
		return LOAD_RANGE
	return Session.reach_for(Vector2(view.viewport.size) / PixelView.PIXELS_PER_UNIT * 0.5 + Vector2.ONE * SEEN_MARGIN)


## How far chunk `key` lies outside the screen seen from `from` (world units x, z), in
## screens: 0 or less where some of it is on the screen. The ground is taken as level
## with the player's (the shear of heights moves it a little up the image).
static func _screen_score(key: Vector2i, from: Vector2, half: Vector2) -> float:
	var d := (Vector2(key) + Vector2(0.5, 0.5)) * (CHUNK * CELL) - from
	# Half a chunk's diagonal: a chunk partly on the screen counts.
	var r := CHUNK * CELL * 0.71
	return maxf((absf(d.dot(PixelView.right)) - r) / half.x, (absf(d.dot(PixelView.up)) - r) / half.y)


## Whether a chunk is being streamed or built to keep its jobs (a job that is not an
## edit), or picked to be streamed and waiting for its job: _streamed() is its key.
func _streams() -> bool:
	return has_target or (job != null and not job.edit)


func _streamed() -> Vector2i:
	return job.key if job != null and not job.edit else target


## Whether a chunk on the screen has no ground yet (pending, or being built new).
func _check_lag() -> void:
	lagging = false
	if not game.ready_to_play or paused or focus.is_finite() or game.player == null:
		return
	var half := _screen_half()
	var here := _at()
	if _streams() and not chunk_nodes.has(_streamed()) and _screen_score(_streamed(), here, half) <= 0.0:
		lagging = true
		return
	if stashed != null and not chunk_nodes.has(stashed.key) \
			and _screen_score(stashed.key, here, half) <= 0.0:
		lagging = true
		return
	for k in pending_chunks:
		if not chunk_nodes.has(k) and _screen_score(k, here, half) <= 0.0:
			lagging = true
			return
