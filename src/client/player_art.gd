extends RefCounted
## Placeholder art of the player, drawn pixel by pixel for every direction and
## frame of the sheet below, in layers that later come from a mod's PNG files: the
## body (skin, eyes, hands), hair, shirt, trousers, boots and what each hand holds (a
## tool, a block, a thing). The figure is 8 pixels wide and 14 tall before its
## outline, two cells tall on screen. The west directions are the east ones mirrored
## with the hands swapped, so a tool stays in the hand that holds it. In the work
## columns the hand in use winds up and strikes the way its tool works (WORK); bare
## hands and anything else held reach out. Layers are drawn once for each look and
## kept, so taking another thing in hand only composites the sheet again.

const SpriteSheet := preload("res://src/client/sprite_sheet.gd")

## Sheet layout: eight directions; column 0 stands, columns 1-4 walk (step left, feet
## together, step right, together), then each work takes two columns, a wind-up and
## a strike. A work plays once over the time of a swing (see Player.work), so its fps
## only sets how its frames share that time.
const SHEET := {
	"frame": [22, 24],
	"directions": ["s", "se", "e", "ne", "n", "sw", "w", "nw"],
	"animations": {
		"idle": {"frames": [0], "fps": 1.0},
		"walk": {"frames": [1, 2, 3, 4], "fps": 10.0},
		"jump": {"frames": [1], "fps": 1.0},
		"chop": {"frames": [5, 6, 6], "fps": 1.0},
		"dig": {"frames": [7, 8, 8], "fps": 1.0},
		"slash": {"frames": [9, 10, 10], "fps": 1.0},
		"reach": {"frames": [11, 12, 12], "fps": 1.0},
	},
	"outline": true,
}
## The wind-up column of each work; the strike is the next one.
const WORK_COLUMNS := {"chop": 5, "dig": 7, "slash": 9, "reach": 11}
## The work of each kind of tool (an item's `tool`); anything else reaches.
const WORK := {"axe": "chop", "pickaxe": "chop", "shovel": "dig", "sword": "slash", "scythe": "slash"}
## Directions drawn as another one flipped, with the hands swapped.
const MIRROR := {"sw": "se", "w": "e", "nw": "ne"}
## Layers of the body in drawing order; what the hands hold goes over them, or under
## them where that hand is behind the body.
const LAYERS := ["body", "shirt", "trousers", "boots", "hair"]
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
	"wood": Color(0.5, 0.33, 0.16),
	"dark": Color(0.3, 0.2, 0.12),
}

## Tools in hand, from the hand along the way the tool points: the haft from `haft[0]`
## to `haft[1]` pixels, then the head as [along, aside, part] (aside: towards the way
## its edge faces; part "h" in the tool's colour, "d" dark); "down": carried head
## down while the hand is not working. Things that are no tool are a small lump of
## their colour.
const SHAPES := {
	"axe": {"haft": [-1, 4], "head": [[3, 1, "h"], [4, 1, "h"], [3, 2, "h"], [4, 2, "h"]]},
	"pickaxe": {"haft": [-1, 4], "head": [[4, -2, "h"], [4, -1, "h"], [4, 0, "h"], [4, 1, "h"], [4, 2, "h"], [3, -2, "h"], [3, 2, "h"]]},
	"shovel": {"haft": [-1, 2], "head": [[3, -1, "h"], [3, 0, "h"], [3, 1, "h"], [4, -1, "h"], [4, 0, "h"], [4, 1, "h"]], "down": true},
	"sword": {"haft": [-1, 0], "head": [[1, -1, "d"], [1, 0, "d"], [1, 1, "d"], [2, 0, "h"], [3, 0, "h"], [4, 0, "h"]]},
	"scythe": {"haft": [-1, 5], "head": [[5, 1, "h"], [5, 2, "h"], [4, 3, "h"], [3, 3, "h"]]},
}

## The hand in use in the work columns, for a hand on the left of the picture facing
## us or turned away (the right one is its mirror): "grip" where the hand is in the
## figure's box, "up" the way a tool points from it, "out" the way its edge faces,
## "sleeve" the pixels of the raised arm. Wind-up first, then the strike.
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
}

## Layer images already drawn, by what they show (see _key).
static var _drawn := {}

