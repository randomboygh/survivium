extends RefCounted
## The walk, copied pixel by pixel from the reference the user picked (2026-11-19, in the
## project library survivium-builds/character/anim/references/: walk-bare.gif gives the
## body, its light and shade, walk-knight.gif where the clothes and the hands are): six
## frames for each drawn direction (PlayerArt.VIEW), the west ones mirrored. Each frame
## bobs the head down (`bob`, the hair and the face with it), has the waistband on row
## `hips`, the hands at `hands` ([right, left] in PlayerArt's box, moved down with the
## bob as in PlayerArt.MOVES: where what they hold goes) and draws the body under the
## head: `rows`, rows 10-17 of the box in the letters of PlayerArt.INK and the hands'
## skin (HANDS), empty where the head is or nothing; the outline is drawn round it as
## on every frame. From the side and from behind the figure stands a row lower than
## the reference has it, its feet on the frame's last row.
##
## The legs are two pixels wide and a foot lifted has no outline under it (player.yaml
## `soles`). A step: the feet apart, the arms down; the body down a pixel, the back heel
## up and the arm opposite the front leg swinging forward; then both feet off the ground,
## the body a row shorter and that arm up at the chin; the same with the other leg. The
## body's forms (PlayerArt.FormsArt) are made of these frames (see rows).

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The hands' skin in `rows`: the hand and the skin's tone (light, shade, deep). In front
## of the body it is drawn with the fists, over what the hand holds; behind it, with the
## body.
const HANDS := {"4": ["right", "S"], "5": ["right", "s"], "6": ["right", "k"],
	"7": ["left", "S"], "8": ["left", "s"], "9": ["left", "k"]}
## Letters of the torso: the shirt and the waistband.
const TORSO := "LCcVUu"
## Letters of the trousers: what a body with hips draws wider (not a foot or a hand).
const THIGHS := "Ttm"
## Where a bust's shade goes on the row over the waistband, by direction and build (the
## middle of a stocky body is two pixels wider).
const BUST := {"s": {"normal": [6, 8], "stocky": [6, 9]}, "se": {"normal": [7, 9], "stocky": [7, 10]}}

