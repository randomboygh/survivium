#!/usr/bin/env python3
"""Draws the pictures of the plants added as bundles (birch, pine, willow, apple, rowan,
currant, rose hip, fern, nettle, cranberry): the barks of the trees as textures like a
material's (48x16: the end grain, the bark, the underside; recoloured from the log's
texture of the wood bundle, with marks of their own), the ground plants' sprites (8x24 a
frame, two frames each, in sprites/plants/ of the bundle), the icons (12x12) and the
voxel models (a row of 16x16 slices) of their berries and fruit. Run from the repo:
    python3 tools/make_plant_art.py
Everything is written again; a picture painted over by hand goes under another name.
"""
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "plants")
TILE = 16


def lerp(a, b, k):
    return tuple(int(round(a[i] + (b[i] - a[i]) * k)) for i in range(3)) + (255,)


def recolour(src, dark, light):
    """Maps the log texture's shades onto a palette from `dark` to `light`."""
    out = Image.new("RGBA", src.size)
    lo, hi = 255, 0
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            lum = (r * 3 + g * 6 + b) / 10.0
            lo = min(lo, lum)
            hi = max(hi, lum)
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            lum = (r * 3 + g * 6 + b) / 10.0
            k = (lum - lo) / max(1.0, hi - lo)
            out.putpixel((x, y), lerp(dark, light, k))
    return out


def bark(name, dark, light, marks=None, seed=1):
    src = Image.open(os.path.join(ROOT, "wood", "textures", "log.png")).convert("RGBA")
    img = recolour(src, dark, light)
    rng = random.Random(seed)
    if marks:
        # Short horizontal dashes on the side tile (birch), and the underside.
        colour, count = marks
        for tile in (1, 2):
            for i in range(count):
                x = tile * TILE + rng.randrange(0, TILE - 3)
                y = rng.randrange(0, TILE)
                w = rng.randrange(2, 5)
                for dx in range(w):
                    img.putpixel(((x + dx) % (TILE * 3), y), colour + (255,))
    path = os.path.join(ROOT, name, "textures", "%s_bark.png" % name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


def sprite(name, frames):
    """`frames`: list of 24 rows of 8 chars each (top row first), chars mapped by `PAL`."""
    img = Image.new("RGBA", (8 * len(frames), 24), (0, 0, 0, 0))
    for f, rows in enumerate(frames):
        assert len(rows) == 24, name
        for y, row in enumerate(rows):
            assert len(row) == 8, (name, y)
            for x, ch in enumerate(row):
                if ch != ".":
                    img.putpixel((f * 8 + x, y), PAL[ch])
    path = os.path.join(ROOT, name, "sprites", "plants", "%s.png" % name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


PAL = {
    "g": (58, 112, 46, 255),  # fern green
    "G": (92, 150, 62, 255),  # lit green
    "d": (40, 80, 36, 255),  # dark green
    "n": (62, 104, 42, 255),  # nettle
    "N": (108, 150, 70, 255),
    "s": (120, 96, 60, 255),  # stem brown
    "r": (176, 36, 48, 255),  # cranberry red
    "R": (226, 90, 96, 255),  # its shine
    "c": (74, 110, 56, 255),  # cranberry leaf
    "k": (30, 24, 24, 255),
}

FERN = [
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "...G....", "..gGg...", ".g.G.g..",
        "g..G..g.", "..gGg...", ".g.G.g..", "g..G..g.", "..gGg...", ".g.G.g..",
        "...G..g.", "..gGg...", ".g.d.g..", "...d....", "...d....", "...s....",
    ],
    [
        "........", "........", "........", "........", "........", "........",
        "........", "....G...", "...gGg..", "..g.G.g.", ".g..G..g", "...gGg..",
        "..g.G.g.", ".g..G..g", "...gGg..", "..g.G.g.", ".g..G...", "...gGg..",
        "..g.G.g.", "....d...", "..g.d...", "....d...", "....d...", "....s...",
    ],
]

NETTLE = [
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "...NN...", "..nNNn..",
        ".nn..nn.", "....n...", "..nNnN..", ".n..n.n.", "....n...", ".nNnNn..",
        "n...n..n", "....n...", "..nnnn..", "....n...", "....s...", "....s...",
    ],
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "....NN..", "...nNNn.", "..nn..n.",
        ".....n..", "...nNnN.", "..n..n..", ".....n..", "..nNnNn.", ".n...n..",
        ".....n..", "...nnnn.", "..n..n..", ".....n..", ".....s..", ".....s..",
    ],
]

