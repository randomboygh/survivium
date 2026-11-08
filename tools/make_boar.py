"""Draws the boar's sheet, content/animals/boar/sprites/creatures/boar.png.

Drawn by hand (2026-11-07) after a pixel-art boar the user showed: a dark outline round the
whole boar, rust-brown fur, a slate mane along the back, a dished face (the top of the muzzle
curves in from the brow to the snout), an upright ear, a pink snout disc with a nostril, a
pale tusk; the haunch and the shoulder shaded so the legs read heavy. Frames 23x15, the
game's size, the head the same size in every view.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 10`, `walk: 4`, `attack: 3`): standing, a
four-frame trot (diagonal pairs reach and lift in turn), two idle frames (a tail flick and
rooting with the snout at the ground), and the attack: crouched with the head low, the
lunge, the tusks tossed up. No animal attacks yet, so the game keeps the last three out of
the idles.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_boar.py
"""
import os

from PIL import Image

PAL = {"O": "#2a120a", "F": "#9a4e26", "H": "#b8642e", "S": "#7a3a1c", "R": "#5e2a14", "M": "#2c3246",
       "m": "#4a5674", "T": "#f2e2b8", "E": "#1a1010", "e": "#ffffff", "N": "#c27a5a", "n": "#3a1a10",
       "D": "#3a1c10", "d": "#2e160c"}
W, H = 23, 15


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W, (len(r), r)
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIDE = art([
    ".......................",
    "................S......",
    ".......M..M..M.SH......",
    ".....MMmMMmMMmMMHF.....",
    "...FHHMMMMMMMMMFHHF....",
    "..FHHHHHHHHHHHMFHeEF...",
    ".RSHHHHHHSHHHHSFHEEHHN.",
    ".RSHHHHHHHSHHHSFHHHHHn.",
    "..SFHHHHHHSFHHSFFHHTHN.",
    "..SFFHHHHFSFFFSSFFFT...",
    "...SFFFFSSFFFFSFFF.....",
])
LEG = 11
LEGX = {"bf": 4, "bn": 4, "ff": 11, "fn": 12}


def side(pose, body=None, dx=0, dy=0):
    px = {(x + dx, y + dy): c for (x, y), c in (body or SIDE).items()}
    for name in ("bf", "ff", "bn", "fn"):
        sx, lift = pose.get(name, (0, 0))
        x = LEGX[name] + sx + dx
        for y in range(LEG + dy, H - lift):
            hoof = y == H - 1 - lift
            thick = y == LEG + dy and lift == 0
            if name.endswith("n"):
                px[(x, y)] = "D" if hoof else "F"
                px[(x + 1, y)] = "D" if hoof else ("H" if thick else "S")
                if thick:
                    px[(x + 2, y)] = "S"
            else:
                px[(x - 1, y)] = "d" if hoof else "S"
                if thick:
                    px[(x - 2, y)] = "R"
    return px


TROT = [
    {"fn": (1, 0), "bf": (1, 0), "ff": (-1, 0), "bn": (-1, 0)},
    {"ff": (0, 1), "bn": (0, 1)},
    {"ff": (1, 0), "bn": (1, 0), "fn": (-1, 0), "bf": (-1, 0)},
    {"fn": (0, 1), "bf": (0, 1)},
]

FRONT = art([
    "......MmM......",
    "..SS.MMMMM.SS..",
    "..SHRFHHHFRHS..",
    ".SRHHHHHHHHHRS.",
    ".SReEHHHHHEeRS.",
    ".SREEHHHHHEERS.",
    ".SFRHNNNNNHRFS.",
    ".SFTNnNNNnNTFS.",
    ".SFTRNNNNNRTFS.",
    "..SFRRRRRRRFS..",
    "..S.HF...FH.S..",
    "..d.HF...FH.d..",
    "....DD...DD....",
], top=2, left=4)

