"""Draws the bear's sheet, content/animals/bear/sprites/creatures/bear.png.

Drawn by hand (2026-11-08) after a pixel-art bear the user showed: a dark outline, deep
brown fur with a darker line along the back, round ears, a shoulder hump and the line of
the shoulder, a tan muzzle with a black nose; from the front a big head over a round belly
and slightly bowed legs. Frames 30x20 (the user asked for it a little larger than before).

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 10`, `walk: 4`, `attack: 3`): standing, a
four-frame rolling amble (legs swing from shoulder and hip, the shoulder and haunch roll
with them, the body sinks when all four feet are down), two idle frames (sniffing with the
nose up, foraging with the head at the ground), and the attack: the forepaw raised with the
shoulder, the blow down with the whole fore half and a white slash of the claws, the slash
fading. The slash ("W", "w") is drawn without an outline.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_bear.py
"""
import os

from PIL import Image

PAL = {"O": "#1e0d05", "d": "#1e0d05", "R": "#2f180e", "S": "#472c19", "F": "#5b3c26", "c": "#aa7742", "C": "#cfa250",
       "N": "#1e0d05", "E": "#1e0d05", "D": "#24120a", "K": "#e8dcc0", "W": "#ffffff", "w": "#d8dce0"}
NO_OUTLINE = set("Ww")   # the claws' slash: a white streak over the ground, no outline
W, H = 30, 20


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W, (len(r), r)
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


SIDE = art([
    "..................RR.RR.....",
    "............SSS..RFFRFFR....",
    ".....RRRRRRRSFFFSRFFFFFFR...",
    "...RRFFFFFFFSFFFFSFFFFFFFF..",
    ".RRFFFFFFFFFSFFFFSFFFFFEFC..",
    "RSFFFFFFFFFFSFFFFSFFFFFFFCC.",
    "RFFFFFFFFFFFSFFFFFSFFFFFFCcN",
    "RFFFFFFFFFFFSFFFFFFSSFFFRcc.",
    "RFFFFSFFFFFSSFFFFFFFRRSS....",
    "RFFFFSSFFSSSSFFFFFFS........",
    "RFFFSSSSSSSSSFFFFFFR........",
    ".FFFSSSSSSSSSSFFFFRR........",
    ".FFSSSSSSSSSSSFFFSRR........",
    "..FSRRSSSSSSRRSFFSR.........",
], top=2, left=1)
LEG = 16
# near legs are 2 wide in the fur's colour, far ones 2 wide in shadow
LEGX = {"bn": 3, "bf": 7, "fn": 14, "ff": 17}


def side(pose, body=None):
    px = dict(body or SIDE)
    for name in ("bf", "ff", "bn", "fn"):
        sx, lift = pose.get(name, (0, 0))
        near = name.endswith("n")
        top = pose.get(name + "_top", LEG)
        n = max(H - lift - top - 1, 1)
        for y in range(top, H - lift):
            # the leg swings from the shoulder or hip: half the reach at the top, all of it at the foot
            x = LEGX[name] + round(sx * (0.5 + 0.5 * (y - top) / n))
            last = y == H - 1 - lift
            if near:
                px[(x, y)] = "S" if last else "F"
                px[(x + 1, y)] = "S" if last else "F"
                px[(x + 2, y)] = "R" if last else "S"
            else:
                px[(x, y)] = "R"
                px[(x + 1, y)] = "R" if last else "S"
    return px


# The walk, a bear's rolling amble: diagonal pairs swing whole from the shoulder and hip
# (2 cells), the shoulder and haunch roll with their leg, and the body sinks a cell when
# all four feet are down and rises as a pair passes.
TROT = [
    ({"fn": (2, 0), "bf": (2, 0), "ff": (-2, 0), "bn": (-2, 0)}, 1),
    ({"ff": (0, 2), "bn": (0, 2), "fn": (-1, 0), "bf": (-1, 0)}, 0),
    ({"ff": (2, 0), "bn": (2, 0), "fn": (-2, 0), "bf": (-2, 0)}, 1),
    ({"fn": (0, 2), "bf": (0, 2), "ff": (-1, 0), "bn": (-1, 0)}, 0),
]


