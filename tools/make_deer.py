"""Draws the deer's sheet, content/animals/deer/sprites/creatures/deer.png.

Drawn by hand (2026-11-07) after a pixel-art fawn the user showed: a dark outline round the
whole deer, chocolate fur with cream spots, a cream throat and belly, a white rump patch,
ears out to the sides, small dark antler nubs, long thin legs with dark hooves. Frames 19x21,
the head the same size in every view.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 7`, `walk: 4`): standing, the walk (each leg a list
of x offsets by row, so it bends at the knee or hock; diagonal pairs reach and push in turn,
the passing pair folded), and two idle frames: an ear flick and grazing (the side bows the
neck to the grass, the front lowers the head before the forelegs, the back hides it behind
the rump with the ears showing).

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_deer.py
"""
import os

from PIL import Image

PAL = {"O": "#2a140c", "F": "#8a4e2c", "H": "#a8643a", "S": "#6a361e", "C": "#ecd09a", "W": "#f4ead6",
       "D": "#3a1e14", "d": "#4a2a1c", "E": "#1c2030", "K": "#3a2418", "N": "#1c1414", "s": "#57301a"}
W, H = 19, 21


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W, r
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIDE = art([
    "............K......",
    ".........SS.KF.....",
    "..........SFHHF....",
    "...........FHEHHF..",
    "...........FHHHHHN.",
    "...........FCCCCS..",
    "...........FCFS....",
    "..........FCFS.....",
    "..WSFFFFFFCFFS.....",
    "..WFHCHHHCHHHS.....",
    "...FHHCHHHHCFS.....",
    "...SFFFFFFFFFS.....",
    "....SCCCCCCSS......",
], top=1)
LEG = 13
LEGX = {"bf": 5, "bn": 6, "ff": 10, "fn": 11}
N = H - LEG  # rows of a leg standing on the ground

# A leg is its x offset in each row from the body down; a shorter list is a lifted foot.
STRAIGHT = [0] * N
HOCK = [0, 0, -1, -1, -1, -1, -1, -1]            # a hind leg: the hock bends it back
FORE_REACH = [0, 0, 1, 1, 1, 2, 2, 2]            # a foreleg reaching forward
FORE_PUSH = [0, 0, 0, -1, -1, -1, -2, -2]        # a foreleg pushing off behind
FORE_TUCK = [0, 0, 0, 0, 1, 1]                 # a foreleg lifted, the knee folded back
HIND_REACH = [0, 0, 0, 0, 1, 1, 1, 1]            # a hind leg swung forward under the body
HIND_PUSH = [0, -1, -1, -2, -2, -2, -3, -3]      # a hind leg stretched back
HIND_TUCK = [0, -1, -1, -2, -2, -2]                  # a hind leg lifted, the hock folded


def side(pose):
    px = dict(SIDE)
    for name in ("bf", "ff", "bn", "fn"):
        offs = pose.get(name, HOCK if name[0] == "b" else STRAIGHT)
        near = name.endswith("n")
        for i, dx in enumerate(offs):
            y = LEG + i
            hoof = i >= len(offs) - 2
            px[(LEGX[name] + dx, y)] = ("D" if hoof else "F") if near else ("d" if hoof else "s")
    return px


TROT = [
    {"fn": FORE_REACH, "bf": HIND_PUSH, "ff": FORE_PUSH, "bn": HIND_REACH},
    {"ff": FORE_TUCK, "bn": HIND_TUCK},
    {"ff": FORE_REACH, "bn": HIND_PUSH, "fn": FORE_PUSH, "bf": HIND_REACH},
    {"fn": FORE_TUCK, "bf": HIND_TUCK},
]

FRONT = art([
    "...K...K...",
    "SSFK...KFSS",
    ".SSFHHHFSS.",
    "...FHHHF...",
    "...EHHHE...",
    "...FHHHF...",
    "....CNC....",
    "....FCF....",
    "...SFCFS...",
    "..SCFCFCS..",
    "..SFFCFFS..",
    "..SFFFFFS..",
    "..SSFCFSS..",
    "...Fd.dF...",
    "...Fd.dF...",
    "...Fd.dF...",
    "...Dd.dD...",
    "...Dd.dD...",
], top=3, left=4)

BACK = art([
    "...K...K...",
    "SSFK...KFSS",
    ".SSFHHHFSS.",
    "...FHHHF...",
    "...FHHHF...",
    "...FHHHF...",
    "....FHF....",
    "....FHF....",
    "...SFHFS...",
    "..SCFHFCS..",
    "..SFCHCFS..",
    "..SFWWWFS..",
    "..SSWWWSS..",
    "...Fs.sF...",
    "...Fs.sF...",
    "...Fs.sF...",
    "...Dd.dD...",
    "...Dd.dD...",
], top=3, left=4)
LEG_FB = 3 + 13
FRONT_COLS = (7, 8, 10, 11)   # front-left, hind-left, hind-right, front-right


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


GRAZE_SIDE = art([
    "............FF.....",
    "............FCFK...",
    ".............FCKSS.",
    ".............FFHS..",
    ".............FHEH..",
    ".............FHHH..",
    "..............FCH..",
    "..............FCC..",
    "...............CN..",
], top=9)


def frames_side():
    s = side({})
    out = [s] + [side(p) for p in TROT]
    # idle 1: ear flick (the ear swings up)
    flick = {k: v for k, v in s.items() if not (k[1] == 2 and k[0] in (9, 10))}
    flick.update({(10, 1): "S", (11, 1): "S"})
    out.append(flick)
    # idle 2: grazing, the neck bowed forward and the muzzle down at the grass
    rest = {k: v for k, v in s.items() if not (k[0] >= 9 and k[1] <= 8)}
    rest.update(GRAZE_SIDE)
    out.append(rest)
    return out


def frames_fb(base, head_rows, ears_row):
    fl, hl, hr, fr = FRONT_COLS
    def lifted(cols):
        f = {}
        for (x, y), c in base.items():
            if y >= LEG_FB and x in cols:
                if y < H - 1:
                    f[(x, y)] = base.get((x, y + 1), c)
            else:
                f[(x, y)] = c
        return f
    out = [base, lifted({fl, hl}), base, lifted({fr, hr}), base]
    flick = dict(base)
    for (x, y), c in base.items():
        if y == ears_row and (x <= 5 or x >= 13):
            del flick[(x, y)]
            flick[(x, y - 1)] = c
    out.append(flick)
    head = {k: v for k, v in base.items() if k[1] <= head_rows}
    rest = {k: v for k, v in base.items() if k not in head}
    if base is FRONT:   # the head bowed to the grass in front of the forelegs
        out.append(rest | {(9, head_rows + 1): "F"} | move(head, lambda x, y: (x, y + 8)))
    else:               # from behind the bowed head is hidden; the ears show at the sides
        rest = {k: v for k, v in rest.items() if k[1] > head_rows + 1}
        out.append(rest | {(4, 12): "S", (5, 12): "S", (13, 12): "S", (14, 12): "S"})
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
            for v, fr in (("side", frames_side()), ("front", frames_fb(FRONT, 3 + 6, 4)),
                          ("back", frames_fb(BACK, 3 + 6, 4)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "deer",
                    "sprites", "creatures", "deer.png")


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
