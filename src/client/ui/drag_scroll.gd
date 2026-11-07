extends Node
## Lets a finger (or the mouse) dragged over a ScrollContainer scroll it, over its cells
## too, not only by its bar. Add it as a child of the ScrollContainer. Cells that pick on
## a tap should pick as the finger lifts (HotbarSlot.on_release) and ask `dragged` first
## (see take_tap): a touch that scrolled picks nothing. Buttons in the list need nothing:
## once the finger drags, the press of every button in it is let go (_let_go), so the
## lift presses none. A touch that begins on a slider, a scroll bar or a text field is
## theirs and scrolls nothing.

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
		if _finger == -1 and _on(list, pos) and not _held_by_control(list, pos):
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
			_let_go(list)
		if dragged:
			list.scroll_vertical = _scroll_from - roundi(y - _from)


## Whether a tap on a cell of the list should pick it: false (once) when the touch
## that ended in the tap scrolled the list.
func take_tap() -> bool:
	if dragged:
		dragged = false
		return false
	return true


## Adds a DragScroll to `list` and returns it.
static func attach(list: ScrollContainer) -> Node:
	var drag = load("res://src/client/ui/drag_scroll.gd").new()
	list.add_child(drag)
	return drag


## Lets go the press of every button under `node`, so the finger lifting off one after a
## drag presses nothing: turning a button off and on again drops its press.
static func _let_go(node: Node) -> void:
	for c in node.get_children():
		var b := c as BaseButton
		if b != null and not b.disabled:
			b.disabled = true
			b.disabled = false
		_let_go(c)


## Whether the touch at `pos` begins on a control that drags by itself (a slider, a scroll
## bar, a text field) inside `node`.
static func _held_by_control(node: Node, pos: Vector2) -> bool:
	# Internal children too: the list's own scroll bar.
	for c in node.get_children(true):
		var control := c as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is Slider or control is ScrollBar or control is SpinBox or control is LineEdit or control is TextEdit:
			if control.get_global_rect().has_point(_local_to_canvas(control, pos)):
				return true
		elif _held_by_control(c, pos):
			return true
	return false


## `pos` (a screen position, as events give it) in the canvas `control` is drawn in.
static func _local_to_canvas(control: Control, pos: Vector2) -> Vector2:
	return control.get_global_transform() * (control.get_global_transform_with_canvas().affine_inverse() * pos)


func _y(list: Control, pos: Vector2) -> float:
	return (list.get_global_transform_with_canvas().affine_inverse() * pos).y


func _on(list: Control, pos: Vector2) -> bool:
	var p: Vector2 = list.get_global_transform_with_canvas().affine_inverse() * pos
	return Rect2(Vector2.ZERO, list.size).has_point(p)
