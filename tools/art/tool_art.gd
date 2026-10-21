extends RefCounted
## The sheets of the tools held in a hand, drawn pixel by pixel; tools/make_sprites.gd
## saves them as the core mod's pictures (content/core/sprites/held/<sprite>.png), which
## can be painted over by hand from there. A sheet has a row for each direction of the
## player's sheet, drawn as held in the right hand, and a column for carrying the tool,
## then one for each frame of its work (player.yaml `works`). Each frame is a cell of
## player.yaml `held` with the hand at its grip; the tool points the way the player's
## pose of that frame says (PlayerArt.pose).
##
## A tool is drawn twice (SHAPES): pointing up, and pointing up and right; turning
## those by quarter turns gives the eight ways. Its edge is on the clockwise side, and
## a tool swung anticlockwise is mirrored along its length. "g" is the pixel in the
## hand. Small things (blocks, food, seeds) have no sheet: the game turns their icon
## (Figure).

const PlayerArt := preload("res://tools/art/player_art.gd")
const Figure := preload("res://src/client/figure.gd")

## Colours of the letters of SHAPES.
const INK := {
	"d": "5a3b22", "w": "84593a", "W": "a77850", "g": "5a3b22",
	"q": "5a5e66", "a": "8a8f97", "A": "c3c8cc",
	"r": "c8ad78", "R": "8e7650",
	"m": "9a7646", "p": "c39c64", "P": "e2c48c",
}
const SHAPES := {
	"axe": {
		"up": [
			".d...",
			"rqaA.",
			"rqaaA",
			"rqaA.",
			".w...",
			".w...",
			".W...",
			".d...",
			".g...",
		],
		"diagonal": [
			"......d",
			".....r.",
			"....rqa",
			"...W.aA",
			"..w..A.",
			".d.....",
			"g......",
		],
		"toward": [
			".g.",
			".w.",
			".W.",
			"qaA",
			"qaA",
			".A.",
		],
		"carry": {"front": 7, "side": 1, "back": 1},
	},
	"pickaxe": {
		"up": [
			".qaaaA.",
			"q..r..A",
			"q..w..A",
			"...w...",
			"...W...",
			"...w...",
			"...w...",
			"...d...",
			"...g...",
		],
		"diagonal": [
			"..qq.....",
			"...aaa...",
			".....raa.",
			"....W..aA",
			"...w....A",
			"..w......",
			".d.......",
			"g........",
		],
		"toward": [
			"..g..",
			"..w..",
			"..W..",
			"qaraA",
			"q...A",
		],
		"carry": {"front": 7, "side": 1, "back": 1},
	},
	"shovel": {
		"up": [
			".pPp.",
			"mpPPp",
			"mppPp",
			"mpppp",
			".mpm.",
			"..w..",
			"..W..",
			"..w..",
			"..w..",
			"..W..",
			"..w..",
			"..d..",
			"..g..",
		],
		"diagonal": [
			".......pP.",
			"......pPPp",
			"......mpPp",
			"......wmm.",
			".....W....",
			"....w.....",
			"...w......",
			"..W.......",
			".d........",
			"g.........",
		],
		"toward": [
			".g..",
			".w..",
			".W..",
			".w..",
			"mppP",
			"mpPP",
			".mp.",
		],
		"carry": {"front": 0, "side": 0, "back": 0},
	},
	"sword": {
		"up": [
			".P.",
			".Pp",
			".Pp",
			".Pp",
			".Pp",
			".Pp",
			"ddd",
			".w.",
			".g.",
		],
		"diagonal": [
			"......P",
			".....Pp",
			"....Pp.",
			".d.Pp..",
			"..d....",
			".w.d...",
			"g......",
		],
		"toward": [
			".g.",
			"ddd",
			".P.",
			".p.",
		],
		"carry": {"front": 5, "side": 3, "back": 3},
	},
	"scythe": {
		"up": [
			"daaAA..",
			"w..qaAA",
			"w....qA",
			"w.....A",
			"w......",
			"W......",
			"wd.....",
			"w......",
			"W......",
			"w......",
			"w......",
			"d......",
			"g......",
		],
		"diagonal": [
			"........da...",
			".......w..aA.",
			"......W....aA",
			".....w......A",
			"....wd......A",
			"...w.........",
			"..W..........",
			".d...........",
			"g............",
		],
		"toward": [
			"g.....",
			"w.....",
			"W.....",
			"w.....",
			"daaAA.",
			"...aAA",
		],
		"carry": {"front": 0, "side": 1, "back": 0},
	},
}


