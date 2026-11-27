"""Writes tools/art/<animal>_art.gd for the hand-drawn wild animals (sparrow, squirrel, crow, duck, owl).

    python3 -I write_wild_art.py <module> <out.gd>     (module: sp, sq, cr, dk, ow)

Each view's frames come in groups drawn on canvases of their own (the rest and what is made from it,
the flight, the squirrel's bounds, the death); a group is cut to its frames' union, put on the view's
canvas with its anchor column on MIDDLE and its last row on the ground (the canvas's last row)."""
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eng import flip  # noqa: E402

INFO = {
    "sp": ("sparrow", "The house sparrow", "bird"),
    "cr": ("crow", "The hooded crow", "bird"),
    "dk": ("duck", "The mallard drake", "bird"),
    "ow": ("owl", "The tawny owl", "bird"),
    "sq": ("squirrel", "The red squirrel", "beast"),
}


def bbox(frames):
    xs, ys = [], []
    for f in frames:
        for y, r in enumerate(f):
            for x, c in enumerate(r):
                if c != ".":
                    xs.append(x); ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)


def bottom_mid(f):
    """The middle of the lowest drawn row (the feet)."""
    for y in range(len(f) - 1, -1, -1):
        xs = [x for x, c in enumerate(f[y]) if c != "."]
        if xs:
            return (xs[0] + xs[-1]) / 2.0
    raise ValueError


def group(frames, anchor):
    """Frames of one canvas cut to their union: (cut frames, anchor column in them)."""
    x0, y0, x1, y1 = bbox(frames)
    cut = [[r[x0:x1 + 1] for r in f[y0:y1 + 1]] for f in frames]
    return cut, anchor - x0


