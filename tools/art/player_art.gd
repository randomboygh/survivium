extends RefCounted
## Placeholder art of the bare player, drawn pixel by pixel for every direction and
## frame of the sheet laid out in content/core/sprites/player.yaml; tools/make_sprites.gd
## saves it as the mod's pictures, which the game reads (Figure). Layers: the body
## (skin, eyes, hands), shirt, trousers, boots, hair, the fists (the hands that work,
## drawn over what they hold) and the hands picture marking where each hand is. The
## hands are empty: what they hold has sheets of its own (ToolArt). The figure is 8
## pixels wide and 14 tall before its outline, two cells tall on screen.
##
## The sheet is drawn for the right hand in use: in the work columns (player.yaml
## `works`) it winds up and strikes, and in a two-handed work the left hand holds the
## same thing further along. The west directions are the east ones mirrored with the
## hands swapped.

const SpriteSheet := preload("res://src/client/sprite_sheet.gd")
const Figure := preload("res://src/client/figure.gd")

## Directions drawn as another one flipped, with the hands swapped.
const MIRROR := {"sw": "se", "w": "e", "nw": "ne"}
## Where the figure's 10x16 box (outline included) sits in a frame: room on each side
## and above for a tool swung out or overhead, its bottom row on the frame's last row.
const ORIGIN := Vector2i(6, 8)

const COLORS := {
	"skin": Color(0.95, 0.78, 0.62),
	"eye": Color(0.1, 0.1, 0.15),
	"hair": Color(0.35, 0.22, 0.12),
	"shirt": Color(0.25, 0.45, 0.72),
	"trousers": Color(0.35, 0.3, 0.24),
	"boots": Color(0.25, 0.17, 0.1),
}

