"""Writes tools/art/player_swim_art.gd from a swim data module (rows 10-17, drop 0)."""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1])
out = sys.argv[2]
REST = {"s": ([3, 14], [10, 14]), "se": ([3, 14], [9, 13]), "e": ([7, 14], [6, 14]), "ne": ([10, 14], [3, 14]), "n": ([10, 14], [3, 14])}
COMMENT = {
    "se": "\t# Turned a little the far arm reaches out short, behind the body when it pulls.\n",
    "e": "\t# From the side the near arm reaches forward, sweeps back from the shoulder, pulls\n\t# down past the hip and comes up under the chin; the far one is behind the body. The\n\t# body leans back from the waist on a diagonal, the legs short and thick with it,\n\t# kicking in their colours (the near leg light, the far one dark, changing places) and\n\t# drawn up a pixel as the arms pull.\n",
    "n": "\t# From behind the shoulders go up beside the head as the hands reach forward.\n",
}


def hand(rows, digits, center):
    pts = [(x, 10 + y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in digits]
    if not pts:
        return None
    low = max(p[1] for p in pts)
    xs = [p[0] for p in pts if p[1] == low]
    x = min(xs, key=lambda v: abs(v - center))
    return [x, low]


def hips(rows):
    for y, r in enumerate(rows):
        if "U" in r or "u" in r:
            return 10 + y
    return 14


lines = []
for d in ["s", "se", "e", "ne", "n"]:
    drop, frames = data.SWIM[d]
    if d in COMMENT:
        lines.append(COMMENT[d].rstrip("\n"))
    lines.append(f'\t"{d}": [')
    for rows in frames:
        r = hand(rows, "456", 6.5) or REST[d][0]
        l = hand(rows, "789", 6.5) or REST[d][1]
        lines.append(f'\t\t{{"bob": 0, "hips": {hips(rows)}, "hands": [{r}, {l}], "rows": ['.replace("'", ""))
        for row in rows:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The swim, drawn whole under the head as the walk is (WalkArt): four frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored; a breaststroke (variant A of
## the review of 2026-11-19). The water comes up to the chin (Body.SWIM_DEPTH), so the
## whole stroke is under it, the body showing through tinted: the hands come together in
## front of the chest, the arms sweep out from the shoulders, pull down by the sides and
## come back up; the legs glide together, kick apart and draw up. An arm moves from its
## shoulder, right under the head. Afloat the head is as high in every direction (`bob`
## 0, no stand `drop`), so the eyes stay over the water.
##
## The frames are in WalkArt's form: the head's place `bob`, the waistband's row `hips`,
## the hands' places `hands` ([right, left], the hand's lowest pixel next to the body:
## where what they hold goes) and `rows`, rows 10-17 of the box in the letters of
## PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS, empty where the
## head is.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: reach in, sweep out, pull down, recover.
const FRAMES := {{
{body}
}}


## Frame `i` of the swim drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from its first row drawn.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	var top := 0
	while top < f.rows.size() - 1 and f.rows[top].replace(".", "") == "":
		top += 1
	return FormsArt.body(f.rows, dir, build, figure, top, f.hips - 10)
'''
open(out, "w").write(src)
