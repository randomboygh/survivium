extends RefCounted
## The jump, drawn whole under the head as the walk is (WalkArt): two frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored. Rising (the sheet's first
## jump column), the shoulders go a row up and the arms with them, the hands a row
## higher by the body's sides, and the legs are drawn up: the feet where the shins were.
## Falling (the second), the shoulders are back down and the arms go out to the sides
## (from the side forward), the hands a pixel out and a row up, the legs straight. An
## arm moves from its shoulder, right under the head: what it leaves is the torso's
## again (the user's notes of 2026-11-19, variant 3 of the review).
##
## The frames are in WalkArt's form: the head's place `bob` (the stand's `drop`), the
## waistband's row `hips`, the hands' places `hands` ([right, left], the hand's lowest
## pixel next to the body, less the bob: where what they hold goes) and `rows`, rows
## 10-17 of the box in the letters of PlayerArt.INK with the hands' skin in the digits of
## WalkArt.HANDS, empty where the head is.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: rising, falling.
const FRAMES := {
	"s": [
		{"bob": 0, "hips": 14, "hands": [[3, 13], [10, 13]], "rows": [
			"..............",
			"...ccVkkVcc...",
			"..45CCCCCC87..",
			"..45cCCCCc87..",
			"....UUuuUU....",
			"....TT..TT....",
			"....BB..BB....",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[2, 13], [11, 13]], "rows": [
			"..............",
			"....cVkkVc....",
			".45ccCCCCcc87.",
			".45.cCCCCc.87.",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	# Turned a little the far hand is short and high by the body's side, at the neck
	# when the shoulders go up.
	"se": [
		{"bob": 1, "hips": 15, "hands": [[4, 13], [9, 12]], "rows": [
			"..............",
			"..............",
			"....cVkkV88...",
			"...44CCCC88...",
			"...44cCCC.....",
			".....UUuUU....",
			".....KB.KB....",
			"..............",
		]},
		{"bob": 1, "hips": 15, "hands": [[3, 13], [10, 12]], "rows": [
			"..............",
			"..............",
			".....VkkVc88..",
			"..44ccCCC.88..",
			"..44.cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the shoulder is under the head: the near arm goes up along the body,
	# then forward; the far one is behind the body.
	"e": [
		{"bob": 1, "hips": 14, "hands": [[7, 13], [6, 13]], "rows": [
			"..............",
			"..............",
			"......CVk.....",
			".....cC44.....",
			".....UU44.....",
			".....ttt......",
			"......BBb.....",
			"..............",
		]},
		{"bob": 1, "hips": 14, "hands": [[8, 13], [7, 13]], "rows": [
			"..............",
			"..............",
			"......CVk.....",
			".....cCC44....",
			".....UUU44....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	"ne": [
		{"bob": 1, "hips": 15, "hands": [[10, 13], [4, 13]], "rows": [
			"..............",
			"..............",
			"....cVVVCCC...",
			"...88cccCC44..",
			"...88VcccC44..",
			".....uuuuu....",
			".....bb.BB....",
			"..............",
		]},
		{"bob": 1, "hips": 15, "hands": [[11, 13], [3, 13]], "rows": [
			"..............",
			"..............",
			".....VVVC.....",
			"..88ccccCCC44.",
			"..88.VcccC.44.",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	# From behind the shoulders go up beside the head (only there: the head is over the
	# rest of that row).
	"n": [
		{"bob": 1, "hips": 15, "hands": [[10, 13], [3, 13]], "rows": [
			"..............",
			"...C......C...",
			"...CCVVVVCC...",
			"..77CccccC44..",
			"..88CccccC55..",
			"....uuuuuu....",
			"....bb..bb....",
			"..............",
		]},
		{"bob": 1, "hips": 15, "hands": [[11, 13], [2, 13]], "rows": [
			"..............",
			"..............",
			"...CCVVVVCC...",
			".77CCccccCC44.",
			".88.CccccC.55.",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the jump drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from its first row drawn: shoulders raised
## over the neck go out with a stocky body's.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	var top := 0
	while top < f.rows.size() - 1 and f.rows[top].replace(".", "") == "":
		top += 1
	return FormsArt.body(f.rows, dir, build, figure, top, f.hips - 10)
