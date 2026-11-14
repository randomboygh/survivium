extends Node3D
## Footprints left behind by the player and the animals, kept in a map of the ground
## round the player (print_map in common.gdshaderinc): a texel for each texel of the
## ground, naming the kind of print there, its level and when it was made. The ground's
## own shaders (world.gdshader; water.gdshader on ice) darken their colour under a
## print before the light and the fog fall on it, so a fog hides a print just as it
## hides the ground round it, and grass and flowers standing over it cover it. The
## shaders fade a print out with age. Prints stay longer in snow and on ice than on
## soil; stone takes them only under a roof, in the dust of a cave floor; planks, stone
## in the open and open water take none.
##
## The map repeats every MAP texels each way: the texel of world texel (x, z) is
## (x, z) modulo MAP. It covers REACH round the player; as the player moves on, the
## rows and columns left behind are cleared for the ground ahead.

const PixelTextures := preload("res://src/client/view/pixel_textures.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

## Prints farther than this from `focus` are not kept: nobody sees them.
const REACH := 24.0
## Texels per world unit (TEXELS in common.gdshaderinc).
const TEXELS := 16
## Texels of the map each way: twice REACH (PRINT_MAP in common.gdshaderinc).
const MAP := 768
## A print's square in world units at scale 1: four texels.
const QUAD := 0.25
const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## The kinds of print (the shader's PRINT_TINT holds their colours) and how long each
## lasts in seconds (PRINT_LIFE there, the same).
enum { NONE, SNOW, ICE, GRASS_DRY, GRASS_WET, SOIL_DRY, SOIL_WET, DUST }
const LIFE := [0.0, 120.0, 90.0, 20.0, 40.0, 45.0, 45.0, 60.0]
## The map is sent to the renderer at most this often, in seconds.
const FLUSH := 0.2
## The clock the prints are stamped with wraps here (a byte of the map).
const WRAP := 256.0

var world
## Where the player is, kept up to date by the game.
var focus := Vector3.ZERO
## Snow cover and wetness of the ground, kept up to date by the game.
var snow := 0.0
var wet := 0.0
var image: Image
var texture: ImageTexture
## Seconds since the start, not wrapped.
var elapsed := 0.0
## The world texel at the north-west corner of the window the map covers now.
var _window := Vector2i.ZERO
var _dirty := false
var _since := 0.0
## The prints not yet expired, oldest first: [when it expires (elapsed), its stamp
## (the byte of the clock), its texels (x, z in the map, packed)].
var _living: Array = []


func _ready() -> void:
	image = Image.create_empty(MAP, MAP, false, Image.FORMAT_RG8)
	texture = ImageTexture.create_from_image(image)
	PixelTextures.set_global("print_map", texture)
	_window = _corner(focus)
	RenderingServer.global_shader_parameter_set("print_now", 0.0)


func _process(delta: float) -> void:
	elapsed += delta
	RenderingServer.global_shader_parameter_set("print_now", fmod(elapsed, WRAP))
	_follow()
	_since += delta
	if _since < FLUSH:
		return
	_since = 0.0
	_expire()
	if _dirty:
		_dirty = false
		texture.update(image)


## The window's north-west world texel for a player at `at`.
static func _corner(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x * TEXELS), floori(at.z * TEXELS)) - Vector2i(MAP / 2, MAP / 2)


## Moves the window with the player, clearing the rows and columns it leaves behind:
## they come back as the ground on the other side.
func _follow() -> void:
	var now := _corner(focus)
	var d := now - _window
	if d == Vector2i.ZERO:
		return
	if absi(d.x) >= MAP or absi(d.y) >= MAP:
		image.fill(Color(0, 0, 0))
	else:
		if d.x != 0:
			_clear_band(mini(_window.x, now.x) + (MAP if d.x > 0 else 0), absi(d.x), true)
		if d.y != 0:
			_clear_band(mini(_window.y, now.y) + (MAP if d.y > 0 else 0), absi(d.y), false)
	_window = now
	_dirty = true


## Clears `count` world columns (or rows) from world texel `start`, where the map
## repeats them.
func _clear_band(start: int, count: int, columns: bool) -> void:
	var from := posmod(start, MAP)
	var first := mini(count, MAP - from)
	for part: Vector2i in [Vector2i(from, first), Vector2i(0, count - first)]:
		if part.y <= 0:
			continue
		var rect := Rect2i(part.x, 0, part.y, MAP) if columns else Rect2i(0, part.x, MAP, part.y)
		image.fill_rect(rect, Color(0, 0, 0))


