extends Node3D
## The ghost things of the blueprint (Plans.things; the user's picks, 2026-11-26, 1А): each
## its own model (Props.model_mesh) where it will stand, see-through and tinted cold blue as
## the blueprint's blocks are (PlanBlocks.ghost_material). A door or a window to be cut into
## a wall built stands in the middle of the wall, where it will be, in the opening it will
## cut, its blocks drawn as air (holes, ChunkStreamer.set_holes; user 2026-11-26), as it
## does while held (hold_hole).
## The build mode carries one held up (hold) and lets it drop back (settle), and shows a
## thing new from the bag in the same look while it is held (material, Props.hold_new).
## PlanView shows them in the build mode only. `game` is the Main node, its `plans` the
## client's copy.

const WorldData := preload("res://src/shared/world/world_data.gd")
const PlanBlocks := preload("res://src/client/view/plan_blocks.gd")
const Props := preload("res://src/client/game/props.gd")
const Items := preload("res://src/shared/content/items.gd")

const CELL := WorldData.CELL
## Ghost things are drawn denser and lit more than the ghost blocks (PlanBlocks.ALPHA, GLOW),
## so a ghost door stands out of the ghost wall it is drawn into.
const ALPHA := 0.9
const GLOW := 0.35
## How often the openings drawn cut are looked at again while none is held, in ms.
const HOLES_MS := 250

var game
## The models of the ghost things drawn, by the north-west cell of each.
var _nodes := {}
var _material: ShaderMaterial
## The look of the ghost things the bag has none of for the blueprint near (BuildMode.short_of),
## tinted PlanBlocks.SHORT_TINT, and which items were short at the last look.
var _short_material: ShaderMaterial
var _short := {}
## The opening of the door or the window held up by the build mode (hold_hole): its cells
## and the ghost thing it is (null for one new from the bag or set down).
var _held_cells: Array = []
var _held_thing: Variant = null
## When the openings were last looked at (_show_holes), whether one was held then and
## whether the ghost things were shown.
var _holes_at := 0
var _was_held := false
var _holes_shown := false


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


## The look of ghost things of `item`: tinted short when the bag has too few for the blueprint near.
func _look(item: String) -> ShaderMaterial:
	var look := material()
	if look == null or not _short.has(item):
		return look
	if _short_material == null:
		_short_material = PlanBlocks.ghost_material(game.world_mat, ALPHA, GLOW)
		for m: ShaderMaterial in [_short_material, _short_material.next_pass]:
			m.set_shader_parameter("ghost_tint", Color(PlanBlocks.SHORT_TINT, PlanBlocks.TINT_SHARE))
	return _short_material


func _process(_delta: float) -> void:
	_show_holes()
	var now := {}
	if game.build != null and game.build.on:
		for id: String in game.build.need():
			if Items.is_interior(id) and game.build.short_of(id):
				now[id] = true
	if now == _short:
		return
	_short = now
	for t: Dictionary in game.plans.things:
		var node: MeshInstance3D = _nodes.get(t.cell)
		if node != null:
			node.material_override = _look(t.item)


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
	var look := _look(t.item)
	var mesh: Mesh = game.props.model_mesh(t.item, t.turn)
	if mesh == null or look == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = look
	node.scale = Vector3.ONE / 16.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = _rest(t)
	node.set_meta("turn", int(t.turn))
	add_child(node)
	_nodes[t.cell] = node
	_fit(node)


func _drop(cell: Vector3i) -> void:
	var node: Node3D = _nodes.get(cell)
	if node != null:
		node.queue_free()
	_nodes.erase(cell)


## Where ghost thing `t` is drawn: its north-west cell (in the wall it is to be cut into too).
func _rest(t: Dictionary) -> Vector3:
	return Vector3(t.cell) * CELL


## Holds the model of ghost thing `t` up over north-west cell `corner` turned `turn`, while
## the build mode drags it.
func hold(t: Dictionary, corner: Vector3i, turn: int) -> void:
	var node: MeshInstance3D = _nodes.get(t.cell)
	if node == null or not is_instance_valid(node):
		return
	_turn(node, t, turn)
	node.position = Vector3(corner) * CELL + Vector3(0.0, Props.LIFT * CELL, 0.0)
	_fit(node)


## The model of ghost thing `t` dragged and let go drops back where it stands (the server
## moves it, if it can go where it was let go).
func settle(t: Dictionary) -> void:
	var node: MeshInstance3D = _nodes.get(t.cell)
	if node == null or not is_instance_valid(node):
		return
	_turn(node, t, int(t.turn))
	node.position = _rest(t)
	_fit(node)


## Fits the boxes of every ghost thing again for the views the camera shows now (see
## ChunkStreamer.refit_boxes).
func refit_boxes() -> void:
	for node: MeshInstance3D in _nodes.values():
		_fit(node)


## Culls `node` by the box of what it draws, sheared by the 3/4 view (Props.fit): a margin
## all round held it only near the sea's level, so on high ground a ghost thing came and
## went as the camera turned.
func _fit(node: MeshInstance3D) -> void:
	game.props.fit(node)


func _turn(node: MeshInstance3D, t: Dictionary, turn: int) -> void:
	if int(node.get_meta("turn", -1)) == turn:
		return
	var mesh: Mesh = game.props.model_mesh(t.item, turn)
	if mesh != null:
		node.mesh = mesh
		node.set_meta("turn", turn)


## The opening of a door or a window the build mode holds up (BuildMode.cut_cells): cells
## `cells` are drawn cut while a stroke holds it, and ghost thing `thing` (when it is one)
## leaves its own opening meanwhile.
func hold_hole(cells: Array, thing: Variant = null) -> void:
	_held_cells = cells
	_held_thing = thing


## Draws cut the blocks the doors and the windows of the blueprint (and the one held up)
## will cut out of walls, in the build mode only (ChunkStreamer.set_holes).
func _show_holes() -> void:
	var held: bool = not game.controls.dragging().is_empty()
	# Looked at again every HOLES_MS (a thing set or built), every frame while one is held.
	var now := Time.get_ticks_msec()
	if not held and not _was_held and now - _holes_at < HOLES_MS and visible == _holes_shown:
		return
	_holes_at = now
	_was_held = held
	_holes_shown = visible
	var want := {}
	if visible and game.build != null:
		for t: Dictionary in game.plans.things:
			if held and is_same(t, _held_thing):
				continue
			for c: Vector3i in game.build.cut_cells(t.item, t.cell, int(t.turn)):
				want[c] = true
		if held:
			for c: Vector3i in _held_cells:
				want[c] = true
	if not want.is_empty() or not game.chunks.holes_empty():
		game.chunks.set_holes(want)
