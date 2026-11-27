extends RefCounted
## The reach (a bare hand taking a thing, a thing put down, a plan built), drawn whole as
## the walk is (WalkArt): four frames for each drawn direction (PlayerArt.VIEW), the west
## ones mirrored (the hand in use with them, so there it is the left one). Upright, the
## hand lifted to the waist; the crouch (the chest's row folds away, the legs never move)
## with the arm stretched down, the hand a row over the ground; still crouched, the arm
## short again, the hand two rows over the ground with what it took; upright, the hand
## brought up to the shoulder. The arm stays against the body in every frame, no empty
## pixel between them (the user's review of 2026-11-20). Where the body stands a row lower
## (every direction but the front) the hands are as high over the ground as from the
## front, so crouched the arms are a row shorter: the one stretched two rows, a short one
## a single row.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand in use, the other]: the hand's lowest pixel next to the body, less the bob; what
## it holds goes there), `a` the way what it holds points (-1: as carried) and `f` whether
## that hand is in front of the body. Made with the review tools in the project library,
## written by tools/art/character/gen_reach_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: the hand lifted, the crouch with the arm stretched down,
## crouched with the arm short, upright with the hand at the shoulder.
const FRAMES := {
	# From the front the hand in use is at the picture's left, down along the side.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[3, 13], [10, 14]], "a": -1, "f": true, "rows": [
			"....cVkkVc....",
			"..4ccCCCCcc...",
			"..45cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[3, 15], [10, 14]], "a": -1, "f": true, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..45UUuuUU87..",
			"..45TT..TT87..",
			"..45tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[3, 14], [10, 14]], "a": -1, "f": true, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..45UUuuUU87..",
			"..45TT..TT87..",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[3, 12], [10, 14]], "a": -1, "f": true, "rows": [
			"..44cVkkVc....",
			"..45cCCCCcc...",
			"....cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	# Turned, the arm in use is the near one; the far arm ends a row higher, beside the
	# shoulders' row.
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[4, 13], [9, 13]], "a": -1, "f": true, "rows": [
			".....VkkVc....",
			"....4cCCC88...",
			"...44cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[4, 14], [9, 12]], "a": -1, "f": true, "rows": [
			".....VkkVc....",
			"....ccCCC88...",
			"...44UUuUU....",
			"...44TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[4, 13], [9, 12]], "a": -1, "f": true, "rows": [
			".....VkkVc....",
			"....ccCCC88...",
			"...44UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[4, 12], [9, 13]], "a": -1, "f": true, "rows": [
			"...44VkkVc....",
			"...44cCCC88...",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the arm goes down and forward in front of the body.
	"e": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[8, 13], [6, 14]], "a": -1, "f": true, "rows": [
			"......CVk.....",
			".....cC4c.....",
			".....UUU44....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[9, 14], [6, 14]], "a": -1, "f": true, "rows": [
			"......CVk.....",
			".....UUU4.....",
			".....ttt44....",
			"......tTt44...",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[8, 13], [6, 14]], "a": -1, "f": true, "rows": [
			"......CVk.....",
			".....UUU4.....",
			".....ttt44....",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[8, 12], [6, 14]], "a": -1, "f": true, "rows": [
			"......CVk.....",
			".....cC444....",
			".....UUU......",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind the hand in use is at the picture's right, what it holds behind the body.
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 13], [4, 14]], "a": -1, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCCC4..",
			"...88VcccC44..",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[10, 14], [4, 13]], "a": -1, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			"...88uuuuu44..",
			".....mm.tt44..",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[10, 13], [4, 13]], "a": -1, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			"...88uuuuu44..",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[9, 12], [4, 14]], "a": -1, "f": false, "rows": [
			".....VVVC44...",
			"....ccccC44...",
			"...88VcccC....",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 13], [3, 14]], "a": -1, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC4..",
			"..77CccccC55..",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[10, 14], [3, 13]], "a": -1, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"..88uuuuuu44..",
			"....mm..mm55..",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[10, 13], [3, 13]], "a": -1, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"..88uuuuuu55..",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 12], [3, 14]], "a": -1, "f": false, "rows": [
			"...CCVVVVC44..",
			"...CCccccC55..",
			"..77CccccC....",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the reach drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
