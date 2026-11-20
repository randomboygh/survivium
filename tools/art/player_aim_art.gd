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
## row of the body), the waistband's row `hips`, the hands' places `hands` ([the hand holding the
## bow: its grip, the other: its lowest pixel next to the body], less the bob), `a` the way a thing
## other than a bow would point (PlayerArt.WORKS; 8 is PlayerArt.TOWARD, at the viewer), `f` the
## bow in front of the body, `two`: the other hand draws the string, so it shows no thing of its
## own, and `bow` the bow as the frame draws it (ToolArt.INK letters: rows from `at`, the offset of
## their corner from the grip), which ToolArt draws for a shape with `bow` instead of turning it.
## Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_aim_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: nocked, drawn, loosed, down again.
const FRAMES := {
	# From the front the bow is held across the body, its arrow at the viewer: nocked at the
	# hips, drawn up to the chin, loosed (the string straight, the hand thrown back), down again.
	"s": [
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 15], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-5, -3], "rows": [
			"KssssnossssK",
			"KPK..no..KPK",
			"KpPKKnoKKPpK",
			".KpPPgoPPpK.",
			"..KppnoppK..",
			"...KKAaKK...",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 16], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-5, -6], "rows": [
			".....ss.....",
			"...ssnoss...",
			".ss..no..ssK",
			"KPK..no..KPK",
			"KpPKKnoKKPpK",
			".KpPPnoPPpK.",
			"..KppgappK..",
			"...KxAaxK...",
		]}, "rows": [
			"....cVkkVc....",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 16], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-5, -3], "rows": [
			"Kss......ssK",
			"KPKssssssKPK",
			"KpPKKKKKKPpK",
			".KpPPgPPPpK.",
			"..KppppppK..",
		]}, "rows": [
			".4..cVkkVc....",
			".45ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"....TT..TT....",
			"....tt..TT....",
			"....BB..BB....",
		]},
		{"bob": 0, "top": 11, "neck": 11, "hips": 14, "hands": [[6, 15], [10, 14]], "a": 8, "f": true, "two": true, "bow": {"at": [-5, -3], "rows": [
			"KssssssssssK",
			"KPK......KPK",
			"KpPKKKKKKPpK",
			".KpPPgPPPpK.",
			"..KppppppK..",
			"...KKKKKK...",
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
	# Turned: the bow down the right side and round under, the arrow along it.
	"se": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-6, -4], "rows": [
			".......sK.",
			"......sKPK",
			"......sKPK",
			"....onKPPK",
			"....sonPpK",
			".sssKPonK.",
			"sKKKPPpAA.",
			"KPPPPpKxA.",
		]}, "rows": [
			".....VkkVc....",
			"....ccCCC44...",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-6, -4], "rows": [
			"....ssssK.",
			"..ss..KPK.",
			"..son.KPK.",
			".s..onPPK.",
			".s..KonpK.",
			".s.KPPpAA.",
			"sKKKPPpKxA",
			"KPPPPpK...",
		]}, "rows": [
			".....VkkVc....",
			"....ccC44.....",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-6, -4], "rows": [
			".......sK.",
			"......sKPK",
			"......sKPK",
			".....sKPPK",
			"....sKPPpK",
			".sssKPPpK.",
			"sKKKPPpK..",
			"KPPPPpK...",
		]}, "rows": [
			".....VkkVc....",
			".44ccCCC......",
			".45..cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 13], [9, 13]], "a": 3, "f": true, "two": true, "bow": {"at": [-6, -4], "rows": [
			".......sK.",
			"......sKPK",
			"......sKPK",
			".....sKPPK",
			"....sKPPpK",
			".sssKPPpK.",
			"sKKKPPpK..",
			"KPPPPpK...",
		]}, "rows": [
			".....VkkVc....",
			"....ccCCC44...",
			".....cCCC.....",
			".....UUuUU....",
			".....TT.Tt....",
			".....KB.KB....",
		]},
	],
	# From the side the bow is up in front of the face, the arrow along the eyes; loosed, the
	# near hand is thrown back down.
	"e": [
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-2, -6], "rows": [
			".KK.......",
			"sPpK......",
			"sKPpK.....",
			".sKPpK....",
			".sKPpK....",
			".snnnnnAAx",
			".sooooaaax",
			".sKPpK....",
			".sKPpK....",
			"sKPpK.....",
			"sPpK......",
			".KK.......",
		]}, "rows": [
			"..........44..",
			"......CVk45...",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-4, -6], "rows": [
			"...KK....",
			"..sPpK...",
			"..sKPpK..",
			".s..KPpK.",
			".s..KPxx.",
			"snnnnnAAx",
			"soooooaax",
			".s..KPxx.",
			".s..KPpK.",
			"..sKPpK..",
			"..sPpK...",
			"...KK....",
		]}, "rows": [
			".......44.....",
			"......CV45....",
			".....cCCc.....",
			".....UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-2, -6], "rows": [
			".KK...",
			"sPpK..",
			"sKPpK.",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			"sKPpK.",
			"sPpK..",
			".KK...",
		]}, "rows": [
			"......CVk.....",
			"....5cCCc.....",
			"....4UUUu.....",
			".....ttt......",
			"......tTt.....",
			"......BBb.....",
		]},
		{"bob": 1, "top": 11, "neck": 12, "hips": 14, "hands": [[13, 11], [6, 14]], "a": 2, "f": true, "two": true, "bow": {"at": [-2, -6], "rows": [
			".KK...",
			"sPpK..",
			"sKPpK.",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			".sKPpK",
			"sKPpK.",
			"sPpK..",
			".KK...",
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
	# Turned away the bow is a stick past the body's right side; drawn, the arrow's head shows
	# past the head.
	"ne": [
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [0, -11], "rows": [
			"..xxx",
			"...Ax",
			"....x",
			".....",
			".....",
			".....",
			".....",
			".....",
			".p...",
			"Pp...",
			"Pp...",
			"Pp...",
			"Pp...",
			"Pp...",
			"sp...",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCC44..",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 10], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [0, -9], "rows": [
			".xxx",
			"..Ax",
			"...x",
			"....",
			"....",
			"....",
			".p..",
			"Pp..",
			"Pp..",
			"Pp..",
			"Pp..",
			"Pp..",
			"sp..",
		]}, "rows": [
			".....VVVC55...",
			"....ccccCCC...",
			".....VcccC....",
			".....uuuuu....",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [0, -3], "rows": [
			".p",
			"Pp",
			"Pp",
			"Pp",
			"Pp",
			"Pp",
			"sp",
		]}, "rows": [
			".....VVVC.....",
			"....ccccCCC...",
			".....Vccc45...",
			".....uuuu44...",
			".....mm.tt....",
			".....bb.BB....",
		]},
		{"bob": 1, "top": 12, "neck": 12, "hips": 15, "hands": [[12, 11], [3, 14]], "a": 1, "f": false, "two": true, "bow": {"at": [0, -3], "rows": [
			".p",
			"Pp",
			"Pp",
			"Pp",
			"Pp",
			"Pp",
			"sp",
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
