extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows): a pill-shaped track with a round knob that slides
## right over an amber track when on, left over a dark one, pale, when off.
## Its `text`, when it has one, stands left of the track; it stands at the
## right end of the switch, or where `track_at` (0 the left, 0.5 the middle) puts it.
## `toggled` tells the change; `show_value` shows a value at once without telling.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## The room the switch draws in, in UI pixels: the line runs across it.
const TRACK := Vector2(40, 22)
## The room between the knob and the track's edge.
const KNOB_GAP := 3
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
	var lit := button_pressed
	# The track: a pill with round ends in a dark edge, amber inside while on.
	_pill(r, UiStyle.EDGE)
	_pill(r.grow(-2), UiStyle.WELL_SHADE)
	if _at > 0.0:
		_pill(Rect2(r.position + Vector2(2, 2), Vector2(r.size.y - 4 + (r.size.x - r.size.y) * _at, r.size.y - 4)),
			UiStyle.ACCENT if lit else UiStyle.ACCENT_DARK)
	# The knob: a round one in a dark edge, cream on and pale off, a lighter top.
	var side := r.size.y - 2 * KNOB_GAP
	var at := r.position + Vector2(KNOB_GAP + roundf((r.size.x - r.size.y) * _at), KNOB_GAP)
	var fill := UiStyle.INK if lit else UiStyle.MUTED
	if is_hovered() and not disabled:
		fill = fill.lightened(0.15)
	var knob := Rect2(at, Vector2(side, side))
	_pill(knob, UiStyle.EDGE)
	_pill(knob.grow(-1), fill.darkened(0.2))
	_pill(Rect2(knob.position + Vector2(1, 1), Vector2(side - 2, side - 3)), fill)


## Fills `r` as a pill: its ends rounded to half its height, cut in whole pixels.
func _pill(r: Rect2, color: Color) -> void:
	var h := int(r.size.y)
	var rad := r.size.y * 0.5
	for i in h:
		var dy := i + 0.5 - rad
		var dx := roundf(rad - sqrt(maxf(0.0, rad * rad - dy * dy)))
		draw_rect(Rect2(r.position.x + dx, r.position.y + i, r.size.x - 2 * dx, 1), color)
