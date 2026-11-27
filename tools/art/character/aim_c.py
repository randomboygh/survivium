"""The bow's shot after the user's review of 2026-11-20 16:39 MSK (the order B they picked on the
card): turned away (ne) the bow is an arc past the head, where the face is, and the arrow a line
from the hand at the chin up and right through it, its head grey; from the front the arrow's head
is grey too, as from the side. The rest as aim_b (aim_a's frames)."""
from aim_a import *  # noqa: F401,F403
import aim_b

AIM = dict(aim_b.AIM)

# From the front: the arrow's head two rows of grey with a dark edge and tip over the bow's belly,
# as the side view's (the same in the nocked and the drawn frame: drawn, the shaft is longer).
S_HEAD = [
    "..KpPxAaxPpK..",
    "...KpxAaxpK...",
    "....KKxxKK....",
]
AIM["s"] = [
    F(0, 11, S_BODY, 12, [
        ".KssssnossssK.",
        ".KPK..no..KPK.",
        ".KpPKKnoKKPpK."] + S_HEAD, grip=(6, 15)),
    F(0, 11, S_BODY, 10, [
        "......ss......",
        "....ssnoss....",
        "..ss..no..ssK.",
        ".KPK..no..KPK.",
        ".KpPKKnoKKPpK."] + S_HEAD, grip=(6, 16)),
    aim_b.AIM["s"][2],
    aim_b.AIM["s"][3],
]


def grid(pixels):
    """{(x, y): letter} in box coordinates -> (rows, top) for F."""
    top = min(y for _, y in pixels)
    bottom = max(y for _, y in pixels)
    width = max(x for x, _ in pixels) + 1
    return ["".join(pixels.get((x, y), ".") for x in range(width)) for y in range(top, bottom + 1)], top


# Turned away (ne): the limb's arc past the head's right side, from the head's top to the hips (box
# row: the x of its light pixel, the shade right of it), the string where the head does not hide it.
NE_ARC = {3: 11, 4: 12, 5: 13, 6: 14, 7: 14, 8: 14, 9: 14, 10: 14, 11: 13, 12: 13, 13: 12, 14: 11}
NE_GRIP = (14, 8)


def ne_bow(string=(10, 11, 12, 13)):
    out = {}
    for y, x in NE_ARC.items():
        out[(x, y)] = "P"
        out[(x + 1, y)] = "p"
    for y in string:
        out[(11, y)] = "s"
    return out


def ne_arrow(nock, shaft, head):
    """An arrow up and right from `nock`, two pixels a row: `shaft` rows of shaft, `head` of its
    grey head, a dark tip."""
    out = {}
    x, y = nock
    for i in range(shaft + head):
        a, b = ("n", "o") if i < shaft else ("A", "a")
        out[(x + i, y - i)] = a
        out[(x + i + 1, y - i)] = b
    out[(x + shaft + head, y - shaft - head)] = "x"
    return out


def NE(top, body, pixels):
    rows, btop = grid(pixels)
    return F(1, top, body + NE_LEGS, btop, rows, a=1, f=False, grip=NE_GRIP)


def _with(bow, arrow):
    out = dict(bow)
    out.update(arrow)
    return out


AIM["ne"] = [
    # 1: the arrow on the string, the near hand holding its nock by the chin.
    NE(10, [
        "...........44.",
        "...........45.",
        ".....VVVC55...",
        "....ccccCC....",
        ".....VcccC....",
        ".....uuuuu...."], _with(ne_bow((12, 13)), ne_arrow((12, 10), 3, 2))),
    # 2: drawn: the hand back at the shoulder, the arrow's head at the bow.
    NE(12, [
        ".....VVVC55...",
        "....ccccCCC...",
        ".....VcccC....",
        ".....uuuuu...."], _with(ne_bow((13,)), ne_arrow((11, 11), 3, 2))),
    # 3: loosed: the string straight, the hand thrown back down.
    NE(12, [
        ".....VVVC.....",
        "....ccccCCC...",
        ".....Vccc45...",
        ".....uuuu44..."], ne_bow()),
    # 4: the bow still up, the hand back by the string.
    NE(12, [
        ".....VVVC.....",
        "....ccccCC45..",
        ".....VcccC44..",
        ".....uuuuu...."], ne_bow()),
]
