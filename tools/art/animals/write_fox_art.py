"""Writes tools/art/fox_art.gd (the path given) from the fox's frames (fox_a.py, written by gen.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fox_a as F  # noqa: E402

OUT = sys.argv[1]
STATES = {"idle": F.IDLE, "walk": F.WALK, "run": F.RUN, "hurt": F.HURT, "death": F.DEATH}
DIRS = ["s", "n", "w"]
# The sheet's columns as Creatures reads them (creatures.yaml: frames 20, walk 4, run 4, hurt 4,
# death 4, idle_anim): the rest, the walk, the idle's other frames, the run, the hurt, the death.
ROW = [("idle", 0)] + [("walk", i) for i in range(4)] + [("idle", i) for i in (1, 2, 3)] \
    + [(s, i) for s in ("run", "hurt", "death") for i in range(4)]
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
## The fox, drawn pixel by pixel from the reference the user gave (2026-11-21; the project
## library's survivium-builds/animals/anim/fox/ has it cut into frames and the review of every
## state, anim/src/ the tools that drew from it, HANDOFF.md how), at x0.7 of the reference (the
## user's rule for every animal, 2026-11-21: standing, the side 22×15, the front 9×13, the back 9×16).
## tools/make_sprites.gd saves it as the fox bundle's picture
## (content/animals/fox/sprites/creatures/fox.png), the sheet Creatures draws from.
## The frames as letters (fox_a.py) and this table's writer (write_fox_art.py) are in tools/art/animals/.
##
## Each state has four frames (the user's rule: at most four) for the south (as it comes at the
## camera), the north (as it goes away) and the west; the east is the west mirrored, as the game
## draws it (the reference's east is the west mirrored too). `idle`: the reference's four frames,
## the head dipping a pixel and rising, the ears pricked up, the tail swaying. `walk`: the step,
## the reference's frames 1, 2, 4 and 5 of six (as the boar's, the user's pick B). `run`: the
## gallop, the reference's 1, 2, 4 and 5 of six: gathered, reaching, stretched in the air,
## landing. `hurt`: the flinch at a blow, the reference's four: struck, ducked, pressed down with
## the eyes shut, ducked. `death`: the reference's frames 2, 3, 4 and 6 of six (as the boar's,
## pick A): struck, sinking, dropped, lying dead; the game keeps the last until its carcass is
## taken (the user's rule). Hurt and death are in the fox's own colours, though the reference
## paints them red: the game flashes a struck animal red with a shader (the user, 2026-11-21).
## The pixels the user corrected on the review (2026-11-21: the standing far front paw, walk's
## outline, run's leg, the tail's tip, the shadow by the tail seen from the back), and the outline
## over the tail that the cut to x0.7 takes, are anim/src/fox_gen.py's EDITS, applied to the frames
## it reduces from the reference.
##
## A frame is rows of letters of INK ("." empty), the outline drawn as letters too. The frames of
## a view share one canvas, so the body does not jump between states; its last row is the ground:
## the feet, or seen from the back the tail lying on the ground nearer the camera, below the feet
## as in the reference (the side view's fox lying dead is a row higher than the reference draws
## it, on that ground).

## The colours of the letters: the outline and the darkest (K k O o), the white fur's shade
## (N n G g), the fur from dark to light (D M L H h F), the ears' and the muzzle's tan (t T) and
## the white fur (w V W E).
const INK := {
%s
}
## The cell of each frame in the sheet: as wide as the side view's canvas needs round MIDDLE,
## the back view's canvas tall (its tail hangs below the feet). Each view's canvas stands on the
## cell's last row.
const CELL := Vector2i(%d, %d)
## The column of each view's canvas over the animal's place, the cell's middle (the game puts that
## on it and mirrors the side about it): the side's between the standing feet, where the
## reference's shadow is, so the body keeps its place as it turns about and only the head and the
## tail swap sides; the front's and the back's in the middle.
const MIDDLE := %s
## The sheet's rows in Creatures' views (SIDE, FRONT, BACK): the west drawn, mirrored to face
## right; the south; the north.
const VIEWS := ["w", "s", "n"]
## A row of the sheet in the order Creatures reads it (creatures.yaml: frames 20, walk 4, run 4,
## hurt 4, death 4; the frames left, after the walk, are the idle's): [state, frame].
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
order = "KkOoNnGgDMLHhFtTwVWE"
assert set(order) >= used, used - set(order)
ink = "\n".join('\t"%s": "%s",' % (k, F.PAL[k].lstrip("#")) for k in order if k in used)
row = "\n".join('\t["%s", %d],' % sr for sr in ROW)
# The canvas column over the animal's place: the side's between the stand's feet (the first and the
# last pixel of its lowest row, the near front paw and the near hind paw), where the reference's
# shadow is; the front's and the back's in the middle.
low = [r for r in STATES["idle"]["w"][0] if r.strip(".")][-1]
feet = [x for x, ch in enumerate(low) if ch != "."]
MIDDLE = {"w": (feet[0] + feet[-1] + 1) // 2, "s": len(STATES["idle"]["s"][0][0]) // 2,
          "n": len(STATES["idle"]["n"][0][0]) // 2}
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
