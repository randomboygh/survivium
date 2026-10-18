extends Node3D
## Player body on the cell grid: walks, steps up one level by itself, jumps,
## cannot enter water. `position` is the middle of the feet.

const SpriteArt := preload("res://src/client/sprite_art.gd")

const HALF_WIDTH := 0.3
const HEIGHT := 0.9
const SPEED := 4.0
const GRAVITY := 22.0
const JUMP_SPEED := 7.5
const MAX_FALL := 15.0

var world
## Movement wish: x = east, y = south, length up to 1.
var move_input := Vector2.ZERO
var velocity_y := 0.0
var on_ground := false
var sprite: Sprite3D
var torch: OmniLight3D


func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.texture = SpriteArt.texture("player")
	sprite.pixel_size = 1.0 / 16.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.position.y = sprite.texture.get_height() / 32.0
	add_child(sprite)
	torch = OmniLight3D.new()
	torch.position = Vector3(0.0, 1.2, 0.0)
	torch.omni_range = 7.0
	torch.light_color = Color(1.0, 0.75, 0.45)
	torch.light_energy = 0.0
	add_child(torch)


func step(delta: float, jump: bool) -> void:
	var dir := move_input.limit_length(1.0)
	var p := position
	p = _try_move(p, Vector3(dir.x * SPEED * delta, 0.0, 0.0))
	p = _try_move(p, Vector3(0.0, 0.0, dir.y * SPEED * delta))
	if jump and on_ground:
		velocity_y = JUMP_SPEED
	velocity_y = maxf(velocity_y - GRAVITY * delta, -MAX_FALL)
	var ny := p.y + velocity_y * delta
	if _collides(Vector3(p.x, ny, p.z)):
		if velocity_y < 0.0:
			p.y = floorf(ny) + 1.0
			on_ground = true
		velocity_y = 0.0
	else:
		p.y = ny
		on_ground = false
	position = p


func level() -> int:
	return floori(position.y + 0.01)


## True if a body standing at `p` would overlap the cell.
func overlaps_cell(cell: Vector3i) -> bool:
	var p := position
	return cell.x == clampi(cell.x, floori(p.x - HALF_WIDTH), floori(p.x + HALF_WIDTH)) \
		and cell.z == clampi(cell.z, floori(p.z - HALF_WIDTH), floori(p.z + HALF_WIDTH)) \
		and cell.y == clampi(cell.y, floori(p.y + 0.001), floori(p.y + HEIGHT))


func _try_move(p: Vector3, d: Vector3) -> Vector3:
	if d == Vector3.ZERO:
		return p
	var np := p + d
	if not _collides(np):
		return np
	# Step up one level when the obstacle is one cell high.
	if on_ground:
		var up := Vector3(np.x, floorf(p.y + 0.01) + 1.0, np.z)
		if not _collides(up) and not _collides(Vector3(p.x, up.y, p.z)):
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
				if world.blocks_body(x, y, z):
					return true
	return false
