extends TextureRect
## PROTOTYPE (setting side_cut): a small section of the world seen from the side, along
## the way the camera looks through the player: away from the camera on the left,
## toward it on the right, levels up and down; the player marked in the middle.

const PixelView := preload("res://src/client/view/pixel_view.gd")
const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const Mat := preload("res://src/shared/content/materials.gd")

const HALF_W := 16
const HALF_H := 12
const SCALE := 4
const CELL := 0.5

var game
var image := Image.create(2 * HALF_W + 1, 2 * HALF_H + 1, false, Image.FORMAT_RGBA8)
var _clock := 0.0
var _colors := {}


func _init(g) -> void:
	game = g
	texture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	custom_minimum_size = Vector2(image.get_width(), image.get_height()) * SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _color(m: int) -> Color:
	if not _colors.has(m):
		_colors[m] = PixelTextures.tint(m).darkened(0.15)
	return _colors[m]


func update(delta: float) -> void:
	visible = bool(game.settings.values.get("side_cut", false)) and game.world != null
	if not visible:
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.25
	var w = game.world
	var p: Vector3 = game.player.position / CELL
	var level: int = game.player.level()
	var toward := -PixelView.up
	var air := Color(0.07, 0.07, 0.09)
	for i in range(-HALF_W, HALF_W + 1):
		var cx := floori(p.x + toward.x * i)
		var cz := floori(p.z + toward.y * i)
		var water: int = w.water_col(cx, cz)
		for j in range(-HALF_H, HALF_H + 1):
			var y := level + j
			var c := air
			if y >= 0 and y < w.size_y:
				var m: int = w.get_cell(cx, y, cz)
				if water & (1 << y):
					c = Color(0.2, 0.35, 0.6)
				elif m != Mat.AIR:
					c = _color(m)
			image.set_pixel(i + HALF_W, HALF_H - j, c)
	# The player, two cells tall, and a frame round the picture.
	image.set_pixel(HALF_W, HALF_H, Color(1.0, 0.85, 0.3))
	image.set_pixel(HALF_W, HALF_H - 1, Color(1.0, 0.85, 0.3))
	for x in image.get_width():
		image.set_pixel(x, 0, Color(0.0, 0.0, 0.0, 0.8))
		image.set_pixel(x, image.get_height() - 1, Color(0.0, 0.0, 0.0, 0.8))
	for y in image.get_height():
		image.set_pixel(0, y, Color(0.0, 0.0, 0.0, 0.8))
		image.set_pixel(image.get_width() - 1, y, Color(0.0, 0.0, 0.0, 0.8))
	texture.update(image)
