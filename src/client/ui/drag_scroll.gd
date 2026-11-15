extends Node
## Lets a finger (or the mouse) dragged over a ScrollContainer scroll it, over its cells
## too, not only by its bar, the way a phone's lists do: the list flies on after a flick
## and slows down by itself (a touch stops it, and that touch picks nothing), and pulled
## past its top or its end it follows the finger less and less and springs back when let
## go; a flick that reaches an end bounces off it. The mouse wheel glides the same way and
## bounces a little at the ends. A list whose rows all fit neither scrolls nor stretches,
## and its wheel goes to the list around it. Add it as a child of the ScrollContainer
## (Kit.scroll does). Cells that pick on a tap should pick as the finger lifts
## (HotbarSlot.on_release) and ask `dragged` first (see take_tap): a touch that scrolled
## picks nothing. Buttons in the list need nothing: once the finger drags, the press of
## every button in it is let go (_let_go), so the lift presses none. A touch that begins
## on a slider, a scroll bar or a text field is theirs and scrolls nothing.
##
## The stretch is drawn by moving the list's content past where the ScrollContainer puts
## it (after each of its sorts, `sort_children`), in whole pixels; the scroll itself stays
## within its bounds, so the bar and every caller see an ordinary list.

## How far a finger goes before the touch is a drag, in UI pixels.
const DEADZONE := 6.0
## How fast a flick slows down: its speed falls e times in 1 / FRICTION s, so a flick of
## speed v flies v / FRICTION pixels in all.
const FRICTION := 2.6
## The same for a turn of the wheel: one notch glides its distance in about a quarter second.
const WHEEL_FRICTION := 11.0
## A flick slower than this, in UI pixels a second, is no flick.
const MIN_SPEED := 40.0
## The fastest a flick goes.
const MAX_SPEED := 5000.0
## How stiff the spring that brings a stretched list back is (rad/s, critically damped:
## back in about 4 / SPRING s, never past the end).
const SPRING := 13.0
## How hard a pull past the end is (the finger's way x shows as
## (1 - 1 / (x * PULL / h + 1)) * h, h the list's height: about PULL × x at first,
## never past h).
const PULL := 0.5
## The farthest a flick or the wheel stretches the list past an end, as a part of its height.
const BOUNCE := 0.12
## How far back the finger's speed is measured on a lift, and how long a finger held still
## before the lift cancels the flick, in ms.
const SPEED_WINDOW := 80
const STILL := 60

## Whether the last touch scrolled the list (or stopped it flying).
var dragged := false
## For tests: the time in ms instead of the clock's, while not negative.
var now_ms := -1

## The finger (or -2 for the mouse) dragging, -1 for none; where it began, the scroll then
## (unclamped: a touch caught while stretched carries the stretch on).
var _finger := -1
var _from := 0.0
var _scroll_from := 0.0
## The scroll while flying, in fractions of a pixel; its speed (pixels a second, + down)
## and how fast it slows.
var _pos := 0.0
var _speed := 0.0
var _friction := FRICTION
## The stretch past an end (+ past the end, - past the top, in scroll pixels) and how
## fast it changes.
var _over := 0.0
var _over_speed := 0.0
## The stretch drawn now, whole pixels the content is moved by.
var _shown := 0
## Whether the list is flying or springing back (else _process is off).
var _moving := false
## A press that stopped a flying list: its lift picks nothing.
var _caught := false
## The finger's recent places: [ms, unclamped scroll] pairs.
var _track: Array = []
var _list: ScrollContainer = null


func _ready() -> void:
	set_process(false)
	_list = get_parent() as ScrollContainer
	if _list == null:
		return
	_list.sort_children.connect(_on_sorted)
	_list.gui_input.connect(_on_list_input)
	_list.visibility_changed.connect(_on_visibility)