## Clears the prints whose time is over, where no later print has been laid on them:
## the clock the map keeps wraps, and an old print would come back.
func _expire() -> void:
	while not _living.is_empty() and _living[0][0] <= elapsed:
		var gone: Array = _living.pop_front()
		var stamp: int = gone[1]
		for packed: int in gone[2]:
			var x := packed % MAP
			var z := packed / MAP
			if roundi(image.get_pixel(x, z).g * 255.0) == stamp:
				image.set_pixel(x, z, Color(0, 0, 0))
				_dirty = true


## Leaves a print of a foot at the world point `feet` (the middle of the body on the
## ground), stepping toward `heading` (x east, y south); `left` picks the foot and its
## side, `boot` the shape, `scale` the size against a person's print.
func leave(feet: Vector3, heading: Vector2, left: bool, boot: bool, scale: float) -> void:
	if absf(feet.x - focus.x) > REACH or absf(feet.z - focus.z) > REACH:
		return
	var kind := _kind(feet)
	if kind == NONE:
		return
	if heading.length_squared() < 0.0001:
		heading = Vector2(0.0, 1.0)
	# Eight headings, so the print's texels stay on the pixel grid.
	var angle := roundf(atan2(heading.x, heading.y) / (PI / 4.0)) * (PI / 4.0)
	var dir := Vector2(sin(angle), cos(angle))
	var side := Vector2(dir.y, -dir.x) * (1.5 * PX * scale) * (-1.0 if left else 1.0)
	var p := PixelView.snap(feet + Vector3(side.x, 0.0, side.y))
	var stamp := int(fmod(elapsed, WRAP))
	var level := posmod(roundi(feet.y / CELL), 32)
	var mark := Color8(kind << 5 | level, stamp, 0)
	var texels := PackedInt32Array()
	var size := QUAD * scale
	var reach := ceili(size * TEXELS * 0.75)
	var centre := Vector2i(floori(p.x * TEXELS), floori(p.z * TEXELS))
	var c := cos(angle)
	var s := sin(angle)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := centre + Vector2i(dx, dz)
			if t.x < _window.x or t.y < _window.y or t.x >= _window.x + MAP or t.y >= _window.y + MAP:
				continue
			# The texel's middle in the print's own square (the square turned back).
			var wx := (t.x + 0.5) / TEXELS - p.x
			var wz := (t.y + 0.5) / TEXELS - p.z
			var u := (wx * c - wz * s) / size + 0.5
			var v := (wx * s + wz * c) / size + 0.5
			if u < 0.0 or v < 0.0 or u >= 1.0 or v >= 1.0:
				continue
			if not _on(floori(u * 4.0), floori(v * 4.0), boot, left):
				continue
			var at := Vector2i(posmod(t.x, MAP), posmod(t.y, MAP))
			image.set_pixelv(at, mark)
			texels.append(at.y * MAP + at.x)
	if texels.is_empty():
		return
	_living.append([elapsed + LIFE[kind], stamp, texels])
	_dirty = true


## Whether texel `x`, `y` of a print's four by four square is part of the print: the
## middle two columns, three rows of a boot (its toe row one texel wide, on the side of
## its foot) or two of a paw.
static func _on(x: int, y: int, boot: bool, left: bool) -> bool:
	if x < 1 or x > 2:
		return false
	if boot:
		return y <= 2 and (y < 2 or x == (1 if left else 2))
	return y >= 1 and y <= 2


## The kind of print the ground under `feet` takes, NONE where it takes none.
func _kind(feet: Vector3) -> int:
	var cell := Vector3i(floori(feet.x / CELL), floori(feet.y / CELL + 0.01) - 1, floori(feet.z / CELL))
	# Ice lies at the water's surface, inside its cell (see WorldData.ice_top).
	if world.water_frozen and world.get_cell(cell.x, cell.y + 1, cell.z) == Mat.WATER:
		cell.y += 1
	var ground: int = world.get_cell(cell.x, cell.y, cell.z)
	if maxf(snow, world.peak_snow(cell.y + 1)) > 0.6 and ground != Mat.WATER and world.roof_level(cell.x, cell.z) == cell.y:
		return SNOW
	if ground == Mat.WATER and world.water_frozen:
		return ICE
	if ground == Mat.GRASS:
		return GRASS_DRY if wet < 0.5 else GRASS_WET
	if Mat.RECORDS[ground].dig == "shovel":
		# Soft ground: dirt, clay, sand, scree.
		return SOIL_DRY if wet < 0.5 else SOIL_WET
	if Mat.RECORDS[ground].dig == "pickaxe" and world.roof_level(cell.x, cell.z) > cell.y:
		# Dust on the floor of a cave.
		return DUST
	return NONE
