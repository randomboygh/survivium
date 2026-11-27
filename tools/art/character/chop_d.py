"""Chop after the user's edits of 2026-11-19 22:32: the crouch on frame 3, upright on 4; east
hand closer to the ear; the torso moves in frames 1 and 2 (turned toward the raised arm,
then stretched up a row)."""
import copy
from chop_c import CHOP as C0, E
CHOP = copy.deepcopy(C0)
SIDE = {"s": -1, "se": -1, "e": -1, "ne": 1, "n": 1}


def waist(fr):
    for i, r in enumerate(fr["rows"]):
        if "U" in r or "u" in r:
            return i


def neck(fr):
    for i, r in enumerate(fr["rows"]):
        if any(c not in ".456789" for c in r):
            return i


def shift_row(r, dx):
    return (r[-dx:] + r[:-dx]) if dx > 0 else (r[-dx:] + "." * -dx)


def turn(fr, dx):
    """The torso (neck to waist) a pixel toward the raised arm."""
    n, h = neck(fr), waist(fr)
    for i in range(n, h + 1):
        fr["rows"][i] = shift_row(fr["rows"][i], dx)


def stretch(fr):
    """The body a row taller over the waist: the head, the arm and the hand up a row."""
    h = waist(fr)
    rows = fr["rows"]
    # The row copied is the one over the other hand (or over the waist), so the hand stays whole.
    k = next((i for i, r in enumerate(rows) if any(c in "789" for c in r)), h - 1)
    chest = "".join("." if c in "789" else c for c in rows[k])
    fr["rows"] = rows[1:k] + [chest] + rows[k:] if rows[0] == E else rows[:k] + [chest] + rows[k:]
    if rows[0] != E:
        fr["top"] -= 1
    fr["bob"] -= 1
    fr["r"] = [fr["r"][0], fr["r"][1] - 1]


# East: the hand nearer the ear in the wind-up, at the wind-up's old place at the top.
CHOP["e"][0] = {"bob": 1, "top": 11, "r": [4, 11], "a": 7, "f": True, "rows": [
    "...44.........",
    "...455CVk.....",
    ".....c5Cc.....",
    ".....UUUu.....",
    ".....ttt......", "......tTt.....", "......BBb....."]}
CHOP["e"][1] = {"bob": 1, "top": 12, "r": [4, 12], "a": 0, "f": True, "rows": [
    "....44CVk.....",
    ".....c55c.....",
    ".....UUUu.....",
    ".....ttt......", "......tTt.....", "......BBb....."]}
for d in CHOP:
    f = CHOP[d]
    turn(f[0], SIDE[d])
    stretch(f[1])
    f[2], f[3] = f[3], f[2]
# The top from the side: the axe up behind the head, its edge back.
CHOP["e"][1]["f"] = True
CHOP["e"][1]["ccw"] = True
