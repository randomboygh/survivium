extends MeshInstance3D
## The fishing line of a figure (Player: its `line_at`), drawn while its float lies on
## the water: a one-pixel line from the tip of the rod held out, sagging a little, down to
## a float, red above white, two pixels wide, that bobs on the water and goes under
## while a fish bites (`bite`). Lines of the world's pixels (fishing_line.gdshader).

const PixelView := preload("res://src/client/view/pixel_view.gd")
const LineShader := preload("res://shaders/fishing_line.gdshader")

## The line's colour, the float's top and its bottom.
const CORD := Color(0.86, 0.86, 0.8)
const TOP := Color(0.85, 0.16, 0.14)
const BOTTOM := Color(0.95, 0.95, 0.9)
## How far the line sags at its middle, in world units, and the pieces it is drawn in.
const SAG := 0.12
const PIECES := 8
## The float's height over the water and under it, in pixels; how far it sinks while
## a fish bites, and how often it bobs, in seconds.
const FLOAT_UP := 3
const FLOAT_DOWN := 1
const SINK := 3
const BOB := 1.4

var _lines := ImmediateMesh.new()


func _init() -> void:
	mesh = _lines
	var m := ShaderMaterial.new()
	m.shader = LineShader
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	extra_cull_margin = 16.0
	visible = false


## Draws the line from world point `tip` to the float at `at` (on the water), the float
## under while `bite`; hidden when `at` is INF.
func show_line(tip: Vector3, at: Vector3, bite: bool) -> void:
	visible = at.is_finite()
	if not visible:
		return
	var px := 1.0 / PixelView.PIXELS_PER_UNIT
	var tall := px / maxf(PixelView.slope, 0.2)
	var t := Time.get_ticks_msec() / 1000.0
	var dip := 0.0
	if bite:
		# Pulled under in jerks.
		dip = SINK if fmod(t, 0.5) < 0.35 else SINK - 1
	elif fmod(t, BOB) < BOB * 0.5:
		dip = 1
	var top := at + Vector3(0.0, (FLOAT_UP - dip) * tall, 0.0)
	_lines.clear_surfaces()
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	# The line, a little slack.
	var last := tip
	for i in range(1, PIECES + 1):
		var k := float(i) / PIECES
		var p := tip.lerp(top, k) - Vector3(0.0, SAG * 4.0 * k * (1.0 - k), 0.0)
		_lines.surface_set_color(CORD)
		_lines.surface_add_vertex(last)
		_lines.surface_set_color(CORD)
		_lines.surface_add_vertex(p)
		last = p
	# The float: two columns a pixel apart, across the screen.
	var side := Vector3(PixelView.right.x, 0.0, PixelView.right.y) * px
	var water := at.y
	for c in 2:
		var x := at + side * (c - 0.5)
		var from := Vector3(x.x, water - (FLOAT_DOWN - minf(dip, FLOAT_DOWN)) * tall, x.z)
		var mid := Vector3(x.x, water + (1.0 - dip) * tall, x.z)
		var to := Vector3(x.x, top.y, x.z)
		if mid.y > from.y:
			_lines.surface_set_color(BOTTOM)
			_lines.surface_add_vertex(from)
			_lines.surface_set_color(BOTTOM)
			_lines.surface_add_vertex(mid)
		_lines.surface_set_color(TOP)
		_lines.surface_add_vertex(maxf(mid.y, from.y) * Vector3.UP + Vector3(x.x, 0.0, x.z))
		_lines.surface_set_color(TOP)
		_lines.surface_add_vertex(to)
	_lines.surface_end()
