extends Node3D
## The rafts and boats on the water (Vessels on the server, told by Protocol.VESSELS,
## VESSEL, VESSEL_GONE): each its item's voxel model on the water, turned the way it last
## went, sliding to where the server last put it. The one the player sits in is drawn at
## the player's own body (its rower's place, or before the one carried, see
## ActionsBoat.seat_at), so it never lags behind them. `game` is the Main node.

const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const Items := preload("res://src/shared/content/items.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const ActionsBoat := preload("res://src/shared/game/actions_boat.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")

const CELL := WorldData.CELL
## The model of a vessel sits this far under the feet of those in it (world units): its
## lowest layer of voxels in the water.
const SINK := 1.0 / 16.0
## How fast a vessel drawn slides to where the server put it (a share a second).
const SLIDE := 12.0
## How much larger than the sheared box of a model its cull box is (world units).
const FIT_MARGIN := 0.25

var game
## By vessel id: {"node": MeshInstance3D, "item", "at", "turn"} as last told.
var vessels := {}
var _meshes := {}


## Takes the whole list (on joining): [[id, item, position, turn]…].
func take_all(list: Array) -> void:
	for id in vessels.keys():
		take_gone(id)
	for r in list:
		if r is Array:
			take(r)


## Takes one vessel launched or moved: [id, item, position, turn].
func take(r: Array) -> void:
	if r.size() != 4 or not r[0] is int or not r[1] is String or not r[2] is Vector3 or not (r[3] is float or r[3] is int):
		return
	var one: Dictionary = vessels.get(r[0], {})
	if one.is_empty():
		var node := MeshInstance3D.new()
		node.mesh = _mesh(r[1])
		node.material_override = game.low_mat
		node.scale = Vector3.ONE / 16.0
		node.position = r[2] - Vector3(0.0, SINK, 0.0)
		node.rotation.y = float(r[3])
		_fit(node)
		add_child(node)
		one = {"node": node}
		vessels[r[0]] = one
	one.item = r[1]
	one.at = r[2]
	one.turn = float(r[3])


func take_gone(id: int) -> void:
	var one: Dictionary = vessels.get(id, {})
	if one.is_empty():
		return
	vessels.erase(id)
	one.node.queue_free()


## The vessel whose hull the view ray from `origin` along `dir` (world units) passes
## nearest, within `reach` of its middle: its id, 0 for none.
func vessel_at(origin: Vector3, dir: Vector3, reach: float) -> int:
	var d := dir.normalized()
	var best := reach
	var out := 0
	for id in vessels:
		var p: Vector3 = vessels[id].node.position
		var t := maxf(0.0, (p - origin).dot(d))
		var miss := (origin + d * t).distance_to(p)
		if miss < best:
			best = miss
			out = id
	return out


func _mesh(item: String) -> Mesh:
	if not _meshes.has(item):
		var model = VoxelProps.drop(Items.get_item(item)) if Items.has(item) else null
		_meshes[item] = (model if model != null else VoxelProps.bundle()).build_mesh()
	return _meshes[item]


func _process(delta: float) -> void:
	if vessels.is_empty():
		return
	var mine: int = game.character.vessel
	for id in vessels:
		var one: Dictionary = vessels[id]
		var node: MeshInstance3D = one.node
		var at: Vector3 = one.at
		var turn: float = one.turn
		if id == mine and mine != 0:
			# The player's own: under them (before them when carried), turned their way.
			var p: Vector3 = game.player.position
			if game.character.seat == 0:
				at = p
				var way := Vector2(game.player.body.glide)
				if way.length() > 0.1:
					one.turn = atan2(way.x, way.y)
				turn = one.turn
			else:
				at = p + Vector3(sin(turn), 0.0, cos(turn)) * ActionsBoat.BACK_SEAT * CELL
		var k := minf(1.0, SLIDE * delta) if id != mine else 1.0
		node.position = node.position.lerp(at - Vector3(0.0, SINK, 0.0), k)
		node.rotation.y = lerp_angle(node.rotation.y, turn, k)
		_fit(node)


## Sets the box the camera culls `node` by to where the shaders draw it (the shear
## moves it far from its own box, see PixelView.sheared_box).
func _fit(node: MeshInstance3D) -> void:
	var to_world := node.transform
	node.custom_aabb = to_world.affine_inverse() * PixelView.sheared_box(to_world * node.mesh.get_aabb(), FIT_MARGIN)
