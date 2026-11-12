extends PanelContainer
## The character's state in the top left corner, as tall as a button: health as a thick
## bar with stamina as a thinner one under it (the load is on the bag button), and beside
## them standing bars under their pictures, in this order: satiety under a loaf, water
## under a mug, the body's warmth under a thermometer (full at Vitals.COMFORT, blue below
## Vitals.COLD, red above Vitals.HOT) and its energy under a moon; red when hungry,
## thirsty, sleepy. A standing bar shows only while it is low (`critical`), or all of them
## while the bag is open (pinned). Last, a column of what hinders the body (DEBUFFS: wet,
## out of breath, overloaded). The panel is as wide as what it shows. Shown
## only while something changes noticeably or is low (plan/design/ui.md: "indicator
## appears only on significant change or in a critical state"), or while pinned.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const ItemIcons := preload("res://src/client/ui/item_icons.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")

## The panel's height inside its frame, and the horizontal bars: health, then stamina.
const HEIGHT := 28
const BAR_X := 12
const HEALTH := Rect2(BAR_X, 1, 60, 12)
const STAMINA := Rect2(BAR_X, 20, 50, 5)
## Where the pictures of the two rows stand.
const HEALTH_Y := 3
const STAMINA_Y := 18
## The standing bars: where the first starts, how far apart they are, how wide a bar is.
const COLUMN_X := BAR_X + 60 + 5
const COLUMN := 10
const COLUMN_BAR := 5
## The standing bars in their order: what, its picture, its colour.
const COLUMNS := [
	["satiety", "food", UiStyle.ACCENT],
	["water", "water", UiStyle.COLD],
	["warmth", "thermo", UiStyle.INK],
	["energy", "sleep", UiStyle.MUTED],
]
## How long the panel stays after a noticeable change, seconds; and what counts as one.
const LINGER := 3.0
const NOTICE := 4.0
## Below these the state is shown all the time (and the bar is red).
const LOW := {"health": 60.0, "satiety": Vitals.HUNGRY + 5.0, "stamina": 30.0, "water": Vitals.THIRSTY + 5.0, "energy": Vitals.SLEEPY + 5.0}
const WATCHED := ["health", "stamina", "satiety", "water", "warmth", "energy"]
## What hinders the body, by its picture, top to bottom of the last column.
const DEBUFFS := {"wet": "drop", "tired": "bolt", "heavy": "weight"}
## Wetter than this shows the drop, and keeps the panel up.
const WET_SHOWN := 0.05
## How far apart the pictures of the last column stand, top to top.
const DEBUFF_ROW := 10

## Keep it shown whatever the state.
var pinned := false
var _values := {}
var _shown := {}
var _linger := 0.0
## What hinders the body now (keys of DEBUFFS, in their order).
var debuffs: Array = []
## The standing bars shown now (their keys, in the order of COLUMNS).
var columns: Array = []
var _canvas: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.TIGHT))
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_state)
	add_child(_canvas)
	_fit()
	visible = false


## Takes the state of `vitals` for this frame, and whether the bag is over its limit.
func update(vitals, delta: float, overloaded := false) -> void:
	var low := false
	for k: String in WATCHED:
		var v: float = vitals.get(k)
		_values[k] = v
		if absf(v - _shown.get(k, v)) >= NOTICE:
			_linger = LINGER
		if absf(v - _shown.get(k, -100.0)) >= 1.0:
			_shown[k] = v
			_canvas.queue_redraw()
		low = low or critical(k, v)
	var wet: float = vitals.wet
	if absf(wet - _values.get("wet", 0.0)) >= 0.05 or (wet > 0.0) != (_values.get("wet", 0.0) > 0.0):
		_values["wet"] = wet
		_canvas.queue_redraw()
	var now := debuffs_of(vitals, overloaded)
	var shown_columns := []
	for c in COLUMNS:
		if pinned or critical(c[0], _values[c[0]]):
			shown_columns.append(c[0])
	if now != debuffs or shown_columns != columns:
		debuffs = now
		columns = shown_columns
		_fit()
		_canvas.queue_redraw()
	low = low or not debuffs.is_empty()
	_linger = maxf(0.0, _linger - delta)
	visible = pinned or low or _linger > 0.0