BACK = art([
    ".....MMmMM.....",
    "..R.SMMMMMS.R..",
    "..RRFHMMMHFRR..",
    ".SFHHHHMHHHHFS.",
    "SFHHHHHMHHHHHFS",
    "SFHHHHHHHHHHHFS",
    "SFHHHHHHHHHHHFS",
    "SFHHHHHRHHHHHFS",
    "SFFFFFRSRFFFFFS",
    ".SFFFFFRFFFFFS.",
    ".FS.d.....d.SF.",
    ".DD.d.....d.DD.",
    "....d.....d....",
], top=2, left=4)
LEG_FB = 2 + 10


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


def head_of(px):
    return {k: v for k, v in px.items() if k[0] >= 15 and k[1] >= 1}


def frames_side():
    s = side({})
    out = [s] + [side(p) for p in TROT]
    # idle 1: the tail flicked up; idle 2: rooting, the snout down at the ground
    flick = dict(s)
    del flick[(1, 6)]
    flick[(1, 4)] = "R"
    out.append(flick)
    head = head_of(s)
    rest = {k: v for k, v in s.items() if k not in head}
    out.append(rest | move(head, lambda x, y: (x, y + 2)))
    return out


def attack_side():
    """Charge and toss: crouched with the head low, lunging forward, the tusks thrown up."""
    s = side({})
    head = head_of(s)
    rest = {k: v for k, v in s.items() if k not in head}
    crouch = side({"fn": (1, 0), "ff": (1, 0), "bn": (-1, 0), "bf": (-1, 0)})
    crouch = {k: v for k, v in crouch.items() if k not in head} | move(head, lambda x, y: (x, y + 2))
    lunge = side({"fn": (2, 1), "ff": (2, 1), "bn": (-1, 0), "bf": (-1, 0)})
    lunge = {k: v for k, v in lunge.items() if k not in head} | move(head, lambda x, y: (x, y + 1))
    snout = lambda k: k[0] >= 18 and k[1] >= 4
    toss_body = {k: v for k, v in SIDE.items() if not snout(k)}
    toss_head = move({k: v for k, v in SIDE.items() if snout(k)}, lambda x, y: (x, y - 1))
    toss = side({"fn": (0, 1), "ff": (0, 0)}, body=toss_body | toss_head)
    return [crouch, lunge, toss]


def frames_fb(base, rooting):
    def lifted(left):
        f = {}
        for (x, y), c in base.items():
            if y >= LEG_FB and (x <= 10 if left else x >= 12):
                if y < H - 1:
                    f[(x, y)] = base.get((x, y + 1), c)
            else:
                f[(x, y)] = c
        return f
    out = [base, lifted(True), base, lifted(False), base]
    flick = dict(base)
    for (x, y), c in base.items():
        if y == 3 and c == "S" and (x <= 7 or x >= 15):
            del flick[(x, y)]
            flick[(x + (-1 if x <= 7 else 1), y - 1)] = c
    out.append(flick)
    if rooting:
        head = {k: v for k, v in base.items() if 3 <= k[1] <= 11 and 6 <= k[0] <= 16}
        rest = {k: v for k, v in base.items() if k not in head}
        out.append(rest | move(head, lambda x, y: (x, y + 1)))
    else:
        out.append(move(base, lambda x, y: (x, y + 1) if y < LEG_FB else (x, y)) |
                   {k: v for k, v in base.items() if k[1] >= LEG_FB + 1})
    return out


def attack_fb(base, front):
    head = {k: v for k, v in base.items() if 3 <= k[1] <= 11 and 6 <= k[0] <= 16}
    rest = {k: v for k, v in base.items() if k not in head}
    low = rest | move(head, lambda x, y: (x, y + 1))
    up = {k: v for k, v in base.items()}
    up = move(up, lambda x, y: (x, y - 1) if y < LEG_FB else (x, y)) | {k: v for k, v in base.items() if k[1] >= LEG_FB}
    return [low, up, base]


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
            for v, fr in (("side", frames_side() + attack_side()), ("front", frames_fb(FRONT, True) + attack_fb(FRONT, True)),
                          ("back", frames_fb(BACK, False) + attack_fb(BACK, False)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "boar",
                    "sprites", "creatures", "boar.png")


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
