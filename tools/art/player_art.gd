extends RefCounted
## The pictures of the bare player, drawn pixel by pixel for every direction and frame
## of the sheet laid out in content/core/sprites/player.yaml; tools/make_sprites.gd
## saves them as the core mod's pictures (content/core/sprites/player/), which the game
## reads (Figure) and which can be painted over by hand from there. Layers: the body
## (skin, face, the arms behind the body, skin under the clothes), shirt, trousers (with
## the belt), boots, hair, the fists (the forearms and hands in front of the body, drawn
## over what the hands hold) and the hands picture marking where each hand is. The hands
## are empty: what they hold has sheets of its own (ToolArt), turned the way the poses
## here say.
##
## The figure is 8 pixels wide and 14 tall inside its outline, two cells tall on screen.
## It is put together from parts written as letters standing for colours (INK): the
## head (rows 1-6 of its 10x16 box), the torso (7-10) and the legs (11-14), for five
## directions; the west ones are the east ones mirrored with the hands swapped. Arms go
## from the shoulder to the hand. Light comes from the upper left.
##
## The sheet is drawn for the right hand in use. In the work columns (player.yaml
## `works`) that hand winds up, strikes and follows through (WORKS), and in a
## two-handed work the other hand holds the same thing further along.

const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")
const Figure := preload("res://src/client/view/figure.gd")

## Directions drawn as another one flipped, with the hands swapped.
const MIRROR := {"sw": "se", "w": "e", "nw": "ne"}
## Where the figure's 10x16 box (outline included) sits in a frame: room on each side
## and above for a tool swung out or overhead, its bottom row on the frame's last row.
const ORIGIN := Vector2i(11, 16)

## Colour and layer of each letter of the parts.
const INK := {
	"J": ["936c48", "hair"], "H": ["6e4a30", "hair"], "D": ["4a301f", "hair"],
	"S": ["e6b690", "body"], "s": ["c08a69", "body"], "E": ["2c2226", "body"],
	"L": ["7f9dbb", "shirt"], "C": ["5b7a9b", "shirt"], "c": ["445c78", "shirt"],
	"K": ["3e2d21", "trousers"], "k": ["c9a65e", "trousers"],
	"T": ["716049", "trousers"], "t": ["514538", "trousers"],
	"B": ["5c402c", "boots"], "b": ["3b291d", "boots"], "O": ["7d5d42", "boots"],
}
## Letters drawn darker skin under them in the body layer (the rest lighter skin).
const SHADED := "cKtb"

## How each drawn direction shows the body.
const VIEW := {"s": "front", "se": "front", "e": "side", "ne": "back", "n": "back"}

## The head, rows 1-6 of the box.
const HEAD := {
	"s": [
		"...JJHH...",
		"..JHHHHD..",
		"..HHHHHHD.",
		"..HSSSSHD.",
		"..SESSES..",
		"...sSSs...",
	],
	"se": [
		"...JJHH...",
		"..JHHHHHD.",
		"..HHHHHHH.",
		"..HHSSSSH.",
		"..DSESSES.",
		"...DsSSs..",
	],
	"e": [
		"...JJHH...",
		"..JHHHHHH.",
		"..HHHHHHHH",
		"..DHHSSSS.",
		"..DDSSSES.",
		"...DsSSs..",
	],
	"ne": [
		"...JJHH...",
		"..JHHHHHH.",
		"..HHHHHHHD",
		"..HHHHHHs.",
		"..DHHHHDs.",
		"...DDss...",
	],
	"n": [
		"...JJHH...",
		"..JHHHHD..",
		"..HHHHHHD.",
		"..HHHHHHD.",
		"..DHHHHDD.",
		"...sssS...",
	],
}
## The torso, rows 7-10: the shirt and the belt.
const TORSO := {
	"s": [
		"..LCCCCc..",
		"..LCCCCc..",
		"..CCCCcc..",
		"..KKkKKK..",
	],
	"se": [
		"..LCCCCc..",
		"..LCCCCc..",
		"..CCCCcc..",
		"..KKKkKK..",
	],
	"e": [
		"...LCCc...",
		"...LCCc...",
		"...CCCc...",
		"...KKKk...",
	],
	"ne": [
		"..LCCCCc..",
		"..LCCCCc..",
		"..CCCCcc..",
		"..KKKKKK..",
	],
	"n": [
		"..LCCCCc..",
		"..LCCCCc..",
		"..CCCCcc..",
		"..KKKKKK..",
	],
}
## The legs, rows 11-14, by view and pose. Front and back: "stand", "right" or "left"
## (that foot a step behind, a pixel up), "tuck" (both drawn up, jumping). Side: "stand",
## "near" or "far" (that leg in front, striding), "pass" (the near knee coming
## forward), "tuck".
const LEGS := {
	"front": {
		"stand": [
			"..TTTTTt..",
			"..TTtTTt..",
			"..TTtTTt..",
			"..BBbBBb..",
		],
		"right": [
			"..TTTTTt..",
			"..TTtTTt..",
			"..BBbTTt..",
			".....BBb..",
		],
		"left": [
			"..TTTTTt..",
			"..TTtTTt..",
			"..TTtBBb..",
			"..BBb.....",
		],
		"tuck": [
			"..TTTTTt..",
			"..TTtTTt..",
			"..BBbBBb..",
			"..........",
		],
	},
	"side": {
		"stand": [
			"...tTTT...",
			"...tTTt...",
			"...tTTt...",
			"...bBBO...",
		],
		"near": [
			"...tTTT...",
			"..tt.TTt..",
			".tt...TT..",
			".bb...BBO.",
		],
		"far": [
			"...TTTt...",
			"..TT.tt...",
			".TT...tt..",
			".BBO..bbb.",
		],
		"pass": [
			"...tTTTT..",
			"...tTTTt..",
			"...t.TT...",
			"...b.BBO..",
		],
		"tuck": [
			"...tTTT...",
			"..tTTTTt..",
			"..bbBBO...",
			"..........",
		],
	},
}