## The hand in use in the work columns, for a hand on the left of the picture facing
## us or turned away (the right one is its mirror): "grip" where the hand is in the
## figure's box, "sleeve" the pixels of the raised arm, "off" where the other hand
## holds a two-handed thing (its arm hidden by the body). "up" (the way a thing held
## points from the hand) and "out" (the way its edge faces) are for the placeholder
## tools (ToolArt). Wind-up first, then the strike.
const FRONT_WORK := {
	"chop": [
		{"grip": Vector2i(1, 5), "up": Vector2i(0, -1), "out": Vector2i(-1, 0), "sleeve": [Vector2i(1, 8), Vector2i(1, 7), Vector2i(1, 6)]},
		{"grip": Vector2i(3, 10), "up": Vector2i(0, 1), "out": Vector2i(-1, 0), "sleeve": [Vector2i(2, 9)]},
	],
	"dig": [
		{"grip": Vector2i(3, 8), "up": Vector2i(0, 1), "out": Vector2i(-1, 0), "sleeve": [Vector2i(2, 8)]},
		{"grip": Vector2i(3, 10), "up": Vector2i(0, 1), "out": Vector2i(-1, 0), "sleeve": [Vector2i(2, 9)]},
	],
	"slash": [
		{"grip": Vector2i(0, 6), "up": Vector2i(-1, -1), "out": Vector2i(-1, 1), "sleeve": [Vector2i(1, 8), Vector2i(1, 7)]},
		{"grip": Vector2i(3, 10), "up": Vector2i(1, 0), "out": Vector2i(0, 1), "sleeve": [Vector2i(2, 9)]},
	],
	"reach": [
		{"grip": Vector2i(1, 9), "up": Vector2i(0, -1), "out": Vector2i(-1, 0), "sleeve": []},
		{"grip": Vector2i(3, 10), "up": Vector2i(0, -1), "out": Vector2i(-1, 0), "sleeve": [Vector2i(2, 9)]},
	],
	"mow": [
		{"grip": Vector2i(0, 10), "up": Vector2i(0, -1), "out": Vector2i(-1, 0), "sleeve": [Vector2i(1, 9)], "off": Vector2i(0, 7)},
		{"grip": Vector2i(2, 11), "up": Vector2i(1, 0), "out": Vector2i(0, 1), "sleeve": [Vector2i(1, 10)], "off": Vector2i(5, 11)},
	],
	"aim": [
		{"grip": Vector2i(2, 10), "up": Vector2i(1, 0), "out": Vector2i(0, -1), "sleeve": [Vector2i(1, 9)], "off": Vector2i(6, 10)},
		{"grip": Vector2i(2, 8), "up": Vector2i(1, 0), "out": Vector2i(0, -1), "sleeve": [Vector2i(1, 8)], "off": Vector2i(6, 8)},
	],
}
## The same for the near hand in side view, facing east; the far hand does the same a
## pixel further back, behind the body.
const SIDE_WORK := {
	"chop": [
		{"grip": Vector2i(3, 6), "up": Vector2i(-1, -1), "out": Vector2i(1, -1), "sleeve": [Vector2i(5, 8), Vector2i(4, 7)]},
		{"grip": Vector2i(7, 9), "up": Vector2i(1, 0), "out": Vector2i(0, 1), "sleeve": [Vector2i(6, 8)]},
	],
	"dig": [
		{"grip": Vector2i(7, 7), "up": Vector2i(1, 1), "out": Vector2i(1, -1), "sleeve": [Vector2i(6, 8)]},
		{"grip": Vector2i(7, 9), "up": Vector2i(1, 1), "out": Vector2i(1, -1), "sleeve": [Vector2i(6, 9)]},
	],
	"slash": [
		{"grip": Vector2i(3, 6), "up": Vector2i(-1, -1), "out": Vector2i(1, -1), "sleeve": [Vector2i(5, 8), Vector2i(4, 7)]},
		{"grip": Vector2i(7, 9), "up": Vector2i(1, 0), "out": Vector2i(0, 1), "sleeve": [Vector2i(6, 8)]},
	],
	"reach": [
		{"grip": Vector2i(6, 9), "up": Vector2i(0, -1), "out": Vector2i(1, 0), "sleeve": []},
		{"grip": Vector2i(8, 9), "up": Vector2i(0, -1), "out": Vector2i(1, 0), "sleeve": [Vector2i(6, 9), Vector2i(7, 9)]},
	],
	"mow": [
		{"grip": Vector2i(3, 10), "up": Vector2i(-1, -1), "out": Vector2i(-1, 1), "sleeve": [Vector2i(4, 9)], "off": Vector2i(1, 8)},
		{"grip": Vector2i(6, 11), "up": Vector2i(1, 0), "out": Vector2i(0, 1), "sleeve": [Vector2i(5, 10)], "off": Vector2i(8, 11)},
	],
	"aim": [
		{"grip": Vector2i(6, 10), "up": Vector2i(1, 0), "out": Vector2i(0, -1), "sleeve": [Vector2i(5, 9)], "off": Vector2i(8, 10)},
		{"grip": Vector2i(5, 8), "up": Vector2i(1, 0), "out": Vector2i(0, -1), "sleeve": [], "off": Vector2i(8, 8)},
	],
}

## Layer images already drawn, by name, and the hands' places (see anchors).
static var _drawn := {}
static var _anchors := []

var img: Image
## Top-left of the figure's box in the image for the frame being drawn.
var at: Vector2i
## The frame being drawn, clear pixels on its edge kept clear for the outline.
var frame: Rect2i
## Which hand of the direction being drawn is in use: the right one, or the left one
## in a mirrored direction (which shows it as the right one).
var drawn_active := "right"


## The image of layer `name` (player.yaml `layers` or `fists`), drawn the first time.
static func layer(name: String) -> Image:
	if not _drawn.has(name):
		var s := SpriteSheet.new(Figure.data())
		var art = load("res://tools/art/player_art.gd").new()
		art.start(s)
		for row in s.directions.size():
			art.draw_row(name, s, row)
		_drawn[name] = art.img
	return _drawn[name]


