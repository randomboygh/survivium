"""The nod «да», first variants from the front (2026-11-20): the body stands still and the
head goes a pixel down over the neck (A), with the eyes shut as in the blink (B) or the
lids lowered, only the eye's lower row showing (C). The nod plays the stand and this frame
(player.yaml `nod`: columns 0 and 50)."""
from gestures_wide import frame


def nod(d, **k):
    drop = 0 if d == "s" else 1
    f = frame(d, {}, bob=drop + 1)
    f["body"] = 0
    f.update(k)
    return f


A = {"s": [nod("s")]}
B = {"s": [nod("s", eyes="shut")]}
C = {"s": [nod("s", eyes="down")]}

# Every direction drawn (the west ones are the east ones mirrored), as C.
ALL_C = {d: [nod(d, eyes="down")] for d in ["s", "se", "e", "ne", "n"]}

# Every direction drawn as B, picked by the user (2026-11-20 19:08 MSK).
ALL_B = {d: [nod(d, eyes="shut")] for d in ["s", "se", "e", "ne", "n"]}
