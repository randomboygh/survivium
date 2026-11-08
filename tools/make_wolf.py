"""Draws the wolf's sheet, content/animals/wolf/sprites/creatures/wolf.png.

Drawn by hand (2026-11-08), in the fox's style: a dark outline, grey fur with a dark saddle
along the back, a cream throat and muzzle, amber eyes. Frames 26x20; the head is the same
size in every view. Legs have a shape: the hind leg a thigh, a hock bent back and a paw, the
foreleg an upper arm, a thin forearm and a paw, each lit in front and shaded behind.

Rows (creatures.yaml `views: 3`): the side (facing right; the game mirrors it for left),
the front and the back. Columns (`frames: 10`, `walk: 4`, `attack: 3`): standing, the trot
(diagonal pairs swing from hip and shoulder, the passing paw lifted), two idle frames (the
tail flicks; the head turns down on the neck to sniff, its size and ears kept, see `turn`),
and the attack: crouched with the head low and fangs bared, the lunge with the jaws wide,
the snap.

Pictures are text: a character a pixel, each a colour of PAL; an outline goes round the
fill. `render` refuses a frame where a pixel has no room for its outline (nothing is cut).

    python3 tools/make_wolf.py
"""
import math
import os

from PIL import Image

PAL = {"O": "#1c1e24", "F": "#7c7a74", "H": "#a29e94", "S": "#5a5852", "R": "#3c3c40", "C": "#d6d0c2",
       "D": "#2a2a30", "d": "#3c3c44", "E": "#e0a428", "N": "#16161a", "P": "#8e2a2a", "T": "#f4f0e6"}
W, H = 26, 20


def art(rows, top=0, left=0):
    for r in rows:
        assert len(r) + left <= W, (len(r), r)
    return {(x + left, y + top): ch for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != "."}


# The head: ears 2 rows, skull 6, as tall and as long as the front's head is wide.
SIDE = art([
    "...............R..R.......",
    "..............RCRRHR......",
    "..............FCHHHHF.....",
    ".............FHHHHHHHF....",
    ".............FHHHHHEHHF...",
    ".............FHHHHHHHHHHN.",
    "......RRRRRRRFCHHHHHCCCCC.",
    "....RRRRRRRRRRFCCCCCCCC...",
    "..RRFHHHHHHHHHFCCCCC......",
    ".RRFHHHHHHHHHHHFCCCF......",
    ".RSFFHHHHHHHHHHFFCCF......",
    ".RSFFFFFFFFFFFFFFFFF......",
    ".RS.FFFSCCCCCSFFFFFS......",
    "..S..FFS.....SFFFS........",
], top=1)

# Legs from the hip or shoulder (row 13) to the ground (row 19): 'a' the leg, 'h' its lit
# front, 's' its shaded back, 'p' the paw. The hind leg: thigh, stifle, hock back, paw.
HIND = ["saah",
        "saah",
        ".sah",
        ".sa.",
        "sa..",
        ".a..",
        ".pp."]
FORE = ["ah.",
        "ah.",
        "sa.",
        ".a.",
        ".a.",
        ".a.",
        ".pp"]
LEG_TOP = 13
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
    return k[0] >= 13 and k[1] <= 8


def jaws(px, dy=0):
    """The mouth open: the lower jaw dropped, red inside, fangs."""
    out = dict(px)
    for x in range(20, 26):
        out.pop((x, 7 + dy), None)
    out |= {(20, 7 + dy): "P", (21, 7 + dy): "T", (22, 7 + dy): "P", (23, 7 + dy): "P",
            (19, 8 + dy): "C", (20, 8 + dy): "C", (21, 8 + dy): "C", (22, 8 + dy): "T"}
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


PIVOT = (14, 8.5)   # where the head sits on the neck


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
    for x0, x1 in ((14, 17), (17, 20)):
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
    tail, rest = split(s, lambda k: k[0] <= 3 and k[1] >= 9)
    out.append(rest | move(tail, lambda x, y: (x + (1 if y >= 13 else 0), y - 2)))
    head, rest = split(SIDE, is_head)
    out.append(side({}, body=rest | turn(head, 35)))
    return out


