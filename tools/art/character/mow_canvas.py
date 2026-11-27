"""Frames of the mow written as one picture each: rows of 30 letters, box x -8..21 (the box's 14
columns are letters 8..21), from box row `top` down to row 17. Body letters (PlayerArt.INK: c C V
k U u T t B b K m L S s, the hands' digits 4-9) go to the frame's `rows`; the scythe's (ToolArt.INK:
d w W q a A) to its `draw` ({offset from the grip: letter}); a hand over the shaft is `$` (4), `%`
(5), `&` (7), `*` (8): the hand's digit with the shaft's `w` under it. `grip`: the working hand's
mark in the box. `smear`: the trail, rows of o + - from the image pixel `at`."""
import mow_shapes  # registers the scythe's turned shape in work_proto
import work_proto
from PIL import Image
import proto


def _render(q, d, fr, tool=None, head_col=0):
    """work_proto.render, with the trail drawn down to the frame's last row as the game draws it
    (PlayerArt.layer: only the top row and the side columns stay clear)."""
    body, thing, fists = work_proto.parts(q, d, fr, tool, head_col)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    layers = ([thing, body] if not fr.get("f", True) else [body, thing]) + [fists]
    mode = __import__("os").environ.get("SMEAR", "free")
    trail = work_proto.smear_pixels(fr)
    if trail and mode == "outlined":
        layers.insert(len(layers) - 1, trail)
    for layer in layers:
        for at, c in layer.items():
            if 0 <= at[0] < 32 and 0 <= at[1] < 32:
                out.putpixel(at, c)
    out = proto.outline(out)
    if trail and mode == "free":
        behind = not fr.get("f", True)
        for at, c in trail.items():
            if 1 <= at[0] < 31 and 1 <= at[1] < 32:
                if behind and out.getpixel(at)[3] > 0:
                    continue
                out.alpha_composite(Image.new("RGBA", (1, 1), c), at)
    return out


work_proto.render = _render

BODY = set("cCVkUuTtBbKmLSs456789")
THING = set("dwWqaAgDxj")
OVER = {"$": "4", "%": "5", "&": "7", "*": "8", "^": "6", "~": "9"}
X0 = -8
WIDTH = 30
EMPTY = "." * 14


def F(bob, top, canvas, grip, a=8, f=True, of=None, smear=None, under="w", two=True, ccw=False, base=None):
    """`base`: the body's rows without the arms (14 letters each, the canvas's last rows: the
    canvas may be taller), which the canvas's body letters and hands go over; the scythe's
    letters then leave the body under them whole."""
    assert top + len(canvas) == 18, (top, len(canvas))
    rows = [EMPTY] * len(canvas)
    if base:
        assert len(base) <= len(canvas), (len(base), len(canvas))
        rows[len(canvas) - len(base):] = list(base)
    draw = {}
    for j, line in enumerate(canvas):
        assert len(line) == WIDTH, (j, len(line), line)
        row = list(rows[j])
        for i, ch in enumerate(line):
            x, y = X0 + i, top + j
            b = None
            if ch in OVER:
                b = OVER[ch]
                draw[(x - grip[0], y - grip[1])] = under
            elif ch in BODY:
                b = ch
            elif ch in THING:
                draw[(x - grip[0], y - grip[1])] = ch
            elif ch == "_":
                b = "."  # nothing of the body here (takes a pixel of the base away)
            else:
                assert ch == ".", (ch, line)
            if b is not None:
                assert 0 <= x <= 13, ("body pixel outside the box", x, y, line)
                row[x] = b
        rows[j] = "".join(row)
    for (x, y) in draw:
        assert 1 <= 9 + grip[0] + x <= 30 and 1 <= 14 + grip[1] + y <= 30, ("the thing leaves the frame", x + grip[0], y + grip[1])
    fr = {"bob": bob, "top": top, "r": [grip[0], grip[1]], "a": a, "f": f, "tool": "scythe",
          "rows": rows, "draw": draw, "two": two}
    if ccw:
        fr["ccw"] = True
    if of is not None:
        fr["of"] = of
    if smear:
        fr["smear"] = smear
    return fr


def moved(rows, which, dx):
    """`rows` with the rows numbered `which` moved `dx` pixels to the right."""
    out = list(rows)
    for i in which:
        r = rows[i]
        out[i] = ("." * dx + r[:len(r) - dx]) if dx > 0 else (r[-dx:] + "." * -dx)
    return out


def smear(top, canvas):
    """A trail written on the same canvas (box x -8..21 from box row `top`): {"at": image pixel
    of its corner, "rows"} cut to what is drawn."""
    pts = [(i, j) for j, line in enumerate(canvas) for i, ch in enumerate(line) if ch != "."]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    rows = [canvas[j][x0:x1 + 1] for j in range(y0, y1 + 1)]
    return {"at": [9 + X0 + x0, 14 + top + y0], "rows": rows}
