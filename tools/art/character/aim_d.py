"""The bow's shot after the user's review of 2026-11-20 16:55-16:57 MSK. Turned away (ne) the view
is back as it was (aim_b: the bow by the body's right side from under the cheek, the hands where
they were), only the bow's visible part is an arc and not a straight stick, and the arrow is the
line they liked (aim_c), from the hand up and right through the bow. On every view the bow's own
dark edge is gone wherever it lay next to the figure's outline («убери двойную линию обводки»):
the outline is the figure's alone, the bow keeps a dark line only inside, against the skin and
between its string and its wood. The rest as aim_c (the grey arrowhead from the front)."""
from aim_a import *  # noqa: F401,F403
import os
import aim_c
import work_proto
from aim_c import grid

AIM = dict(aim_c.AIM)

# Turned away (ne): the bow by the body's right side, from under the cheek to the knee: the limb's
# arc (box row: the x of its light pixel, the shade right of it), its ends in by a pixel, and the
# string straight between them, next to the body (the figure's outline between the two).
NE_ARC = {10: 12, 11: 13, 12: 13, 13: 13, 14: 13, 15: 12}
NE_STRING = {(11, y): "s" for y in range(11, 17)}
NE_END = {(12, 16): "p"}
NE_GRIP = (13, 12)


def ne_bow(up=0):
    """The bow, `up` pixels higher (drawn, it is lifted a pixel)."""
    out = {}
    for y, x in NE_ARC.items():
        out[(x, y - up)] = "P"
        out[(x + 1, y - up)] = "p"
    for part in (NE_STRING, NE_END):
        for (x, y), c in part.items():
            out[(x, y - up)] = c
    return out


def ne_arrow(nock, shaft, head):
    """An arrow up and right from `nock`, two pixels a row: `shaft` rows of shaft, `head` of its
    grey head and the head's point."""
    out = {}
    x, y = nock
    for i in range(shaft + head):
        a, b = ("n", "o") if i < shaft else ("A", "a")
        out[(x + i, y - i)] = a
        out[(x + i + 1, y - i)] = b
    out[(x + shaft + head, y - shaft - head)] = "a"
    return out


def ne_lifted():
    """The bow a pixel higher. The light pixel of its upper end would lie against the ear: left
    out, so that the figure's outline parts the two."""
    out = ne_bow(1)
    del out[(12, 9)]
    return out


def NE(body, pixels):
    rows, btop = grid(pixels)
    return F(1, 12, body + NE_LEGS, btop, rows, a=1, f=False, grip=NE_GRIP)


def _with(bow, arrow):
    out = dict(bow)
    out.update(arrow)
    return out


AIM["ne"] = [
    # 1: the arrow on the string, the near hand at its nock.
    NE([".....VVVC.....",
        "....ccccCC44..",
        ".....VcccC....",
        ".....uuuuu...."], _with(ne_bow(), ne_arrow((12, 13), 3, 2))),
    # 2: drawn: the hand back at the shoulder, the bow lifted, the arrow's head at the bow.
    NE([".....VVVC55...",
        "....ccccCCC...",
        ".....VcccC....",
        ".....uuuuu...."], _with(ne_lifted(), ne_arrow((11, 12), 2, 2))),
    # 3: loosed: the hand thrown back down.
    NE([".....VVVC.....",
        "....ccccCCC...",
        ".....Vccc45...",
        ".....uuuu44..."], ne_bow()),
    # 4: the hand back on the string.
    NE([".....VVVC.....",
        "....ccccCC45..",
        ".....VcccC44..",
        ".....uuuuu...."], ne_bow()),
]

# From the side, drawn: the limb whole beside the arrow's head (the head's dark edge is gone), and
# a pixel thicker next to the arrow (its grip), so that the dark between the face and the limb is
# not two pixels thick.
_E = list(E_BOW_DRAWN)
_E[4] = "..........s..PPp.."
_E[7] = "..........s..PPp.."
_e2 = AIM["e"][1]
AIM["e"] = [AIM["e"][0], F(_e2["bob"], _e2["top"], _e2["rows"], 6, _E, a=2, grip=(13, 12)), AIM["e"][2], AIM["e"][3]]

# Turned (se), drawn: the upper limb two pixels wide (it was one between two dark edges), so that
# the gap between the string and the limb is a line and not a black square.
_SE = list(SE_BOW_DRAWN)
_SE[1] = "........ss..PpK."
_SE[2] = "........son.PpK."
_s2, _s3 = AIM["se"][1], AIM["se"][2]
# Loosed: the shoulder of the arm thrown back reaches the neck (the outline under the head and
# the one over the arm were two lines there).
_rows3 = list(_s3["rows"])
assert _rows3[0] == ".....VkkVc....", _rows3
_rows3[0] = "....cVkkVc...."
AIM["se"] = [AIM["se"][0], F(_s2["bob"], _s2["top"], _s2["rows"], 10, _SE, a=3, grip=(12, 14)),
             F(_s3["bob"], _s3["top"], _rows3, 10, SE_BOW_LOOSED, a=3, grip=(12, 14)), AIM["se"][3]]



def regrip(fr, grip):
    """`fr` with its mark (the picture's anchor) moved to `grip`, the picture where it was."""
    dx, dy = fr["r"][0] - grip[0], fr["r"][1] - grip[1]
    out = dict(fr)
    out["r"] = [grip[0], grip[1]]
    out["draw"] = {(x + dx, y + dy): c for (x, y), c in fr["draw"].items()}
    return out


# From the front the bow is held across the body: its mark is above the neck, where PlayerArt.pose
# moves nothing, so that in the stocky build (its halves a pixel out each way) the bow stays in the
# middle and does not go a pixel left with the left half.
S_MARK = (6, 10)
AIM["s"] = [regrip(fr, S_MARK) for fr in AIM["s"]]

# The bow's own dark letters: its edge (K) and the edge of the arrow's head (x).
DARK = "Kx"
WOOD = "Ppg"
NEAR = ((1, 0), (-1, 0), (0, 1), (0, -1))


def peeled(d, fr, q=os.environ.get("QUICK", "../q")):
    """`fr` without the bow's dark pixels that lie next to an empty pixel of the frame as it is
    drawn: there the figure's outline goes, and the two made a line two pixels thick."""
    body, thing, fists = work_proto.parts(q, d, fr, letters=True)
    front = fr.get("f", True)
    gx, gy = work_proto.ORIGIN[0] + fr["r"][0], work_proto.ORIGIN[1] + fr["r"][1]
    # What the frame's edge cuts off (Figure keeps a thing a pixel inside the frame) is not drawn.
    draw = {(x, y): c for (x, y), c in fr["draw"].items() if 1 <= gx + x <= 30 and 1 <= gy + y <= 30}
    while True:
        solid = set(body) | set(fists) | {(gx + x, gy + y) for x, y in draw}
        gone = []
        for (x, y), c in draw.items():
            at = (gx + x, gy + y)
            hidden = at in fists or (not front and at in body)
            if c not in DARK or hidden or all((at[0] + dx, at[1] + dy) in solid for dx, dy in NEAR):
                continue
            # A dark pixel over the body that parts the body from the bow's wood stays.
            if at in body and any(draw.get((x + dx, y + dy), "K") in WOOD for dx, dy in NEAR):
                continue
            gone.append((x, y))
        if not gone:
            break
        for p in gone:
            del draw[p]
    out = dict(fr)
    out["draw"] = draw
    return out


RAW = AIM
AIM = {d: [peeled(d, fr) for fr in frs] for d, frs in RAW.items()}
