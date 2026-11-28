extends "res://src/client/world/streamer_order.gd"
## The chunk streamer's nodes (see chunk_streamer.gd): the nodes a chunk is drawn with,
## their meshes, plants and lights applied, their culling boxes fitted to the view, the
## edge haze, and the queue that paints chunks into the roof map and the minimap.

## World units the shaders may move what a chunk draws past its mesh (leaves and grass
## swaying, ice raised): the margin of its culling box (see PixelView.sheared_box).
const SWAY := 1.0
## The parts of a chunk's meshes, in the order of chunk_nodes' arrays.
const PARTS := ["solid", "water", "grass", "clumps", "shadows", "bushes", "drifts"]

## Counts the changes of chunk_nodes (a chunk built or let go), so the haze knows when the
## set is the same (EdgeHaze.update).
var nodes_changes := 0
## One cap over the cut per chunk (see update_caps): nodes, the level each was built
## for, and the chunks within reach of the player, nearest first.
var cap_nodes := {}
var cap_levels := {}
## The caps built lately, by chunk and then by level (at most CAP_KEPT levels a chunk):
## a cut that comes back to a level (the player stepping in and out behind a big
## object) shows its caps at once instead of building them again chunk by chunk, which
## left holes flickering over the cut. A chunk's go when it is meshed again or freed.
var cap_cache := {}
## The level every chunk in range has its cap built for, -1 while some are still to
## build: update_caps does nothing more until a chunk or the cut changes.
var _caps_ready := -1
## The haze over the edge of what is built (the «Туман на краю» setting), null when off.
var haze: EdgeHaze
var haze_on := false
## Chunks just made whose columns the roof map (part 0) and the minimap (part 1, its new
## crowns only: 2) still have to take, one a frame, nearest to the player first (see
## _next_paint): Vector3i(key.x, key.y, part).
var paint_queue: Array[Vector3i] = []
## Time spent in the budgeted loops (chunk steps, caps, and the session's generation
## given to run_jobs), for tests/frame_test.gd to tell it from what a frame does
## outside a budget.
var budget_us := 0
## Painting into the roof map and the minimap goes at once while a chunk is built whole
## (see build_chunk), else one a frame (see paint_queue).
var _whole := false


## A chunk reached a stage (WorldGen.made): once it is SHAPED its columns are final,
## so the roof map and the minimap take them, at once while a chunk is built whole
## (the loading screen and tools, see build_chunk), else one a frame (see run_jobs).
## The minimap paints a chunk already at PLANTED, a chunk ahead of the meshes, so the
## world is not seen being made at its edge, with its trees (user 2026-11-21: painted
## bare at TERRAIN, two rings at the map's edge had no trees until they were SHAPED);
## the crowns a chunk planted later grows into a painted neighbour are added to it
## (part 2, Minimap.paint_chunk `leaves_only`). A chunk the map already shows (from the
## save, or made again after it was forgotten) is not painted at PLANTED: the crowns of
## its neighbours not planted again would go from the map until it is SHAPED.
func _on_generated(key: Vector2i, stage: int) -> void:
	waiting.clear()
	var parts: Array
	if stage == WorldGen.SHAPED:
		parts = [0, 1]
	elif stage == WorldGen.PLANTED and game.hud != null and game.hud.minimap != null:
		var mm = game.hud.minimap
		if not mm.has_chunk(key):
			parts = [1]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := key + Vector2i(dx, dz)
				if (dx != 0 or dz != 0) and mm.has_chunk(n) and gen.stage_of(n) < WorldGen.SHAPED:
					_queue_paint(Vector3i(n.x, n.y, 2))
	for part: int in parts:
		_queue_paint(Vector3i(key.x, key.y, part))


## Paints `item` at once while a chunk is built whole, else queues it (once).
func _queue_paint(item: Vector3i) -> void:
	if _whole:
		_paint(item)
	elif not item in paint_queue:
		paint_queue.append(item)


