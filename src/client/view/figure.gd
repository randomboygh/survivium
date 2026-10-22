extends RefCounted
## Puts together the sheet the player is drawn with from the pictures of the core mod
## (content/core/sprites/player.yaml says how they are laid out): the bare figure, in
## layers, with the hands moving through every animation and a picture marking where
## each hand is in each frame and the way what it holds points, and the sheet of each
## tool held, whose frames are put at the hand, under the body where that hand is
## behind it. A thing without a sheet (a block, food, seeds) is its icon made small
## and turned the way the hand holds it. The figure is drawn for the right hand in use;
## with the left one in use each direction is the opposite one with the hands swapped,
## mirrored, so neither the figure nor a thing is drawn twice. The sheet is built a
## part of a row at a time (step), so taking another thing in hand never takes a frame
## of its own.
##
## `look` lists the worn layers. `held` is {"left": thing, "right": thing, "active":
## "left" or "right"}, a thing being {} for an empty hand, {"sprite": the path of its
## sheet, "anim": the work it is used with} or {"icon": the name it is kept by,
## "picture": its Image (null: a lump), "anim"}.

const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Yaml := preload("res://src/shared/content/yaml.gd")

const SPRITES := "res://content/core/sprites"
## What a hand shows of a thing with neither a sheet nor an icon.
const LUMP := "res://content/core/sprites/held/lump.png"
## Colours marking the hands in the hands picture (see player.yaml), the darker ones
## behind the body.
const MARKS := {"right": Color(1, 0, 0), "left": Color(0, 0, 1)}
## Frames put together in one step.
const PART := 10

static var _data := {}
static var _layers := {}
static var _anchors := []
static var _held := {}
static var _icons := {}

var target: SpriteSheet
var look: Array
var held: Dictionary
var _img: Image
## The next part to put together, PART frames of a row; -1 before the sheets of the
## things are loaded.
var _part := -1
## By hand as the figure is drawn (the right one in use): what it holds, and its sheet
## or its icon turned each way (icon_turns).
var _things := {}
var _sheets := {}
var _turns := {}


func _init(worn: Array, hands: Dictionary) -> void:
	look = worn
	held = hands
	target = SpriteSheet.new(data())


## The sheet built at once.
static func sheet(worn: Array, hands := {}) -> SpriteSheet:
	var f = load("res://src/client/view/figure.gd").new(worn, hands)
	while not f.step():
		pass
	return f.target


## The layout of the sheets (player.yaml).
static func data() -> Dictionary:
	if _data.is_empty():
		_data = Yaml.new().parse(FileAccess.get_file_as_string(SPRITES + "/player.yaml"), "player.yaml")
	return _data


## Loads the figure's pictures ahead, so a sheet later only puts them together.
static func prepare(worn: Array) -> void:
	for name in worn:
		layer(name)
	layer(data().fists)
	anchors()


## The picture of layer `name` of the figure.
static func layer(name: String) -> Image:
	if not _layers.has(name):
		_layers[name] = _picture("%s/player/%s.png" % [SPRITES, name])
	return _layers[name]


## Where the hands are, by row and column of the sheet: {"right": hand, "left": hand},
## a hand being {"at": its pixel in the frame, "front": over the body or not, "angle":
## the way what it holds points, 0 up and clockwise by eighths, -1 as carried}, or {}
## where it holds the same thing as the other one (or is not marked).
static func anchors() -> Array:
	if _anchors.is_empty():
		var s := SpriteSheet.new(data())
		var marks := layer(data().hands)
		for row in s.directions.size():
			var cols := []
			for col in s.columns:
				var frame := marks.get_region(Rect2i(Vector2i(col, row) * s.frame_size, s.frame_size))
				var both := {"right": {}, "left": {}}
				var used := frame.get_used_rect()
				for y in range(used.position.y, used.end.y):
					for x in range(used.position.x, used.end.x):
						var c := frame.get_pixel(x, y)
						if c.a < 0.5:
							continue
						var hand := "right" if c.r > c.b else "left"
						var angle := roundi(c.g * 8.0) - 1 if c.g > 0.06 else -1
						both[hand] = {"at": Vector2i(x, y), "front": maxf(c.r, c.b) > 0.75, "angle": angle}
				cols.append(both)
			_anchors.append(cols)
	return _anchors


