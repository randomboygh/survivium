extends Control
## The whole map over the screen: everything explored so far, centred on the player
## when it opens, moved by dragging (a finger or the mouse), zoomed by pinching, the
## mouse wheel or the buttons, closed by the cross, Escape or M. It draws the regions
## the minimap paints (see Minimap.draw_map).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Minimap := preload("res://src/client/ui/minimap.gd")

## UI pixels per map pixel (a map pixel is two by two cells); below one the map
## shrinks, so a long walk fits on the screen; the closest parts the marks of things
## placed side by side.
const ZOOMS := [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 6.0, 9.0, 12.0]
## The zoom the map opens at the first time.
const FIRST_ZOOM := 3
const BUTTON := 36
const MARGIN := 8
const BACKGROUND := Color(0.06, 0.06, 0.07, 0.97)
## Mouse events this soon after a touch come from the finger (see Controls.input).
const TOUCH_MOUSE_MS := 1000

var minimap: Minimap
## The column in the middle of the screen, in cells.
var centre := Vector2.ZERO
var zoom_index := FIRST_ZOOM
## Fingers on the map by index, and how far apart two of them were when the pinch
## last changed the zoom.
var _fingers := {}
var _pinch := 0.0
var _mouse_drag := false
var _last_touch := -100000
var _last_player := Vector2i(1 << 30, 0)
var _buttons: VBoxContainer
## The zoom buttons, dimmed at the largest and the smallest zoom.
var _plus: Button
var _minus: Button
var _title: Label
var _hint: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	add_child(_buttons)
	_button("close", "Закрыть (M)", close)
	_plus = _button("plus", "Крупнее", func() -> void: zoom_by(1))
	_minus = _button("minus", "Мельче", func() -> void: zoom_by(-1))
	zoom_by(0)
	_button("target", "К игроку", func() -> void:
		centre = Vector2(minimap.player_cell)
		queue_redraw())
	_title = UiStyle.label("Карта", UiStyle.ACCENT)
	_title.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	add_child(_title)
	_hint = UiStyle.label("", UiStyle.MUTED)
	add_child(_hint)


func _button(icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = UiStyle.icon(icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(BUTTON, BUTTON)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_stylebox_override("normal", UiStyle.panel())
	b.add_theme_stylebox_override("hover", UiStyle.panel())
	b.add_theme_stylebox_override("disabled", UiStyle.panel())
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	b.pressed.connect(action)
	_buttons.add_child(b)
	return b


## Covers a screen `screen` UI pixels large; `touch` picks the hint.
func fit(screen: Vector2, touch: bool) -> void:
	position = Vector2.ZERO
	size = screen
	_buttons.reset_size()
	_buttons.position = Vector2(screen.x - MARGIN - _buttons.size.x, MARGIN)
	_title.position = Vector2(MARGIN, MARGIN)
	_hint.text = "Двигайте пальцем, щипок меняет масштаб" if touch else "Перетащите мышью, колесо меняет масштаб"
	_hint.reset_size()
	_hint.position = Vector2(MARGIN, screen.y - MARGIN - _hint.size.y)
	queue_redraw()


func open() -> void:
	centre = Vector2(minimap.player_cell)
	_fingers.clear()
	visible = true
	move_to_front()
	queue_redraw()


func close() -> void:
	visible = false
	_fingers.clear()
	_mouse_drag = false


func zoom_by(d: int) -> void:
	zoom_index = clampi(zoom_index + d, 0, ZOOMS.size() - 1)
	_plus.disabled = zoom_index == ZOOMS.size() - 1
	_minus.disabled = zoom_index == 0
	queue_redraw()


func zoom() -> float:
	return ZOOMS[zoom_index]


func _process(_delta: float) -> void:
	if visible and minimap.player_cell != _last_player:
		_last_player = minimap.player_cell
		queue_redraw()


func _pan(screen_moved: Vector2) -> void:
	centre -= screen_moved / zoom() * Minimap.STEP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_last_touch = Time.get_ticks_msec()
		if event.pressed:
			_fingers[event.index] = event.position
		else:
			_fingers.erase(event.index)
		_pinch = _spread()
	elif event is InputEventScreenDrag:
		_last_touch = Time.get_ticks_msec()
		_fingers[event.index] = event.position
		if _fingers.size() == 1:
			_pan(event.relative)
		elif _fingers.size() == 2:
			var d := _spread()
			if _pinch > 0.0 and d > _pinch * 1.35:
				zoom_by(1)
				_pinch = d
			elif _pinch > 0.0 and d < _pinch / 1.35:
				zoom_by(-1)
				_pinch = d
	elif Time.get_ticks_msec() - _last_touch < TOUCH_MOUSE_MS:
		pass
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_mouse_drag = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_by(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_by(-1)
	elif event is InputEventMouseMotion and _mouse_drag:
		_pan(event.relative)
	accept_event()


## Distance between the first two fingers on the map, 0 with fewer.
func _spread() -> float:
	if _fingers.size() < 2:
		return 0.0
	var p: Array = _fingers.values()
	return (p[0] as Vector2).distance_to(p[1])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_M and not get_tree().paused:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BACKGROUND)
	minimap.draw_map(self, rect, centre, zoom(), true)
	var p := (rect.get_center() + (Vector2(minimap.player_cell) - centre) / Minimap.STEP * zoom()).floor()
	var r := 1.0 + clampi(zoom_index - 2, 0, 4)
	draw_rect(Rect2(p - Vector2(r + 1, r + 1), Vector2(2 * r + 3, 2 * r + 3)), UiStyle.DARK_INK)
	draw_rect(Rect2(p - Vector2(r, r), Vector2(2 * r + 1, 2 * r + 1)), UiStyle.ACCENT)
