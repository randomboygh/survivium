extends Node3D
## The rafts and boats on the water (Vessels on the server, told by Protocol.VESSELS,
## VESSEL, VESSEL_GONE): each its item's voxel model on the water, turned the way it last
## went, sliding to where the server last put it. The one the player sits in is drawn at
## the player's own body (its rower's place, or before the one carried, see
## ActionsBoat.seat_at), so it never lags behind them. A vessel that names `oars` has two
## at its oarlocks, swung in time with its rower's strokes (the `row` animation, see
## stroke) while it goes. `game` is the Main node.

const VoxelProps := preload("res://src/client/view/voxel_props.gd")
const Items := preload("res://src/shared/content/items.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const ActionsBoat := preload("res://src/shared/game/actions_boat.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const VoxelModel := preload("res://src/client/view/voxel_model.gd")
const Mat := preload("res://src/shared/content/materials.gd")

const CELL := WorldData.CELL
## The model of a vessel sits this far under the feet of those in it (world units): its
## lowest layer of voxels in the water.
const SINK := 1.0 / 16.0
## How fast a vessel drawn slides to where the server put it (a share a second).
const SLIDE := 12.0
## How much larger than the sheared box of a model its cull box is (world units).
const FIT_MARGIN := 0.25
## How long one stroke of the oars takes, in seconds: the rower's `row` animation and the
## oars go by the same clock (stroke).
const ROW_PERIOD := 1.0
## How far the oars swing forward and back from across, and how far their blades dip
## pulling and stay up coming back (radians), and lie on the water at rest.
const OAR_SWEEP := 0.55
const OAR_DIP := 0.42
const OAR_LIFT := 0.12
const OAR_REST := 0.3
## How fast a vessel goes to be seen rowed (world units a second), and how near its middle
## a body sits to be its rower (world units).
const GOING := 0.25
const AT_OARS := 0.3
## How far behind its middle a vessel's wake starts (cells), where along an oar its blade
## splashes (voxels from the oarlock), and how loud the oars plash (Sound.play).
const STERN := 1.3
const OAR_BLADE := 12.0
const OAR_PLASH := 0.35

var game
## By vessel id: {"node": MeshInstance3D, "item", "at", "turn"} as last told.
var vessels := {}
var _meshes := {}
var _oar_mesh: Mesh


## Where the stroke of the oars is now, 0 to 1: caught forward at 0, pulled through the
## water to 0.5, carried forward over it to 1 (the `row` frames: hands out, pulling,
## pulled in, coming back).
static func stroke() -> float:
	return fmod(Time.get_ticks_msec() / 1000.0, ROW_PERIOD) / ROW_PERIOD


## Whether a body at `at` (world units) sits at the oars of a vessel: at its middle.
func rower_at(at: Vector3) -> bool:
	for id in vessels:
		var p: Vector3 = vessels[id].node.position
		if Vector2(p.x - at.x, p.z - at.z).length() < AT_OARS * CELL:
			return true
	return false


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
		node.layers = PixelView.LAYER_THINGS
		_fit(node)
		add_child(node)
		one = {"node": node, "oars": _oars(node, r[1]), "stroke": 0.0,
			"wake": game.effects.wake() if game.effects != null else null}
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
	if one.wake != null:
		one.wake.queue_free()


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
				one.turn = game.player.body.heading
				turn = one.turn
			else:
				at = p + Vector3(sin(turn), 0.0, cos(turn)) * ActionsBoat.BACK_SEAT * CELL
		var k := minf(1.0, SLIDE * delta) if id != mine else 1.0
		var was := node.position
		node.position = node.position.lerp(at - Vector3(0.0, SINK, 0.0), k)
		node.rotation.y = lerp_angle(node.rotation.y, turn, k)
		_fit(node)
		var going: bool = (node.position - was).length() > GOING * delta
		if id == mine:
			going = Vector2(game.player.body.glide).length() > GOING
		if one.wake != null:
			# The wake trails from the stern while it goes.
			# (On the water, not under it where the model's bottom is.)
			one.wake.position = node.position + Vector3(0.0, 2.0 * SINK, 0.0) \
				+ Vector3(sin(node.rotation.y), 0.0, cos(node.rotation.y)) * -STERN * CELL
			one.wake.emitting = going
		if not one.oars.is_empty():
			var rowed := going
			if id == mine:
				# The player rows while pushing the stick, not while it coasts on.
				rowed = game.character.seat == 0 and game.player.body.move_input.length() > 0.1
			_swing(one.oars, rowed)
			var t := stroke()
			if rowed and t < one.stroke:
				_dip(one, node)
			one.stroke = t


## The blades of vessel `one`'s oars catch the water (each stroke): a splash at each
## and the plash of them, heard near.
func _dip(one: Dictionary, node: MeshInstance3D) -> void:
	for pivot: Node3D in one.oars:
		var blade: Vector3 = pivot.global_transform * Vector3(OAR_BLADE, 0.0, 0.0)
		if game.effects != null:
			game.effects.burst(blade, Mat.WATER)
	game.sound.play("swim", node.position, OAR_PLASH)


## The two oars of a vessel of `item` that names `oars`, at its oarlocks (the ends of its
## widest row, a voxel under its top, a voxel and a half before its middle), children of
## its `node`: [right pivot, left pivot], or [] for a vessel without.
func _oars(node: MeshInstance3D, item: String) -> Array:
	if not Items.has(item) or str(Items.get_item(item).get("oars", "")) == "":
		return []
	if _oar_mesh == null:
		_oar_mesh = _oar().build_mesh()
	var box := node.mesh.get_aabb()
	var out := []
	for side in 2:
		var pivot := Node3D.new()
		pivot.position = Vector3(box.end.x - 0.5 if side == 0 else box.position.x + 0.5, box.end.y - 0.5, box.get_center().z + 1.5)
		var oar := MeshInstance3D.new()
		oar.mesh = _oar_mesh
		oar.material_override = game.low_mat
		oar.layers = PixelView.LAYER_THINGS
		# Turned about the oarlock, the shear moves it out of its box (see _fit).
		oar.extra_cull_margin = 16.0 * 4.0
		oar.position = -Vector3(0.5, 0.5, 0.5)
		pivot.add_child(oar)
		node.add_child(pivot)
		out.append(pivot)
	_swing(out, false)
	return out


## Swings the oars to where the stroke is now (stroke) while the vessel is rowed, else lets
## them lie across on the water.
func _swing(oars: Array, going: bool) -> void:
	var yaw := 0.0
	var dip := OAR_REST
	if going:
		# Caught forward, pulled back through the water, then carried forward over it.
		var t := stroke()
		yaw = OAR_SWEEP * (4.0 * t - 1.0) if t < 0.5 else OAR_SWEEP * (3.0 - 4.0 * t)
		dip = OAR_DIP if t < 0.5 else OAR_LIFT
	for side in oars.size():
		var w := yaw if side == 0 else PI - yaw
		oars[side].basis = Basis.from_euler(Vector3(0.0, w, -dip))


## An oar along +x from its oarlock (the voxel at the origin): the handle inside, the
## shaft out over the water and the blade at its end.
static func _oar() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.66, 0.5, 0.31)
	var blade := Color(0.56, 0.41, 0.24)
	for x in range(-4, 10):
		m.set_voxel(Vector3i(x, 0, 0), wood * (0.85 if x < -2 else 1.0))
	for x in range(10, 14):
		for z in range(-1, 2):
			m.set_voxel(Vector3i(x, 0, z), blade)
	return m


## Sets the box the camera culls `node` by to where the shaders draw it (the shear
## moves it far from its own box, see PixelView.sheared_box).
func _fit(node: MeshInstance3D) -> void:
	var to_world := node.transform
	node.custom_aabb = to_world.affine_inverse() * PixelView.sheared_box(to_world * node.mesh.get_aabb(), FIT_MARGIN)
