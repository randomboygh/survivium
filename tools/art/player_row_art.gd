extends RefCounted
## The rowing, drawn whole as the walk is (WalkArt): four frames for each drawn direction
## (PlayerArt.VIEW), the west ones mirrored, played in time with the oars (Boats.stroke).
## A push stroke, as the oars swing for a body facing the bow: the catch (the fists near the
## body, the blades in the water), pushed forward (the body leaning a row down), the blades
## lifted (the fists low), back. The body sits as in the sit (the legs never move, so the
## two follow each other without a jump) and its fists stay on the handles' ends, where the
## oars have no grip of their own (Boats._oar), so they show over the handles: after the
## user's review (2026-11-20), a couple of pixels of each hand in sight wherever the hull
## and the bench leave them.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body: what is over it, a fist by the head, stays put in every
## form), the waistband's row `hips` and the hands' places `hands` ([right, left], the
## hand's lowest pixel next to the body, less the bob). The legs are not in `rows`: they
## are the sit's (PlayerArt.frame_letters), the feet over the waistband where it is on the
## last row. Made with the review tools in the project library
## (survivium-builds/character/anim/src/gen_row_gd.py).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: the catch, pushed, the blades lifted, back.
const FRAMES := {
	# From the front the fists hold the handles' ends by the chin, an outline between;
	# below the chest the hull hides the rest. The fists go with the body as a build widens it.
	"s": [
		{"bob": 2, "top": 12, "neck": 12, "hips": 16, "hands": [[2, 11], [11, 11]], "rows": [
			".44........77.",
			".56.cVkkVc.98.",
			"...ccCCCCcc...",
			"....cCCCCc....",
			"....UUuuUU....",
			"..............",
		]},
		{"bob": 3, "top": 13, "neck": 13, "hips": 16, "hands": [[2, 11], [11, 11]], "rows": [
			".44........77.",
			".56.cVkkVc.98.",
			"...ccCCCCcc...",
			"....UUuuUU....",
			"..............",
		]},
		{"bob": 3, "top": 13, "neck": 13, "hips": 16, "hands": [[2, 11], [11, 11]], "rows": [
			".44........77.",
			".56.cVkkVc.98.",
			"...ccCCCCcc...",
			"....UUuuUU....",
			"..............",
		]},
		{"bob": 2, "top": 13, "neck": 13, "hips": 16, "hands": [[2, 12], [11, 12]], "rows": [
			".44.cVkkVc.77.",
			".56ccCCCCcc98.",
			"....cCCCCc....",
			"....UUuuUU....",
			"..............",
		]},
	],
	# Turned a little: the near fist by the shoulder, the far one out from behind the head
	# on its oar (over the neck: it stays put as the body widens).
	"se": [
		{"bob": 3, "top": 8, "neck": 14, "hips": 17, "hands": [[4, 12], [12, 6]], "rows": [
			"............77",
			"............98",
			"..............",
			"..............",
			"..............",
			"..............",
			"...44VkkVc....",
			"...56cCCC.....",
			".....cCCC.....",
			".....UUuUU....",
		]},
		{"bob": 4, "top": 9, "neck": 15, "hips": 17, "hands": [[4, 12], [12, 6]], "rows": [
			"............77",
			"............98",
			"..............",
			"..............",
			"..............",
			"..............",
			"...44VkkVc....",
			"...56cCCC.....",
			".....UUuUU....",
		]},
		{"bob": 4, "top": 10, "neck": 15, "hips": 17, "hands": [[4, 12], [12, 7]], "rows": [
			"............77",
			"............98",
			"..............",
			"..............",
			"..............",
			"...44VkkVc....",
			"...56cCCC.....",
			".....UUuUU....",
		]},
		{"bob": 3, "top": 9, "neck": 14, "hips": 17, "hands": [[4, 13], [12, 7]], "rows": [
			"............77",
			"............98",
			"..............",
			"..............",
			"..............",
			".....VkkVc....",
			"...44cCCC.....",
			"...56cCCC.....",
			".....UUuUU....",
		]},
	],
	# From the side the near fist goes round in front of the vessel's bench, clear of the
	# chin: by the chest, forward and down, back, back up.
	"e": [
		{"bob": 3, "top": 14, "neck": 14, "hips": 16, "hands": [[9, 13], [8, 14]], "rows": [
			"......CVk.....",
			".....cCCS44...",
			".....UUUu56...",
			"..............",
		]},
		{"bob": 4, "top": 15, "neck": 15, "hips": 16, "hands": [[10, 13], [8, 14]], "rows": [
			"......CVk.....",
			".....cCSSs44..",
			"..........56..",
		]},
		{"bob": 4, "top": 15, "neck": 15, "hips": 16, "hands": [[9, 13], [8, 14]], "rows": [
			"......CVk.....",
			".....cCSS44...",
			".........56...",
		]},
		{"bob": 3, "top": 14, "neck": 14, "hips": 16, "hands": [[8, 13], [8, 14]], "rows": [
			"......CVk.....",
			".....cCC44....",
			".....UUU56....",
			"..............",
		]},
	],
	# The back turned a little: the near fist at the shoulder, then up and out on its
	# handle; the far one is behind the head, its arm forward behind the body.
	"ne": [
		{"bob": 3, "top": 14, "neck": 14, "hips": 17, "hands": [[9, 12], [3, 5]], "rows": [
			".....VVVC44...",
			"....ccccC56...",
			".....VcccC....",
			".....uuuuu....",
		]},
		{"bob": 4, "top": 12, "neck": 15, "hips": 17, "hands": [[11, 9], [4, 3]], "rows": [
			"...........44.",
			"...........56.",
			"...........S..",
			".....VVVC.S...",
			"....ccccCCC...",
			".....uuuuu....",
		]},
		{"bob": 4, "top": 13, "neck": 15, "hips": 17, "hands": [[11, 10], [4, 4]], "rows": [
			"...........44.",
			"...........56.",
			".....VVVC.S...",
			"....ccccCCC...",
			".....uuuuu....",
		]},
		{"bob": 3, "top": 14, "neck": 14, "hips": 17, "hands": [[9, 12], [3, 5]], "rows": [
			".....VVVC44...",
			"....ccccC56...",
			".....VcccC....",
			".....uuuuu....",
		]},
	],
	# From behind the fists show by the head on the handles' ends, the arms up from the
	# shoulders.
	"n": [
		{"bob": 3, "top": 11, "neck": 14, "hips": 17, "hands": [[12, 9], [1, 9]], "rows": [
			"77..........44",
			"98..........56",
			".8..........5.",
			"..8CCVVVVCC5..",
			"...CCccccCC...",
			"....CccccC....",
			"....uuuuuu....",
		]},
		{"bob": 4, "top": 10, "neck": 15, "hips": 17, "hands": [[12, 7], [1, 7]], "rows": [
			"77..........44",
			"98..........56",
			".8..........5.",
			".8..........5.",
			".8..........5.",
			"..8CCVVVVCC5..",
			"...CCccccCC...",
			"....uuuuuu....",
		]},
		{"bob": 4, "top": 10, "neck": 15, "hips": 17, "hands": [[12, 7], [1, 7]], "rows": [
			"77..........44",
			"98..........56",
			".8..........5.",
			".8..........5.",
			".8..........5.",
			"..8CCVVVVCC5..",
			"...CCccccCC...",
			"....uuuuuu....",
		]},
		{"bob": 3, "top": 11, "neck": 14, "hips": 17, "hands": [[12, 9], [1, 9]], "rows": [
			"77..........44",
			"98..........56",
			".8..........5.",
			"..8CCVVVVCC5..",
			"...CCccccCC...",
			"....CccccC....",
			"....uuuuuu....",
		]},
	],
}


## Frame `i` of the rowing drawn in direction `dir` (a drawn one), or {}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
