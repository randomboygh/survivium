"""Draws the wild cat's sheet, content/animals/cat/sprites/creatures/cat.png.

Drawn by hand (2026-11-08) by the wolf's rules (tools/make_wolf.py): a dark outline, buff
grey fur with dark tabby stripes on the back and brow, a cream throat and muzzle, green
eyes, a pink nose, and a long thick ringed tail with a black tip. Frames 25x16; the head is
the same size in every view; legs have a thigh, a hock and a paw.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 10`, `walk: 4`, `attack: 3`): standing, the walk,
two idle frames (the tail flicks; the head turned down on the neck to sniff, see `turn`),
and the attack: crouched with a hiss, the pounce, a swipe of a forepaw.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_cat.py
"""
import math
import os
import os

from PIL import Image

PAL = {"O": "#221a14", "F": "#8c7a5e", "H": "#b4a282", "S": "#68583f", "R": "#3a2e22", "C": "#e4d8bc",
       "D": "#2c2218", "d": "#3e3226", "E": "#b4c23a", "N": "#b86a5c", "P": "#8e2a2a", "T": "#f4f0e6"}
W, H = 25, 16
SHIFT = 2   # the side drawn 2 columns in from the left, for the long tail


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W - SHIFT, (len(r), r)
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


# The head: ears 2 rows, skull 6, as tall and as long as the front's head is wide.
SIDE = art([
    "..............R...R....",
    ".............RCR.RCR...",
    ".............FHHHHHHF..",
    ".............FHHHHEHHF.",
    ".....RRSRRSRRFHHHHHHCN.",
    ".R.HRFHRHHRHHFCHHHCCC..",
    ".RRHRHHRHHRHHHFCCCCC...",
    "..R.FHHHHHHHHHFFCCF....",
    "...FFFFFFFFFFFFFFFF....",
    "....FFSCCCCCCSFFFF.....",
], top=1)

# the long ringed tail out behind, its tip black (left of column 0 before SHIFT)
SIDE |= {(-1, 6): "R", (0, 6): "H", (-1, 7): "R", (0, 7): "H", (-1, 5): "R"}

# Legs from the hip or shoulder (row 10) to the ground (row 15): 'a' the leg, 'h' its lit
# front, 's' its shaded back, 'p' the paw. The hind leg: thigh, hock back, paw.
HIND = ["saah",
        "saah",
        ".sa.",
        ".a..",
        ".a..",
        ".pp."]
FORE = ["ah.",
        "ah.",
        "sa.",
        ".a.",
        ".a.",
        ".pp"]
LEG_TOP = 10
LEGX = {"bf": 6, "bn": 4, "ff": 16, "fn": 14}


def side(pose, body=None, bob=0):
    px = {(x, y + bob): c for (x, y), c in (body or SIDE).items()}
    for name in ("bf", "ff", "bn", "fn"):
        sx, lift = pose.get(name, (0, 0))
        near = name.endswith("n")
        tpl = HIND if name[0] == "b" else FORE
        if lift:
            # the paw comes up under the leg, curled back a pixel
            tpl = tpl[:len(tpl) - 1 - lift] + [tpl[-1][1:] + "."]
        n = len(tpl)
        for r, row in enumerate(tpl):
            y = LEG_TOP + r + (bob if r < 2 else 0)
            off = round(sx * r / (n - 1)) if n > 1 else 0
            for c, ch in enumerate(row):
                if ch not in "apsh":
                    continue
                x = LEGX[name] + c + off
                if ch == "p":
                    px[(x, y)] = "D" if near else "d"
                else:
                    px[(x, y)] = {"a": "F", "h": "H", "s": "S"}[ch] if near else ("R" if ch == "s" else "S")
    return px


TROT = [
    ({"fn": (2, 0), "bf": (2, 0), "ff": (-2, 0), "bn": (-2, 0)}, 1),
    ({"ff": (0, 1), "bn": (0, 1), "fn": (-1, 0), "bf": (-1, 0)}, 0),
    ({"ff": (2, 0), "bn": (2, 0), "fn": (-2, 0), "bf": (-2, 0)}, 1),
    ({"fn": (0, 1), "bf": (0, 1), "ff": (-1, 0), "bn": (-1, 0)}, 0),
]


def move(px, f):
    return {f(x, y): ch for (x, y), ch in px.items()}


def split(px, test):
    return {k: v for k, v in px.items() if test(k)}, {k: v for k, v in px.items() if not test(k)}


def is_head(k):
    return k[0] >= 13 and k[1] <= 7


