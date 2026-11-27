"""Writes tools/art/boar_art.gd (the path given) from the accepted frames (boar_frames.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boar_07 as F  # noqa: E402

OUT = sys.argv[1]
NAMES = {("idle", 0): "STAND", ("hurt", 1): "FLINCH"}

seen = {}
for s, dd in F.STATES.items():
    for d in F.DIRS:
        for i, f in enumerate(dd[d]):
            seen.setdefault(tuple(f), []).append((s, d, i))
shared = {}
for rows, uses in seen.items():
    if len(uses) > 1:
        s, d, i = uses[0]
        shared[rows] = "%s_%s" % (NAMES.get((s, i), "%s_%d" % (s.upper(), i)), d.upper())

HEAD = '''extends RefCounted
## The boar, drawn pixel by pixel from the reference the user gave (2026-11-20; the project
## library's survivium-builds/animals/anim/ has it cut into frames, the tools that drew from it,
## every review and HANDOFF.md with the user's picks), at x0.7 of the reference (the user's rule
## for every animal, 2026-11-21): the frames accepted at about 0.8 (size B) with two rows and two or
## three columns of each view left out, the same in all its frames (boar_07.py there).
## tools/make_sprites.gd saves it as the boar bundle's picture
## (content/animals/boar/sprites/creatures/boar.png), the sheet Creatures draws from.
## The frames as letters (boar_07.py) and this table's writer (write_art07.py) are in tools/art/animals/.
##
## Each state has four frames (the user's rule: at most four) for the south (as it comes at the
## camera), the north (as it goes away) and the west; the east is the west mirrored, as the game
## draws it. `idle`: standing, then a pixel lower with the ears pricked up, still low with the
## ears out, up again with them drooping (the north's tail swings, the west's tip lifts and drops).
## `walk`: the step, the reference's six frames cut to four (the user's pick B; the west's last
## with the front leg as in A). `run`: the gallop, the reference's frames 1-4 (pick A): gathered,
## reaching, stretched, the back arched. `attack`: the leap with the tusks, the reference's frames
## 2-5 (pick A). `hurt`: the flinch at a blow, standing, squinting (the north ducks its head), the
## eyes shut, squinting; in its own colours, as the game flashes a struck animal red with a shader
## (the user, 2026-11-21). `death`: the reference's frames 2, 3, 4 and 6 (pick A): squinting and
## sunk, dropped on its belly, fallen (a row squashed), lying dead; the game keeps the last until
## its carcass is taken (the user's rule).
##
## A frame is rows of letters of INK ("." empty), the outline drawn as letters too, the feet (or
## the body lying) on the last row. The frames of a state share one canvas; AT is the column of it
## where the standing body's left edge is, when the canvas is wider than the stand (the leap
## reaches out before it, the fallen legs splay past it); the gallop's canvas is a column longer
## at the tail's end.

## The colours of the letters: the fur from dark to light (O D M L H), the mane and the
## brow's dark (K N n h), the snout and mouth (l q p g), the eyes (E W), the tusks (T t u), the
## hooves' soles (G) and the tusks' swipe (S).
const INK := {
%s
}
## The cell of each frame in the sheet: the widest frame (the leap, seen from the side) and the
## tallest (a step's raised frame). Every frame stands on its last row with the standing body in
## the middle.
const CELL := Vector2i(%d, %d)
## The sheet's rows in Creatures' views (SIDE, FRONT, BACK): the west drawn, mirrored to face
## right; the south; the north.
const VIEWS := ["w", "s", "n"]
## A row of the sheet in the order Creatures reads it (creatures.yaml: frames 24, walk 4, attack
## 4, run 4, hurt 4, death 4; the frames left, after the walk, are the idle's): [state, frame].
const ROW := [
%s
]
## Where the standing body's left edge is in a state's canvas wider than the stand.
const AT := {"attack": {"s": 4, "n": 4, "w": 3}, "death": {"s": 1}}

'''

TAIL = '''

## The sheet the game reads: a row for each of VIEWS, a CELL for each frame of ROW.
static func sheet() -> Image:
	var img := Image.create_empty(CELL.x * ROW.size(), CELL.y * VIEWS.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for v in VIEWS.size():
		var d: String = VIEWS[v]
		var stand: String = FRAMES.idle[d][0][0]
		var x0 := (CELL.x - stand.length()) / 2
		for c in ROW.size():
			var state: String = ROW[c][0]
			var rows: Array = FRAMES[state][d][ROW[c][1]]
			var left: int = x0 - AT.get(state, {}).get(d, 0)
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
order = "ODMLHKNnhlqpgEWTtuGS"
assert set(order) >= used, used - set(order)
ink = "\n".join('\t"%s": "%s",' % (k, F.PAL[k].lstrip("#")) for k in order if k in used)
row = "\n".join('\t["%s", %d],' % sr for sr in F.ROW)
out = HEAD % (ink, F.CELL[0], F.CELL[1], row)
for rows, name in shared.items():
    s, d, i = seen[rows][0]
    out += "## %s's frame %d of `%s`, used again (see FRAMES).\n" % ({"s": "The south", "n": "The north", "w": "The west"}[d], i, s)
    out += "const %s := %s\n" % (name, frame(rows, 0))
out += "## state -> the south (s), the north (n), the west (w) -> its frames.\nconst FRAMES := {\n"
for s, dd in F.STATES.items():
    out += '\t"%s": {\n' % s
    for d in F.DIRS:
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