## The sheet of a tool held: its picture at `path`.
static func held_sheet(path: String) -> Image:
	if not _held.has(path):
		_held[path] = _picture(path if ResourceLoader.exists(path) else LUMP)
	return _held[path]


## Icon `picture` of a thing kept as `key`, made small for a hand (player.yaml `held`
## `icon`: the size it is cut down to) and turned each of the eight ways (0 up, as
## carried, then clockwise by eighths).
static func icon_turns(key: String, picture: Image) -> Array:
	if not _icons.has(key):
		var small: Image = _small(picture) if picture != null else _picture(LUMP)
		var turns := []
		for a in 8:
			turns.append(_turned(small, a))
		_icons[key] = turns
	return _icons[key]


## A picture cut down to at most player.yaml `held` `icon` pixels a side: each block
## of pixels becomes one, of their mean colour, where at least half of them are drawn.
static func _small(picture: Image) -> Image:
	var src := picture.duplicate() as Image
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	if not used.has_area():
		return _picture(LUMP)
	src = src.get_region(used)
	var most: int = data().held.icon
	var step := maxi(1, ceili(maxf(src.get_width(), src.get_height()) / float(most)))
	var size := Vector2i(ceili(src.get_width() / float(step)), ceili(src.get_height() / float(step)))
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in size.y:
		for x in size.x:
			var sum := Color(0, 0, 0, 0)
			var drawn := 0
			var all := 0
			for dy in step:
				for dx in step:
					var p := Vector2i(x * step + dx, y * step + dy)
					if p.x >= src.get_width() or p.y >= src.get_height():
						continue
					all += 1
					var c := src.get_pixelv(p)
					if c.a >= 0.5:
						sum += c
						drawn += 1
			if drawn > 0 and drawn * 2 >= all:
				var c := sum / drawn
				c.a = 1.0
				out.set_pixel(x, y, c)
	return out


## A picture turned by `a` eighths clockwise around its middle, pixel by pixel.
static func _turned(img: Image, a: int) -> Image:
	if a == 0:
		return img
	var w := img.get_width()
	var h := img.get_height()
	var side := ceili(Vector2(w, h).length()) | 1
	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var turn := -a * PI / 4.0
	var mid := Vector2(side - 1, side - 1) / 2.0
	var from := Vector2(w - 1, h - 1) / 2.0
	for y in side:
		for x in side:
			var p := (Vector2(x, y) - mid).rotated(turn) + from
			var q := Vector2i(roundi(p.x), roundi(p.y))
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				out.set_pixel(x, y, img.get_pixelv(q))
	return out


## The work playing in column `col` of the sheet and its frame there, or ["", 0].
static func work_at(col: int) -> Array:
	var works: Dictionary = data().works
	for kind in works:
		var c: Array = works[kind].columns
		if c.has(col):
			return [kind, c.find(col)]
	return ["", 0]


## The direction mirrored east to west.
static func opposite(dir: String) -> String:
	return dir.replace("e", "_").replace("w", "e").replace("_", "w")


static func _picture(path: String) -> Image:
	var img: Image = load(path).get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## Does a little of the building: first the sheets of the things held, then a part of
## a row of the sheet. True when the sheet is done.
func step() -> bool:
	if _part < 0:
		var swap: bool = held.get("active", "right") == "left"
		for hand in ["left", "right"]:
			var thing: Dictionary = held.get(_other(hand) if swap else hand, {})
			_things[hand] = thing
			if thing.has("sprite"):
				_sheets[hand] = held_sheet(thing.sprite)
			elif thing.has("icon"):
				_turns[hand] = icon_turns(thing.icon, thing.get("picture"))
		_img = Image.create_empty(target.image_size().x, target.image_size().y, false, Image.FORMAT_RGBA8)
		_part = 0
		return false
	var parts := ceili(target.columns / float(PART))
	var c0 := (_part % parts) * PART
	_put_row(_part / parts, c0, mini(c0 + PART, target.columns))
	_part += 1
	if _part < parts * target.directions.size():
		return false
	target.show(_img)
	_img = null
	return true


