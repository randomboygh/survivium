extends RefCounted
## Pixel-perfect oblique 3/4 view. The 3D scene renders into a low-resolution image
## that is scaled up by a whole number. The orthographic camera looks straight down,
## and the shaders move every vertex north by its height (`shear`), so on screen a
## cell's top and its south wall are both exactly PIXELS_PER_UNIT pixels square and
## one texel of a 16 px texture is always one pixel. Things that move are snapped to
## 1/16 of a cell; the camera follows smoothly by shifting the upscaled image by the
## leftover fraction of a pixel.

const PIXELS_PER_UNIT := 16.0
## Wanted height of the low-res image; the real one is within about 20% of it.
const TARGET_HEIGHT := 360.0
## Extra low-res pixels rendered on each side, room for the sub-pixel camera shift.
const MARGIN := 1
## Height of the camera above the world; it must be above the highest level.
const CAMERA_HEIGHT := 48.0
## Render layers that pick which lights a thing casts its shadow from (each light's
## shadow_caster_mask); everything else is on layer 1 and casts from every light.
## The shadow discs under crowns and bushes cast only from the sun and the moon: from
## a fire below a crown they would throw the crown's shadow upward.
const LAYER_SUN_CASTER := 4
## The player's sprite, which the torch in the player's hand does not shade.
const LAYER_PLAYER := 8
## Direction of view rays in the unsheared world: down and north at 45 degrees.
const VIEW_DIR := Vector3(0.0, -0.70710678, -0.70710678)


## Upscale factor and low-res image size for a screen. Both sides are even, so the
## camera centre falls on a pixel corner; the image covers the whole screen and is
## cropped by less than 2 * scale screen pixels at the right and bottom.
static func layout(screen: Vector2, target_height := TARGET_HEIGHT) -> Array:
	var scale := maxi(1, roundi(screen.y / target_height))
	var w := maxi(2, ceili(screen.x / scale / 2.0) * 2)
	var h := maxi(2, ceili(screen.y / scale / 2.0) * 2)
	return [scale, Vector2i(w, h)]


## Orthographic camera size (vertical extent in world units) for a low-res image height.
static func camera_size(image_height: int) -> float:
	return image_height / PIXELS_PER_UNIT


## Where the shaders draw a world point: moved north by its height.
static func shear(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y, p.z - p.y)


## The box that what a mesh with box `a` draws takes up once the shaders have moved
## each point north by its height (shear), `margin` world units larger all round for
## what the shaders sway or raise a little (leaves, grass, ice). Set as a node's
## custom_aabb, it lets the camera cull the node exactly as it shows.
static func sheared_box(a: AABB, margin: float) -> AABB:
	var lo := a.position
	var hi := a.end
	return AABB(Vector3(lo.x, lo.y, lo.z - hi.y) - Vector3.ONE * margin,
		Vector3(a.size.x, a.size.y, a.size.z + a.size.y) + Vector3.ONE * 2.0 * margin)


## Position of a world point on the screen plane, in world units (x right, y down).
static func screen_plane(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z - p.y)


## Snaps a world point to 1/16 of a cell, so it lands on whole pixels on screen.
static func snap(p: Vector3) -> Vector3:
	var px := 1.0 / PIXELS_PER_UNIT
	return Vector3(snappedf(p.x, px), snappedf(p.y, px), snappedf(p.z, px))


static func snap_plane(c: Vector2) -> Vector2:
	var px := 1.0 / PIXELS_PER_UNIT
	return Vector2(snappedf(c.x, px), snappedf(c.y, px))


## Camera transform that shows the screen-plane point `c` (already snapped) in the
## middle of the image.
static func camera_transform(c: Vector2) -> Transform3D:
	var b := Basis.from_euler(Vector3(-PI / 2.0, 0.0, 0.0))
	return Transform3D(b, Vector3(c.x, CAMERA_HEIGHT, c.y))


## View ray through a low-res pixel `offset` from the image centre, for a camera
## centred on screen-plane point `c`. Returns [origin, direction] in the unsheared
## world; the origin is at height `top`.
static func view_ray(c: Vector2, offset: Vector2, top: float) -> Array:
	var p := c + offset / PIXELS_PER_UNIT
	return [Vector3(p.x, top, p.y + top), VIEW_DIR]


## Upright quad for a pixel-art sprite: one texel per pixel, bottom edge at the origin,
## left and right edges on whole pixels so the sprite stays sharp when the origin is
## snapped.
static func sprite_mesh(width: int, height: int) -> ArrayMesh:
	var px := 1.0 / PIXELS_PER_UNIT
	var x0 := -floorf(width / 2.0) * px
	var x1 := x0 + width * px
	var y1 := height * px
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(x0, 0, 0), Vector3(x0, y1, 0), Vector3(x1, y1, 0), Vector3(x1, 0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
