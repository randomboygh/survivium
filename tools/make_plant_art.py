#!/usr/bin/env python3
"""Draws the pictures of the plants added as bundles (birch, pine, willow, apple, rowan,
currant, rose hip, fern, nettle, cranberry, flax, monstera): the barks of the trees as textures like a
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


def bark(name, dark, light, marks=None, seed=1, file=None):
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
    path = os.path.join(ROOT, name, "textures", "%s.png" % (file or name + "_bark"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


def sprite(name, frames, bundle=None, across=1):
    """`frames`: list of 24 rows of 8 chars each (top row first; 8 * `across` for a plant
    drawn as `across` cards side by side), chars mapped by `PAL`; saved in the bundle of
    that name (`bundle`, else `name`)."""
    w = 8 * across
    img = Image.new("RGBA", (w * len(frames), 24), (0, 0, 0, 0))
    for f, rows in enumerate(frames):
        assert len(rows) == 24, name
        for y, row in enumerate(rows):
            assert len(row) == w, (name, y)
            for x, ch in enumerate(row):
                if ch != ".":
                    img.putpixel((f * w + x, y), PAL[ch])
    path = os.path.join(ROOT, bundle or name, "sprites", "plants", "%s.png" % name)
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
    "f": (88, 128, 60, 255),  # flax stalk
    "u": (96, 120, 220, 255),  # flax flower
    "U": (150, 170, 240, 255),
    "w": (96, 140, 56, 255),  # wheat blade
    "W": (136, 172, 76, 255),  # its lit side
    "e": (206, 168, 72, 255),  # ripe wheat
    "E": (238, 206, 112, 255),  # its shine
    "o": (156, 120, 52, 255),  # ripe stalk
    "t": (64, 124, 56, 255),  # turnip leaf
    "T": (110, 166, 78, 255),  # its lit side
    "p": (150, 70, 140, 255),  # turnip root
    "P": (234, 222, 206, 255),  # its pale part
    "l": (78, 146, 58, 255),  # carrot leaf
    "L": (130, 190, 84, 255),  # its lit side
    "a": (222, 112, 28, 255),  # carrot
    "A": (250, 160, 64, 255),  # its shine
    "v": (84, 144, 66, 255),  # pea vine
    "V": (134, 190, 92, 255),  # its lit side
    "q": (150, 200, 96, 255),  # pea pod
    "Q": (244, 244, 232, 255),  # pea flower
    "m": (30, 88, 40, 255),  # monstera leaf
    "M": (64, 136, 58, 255),  # its lit side
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

FLAX = [
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "..U.....", ".UuU..U.", "..f..UuU", "..f...f.",
        "..f...f.", "...f..f.", "...f.f..", "U..f.f..", "uU.f.f..", ".f.f.f..",
        ".f..ff..", "..f.f...", "..f.f...", "...ff...", "...ff...", "...ff...",
    ],
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "...U....", "..UuU.U.", "...f.UuU", "...f..f.",
        "...f..f.", "...f.f..", "U..f.f..", "uU.f.f..", ".f..ff..", ".f..ff..",
        "..f.f...", "..f.f...", "..f.f...", "...ff...", "...ff...", "...ff...",
    ],
]

# Wheat sown on a bed (crop of the ears bundle), a frame a stage: a sprout, young blades,
# green ears, ripe golden ears.
WHEAT = [
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "........",
        "........", "...W....", "..Ww.W..", "..w.ww..", "...ww...", "...w....",
    ],
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "........", "........",
        "........", ".W....W.", ".w..W.w.", "..w.w.w.", "..wWw.w.", "W.w.ww..",
        "w..ww.W.", ".w.w.ww.", "..www.w.", "...wwW..", "...ww...", "...w....",
    ],
    [
        "........", "........", "........", "........", "........", "..W.....",
        "..WW..W.", "..Ww.WW.", "..W..Ww.", "..w..W..", "..w..w..", ".Ww..w.W",
        ".w.w.w.w", "..w.w.w.", "W.w.w.w.", "w..ww.w.", ".w.w.w..", "..w.ww..",
        "..w.w...", "...ww...", "..www...", "...ww...", "...ww...", "...w....",
    ],
    [
        "........", "........", "........", "..E.....", "..eE..E.", "..Ee.eE.",
        "..eE.Ee.", "..e..eE.", "..o..e..", "..o..o..", "E.o..o..", "eEo..o.E",
        "Ee.o.o.e", ".o.o.o.o", "..o.o.o.", "..o.o.o.", "..o.oo..", "..o.o...",
        "..oo....", "...oo...", "..ooo...", "...oo...", "...oo...", "...o....",
    ],
]

def low(*rows):
    """A frame of the rows given, set on the ground (padded on top to 24 rows)."""
    return ["........"] * (24 - len(rows)) + list(rows)


# The crops sown on a bed (turnip, carrot, peas, flax bundles), a frame a stage: a sprout,
# young leaves, grown, ripe.
TURNIP = [
    low("..t.t...", "...t....", "...t...."),
    low(".T...T..", ".tT.Tt..", "..tTt...", "...tt...", "...t...."),
    low("T.....T.", "tT.T.Tt.", ".tTtTt..", "..tTt.T.", "T.ttt.t.", "tTt.tTt.", ".ttttt..", "...tt...", "...t...."),
    low("T.....T.", "tT.T.Tt.", ".tTtTt..", "..tTt.T.", "T.ttt.t.", "tTt.tTt.", ".ttttt..", "..tttt..",
        ".pPPpp..", ".PPPpp..", "..Ppp..."),
]

CARROT = [
    low("..l.l...", "...l....", "...l...."),
    low(".L.l.L..", "..lll...", "L..l..l.", ".l.l.L..", "..lll...", "...l...."),
    low("..L..l..", ".l.L.l.L", "l..lll..", ".L.l.l.l", "..l.L.l.", "l..lll..", ".l.l.L..", "..lll..l",
        "...l.l..", "...ll...", "...l...."),
    low("..L..l..", ".l.L.l.L", "l..lll..", ".L.l.l.l", "..l.L.l.", "l..lll..", ".l.l.L..", "..lll..l",
        "...l.l..", "..lll...", "..AaA...", "..aAa...", "...a...."),
]

PEAS = [
    low("...v....", "..vv....", "...v...."),
    low("..V.....", ".vVv....", "..v.V...", "..vvV...", "...v....", "..vv....", "...v...."),
    low("...V....", "..vVQ...", ".v.v.V..", "..vVv...", ".Q.v.vV.", "..vvV...", "V..v..v.", "vV.vvVv.",
        "..vv.v..", ".v.v....", "...vv...", "...v....", "..vv....", "...v...."),
    low("...V....", "..vVq...", ".v.vqV..", "..vVv...", ".q.v.vV.", ".qvvVq..", "V..v..q.", "vV.vvVv.",
        "..vv.v..", ".vqv....", "..qvv...", "...v....", "..vv....", "...v...."),
]

SOWN_FLAX = [
    low("..f.f...", "...f....", "...f...."),
    low(".f..f...", "..f.f.f.", "..f.ff..", "...ff...", "...f....", "...f...."),
    low("..U..u..", ".uUu.U..", "..f..f.U", "..f.f.uf", ".Uf.f.f.", "uf..f.f.", ".f.ff.f.", "..ff.f..",
        "..f.ff..", "..ff.f..", "...ff...", "...f...."),
    low("..E..e..", ".eEe.E..", "..o..o.E", "..o.o.eo", ".Eo.o.o.", "eo..o.o.", ".o.oo.o.", "..oo.o..",
        "..o.oo..", "..oo.o..", "...oo...", "...o...."),
]

# The saplings grown from a tree's seed (oak, spruce bundles), a frame a stage, two cards
# wide (plants `across: 2`), the stem between them: a sprout, a shoot (a young tree, then
# the tree, are voxels: Growth).
def low16(*rows):
    """A 16 px wide frame of the rows given, set on the ground (padded on top to 24 rows)."""
    return ["." * 16] * (24 - len(rows)) + list(rows)


OAK_SAPLING = [
    low16(
        "......GG........",
        ".....GgGG.......",
        ".....dGgGG..GG..",
        "......dgG..GgGG.",
        ".......s..GgGgG.",
        "..GG...s.dgGgd..",
        ".GgGG..s.sdd....",
        ".dGgGG.ss.......",
        "..dgGds.s.......",
        "...dd..ss.......",
        ".......s........",
        ".......ss.......",
        "......sss.......",
    ),
    low16(
        "......GG.GG.....",
        "....GGgGGgGGG...",
        "...GgGgGgGgGGG..",
        "..GgGgdgGgGgGgG.",
        ".GgGdgGgdGgGgGgG",
        ".gGgGgdgGgdgGgG.",
        "GgdgGgGgdgGgGdgG",
        "gGgGdgGgGgGdgGg.",
        ".dgGgdgsgGgGgdg.",
        "..dgdg.sgdgGgd..",
        "...dd.sgs.dgd...",
        "......ss..dd....",
        ".......s........",
        ".......ss.......",
        ".......s........",
        ".......ss.......",
        ".......ss.......",
        "......sss.......",
    ),
]

SPRUCE_SAPLING = [
    low16(
        ".......G........",
        "......gGg.......",
        ".....gdGdg......",
        "......gGg.......",
        ".....gdGdg......",
        "....gdgGgdg.....",
        "......gGg.......",
        ".....gdgdgg.....",
        "....gdgGgdgd....",
        "...gd.ddsd.dg...",
        ".......s........",
        ".......s........",
        "......sss.......",
    ),
    low16(
        ".......G........",
        "......gGg.......",
        ".....gdGdg......",
        "......gGg.......",
        ".....gdGgdg.....",
        "....gdgGdgdg....",
        "......gGg.......",
        ".....gdGdgd.....",
        "....gdgGgdgd....",
        "...gdgdGdgdgd...",
        ".....gdGgdg.....",
        "....gdgGgdgdg...",
        "...gdgdGgdgdgd..",
        "..gdgdgGdgdgdgd.",
        "....gdgsgdgd....",
        "...gdgdGgdgdgd..",
        "..gdgdgGgdgdgdg.",
        ".gdgdgdsdgdgdgdg",
        "...d.d.ss.d.d...",
        ".......ss.......",
        ".......ss.......",
        "......ssss......",
    ),
]

CROP_ICONS = {
    "turnip": ["............", "....t.t.....", ".....tt.....", ".....t......", "...PPPPP....", "..PPPPPPP...",
               "..PPPPPPP...", "..pPPPPPp...", "...ppppp....", "....ppp.....", ".....p......", "............"],
    "carrot": ["............", "........l.l.", ".........ll.", "......AAal..", ".....AAaa...", "....AAaa....",
               "...Aaaa.....", "..Aaaa......", "..aaa.......", ".aa.........", "............", "............"],
    "peas": ["............", "............", "........v...", ".......vv...", "...qqqqqq...", "..qVqVqVq...",
             "..qqqqqqq...", "...qqqqq....", "............", "............", "............", "............"],
}


def seeds(name, bundle, colour):
    """The seeds of a crop: the grass bundle's seeds icon and model in colour `colour`."""
    for kind in ("icons", "models"):
        src = Image.open(os.path.join(ROOT, "grass", kind, "seeds.png")).convert("RGBA")
        out = Image.new("RGBA", src.size, (0, 0, 0, 0))
        for y in range(src.height):
            for x in range(src.width):
                r, g, b, a = src.getpixel((x, y))
                if a:
                    k = (r * 3 + g * 6 + b) / 2550.0
                    out.putpixel((x, y), lerp(tuple(c * 0.55 for c in colour), colour, k))
        path = os.path.join(ROOT, bundle, kind, "%s.png" % name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save(path)
        print(path)


def carrot_model(bundle):
    """A carrot lying on its side: an orange wedge with a green top, two slices high."""
    img = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    for level in range(2):
        for i in range(8):
            x, y = 3 + i, 11 - i
            w = 2 if i > 1 else 1
            for dx in range(w if level == 0 else max(1, w - 1)):
                img.putpixel((level * 16 + x + dx, y), PAL["A" if level else "a"])
        img.putpixel((level * 16 + 11, 3), PAL["L"])
        img.putpixel((level * 16 + 12, 3), PAL["l"])
        img.putpixel((level * 16 + 12, 2), PAL["l"])
    path = os.path.join(ROOT, bundle, "models", "carrot.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


def crops():
    sprite("turnip", TURNIP)
    sprite("carrot", CARROT)
    sprite("peas", PEAS)
    sprite("sown_flax", SOWN_FLAX, "flax")
    sprite("oak_sapling", OAK_SAPLING, "oak", 2)
    sprite("spruce_sapling", SPRUCE_SAPLING, "spruce", 2)
    for name, rows in CROP_ICONS.items():
        icon(name, name, rows, PAL)
    seeds("turnip_seeds", "turnip", (120, 70, 90))
    seeds("carrot_seeds", "carrot", (170, 130, 80))
    seeds("flax_seeds", "flax", (170, 120, 60))
    berry_model("turnip", "turnip", PAL["p"], PAL["P"], size=4)
    berry_model("peas", "peas", PAL["q"], PAL["V"], size=2)
    carrot_model("carrot")


# Monstera: two or three broad leaves split to the rib on short stalks, the jungle's
# undergrowth.
MONSTERA = [
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", ".MM.....", "MmMM..m.",
        "M.mM.mMM", "MmM..M.m", ".mm.MmMM", "..s.mM.m", "..s..mm.", "...s.s..",
        ".mMs.s..", "mM.Mss..", "Mm.MMs..", ".mMm.s..", "...ss...", "...s....",
    ],
    [
        "........", "........", "........", "........", "........", "........",
        "........", "........", "........", "........", "......MM", "..m..MMm",
        ".MMm.Mm.", "Mm.M.mMm", "MmMM..m.", ".mm.s.s.", "...s..s.", "...s.s..",
        "..s..sMm", "..s.Mm.M", "..ssMM.m", "...s.mMm", "...ss...", "....s...",
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


# The barks of the trees added with the crown shapes: name, dark, light, options.
# The atlas had room for 21 materials and barks together then (PixelTextures.MOST_MATERIALS,
# 63 now), so the grey bark in common/ is shared by linden, poplar, fir and bird cherry,
# and maple and larch keep the log's own.
NEW_BARKS = [
    ("common", (92, 90, 84), (156, 152, 142), {"marks": ((64, 60, 54), 6), "seed": 9, "file": "grey_bark"}),
    ("cherry", (88, 44, 40), (150, 86, 74), {"marks": ((178, 128, 110), 10), "seed": 13}),
    ("deadwood", (104, 100, 92), (192, 186, 172), {"marks": ((60, 54, 48), 10), "seed": 15}),
]


def main():
    import sys
    if sys.argv[1:] == ["wheat"]:
        sprite("wheat", WHEAT, "ears")
        return
    if sys.argv[1:] == ["saplings"]:
        sprite("oak_sapling", OAK_SAPLING, "oak", 2)
        sprite("spruce_sapling", SPRUCE_SAPLING, "spruce", 2)
        return
    if sys.argv[1:] == ["crops"]:
        crops()
        return
    bark("birch", (210, 206, 196), (246, 244, 238), marks=((48, 40, 36), 14), seed=3)
    bark("pine", (120, 66, 38), (196, 120, 70), seed=4)
    bark("willow", (86, 78, 66), (150, 140, 118), seed=5)
    bark("apple", (92, 82, 74), (150, 138, 124), seed=6)
    bark("rowan", (104, 96, 90), (164, 156, 146), seed=7)
    for args in NEW_BARKS:
        bark(*args[:3], **args[3])
    sprite("fern", FERN)
    sprite("nettle", NETTLE)
    sprite("cranberry", CRANBERRY)
    sprite("flax", FLAX)
    sprite("monstera", MONSTERA)
    sprite("wheat", WHEAT, "ears")
    crops()
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