static func _other(hand: String) -> String:
	return "left" if hand == "right" else "right"


## Columns c0..c1 (not included) of row `row` of the sheet: the figure's row of the
## same direction, or of the opposite one mirrored when the left hand is in use, with
## the things at the hands.
func _put_row(row: int, c0: int, c1: int) -> void:
	var swap: bool = held.get("active", "right") == "left"
	var dir: String = target.directions[row]
	var src := target.directions.find(opposite(dir) if swap else dir)
	var size := target.frame_size
	var strip := Image.create_empty(size.x * (c1 - c0), size.y, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	var from := Rect2i(c0 * size.x, src * size.y, strip.get_width(), size.y)
	_put_things(strip, src, false, c0, c1)
	for name in data().layers:
		if look.has(name):
			strip.blend_rect(layer(name), from, Vector2i.ZERO)
	_put_things(strip, src, true, c0, c1)
	strip.blend_rect(layer(data().fists), from, Vector2i.ZERO)
	var whole := Rect2i(Vector2i.ZERO, strip.get_size())
	if target.outline:
		SpriteSheet.outline_rect(strip, whole)
	if swap:
		for col in c1 - c0:
			var r := Rect2i(Vector2i(col * size.x, 0), size)
			var part := strip.get_region(r)
			part.flip_x()
			strip.blit_rect(part, Rect2i(Vector2i.ZERO, size), r.position)
	_img.blit_rect(strip, whole, Vector2i(c0 * size.x, row * size.y))


## The things held in columns c0..c1 of row `src` of the figure, those in front of the
## body or behind it.
## The right hand shows its thing's own frames (its work while that plays, else the
## carried one); the left one the carried frame of the opposite direction, mirrored. An
## icon turns the way the hand holds it while its work plays.
func _put_things(strip: Image, src: int, front: bool, c0: int, c1: int) -> void:
	var size := target.frame_size
	var dir: String = target.directions[src]
	var marks: Array = anchors()[src]
	var cell := Vector2i(data().held.cell[0], data().held.cell[1])
	var grip := Vector2i(data().held.grip[0], data().held.grip[1])
	for col in range(c0, c1):
		var frame := Rect2i(Vector2i((col - c0) * size.x, 0), size).grow(-1)
		for hand in ["left", "right"]:
			var thing: Dictionary = _things[hand]
			var a: Dictionary = marks[col][hand]
			if thing.is_empty() or a.is_empty() or a.front != front:
				continue
			var right: bool = hand == "right"
			var work := work_at(col)
			var working: bool = right and work[0] != "" and work[0] == thing.get("anim", "")
			var pic: Image
			var hold: Vector2i
			if _turns.has(hand):
				pic = _turns[hand][maxi(0, a.angle) if working else 0]
				hold = pic.get_size() / 2
				if not right:
					pic = pic.duplicate()
					pic.flip_x()
			else:
				var sheet_img: Image = _sheets[hand]
				var tcol: int = 1 + work[1] if working else 0
				if (tcol + 1) * cell.x > sheet_img.get_width():
					tcol = 0
				var trow: int = src if right else target.directions.find(opposite(dir))
				pic = sheet_img.get_region(Rect2i(Vector2i(tcol, trow) * cell, cell))
				hold = grip
				if not right:
					pic.flip_x()
					hold.x = cell.x - 1 - grip.x
			var at: Vector2i = frame.position - Vector2i.ONE + a.at - hold
			# Kept within the frame, its edge clear for the outline.
			var dst := Rect2i(at, pic.get_size()).intersection(frame)
			if dst.has_area():
				strip.blend_rect(pic, Rect2i(dst.position - at, dst.size), dst.position)