## The queued paint nearest to the player first, so the map fills from the player
## outwards (user 2026-11-21).
func _next_paint() -> Vector3i:
	var home := _player_chunk()
	var best := 0
	var best_d := 1 << 30
	for i in paint_queue.size():
		var it := paint_queue[i]
		var d := maxi(absi(it.x - home.x), absi(it.y - home.y))
		if d < best_d:
			best_d = d
			best = i
	var item := paint_queue[best]
	paint_queue.remove_at(best)
	return item


## Paints chunk (item.x, item.y) into the roof map (item.z 0) or the minimap (1), or
## adds to the minimap the crowns grown into it since it was painted (2).
func _paint(item: Vector3i) -> void:
	var key := Vector2i(item.x, item.y)
	if not world.has_chunk(key):
		return
	if item.z == 0:
		game.roof.fill_chunk(world, key)
	elif game.hud != null and game.hud.minimap != null:
		game.hud.minimap.paint_chunk(world, key, item.z == 2)


## Turns the haze over the edge of what is built on or off («Туман на краю»); it is
## made with the first frame of play.
func set_haze(on: bool) -> void:
	haze_on = on
	if not on and haze != null:
		haze.free_node()
		haze = null


## The fog's material (made with the fog when it is on), null when off: its shader is
## built ahead (ShaderWarmup).
func haze_material() -> ShaderMaterial:
	if not haze_on or game.world_root == null:
		return null
	if haze == null:
		haze = EdgeHaze.new(game)
	return haze.material


## Lays the haze over the chunks on the screen with no ground yet.
func _update_haze() -> void:
	if not haze_on or game.player == null or not game.ready_to_play:
		return
	if haze == null:
		haze = EdgeHaze.new(game)
	var tp := Time.get_ticks_usec()
	haze.update(chunk_nodes, _at(), _screen_half(), game.player.position.y, nodes_changes)
	budget_us += Time.get_ticks_usec() - tp


func _apply_chunk(key: Vector2i, meshes: Array, plants: Dictionary) -> void:
	_chunk_nodes(key)
	_apply_ground(key, meshes)
	_apply_plants(key, plants)


## Makes the nodes of chunk `key` if it has none yet.
func _chunk_nodes(key: Vector2i) -> void:
	if not chunk_nodes.has(key):
		var solid := MeshInstance3D.new()
		solid.material_override = game.world_mat
		# A fire's real shadow falls on the ground and the walls alone (PixelView.LAYER_GROUND).
		solid.layers = PixelView.LAYER_GROUND
		var water := MeshInstance3D.new()
		water.material_override = game.water_mat
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var tufts := Foliage.multimesh(game.grass_mesh, game.grass_mat, false, true)
		tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The player's shadow from a fire lies over the grass too.
		tufts.layers = PixelView.LAYER_GROUND
		var crowns := Foliage.multimesh(game.clump_mesh, game.leaves_mat, true, true)
		crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shade := Foliage.multimesh(game.disc_mesh, game.leaf_shadow_mat, false, true)
		shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shade.layers = PixelView.LAYER_SUN_CASTER
		var bushes := Foliage.multimesh(game.bush_mesh, game.bush_mat, true, true)
		bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var drifts := Foliage.multimesh(game.drift_mesh, game.low_mat, false, false)
		# The trees drawn as pictures (TreeSprites), after the parts of PARTS.
		var trees := Foliage.multimesh(game.tree_mesh, game.tree_mat, true, true)
		trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Their shadows: the same instances drawn by tree_shadow.gdshader into the sun's
		# and the moon's shadow map only (as the crown discs, `shade`).
		var tree_shade := MultiMeshInstance3D.new()
		tree_shade.multimesh = trees.multimesh
		tree_shade.material_override = game.tree_shadow_mat
		tree_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		tree_shade.layers = PixelView.LAYER_SUN_CASTER
		var parts: Array = [solid, water, tufts, crowns, shade, bushes, drifts, trees, tree_shade]
		for n in parts:
			if n == drifts:
				game.drifts_root.add_child(n)
			else:
				game.world_root.add_child(n)
		chunk_nodes[key] = parts
		nodes_changes += 1
		# What lies on the ground of a chunk from the save (a beast's body lay there before).
		if world.drops.has(key) and not game.props.drop_nodes.has(key):
			game.props.show_drops(key, false, true)