func _input(event: InputEvent) -> void:
	var list := _list
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
			# A list caught flying stops where it is, and the touch is no tap.
			_caught = _moving and absf(_speed) > MIN_SPEED
			_scroll_from = float(list.scroll_vertical) + _unpull(_over)
			_stop()
			_track = [[_now(), _scroll_from]]
			dragged = _caught
	elif release:
		if index == _finger:
			_finger = -1
			if _caught:
				_let_go(list)
			_caught = false
			_lift()
	elif drag and index == _finger:
		var y := _y(list, pos)
		if not dragged and absf(y - _from) > DEADZONE:
			dragged = true
			_let_go(list)
			# The drag starts where the finger is, not with a jump of the deadzone.
			_from = y
		if dragged:
			_drag_to(_scroll_from - (y - _from))


## Whether a tap on a cell of the list should pick it: false (once) when the touch
## that ended in the tap scrolled the list.
func take_tap() -> bool:
	if dragged:
		dragged = false
		return false
	return true


## How far the list is stretched past an end now, in whole pixels (+ past the end).
func stretch() -> int:
	return -_shown


## Whether the list is flying or springing back.
func moving() -> bool:
	return _moving


## Adds a DragScroll to `list` and returns it.
static func attach(list: ScrollContainer) -> Node:
	var drag = load("res://src/client/ui/drag_scroll.gd").new()
	list.add_child(drag)
	return drag


func _process(delta: float) -> void:
	step(minf(delta, 0.1))


## Moves a flying or springing list on by `delta` seconds.
func step(delta: float) -> void:
	var list := _list
	if list == null:
		_stop()
		return
	var end := _end()
	# Moved from outside (a page reset to its top, a row kept in sight): that wins.
	if absf(_speed) > 0.0 and list.scroll_vertical != roundi(_pos):
		_speed = 0.0
	_pos = clampf(_pos, 0.0, end) if _speed == 0.0 else _pos
	# Short steps keep the spring steady on a slow frame.
	var left := delta
	while left > 0.0:
		var dt := minf(left, 1.0 / 120.0)
		left -= dt
		if _speed != 0.0:
			_pos += _speed * dt
			_speed *= exp(-_friction * dt)
			if _pos < 0.0 or _pos > end:
				# Reached an end: the rest of the speed stretches the list, a little.
				var edge := 0.0 if _pos < 0.0 else end
				var most := BOUNCE * list.size.y * SPRING * exp(1.0)
				_over = 0.0
				_over_speed = clampf(_speed, -most, most)
				_pos = edge
				_speed = 0.0
			elif absf(_speed) < MIN_SPEED * 0.25:
				_speed = 0.0
		if _over != 0.0 or _over_speed != 0.0:
			_over_speed += (-SPRING * SPRING * _over - 2.0 * SPRING * _over_speed) * dt
			_over += _over_speed * dt
			if absf(_over) < 0.5 and absf(_over_speed) < 10.0:
				_over = 0.0
				_over_speed = 0.0
	list.scroll_vertical = roundi(_pos)
	_show_over()
	if _speed == 0.0 and _over == 0.0 and _over_speed == 0.0:
		_stop()


## The finger at the unclamped scroll `raw`: within the bounds it scrolls, past them the
## list stretches, harder the farther.
func _drag_to(raw: float) -> void:
	var list := _list
	_track.append([_now(), raw])
	if _track.size() > 12:
		_track.pop_front()
	var end := _end()
	if end <= 0.0:
		# Everything fits: nothing to scroll or to stretch.
		list.scroll_vertical = 0
		_over = 0.0
	elif raw < 0.0:
		list.scroll_vertical = 0
		_over = -_pull(-raw)
	elif raw > end:
		list.scroll_vertical = roundi(end)
		_over = _pull(raw - end)
	else:
		list.scroll_vertical = roundi(raw)
		_over = 0.0
	_pos = float(list.scroll_vertical)
	_show_over()


