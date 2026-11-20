extends Node
## Grass trodden down where someone walked (the player, the other players, the beasts):
## a map of the ground round the player (trample_map in grass.gdshader), a texel for
## each quarter of a world unit, naming when it was trodden, which way its tufts were
## pushed and how hard, and its level. The grass shader lays the tufts over that way and
## lower, and they stand up again over LIFE seconds. Tracks.leave stamps it at every
## stride, so whoever leaves prints treads the grass too.
##
## The map repeats every MAP texels each way, like the prints' (tracks.gd): the texel
## of world texel (x, z) is (x, z) modulo MAP; as the player moves on, the rows and
## columns left behind are cleared for the ground ahead.

const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## Texels per world unit (TRAMPLE_TEXELS in grass.gdshader).
const TEXELS := 4
## Texels of the map each way: twice Tracks.REACH (TRAMPLE_MAP in grass.gdshader).
const MAP := 192
## How far round the feet a person treads the grass, in world units, at scale 1.
const RADIUS := 0.45
## Seconds until trodden grass stands up again (TRAMPLE_LIFE in grass.gdshader).
const LIFE := 9.0
## Directions a push is kept in (TRAMPLE_DIRS in grass.gdshader).
const DIRS := 16
## The map is sent to the renderer at most this often, in seconds, for what nobody
## waits to see (the window moving on, grass standing up again).
const FLUSH := 0.15
## Grass newly trodden is sent at once, unless the map went less than this long ago
## (seconds; as Tracks.SOON), so it bends under the foot, not after it.
const SOON := 0.05
## The clock the stamps are made with wraps here (a byte of the map).
const WRAP := 256.0

## Where the player is, kept up to date by Tracks.
var focus := Vector3.ZERO
var image: Image
var texture: ImageTexture
## Seconds since the start, not wrapped (trample_now is this modulo WRAP).
var elapsed := 0.0
## The world texel at the north-west corner of the window the map covers now.
var _window := Vector2i.ZERO
var _dirty := false
## Grass was trodden since the map was last sent (it goes within SOON).
var _fresh := false
var _since := 0.0
## Seconds since the map was last sent.
var _sent := 0.0
## The stamps not yet expired, oldest first: [when it expires (elapsed), its stamp
## (the byte of the clock), its texels (x, z in the map, packed)].
var _living: Array = []


func _init() -> void:
	image = Image.create_empty(MAP, MAP, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)
	PixelTextures.set_global("trample_map", texture)
	RenderingServer.global_shader_parameter_set("trample_now", 0.0)


func _process(delta: float) -> void:
	step(delta)


## Moves the clock and the window on by `delta` seconds, clears what has stood up and
## sends the map to the renderer when it changed.
func step(delta: float) -> void:
	elapsed += delta
	RenderingServer.global_shader_parameter_set("trample_now", fmod(elapsed, WRAP))
	_follow()
	_since += delta
	_sent += delta
	if _since >= FLUSH:
		_since = 0.0
		_expire()
	if _dirty and (_sent >= FLUSH or (_fresh and _sent >= SOON)):
		_dirty = false
		_fresh = false
		_sent = 0.0
		texture.update(image)


## The window's north-west world texel for a player at `at`.
static func corner(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x * TEXELS), floori(at.z * TEXELS)) - Vector2i(MAP / 2, MAP / 2)


## Moves the window with the player, clearing the rows and columns it leaves behind.
func _follow() -> void:
	var now := corner(focus)
	var d := now - _window
	if d == Vector2i.ZERO:
		return
	if absi(d.x) >= MAP or absi(d.y) >= MAP:
		image.fill(Color(0, 0, 0, 0))
	else:
		if d.x != 0:
			_clear_band(mini(_window.x, now.x) + (MAP if d.x > 0 else 0), absi(d.x), true)
		if d.y != 0:
			_clear_band(mini(_window.y, now.y) + (MAP if d.y > 0 else 0), absi(d.y), false)
	_window = now
	_dirty = true


func _clear_band(start: int, count: int, columns: bool) -> void:
	var from := posmod(start, MAP)
	var first := mini(count, MAP - from)
	for part: Vector2i in [Vector2i(from, first), Vector2i(0, count - first)]:
		if part.y <= 0:
			continue
		var rect := Rect2i(part.x, 0, part.y, MAP) if columns else Rect2i(0, part.x, MAP, part.y)
		image.fill_rect(rect, Color(0, 0, 0, 0))


## Clears the stamps whose time is over, where no later one has been laid on them: the
## clock the map keeps wraps, and an old stamp would come back.
func _expire() -> void:
	while not _living.is_empty() and _living[0][0] <= elapsed:
		var gone: Array = _living.pop_front()
		var stamp: int = gone[1]
		for packed: int in gone[2]:
			var x := packed % MAP
			var z := packed / MAP
			if roundi(image.get_pixel(x, z).r * 255.0) == stamp:
				image.set_pixel(x, z, Color(0, 0, 0, 0))
				_dirty = true


## Treads the grass round `feet` (the middle of the body on the ground), walking toward
## `heading` (x east, y south), over a disc `scale` times a person's: the tufts in the
## middle are laid forward, those at its edge aside, away from the path, and less.
func tread(feet: Vector3, heading: Vector2, scale: float) -> void:
	if heading.length_squared() < 0.0001:
		return
	var f := heading.normalized()
	var radius := RADIUS * scale
	var reach := ceili(radius * TEXELS)
	var centre := Vector2i(floori(feet.x * TEXELS), floori(feet.z * TEXELS))
	var stamp := int(fmod(elapsed, WRAP))
	var level := posmod(roundi(feet.y / WorldData.CELL), 256)
	var texels := PackedInt32Array()
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := centre + Vector2i(dx, dz)
			if t.x < _window.x or t.y < _window.y or t.x >= _window.x + MAP or t.y >= _window.y + MAP:
				continue
			var o := Vector2((t.x + 0.5) / TEXELS - feet.x, (t.y + 0.5) / TEXELS - feet.z)
			var d := o.length() / radius
			if d > 1.0:
				continue
			var side := o - f * o.dot(f)
			var push := f + side / radius * 1.6
			var dir := posmod(roundi(atan2(push.y, push.x) / (TAU / DIRS)), DIRS)
			# Three strengths: full in the middle, less toward the edge.
			var strength := clampi(3 - floori(d * 2.0), 1, 3)
			var at := Vector2i(posmod(t.x, MAP), posmod(t.y, MAP))
			image.set_pixelv(at, Color8(stamp, dir + DIRS * strength, level, 255))
			texels.append(at.y * MAP + at.x)
	if texels.is_empty():
		return
	_living.append([elapsed + LIFE + 1.0, stamp, texels])
	_dirty = true
	_fresh = true
