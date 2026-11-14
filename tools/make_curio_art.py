#!/usr/bin/env python3
"""Draws the pictures of the curiosities: the ground plants mimosa (open, and folded as
someone passes), giant puffball, sundew (its dew glints: texels of alpha DEW, see
grass.gdshader) and evening primrose (buds by day, open flowers at night), their
items' icons (12x12) and models (a row of 16x16 slices), and the finds in stone
(ammonite, geode, amber) of the materials mod. Run from the repo:
    python3 tools/make_curio_art.py
Everything is written again.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_plant_art as art  # noqa: E402

CONTENT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content")
## Alpha of the texels that glint (dew drops): opaque enough to be drawn, below 255 so
## the shader knows them.
DEW = 220

art.PAL.update({
    "1": (70, 140, 60, 255),  # mimosa leaflet
    "2": (118, 186, 88, 255),  # its lit side
    "3": (46, 96, 44, 255),  # folded leaflet
    "4": (226, 120, 196, 255),  # mimosa pompom
    "5": (250, 176, 226, 255),  # its light
    "6": (232, 226, 210, 255),  # puffball
    "7": (250, 248, 240, 255),  # its lit top
    "8": (186, 176, 152, 255),  # its shade
    "9": (150, 46, 40, 255),  # sundew leaf
    "0": (196, 80, 64, 255),  # its rim
    "!": (255, 214, 220, DEW),  # a dew drop
    "?": (96, 120, 56, 255),  # sundew stalk
    "+": (226, 212, 96, 255),  # primrose bud
    "#": (250, 236, 120, 255),  # primrose petal
    "%": (255, 250, 190, 255),  # its light
    "&": (200, 150, 40, 255),  # its heart
    "=": (78, 128, 58, 255),  # primrose leaf
})

low = art.low

# Mimosa: a low sprawl of fern-like leaves, pink pompoms on short stalks; the last two
# frames the same plants folded shut (shy: shown as someone passes, see grass.gdshader).
MIMOSA = [
    low("...54...", "..444...", "...4..2.", "21212.1.", "..s..212", "212s.s..", "...ss.s.", "....ss..", "....s..."),
    low("......4.", ".2...454", "121...4.", "..s.1212", "2121s...", "...s.s..", "...ss...", "....s..."),
    low("...44...", "..444...", "...4....", "...3..3.", "..3s.3..", "..3s.s3.", "...ss.s.", "....ss..", "....s..."),
    low("......4.", "......44", "..3...4.", ".3s..3..", "..3s3...", "...s.s..", "...ss...", "....s..."),
]

# Giant puffball: a white ball on the grass, big and small.
PUFFBALL = [
    low("..7776..", ".777666.", ".7766668", ".6666688", "..66888."),
    low("...76...", "..7666..", "..66688.", "...888.."),
]

# Sundew: a red rosette, each leaf tipped with a drop of dew; a stalk of flowers.
SUNDEW = [
    low("....?...", "...!?...", "....?...", ".!..?.!.", ".0..?.0.", "..9.?9..", "!09909!.", ".099990."),
    low("........", ".!......", ".0...!..", "..9..0..", "..9.9..!", "!0999990", ".09990.."),
]

# Evening primrose: by day closed yellow buds on tall stalks; at night (the last two
# frames) open four-petalled flowers.
PRIMROSE = [
    low("...+....", "...s.+..", "..=s.s..", "...s=s..", "..=s.s=.", "...ss...", "..=s=...", "...s...."),
    low(".....+..", "..+..s..", "..s.=s..", "..s=.s..", ".=s..s=.", "..s.ss..", "...ss=..", "...s...."),
    low("..%#....", ".#&#.%#.", "..#s#&#.", "..=s.s..", "...s=s..", "..=s.s=.", "...ss...", "..=s=...", "...s...."),
    low(".....%#.", ".%#.#&#.", "#&#s.s#.", ".#s.=s..", "..s=.s..", ".=s..s=.", "..s.ss..", "...ss=..", "...s...."),
]


def save(img, *path):
    path = os.path.join(CONTENT, *path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(path)


def icon(name, mod, bundle, rows, pal):
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img.putpixel((x, y), pal[ch])
    save(img, mod, bundle, "icons", "%s.png" % name)


def model(name, mod, bundle, levels, paint):
    """`paint(level, x, y)` -> colour or None for each texel of each 16x16 slice."""
    img = Image.new("RGBA", (16 * levels, 16), (0, 0, 0, 0))
    for level in range(levels):
        for y in range(16):
            for x in range(16):
                c = paint(level, x, y)
                if c:
                    img.putpixel((level * 16 + x, y), c)
    save(img, mod, bundle, "models", "%s.png" % name)


def lump(r, colour, shine=None, cx=7.5, cy=7.5, squash=1.0):
    """A ball of radius `r` texels as slices: rounder in the middle, lit on top."""
    levels = max(1, int(round(r * 2 * squash)))

    def paint(level, x, y):
        h = (level + 0.5) / levels * 2.0 - 1.0
        rr = r * math.sqrt(max(0.0, 1.0 - h * h))
        if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= rr * rr:
            if shine and level == levels - 1 and x < cx and y < cy:
                return shine
            return colour
        return None
    return levels, paint


def plants():
    art.sprite("mimosa", MIMOSA)
    art.sprite("puffball", PUFFBALL)
    art.sprite("sundew", SUNDEW)
    art.sprite("evening_primrose", PRIMROSE)
    pal = {"w": art.PAL["6"], "W": art.PAL["7"], "s": art.PAL["8"], "r": art.PAL["9"], "R": art.PAL["0"],
           "d": art.PAL["!"][:3] + (255,), "g": art.PAL["?"], "y": art.PAL["#"], "Y": art.PAL["%"], "h": art.PAL["&"],
           "l": art.PAL["="], "b": (150, 96, 60, 255), "B": (190, 130, 80, 255), "t": (176, 140, 60, 255)}
    icon("puffball", "plants", "puffball", [
        "............", "............", "....WWWW....", "...WWWwww...", "..WWwwwwws..", "..Wwwwwwws..",
        "..wwwwwwss..", "..wwwwwsss..", "...wwssss...", "....ssss....", "............", "............"], pal)
    icon("sundew", "plants", "sundew", [
        "............", "..d.....d...", "..R..g..R...", "...r.g.r....", "d...rgr...d.", "R..rrrrr..R.",
        ".rrrrrrrrr..", "..rrrrrrr...", "....rrr.....", "............", "............", "............"], pal)
    icon("evening_primrose", "plants", "evening_primrose", [
        "............", "....YY......", "...yhhy.Y...", "..YyhhyYy...", "...yyyy.y...", "....g..g....",
        "....g.gl....", "...lg.g.....", "....gg......", "....g.......", "....g.......", "............"], pal)
    icon("primrose_tea", "plants", "evening_primrose", [
        "............", "....t.t.....", ".....t......", "..BBBBBBB...", "..BttttbBBB.", "..BbbbbbB.B.",
        "..BbbbbbBB..", "...BbbbB....", "....BBB.....", "............", "............", "............"], pal)
    model("puffball", "plants", "puffball", *lump(4.5, art.PAL["6"], art.PAL["7"], squash=0.8))
    model("sundew", "plants", "sundew", 1, lambda lv, x, y: (
        art.PAL["9"] if (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 9 else (
            art.PAL["0"] if (x - 7.5) ** 2 + (y - 7.5) ** 2 <= 14 else None)))
    model("evening_primrose", "plants", "evening_primrose", 1, lambda lv, x, y: (
        art.PAL["&"] if (x, y) in [(7, 7), (8, 8)] else (
            art.PAL["#"] if abs(x - 7.5) + abs(y - 7.5) <= 3.5 else (
                art.PAL["="] if 8 <= x <= 13 and y == 10 else None))))

    def cup(level, x, y):
        d = (x - 7.5) ** 2 + (y - 7.5) ** 2
        if level == 0:
            return (150, 96, 60, 255) if d <= 9 else None
        if d <= 6:
            return (176, 140, 60, 255) if level == 2 else (150, 96, 60, 255)
        return (190, 130, 80, 255) if d <= 12 else None
    model("primrose_tea", "plants", "evening_primrose", 3, cup)


def finds():
    stone = (150, 140, 124, 255)
    pal = {"s": stone, "S": (196, 186, 168, 255), "d": (96, 88, 78, 255), "c": (170, 120, 210, 255),
           "C": (224, 196, 250, 255), "a": (220, 140, 30, 255), "A": (250, 200, 90, 255), "k": (60, 40, 20, 255)}
    icon("ammonite", "materials", "finds", [
        "............", "....SSSS....", "..SSsssSS...", ".Ssd.dddsS..", ".Ssdssssds..", ".sdsSSddsd..",
        ".sdsdsSdsd..", ".sdssddsds..", "..sddsssd...", "...sdddd....", "............", "............"], pal)
    icon("geode", "materials", "finds", [
        "............", "....SSSS....", "..SSssssS...", ".SsCCcCCsS..", ".sCcCCcCcs..", ".sCCcCCCCs..",
        ".scCCcCcCs..", ".sdCCcCCds..", "..sddddds...", "...ssss.....", "............", "............"], pal)
    icon("amber", "materials", "finds", [
        "............", "............", ".....AA.....", "....AAaa....", "...AAaaaa...", "...Aaakaa...",
        "...aakkaa...", "...aaaaaa...", "....aaaa....", ".....aa.....", "............", "............"], pal)

    def ammonite(level, x, y):
        dx, dy = x - 7.5, y - 7.5
        r = math.hypot(dx, dy)
        if r > 5.5:
            return None
        a = math.atan2(dy, dx)
        # A spiral groove: the radius where the shell's coil runs at this angle.
        groove = (r - (a + math.pi) / (2 * math.pi) * 2.2) % 2.2 < 0.6
        return pal["d"] if groove and level == 1 else (pal["S"] if level == 1 else stone)
    model("ammonite", "materials", "finds", 2, ammonite)

    def geode(level, x, y):
        d = (x - 7.5) ** 2 + (y - 7.5) ** 2
        if d > 25:
            return None
        if level == 2:
            return pal["S"] if d > 12 else None
        if level == 1 and d <= 12:
            return pal["C"] if (x + y) % 3 == 0 else pal["c"]
        return stone
    model("geode", "materials", "finds", 3, geode)
    model("amber", "materials", "finds", *lump(3.0, pal["a"], pal["A"], squash=0.7))


def main():
    plants()
    finds()


if __name__ == "__main__":
    main()
