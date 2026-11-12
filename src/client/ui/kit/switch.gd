extends Button
## A switch of the UI kit (kit.gd `check`, and the rows «name ‹ value ›» whose values are
## only «выкл | вкл», ChoiceRows), in pixels (the user's pick of five, 2026-11-12): a pill
## in a dark edge with a round knob in a thick edge; off, a dark track and a pale knob on
## the left; on, a dim amber track and an amber knob on the right. The round ends are
## pixel circles drawn by pixel art's rules: even steps, the same on every side.
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


## The rows' insets of a pixel circle, by its diameter (see _round).
static var _rounds := {}


## Fills `r` as a pill in whole pixels: its ends half circles drawn as pixel art draws
## them (_round), the same steps on every side.
func _pill(r: Rect2, color: Color) -> void:
	var h := int(r.size.y)
	var inset := _round(h)
	for i in h:
		var dx: int = inset[i]
		draw_rect(Rect2(r.position.x + dx, r.position.y + i, r.size.x - 2 * dx, 1), color)


## How far each row of a pixel circle `h` pixels across stands in from its side, top to
## bottom. Of the circles the pixels' centres give for a radius a little smaller than
## h / 2, the one whose steps run evenly: from the flat top to the diagonal each step is
## no longer than the one before and shrinks by as little as it can, and the same from the
## flat side (the circle is the same turned over its diagonal); no step of one pixel
## between two longer ones, no jump from a long step to a short one.
static func _round(h: int) -> PackedInt32Array:
	if _rounds.has(h):
		return _rounds[h]
	var half := PackedInt32Array()
	half.resize(h >> 1)
	if h >= 4:
		var best := Vector3(INF, INF, INF)
		for k in 11:
			var t := k * 0.05
			var cand := _round_half(h, h * 0.5 - t)
			var score := _steps_score(cand)
			if score < best:
				best = score
				half = cand
	var all := half.duplicate()
	if h % 2 == 1:
		all.append(0)
	for i in range(half.size() - 1, -1, -1):
		all.append(half[i])
	_rounds[h] = all
	return all


## The top half's insets of the circle `h` across whose pixels have their centres within
## `rad` of its middle.
static func _round_half(h: int, rad: float) -> PackedInt32Array:
	var mid := h * 0.5
	var half := PackedInt32Array()
	for i in h >> 1:
		var dy := mid - (i + 0.5)
		if rad <= dy:
			half.append(h >> 1)
		else:
			half.append(maxi(0, ceili(mid - sqrt(rad * rad - dy * dy) - 0.5)))
	return half


## How unevenly the steps of a quarter circle run (its top half's insets `half`), lower
## is better: (how much steps grow towards the diagonal, the longest drop between two
## steps, 0) — from the top the steps are the drops of the inset, from the side the rows
## each inset holds.
static func _steps_score(half: PackedInt32Array) -> Vector3:
	var values: Array[int] = []
	var rows: Array[int] = []
	for v in half:
		if not values.is_empty() and values[-1] == v:
			rows[-1] += 1
		else:
			values.append(v)
			rows.append(1)
	var top: Array[int] = [half.size() - values[0]]
	for i in values.size() - 1:
		top.append(values[i] - values[i + 1])
	var side: Array[int] = [rows[-1]]
	for i in range(rows.size() - 2, 0, -1):
		side.append(rows[i])
	var grow := 0
	var drop := 0
	for run: Array in [top, side]:
		for i in run.size() - 1:
			grow += maxi(0, run[i + 1] - run[i])
			drop = maxi(drop, run[i] - run[i + 1])
	return Vector3(grow, drop, 0)