## Shoulders by view: where the right arm and the left one start (side view: the near
## one and the far one).
const SHOULDER := {
	"front": {"right": Vector2i(1, 7), "left": Vector2i(8, 7)},
	"side": {"right": Vector2i(4, 7), "left": Vector2i(4, 7)},
	"back": {"right": Vector2i(8, 7), "left": Vector2i(1, 7)},
}
## The hands when they do not work, by view and animation, a frame each: [right hand,
## left hand] in the box (moved with the body when it bobs), and the legs and how far
## the body bobs down. A swimmer's strokes go over the water, which comes up to its
## shoulders (Body.SWIM_DEPTH), the arms reaching out and pulling back in turn.
const MOVES := {
	"front": {
		"idle": [{"hands": [[1, 10], [8, 10]]}],
		"walk": [
			{"hands": [[1, 9], [8, 10]], "legs": "left", "bob": 1},
			{"hands": [[1, 10], [8, 10]]},
			{"hands": [[1, 10], [8, 9]], "legs": "right", "bob": 1},
			{"hands": [[1, 10], [8, 10]]},
		],
		"jump": [
			{"hands": [[0, 6], [9, 6]], "legs": "tuck"},
			{"hands": [[0, 8], [9, 8]]},
		],
		"swim": [
			{"hands": [[0, 3], [9, 7]], "legs": "left"},
			{"hands": [[0, 6], [9, 5]]},
			{"hands": [[0, 7], [9, 3]], "legs": "right"},
			{"hands": [[0, 5], [9, 6]]},
		],
	},
	"side": {
		"idle": [{"hands": [[4, 10], [3, 10]]}],
		"walk": [
			{"hands": [[2, 9], [7, 9]], "legs": "near", "bob": 1},
			{"hands": [[4, 10], [3, 10]], "legs": "pass"},
			{"hands": [[6, 9], [2, 9]], "legs": "far", "bob": 1},
			{"hands": [[4, 10], [3, 10]], "legs": "pass"},
		],
		"jump": [
			{"hands": [[6, 5], [2, 6]], "legs": "tuck"},
			{"hands": [[6, 8], [2, 8]]},
		],
		"swim": [
			{"hands": [[9, 4], [2, 6]], "legs": "near"},
			{"hands": [[7, 7], [5, 3]]},
			{"hands": [[2, 6], [9, 4]], "legs": "far"},
			{"hands": [[5, 3], [7, 7]]},
		],
	},
	"back": {
		"idle": [{"hands": [[8, 10], [1, 10]]}],
		"walk": [
			{"hands": [[8, 9], [1, 10]], "legs": "left", "bob": 1},
			{"hands": [[8, 10], [1, 10]]},
			{"hands": [[8, 10], [1, 9]], "legs": "right", "bob": 1},
			{"hands": [[8, 10], [1, 10]]},
		],
		"jump": [
			{"hands": [[9, 6], [0, 6]], "legs": "tuck"},
			{"hands": [[9, 8], [0, 8]]},
		],
		"swim": [
			{"hands": [[9, 3], [0, 7]], "legs": "left"},
			{"hands": [[9, 6], [0, 5]]},
			{"hands": [[9, 7], [0, 3]], "legs": "right"},
			{"hands": [[9, 5], [0, 6]]},
		],
	},
}
## The hand in use in each frame of the works, by view, for the right hand (side view:
## the near one): "r" where it is, "a" the way what it holds points (0 up, then
## clockwise by eighths; -1: as carried), "ccw" when the thing turns anticlockwise (its
## edge leads the other way), "f" in front of the body or not (by default as the view
## has it), "o" where the other hand holds a two-handed thing, "bob" and "lean" how far
## the body bends down and forward, "eyes" "shut".
const WORKS := {
	"front": {
		"chop": [
			{"r": [1, 5], "a": 0, "f": false},
			{"r": [2, 1], "a": 0, "f": false},
			{"r": [3, 8], "a": TOWARD},
			{"r": [3, 9], "a": TOWARD, "bob": 1},
		],
		"dig": [
			{"r": [2, 8], "a": TOWARD},
			{"r": [2, 9], "a": TOWARD, "bob": 1},
			{"r": [3, 10], "a": TOWARD, "bob": 1},
			{"r": [1, 7], "a": 7},
		],
		"slash": [
			{"r": [0, 6], "a": 7},
			{"r": [0, 3], "a": 6, "f": false},
			{"r": [5, 8], "a": 2},
			{"r": [6, 8], "a": 3},
		],
		"reach": [
			{"r": [1, 9], "a": -1},
			{"r": [2, 10], "a": -1},
			{"r": [3, 11], "a": -1, "bob": 1},
			{"r": [2, 10], "a": -1},
		],
		"mow": [
			{"r": [1, 8], "a": 6, "o": [3, 8], "ccw": true},
			{"r": [2, 9], "a": TOWARD, "o": [3, 8], "ccw": true, "bob": 1},
			{"r": [4, 9], "a": TOWARD, "o": [5, 8], "ccw": true, "bob": 1},
			{"r": [6, 8], "a": 2, "o": [8, 8], "ccw": true},
		],
		"aim": [
			{"r": [2, 9], "a": TOWARD, "o": [5, 9]},
			{"r": [3, 8], "a": TOWARD, "o": [6, 8]},
			{"r": [3, 7], "a": TOWARD, "o": [6, 7]},
			{"r": [3, 8], "a": TOWARD, "o": [6, 8]},
		],
		"eat": [
			{"r": [2, 9], "a": -1},
			{"r": [3, 8], "a": -1},
			{"r": [4, 6], "a": -1, "eyes": "shut"},
			{"r": [3, 7], "a": -1},
		],
	},
	"side": {
		"chop": [
			{"r": [3, 5], "a": 7},
			{"r": [3, 1], "a": 6},
			{"r": [7, 7], "a": 3, "lean": 1},
			{"r": [7, 9], "a": 3, "bob": 1, "lean": 1},
		],
		"dig": [
			{"r": [6, 6], "a": 3},
			{"r": [7, 7], "a": 3, "bob": 1},
			{"r": [7, 8], "a": 3, "bob": 1, "lean": 1},
			{"r": [6, 6], "a": 2},
		],
		"slash": [
			{"r": [4, 4], "a": 0},
			{"r": [3, 3], "a": 7},
			{"r": [8, 7], "a": 2, "lean": 1},
			{"r": [7, 9], "a": 3},
		],
		"reach": [
			{"r": [5, 9], "a": -1},
			{"r": [7, 9], "a": -1},
			{"r": [8, 9], "a": -1, "lean": 1},
			{"r": [6, 9], "a": -1},
		],
		"mow": [
			{"r": [4, 7], "a": 6, "o": [3, 8], "ccw": true},
			{"r": [5, 7], "a": 5, "o": [4, 8], "ccw": true, "bob": 1},
			{"r": [7, 7], "a": 3, "o": [8, 8], "ccw": true, "bob": 1, "lean": 1},
			{"r": [7, 7], "a": 2, "o": [9, 7], "ccw": true},
		],
		"aim": [
			{"r": [6, 9], "a": 2, "o": [8, 9]},
			{"r": [6, 8], "a": 2, "o": [8, 8]},
			{"r": [5, 8], "a": 2, "o": [7, 8]},
			{"r": [6, 8], "a": 2, "o": [8, 8]},
		],
		"eat": [
			{"r": [5, 9], "a": -1},
			{"r": [6, 7], "a": -1},
			{"r": [7, 6], "a": -1, "eyes": "shut"},
			{"r": [6, 8], "a": -1},
		],
	},
	"back": {
		"chop": [
			{"r": [8, 5], "a": 0, "f": true},
			{"r": [7, 1], "a": 0, "f": true},
			{"r": [6, 8], "a": 0},
			{"r": [6, 9], "a": 0, "bob": 1},
		],
		"dig": [
			{"r": [7, 8], "a": 0},
			{"r": [7, 9], "a": 0, "bob": 1},
			{"r": [6, 10], "a": 0, "bob": 1},
			{"r": [7, 8], "a": 1},
		],
		"slash": [
			{"r": [9, 6], "a": 1, "f": true},
			{"r": [9, 3], "a": 2, "f": true},
			{"r": [4, 8], "a": 7},
			{"r": [3, 9], "a": 0},
		],
		"reach": [
			{"r": [8, 9], "a": -1},
			{"r": [7, 9], "a": -1},
			{"r": [6, 9], "a": -1, "bob": 1},
			{"r": [7, 9], "a": -1},
		],
		"mow": [
			{"r": [8, 9], "a": 2, "o": [6, 9], "ccw": true, "f": true},
			{"r": [7, 10], "a": 1, "o": [5, 10], "ccw": true, "bob": 1},
			{"r": [5, 10], "a": 0, "o": [3, 10], "ccw": true, "bob": 1},
			{"r": [3, 9], "a": 7, "o": [1, 9], "ccw": true},
		],
		"aim": [
			{"r": [7, 9], "a": 0, "o": [4, 9]},
			{"r": [7, 8], "a": 0, "o": [4, 8]},
			{"r": [7, 7], "a": 0, "o": [4, 7]},
			{"r": [7, 8], "a": 0, "o": [4, 8]},
		],
		"eat": [
			{"r": [8, 9], "a": -1},
			{"r": [7, 7], "a": -1},
			{"r": [6, 6], "a": -1},
			{"r": [7, 8], "a": -1},
		],
	},
}
## A thing held pointing at the ground in front of a body facing the viewer, drawn
## foreshortened (one more way after the eight).
const TOWARD := 8
## The eight ways a thing held can point, clockwise from up.
const WAYS := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

