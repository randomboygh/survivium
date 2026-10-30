extends RefCounted
## What stands and lies on the ground besides the cells, drawn: the things placed on two
## by two cells (Placed, src/shared: chests, workbenches, kilns, campfires), their
## models and fires and the warmth of the fires, and the items lying on the ground
## (WorldData.drops: what a felled tree leaves, a death sack) and those flying to the
## player when taken. Bushes and snowdrifts are grown by the world generator and drawn
## with the chunk they stand in (see ChunkStreamer, Foliage.finish). `game` is the Main
## node that owns the scene.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const RoofMap := preload("res://src/client/world/roof_map.gd")
const Items := preload("res://src/shared/content/items.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const Placed := preload("res://src/shared/game/placed.gd")
const WorldActions := preload("res://src/shared/game/world_actions.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")

const CELL := WorldData.CELL
## World units the bounding box of a thing flying to the player grows by, so the shear
## of the 3/4 view (which draws a thing `y` units north of its place) does not cull it.
## The models are scaled down to 1/16 and the margin grows the box before that, so they
## get it 16 times over. What stays put is culled by its sheared box (fit) instead.
const CULL_MARGIN := 24.0
## World units round a sheared box, for the half pixel snap of the shaders.
const FIT_MARGIN := 0.25
## Things lower than this (world units; the player is 1 tall) are low: the player's
## silhouette does not show behind them (see sprite_xray.gdshader).
const LOW_HEIGHT := 0.75
## Seconds a thing taken from the ground takes to fly to the player.
const FLY_TIME := 0.2

var game
## Meshes of the things on the ground by model, their vertices one triangle after
## another ([verts, normals, uvs, uv2s, colours]) by model, and the nodes of the chunks
## shown (their things in one mesh, and a death sack's glow) by chunk.
var drop_meshes := {}
var _drop_arrays := {}
var drop_nodes := {}
## The models of the placed things by prop kind, their nodes and the campfires' records
## in Effects (see Effects.add_campfire) by the thing's cell (see Placed.things).
var _models := {}
var _nodes := {}
var _fires := {}
var _heat_queued := false


func _init(g) -> void:
	game = g


## Draws the things of `placed` (Placed) as they come and go; their solid parts are
## the shapes of these models.
func watch(placed) -> void:
	for id in Items.IDS:
		var kind: String = Items.get_item(id).get("prop", "none")
		if kind != "none" and not Items.get_item(id).fire:
			placed.footprints[kind] = VoxelProps.footprint(_model(kind))
	placed.added.connect(_on_added)
	placed.removed.connect(_on_removed)
	placed.lit_changed.connect(_on_lit_changed)


## Puts the placed things into the world as the save had them, or the camp of the start
## next to the player in a new world (Placed.start_camp; and the test world's camp); the
## near chunks are built by then, so the ground under them is known.
func place() -> void:
	var meta: Dictionary = game.save.meta
	if meta.get("placed") is Array:
		game.placed.from_list(meta.placed)
	elif meta.get("props") is Dictionary:
		# A save from before things could be placed: the chest and the campfire by name.
		for name in ["chest", "campfire"]:
			var c: Variant = game.save.prop_cell(name)
			if c != null:
				game.placed.put(Items.with_prop("chest") if name == "chest" else Placed.CAMPFIRE, c,
					meta.get("chest") if name == "chest" else null)
	else:
		game.placed.start_camp(game.player.position)
		# The camp of the test world (TestGround.plan_things), for FPS and freezes.
		if game.gen.has_method("plan_things"):
			for t: Array in game.gen.plan_things():
				game.placed.put(t[0], t[1])
	_heat_later()


## The player places item `id` from the bag (see Placed.put_from_bag) below the level
## cut; true if it was placed.
func put_from_bag(id: String, slot := -1) -> bool:
	return game.placed.put_from_bag(game.character, id, slot, game.chunks.cut_level)


func _model(kind: String):
	if not _models.has(kind):
		_models[kind] = VoxelProps.prop(kind)
	return _models[kind]


func _on_added(e: Dictionary) -> void:
	if Placed.is_fire(e):
		_fires[e.cell] = game.effects.add_campfire(Vector3(e.cell) * CELL, game.low_mat)
		if not e.lit:
			game.effects.put_out(_fires[e.cell])
		_heat_later()
		return
	var node := MeshInstance3D.new()
	node.mesh = _model(Items.get_item(e.item).prop).build_mesh()
	node.material_override = game.low_mat if node.mesh.get_aabb().end.y / 16.0 < LOW_HEIGHT else game.world_mat
	node.scale = Vector3.ONE / 16.0
	node.position = Vector3(e.cell) * CELL
	_fit(node)
	game.world_root.add_child(node)
	_nodes[e.cell] = node


func _on_removed(e: Dictionary) -> void:
	if _nodes.has(e.cell):
		_nodes[e.cell].queue_free()
		_nodes.erase(e.cell)
	if _fires.has(e.cell):
		game.effects.remove_campfire(_fires[e.cell])
		_fires.erase(e.cell)
		_heat_later()


func _on_lit_changed(e: Dictionary) -> void:
	if e.lit:
		game.effects.remove_campfire(_fires[e.cell])
		_fires[e.cell] = game.effects.add_campfire(Vector3(e.cell) * CELL, game.low_mat)
	else:
		game.effects.put_out(_fires[e.cell])
	_heat_later()


## The fires' warmth on the ground is drawn again at the end of the frame, once for all
## the fires that came, went or changed in it.
func _heat_later() -> void:
	if _heat_queued:
		return
	_heat_queued = true
	_update_heat.call_deferred()


func _update_heat() -> void:
	_heat_queued = false
	RenderingServer.global_shader_parameter_set("heat_map", game.effects.heat_map(RoofMap.WRAP / 2))


## Shows what lies on the ground in chunk `key` (see WorldData.drops) afresh, all of
## it one mesh: a thing apiece cost a draw call in every light's pass and the sun's
## shadow, some 600 calls round a busy camp on the phone (2026-10-24). A death's sack
## glows (Effects.sack_glow).
func show_drops(key: Vector2i) -> void:
	hide_drops(key)
	if not game.chunks.chunk_nodes.has(key):
		return
	var nodes := []
	var parts := [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(),
		PackedVector2Array(), PackedColorArray()]
	for d: Array in game.world.drops.get(key, []):
		var arrays := _arrays_of(d[0])
		if arrays.is_empty():
			continue
		# Turned in steps of 45 degrees, which keep the pixels tidy.
		var turn := Basis(Vector3.UP, -snappedf(d[2], PI / 4.0))
		parts[0].append_array(Transform3D(turn.scaled(Vector3.ONE / 16.0), d[1]) * (arrays[0] as PackedVector3Array))
		parts[1].append_array(Transform3D(turn, Vector3.ZERO) * (arrays[1] as PackedVector3Array))
		for i in range(2, 5):
			parts[i].append_array(arrays[i])
		if d[0] == Items.SACK:
			nodes.append(game.effects.sack_glow(d[1]))
	if not parts[0].is_empty():
		var surface := []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = parts[0]
		surface[Mesh.ARRAY_NORMAL] = parts[1]
		surface[Mesh.ARRAY_TEX_UV] = parts[2]
		surface[Mesh.ARRAY_TEX_UV2] = parts[3]
		surface[Mesh.ARRAY_COLOR] = parts[4]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
		game.hud.perf.mark("вещи")
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = game.low_mat
		_fit(node)
		game.world_root.add_child(node)
		nodes.append(node)
	drop_nodes[key] = nodes


## Frees what was drawn lying in chunk `key`, as its chunk goes from the screen.
func hide_drops(key: Vector2i) -> void:
	for node: Node in drop_nodes.get(key, []):
		node.queue_free()
	drop_nodes.erase(key)


## The vertices of the model of a thing of `kind` on the ground, one triangle after
## another, or none for a thing with no model.
func _arrays_of(kind: String) -> Array:
	if _drop_arrays.has(kind):
		return _drop_arrays[kind]
	var arrays := []
	var mesh := _drop_mesh(kind)
	if mesh != null:
		var a := mesh.surface_get_arrays(0)
		var index: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
			var from = a[k]
			var to = from.duplicate()
			to.resize(index.size())
			for i in index.size():
				to[i] = from[index[i]]
			arrays.append(to)
	_drop_arrays[kind] = arrays
	return arrays


## Culls `node` (a model of the things placed or lying) by the box of what it draws in
## the views the camera shows or turns to (PixelView.sheared_box).
func _fit(node: MeshInstance3D) -> void:
	var to_world := node.transform
	var box := PixelView.sheared_box(to_world * node.mesh.get_aabb(), FIT_MARGIN)
	node.custom_aabb = to_world.affine_inverse() * box


## Fits the boxes of every model again for the views the camera shows now (see
## ChunkStreamer.refit_boxes).
func refit_boxes() -> void:
	for node: MeshInstance3D in _nodes.values():
		_fit(node)
	for nodes: Array in drop_nodes.values():
		for node: Node in nodes:
			if node is MeshInstance3D:
				_fit(node)


## The mesh of a thing of `kind` lying on the ground (see WorldData.drops): its item's
## model, a clod of the block's colour for a block, else a bundle.
func _drop_mesh(kind: String) -> Mesh:
	var item := Items.get_item(kind)
	var name: String = "sack" if kind == Items.SACK else item.get("model", "")
	var m := Mat.index(item.get("place", "")) if name == "" else -1
	if m >= 0:
		name = "block:%d" % m
	elif name == "":
		name = "bundle"
	elif kind != Items.SACK:
		name = VoxelProps.model_path(item, name)
	if not drop_meshes.has(name):
		var model = VoxelProps.block(_tile_colour(m)) if m >= 0 else (VoxelProps.sack() if name == "sack" else (VoxelProps.bundle() if name == "bundle" else VoxelProps.drop(item)))
		if model == null:
			model = VoxelProps.bundle()
		drop_meshes[name] = model.build_mesh()
	return drop_meshes[name]


## The average colour of material `m`'s tile in the terrain atlas.
func _tile_colour(m: int) -> Color:
	var atlas: Texture2D = game.atlas
	if atlas == null:
		return Color(0.5, 0.4, 0.3)
	# Read back from the texture only when the image is not kept (slow in the browser).
	var img: Image = PixelTextures.atlas_image if PixelTextures.atlas_image != null else atlas.get_image()
	var tile: int = PixelTextures.TILE
	var t := m * 3
	var x0: int = (t % PixelTextures.TILES) * tile
	var y0: int = floori(t / float(PixelTextures.TILES)) * tile
	var sum := Color(0, 0, 0, 0)
	for y in tile:
		for x in tile:
			sum += img.get_pixel(x0 + x, y0 + y)
	return sum / float(tile * tile)


## A thing taken from the ground at `from` flies to the player and is gone.
func fly(kind: String, from: Vector3) -> void:
	var mesh := _drop_mesh(kind)
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = game.low_mat
	node.scale = Vector3.ONE / 16.0
	node.position = from
	node.extra_cull_margin = CULL_MARGIN
	game.world_root.add_child(node)
	var tw := node.create_tween()
	tw.tween_property(node, "position", game.player.position + Vector3(0.0, 0.5, 0.0), FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)


## A bush disappears when its cell is filled or the ground under it is dug.
func on_cell_changed(cell: Vector3i) -> void:
	WorldActions.bushes_lose_ground(game.world, cell)
