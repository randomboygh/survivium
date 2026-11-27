"""The bow, from the front, three variants for review (frames 56 and 57: halfway and down; the
animation plays 56, 57, 57, 57, 56 and stands): A the head alone goes a pixel and two down; B the
chest folds too (its second row gone, the shoulders a row lower) on the way down; C as B with the
eyes shut down."""
from gestures_wide import seg, frame


def s(over, bob, **k):
    f = frame("s", over, bob=bob)
    f.update(k)
    return f


FOLD = {11: None, 12: seg((4, "cVkkVc"))}
A = {"s": [s({}, 1, body=0), s({}, 2, body=0)]}
B = {"s": [s({}, 1, body=0), s(FOLD, 2, body=0)]}
C = {"s": [s({}, 1, body=0), s(FOLD, 2, body=0, eyes="shut")]}


# The user's pick (2026-11-20 22:27 MSK): C in every direction: the head a pixel and two below the
# stand's, on the way down the chest's second row folds away (the first row a row lower, the
# hands' pixels kept where they are), the eyes shut down there.
import gestures_wide as gw

DROP = {"s": 0, "se": 1, "e": 1, "ne": 1, "n": 1}


def fold(d):
    st = gw.stand(d)
    top = min(y for y in st if st[y].strip(".") and y > 10)
    low = list(st[top + 1])
    for x, c in enumerate(st[top]):
        if c != "." and not low[x].isdigit():
            low[x] = c
    return {top: None, top + 1: "".join(low)}


def bow(d):
    return [dict(frame(d, {}, bob=DROP[d] + 1), body=0),
            dict(frame(d, fold(d), bob=DROP[d] + 2), body=0, eyes="shut")]


ALL = {d: bow(d) for d in DROP}
ALL["s"] = C["s"]  # as the user saw it from the front


# The user's edit (2026-11-20 22:29 MSK): in every view but the front the head turns a little
# forward about the neck: turned and from the side it goes a pixel the way the body faces as it
# goes down (a pixel at the bottom of the bow, none halfway).
def forward(d, i):
    f = dict(ALL[d][i])
    if d in ("se", "e", "ne") and i == 1:
        f["head_shift"] = (1, 0)
    return f


ALL_B = {d: [forward(d, i) for i in range(2)] for d in DROP}
ALL_B1 = {d: [dict(f, head_shift=(1, 0)) if d in ("se", "e", "ne") else f for f in ALL[d]] for d in DROP}


# The user's edit (2026-11-20 22:41 MSK): not a move but a turn about the neck: the head's rows
# go forward the more the higher they are (`tilt`: {head row: pixels}), turned and from the side.
HALF1, DEEP1 = {1: 1, 2: 1}, {r: 1 for r in range(1, 6)}
HALF2, DEEP2 = {r: 1 for r in range(1, 5)}, {1: 2, 2: 2, 3: 2, 4: 1, 5: 1, 6: 1}


def tilted(half, deep):
    out = {}
    for d in DROP:
        fs = [dict(f) for f in ALL[d]]
        if d in ("se", "e", "ne"):
            fs[0]["tilt"], fs[1]["tilt"] = half, deep
        out[d] = fs
    return out


TILT1 = tilted(HALF1, DEEP1)
TILT2 = tilted(HALF2, DEEP2)


# The user's edit (2026-11-20 22:44 MSK): the head is a circle with its hair, eyes, ears: turn it
# whole about the neck, its shape kept, 15-30 degrees (`rot`), turned and from the side.
def rotated(half, deep):
    out = {}
    for d in DROP:
        fs = [dict(f) for f in ALL[d]]
        if d in ("se", "e", "ne"):
            fs[0]["rot"], fs[1]["rot"] = half, deep
        out[d] = fs
    return out


ROT_15_30 = rotated(15, 30)
ROT_10_20 = rotated(10, 20)
