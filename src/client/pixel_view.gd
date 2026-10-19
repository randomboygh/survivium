extends RefCounted
## Pixel-perfect view math. The 3D scene renders into a low-resolution image that is
## scaled up by a whole number, and the orthographic camera shows exactly
## PIXELS_PER_UNIT low-res pixels per world unit, so one texel of a 16 px texture is
## one pixel on screen. The camera and every moving sprite are snapped to whole
## pixels, otherwise a sprite drifting between pixels gains or loses a pixel column.

const PIXELS_PER_UNIT := 16.0
## Wanted height of the low-res image; the real one is within about 20% of it.
const TARGET_HEIGHT := 360.0


## Upscale factor and low-res image size for a screen. Both sides are even, so the
## camera centre falls on a pixel corner; the image covers the whole screen and is
## cropped by less than 2 * scale screen pixels at the right and bottom.
static func layout(screen: Vector2) -> Array:
	var scale := maxi(1, roundi(screen.y / TARGET_HEIGHT))
	var w := maxi(2, ceili(screen.x / scale / 2.0) * 2)
	var h := maxi(2, ceili(screen.y / scale / 2.0) * 2)
	return [scale, Vector2i(w, h)]


## Orthographic camera size (vertical extent in world units) for a low-res image height.
static func camera_size(image_height: int) -> float:
	return image_height / PIXELS_PER_UNIT


## Moves a point so that it lands on a pixel corner of a camera with basis `b` whose
## own position was snapped the same way. Depth along the view axis is kept.
static func snap(p: Vector3, b: Basis) -> Vector3:
	var px := 1.0 / PIXELS_PER_UNIT
	var right := snappedf(p.dot(b.x), px)
	var up := snappedf(p.dot(b.y), px)
	return b.x * right + b.y * up + b.z * p.dot(b.z)


## Sprite3D settings that keep a pixel-art sprite on the pixel grid: one texel per
## pixel, and a half-pixel offset for odd sizes so texel edges meet pixel edges when
## the sprite's origin sits on a pixel corner.
static func setup_sprite(sprite: Sprite3D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.pixel_size = 1.0 / PIXELS_PER_UNIT
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.offset = Vector2(0.5 * (texture.get_width() % 2), 0.5 * (texture.get_height() % 2))
