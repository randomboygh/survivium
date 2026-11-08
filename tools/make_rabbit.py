"""Draws the hare's sheet, content/animals/rabbit/sprites/creatures/rabbit.png.

Drawn by hand (2026-11-07) after a pixel-art rabbit the user showed: a dark brown outline
round the whole hare, sandy fur lighter on the back, a cream belly and white scut, long
ears with a pink inner, a round head with a large eye and its glint. Frames 14x13 (made a little smaller
on 2026-11-08 at the user's ask; it was 16x15).

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 7`, `walk: 4`): sitting, the bound (gathered,
pushing off, in the air, landing), and two idle frames: the ears up (alert) and the head
down at the grass.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. The sitting hare of each view is drawn; the bound moves, tilts and lifts it.

    python3 tools/make_rabbit.py
"""
import os

from PIL import Image

PAL = {"O": "#3c2618", "F": "#d4a474", "H": "#eccb98", "S": "#b07c50", "B": "#f4e6c8",
       "I": "#c2645a", "i": "#e4a090", "E": "#1a0e08", "e": "#ffffff", "N": "#b4605a", "W": "#f6eee0"}
W, H = 14, 13
TOP = 2  # room above the sitting hare for its ears in a leap


def art(rows):
    return {(x, y + TOP): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIT = {
    "E": art([
        "..FFi.........",
        "...FIi........",
        "....FIF.......",
        ".....FIHHF....",
        ".....FHHHHF...",
        "..HHHSHHHHHF..",
        ".HHHHHSHHEeHF.",
        "FHFFFFFSHEEHFN",
        "WFFFFFFFSHHBB.",
        ".SFFFSFFSSBB..",
        "..SSSSSSSBBB..",
    ]),
    "S": art([
        "...Fi....iF...",
        "...FIF..FIF...",
        "....FIFFIF....",
        "....FHHHHF....",
        "...FHHHHHHF...",
        "...FEeHHeEF...",
        "...FEEHHEEF...",
        "...SHHNNHHS...",
        "..SFFBBBBFFS..",
        "..SSFBBBBFSS..",
        "...SSB..BSS...",
    ]),
    "N": art([
        "...FF....FF...",
        "...FHF..FHF...",
        "....FHFFHF....",
        "....FHHHHF....",
        "...FHHHHHHF...",
        "...FHHHHHHF...",
        "...SFHHHHFS...",
        "..SFFHHHHFFS..",
        "..SFFFWWFFFS..",
        "..SSFWWWWFSS..",
        "...SSSSSSSS...",
    ]),
}
# The ears pricked straight up, for the side view's alert frame.
EARS_UP = art(["......FiF.....", "......FIF.....", "......FIF.....", "......FIH....."])


def is_head(view, x, y):
    y -= TOP
    return (x >= 7 and y <= 8) or y <= 3 if view == "E" else y <= 7


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


def tilt(px, k, pivot):
    """Columns right of `pivot` go up k pixels every 4 columns (left of it, down)."""
    return move(px, lambda x, y: (x, y - round(k * (x - pivot) / 4.0)))


def frames(view):
    sit = SIT[view]
    head = {k: v for k, v in sit.items() if is_head(view, *k)}
    body = {k: v for k, v in sit.items() if not is_head(view, *k)}
    g = H - 1
    out = [sit]
    if view == "E":
        out.append(body | move(head, lambda x, y: (x, y + 1)))
        push = move(tilt(sit, 1, 3), lambda x, y: (x, y - 1))
        push.update({(1, g): "F", (0, g): "S", (2, g - 1): "S"})
        out.append(push)
        air = move(sit, lambda x, y: (x, y - 2))
        air.update({(10, g - 2): "B", (11, g - 2): "B", (1, g - 2): "F", (0, g - 2): "S"})
        out.append(air)
        land = move(tilt(sit, -1, 8), lambda x, y: (x, y - 1))
        land.update({(9, g): "B", (10, g): "B"})
        out.append(land)
        alert = {k: v for k, v in sit.items() if not (k[1] <= 3 + TOP and v in "FIi" and k[0] < 8)}
        alert.update(EARS_UP)
        out.append(alert)
        out.append(body | move(head, lambda x, y: (x + 1, y + 2)))
    else:
        feet = {k: v for k, v in sit.items() if k[1] < g}
        out.append(body | move(head, lambda x, y: (x, y + 1)))
        out.append(move(sit, lambda x, y: (x, y - 1)))
        out.append(move(feet, lambda x, y: (x, y - 2)))
        out.append(move(feet, lambda x, y: (x, y - 1)))
        out.append(body | head | move(head, lambda x, y: (x, y - 1)))
        out.append(body | move(head, lambda x, y: (x, y + 2)))
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
PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "rabbit",
                    "sprites", "creatures", "rabbit.png")


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
