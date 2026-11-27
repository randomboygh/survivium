extends RefCounted
## The bow's shot (the work `aim`), drawn whole as the walk is (WalkArt), the bow drawn for each
## frame: four frames for each drawn direction (PlayerArt.VIEW), the west ones mirrored (the bow
## with them, so there it is in the left hand). After the Bow Attack of Puny Characters (Shade,
## CC0; the user's pick 2026-11-20): an arrow nocked, the string drawn back, loosed (the string
## straight, the drawing hand thrown back), the bow down again; the arrow leaves on the third
## frame, as every work strikes (Controls). The legs never move. The bows play it.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in the
## letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck` the first
## row of the body), the waistband's row `hips`, the hands' places `hands` ([the bow's mark: the
## hand at its grip, but from the front a place above the neck, which no build moves
## (PlayerArt.pose), so that the bow held across the body stays in the middle; the other hand: its
## lowest pixel next to the body], less the bob), `a` the way a thing
## other than a bow would point (PlayerArt.WORKS; 8 is PlayerArt.TOWARD, at the viewer), `f` the
## bow in front of the body, `two`: the other hand draws the string, so it shows no thing of its
## own, and `bow` the bow as the frame draws it (ToolArt.INK letters: rows from `at`, the offset of
## their corner from the grip), which ToolArt draws for a shape with `bow` instead of turning it.
## The bow has no dark edge of its own where the figure's outline goes (the two made a line two
## pixels thick): its dark letters (K, x) only part its wood from the skin and from its string.
## Made with the review tools in the project library,
## written by tools/art/character/gen_aim_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: nocked, drawn, loosed, down again.
const FRAMES := {
	# From the front the bow is held across the body, its arrow at the viewer, the grey head
	# over the bow's belly: nocked at the hips, drawn up to the chin, loosed (the string straight,
	# the hand thrown back), down again. Its mark is above the neck: the bow stays in the middle
	# in every build.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 10], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-4, 2], "rows": [
			"ssssnossss",
			"PK..no..KP",
			"pPKKnoKKPp",
			".pPxAaxPp.",
			"..pxAaxp..",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 10], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-4, 0], "rows": [
			"....ss....",
			"..ssnoss..",
			"ss..no..ss",
			"PK..no..KP",
			"pPKKnoKKPp",
			".pPxAaxPp.",
			"..pxAaxp..",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 10], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-4, 3], "rows": [
			"ss......ss",
			"PKssssssKP",
			"pPKKKKKKPp",
			".pPPgPPPp.",
		]}, "rows": [
			".4..cVkkVc....",
			".45ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 10], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-4, 2], "rows": [
			"ssssssssss",
			"PK......KP",
			"pPKKKKKKPp",
			".pPPgPPPp.",
			"..pppppp..",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
	],
	# Turned: the bow down the right side and round under (its lower end is under the frame's
	# edge), the arrow along it. The string ends where it meets the limb on the hips' row and
	# never runs over the legs; drawn, it goes from the bow's upper end back to the hand at the
	# chin, and the upper limb is two pixels wide.
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-3, -4], "rows": [
			"....s.",
			"...sKP",
			"...sKP",
			".onKPP",
			".sonPp",
			"sKPon.",
			"KPPpAA",
		]}, "rows": [
			".....VkkVc....",
			"....ccCCC44...",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-5, -4], "rows": [
			"...ssss..",
			".ss..Pp..",
			".son.Pp..",
			"s..onPP..",
			"....onp..",
			"..KPPpAA.",
			"..KPPp..A",
		]}, "rows": [
			".....VkkVc....",
			"....ccC44.....",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-3, -4], "rows": [
			"....s.",
			"...sKP",
			"...sKP",
			"..sKPP",
			".sKPPp",
			"sKPPp.",
			"KPPp..",
		]}, "rows": [
			"....cVkkVc....",
			".44ccCCC......",
			".45..cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-3, -4], "rows": [
			"....s.",
			"...sKP",
			"...sKP",
			"..sKPP",
			".sKPPp",
			"sKPPp.",
			"KPPp..",
		]}, "rows": [
			".....VkkVc....",
			"....ccCCC44...",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the bow is up in front of the face, the arrow along the eyes; drawn, the limb
	# is a pixel thicker beside the arrow (its grip); loosed, the near hand is thrown back down.
	"e": [
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-2, -5], "rows": [
			"sPp......",
			"sKPp.....",
			".sKPp....",
			".sKPp....",
			".snnnnnAA",
			".sooooaaa",
			".sKPp....",
			".sKPp....",
			"sKPp.....",
			"sPp......",
		]}, "rows": [
			"..........44..",
			"......CVk45...",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-4, -5], "rows": [
			"..sPp...",
			"..s.Pp..",
			".s...Pp.",
			".s..PPp.",
			"snnnnnAA",
			"soooooaa",
			".s..PPp.",
			".s...Pp.",
			"..s.Pp..",
			"..sPp...",
		]}, "rows": [
			".......44.....",
			"......CV45....",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-2, -5], "rows": [
			"sPp..",
			"sKPp.",
			".sKPp",
			".sKPp",
			".sKPp",
			".sKPp",
			".sKPp",
			".sKPp",
			"sKPp.",
			"sPp..",
		]}, "rows": [
			"......CVk.....",
			"....5cCCc.....",
			"....4UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-2, -5], "rows": [
			"sPp..",
			"sKPp.",
			".sKPp",
			".sKPp",
			".sKPp",
			".sKPp",
			".sKPp",
			".sKPp",
			"sKPp.",
			"sPp..",
		]}, "rows": [
			"..........44..",
			"......CVk45...",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
	],
	# Turned away the bow is by the body's right side, from under the cheek to the knee: the
	# limb's arc and its string, straight between the limb's ends, next to the body. The arrow is
	# a line from the near hand up and right through the bow, its grey head past the bow (nocked)
	# or at it (drawn, the bow a pixel higher).
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[13, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [-2, -4], "rows": [
			"......a",
			".....Aa",
			".Pp.Aa.",
			"s.Pno..",
			"s.no...",
			"snop...",
			"s.Pp...",
			"sPp....",
			"sp.....",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCC44..",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[13, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [-2, -4], "rows": [
			"....a",
			"..pAa",
			"s.Aa.",
			"snop.",
			"noPp.",
			"s.Pp.",
			"sPp..",
			"sp...",
		]}, "rows": [
			".....VVVC55...",
			"....ccccCCC...",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[13, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [-2, -2], "rows": [
			".Pp.",
			"s.Pp",
			"s.Pp",
			"s.Pp",
			"s.Pp",
			"sPp.",
			"sp..",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			".....Vccc45...",
			".....uuuu44...",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[13, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [-2, -2], "rows": [
			".Pp.",
			"s.Pp",
			"s.Pp",
			"s.Pp",
			"s.Pp",
			"sPp.",
			"sp..",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCC45..",
			".....VcccC44..",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
	],
	# From behind the body hides the bow: only the drawing arm shows, up at the shoulder, then
	# thrown back down by the right side.
	"n": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 12], [3, 14]], "a": 0, "f": false, "two": true, "bow": {"at": [0, 0], "rows": []}, "rows": [
			"...CCVVVVCC...",
			"...CCccccC44..",
			"....CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 12], [3, 14]], "a": 0, "f": false, "two": true, "bow": {"at": [0, 0], "rows": []}, "rows": [
			"...CCVVVVC555.",
			"...CCccccCC...",
			"....CccccC....",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 12], [3, 14]], "a": 0, "f": false, "two": true, "bow": {"at": [0, 0], "rows": []}, "rows": [
			"...CCVVVVCC...",
			"...CCccccCC...",
			"....CccccC45..",
			"....uuuuuu44..",
			"....mm..mm....",
			"....bb..bb....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[10, 12], [3, 14]], "a": 0, "f": false, "two": true, "bow": {"at": [0, 0], "rows": []}, "rows": [
			"...CCVVVVCC...",
			"...CCccccC45..",
			"....CccccC44..",
			"....uuuuuu....",
			"....mm..mm....",
			"....bb..bb....",
		]},
	],
}


## Frame `i` of the aim drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
