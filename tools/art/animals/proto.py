"""The animals' frames for the review tools: a frame of a data module drawn from its letters, or a
frame of a reference cut by ref_cut.py.

A data module (boar_a.py) has `PAL` (a letter -> "#rrggbb"; "." is empty) and, per drawing, a dict
direction -> frames, a frame a list of rows of letters (the outline is drawn as letters too, as the
references draw it), the feet on the last row. `REF` says where the reference's frames are:
{"dir": the ref_cut.py output folder (next to the module or absolute), "states": state -> (band, first
column, frames), "dirs": the direction of each row in a band}; a band is four rows of the sheet.

A spec, as the tools take it:
    <module>:<attr>:<dir>:<index>     a drawn frame
    <module>:REF:<state>:<dir>:<index> the reference's frame (background and drop shadow left empty)
    <module>:<attr>:<dir>             every frame of a direction (tools that take a row)
"""
import importlib
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
# The game's player sprite, for the scale (the default look's layers, front frame).
REPO = os.environ.get("REPO", "/home/user/survivium")
PLAYER_LAYERS = ("body", "trousers", "shirt", "boots", "hair")
PLAYER_ROWS = {"s": 0, "se": 1, "e": 2, "ne": 3, "n": 4, "nw": 5, "w": 6, "sw": 7}


def rgba(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def render(rows, pal):
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in ". ":
                im.putpixel((x, y), rgba(pal[ch]))
    return im


def mirror(half):
    """Rows drawn from the left edge to the middle column (included), made whole."""
    return [r + r[-2::-1] for r in half]


def paint(rows, marks):
    """Rows with some letters put over them: `marks` is "x,y:letters" strings, the letters laid
    rightwards from (x, y) ("." leaves a pixel as it is), for what a mirrored half cannot draw (a
    tail curled to one side)."""
    rows = [list(r) for r in rows]
    for m in marks:
        at, letters = m.split(":")
        x, y = map(int, at.split(","))
        for i, ch in enumerate(letters):
            if ch != ".":
                rows[y][x + i] = ch
    return ["".join(r) for r in rows]


def module(name):
    return importlib.import_module(name)


def ref_sheet(mod):
    d = mod.REF["dir"]
    if not os.path.isabs(d):
        d = os.path.join(os.path.dirname(os.path.abspath(mod.__file__)), d)
    lay = json.load(open(os.path.join(d, "frames.json")))
    return d, lay


def ref_frame(mod, state, d, i, keep_bg=False):
    """The reference's frame `i` of `state` facing `d`, cut to its box; the background and the drop
    shadow empty unless `keep_bg`. A state named in `REF["swipe"]` keeps its very light pixels (a
    white swipe the reference draws, as the attack's tusks): they are not the JPEG's ring. A small piece at
    the box's side, apart from the figure, is a neighbouring frame's (the sheet's grid drifts): cleared."""
    folder, lay = ref_sheet(mod)
    band, first, n = mod.REF["states"][state]
    row = band * 4 + mod.REF["dirs"].index(d)
    f = [f for f in lay["frames"] if f["row"] == row and f["col"] == first + i][0]
    sheet = Image.open(os.path.join(folder, "native.png")).convert("RGBA")
    im = sheet.crop(tuple(f["box"]))
    if not keep_bg:
        bg = rgba(lay["background"])[:3]
        px = im.load()
        w, h = im.size
        swipe = state in mod.REF.get("swipe", ())

        def outside(p):
            # The background, the drop shadow's grey, and the light greyish ring a JPEG leaves
            # round a figure; only where it joins the frame's edge (an eye's white stays).
            near_bg = sum(abs(a - b) for a, b in zip(p, bg)) <= 40
            grey = max(p) - min(p) < 16 and 100 <= sum(p) / 3 <= 175
            # The shadow's edge, a little blue (a fur pixel is always redder than blue).
            bluegrey = p[2] >= p[0] and max(p) - min(p) < 30 and 100 <= sum(p) / 3 <= 175
            ring = max(p) - min(p) < 40 and sum(p) / 3 > 150
            return near_bg or grey or bluegrey or ring

        def swiped(p):
            # A swipe's pixel: kept, but the background it closes in is still cleared.
            return swipe and max(p) - min(p) < 40 and sum(p) / 3 >= 205

        stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
        seen = set()
        while stack:
            x, y = stack.pop()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
                continue
            seen.add((x, y))
            if swiped(px[x, y][:3]):
                stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                continue
            if not outside(px[x, y][:3]):
                continue
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        # Specks of the drop shadow's blue-grey edge left apart from the figure (up to 3 pixels).
        groups = parts(px, w, h)
        for c in groups:
            if len(c) <= 3 and all(max(px[q][:3]) - min(px[q][:3]) < 30 and sum(px[q][:3]) / 3 > 100 for q in c):
                for q in c:
                    px[q] = (0, 0, 0, 0)
        # A neighbour's piece the box catches as the sheet's grid drifts (a tail, a rump's edge): small,
        # apart from the figure, at the box's side, and no swipe in it.
        big = max((len(c) for c in groups), default=0)
        for c in groups:
            if len(c) <= 12 < big and any(q[0] in (0, w - 1) for q in c) \
                    and not any(swiped(px[q][:3]) for q in c if px[q][3]):
                for q in c:
                    px[q] = (0, 0, 0, 0)
        box = im.getbbox()
        im = im.crop(box) if box else im
    return im


def parts(px, w, h):
    """The opaque pixels' 8-connected groups."""
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not px[x, y][3]:
                continue
            stack, group = [(x, y)], []
            seen.add((x, y))
            while stack:
                a, b = stack.pop()
                group.append((a, b))
                for q in ((a + i, b + j) for i in (-1, 0, 1) for j in (-1, 0, 1)):
                    if 0 <= q[0] < w and 0 <= q[1] < h and q not in seen and px[q][3]:
                        seen.add(q)
                        stack.append(q)
            out.append(group)
    return out


def frames(spec):
    """Every frame a spec names, as RGBA images cut to the figure, the feet on the last row."""
    parts = spec.split(":")
    mod = module(parts[0])
    if parts[1] == "REF":
        state, d = parts[2], parts[3]
        n = mod.REF["states"][state][2]
        idx = [int(parts[4])] if len(parts) > 4 else range(n)
        return [ref_frame(mod, state, d, i) for i in idx]
    data = getattr(mod, parts[1])
    d = parts[2]
    rows = data[d]
    idx = [int(parts[3])] if len(parts) > 3 else range(len(rows))
    out = []
    for i in idx:
        im = render(rows[i], mod.PAL)
        out.append(im)
    return out


def frame(spec):
    return frames(spec)[0]


def player(d="s", col=0):
    """The player's default look in direction `d`, the frame cut to the figure."""
    fr = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    r = PLAYER_ROWS[d]
    for layer in PLAYER_LAYERS:
        im = Image.open(os.path.join(REPO, "content/core/sprites/player/%s.png" % layer)).convert("RGBA")
        fr.alpha_composite(im.crop((col * 32, r * 32, col * 32 + 32, r * 32 + 32)))
    return fr.crop(fr.getbbox())


def grass(w, h):
    tex = Image.open(os.path.join(REPO, "content/core/textures/grass.png")).convert("RGBA").crop((0, 0, 16, 16))
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, 16):
        for x in range(0, w, 16):
            out.paste(tex, (x, y))
    return out
