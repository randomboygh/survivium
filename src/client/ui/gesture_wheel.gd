extends Control
## The wheel of gestures (decision 183, Gestures.LIST): a round button for each gesture
## on a circle in the middle of the screen, its icon and its words under it, its number
## for the keys 1–8. A tap or a key says `chosen` with its name and closes the wheel; a
## tap beside the buttons, Escape or the wheel's own key (C) close it. It covers the whole
## screen, so a tap on it does not reach the world, but shades only a disc under the
## buttons and their words, the world round it seen as it is. `game` is the Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Lang := preload("res://src/shared/content/lang.gd")
const Gestures := preload("res://src/shared/game/gestures.gd")

## The buttons' size and how far from the middle they stand, in interface pixels; the
## circle shrinks on a narrow screen.
const BUTTON := 44
const RADIUS := 84
const BACKDROP := Color(0.03, 0.03, 0.04, 0.5)
## How far the shaded disc reaches past the buttons' centres: half a button and a line of words.
const SHADE_PAST := BUTTON / 2 + 14
## Interface pixels over which the disc's edge thins out, dithered.
const SHADE_EDGE := 6
## The 4×4 ordered dither: a pixel of the edge is shaded while its number is under the
## shade's strength there (0..16).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

signal chosen(name: String)
signal closed

var game
var _buttons: Array[Button] = []
var _labels: Array[Label] = []
## The buttons' icons, each pixel of them a whole number of the screen's (_size_pics).
var _pics: Array[TextureRect] = []
## Screen pixels an icon's pixel takes now (0 before the first fit).
var _pic_px := 0
## The shaded disc under the buttons: its centre and radius.
var _mid := Vector2.ZERO
var _shade := 0.0
## The shaded disc as a picture, its edge dithered (made again when its size changes).
var _disc: ImageTexture


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in Gestures.LIST.size():
		var g: Dictionary = Gestures.LIST[i]
		var b := Button.new()
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.stretch_mode = TextureRect.STRETCH_KEEP
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_child(pic)
		_pics.append(pic)
		b.tooltip_text = "%s (%d)" % [Lang.t(g.title), i + 1]
		b.focus_mode = Control.FOCUS_NONE
		# No button behind the icon: the icon and its words on the shade; the words
		# light up under the pointer.
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
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
		b.mouse_entered.connect(l.add_theme_color_override.bind("font_color", UiStyle.ACCENT))
		b.mouse_exited.connect(l.add_theme_color_override.bind("font_color", UiStyle.INK))
	get_parent().resized.connect(_fit)
	_fit()


## The icons about twice as large as the interface's pixels, but each of their pixels
## a whole number of the screen's: on a phone the interface is scaled by a fraction
## (Hud.fit), and an icon only doubled there would have pixels of two widths, its
## slanted lines broken. Each is made that many times larger and drawn back at the
## screen's own scale, in the middle of its button.
func _size_pics() -> void:
	var s := get_global_transform_with_canvas().get_scale().x
	if s <= 0.0:
		return
	var px := maxi(1, roundi(2.0 * s))
	for i in _pics.size():
		var pic := _pics[i]
		if px != _pic_px:
			var img := UiStyle.icon("g_" + Gestures.LIST[i].name).get_image()
			img.resize(img.get_width() * px, img.get_height() * px, Image.INTERPOLATE_NEAREST)
			pic.texture = ImageTexture.create_from_image(img)
		pic.scale = Vector2(1.0 / s, 1.0 / s)
		pic.size = pic.texture.get_size()
		# The drawn pixels in the middle (an odd icon has a clear column or row).
		var used := Rect2(pic.texture.get_image().get_used_rect())
		pic.position = Vector2(BUTTON, BUTTON) * 0.5 - (used.position + used.size * 0.5) / s
	_pic_px = px


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
	_mid = mid
	_shade = r + SHADE_PAST
	if _disc == null or _disc.get_width() != 2 * int(_shade):
		_disc = _make_disc(int(_shade))
	for i in _buttons.size():
		var a := TAU * i / _buttons.size() - PI * 0.5
		var at := (mid + Vector2(cos(a), sin(a)) * r - Vector2(BUTTON, BUTTON) * 0.5).floor()
		_buttons[i].position = at
		var l := _labels[i]
		l.reset_size()
		l.position = (at + Vector2(BUTTON * 0.5 - l.size.x * 0.5, BUTTON + 1)).floor()
	_size_pics()
	move_to_front()
	queue_redraw()


func _draw() -> void:
	draw_texture(_disc, _mid - Vector2(_disc.get_size()) * 0.5)


## The disc `radius` interface pixels round: BACKDROP inside, its last SHADE_EDGE pixels
## dithered away (BAYER), pixel by pixel as the rest of the interface.
static func _make_disc(radius: int) -> ImageTexture:
	var img := Image.create_empty(2 * radius, 2 * radius, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 2 * radius:
		for x in 2 * radius:
			var d := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var t := (radius - d) / SHADE_EDGE
			if t >= 1.0 or t > 0.0 and BAYER[(y % 4) * 4 + x % 4] < int(t * 16.0):
				img.set_pixel(x, y, BACKDROP)
	return ImageTexture.create_from_image(img)