var img: Image
## Top-left of the figure's box in the image for the frame being drawn.
var at: Vector2i
## The frame being drawn, clear pixels on its edge kept clear for the outline.
var frame: Rect2i
## The hand in use ("left", "right") and, while a direction is drawn, as which hand of
## the drawn direction it shows (swapped in a mirrored one).
var active := "right"
var _drawn_active := "right"
## While building a sheet (see build): the sheet, its layers, the layers still to draw
## ({"layer", "art" drawing it, "thing", "row" next}) and the next row to composite.
var target: SpriteSheet
var _layers := []
var _todo := []
var _composited := 0


## The sheet with the given body layers (names from LAYERS) and what the hands hold:
## `held` is {"left": look, "right": look, "active": "left" or "right"}, a look being
## {"model": a key of SHAPES, "block" or "thing", "colour": Color} or {} for an empty
## hand. Built at once; build() spreads the work over frames.
static func sheet(look: Array, held := {}) -> SpriteSheet:
	var b = build(look, held)
	while not b.step():
		pass
	return b.target


## A sheet to be built a step at a time (see step), so a change of what the hands hold
## never takes a frame of its own.
static func build(look: Array, held := {}):
	var b = load("res://src/client/player_art.gd").new()
	b.target = SpriteSheet.new(SHEET)
	var hand: String = held.get("active", "right")
	for name in LAYERS:
		if look.has(name):
			b._want(name, hand, {}, [])
	for side in ["left", "right"]:
		var thing: Dictionary = held.get(side, {})
		if thing.is_empty():
			continue
		var behind := []
		for dir in b.target.directions:
			if _behind(dir, side):
				behind.append(dir)
		b._want(side, hand, thing, behind)
	return b


## Draws the body layers for either hand in use ahead, so changing hands later only
## composites.
static func prepare(look: Array) -> void:
	for hand in ["left", "right"]:
		var b = build(look, {"active": hand})
		while not b._todo.is_empty():
			b.step()


## Does a little of the building: a row of a layer not drawn before, else a row of the
## compositing. True when the sheet is done.
func step() -> bool:
	if not _todo.is_empty():
		var t: Dictionary = _todo[0]
		t.art.draw_row(t.layer.name, target, t.thing, t.row)
		t.row += 1
		if t.row == target.directions.size():
			t.layer.image = t.art.img
			_drawn[t.layer.key] = t.art.img
			_todo.pop_front()
		return false
	if _composited == 0:
		target.begin(_layers)
	target.compose_row(_composited)
	_composited += 1
	if _composited < target.directions.size():
		return false
	target.finish()
	return true


## Adds a layer to the sheet, to be drawn first unless it was drawn before; only the
## body, the shirt and the hands change with the hand in use.
func _want(name: String, hand: String, thing: Dictionary, behind: Array) -> void:
	var key := name
	if name in ["body", "shirt", "left", "right"]:
		key += "|" + hand
	if not thing.is_empty():
		key += "|%s|%s" % [thing.model, thing.colour.to_html()]
	var layer := {"name": name, "behind": behind, "key": key}
	_layers.append(layer)
	if _drawn.has(key):
		layer.image = _drawn[key]
		return
	for t: Dictionary in _todo:
		if t.layer.key == key:
			return
	var art = load("res://src/client/player_art.gd").new()
	art.active = hand
	art.start(target)
	_todo.append({"layer": layer, "art": art, "thing": thing, "row": 0})


## A clear image for a whole grid of one layer.
func start(s: SpriteSheet) -> void:
	img = Image.create_empty(s.frame_size.x * s.columns, s.frame_size.y * s.directions.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))


## The whole grid of one layer; `thing` is what the hand holds for a hand's layer.
func draw_layer(layer: String, s: SpriteSheet, thing := {}) -> Image:
	start(s)
	for row in s.directions.size():
		draw_row(layer, s, thing, row)
	return img


## One direction of a layer, every column.
func draw_row(layer: String, s: SpriteSheet, thing: Dictionary, row: int) -> void:
	var dir: String = s.directions[row]
	var drawn: String = MIRROR.get(dir, dir)
	var flipped := MIRROR.has(dir)
	_drawn_active = _other(active) if flipped else active
	for col in s.columns:
		var pose := _pose(col)
		frame = Rect2i(Vector2i(col * s.frame_size.x, row * s.frame_size.y), s.frame_size)
		at = frame.position + ORIGIN
		# A step lifts the whole body by a pixel.
		at.y -= pose.bob
		if layer == "left" or layer == "right":
			_held(thing, _hand(drawn, _other(layer) if flipped else layer, col, pose))
		else:
			_draw(layer, drawn, pose, col)
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


