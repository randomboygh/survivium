extends RefCounted
## Puts together the sheet the player is drawn with from the pictures of the core mod
## (content/core/sprites/player.yaml says how they are laid out): the bare figure, in
## layers, with the hands moving through every animation and a picture marking where
## each hand is in each frame, and the sheet of each thing held, whose frames are put
## at the hand, under the body where that hand is behind it. The figure is drawn for
## the right hand in use; with the left one in use each direction is the opposite one
## with the hands swapped, mirrored, so neither the figure nor a thing is drawn twice.
## The sheet is built a row at a time (step), so taking another thing in hand never
## takes a frame of its own.
##
## `look` lists the worn layers. `held` is {"left": thing, "right": thing, "active":
## "left" or "right"}, a thing being {} for an empty hand or {"sprite": the path of its
## sheet, "colour": Color it is tinted with, "anim": the work it is used with}.

const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const Yaml := preload("res://src/shared/yaml.gd")

const SPRITES := "res://content/core/sprites"
## A thing without a sheet of its own: a lump, tinted with its colour.
const LUMP := "res://content/core/sprites/held/lump.png"
## Colours marking the hands in the hands picture (see player.yaml), the darker ones
## behind the body.
const MARKS := {"right": Color(1, 0, 0), "left": Color(0, 0, 1)}

static var _data := {}
static var _layers := {}
static var _anchors := []
static var _held := {}

var target: SpriteSheet
var look: Array
var held: Dictionary
var _img: Image
## The next row to put together; -1 before the sheets of the things are loaded.
var _row := -1
## By hand as the figure is drawn (the right one in use): what it holds and its sheet.
var _things := {}
var _sheets := {}


func _init(worn: Array, hands: Dictionary) -> void:
	look = worn
	held = hands
	target = SpriteSheet.new(data())


## The sheet built at once.
static func sheet(worn: Array, hands := {}) -> SpriteSheet:
	var f = load("res://src/client/figure.gd").new(worn, hands)
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
## a hand being {"at": its pixel in the frame, "front": over the body or not}, or {}
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
						both[hand] = {"at": Vector2i(x, y), "front": maxf(c.r, c.b) > 0.75}
				cols.append(both)
			_anchors.append(cols)
	return _anchors


## The sheet of a thing held: its picture at `path`, tinted with `colour`.
static func held_sheet(path: String, colour: Color) -> Image:
	var key := "%s|%s" % [path, colour.to_html()]
	if not _held.has(key):
		var img := _picture(path if ResourceLoader.exists(path) else LUMP)
		if colour != Color.WHITE:
			img = img.duplicate()
			for y in img.get_height():
				for x in img.get_width():
					img.set_pixel(x, y, img.get_pixel(x, y) * colour)
		_held[key] = img
	return _held[key]


## The work playing in column `col` of the sheet and its phase (0 wind-up, 1 strike),
## or ["", 0].
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


## Does a little of the building: first the sheets of the things held, then a row of
## the sheet. True when the sheet is done.
func step() -> bool:
	if _row < 0:
		var swap: bool = held.get("active", "right") == "left"
		for hand in ["left", "right"]:
			var thing: Dictionary = held.get(_other(hand) if swap else hand, {})
			_things[hand] = thing
			if not thing.is_empty():
				_sheets[hand] = held_sheet(thing.sprite, thing.get("colour", Color.WHITE))
		_img = Image.create_empty(target.image_size().x, target.image_size().y, false, Image.FORMAT_RGBA8)
		_row = 0
		return false
	_put_row(_row)
	_row += 1
	if _row < target.directions.size():
		return false
	target.show(_img)
	_img = null
	return true


static func _other(hand: String) -> String:
	return "left" if hand == "right" else "right"


## Row `row` of the sheet: the figure's row of the same direction, or of the opposite
## one mirrored when the left hand is in use, with the things at the hands.
func _put_row(row: int) -> void:
	var swap: bool = held.get("active", "right") == "left"
	var dir: String = target.directions[row]
	var src := target.directions.find(opposite(dir) if swap else dir)
	var size := target.frame_size
	var strip := Image.create_empty(size.x * target.columns, size.y, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	var from := Rect2i(0, src * size.y, strip.get_width(), size.y)
	_put_things(strip, src, false)
	for name in data().layers:
		if look.has(name):
			strip.blend_rect(layer(name), from, Vector2i.ZERO)
	_put_things(strip, src, true)
	strip.blend_rect(layer(data().fists), from, Vector2i.ZERO)
	var whole := Rect2i(Vector2i.ZERO, strip.get_size())
	if target.outline:
		SpriteSheet.outline_rect(strip, whole)
	if swap:
		for col in target.columns:
			var r := Rect2i(Vector2i(col * size.x, 0), size)
			var part := strip.get_region(r)
			part.flip_x()
			strip.blit_rect(part, Rect2i(Vector2i.ZERO, size), r.position)
	_img.blit_rect(strip, whole, Vector2i(0, row * size.y))


## The things held in row `src` of the figure, those in front of the body or behind it.
## The right hand shows its thing's own frames (its work while that plays, else the
## carried one); the left one the carried frame of the opposite direction, mirrored.
func _put_things(strip: Image, src: int, front: bool) -> void:
	var size := target.frame_size
	var dir: String = target.directions[src]
	var marks: Array = anchors()[src]
	var cell := Vector2i(data().held.cell[0], data().held.cell[1])
	var grip := Vector2i(data().held.grip[0], data().held.grip[1])
	for col in target.columns:
		var frame := Rect2i(Vector2i(col * size.x, 0), size).grow(-1)
		for hand in ["left", "right"]:
			var thing: Dictionary = _things[hand]
			var a: Dictionary = marks[col][hand]
			if thing.is_empty() or a.is_empty() or a.front != front:
				continue
			var right: bool = hand == "right"
			var sheet_img: Image = _sheets[hand]
			var tcol := 0
			var work := work_at(col)
			if right and work[0] != "" and work[0] == thing.get("anim", ""):
				tcol = 1 + work[1]
			if (tcol + 1) * cell.x > sheet_img.get_width():
				tcol = 0
			var trow: int = src if right else target.directions.find(opposite(dir))
			var pic := sheet_img.get_region(Rect2i(Vector2i(tcol, trow) * cell, cell))
			var hold := grip
			if not right:
				pic.flip_x()
				hold.x = cell.x - 1 - grip.x
			var at: Vector2i = frame.position - Vector2i.ONE + a.at - hold
			# Kept within the frame, its edge clear for the outline.
			var dst := Rect2i(at, cell).intersection(frame)
			if dst.has_area():
				strip.blend_rect(pic, Rect2i(dst.position - at, dst.size), dst.position)
