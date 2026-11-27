"""Writes tools/art/player_mow_art.gd from a mow data module (mow_c.py: work_proto frames made with
mow_canvas.F: rows from box row `top`, `bob` with the stand's drop, the scythe drawn for each
frame, `draw` {offset from the hand `r`: letter}, `f` in front of the body, `smear` the trail).
The scythe's mark is the hand `r` from the side; in the other views a place above the neck, which
no build moves (PlayerArt.pose), within the held cell's reach of every pixel of the scythe.
python3 -I gen_mow_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).MOW
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
REACH = 12  # a held thing's cell is 25 pixels square, its grip in the middle (player.yaml `held`)
COMMENT = {
    "s": "\t# From the front the scythe is at the right side (the picture's left), its far end up and the\n\t# blade hanging to the ground, both hands on the snath across the belly, its near end behind\n\t# the forearm that crosses the chest; lifted, the torso after it; then at the other side, the\n\t# trail a shallow arc from where it was to the blade's point, over the feet.\n",
    "se": "\t# Turned, as from the front.\n",
    "e": "\t# From the side the scythe is drawn back behind the mower and swept round to the front; the\n\t# snath's near end shows past the fists, over the waistband and then on the hip under the arm;\n\t# the trail goes the same way, over the feet.\n",
    "ne": "\t# Turned away it goes the other way, from the right side to the left, where the left hand\n\t# holds it and the body hides the right, as it hides the snath's near end; the trail lies on\n\t# the ground past the mower, behind the figure.\n",
    "n": "\t# From behind, as turned away.\n",
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


def trimmed(fr):
    """The frame without its empty rows at the top."""
    fr = dict(fr)
    rows = list(fr["rows"])
    top = fr["top"]
    while rows and set(rows[0]) == {"."}:
        rows.pop(0)
        top += 1
    fr["rows"], fr["top"] = rows, top
    return fr


def mark_of(d, fr, neck):
    """The scythe's mark in the box: the hand from the side, else above the neck."""
    pts = [(fr["r"][0] + p[0], fr["r"][1] + p[1]) for p in fr["draw"]]
    if d == "e":
        m = list(fr["r"])
    else:
        lo, hi = max(p[0] for p in pts) - REACH, min(p[0] for p in pts) + REACH
        lo, hi = max(lo, 0), min(hi, 13)
        assert lo <= hi, (d, lo, hi)
        m = [min(range(lo, hi + 1), key=lambda v: abs(v - 6.5)), neck - 1]
    assert all(abs(p[0] - m[0]) <= REACH and abs(p[1] - m[1]) <= REACH for p in pts), (d, m)
    return m


def scythe_of(fr, mark):
    """The scythe drawn for the frame as GDScript: "scythe": {"at": [x, y] of the rows' corner from
    the mark, "rows": [...]} (ToolArt.INK letters, "." nothing)."""
    pts = {(fr["r"][0] + p[0] - mark[0], fr["r"][1] + p[1] - mark[1]): c for p, c in fr["draw"].items()}
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    rows = ["".join(pts.get((x, y), ".") for x in range(x0, x1 + 1)) for y in range(y0, y1 + 1)]
    s = '"scythe": {"at": [%d, %d], "rows": [\n' % (x0, y0)
    s += "".join('\t\t\t"%s",\n' % r for r in rows)
    return s + "\t\t]}, "


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
        fr = trimmed(fr)
        assert fr["top"] + len(fr["rows"]) == 18, (d, fr)
        bob = fr["bob"]
        hips = first(fr, lambda c: c in "Uu")
        neck = first(fr, lambda c: c not in ".456789")
        l = other_hand(fr)
        l = [l[0], l[1] - bob] if l else REST[d]
        m = mark_of(d, fr, neck)
        r = [m[0], m[1] - bob]
        assert r != l, (d, r, l)
        extra = ', "ccw": true' if fr.get("ccw") else ""
        if "of" in fr:
            extra += ', "of": %s' % ("true" if fr["of"] else "false")
        f = "true" if fr.get("f", True) else "false"
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": {fr["a"]}, "f": {f}{extra}, "two": true, '.replace("'", "") + scythe_of(fr, m) + trail_of(fr) + '"rows": [')
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The mow (the work `mow`: a scythe in two hands), drawn whole as the walk is (WalkArt), the
## scythe drawn for each frame: four frames for each drawn direction (PlayerArt.VIEW), the west
## ones mirrored (the scythe with them). After the user's review of 2026-11-20: the blade hangs
## down from the snath's far end, which is held up for it (a frame has no room under the feet),
## the trail runs in front of the mower, and the hands hold the snath at its middle, not at its
## end (its near end comes out two pixels past them). 1 the scythe at the mower's right side,
## the blade's point at the ground; 2 its far end up, the torso after it; 3 crouched, the scythe
## at the other side, its trail along the ground between (the strike, as every work's third
## frame); 4 standing, the scythe where it stopped. The legs never move. The scythes play it.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in the
## letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck` the first
## row of the body), the waistband's row `hips`, the hands' places `hands` ([the scythe's mark:
## from the side the hand on the snath, in the other views a place above the neck, which no
## build moves (PlayerArt.pose), so that a wider body's hands slide along the snath and the
## blade stays inside the frame; the other hand: its lowest pixel next to the body], less the
## bob), `a` the way a thing other than a scythe would point (PlayerArt.WORKS), `f` the scythe
## in front of the body, `two`: the other hand is on the snath too, so it shows no thing of its
## own, `scythe` the scythe as the frame draws it (ToolArt.INK letters: rows from `at`, the
## offset of their corner from the mark), which ToolArt draws for a shape with `scythe` instead
## of turning it, and on the third frame `trail` (its rows in the frame's pixels from `at`, the
## letters o + - of PlayerArt.INK), which the game draws for an item with `trail` over the
## figure and its outline, or behind them where the scythe is behind the body (`f` false)
## (Figure). Made with the review tools in the project library,
## written by tools/art/character/gen_mow_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: at the side, back and up, the sweep (crouched), standing.
const FRAMES := {{
{body}
}}


## Frame `i` of the mow drawn in direction `dir` (a drawn one), or {{}}.
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