def walk(pose, bob):
    """A frame of the walk: the body `bob` cells down, each near leg's shoulder or haunch
    carried a cell the way the leg swings, the legs from the lowered body."""
    body = {(x, y + bob): c for (x, y), c in SIDE.items()}
    for name in ("bn", "fn"):
        sx = pose.get(name, (0, 0))[0]
        if sx == 0:
            continue
        d = 1 if sx > 0 else -1
        lx = LEGX[name]
        block = {(x, y): c for (x, y), c in body.items() if lx - 1 <= x <= lx + 3 and LEG - 4 + bob <= y < LEG + bob}
        body |= {(x + d, y): c for (x, y), c in block.items()}
    tops = {n + "_top": LEG + bob for n in ("bf", "ff", "bn", "fn")}
    return side(pose | tops, body=body)


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


def split(px, test):
    return {k: v for k, v in px.items() if test(k)}, {k: v for k, v in px.items() if not test(k)}


def is_head(k):
    return k[0] >= 18 and k[1] < 10


def frames_side():
    s = side({})
    out = [s] + [walk(p, bob) for p, bob in TROT]
    head, rest = split(s, is_head)
    # idle 1: sniffing, the nose up; idle 2: foraging, the head down at the ground
    snout, _ = split(s, lambda k: k[0] >= 24 and 4 <= k[1] < 10)
    out.append(s | move(snout, lambda x, y: (x, y - 1)))
    neck = {(x, y): "F" for x in range(18, 24) for y in range(10, 14)}
    out.append(rest | neck | move(head, lambda x, y: (x, y + 4)))
    return out


def limb(x0, y0, x1, y1, claws=(0, -1), thick=4):
    """A heavy foreleg from the shoulder (x0, y0) to the paw at (x1, y1), `thick` cells
    across and shaded like the near legs, a broad dark paw with pale claws beyond it
    (`claws`: which way)."""
    px = {}
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    flat = abs(x1 - x0) >= abs(y1 - y0)
    shade = ["F"] * (thick - 1) + ["S"]
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for d in range(thick):
            o = d - thick // 2
            px[(x, y + o) if flat else (x + o, y)] = shade[d]
    for dx in range(-2, 2):
        for dy in range(-1, 2):
            if not (abs(dx + 0.5) > 1 and abs(dy) == 1):
                px[(x1 + dx, y1 + dy)] = "D"
    cx, cy = claws
    for k in (-1, 0, 1):
        px[(x1 + 2 * cx + (k if cy else 0), y1 + 2 * cy + (0 if cy else k))] = "K"
    return px


def carry(px, box, dx, dy):
    """The shoulder and shoulder blade in `box` (x0, y0, x1, y1) carried (dx, dy) with the
    swinging leg, laid over the body so nothing tears behind it."""
    x0, y0, x1, y1 = box
    block = {(x, y): c for (x, y), c in px.items() if x0 <= x <= x1 and y0 <= y <= y1}
    return px | {(x + dx, y + dy): c for (x, y), c in block.items()}


def raise_front(px, dy, head_dy=0):
    """The fore half of the bear (from the shoulder on) lifted `dy` cells, the head another
    `head_dy`; the rump stays."""
    out = {}
    for (x, y), c in px.items():
        if x >= 12 and y < LEG:
            out[(x, y - dy - (head_dy if x >= 18 else 0))] = c
        else:
            out[(x, y)] = c
    return out


