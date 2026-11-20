extends RefCounted
## The slash, drawn whole as the walk is (WalkArt), a blade held in one hand: four frames
## for each drawn direction (PlayerArt.VIEW), the west ones mirrored (the blade with them,
## so there it is in the left hand). After Puny Characters (Shade, CC0) and the user's
## review (2026-11-20) the blade goes along an arc: raised upright beside the head; swept
## down that side, pointing out and down; the strike (crouched: the chest's row folds away,
## the legs never move), the blade at the bottom of the arc in front of the body with its
## trail behind it; stopped at the other side, about 30 degrees to the ground. The hand
## holding it stays on its own side of the body. The blow lands on the third frame, as in
## the other works. The swords, knives, spears, sickles, slings, bows and rods play it; a
## rod out fishing is held out as in the strike (Player.ROD_OUT).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand holding the blade: its grip, the other: its lowest pixel next to the body], less
## the bob) and how the blade is held: `a` the way it points (PlayerArt.WORKS; 8 is
## PlayerArt.TOWARD, at the viewer, 9 and 10 PlayerArt.LOW and LOW_LEFT, about 30 degrees
## down), `ccw` its edge the other way, `f` in front of the body, `of` false: the other hand
## behind the blade, which comes across in front of it; `trail` the trail a blade leaves
## (PlayerArt.INK o, +, -: rows of the frame's pixels from `at`), which the game draws over
## the figure and its outline for an item with `trail` (Figure). Made with the review tools
## in the project library (survivium-builds/character/anim/src/gen_slash_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: raised, swept down, the strike (crouched), stopped.
const FRAMES := {
	# From the front the blade is raised beside the head at the right side (the picture's left),
	# swept down that side, at the viewer between the legs on the strike with its trail behind it,
	# then down at the other side; the hand stays left of the belly's middle.
	"s": [
		{"bob": -1, "top": 7, "neck": 10, "hips": 14, "hands": [[0, 8], [10, 15]], "a": 0, "f": true, "ccw": true, "rows": [
			"44............",
			"45............",
			".45...........",
			"..45cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 9, "neck": 11, "hips": 14, "hands": [[0, 9], [10, 14]], "a": 10, "f": true, "rows": [
			"45............",
			".45...........",
			"..45cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[6, 12], [10, 13]], "a": 8, "f": true, "of": false, "trail": {"at": [6, 11], "rows": [
			"....-...",
			"...--...",
			"..--....",
			".-+.....",
			".++.....",
			"++......",
			"++......",
			"+o......",
			"oo......",
			"oo......",
			"oo......",
			".oo.....",
			".oo.....",
			"..oo....",
			"..ooo...",
			"...ooo..",
			"....oo..",
			".....oo.",
			"......oo",
			".......o",
		]}, "rows": [
			"....cVkkVc....",
			"...c445CCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 13], [10, 13]], "a": 9, "f": true, "of": false, "rows": [
			"....cVkkVc....",
			"...ccCCCCc87..",
			"...c445CCc87..",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[1, 12], [8, 13]], "a": 6, "f": true, "rows": [
			"....VkkVc.....",
			"444ccCCC......",
			"55..cCCC88....",
			"....UUuUU.....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 15, "hands": [[1, 11], [9, 14]], "a": 7, "f": false, "rows": [
			".44..VkkVc....",
			"..45ccCCC.....",
			".....cCCC.....",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[9, 12], [9, 13]], "a": 1, "f": true, "rows": [
			".....VkkVc....",
			"....c44445....",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[10, 11], [10, 13]], "a": 9, "f": true, "of": false, "rows": [
			".....VkkVc45..",
			"....c4444C....",
			".....UUuUU88..",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the arm draws the blade back up behind the head, swings it up in front
	# and down forward.
	"e": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[3, 12], [6, 14]], "a": 6, "f": true, "rows": [
			"......CVk.....",
			"...4444Cc.....",
			"...55UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[3, 11], [6, 14]], "a": 7, "f": true, "rows": [
			"...44.CVk.....",
			"....45CCc.....",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 12], [6, 14]], "a": 1, "f": true, "rows": [
			"......CVk.....",
			".....cC4445...",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[11, 11], [6, 14]], "a": 9, "f": true, "rows": [
			"......CV4445..",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind it is mirrored: up at the right side, then over to the left and down, in
	# front of the body, hidden but for what shows past it.
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 12], [5, 13]], "a": 2, "f": true, "rows": [
			"......VVVC....",
			"....88cccCCC44",
			"....88VcccC.55",
			"......uuuuu...",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 15, "hands": [[12, 11], [4, 14]], "a": 1, "f": true, "rows": [
			".....VVVC...44",
			"....ccccCCC45.",
			"...88cccCCC...",
			"...88VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[4, 11], [4, 13]], "a": 7, "f": false, "rows": [
			".....VVVC.....",
			"...88cccCCC...",
			"...88VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[4, 11], [4, 13]], "a": 10, "f": false, "rows": [
			".....VVVC.....",
			"...88cccCCC...",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 12], [4, 13]], "a": 2, "f": true, "rows": [
			"....CCVVVVCC..",
			"...77CccccCC44",
			"...88CccccC.55",
			".....uuuuuu...",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 15, "hands": [[12, 11], [3, 14]], "a": 1, "f": true, "rows": [
			"...CCVVVVCC.44",
			"...CCccccCC45.",
			"..77CccccCC...",
			"..88CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[3, 11], [3, 13]], "a": 7, "f": false, "rows": [
			"...CCVVVVCC...",
			"..77CccccCC...",
			"..88CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[4, 11], [3, 13]], "a": 10, "f": false, "rows": [
			"...CCVVVVCC...",
			"..77CccccCC...",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the slash drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
