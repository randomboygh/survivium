extends HBoxContainer
## A strip of the UI kit (kit.gd): a row of big cells between two arrows, as the hotbar,
## the build mode's and the farming mode's palettes have it. The owner puts its cells
## (HotbarSlot) into `cells` and says how many things there are and how many cells show
## (`set_counts`); the strip keeps the first one shown (`first`). When not all fit, the
## arrows move them a cell at a time and stop at the ends, and a finger dragged along
## the cells moves them a cell for each cell it passes (the tap it began with picks
## nothing). `scrolled` tells the owner to show its cells anew.

const Kit := preload("res://src/client/ui/kit/kit.gd")

## A cell's side, the gap between cells and the arrows' width, in UI pixels.
const SLOT := 40
const GAP := 4
const ARROW := 28

## `first` changed: the owner shows its cells anew.
signal scrolled

var prev: Button
var next: Button
## The owner's cells go here.
var cells: HBoxContainer
## How many things there are, how many cells show, the first thing shown.
var total := 0
var shown := 1
var first := 0
## The finger dragging the cells along (-1 none), its x in the strip where the cells
## last moved, and whether it moved far enough to be a drag, not a tap.
var _swipe := -1
var _swipe_x := 0.0
var _swiped := false


func _init(prev_tip := "[previous]", next_tip := "[next]") -> void:
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev = _arrow("prev", prev_tip, func() -> void: scroll(-1))
	cells = HBoxContainer.new()
	cells.add_theme_constant_override("separation", GAP)
	cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cells)
	next = _arrow("next", next_tip, func() -> void: scroll(1))


## The width of the strip with `count` cells and its arrows.
static func width_for(count: int, arrows := true) -> float:
	return count * (SLOT + GAP) - GAP + (2 * (ARROW + GAP) if arrows else 0)


## How many cells fit in `width` (between the arrows when not all `count` fit), from one
## to `most`.
static func fitting(width: float, count: int, most: int) -> int:
	if floori(width / (SLOT + GAP)) >= count:
		return mini(count, most)
	return clampi(floori((width - 2 * (ARROW + GAP)) / (SLOT + GAP)), 1, mini(count, most))


## There are `count` things and `cells_shown` cells: keeps the first shown in range and
## shows the arrows anew (without `scrolled`).
func set_counts(count: int, cells_shown: int) -> void:
	total = count
	shown = maxi(cells_shown, 1)
	first = clampi(first, 0, maxi(0, total - shown))
	_show_arrows()


## Whether thing `i` is in a cell now.
func is_shown(i: int) -> bool:
	return i >= first and i < first + shown


## Moves the shown things `by` along; none past the ends.
func scroll(by: int) -> void:
	var to := clampi(first + by, 0, maxi(0, total - shown))
	if to == first:
		return
	first = to
	_show_arrows()
	scrolled.emit()


## Whether the things are more than the cells (the arrows show).
func scrolls() -> bool:
	return total > shown


func _show_arrows() -> void:
	prev.visible = scrolls()
	next.visible = prev.visible
	prev.disabled = first <= 0
	next.disabled = first >= total - shown


func _arrow(icon: String, tip: String, action: Callable) -> Button:
	var b := Kit.framed_button(icon, tip, action, Vector2(ARROW, SLOT))
	add_child(b)
	return b


func _input(event: InputEvent) -> void:
	if not prev.visible or not is_visible_in_tree():
		_swipe = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed and _swipe < 0 and _on_strip(event.position):
			_swipe = event.index
			_swipe_x = _point(event.position).x
			_swiped = false
		elif not event.pressed and event.index == _swipe:
			_swipe = -1
	elif event is InputEventScreenDrag and event.index == _swipe:
		var x := _point(event.position).x
		if not _swiped and absf(x - _swipe_x) > 6.0:
			_swiped = true
			for c in cells.get_children():
				if c.has_method("cancel_tap"):
					c.cancel_tap()
		if _swiped:
			var step := float(SLOT + GAP)
			while _swipe_x - x >= step:
				scroll(1)
				_swipe_x -= step
			while x - _swipe_x >= step:
				scroll(-1)
				_swipe_x += step


## Screen point `pos` in the strip's UI pixels.
func _point(pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * pos


## Whether screen point `pos` is on the strip (its cells and arrows).
func _on_strip(pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_point(pos))