def attack_side():
    """A blow from the shoulder: the fore half rises, the shoulder blade lifts and the
    heavy foreleg is thrown up and forward under the chin; the fore half drops with all its
    weight, the shoulder driving the paw down to the ground ahead (a white slash); then it
    leans on the paw while the slash fades."""
    hind = {"bn": (-1, 0), "bf": (-1, 0)}
    up = carry(raise_front(SIDE, 1, 0), (12, 4, 19, LEG - 1), 0, -1)
    wind = side(hind | {"ff": (0, 3), "ff_top": LEG - 1, "fn": (0, H - LEG)}, body=up)
    wind |= limb(16, 12, 23, 11, claws=(1, 0))
    low = carry({(x, y + (1 if x >= 12 else 0)): c for (x, y), c in SIDE.items()}, (12, 5, 19, LEG), 1, 0)
    strike = side({"bn": (1, 0), "fn": (0, H - LEG), "ff": (1, 0)} | {"ff_top": LEG + 1, "bn_top": LEG}, body=low)
    strike |= limb(18, 12, 23, 17, claws=(1, 0))
    strike |= {(x, y): "W" for x, y in ((26, 10), (27, 11), (27, 12), (28, 13), (28, 14), (27, 15), (28, 15),
                                         (26, 16), (27, 16), (26, 17))}
    lean = side({"ff": (1, 0), "fn": (0, H - LEG)}, body=carry(SIDE, (12, 5, 19, LEG - 1), 1, 0))
    lean |= limb(17, 13, 21, 18, claws=(1, 0))
    lean |= {(x, y): "w" for x, y in ((27, 11), (28, 13), (27, 15), (26, 17))}
    return [wind, strike, lean]


FRONT = art([
    ".RRR.......RRR.",
    ".RFRRFFFFFRRFR.",
    "..RRFFFFFFFRR..",
    "..SFFFFFFFFFS..",
    ".SFFEFFFFFEFFS.",
    "SFFFFCCCCCFFFFS",
    "SFFFCCCNCCCFFFS",
    "SFFFCCcccCCFFFS",
    "SFFFRcccccRFFFS",
    "SFFFFRRRRRFFFFS",
    "FFFFFSSSSSFFFFF",
    "FFFFSSSSSSSFFFF",
    "FFFSSSSRSSSSFFF",
    "FFFSSSRRRSSSFFF",
    ".FFSSRRRRRSSFF.",
    ".FFF.SRRRS.FFF.",
    "..FFF.....FFF..",
    "..FFS.....SFF..",
    "..SSS.....SSS..",
], top=1, left=7)

BACK = art([
    ".RRR.......RRR.",
    ".RFRRFFFFFRRFR.",
    "..RRFFFFFFFRR..",
    "..SFFFFFFFFFS..",
    ".SFFFFFFFFFFFS.",
    "SFFFFFFFFFFFFFS",
    "SFFFFFFFFFFFFFS",
    "SFFFFFFFFFFFFFS",
    "SFFFFSFFFSFFFFS",
    "SFFFFFSSSFFFFFS",
    "FFFFFFSRSFFFFFF",
    "FFFFFFFSFFFFFFF",
    "FFFSSSSSSSSSFFF",
    "FFFSSSRRRSSSFFF",
    ".FFSSRRRRRSSFF.",
    ".FFF.SRRRS.FFF.",
    "..FFF.....FFF..",
    "..FFS.....SFF..",
    "..SSS.....SSS..",
], top=1, left=7)
LEG_FB = 1 + 15
CX = 14


def fb_head(k):
    return k[1] <= 1 + 9 and 8 <= k[0] <= 20 and (k[1] <= 3 or 9 <= k[0] <= 19)


