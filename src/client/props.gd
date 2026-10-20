extends RefCounted
## Things standing on the ground that are not cells: the bushes of the map (one
## multimesh of cards and one of shadows), the snowdrifts, and the chest and the
## campfire next to the spawn. `game` is the Main node that owns the scene.

const Bushes := preload("res://src/shared/bushes.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const Foliage := preload("res://src/client/foliage.gd")
const PixelTextures := preload("res://src/client/pixel_textures.gd")
const VoxelProps := preload("res://src/client/voxel_props.gd")
const Drifts := preload("res://src/client/drifts.gd")
const LeavesShader := preload("res://shaders/leaves.gdshader")

const CELL := WorldData.CELL
const CULL_MARGIN := 24.0

var game
var bushes: MultiMeshInstance3D
var bush_shade: MultiMeshInstance3D
var bush_cells: Array[Vector3i] = []
## Where each bush's cards and shadow sit in the multimeshes: [first card, cards, disc].
var bush_slots := {}
var drifts: MultiMeshInstance3D


func _init(g) -> void:
	game = g


## Puts the bushes, the drifts, the chest and the campfire into the world; the near
## chunks are built by then, so the ground under them is known.
func place() -> void:
	var world = game.world
	var world_root: Node3D = game.world_root
	# Until the world generator places bushes, they are scattered plainly.
	if world.bushes.is_empty():
		Bushes.scatter(world, game.WORLD_SEED + 100)
	bush_cells.assign(world.bushes.keys())
	var bush_mat := ShaderMaterial.new()
	bush_mat.shader = LeavesShader
	bush_mat.set_shader_parameter("clump_texture", PixelTextures.build_bush_clumps(Foliage.BUSH_CLUMP))
	bush_mat.set_shader_parameter("clump_size", Foliage.BUSH_CLUMP / 16.0)
	bush_mat.set_shader_parameter("clump_rows", PixelTextures.BUSH_ROWS)
	bush_mat.set_shader_parameter("branch_row", PixelTextures.BUSH_TWIG_ROW)
	var berry_colors := PackedVector3Array()
	for b: Dictionary in Bushes.TYPES:
		var c: Color = b.berries
		berry_colors.append(Vector3(c.r, c.g, c.b))
	bush_mat.set_shader_parameter("berry_colors", berry_colors)
	bushes = Foliage.multimesh(Foliage.quad_mesh(Foliage.BUSH_CLUMP / 16.0, true), bush_mat, true, true)
	bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bushes.extra_cull_margin = CULL_MARGIN
	world_root.add_child(bushes)
	bush_shade = Foliage.multimesh(Foliage.disc_mesh(Foliage.BUSH_DISC), game.leaf_shadow_mat, false, true)
	bush_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	bush_shade.extra_cull_margin = CULL_MARGIN
	world_root.add_child(bush_shade)
	refresh_bushes()
	# Snowdrifts, shown with the snow cover.
	drifts = Foliage.multimesh(Drifts.mound_mesh(), game.world_mat, false, false)
	var mounds: Array = Drifts.build(world)
	drifts.multimesh.instance_count = mounds[0]
	if mounds[0] > 0:
		drifts.multimesh.buffer = mounds[1]
	drifts.visible = false
	drifts.extra_cull_margin = CULL_MARGIN
	world_root.add_child(drifts)

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
	RenderingServer.global_shader_parameter_set("heat_map", game.effects.heat_map(ceili(world.size_x * CELL), ceili(world.size_z * CELL)))


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
	return Vector3i(x, y, z)


## Props stand on level ground: a slope under them becomes a whole cube.
func _level_ground(cell: Vector3i) -> void:
	var world = game.world
	if world.slope_mask(cell.x, cell.y, cell.z) != world.FULL:
		world.set_natural(cell.x, cell.y, cell.z, false)
		game.chunks.on_cell_changed(cell)


## Builds every bush of the map: once, at the start (5 ms on a desktop for 240 bushes,
## a freeze on a phone, so a bush that goes is hidden by remove_bush instead).
func refresh_bushes() -> void:
	var world = game.world
	var part: Array = Foliage.bushes(bush_cells, world.bushes)
	bushes.multimesh.instance_count = part[0]
	if part[0] > 0:
		bushes.multimesh.buffer = part[1]
	var discs := PackedFloat32Array()
	bush_slots.clear()
	var first := 0
	for cell in bush_cells:
		var type: int = world.bushes.get(cell, Bushes.SHRUB)
		Foliage.put(discs, (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, 0.5, 0.0))
		discs.append_array([Foliage.bush_kind(type), 0.0, 0.0, 0.0])
		var cards: int = Bushes.TYPES[type].cards
		bush_slots[cell] = [first, cards, bush_slots.size()]
		first += cards
	bush_shade.multimesh.instance_count = bush_cells.size()
	if not bush_cells.is_empty():
		bush_shade.multimesh.buffer = discs


## Takes the bush on `cell` out of the world and scales its cards and shadow away.
func remove_bush(cell: Vector3i) -> void:
	bush_cells.erase(cell)
	game.world.bushes.erase(cell)
	if not bush_slots.has(cell):
		return
	var slot: Array = bush_slots[cell]
	bush_slots.erase(cell)
	var gone := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for i in range(slot[0], slot[0] + slot[1]):
		bushes.multimesh.set_instance_transform(i, gone)
	bush_shade.multimesh.set_instance_transform(slot[2], gone)


## A bush disappears when its cell is filled or the ground under it is dug.
func on_cell_changed(cell: Vector3i) -> void:
	for c in [cell, cell + Vector3i(0, 1, 0)]:
		if bush_cells.has(c):
			remove_bush(c)