def attack_side():
    """Crouched with the head low and the fangs bared; the lunge, forelegs flung forward,
    jaws wide; the snap."""
    head, rest = split(SIDE, is_head)
    # stalking: the head held level and low, ears up, the fangs bared
    low = rest | {(x, y): "F" for x in range(14, 18) for y in range(8, 11)} | move(jaws(head), lambda x, y: (x, y + 2))
    crouch = side({"fn": (-1, 0), "ff": (-1, 0), "bn": (1, 0), "bf": (1, 0)}, body=low, bob=1)
    lunge = jaws(side({"fn": (3, 2), "ff": (3, 1), "bn": (-2, 0), "bf": (-2, 0)}), 0)
    snap = side({"fn": (2, 0), "ff": (1, 0), "bn": (-1, 0), "bf": (-1, 0)},
                body=rest | move(head, lambda x, y: (x, y + 1)) | {(x, 9): "F" for x in range(14, 18)})
    return [crouch, lunge, snap]


# Front: forelegs with an elbow (2 wide), a thin forearm and a paw turned out; the hind
# paws between them, farther, so higher.
FRONT = art([
    "..R.......R..",
    "..RR.....RR..",
    "..RCR...RCR..",
    "..FHHFFFHHF..",
    ".FHHHHHHHHHF.",
    ".FHEHHHHHEHF.",
    ".FCHHHHHHHCF.",
    "..FCCHHHCCF..",
    "...FCCNCCF...",
    "..SFCCCCCFS..",
    "..SHFCCCFHS..",
    "..SHFFCFFHS..",
    "...HF.d.FH...",
    "...H..d..H...",
    "...H.d.d.H...",
    "...F.d.d.F...",
    "...F.d.d.F...",
    "...F.D.D.F...",
    "...D.....D...",
], top=1, left=6)

BACK = art([
    "..R.......R..",
    "..RR.....RR..",
    "..RRR...RRR..",
    "..FHHFFFHHF..",
    ".FHHHHHHHHHF.",
    ".FHHHHHHHHHF.",
    ".FHHHHHHHHHF.",
    "..FHHHHHHHF..",
    "..FFHHRHHFF..",
    "..FHHHRHHHF..",
    "..FHHHRHHHF..",
    "..FHHHRHHHF..",
    "..FHHRRRHHF..",
    "...F.RRR.F...",
    "...F.RRR.F...",
    "...F..R..F...",
    "...F.d.d.F...",
    "...F.d.d.F...",
    "...D.....D...",
], top=1, left=6)
LEG_FB = 13
HEAD_FB = 9
CX = 12


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
        head_b = {(x, y + 3): c for (x, y), c in base.items() if y <= 7}
        out.append(head_b | {k: v for k, v in base.items() if k[1] > 7})
    return out


def nod(base):
    """The front head tipped down toward the viewer: the ears stay up, the forehead shows
    more and the muzzle sinks under it."""
    out = {}
    for (x, y), c in base.items():
        if y <= 3:
            out[(x, y + 1)] = c           # the ears, whole, with the brow
        elif y <= 5:
            out[(x, y + 1)] = c           # brow
            if y == 5:
                out[(x, y + 2)] = c       # more forehead shows
        elif y <= HEAD_FB:
            out[(x, y + 2)] = c           # eyes, muzzle, nose lower
    return out


def snarl(px, dy):
    out = dict(px)
    out |= {(11, 10 + dy): "T", (12, 10 + dy): "P", (13, 10 + dy): "T", (11, 11 + dy): "P", (12, 11 + dy): "P",
            (13, 11 + dy): "P", (12, 12 + dy): "C"}
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
    t, rest = split(base, lambda k: 10 <= k[0] <= 14 and k[1] >= 12 and base[k] in "RS")
    up = rest | {(x, y - 8): c for (x, y), c in t.items() if y - 8 >= 1}
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
    return [[render(p, "%s %d" % (v, i)) for i, p in enumerate(fr)]
            for v, fr in (("side", frames_side() + attack_side()),
                          ("front", frames_fb(FRONT, True) + attack_fb(FRONT, True)),
                          ("back", frames_fb(BACK, False) + attack_fb(BACK, False)))]


PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals", "wolf",
                    "sprites", "creatures", "wolf.png")


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
