extends RefCounted
## A voxel model as the voxel editor changes it (stage 2 item 3, step 5, 4А): the PNG the
## game reads (VoxelModel.from_image), a row of square slices `side` across, one per level
## from the ground up; a pixel is the voxel at its x and z (z down the slice), clear for
## none, alpha FOLIAGE_ALPHA for a leaf the season tints. Each change before it is kept to
## take back (`undo`).

const VoxelModel := preload("res://src/client/view/voxel_model.gd")

## The narrowest and widest slice, and the most levels.
const SIDE_MIN := 4
const SIDE_MAX := 32
const LEVELS_MAX := 32
## The most changes kept to take back.
const MOST_UNDO := 60

## The sheet's picture, `side` high and `side * levels` wide.
var img: Image
var side := 16
var levels := 1
## Whether the model lies centred on its spot (a thing lying on the ground, held) or has
## its corner at the cell's (a thing placed on cells): a slice made wider or narrower
## keeps its middle, or its corner.
var centred := true
## Pictures of the sheet before each change, the last on top.
var history: Array[Image] = []


## The sheet of PNG picture `from` (null or a picture that is no row of square slices:
## an empty one `side_` across).
static func of(from: Image, centred_ := true, side_ := 16):
	var s = new()
	s.centred = centred_
	if from != null and from.get_height() >= 1 and from.get_width() % from.get_height() == 0 \
			and from.get_height() <= SIDE_MAX and from.get_width() / from.get_height() <= LEVELS_MAX:
		s.img = from.duplicate()
		s.img.convert(Image.FORMAT_RGBA8)
		s.side = from.get_height()
		s.levels = from.get_width() / from.get_height()
	else:
		s.side = clampi(side_, SIDE_MIN, SIDE_MAX)
		s.levels = 1
		s.img = Image.create(s.side, s.side, false, Image.FORMAT_RGBA8)
	return s


## The voxel at `x`, `z` of level `y`: its colour, alpha 0 for none.
func at(x: int, y: int, z: int) -> Color:
	if not inside(x, y, z):
		return Color(0, 0, 0, 0)
	return img.get_pixel(y * side + x, z)


func inside(x: int, y: int, z: int) -> bool:
	return x >= 0 and z >= 0 and y >= 0 and x < side and z < side and y < levels


## Whether the voxel at `x`, `y`, `z` is a leaf.
func leaf(x: int, y: int, z: int) -> bool:
	var c := at(x, y, z)
	return c.a > 0.0 and c.a8 <= VoxelModel.FOLIAGE_ALPHA


## The colour a voxel of `color` (a leaf when `is_leaf`) has in the picture.
static func ink(color: Color, is_leaf: bool) -> Color:
	var c := Color(color, 1.0)
	if is_leaf:
		c.a8 = VoxelModel.FOLIAGE_ALPHA
	return c


## `c` as the picture keeps it (8 bits a channel), so what is put compares with what is read.
static func exact(c: Color) -> Color:
	return Color8(c.r8, c.g8, c.b8, c.a8)


## Keeps the sheet as it is, to take back the change that follows.
func remember() -> void:
	history.append(img.duplicate())
	if history.size() > MOST_UNDO:
		history.pop_front()


## Sets the voxel at `x`, `y`, `z` (no change remembered: a stroke remembers once).
## Whether anything changed.
func put(x: int, y: int, z: int, color: Color) -> bool:
	color = exact(color)
	if not inside(x, y, z) or at(x, y, z) == color:
		return false
	img.set_pixel(y * side + x, z, color)
	return true


## Fills the voxels of level `y` joined to `x`, `z` (by their sides) that have its colour
## with `color`. Whether anything changed.
func fill(x: int, y: int, z: int, color: Color) -> bool:
	var was := at(x, y, z)
	color = exact(color)
	if not inside(x, y, z) or was == color:
		return false
	var todo: Array[Vector2i] = [Vector2i(x, z)]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if not inside(p.x, y, p.y) or at(p.x, y, p.y) != was:
			continue
		img.set_pixel(y * side + p.x, p.y, color)
		todo.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])
	return true


## Puts a level after level `after` (-1: under the first), empty or a copy of `after`.
## Whether there was room.
func add_level(after: int, copy: bool) -> bool:
	if levels >= LEVELS_MAX:
		return false
	remember()
	var out := Image.create(side * (levels + 1), side, false, Image.FORMAT_RGBA8)
	for y in levels:
		var to := y if y <= after else y + 1
		out.blit_rect(img, Rect2i(y * side, 0, side, side), Vector2i(to * side, 0))
	if copy and after >= 0:
		out.blit_rect(img, Rect2i(after * side, 0, side, side), Vector2i((after + 1) * side, 0))
	img = out
	levels += 1
	return true


## Takes level `y` out (the last one is only cleared). Whether anything changed.
func remove_level(y: int) -> bool:
	if y < 0 or y >= levels:
		return false
	remember()
	if levels == 1:
		img.fill(Color(0, 0, 0, 0))
		return true
	var out := Image.create(side * (levels - 1), side, false, Image.FORMAT_RGBA8)
	for i in levels:
		if i != y:
			out.blit_rect(img, Rect2i(i * side, 0, side, side), Vector2i((i if i < y else i - 1) * side, 0))
	img = out
	levels -= 1
	return true


## Makes the slices `to` across (even, SIDE_MIN..SIDE_MAX): each keeps its middle when
## the model is centred, else its corner; voxels outside are lost. Whether it changed.
func resize(to: int) -> bool:
	to = clampi(to, SIDE_MIN, SIDE_MAX)
	if to == side:
		return false
	remember()
	var shift := (to - side) / 2 if centred else 0
	var out := Image.create(to * levels, to, false, Image.FORMAT_RGBA8)
	for y in levels:
		for z in side:
			for x in side:
				var c := img.get_pixel(y * side + x, z)
				var nx := x + shift
				var nz := z + shift
				if c.a > 0.0 and nx >= 0 and nz >= 0 and nx < to and nz < to:
					out.set_pixel(y * to + nx, nz, c)
	img = out
	side = to
	return true


## Moves every voxel by `by` (x, levels, z): those pushed out are lost. Whether any moved.
func shift(by: Vector3i) -> bool:
	if by == Vector3i.ZERO:
		return false
	remember()
	var out := Image.create(side * levels, side, false, Image.FORMAT_RGBA8)
	for y in levels:
		for z in side:
			for x in side:
				var c := img.get_pixel(y * side + x, z)
				var to := Vector3i(x, y, z) + by
				if c.a > 0.0 and inside(to.x, to.y, to.z):
					out.set_pixel(to.y * side + to.x, to.z, c)
	img = out
	return true


## Takes the last change back. Whether there was one.
func undo() -> bool:
	if history.is_empty():
		return false
	img = history.pop_back()
	side = img.get_height()
	levels = img.get_width() / side
	return true


## The colours of the model's voxels, most used first (leaves as their colour).
func colours() -> Array[Color]:
	var count := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				var key := Color(c, 1.0)
				count[key] = count.get(key, 0) + 1
	var out: Array[Color] = []
	out.assign(count.keys())
	out.sort_custom(func(a: Color, b: Color) -> bool: return count[a] > count[b])
	return out


## How many voxels the model has.
func count() -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				n += 1
	return n


## The model the game would draw (VoxelModel.from_image).
func model():
	return VoxelModel.from_image(img, centred)


## The sheet as the PNG the game reads.
func png() -> PackedByteArray:
	return img.save_png_to_buffer()
