"""The shake «нет», first variants from the front (2026-11-20): the body stands and the head
turns to one side and the other: the turned head of the south-east and of the south-west
on the front's body (A), the head a pixel to one side and the other, not turned (B), turned
and a pixel that way (C). The shake plays its two columns (player.yaml `shake`: 51, 52)."""
from gestures_wide import frame


def shake(d, **k):
    drop = 0 if d == "s" else 1
    f = frame(d, {}, bob=drop)
    f.update(k)
    return f


A = {"s": [shake("s", head="se"), shake("s", head="sw")]}
B = {"s": [shake("s", head_shift=(1, 0)), shake("s", head_shift=(-1, 0))]}
C = {"s": [shake("s", head="se", head_shift=(1, 0)), shake("s", head="sw", head_shift=(-1, 0))]}

# Every direction drawn as A: the head turned a way to each side of the body's.
TURNS = {"s": ["se", "sw"], "se": ["s", "e"], "e": ["se", "ne"], "ne": ["e", "n"], "n": ["ne", "nw"]}
ALL_A = {d: [shake(d, head=h) for h in TURNS[d]] for d in TURNS}

# Every direction drawn as C, picked by the user (2026-11-20 19:37 MSK): turned and a pixel
# towards the side the face turns to; from the side it turns towards the viewer and away,
# so it is not moved (ALL_C_SIDE tries the side moved too).
SHIFTS = {"s": [1, -1], "se": [-1, 1], "e": [0, 0], "ne": [1, -1], "n": [1, -1]}
ALL_C = {d: [shake(d, head=h, head_shift=(x, 0)) for h, x in zip(TURNS[d], SHIFTS[d])] for d in TURNS}
ALL_C_SIDE = dict(ALL_C, e=[shake("e", head="se", head_shift=(-1, 0)), shake("e", head="ne", head_shift=(1, 0))])
# The user's edit (2026-11-20): the head goes only a pixel between the two frames: aside the way
# the face turns in the first, in its place in the second.
SHIFTS_D = {"s": [1, 0], "se": [0, 1], "e": [0, 0], "ne": [1, 0], "n": [1, 0]}
ALL_D = {d: [shake(d, head=h, head_shift=(x, 0)) for h, x in zip(TURNS[d], SHIFTS_D[d])] for d in TURNS}
