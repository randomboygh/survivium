extends Control
## On-screen joystick for touch screens. `value` is the stick offset, up to 1 in length.
## It follows its own finger, so the other thumb can press buttons at the same time
## (Godot turns only the first finger into mouse events).

const RADIUS := 56.0

const NONE := -1
const MOUSE := -2

var value := Vector2.ZERO
## The touch index holding the stick, MOUSE for a real mouse, or NONE.
var _finger := NONE
var _touch_ms := -100000


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var finger := NONE
	var pressed := false
	if event is InputEventScreenTouch:
		_touch_ms = Time.get_ticks_msec()
		finger = event.index
		pressed = event.pressed
	elif event is InputEventScreenDrag:
		if event.index == _finger:
			_set_from(event.position)
		accept_event()
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# The first finger also arrives as mouse events, and browsers may add clicks of
		# their own after a tap; its touch events already count.
		accept_event()
		if event.device == InputEvent.DEVICE_ID_EMULATION or Time.get_ticks_msec() - _touch_ms < 1000:
			return
		finger = MOUSE
		pressed = event.pressed
	elif event is InputEventMouseMotion:
		if _finger == MOUSE:
			_set_from(event.position)
		accept_event()
		return
	else:
		return
	accept_event()
	if pressed and _finger == NONE:
		_finger = finger
		_set_from(event.position)
	elif not pressed and finger == _finger:
		_finger = NONE
		value = Vector2.ZERO
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_finger = NONE
		value = Vector2.ZERO


func _set_from(p: Vector2) -> void:
	value = ((p - size * 0.5) / RADIUS).limit_length(1.0)
	queue_redraw()


func _draw() -> void:
	var c := (size * 0.5).floor()
	var knob := (c + value * RADIUS).floor()
	_octagon(c, RADIUS, Color(0.06, 0.04, 0.02, 0.45))
	_octagon(knob, RADIUS * 0.4 + 2.0, Color("#0f0a06"))
	_octagon(knob, RADIUS * 0.4, Color("#c9b896"))


## A pixel-style octagon: a square with its corners cut at 30%.
func _octagon(c: Vector2, r: float, color: Color) -> void:
	var k := roundf(r * 0.4)
	var pts := PackedVector2Array([
		c + Vector2(-r + k, -r), c + Vector2(r - k, -r), c + Vector2(r, -r + k), c + Vector2(r, r - k),
		c + Vector2(r - k, r), c + Vector2(-r + k, r), c + Vector2(-r, r - k), c + Vector2(-r, -r + k)])
	draw_colored_polygon(pts, color)
