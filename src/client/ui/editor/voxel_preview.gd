extends SubViewportContainer
## The voxel editor's 3D picture of the model (stage 2 item 3, step 5, 4А): the model as
## the game builds it (VoxelModel.build_mesh), turning slowly; a drag turns it by hand
## (and it rests a while after), the level being painted outlined in amber. Its own small
## world, so nothing of the game's scene lights it or shows in it; drawn at a low
## resolution and blown up with sharp pixels, like the game.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const VoxelSheet := preload("res://src/client/ui/editor/voxel_sheet.gd")

## Turns a second on its own, and how long it rests after a drag.
const TURN_SPEED := 0.5
const REST := 3.0
## Radians a UI pixel of drag turns.
const DRAG_TURN := 0.02
## How far down the camera looks.
const PITCH := -0.6

var viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: MeshInstance3D
var _outline: MeshInstance3D
var _material: StandardMaterial3D
var _rest := 0.0
var _dragging := false
## The sheet's levels and side the camera was last framed for.
var _framed := Vector2i.ZERO
var _centre := Vector3.ZERO


func _init() -> void:
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.55
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_energy = 0.9
	viewport.add_child(sun)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_pivot.add_child(_camera)
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_model = MeshInstance3D.new()
	_model.material_override = _material
	viewport.add_child(_model)
	_outline = MeshInstance3D.new()
	var line := StandardMaterial3D.new()
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.albedo_color = UiStyle.ACCENT
	line.no_depth_test = true
	_outline.material_override = line
	viewport.add_child(_outline)
	_pivot.rotation = Vector3(0.0, 0.6, 0.0)


## Builds the picture of `sheet` anew, level `level` outlined.
func show_sheet(sheet: VoxelSheet, level: int) -> void:
	var model = VoxelSheet.VoxelModel.from_image(sheet.img, true)
	_model.mesh = model.build_mesh() if not model.voxels.is_empty() else null
	var half := sheet.side / 2.0
	_outline.mesh = _slab(Vector3(-half, level, -half), Vector3(half, level + 1, half))
	var framed := Vector2i(sheet.side, sheet.levels)
	if framed != _framed:
		_framed = framed
		_centre = Vector3(0.0, sheet.levels * 0.5, 0.0)
		var span := maxf(sheet.side * 1.45, sheet.levels * 1.2)
		_camera.size = span
		_camera.near = 0.1
		_camera.far = span * 6.0
		_pivot.position = _centre
		_camera.rotation = Vector3(PITCH, 0.0, 0.0)
		_camera.position = Vector3(0.0, -sin(PITCH), cos(PITCH)) * span * 2.0


## The edges of the box from `a` to `b`, as lines.
static func _slab(a: Vector3, b: Vector3) -> ImmediateMesh:
	var m := ImmediateMesh.new()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	var c := [Vector3(a.x, 0, a.z), Vector3(b.x, 0, a.z), Vector3(b.x, 0, b.z), Vector3(a.x, 0, b.z)]
	for y: float in [a.y, b.y]:
		for i in 4:
			m.surface_add_vertex(c[i] + Vector3(0, y, 0))
			m.surface_add_vertex(c[(i + 1) % 4] + Vector3(0, y, 0))
	for i in 4:
		m.surface_add_vertex(c[i] + Vector3(0, a.y, 0))
		m.surface_add_vertex(c[i] + Vector3(0, b.y, 0))
	m.surface_end()
	return m


## Turns the model to `angle` (radians about the up axis).
func turn_to(angle: float) -> void:
	_pivot.rotation.y = angle


func _process(delta: float) -> void:
	if _rest > 0.0:
		_rest -= delta
		return
	_pivot.rotation.y = wrapf(_pivot.rotation.y + TURN_SPEED * delta, -PI, PI)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_rest = REST
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y = wrapf(_pivot.rotation.y - event.relative.x * DRAG_TURN, -PI, PI)
		_rest = REST
		accept_event()
