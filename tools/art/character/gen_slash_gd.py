"""Writes tools/art/player_slash_art.gd from a slash data module (work_proto frames: rows
from box row `top`, `bob` with the stand's drop, the hand `r` holding the blade pointing `a`,
`f` in front of the body).
python3 -I gen_slash_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).SLASH
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
COMMENT = {
    "s": "\t# From the front the sword is up beside the head at the right side (the picture's left), at\n\t# the shoulders, then higher; the swing goes down that side and under to the other, its trail\n\t# along the whole arc, the blade about 30 degrees down; the hand stays left of the belly's middle.\n",
    "se": "\t# Turned, as from the front.\n",
    "e": "\t# From the side as from the front: the sword up behind the head, at the shoulders (the hand\n\t# by the chin), then higher; the swing goes down behind and under to the blade forward and\n\t# down, its trail the front's crescent from the raised sword's tip.\n",
    "ne": "\t# From behind it is the front mirrored: up beside the head at the right side, the swing down\n\t# it and on in front of the body, hidden but for the tip past the left side; its trail goes\n\t# behind the body too.\n",
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


def trail_of(fr):
    """The frame's trail (`smear`: rows of the picture's pixels from `at`), cut to what is
    drawn, as GDScript: "trail": {"at": [x, y], "rows": [...]}, or nothing."""
    sm = fr.get("smear")
    if not sm:
        return ""
    pts = [(x, y) for y, r in enumerate(sm["rows"]) for x, c in enumerate(r) if c != "."]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    rows = [r[x0:x1 + 1].ljust(x1 + 1 - x0, ".") for r in sm["rows"][y0:y1 + 1]]
    out = '"trail": {"at": [%d, %d], "rows": [\n' % (sm["at"][0] + x0, sm["at"][1] + y0)
    out += "".join('\t\t\t"%s",\n' % r for r in rows)
    return out + "\t\t]}, "


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
        if "of" in fr:
            extra += ', "of": %s' % ("true" if fr["of"] else "false")
        f = "true" if fr.get("f", True) else "false"
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": {fr["a"]}, "f": {f}{extra}, '.replace("'", "") + trail_of(fr) + '"rows": [')
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The slash, drawn whole as the walk is (WalkArt), a blade held in one hand: four frames
## for each drawn direction (PlayerArt.VIEW), the west ones mirrored (the blade with them,
## so there it is in the left hand). After Puny Characters (Shade, CC0) and the user's
## review (2026-11-20): the sword up beside the head at the shoulders, then raised higher;
## the swing along an arc down that side and under to the other (crouched: the chest's row
## folds away, the legs never move), the blade about 30 degrees to the ground, its trail
## along the whole arc; then standing up again, the blade where it stopped. The hand
## holding it stays on its own side of the body. From the side it is the front's swing
## too (behind the head, down behind and under to the blade in front); from behind the
## front mirrored, the blade and its trail hidden behind the body. The blow lands on the
## third frame, as in the other works. The swords, knives, spears, sickles, slings and
## rods play it (the bows their shot, AimArt); a rod out fishing is held as in the last
## frame (Player.ROD_OUT).
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand holding the blade: its grip, the other: its lowest pixel next to the body], less
## the bob) and how the blade is held: `a` the way it points (PlayerArt.WORKS; 8 is
## PlayerArt.TOWARD, at the viewer, 9 and 10 PlayerArt.LOW and LOW_LEFT, about 30 degrees
## down), `ccw` its edge the other way, `f` in front of the body, `of` false: the other hand
## behind the blade, which comes across in front of it; `trail` the trail a blade leaves
## (PlayerArt.INK o, +, -: rows of the frame's pixels from `at`), which the game draws for an
## item with `trail` over the figure and its outline, or behind them where the blade is
## behind the body (`f` false) (Figure). Made with the review tools in the project library,
## written by tools/art/character/gen_slash_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: up at the shoulders, higher, the swing (crouched), standing.
const FRAMES := {{
{body}
}}


## Frame `i` of the slash drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
'''
open(out, "w").write(src)