def jaws(px, dy=0):
    """The mouth open in a hiss: the jaw dropped, red inside, fangs."""
    out = dict(px)
    out.pop((21, 5 + dy), None)
    out |= {(19, 6 + dy): "P", (20, 6 + dy): "T", (21, 6 + dy): "P", (19, 7 + dy): "C", (20, 7 + dy): "T"}
    return out


def scale2x(g):
    """EPX/Scale2x: each pixel becomes four, corners taking a neighbour's colour where two
    neighbours agree, so slants stay slants when the picture is turned."""
    o = {}
    xs = [x for x, _ in g] or [0]
    ys = [y for _, y in g] or [0]
    for y in range(min(ys) - 1, max(ys) + 2):
        for x in range(min(xs) - 1, max(xs) + 2):
            P, A, B, C, D = g.get((x, y)), g.get((x, y - 1)), g.get((x + 1, y)), g.get((x - 1, y)), g.get((x, y + 1))
            for (dx, dy), e in (((0, 0), C if C == A and C != D and A != B else P),
                                ((1, 0), A if A == B and A != C and B != D else P),
                                ((0, 1), C if D == C and D != B and C != A else P),
                                ((1, 1), B if B == D and B != A and D != C else P)):
                if e is not None:
                    o[(2 * x + dx, 2 * y + dy)] = e
    return o


PIVOT = (13, 7.5)   # where the head sits on the neck


def turn_point(p, deg):
    a = math.radians(deg)
    u, v = p[0] + 0.5 - PIVOT[0], p[1] + 0.5 - PIVOT[1]
    return PIVOT[0] + u * math.cos(a) - v * math.sin(a), PIVOT[1] + u * math.sin(a) + v * math.cos(a)


def turn(head, deg):
    """The head turned nose-down by `deg` about the neck, its size and shape kept
    (RotSprite: blown up 8x by Scale2x, turned, sampled back). The ears are carried upright
    to where their bases went, and the eye and nose are put back as single pixels, since
    turning would smear those."""
    ears = {k: v for k, v in head.items() if k[1] <= 2}
    skull = {k: ("H" if v in "EN" else v) for k, v in head.items() if k[1] > 2}
    big = skull
    for _ in range(3):
        big = scale2x(big)
    a = math.radians(deg)
    out = {}
    for y in range(H):
        for x in range(W):
            u, v = x + 0.5 - PIVOT[0], y + 0.5 - PIVOT[1]
            sx = PIVOT[0] + u * math.cos(a) + v * math.sin(a)
            sy = PIVOT[1] - u * math.sin(a) + v * math.cos(a)
            c = big.get((math.floor(sx * 8), math.floor(sy * 8)))
            if c is not None:
                out[(x, y)] = c
    for x0, x1 in ((13, 17), (17, 21)):
        part = {k: v for k, v in ears.items() if x0 <= k[0] < x1}
        bx = sum(k[0] for k in part) / len(part)
        nx, ny = turn_point((bx, 2), deg)
        dx, dy = round(nx - bx - 0.5), round(ny - 2.5)
        out |= {(x + dx, y + dy): v for (x, y), v in part.items()}
    for (x, y), c in head.items():
        if c in "EN":
            nx, ny = turn_point((x, y), deg)
            out[(math.floor(nx), math.floor(ny))] = c
    return out


def frames_side():
    s = side({})
    out = [s] + [side(p, bob=b) for p, b in TROT]
    tail, rest = split(s, lambda k: k[0] <= 3 and 5 <= k[1] <= 8)
    out.append(rest | move(tail, lambda x, y: (x, y - (2 if x <= 0 else 1 if x <= 2 else 0))))
    head, rest = split(SIDE, is_head)
    out.append(side({}, body=rest | turn(head, 35)))
    return out


def attack_side():
    """Crouched low with the ears up and a hiss; the pounce, forelegs flung forward; the
    swipe of a forepaw."""
    head, rest = split(SIDE, is_head)
    low = rest | {(x, y): "F" for x in range(14, 18) for y in range(7, 9)} | move(jaws(head), lambda x, y: (x, y + 2))
    crouch = side({"fn": (-1, 0), "ff": (-1, 0), "bn": (1, 0), "bf": (1, 0)}, body=low, bob=1)
    lunge = jaws(side({"fn": (3, 2), "ff": (3, 1), "bn": (-2, 0), "bf": (-2, 0)}), 0)
    swipe = side({"fn": (3, 3), "ff": (0, 0), "bn": (-1, 0), "bf": (-1, 0)})
    return [crouch, lunge, swipe]


