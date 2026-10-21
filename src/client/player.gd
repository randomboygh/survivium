extends Node3D
## Player body on the cell grid: walks up and down slopes, jumps up onto a sheer step of
## one cell (8 px) but not of two, goes around cut corners of cliffs. It wades through
## shallow water, swims in deep water with its head above the surface, pulls itself
## out onto ground up to one level above the water, and walks on ice in winter.
## `position` is the middle of the feet in world units; the body moves in cells.

const Figure := preload("res://src/client/figure.gd")
const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")
const XrayShader := preload("res://shaders/sprite_xray.gdshader")
const UnderwaterShader := preload("res://shaders/sprite_water.gdshader")

const CELL := WorldData.CELL
## Body and motion in cells: a little narrower than a cell, a little under two tall.
const HALF_WIDTH := 0.44
## The body is thin north to south: the sprite has no depth, and the 3/4 view draws
## anything deeper as feet off what they stand on (in the air over the back edge of a
## chest's lid, or hanging in front of it).
const HALF_DEPTH := 0.2
const HEIGHT := 1.8
const SPEED := 8.0
const GRAVITY := 44.0
## A jump rises about 1.45 cells: onto a block of one cell, not of two.
const JUMP_SPEED := 11.3
const MAX_FALL := 30.0
## Walking keeps the feet on the ground up and down slopes by up to this much per step;
## a sheer step of a whole cell is not walked up or down.
const STEP_UP := 0.5
const STEP_DOWN := 0.6
## A swimmer floats with the feet this deep under the surface, so water up to one
## cell deep is waded and deeper water is swum.
const SWIM_DEPTH := 0.95
## Speed in water up to the knees and deeper, and while swimming, against walking.
const WADE := 0.65
const SWIM := 0.45
## Water slows a fall to this many cells a second and lifts a sunk swimmer this fast.
const SINK_SPEED := 5.0
const FLOAT_SPEED := 4.0
## On ice the body picks up and loses speed this slowly (cells a second, per second),
## so it glides on after the stick is let go.
const ICE_GRIP := 14.0
## The shortest a work plays, in seconds, so quick placing still shows.
const MIN_WORK := 0.2
## How many sheets of looks and things held are kept, so changing hands back and forth
## takes no building.
const SHEETS_KEPT := 6

var world
## Movement wish: x = east, y = south, length up to 1.
var move_input := Vector2.ZERO
## Playtest multiplier of the walking speed (Settings.PLAYER_SPEEDS).
var speed_scale := 1.0
## What the load and tiredness leave of the pace (see Character).
var load_scale := 1.0
## Playtest switch: a press of jump in the air jumps again, to climb out of a deep
## pit by pressing it over and over.
var air_jumps := false
## Whether the last step started a jump.
var jumped := false
## Whether jump was held in the last step: an air jump needs a fresh press.
var _jump_was := false
var velocity_y := 0.0
var on_ground := false
var swimming := false
## How deep the feet are under the water surface, 0 out of water.
var water_depth := 0.0
## Height of that surface in cells, -INF out of water.
var water_level := -INF
## The velocity on the ground plane in cells a second (x east, y south); on ice it
## lags behind the wish.
var glide := Vector2.ZERO
## Height the body pushed against while in water can pull itself up by this step.
var _pull_up := 0.0
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
	if swimming:
		next = "swim"
	elif not on_ground:
		next = "jump"
	elif dir.length() > 0.1:
		next = "walk"
	if next != anim:
		anim = next
		anim_time = 0.0
	if anim == "jump":
		# Going up, then coming down.
		anim_time = 0.0 if velocity_y > 0.0 else 1.0 / Figure.data().animations.jump.fps
	elif anim == "idle":
		anim_time += delta
	else:
		anim_time += delta * speed / SPEED


