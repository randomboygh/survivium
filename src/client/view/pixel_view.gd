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
## Direction of view rays in the unsheared world in the default view: down and north
## at 45 degrees.
const VIEW_DIR := Vector3(0.0, -0.70710678, -0.70710678)
## The view's elevation in the default view, and how far the camera may tilt from it.
const ELEVATION := PI / 4.0
const MAX_TILT := PI / 12.0

## The view the shaders draw (see set_view): which way of the world is up on the image
## (x, z), how much the tops are stretched along it and how long a wall of one unit is,
## both 1 in the default view (looking north, 45 degrees down).
static var up := Vector2(0.0, -1.0)
static var right := Vector2(1.0, 0.0)
static var squash := 1.0
static var slope := 1.0
## The views the culling boxes must hold (see sheared_box): the one shown and, while
## the camera turns, the one it turns to. Each is [up, squash, slope].
static var box_views: Array = [[Vector2(0.0, -1.0), 1.0, 1.0]]


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


## Sets the view: the camera turned `turn` radians to the left from looking north
## (a quarter turn looks west) and tilted `tilt` radians from 45 degrees down (more is steeper). The
## camera still looks straight down; the shaders move each point up the image by its
## height (`slope`) and stretch the tops along it (`squash`), as a real camera at that
## elevation would draw them, scaled so that the default view keeps its 16 px cells.
## Sets the shader globals too.
static func set_view(turn: float, tilt: float) -> void:
	var v := view_of(turn, tilt)
	up = v[0]
	right = Vector2(-up.y, up.x)
	squash = v[1]
	slope = v[2]
	RenderingServer.global_shader_parameter_set("view_up", up)
	RenderingServer.global_shader_parameter_set("view_squash", squash)
	RenderingServer.global_shader_parameter_set("view_slope", slope)


## [up, squash, slope] of a view (see set_view).
static func view_of(turn: float, tilt: float) -> Array:
	var el := ELEVATION + tilt
	return [Vector2(-sin(turn), -cos(turn)), sqrt(2.0) * sin(el), sqrt(2.0) * cos(el)]


## Where the shaders draw a world point: moved up the image by its height, the tops
## stretched along it (see set_view; in the default view simply north by its height).
static func shear(p: Vector3) -> Vector3:
	return _shear(p, up, squash, slope)


static func _shear(p: Vector3, u: Vector2, sq: float, sl: float) -> Vector3:
	var s := Vector2(p.x, p.z)
	s += u * (s.dot(u) * (sq - 1.0) + sl * p.y)
	return Vector3(s.x, p.y, s.y)


## The box that what a mesh with box `a` draws takes up once the shaders have moved
## each point (shear), in every view of box_views, `margin` world units larger all
## round for what the shaders sway or raise a little (leaves, grass, ice). Set as a
## node's custom_aabb, it lets the camera cull the node exactly as it shows.
static func sheared_box(a: AABB, margin: float) -> AABB:
	var c := a.get_center()
	var h := a.size * 0.5
	var lo := Vector2(INF, INF)
	var hi := -lo
	for v: Array in box_views:
		# shear is linear: x' = A (x, z) + b y, so the box's middle goes where shear puts
		# it and its half size spreads by the absolute weights.
		var u: Vector2 = v[0]
		var k: float = v[1] - 1.0
		var b: Vector2 = u * float(v[2])
		var a00 := 1.0 + k * u.x * u.x
		var a01 := k * u.x * u.y
		var a11 := 1.0 + k * u.y * u.y
		var mid := Vector2(a00 * c.x + a01 * c.z + b.x * c.y, a01 * c.x + a11 * c.z + b.y * c.y)
		var ext := Vector2(absf(a00) * h.x + absf(a01) * h.z + absf(b.x) * h.y,
			absf(a01) * h.x + absf(a11) * h.z + absf(b.y) * h.y)
		lo = lo.min(mid - ext)
		hi = hi.max(mid + ext)
	return AABB(Vector3(lo.x, a.position.y, lo.y) - Vector3.ONE * margin,
		Vector3(hi.x - lo.x, a.size.y, hi.y - lo.y) + Vector3.ONE * 2.0 * margin)


## Position of a world point on the screen plane, in world units (x right, y down).
static func screen_plane(p: Vector3) -> Vector2:
	var s := shear(p)
	return plane_of(Vector2(s.x, s.z))


## The screen-plane point over the drawn (sheared) point (x, z) `s`, such as the
## camera's position.
static func plane_of(s: Vector2) -> Vector2:
	return Vector2(s.dot(right), -s.dot(up))


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
	var b := Basis(Vector3(right.x, 0.0, right.y), Vector3(up.x, 0.0, up.y), Vector3.UP)
	var s := right * c.x - up * c.y
	return Transform3D(b, Vector3(s.x, CAMERA_HEIGHT, s.y))


## A world direction (x, z) for a direction on the screen (x right, y down), such as
## the way the stick or the keys push.
static func world_dir(d: Vector2) -> Vector2:
	return right * d.x - up * d.y


## A direction on the screen for a world direction (x, z): world_dir undone.
static func screen_dir(d: Vector2) -> Vector2:
	return Vector2(d.dot(right), -d.dot(up))


## View ray through a low-res pixel `offset` from the image centre, for a camera
## centred on screen-plane point `c`. Returns [origin, direction] in the unsheared
## world; the origin is at height `top`.
static func view_ray(c: Vector2, offset: Vector2, top: float) -> Array:
	var q := c + offset / PIXELS_PER_UNIT
	var s := right * q.x - up * q.y - up * slope * top
	# The tops are stretched along `up` by `squash`: undo it.
	s += up * s.dot(up) * (1.0 / squash - 1.0)
	var run := up * slope / squash
	return [Vector3(s.x, top, s.y), Vector3(run.x, -1.0, run.y).normalized()]


## The direction to the sun the shaders must be given for the shadows to fall on the
## ground where they fall in the default view: the light is in the drawn (sheared)
## world too. `to_sun` is the direction in the default view.
static func light_dir(to_sun: Vector3) -> Vector3:
	if to_sun.y <= 0.001:
		return to_sun
	# How far the shadow of a unit of height reaches over the ground in the default
	# view, then where that lies once drawn in this one.
	var w := Vector2(0.0, -1.0) - Vector2(to_sun.x, to_sun.z) / to_sun.y
	var drawn := Vector2(w.x, w.y)
	drawn += up * drawn.dot(up) * (squash - 1.0)
	var run := up * slope - drawn
	return Vector3(run.x * to_sun.y, to_sun.y, run.y * to_sun.y).normalized()


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
