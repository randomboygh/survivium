extends RefCounted
## The dig, drawn whole as the walk is (WalkArt), the shovel held: four frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored (the shovel with them, so there
## it is in the left hand). The hand holds the shaft halfway, the end of the shaft behind
## it: three frames of the blade going into the earth from the feet's level, a pixel
## deeper each (crouched on the third: the chest's row folds away, the legs never move),
## then the toss (upright, the blade up and forward).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand holding the shovel: its grip, the other: its lowest pixel next to the body], less
## the bob) and how the shovel is held: `a` the way it points (PlayerArt.WORKS), `slide`
## how far up its length the hand holds it (ToolArt.turned), `ccw` its edge the other way,
## `f` in front of the body. Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_dig_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: the blade at the feet's level, a pixel deeper, two
## deeper (crouched), the toss.
const FRAMES := {
	# From the front the shovel is at the right side (the picture's left), the blade at the
	# viewer (PlayerArt.TOWARD), beside the feet with the outline between.
	"s": [
		{"bob": 0, "top": 10, "neck": 11, "hips": 14, "hands": [[0, 13], [10, 14]], "a": 8, "slide": 3, "f": true, "rows": [
			"..............",
			"...ccVkkVc....",
			"..4cCCCCCcc...",
			"44.cCCCCc87...",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 10, "neck": 11, "hips": 14, "hands": [[0, 14], [10, 14]], "a": 8, "slide": 3, "f": true, "rows": [
			"..............",
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..4.cCCCCc87..",
			"44..UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 14, "hands": [[0, 14], [10, 13]], "a": 8, "slide": 3, "f": true, "rows": [
			"..............",
			"..............",
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..4.UUuuUU87..",
			"44..TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 10, "neck": 11, "hips": 14, "hands": [[2, 12], [9, 13]], "a": 7, "slide": 4, "f": false, "rows": [
			"..............",
			"...4cVkkVc....",
			"..45CCCCCcc...",
			"...ccCCCC87...",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 12], [9, 13]], "a": 3, "slide": 6, "f": true, "rows": [
			".....VkkVc....",
			"....ccCCC444..",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 13], [9, 13]], "a": 3, "slide": 6, "f": true, "rows": [
			"......VkkVc...",
			".....ccCCC....",
			".....cCCC444..",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[11, 13], [9, 13]], "a": 3, "slide": 6, "f": true, "rows": [
			".....VkkVc....",
			"....ccCCC.....",
			".....UUuUU444.",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 11], [10, 12]], "a": 1, "slide": 4, "f": false, "rows": [
			".....VkkVc....",
			"....ccCC4488..",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side, the turned views and from behind the blade goes in by the right foot,
	# down and forward; from behind the shovel is behind the body.
	"e": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 12], [6, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			"......CVk.....",
			".....cC4444...",
			".....UUU......",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 13], [6, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			".......CVk....",
			"......cC4.....",
			".....UUU444...",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[10, 13], [6, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			"......CVk.....",
			".....UUU44....",
			".....ttt.444..",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[11, 10], [6, 14]], "a": 1, "slide": 4, "f": false, "rows": [
			"..............",
			"......CVk.44..",
			".....cC444....",
			".....UUU......",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 12], [3, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCC44..",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 13], [3, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCC....",
			".....VcccC44..",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[11, 13], [3, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCC....",
			".....uuuuu44..",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[12, 10], [9, 11]], "a": 1, "slide": 4, "f": false, "rows": [
			"..............",
			"...........44.",
			".....VVVC884..",
			"....ccccCC....",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 12], [3, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC44.",
			"....CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 13], [3, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"....CccccC44..",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[11, 13], [3, 14]], "a": 3, "slide": 6, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"....uuuuuu44..",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[12, 10], [9, 12]], "a": 1, "slide": 4, "f": false, "rows": [
			"..............",
			"...........44.",
			"...CCVVVVC.4..",
			"...CCcccc774..",
			"....CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the dig drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
