"""Writes tools/art/player_aim_art.gd from an aim data module (aim_e.py: work_proto frames with the
bow drawn for each frame, `draw` {offset from the grip: letter}; rows from box row `top`, `bob` with
the stand's drop, the hand `r` at the bow's grip, `a` the way a thing other than a bow points, `f`
in front of the body).
python3 -I gen_aim_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).AIM
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
COMMENT = {
    "s": "\t# From the front the bow is held across the body, its arrow at the viewer, the grey head\n\t# over the bow's belly: nocked at the hips, drawn up to the chin, loosed (the string straight,\n\t# the hand thrown back), down again. Its mark is above the neck: the bow stays in the middle\n\t# in every build.\n",
    "se": "\t# Turned: the bow down the right side and round under (its lower end is under the frame's\n\t# edge), the arrow along it. The string ends where it meets the limb on the hips' row and\n\t# never runs over the legs; drawn, it goes from the bow's upper end back to the hand at the\n\t# chin, and the upper limb is two pixels wide.\n",
    "e": "\t# From the side the bow is up in front of the face, the arrow along the eyes; drawn, the limb\n\t# is a pixel thicker beside the arrow (its grip); loosed, the near hand is thrown back down.\n",
    "ne": "\t# Turned away the bow is by the body's right side, from under the cheek to the knee: the\n\t# limb's arc and its string, straight between the limb's ends, next to the body. The arrow is\n\t# a line from the near hand up and right through the bow, its grey head past the bow (nocked)\n\t# or at it (drawn, the bow a pixel higher).\n",
    "n": "\t# From behind the body hides the bow: only the drawing arm shows, up at the shoulder, then\n\t# thrown back down by the right side.\n",
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


def bow_of(fr):
    """The bow drawn for the frame as GDScript: "bow": {"at": [x, y] of the rows' corner from the
    grip, "rows": [...]} (ToolArt.INK letters, "." nothing)."""
    pts = fr["draw"]
    if not pts:
        return '"bow": {"at": [0, 0], "rows": []}, '
    x0 = min(p[0] for p in pts)
    x1 = max(p[0] for p in pts)
    y0 = min(p[1] for p in pts)
    y1 = max(p[1] for p in pts)
    rows = ["".join(pts.get((x, y), ".") for x in range(x0, x1 + 1)) for y in range(y0, y1 + 1)]
    s = '"bow": {"at": [%d, %d], "rows": [\n' % (x0, y0)
    s += "".join('\t\t\t"%s",\n' % r for r in rows)
    return s + "\t\t]}, "


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
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": {fr["a"]}, "f": {f}{extra}, "two": true, '.replace("'", "") + bow_of(fr) + '"rows": [')
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The bow's shot (the work `aim`), drawn whole as the walk is (WalkArt), the bow drawn for each
## frame: four frames for each drawn direction (PlayerArt.VIEW), the west ones mirrored (the bow
## with them, so there it is in the left hand). After the Bow Attack of Puny Characters (Shade,
## CC0; the user's pick 2026-11-20): an arrow nocked, the string drawn back, loosed (the string
## straight, the drawing hand thrown back), the bow down again; the arrow leaves on the third
## frame, as every work strikes (Controls). The legs never move. The bows play it.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in the
## letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck` the first
## row of the body), the waistband's row `hips`, the hands' places `hands` ([the bow's mark: the
## hand at its grip, but from the front a place above the neck, which no build moves
## (PlayerArt.pose), so that the bow held across the body stays in the middle; the other hand: its
## lowest pixel next to the body], less the bob), `a` the way a thing
## other than a bow would point (PlayerArt.WORKS; 8 is PlayerArt.TOWARD, at the viewer), `f` the
## bow in front of the body, `two`: the other hand draws the string, so it shows no thing of its
## own, and `bow` the bow as the frame draws it (ToolArt.INK letters: rows from `at`, the offset of
## their corner from the grip), which ToolArt draws for a shape with `bow` instead of turning it.
## The bow has no dark edge of its own where the figure's outline goes (the two made a line two
## pixels thick): its dark letters (K, x) only part its wood from the skin and from its string.
## Made with the review tools in the project library,
## written by tools/art/character/gen_aim_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: nocked, drawn, loosed, down again.
const FRAMES := {{
{body}
}}


## Frame `i` of the aim drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
'''
open(out, "w").write(src)
print("wrote", out)
