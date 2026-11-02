extends Node
## Lets a finger (or the mouse) dragged over a ScrollContainer scroll it, over its cells
## too, not only by its bar. Add it as a child of the ScrollContainer. Cells that pick on
## a tap should pick as the finger lifts (HotbarSlot.on_release) and ask `dragged` first
## (see take_tap): a touch that scrolled picks nothing.

## How far a finger goes before the touch is a drag, in UI pixels.
const DEADZONE := 6.0

## Whether the last touch scrolled the list.
var dragged := false
## The finger (or -2 for the mouse) dragging, -1 for none; where it began, the scroll then.
var _finger := -1
var _from := 0.0
var _scroll_from := 0


func _input(event: InputEvent) -> void:
	var list := get_parent() as ScrollContainer
	if list == null or not list.is_visible_in_tree():
		_finger = -1
		return
	var index := -1
	var pos := Vector2.ZERO
	var press := false
	var release := false
	var drag := false
	if event is InputEventScreenTouch:
		index = event.index
		pos = event.position
		press = event.pressed
		release = not event.pressed
	elif event is InputEventScreenDrag:
		index = event.index
		pos = event.position
		drag = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		index = -2
		pos = event.position
		press = event.pressed
		release = not event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		index = -2
		pos = event.position
		drag = true
	else:
		return
	if press:
		if _finger == -1 and _on(list, pos):
			_finger = index
			_from = _y(list, pos)
			_scroll_from = list.scroll_vertical
			dragged = false
	elif release:
		if index == _finger:
			_finger = -1
	elif drag and index == _finger:
		var y := _y(list, pos)
		if not dragged and absf(y - _from) > DEADZONE:
			dragged = true
		if dragged:
			list.scroll_vertical = _scroll_from - roundi(y - _from)


## Whether a tap on a cell of the list should pick it: false (once) when the touch
## that ended in the tap scrolled the list.
func take_tap() -> bool:
	if dragged:
		dragged = false
		return false
	return true


func _y(list: Control, pos: Vector2) -> float:
	return (list.get_global_transform_with_canvas().affine_inverse() * pos).y


func _on(list: Control, pos: Vector2) -> bool:
	var p: Vector2 = list.get_global_transform_with_canvas().affine_inverse() * pos
	return Rect2(Vector2.ZERO, list.size).has_point(p)