## Where the hands are, by row and column of the sheet: {"right": hand, "left": hand},
## a hand being {"at": its pixel in the frame, "front": over the body or not}, or {}
## for the other hand of a two-handed work, which holds the same thing.
static func anchors() -> Array:
	if _anchors.is_empty():
		var s := SpriteSheet.new(Figure.data())
		var art = load("res://tools/art/player_art.gd").new()
		for row in s.directions.size():
			var dir: String = s.directions[row]
			var drawn: String = MIRROR.get(dir, dir)
			var flipped := MIRROR.has(dir)
			art.drawn_active = "left" if flipped else "right"
			var cols := []
			for col in s.columns:
				var pose: Dictionary = art.pose_at(col)
				var both := {}
				for hand in ["right", "left"]:
					var h: Dictionary = art.hand(drawn, _other(hand) if flipped else hand, col)
					if not h.holds:
						both[hand] = {}
						continue
					var p: Vector2i = ORIGIN + h.grip - Vector2i(0, pose.bob)
					if flipped:
						p.x = s.frame_size.x - 1 - p.x
					both[hand] = {"at": p, "front": h.front}
				cols.append(both)
			_anchors.append(cols)
	return _anchors


## The hands picture: in each frame a pixel at each hand, red for the right one, blue
## for the left one, darker behind the body (see player.yaml).
static func marks() -> Image:
	var s := SpriteSheet.new(Figure.data())
	var img := Image.create_empty(s.image_size().x, s.image_size().y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var all := anchors()
	for row in all.size():
		for col in all[row].size():
			for hand in ["right", "left"]:
				var a: Dictionary = all[row][col][hand]
				if not a.is_empty():
					var c: Color = Figure.MARKS[hand] * (1.0 if a.front else 0.5)
					c.a = 1.0
					img.set_pixelv(Vector2i(col, row) * s.frame_size + a.at, c)
	return img


## A clear image for a whole grid of one layer.
func start(s: SpriteSheet) -> void:
	img = Image.create_empty(s.frame_size.x * s.columns, s.frame_size.y * s.directions.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))


## One direction of a layer, every column.
func draw_row(layer_name: String, s: SpriteSheet, row: int) -> void:
	var dir: String = s.directions[row]
	var drawn: String = MIRROR.get(dir, dir)
	var flipped := MIRROR.has(dir)
	drawn_active = "left" if flipped else "right"
	for col in s.columns:
		var pose := pose_at(col)
		frame = Rect2i(Vector2i(col * s.frame_size.x, row * s.frame_size.y), s.frame_size)
		at = frame.position + ORIGIN
		# A step lifts the whole body by a pixel.
		at.y -= pose.bob
		_draw(layer_name, drawn, pose, col)
		if flipped:
			var part := img.get_region(frame)
			part.flip_x()
			img.blit_rect(part, Rect2i(Vector2i.ZERO, frame.size), frame.position)


static func _other(hand: String) -> String:
	return "left" if hand == "right" else "right"


## How a drawn direction shows the body: facing us, from the side or from behind.
static func _view(dir: String) -> String:
	match dir:
		"e":
			return "side"
		"n", "ne":
			return "back"
	return "front"


## Where hand `hand` shows in drawn direction `dir`: on the left of the picture ("a")
## or the right ("b") facing us or from behind, near or far from the side.
static func _slot(dir: String, hand: String) -> String:
	match _view(dir):
		"side":
			return "near" if hand == "right" else "far"
		"front":
			return "a" if hand == "right" else "b"
	return "b" if hand == "right" else "a"


## What the legs and arms do in a column of the sheet. left/right: that leg is
## lifted, swing: the hand in front (1) or behind (-1), apart: the legs are apart
## in side view, leading with the front leg (1) or the back one (-1).
func pose_at(col: int) -> Dictionary:
	match col:
		1:
			return {"left": true, "right": false, "swing": 1, "apart": 1, "bob": 1}
		3:
			return {"left": false, "right": true, "swing": -1, "apart": -1, "bob": 1}
	return {"left": false, "right": false, "swing": 0, "apart": 0, "bob": 0}