## Layer images already drawn, by name, and the hands' places (see anchors).
static var _drawn := {}
static var _anchors := []


## The image of layer `name` (player.yaml `layers` or `fists`), drawn the first time.
static func layer(name: String) -> Image:
	if not _drawn.has(name):
		var s := SpriteSheet.new(Figure.data())
		var img := Image.create_empty(s.image_size().x, s.image_size().y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for row in s.directions.size():
			var dir: String = s.directions[row]
			var drawn: String = MIRROR.get(dir, dir)
			var flipped := MIRROR.has(dir)
			for col in s.columns:
				var frame := Rect2i(Vector2i(col * s.frame_size.x, row * s.frame_size.y), s.frame_size)
				var letters: Dictionary = frame_letters(drawn, "left" if flipped else "right", col)[name]
				for p: Vector2i in letters:
					var at := ORIGIN + p
					if flipped:
						at.x = s.frame_size.x - 1 - at.x
					# The frame's edge stays clear for the outline.
					if at.x > 0 and at.y > 0 and at.x < s.frame_size.x - 1 and at.y < s.frame_size.y - 1:
						img.set_pixelv(frame.position + at, Color.html(INK[letters[p]][0]))
		_drawn[name] = img
	return _drawn[name]


## Where the hands are, by row and column of the sheet: {"right": hand, "left": hand},
## a hand being {"at": its pixel in the frame, "front": over the body or not, "angle":
## the way what it holds points, -1 as carried}, or {} for the other hand of a
## two-handed work, which holds the same thing.
static func anchors() -> Array:
	if _anchors.is_empty():
		var s := SpriteSheet.new(Figure.data())
		for row in s.directions.size():
			var dir: String = s.directions[row]
			var drawn: String = MIRROR.get(dir, dir)
			var flipped := MIRROR.has(dir)
			var cols := []
			for col in s.columns:
				var p := pose(drawn, "left" if flipped else "right", col)
				var both := {}
				for hand in ["right", "left"]:
					var h: Dictionary = p[_other(hand) if flipped else hand]
					if not h.holds:
						both[hand] = {}
						continue
					var at: Vector2i = ORIGIN + h.at
					if flipped:
						at.x = s.frame_size.x - 1 - at.x
					var angle: int = h.angle
					if angle == TOWARD:
						angle = 4
					if flipped and angle >= 0:
						angle = mirrored(angle)
					both[hand] = {"at": at, "front": h.front, "angle": angle}
				cols.append(both)
			_anchors.append(cols)
	return _anchors


## The hands picture: in each frame a pixel at each hand, red for the right one, blue
## for the left one, darker behind the body, its green the way what the hand holds
## points (see player.yaml).
static func marks() -> Image:
	var s := SpriteSheet.new(Figure.data())
	var img := Image.create_empty(s.image_size().x, s.image_size().y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var all := anchors()
	for row in all.size():
		for col in all[row].size():
			for hand in ["right", "left"]:
				var a: Dictionary = all[row][col][hand]
				var other: Dictionary = all[row][col][_other(hand)]
				if not a.is_empty() and not other.is_empty() and a.at == other.at:
					push_error("both hands on one pixel in row %d, column %d" % [row, col])
				if not a.is_empty():
					var c: Color = Figure.MARKS[hand] * (1.0 if a.front else 0.5)
					c.a = 1.0
					c.g = (a.angle + 1) / 8.0 if a.angle >= 0 else 0.0
					img.set_pixelv(Vector2i(col, row) * s.frame_size + a.at, c)
	return img


static func _other(hand: String) -> String:
	return "left" if hand == "right" else "right"


## The animation playing in column `col` of the sheet and its frame there: [name, i].
static func column(col: int) -> Array:
	var works: Dictionary = Figure.data().works
	for kind in works:
		if works[kind].columns.has(col):
			return [kind, works[kind].columns.find(col)]
	var anims: Dictionary = Figure.data().animations
	for name in anims:
		var seen := []
		for c in anims[name].frames:
			if not seen.has(c):
				seen.append(c)
		if seen.has(col):
			return [name, seen.find(col)]
	return ["idle", 0]


## Way `a` mirrored left to right.
static func mirrored(a: int) -> int:
	return a if a == TOWARD else (8 - a) % 8


## The pose of column `col` drawn in direction `dir` (a drawn one: s, se, e, ne, n) with
## hand `active` in use: {"bob", "lean", "legs", "eyes", "right": hand, "left": hand}, a
## hand being {"at": where it is in the box, "shoulder", "front": in front of the body,
## "holds": false for the other hand of a two-handed work, "worked", "angle": the way
## what it holds points (-1: as carried), "ccw"}.
static func pose(dir: String, active: String, col: int) -> Dictionary:
	var view: String = VIEW[dir]
	var c := column(col)
	var moves: Dictionary = MOVES[view]
	var move: Dictionary = moves.idle[0]
	if moves.has(c[0]):
		move = moves[c[0]][mini(c[1], moves[c[0]].size() - 1)]
	var p := {"bob": move.get("bob", 0), "lean": 0, "legs": move.get("legs", "stand"), "eyes": "open"}
	if c[0] == "idle" and c[1] == 1:
		p.eyes = "shut"
	for i in 2:
		var hand: String = ["right", "left"][i]
		var at: Array = move.hands[i]
		p[hand] = {"at": Vector2i(at[0], at[1] + p.bob), "front": _front(view, hand), "holds": true, "worked": false, "angle": -1, "ccw": false}
	if WORKS[view].has(c[0]):
		var w: Dictionary = WORKS[view][c[0]][c[1]]
		p.bob = w.get("bob", 0)
		p.lean = w.get("lean", 0)
		p.eyes = w.get("eyes", "open")
		var other := _other(active)
		var at := Vector2i(w.r[0], w.r[1])
		var angle: int = w.a
		var ccw: bool = w.get("ccw", false)
		var front: bool = w.get("f", _front(view, "right"))
		var off: Vector2i = Vector2i(w.o[0], w.o[1]) if w.has("o") else Vector2i(-1, -1)
		if active == "left":
			if view == "side":
				# The far hand does the same a pixel further back, behind the body.
				at.x -= 1
				front = false
			else:
				# The left hand does it on the other side of the body.
				at.x = 9 - at.x
				off.x = 9 - off.x
				if angle >= 0:
					angle = mirrored(angle)
				ccw = not ccw
		if dir in ["se", "ne"] and angle >= 0:
			# Turned a little to the east: what it holds swings that way.
			angle = [1, 1, 2, 3, 3, 4, 6, 0, TOWARD][angle]
		p[active] = {"at": at, "front": front, "holds": true, "worked": true, "angle": angle, "ccw": ccw}
		if w.has("o"):
			p[other] = {"at": off, "front": front if view != "side" else active == "left", "holds": false, "worked": true, "angle": -1, "ccw": false}
		else:
			# The other hand hangs as it does standing.
			var still: Array = moves.idle[0].hands[1 if other == "left" else 0]
			p[other].at = Vector2i(still[0], still[1] + p.bob)
	for hand in ["right", "left"]:
		var s: Vector2i = SHOULDER[view][hand]
		p[hand].shoulder = s + Vector2i(p.lean, p.bob)
	return p


## Whether a hand of a view is in front of the body by default.
static func _front(view: String, hand: String) -> bool:
	match view:
		"front":
			return true
		"side":
			return hand == "right"
	return false


## The letters of every layer in one frame: {layer: {pixel in the box: letter}}.
static func frame_letters(dir: String, active: String, col: int) -> Dictionary:
	var p := pose(dir, active, col)
	var view: String = VIEW[dir]
	var out := {"body": {}, "shirt": {}, "trousers": {}, "boots": {}, "hair": {}, "fists": {}}
	var up := Vector2i(p.lean, p.bob)
	var parts := []
	var legs: Dictionary = LEGS["side" if view == "side" else "front"]
	_stamp(parts, legs[p.legs], 11, Vector2i.ZERO)
	_stamp(parts, TORSO[dir], 7, up)
	var head: Array = HEAD[dir]
	if p.eyes == "shut":
		head = head.map(func(r: String) -> String: return r.replace("E", "s"))
	_stamp(parts, head, 1, up)
	var solid := {}
	for e: Array in parts:
		solid[e[0]] = true
	# Arms behind the body show only where the body leaves them.
	for hand in ["left", "right"]:
		if not p[hand].front:
			_arm(out, p[hand], view, hand, solid, false)
	for e: Array in parts:
		_put(out, e[0], e[1])
	for hand in ["left", "right"]:
		if p[hand].front:
			_arm(out, p[hand], view, hand, {}, true)
	return out


static func _stamp(parts: Array, rows: Array, y0: int, shift: Vector2i) -> void:
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] != ".":
				parts.append([Vector2i(x, y0 + y) + shift, r[x]])


## A letter in its layer, with skin under it in the body layer where it is clothes.
static func _put(out: Dictionary, at: Vector2i, letter: String) -> void:
	var layer: String = INK[letter][1]
	out[layer][at] = letter
	if layer in ["shirt", "trousers", "boots"] and not out.body.has(at):
		out.body[at] = "s" if SHADED.contains(letter) else "S"


## An arm from the shoulder to the hand: the sleeve the first half, then the skin; in
## front of the body the skin goes to the fists, over what the hand holds.
static func _arm(out: Dictionary, h: Dictionary, view: String, hand: String, solid: Dictionary, front: bool) -> void:
	var line := _line(h.shoulder, h.at)
	var sleeve := maxi(1, line.size() / 2)
	# The arm on the lit side is lighter.
	var lit: bool = (view == "front" and hand == "right") or (view == "back" and hand == "left") or (view == "side" and hand == "right")
	for i in line.size():
		var at: Vector2i = line[i]
		if solid.has(at):
			continue
		if i < sleeve and line.size() > 1:
			_put(out, at, "L" if lit else "c")
		elif front:
			out.fists[at] = "S" if lit or i == line.size() - 1 else "s"
		else:
			out.body[at] = "s"


## The pixels of a line from `a` to `b`, both ends included.
static func _line(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(1.0, n)
		out.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return out
