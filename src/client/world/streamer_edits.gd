extends "res://src/client/world/streamer_jobs.gd"
## The chunk streamer's edits (see chunk_streamer.gd): a changed cell, a blueprint's holes or
## a regrown cell mark the chunks around for rebuilding, the columns around the change only.

## Where the earth that hides the player was last worked out: Vector3i(x, level, z).
var hidden_at := Vector3i(0, -1000, 0)


## Queues the chunks a changed cell touches for a rebuild, the chunk of the cell
## first, and tells the roof map and the props.
func on_cell_changed(cell: Vector3i) -> void:
	game.roof.touch(world, cell)
	solid.touch(world, cell)
	# The ground around the player may have risen or gone: look again.
	hidden_at.y = -1000
	if game.hud != null and game.hud.minimap != null:
		game.hud.minimap.touch(world, cell)
	# Slopes and corners look at the neighbours, edges of a top at theirs, and the
	# surface of a slope at the slopes beside it (three columns in all). The chunk of
	# the cell goes first in the queue, then the chunks of the earlier changes not
	# rebuilt yet (the other columns of a felled tree), the neighbours after (see
	# run_jobs): a tree near a chunk's corner goes as soon as its own chunks are drawn,
	# not after the three around too.
	# A cell up in the air (a crown's) changes only the columns beside it, unless its
	# column lost its last leaf or got its first (ChunkMesher.reach).
	_remesh_around(cell)
	game.props.on_cell_changed(cell)


## Draws the cells of `cells` (cell -> true) as air in the build mode though they are
## solid (ChunkMesher.holes): the openings of the doors and windows to be cut into walls
## (PlanThings). The columns round the ones that changed are built again.
func set_holes(cells: Dictionary) -> void:
	if cells == ChunkMesher.holes:
		return
	var changed := {}
	for c: Vector3i in ChunkMesher.holes:
		if not cells.has(c):
			changed[c] = true
	for c: Vector3i in cells:
		if not ChunkMesher.holes.has(c):
			changed[c] = true
	ChunkMesher.holes = cells.duplicate()
	for c: Vector3i in changed:
		_remesh_around(c)


## Whether no cell is drawn cut (set_holes).
func holes_empty() -> bool:
	return ChunkMesher.holes.is_empty()


## Builds the columns round cell `cell` again, its chunk first (see on_cell_changed).
func _remesh_around(cell: Vector3i) -> void:
	var home := WorldData.chunk_key(cell.x, cell.z)
	var r := ChunkMesher.reach(world, cell)
	var keys := {}
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			keys[WorldData.chunk_key(cell.x + dx, cell.z + dz)] = true
	# Within each chunk only those columns are built again (see run_jobs), if it was kept.
	var around := Rect2i(cell.x - r, cell.z - r, 2 * r + 1, 2 * r + 1)
	for key: Vector2i in keys:
		if chunk_nodes.has(key):
			var part := around.intersection(Rect2i(key * CHUNK, Vector2i(CHUNK, CHUNK)))
			dirty_rects[key] = dirty_rects[key].merge(part) if dirty_rects.has(key) else part
	if job_mesh != null and keys.has(job_key):
		if job_edit:
			# The chunk being rebuilt for an edit changed again: the job goes on and
			# shows the earlier edit, and the chunk is rebuilt once more after it. Were
			# it started over, digging faster than a rebuild takes (a phone) would
			# never show the ground changing.
			keys[job_key] = true
		else:
			# A chunk being streamed: start it over as an edit (one built only to keep
			# its jobs is built whole for the edit).
			if not job_keep:
				has_target = true
			_drop_job()
	if not stashed.is_empty() and keys.has(stashed[0]):
		_unstash(stashed[0])
	var queue := {}
	if chunk_nodes.has(home):
		queue[home] = true
		edited[home] = true
	for key in dirty_chunks:
		if edited.has(key):
			queue[key] = true
	for key in keys:
		if chunk_nodes.has(key):
			queue[key] = true
	for key in dirty_chunks:
		queue[key] = true
	dirty_chunks = queue


## Draws the grass of cell `cell` again (cut short, a plant picked or crushed): only the
## column of the cell, its chunk first in the queue as an edit (see on_cell_changed), so
## the plant is gone within a frame or two, not after the chunk is rebuilt whole.
## A stone top whose moss was picked also redraws the four tops beside it, which may be
## in the chunks beside: their ragged edge of moss towards it goes (ChunkMesher
## _picked_around). Kept, it drew a grid of moss lines between the tops picked one by one.
func regrow_cell(cell: Vector3i) -> void:
	var key := WorldData.chunk_key(cell.x, cell.z)
	if not chunk_nodes.has(key):
		return
	var parts := {key: Rect2i(cell.x, cell.z, 1, 1)}
	if world.get_cell(cell.x, cell.y, cell.z) == Mat.STONE:
		for o: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var k := WorldData.chunk_key(cell.x + o.x, cell.z + o.y)
			if chunk_nodes.has(k):
				var one := Rect2i(cell.x + o.x, cell.z + o.y, 1, 1)
				parts[k] = parts[k].merge(one) if parts.has(k) else one
	var queue := {}
	for k: Vector2i in parts:
		if job_mesh != null and job_key == k and not job_edit:
			if not job_keep:
				has_target = true
			_drop_job()
		_unstash(k)
		var part: Rect2i = parts[k]
		dirty_rects[k] = dirty_rects[k].merge(part) if dirty_rects.has(k) else part
		edited[k] = true
		queue[k] = true
	for k in dirty_chunks:
		queue[k] = true
	dirty_chunks = queue


## Builds the mesh of chunk `key` again, by itself: what is drawn on it changed (the
## berries of a bush) but no cell did.
func remesh_chunk(key: Vector2i) -> void:
	if not chunk_nodes.has(key):
		return
	if job_mesh != null and job_key == key and not job_edit:
		if not job_keep:
			has_target = true
		_drop_job()
	_unstash(key)
	dirty_chunks[key] = true
	dirty_rects[key] = Rect2i(key * CHUNK, Vector2i(CHUNK, CHUNK))
