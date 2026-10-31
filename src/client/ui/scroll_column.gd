extends VBoxContainer
## A column of square buttons (the kinds of items, the stations near) that shows at most
## SHOWN of them: past that, arrows above and below and a finger dragged along it move
## the column a button at a time, as the hotbar's slots do. Its buttons are given with
## set_items and are children of `box`.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const TabRow := preload("res://src/client/ui/tab_row.gd")

## How many buttons show at once.
const SHOWN := 6
## The height of an arrow, in UI pixels.
const ARROW := 12

## The buttons' column between the arrows.
var box: VBoxContainer
var _up: Button
var _down: Button
## The first button shown.
var _first := 0
## The finger dragging the column (-1 for none) and where it was.
var _swipe := -1
var _swipe_y := 0.0
## Whether the last touch on the column dragged it: the tap it began with picks nothing
## (the owner's buttons ask, see IconTabs.pick).
var swiped := false


func _init(side: int) -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size.x = side
	_up = TabRow.icon_button(UiStyle.icon("prev_up"), "Выше", func() -> void: scroll(-1))
	_up.custom_minimum_size = Vector2(side, ARROW)
	add_child(_up)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_down = TabRow.icon_button(UiStyle.icon("next_down"), "Ниже", func() -> void: scroll(1))
	_down.custom_minimum_size = Vector2(side, ARROW)
	add_child(_down)
	_show()


## The buttons in the column.
func items() -> Array:
	return box.get_children()


## Puts button `c` at the end of the column.
func add_item(c: Control) -> void:
	box.add_child(c)
	_show()


## Takes every button out (freed).
func clear_items() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	_first = 0
	_show()


## Moves the buttons shown `by` along; they stop at the ends.
func scroll(by: int) -> void:
	_first = clampi(_first + by, 0, maxi(0, _count() - SHOWN))
	_show()


## Moves the column so button `i` (of those that show) is in view.
func reveal(i: int) -> void:
	if i < _first:
		_first = i
	elif i >= _first + SHOWN:
		_first = i - SHOWN + 1
	_show()


## Shows the buttons from the first in view, and the arrows when not all fit. Call after
## changing which buttons are visible.
func refresh() -> void:
	_first = clampi(_first, 0, maxi(0, _count() - SHOWN))
	_show()


## The buttons that would show without the paging (those not hidden by their owner).
func _wanted() -> Array:
	return box.get_children().filter(func(c: Control) -> bool: return not c.has_meta("hidden"))


func _count() -> int:
	return _wanted().size()


## Hides button `c` from the column for its owner's reasons (not the paging's).
func set_shown(c: Control, on: bool) -> void:
	if on:
		c.remove_meta("hidden")
	else:
		c.set_meta("hidden", true)


func _show() -> void:
	var wanted := _wanted()
	var paged := wanted.size() > SHOWN
	_first = clampi(_first, 0, maxi(0, wanted.size() - SHOWN))
	for c in box.get_children():
		var i := wanted.find(c)
		c.visible = i >= 0 and (not paged or (i >= _first and i < _first + SHOWN))
	_up.visible = paged
	_down.visible = paged
	_up.disabled = _first <= 0
	_down.disabled = _first >= wanted.size() - SHOWN


## A finger dragged along the column moves it a button for each button it passes.
func _input(event: InputEvent) -> void:
	if not _up.visible or not is_visible_in_tree():
		_swipe = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _swipe < 0 and _on_box(event.position):
			_swipe = event.index
			_swipe_y = _box_y(event.position)
			swiped = false
		elif not event.pressed and event.index == _swipe:
			_swipe = -1
	elif event is InputEventScreenDrag and event.index == _swipe:
		var y := _box_y(event.position)
		if not swiped and absf(y - _swipe_y) > 6.0:
			swiped = true
		if swiped:
			var step: float = custom_minimum_size.x
			while _swipe_y - y >= step:
				scroll(1)
				_swipe_y -= step
			while y - _swipe_y >= step:
				scroll(-1)
				_swipe_y += step


func _box_point(pos: Vector2) -> Vector2:
	return box.get_global_transform_with_canvas().affine_inverse() * pos


func _box_y(pos: Vector2) -> float:
	return _box_point(pos).y


func _on_box(pos: Vector2) -> bool:
	var p := _box_point(pos)
	return p.x >= 0.0 and p.x <= box.size.x and p.y >= 0.0 and p.y <= box.size.y
