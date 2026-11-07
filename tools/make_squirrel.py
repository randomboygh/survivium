"""Draws the squirrel's sheet, content/animals/squirrel/sprites/creatures/squirrel.png.

Drawn by hand (2026-11-07) in the hare's style (tools/make_rabbit.py): a dark brown outline
round the whole squirrel, russet fur lighter on the head, a cream belly, a big bushy tail
curled up over the back, ear tufts, a round head with a large eye and its glint. Frames 14x15.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 7`, `walk: 4`): sitting, the bound (gathered,
pushing off, in the air, landing), and two idle frames: the tail flicked and the head
down at the ground.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. The sitting squirrel of each view is drawn; the bound moves, tilts and lifts it.

    python3 tools/make_squirrel.py
"""
import os

from PIL import Image

PAL = {"O": "#3a1a0c", "F": "#b85424", "H": "#d8763a", "S": "#8a3c1a", "T": "#e8944c", "t": "#f6bc7c",
       "B": "#f4e0c0", "E": "#1a0e08", "e": "#ffffff", "K": "#8a3a18", "N": "#5a2a14"}
W, H = 14, 15
TOP = 2


def art(rows):
    return {(x, y + TOP): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIT = {
    "E": art([
        "..ttt.........",
        ".tTTTt....K...",
        "tTTtTTt..KFK..",
        "tTt..TTtFHHHF.",
        ".t...tTFHHEeF.",
        ".....tTHHHEEFN",
        ".....TFHHHHBB.",
        ".....TFHHFBBB.",
        "....tTFFFFBB..",
        "....TSFFFBBB..",
        ".....SFFFFBF..",
        ".....SSFSSBF..",
        "......SS..SS..",
    ]),
    "S": art([
        "..........tt..",
        "...K....KtTTt.",
        "...KFFFFKtTtT.",
        "..FHHHHHHFtTt.",
        "..FEeHHeEFtTt.",
        "..FEEHHEEF.tT.",
        "...FHNNHF..tT.",
        "...SFBBFS.tT..",
        "..SFBBBBFStT..",
        "..SFBBBBFSTt..",
        "..SFBBBBFST...",
        "...SFBBFSS....",
        "...SS..SS.....",
    ]),
    "N": art([
        "..........tt..",
        "...K....KtTTt.",
        "...KFFFFKTttT.",
        "..FHHHHHHFtTT.",
        "..FHHHHHHFtTt.",
        "..FHHHHHHFtT..",
        "...FHHHHFtTt..",
        "...SFFFtTTt...",
        "..SFFFtTTtFS..",
        "..SFFtTTtFFS..",
        "..SFFtTtTFFS..",
        "...SFtTTtFS...",
        "...SS.tt.SS...",
    ]),
}


def is_head(view, x, y):
    y -= TOP
    return x >= 7 and y <= 7 if view == "E" else 1 <= y <= 6 and 2 <= x <= 9 and True


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


def tilt(px, k, pivot):
    """Columns right of `pivot` go up k pixels every 4 columns (left of it, down)."""
    return move(px, lambda x, y: (x, y - round(k * (x - pivot) / 4.0)))


def flick(px):
    """The tail's tip flicked: its top rows a pixel to the right."""
    return {(x + (1 if ch in "Tt" and y <= TOP + 2 else 0), y): ch for (x, y), ch in px.items()}


def frames(view):
    sit = SIT[view]
    head = {k: v for k, v in sit.items() if is_head(view, *k)}
    body = {k: v for k, v in sit.items() if not is_head(view, *k)}
    g = H - 1
    out = [sit]
    if view == "E":
        out.append(body | move(head, lambda x, y: (x, y + 1)))
        push = move(tilt(sit, 1, 4), lambda x, y: (x, y - 1))
        push.update({(5, g): "F", (4, g): "S"})
        out.append(push)
        air = move(sit, lambda x, y: (x, y - 2))
        air.update({(11, g - 2): "F", (12, g - 2): "F", (5, g - 2): "S", (4, g - 2): "S"})
        out.append(air)
        land = move(tilt(sit, -1, 8), lambda x, y: (x, y - 1))
        land.update({(10, g): "F", (11, g): "F"})
        out.append(land)
        out.append(flick(sit))
        out.append(body | move(head, lambda x, y: (x, y + 1)))
    else:
        feet = {k: v for k, v in sit.items() if k[1] < g}
        out.append(body | move(head, lambda x, y: (x, y + 1)))
        out.append(move(sit, lambda x, y: (x, y - 1)))
        out.append(move(feet, lambda x, y: (x, y - 2)))
        out.append(move(feet, lambda x, y: (x, y - 1)))
        out.append(flick(sit))
        out.append(body | move(head, lambda x, y: (x, y + 1)))
    return out


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def render(px):
    px = {k: v for k, v in px.items() if 0 <= k[0] < W and 0 <= k[1] < H}
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for (x, y), ch in px.items():
        im.putpixel((x, y), hexc(PAL[ch]))
    for x in range(W):
        for y in range(H):
            if (x, y) not in px and any((x + dx, y + dy) in px for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                im.putpixel((x, y), hexc(PAL["O"]))
    return im


ORDER = ["E", "S", "N"]
PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "squirrel",
                    "sprites", "creatures", "squirrel.png")


def sheet():
    rows = [[render(p) for p in frames(v)] for v in ORDER]
    im = Image.new("RGBA", (W * len(rows[0]), H * len(rows)), (0, 0, 0, 0))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            im.alpha_composite(f, (i * W, j * H))
    return im


if __name__ == "__main__":
    sheet().save(PATH)
    print(PATH)