## The finger lifted: a list stretched springs back, one flicked flies on.
func _lift() -> void:
	if not dragged or _end() <= 0.0:
		_track.clear()
		if _over != 0.0:
			_go()
		return
	var now := _now()
	var speed := 0.0
	if _track.size() >= 2 and now - int(_track[-1][0]) <= STILL:
		var last: Array = _track[-1]
		var first: Array = last
		for t: Array in _track:
			if int(last[0]) - int(t[0]) <= SPEED_WINDOW:
				first = t
				break
		var ms := int(last[0]) - int(first[0])
		if ms > 0:
			speed = (float(last[1]) - float(first[1])) * 1000.0 / ms
	_track.clear()
	if _over == 0.0 and absf(speed) >= MIN_SPEED:
		_fly(clampf(speed, -MAX_SPEED, MAX_SPEED), FRICTION)
	elif _over != 0.0:
		_go()


## Starts the list flying at `speed` (+ down) slowing by `friction`.
func _fly(speed: float, friction: float) -> void:
	_pos = float(_list.scroll_vertical)
	_speed = speed
	_friction = friction
	_go()


func _go() -> void:
	_moving = true
	set_process(true)


func _stop() -> void:
	_moving = false
	_speed = 0.0
	_over_speed = 0.0
	set_process(false)
	if _over != 0.0 and _finger == -1:
		_over = 0.0
		_show_over()


## The wheel over the list: it glides (and a little past an end, back); a list whose rows
## fit leaves the wheel to the list around it. The list's own touch drag is turned off
## (this one does it): a press that reaches the list itself goes no further.
func _on_list_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null:
		return
	if b.button_index == MOUSE_BUTTON_LEFT:
		if DisplayServer.is_touchscreen_available():
			_list.accept_event()
		return
	if not b.pressed or (b.button_index != MOUSE_BUTTON_WHEEL_UP and b.button_index != MOUSE_BUTTON_WHEEL_DOWN):
		return
	if _end() <= 0.0 or b.shift_pressed or _finger != -1:
		return
	_list.accept_event()
	wheel(1.0 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0, b.factor)


## A turn of the wheel by `notches` (+ down) of `factor` each: the list glides an eighth
## of its height a notch (as the engine's wheel steps), adding to a glide the same way.
func wheel(notches: float, factor := 1.0) -> void:
	var bar := _list.get_v_scroll_bar()
	var way := bar.page / 8.0 * (factor if factor > 0.0 else 1.0) * notches
	var speed := way * WHEEL_FRICTION
	if _speed != 0.0 and signf(_speed) == signf(speed) and _friction == WHEEL_FRICTION:
		_speed = clampf(_speed + speed, -MAX_SPEED, MAX_SPEED)
	else:
		_fly(speed, WHEEL_FRICTION)


func _on_sorted() -> void:
	# The container has put the content back at its scroll: move it by the stretch again.
	_shown = 0
	_show_over()


func _on_visibility() -> void:
	if not _list.is_visible_in_tree():
		_finger = -1
		_over = 0.0
		_stop()
		_show_over()


## Moves the content by the stretch, in whole pixels.
func _show_over() -> void:
	var content := _content()
	var want := -roundi(_over)
	if content == null or want == _shown:
		return
	content.position.y += want - _shown
	_shown = want


## The list's content: its first child that is a Control.
func _content() -> Control:
	if _list == null:
		return null
	for c in _list.get_children():
		if c is Control and not (c as Control).top_level:
			return c
	return null


## How far the list scrolls (0: everything fits).
func _end() -> float:
	if _list == null or _list.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return 0.0
	var bar := _list.get_v_scroll_bar()
	return maxf(bar.max_value - bar.page, 0.0)


## The stretch shown for a pull of `x` pixels past an end, and back.
func _pull(x: float) -> float:
	var h := maxf(_list.size.y, 1.0)
	return (1.0 - 1.0 / (x * PULL / h + 1.0)) * h


func _unpull(over: float) -> float:
	var h := maxf(_list.size.y, 1.0)
	var y := clampf(absf(over) / h, 0.0, 0.95)
	return signf(over) * (1.0 / (1.0 - y) - 1.0) * h / PULL


func _now() -> int:
	return now_ms if now_ms >= 0 else Time.get_ticks_msec()


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
