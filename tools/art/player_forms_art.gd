extends RefCounted
## The body's forms a player picks (player.yaml `looks`: `build` and `figure`), as changes
## to the figure PlayerArt draws (the normal build, straight): what each build and
## figure draws differently, by drawn direction (s, se, e, ne, n), in the letters of
## PlayerArt.INK. Every layer drawn on the body (the skin, the clothes and their shapes,
## the fists, the hands' places) is drawn again for each form, so what is worn follows
## it (make_sprites.gd saves them in player/forms/<build>_<figure>/ and
## worn/<look>/<build>_<figure>.png).
##
## Builds: thin has arms a pixel wide; stocky has a torso two pixels wider, its arms
## hanging a pixel further out each side (in the front and back views; from the side its
## belly a pixel forward). Figures (no sex is picked: every form is for everyone):
## a bust (the shade under it from the front, two pixels forward from the side, in
## the letter V: the shirt's dark over the skin's deepest) and a bust
## with hips (the thighs a pixel wider each side, from the side the seat a pixel back).
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

## The neck and torso, rows 11-14 (PlayerArt.TORSO), where a build draws them otherwise.
const TORSO := {
	"stocky": {
		"s": [
			".....kkkk.....",
			"..LCCCCCCCCc..",
			"....CCCCCc....",
			"....UUUUUu....",
		],
		"se": [
			"...C..kkkk....",
			"..LCCCCCCCCc..",
			".....CCCCCc...",
			".....UUUUUu...",
		],
		"e": [
			"......kkk.....",
			".....LCCCCc...",
			".....cCCCCc...",
			".....UUUUUu...",
		],
		"ne": [
			"...C..kkkk....",
			"..LCCCCCCCCc..",
			"....CCCCCC....",
			"....UUUUUu....",
		],
		"n": [
			".....kkkk.....",
			"..LCCCCCCCCc..",
			"....CCCCCc....",
			"....UUUUUu....",
		],
	},
}

## The bust: rows of the torso (by their row in the box, 11-14) replaced, by build
## (none: the normal build's) and direction. Seen from behind nothing shows.
const BUST := {
	"normal": {
		"s": {13: ".....CVCV....."},
		"se": {13: "......CVCV...."},
		"e": {12: ".....LCCCCc...", 13: ".....cCCCCV..."},
	},
	"stocky": {
		"s": {13: "....CCVCCV...."},
		"se": {13: ".....CCVCCV..."},
		"e": {12: ".....LCCCCCc..", 13: ".....cCCCCCV.."},
	},
}


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


## The torso of direction `dir` for build `build` and figure `figure`, rows 11-14.
static func torso(rows: Array, dir: String, build: String, figure: String) -> Array:
	var out: Array = TORSO.get(build, {}).get(dir, rows).duplicate()
	if figure != "straight":
		var bust: Dictionary = BUST.get(build, BUST.normal).get(dir, {})
		for y: int in bust:
			out[y - 11] = bust[y]
	return out


## The legs, rows 15-17 (PlayerArt.legs), with hips: the thighs a pixel wider out to
## each side from the front and back, and the seat a pixel back from the side.
static func legs(rows: Array, dir: String, side: bool, figure: String) -> Array:
	if figure != "curvy" or rows.is_empty():
		return rows
	var out: Array = rows.duplicate()
	var top: String = out[0]
	if side:
		# The rearmost pixel of the top of the legs gets one behind it.
		var at := 0
		while at < top.length() and top[at] == ".":
			at += 1
		if at < top.length() and at > 0:
			top = top.left(at - 1) + "t" + top.substr(at)
	else:
		var wide := top
		for x in top.length():
			if top[x] == ".":
				continue
			var out_x := x - 1 if x < 7 else x + 1
			if out_x >= 0 and out_x < top.length() and top[out_x] == ".":
				wide[out_x] = top[x]
		top = wide
	out[0] = top
	return out
