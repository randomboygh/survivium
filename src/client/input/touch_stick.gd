extends Control
## On-screen joystick for touch screens. `value` is the stick offset, up to 1 in length.
## It follows its own finger, so the other thumb can press buttons at the same time
## (Godot turns only the first finger into mouse events).

const UiStyle := preload("res://src/client/ui/ui_style.gd")

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
	var held := _finger != NONE
	# The base: a dark rim (amber while held), a wooden ring and a sunken well, with
	# notches pointing the four ways.
	_octagon(c, RADIUS, Color(UiStyle.EDGE, 0.6))
	_octagon(c, RADIUS - 2.0, Color(UiStyle.ACCENT if held else UiStyle.HIGHLIGHT, 0.5))
	_octagon(c, RADIUS - 4.0, Color(UiStyle.BUTTON, 0.55))
	_octagon(c, RADIUS * 0.66, Color(UiStyle.EDGE, 0.35))
	_octagon(c, RADIUS * 0.66 - 2.0, Color(UiStyle.WELL, 0.45))
	var notch := Color(UiStyle.MUTED, 0.85 if held else 0.6)
	var r := roundf(RADIUS * 0.83)
	for d: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_notch(c + d * r, d, notch)
	# The knob: a shadow under it, an outline, a darker lower part and a light top,
	# a glint and three grooves to hold.
	var k := RADIUS * 0.4
	_octagon(knob + Vector2(0, 4), k + 2.0, Color(0, 0, 0, 0.35))
	_octagon(knob, k + 2.0, UiStyle.EDGE)
	_octagon(knob, k, Color("#8f7d5c"))
	_octagon(knob + Vector2(0, -2), k - 2.0, Color("#d8c7a2") if held else UiStyle.MUTED)
	draw_rect(Rect2(knob + Vector2(-k * 0.5, -k * 0.75), Vector2(4, 2)), UiStyle.INK)
	draw_rect(Rect2(knob + Vector2(-k * 0.5 - 2, -k * 0.75 + 2), Vector2(2, 2)), UiStyle.INK)
	for i in 3:
		draw_rect(Rect2(knob + Vector2(-6, -5 + i * 4), Vector2(12, 2)), Color("#8f7d5c"))


## A small arrow of pixels at `p` pointing `d`.
func _notch(p: Vector2, d: Vector2, color: Color) -> void:
	var side := Vector2(-d.y, d.x)
	for i in 3:
		var w := 6 - 2 * i
		var at := p + d * (i * 2) - side * (w * 0.5)
		var rect := Rect2(at, side * w + d * 2).abs()
		draw_rect(rect, color)


## A pixel-style octagon: a square with its corners cut at 30%.
func _octagon(c: Vector2, r: float, color: Color) -> void:
	r = roundf(r)
	var k := roundf(r * 0.4)
	var pts := PackedVector2Array([
		c + Vector2(-r + k, -r), c + Vector2(r - k, -r), c + Vector2(r, -r + k), c + Vector2(r, r - k),
		c + Vector2(r - k, r), c + Vector2(-r + k, r), c + Vector2(-r, r - k), c + Vector2(-r, -r + k)])
	draw_colored_polygon(pts, color)
