extends PanelContainer
## The character's state in the top left corner, as tall as a button: health, satiety
## and stamina as short bars (the load is on the bag button). Shown only while something changes noticeably or
## is low (plan/design/ui.md: "indicator appears only on significant change or in a
## critical state"), or while pinned.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")

const BAR := Vector2(50, 5)
const ROW := 10
## How long the panel stays after a noticeable change, seconds; and what counts as one.
const LINGER := 3.0
const NOTICE := 4.0
## Below these the state is shown all the time.
const LOW := {"health": 60.0, "satiety": Vitals.HUNGRY + 5.0, "stamina": 30.0}
const ROWS := [
	["health", "heart", UiStyle.DANGER],
	["satiety", "food", UiStyle.ACCENT],
	["stamina", "bolt", UiStyle.GOOD],
]

## Keep it shown whatever the state.
var pinned := false
var _values := {}
var _shown := {}
var _linger := 0.0
var _canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.TIGHT))
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.custom_minimum_size = Vector2(12 + BAR.x, ROW * ROWS.size() - 2)
	_canvas.draw.connect(_draw_rows)
	add_child(_canvas)
	visible = false


## Takes the state of `vitals` for this frame.
func update(vitals, delta: float) -> void:
	var low := false
	for r in ROWS:
		var v: float = vitals.get(r[0])
		_values[r[0]] = v
		if absf(v - _shown.get(r[0], v)) >= NOTICE:
			_linger = LINGER
		if absf(v - _shown.get(r[0], -100.0)) >= 1.0:
			_shown[r[0]] = v
			_canvas.queue_redraw()
		low = low or v < LOW[r[0]]
	_linger = maxf(0.0, _linger - delta)
	visible = pinned or low or _linger > 0.0


func _draw_rows() -> void:
	var y := 0
	for r in ROWS:
		_row(y, r[1], _values.get(r[0], 0.0) / Vitals.MAX, r[2])
		y += ROW


func _row(y: int, icon: String, share: float, color: Color) -> void:
	_canvas.draw_texture(ItemIcons.picture(icon), Vector2(0, y))
	var r := Rect2(12, y + 2, BAR.x, BAR.y)
	_canvas.draw_rect(r, UiStyle.WELL)
	_canvas.draw_rect(Rect2(r.position, Vector2(roundf(BAR.x * clampf(share, 0.0, 1.0)), BAR.y)), color)