## Whether `value` of state `what` is low enough to show all the time: hungry, thirsty,
## sleepy soon, too cold or hot.
static func critical(what: String, value: float) -> bool:
	if what == "warmth":
		return value < Vitals.COLD or value > Vitals.HOT
	return value < LOW[what]


## What hinders a body of `vitals` (keys of DEBUFFS, in their order): wet, out of breath
## (it walks slower, Vitals.TIRED), carrying more than it can (`overloaded`).
static func debuffs_of(vitals, overloaded: bool) -> Array:
	var out := []
	if vitals.wet > WET_SHOWN:
		out.append("wet")
	if vitals.stamina < Vitals.TIRED:
		out.append("tired")
	if overloaded:
		out.append("heavy")
	return out


## The panel as wide as its bars, the standing ones shown and, when something hinders
## the body, its column.
func _fit() -> void:
	var n := columns.size() + (0 if debuffs.is_empty() else 1)
	var w := BAR_X + int(HEALTH.size.x) if n == 0 else COLUMN_X + (n - 1) * COLUMN + 9
	_canvas.custom_minimum_size = Vector2(w, HEIGHT)
	_canvas.size = _canvas.custom_minimum_size
	reset_size()


func _draw_state() -> void:
	var health: float = _values.get("health", Vitals.MAX)
	_row(HEALTH_Y, "heart", HEALTH, health / Vitals.MAX, UiStyle.DANGER)
	var stamina: float = _values.get("stamina", Vitals.MAX)
	_row(STAMINA_Y, "bolt", STAMINA, stamina / Vitals.MAX, UiStyle.DANGER if stamina < Vitals.TIRED else UiStyle.GOOD)
	var x := COLUMN_X
	for c in COLUMNS:
		if not c[0] in columns:
			continue
		var v: float = _values.get(c[0], Vitals.MAX if c[0] != "warmth" else Vitals.COMFORT)
		var share := v / Vitals.MAX
		var color: Color = c[2]
		match c[0]:
			"satiety":
				color = UiStyle.DANGER if v < Vitals.HUNGRY else color
			"water":
				color = UiStyle.DANGER if v < Vitals.THIRSTY else color
			"energy":
				color = UiStyle.DANGER if v < Vitals.SLEEPY else color
			"warmth":
				share = v / Vitals.COMFORT
				if v < Vitals.COLD:
					color = UiStyle.COLD
				elif v > Vitals.HOT:
					color = UiStyle.DANGER
		_column(x, c[1], share, color)
		x += COLUMN
	var y := 0
	for d: String in debuffs:
		# The drop is the clearer the wetter the body.
		var tint := Color(1, 1, 1, lerpf(0.4, 1.0, _values.get("wet", 0.0))) if d == "wet" else Color.WHITE
		_canvas.draw_texture(ItemIcons.picture(DEBUFFS[d]), Vector2(x, y), tint)
		y += DEBUFF_ROW


## A standing bar at `x` under picture `icon`, filled `share` from the bottom.
func _column(x: int, icon: String, share: float, color: Color) -> void:
	_canvas.draw_texture(ItemIcons.picture(icon), Vector2(x, 0))
	var top := 10
	var r := Rect2(x + 2, top, COLUMN_BAR, HEIGHT - top)
	_canvas.draw_rect(r, UiStyle.WELL)
	var full := roundf(r.size.y * clampf(share, 0.0, 1.0))
	_canvas.draw_rect(Rect2(r.position.x, r.end.y - full, COLUMN_BAR, full), color)


## A lying bar `bar` with picture `icon` at height `y` left of it, filled `share`.
func _row(y: int, icon: String, bar: Rect2, share: float, color: Color) -> void:
	_canvas.draw_texture(ItemIcons.picture(icon), Vector2(0, y))
	_canvas.draw_rect(bar, UiStyle.WELL)
	_canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(share, 0.0, 1.0)), bar.size.y)), color)
