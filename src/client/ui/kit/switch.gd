extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows): a sunken groove with a knob that slides right and
## lights amber when on, left and plain when off, drawn in the window buttons' frames.
## Its `text`, when it has one, stands left of the groove; the groove stands at the
## right end of the switch, or where `track_at` (0 the left, 0.5 the middle) puts it.
## `toggled` tells the change; `set_pressed_no_signal` shows a value without telling.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## The groove's size, in UI pixels.
const TRACK := Vector2(52, 24)
## The room between the text and the groove.
const GAP := 8
## How long the knob slides, in seconds.
const SLIDE := 0.08

## Where the groove stands along the free room: 1 the right end, 0.5 the middle.
var track_at := 1.0
## The knob's place, 0 (off) to 1 (on), sliding towards the value.
var _at := 0.0


func _init(caption := "", on := false) -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	text = caption
	button_pressed = on
	_at = 1.0 if on else 0.0
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = 0
	bare.content_margin_right = TRACK.x + GAP
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, bare)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(c, UiStyle.INK)
	custom_minimum_size.y = TRACK.y
	toggled.connect(_toggled)


## Shows `on` at once, with the knob already there, telling no one.
func show_value(on: bool) -> void:
	set_pressed_no_signal(on)
	_at = 1.0 if on else 0.0
	set_process(false)
	queue_redraw()


## The groove's rect in the switch.
func track_rect() -> Rect2:
	var room := size.x - TRACK.x
	var x := room if text != "" else floorf(room * track_at)
	return Rect2(Vector2(maxf(0.0, x), floorf((size.y - TRACK.y) * 0.5)), TRACK)


func _toggled(_on: bool) -> void:
	set_process(true)


func _process(delta: float) -> void:
	var goal := 1.0 if button_pressed else 0.0
	_at = move_toward(_at, goal, delta / SLIDE)
	if _at == goal:
		set_process(false)
	queue_redraw()


func _ready() -> void:
	set_process(false)


func _draw() -> void:
	var r := track_rect()
	var ci := get_canvas_item()
	# The groove: a sunken well, lit dim amber on its lit side while on.
	_box("slot").draw(ci, r)
	var inner := r.grow(-4)
	if _at > 0.0:
		draw_rect(Rect2(inner.position, Vector2(floorf(inner.size.x * _at), inner.size.y)), Color(UiStyle.ACCENT_DARK, 0.45))
	# The knob: a button of the windows, amber when on.
	var knob := Vector2(floorf(TRACK.x * 0.5) + 2, TRACK.y)
	var at := r.position + Vector2(roundf((TRACK.x - knob.x) * _at), 0)
	var state := "normal"
	if is_hovered() and not disabled:
		state = "hover"
	_box(state + ("+on" if button_pressed else "")).draw(ci, Rect2(at, knob))
	# Two notches in its middle to take it by.
	var mid := at + (knob * 0.5).floor()
	var ink := UiStyle.ACCENT_DARK if button_pressed else UiStyle.BUTTON_SHADE
	for dx in [-3, 1]:
		draw_rect(Rect2(mid + Vector2(dx, -5), Vector2(2, 8)), ink)


## The frames the switches draw, made once: "slot", or a knob's state, "+on" when lit.
static var _boxes := {}


static func _box(key: String) -> StyleBox:
	if not _boxes.has(key):
		_boxes[key] = UiStyle.slot() if key == "slot" else UiStyle.button(key.trim_suffix("+on"), key.ends_with("+on"))
	return _boxes[key]
