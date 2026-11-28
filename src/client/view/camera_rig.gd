extends RefCounted
## The pixel-perfect view: the low-resolution SubViewport the 3D scene renders into,
## the colour grade over it, the upscale, the orthographic camera that
## follows the player, and the part of the screen the interface may use (the safe
## rect under browser toolbars). `game` is the Main node that owns the scene.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const GradeShader := preload("res://shaders/grade.gdshader")
const Crt := preload("res://src/client/view/crt.gd")

const CELL := WorldData.CELL
const CAMERA_HEIGHT := PixelView.CAMERA_HEIGHT
## The camera turns round in steps of 45 degrees (the four sides and the diagonals)
## and tilts in steps from the default view, a step making a wall 2 px shorter: STEEPER
## steps up and LOWER down, 2 to 16 px a cell under an 8 px top (a wall never drops to
## 0 px: the camera looking straight down would draw upright things as lines).
const TURN_STEP := PixelView.TURN_STEP
const TURNS := 8
const TILT_STEP := PixelView.TILT_STEP
const STEEPER := 3
const LOWER := 4
## The views on the way that the culling boxes hold, this far apart: a turn sweeps
## the drawn heights round an arc, which the boxes of its ends alone would cut.
const BOX_STEP := PI / 12.0
## While it turns on by itself (held or drifting) the boxes hold the views this far
## ahead, and are fitted again once it gets there: boxes for the whole way round grew
## every chunk's by its heights' shear all round and drew twice the chunks (calls 280 →
## 550 in the phone's browser, 2026-11-14), and a refit costs ~10 ms there.
const SPIN_AHEAD := PI / 4.0
## How fast the view glides to the one set: the share of the way left gone a second.
const TURN_RATE := 9.0
## A turn button held this many seconds turns the camera on smoothly, SPIN_RATE
## radians a second, until it is let go and the view glides to the nearest step.
const HOLD_TIME := 0.35
const SPIN_RATE := PI / 2.0
## Left alone for IDLE_TIME seconds (no key, tap or mouse, the player standing), the
## view drifts round the player by itself, gathering speed over IDLE_EASE seconds up to
## DRIFT_RATE radians a second (a whole turn in a minute and a half); any input stops it
## and it glides to the nearest step.
const IDLE_TIME := 60.0
const IDLE_EASE := 4.0
const DRIFT_RATE := TAU / 90.0
## The player counts as walking once its feet are this far, in metres along the ground,
## from where it stood still: a body that settles, bobs in water or is nudged by another
## a hair at a time does not keep the view from drifting (it reset the minute for good).
const IDLE_SLACK := 0.15
## Mouse motion shorter than this, in pixels, is not the player at the game: a phone
## browser sends stray moves after a tap.
const IDLE_MOUSE := 3.0
## Short of sleep (Vitals.SLEEPY) the picture swims instead (grade.gdshader `sway`), more
## the more tired; it comes and goes at SWAY_RATE a second.
const SWAY_RATE := 0.25
## After a glowing mushroom (Vitals.visions) the picture swims harder still, and colours
## run and split (grade.gdshader `trip`): it comes on at TRIP_RATE a second and fades
## over the last TRIP_FADE seconds of the visions.
const TRIP_RATE := 0.4
const TRIP_FADE := 20.0
## Behind a system menu the picture blurs and darkens (grade.gdshader `menu_blur`) in
## MENU_BLUR_IN seconds, and clears again in MENU_BLUR_OUT.
const MENU_BLUR_IN := 0.5
const MENU_BLUR_OUT := 0.2
## Seconds a shake lasts.
const SHAKE_TIME := 0.3
## The first-person view (the test setting «Вид от первого лица», Settings.first_person):
## a perspective camera at the eyes, EYE above the feet, FOV degrees tall, turned by
## swipes (look_by) and looking at most PITCH_MAX up or down; the player's figure is not
## drawn.
const EYE := 1.6
const FOV := 70.0
const PITCH_MAX := deg_to_rad(80.0)
const FAR := 60.0
const CROSS_ARM := 3.0

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
## Asked once: every frame asks the page otherwise.
var _web := OS.has_feature("web")
## Screen-plane point the camera follows smoothly (see PixelView.screen_plane).
var cam_target := Vector2.ZERO
## The world pixel at the image's top left this frame (grade.gdshader `view_origin`).
var origin_px := Vector2.ZERO
## The view set, in steps (the turn counts on past a whole turn, so it always glides
## the short way), and the one drawn now, gliding to it, in radians.
var turn_steps := 0
var tilt_steps := 0
var turn := 0.0
var tilt := 0.0
## The turn button held (1 left, -1 right, 0 none), how long, and whether it has
## started turning the camera smoothly.
var _hold := 0
var _held := 0.0
var _spinning := false
## The turn the culling boxes hold the views up to while it spins or drifts (see
## _spin_boxes).
var _boxes_to := 0.0
## The view drifting round the player by itself, the game left alone (see _drowse).
var _drifting := false
## Seconds since the last input or step of the player (see wake), and where it stood.
var idle := 0.0
var _idle_at := Vector3.INF
## How much the picture swims now, 0..1 (see drowsiness), and the value the shader has.
var sway := 0.0
var _sway_set := -1.0
## How deep in sleep the picture is, 0..1 (grade.gdshader `dream`: glow, a pale blue,
## the edges blurred and darker, given eased in and out), and the value last given.
var dream := 0.0
var _dream_set := -1.0
## Seconds the dream takes to come on falling asleep, and to go waking.
const DREAM_IN := 3.0
const DREAM_OUT := 2.0
## How strong the visions are now, 0..1 (see visions), and the value the shader has.
var trip := 0.0
var _trip_set := -1.0
## How blurred and dark the picture is behind a system menu now, 0..1 (see
## ease_menu_blur), and the value the shader has.
var menu_blur := 0.0
var _menu_blur_set := 0.0
## A shake of the picture (see shake): how far, in low-res pixels, and its seconds left.
var _shake := 0.0
var _shake_left := 0.0

