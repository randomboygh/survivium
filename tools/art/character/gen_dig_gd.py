"""Writes tools/art/player_dig_art.gd from a dig data module (work_proto frames: rows from
box row `top`, `bob` with the stand's drop, the hand `r` holding the shovel pointing `a`,
held `slide` pixels up its shaft).
python3 -I gen_dig_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).DIG
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
COMMENT = {
    "s": "\t# From the front the shovel is at the right side (the picture's left), the blade at the\n\t# viewer (PlayerArt.TOWARD), beside the feet with the outline between.\n",
    "e": "\t# From the side, the turned views and from behind the blade goes in by the right foot,\n\t# down and forward; from behind the shovel is behind the body.\n",
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
        assert fr["top"] + len(fr["rows"]) == 18, (d, fr)
        bob = fr["bob"]
        l = other_hand(fr)
        l = [l[0], l[1] - bob] if l else REST[d]
        r = [fr["r"][0], fr["r"][1] - bob]
        hips = first(fr, lambda c: c in "Uu")
        neck = first(fr, lambda c: c not in ".456789")
        extra = ', "ccw": true' if fr.get("ccw") else ""
        f = "true" if fr.get("f", True) else "false"
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": {fr["a"]}, "slide": {fr.get("slide", 0)}, "f": {f}{extra}, "rows": ['.replace("'", ""))
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The dig, drawn whole as the walk is (WalkArt), the shovel held: four frames for each
## drawn direction (PlayerArt.VIEW), the west ones mirrored (the shovel with them, so there
## it is in the left hand). The hand holds the shaft halfway, the end of the shaft behind
## it: three frames of the blade going into the earth from the feet's level, a pixel
## deeper each (crouched on the third: the chest's row folds away, the legs never move),
## then the toss (upright, the blade up and forward).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand holding the shovel: its grip, the other: its lowest pixel next to the body], less
## the bob) and how the shovel is held: `a` the way it points (PlayerArt.WORKS), `slide`
## how far up its length the hand holds it (ToolArt.turned), `ccw` its edge the other way,
## `f` in front of the body. Made with the review tools in the project library,
## written by tools/art/character/gen_dig_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: the blade at the feet's level, a pixel deeper, two
## deeper (crouched), the toss.
const FRAMES := {{
{body}
}}


## Frame `i` of the dig drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
'''
open(out, "w").write(src)
