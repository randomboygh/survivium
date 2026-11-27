"""Writes tools/art/grouse_art.gd (the path given) from the grouse's frames (grouse_a.py, written by grouse_gen.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grouse_a as F  # noqa: E402

OUT = sys.argv[1]
STATES = {"idle": F.IDLE, "flight": F.FLIGHT, "walk": F.WALK, "hurt": F.HURT, "death": F.DEATH}
DIRS = ["s", "n", "w"]
# The sheet's columns as Creatures reads them (creatures.yaml: frames 20, walk 4 (a flyer's wing
# beats), hop 4 with `walks` (its walk on the ground), hurt 4, death 4, idle_anim): the rest, the
# flight, the idle's other frames, the walk, the hurt, the death.
ROW = [("idle", 0)] + [("flight", i) for i in range(4)] + [("idle", i) for i in (1, 2, 3)] \
    + [(s, i) for s in ("walk", "hurt", "death") for i in range(4)]
NAMES = {("idle", 0): "STAND", ("hurt", 1): "FLINCH"}

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
## The black grouse, drawn pixel by pixel from the reference the user gave (2026-11-21; the
## project library's survivium-builds/animals/anim/grouse/ has it cut into frames and the review
## of every state, anim/src/ the tools that drew from it, HANDOFF.md how), at about 0.7 of the
## reference (the user's rule, 2026-11-21: every animal at 0.7 of its reference).
## tools/make_sprites.gd saves it as the grouse
## bundle's picture (content/animals/grouse/sprites/creatures/grouse.png), the sheet Creatures
## draws from.
## The frames as letters (grouse_a.py) and this table's writer (write_grouse_art.py) are in tools/art/animals/.
##
## Each state has four frames (the user's rule: at most four) for the south (as it comes at the
## camera), the north (as it goes away) and the west; the east is the west mirrored, as the game
## draws it (the reference's east is the west mirrored too). `idle`: the reference's four frames.
## `flight`: the wing beat, the reference's frames 1, 3, 4 and 6 of six (wings up, level, down,
## rising), played in the air. `walk`: the step on the ground, the reference's 1, 3, 4 and 6 of
## six. `hurt`: the flinch at a blow, the reference's four. `death`: the reference's frames 2, 3,
## 4 and 6 of six; the game keeps the last until its carcass is taken (the user's rule). Hurt and
## death are in the grouse's own colours, though the reference paints them red: the game flashes
## a struck animal red with a shader.
##
## A frame is rows of letters of INK ("." empty), the outline drawn as letters too. The frames of
## a view share one canvas, so the body does not jump between states; its last row is the ground
## (the flight's lowest feathers too: in the air the game lifts the whole sprite).

## The colours of the letters: the outline and the darkest (K k), the black feathers from dark
## to light (N n G), the blue sheen from dark to light (B b C c A), the red brow from dark to
## light (r R P Q), the grey and white of the wings and the tail (S s w V E e).
const INK := {
%s
}
## The cell of each frame in the sheet: as wide as the widest canvas needs round MIDDLE, as tall
## as the tallest (the wings raised in flight). Each view's canvas stands on the cell's last row.
const CELL := Vector2i(%d, %d)
## The column of each view's canvas over the animal's place, the cell's middle (the game puts that
## on it and mirrors the side about it): the side's over the standing feet, so the body keeps its
## place as it turns about and only the head and the tail swap sides; the front's and the back's
## in the middle.
const MIDDLE := %s
## The sheet's rows in Creatures' views (SIDE, FRONT, BACK): the west drawn, mirrored to face
## right; the south; the north.
const VIEWS := ["w", "s", "n"]
## A row of the sheet in the order Creatures reads it (creatures.yaml: frames 20, walk 4, the
## wing beats; hop 4 with `walks`, the steps on the ground; hurt 4, death 4; the frames left,
## after the wing beats, are the idle's): [state, frame].
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
order = "KkNnGBbCcArRPQSswVEe"
assert set(order) >= used, used - set(order)
ink = "\n".join('\t"%s": "%s",' % (k, F.PAL[k].lstrip("#")) for k in order if k in used)
row = "\n".join('\t["%s", %d],' % sr for sr in ROW)
# The canvas column over the animal's place: the side's over the stand's feet (columns 8-10), the
# front's and the back's between their feet.
MIDDLE = {"w": 9, "s": 10, "n": 11}
half = max(max(MIDDLE[d], len(STATES["idle"][d][0][0]) - MIDDLE[d]) for d in DIRS)
cw = 2 * half
chh = max(len(STATES["idle"][d][0]) for d in DIRS)
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
