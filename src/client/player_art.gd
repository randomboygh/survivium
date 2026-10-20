extends RefCounted
## Placeholder art of the player, drawn pixel by pixel for every direction and
## frame of the sheet below, in layers that later come from a mod's PNG files: the
## body (skin, eyes, hands), hair, shirt, trousers, boots and a tool in the right
## hand. The figure is 8 pixels wide and 14 tall before its outline, two cells tall
## on screen, like the one-frame text sprite it replaces.

const SpriteSheet := preload("res://src/client/sprite_sheet.gd")

## Sheet layout: five drawn directions, the west ones mirrored from the east ones;
## column 0 stands, columns 1-4 walk (step left, feet together, step right, together).
const SHEET := {
	"frame": [14, 18],
	"directions": ["s", "se", "e", "ne", "n"],
	"mirror": {"sw": "se", "w": "e", "nw": "ne"},
	"animations": {
		"idle": {"frames": [0], "fps": 1.0},
		"walk": {"frames": [1, 2, 3, 4], "fps": 10.0},
		"jump": {"frames": [1], "fps": 1.0},
	},
	"outline": true,
}
## Layers in drawing order; the axe goes behind the body when the back is turned.
const LAYERS := [
	{"name": "body"},
	{"name": "shirt"},
	{"name": "trousers"},
	{"name": "boots"},
	{"name": "hair"},
	{"name": "axe", "behind": ["n", "ne"]},
]
## Where the figure's 10x16 box (outline included) sits in a frame: two pixels of
## room on each side for a tool and above for a lifted body, its bottom row on the
## frame's last row.
const ORIGIN := Vector2i(2, 2)

const COLORS := {
	"skin": Color(0.95, 0.78, 0.62),
	"eye": Color(0.1, 0.1, 0.15),
	"hair": Color(0.35, 0.22, 0.12),
	"shirt": Color(0.25, 0.45, 0.72),
	"trousers": Color(0.35, 0.3, 0.24),
	"boots": Color(0.25, 0.17, 0.1),
	"wood": Color(0.5, 0.33, 0.16),
	"iron": Color(0.62, 0.64, 0.68),
}

var img: Image
## Top-left of the figure's box in the image for the frame being drawn.
var at: Vector2i


## The sheet with the given layers (names from LAYERS) drawn and composited.
static func sheet(look: Array) -> SpriteSheet:
	var s := SpriteSheet.new(SHEET)
	var layers := []
	for layer in LAYERS:
		if look.has(layer.name):
			var l: Dictionary = layer.duplicate()
			l.image = load("res://src/client/player_art.gd").new().draw_layer(layer.name, s)
			layers.append(l)
	s.set_layers(layers)
	return s


## The whole grid of one layer.
func draw_layer(layer: String, s: SpriteSheet) -> Image:
	img = Image.create_empty(s.frame_size.x * s.columns, s.frame_size.y * s.directions.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for row in s.directions.size():
		for col in s.columns:
			var pose := _pose(col)
			at = Vector2i(col * s.frame_size.x, row * s.frame_size.y) + ORIGIN
			# A step lifts the whole body by a pixel.
			at.y -= pose.bob
			_draw(layer, s.directions[row], pose)
	return img


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


func _px(x: int, y: int, c: Color) -> void:
	img.set_pixel(at.x + x, at.y + y, c)


func _row(x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(x, y, c)


func _draw(layer: String, dir: String, pose: Dictionary) -> void:
	var side := dir == "e"
	var back := dir == "n" or dir == "ne"
	match layer:
		"body":
			_face(dir)
			var skin: Color = COLORS.skin
			if side:
				# The near arm hangs in front of the body and swings with the step.
				var x: int = 5 + pose.swing
				_row(x, x, 9 if pose.swing != 0 else 10, skin)
				_px(x, 10, skin)
			else:
				var lift_left: bool = pose.swing < 0
				var lift_right: bool = pose.swing > 0
				_row(1, 1, 8 if lift_left else 10, skin)
				_px(1, 9, skin)
				_row(8, 8, 8 if lift_right else 10, skin)
				_px(8, 9, skin)
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
		"shirt":
			var c: Color = COLORS.shirt
			if side:
				_row(4, 6, 7, c)
				_row(3, 6, 8, c)
				_row(3, 6, 9, c)
				_row(3, 6, 10, c)
				# Leave the near hand showing.
				var x: int = 5 + pose.swing
				_px(x, 10, Color(0, 0, 0, 0))
				if pose.swing != 0:
					_px(x, 9, Color(0, 0, 0, 0))
			else:
				_row(3, 6, 7, c)
				for y in range(8, 11):
					_row(2, 7, y, c)
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
		"axe":
			var wood: Color = COLORS.wood
			var iron: Color = COLORS.iron
			if side:
				for y in range(8, 13):
					_px(7, y, wood)
				_row(7, 8, 7, iron)
				_row(7, 8, 8, iron)
			else:
				# In the right hand: on the right when facing us, on the left from behind.
				var x := -1 if back else 10
				var head := 0 if back else 9
				for y in range(7, 12):
					_px(x, y, wood)
				_row(mini(x, head), maxi(x, head), 6, iron)
				_row(mini(x, head), maxi(x, head), 7, iron)


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