const FRAMES := {
	"s": [
		{"bob": 0, "hips": 14, "hands": [[3, 14], [10, 14]], "rows": [
			"..............",
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..44cCCCCc87..",
			"..44UUuuUU87..",
			"....tt..TT....",
			"....BB..TT....",
			"........BB....",
		]},
		{"bob": 1, "hips": 14, "hands": [[4, 13], [11, 12]], "rows": [
			"..............",
			"..............",
			"...ccVkkVcc8..",
			"...44CCCCCc8..",
			"...44UuuUU....",
			".....t..TT....",
			"....bb..tt....",
			"........BB....",
		]},
		{"bob": 0, "hips": 13, "hands": [[4, 13], [11, 11]], "rows": [
			"..........c8..",
			"...ccVkkVcc8..",
			"...44CCCCC....",
			"...44uuuUU....",
			".....t..TT....",
			"....BB..BB....",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[3, 14], [10, 14]], "rows": [
			"..............",
			"....cVkkVc....",
			"...ccCCCCcc...",
			"..45cCCCCc77..",
			"..45UUuuUU77..",
			"....TT..tt....",
			"....tt..BB....",
			"....BB........",
		]},
		{"bob": 1, "hips": 14, "hands": [[2, 12], [9, 13]], "rows": [
			"..............",
			"..............",
			"..5ccVkkVcc...",
			"..5ccCCCC77...",
			"....UUuuU77...",
			"....TT..t.....",
			"....tt..bb....",
			"....BB........",
		]},
		{"bob": 0, "hips": 13, "hands": [[2, 11], [9, 13]], "rows": [
			"..5c..........",
			"..5ccVkkVcc...",
			"....cCCCC77...",
			"....UUuuu77...",
			"....TT..t.....",
			"....BB..BB....",
			"..............",
			"..............",
		]},
	],
	"se": [
		{"bob": 0, "hips": 14, "hands": [[4, 14], [9, 13]], "rows": [
			"..............",
			".....VkkVc....",
			"....ccCCC88...",
			"...44cCCC88...",
			"...44UUuUU....",
			".....tt.TTt...",
			"....BB..KB....",
			"..............",
		]},
		{"bob": 1, "hips": 14, "hands": [[5, 13], [9, 12]], "rows": [
			"..............",
			"..............",
			"....cckkVc....",
			"....44CCC8....",
			"....44UuUU....",
			".....tt.Tt....",
			"....bb..BBB...",
			"..............",
		]},
		{"bob": 0, "hips": 13, "hands": [[6, 13], [9, 12]], "rows": [
			"..............",
			"....CckkVc....",
			"....C44CC8....",
			".....44uUU....",
			".....tt.Tt....",
			"....bb..BB....",
			"..............",
			"..............",
		]},
		{"bob": 0, "hips": 14, "hands": [[4, 14], [9, 13]], "rows": [
			"..............",
			".....VkkVc....",
			"....ccCCC88...",
			"...44cCCC88...",
			"...44UUuU.....",
			".....TTTm.....",
			".....TTt......",
			".....KB.......",
		]},
		{"bob": 1, "hips": 15, "hands": [[4, 13], [10, 13]], "rows": [
			"..............",
			"..............",
			"....cckkVcc...",
			"..44ccCCC888..",
			"..445CCcC.88..",
			".....UUUu.....",
			".....Tt.b.....",
			".....BBB......",
		]},
		{"bob": 0, "hips": 14, "hands": [[3, 12], [10, 13]], "rows": [
			"..............",
			"..44cckkVcc...",
			"..44ccCCC888..",
			".....CCcC.88..",
			".....UUUu.....",
			".....TT.......",
			".....BB.......",
			"..............",
		]},
	],
	"e": [
		{"bob": 1, "hips": 15, "hands": [[5, 14], [9, 13]], "rows": [
			"..............",
			"..............",
			"......Ckk.....",
			".....CCCCc....",
			"....44CCC8....",
			"....44uuUuu...",
			".....tttmmm...",
			".....BB..b....",
		]},
		{"bob": 2, "hips": 15, "hands": [[4, 13], [9, 13]], "rows": [
			"..............",
			"..............",
			"..............",
			"....CCCkk.....",
			"...444cCC88...",
			"...44uuuU88...",
			".....tttmm....",
			".....BB.bb....",
		]},
		{"bob": 1, "hips": 14, "hands": [[5, 12], [9, 12]], "rows": [
			"..............",
			"..............",
			"...4CCCkk88...",
			"...444cCC88...",
			".....uuuU.....",
			".....tttmm....",
			".....BB.bb....",
			"..............",
		]},
		{"bob": 1, "hips": 14, "hands": [[7, 14], [6, 14]], "rows": [
			"..............",
			"..............",
			"......CVk.....",
			"......CCc.....",
			"......U44.....",
			".....tt44t....",
			".....ttmttt...",
			".....bb..B....",
		]},
		{"bob": 2, "hips": 15, "hands": [[8, 13], [5, 13]], "rows": [
			"..............",
			"..............",
			"..............",
			"......CVV.....",
			".....9cCC44...",
			".....9uU444...",
			"......tmtt....",
			"......bbBBB...",
		]},
		{"bob": 1, "hips": 14, "hands": [[8, 13], [5, 12]], "rows": [
			"..............",
			"..............",
			"....99CCC.....",
			"....99CCC44...",
			"......uu444...",
			"......tmtt....",
			"......bbBB....",
			"..............",
		]},
	],
	"ne": [
		{"bob": 1, "hips": 15, "hands": [[10, 14], [4, 14]], "rows": [
			"..............",
			"..............",
			".....VVVC.....",
			"....ccccCCC...",
			"...88Vccc444..",
			"...88uuuuu44..",
			"......ttt.....",
			"......BB......",
		]},
		{"bob": 2, "hips": 15, "hands": [[9, 13], [3, 13]], "rows": [
			"..............",
			"..............",
			"..............",
			"...ccVVVCC....",
			"..888ccccCC4..",
			"..88.uuu.544..",
			"......tt......",
			"......BB......",
		]},
		{"bob": 1, "hips": 14, "hands": [[9, 12], [3, 13]], "rows": [
			"..............",
			"..............",
			"..888VVVccc4..",
			"..888cccc444..",
			"..88.uuu......",
			"......tt......",
			"......BB......",
			"..............",
		]},
		{"bob": 1, "hips": 14, "hands": [[7, 14], [3, 14]], "rows": [
			"..............",
			"..............",
			".....VVVCC....",
			".....ccCCC....",
			".....uU44.....",
			".....mT44t....",
			"....mm.ttt....",
			"....bb..B.....",
		]},
		{"bob": 2, "hips": 14, "hands": [[6, 13], [9, 11]], "rows": [
			"..............",
			"..............",
			"..............",
			".....VVCC7....",
			"....u44UU.....",
			"....m444t.....",
			"...mmm.ttt....",
			"...bb...BB....",
		]},
		{"bob": 1, "hips": 13, "hands": [[6, 12], [9, 11]], "rows": [
			"..............",
			"..............",
			".....44CC7....",
			"....u444u.....",
			"....mmmtt.....",
			"...mmm.ttt....",
			"...bb...BB....",
			"..............",
		]},
	],
	"n": [
		{"bob": 1, "hips": 15, "hands": [[10, 14], [3, 13]], "rows": [
			"..............",
			"..............",
			"...CCVVVVC....",
			"..7CCccccCC...",
			"..77ccccc444..",
			"....uuuuuu44..",
			"....bb..mm....",
			"........bb....",
		]},
		{"bob": 2, "hips": 15, "hands": [[10, 14], [3, 14]], "rows": [
			"..............",
			"..............",
			"...C..........",
			"...CcVVVVCC...",
			"....cccccCC...",
			"....uuuuu444..",
			".....b..mm44..",
			"........bb....",
		]},
		{"bob": 1, "hips": 14, "hands": [[9, 14], [3, 14]], "rows": [
			"..............",
			"...C..........",
			"....cVVVVCC...",
			"....cccccCC...",
			"....uuuuu44...",
			"........m44...",
			"........bb....",
			"..............",
		]},
		{"bob": 1, "hips": 15, "hands": [[10, 13], [3, 14]], "rows": [
			"..............",
			"..............",
			"....CVVVVCC...",
			"...CCccccCC4..",
			"..777ccccc44..",
			"..77uuuuuu....",
			"....mm..bb....",
			"....bb........",
		]},
		{"bob": 2, "hips": 15, "hands": [[10, 14], [3, 14]], "rows": [
			"..............",
			"..............",
			"..........c...",
			"...CcVVVVcC...",
			"...CCccccc....",
			"..777uuuuu....",
			"..77mm..b.....",
			"....bb........",
		]},
		{"bob": 1, "hips": 14, "hands": [[10, 14], [4, 14]], "rows": [
			"..............",
			"..........c...",
			"...CcVVVVc....",
			"...CCccccc....",
			"...77uuuuu....",
			"...77m........",
			"....bb........",
			"..............",
		]},
	],
}


