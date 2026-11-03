extends RefCounted
## The view in a sphere (setting «Вид в пещере» → «сфера»): under a roof, in a ravine or
## behind a hill, a sphere stands in the world on the line from the middle of the
## player's body to the camera, SHIFTS cells toward the camera, RADII cells in radius
## (test settings «Пещеры»). What of it is nearer the camera than the player (by
## MARGIN, across the way the camera looks) is left out: the shaders hide what stands
## there (sphere_hides in common.gdshaderinc, globals sphere_view = on and the
## sphere's middle, sphere_body = the middle of the body and the radius). Everything
## else is drawn as it is, from the camera's side too. The faces of the solid cells
## beyond what is left out, which the world's mesh does not have, are drawn on the
## sphere's near side (cave_sphere.gdshader, by solid_map). A test setting shows the
## sphere itself, see-through and lit (cave_sphere_debug.gdshader). This mirrors
## sphere_hides for picking cells.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const FaceShader := preload("res://shaders/cave_sphere.gdshader")
const DebugShader := preload("res://shaders/cave_sphere_debug.gdshader")

const CELL := 0.5
## The test settings' radii and shifts toward the camera, in cells.
const RADII := [4, 5, 6, 7, 8, 9, 10, 12]
const SHIFTS := [0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 12, 14, 16]
## As PLANE_MARGIN in common.gdshaderinc.
const MARGIN := 0.25

## The faces it opens, and the sphere shown for a test.
var faces: MeshInstance3D
var shown: MeshInstance3D
var on := false
## The middle of the player's body and of the sphere, the radius, in world units.
var body := Vector3.ZERO
var middle := Vector3.ZERO
var radius := 4.0


## Shows or hides the sphere for a player at `at` (their feet, world units), `cells`
## in radius and `shift` cells toward the camera, under `root`; `debug` shows it.
func update(root: Node3D, show: bool, at: Vector3, cells: int, shift: int, debug: bool) -> void:
	if show and faces == null:
		faces = _sphere(root, FaceShader, false)
		shown = _sphere(root, DebugShader, true)
	if faces != null:
		faces.visible = show
		shown.visible = show and debug
	var was := on
	on = show
	if not show:
		if was:
			RenderingServer.global_shader_parameter_set("sphere_view", Vector4.ZERO)
		return
	body = at + Vector3(0.0, CELL, 0.0)
	middle = body + toward_camera() * (shift * CELL)
	radius = cells * CELL
	for node: MeshInstance3D in [faces, shown]:
		var mesh: SphereMesh = node.mesh
		if not is_equal_approx(mesh.radius, radius):
			mesh.radius = radius
			mesh.height = 2.0 * radius
		node.position = middle
	RenderingServer.global_shader_parameter_set("sphere_view", Vector4(1.0, middle.x, middle.y, middle.z))
	RenderingServer.global_shader_parameter_set("sphere_body", Vector4(body.x, body.y, body.z, radius))


func _sphere(root: Node3D, shader: Shader, shadow: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 48
	mesh.rings = 24
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = shader
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shear draws it elsewhere than it stands.
	node.extra_cull_margin = 16.0 * 64.0
	node.visible = false
	root.add_child(node)
	return node


## The way from the world toward the camera, of length 1 (as toward_camera in
## common.gdshaderinc).
static func toward_camera() -> Vector3:
	var u := PixelView.up
	var s := -u * PixelView.slope
	var along := s.dot(u)
	s += u * (along / PixelView.squash - along)
	return Vector3(s.x, 1.0, s.y).normalized()


## Whether the view in a sphere leaves out cell `cell` (by its middle), with the
## sphere `middle`, `radius` and the player's body at `body`, all in world units.
static func hides_at(cell: Vector3i, middle_at: Vector3, r: float, body_at: Vector3) -> bool:
	var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	return p.distance_squared_to(middle_at) < r * r and (p - body_at).dot(toward_camera()) > MARGIN


## Whether picking passes through cell `cell`: the view leaves it out.
func hides(cell: Vector3i) -> bool:
	return on and hides_at(cell, middle, radius, body)
