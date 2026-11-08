extends Control
## One item cell of the hotbar, a hand or the bag: a sunken well with an icon, a tag in
## the top left corner (which hand holds it: Л, П or Л+П), its key in the top right and
## a number (how many) in the bottom right, and a strip along the bottom for how much
## of a light held is left to burn, how fresh food is, or how loaded the bag on the back is;
## the well faintly tinted by the grade of the thing's quality, stronger toward its edges
## the better the thing (Quality);
## the picture faint when the thing cannot be used now (`inactive`).

const UiStyle := preload("res://src/client/ui/ui_style.gd")

signal pressed

## The colour of the slot's number (its key).
const KEY_COLOR := Color("#7a6850")
## The picture of a thing that cannot be used now.
const INACTIVE := Color(0.55, 0.55, 0.55, 0.45)

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
## How much is left of what burns in the slot, or how fresh its food is, 0..1, drawn
## as a strip; below 0 none.
var fill := -1.0:
	set(v):
		if v != fill:
			fill = v
			queue_redraw()
## The strip's colour; transparent for a light's (amber, red when nearly out).
var fill_color := Color(0, 0, 0, 0):
	set(v):
		fill_color = v
		queue_redraw()
## The grade of the quality of the thing in the slot (Quality.grade), a faint radial tint
## of GRADE_TINTS over the well, under the icon: empty in a wide middle, rising near the
## well's edge; below 0 none.
var grade := -1:
	set(v):
		if v != grade:
			grade = v
			queue_redraw()
## Poor, plain, normal, good, excellent: a colour and how much of it lies at the well's
## edges (the better, the more the edges glow).
const GRADE_TINTS := [[Color(0.85, 0.35, 0.25), 0.10], [Color(0.6, 0.6, 0.6), 0.06],
	[Color(1.0, 0.95, 0.8), 0.07], [Color(0.45, 0.85, 0.4), 0.20], [Color(0.95, 0.75, 0.3), 0.30]]
## The share of the radius left empty in the middle before the tint starts rising.
const TINT_HOLLOW := 0.6
## The tints as radial gradients, made once.
static var _tints := []
## The well's frame, which the tint stays inside.
const TINT_INSET := 3.0
var selected := false:
	set(v):
		selected = v
		queue_redraw()
## A thing that cannot be used now (a weapon with nothing to shoot): its picture faint
## and grey, the slot and its marks as they are.
var inactive := false:
	set(v):
		if v != inactive:
			inactive = v
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


## The radial tint of grade `g`: nothing in the middle, rising to its edge colour.
static func _tint(g: int) -> Texture2D:
	if _tints.is_empty():
		for t: Array in GRADE_TINTS:
			var c: Color = t[0]
			var grad := Gradient.new()
			grad.offsets = PackedFloat32Array([0.0, TINT_HOLLOW, 1.0])
			grad.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.0), Color(c, t[1])])
			var tex := GradientTexture2D.new()
			tex.gradient = grad
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(0.5, 0.0)
			tex.width = 32
			tex.height = 32
			_tints.append(tex)
	return _tints[g]


func cancel_tap() -> void:
	_down = -1


func _draw() -> void:
	draw_style_box(_box_selected if selected else _box, Rect2(Vector2.ZERO, size))
	if grade >= 0 and texture != null:
		draw_texture_rect(_tint(clampi(grade, 0, GRADE_TINTS.size() - 1)),
			Rect2(Vector2.ONE * TINT_INSET, size - Vector2.ONE * TINT_INSET * 2.0), false)
	if texture != null:
		draw_texture_rect(texture, Rect2(((size - icon_size) * 0.5).floor(), icon_size), false,
			INACTIVE if inactive else Color.WHITE)
	var font := UiStyle.font()
	var fs := UiStyle.FONT_SIZE
	if fill >= 0.0:
		var w := size.x - 8.0
		var r := Rect2(4.0, size.y - 6.0, w, 2.0)
		draw_rect(r.grow(1.0), UiStyle.EDGE)
		draw_rect(Rect2(r.position, Vector2(maxf(1.0, roundf(w * fill)), r.size.y)), fill_color if fill_color.a > 0.0 else (UiStyle.DANGER if fill < 0.25 else UiStyle.ACCENT))
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