## Where hand `hand` of drawn direction `dir` is in column `col` (see FRONT_WORK), with
## "slot" (see _slot), "worked": whether it works in this column (the body draws it
## raised instead of hanging), "holds": false for the other hand of a two-handed work,
## and "front": whether it is in front of the body.
func hand(dir: String, which: String, col: int) -> Dictionary:
	var pose := pose_at(col)
	var view := _view(dir)
	var slot := _slot(dir, which)
	# The pose is given for the hand in use, mirrored or moved back with it.
	var frame_slot := slot
	var work := Figure.work_at(col)
	var h := {}
	if work[0] != "":
		var entry: Dictionary = (SIDE_WORK if view == "side" else FRONT_WORK)[work[0]][work[1]]
		if which == drawn_active:
			h = {"grip": entry.grip, "up": entry.up, "out": entry.out, "sleeve": entry.sleeve, "worked": true, "holds": true}
		elif entry.has("off"):
			h = {"grip": entry.off, "up": entry.up, "out": entry.out, "sleeve": [], "worked": true, "holds": false}
			frame_slot = _slot(dir, drawn_active)
	if h.is_empty():
		if slot == "near":
			# The near hand swings with the step; a tool stands up in front of it.
			var x: int = 5 + pose.swing
			h = {"grip": Vector2i(x + 1, 9 if pose.swing != 0 else 10), "up": Vector2i(0, -1), "out": Vector2i(1, 0)}
		elif slot == "far":
			h = {"grip": Vector2i(4, 10), "up": Vector2i(0, -1), "out": Vector2i(1, 0)}
		else:
			# A hanging hand holds a tool upright beside it, edge outwards.
			var lifted: bool = pose.swing < 0 if slot == "a" else pose.swing > 0
			h = {"grip": Vector2i(0, 8 if lifted else 10), "up": Vector2i(0, -1), "out": Vector2i(-1, 0)}
		h.merge({"sleeve": [], "worked": false, "holds": true})
	if frame_slot == "b":
		h.grip = Vector2i(9 - h.grip.x, h.grip.y)
		h.up = Vector2i(-h.up.x, h.up.y)
		h.out = Vector2i(-h.out.x, h.out.y)
		h.sleeve = h.sleeve.map(func(p: Vector2i) -> Vector2i: return Vector2i(9 - p.x, p.y))
	elif frame_slot == "far" and h.worked:
		h.grip -= Vector2i(1, 0)
		h.sleeve = h.sleeve.map(func(p: Vector2i) -> Vector2i: return p - Vector2i(1, 0))
	h.slot = slot
	h.front = view == "front" or slot == "near"
	return h


## A pixel of the frame being drawn, at (x, y) of the figure's box; the frame's edge
## stays clear for the outline.
func _px(x: int, y: int, c: Color) -> void:
	var p := at + Vector2i(x, y)
	if p.x > frame.position.x and p.y > frame.position.y and p.x < frame.end.x - 1 and p.y < frame.end.y - 1:
		img.set_pixelv(p, c)