CRANBERRY = [
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "...R....",
        "..rr..c.", "c.rr.cc.", "cc...R..", ".cc.rr.c", "..c.rr.c", "..cccc..",
    ],
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "........",
        ".c..R...", "cc.rr..c", ".c.rr.cc", "..c...c.", "R.ccc.rr", "rr.c..rr",
    ],
]


def icon(name, bundle, rows, pal):
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), pal[ch])
    path = os.path.join(ROOT, bundle, "icons", "%s.png" % name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


def berry_icon(name, bundle, colour, shine, leaf=(70, 110, 50, 255), cluster=True):
    rows = [
        "............",
        ".....L......",
        "....LLL.....",
        "..........B.",
        "...BBB...BB.",
        "..BBBBB.....",
        "..BBBBB.BBB.",
        "..BBBSB.BSB.",
        "...BBB..BBB.",
        ".........B..",
        "............",
        "............",
    ] if cluster else [
        "............",
        ".....L......",
        "....LLL.....",
        "....BBB.....",
        "...BBBBB....",
        "..BBBBBBB...",
        "..BBBBBBB...",
        "..BBSBBBB...",
        "...BBBBB....",
        "....BBB.....",
        "............",
        "............",
    ]
    icon(name, bundle, rows, {"B": colour, "S": shine, "L": leaf})


def bush_icon(name, bundle, leaf, berry):
    rows = [
        "............",
        "............",
        "....##......",
        "...####.#...",
        "..###B####..",
        ".####B###B#.",
        ".#B#######B.",
        "..####B###..",
        "...######...",
        "....#..#....",
        "...SSSSSS...",
        "............",
    ]
    icon(name, bundle, rows, {"#": leaf, "B": berry, "S": (120, 96, 60, 255)})


def berry_model(name, bundle, colour, shine, size=3):
    """A berry (or an apple) as a row of square slices: a lump of `size` px."""
    levels = 2 if size <= 3 else 3
    img = Image.new("RGBA", (16 * levels, 16), (0, 0, 0, 0))
    cx, cy = 7, 7
    for level in range(levels):
        r = size if level < levels - 1 else size - 1
        for y in range(16):
            for x in range(16):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    c = shine if (x < cx and y < cy and level == levels - 1) else colour
                    img.putpixel((level * 16 + x, y), c)
    path = os.path.join(ROOT, bundle, "models", "%s.png" % name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


def main():
    bark("birch", (210, 206, 196), (246, 244, 238), marks=((48, 40, 36), 14), seed=3)
    bark("pine", (120, 66, 38), (196, 120, 70), seed=4)
    bark("willow", (86, 78, 66), (150, 140, 118), seed=5)
    bark("apple", (92, 82, 74), (150, 138, 124), seed=6)
    bark("rowan", (104, 96, 90), (164, 156, 146), seed=7)
    sprite("fern", FERN)
    sprite("nettle", NETTLE)
    sprite("cranberry", CRANBERRY)
    berry_icon("apple", "apple", (196, 44, 40, 255), (236, 120, 100, 255), cluster=False)
    berry_icon("rowan", "rowan", (220, 90, 30, 255), (240, 150, 80, 255))
    berry_icon("currant", "currant", (40, 28, 52, 255), (110, 80, 130, 255))
    berry_icon("rosehip", "rosehip", (200, 50, 30, 255), (240, 120, 90, 255))
    berry_icon("cranberry", "cranberry", (176, 36, 48, 255), (226, 90, 96, 255))
    bush_icon("bush_currant", "currant", (56, 96, 48, 255), (40, 28, 52, 255))
    bush_icon("bush_rosehip", "rosehip", (62, 100, 44, 255), (200, 50, 30, 255))
    berry_model("apple", "apple", (196, 44, 40, 255), (236, 120, 100, 255), size=4)
    berry_model("rowan", "rowan", (220, 90, 30, 255), (240, 150, 80, 255))
    berry_model("currant", "currant", (40, 28, 52, 255), (110, 80, 130, 255))
    berry_model("rosehip", "rosehip", (200, 50, 30, 255), (240, 120, 90, 255))
    berry_model("cranberry", "cranberry", (176, 36, 48, 255), (226, 90, 96, 255))


if __name__ == "__main__":
    main()
