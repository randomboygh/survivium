"""Draws the sparrow's sheet, content/animals/sparrow/sprites/creatures/sparrow.png.

Drawn by hand after a 16 px sparrow the user made (2026-11-07): a slate outline round
the whole bird, a chestnut back, a peach breast, a yellow wing bar; broad wings in
flight. Frames 14x11, the bird about 11x8 standing (the game's size).

Rows (creatures.yaml `views: 3`): the side (E, facing right; the game mirrors it for
left), the front (S) and the back (N). Columns (`frames: 9`, `walk: 4`, `hop: 2`): sitting, the
wing beat (up, level, down, rising), two idle frames (pecking), and the hop on the
ground (crouched, in the air).

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round
the fill. Legs 'L' are in the outline colour and get no outline of their own.

    python3 tools/make_sparrow.py
"""
import os
from PIL import Image

PAL = {
    "O": "#2a2e34", "L": "#2a2e34",
    "C": "#b15d37", "c": "#c8784a",
    "R": "#953f20", "D": "#6e3019", "T": "#7d391d",
    "H": "#f9c391", "P": "#d39a74", "p": "#b98262",
    "Y": "#d7b043", "E": "#1a0e06", "K": "#744e37", "B": "#3a3236",
    "W": "#a3542b", "w": "#6e3019",
}
W, H = 14, 11
AXIS = 12  # the front and back views are centred on x = 6


def art(rows):
    return {(x, y): ch for y, r in rows.items() for x, ch in enumerate(r) if ch != "."}


STAND = {
    "S": art({
        4: ".....cCc......",
        5: "....HECEH.....",
        6: "....HKBKH.....",
        7: "...RYPKPYR....",
        8: "...RPPPPPR....",
        9: "....RpPpR.....",
        10: ".....L.L......",
    }),
    "E": art({
        4: ".......cC.....",
        5: "......cCCC....",
        6: "......CHEKB...",
        7: "...RRYRHHP....",
        8: "..TRYYRPPP....",
        9: ".T.DRRpPP.....",
        10: ".....L.L......",
    }),
    "N": art({
        4: ".....cCc......",
        5: "....cCCCC.....",
        6: "....HCCCH.....",
        7: "...RDRRRDR....",
        8: "...YRDRDRY....",
        9: "....RRTRR.....",
        10: ".....LTL......",
    }),
}
HEAD_ROWS = 6  # rows up to this one are the head (pecking moves them)

FLY = {
    "E": art({
        5: "........cCC...",
        6: ".TT....cCHEB..",
        7: "TTTRRRRRHHH...",
        8: ".TRRRYRRPPP...",
        9: "....DDpPP.....",
    }),
    "S": art({
        3: ".....cCc......",
        4: "....HECEH.....",
        5: "....HKBKH.....",
        6: "...RYPKPYR....",
        7: "...RPPPPPR....",
        8: "....RpPpR.....",
        9: ".....pTp......",
    }),
    "N": art({
        3: ".....cCc......",
        4: "....cCCCC.....",
        5: "....HCCCH.....",
        6: "...RDRRRDR....",
        7: "...YRDRDRY....",
        8: "....RRRRR.....",
        9: "....TTTTT.....",
    }),
}

# The near wing seen from the side: up, level (spread at us), down, rising.
SIDE_WINGS = [
    art({0: "..w.w.........", 1: "..wwwww.......", 2: "...wWWW.......",
         3: "....WYW.......", 4: ".....WW.......", 5: ".....WW.......", 6: "......W......."}),
    art({6: "...wWWW.......", 7: ".wwwWYYW......", 8: "w.w.w........."}),
    art({7: ".....WYYW.....", 8: "....WWWW......", 9: "..wwwW........", 10: ".w.w.........."}),
    art({2: ".ww...........", 3: "..wwW.........", 4: "...WWYW.......", 5: ".....WW......."}),
]
# The left wing from the front or back; the right one is its mirror.
FRONT_WINGS = [
    art({0: "w.w...........", 1: "www...........", 2: "wWWw..........",
         3: ".WWYW.........", 4: "..WWW.........", 5: "...WW........."}),
    art({5: "..wWW.........", 6: "wwWWYW........", 7: "w.w.w........."}),
    art({6: "...WW.........", 7: "..WYW.........", 8: ".wWW..........", 9: "www...........", 10: "w.w..........."}),
    art({2: ".w............", 3: ".wwW..........", 4: "..wWYW........", 5: "...WWW........"}),
]
BEAT_BOB = [0, -1, 0, -1]

# Pecking, seen from the side: the tail tips up, the
# head goes down in front of the breast, then the beak to the ground.
PECK_SIDE = [
    art({
        5: "..T...........",
        6: "..TR..........",
        7: "...RRYRcC.....",
        8: "...RYYRCCC....",
        9: "....RpPHEKB...",
        10: ".....L.L......",
    }),
    art({
        5: "..T...........",
        6: "..TRR.........",
        7: "...RYYRR......",
        8: "...RYRRcCC....",
        9: "....RpCHEK....",
        10: ".....L.L..B...",
    }),
]


def mirror(px):
    return {(AXIS - x, y): ch for (x, y), ch in px.items()}


def shift(px, dx, dy):
    return {(x + dx, y + dy): ch for (x, y), ch in px.items()}


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def render(layers):
    out = {}
    for layer in layers:
        for (x, y), ch in layer.items():
            if 0 <= x < W and 0 <= y < H:
                out[(x, y)] = ch
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
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


def posed(view, head=(0, 0), bob=0, crouch=False):
    px = {}
    # The head is drawn last, over the body it bends in front of.
    items = sorted(STAND[view].items(), key=lambda kv: kv[0][1] <= HEAD_ROWS)
    for (x, y), ch in items:
        dx, dy = head if y <= HEAD_ROWS else (0, 0)
        if ch == "T" and head[1] > 0 and view not in ("S", "N"):
            dy = -1
        if crouch and ch != "L":
            dy += 1
        px[(x + dx, y + dy + bob)] = ch
    return px


def flight(view, i):
    body = FLY[view]
    if view == "E":
        layers = [body, SIDE_WINGS[i]]
    else:
        layers = [FRONT_WINGS[i], mirror(FRONT_WINGS[i]), body]
    return render([shift(layer, 0, BEAT_BOB[i]) for layer in layers])


def frames(view):
    fwd = 0 if view in ("S", "N") else 1
    out = [render([posed(view)])]
    out += [flight(view, i) for i in range(4)]
    if fwd:
        out += [render([p]) for p in PECK_SIDE]
    else:
        out.append(render([posed(view, head=(0, 1))]))
        out.append(render([posed(view, head=(0, 2))]))
    out.append(render([posed(view, crouch=True)]))
    out.append(render([posed(view, bob=-2)]))
    return out


ORDER = ["E", "S", "N"]
PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "sparrow",
                    "sprites", "creatures", "sparrow.png")


def sheet():
    rows = [frames(v) for v in ORDER]
    im = Image.new("RGBA", (W * len(rows[0]), H * len(rows)), (0, 0, 0, 0))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            im.alpha_composite(f, (i * W, j * H))
    return im


if __name__ == "__main__":
    sheet().save(PATH)
    print(PATH)
