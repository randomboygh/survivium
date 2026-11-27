"""gen_row_gd.py <data module> <out .gd>: writes tools/art/player_row_art.gd from a rowing data module
(ROW: by drawn direction, four frames {bob, top, rows} with rows from box row `top` down to the feet)."""
import sys as _s
_s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib
import sys

data = importlib.import_module(sys.argv[1])
out = sys.argv[2]
DIRS = ["s", "se", "e", "ne", "n"]
# The waistband's row of the sit each direction keeps (PlayerArt BODY hips, two rows down), and the
# waistband itself where it is on the last row, under the feet (BODY's).
HIPS = {"s": 16, "se": 17, "e": 16, "ne": 17, "n": 17}
# Where a hand not drawn is (less the bob): from the side the far one behind the body, by the near
# one; from behind turned a little the far one on its handle's end behind the head (the oar's
# inner end in the game's capture, a frame each).
REST = {"s": ([3, 14], [10, 14]), "se": ([3, 14], [10, 14]), "e": ([9, 14], [8, 14]),
        "ne": ([10, 14], [[3, 5], [4, 3], [4, 4], [3, 5]]), "n": ([10, 14], [3, 14])}
WAIST = {"se": ".....UUuUU....", "ne": ".....uuuuu....", "n": "....uuuuuu...."}
COMMENT = {
    "s": "\t# From the front the fists hold the handles' ends by the chin, an outline between;\n"
         "\t# below the chest the hull hides the rest. The fists go with the body as a build widens it.\n",
    "se": "\t# Turned a little: the near fist by the shoulder, the far one out from behind the head\n"
          "\t# on its oar (over the neck: it stays put as the body widens).\n",
    "e": "\t# From the side the near fist goes round in front of the vessel's bench, clear of the\n"
         "\t# chin: by the chest, forward and down, back, back up.\n",
    "ne": "\t# The back turned a little: the near fist at the shoulder, then up and out on its\n"
          "\t# handle; the far one is behind the head, its arm forward behind the body.\n",
    "n": "\t# From behind the fists show by the head on the handles' ends, the arms up from the\n"
         "\t# shoulders.\n",
}


def hand(rows, top, digits, center):
    """The fist's lowest pixel next to the body: the fist is two pixels wide, an arm in the hand's
    digits under it (raised, from behind) one."""
    pts = [(x, top + y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in digits]
    if not pts:
        return None
    wide = [y for y in {p[1] for p in pts} if sum(1 for p in pts if p[1] == y) >= 2]
    low = max(wide) if wide else max(p[1] for p in pts)
    xs = [p[0] for p in pts if p[1] == low]
    return [min(xs, key=lambda v: abs(v - center)), low]


lines = []
for d in DIRS:
    if d in COMMENT:
        lines.append(COMMENT[d].rstrip("\n"))
    lines.append(f'\t"{d}": [')
    for k, f in enumerate(data.ROW[d]):
        rows = list(f["rows"])
        top = f.get("top", 10)
        while rows and rows[0].replace(".", "") == "":
            rows.pop(0)
            top += 1
        assert top + len(rows) == 18, (d, top, len(rows))
        assert all(len(r) == 14 for r in rows), d
        # The legs come from the sit (PlayerArt.frame_letters): the last row keeps only the hands
        # and, where the waistband is on it (BODY hips 15), the waistband the feet go over.
        last = "".join(c if c in "456789" else "." for c in rows[-1])
        if d in WAIST:
            last = "".join(c if c != "." else w for c, w in zip(last, WAIST[d]))
        rows[-1] = last
        bob = f["bob"]
        # From the front the fists by the chin are the body's first rows; elsewhere the body
        # starts at the neck, under the head, and what is over it stays put.
        neck = top if d == "s" else 11 + bob
        r = hand(rows, top, "456", 6.5)
        l = hand(rows, top, "789", 6.5)
        hands = []
        for h, rest in zip((r, l), REST[d]):
            if isinstance(rest[0], list):
                rest = rest[k]
            hands.append([h[0], h[1] - bob] if h else rest)
        lines.append(f'\t\t{{"bob": {bob}, "top": {top}, "neck": {neck}, "hips": {HIPS[d]}, '
                     f'"hands": [[{hands[0][0]}, {hands[0][1]}], [{hands[1][0]}, {hands[1][1]}]], "rows": [')
        for row in rows:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The rowing, drawn whole as the walk is (WalkArt): four frames for each drawn direction
## (PlayerArt.VIEW), the west ones mirrored, played in time with the oars (Boats.stroke).
## A push stroke, as the oars swing for a body facing the bow: the catch (the fists near the
## body, the blades in the water), pushed forward (the body leaning a row down), the blades
## lifted (the fists low), back. The body sits as in the sit (the legs never move, so the
## two follow each other without a jump) and its fists stay on the handles' ends, where the
## oars have no grip of their own (Boats._oar), so they show over the handles: after the
## user's review (2026-11-20), a couple of pixels of each hand in sight wherever the hull
## and the bench leave them.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body: what is over it, a fist by the head, stays put in every
## form), the waistband's row `hips` and the hands' places `hands` ([right, left], the
## hand's lowest pixel next to the body, less the bob). The legs are not in `rows`: they
## are the sit's (PlayerArt.frame_letters), the feet over the waistband where it is on the
## last row. Made with the review tools in the project library,
## written by tools/art/character/gen_row_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: the catch, pushed, the blades lifted, back.
const FRAMES := {{
{body}
}}


## Frame `i` of the rowing drawn in direction `dir` (a drawn one), or {{}}.
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