var first_person := false
## EXPERIMENT: a true orthographic camera tilted, no shear (the first-person path).
var ortho_test := false
## The small cross in the middle of the screen in the first-person view.
var crosshair: Control
## Where the first-person view looks: radians to the left of north (as `turn`), and up
## (positive) or down.
var look_yaw := 0.0
var look_pitch := 0.0


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
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	crosshair.draw.connect(_draw_crosshair)
	parent.add_child(crosshair)


func build_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = PixelView.camera_size(image_size.y)
	camera.near = 1.0
	camera.far = CAMERA_HEIGHT + 10.0
	world_root.add_child(camera)
	camera.current = true


## Turns the first-person view on or off. On, it looks the way the camera was turned,
## a little down; off, the camera is over the player again as it was set.
func set_first_person(on: bool) -> void:
	if on == first_person:
		return
	first_person = on
	if camera == null:
		return
	if on:
		_hold = 0
		_spinning = false
		_drifting = false
		look_yaw = turn
		look_pitch = -0.2
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = FOV
		camera.near = 0.05
		camera.far = FAR
		if ortho_test:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = PixelView.camera_size(image_size.y)
			camera.near = 1.0
			camera.far = 300.0
		PixelView.set_first_person(look_yaw)
		# Without the shear every view's box is the same: fitted once.
		PixelView.box_views = [[PixelView.up, 1.0, 0.0]]
		if game.chunks != null:
			game.chunks.refit_boxes()
		if game.effects != null:
			game.effects.reanchor()
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = PixelView.camera_size(image_size.y)
		camera.near = 1.0
		camera.far = CAMERA_HEIGHT + 10.0
		look_at_player()
		PixelView.box_views = [PixelView.view_of(turn, tilt)]
		if game.chunks != null:
			game.chunks.refit_boxes()
	game.player.set_drawn(not on or ortho_test)
	if game.chunks != null:
		# The fog over chunks not built lies on the ground as seen from above; the
		# first-person view has its own fog with the distance (Sky).
		game.chunks.set_haze(not on and game.settings.values.edge_mist)
	game.player.look_way = PixelView.up if on and not ortho_test else Vector2.ZERO
	if crosshair != null:
		crosshair.visible = on and not ortho_test


## Turns the first-person view by `d` radians: x to the right, y down.
func look_by(d: Vector2) -> void:
	if not first_person:
		return
	look_yaw = wrapf(look_yaw - d.x, -PI, PI)
	look_pitch = clampf(look_pitch - d.y, -PITCH_MAX, PITCH_MAX)
	PixelView.set_first_person(look_yaw)
	if not ortho_test:
		game.player.look_way = PixelView.up


