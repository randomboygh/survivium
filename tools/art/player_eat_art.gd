extends RefCounted
## The eat, drawn whole as the walk is (WalkArt), the food in one hand: four frames for
## each drawn direction (PlayerArt.VIEW), the west ones mirrored (the food with them, so
## there it is in the left hand). After the user's review (2026-11-20): the food lifted to
## the belly, the elbow by the side; raised to the chin, the hand beside it; the bite, a
## nod: the head a row down onto the food, which stays where it was, the eyes shut (the
## chest's row folds away, the legs never move); lowered again, chewing with the eyes
## shut. The bite is on the third frame, as the blow of the other works. Turned and from
## the side the food is before the face; from behind the body hides it, the elbow and
## the nod show the bite. What is eaten or drunk plays it (an item's `anim`).
##
## The food is the thing in the hand as it is carried, an icon cut down to a few pixels
## (Figure.icon_turns), its middle at the hand's place and the hand's skin drawn over it:
## so the hand is drawn beside the food, not across it. An icon is not mirrored with the
## figure and one of an even width has its middle a pixel left, so in a west direction it
## sits a pixel further from the body than in its east one: the frames are drawn to hold
## it both ways.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand with the food: where the food's middle goes, the other: its lowest pixel next to
## the body], less the bob), `a` -1: the food as it is carried, `f` in front of the body,
## `of` false: the other hand behind the food, `eyes` "shut". Made with the review tools
## in the project library, written by tools/art/character/gen_eat_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: to the belly, to the chin, the bite (a nod), down again.
const FRAMES := {
	# From the front: the food to the belly, the arm a row shorter; up to the chin, the hand by it
	# at the chest's height over the elbow; the head down onto it; down again.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 13], [10, 14]], "a": -1, "f": true, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..45cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[7, 12], [10, 14]], "a": -1, "f": true, "rows": [
			"....cVkkVc....",
			"...44CCCCcc...",
			"..55cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[7, 11], [10, 13]], "a": -1, "f": true, "eyes": "shut", "rows": [
			"...44VkkVc....",
			"..55cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 13], [10, 14]], "a": -1, "f": true, "eyes": "shut", "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..45cCCCCc87..",
			"....UUuuUU87..",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	# Turned, as from the front: the food before the face's middle, the other arm behind it.
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 13], [9, 13]], "a": -1, "f": true, "of": false, "rows": [
			".....VkkVc....",
			"....ccCCC88...",
			"...44cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 12], [9, 13]], "a": -1, "f": true, "of": false, "rows": [
			".....VkkVc....",
			"....c44CC88...",
			"...55cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[8, 11], [9, 12]], "a": -1, "f": true, "of": false, "eyes": "shut", "rows": [
			".....44kVc....",
			"...55cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 13], [9, 13]], "a": -1, "f": true, "of": false, "eyes": "shut", "rows": [
			".....VkkVc....",
			"....ccCCC88...",
			"...44cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the food is held against the belly, then before the chin, the hand under the
	# chin reaching a pixel into it (the west twin's food sits a pixel further out).
	"e": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 13], [6, 14]], "a": -1, "f": true, "rows": [
			"......CVk.....",
			".....cCCc.....",
			".....UU44.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[12, 12], [6, 14]], "a": -1, "f": true, "rows": [
			"......CVk444..",
			".....cCC444...",
			".....UU55.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 12, "neck": 13, "hips": 14, "hands": [[12, 11], [6, 14]], "a": -1, "f": true, "eyes": "shut", "rows": [
			"...........4..",
			"......CV444...",
			".....UU55.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[10, 13], [6, 14]], "a": -1, "f": true, "eyes": "shut", "rows": [
			"......CVk.....",
			".....cCCc.....",
			".....UU44.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind the body hides the food but for its edge past the neck: the arm a row shorter,
	# then its elbow up at the shoulder.
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 12], [4, 14]], "a": -1, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			"...88VcccC44..",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[11, 11], [4, 14]], "a": -1, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCC44..",
			"...88VcccC55..",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[11, 10], [4, 13]], "a": -1, "f": false, "eyes": "shut", "rows": [
			".....VVVCC44..",
			"...88VcccC55..",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 12], [4, 14]], "a": -1, "f": false, "eyes": "shut", "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			"...88VcccC44..",
			"...88uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	# From the back the food is hidden: the elbow out at the shoulder and the nod show the bite.
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 12], [3, 14]], "a": -1, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"..77CccccC44..",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 11], [3, 14]], "a": -1, "f": false, "rows": [
			"...CCVVVVCC...",
			"...CCccccC44..",
			"..77CccccC....",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[7, 10], [3, 13]], "a": -1, "f": false, "eyes": "shut", "rows": [
			"...CCVVVVC44..",
			"..77CccccC....",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 12], [3, 14]], "a": -1, "f": false, "eyes": "shut", "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"..77CccccC44..",
			"..88uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the eat drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
