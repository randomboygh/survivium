"""aim_a with the back-turned view (ne) as the reference draws it: the bow a stick by the body's
right side from the head's bottom to the hips, drawn its arrow's head by the head's right, apart."""
from aim_a import *  # noqa: F401,F403
import aim_a

AIM = dict(aim_a.AIM)
# The bow from behind: its far limb past the body's right side, the string's lower end (s) by it.
NE_STICK = [
    "..p",
    ".Pp",
    ".Pp",
    ".Pp",
    ".Pp",
    ".Pp",
    ".sp",
]
NE_HEAD = [
    "xxx",
    ".Ax",
    "..x",
]


def ne_bow(btop, head=None, hx=13):
    """The bow's rows from box row `btop` at x 11-13, with the arrow's head from box row `head`
    when given (x `hx` to `hx` + 2). Returns (rows, top)."""
    rows = {}
    for y, r in enumerate(NE_STICK):
        rows[btop + y] = "." * 11 + r
    if head is not None:
        for y, r in enumerate(NE_HEAD):
            rows[head + y] = "." * hx + r
    top = min(rows)
    return [rows.get(y, "") for y in range(top, max(rows) + 1)], top


def NE(bob, rows, btop, head=None, hx=13):
    bow, top = ne_bow(btop, head, hx)
    return F(bob, 12, rows, top, bow, a=1, f=False, grip=(12, btop + 3))


AIM["ne"] = [
    NE(1, [
        ".....VVVC.....",
        "....ccccCC44..",
        ".....VcccC....",
        ".....uuuuu...."] + NE_LEGS, 9, head=1, hx=14),
    NE(1, [
        ".....VVVC55...",
        "....ccccCCC...",
        ".....VcccC....",
        ".....uuuuu...."] + NE_LEGS, 8, head=2),
    NE(1, [
        ".....VVVC.....",
        "....ccccCCC...",
        ".....Vccc45...",
        ".....uuuu44..."] + NE_LEGS, 9),
    NE(1, [
        ".....VVVC.....",
        "....ccccCC45..",
        ".....VcccC44..",
        ".....uuuuu...."] + NE_LEGS, 9),
]