func _row(x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(x, y, c)


## A raised arm: its sleeve and the hand at the grip.
func _arm(h: Dictionary, sleeve: Color) -> void:
	for p: Vector2i in h.sleeve:
		_px(p.x, p.y, sleeve)
	_px(h.grip.x, h.grip.y, COLORS.skin)


func _draw(layer_name: String, dir: String, pose: Dictionary, col: int) -> void:
	var side := dir == "e"
	var hands := []
	if layer_name in ["body", "shirt", "fists"]:
		hands = [hand(dir, "left", col), hand(dir, "right", col)]
	match layer_name:
		"fists":
			# The working hands in front of the body, over what they hold.
			for h: Dictionary in hands:
				if h.worked and h.front:
					_px(h.grip.x, h.grip.y, COLORS.skin)
		"body":
			_face(dir)
			var skin: Color = COLORS.skin
			for h: Dictionary in hands:
				if h.worked:
					# A raised hand behind the body shows where the body leaves it.
					if not h.front:
						_arm(h, COLORS.shirt)
					continue
				match h.slot:
					"near":
						# The near arm hangs in front of the body and swings with the step.
						var x: int = 5 + pose.swing
						_px(x, 9 if pose.swing != 0 else 10, skin)
						_px(x, 10, skin)
					"a", "b":
						var x := 1 if h.slot == "a" else 8
						_px(x, 8 if h.grip.y == 8 else 10, skin)
						_px(x, 9, skin)
		"shirt":
			var c: Color = COLORS.shirt
			if side:
				_row(4, 6, 7, c)
				_row(3, 6, 8, c)
				_row(3, 6, 9, c)
				_row(3, 6, 10, c)
				var near: Dictionary = hands[0] if hands[0].slot == "near" else hands[1]
				if not near.worked:
					# Leave the near hand showing.
					var x: int = 5 + pose.swing
					_px(x, 10, Color(0, 0, 0, 0))
					if pose.swing != 0:
						_px(x, 9, Color(0, 0, 0, 0))
			else:
				_row(3, 6, 7, c)
				for y in range(8, 11):
					_row(2, 7, y, c)
			for h: Dictionary in hands:
				if h.worked and h.front:
					_arm(h, c)
		"hair":
			var c: Color = COLORS.hair
			if side:
				_row(4, 6, 1, c)
				_row(3, 7, 2, c)
				_row(3, 5, 3, c)
				_px(3, 4, c)
				_px(4, 5, c)
			else:
				_row(3, 6, 1, c)
				_row(2, 7, 2, c)
				match dir:
					"s":
						_px(2, 3, c)
						_px(7, 3, c)
					"se":
						_row(2, 3, 3, c)
						_px(2, 4, c)
					"n", "ne":
						_row(2, 7, 3, c)
						_row(2, 6 if dir == "ne" else 7, 4, c)
						_row(3, 6, 5, c)
		"trousers":
			var c: Color = COLORS.trousers
			if side:
				_row(3, 6, 11, c)
				if pose.apart != 0:
					_px(3, 12, c)
					_px(3, 13, c)
					_px(6, 12, c)
					_px(6, 13, c)
				else:
					_row(4, 5, 12, c)
					_row(4, 5, 13, c)
			else:
				_row(2, 7, 11, c)
				_row(2, 3, 12, c)
				_row(6, 7, 12, c)
				if not pose.left:
					_row(2, 3, 13, c)
				if not pose.right:
					_row(6, 7, 13, c)
		"boots":
			var c: Color = COLORS.boots
			if side:
				if pose.apart != 0:
					_row(2, 3, 14, c)
					_row(6, 7, 14, c)
				else:
					_row(4, 6, 14, c)
			else:
				_row(2, 3, 13 if pose.left else 14, c)
				_row(6, 7, 13 if pose.right else 14, c)


## Skin and eyes of the head, which the hair layer covers from behind.
func _face(dir: String) -> void:
	var skin: Color = COLORS.skin
	var eye: Color = COLORS.eye
	match dir:
		"s":
			_row(3, 6, 3, skin)
			_row(2, 7, 4, skin)
			_row(3, 6, 5, skin)
			_px(3, 4, eye)
			_px(6, 4, eye)
		"se":
			_row(4, 7, 3, skin)
			_row(3, 7, 4, skin)
			_row(4, 7, 5, skin)
			_px(4, 4, eye)
			_px(6, 4, eye)
		"e":
			_row(6, 7, 3, skin)
			_row(4, 7, 4, skin)
			_row(5, 7, 5, skin)
			_px(6, 4, eye)
		"ne":
			_px(7, 4, skin)
