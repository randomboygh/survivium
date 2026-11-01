extends Control
## One item cell of the hotbar, a hand or the bag: a sunken well with an icon, a tag in
## the top left corner (which hand holds it: Л, П or Л+П), its key in the top right and
## a number (how many) in the bottom right, and a strip along the bottom for how much
## of a light held is left to burn.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

signal pressed

## The colour of the slot's number (its key).
const KEY_COLOR := Color("#7a6850")

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
var key := "":
	set(v):
		key = v
		queue_redraw()
## How much is left of what burns in the slot, 0..1, drawn as a strip; below 0 none.
var fill := -1.0:
	set(v):
		if v != fill:
			fill = v
			queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()

## When set, a touch (or a click) picks the slot as the finger lifts over it, not as it
## lands (the hotbar and the lists that scroll, where a finger also drags the slots
## along); cancel_tap() forgets the touch.
var on_release := false

var _box: StyleBox
var _touch_ms := -100000
var _down := -1
var _box_selected: StyleBox
static var _boxes := []


func _init(side := 40) -> void:
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	# One frame of each kind for every slot: a frame is drawn pixel by pixel.
	if _boxes.is_empty():
		_boxes = [UiStyle.slot(false), UiStyle.slot(true)]
	_box = _boxes[0]
	_box_selected = _boxes[1]


func _gui_input(event: InputEvent) -> void:
	# Taps come as touches from any finger, so a slot can be picked while the other thumb
	# walks; mouse clicks that copy a tap are skipped.
	if event is InputEventScreenTouch:
		_touch_ms = Time.get_ticks_msec()
		if event.pressed and not on_release:
			pressed.emit()
		elif event.pressed:
			_down = event.index
		elif event.index == _down:
			_down = -1
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device != InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _touch_ms > 1000:
			if event.pressed and not on_release:
				pressed.emit()
			elif event.pressed:
				_down = -2
			elif _down == -2:
				_down = -1
				if Rect2(Vector2.ZERO, size).has_point(event.position):
					pressed.emit()
		accept_event()


func cancel_tap() -> void:
	_down = -1


func _draw() -> void:
	draw_style_box(_box_selected if selected else _box, Rect2(Vector2.ZERO, size))
	if texture != null:
		draw_texture_rect(texture, Rect2(((size - icon_size) * 0.5).floor(), icon_size), false)
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	if fill >= 0.0:
		var w := size.x - 8.0
		var r := Rect2(4.0, size.y - 6.0, w, 2.0)
		draw_rect(r.grow(1.0), UiStyle.EDGE)
		draw_rect(Rect2(r.position, Vector2(maxf(1.0, roundf(w * fill)), r.size.y)), UiStyle.DANGER if fill < 0.25 else UiStyle.ACCENT)
	if tag != "":
		_text(font, tag, Vector2(4, 3 + font.get_ascent(fs)), UiStyle.ACCENT)
	if key != "":
		# The slot's number is a quiet mark: dim and without the outline.
		var kw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(size.x - 3 - kw, 3 + font.get_ascent(fs)).round(), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, KEY_COLOR)
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
