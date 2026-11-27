"""The boar at x0.7 of the reference (the user's rule, 2026-11-21): the accepted frames at about 0.8
(boar_frames.py) with rows and columns left out, the same in every frame of a view (a nearest resize
of 0.875 with its seams placed by hand off the eyes, tusks and hooves). Rows count from the ground
(the frame's last row), columns from the standing body's left edge (AT)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import boar_frames as B  # noqa: E402

ROWS = {"s": [2, 10], "n": [2, 9], "w": [2, 10]}
COLS = {"s": [2, 12], "n": [2, 12], "w": [5, 12, 15]}
ROWS = {d: [int(x) for x in os.environ.get("R" + d, ",".join(map(str, v))).split(",")] for d, v in ROWS.items()}
COLS = {d: [int(x) for x in os.environ.get("C" + d, ",".join(map(str, v))).split(",")] for d, v in COLS.items()}

PAL = B.PAL
DIRS = B.DIRS
ROW = B.ROW
VIEWS = B.VIEWS
AT = B.AT


def cut(rows, d, at):
    n = len(rows)
    return ["".join(ch for x, ch in enumerate(r) if (x - at) not in COLS[d]) for y, r in enumerate(rows) if (n - 1 - y) not in ROWS[d]]


STATES = {s: {d: [cut(f, d, AT.get(s, {}).get(d, 0)) for f in dd[d]] for d in DIRS} for s, dd in B.STATES.items()}
CELL = (max(len(f[0]) for dd in STATES.values() for d in DIRS for f in dd[d]) + 0, max(len(f) for dd in STATES.values() for d in DIRS for f in dd[d]))


def sheet():
    from PIL import Image
    W, H = CELL
    im = Image.new("RGBA", (W * len(ROW), H * len(VIEWS)), (0, 0, 0, 0))
    for v, d in enumerate(VIEWS):
        x0 = (W - len(STATES["idle"][d][0][0])) // 2
        for c, (s, i) in enumerate(ROW):
            rows = STATES[s][d][i]
            left = x0 - AT.get(s, {}).get(d, 0)
            top = H - len(rows)
            for y, r in enumerate(rows):
                for x, ch in enumerate(r):
                    if ch != ".":
                        px = left + x
                        if d == "w":
                            px = W - 1 - px
                        h = PAL[ch].lstrip("#")
                        im.putpixel((c * W + px, v * H + top + y), tuple(int(h[k:k + 2], 16) for k in (0, 2, 4)) + (255,))
    return im
