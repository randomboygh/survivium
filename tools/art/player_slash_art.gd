extends RefCounted
## The slash, drawn whole as the walk is (WalkArt), a blade held in one hand: four frames
## for each drawn direction (PlayerArt.VIEW), the west ones mirrored (the blade with them,
## so there it is in the left hand). A sweep from the side, the same in every direction:
## the arm out to the working side, the blade pointing out (the torso turned toward it,
## from the side only the arm goes back); drawn back and up (the body a row taller); the
## strike, the blade swept across the front toward the work (crouched: the chest's row
## folds away, the legs never move); upright, the blade swept through and down on the
## other side, about 30 degrees to the ground. The swords, knives, spears, sickles,
## slings, bows and rods play it; a rod out fishing stands on the strike's frame.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand holding the blade: its grip, the other: its lowest pixel next to the body], less
## the bob) and how the blade is held: `a` the way it points (PlayerArt.WORKS; 9 and 10
## are PlayerArt.LOW and LOW_LEFT, about 30 degrees down), `ccw` its edge the other way,
## `f` in front of the body, `of` false: the other hand behind the body, the blade swept
## across in front of it. Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_slash_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: out to the side, drawn back, the strike (crouched), the
## follow-through.
const FRAMES := {
	# From the front and turned toward the viewer the blade sweeps from the right side
	# (the picture's left) across the body to the left and down.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[1, 12], [9, 14]], "a": 6, "f": true, "rows": [
			"...cVkkVc.....",
			"44ccCCCCcc....",
			"55.cCCCCc87...",
			"...UUuuUU87...",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": -1, "top": 10, "neck": 10, "hips": 14, "hands": [[0, 11], [10, 15]], "a": 7, "f": false, "rows": [
			"44..cVkkVc....",
			".45ccCCCCcc...",
			"....cCCCCc....",
			"....cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[6, 12], [10, 14]], "a": 2, "f": true, "of": false, "rows": [
			"....cVkkVc....",
			"...c4445Ccc...",
			"....UUuuUU87..",
			"....TT..TT87..",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[7, 12], [10, 14]], "a": 9, "f": true, "of": false, "rows": [
			"....cVkkVc....",
			"...c4445Ccc...",
			"....cCCCCc87..",
			"....UUuuUU87..",
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[7, 12], [10, 13]], "a": 2, "f": true, "of": false, "rows": [
			".....VkkVc....",
			"....c4445C....",
			".....UUuUU88..",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 12], [9, 13]], "a": 9, "f": true, "of": false, "rows": [
			".....VkkVc....",
			"....c4445.....",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the arm draws the blade back behind the body, sweeps it forward and
	# down.
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[10, 12], [6, 14]], "a": 2, "f": true, "rows": [
			"......CVk.....",
			".....UU4444...",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 12], [6, 14]], "a": 9, "f": true, "rows": [
			"......CVk.....",
			".....cC444....",
			".....UUU55....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind the sweep is mirrored: out to the right side, up, then across behind the
	# body to the left and down.
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[6, 12], [4, 13]], "a": 6, "f": false, "rows": [
			".....VVVC.....",
			"...88cccCCC...",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[5, 11], [4, 13]], "a": 10, "f": false, "rows": [
			".....VVVC.....",
			"...88cccCCC...",
			"...88VcccC....",
			".....uuuuu....",
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[5, 12], [3, 13]], "a": 6, "f": false, "rows": [
			"...CCVVVVCC...",
			"..77CccccCC...",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[4, 11], [3, 13]], "a": 10, "f": false, "rows": [
			"...CCVVVVCC...",
			"..77CccccCC...",
			"..88CccccC....",
			"....uuuuuu....",
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