# Front: forelegs with an elbow (2 wide), a thin forearm and a paw turned out; the hind
# paws between them, farther, so higher.
FRONT = art([
    "..R.....R..",
    ".RCR...RCR.",
    ".FHHRHRHHF.",
    ".FHHHHHHHF.",
    ".FHEHHHEHF.",
    ".FCHHHHHCF.",
    "..FCCNCCF..",
    "..SFCCCFS..",
    "..SHFCFHS..",
    "..SHF.FHS..",
    "...H.d.H...",
    "...F.d.F...",
    "...F.D.F...",
    "...F...F...",
    "...D...D...",
], top=1, left=6)

BACK = art([
    "..R.....R..",
    ".RRR...RRR.",
    ".FHHRHRHHF.",
    ".FHHHRHHHF.",
    ".FHHHHHHHF.",
    ".FHHHHHHHF.",
    "..FHHHHHF..",
    "..FFHRHFF..",
    "..FHHRHHF..",
    "..FHHRHHF..",
    "...FFRFF...",
    "...F.H.F...",
    "...F.R.F...",
    "...F.d.F...",
    "...D...D...",
], top=1, left=6)
LEG_FB = 10
HEAD_FB = 7
CX = 11


def frames_fb(base, front):
    def lifted(left):
        f = {}
        for (x, y), c in base.items():
            on = (x < CX if left else x > CX)
            if on and y >= LEG_FB - 1 and c in "DdFS":
                f[(x, y - (2 if y >= LEG_FB + 1 else 1))] = c
            else:
                f[(x, y)] = c
        return f

    def sunk():
        body = {(x, y + 1): c for (x, y), c in base.items() if y < LEG_FB - 1}
        return body | {k: v for k, v in base.items() if k[1] >= LEG_FB}
    out = [base, lifted(True), sunk(), lifted(False), sunk()]
    head, rest = split(base, lambda k: k[1] <= HEAD_FB)
    ears, _ = split(base, lambda k: k[1] <= 3)
    out.append({k: v for k, v in base.items() if k not in ears} |
               {(x + (-1 if x < CX else 1), y): c for (x, y), c in ears.items() if y <= 2} |
               {k: v for k, v in ears.items() if k[1] == 3})
    if front:
        out.append(rest | nod(base))
    else:
        head_b = {(x, y + 3): c for (x, y), c in base.items() if y <= 6}
        out.append(head_b | {k: v for k, v in base.items() if k[1] > 6})
    return out


def nod(base):
    """The front head tipped down toward the viewer: the ears stay up, the forehead shows
    more and the muzzle sinks under it."""
    out = {}
    for (x, y), c in base.items():
        if y <= 4:
            out[(x, y + 1)] = c           # the ears, whole, with the brow
            if y == 4:
                out[(x, y + 2)] = c       # more forehead shows
        elif y <= HEAD_FB:
            out[(x, y + 2)] = c           # eyes, muzzle, nose lower
    return out


def snarl(px, dy):
    out = dict(px)
    out |= {(10, 8 + dy): "T", (11, 8 + dy): "P", (12, 8 + dy): "T", (11, 9 + dy): "P"}
    return out


def attack_fb(base, front):
    legs = {k: v for k, v in base.items() if k[1] >= LEG_FB - 1}
    body = {k: v for k, v in base.items() if k[1] < LEG_FB - 1}
    spread = {(x + (-1 if x < CX else 1), y): c for (x, y), c in legs.items() if x != CX}
    if front:
        crouch = snarl({(x, y + 1): c for (x, y), c in body.items()} | legs, 1)
        lunge = snarl({(x, y + 2): c for (x, y), c in body.items()} | spread, 2)
        snap = {(x, y + 1): c for (x, y), c in body.items()} | legs
        return [crouch, lunge, snap]
    t, rest = split(base, lambda k: k[0] == CX and k[1] >= 11 and base[k] in "RH")
    up = rest | {(x, y - 7): c for (x, y), c in t.items() if y - 7 >= 1}
    crouch = {(x, y + 1): c for (x, y), c in up.items() if y < LEG_FB - 1} | {k: v for k, v in up.items() if k[1] >= LEG_FB - 1}
    lunge = {(x, y + 1): c for (x, y), c in up.items() if y < LEG_FB - 1} | \
        {(x + (-1 if x < CX else 1), y): c for (x, y), c in up.items() if y >= LEG_FB - 1 and x != CX}
    return [crouch, lunge, up]


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
    sh = lambda fr, d: [{(x + d, y): c for (x, y), c in f.items()} for f in fr]
    return [[render(p, "%s %d" % (v, i)) for i, p in enumerate(fr)]
            for v, fr in (("side", sh(frames_side() + attack_side(), SHIFT)),
                          ("front", sh(frames_fb(FRONT, True) + attack_fb(FRONT, True), 1)),
                          ("back", sh(frames_fb(BACK, False) + attack_fb(BACK, False), 1)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "cat",
                    "sprites", "creatures", "cat.png")


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