## Shows the ground and the water of chunk `key`.
func _apply_ground(key: Vector2i, meshes: Array) -> void:
	cap_levels.erase(key)
	cap_cache.erase(key)
	_caps_ready = -1
	var nodes: Array = chunk_nodes[key]
	game.hud.perf.mark("mesh")
	nodes[0].mesh = meshes[0]
	nodes[1].mesh = meshes[1]
	_fit_box(nodes[0])
	_fit_box(nodes[1])


## Shows the plants of chunk `key` (grass, crowns, their shadows, bushes, drifts).
func _apply_plants(key: Vector2i, plants: Dictionary) -> void:
	var nodes: Array = chunk_nodes[key]
	for i in range(2, PARTS.size()):
		var part: Array = plants[PARTS[i]]
		var mm: MultiMesh = nodes[i].multimesh
		mm.instance_count = part[0]
		if part[0] > 0:
			mm.buffer = part[1]
	var pics := TreeSprites.build(world, key.x * CHUNK, key.y * CHUNK)
	# A standing tree gone to a stump was felled: it falls (TreeHits.fall).
	var was: Dictionary = _standing.get(key, {})
	if fx_trees() != null:
		for col: Vector2i in was:
			if not pics[2].has(col) and Growth.stump_look(world, col) >= 0:
				fx_trees().fall(col, was[col])
	_standing[key] = pics[2]
	var tm: MultiMesh = nodes[PARTS.size()].multimesh
	tm.instance_count = pics[0]
	if pics[0] > 0:
		tm.buffer = pics[1]
	for i in range(2, nodes.size()):
		_fit_box(nodes[i])
	var fx = game.get("effects")
	if fx != null and fx.glows != null:
		fx.glows.sea_top = (world.sea_level + 1) * CELL
		fx.glows.set_spots(key, plants.get("glows", PackedVector3Array()))


## The standing pictured trees of each chunk shown, as TreeSprites.build gives them.
var _standing := {}


## Effects' trees (TreeHits), null without effects.
func fx_trees():
	var fx = game.get("effects")
	return fx.trees if fx != null and fx.get("trees") != null else null


## Hands the cells of chunk `key` that cast light (lava, crystals), as mesh job `jm`
## found them, to their lights (Effects.lit).
func _apply_lit(key: Vector2i, jm: ChunkMesher.Job) -> void:
	var fx = game.get("effects")
	if fx != null and fx.lit != null:
		fx.lit.set_spots(key, jm.glows, jm.glow_mats)


## Fits the culling boxes of every chunk shown to the views the camera may show next
## (PixelView.box_views), when it turns or tilts.
func refit_boxes() -> void:
	for parts: Array in chunk_nodes.values():
		for n: GeometryInstance3D in parts:
			_fit_box(n)
	for n: GeometryInstance3D in cap_nodes.values():
		_fit_box(n)
	game.props.refit_boxes()
	if game.plan_view != null:
		game.plan_view.things.refit_boxes()


## Culls a part of a chunk by what it draws, moved north as the shaders draw it, instead
## of a margin of a level's height all round, which kept nearly every chunk loaded drawn
## (636 draw calls against 301 at the spawn by day, 2026-10-21).
static func _fit_box(n: GeometryInstance3D) -> void:
	# The mesh's or the multimesh's own box (VisualInstance3D.get_aabb, which leaves
	# custom_aabb out); none when it has nothing to draw.
	var box := n.get_aabb()
	if box.size == Vector3.ZERO:
		return
	if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh.mesh == TreeSprites.quad:
		box = TreeSprites.stand_box(box)
	n.custom_aabb = PixelView.sheared_box(box, SWAY)
