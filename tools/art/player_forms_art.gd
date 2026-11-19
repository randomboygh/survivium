extends RefCounted
## The body's forms a player picks (player.yaml `looks`: `build` and `figure`), as changes
## to the figure PlayerArt draws (the normal build, straight): what each build and
## figure draws differently, by drawn direction (s, se, e, ne, n), in the letters of
## PlayerArt.INK. Every layer drawn on the body (the skin, the clothes and their shapes,
## the fists, the hands' places) is drawn again for each form, so what is worn follows
## it (make_sprites.gd saves them in player/forms/<build>_<figure>/ and
## worn/<look>/<build>_<figure>.png).
##
## Each form is made of the rows of the body drawn (body): the stand (PlayerArt.BODY) and
## every frame of the walk (WalkArt) and of the jump (JumpArt). Builds: thin has arms a
## pixel wide; stocky has a torso two pixels wider from the neck to the waist, its arms
## hanging a pixel further out each side (in the front and back views; from the side its
## belly a pixel forward).
## Figures (no sex is picked: every form is for everyone): a bust (the shade under it on
## the row over the waist from the front, a pixel forward from the side, in the letter V:
## the shirt's dark over the skin's deepest) and a bust with hips (the thighs a pixel
## wider each side, from the side the seat a pixel back).
##
## Designed in survivium-builds/character/looks/figure-forms-draft.png (the user's picks
## of 2026-11-19: build thin, normal, stocky; a separate figure row; the bust more visible
## than in the draft).

const BUILDS := ["thin", "normal", "stocky"]
const FIGURES := ["straight", "bust", "curvy"]

## How far the shoulders and the hanging hands go out from the body's middle, front and
## back views (a pixel each side).
const OUT := {"thin": 0, "normal": 0, "stocky": 1}
## Builds whose arms are a pixel wide.
const NARROW := ["thin"]

## Letters of the torso: the shirt and the waistband.
const TORSO := "LCcVUu"
## Letters of the trousers: what a body with hips draws wider (not a foot or a hand).
const THIGHS := "Ttm"
## The hands' pixels in the rows of a body (the frames drawn whole: WalkArt, JumpArt), by
## hand: digits.
const HANDS := {"right": "456", "left": "789"}
## Where a bust's shade goes on the row over the waistband, by direction and build (the
## middle of a stocky body is two pixels wider).
const BUST := {"s": {"normal": [6, 8], "stocky": [6, 9]}, "se": {"normal": [7, 9], "stocky": [7, 10]}}


## The name of a form: its build and figure.
static func form(build: String, figure: String) -> String:
	return build + "_" + figure


## Every form, the normal straight one first.
static func all() -> Array:
	var out := [form("normal", "straight")]
	for b: String in BUILDS:
		for f: String in FIGURES:
			if not out.has(form(b, f)):
				out.append(form(b, f))
	return out


## The rows of a body drawn in the normal build, straight (`rows`: rows of the box from the
## neck, at index `neck`, down to the feet, the waistband at index `hips`; the hands in
## them, if any, digits: HANDS), as build `build` and figure `figure` draw it in direction
## `dir`: a stocky body two pixels wider from the neck to the waist, its hands a pixel
## further out (from the side its belly a pixel forward); thin hands a pixel narrower; a
## bust shaded over the waist (from the side a pixel forward); hips with the thighs wider.
## Seen from behind a bust shows nothing.
static func body(rows: Array, dir: String, build: String, figure: String, neck: int, hips: int) -> Array:
	var out: Array = rows.duplicate()
	var side := dir == "e"
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
		out[hips + 1] = hipped(out[hips + 1], dir)
	return out


## The top row of the legs `r` with hips: the thighs a pixel wider out to each side from
## the front and the back, the seat a pixel back from the side; only the trousers' pixels
## (THIGHS) drawn wider, into empty ones, not a foot lifted that high or a hand.
static func hipped(r: String, dir: String) -> String:
	var top := ""
	for x in r.length():
		top += r[x] if r[x] in THIGHS else "."
	var wide := top
	if dir == "e":
		# The rearmost pixel of the top of the legs gets one behind it.
		var at := 0
		while at < top.length() and top[at] == ".":
			at += 1
		if at < top.length() and at > 0:
			wide[at - 1] = "t"
	else:
		for x in top.length():
			if top[x] == ".":
				continue
			var out_x := x - 1 if x < 7 else x + 1
			if out_x >= 0 and out_x < top.length() and top[out_x] == ".":
				wide[out_x] = top[x]
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
		out += "." if _hand(r[x]) != "" else r[x]
	for x in r.length():
		if _hand(r[x]) != "":
			var to := x - 1 if x < 7 else x + 1
			if to >= 0 and to < r.length() and out[to] == ".":
				out[to] = r[x]
	return out


## Row `r` with each hand a pixel narrower where it is wider than one: the pixel of it
## farthest from the middle left out.
static func _thin(r: String) -> String:
	for hand: String in HANDS:
		var xs := []
		for x in r.length():
			if _hand(r[x]) == hand:
				xs.append(x)
		if xs.size() > 1:
			var far: int = xs[0] if absf(xs[0] - 6.5) > absf(xs[-1] - 6.5) else xs[-1]
			r[far] = "."
	return r


## The hand letter `c` is a pixel of ("right", "left"), or "".
static func _hand(c: String) -> String:
	for hand: String in HANDS:
		if c in HANDS[hand]:
			return hand
	return ""
