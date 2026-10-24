extends MeshInstance3D
## The cursor frame: one-pixel lines round one square of each cell a tap, a click or
## the action button would work on (plan/design/ui.md, "рамка-курсор"), light when it
## can be done, red when not (too far, the wrong tool). The square is the face that
## shows: the top of a solid cell open above, else its side toward the camera; for an
## open cell (a bush, a block to put) the floor it stands on. Controls tells it what to
## frame.

const WorldData := preload("res://src/shared/world/world_data.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const CursorShader := preload("res://shaders/cursor.gdshader")

const CELL := WorldData.CELL
## Lines run half a pixel inside the cell's edges, through the middle of its border
## pixels (16 pixels per world unit).
const INSET := 0.5 / 16.0
## The faces a frame goes round.
enum { TOP, SIDE, FLOOR }

## The WorldData, to see which face of a cell shows (main sets it).
var world

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
	var faces := []
	for c: Vector3i in cells:
		var side := _side()
		faces.append([c, _face(c, side), side])
	if faces == _shown and ok == _ok:
		return
	_shown = faces
	_ok = ok
	_lines.clear_surfaces()
	visible = not cells.is_empty()
	if cells.is_empty():
		return
	_material.set_shader_parameter("color", Color(UiStyle.INK, 0.9) if ok else Color(UiStyle.DANGER, 0.9))
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for f: Array in faces:
		var c: Vector3i = f[0]
		var a := Vector3(c) * CELL + Vector3(INSET, INSET, INSET)
		var b := Vector3(c + Vector3i.ONE) * CELL - Vector3(INSET, INSET, INSET)
		var corners: Array
		match f[1]:
			TOP:
				corners = [Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
			SIDE:
				# The side's square: x or z at the side's edge of the cell.
				var s: Vector2i = f[2]
				var lo := Vector3(a.x if s.x <= 0 else b.x, 0.0, a.z if s.y <= 0 else b.z)
				var hi := Vector3(b.x if s.x >= 0 else a.x, 0.0, b.z if s.y >= 0 else a.z)
				corners = [Vector3(lo.x, b.y, lo.z), Vector3(hi.x, b.y, hi.z), Vector3(hi.x, a.y, hi.z), Vector3(lo.x, a.y, lo.z)]
			_:
				corners = [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]
		for i in 4:
			_lines.surface_add_vertex(corners[i])
			_lines.surface_add_vertex(corners[(i + 1) % 4])
	_lines.surface_end()


## Which face of `c` the frame goes round: one square on the screen, the one that shows.
func _face(c: Vector3i, side: Vector2i) -> int:
	if world == null:
		return TOP
	if not world.is_solid(c.x, c.y, c.z):
		return FLOOR
	if world.is_solid(c.x, c.y + 1, c.z) and not world.is_solid(c.x + side.x, c.y, c.z + side.y):
		return SIDE
	return TOP


## The side of a cell that faces the camera most (south in the default view; of two
## as near on a diagonal, the north or south one).
static func _side() -> Vector2i:
	var toward := -PixelView.up
	if absf(toward.y) >= absf(toward.x) - 0.01:
		return Vector2i(0, 1 if toward.y > 0.0 else -1)
	return Vector2i(1 if toward.x > 0.0 else -1, 0)
