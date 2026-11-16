extends Control
## One level of a voxel sheet (VoxelSheet) as a grid to paint on with a finger or the
## mouse (stage 2 item 3, step 5): the level's voxels, the level under it faint (to build
## on), lines between the cells and a stronger one every 8 (a cell of the world is 16
## voxels, a placed thing's squares are 8). A press and a drag use the tool chosen.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const VoxelSheet := preload("res://src/client/ui/editor/voxel_sheet.gd")

enum Tool { PAINT, ERASE, FILL, TAKE }

## A level's voxels were changed (a stroke's first change was remembered for «Undo»).
signal painted
## The colour under the finger was taken (the TAKE tool): its colour, whether a leaf.
signal taken(color: Color, is_leaf: bool)

const UNDER := Color(1, 1, 1, 0.16)
const LINE := Color(0, 0, 0, 0.35)
const LINE_8 := Color(0, 0, 0, 0.7)
const CHECK_A := Color(0.17, 0.17, 0.19)
const CHECK_B := Color(0.21, 0.21, 0.23)

var sheet: VoxelSheet
## The level shown.
var level := 0
var tool := Tool.PAINT
## The colour painted and whether it makes leaves.
var color := Color(0.55, 0.4, 0.24)
var leafy := false
var _stroke := false
var _last := Vector2i(-1, -1)
## The sheet as it was when the stroke began, and whether the stroke changed it yet.
var _before: Image
var _changed := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## The side of a voxel's square, in UI px.
func cell() -> float:
	return floorf(minf(size.x, size.y) / maxi(sheet.side, 1)) if sheet != null else 1.0


func _origin() -> Vector2:
	var c := cell()
	return ((size - Vector2.ONE * c * sheet.side) * 0.5).floor()


func _draw() -> void:
	if sheet == null:
		return
	var c := cell()
	var o := _origin()
	var n := sheet.side
	for z in n:
		for x in n:
			var r := Rect2(o + Vector2(x, z) * c, Vector2(c, c))
			draw_rect(r, CHECK_A if (x + z) & 1 == 0 else CHECK_B)
			var v := sheet.at(x, level, z)
			if v.a > 0.0:
				draw_rect(r, Color(v, 1.0))
				if v.a8 <= VoxelSheet.VoxelModel.FOLIAGE_ALPHA and c >= 6:
					# A leaf: a light dot in its corner.
					draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.55))
			elif level > 0 and sheet.at(x, level - 1, z).a > 0.0:
				var u := sheet.at(x, level - 1, z)
				draw_rect(r, Color(Color(u, 1.0).lerp(CHECK_A, 0.6), 1.0))
				draw_rect(r.grow(-maxf(1.0, floorf(c / 3.0))), UNDER)
	for i in n + 1:
		var line := LINE_8 if i % 8 == 0 or i == n else LINE
		draw_line(o + Vector2(i * c, 0), o + Vector2(i * c, n * c), line)
		draw_line(o + Vector2(0, i * c), o + Vector2(n * c, i * c), line)


## The voxel under point `p` of the grid (-1, -1 outside).
func voxel_at(p: Vector2) -> Vector2i:
	var c := cell()
	var q := ((p - _origin()) / c).floor()
	var v := Vector2i(int(q.x), int(q.y))
	return v if v.x >= 0 and v.y >= 0 and v.x < sheet.side and v.y < sheet.side else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if sheet == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_stroke = true
			_last = Vector2i(-1, -1)
			use(voxel_at(event.position), true)
		else:
			_stroke = false
	elif event is InputEventMouseMotion and _stroke:
		accept_event()
		use(voxel_at(event.position), false)


## Uses the tool on voxel `v` of the level shown; `first`: a stroke's first touch. A
## stroke is remembered once for «Undo», before its first change.
func use(v: Vector2i, first: bool) -> void:
	if first:
		_before = sheet.img.duplicate()
		_changed = false
	if v.x < 0 or v == _last:
		return
	_last = v
	var done := false
	match tool:
		Tool.TAKE:
			var c := sheet.at(v.x, level, v.y)
			if c.a > 0.0:
				taken.emit(Color(c, 1.0), sheet.leaf(v.x, level, v.y))
			return
		Tool.FILL:
			done = first and sheet.fill(v.x, level, v.y, _ink())
		_:
			done = sheet.put(v.x, level, v.y, _ink())
	if not done:
		return
	if not _changed and _before != null:
		_changed = true
		sheet.history.append(_before)
		if sheet.history.size() > VoxelSheet.MOST_UNDO:
			sheet.history.pop_front()
	queue_redraw()
	painted.emit()


func _ink() -> Color:
	return Color(0, 0, 0, 0) if tool == Tool.ERASE else VoxelSheet.ink(color, leafy)