## The cross in the middle of the picture: arms CROSS_ARM pixels of the world long, light
## with a dark rim, so it shows on the sky and on the ground.
func _draw_crosshair() -> void:
	var c: Vector2 = (game.get_viewport().get_visible_rect().size / 2.0).round()
	var px := maxf(1.0, roundf(view_scale))
	for pass_i in 2:
		var color := Color(0.0, 0.0, 0.0, 0.5) if pass_i == 0 else Color(1.0, 1.0, 1.0, 0.85)
		var grow := px if pass_i == 0 else 0.0
		var arm := CROSS_ARM * px + grow
		var half := px * 0.5 + grow
		crosshair.draw_rect(Rect2(c.x - arm, c.y - half, arm * 2.0, half * 2.0), color)
		crosshair.draw_rect(Rect2(c.x - half, c.y - arm, half * 2.0, arm * 2.0), color)


## Starts the camera over the player, turned and tilted as last set.
func look_at_player() -> void:
	if first_person:
		PixelView.set_first_person(look_yaw)
		return
	turn_steps = posmod(int(game.settings.values.camera_turn), TURNS)
	tilt_steps = clampi(int(game.settings.values.camera_tilt), -LOWER, STEEPER)
	turn = turn_steps * TURN_STEP
	tilt = tilt_steps * TILT_STEP
	PixelView.set_view(turn, tilt)
	if game.effects != null:
		game.effects.reanchor()
	_aim()
	cam_target = PixelView.screen_plane(game.player.position + Vector3(0.0, 0.5, 0.0))


## Turns the camera `steps` steps of TURN_STEP to the left (negative: right).
func turn_by(steps: int) -> void:
	if first_person:
		look_by(Vector2(-steps * TURN_STEP, 0.0))
		return
	turn_steps += steps
	_aim()


## A turn button pressed: a step to that side at once, and a smooth turn when it is
## held (see HOLD_TIME).
func hold_turn(dir: int) -> void:
	turn_by(dir)
	if first_person:
		return
	if _spinning and dir != _hold:
		_spinning = false
	_hold = dir
	_held = 0.0


## The turn button let go: a smooth turn stops at the nearest step.
func release_turn(dir: int) -> void:
	if dir != _hold:
		return
	_hold = 0
	if _spinning:
		_spinning = false
		turn_steps = roundi(turn / TURN_STEP)
		_aim()


func is_spinning() -> bool:
	return _spinning


## Whether the view drifts round by itself, the game left alone (see drift_rate).
func is_drifting() -> bool:
	return _drifting


## Tilts the camera `steps` steps of TILT_STEP steeper (negative: lower), within
## STEEPER and LOWER.
func tilt_by(steps: int) -> void:
	if first_person:
		look_by(Vector2(0.0, -steps * TILT_STEP))
		return
	tilt_steps = clampi(tilt_steps + steps, -LOWER, STEEPER)
	_aim()


## Back to the default view, turning the short way.
func reset_turn() -> void:
	if first_person:
		look_by(Vector2(look_yaw, look_pitch + 0.2))
		return
	_hold = 0
	_spinning = false
	turn_steps = roundi(turn_steps / float(TURNS)) * TURNS
	tilt_steps = 0
	_aim()


func is_default() -> bool:
	if first_person:
		return false
	return posmod(turn_steps, TURNS) == 0 and tilt_steps == 0


## The turn set, in whole degrees to the left of north, 0..315 (any while it turns
## smoothly or drifts).
func turn_degrees() -> int:
	if first_person:
		return posmod(roundi(rad_to_deg(look_yaw)), 360)
	if _spinning or _drifting:
		return posmod(roundi(rad_to_deg(turn)), 360)
	return posmod(turn_steps, TURNS) * 45


## A new view is set: the chunks get culling boxes that hold what they draw all the
## way there (a box per step of the way), all round while it spins or drifts (a turn or
## tilt asked mid-drift kept only the step's boxes, and the drift turned on past them:
## things vanished), and the setting is kept.
func _aim() -> void:
	if _spinning or _drifting:
		_spin_boxes()
	else:
		var to := turn_steps * TURN_STEP
		var to_tilt := tilt_steps * TILT_STEP
		var views := [PixelView.view_of(turn, tilt)]
		var n := maxi(1, ceili(absf(to - turn) / BOX_STEP))
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