def frames_fb(base, front):
    def lifted(left):
        """One side's legs off the ground: that side from the shoulder down rises a cell
        and its foot another."""
        f = {}
        for (x, y), c in base.items():
            on = x < CX if left else x > CX
            if on and y >= 9:
                f[(x, y - (2 if y >= LEG_FB + 1 else 1))] = c
            else:
                f[(x, y)] = c
        return f

    def sunk():
        """All four feet down: the body a cell lower, the legs a cell shorter."""
        body = {(x, y + 1): c for (x, y), c in base.items() if y < LEG_FB}
        return body | {k: v for k, v in base.items() if k[1] > LEG_FB}
    out = [base, lifted(True), sunk(), lifted(False), sunk()]
    head, rest = split(base, fb_head)
    # idle 1: an ear flick; idle 2: the head bowed to the ground
    ears = {k: v for k, v in base.items() if k[1] == 1}
    out.append({k: v for k, v in base.items() if k not in ears} |
               {(x + (-1 if x < CX else 1), y): c for (x, y), c in ears.items()})
    if front:
        out.append(rest | move(head, lambda x, y: (x, y + 3)))
    else:
        out.append({k: v for k, v in base.items() if k[1] > 3})
    return out


def attack_fb(base, front):
    """The same blow seen from the front or behind: the right shoulder hunches up and the
    heavy forepaw is swung high out at the side; then shoulder and paw come down together
    to the ground beside the bear with a slash; then the slash fades."""
    right_leg = lambda k: k[0] > CX and k[1] >= LEG_FB - 1
    if front:   # the right foreleg is the one swung; the hind leg behind it shows in the shadow
        keep = {k: v for k, v in base.items() if not right_leg(k)}
        keep |= {(x, y): ("R" if y < H - 1 else "O") for x in (CX + 2, CX + 3) for y in range(LEG_FB - 1, H)}
        keep |= {(x, y): "S" for x in (CX + 4,) for y in range(LEG_FB - 1, H - 1)}
    else:       # from behind both hind legs stay planted; the foreleg swings out past the right one
        keep = dict(base)
    wind = carry(keep, (CX + 3, 4, CX + 7, LEG_FB - 2), 0, -1)
    wind |= limb(20, 9, 23, 3, claws=(0, -1))
    sunk = {(x, y + 1): c for (x, y), c in keep.items() if y < LEG_FB - 1} | {k: v for k, v in keep.items() if k[1] >= LEG_FB - 1}
    strike = carry(sunk, (CX + 3, 5, CX + 7, LEG_FB - 1), 1, 0)
    strike |= limb(21, 10, 23, 17, claws=(1, 0))
    strike |= {(x, y): "W" for x, y in ((25, 6), (26, 7), (27, 8), (27, 9), (28, 10), (28, 11), (28, 12), (27, 13),
                                         (28, 13), (27, 14), (26, 15), (27, 15))}
    fade = carry(keep, (CX + 3, 5, CX + 7, LEG_FB - 1), 1, 0) | limb(21, 11, 22, 17, claws=(1, 0))
    fade |= {(x, y): "w" for x, y in ((26, 7), (27, 9), (28, 11), (27, 13), (26, 15))}
    return [wind, strike, fade]


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def render(px, label):
    body = {k: v for k, v in px.items() if v not in NO_OUTLINE}
    for (x, y) in body:
        assert 1 <= x <= W - 2 and 1 <= y <= H - 1, "%s: pixel %s cut (no room for its outline)" % (label, (x, y))
    for (x, y) in px:
        assert 0 <= x < W and 0 <= y < H, "%s: pixel %s off the frame" % (label, (x, y))
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for (x, y), ch in body.items():
        im.putpixel((x, y), hexc(PAL[ch]))
    for x in range(W):
        for y in range(H):
            if (x, y) not in body and any((x + dx, y + dy) in body for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                im.putpixel((x, y), hexc(PAL["O"]))
    for (x, y), ch in px.items():
        if ch in NO_OUTLINE:
            im.putpixel((x, y), hexc(PAL[ch]))
    return im


def rows():
    return [[render(p, "%s %d" % (v, i)) for i, p in enumerate(fr)]
            for v, fr in (("side", frames_side() + attack_side()),
                          ("front", frames_fb(FRONT, True) + attack_fb(FRONT, True)),
                          ("back", frames_fb(BACK, False) + attack_fb(BACK, False)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "bear",
                    "sprites", "creatures", "bear.png")


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
