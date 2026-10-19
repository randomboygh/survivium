extends Node3D
## Player body on the cell grid: walks up and down slopes, jumps up onto a sheer step of
## one cell (8 px) but not of two, goes around cut corners of cliffs, cannot enter
## water. `position` is the middle of the feet in world units; the body moves in cells.

const SpriteArt := preload("res://src/client/sprite_art.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const SpriteShader := preload("res://shaders/sprite.gdshader")
const XrayShader := preload("res://shaders/sprite_xray.gdshader")

const CELL := WorldData.CELL
## Body and motion in cells: a little narrower than a cell, a little under two tall.
const HALF_WIDTH := 0.44
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

var world
## Movement wish: x = east, y = south, length up to 1.
var move_input := Vector2.ZERO
var velocity_y := 0.0
var on_ground := false
var sprite: MeshInstance3D
## The same sprite drawn as a silhouette where walls or crowns hide the player.
var xray: MeshInstance3D
var torch: OmniLight3D


func _ready() -> void:
	var tex := SpriteArt.texture("player")
	var mesh := PixelView.sprite_mesh(tex.get_width(), tex.get_height())
	sprite = MeshInstance3D.new()
	sprite.mesh = mesh
	sprite.material_override = sprite_material(SpriteShader, tex)
	sprite.extra_cull_margin = 24.0
	# Placed by place_sprite() on whole pixels, not by the body's position.
	sprite.top_level = true
	add_child(sprite)
	xray = MeshInstance3D.new()
	xray.mesh = mesh
	xray.material_override = sprite_material(XrayShader, tex)
	xray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	xray.extra_cull_margin = 24.0
	xray.top_level = true
	add_child(xray)
	torch = OmniLight3D.new()
	torch.omni_range = 6.5
	torch.omni_attenuation = 1.4
	torch.light_color = Color(1.0, 0.55, 0.25)
	torch.light_energy = 0.0
	torch.top_level = true
	add_child(torch)


static func sprite_material(shader: Shader, tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("sprite_texture", tex)
	return m


func step(delta: float, jump: bool) -> void:
	var dir := move_input.limit_length(1.0)
	var p := position / CELL
	p = _try_move(p, Vector3(dir.x * SPEED * delta, 0.0, 0.0))
	p = _try_move(p, Vector3(0.0, 0.0, dir.y * SPEED * delta))
	if on_ground and not jump:
		var below := _ground_top(p, p.y - STEP_DOWN, p.y)
		if below > -INF:
			p.y = below
	if jump and on_ground:
		velocity_y = JUMP_SPEED
	velocity_y = maxf(velocity_y - GRAVITY * delta, -MAX_FALL)
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


## Puts the sprite on the body, snapped to whole pixels, and the torch above it
## (lights live where the shaders draw, so its position is sheared).
func place_sprite() -> void:
	sprite.global_position = PixelView.snap(position)
	xray.global_position = sprite.global_position
	torch.global_position = PixelView.shear(position + Vector3(0.0, 1.2, 0.3))


## The level of the cell the feet are in.
func level() -> int:
	return floori(position.y / CELL + 0.01)


## True if the body would overlap the cell.
func overlaps_cell(cell: Vector3i) -> bool:
	var p := position / CELL
	return cell.x == clampi(cell.x, floori(p.x - HALF_WIDTH), floori(p.x + HALF_WIDTH)) \
		and cell.z == clampi(cell.z, floori(p.z - HALF_WIDTH), floori(p.z + HALF_WIDTH)) \
		and cell.y == clampi(cell.y, floori(p.y + 0.001), floori(p.y + HEIGHT))


func _try_move(p: Vector3, d: Vector3) -> Vector3:
	if d == Vector3.ZERO:
		return p
	var np := p + d
	if not _collides(np):
		return np
	# Follow ground rising a little: a slope, not a sheer step.
	if on_ground:
		var top := _ground_top(np, p.y, p.y + STEP_UP)
		if top > p.y:
			var up := Vector3(np.x, top, np.z)
			if not _collides(up) and not _collides(Vector3(p.x, top, p.z)):
				return up
	return p


func _collides(p: Vector3) -> bool:
	var x0 := floori(p.x - HALF_WIDTH)
	var x1 := floori(p.x + HALF_WIDTH)
	var z0 := floori(p.z - HALF_WIDTH)
	var z1 := floori(p.z + HALF_WIDTH)
	var y0 := floori(p.y + 0.001)
	var y1 := floori(p.y + HEIGHT)
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var f := _footprint(x, z, p)
				if not world.blocks_part(x, y, z, f.position.x, f.end.x, f.position.y, f.end.y):
					continue
				# A sloping cell only blocks below its surface under the feet.
				if y != y0 or p.y + 0.001 < y + _cell_top(x, y, z, p):
					return true
	return false


## Height of the highest ground the feet at `p` would stand on, among surfaces between
## `lo` and `hi`; -INF when there is none.
func _ground_top(p: Vector3, lo: float, hi: float) -> float:
	var best := -INF
	for y in range(floori(lo), floori(hi) + 1):
		for z in range(floori(p.z - HALF_WIDTH), floori(p.z + HALF_WIDTH) + 1):
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
	var a := Vector2(clampf(p.x - HALF_WIDTH - x, 0.0, 1.0), clampf(p.z - HALF_WIDTH - z, 0.0, 1.0))
	var b := Vector2(clampf(p.x + HALF_WIDTH - x, 0.0, 1.0), clampf(p.z + HALF_WIDTH - z, 0.0, 1.0))
	return Rect2(a, b - a)


## Top of a solid cell under the footprint at `p`, 0..1: 1 for a cube, the highest
## point of the slope under the feet otherwise.
func _cell_top(x: int, y: int, z: int, p: Vector3) -> float:
	if not Mat.can_slope(world.get_cell(x, y, z)):
		return 1.0
	var mask: int = world.slope_mask(x, y, z)
	if mask == WorldData.FULL:
		return 1.0
	var cuts: int = world.corner_cuts(x, y, z)
	var ax := clampf(p.x - HALF_WIDTH - x, 0.0, 1.0)
	var bx := clampf(p.x + HALF_WIDTH - x, 0.0, 1.0)
	var az := clampf(p.z - HALF_WIDTH - z, 0.0, 1.0)
	var bz := clampf(p.z + HALF_WIDTH - z, 0.0, 1.0)
	var top := 0.0
	for i in 3:
		for k in 3:
			top = maxf(top, WorldData.slope_height(mask, lerpf(ax, bx, i * 0.5), lerpf(az, bz, k * 0.5), cuts))
	return top