## A smooth turn starts: the culling boxes hold the views SPIN_AHEAD on, fitted again
## as it gets there (_spin_on), until it settles on a step again.
func _spin_start() -> void:
	_spinning = true
	_spin_boxes()


## Which way the view turns on by itself: the held button's, else the drift's.
func _spin_way() -> float:
	return float(_hold) if _spinning else 1.0


## The boxes hold the views from the turn now to SPIN_AHEAD on the way it turns (and the
## tilt it goes to, if it tilts on the way).
func _spin_boxes() -> void:
	var views := []
	var n := ceili(SPIN_AHEAD / BOX_STEP)
	var way := _spin_way()
	_boxes_to = turn + way * SPIN_AHEAD
	for i in n + 1:
		views.append(PixelView.view_of(turn + way * i * SPIN_AHEAD / n, tilt))
	var to_tilt := tilt_steps * TILT_STEP
	if to_tilt != tilt:
		for i in n + 1:
			views.append(PixelView.view_of(turn + way * i * SPIN_AHEAD / n, to_tilt))
	PixelView.box_views = views
	if game.chunks != null:
		game.chunks.refit_boxes()


## The view spun or drifted past the views the boxes hold: fitted again from here on,
## before the frame is drawn, so nothing is cut however long the frame was.
func _spin_on() -> void:
	if (_boxes_to - turn) * _spin_way() < 0.0:
		_spin_boxes()


## How fast the view drifts round now, radians a second: 0 until the game has been
## left alone IDLE_TIME seconds, then up to DRIFT_RATE.
func drift_rate() -> float:
	if idle < IDLE_TIME:
		return 0.0
	return DRIFT_RATE * clampf((idle - IDLE_TIME) / IDLE_EASE, 0.05, 1.0)


## A key, a tap or the mouse: the game is not left alone (main.gd's _input), and the
## drift, stopped, starts again after the next IDLE_TIME alone. Stray events (a mouse
## moved a pixel or two, a stick of a gamepad resting off centre) do not count.
func wake(event: InputEvent = null) -> void:
	if event is InputEventMouseMotion and event.relative.length() < IDLE_MOUSE:
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
		return
	idle = 0.0


## How much the picture should swim, 0..1: 0 rested or asleep, from 0.3 just short of
## sleep up to 1 with no energy left.
func drowsiness() -> float:
	var v = game.character.vitals if game.character != null else null
	if v == null or v.asleep or not v.fatigue or v.energy >= v.SLEEPY:
		return 0.0
	return lerpf(0.3, 1.0, 1.0 - v.energy / v.SLEEPY)


## How strong the visions should be, 0..1: full while they last, fading over the last
## TRIP_FADE seconds; 0 asleep.
func visions() -> float:
	var v = game.character.vitals if game.character != null else null
	if v == null or v.asleep or v.visions <= 0.0:
		return 0.0
	return clampf(v.visions / TRIP_FADE, 0.0, 1.0)


## Counts the time left alone (a key or the stick held, or the player walking, counts
## as input: a held key or a finger held on the stick sends nothing new) and eases the
## swim to the body's drowsiness, telling the shader when it changed. Only the feet's
## way along the ground counts, from where they stood still, and not afloat: water and
## a vessel carry the body by themselves.
func _tire(delta: float) -> void:
	var at: Vector3 = game.player.position
	var carried: bool = game.character != null and (game.character.vessel != 0 or game.character.riding != "")
	var walked := Vector2(at.x - _idle_at.x, at.z - _idle_at.z).length() > IDLE_SLACK
	var held: bool = game.get("controls") != null and game.get("hud") != null and game.controls.read_move() != Vector2.ZERO
	if held or (walked and not carried) or not _idle_at.is_finite():
		idle = 0.0
		_idle_at = at
	else:
		idle += delta
		if carried:
			_idle_at = at
	sway = move_toward(sway, drowsiness(), delta * SWAY_RATE)
	if grade_mat != null and (absf(sway - _sway_set) > 0.002 or (sway == 0.0 and _sway_set > 0.0)):
		_sway_set = sway
		grade_mat.set_shader_parameter("sway", sway)
	var asleep: bool = game.character != null and game.character.vitals.asleep and not game.character.is_dead()
	dream = move_toward(dream, 1.0 if asleep else 0.0, delta / (DREAM_IN if asleep else DREAM_OUT))
	if grade_mat != null and (absf(dream - _dream_set) > 0.002 or (dream == 0.0 and _dream_set > 0.0)):
		_dream_set = dream
		grade_mat.set_shader_parameter("dream", smoothstep(0.0, 1.0, dream))
	trip = move_toward(trip, visions(), delta * TRIP_RATE)
	if grade_mat != null and (absf(trip - _trip_set) > 0.002 or (trip == 0.0 and _trip_set > 0.0)):
		_trip_set = trip
		grade_mat.set_shader_parameter("trip", trip)


