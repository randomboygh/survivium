extends Node3D
## The player on the screen: the body (Body, src/shared: walking, jumping, swimming, ice)
## moved every frame from the node's `position`, the middle of the feet in world units,
## and the sprite drawn there, turned the way it moves or works, with the animation of
## what it does.

const Body := preload("res://src/shared/game/body.gd")
const Figure := preload("res://src/client/view/figure.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")
const XrayShader := preload("res://shaders/sprite_xray.gdshader")
const UnderwaterShader := preload("res://shaders/sprite_water.gdshader")

const CELL := WorldData.CELL
## The body's height in cells (see Body).
const HEIGHT := Body.HEIGHT
## Colour of the line of ripples round the body where it goes into water, and into the
## murky water of a swamp; the tint of the body under it in clear water and in a
## swamp's, shallow and deep (water.gdshader's).
const FOAM_RIPPLE := Color(0.85, 0.93, 0.92)
const MURKY_RIPPLE := Color(0.62, 0.65, 0.5)
const CLEAR_TINT := [Color(0.36, 0.62, 0.6), Color(0.13, 0.29, 0.42)]
const SWAMP_TINT := [Color(0.37, 0.43, 0.25), Color(0.2, 0.26, 0.16)]
## The shortest a work plays, in seconds, so quick placing still shows.
const MIN_WORK := 0.2
## How many sheets of looks and things held are kept, so changing hands back and forth
## takes no building.
const SHEETS_KEPT := 6

## How the body moves (its `world` is set when the world is made).
var body := Body.new()
## The performance statistics (PerfPanel), told when a new sheet is sent to the renderer.
var perf
## Which way the body faces, one of SpriteSheet.COMPASS; set by the last movement.
var facing := "s"
## The animation playing and how long it has, in seconds of animation time.
var anim := "idle"
var anim_time := 0.0
## Layers of the look (content/core/sprites/player.yaml `layers`): what is worn.
var look: Array = ["body", "hair", "shirt", "trousers", "boots"]
## What the hands hold and which one is in use (see Figure).
var held := {"left": {}, "right": {}, "active": "right"}
## The work playing (one of player.yaml `works`, "" none), how long it lasts and
## how far it has got, in seconds.
var work_kind := ""
var work_length := 0.0
## How many works were started, and where the last was turned to (INF for none): the
## server tells the other players of them (Protocol.INPUT, PEOPLE).
var work_n := 0
var work_at := Vector3.INF
var _work_time := 0.0
## The sheet being built for a new look (see _redraw) and the sheets built, by look.
var _build = null
var _build_key := ""
var _sheets := {}
var sheet: SpriteSheet
var sprite: MeshInstance3D
## The same sprite drawn as a silhouette where walls or crowns hide the player.
var xray: MeshInstance3D
## The part of the sprite under the water, tinted, drawn over the water.
var underwater: MeshInstance3D
## The light round the player in the dark: a faint glow of their own, or a torch's
## when they hold one (see sky.gd).
var torch: OmniLight3D
## A thing held gives light (Character.light_held), set by sky.gd.
var torch_lit := false
## Where the flames of the lights held burn, in world units, one a hand that holds
## one: the brightest pixel of what the hand holds in the frame shown
## (SpriteSheet.spots); empty when none shows.
var flames_at: Array = []


