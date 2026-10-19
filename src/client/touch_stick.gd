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
	var c := size * 0.5
	var knob := c + value * RADIUS
	draw_circle(c, RADIUS, Color(0, 0, 0, 0.25))
	draw_arc(c, RADIUS - 1.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0, true)
	draw_circle(knob, RADIUS * 0.4, Color(1, 1, 1, 0.55))
	draw_arc(knob, RADIUS * 0.4, 0.0, TAU, 32, Color(0, 0, 0, 0.4), 2.0, true)