## Starts or stops the drift of a view left alone: the culling boxes then hold the views
## all round, as for a smooth turn; on any input the view glides to the nearest step.
func _drowse(_delta: float) -> void:
	var drift := drift_rate() > 0.0
	if drift == _drifting:
		return
	_drifting = drift
	if drift:
		_spin_boxes()
	elif not _spinning:
		turn_steps = roundi(turn / TURN_STEP)
		_aim()


## Glides the drawn view to the one set; once there, the culling boxes hold that view
## alone again.
func _glide(delta: float) -> void:
	_drowse(delta)
	if _hold != 0 and not _spinning:
		_held += delta
		if _held >= HOLD_TIME:
			_spin_start()
	var to := turn_steps * TURN_STEP
	var to_tilt := tilt_steps * TILT_STEP
	if turn == to and tilt == to_tilt and not _spinning and not _drifting:
		return
	var k := minf(1.0, delta * TURN_RATE)
	if _drifting and not _spinning:
		turn += drift_rate() * delta
		turn_steps = roundi(turn / TURN_STEP)
	elif _spinning:
		turn += _hold * SPIN_RATE * delta
		# The step it is nearest to is the one set, for whoever reads it.
		turn_steps = roundi(turn / TURN_STEP)
	else:
		turn = lerpf(turn, to, k)
	tilt = lerpf(tilt, to_tilt, k)
	if _spinning or _drifting:
		_spin_on()
	if not _spinning and not _drifting and absf(turn - to) < 0.002 and absf(tilt - to_tilt) < 0.0005:
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
	if game.effects != null:
		game.effects.reanchor()
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
## visual viewport (which the phone's keyboard shortens); in a phone's app the screen
## without its camera cutout and above the keyboard, as the browser does it (the app's
## window keeps its size under the keyboard); elsewhere the whole window.
func _safe_rect() -> Rect2:
	var full: Rect2 = Rect2(Vector2.ZERO, game.get_viewport().get_visible_rect().size)
	if not _web:
		if not OS.has_feature("mobile"):
			return full
		var cut := full.intersection(Rect2(DisplayServer.get_display_safe_area()))
		if cut.size.x <= 100.0 or cut.size.y <= 100.0:
			cut = full
		var keys := float(DisplayServer.virtual_keyboard_get_height())
		if keys > 0.0:
			cut.size.y = minf(cut.size.y, full.size.y - keys - cut.position.y)
		return cut if cut.size.y > 100.0 else full
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
## of the screen is re-checked twice a second; in a phone's app, where nothing tells of
## the keyboard coming up or going, ten times a second.
func poll_safe_rect(delta: float) -> void:
	if not _web and not OS.has_feature("mobile"):
		return
	safe_clock += delta
	if safe_clock < (0.5 if _web else 0.1):
		return
	safe_clock = 0.0
	var r := _safe_rect()
	if not r.is_equal_approx(safe_rect):
		layout_ui(r)


## Where world point `p` is on the low-res image, in its pixels (far off it when it is
## behind the first-person camera).
func image_of(p: Vector3) -> Vector2:
	if first_person:
		if camera.is_position_behind(p):
			return Vector2(-100000.0, -100000.0)
		return camera.unproject_position(p)
	var center := PixelView.plane_of(Vector2(camera.global_position.x, camera.global_position.z))
	return (PixelView.screen_plane(p) - center) * PixelView.PIXELS_PER_UNIT + Vector2(image_size) * 0.5


## The view ray through low-res image point `at` of the first-person camera, in world
## units: [origin, direction].
func first_person_ray(at: Vector2) -> Array:
	return [camera.project_ray_origin(at), camera.project_ray_normal(at)]