func _ready() -> void:
	Figure.prepare(look)
	sheet = Figure.sheet(look, held)
	_sheets[str(look) + str(held)] = sheet
	var tex := sheet.texture
	var mesh := PixelView.sprite_mesh(sheet.frame_size.x, sheet.frame_size.y)
	sprite = MeshInstance3D.new()
	sprite.mesh = mesh
	sprite.material_override = sprite_material(SpriteShader, tex)
	sprite.extra_cull_margin = 24.0
	# Placed by place_sprite() on whole pixels, not by the body's position.
	sprite.top_level = true
	sprite.layers = PixelView.LAYER_PLAYER
	add_child(sprite)
	xray = MeshInstance3D.new()
	xray.mesh = mesh
	xray.material_override = sprite_material(XrayShader, tex)
	xray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	xray.extra_cull_margin = 24.0
	xray.top_level = true
	add_child(xray)
	underwater = MeshInstance3D.new()
	underwater.mesh = mesh
	underwater.material_override = sprite_material(UnderwaterShader, tex)
	# After the water, which is drawn at priority 0.
	underwater.material_override.render_priority = 1
	underwater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	underwater.extra_cull_margin = 24.0
	underwater.top_level = true
	add_child(underwater)
	torch = OmniLight3D.new()
	# Rings of 1, 2, 3 and 5 world units (see toon_light).
	torch.omni_range = 5.0
	torch.omni_attenuation = 0.0
	torch.light_color = Color(1.0, 0.55, 0.25)
	torch.light_energy = 0.0
	# Shadows of everything around but the player holding it (see sky.gd for when).
	torch.shadow_caster_mask = 0xFFFFF & ~(PixelView.LAYER_PLAYER | PixelView.LAYER_SUN_CASTER)
	torch.top_level = true
	add_child(torch)


