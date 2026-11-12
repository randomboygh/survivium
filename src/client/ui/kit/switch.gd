extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows): a thin dark line with a small square knob that slides
## right and lights amber (the line amber behind it) when on, left and pale when off.
## Its `text`, when it has one, stands left of the line and the knob; they stand at the
## right end of the switch, or where `track_at` (0 the left, 0.5 the middle) puts it.
## `toggled` tells the change; `set_pressed_no_signal` shows a value without telling.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## The room the switch draws in, in UI pixels: the line runs across it.
const TRACK := Vector2(34, 14)
## The line's thickness and the knob's side.
const BAR := 4
const KNOB := 14
## The room between the text and the line.
const GAP := 8
## How long the knob slides, in seconds.
const SLIDE := 0.08

## Where the line stands along the free room: 1 the right end, 0.5 the middle.
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


## The rect the line and the knob take in the switch.
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
	var y := r.position.y + floorf(r.size.y * 0.5)
	# The line: thin, a dark edge round it, lit amber up to the knob while on.
	var line := Rect2(r.position.x + 2, y - BAR * 0.5 - 1, r.size.x - 4, BAR + 2)
	draw_rect(line, UiStyle.EDGE)
	var inner := line.grow(-1)
	draw_rect(inner, UiStyle.WELL_SHADE)
	var travel := r.size.x - KNOB
	var x := r.position.x + roundf(travel * _at)
	if _at > 0.0:
		draw_rect(Rect2(inner.position, Vector2(x + KNOB * 0.5 - inner.position.x, inner.size.y)), UiStyle.ACCENT_DARK)
	# The knob: a small square with its corners cut, a pixel of light on top.
	var lit := button_pressed
	var fill := UiStyle.ACCENT if lit else UiStyle.MUTED
	if is_hovered() and not disabled:
		fill = fill.lightened(0.15)
	var k := Rect2(x, y - KNOB * 0.5, KNOB, KNOB)
	draw_rect(Rect2(k.position + Vector2(1, 0), Vector2(KNOB - 2, KNOB)), UiStyle.EDGE)
	draw_rect(Rect2(k.position + Vector2(0, 1), Vector2(KNOB, KNOB - 2)), UiStyle.EDGE)
	draw_rect(k.grow(-2), fill)
	draw_rect(Rect2(k.position + Vector2(2, 2), Vector2(KNOB - 4, 1)), fill.lightened(0.35))
	draw_rect(Rect2(k.position + Vector2(2, KNOB - 3), Vector2(KNOB - 4, 1)), fill.darkened(0.3))