## Where world point `p` is on the screen, in screen pixels (as drawn this frame).
func screen_of(p: Vector3) -> Vector2:
	if first_person:
		return container.position + image_of(p) * view_scale
	var offset := (PixelView.screen_plane(p) - cam_target) * PixelView.PIXELS_PER_UNIT
	return (Vector2(image_size) / 2.0 - Vector2.ONE * PixelView.MARGIN + offset) * view_scale


## The camera renders from a whole pixel; the leftover fraction of a pixel shifts the
## upscaled image, so the view glides smoothly while the pixel art stays on its grid.
func update(delta: float) -> void:
	if camera == null:
		return
	var player = game.player
	_tire(delta)
	if game.settings.first_person != first_person:
		set_first_person(game.settings.first_person)
	if first_person:
		_first_person_frame(player)
		return
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
	origin_px = snapped * PixelView.PIXELS_PER_UNIT - Vector2(image_size) / 2.0
	grade_mat.set_shader_parameter("view_origin", origin_px)
	container.position = (-Vector2.ONE * PixelView.MARGIN - frac) * view_scale
	container.position = container.position.round()
	# The drops and snow on the screen keep to the screen, not to the gliding picture.
	grade_mat.set_shader_parameter("screen_shift", container.position / view_scale + Vector2.ONE * PixelView.MARGIN)
	if game.settings.values.crt != 0 or sway > 0.0 or trip > 0.0 or dream > 0.0:
		Crt.frame(grade_mat, game.get_viewport().get_visible_rect().size, container.position, view_scale,
			Engine.get_process_frames())
	player.place_sprite()
	RenderingServer.global_shader_parameter_set("player_pos", player.position)


## A frame of the first-person view: the camera at the eyes, the picture not shifted.
func _first_person_frame(player) -> void:
	var eye: Vector3 = player.position + Vector3(0.0, EYE, 0.0)
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0)), eye)
	if ortho_test:
		var b := Basis.from_euler(Vector3(look_pitch, look_yaw, 0.0))
		camera.global_transform = Transform3D(b, player.position + Vector3(0.0, 0.5, 0.0) + b.z * 100.0)
	cam_target = PixelView.screen_plane(player.position + Vector3(0.0, 0.5, 0.0))
	grade_mat.set_shader_parameter("view_origin", Vector2.ZERO)
	container.position = (-Vector2.ONE * PixelView.MARGIN * view_scale).round()
	if crosshair.size != game.get_viewport().get_visible_rect().size:
		crosshair.size = game.get_viewport().get_visible_rect().size
		crosshair.queue_redraw()
	grade_mat.set_shader_parameter("screen_shift", container.position / view_scale + Vector2.ONE * PixelView.MARGIN)
	if game.settings.values.crt != 0 or sway > 0.0 or trip > 0.0 or dream > 0.0:
		Crt.frame(grade_mat, game.get_viewport().get_visible_rect().size, container.position, view_scale,
			Engine.get_process_frames())
	player.place_sprite()
	RenderingServer.global_shader_parameter_set("player_pos", player.position)


## Eases the blur and the dark behind a system menu towards on (`open`) or off over
## `delta` seconds; returns how far it is, eased (0..1). Called by the HUD, which keeps
## running while the game is paused.
func ease_menu_blur(open: bool, delta: float) -> float:
	menu_blur = move_toward(menu_blur, 1.0 if open else 0.0, delta / (MENU_BLUR_IN if open else MENU_BLUR_OUT))
	# Eased, so it starts and ends softly.
	var k := smoothstep(0.0, 1.0, menu_blur)
	if grade_mat == null or menu_blur == _menu_blur_set:
		return k
	if _menu_blur_set == 0.0:
		# The linear-filtered picture the blur reads (Crt.apply binds it too).
		grade_mat.set_shader_parameter("crt_view", viewport.get_texture())
	_menu_blur_set = menu_blur
	grade_mat.set_shader_parameter("menu_blur", k)
	return k


## Shakes the picture by up to `pixels` low-res pixels for a moment, fading.
func shake(pixels: float) -> void:
	_shake = maxf(pixels, _shake if _shake_left > 0.0 else 0.0)
	_shake_left = SHAKE_TIME
