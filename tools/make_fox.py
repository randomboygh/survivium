"""Draws the fox's sheet, content/animals/fox/sprites/creatures/fox.png.

Drawn by hand (2026-11-07) after a pixel-art fox sheet the user showed: a dark outline round
the whole fox, orange fur with a lighter back, white cheeks, bib and tail tip, ears with a
cream inner, thin legs in dark stockings. Frames 22x16, the head the same size in every view.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 7`, `walk: 4`): standing, the trot (diagonal pairs
of legs swing from the hip in turn, the passing leg lifted a pixel), and two idle frames: the
side flicks its tail and lowers its head to sniff; the front and back twitch the ears and
lower the head.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_fox.py
"""
import os

from PIL import Image

PAL = {"O": "#3a1610", "F": "#c85a28", "H": "#e27e3a", "S": "#9c3c1c", "R": "#6e2414", "C": "#f0c894",
       "B": "#f2eee4", "b": "#b8c0cc", "D": "#262838", "d": "#3c3e52", "E": "#1c1c2c", "N": "#1c1c2c"}
W, H = 22, 16


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W, r
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIDE = art([
    ".............R..R.....",
    "............RC.RC.....",
    "............FHHHHHF...",
    "...........FHHHHEHHF..",
    "...........FHHHHEHBBN.",
    "...........FFHHBBBBB..",
    "............FFBBBb....",
    ".....SFFHHHHHFFBBb....",
    "..bSFFHHHHHHHFFFBF....",
    ".bBBFFFFFFFFFFFFFS....",
    ".bBBFFS.SFFSSSFFS.....",
    "..bb..................",
], top=1)
LEG = 11
LEGX = {"bf": 7, "bn": 8, "ff": 14, "fn": 15}


def side(pose, bob=0):
    px = {(x, y + bob): c for (x, y), c in SIDE.items()}
    for name in ("bf", "ff", "bn", "fn"):
        dx, lift = pose.get(name, (0, 0))
        near = name.endswith("n")
        x = LEGX[name] + dx
        g = H - 1 - lift
        for y in range(LEG + bob, g + 1):
            dark = y >= H - 2 - lift
            px[(x, y)] = ("D" if dark else "F") if near else ("d" if dark else "S")
    return px


# Trot: diagonal pairs move together; the whole leg swings from the hip (shifts), the
# passing leg is lifted a pixel and the body dips a pixel on the planted legs.
TROT = [
    ({"fn": (1, 0), "bf": (1, 0), "ff": (-1, 0), "bn": (-1, 0)}, 0),
    ({"ff": (0, 1), "bn": (0, 1)}, 0),
    ({"ff": (1, 0), "bn": (1, 0), "fn": (-1, 0), "bf": (-1, 0)}, 0),
    ({"fn": (0, 1), "bf": (0, 1)}, 0),
]

FRONT = art([
    "..R......R..",
    "..RR....RR..",
    "..RCR..RCR..",
    "..FHHFFHHF..",
    ".FHHHHHHHHF.",
    ".FHEHHHHEHF.",
    ".FHEHHHHEHF.",
    "..FBBHHBBF..",
    "...FBNNBF...",
    "...SBBBBS...",
    "...SF..FS...",
    "...F.dd.F...",
    "...F.dd.F...",
    "...D....D...",
    "...D....D...",
], top=1, left=5)

BACK = art([
    "..R......R..",
    "..RR....RR..",
    "..RRR..RRR..",
    "..FHHFFHHF..",
    ".FHHHHHHHHF.",
    ".FHHHHHHHHF.",
    ".FHHHHHHHHF.",
    "..FHHHHHHF..",
    "...FFHHFF...",
    "...SFHHFS...",
    "...SFHHFS...",
    "...F.HH.F...",
    "...F.BB.F...",
    "...D.bb.D...",
    "...D....D...",
], top=1, left=5)
LEG_FB = 1 + 11
HEAD_FB = 1 + 7


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


def frames_side():
    s = side({})
    out = [s] + [side(p, bob) for p, bob in TROT]
    tail = {k: v for k, v in s.items() if k[0] <= 3 and k[1] >= 9}
    rest = {k: v for k, v in s.items() if k not in tail}
    out.append(rest | move(tail, lambda x, y: (x, y - 1)))
    head = {k: v for k, v in s.items() if k[0] >= 11 and k[1] <= 7}
    rest = {k: v for k, v in s.items() if k not in head}
    neck = {(12, 7): "F", (13, 7): "F", (12, 8): "F", (13, 8): "F"}
    out.append(rest | neck | move(head, lambda x, y: (x, y + 3)))
    return out


def frames_fb(base, head_rows, ears):
    """Walk: the diagonal pairs lift in turn (a leg is a column: its foot goes up a pixel)."""
    def lifted(cols):
        f = {}
        for (x, y), c in base.items():
            if y >= LEG_FB and x in cols and c in "DdFS":
                if y < H - 1:
                    f[(x, y)] = base.get((x, y + 1), c)
            else:
                f[(x, y)] = c
        return f
    out = [base, lifted({8, 11}), base, lifted({13, 10}), base]
    head = {k: v for k, v in base.items() if k[1] <= head_rows}
    rest = {k: v for k, v in base.items() if k not in head}
    out.append(rest | move(head, lambda x, y: (x + (1 if y <= ears else 0), y)))
    out.append(rest | move(head, lambda x, y: (x, y + 1)))
    return out


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def render(px, label):
    for (x, y) in px:
        assert 1 <= x <= W - 2 and 1 <= y <= H - 1, "%s: pixel %s cut (no room for its outline)" % (label, (x, y))
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for (x, y), ch in px.items():
        im.putpixel((x, y), hexc(PAL[ch]))
    for x in range(W):
        for y in range(H):
            if (x, y) not in px and any((x + dx, y + dy) in px for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                im.putpixel((x, y), hexc(PAL["O"]))
    return im


def rows():
    return [[render(p, "%s %d" % (v, i)) for i, p in enumerate(fr)]
            for v, fr in (("side", frames_side()), ("front", frames_fb(FRONT, 9, 3)), ("back", frames_fb(BACK, 8, 3)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "fox",
                    "sprites", "creatures", "fox.png")


def sheet():
    r = rows()
    im = Image.new("RGBA", (W * len(r[0]), H * len(r)), (0, 0, 0, 0))
    for j, row in enumerate(r):
        for i, f in enumerate(row):
            im.alpha_composite(f, (i * W, j * H))
    return im


if __name__ == "__main__":
    sheet().save(PATH)
    print(PATH)
