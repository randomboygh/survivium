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
## The shortest a work plays, in seconds, so quick placing still shows.
const MIN_WORK := 0.2
## How many sheets of looks and things held are kept, so changing hands back and forth
## takes no building.
const SHEETS_KEPT := 6

## How the body moves (its `world` is set when the world is made).
var body := Body.new()
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
var _work_length := 0.0
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
var torch: OmniLight3D


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


## Changes what the body wears: the sheet is drawn again with these layers.
func set_look(layers: Array) -> void:
	look = layers
	_redraw()


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
	if work_kind != "" and _work_time < _work_length * 0.5:
		return
	work_kind = kind
	_work_length = maxf(seconds, MIN_WORK)
	_work_time = 0.0
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
		if _work_time < _work_length:
			var frames: Array = sheet.animations[work_kind].frames
			anim = work_kind
			anim_time = minf(_work_time / _work_length, 0.999) * frames.size() / sheet.animations[work_kind].fps
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
	var frame := sheet.frame_uv(facing, anim, anim_time)
	for layer in [sprite, xray, underwater]:
		layer.global_position = sprite.global_position
		layer.material_override.set_shader_parameter("water_line", line)
		layer.material_override.set_shader_parameter("frame_uv", frame)
	underwater.visible = line > -1000.0
	torch.global_position = PixelView.shear(position + Vector3(0.0, 1.2, 0.3))


## The level of the cell the feet are in.
func level() -> int:
	return Body.level_at(position)


## True if the body would overlap the cell.
func overlaps_cell(cell: Vector3i) -> bool:
	return Body.overlaps(position, cell)
