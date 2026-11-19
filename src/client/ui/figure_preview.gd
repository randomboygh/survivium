extends Control
## The character drawn big (the «Персонаж» tab of «Новая игра», «Создать сервер» and
## «Присоединиться», CharacterPage): the figure's sheet (Figure) in look `look`
## (Figure.dressed) in the colours of the looks picked (paint), breathing (its `idle`
## frames), `pixels` screen pixels a pixel of it.
## A finger or the mouse dragged across turns it through the eight directions (a step
## each TURN_DRAG pixels, the front following the finger); a tap on its left or right
## half turns it a step that way; `turn` does it from keys. It stands on a round stand
## (_draw_stand) that swings round with it, a lit mark at its front. The sheet is built a few parts of
## a row a frame (Figure.step, BUILD_BUDGET_US), so opening the tab never stops the menu for a frame of its own.

const Figure := preload("res://src/client/view/figure.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const PreviewShader := preload("res://shaders/figure_preview.gdshader")

## Pixels of drag that turn it a step.
const TURN_DRAG := 24.0
## Time the building of the sheet may take a frame, in microseconds.
const BUILD_BUDGET_US := 3000
## The direction it faces at first: three quarters, as the camera sees the world.
const FIRST := "se"
## The round stand it turns on, in the figure's pixels: half its width and depth across
## the top, how deep its side is, and how far under the frame's bottom row it reaches
## (room kept for it below the frame).
const STAND_RX := 11
const STAND_RY := 4
const STAND_SIDE := 2
const STAND_BELOW := STAND_RY + STAND_SIDE + 1
## Its colours: the top, its rim, the side, the marks that show it turn, and the one at
## the front.
const STAND_TOP := Color("#c9b896")
const STAND_RIM := Color("#a8956f")
const STAND_SIDE_COLOR := Color("#5b4630")
const STAND_MARK := Color("#8a7756")
const STAND_FRONT := Color("#e9b44c")
## How fast the stand swings to the way the figure faces (the figure turns at once).
const STAND_SPEED := 14.0
## The way each direction faces on the screen (x right, y down: south towards the viewer).
const WAYS := {"s": Vector2(0, 1), "sw": Vector2(-1, 1), "w": Vector2(-1, 0), "nw": Vector2(-1, -1),
	"n": Vector2(0, -1), "ne": Vector2(1, -1), "e": Vector2(1, 0), "se": Vector2(1, 1)}

var look: Array = []
var pixels := 4
## The part of the frame drawn, in its pixels (the figure's frame, Figure.data: the room
## round the body that only the things held reach can be left out to draw it bigger);
## empty: the whole frame. Its bottom is the frame's: the stand stays under the feet.
var crop := Rect2i()
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
## The angle the stand shows (radians on the screen), swinging to the facing's.
var _stand := WAYS[FIRST].angle()


func _init(worn := [], scale_px := 4, part := Rect2i()) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crop = part
	set_pixels(scale_px)
	dress(worn if not worn.is_empty() else Figure.dressed({}))


## Draws it `scale_px` screen pixels a pixel of it.
func set_pixels(scale_px: int) -> void:
	pixels = scale_px
	var part := shown()
	custom_minimum_size = Vector2(part.size.x, part.size.y + STAND_BELOW) * pixels
	queue_redraw()


## The part of the frame drawn (crop, else the whole frame), in its pixels.
func shown() -> Rect2i:
	if crop.has_area():
		return crop
	var frame: Array = Figure.data().frame
	return Rect2i(0, 0, frame[0], frame[1])


## Shows the figure in look `worn`: the sheet is built anew over the next frames.
func dress(worn: Array) -> void:
	if worn == look and (sheet != null or _build != null):
		return
	look = worn
	_build = Figure.new(look, {})


## Shows the colours of the character's looks `looks` (Looks, Figure.paint): swapped by
## its shader, the sheet stays.
func paint(looks: Dictionary) -> void:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = PreviewShader
	Figure.paint(material, looks)


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
	# Hidden (a tab or a window not shown) it neither builds nor breathes.
	if not is_visible_in_tree():
		return
	var t0 := Time.get_ticks_usec()
	while _build != null and Time.get_ticks_usec() - t0 < BUILD_BUDGET_US:
		if _build.step():
			sheet = _build.target
			_build = null
	_time += delta
	_stand = lerp_angle(_stand, WAYS[facing()].angle(), minf(delta * STAND_SPEED, 1.0))
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
	var part := shown()
	# A frame drawn mirrored shows the other side of its picture.
	var left: float = part.position.x if f.z != 1 else fs.x - part.end.x
	var src := Rect2(Vector2(f.x, f.y) * fs + Vector2(left, part.position.y), Vector2(part.size))
	var drawn := Vector2(part.size) * pixels
	# The part drawn and the stand under it, centred together.
	var whole := Vector2(part.size.x, part.size.y + STAND_BELOW) * pixels
	var at := ((size - whole) * 0.5).floor()
	_draw_stand(at + (Vector2(fs.x * 0.5, fs.y - 1.0) - Vector2(part.position)) * pixels)
	if f.z == 1:
		draw_set_transform(at + Vector2(drawn.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	else:
		draw_set_transform(at)
	draw_texture_rect_region(sheet.texture, Rect2(Vector2.ZERO, drawn), src)
	draw_set_transform(Vector2.ZERO)


## The round stand under the feet (its top's centre at `centre`), drawn in the figure's
## pixels: a top with a rim, a side under it, and eight marks round it, the front one
## lit, turned by `_stand` so the stand turns with the figure.
func _draw_stand(centre: Vector2) -> void:
	var marks := {}
	for k in 8:
		var a := _stand + k * TAU / 8.0
		var p := Vector2i(roundi(cos(a) * (STAND_RX - 2)), roundi(sin(a) * (STAND_RY - 1)))
		# The front's mark wins a pixel two share.
		if k == 0 or not marks.has(p):
			marks[p] = STAND_FRONT if k == 0 else STAND_MARK
	for y in range(-STAND_RY, STAND_RY + STAND_SIDE + 1):
		for x in range(-STAND_RX, STAND_RX + 1):
			var c := _stand_pixel(x, y, marks)
			if c.a > 0.0:
				draw_rect(Rect2(centre + Vector2(x - 0.5, y) * pixels, Vector2.ONE * pixels), c)


## The colour of the stand's pixel (x, y) from its top's centre (none: clear).
func _stand_pixel(x: int, y: int, marks: Dictionary) -> Color:
	var on_top := _inside(x, y)
	if on_top:
		if not _inside(x, y + 1) or not _inside(x - 1, y) or not _inside(x + 1, y) or not _inside(x, y - 1):
			return STAND_RIM
		return marks.get(Vector2i(x, y), STAND_TOP)
	for d in range(1, STAND_SIDE + 1):
		if _inside(x, y - d) and y > 0:
			return STAND_SIDE_COLOR
	return Color(0, 0, 0, 0)


## Whether (x, y) is on the stand's top, an ellipse STAND_RX by STAND_RY.
func _inside(x: int, y: int) -> bool:
	var fx := float(x) / (STAND_RX + 0.5)
	var fy := float(y) / (STAND_RY + 0.5)
	return fx * fx + fy * fy <= 1.0
