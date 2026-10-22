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

const CELL := WorldData.CELL
## World units the bounding boxes grow by, so the shear of the 3/4 view (which draws a
## thing `y` units north of its place) does not cull it. The models are scaled down to
## 1/16 and the margin grows the box before that, so they get it 16 times over.
const CULL_MARGIN := 24.0
## Things lower than this (world units; the player is 1 tall) are low: the player's
## silhouette does not show behind them (see sprite_xray.gdshader).
const LOW_HEIGHT := 0.75
## Seconds a thing taken from the ground takes to fly to the player.
const FLY_TIME := 0.2
const MODEL_CULL_MARGIN := CULL_MARGIN * 16.0

var game
## Meshes of the things on the ground by model, and their nodes by chunk.
var drop_meshes := {}
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
		if kind != "none" and kind != "campfire":
			placed.footprints[kind] = VoxelProps.footprint(_model(kind))
	placed.added.connect(_on_added)
	placed.removed.connect(_on_removed)
	placed.lit_changed.connect(_on_lit_changed)


## Puts the placed things into the world as the save had them, or a chest and a
## campfire next to the player in a new world; the near chunks are built by then, so
## the ground under them is known.
func place() -> void:
	var meta: Dictionary = game.save.meta
	if meta.get("placed") is Array:
		game.placed.from_list(meta.placed)
	elif meta.get("props") is Dictionary:
		# A save from before things could be placed: the chest and the campfire by name.
		for name in ["chest", "campfire"]:
			var c: Variant = game.save.prop_cell(name)
			if c != null:
				game.placed.put(Placed.CHEST if name == "chest" else Placed.CAMPFIRE, c,
					meta.get("chest") if name == "chest" else null)
	else:
		game.placed.start_camp(game.player.position)
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
	node.extra_cull_margin = MODEL_CULL_MARGIN
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


## Shows what lies on the ground in chunk `key` (see WorldData.drops) afresh; a death's
## sack glows (Effects.sack_glow).
func show_drops(key: Vector2i) -> void:
	for node: Node in drop_nodes.get(key, []):
		node.queue_free()
	var nodes := []
	for d: Array in game.world.drops.get(key, []):
		var mesh := _drop_mesh(d[0])
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = game.low_mat
		# Turned in steps of 45 degrees, which keep the pixels tidy.
		node.basis = Basis(Vector3.UP, -snappedf(d[2], PI / 4.0)).scaled(Vector3.ONE / 16.0)
		node.position = d[1]
		node.extra_cull_margin = MODEL_CULL_MARGIN
		game.world_root.add_child(node)
		nodes.append(node)
		if d[0] == Items.SACK:
			nodes.append(game.effects.sack_glow(d[1]))
	drop_nodes[key] = nodes


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
	if not drop_meshes.has(name):
		var model = VoxelProps.block(_tile_colour(m)) if m >= 0 else VoxelProps.drop(name)
		drop_meshes[name] = model.build_mesh() if model != null else null
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
