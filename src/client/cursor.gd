extends MeshInstance3D
## The cursor frame: one-pixel lines round the top and the south face of each cell a
## tap, a click or the action button would work on (plan/design/ui.md, "рамка-курсор"),
## light when it can be done, red when not (too far, the wrong tool). Controls tells it
## what to frame.

const WorldData := preload("res://src/shared/world_data.gd")
const UiStyle := preload("res://src/client/ui_style.gd")
const CursorShader := preload("res://shaders/cursor.gdshader")

const CELL := WorldData.CELL
## Lines run half a pixel inside the cell's edges, through the middle of its border
## pixels (16 pixels per world unit).
const INSET := 0.5 / 16.0

var _lines := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _shown: Array = []
var _ok := true


func _init() -> void:
	mesh = _lines
	_material.shader = CursorShader
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16.0
	visible = false


## Frames `cells` (none hides the frame); `ok` false draws them red.
func show_cells(cells: Array, ok: bool) -> void:
	if cells == _shown and ok == _ok:
		return
	_shown = cells.duplicate()
	_ok = ok
	_lines.clear_surfaces()
	visible = not cells.is_empty()
	if cells.is_empty():
		return
	_material.set_shader_parameter("color", Color(UiStyle.INK, 0.9) if ok else Color(UiStyle.DANGER, 0.9))
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for c: Vector3i in cells:
		var a := Vector3(c) * CELL + Vector3(INSET, INSET, INSET)
		var b := Vector3(c + Vector3i.ONE) * CELL - Vector3(INSET, INSET, INSET)
		# The top face, then the rest of the south face below its south edge.
		var corners := [Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
		for i in 4:
			_lines.surface_add_vertex(corners[i])
			_lines.surface_add_vertex(corners[(i + 1) % 4])
		for p in [[Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)], [Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z)],
				[Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z)]]:
			_lines.surface_add_vertex(p[0])
			_lines.surface_add_vertex(p[1])
	_lines.surface_end()
