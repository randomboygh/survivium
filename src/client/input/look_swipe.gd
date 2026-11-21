extends RefCounted
## The look of the first-person view (CameraRig.first_person, the test setting «Вид от
## первого лица»): a finger, or the mouse's left button, pressed on the world and moved
## more than SLOP of the screen's short side turns the view as far as it goes
## (CameraRig.look_by); let go before it moved, it is a tap (Controls.tap) where it was
## pressed; held still for HOLD seconds, a tap that goes on working while it is held (the
## hands dig on, as a held tap does in the view from above). The joystick and the buttons
## take their own fingers before this sees them. `game` is the Main node.

## How far a finger moves before it turns the view, a share of the screen's short side.
const SLOP := 0.02
## How long a finger held still waits before it works as a held tap, in seconds.
const HOLD := 0.35
## How far a swipe turns the view: radians for a swipe across the screen's short side.
const SPEED := 2.4
const NONE := -1
const MOUSE := -2

var game
## The finger turning the view or waiting to tap (its index, MOUSE, or NONE), where it
## was pressed, when (msec), and whether it turns the view or tapped already.
var _finger := NONE
var _from := Vector2.ZERO
var _at := 0
var _swiping := false
var _tapped := false


func _init(g) -> void:
	game = g


## Takes the presses and moves of the fingers and the mouse's left button on the world;
## true when the event is its own (Controls leaves it).
func input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == NONE:
			if game.hud.covers(event.position):
				return false
			_press(event.index, event.position)
			return true
		if not event.pressed and event.index == _finger:
			_release(event.position)
			return true
		return false
	if event is InputEventScreenDrag:
		if event.index != _finger:
			return false
		_move(event.position, event.relative)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# The first finger arrives as the mouse too: its touches already count.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return true
		if event.pressed and _finger == NONE:
			if game.hud.covers(event.position):
				return false
			_press(MOUSE, event.position)
			return true
		if not event.pressed and _finger == MOUSE:
			_release(event.position)
			return true
		return false
	if event is InputEventMouseMotion and _finger == MOUSE and event.device != InputEvent.DEVICE_ID_EMULATION:
		_move(event.position, event.relative)
		# The stroke of a held tap follows the pointer (Controls.unhandled_input).
		return not _tapped
	return false


## A finger held still for HOLD seconds starts a held tap; called every frame.
func update() -> void:
	if _finger == NONE or _swiping or _tapped:
		return
	if Time.get_ticks_msec() - _at >= HOLD * 1000.0:
		_tapped = true
		_tap(_from)


func _press(finger: int, pos: Vector2) -> void:
	_finger = finger
	_from = pos
	_at = Time.get_ticks_msec()
	_swiping = false
	_tapped = false


func _move(pos: Vector2, relative: Vector2) -> void:
	var side := _short_side()
	if not _swiping and not _tapped and pos.distance_to(_from) > SLOP * side:
		_swiping = true
		# The way from the press counts too, so the view does not lag the finger.
		relative = pos - _from
	if _swiping:
		game.view.look_by(relative / side * SPEED)


func _release(pos: Vector2) -> void:
	if not _swiping and not _tapped:
		_tap(pos)
	_finger = NONE


func _tap(pos: Vector2) -> void:
	var c = game.controls
	c.tap(c.active if c.touch else 0, pos, MOUSE_BUTTON_LEFT)


func _short_side() -> float:
	var s: Vector2 = game.get_viewport().get_visible_rect().size
	return maxf(1.0, minf(s.x, s.y))
