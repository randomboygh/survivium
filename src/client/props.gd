extends RefCounted
## Things standing on the ground that are not cells and not part of a chunk: the
## chest and the campfire next to the spawn, and the items lying on the ground
## (WorldData.drops: what a felled tree leaves, a death sack). Bushes and snowdrifts
## are grown by the world generator and drawn with the chunk they stand in (see ChunkStreamer,
## Foliage.finish); a bush that goes is taken out of the world and its chunk is
## rebuilt. `game` is the Main node that owns the scene.

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const RoofMap := preload("res://src/client/roof_map.gd")
const Items := preload("res://src/shared/items.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")

const CELL := WorldData.CELL
## World units the bounding boxes grow by, so the shear of the 3/4 view (which draws a
## thing `y` units north of its place) does not cull it. The models are scaled down to
## 1/16 and the margin grows the box before that, so they get it 16 times over.
const CULL_MARGIN := 24.0
## Seconds a thing taken from the ground takes to fly to the player.
const FLY_TIME := 0.2
const MODEL_CULL_MARGIN := CULL_MARGIN * 16.0

var game
## Meshes of the things on the ground by model, and their nodes by chunk.
var drop_meshes := {}
var drop_nodes := {}
## The north-west cell of each prop placed, by name ("chest", "campfire"), for the save.
var cells := {}


func _init(g) -> void:
	game = g


## Puts the chest and the campfire into the world, where the save had them or next to
## the player; the near chunks are built by then, so the ground under them is known.
func place() -> void:
	var world_root: Node3D = game.world_root
	# A chest and a campfire next to the spawn point, each on two by two cells.
	var at: Vector3 = game.player.position
	var new_world: bool = not game.save.player_placed
	var chest_spot := _saved_or_new("chest", at + Vector3(2.0, 0.0, 1.0))
	if chest_spot.y >= 0:
		var chest := MeshInstance3D.new()
		chest.mesh = VoxelProps.chest().build_mesh()
		chest.material_override = game.world_mat
		chest.scale = Vector3.ONE / 16.0
		chest.position = Vector3(chest_spot) * CELL
		chest.extra_cull_margin = MODEL_CULL_MARGIN
		world_root.add_child(chest)
	var fire := _saved_or_new("campfire", at + Vector3(-2.0, 0.0, 2.0))
	if new_world:
		_lay_tools(Vector3i((at / CELL).floor()))
	if fire.y >= 0:
		game.effects.add_campfire(Vector3(fire) * CELL, game.world_mat)
	RenderingServer.global_shader_parameter_set("heat_map", game.effects.heat_map(RoofMap.WRAP / 2))


## Until tools are crafted, a new world has a set of them lying in a row just south of
## the spawn cell `at`.
func _lay_tools(at: Vector3i) -> void:
	var world = game.world
	var ids: Array = game.settings.TOOL_SET
	for i in ids.size():
		var x := at.x - 3 + i * 2
		var z := at.z + 2
		var h: float = world.ground_height(x + 0.5, z + 0.5)
		if h > 0.0:
			world.add_drop(ids[i], Vector3(x + 0.5, h, z + 0.5) * CELL, PI / 4.0)
	show_drops(WorldData.chunk_key(at.x - 3, at.z + 2))
	show_drops(WorldData.chunk_key(at.x + 3, at.z + 2))


## The cell of prop `name` from the save, else a new spot near `p` (see _prop_spot).
func _saved_or_new(name: String, p: Vector3) -> Vector3i:
	var saved: Variant = game.save.prop_cell(name)
	var spot: Vector3i = saved if saved != null else _prop_spot(p)
	if spot.y >= 0:
		cells[name] = spot
	return spot


## The north-west cell of two by two free cells on ground at one level near the world
## point `p`, the ground under them levelled; y = -1 when there is no such spot.
func _prop_spot(p: Vector3) -> Vector3i:
	var world = game.world
	var x := floori(p.x / CELL)
	var z := floori(p.z / CELL)
	var y: int = world.surface_y(x, z)
	if y <= 0:
		return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			if world.get_cell(x + dx, y, z + dz) != Mat.AIR or not world.is_solid(x + dx, y - 1, z + dz):
				return Vector3i(0, -1, 0)
	for dz in 2:
		for dx in 2:
			_level_ground(Vector3i(x + dx, y - 1, z + dz))
			remove_bush(Vector3i(x + dx, y, z + dz))
	return Vector3i(x, y, z)


## Props stand on level ground: a slope under them becomes a whole cube.
func _level_ground(cell: Vector3i) -> void:
	var world = game.world
	if world.slope_mask(cell.x, cell.y, cell.z) != world.FULL:
		world.set_natural(cell.x, cell.y, cell.z, false)
		game.chunks.on_cell_changed(cell)


## Takes the bush on `cell` out of the world; its chunk is rebuilt without it.
func remove_bush(cell: Vector3i) -> void:
	if not game.world.bushes.has(cell):
		return
	game.world.remove_bush(cell)
	game.chunks.on_cell_changed(cell)


## Shows what lies on the ground in chunk `key` (see WorldData.drops) afresh.
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
		node.material_override = game.world_mat
		# Turned in steps of 45 degrees, which keep the pixels tidy.
		node.basis = Basis(Vector3.UP, -snappedf(d[2], PI / 4.0)).scaled(Vector3.ONE / 16.0)
		node.position = d[1]
		node.extra_cull_margin = MODEL_CULL_MARGIN
		game.world_root.add_child(node)
		nodes.append(node)
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
	var img := atlas.get_image()
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
	node.material_override = game.world_mat
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
	for c in [cell, cell + Vector3i(0, 1, 0)]:
		if game.world.bushes.has(c):
			game.world.remove_bush(c)
