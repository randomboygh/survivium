extends RefCounted
## The chop, drawn whole as the walk is (WalkArt), the axe held: four frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored (the axe with them, so there
## it is in the left hand). The arm moves from the shoulder, right under the head, and
## stays in sight: the wind-up (the shoulder up, the hand by the ear, the axe back over
## it, the torso turned a pixel toward it), the top (the body stretched a row up, the axe
## up), the strike (the body crouched a pixel, the axe forward and down) and the
## follow-through (upright again, the hand in front of the chest).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top`
## (rows over the neck, `neck`, hold only the raised arm, beside the head) in the
## letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS, the
## waistband's row `hips`, the hands' places `hands` ([the hand holding the axe: its grip,
## the other: its lowest pixel next to the body], less the bob) and how the axe is held:
## `a` the way it points (PlayerArt.WORKS), `ccw` its edge the other way, `f` in front of
## the body. Made with the review tools in the project library,
## written by tools/art/character/gen_chop_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: wind-up, top, strike, follow-through.
const FRAMES := {
	# From the front the axe comes down at the viewer, short (PlayerArt.TOWARD).
	"s": [
		{"bob": 0, "top": 10, "neck": 11, "hips": 14, "hands": [[2, 10], [9, 14]], "a": 7, "f": false, "rows": [
			"..44..........",
			".55cVkkVc.....",
			"..5cCCCCcc....",
			"...cCCCCc87...",
			"...UUuuUU87...",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
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
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[5, 12], [10, 14]], "a": 8, "f": true, "rows": [
			"..............",
			"..............",
			"....cVkkVc....",
			"...c445CCcc...",
			"....cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 10, "neck": 11, "hips": 14, "hands": [[5, 12], [10, 14]], "a": 8, "f": true, "rows": [
			"..............",
			"....cVkkVc....",
			"...c445CCcc...",
			"....cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	"se": [
		{"bob": 1, "top": 11, "neck": 12, "hips": 15, "hands": [[3, 10], [8, 13]], "a": 7, "f": false, "rows": [
			"...44.........",
			"..55VkkVc.....",
			"...5cCCC88....",
			"....cCCC88....",
			"....UUuUU.....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 0, "top": 8, "neck": 11, "hips": 15, "hands": [[1, 8], [9, 14]], "a": 0, "f": true, "ccw": true, "rows": [
			".44...........",
			".45...........",
			"..45..........",
			"...45VkkVc....",
			"....ccCCC.....",
			"....ccCCC88...",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 16, "hands": [[6, 11], [9, 13]], "a": 8, "f": true, "rows": [
			"....c445Vc....",
			".....cCCC88...",
			".....cCCC88...",
			".....UUuUU....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 12], [9, 13]], "a": 8, "f": true, "rows": [
			".....VkkVc....",
			"....c445C88...",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the near arm lifts the axe back past the head, up behind it, and
	# swings it forward and down; the far arm is hidden behind the body.
	"e": [
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[4, 10], [6, 14]], "a": 7, "f": true, "rows": [
			"...44.........",
			"..455CVk......",
			"....c5Cc......",
			"....UUUu......",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[4, 11], [6, 14]], "a": 0, "f": true, "rows": [
			"....44CVk.....",
			".....c55c.....",
			".....c55c.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[10, 12], [6, 14]], "a": 2, "f": true, "rows": [
			"......CVk.....",
			".....cC444....",
			".....UUU55....",
			".....ttt......",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 12], [6, 14]], "a": 1, "f": true, "rows": [
			"......CVk.....",
			".....cC4444...",
			".....UUU55....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind the axe is raised over the right shoulder and swung down away from the
	# viewer, behind the body.
	"ne": [
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[12, 9], [5, 13]], "a": 1, "f": true, "rows": [
			"............44",
			"...........44.",
			"......VVVCC44.",
			"....88cccCC...",
			"....88VcccC...",
			"......uuuuu...",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 0, "top": 7, "neck": 11, "hips": 15, "hands": [[13, 7], [4, 14]], "a": 0, "f": true, "rows": [
			".............4",
			"............44",
			"............54",
			"...........54.",
			".....VVVCC54..",
			".....cccCCC...",
			"...88cccCCC...",
			"...88VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 16, "hands": [[10, 14], [4, 13]], "a": 0, "f": false, "rows": [
			".....VVVC.....",
			"...88cccCCC...",
			"...88VcccC44..",
			".....uuuu44...",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 12], [4, 13]], "a": 1, "f": false, "rows": [
			".....VVVC.....",
			"...88cccCC44..",
			"...88VcccC55..",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	"n": [
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[12, 9], [4, 13]], "a": 1, "f": true, "rows": [
			"............44",
			"...........44.",
			"....CCVVVVC44.",
			"...77CccccCC..",
			"...88CccccC...",
			".....uuuuuu...",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 0, "top": 7, "neck": 11, "hips": 15, "hands": [[13, 7], [3, 14]], "a": 0, "f": true, "rows": [
			".............4",
			"............44",
			"............54",
			"...........54.",
			"...CCVVVVC54..",
			"....CccccCC...",
			"..77CccccCC...",
			"..88CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 16, "hands": [[8, 13], [3, 14]], "a": 0, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"..77CccccC4...",
			"..88uuuuuu5...",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 13], [3, 14]], "a": 0, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"..77CccccC4...",
			"..88uuuuuu5...",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the chop drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