static func sprite_material(shader: Shader, tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("sprite_texture", tex)
	return m


## Puts things in the hands, each {} or {"sprite", "colour", "anim"} (see Figure), and
## says which hand is in use ("left" or "right"); the sheet is drawn again on a change.
func hold(left: Dictionary, right: Dictionary, active: String) -> void:
	var next := {"left": left, "right": right, "active": active}
	if str(next) == str(held):
		return
	held = next
	if sprite != null:
		_redraw()


## Builds the sheet of the look and what is held over the next frames (see
## place_sprite), or takes it from the ones built before.
func _redraw() -> void:
	var key := str(look) + str(held)
	_build = null
	if _sheets.has(key):
		_use(_sheets[key])
		return
	_build = Figure.new(look, held)
	_build_key = key


func _use(s: SpriteSheet) -> void:
	sheet = s
	for layer in [sprite, xray, underwater]:
		layer.material_override.set_shader_parameter("sprite_texture", sheet.texture)


## Swings the hand in use once over `seconds`, turned towards world point `at` (none
## when INF): `kind` is one of player.yaml `works`, or "" for the one of the
## tool in that hand. A swing that comes while one is past its strike starts anew, so
## work held down keeps swinging.
func work(kind: String, seconds: float, at := Vector3.INF) -> void:
	if kind == "":
		var thing: Dictionary = held.get(held.active, {})
		kind = thing.get("anim", "")
		if not Figure.data().works.has(kind):
			kind = "reach"
	if work_kind != "" and _work_time < work_length * 0.5:
		return
	work_kind = kind
	work_length = maxf(seconds, MIN_WORK)
	_work_time = 0.0
	work_n += 1
	work_at = at
	if at != Vector3.INF:
		var to := Vector2(at.x - position.x, at.z - position.z)
		if to.length() > 0.1 * CELL:
			facing = SpriteSheet.direction_of(to)


## Picks the direction and animation for this step: the body turns the way it is
## pushed and walks, jumps, swims or stands, unless a work is playing; the walk goes as fast
## as the feet.
func _animate(dir: Vector2, speed: float, delta: float) -> void:
	if dir.length() > 0.1:
		facing = SpriteSheet.direction_of(dir)
	if work_kind != "":
		# A work plays once over its length, then the body walks or stands again.
		_work_time += delta
		if _work_time < work_length:
			var frames: Array = sheet.animations[work_kind].frames
			anim = work_kind
			anim_time = minf(_work_time / work_length, 0.999) * frames.size() / sheet.animations[work_kind].fps
			return
		work_kind = ""
	var next := "idle"
	if body.swimming:
		next = "swim"
	elif not body.on_ground:
		next = "jump"
	elif dir.length() > 0.1:
		next = "walk"
	if next != anim:
		anim = next
		anim_time = 0.0
	if anim == "jump":
		# Going up, then coming down.
		anim_time = 0.0 if body.velocity_y > 0.0 else 1.0 / Figure.data().animations.jump.fps
	elif anim == "idle":
		anim_time += delta
	else:
		anim_time += delta * speed / Body.SPEED


## Moves the body for `delta` seconds (see Body.step), jumping when `jump` is held, and
## picks its animation for the pace it walks at.
func step(delta: float, jump: bool) -> void:
	_animate(body.move_input.limit_length(1.0), body.speed_at(position), delta)
	position = body.step(position, delta, jump)


## Puts the sprite on the body, snapped to whole pixels, and the torch above it (lights
## live where the shaders draw, so its position is sheared); first a step of building
## a new sheet if one is being built.
func place_sprite() -> void:
	if _build != null and _build.step():
		if perf != null:
			perf.mark("фигура")
		if _sheets.size() >= SHEETS_KEPT:
			_sheets.erase(_sheets.keys()[0])
		_sheets[_build_key] = _build.target
		_use(_build.target)
		_build = null
	sprite.global_position = PixelView.snap(position)
	if body.swimming and fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6:
		# A swimmer bobs on the water by a pixel.
		sprite.global_position.y += 1.0 / PixelView.PIXELS_PER_UNIT
	var line: float = body.water_level * CELL if body.water_level > -INF else -1000.0
	var frame := sheet.frame_uv(drawn_facing(), anim, anim_time)
	for layer in [sprite, xray, underwater]:
		layer.global_position = sprite.global_position
		layer.material_override.set_shader_parameter("water_line", line)
		layer.material_override.set_shader_parameter("frame_uv", frame)
	# Water shows the body under it tinted; a bog's is too murky to see through.
	sprite.material_override.set_shader_parameter("ripple", MURKY_RIPPLE if body.murk > 0 else FOAM_RIPPLE)
	sprite.material_override.set_shader_parameter("splash", 1.0 if body.swimming else 0.0)
	var tint: Array = SWAMP_TINT if body.murk > 0 else CLEAR_TINT
	underwater.material_override.set_shader_parameter("shallow", tint[0])
	underwater.material_override.set_shader_parameter("deep", tint[1])
	underwater.visible = line > -1000.0 and not body.in_bog
	# The torch is held a little towards the viewer.
	torch.global_position = PixelView.shear(position + Vector3(-PixelView.up.x * 0.3, 1.2, -PixelView.up.y * 0.3))
	_find_flame()


## Puts flames_at on the frame shown: the frame's spot is a pixel of the upright quad
## (see PixelView.sprite_mesh), turned to face the view and made as tall as the
## shaders draw it (face_view, stand_tall).
func _find_flame() -> void:
	var f := sheet.frame_at(drawn_facing(), anim, anim_time)
	var spots: Variant = sheet.spots.get(Vector2i(f.x, f.y))
	if spots == null:
		if sheet.spots.is_empty():
			flames_at = []
		return
	var size := sheet.frame_size
	var px := 1.0 / PixelView.PIXELS_PER_UNIT
	flames_at = []
	for spot: Vector2i in spots:
		var x: int = size.x - 1 - spot.x if f.z == 1 else spot.x
		var across: float = (x + 0.5 - floorf(size.x / 2.0)) * px
		var up: float = (size.y - spot.y - 0.5) * px / PixelView.slope
		flames_at.append(sprite.global_position + Vector3(PixelView.right.x * across, up, PixelView.right.y * across))


## The way the body faces on the screen: `facing` is a way of the world, the camera
## may be turned.
func drawn_facing() -> String:
	if PixelView.up == Vector2(0.0, -1.0):
		return facing
	var turn := SpriteSheet.COMPASS.find(facing) / 8.0 * TAU
	return SpriteSheet.direction_of(PixelView.screen_dir(Vector2(-sin(turn), cos(turn))))


## The level of the cell the feet are in.
func level() -> int:
	return Body.level_at(position)


## True if the body would overlap the cell.
func overlaps_cell(cell: Vector3i) -> bool:
	return Body.overlaps(position, cell)
