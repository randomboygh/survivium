extends RefCounted
## A sheet of animation frames for an upright sprite, described by data: a grid of
## frames with one row per drawn direction, the directions that are mirrors of a
## drawn one, named animations as lists of columns, and layers (body, hair, clothes,
## a tool in hand) drawn over each other in order. The layers are composited into
## one texture, so a sprite is one quad with one texture whatever it wears; changing
## a layer builds the texture again. The description is shaped like the data a mod
## will carry (see plan/architecture/modding.md), so it can move there as is.
##
## Description keys:
##   frame: [width, height] of a frame in pixels; the feet stand on the bottom row.
##   directions: drawn directions, one row each, e.g. ["s", "se", "e", "ne", "n"].
##   mirror: {direction: drawn direction} for directions shown flipped.
##   animations: {name: {"frames": [column, ...], "fps": float}}.
##   outline: true draws a one-pixel outline around the composited figure (the
##     outermost pixels of each frame have to stay clear for it).
## A layer is {"name": String, "image": Image, "behind": [direction, ...]}: the image
## is the whole grid for that layer; in the directions listed in `behind` the layer
## goes under the ones before it (a tool held in the far hand).

const OUTLINE := Color(0.12, 0.1, 0.08)
## All eight directions in order of the compass turned clockwise from south, so
## direction_of() can pick one by angle.
const COMPASS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]

var frame_size: Vector2i
var directions: Array
var mirror: Dictionary
var animations: Dictionary
var outline: bool
var layers: Array = []
var texture: ImageTexture
var columns := 1
## The image being composited (see begin).
var _img: Image
## Images filled with OUTLINE, by size.
static var _dark := {}


func _init(description: Dictionary) -> void:
	frame_size = Vector2i(description.frame[0], description.frame[1])
	directions = description.directions
	mirror = description.get("mirror", {})
	animations = description.animations
	outline = description.get("outline", false)
	for anim in animations.values():
		for col in anim.frames:
			columns = maxi(columns, col + 1)


## Replaces the layers and builds the texture.
func set_layers(new_layers: Array) -> void:
	begin(new_layers)
	for row in directions.size():
		compose_row(row)
	finish()


## Starts compositing `new_layers` into a new image a row at a time (compose_row), so
## the work can be spread over frames; finish() puts the image into the texture.
func begin(new_layers: Array) -> void:
	layers = new_layers
	_img = Image.create_empty(frame_size.x * columns, frame_size.y * directions.size(), false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))


## Composites the frames of one direction and outlines them.
func compose_row(row: int) -> void:
	var dir: String = directions[row]
	var order: Array = []
	for layer in layers:
		if layer.get("behind", []).has(dir):
			order.append(layer)
	for layer in layers:
		if not layer.get("behind", []).has(dir):
			order.append(layer)
	var rect := Rect2i(0, row * frame_size.y, frame_size.x * columns, frame_size.y)
	for layer in order:
		_img.blend_rect(layer.image, rect, rect.position)
	if outline:
		_outline(_img, rect)


func finish() -> void:
	if texture == null:
		texture = ImageTexture.create_from_image(_img)
	else:
		texture.set_image(_img)
	_img = null


## The eight-way direction a movement wish points to (x east, y south).
static func direction_of(move: Vector2) -> String:
	# Clockwise from south: south is 0, west a quarter turn, north a half.
	var turn := fposmod(atan2(-move.x, move.y) / TAU, 1.0)
	return COMPASS[roundi(turn * 8.0) % 8]


## UV rectangle (offset x, y, size x, y) of the frame to show: direction `dir`,
## animation `anim` at time `t` seconds. A mirrored direction gets a negative width,
## so the shader samples the drawn direction flipped.
func frame_uv(dir: String, anim: String, t: float) -> Vector4:
	var flipped := mirror.has(dir)
	var drawn: String = mirror[dir] if flipped else dir
	var row := maxi(0, directions.find(drawn))
	var a: Dictionary = animations[anim]
	var frames: Array = a.frames
	var col: int = frames[int(t * a.fps) % frames.size()]
	var w := 1.0 / columns
	var h := 1.0 / directions.size()
	if flipped:
		return Vector4((col + 1) * w, row * h, -w, h)
	return Vector4(col * w, row * h, w, h)


## Draws OUTLINE on every clear pixel of `r` next to a drawn one (4 neighbours), the
## way the text sprites in sprite_art.gd outline themselves: the figure is stamped dark
## one pixel each way under itself. The outermost pixels of a frame have to stay clear,
## or the outline would spill into the next frame.
static func _outline(img: Image, r: Rect2i) -> void:
	var part := img.get_region(r)
	var whole := Rect2i(Vector2i.ZERO, r.size)
	if not _dark.has(r.size):
		var d := Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		d.fill(OUTLINE)
		_dark[r.size] = d
	var out := Image.create_empty(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		out.blit_rect_mask(_dark[r.size], part, whole, d)
	out.blend_rect(part, whole, Vector2i.ZERO)
	img.blit_rect(out, whole, r.position)
