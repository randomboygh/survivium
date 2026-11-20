extends RefCounted
## The slash, drawn whole as the walk is (WalkArt), a blade held in one hand: four frames
## for each drawn direction (PlayerArt.VIEW), the west ones mirrored (the blade with them,
## so there it is in the left hand). After Puny Characters (Shade, CC0) and the user's
## review (2026-11-20): the sword up beside the head at the shoulders, then raised higher;
## the swing along an arc down that side and under to the other (crouched: the chest's row
## folds away, the legs never move), the blade about 30 degrees to the ground, its trail
## along the whole arc; then standing up again, the blade where it stopped. The hand
## holding it stays on its own side of the body. From the side it is the front's swing
## too (behind the head, down behind and under to the blade in front); from behind the
## front mirrored, the blade and its trail hidden behind the body. The blow lands on the
## third frame, as in the other works. The swords, knives, spears, sickles, slings, bows
## and rods play it; a rod out fishing is held as in the last frame (Player.ROD_OUT).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand holding the blade: its grip, the other: its lowest pixel next to the body], less
## the bob) and how the blade is held: `a` the way it points (PlayerArt.WORKS; 8 is
## PlayerArt.TOWARD, at the viewer, 9 and 10 PlayerArt.LOW and LOW_LEFT, about 30 degrees
## down), `ccw` its edge the other way, `f` in front of the body, `of` false: the other hand
## behind the blade, which comes across in front of it; `trail` the trail a blade leaves
## (PlayerArt.INK o, +, -: rows of the frame's pixels from `at`), which the game draws for an
## item with `trail` over the figure and its outline, or behind them where the blade is
## behind the body (`f` false) (Figure). Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_slash_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: up at the shoulders, higher, the swing (crouched), standing.
const FRAMES := {
	# From the front the sword is up beside the head at the right side (the picture's left), at
	# the shoulders, then higher; the swing goes down that side and under to the other, its trail
	# along the whole arc, the blade about 30 degrees down; the hand stays left of the belly's middle.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[0, 11], [10, 14]], "a": 0, "f": true, "ccw": true, "rows": [
			"44..cVkkVc....",
			".455cCCCCcc...",
			"....cCCCCc87..",
			"....UUuuUU87..",
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
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[6, 12], [10, 13]], "a": 9, "f": true, "of": false, "trail": {"at": [6, 11], "rows": [
			"....-........",
			"...--........",
			"..--.........",
			".-+..........",
			".++..........",
			"++...........",
			"++...........",
			"+o...........",
			"oo...........",
			"oo...........",
			"oo...........",
			".oo..........",
			".oo..........",
			"..oo.........",
			"..ooo........",
			"...ooo.......",
			"....ooo......",
			".....oooo....",
			"......ooooo..",
			"........ooooo",
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
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[0, 11], [9, 13]], "a": 0, "f": true, "ccw": true, "rows": [
			"44...VkkVc....",
			".455ccCCC.....",
			".....cCCC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[6, 12], [9, 12]], "a": 9, "f": true, "of": false, "trail": {"at": [7, 12], "rows": [
			"....-......",
			"...--......",
			"..--.......",
			".-+........",
			".++........",
			"++.........",
			"++.........",
			"+o.........",
			"oo.........",
			"oo.........",
			"oo.........",
			".oo........",
			".oo........",
			"..oo.......",
			"..ooo......",
			"...ooo.....",
			"....ooo....",
			".....oooo..",
			"......ooooo",
		]}, "rows": [
			".....VkkVc....",
			"....c45CC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 13], [9, 13]], "a": 9, "f": true, "of": false, "rows": [
			".....VkkVc....",
			"....ccCCC88...",
			"....c45CC88...",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side as from the front: the sword up behind the head, at the shoulders (the hand
	# by the chin), then higher; the swing goes down behind and under to the blade forward and
	# down, its trail the front's crescent from the raised sword's tip.
	"e": [
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[1, 10], [6, 14]], "a": 0, "f": true, "ccw": true, "rows": [
			".44...........",
			"..4555CVk.....",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 0, "top": 8, "neck": 11, "hips": 14, "hands": [[1, 8], [6, 14]], "a": 0, "f": true, "ccw": true, "rows": [
			".44...........",
			".45...........",
			"..45..........",
			"...455CVk.....",
			".....cCCc.....",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[8, 11], [6, 14]], "a": 9, "f": true, "trail": {"at": [7, 12], "rows": [
			"....-......",
			"...--......",
			"..--.......",
			".-+........",
			".++........",
			"++.........",
			"++.........",
			"+o.........",
			"oo.........",
			"oo.........",
			"oo.........",
			".oo........",
			".oo........",
			"..oo.......",
			"..ooo......",
			"...ooo.....",
			"....ooo....",
			".....oooo..",
			"......ooooo",
		]}, "rows": [
			"......C45.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[8, 12], [6, 14]], "a": 9, "f": true, "rows": [
			"......CVk.....",
			".....cC45.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# From behind it is the front mirrored: up beside the head at the right side, the swing down
	# it and on in front of the body, hidden but for the tip past the left side; its trail goes
	# behind the body too.
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[13, 11], [4, 13]], "a": 0, "f": true, "rows": [
			".....VVVC...44",
			"....ccccCCC554",
			"...88VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[8, 12], [4, 12]], "a": 10, "f": false, "trail": {"at": [15, 12], "rows": [
			"......-....",
			"......--...",
			".......--..",
			"........+-.",
			"........++.",
			".........++",
			".........++",
			".........o+",
			".........oo",
			".........oo",
			".........oo",
			"........oo.",
			"........oo.",
			".......oo..",
			"......ooo..",
			".....ooo...",
			"....ooo....",
			"..oooo.....",
			"ooooo......",
		]}, "rows": [
			".....VVVC.....",
			"...88Vcc544...",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[8, 13], [4, 13]], "a": 10, "f": false, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			"...88Vcc544...",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[13, 11], [3, 14]], "a": 0, "f": true, "rows": [
			"...CCVVVVCC.44",
			"...CCccccCC554",
			"..78CccccC....",
			"..78uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
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
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[7, 12], [3, 13]], "a": 10, "f": false, "trail": {"at": [15, 12], "rows": [
			"......-....",
			"......--...",
			".......--..",
			"........+-.",
			"........++.",
			".........++",
			".........++",
			".........o+",
			".........oo",
			".........oo",
			".........oo",
			"........oo.",
			"........oo.",
			".......oo..",
			"......ooo..",
			".....ooo...",
			"....ooo....",
			"..oooo.....",
			"ooooo......",
		]}, "rows": [
			"...CCVVVVCC...",
			"..78Ccc544c...",
			"..78uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 13], [3, 13]], "a": 10, "f": false, "rows": [
			"...CCVVVVCC...",
			"..78CccccCC...",
			"..78Ccc544c...",
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
