"""Writes tools/art/player_chop_art.gd from a chop data module (work_proto frames: rows from
box row `top`, `bob` with the stand's drop, the hand `r` holding the axe pointing `a`).
python3 -I gen_chop_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).CHOP
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
COMMENT = {
    "s": "\t# From the front the axe comes down at the viewer, short (PlayerArt.TOWARD).\n",
    "e": "\t# From the side the near arm lifts the axe back past the head, up behind it, and\n\t# swings it forward and down; the far arm is hidden behind the body.\n",
    "ne": "\t# From behind the axe is raised over the right shoulder and swung down away from the\n\t# viewer, behind the body.\n",
}


def other_hand(fr):
    pts = [(x, fr["top"] + y) for y, r in enumerate(fr["rows"]) for x, c in enumerate(r) if c in "789"]
    if not pts:
        return None
    low = max(p[1] for p in pts)
    xs = [p[0] for p in pts if p[1] == low]
    return [min(xs, key=lambda v: abs(v - 6.5)), low]


def first(fr, test):
    for y, r in enumerate(fr["rows"]):
        if any(test(c) for c in r):
            return fr["top"] + y
    return None


lines = []
for d in ["s", "se", "e", "ne", "n"]:
    if d in COMMENT:
        lines.append(COMMENT[d].rstrip("\n"))
    lines.append(f'\t"{d}": [')
    for fr in data[d]:
        bob = fr["bob"]
        l = other_hand(fr)
        l = [l[0], l[1] - bob] if l else REST[d]
        r = [fr["r"][0], fr["r"][1] - bob]
        hips = first(fr, lambda c: c in "Uu")
        neck = first(fr, lambda c: c not in ".456789")
        extra = ', "ccw": true' if fr.get("ccw") else ""
        f = "true" if fr.get("f", True) else "false"
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": {fr["a"]}, "f": {f}{extra}, "rows": ['.replace("'", ""))
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The chop, drawn whole as the walk is (WalkArt), the axe held: four frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored (the axe with them, so there
## it is in the left hand). The arm moves from the shoulder, right under the head, and
## stays in sight: the wind-up (the shoulder up, the hand by the ear, the axe back over
## it, the torso turned a pixel toward it), the top (the body stretched a row up, the axe
## up), the strike (the body crouched a pixel, the axe forward and down) and the
## follow-through (upright again, the hand in front of the chest).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top`
## (rows over the neck, `neck`, hold only the raised arm, beside the head) in the
## letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS, the
## waistband's row `hips`, the hands' places `hands` ([the hand holding the axe: its grip,
## the other: its lowest pixel next to the body], less the bob) and how the axe is held:
## `a` the way it points (PlayerArt.WORKS), `ccw` its edge the other way, `f` in front of
## the body. Made with the review tools in the project library,
## written by tools/art/character/gen_chop_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: wind-up, top, strike, follow-through.
const FRAMES := {{
{body}
}}


## Frame `i` of the chop drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
'''
open(out, "w").write(src)
