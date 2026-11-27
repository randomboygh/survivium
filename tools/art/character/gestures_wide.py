"""Wide frames for the gestures: rows of the box from x = -3 (X0) to 16, so a hand can go
outside the 14-wide box. seg(*parts) builds a row from (x, text) parts; stand(d) is the
stand's rows by box row (stands_data), wide; frame(d, over, top) puts `over` ({row: wide
row or None}) over the stand rows and returns a gestures_proto frame."""
from stands_data import STANDS

X0, W = -3, 20


def seg(*parts):
    r = ["."] * W
    for x, t in parts:
        for i, c in enumerate(t):
            if c != " ":
                r[x - X0 + i] = c
    return "".join(r)


def stand(d):
    drop, rows = STANDS[d]
    return {10 + i: "..." + r + "..." for i, r in enumerate(rows)}


def frame(d, over, bob=None):
    rows = stand(d)
    for y, r in over.items():
        rows[y] = r if r is not None else "." * W
    top = min(y for y in rows if rows[y].strip(".") != "")
    out = [rows.get(y, "." * W) for y in range(top, 18)]
    f = {"top": top, "x0": X0, "rows": out}
    if bob is not None:
        f["bob"] = bob
    return f
