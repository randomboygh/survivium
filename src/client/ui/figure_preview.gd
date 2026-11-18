extends Control
## The character drawn big (the «Персонаж» tab of «Новая игра», «Создать сервер» and
## «Присоединиться», CharacterPage): the figure's sheet (Figure) in look `look`
## (Figure.dressed), breathing (its `idle` frames), `pixels` screen pixels a pixel of it.
## A finger or the mouse dragged across turns it through the eight directions (a step
## each TURN_DRAG pixels, the front following the finger); a tap on its left or right
## half turns it a step that way; `turn` does it from keys. The sheet is built a few parts of
## a row a frame (Figure.step, BUILD_BUDGET_US), so opening the tab never stops the menu for a frame of its own.

const Figure := preload("res://src/client/view/figure.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")

## Pixels of drag that turn it a step.
const TURN_DRAG := 24.0
## Time the building of the sheet may take a frame, in microseconds.
const BUILD_BUDGET_US := 3000
## The direction it faces at first: three quarters, as the camera sees the world.
const FIRST := "se"

var look: Array = []
var pixels := 4
## The sheet shown; null until built.
var sheet: SpriteSheet = null
## The figure being built (Figure), null when done.
var _build = null
var _dir := SpriteSheet.COMPASS.find(FIRST)
var _time := 0.0
## Where a press began (x) and whether it has turned the figure since.
var _from := 0.0
var _down := false
var _dragged := false


func _init(worn := [], scale_px := 4) -> void:
	pixels = scale_px
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame: Array = Figure.data().frame
	custom_minimum_size = Vector2(frame[0], frame[1]) * pixels
	dress(worn if not worn.is_empty() else Figure.dressed({}))


## Shows the figure in look `worn`: the sheet is built anew over the next frames.
func dress(worn: Array) -> void:
	look = worn
	_build = Figure.new(look, {})


## The direction it faces (SpriteSheet.COMPASS).
func facing() -> String:
	return SpriteSheet.COMPASS[_dir]


## Turns it `steps` eighths: positive brings its front to the right of the screen.
func turn(steps: int) -> void:
	# COMPASS goes clockwise from the south (as seen from above): a front moving right
	# of the screen goes the other way.
	_dir = posmod(_dir - steps, SpriteSheet.COMPASS.size())
	queue_redraw()


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	while _build != null and Time.get_ticks_usec() - t0 < BUILD_BUDGET_US:
		if _build.step():
			sheet = _build.target
			_build = null
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_from = event.position.x
			_down = true
			_dragged = false
		elif _down:
			_down = false
			if not _dragged:
				turn(1 if event.position.x >= size.x * 0.5 else -1)
		accept_event()
	elif event is InputEventMouseMotion and _down:
		var dx: float = event.position.x - _from
		while absf(dx) >= TURN_DRAG:
			var s := 1 if dx > 0.0 else -1
			turn(s)
			_from += s * TURN_DRAG
			dx -= s * TURN_DRAG
			_dragged = true
		accept_event()


func _draw() -> void:
	if sheet == null or sheet.texture == null:
		return
	var f := sheet.frame_at(facing(), "idle", _time)
	var fs := Vector2(sheet.frame_size)
	var src := Rect2(Vector2(f.x, f.y) * fs, fs)
	var drawn := fs * pixels
	var at := ((size - drawn) * 0.5).floor()
	if f.z == 1:
		draw_set_transform(at + Vector2(drawn.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	else:
		draw_set_transform(at)
	draw_texture_rect_region(sheet.texture, Rect2(Vector2.ZERO, drawn), src)
	draw_set_transform(Vector2.ZERO)
