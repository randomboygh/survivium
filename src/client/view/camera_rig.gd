extends RefCounted
## The pixel-perfect view: the low-resolution SubViewport the 3D scene renders into,
## the colour grade over it, the upscale, the orthographic camera that
## follows the player, and the part of the screen the interface may use (the safe
## rect under browser toolbars). `game` is the Main node that owns the scene.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const GradeShader := preload("res://shaders/grade.gdshader")

const CELL := WorldData.CELL
const CAMERA_HEIGHT := PixelView.CAMERA_HEIGHT
## The camera turns round in steps of 15 degrees and tilts by 5 degrees, three steps
## each way from the default view (PixelView.MAX_TILT).
const TURN_STEP := PI / 12.0
const TURNS := 24
const TILT_STEP := PI / 36.0
const TILTS := 3
## How fast the view glides to the one set: the share of the way left gone a second.
const TURN_RATE := 9.0
## Seconds a shake lasts.
const SHAKE_TIME := 0.3

var game
var container: SubViewportContainer
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var grade_mat: ShaderMaterial
var image_size := Vector2i(640, 360)
## Wanted height of the low-res image; the pixel size setting lowers it.
var target_height := PixelView.TARGET_HEIGHT
## How many screen pixels a low-res pixel takes (a fraction on a phone, see PixelView.layout).
var view_scale := 1.0
var safe_rect := Rect2()
## A phone or a tablet: the view and the interface scale by fractions (see turns);
## tools and tests set it to lay a computer's window out as a phone.
var turning := turns()
var safe_clock := 0.0
## Screen-plane point the camera follows smoothly (see PixelView.screen_plane).
var cam_target := Vector2.ZERO
## The view set, in steps (the turn counts on past a whole turn, so it always glides
## the short way), and the one drawn now, gliding to it, in radians.
var turn_steps := 0
var tilt_steps := 0
var turn := 0.0
var tilt := 0.0
## A shake of the picture (see shake): how far, in low-res pixels, and its seconds left.
var _shake := 0.0
var _shake_left := 0.0


func _init(g) -> void:
	game = g


## Puts the viewport with the colour grade under `parent`; the 3D scene goes into
## `world_root`.
func build(parent: Node) -> void:
	container = SubViewportContainer.new()
	container.stretch = false
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_mat = ShaderMaterial.new()
	grade_mat.shader = GradeShader
	container.material = grade_mat
	parent.add_child(container)
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)


func build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = PixelView.camera_size(image_size.y)
	camera.near = 1.0
	camera.far = CAMERA_HEIGHT + 10.0
	world_root.add_child(camera)
	camera.current = true


## Starts the camera over the player, turned and tilted as last set.
func look_at_player() -> void:
	turn_steps = posmod(int(game.settings.values.camera_turn), TURNS)
	tilt_steps = clampi(int(game.settings.values.camera_tilt), -TILTS, TILTS)
	turn = turn_steps * TURN_STEP
	tilt = tilt_steps * TILT_STEP
	PixelView.set_view(turn, tilt)
	_aim()
	cam_target = PixelView.screen_plane(game.player.position + Vector3(0.0, 0.5, 0.0))


## Turns the camera `steps` steps of TURN_STEP to the left (negative: right).
func turn_by(steps: int) -> void:
	turn_steps += steps
	_aim()


## Tilts the camera `steps` steps of TILT_STEP steeper (negative: lower), within TILTS.
func tilt_by(steps: int) -> void:
	tilt_steps = clampi(tilt_steps + steps, -TILTS, TILTS)
	_aim()


## Back to the default view, turning the short way.
func reset_turn() -> void:
	turn_steps = roundi(turn_steps / float(TURNS)) * TURNS
	tilt_steps = 0
	_aim()


func is_default() -> bool:
	return posmod(turn_steps, TURNS) == 0 and tilt_steps == 0


## The turn set, in whole degrees to the left of north, 0..345.
func turn_degrees() -> int:
	return posmod(turn_steps, TURNS) * 15


## A new view is set: the chunks get culling boxes that hold what they draw all the
## way there (a box per step of the way), and the setting is kept.
func _aim() -> void:
	var to := turn_steps * TURN_STEP
	var to_tilt := tilt_steps * TILT_STEP
	var views := [PixelView.view_of(turn, tilt)]
	var n := maxi(1, ceili(absf(to - turn) / TURN_STEP))
	for i in range(1, n + 1):
		views.append(PixelView.view_of(lerpf(turn, to, i / float(n)), lerpf(tilt, to_tilt, i / float(n))))
	PixelView.box_views = views
	if game.chunks != null:
		game.chunks.refit_boxes()
	var values: Dictionary = game.settings.values
	if values.camera_turn != posmod(turn_steps, TURNS) or values.camera_tilt != tilt_steps:
		values.camera_turn = posmod(turn_steps, TURNS)
		values.camera_tilt = tilt_steps
		game.settings.save()


## Glides the drawn view to the one set; once there, the culling boxes hold that view
## alone again.
func _glide(delta: float) -> void:
	var to := turn_steps * TURN_STEP
	var to_tilt := tilt_steps * TILT_STEP
	if turn == to and tilt == to_tilt:
		return
	var k := minf(1.0, delta * TURN_RATE)
	turn = lerpf(turn, to, k)
	tilt = lerpf(tilt, to_tilt, k)
	if absf(turn - to) < 0.002 and absf(tilt - to_tilt) < 0.0005:
		turn = to
		tilt = to_tilt
		# The turn counts round from 0 again, as it was set.
		var round_turns := floori(turn_steps / float(TURNS)) * TURNS
		turn_steps -= round_turns
		turn = turn_steps * TURN_STEP
		PixelView.box_views = [PixelView.view_of(turn, tilt)]
		if game.chunks != null:
			game.chunks.refit_boxes()
	var before := PixelView.screen_plane(game.player.position + Vector3(0.0, 0.5, 0.0))
	PixelView.set_view(turn, tilt)
	# The camera keeps the lag it had behind the player, in the new view.
	cam_target += PixelView.screen_plane(game.player.position + Vector3(0.0, 0.5, 0.0)) - before


