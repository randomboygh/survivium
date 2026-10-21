extends RefCounted
## Placeholder sheets of the things held in a hand, drawn pixel by pixel;
## tools/make_sprites.gd saves them as the mod's pictures (content/core/sprites/held/).
## A thing's sheet has a row for each direction of the player's sheet, drawn as held in
## the right hand, and a column for carrying it, then one for each frame of its work
## (player.yaml `works`: wind-up, strike). Each frame is a cell of player.yaml `held`
## with the hand at its grip.

const PlayerArt := preload("res://tools/art/player_art.gd")
const Figure := preload("res://src/client/figure.gd")

## A thing that has no picture of its own: a white lump, tinted with its colour.
const LUMP := "lump"

const COLORS := {
	"wood": Color(0.5, 0.33, 0.16),
	"dark": Color(0.3, 0.2, 0.12),
}
## The pictures, from the hand along the way the tool points: the haft from `haft[0]`
## to `haft[1]` pixels, then the head as [along, aside, part] (aside: towards the way
## its edge faces; part "h" in the thing's colour, "d" dark); "down": carried head
## down.
const SHAPES := {
	"axe": {"haft": [-1, 4], "head": [[3, 1, "h"], [4, 1, "h"], [3, 2, "h"], [4, 2, "h"]]},
	"pickaxe": {"haft": [-1, 4], "head": [[4, -2, "h"], [4, -1, "h"], [4, 0, "h"], [4, 1, "h"], [4, 2, "h"], [3, -2, "h"], [3, 2, "h"]]},
	"shovel": {"haft": [-1, 2], "head": [[3, -1, "h"], [3, 0, "h"], [3, 1, "h"], [4, -1, "h"], [4, 0, "h"], [4, 1, "h"]], "down": true},
	"sword": {"haft": [-1, 0], "head": [[1, -1, "d"], [1, 0, "d"], [1, 1, "d"], [2, 0, "h"], [3, 0, "h"], [4, 0, "h"]]},
	"scythe": {"haft": [-1, 6], "head": [[6, 1, "h"], [6, 2, "h"], [5, 3, "h"], [4, 3, "h"]]},
	LUMP: {},
}

var img: Image
## The cell being drawn; a thing reaching out of it is cut off.
var _cell: Rect2i


## The sheet of picture `sprite` (a key of SHAPES) in `colour`, with the frames of work
## `anim` (a key of player.yaml `works`, or "" for none).
static func sheet(sprite: String, colour: Color, anim: String) -> Image:
	return load("res://tools/art/tool_art.gd").new()._draw_sheet(SHAPES.get(sprite, {}), colour, anim)


func _draw_sheet(shape: Dictionary, colour: Color, anim: String) -> Image:
	var dirs: Array = Figure.data().directions
	var cell_size := Vector2i(Figure.data().held.cell[0], Figure.data().held.cell[1])
	var grip := Vector2i(Figure.data().held.grip[0], Figure.data().held.grip[1])
	var cols: Array = [0]
	if Figure.data().works.has(anim):
		cols.append_array(Figure.data().works[anim].columns)
	img = Image.create_empty(cell_size.x * cols.size(), cell_size.y * dirs.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var art = PlayerArt.new()
	for row in dirs.size():
		var dir: String = dirs[row]
		var flipped := PlayerArt.MIRROR.has(dir)
		var drawn: String = PlayerArt.MIRROR.get(dir, dir)
		# In a mirrored direction the right hand is drawn as the left one, flipped.
		art.drawn_active = "left" if flipped else "right"
		for i in cols.size():
			var h: Dictionary = art.hand(drawn, art.drawn_active, cols[i])
			var cell := Rect2i(Vector2i(i, row) * cell_size, cell_size)
			_cell = cell
			# Drawn mirrored around the grip, so flipped it holds the same grip.
			_draw_thing(cell.position + (Vector2i(cell_size.x - 1 - grip.x, grip.y) if flipped else grip), shape, colour, h, i == 0)
			if flipped:
				var part := img.get_region(cell)
				part.flip_x()
				img.blit_rect(part, Rect2i(Vector2i.ZERO, cell_size), cell.position)
	return img


## The thing with its grip at `grip`, pointing the way hand `h` holds it (PlayerArt.hand).
func _draw_thing(grip: Vector2i, shape: Dictionary, c: Color, h: Dictionary, carried: bool) -> void:
	if shape.is_empty():
		var aside := Vector2i(signi(h.out.x) if h.out.x != 0 else 1, 0)
		for d: Vector2i in [Vector2i.ZERO, aside, Vector2i.UP, aside + Vector2i.UP]:
			_px(grip + d, c)
		return
	var up: Vector2i = -h.up if carried and shape.get("down", false) else h.up
	for a in range(shape.haft[0], shape.haft[1] + 1):
		_px(grip + up * a, COLORS.wood)
	for part: Array in shape.head:
		_px(grip + up * int(part[0]) + h.out * int(part[1]), c if part[2] == "h" else COLORS.dark)


func _px(p: Vector2i, c: Color) -> void:
	if _cell.has_point(p):
		img.set_pixelv(p, c)
