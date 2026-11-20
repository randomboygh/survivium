extends RefCounted
## The gestures (Gestures, decision 183), drawn whole under the head as the walk is
## (WalkArt), frames for each drawn direction (PlayerArt.VIEW), the west ones mirrored, in
## the order of their animation's own columns (player.yaml). After the user's review
## (2026-11-20):
## - the wave: the right hand up by the face at the eyes' rows, two pixels square, on a
##   short shoulder (two pixels on the diagonal, a pixel and a half wide: the light over its
##   shade, a pixel of shade under the hand next to it), the hand against the hair on its
##   top row; the hand and the shoulder go a pixel out and back. Turned a little the hand is a
##   pixel over the head's edge (a hand in front of the body is drawn with the fists, over the
##   head), so the shoulder is as short. From the side the near arm is in front of the head:
##   the hand over its side by the ear (its lower row, on the skin, in the shade), the forearm
##   up across the jaw. Turned away the hand is by the jaw, clear of the cheek; from behind by
##   the head at the ear's row.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` and
## from box column X0 (a hand goes out beside the head past the box's edge) in the letters of
## PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS, the body's first row
## `neck` (rows over it hold only a raised arm, which stays where it is in every form), the
## waistband's row `hips` and the hands' places `hands` ([right, left]: the hand's lowest
## pixel under its middle, the one nearer the body on a tie, less the bob; so a hand that
## moves moves its place). Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_gesture_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The rows' first column in the box: they reach as far past its other edge.
const X0 := -2
## The frames by gesture and drawn direction.
const FRAMES := {
	"wave": {
		"s": [
			{"bob": 0, "top": 8, "neck": 11, "hips": 14, "hands": [[1, 9], [10, 14]], "rows": [
				"..44..............",
				"..45..............",
				"...cC.............",
				"....cCcVkkVc......",
				"......cCCCCcc.....",
				"......cCCCCc87....",
				"......UUuuUU87....",
				"......TT..TT......",
				"......tt..TT......",
				"......BB..BB......",
			]},
			{"bob": 0, "top": 8, "neck": 11, "hips": 14, "hands": [[0, 9], [10, 14]], "rows": [
				".44...............",
				".45...............",
				"..cC..............",
				"...cCCcVkkVc......",
				"......cCCCCcc.....",
				"......cCCCCc87....",
				"......UUuuUU87....",
				"......TT..TT......",
				"......tt..TT......",
				"......BB..BB......",
			]},
		],
		"se": [
			{"bob": 1, "top": 9, "neck": 12, "hips": 15, "hands": [[2, 9], [10, 13]], "rows": [
				"...44.............",
				"...45.............",
				"....cC............",
				".....cCVkkVc......",
				".......cCCC88.....",
				".......cCCC88.....",
				".......UUuUU......",
				".......TT.Tt......",
				".......KB.KB......",
			]},
			{"bob": 1, "top": 9, "neck": 12, "hips": 15, "hands": [[1, 9], [10, 13]], "rows": [
				"..44..............",
				"..45..............",
				"...cC.............",
				"....cCCVkkVc......",
				".......cCCC88.....",
				".......cCCC88.....",
				".......UUuUU......",
				".......TT.Tt......",
				".......KB.KB......",
			]},
		],
		"e": [
			{"bob": 1, "top": 9, "neck": 12, "hips": 14, "hands": [[6, 10], [6, 14]], "rows": [
				".......44.........",
				".......55.........",
				"........45........",
				"........CVk.......",
				".......cCCc.......",
				".......UUUu.......",
				".......ttt........",
				"........tTt.......",
				"........BBb.......",
			]},
			{"bob": 1, "top": 9, "neck": 12, "hips": 14, "hands": [[5, 10], [6, 14]], "rows": [
				"......44..........",
				"......55..........",
				".......455........",
				"........CVk.......",
				".......cCCc.......",
				".......UUUu.......",
				".......ttt........",
				"........tTt.......",
				"........BBb.......",
			]},
		],
		"ne": [
			{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[12, 10], [3, 14]], "rows": [
				"..............44..",
				"..............54..",
				".......VVVC..Cc...",
				"......ccccCCCc....",
				".....88VcccC......",
				".....88uuuuu......",
				".......mm.tt......",
				".......bb.BB......",
			]},
			{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[13, 10], [3, 14]], "rows": [
				"...............44.",
				"...............54.",
				".......VVVC..CCc..",
				"......ccccCCCc....",
				".....88VcccC......",
				".....88uuuuu......",
				".......mm.tt......",
				".......bb.BB......",
			]},
		],
		"n": [
			{"bob": 1, "top": 9, "neck": 12, "hips": 15, "hands": [[12, 9], [3, 14]], "rows": [
				"..............44..",
				"..............54..",
				".............Cc...",
				".....CCVVVVCCc....",
				".....CCccccC......",
				"....77CccccC......",
				"....88uuuuuu......",
				"......mm..mm......",
				"......bb..bb......",
			]},
			{"bob": 1, "top": 9, "neck": 12, "hips": 15, "hands": [[13, 9], [3, 14]], "rows": [
				"...............44.",
				"...............54.",
				"..............Cc..",
				".....CCVVVVCCCc...",
				".....CCccccC......",
				"....77CccccC......",
				"....88uuuuuu......",
				"......mm..mm......",
				"......bb..bb......",
			]},
		],
	},
}


## Frame `i` of gesture `gesture` in direction `dir`, with its rows' first column `x0`; {}
## for none.
static func frame(gesture: String, dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(gesture, {}).get(dir, [])
	if i < 0 or i >= frames.size():
		return {}
	var f: Dictionary = frames[i].duplicate()
	f.x0 = X0
	return f


## The rows of frame `f` for a body of build `build` and figure `figure` (FormsArt.body)
## drawn in direction `dir`, from column X0: the box's part made in the form, the hands out
## past its edges thinned with it.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	var wide: Array = f.rows
	if build in FormsArt.NARROW:
		wide = wide.map(_thin)
	var box: Array = wide.map(func(r: String) -> String: return r.substr(-X0, 14))
	box = FormsArt.body(box, dir, build, figure, f.neck - f.top, f.hips - f.top)
	var out := []
	for y in wide.size():
		out.append(wide[y].substr(0, -X0) + box[y] + wide[y].substr(14 - X0))
	return out


## Row `r` (from column X0) with each hand a pixel narrower where it is wider than one: the
## pixel of it farthest from the box's middle left out (FormsArt's thin build).
static func _thin(r: String) -> String:
	var middle := 6.5 - X0
	for digits: String in ["456", "789"]:
		var xs := []
		for x in r.length():
			if r[x] in digits:
				xs.append(x)
		if xs.size() > 1:
			var far: int = xs[0] if absf(xs[0] - middle) > absf(xs[-1] - middle) else xs[-1]
			r[far] = "."
	return r
