extends Button
## A button that works under any finger, not only the first one: Godot turns only the
## first touch into mouse clicks, which a plain Button needs, so jumping while the other
## thumb holds the joystick would do nothing. `held` reports pressing and letting go.

signal held(on: bool)

const NONE := -1
const MOUSE := -2

## The touch index holding the button, MOUSE for a real mouse, or NONE.
var _finger := NONE
var _touch_ms := -100000


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	# Toggle mode only shows the pressed look while held; presses are handled below.
	toggle_mode = true
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_ms = Time.get_ticks_msec()
		if event.pressed and _finger == NONE:
			_set_held(event.index)
		elif not event.pressed and event.index == _finger:
			_set_held(NONE)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# The first finger also arrives as a mouse click, and browsers may add clicks of
		# their own after a tap; the touch above already counted it.
		if event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _touch_ms > 1000:
			if event.pressed and _finger == NONE:
				_set_held(MOUSE)
			elif not event.pressed and _finger == MOUSE:
				_set_held(NONE)
	else:
		return
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _finger != NONE:
		_set_held(NONE)


func _set_held(finger: int) -> void:
	_finger = finger
	set_pressed_no_signal(finger != NONE)
	held.emit(finger != NONE)