func on_screen_resized() -> void:
	var screen: Vector2 = game.get_viewport().get_visible_rect().size
	var view: Array = PixelView.layout(screen, target_height, turning)
	var scale: float = view[0]
	# A margin of pixels around the screen leaves room for the sub-pixel camera shift.
	image_size = view[1] + Vector2i(2, 2) * PixelView.MARGIN
	view_scale = scale
	viewport.size = image_size
	container.size = Vector2(image_size)
	container.scale = Vector2(scale, scale)
	container.position = (-Vector2.ONE * PixelView.MARGIN * scale).round()
	if camera != null:
		camera.size = PixelView.camera_size(image_size.y)
	layout_ui(_safe_rect())


## A screen held either way (a phone or a tablet): the world is as large in both.
static func turns() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func layout_ui(rect: Rect2) -> void:
	safe_rect = rect
	game.hud.fit(rect, turning, game.get_viewport().get_visible_rect().size)


## The part of the screen the player can see. Mobile browsers can lay the page out
## under their toolbars, so on the web this is the canvas clipped to the browser's
## visual viewport; elsewhere it is the whole window.
func _safe_rect() -> Rect2:
	var full: Rect2 = Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	if not OS.has_feature("web"):
		return full
	var js: Variant = JavaScriptBridge.eval("""(function () {
		var c = document.querySelector('canvas'), v = window.visualViewport;
		if (!c || !v) return '';
		var b = c.getBoundingClientRect();
		if (b.width <= 0 || b.height <= 0) return '';
		var k = c.width / b.width;
		var x0 = Math.max(b.left, v.offsetLeft), y0 = Math.max(b.top, v.offsetTop);
		var x1 = Math.min(b.right, v.offsetLeft + v.width), y1 = Math.min(b.bottom, v.offsetTop + v.height);
		return [(x0 - b.left) * k, (y0 - b.top) * k, (x1 - x0) * k, (y1 - y0) * k].join(',');
	})()""", true)
	if typeof(js) != TYPE_STRING or js == "":
		return full
	var v: PackedFloat64Array = String(js).split_floats(",")
	if v.size() != 4:
		return full
	var r := full.intersection(Rect2(v[0], v[1], v[2], v[3]))
	return r if r.size.x > 100.0 and r.size.y > 100.0 else full


## Browsers do not always report toolbars appearing or hiding, so the visible part
## of the screen is re-checked twice a second.
func poll_safe_rect(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	safe_clock += delta
	if safe_clock < 0.5:
		return
	safe_clock = 0.0
	var r := _safe_rect()
	if not r.is_equal_approx(safe_rect):
		layout_ui(r)


## Where world point `p` is on the screen, in screen pixels (as drawn this frame).
func screen_of(p: Vector3) -> Vector2:
	var offset := (PixelView.screen_plane(p) - cam_target) * PixelView.PIXELS_PER_UNIT
	return (Vector2(image_size) / 2.0 - Vector2.ONE * PixelView.MARGIN + offset) * view_scale


## The camera renders from a whole pixel; the leftover fraction of a pixel shifts the
## upscaled image, so the view glides smoothly while the pixel art stays on its grid.
func update(delta: float) -> void:
	if camera == null:
		return
	var player = game.player
	_glide(delta)
	var target: Vector2 = PixelView.screen_plane(player.position + Vector3(0.0, 0.5, 0.0))
	cam_target = cam_target.lerp(target, minf(1.0, delta * 6.0))
	var snapped := PixelView.snap_plane(cam_target)
	var frac := (cam_target - snapped) * PixelView.PIXELS_PER_UNIT
	if _shake_left > 0.0:
		# Whole pixels of the camera, so the picture shakes on its grid and nothing past
		# the rendered image shows.
		_shake_left = maxf(0.0, _shake_left - delta)
		var k := _shake * _shake_left / SHAKE_TIME
		snapped += Vector2(randf_range(-k, k), randf_range(-k, k)).round() / PixelView.PIXELS_PER_UNIT
	camera.global_transform = PixelView.camera_transform(snapped)
	grade_mat.set_shader_parameter("view_origin", snapped * PixelView.PIXELS_PER_UNIT - Vector2(image_size) / 2.0)
	container.position = (-Vector2.ONE * PixelView.MARGIN - frac) * view_scale
	container.position = container.position.round()
	player.place_sprite()
	RenderingServer.global_shader_parameter_set("player_pos", player.position)
	# The levels below fade from the player's feet, or from a level picked by hand.
	var manual_level: int = game.chunks.manual_level
	if manual_level >= 0:
		RenderingServer.global_shader_parameter_set("view_height", (manual_level + 1) * CELL)
	elif player.body.on_ground or player.body.swimming:
		RenderingServer.global_shader_parameter_set("view_height", player.level() * CELL)


## Shakes the picture by up to `pixels` low-res pixels for a moment, fading.
func shake(pixels: float) -> void:
	_shake = maxf(pixels, _shake if _shake_left > 0.0 else 0.0)
	_shake_left = SHAKE_TIME
