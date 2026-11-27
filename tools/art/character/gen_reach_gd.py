"""Writes tools/art/player_reach_art.gd from a reach data module (work_proto frames: rows from
box row `top`, `bob` with the stand's drop, the hand `r` in use, `f` in front of the body).
python3 -I gen_reach_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).REACH
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
COMMENT = {
    "s": "\t# From the front the hand in use is at the picture's left, down along the side.\n",
    "se": "\t# Turned, the arm in use is the near one; the far arm ends a row higher, beside the\n\t# shoulders' row.\n",
    "e": "\t# From the side the arm goes down and forward in front of the body.\n",
    "ne": "\t# From behind the hand in use is at the picture's right, what it holds behind the body.\n",
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
        fr = dict(fr)
        assert fr["top"] + len(fr["rows"]) == 18, (d, fr)
        # Empty rows over the body are left out.
        while not fr["rows"][0].replace(".", ""):
            fr["rows"] = fr["rows"][1:]
            fr["top"] += 1
        bob = fr["bob"]
        l = other_hand(fr)
        l = [l[0], l[1] - bob] if l else REST[d]
        r = [fr["r"][0], fr["r"][1] - bob]
        hips = first(fr, lambda c: c in "Uu")
        neck = first(fr, lambda c: c not in ".456789")
        f = "true" if fr.get("f", True) else "false"
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": -1, "f": {f}, "rows": ['.replace("'", ""))
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The reach (a bare hand taking a thing, a thing put down, a plan built), drawn whole as
## the walk is (WalkArt): four frames for each drawn direction (PlayerArt.VIEW), the west
## ones mirrored (the hand in use with them, so there it is the left one). Upright, the
## hand lifted to the waist; the crouch (the chest's row folds away, the legs never move)
## with the arm stretched down, the hand a row over the ground; still crouched, the arm
## short again, the hand two rows over the ground with what it took; upright, the hand
## brought up to the shoulder. The arm stays against the body in every frame, no empty
## pixel between them (the user's review of 2026-11-20). Where the body stands a row lower
## (every direction but the front) the hands are as high over the ground as from the
## front, so crouched the arms are a row shorter: the one stretched two rows, a short one
## a single row.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand in use, the other]: the hand's lowest pixel next to the body, less the bob; what
## it holds goes there), `a` the way what it holds points (-1: as carried) and `f` whether
## that hand is in front of the body. Made with the review tools in the project library,
## written by tools/art/character/gen_reach_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: the hand lifted, the crouch with the arm stretched down,
## crouched with the arm short, upright with the hand at the shoulder.
const FRAMES := {{
{body}
}}


## Frame `i` of the reach drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
'''
open(out, "w").write(src)
