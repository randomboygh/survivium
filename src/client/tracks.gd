extends Node3D
## Footprints left behind by the player and the animals: a ring of flat quads over the
## ground, drawn with track.gdshader, which darkens the ground under each print and
## fades it out with age. Prints stay longer in snow than on soil; stone, planks and
## water take none.

const PixelView := preload("res://src/client/pixel_view.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const TrackShader := preload("res://shaders/track.gdshader")

## Prints kept at once; the oldest is reused.
const SIZE := 2048
## Prints farther than this from `focus` are not kept: nobody sees them, and the
## animals all over the world would cycle the ring in seconds.
const REACH := 24.0
## Quad size in world units: four texels.
const QUAD := 0.25
const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## The clock prints are stamped with wraps here, so it keeps its precision in the
## half floats the web renderer stores instance data in.
const WRAP := 2048.0

var world
## Where the player is, kept up to date by the game.
var focus := Vector3.ZERO
## Snow cover and wetness of the ground, kept up to date by the game.
var snow := 0.0
var wet := 0.0
var multimesh: MultiMesh
var material: ShaderMaterial
var next := 0
## Seconds since the start, wrapping at WRAP; the shader gets it every frame.
var clock := 0.0


func _ready() -> void:
	var h := QUAD * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = SIZE
	for i in SIZE:
		# Not yet made: a print from the far past is never drawn.
		multimesh.set_instance_custom_data(i, Color(-1e4, 1.0, 0.0, 0.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	material = ShaderMaterial.new()
	material.shader = TrackShader
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 24.0
	add_child(node)


func _process(delta: float) -> void:
	clock = fmod(clock + delta, WRAP)
	material.set_shader_parameter("now", clock)


## Leaves a print of a foot at the world point `feet` (the middle of the body on the
## ground), stepping toward `heading` (x east, y south); `left` picks the foot and its
## side, `boot` the shape, `scale` the size against a person's print.
func leave(feet: Vector3, heading: Vector2, left: bool, boot: bool, scale: float) -> void:
	if absf(feet.x - focus.x) > REACH or absf(feet.z - focus.z) > REACH:
		return
	var cell := Vector3i(floori(feet.x / CELL), floori(feet.y / CELL + 0.01) - 1, floori(feet.z / CELL))
	var ground: int = world.get_cell(cell.x, cell.y, cell.z)
	var tint: Color
	var life: float
	if snow > 0.6 and ground != Mat.WATER and world.roof_level(cell.x, cell.z) == cell.y:
		tint = Color(0.62, 0.68, 0.84)
		life = 120.0
	elif ground == Mat.GRASS:
		tint = Color(0.72, 0.68, 0.58) if wet < 0.5 else Color(0.6, 0.56, 0.5)
		life = 20.0 if wet < 0.5 else 40.0
	elif ground == Mat.DIRT or ground == Mat.CLAY or ground == Mat.SAND:
		tint = Color(0.7, 0.65, 0.58) if wet < 0.5 else Color(0.58, 0.53, 0.48)
		life = 45.0
	else:
		return
	if heading.length_squared() < 0.0001:
		heading = Vector2(0.0, 1.0)
	# Eight headings, so the print's texels stay on the pixel grid.
	var angle := roundf(atan2(heading.x, heading.y) / (PI / 4.0)) * (PI / 4.0)
	var dir := Vector2(sin(angle), cos(angle))
	var side := Vector2(dir.y, -dir.x) * (1.5 * PX * scale) * (-1.0 if left else 1.0)
	var p := PixelView.snap(feet + Vector3(side.x, 0.0, side.y))
	# A texel above the ground, and as much south so it stays in place on screen.
	p += Vector3(0.0, 1.5 * PX, 1.5 * PX)
	var basis := Basis(Vector3.UP, angle).scaled(Vector3(scale, 1.0, scale))
	multimesh.set_instance_transform(next, Transform3D(basis, p))
	multimesh.set_instance_color(next, tint)
	multimesh.set_instance_custom_data(next, Color(clock, life, 1.0 if boot else 0.0, 1.0 if left else 0.0))
	next = (next + 1) % SIZE
