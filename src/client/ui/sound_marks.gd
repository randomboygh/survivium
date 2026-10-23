extends Control
## Faint marks at the edge of the screen on the side an important sound came from
## (decision 89: a predator's voice off the screen), fading in a moment. Over the whole
## interface rect, under the rest of it. `game` is the Main node; Voices calls show_at.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Seconds a mark lasts, and how strong it starts.
const LIFE := 2.5
const ALPHA := 0.55
## UI pixels from the edge, and the mark's size: an arc of a ring round the screen's
## middle, so it says the side, not the place.
const INSET := 10.0
const LENGTH := 22.0
const WIDTH := 3.0

var game
## The marks shown: {"pos": world point, "age": seconds}.
var _marks := []


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Shows a mark for a sound from world point `pos` when it is off the screen.
func show_at(pos: Vector3) -> void:
	if Rect2(Vector2.ZERO, size).has_point(_local(pos)):
		return
	for m in _marks:
		if m.pos.distance_to(pos) < 4.0:
			m.age = 0.0
			return
	_marks.append({"pos": pos, "age": 0.0})
	queue_redraw()


func _local(pos: Vector3) -> Vector2:
	var t := get_global_transform()
	return (game.view.screen_of(pos) - t.origin) / t.get_scale()


func _process(delta: float) -> void:
	if _marks.is_empty():
		return
	for m in _marks.duplicate():
		m.age += delta
		if m.age >= LIFE:
			_marks.erase(m)
	queue_redraw()


func _draw() -> void:
	var mid := size * 0.5
	var half := mid - Vector2(INSET, INSET)
	if half.x <= 0.0 or half.y <= 0.0:
		return
	for m in _marks:
		var dir: Vector2 = (_local(m.pos) - mid).normalized()
		if dir == Vector2.ZERO:
			continue
		# Where the way to the sound leaves the rect, kept inside it.
		var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var at := mid + dir * k
		var side := Vector2(-dir.y, dir.x)
		var t: float = m.age / LIFE
		var c := UiStyle.DANGER
		c.a = ALPHA * (1.0 - t) * minf(m.age / 0.15, 1.0)
		draw_line(at - side * LENGTH * 0.5, at + side * LENGTH * 0.5, c, WIDTH)
		var inner := c
		inner.a *= 0.5
		draw_line(at - side * LENGTH * 0.3 - dir * 4.0, at + side * LENGTH * 0.3 - dir * 4.0, inner, WIDTH - 1.0)
