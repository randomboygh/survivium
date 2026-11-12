extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows), in pixels (the user's pick of five, 2026-11-12): a pill
## in a dark edge with a round knob in a thick edge; off, a dark track and a pale knob on
## the left; on, a dim amber track and an amber knob on the right. The round ends are
## smooth circles (stepped pixel circles showed as stairs at a phone's scale).
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
	# The track: a pill in a dark edge, amber inside while on.
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


## Fills `r` as a pill: smooth round ends whose edge fades over one pixel of the screen,
## so they stay round however large the interface is drawn (stepped whole-pixel ends
## showed as stairs on a phone, where one UI pixel is three or four of the screen's).
func _pill(r: Rect2, color: Color) -> void:
	var rad := r.size.y * 0.5
	if rad <= 0.0:
		return
	# One pixel of the screen in this control's units.
	var px := 1.0 / maxf(0.01, get_global_transform_with_canvas().get_scale().y)
	var y := r.position.y + rad
	var ends := PackedVector2Array([Vector2(r.position.x + rad, y), Vector2(maxf(r.position.x + rad, r.end.x - rad), y)])
	var steps := clampi(ceili(rad / px * 0.6), 6, 48)
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for side in 2:
		for k in steps + 1:
			var a := PI * (0.5 + float(k) / steps) + PI * side
			var dir := Vector2(cos(a), sin(a))
			inner.append(ends[side] + dir * maxf(0.0, rad - px * 0.5))
			outer.append(ends[side] + dir * (rad + px * 0.5))
	draw_colored_polygon(inner, color)
	var points := inner + outer
	var n := inner.size()
	var clear := Color(color, 0.0)
	var colors := PackedColorArray()
	colors.resize(2 * n)
	for k in n:
		colors[k] = color
		colors[n + k] = clear
	var indices := PackedInt32Array()
	for k in n:
		var m := (k + 1) % n
		indices.append_array([k, m, n + k, m, n + m, n + k])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)
