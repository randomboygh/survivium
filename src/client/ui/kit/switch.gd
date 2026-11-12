extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows), after Material 3: off, a dark pill in a pale outline
## with a small pale knob on the left; on, an amber pill with a big dark knob on the right
## (the user's pick of five, 2026-11-12). Its round ends are drawn smooth, not stepped.
## Its `text`, when it has one, stands left of the track; it stands at the
## right end of the switch, or where `track_at` (0 the left, 0.5 the middle) puts it.
## `toggled` tells the change; `show_value` shows a value at once without telling.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## The track's size, in UI pixels.
const TRACK := Vector2(44, 24)
## The knob's radius off and on, and how far its centre stays from the track's ends.
const KNOB_OFF := 5.0
const KNOB_ON := 9.0
const KNOB_INSET := 12.0
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
	var mid := r.position + r.size * 0.5
	# The track: off, a pale outline round a dark fill; on, filled amber (Material 3).
	if _at < 0.5:
		_pill(r, UiStyle.MUTED)
		_pill(r.grow(-2), UiStyle.WELL_SHADE)
	else:
		_pill(r, UiStyle.ACCENT_DARK)
		_pill(r.grow(-1), UiStyle.ACCENT)
	# The knob: small and pale off, big and dark on, so the state shows without colour.
	var color := UiStyle.MUTED.lerp(UiStyle.DARK_INK, _at)
	if is_hovered() and not disabled:
		color = color.lightened(0.15)
	var x := lerpf(r.position.x + KNOB_INSET, r.end.x - KNOB_INSET, _at)
	draw_circle(Vector2(x, mid.y), lerpf(KNOB_OFF, KNOB_ON, _at), color, true, -1.0, true)


## Fills `r` as a pill, its ends half circles, drawn smooth at any scale of the UI.
func _pill(r: Rect2, color: Color) -> void:
	var rad := r.size.y * 0.5
	draw_rect(Rect2(r.position + Vector2(rad, 0), Vector2(r.size.x - 2 * rad, r.size.y)), color)
	draw_circle(r.position + Vector2(rad, rad), rad, color, true, -1.0, true)
	draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, color, true, -1.0, true)
