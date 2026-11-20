extends RefCounted
## The mow (the work `mow`: a scythe in two hands), drawn whole as the walk is (WalkArt), the
## scythe drawn for each frame: four frames for each drawn direction (PlayerArt.VIEW), the west
## ones mirrored (the scythe with them). After the user's review of 2026-11-20: the blade hangs
## down from the snath's far end, which is held up for it (a frame has no room under the feet),
## the trail runs in front of the mower, and the hands hold the snath at its middle, not at its
## end (its near end comes out two pixels past them). 1 the scythe at the mower's right side,
## the blade's point at the ground; 2 its far end up, the torso after it; 3 crouched, the scythe
## at the other side, its trail along the ground between (the strike, as every work's third
## frame); 4 standing, the scythe where it stopped. The legs never move. The scythes play it.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in the
## letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck` the first
## row of the body), the waistband's row `hips`, the hands' places `hands` ([the scythe's mark:
## from the side the hand on the snath, in the other views a place above the neck, which no
## build moves (PlayerArt.pose), so that a wider body's hands slide along the snath and the
## blade stays inside the frame; the other hand: its lowest pixel next to the body], less the
## bob), `a` the way a thing other than a scythe would point (PlayerArt.WORKS), `f` the scythe
## in front of the body, `two`: the other hand is on the snath too, so it shows no thing of its
## own, `scythe` the scythe as the frame draws it (ToolArt.INK letters: rows from `at`, the
## offset of their corner from the mark), which ToolArt draws for a shape with `scythe` instead
## of turning it, and on the third frame `trail` (its rows in the frame's pixels from `at`, the
## letters o + - of PlayerArt.INK), which the game draws for an item with `trail` over the
## figure and its outline, or behind them where the scythe is behind the body (`f` false)
## (Figure). Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_mow_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: at the side, back and up, the sweep (crouched), standing.
const FRAMES := {
	# From the front the scythe is at the right side (the picture's left), its far end up and the
	# blade hanging to the ground, both hands on the snath across the belly, its near end behind
	# the forearm that crosses the chest; lifted, the torso after it; then at the other side, the
	# trail a shallow arc from where it was to the blade's point, over the feet.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 10], [6, 13]], "a": 10, "f": true, "two": true, "scythe": {"at": [-12, 1], "rows": [
			"..dw..........",
			".aq.ww........",
			"Aa....wwwwwwww",
			"Aa............",
			"A.............",
			".A............",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			".44.77888c....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 10], [6, 13]], "a": 10, "f": true, "two": true, "scythe": {"at": [-12, 0], "rows": [
			"..dw.........",
			".aq.w........",
			"Aa...w.......",
			"Aa....wwwwwww",
			"A............",
			".A...........",
		]}, "rows": [
			"...cVkkVc.....",
			"..ccCCCCcc....",
			"44.77888c.....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[7, 10], [11, 12]], "a": 9, "f": true, "two": true, "scythe": {"at": [-1, 0], "rows": [
			"..........wd..",
			"........ww.qa.",
			"wwwwwwww....aA",
			"............aA",
			".............A",
			"............A.",
		]}, "trail": {"at": [3, 28], "rows": [
			"--.....................",
			"..-++................oo",
			".....+++o........oooo..",
			".........oooooooo......",
		]}, "rows": [
			".....cVkkVc...",
			"....c44544c77.",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[7, 10], [11, 13]], "a": 9, "f": true, "two": true, "scythe": {"at": [-1, 1], "rows": [
			"..........wd..",
			"........ww.qa.",
			"wwwwwwww....aA",
			"............aA",
			".............A",
			"............A.",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"....c44544.77.",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	# Turned, as from the front.
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 10], [6, 13]], "a": 10, "f": true, "two": true, "scythe": {"at": [-12, 0], "rows": [
			"..dw...........",
			".aq.ww.........",
			"Aa....ww.......",
			"Aa......wwwwwww",
			"A..............",
			".A.............",
		]}, "rows": [
			".....VkkVc....",
			"....ccCCC.....",
			"..44.7788.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 10], [6, 13]], "a": 10, "f": true, "two": true, "scythe": {"at": [-12, -1], "rows": [
			"..dw..........",
			".aq.w.........",
			"Aa...w........",
			"Aa....w.......",
			"A......wwwwwww",
			".A............",
		]}, "rows": [
			"....VkkVc.....",
			"...ccCCC......",
			".44.7788......",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[7, 10], [11, 12]], "a": 9, "f": true, "two": true, "scythe": {"at": [-1, -1], "rows": [
			"..........wd..",
			"........ww.qa.",
			"......ww....aA",
			"wwwwww......aA",
			".............A",
			"............A.",
		]}, "trail": {"at": [3, 28], "rows": [
			"--.....................",
			"..-++................oo",
			".....+++o........oooo..",
			".........oooooooo......",
		]}, "rows": [
			"......VkkVc...",
			".....c4544.77.",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 10], [11, 13]], "a": 9, "f": true, "two": true, "scythe": {"at": [-1, 0], "rows": [
			"..........wd..",
			"........ww.qa.",
			"......ww....aA",
			"wwwwww......aA",
			".............A",
			"............A.",
		]}, "rows": [
			".....VkkVc....",
			"....ccCCC.....",
			".....c4544.77.",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the scythe is drawn back behind the mower and swept round to the front; the
	# snath's near end shows past the fists, over the waistband and then on the hip under the arm;
	# the trail goes the same way, over the feet.
	"e": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[4, 13], [6, 14]], "a": 10, "f": true, "two": true, "scythe": {"at": [-8, -3], "rows": [
			"..dw........",
			".aq.ww......",
			"Aa....ww....",
			"Aa......wwww",
			"A...........",
			".A..........",
		]}, "rows": [
			"......CVk.....",
			".....c4Cc.....",
			"....44UUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[3, 13], [6, 14]], "a": 10, "f": true, "two": true, "scythe": {"at": [-8, -4], "rows": [
			"..dw........",
			".aq.w.......",
			"Aa...w......",
			"Aa....ww....",
			"A.......wwww",
			".A..........",
		]}, "rows": [
			".....CVk......",
			"....c4Cc......",
			"...44UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 14, "hands": [[9, 11], [6, 14]], "a": 9, "f": true, "two": true, "scythe": {"at": [-2, -2], "rows": [
			"......wd..",
			".....w.qa.",
			"..www...aA",
			"ww......aA",
			".........A",
			"........A.",
		]}, "trail": {"at": [4, 28], "rows": [
			"--.................",
			"..-++..............",
			".....+++oo.....oooo",
			"..........ooooo....",
		]}, "rows": [
			"......C4444...",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[9, 12], [6, 14]], "a": 9, "f": true, "two": true, "scythe": {"at": [-2, -2], "rows": [
			"......wd..",
			".....w.qa.",
			"..www...aA",
			"ww......aA",
			".........A",
			"........A.",
		]}, "rows": [
			"......CVk.....",
			".....cC4444...",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# Turned away it goes the other way, from the right side to the left, where the left hand
	# holds it and the body hides the right, as it hides the snath's near end; the trail lies on
	# the ground past the mower, behind the figure.
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 10], [3, 14]], "a": 9, "f": true, "two": true, "scythe": {"at": [3, 0], "rows": [
			"......wd..",
			"....ww.qa.",
			"..ww....aA",
			"ww......aA",
			".........A",
			"........A.",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			".....VcccC44..",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 10], [3, 14]], "a": 9, "f": true, "two": true, "scythe": {"at": [4, -1], "rows": [
			".....wd..",
			"....w.qa.",
			"...w...aA",
			"..w....aA",
			"ww......A",
			".......A.",
		]}, "rows": [
			"......VVVC....",
			".....ccccCCC..",
			"......VcccC44.",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[6, 10], [4, 12]], "a": 10, "f": false, "two": true, "scythe": {"at": [-11, -1], "rows": [
			"..dw......",
			".aq.ww....",
			"Aa....ww..",
			"Aa......ww",
			"A.........",
			".A........",
		]}, "trail": {"at": [7, 29], "rows": [
			"...oo........++++...",
			"ooo..............---",
		]}, "rows": [
			".....VVVC.....",
			"...78VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 10], [4, 13]], "a": 10, "f": false, "two": true, "scythe": {"at": [-11, 0], "rows": [
			"..dw......",
			".aq.ww....",
			"Aa....ww..",
			"Aa......ww",
			"A.........",
			".A........",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			"...78VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	# From behind, as turned away.
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 10], [3, 14]], "a": 9, "f": true, "two": true, "scythe": {"at": [3, 0], "rows": [
			"......wd..",
			"....ww.qa.",
			"..ww....aA",
			"ww......aA",
			".........A",
			"........A.",
		]}, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"....CccccC44..",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[7, 10], [3, 14]], "a": 9, "f": true, "two": true, "scythe": {"at": [4, -1], "rows": [
			".....wd..",
			"....w.qa.",
			"...w...aA",
			"..w....aA",
			"ww......A",
			".......A.",
		]}, "rows": [
			"....CCVVVVCC..",
			"....CCccccCC..",
			".....CccccC44.",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 15, "hands": [[6, 10], [2, 12]], "a": 10, "f": false, "two": true, "scythe": {"at": [-12, -1], "rows": [
			"..dw.....",
			".aq.ww...",
			"Aa....w..",
			"Aa.....ww",
			"A........",
			".A.......",
		]}, "trail": {"at": [6, 29], "rows": [
			"...o..........++++...",
			"ooo...............---",
		]}, "rows": [
			"..CCVVVVCC....",
			".78CccccC.....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[6, 10], [2, 13]], "a": 10, "f": false, "two": true, "scythe": {"at": [-12, 0], "rows": [
			"..dw.....",
			".aq.ww...",
			"Aa....w..",
			"Aa.....ww",
			"A........",
			".A.......",
		]}, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			".78.CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the mow drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
