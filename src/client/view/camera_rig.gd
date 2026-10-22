extends RefCounted
## The pixel-perfect view: the low-resolution SubViewport the 3D scene renders into,
## the colour grade over it, the whole-number upscale, the orthographic camera that
## follows the player, and the part of the screen the interface may use (the safe
## rect under browser toolbars). `game` is the Main node that owns the scene.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const GradeShader := preload("res://shaders/grade.gdshader")

const CELL := WorldData.CELL
const CAMERA_HEIGHT := PixelView.CAMERA_HEIGHT

var game
var container: SubViewportContainer
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var grade_mat: ShaderMaterial
var image_size := Vector2i(640, 360)
## Wanted height of the low-res image; the pixel size setting lowers it.
var target_height := PixelView.TARGET_HEIGHT
var view_scale := 1
var safe_rect := Rect2()
var safe_clock := 0.0
## Screen-plane point the camera follows smoothly (see PixelView.screen_plane).
var cam_target := Vector2.ZERO


func _init(g) -> void:
	game = g


## Puts the viewport with the colour grade under `parent`; the 3D scene goes into
## `world_root`.
func build(parent: Node) -> void:
	container = SubViewportContainer.new()
	container.stretch = true
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


## Starts the camera over the player.
func look_at_player() -> void:
	cam_target = PixelView.screen_plane(game.player.position + Vector3(0.0, 0.5, 0.0))


func on_screen_resized() -> void:
	var screen: Vector2 = game.get_viewport().get_visible_rect().size
	var view: Array = PixelView.layout(screen, target_height)
	var scale: int = view[0]
	# A margin of pixels around the screen leaves room for the sub-pixel camera shift.
	image_size = view[1] + Vector2i(2, 2) * PixelView.MARGIN
	view_scale = scale
	container.stretch_shrink = scale
	container.position = -Vector2.ONE * PixelView.MARGIN * scale
	container.size = Vector2(image_size * scale)
	if camera != null:
		camera.size = PixelView.camera_size(image_size.y)
	layout_ui(_safe_rect())


func layout_ui(rect: Rect2) -> void:
	safe_rect = rect
	game.hud.fit(rect)


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


## The camera renders from a whole pixel; the leftover fraction of a pixel shifts the
## upscaled image, so the view glides smoothly while the pixel art stays on its grid.
func update(delta: float) -> void:
	if camera == null:
		return
	var player = game.player
	var target: Vector2 = PixelView.screen_plane(player.position + Vector3(0.0, 0.5, 0.0))
	cam_target = cam_target.lerp(target, minf(1.0, delta * 6.0))
	var snapped := PixelView.snap_plane(cam_target)
	camera.global_transform = PixelView.camera_transform(snapped)
	grade_mat.set_shader_parameter("view_origin", snapped * PixelView.PIXELS_PER_UNIT - Vector2(image_size) / 2.0)
	var frac := (cam_target - snapped) * PixelView.PIXELS_PER_UNIT
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