func step(delta: float, jump: bool) -> void:
	var p := position / CELL
	var surface := _water_surface(p)
	if surface > -INF and world.water_frozen:
		# The water froze around the body: stand on the ice.
		p.y = ceilf(surface)
		surface = -INF
	water_depth = maxf(0.0, surface - p.y)
	water_level = surface if water_depth > 0.0 else -INF
	var speed := SPEED * speed_scale * load_scale * (SWIM if swimming else (WADE if water_depth > 0.3 else 1.0))
	# In water the body gets out onto ground up to one level above the water's cell.
	var reach := ceilf(surface) + 1.0 if surface > -INF else -INF
	var dir := move_input.limit_length(1.0)
	_animate(dir, speed, delta)
	_pull_up = 0.0
	if on_ice(p):
		glide = glide.move_toward(dir * speed, ICE_GRIP * delta)
	else:
		glide = dir * speed
	var before := p
	p = _try_move(p, Vector3(glide.x * delta, 0.0, 0.0), reach)
	p = _try_move(p, Vector3(0.0, 0.0, glide.y * delta), reach)
	# A wall stops the glide along it.
	if absf(p.x - before.x) < absf(glide.x * delta) * 0.5:
		glide.x = 0.0
	if absf(p.z - before.z) < absf(glide.y * delta) * 0.5:
		glide.y = 0.0
	if on_ground and not jump:
		var below := _ground_top(p, p.y - STEP_DOWN, p.y)
		if below > -INF:
			p.y = below
	jumped = jump and (on_ground or (air_jumps and not _jump_was))
	_jump_was = jump
	if jumped:
		velocity_y = JUMP_SPEED
	elif _pull_up > 0.0 and velocity_y <= 0.0:
		velocity_y = sqrt(2.0 * GRAVITY * (_pull_up + 0.2))
	var float_y := surface - SWIM_DEPTH
	swimming = velocity_y <= 0.0 and p.y <= float_y + 0.01
	if swimming:
		# Deep water holds the body up with its head above the surface.
		velocity_y = 0.0
		on_ground = false
		var fy := move_toward(p.y, float_y, FLOAT_SPEED * delta)
		if not _collides(Vector3(p.x, fy, p.z)) or _collides(p):
			p.y = fy
		position = p * CELL
		return
	velocity_y = maxf(velocity_y - GRAVITY * delta, -SINK_SPEED if water_depth > 0.0 else -MAX_FALL)
	var ny := p.y + velocity_y * delta
	if _collides(Vector3(p.x, ny, p.z)):
		if velocity_y < 0.0:
			var ground := _ground_top(p, ny, p.y)
			p.y = ground if ground > -INF else floorf(ny) + 1.0
			on_ground = true
		velocity_y = 0.0
	else:
		p.y = ny
		on_ground = false
	position = p * CELL


## True when the body at `p` (in cells) stands on frozen water.
func on_ice(p: Vector3) -> bool:
	if not on_ground or not world.water_frozen:
		return false
	return world.get_cell(floori(p.x), floori(p.y + 0.01) - 1, floori(p.z)) == Mat.WATER


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
	if swimming and fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6:
		# A swimmer bobs on the water by a pixel.
		sprite.global_position.y += 1.0 / PixelView.PIXELS_PER_UNIT
	var line := water_level * CELL if water_level > -INF else -1000.0
	var frame := sheet.frame_uv(facing, anim, anim_time)
	for layer in [sprite, xray, underwater]:
		layer.global_position = sprite.global_position
		layer.material_override.set_shader_parameter("water_line", line)
		layer.material_override.set_shader_parameter("frame_uv", frame)
	underwater.visible = line > -1000.0
	torch.global_position = PixelView.shear(position + Vector3(0.0, 1.2, 0.3))


## The level of the cell the feet are in.
func level() -> int:
	return floori(position.y / CELL + 0.01)


## True if the body would overlap the cell.
func overlaps_cell(cell: Vector3i) -> bool:
	var p := position / CELL
	return cell.x == clampi(cell.x, floori(p.x - HALF_WIDTH), floori(p.x + HALF_WIDTH)) \
		and cell.z == clampi(cell.z, floori(p.z - HALF_DEPTH), floori(p.z + HALF_DEPTH)) \
		and cell.y == clampi(cell.y, floori(p.y + 0.001), floori(p.y + HEIGHT))


## Moves by `d` unless something is in the way. On the ground the body follows ground
## rising a little (a slope, not a sheer step); in water, ground up to `reach` ahead
## sets _pull_up for a climb out.
func _try_move(p: Vector3, d: Vector3, reach: float) -> Vector3:
	if d == Vector3.ZERO:
		return p
	var np := p + d
	if not _collides(np):
		return np
	if on_ground:
		var top := _ground_top(np, p.y, p.y + STEP_UP)
		if top > p.y:
			var up := Vector3(np.x, top, np.z)
			if not _collides(up) and not _collides(Vector3(p.x, top, p.z)):
				return up
	if reach > p.y:
		var top := _ground_top(np, p.y, reach)
		if top > p.y and not _collides(Vector3(np.x, top, np.z)):
			_pull_up = maxf(_pull_up, top - p.y)
	return p


