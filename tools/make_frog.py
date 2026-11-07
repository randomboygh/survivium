"""Draws the frog's sheet, content/animals/frog/sprites/creatures/frog.png.

Drawn by hand in the sparrow's style (tools/make_sparrow.py, 2026-11-07): a dark outline
round the whole frog, a lime back, a cream belly, gold eyes. Frames 14x10.

Rows (creatures.yaml `views: 3`): the side (E, facing right; the game mirrors it for
left), the front (S) and the back (N). Columns (`frames: 5`, `walk: 2`): sitting, the leap
(stretched out; also its swim), crouched (taking off and landing), and two idle frames:
a blink and the throat puffed.

    python3 tools/make_frog.py
"""
import os

from PIL import Image

PAL = {
    "O": "#16220e", "L": "#16220e",
    "G": "#78ac3a", "g": "#a2cc54", "D": "#4c762a", "S": "#2c461a", "H": "#5e9030",
    "P": "#d8d49a", "p": "#b0ac70", "Q": "#f2eec4",
    "E": "#e8c040", "K": "#101408", "M": "#2c461a",
}
W, H = 14, 10
AXIS = 13


def art(rows):
    return {(x, y): ch for y, r in rows.items() for x, ch in enumerate(r) if ch != "."}


SIT = {
    "E": art({
        3: "........gg....",
        4: ".......gEKg...",
        5: "....DDDGGGGg..",
        6: "..DDSDDGGGGGg.",
        7: ".HDGGGDGMMMMM.",
        8: "HHHGGGGPPPPP..",
        9: "LLLHL.LPpL....",
    }),
    "S": art({
        4: "...gg....gg...",
        5: "..gEKg..gKEg..",
        6: "..GGGGGGGGGG..",
        7: ".GGMMMMMMMMGG.",
        8: "HHGGPPPPPPGGHH",
        9: "LLHL.PppP.LHLL",
    }),
    "N": art({
        4: "...gg....gg...",
        5: "..gEEg..gEEg..",
        6: "..GGDGGGGDGG..",
        7: ".GGDSDGGDSDGG.",
        8: "HHGGDDGGDDGGHH",
        9: "LLHHGG..GGHHLL",
    }),
}

LEAP = {
    "E": art({
        1: "...........gg.",
        2: "..........gEKg",
        3: "........DDGGGG",
        4: "......DDSGGMMg",
        5: "....HHDGGPPPP.",
        6: "..HHH.GPPPL...",
        7: ".HH...........",
        8: "LL............",
    }),
    "S": art({
        2: "...gg....gg...",
        3: "..gEKg..gKEg..",
        4: "..GGGGGGGGGG..",
        5: ".GGMMMMMMMMGG.",
        6: "L.GPPPPPPPPG.L",
        7: "..HPPPPPPPPH..",
        8: "..HH.PppP.HH..",
        9: "...LL....LL...",
    }),
    "N": art({
        2: "...gg....gg...",
        3: "..gEEg..gEEg..",
        4: "..GGDGGGGDGG..",
        5: ".GGDSDGGDSDGG.",
        6: "L.GGDDGGDDGG.L",
        7: "..HGGGGGGGGH..",
        8: "..HH.GGGG.HH..",
        9: "...LL....LL...",
    }),
}

SAC = {
    "E": art({8: "..........QQ..", 9: "..........QQ.."}),
    "S": art({8: ".....QQQQ.....", 9: ".....QQQQ....."}),
}


def crouch(px):
    out = {}
    for (x, y), ch in sorted(px.items(), key=lambda kv: kv[0][1] <= 6):
        if ch == "L":
            out[(x, y)] = ch
            continue
        out[(x, y + 1 if y <= 7 else y)] = ch
    for (x, y), ch in px.items():
        if y == 8 and ch in "HG" and (x <= 2 or x >= 11):
            out[(x, 9)] = "H"
    return out


def render(layers):
    out = {}
    for layer in layers:
        for (x, y), ch in layer.items():
            if 0 <= x < W and 0 <= y < H:
                out[(x, y)] = ch
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hexc = lambda s: tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    for (x, y), ch in out.items():
        im.putpixel((x, y), hexc(PAL[ch]))
    for x in range(W):
        for y in range(H):
            if (x, y) in out:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = out.get((x + dx, y + dy))
                if n is not None and n not in "LO":
                    im.putpixel((x, y), hexc(PAL["O"]))
                    break
    return im


def frames(view):
    sit = SIT[view]
    blink = {k: ("g" if ch in "EK" else ch) for k, ch in sit.items()}
    return [render([sit]), render([LEAP[view]]), render([crouch(sit)]), render([blink]),
            render([sit, SAC.get(view, {})])]


ORDER = ["E", "S", "N"]


def sheet():
    rows = [frames(v) for v in ORDER]
    im = Image.new("RGBA", (W * len(rows[0]), H * len(rows)), (0, 0, 0, 0))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            im.alpha_composite(f, (i * W, j * H))
    return im


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "frog",
                    "sprites", "creatures", "frog.png")

if __name__ == "__main__":
    sheet().save(PATH)
    print(PATH)