## Sheets drawn as another tool with some colours swapped: name -> [a key of SHAPES,
## {letter: letter}] (a stone sword, wooden heads of a pickaxe and a scythe).
const RECOLOURED := {
	"stone_sword": ["sword", {"P": "A", "p": "a"}],
	"wooden_pickaxe": ["pickaxe", {"q": "R", "a": "m", "A": "p"}],
	"wooden_scythe": ["scythe", {"q": "R", "a": "m", "A": "p"}],
}


## The sheet of tool `sprite` (a key of SHAPES or RECOLOURED) with the frames of work `anim` (a key
## of player.yaml `works`).
static func sheet(sprite: String, anim: String) -> Image:
	var swap: Dictionary = RECOLOURED[sprite][1] if RECOLOURED.has(sprite) else {}
	var shape: Dictionary = SHAPES[RECOLOURED[sprite][0]] if RECOLOURED.has(sprite) else SHAPES[sprite]
	var dirs: Array = Figure.data().directions
	var cell := Vector2i(Figure.data().held.cell[0], Figure.data().held.cell[1])
	var grip := Vector2i(Figure.data().held.grip[0], Figure.data().held.grip[1])
	var cols: Array = [-1]
	if Figure.data().works.has(anim):
		cols.append_array(Figure.data().works[anim].columns)
	var img := Image.create_empty(cell.x * cols.size(), cell.y * dirs.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for row in dirs.size():
		var dir: String = dirs[row]
		var flipped := PlayerArt.MIRROR.has(dir)
		var drawn: String = PlayerArt.MIRROR.get(dir, dir)
		# In a mirrored direction the right hand is drawn as the left one, flipped.
		var hand := "left" if flipped else "right"
		var view: String = PlayerArt.VIEW[drawn]
		for i in cols.size():
			var angle := -1
			var ccw := false
			if cols[i] >= 0:
				var h: Dictionary = PlayerArt.pose(drawn, hand, cols[i])[hand]
				angle = h.angle
				ccw = h.ccw
			if angle < 0:
				angle = shape.carry[view]
				if hand == "left" and view != "side":
					angle = PlayerArt.mirrored(angle)
			var r := Rect2i(Vector2i(i, row) * cell, cell)
			var pixels := turned(shape, angle, ccw)
			for p: Vector2i in pixels:
				var at: Vector2i = r.position + grip + p
				if r.has_point(at):
					img.set_pixelv(at, Color.html(INK[swap.get(pixels[p], pixels[p])]))
			if flipped:
				var part := img.get_region(r)
				part.flip_x()
				img.blit_rect(part, Rect2i(Vector2i.ZERO, cell), r.position)
	return img


## The pixels of a tool pointing way `angle` (0 up, clockwise by eighths, or
## PlayerArt.TOWARD: at the ground in front, towards the viewer, foreshortened),
## mirrored along its length when `ccw`: {offset from the grip: letter}.
static func turned(shape: Dictionary, angle: int, ccw: bool) -> Dictionary:
	if angle == PlayerArt.TOWARD:
		return _pixels(shape.toward, ccw, 0, false)
	return _pixels(shape.up if angle % 2 == 0 else shape.diagonal, ccw, angle / 2, angle % 2 == 1)


static func _pixels(rows: Array, ccw: bool, turns: int, diagonal: bool) -> Dictionary:
	var grip := Vector2i.ZERO
	for y in rows.size():
		var x: int = rows[y].find("g")
		if x >= 0:
			grip = Vector2i(x, y)
	var out := {}
	for y in rows.size():
		for x in rows[y].length():
			var c: String = rows[y][x]
			if c == ".":
				continue
			var p := Vector2i(x, y) - grip
			if ccw:
				p = Vector2i(-p.y, -p.x) if diagonal else Vector2i(-p.x, p.y)
			for k in turns:
				p = Vector2i(-p.y, p.x)
			out[p] = c
	return out
