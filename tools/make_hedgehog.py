"""Draws the hedgehog's sheet, content/animals/hedgehog/sprites/creatures/hedgehog.png.

Drawn by hand (2026-11-08) in the redrawn animals' style: a dark outline, a dome of dark
brown spines with light tips, a pointed tan snout with a black nose and eye, tiny legs.
Frames 20x12.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 7`, `walk: 4`): standing, a four-frame shuffle,
and two idle frames: sniffing with the snout down, and curled into a ball.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_hedgehog.py
"""
import os

from PIL import Image

PAL = {"O": "#24180f", "K": "#4a3524", "k": "#6e5236", "t": "#d0b890", "F": "#9a7048", "C": "#d4ac7e",
       "N": "#120c08", "E": "#120c08", "D": "#3a2416", "d": "#2c1c10"}
W, H = 20, 12


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W, (len(r), r)
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIDE = art([
    "......t.t.t.......",
    "....tKKtKKtKt.....",
    "...tKkKKkKKkKt....",
    "..tKkKtKkKtKkKKC..",
    "..KkKtKkKtKkKKCCC.",
    ".tKkKkKkKkKkKCCECC",
    "..KKkKkKkKkKKCCCCN",
    "...FFFFFFFFFFFCC..",
    "....FFFFFFFFFF....",
], top=1)
LEGX = {"bf": 6, "bn": 5, "ff": 12, "fn": 11}
LEG = 10


def side(pose, body=None, bob=0):
    px = {(x, y + bob): c for (x, y), c in (body or SIDE).items()}
    for name in ("bf", "ff", "bn", "fn"):
        dx, lift = pose.get(name, (0, 0))
        near = name.endswith("n")
        x = LEGX[name] + (1 if not near else 0)
        px[(x, LEG - lift)] = "F" if near else "d"
        px[(x + dx, LEG + 1 - lift)] = "D" if near else "d"
    return px


WALK = [
    ({"fn": (1, 0), "bf": (1, 0), "ff": (-1, 0), "bn": (-1, 0)}, 0),
    ({"ff": (0, 1), "bn": (0, 1)}, 1),
    ({"ff": (1, 0), "bn": (1, 0), "fn": (-1, 0), "bf": (-1, 0)}, 0),
    ({"fn": (0, 1), "bf": (0, 1)}, 1),
]

BALL_SIDE = art([
    "......t.t.t.......",
    "....tKKtKKtKt.....",
    "...tKkKKkKKkKt....",
    "..tKkKtKkKtKkKt...",
    "..KkKtKkKtKkKtK...",
    "..tKkKkKkKkKkKt...",
    "..KKkKtKkKtKkKK...",
    "...KkKkKkKkKkK....",
    "....KKkKKkKKK.....",
], top=2)

FRONT = art([
    "..t.t.t.t..",
    ".tKKtKKtKt.",
    "tKkKKkKKkKt",
    "KkKCCCCCKkK",
    "KKCECCCECKK",
    "KkCCCNCCCkK",
    ".KFCCCCCFK.",
    "..FFFFFFF..",
], top=2, left=4)
BACK = art([
    "..t.t.t.t..",
    ".tKKtKKtKt.",
    "tKkKKkKKkKt",
    "KkKtKkKtKkK",
    "KKkKKtKKkKK",
    "KkKtKkKtKkK",
    ".KkKkKkKkK.",
    "..FFFFFFF..",
], top=2, left=4)
BALL_FB = art([
    "..t.t.t.t..",
    ".tKKtKKtKt.",
    "tKkKKkKKkKt",
    "KkKtKkKtKkK",
    "KKkKKtKKkKK",
    "tKkKtKkKtKt",
    ".KKkKkKkKK.",
    "..KKkKkKK..",
], top=3, left=4)


def fb(base, front):
    def legs(lift_l, lift_r):
        px = dict(base)
        for x, lift in ((6, lift_l), (12, lift_r)):
            px[(x, 10 - lift)] = "F"
            px[(x, 11 - lift)] = "D"
        return px
    out = [legs(0, 0), legs(1, 0), {(x, y + 1): c for (x, y), c in legs(0, 0).items() if y < 10} | {k: v for k, v in legs(0, 0).items() if k[1] >= 10},
           legs(0, 1), legs(0, 0)]
    if front:
        sniff = dict(legs(0, 0))
        sniff.pop((9, 7), None)
        sniff |= {(9, 7): "C", (9, 8): "N"}
    else:
        sniff = legs(0, 0)
    out += [sniff, BALL_FB]
    return out


def frames_side():
    out = [side({})] + [side(p, bob=b) for p, b in WALK]
    sniff = side({})
    for (x, y) in [(17, 7)]:
        sniff.pop((x, y), None)
    sniff |= {(16, 8): "C", (17, 8): "N", (17, 7): "C"}
    sniff.pop((17, 7), None)
    out += [sniff, BALL_SIDE]
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
    sh = lambda fr: [{(x + 1, y): c for (x, y), c in f.items()} for f in fr]
    return [[render(p, "%s %d" % (v, i)) for i, p in enumerate(fr)]
            for v, fr in (("side", sh(frames_side())), ("front", fb(FRONT, True)), ("back", fb(BACK, False)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "hedgehog",
                    "sprites", "creatures", "hedgehog.png")


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
