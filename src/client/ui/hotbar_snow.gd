extends Control
## Snow settling on the hotbar while it snows outside (AirEffects.hotbar_snow, 0..1): a
## cap of drifts along its top edge, lumpy, higher the deeper, melting away in the warm.
## A child of the hotbar's panel, drawn over it; touches pass through. `game` is the
## Main node.

## The highest a drift grows over the panel's top edge, UI px, and the width of a
## column of it.
const HIGH := 10.0
const STEP := 2.0
## How far in from each end of the panel the drifts slope down to nothing, UI px.
const TAPER := 22.0
const SNOW := Color(0.94, 0.97, 1.0)
const SHADE := Color(0.72, 0.82, 0.93)

var game
var _depth := 0.0


func _init(g) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var air = game.effects.air if game.effects != null else null
	var depth: float = snappedf(air.hotbar_snow, 0.02) if air != null else 0.0
	if depth != _depth:
		_depth = depth
		queue_redraw()


func _draw() -> void:
	if _depth <= 0.0:
		return
	var panel := Rect2(-position, get_parent().size)
	var top := panel.position.y
	var x := panel.position.x + 2.0
	while x < panel.end.x - 2.0:
		var i := x / STEP
		# Drifts: two slow waves and a little roughness, all still with the depth.
		var lump := 0.55 + 0.3 * sin(i * 0.21 + 1.3) + 0.15 * sin(i * 0.67) + 0.1 * (fposmod(i * 7.31, 1.0) - 0.5)
		# Sloping down to nothing at the ends, as snow does off a ledge.
		var w := minf(STEP, panel.end.x - 2.0 - x)
		var end_k := clampf(minf(x - panel.position.x, panel.end.x - x - w) / TAPER, 0.0, 1.0)
		end_k = end_k * (2.0 - end_k)
		var h := roundf((HIGH * _depth * clampf(lump, 0.2, 1.0) + 1.0) * end_k)
		if h >= 1.0:
			draw_rect(Rect2(x, top - h + 2.0, w, h), SNOW)
			draw_rect(Rect2(x, top + 2.0, w, 1.0), SHADE)
		x += STEP