## Height of the water surface in the column under the middle of the body when the
## feet are in water there, -INF otherwise. The surface is where it is drawn: below
## the top of its cell under open air, at the top under a ceiling.
func _water_surface(p: Vector3) -> float:
	var x := floori(p.x)
	var y := floori(p.y + 0.001)
	var z := floori(p.z)
	if world.get_cell(x, y, z) != Mat.WATER:
		return -INF
	while world.get_cell(x, y + 1, z) == Mat.WATER:
		y += 1
	return y + (WorldData.WATER_TOP if world.get_cell(x, y + 1, z) == Mat.AIR else 1.0)


func _collides(p: Vector3) -> bool:
	var x0 := floori(p.x - HALF_WIDTH)
	var x1 := floori(p.x + HALF_WIDTH)
	var z0 := floori(p.z - HALF_DEPTH)
	var z1 := floori(p.z + HALF_DEPTH)
	var y0 := floori(p.y + 0.001)
	var y1 := floori(p.y + HEIGHT)
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var f := _footprint(x, z, p)
				if not world.blocks_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y):
					continue
				# A sloping cell only blocks below its surface under the feet, which may
				# lie below the cell where the slope goes on down.
				if p.y + 0.001 < y + _cell_top(x, y, z, p):
					return true
	return false


## Height of the highest ground the feet at `p` would stand on, among surfaces between
## `lo` and `hi`; -INF when there is none.
func _ground_top(p: Vector3, lo: float, hi: float) -> float:
	var best := -INF
	for y in range(floori(lo), floori(hi) + 1):
		for z in range(floori(p.z - HALF_DEPTH), floori(p.z + HALF_DEPTH) + 1):
			for x in range(floori(p.x - HALF_WIDTH), floori(p.x + HALF_WIDTH) + 1):
				var f := _footprint(x, z, p)
				if not world.ground_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y):
					continue
				var top := y + _cell_top(x, y, z, p)
				if top >= lo - 0.001 and top <= hi + 0.001:
					best = maxf(best, top)
	return best


## The part of the cell (x, z) under the footprint of a body at `p`, in 0..1 cell
## coordinates: position = (min x, min z), end = (max x, max z).
func _footprint(x: int, z: int, p: Vector3) -> Rect2:
	var a := Vector2(clampf(p.x - HALF_WIDTH - x, 0.0, 1.0), clampf(p.z - HALF_DEPTH - z, 0.0, 1.0))
	var b := Vector2(clampf(p.x + HALF_WIDTH - x, 0.0, 1.0), clampf(p.z + HALF_DEPTH - z, 0.0, 1.0))
	return Rect2(a, b - a)


## Top of a solid cell under the footprint at `p` above its level: 1 for a cube, the
## top of a thing standing in it (see WorldData.blockers), the
## highest point of the slope under the feet otherwise (below 0 where the slope goes
## on down into the cell below).
func _cell_top(x: int, y: int, z: int, p: Vector3) -> float:
	if not world.blockers.is_empty():
		var f := _footprint(x, z, p)
		var thing: float = world.blocker_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y)
		if thing > 0.0:
			return thing
	if not Mat.can_slope(world.get_cell(x, y, z)):
		return 1.0
	var mask: int = world.slope_mask(x, y, z)
	if mask == WorldData.FULL:
		return 1.0
	var patch: PackedFloat32Array = world.surface_patch(x, y, z)
	var ax := clampf(p.x - HALF_WIDTH - x, 0.0, 1.0)
	var bx := clampf(p.x + HALF_WIDTH - x, 0.0, 1.0)
	var az := clampf(p.z - HALF_DEPTH - z, 0.0, 1.0)
	var bz := clampf(p.z + HALF_DEPTH - z, 0.0, 1.0)
	var top := -INF
	for i in 3:
		for k in 3:
			top = maxf(top, WorldData.patch_height(patch, lerpf(ax, bx, i * 0.5), lerpf(az, bz, k * 0.5)))
	return top
