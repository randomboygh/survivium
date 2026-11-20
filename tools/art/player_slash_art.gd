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
## rod out fishing is held as in the second frame (Player.ROD_OUT).
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
	# Turned, as from the front.
	"se": [
		{"bob": 0, "top": 8, "neck": 11, "hips": 15, "hands": [[0, 8], [9, 14]], "a": 0, "f": true, "ccw": true, "rows": [
			"44............",
			"45............",
			".45...........",
			"..45cVkkVc....",
			"....ccCCC.....",
			".....cCCC.....",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[0, 9], [9, 13]], "a": 10, "f": true, "rows": [
			"45............",
			".45...........",
			"..45cVkkVc....",
			"....ccCCC.....",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[7, 12], [9, 12]], "a": 8, "f": true, "of": false, "trail": {"at": [7, 12], "rows": [
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
		]}, "rows": [
			".....VkkVc....",
			"....c445C88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 12], [9, 13]], "a": 9, "f": true, "of": false, "rows": [
			".....VkkVc....",
			"....c45CC88...",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the arc is seen edge on: the blade upright behind the head, over and up
	# in front of the face, straight forward on the strike with its trail in front of the head,
	# then down forward.
	"e": [
		{"bob": 0, "top": 8, "neck": 11, "hips": 14, "hands": [[0, 8], [6, 14]], "a": 0, "f": true, "ccw": true, "rows": [
			"44............",
			"45............",
			".45...........",
			"..4455CVk.....",
			".....cCCc.....",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 14, "hands": [[13, 9], [6, 14]], "a": 1, "f": true, "rows": [
			"............44",
			"..........445.",
			"......CV445...",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[11, 11], [6, 14]], "a": 2, "f": true, "trail": {"at": [20, 12], "rows": [
			"--........",
			"..--......",
			"....-+....",
			".....++...",
			"......++..",
			".......++.",
			".......+o.",
			"........oo",
			"........oo",
			"........oo",
			"........oo",
			"........oo",
			".......ooo",
			"......ooo.",
			"....oooo..",
		]}, "rows": [
			"......CV4445..",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[9, 12], [6, 14]], "a": 9, "f": true, "rows": [
			"......CVk.....",
			".....cCC45....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind it is the front mirrored: up beside the head at the right side, swept down
	# it, on the strike in front of the body (hidden, its trail at the right side), then down
	# at the left, hidden but for what shows past the body.
	"ne": [
		{"bob": 0, "top": 8, "neck": 11, "hips": 15, "hands": [[13, 8], [4, 14]], "a": 0, "f": true, "rows": [
			"............44",
			"............54",
			"...........54.",
			".....VVVCc54..",
			"....ccccCCC...",
			".....VcccC....",
			"...88VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[13, 9], [4, 13]], "a": 9, "f": true, "rows": [
			"............54",
			"...........54.",
			".....VVVCc54..",
			"....ccccCCC...",
			"...88VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[8, 12], [4, 12]], "a": 8, "f": false, "trail": {"at": [20, 12], "rows": [
			".-....",
			".--...",
			"..--..",
			"...+-.",
			"...++.",
			"....++",
			"....++",
			"....o+",
			"....oo",
			"....oo",
			"....oo",
			"...oo.",
			"...oo.",
			"..oo..",
			".ooo..",
			"ooo...",
			"oo....",
		]}, "rows": [
			".....VVVC.....",
			"...88Vcc544...",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 12], [4, 12]], "a": 10, "f": false, "rows": [
			".....VVVC.....",
			"...88Vcc544...",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	"n": [
		{"bob": 0, "top": 8, "neck": 11, "hips": 15, "hands": [[13, 8], [3, 15]], "a": 0, "f": true, "rows": [
			"............44",
			"............54",
			"...........54.",
			"...CCVVVVCC54.",
			"...CCccccCC...",
			"....CccccC....",
			"..78CccccC....",
			"..78uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 10, "neck": 12, "hips": 15, "hands": [[13, 9], [3, 14]], "a": 9, "f": true, "rows": [
			"............54",
			"...........54.",
			"...CCVVVVCC54.",
			"...CCccccCC...",
			"..78CccccC....",
			"..78uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[7, 12], [3, 13]], "a": 8, "f": false, "trail": {"at": [20, 12], "rows": [
			".-....",
			".--...",
			"..--..",
			"...+-.",
			"...++.",
			"....++",
			"....++",
			"....o+",
			"....oo",
			"....oo",
			"....oo",
			"...oo.",
			"...oo.",
			"..oo..",
			".ooo..",
			"ooo...",
			"oo....",
		]}, "rows": [
			"...CCVVVVCC...",
			"..78Ccc544c...",
			"..78uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 12], [3, 13]], "a": 10, "f": false, "rows": [
			"...CCVVVVCC...",
			"..78Ccc544c...",
			"..78CccccC....",
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
