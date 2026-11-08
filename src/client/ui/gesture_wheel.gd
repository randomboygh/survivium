extends Control
## The wheel of gestures (decision 183, Gestures.LIST): a round button for each gesture
## on a circle in the middle of the screen, its icon and its words under it, its number
## for the keys 1–8. A tap or a key says `chosen` with its name and closes the wheel; a
## tap beside the buttons, Escape or the wheel's own key (C) close it. It covers the whole
## screen over a light shade, so a tap on it does not reach the world. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Gestures := preload("res://src/shared/game/gestures.gd")

## The buttons' size and how far from the middle they stand, in interface pixels; the
## circle shrinks on a narrow screen.
const BUTTON := 44
const RADIUS := 84
const BACKDROP := Color(0.03, 0.03, 0.04, 0.35)

signal chosen(name: String)
signal closed

var game
var _buttons: Array[Button] = []
var _labels: Array[Label] = []


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in Gestures.LIST.size():
		var g: Dictionary = Gestures.LIST[i]
		var b := Button.new()
		b.icon = _twice(UiStyle.icon("g_" + g.name))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.tooltip_text = "%s (%d)" % [Lang.t(g.title), i + 1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(BUTTON, BUTTON)
		b.size = Vector2(BUTTON, BUTTON)
		var name: String = g.name
		b.pressed.connect(func() -> void: choose(name))
		add_child(b)
		_buttons.append(b)
		var l := UiStyle.label(g.title, UiStyle.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", UiStyle.DARK_INK)
		l.add_theme_constant_override("outline_size", 4)
		add_child(l)
		_labels.append(l)
	get_parent().resized.connect(_fit)
	_fit()


## Icon `tex` drawn twice as large, pixel for pixel, as the wheel's buttons show it.
static func _twice(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Makes gesture `name` and closes the wheel.
func choose(name: String) -> void:
	chosen.emit(name)
	close()


func close() -> void:
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	# A tap beside the buttons closes the wheel.
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		accept_event()
		close()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	if k >= KEY_1 and k <= KEY_8 and k - KEY_1 < Gestures.LIST.size():
		get_viewport().set_input_as_handled()
		choose(Gestures.LIST[k - KEY_1].name)
	elif k == KEY_ESCAPE or k == KEY_C:
		get_viewport().set_input_as_handled()
		close()


## The buttons on a circle round the middle of the screen, the first at the top, then
## clockwise; their words under them.
func _fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	var mid := (screen * 0.5).floor()
	var r := minf(RADIUS, minf(screen.x, screen.y) * 0.5 - BUTTON)
	for i in _buttons.size():
		var a := TAU * i / _buttons.size() - PI * 0.5
		var at := (mid + Vector2(cos(a), sin(a)) * r - Vector2(BUTTON, BUTTON) * 0.5).floor()
		_buttons[i].position = at
		var l := _labels[i]
		l.reset_size()
		l.position = (at + Vector2(BUTTON * 0.5 - l.size.x * 0.5, BUTTON + 1)).floor()
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
