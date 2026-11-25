extends Control
## The thin line from the finger up to the thing the build mode holds over it on a touch
## screen (BuildMode.FINGER_LIFT: the thing goes where the line ends, a finger's breadth
## over the touch, so the finger does not hide it; the user's pick, 2026-11-26). Drawn in
## the interface's pixels as pixel art: a light core one pixel wide in a dark rim, a small
## square where it ends. A child of the HUD (hud.gd), under the rest of the interface.

## The line's core and its rim.
const CORE := Color(1.0, 0.97, 0.88, 0.9)
const RIM := Color(0.08, 0.06, 0.05, 0.55)

## The ends in the HUD's pixels (the finger's, the thing's), shown or not.
var _from := Vector2.ZERO
var _to := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the line from the finger at screen point `finger` up to screen point `aim`.
func show_line(finger: Vector2, aim: Vector2) -> void:
	var hud := get_parent() as Control
	var k := hud.scale.x if hud != null and hud.scale.x > 0.0 else 1.0
	var at := hud.position if hud != null else Vector2.ZERO
	var from := ((finger - at) / k).floor()
	var to := ((aim - at) / k).floor()
	if visible and from == _from and to == _to:
		return
	_from = from
	_to = to
	visible = true
	queue_redraw()


func hide_line() -> void:
	if visible:
		visible = false


func _draw() -> void:
	# Straight up from the finger: a column of pixels, the rim one pixel round the core.
	var top := minf(_from.y, _to.y)
	var bottom := maxf(_from.y, _to.y)
	var x := _to.x
	draw_rect(Rect2(x - 1.0, top - 1.0, 3.0, bottom - top + 1.0), RIM)
	draw_rect(Rect2(x, top, 1.0, bottom - top), CORE)
	# The end the thing is aimed at: a dot three pixels across in its rim.
	draw_rect(Rect2(x - 2.0, _to.y - 2.0, 5.0, 5.0), RIM)
	draw_rect(Rect2(x - 1.0, _to.y - 1.0, 3.0, 3.0), CORE)