def main():
    mod, out = sys.argv[1], sys.argv[2]
    m = importlib.import_module(mod)
    name, title, kind = INFO[mod]
    views = ["w", "s", "n"]
    # state -> view -> (group id); frames grouped by the canvas they were drawn on.
    groups = {d: {} for d in views}   # d -> gid -> (frames list, anchor, [(state, i)])
    states = {}

    def add(d, gid, state, frames, anchor_of):
        g = groups[d].setdefault(gid, [[], None, []])
        for i, f in enumerate(frames):
            g[0].append(f); g[2].append((state, i))
        if g[1] is None:
            g[1] = anchor_of
        states.setdefault(state, {}).setdefault(d, [None] * len(frames))

    for d in views:
        rest = m.IDLE[d][0]
        add(d, "rest", "idle", m.IDLE[d], bottom_mid(rest))
        if kind == "bird":
            add(d, "rest", "walk", m.WALK[d], None)
            fl = {"w": m.SIDE_FLY, "s": m.FS, "n": m.FN}[d]
            if d == "w":
                fa = m.BX + len(m.BODY_W[0]) / 2.0
            else:
                fa = m.FX + len(m.BODY_S[0]) // 2 + 0.0
            add(d, "flight", "flight", fl, fa + 1)
        else:
            if d == "w":
                add(d, "bound", "walk", m.WALK[d], bottom_mid(m.RUN[d][0]))
                add(d, "bound", "run", m.RUN[d], None)
            else:
                add(d, "bound", "walk", m.WALK[d], 7.0)
                add(d, "bound", "run", m.RUN[d], None)
        add(d, "death", "death", [m.DEAD], (bbox([m.DEAD])[0] + bbox([m.DEAD])[2]) / 2.0)
    # Cut each group, place on the view's canvas.
    canvas = {}
    for d in views:
        cut = {}
        for gid, (frames, anchor, uses) in groups[d].items():
            cut[gid] = group(frames, anchor) + (uses,)
        L = max(int(round(a)) for f, a, u in cut.values())
        R = max(len(f[0][0]) - 1 - int(round(a)) for f, a, u in cut.values())
        H = max(len(f[0]) for f, a, u in cut.values())
        W = L + R + 1
        for gid, (fs, a, uses) in cut.items():
            off = L - int(round(a))
            for f, (state, i) in zip(fs, uses):
                rows = ["." * W] * (H - len(f)) + ["." * off + r + "." * (W - off - len(r)) for r in f]
                states[state][d][i] = rows
        canvas[d] = (W, H, L)
    MIDDLE = {d: canvas[d][2] for d in views}
    half = max(max(canvas[d][2] + 1, canvas[d][0] - canvas[d][2]) for d in views)
    cw, ch = 2 * half, max(canvas[d][1] for d in views)
    if kind == "bird":
        order = [("idle", 0)] + [("flight", i) for i in range(4)] + [("idle", i) for i in (1, 2, 3)] \
            + [("walk", i) for i in range(4)] + [("death", 0)]
        rowdoc = ("creatures.yaml: frames 13, walk 4, the wing beats; hop 4, the steps or hops on the "
                  "ground (and the swim); death 1; the frames left, after the wing beats, are the idle's")
    else:
        order = [("idle", 0)] + [("walk", i) for i in range(4)] + [("idle", i) for i in (1, 2, 3)] \
            + [("run", i) for i in range(4)] + [("death", 0)]
        rowdoc = ("creatures.yaml: frames 13, walk 4, run 4, death 1; the frames between the walk "
                  "and the run are the idle's")
    used = sorted({c for s in states.values() for fs in s.values() for f in fs for r in f for c in r} - {"."})
    ink = "\n".join('\t"%s": "%s",' % (k, m.PAL[k].lstrip("#")) for k in used)
    o = []
    o.append("extends RefCounted")
    o.append("## %s, drawn by hand in the style of the animals redrawn from the user's references (thread" % title)
    o.append("## «Нарисовать воробья, белку, ворону и утку», 2026-11-21; approved by the user). The project")
    o.append("## library's survivium-builds/animals/anim/wild4/ has the reviews; the frames are tools/art/animals/")
    o.append("## %s.py, written here by write_wild_art.py. tools/make_sprites.gd saves it as the %s" % (mod, name))
    o.append("## bundle's picture (content/animals/%s/sprites/creatures/%s.png), the sheet Creatures draws from." % (name, name))
    o.append("##")
    o.append("## Every state has at most four frames (the user's rule) for the south (as it comes at the camera),")
    o.append("## the north (as it goes away) and the west; the east is the west mirrored, as the game draws it.")
    o.append("## No frames of hurt (the user's pick: the game flashes a struck animal red on its own frame) and one")
    o.append("## of death, which stays till its carcass is taken.")
    o.append("##")
    o.append("## A frame is rows of letters of INK (\".\" empty), the outline drawn as letters too. The frames of a")
    o.append("## view share one canvas, so the body does not jump between states; its last row is the ground (in")
    o.append("## the air the game lifts the whole sprite).")
    o.append("")
    o.append("## The colours of the letters.")
    o.append("const INK := {\n%s\n}" % ink)
    o.append("## The cell of each frame in the sheet. Each view's canvas stands on the cell's last row.")
    o.append("const CELL := Vector2i(%d, %d)" % (cw, ch))
    o.append("## The column of each view's canvas over the animal's place, the cell's middle (the game puts that")
    o.append("## on it and mirrors the side about it).")
    o.append("const MIDDLE := {%s}" % ", ".join('"%s": %d' % (d, MIDDLE[d]) for d in views))
    o.append("## The sheet's rows in Creatures' views (SIDE, FRONT, BACK): the west drawn, mirrored to face")
    o.append("## right; the south; the north.")
    o.append('const VIEWS := ["w", "s", "n"]')
    o.append("## A row of the sheet in the order Creatures reads it (%s): [state, frame]." % rowdoc)
    o.append("const ROW := [\n%s\n]" % "\n".join('\t["%s", %d],' % sr for sr in order))
    o.append("## state -> the south (s), the north (n), the west (w) -> its frames.")
    body = "const FRAMES := {\n"
    for s in [x for x in ("idle", "flight", "walk", "run", "death") if x in states]:
        body += '\t"%s": {\n' % s
        for d in ("s", "n", "w"):
            body += '\t\t"%s": [\n' % d
            for f in states[s][d]:
                body += "\t\t\t[\n" + "".join('\t\t\t\t"%s",\n' % r for r in f) + "\t\t\t],\n"
            body += "\t\t],\n"
        body += "\t},\n"
    body += "}"
    o.append(body)
    o.append('''

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
	return img''')
    open(out, "w").write("\n".join(o) + "\n")
    print(out, "cell", cw, ch, "middle", MIDDLE)


if __name__ == "__main__":
    main()
