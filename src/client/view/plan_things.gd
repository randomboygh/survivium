extends Node3D
## The ghost things of the blueprint (Plans.things; the user's picks, 2026-11-26, 1А): each
## its own model (Props.model_mesh) where it will stand, see-through and tinted cold blue as
## the blueprint's blocks are (PlanBlocks.ghost_material). A door or a window to be cut into
## a wall built hangs before the wall's face (BuildMode.out_of_wall), as it did while held.
## The build mode carries one held up (hold) and lets it drop back (settle), and shows a
## thing new from the bag in the same look while it is held (material, Props.hold_new).
## PlanView shows them in the build mode only. `game` is the Main node, its `plans` the
## client's copy.

const WorldData := preload("res://src/shared/world/world_data.gd")
const PlanBlocks := preload("res://src/client/view/plan_blocks.gd")
const Props := preload("res://src/client/game/props.gd")

const CELL := WorldData.CELL
## Ghost things are drawn denser and lit more than the ghost blocks (PlanBlocks.ALPHA, GLOW),
## so a ghost door stands out of the ghost wall it is drawn into.
const ALPHA := 0.9
const GLOW := 0.35

var game
## The models of the ghost things drawn, by the north-west cell of each.
var _nodes := {}
var _material: ShaderMaterial


func _init(g) -> void:
	game = g


func _ready() -> void:
	game.plans.thing_changed.connect(_on_thing)
	game.plans.changed.connect(_on_changed)
	_reset()


## The ghost look (PlanBlocks.ghost_material) of the props' world material, once the world
## has one; null before.
func material() -> ShaderMaterial:
	if _material == null and game.world_mat != null:
		_material = PlanBlocks.ghost_material(game.world_mat, ALPHA, GLOW)
	return _material


## The whole blueprint read anew (joining, a world loaded): every ghost thing drawn again.
func _on_changed(cells: Array, _item: String) -> void:
	if cells.is_empty():
		_reset()


func _on_thing(t: Dictionary, came: bool) -> void:
	if came:
		_add(t)
	else:
		_drop(t.cell)


func _reset() -> void:
	for c: Vector3i in _nodes:
		_nodes[c].queue_free()
	_nodes.clear()
	for t: Dictionary in game.plans.things:
		_add(t)


## Draws ghost thing `t` where it stands (one at its cell before goes).
func _add(t: Dictionary) -> void:
	_drop(t.cell)
	var look := material()
	var mesh: Mesh = game.props.model_mesh(t.item, t.turn)
	if mesh == null or look == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = look
	node.scale = Vector3.ONE / 16.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Drawn sheared by the 3/4 view: its box grows so it is not culled while seen.
	node.extra_cull_margin = Props.CULL_MARGIN
	node.position = _rest(t)
	node.set_meta("turn", int(t.turn))
	add_child(node)
	_nodes[t.cell] = node


func _drop(cell: Vector3i) -> void:
	var node: Node3D = _nodes.get(cell)
	if node != null:
		node.queue_free()
	_nodes.erase(cell)


## Where ghost thing `t` is drawn: its north-west cell, before the wall it is to be cut into.
func _rest(t: Dictionary) -> Vector3:
	return (Vector3(t.cell) + game.build.out_of_wall(t.item, t.cell, t.turn)) * CELL


## Holds the model of ghost thing `t` up over north-west cell `corner` turned `turn`, moved
## `out` cells more (a door before the wall it would be cut into), while the build mode
## drags it.
func hold(t: Dictionary, corner: Vector3i, turn: int, out := Vector3.ZERO) -> void:
	var node: MeshInstance3D = _nodes.get(t.cell)
	if node == null or not is_instance_valid(node):
		return
	_turn(node, t, turn)
	node.position = (Vector3(corner) + out) * CELL + Vector3(0.0, Props.LIFT * CELL, 0.0)


## The model of ghost thing `t` dragged and let go drops back where it stands (the server
## moves it, if it can go where it was let go).
func settle(t: Dictionary) -> void:
	var node: MeshInstance3D = _nodes.get(t.cell)
	if node == null or not is_instance_valid(node):
		return
	_turn(node, t, int(t.turn))
	node.position = _rest(t)


func _turn(node: MeshInstance3D, t: Dictionary, turn: int) -> void:
	if int(node.get_meta("turn", -1)) == turn:
		return
	var mesh: Mesh = game.props.model_mesh(t.item, turn)
	if mesh != null:
		node.mesh = mesh
		node.set_meta("turn", turn)
