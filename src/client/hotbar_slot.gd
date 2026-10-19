extends Control
## One item cell of the hotbar or a hand: a sunken well with an icon, a tag in the top
## left corner (which hand holds it: Л, П or Л+П) and a number or key in the bottom right.

const UiStyle := preload("res://src/client/ui_style.gd")

signal pressed

var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
## Size the icon is drawn at; a whole multiple of the texture keeps its pixels square.
var icon_size := Vector2(24, 24)
var tag := "":
	set(v):
		tag = v
		queue_redraw()
var number := "":
	set(v):
		number = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()

var _box: StyleBox
var _touch_ms := -100000
var _box_selected: StyleBox


func _init(side := 40) -> void:
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = UiStyle.slot(false)
	_box_selected = UiStyle.slot(true)


func _gui_input(event: InputEvent) -> void:
	# Taps come as touches from any finger, so a slot can be picked while the other thumb
	# walks; mouse clicks that copy a tap are skipped.
	if event is InputEventScreenTouch and event.pressed:
		_touch_ms = Time.get_ticks_msec()
		pressed.emit()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _touch_ms > 1000:
			pressed.emit()
		accept_event()


func _draw() -> void:
	draw_style_box(_box_selected if selected else _box, Rect2(Vector2.ZERO, size))
	if texture != null:
		draw_texture_rect(texture, Rect2(((size - icon_size) * 0.5).floor(), icon_size), false)
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	if tag != "":
		_text(font, tag, Vector2(4, 3 + font.get_ascent(fs)), UiStyle.ACCENT)
	if number != "":
		var w := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(font, number, Vector2(size.x - 3 - w, size.y - 3 - font.get_descent(fs)), UiStyle.INK)


## Text with a one-pixel dark outline so it reads over any icon.
func _text(font: Font, text: String, pos: Vector2, color: Color) -> void:
	var fs := UiStyle.FONT_SIZE
	pos = pos.round()
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.EDGE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