## Whether what hand `hand` holds goes under the body in direction `dir`: with the
## back turned, or in the far hand from the side.
static func _behind(dir: String, hand: String) -> bool:
	var drawn: String = MIRROR.get(dir, dir)
	if MIRROR.has(dir):
		hand = _other(hand)
	match _view(drawn):
		"back":
			return true
		"side":
			return _slot(drawn, hand) == "far"
	return false


## What the legs and arms do in a column of the sheet. left/right: that leg is
## lifted, swing: the hand in front (1) or behind (-1), apart: the legs are apart
## in side view, leading with the front leg (1) or the back one (-1).
func _pose(col: int) -> Dictionary:
	match col:
		1:
			return {"left": true, "right": false, "swing": 1, "apart": 1, "bob": 1}
		3:
			return {"left": false, "right": true, "swing": -1, "apart": -1, "bob": 1}
	return {"left": false, "right": false, "swing": 0, "apart": 0, "bob": 0}


## Where hand `hand` of drawn direction `dir` is in column `col` (see FRONT_WORK), with
## "slot" (see _slot), "worked": whether it is the hand in use in a work column, which
## the body draws raised instead of hanging, and "front": whether it is in front of
## the body.
func _hand(dir: String, hand: String, col: int, pose: Dictionary) -> Dictionary:
	var view := _view(dir)
	var slot := _slot(dir, hand)
	var work := ""
	var phase := 0
	for kind in WORK_COLUMNS:
		if col == WORK_COLUMNS[kind] or col == WORK_COLUMNS[kind] + 1:
			work = kind
			phase = col - WORK_COLUMNS[kind]
	var h: Dictionary
	if work != "" and hand == _drawn_active:
		h = (SIDE_WORK if view == "side" else FRONT_WORK)[work][phase].duplicate()
		h.worked = true
		if slot == "far":
			h.grip -= Vector2i(1, 0)
			h.sleeve = h.sleeve.map(func(p: Vector2i) -> Vector2i: return p - Vector2i(1, 0))
	elif slot == "near":
		# The near hand swings with the step; a tool stands up in front of it.
		var x: int = 5 + pose.swing
		h = {"grip": Vector2i(x + 1, 9 if pose.swing != 0 else 10), "up": Vector2i(0, -1), "out": Vector2i(1, 0)}
	elif slot == "far":
		h = {"grip": Vector2i(4, 10), "up": Vector2i(0, -1), "out": Vector2i(1, 0)}
	else:
		# A hanging hand holds its tool upright beside it, edge outwards.
		var lifted: bool = pose.swing < 0 if slot == "a" else pose.swing > 0
		h = {"grip": Vector2i(0, 8 if lifted else 10), "up": Vector2i(0, -1), "out": Vector2i(-1, 0)}
	if not h.has("worked"):
		h.worked = false
		h.sleeve = []
	if slot == "b":
		h.grip = Vector2i(9 - h.grip.x, h.grip.y)
		h.up = Vector2i(-h.up.x, h.up.y)
		h.out = Vector2i(-h.out.x, h.out.y)
		h.sleeve = h.sleeve.map(func(p: Vector2i) -> Vector2i: return Vector2i(9 - p.x, p.y))
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


## What a hand holds, from its grip (see _hand) and over it the hand when it works.
func _held(thing: Dictionary, h: Dictionary) -> void:
	var c: Color = thing.colour
	var shape: Dictionary = SHAPES.get(thing.model, {})
	if shape.is_empty():
		var aside := Vector2i(signi(h.out.x) if h.out.x != 0 else 1, 0)
		for d: Vector2i in [Vector2i.ZERO, aside, Vector2i.UP, aside + Vector2i.UP]:
			_px(h.grip.x + d.x, h.grip.y + d.y, c)
	else:
		var up: Vector2i = h.up if h.worked or not shape.get("down", false) else -h.up
		for a in range(shape.haft[0], shape.haft[1] + 1):
			var p: Vector2i = h.grip + up * a
			_px(p.x, p.y, COLORS.wood)
		for part: Array in shape.head:
			var p: Vector2i = h.grip + up * int(part[0]) + h.out * int(part[1])
			_px(p.x, p.y, c if part[2] == "h" else COLORS.dark)
	if h.worked:
		_px(h.grip.x, h.grip.y, COLORS.skin)


func _draw(layer: String, dir: String, pose: Dictionary, col: int) -> void:
	var side := dir == "e"
	var hands := []
	if layer == "body" or layer == "shirt":
		hands = [_hand(dir, "left", col, pose), _hand(dir, "right", col, pose)]
	match layer:
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
