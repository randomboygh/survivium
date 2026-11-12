extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows), in pixels (the user's pick of five, 2026-11-12): a pill
## in a dark edge with a round knob in a thick edge; off, a dark track and a pale knob on
## the left; on, a dim amber track and an amber knob on the right. The round ends are
## pixel circles, stepped the same on every side.
## Its `text`, when it has one, stands left of the track; it stands at the
## right end of the switch, or where `track_at` (0 the left, 0.5 the middle) puts it.
## `toggled` tells the change; `show_value` shows a value at once without telling.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## The track's size, in UI pixels.
const TRACK := Vector2(44, 24)
## The track's dark edge, the room between it and the knob, and the knob's own edge.
const EDGE_W := 2
const KNOB_GAP := 3
const KNOB_EDGE := 2
## The room between the text and the track.
const GAP := 8
## How long the knob slides, in seconds.
const SLIDE := 0.08

## Where the track stands along the free room: 1 the right end, 0.5 the middle.
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


## The track's rect in the switch.
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
	# The track: a pill in whole pixels in a dark edge, amber inside while on.
	_pill(r, UiStyle.EDGE)
	_pill(r.grow(-EDGE_W), UiStyle.WELL_SHADE.lerp(UiStyle.ACCENT_DARK, _at))
	# The knob: a round one in a thick dark edge, amber on and pale off, a gleam on top.
	var fill := UiStyle.ACCENT if button_pressed else UiStyle.MUTED
	if is_hovered() and not disabled:
		fill = fill.lightened(0.15)
	var side := r.size.y - 2 * KNOB_GAP
	var knob := Rect2(Vector2(roundf(lerpf(r.position.x + KNOB_GAP, r.end.x - KNOB_GAP - side, _at)),
		r.position.y + KNOB_GAP), Vector2(side, side))
	_pill(knob, UiStyle.EDGE)
	_pill(knob.grow(-KNOB_EDGE), fill)
	_pill(Rect2(knob.position + Vector2(side * 0.5 - 4, KNOB_EDGE + 1), Vector2(8, 3)), fill.lightened(0.3))


## Fills `r` as a pill in whole pixels: its ends half circles stepped as a pixel circle
## is (midpoint rounding, the same steps on every side).
func _pill(r: Rect2, color: Color) -> void:
	var h := int(r.size.y)
	var rad := h * 0.5
	for i in h:
		var dy := absf(i + 0.5 - rad)
		var dx := floorf(rad - sqrt(maxf(0.0, rad * rad - dy * dy)) + 0.5)
		draw_rect(Rect2(r.position.x + dx, r.position.y + i, r.size.x - 2 * dx, 1), color)
