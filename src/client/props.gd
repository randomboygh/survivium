extends RefCounted
## Things standing on the ground that are not cells and not part of a chunk: the
## chest and the campfire next to the spawn. Bushes and snowdrifts are grown by the
## world generator and drawn with the chunk they stand in (see ChunkStreamer,
## Foliage.finish); a bush that goes is taken out of the world and its chunk is
## rebuilt. `game` is the Main node that owns the scene.

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const RoofMap := preload("res://src/client/roof_map.gd")
const Items := preload("res://src/shared/items.gd")

const CELL := WorldData.CELL
const CULL_MARGIN := 24.0

var game
## Meshes of the things on the ground by model, and their nodes by chunk.
var drop_meshes := {}
var drop_nodes := {}


func _init(g) -> void:
	game = g


## Puts the chest and the campfire into the world; the near chunks are built by
## then, so the ground under them is known.
func place() -> void:
	var world = game.world
	var world_root: Node3D = game.world_root
	# A chest and a campfire next to the spawn point, each on two by two cells.
	var at: Vector3 = game.player.position
	var chest_spot := _prop_spot(at + Vector3(2.0, 0.0, 1.0))
	if chest_spot.y >= 0:
		var chest := MeshInstance3D.new()
		chest.mesh = VoxelProps.chest().build_mesh()
		chest.material_override = game.world_mat
		chest.scale = Vector3.ONE / 16.0
		chest.position = Vector3(chest_spot) * CELL
		chest.extra_cull_margin = CULL_MARGIN
		world_root.add_child(chest)
	var fire := _prop_spot(at + Vector3(-2.0, 0.0, 2.0))
	if fire.y >= 0:
		game.effects.add_campfire(Vector3(fire) * CELL, game.world_mat)
	RenderingServer.global_shader_parameter_set("heat_map", game.effects.heat_map(RoofMap.WRAP / 2))


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
		var kind: String = d[0]
		var name: String = "sack" if kind == Items.SACK else Items.get_item(kind).get("model", "")
		if name == "":
			name = "bundle"
		if not drop_meshes.has(name):
			var model = VoxelProps.drop(name)
			drop_meshes[name] = model.build_mesh() if model != null else null
		if drop_meshes[name] == null:
			continue
		var node := MeshInstance3D.new()
		node.mesh = drop_meshes[name]
		node.material_override = game.world_mat
		# Turned in steps of 45 degrees, which keep the pixels tidy.
		node.basis = Basis(Vector3.UP, -snappedf(d[2], PI / 4.0)).scaled(Vector3.ONE / 16.0)
		node.position = d[1]
		node.extra_cull_margin = CULL_MARGIN
		game.world_root.add_child(node)
		nodes.append(node)
	drop_nodes[key] = nodes


## A bush disappears when its cell is filled or the ground under it is dug.
func on_cell_changed(cell: Vector3i) -> void:
	for c in [cell, cell + Vector3i(0, 1, 0)]:
		if game.world.bushes.has(c):
			game.world.remove_bush(c)
