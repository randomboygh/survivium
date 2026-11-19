extends RefCounted
## The swim, drawn whole under the head as the walk is (WalkArt): four frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored; a breaststroke (variant A of
## the review of 2026-11-19). The water comes up to the chin (Body.SWIM_DEPTH), so the
## whole stroke is under it, the body showing through tinted: the hands come together in
## front of the chest, the arms sweep out from the shoulders, pull down by the sides and
## come back up; the legs glide together, kick apart and draw up. An arm moves from its
## shoulder, right under the head. Afloat the head is as high in every direction (`bob`
## 0, no stand `drop`), so the eyes stay over the water.
##
## The frames are in WalkArt's form: the head's place `bob`, the waistband's row `hips`,
## the hands' places `hands` ([right, left], the hand's lowest pixel next to the body:
## where what they hold goes) and `rows`, rows 10-17 of the box in the letters of
## PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS, empty where the
## head is.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: reach in, sweep out, pull down, recover.
const FRAMES := {
	"s": [
		{"bob": 0, "hips": 14, "hands": [[6, 13], [7, 13]], "rows": [
			"..............",
			"...ccVkkVcc...",
			"...cC4477Cc...",
			"....c5588c....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..tt....",
			"....BB..BB....",
		]},
		{"bob": 0, "hips": 14, "hands": [[2, 13], [11, 13]], "rows": [
			"..............",
			"....cVkkVc....",
			".45ccCCCCcc87.",
			".45.cCCCCc.87.",
			"....UUuuUU....",
			"...TT....TT...",
			"...tt....tt...",
			"...BB....BB...",
		]},
		{"bob": 0, "hips": 14, "hands": [[3, 14], [10, 14]], "rows": [
			"..............",
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..45cCCCCc87..",
			"..45UUuuUU87..",
			"...TT....TT...",
			"...BB....BB...",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[4, 13], [9, 13]], "rows": [
			"..............",
			"...ccVkkVcc...",
			"...44CCCC77...",
			"...55cCCc88...",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..tt....",
			"....BB..BB....",
		]},
	],
	# Turned a little the far arm reaches out short, behind the body when it pulls.
	"se": [
		{"bob": 0, "hips": 14, "hands": [[5, 13], [8, 13]], "rows": [
			"..............",
			".....VkkVc....",
			"....44CC77....",
			"....55cC88....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[3, 13], [10, 12]], "rows": [
			"..............",
			".....VkkVc88..",
			"..44ccCCC.88..",
			"..44.cCCC.....",
			".....UUuUU....",
			"....TT...Tt...",
			"....KB...KB...",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[4, 14], [9, 13]], "rows": [
			"..............",
			".....VkkVc....",
			"....ccCCC88...",
			"...44cCCC88...",
			"...44UUuUU....",
			"....KB...KB...",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[5, 13], [9, 13]], "rows": [
			"..............",
			".....VkkVc....",
			"....44CCC77...",
			"....55cCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
			"..............",
		]},
	],
	# From the side the near arm reaches forward, sweeps back from the shoulder, pulls
	# down past the hip and comes up under the chin; the far one is behind the body. The
	# body leans back from the waist on a diagonal, the legs short and thick with it,
	# kicking in their colours (the near leg light, the far one dark, changing places) and
	# drawn up a pixel as the arms pull.
	"e": [
		{"bob": 0, "hips": 13, "hands": [[8, 13], [6, 14]], "rows": [
			"..............",
			"......CVk.....",
			".....cCC444...",
			"...uUUu.555...",
			"...TTm........",
			"..BBb.........",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 13, "hands": [[7, 13], [6, 14]], "rows": [
			"..............",
			"......CVk.....",
			".....cC44.....",
			"...uUUu44.....",
			"...tTm........",
			"..bBb.........",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 13, "hands": [[3, 13], [6, 14]], "rows": [
			"..............",
			"......CVk.....",
			"....44CCc.....",
			"..44UUu.......",
			"...mTT........",
			"...bBB........",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 13, "hands": [[8, 12], [6, 14]], "rows": [
			"..............",
			"......CV44....",
			".....cCC44....",
			"...uUUu.......",
			"...mTt........",
			"..bBb.........",
			"..............",
			"..............",
		]},
	],
	"ne": [
		{"bob": 0, "hips": 14, "hands": [[10, 14], [3, 14]], "rows": [
			"..............",
			"....cVVVCC....",
			"....ccccCCC...",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[11, 13], [3, 13]], "rows": [
			"..............",
			".....VVVC.....",
			"..88ccccCCC44.",
			"..88.VcccC.44.",
			".....uuuuu....",
			"....mm...tt...",
			"....bb...BB...",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[10, 14], [4, 14]], "rows": [
			"..............",
			".....VVVC.....",
			"....ccccCCC...",
			"...88VcccC44..",
			"...88uuuuu44..",
			"....bb...BB...",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[10, 12], [4, 12]], "rows": [
			"..............",
			"....8VVVC4....",
			"....8cccCC4...",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
			"..............",
		]},
	],
	# From behind the shoulders go up beside the head as the hands reach forward.
	"n": [
		{"bob": 0, "hips": 14, "hands": [[10, 14], [3, 14]], "rows": [
			"...C......C...",
			"...CCVVVVCC...",
			"...CCccccCC...",
			"....CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[11, 13], [2, 13]], "rows": [
			"..............",
			"...CCVVVVCC...",
			".77CCccccCC44.",
			".88.CccccC.55.",
			"....uuuuuu....",
			"...mm....mm...",
			"...bb....bb...",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[10, 14], [3, 14]], "rows": [
			"..............",
			"...CCVVVVCC...",
			"..77CccccC44..",
			"..77CccccC44..",
			"..88uuuuuu55..",
			"...bb....bb...",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[11, 12], [2, 12]], "rows": [
			"..............",
			"..7CCVVVVCC4..",
			"..8CCccccCC5..",
			"....CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
			"..............",
		]},
	],
}


## Frame `i` of the swim drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from its first row drawn.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	var top := 0
	while top < f.rows.size() - 1 and f.rows[top].replace(".", "") == "":
		top += 1
	return FormsArt.body(f.rows, dir, build, figure, top, f.hips - 10)
