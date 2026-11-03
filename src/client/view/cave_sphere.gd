extends RefCounted
## The view in a sphere (setting «Вид в пещере» → «сфера»): under a roof, in a ravine or
## behind a hill, a sphere round the player is opened, round on the screen, together
## with all that stands between it and the camera. Inside it: the floor below the feet
## stays whole, the walls behind the player up to their head stay, the walls in front
## and all over the head go, and only the cave the player stands in opens (ReachMap):
## another cave behind solid rock stays rock. Where the far half of the sphere passes
## through rock, its section is drawn (cave_sphere.gdshader on the inside of a sphere
## mesh round the player in the drawn, sheared space). Outside it the world is as it
## is. The shaders hide by sphere_hides in common.gdshaderinc (globals sphere_view =
## on and the middle of the body, sphere_cell = the feet cell and the radius in world
## units, reach_map); this mirrors it for picking cells.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const SphereShader := preload("res://shaders/cave_sphere.gdshader")

const CELL := 0.5
## The test setting's radii, in cells.
const RADII := [4, 5, 6, 7, 8, 9, 10, 12]
## As PLANE_MARGIN in common.gdshaderinc.
const MARGIN := 0.25

var node: MeshInstance3D
var on := false
var feet := Vector3i.ZERO
var radius := 8


## Shows or hides the sphere round the player with feet in cell `at`, `cells` in
## radius, under `root`.
func update(root: Node3D, show: bool, at: Vector3i, cells: int) -> void:
	if show and node == null:
		node = MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 48
		mesh.rings = 24
		node.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = SphereShader
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	if node != null:
		node.visible = show
	if show:
		var r := cells * CELL
		var mesh: SphereMesh = node.mesh
		if not is_equal_approx(mesh.radius, r):
			mesh.radius = r
			mesh.height = 2.0 * r
		# The middle of the body, where it is drawn: the sphere is round on the screen.
		node.position = PixelView.shear(middle(at))
	if show != on or at != feet or cells != radius:
		on = show
		feet = at
		radius = cells
		var m := middle(at)
		RenderingServer.global_shader_parameter_set("sphere_view", Vector4(1.0 if show else 0.0, m.x, m.y, m.z))
		RenderingServer.global_shader_parameter_set("sphere_cell", Vector4(at.x, at.y, at.z, cells * CELL))


## The middle of the body of a player with feet in cell `at`, in world units.
static func middle(at: Vector3i) -> Vector3:
	return Vector3(at.x + 0.5, at.y + 1.0, at.z + 0.5) * CELL


## Whether picking passes through solid cell `cell` (as sphere_hides for a face,
## leaving out the reach: a cell the finger meets is not of another cave). `body` is
## the middle of the player's body.
func hides(cell: Vector3i, body: Vector3) -> bool:
	if not on:
		return false
	var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * CELL
	var s := PixelView.shear(p) - PixelView.shear(middle(feet))
	var big := radius * CELL * radius * CELL
	var r2 := s.x * s.x + s.z * s.z
	if r2 >= big or s.y <= -sqrt(big - r2):
		return false
	if cell.y < feet.y:
		return false
	var toward := PixelView.slope / PixelView.squash
	var up := PixelView.up
	var before := p.y - (p.x * up.x + p.z * up.y) * toward - (body.y - (body.x * up.x + body.z * up.y) * toward)
	return not (before <= MARGIN and cell.y <= feet.y + 1)
