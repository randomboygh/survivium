extends Control
## On-screen joystick for touch screens. `value` is the stick offset, up to 1 in length.

const RADIUS := 56.0

var value := Vector2.ZERO
var _pressed := false


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		value = Vector2.ZERO
		if _pressed:
			_set_from(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		_set_from(event.position)
		accept_event()
	queue_redraw()


func _set_from(p: Vector2) -> void:
	value = ((p - size * 0.5) / RADIUS).limit_length(1.0)


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