## Frame `i` of the walk drawn in direction `dir` ({"bob", "hips", "hands", "rows"}), or
## {} when that direction has none.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (PlayerArt.FormsArt), drawn in direction `dir`: a stocky body two pixels wider from the
## neck to the waist, its hands further out (from the side its belly a pixel forward);
## thin hands a pixel narrower; a bust shaded over the waist (from the side a pixel
## forward); hips with the thighs wider (_hips). The hands stay where they are
## but for a stocky body's front and back.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	var out: Array = f.rows.duplicate()
	var side := dir == "e"
	var neck: int = 1 + f.bob
	var hips: int = f.hips - 10
	if build == "stocky":
		for y in range(neck, out.size()):
			if side:
				if y > neck and y <= hips:
					out[y] = _forward(out[y], "")
			elif y <= hips:
				out[y] = out[y].substr(1, 6) + out[y].substr(6, 2) + out[y].substr(7, 6)
			else:
				out[y] = _hands_out(out[y])
	elif build == "thin":
		out = out.map(_thin)
	if figure != "straight":
		if side:
			out[hips - 2] = _forward(out[hips - 2], "")
			out[hips - 1] = _forward(out[hips - 1], "V")
		elif BUST.has(dir):
			var r: String = out[hips - 1]
			for x: int in BUST[dir]["stocky" if build == "stocky" else "normal"]:
				if r[x] in "LCc":
					r[x] = "V"
			out[hips - 1] = r
	if figure == "curvy" and hips + 1 < out.size():
		out[hips + 1] = _hips(out[hips + 1], dir, side)
	return out


## The top row of the legs `r` with hips (FormsArt.legs): only the thighs drawn wider,
## into empty pixels, not a foot lifted that high or a hand.
static func _hips(r: String, dir: String, side: bool) -> String:
	var thighs := ""
	for x in r.length():
		thighs += r[x] if r[x] in THIGHS else "."
	var wide: String = FormsArt.legs([thighs], dir, side, "curvy")[0]
	for x in r.length():
		if r[x] == "." and wide[x] != ".":
			r[x] = wide[x]
	return r


## Row `r` with a pixel put before the front (east) edge of the torso: a copy of it, or
## `letter`; not where a hand is.
static func _forward(r: String, letter: String) -> String:
	var at := -1
	for x in r.length():
		if r[x] in TORSO:
			at = x
	if at >= 0 and at + 1 < r.length() and r[at + 1] == ".":
		r[at + 1] = letter if letter != "" else r[at]
	return r


## Row `r` with the hands' pixels a pixel further out from the middle.
static func _hands_out(r: String) -> String:
	var out := ""
	for x in r.length():
		out += "." if HANDS.has(r[x]) else r[x]
	for x in r.length():
		if HANDS.has(r[x]):
			var to := x - 1 if x < 7 else x + 1
			if to >= 0 and to < r.length() and out[to] == ".":
				out[to] = r[x]
	return out


## Row `r` with each hand a pixel narrower where it is wider than one: the pixel of it
## farthest from the middle left out.
static func _thin(r: String) -> String:
	for hand: String in ["right", "left"]:
		var xs := []
		for x in r.length():
			if HANDS.has(r[x]) and HANDS[r[x]][0] == hand:
				xs.append(x)
		if xs.size() > 1:
			var far: int = xs[0] if absf(xs[0] - 6.5) > absf(xs[-1] - 6.5) else xs[-1]
			r[far] = "."
	return r
