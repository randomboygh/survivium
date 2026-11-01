extends PanelContainer
## The character's state in the top left corner, as tall as a button: health, satiety
## and stamina as short bars (the load is on the bag button), and beside them the body's
## warmth as a standing bar under a thermometer, full at Vitals.COMFORT, blue below
## Vitals.COLD, red above Vitals.HOT; a drop by the thermometer shows how wet the body is. Shown only while something changes noticeably or
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
	["warmth", "thermo", UiStyle.INK],
]
## Where the warmth column starts, and how wide its bar is.
const WARM_X := 12 + 50 + 4
const WARM_BAR := 5
## Wetter than this shows the drop, and keeps the panel up.
const WET_SHOWN := 0.05

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
	_canvas.custom_minimum_size = Vector2(WARM_X + 9 + 9, ROW * (ROWS.size() - 1) - 2)
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
		if r[0] == "warmth":
			low = low or v < Vitals.COLD or v > Vitals.HOT
		else:
			low = low or v < LOW[r[0]]
	var wet: float = vitals.wet
	if absf(wet - _values.get("wet", 0.0)) >= 0.05 or (wet > 0.0) != (_values.get("wet", 0.0) > 0.0):
		_values["wet"] = wet
		_canvas.queue_redraw()
	low = low or wet > WET_SHOWN
	_linger = maxf(0.0, _linger - delta)
	visible = pinned or low or _linger > 0.0


func _draw_rows() -> void:
	var y := 0
	for r in ROWS:
		if r[0] == "warmth":
			_warmth_column()
		else:
			_row(y, r[1], _values.get(r[0], 0.0) / Vitals.MAX, r[2])
			y += ROW


## Warmth: a standing bar under the thermometer, filled up to comfort and full when hot,
## coloured by the danger; the drop beside the thermometer when wet.
func _warmth_column() -> void:
	var v: float = _values.get("warmth", Vitals.COMFORT)
	var color := UiStyle.INK
	if v < Vitals.COLD:
		color = UiStyle.COLD
	elif v > Vitals.HOT:
		color = UiStyle.DANGER
	_canvas.draw_texture(ItemIcons.picture("thermo"), Vector2(WARM_X, 0))
	var top := ROW
	var h: int = int(_canvas.size.y) - top
	var r := Rect2(WARM_X + 2, top, WARM_BAR, h)
	_canvas.draw_rect(r, UiStyle.WELL)
	var full := roundf(h * clampf(v / Vitals.COMFORT, 0.0, 1.0))
	_canvas.draw_rect(Rect2(r.position.x, r.end.y - full, WARM_BAR, full), color)
	var wet: float = _values.get("wet", 0.0)
	if wet > WET_SHOWN:
		_canvas.draw_texture(ItemIcons.picture("drop"), Vector2(WARM_X + 9, 0), Color(1, 1, 1, lerpf(0.4, 1.0, wet)))


func _row(y: int, icon: String, share: float, color: Color) -> void:
	_canvas.draw_texture(ItemIcons.picture(icon), Vector2(0, y))
	var r := Rect2(12, y + 2, BAR.x, BAR.y)
	_canvas.draw_rect(r, UiStyle.WELL)
	_canvas.draw_rect(Rect2(r.position, Vector2(roundf(BAR.x * clampf(share, 0.0, 1.0)), BAR.y)), color)
