"""Writes tools/art/bear_art.gd (the path given) from the bear's frames (bear_x1.py, written by x1.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bear_x1 as F  # noqa: E402

OUT = sys.argv[1]
PAL = {"K": "1e0d05", "D": "2f180e", "M": "472c19", "L": "5b3c26", "s": "aa7742", "t": "cfa250", "u": "e4b35b", "W": "ffffff"}
# The walk is the reference's run played slower (the user's pick 2A); the hurt is death 0, 1, 0 and the
# stand (3B).
HURT = {d: [F.DEAD[d][0], F.DEAD[d][1], F.DEAD[d][0], F.IDLE[d][0]] for d in "wsn"}
STATES = {"idle": F.IDLE, "walk": F.RUN, "attack": F.ATTACK, "run": F.RUN, "hurt": HURT, "death": F.DEAD}
DIRS = ["s", "n", "w"]
# The sheet's columns as Creatures reads them (creatures.yaml: frames 20, walk 4, run 4, hurt 4,
# death 4, idle_anim): the rest, the walk, the idle's other frames, the run, the hurt, the death.
ROW = [("idle", 0)] + [("walk", i) for i in range(4)] + [("idle", i) for i in (1, 2, 3)] \
    + [(s, i) for s in ("attack", "run", "hurt", "death") for i in range(4)]
NAMES = {("idle", 0): "STAND", ("walk", 0): "STEP_0", ("walk", 1): "STEP_1", ("walk", 2): "STEP_2",
         ("walk", 3): "STEP_3", ("hurt", 0): "STRUCK", ("hurt", 1): "FLINCH"}

seen = {}
for s, dd in STATES.items():
    for d in DIRS:
        for i, f in enumerate(dd[d]):
            seen.setdefault(tuple(f), []).append((s, d, i))
shared = {}
for rows, uses in seen.items():
    if len(uses) > 1:
        s, d, i = uses[0]
        shared[rows] = "%s_%s" % (NAMES.get((s, i), "%s_%d" % (s.upper(), i)), d.upper())

HEAD = '''extends RefCounted
## The bear, from the reference the user gave (the project library's
## survivium-builds/animals/anim/bear/: bear-reference.gif, a sheet of four directions with the
## idle, the attack, the run and the death in four frames each; src/ the tools, the reviews beside),
## at x1, the reference's own size (the user's pick, 2026-11-22: standing, the side 37x22, the
## front 17x23). The only change from the reference: one outer outline. Its inner lines (round the
## head and the muzzle, the ears, between the legs) are the dark fur (D); the nose, the mouth and
## the side's eye stay dark (K). The far legs are the darker fur, as the reference draws them.
## tools/make_sprites.gd saves it as the bear bundle's picture
## (content/animals/bear/sprites/creatures/bear.png), the sheet Creatures draws from.
## The frames as letters (bear_x1.py) and this table's writer (write_bear_art.py) are in tools/art/animals/.
##
## Each state has four frames for the south (as it comes at the camera), the north (as it goes
## away) and the west; the east is the west mirrored, as the game draws it (the reference's east
## is exactly the west mirrored). `idle`, `attack` (a forepaw's blow with a white swipe of the
## claws), `run` and `death` are the reference's four. The reference has no walk and no hurt (the
## user's picks, 2026-11-22): `walk` is the run's four frames played slower (2A); `hurt` is the
## flinch, the death's frames 0, 1, 0 and the stand (3B). The game keeps the last frame of `death`
## until the carcass is taken.
##
## A frame is rows of letters of INK ("." empty), the outline drawn as letters too. The frames of
## a view share one canvas (the reference's cell cut to every frame of that view: the run's head
## and the attack's swipe reach past the stand), so the body does not jump between states; its
## last row is the ground.

## The colours of the letters (the reference's eight): the outline, the nose and the mouth (K),
## the fur from dark to light (D M L), the muzzle from dark to light (s t u) and the claws' swipe (W).
const INK := {
%s
}
## The cell of each frame in the sheet: as wide as the side view's canvas needs round MIDDLE, as
## tall as the tallest canvas. Each view's canvas stands on the cell's last row.
const CELL := Vector2i(%d, %d)
## The column of each view's canvas over the animal's place, the cell's middle (the game puts that
## on it and mirrors the side about it): the side's between the standing feet, where the
## body keeps its place as it turns about and only the head and the rump swap sides; the front's
## and the back's in the middle.
const MIDDLE := %s
## The sheet's rows in Creatures' views (SIDE, FRONT, BACK): the west drawn, mirrored to face
## right; the south; the north.
const VIEWS := ["w", "s", "n"]
## A row of the sheet in the order Creatures reads it (creatures.yaml: frames 24, walk 4, attack 4,
## run 4, hurt 4, death 4; the frames left, after the walk, are the idle's): [state, frame].
const ROW := [
%s
]

'''

TAIL = '''

## The sheet the game reads: a row for each of VIEWS, a CELL for each frame of ROW.
static func sheet() -> Image:
	var img := Image.create_empty(CELL.x * ROW.size(), CELL.y * VIEWS.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v in VIEWS.size():
		var d: String = VIEWS[v]
		for c in ROW.size():
			var rows: Array = FRAMES[ROW[c][0]][d][ROW[c][1]]
			var left: int = CELL.x / 2 - MIDDLE[d]
			var top := CELL.y - rows.size()
			for y in rows.size():
				var r: String = rows[y]
				for x in r.length():
					if r[x] == ".":
						continue
					# The west is drawn, the sheet's side faces right.
					var px: int = CELL.x - 1 - (left + x) if d == "w" else left + x
					img.set_pixel(c * CELL.x + px, v * CELL.y + top + y, Color.html(INK[r[x]]))
	return img
'''


def frame(rows, ind):
    pad = "\t" * ind
    return "[\n" + "".join('%s\t"%s",\n' % (pad, r) for r in rows) + pad + "]"


used = set()
for rows in seen:
    for r in rows:
        used |= set(r)
used.discard(".")
order = "KDMLstuW"
assert set(order) >= used, used - set(order)
ink = "\n".join('\t"%s": "%s",' % (k, PAL[k].lstrip("#")) for k in order if k in used)
row = "\n".join('\t["%s", %d],' % sr for sr in ROW)
# The canvas column over the animal's place: the side's between the stand's feet (the first and the
# last pixel of its lowest row, the front paw and the hind paw); the front's and the back's in the
# middle of the stand.
low = [r for r in STATES["idle"]["w"][0] if r.strip(".")][-1]
feet = [x for x, ch in enumerate(low) if ch != "."]
def mid(f):
    xs = [x for r in f for x, ch in enumerate(r) if ch != "."]
    return (min(xs) + max(xs) + 1) // 2


MIDDLE = {"w": (feet[0] + feet[-1] + 1) // 2, "s": mid(STATES["idle"]["s"][0]), "n": mid(STATES["idle"]["n"][0])}
half = max(max(MIDDLE[d], len(STATES["idle"][d][0][0]) - MIDDLE[d]) for d in DIRS)
cw = 2 * half
chh = max(len(STATES["idle"][d][0]) for d in DIRS)
assert all(len(f) <= chh for s in STATES.values() for d in DIRS for f in s[d])
for s, dd in STATES.items():
    for d in DIRS:
        for f in dd[d]:
            assert len(f) == len(dd[d][0]) and all(len(r) == len(f[0]) for r in f), (s, d)
middle = "{%s}" % ", ".join('"%s": %d' % (d, MIDDLE[d]) for d in ["w", "s", "n"])
out = HEAD % (ink, cw, chh, middle, row)
for rows, name in shared.items():
    s, d, i = seen[rows][0]
    others = ", ".join("%s %d" % (s2, i2) for s2, d2, i2 in seen[rows][1:])
    out += "## %s's frame %d of `%s`, again as %s.\n" % (
        {"s": "The south", "n": "The north", "w": "The west"}[d], i, s, others)
    out += "const %s := %s\n" % (name, frame(rows, 0))
out += "## state -> the south (s), the north (n), the west (w) -> its frames.\nconst FRAMES := {\n"
for s, dd in STATES.items():
    out += '\t"%s": {\n' % s
    for d in DIRS:
        out += '\t\t"%s": [\n' % d
        for f in dd[d]:
            t = tuple(f)
            out += "\t\t\t%s,\n" % (shared[t] if t in shared else frame(f, 3))
        out += "\t\t],\n"
    out += "\t},\n"
out += "}\n"
out += TAIL
open(OUT, "w").write(out)
print(OUT, len(out), "bytes;", len(shared), "shared:", sorted(shared.values()))
