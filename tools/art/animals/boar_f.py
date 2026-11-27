"""The boar, sixth drawing: the walk at size B, from the reference's six walk frames. The reference
walks in two mirrored halves: 0 a front leg lifted toward the viewer (lit), the other leg reaching to
the ground, the body a pixel higher and the ears flapping out low; 1 both feet down, the same leg
still lit, the body as it stands; 2 the body a pixel lower, the ears pricked up, the other leg lit
and stepping out; 3, 4, 5 the same with the legs swapped (the reference's frame mirrored). At size B
the ears' four rows of frame 0 become three (top, tip, bottom), as the droop's did.

The user's rule allows four frames: WALK_A keeps 0, 2, 3, 5 (the stride and the dip: the legs, the
bob and the ears all move), WALK_B keeps 0, 1, 3, 4 (the stride and the passing: a pixel of bob, the
ears only flap out).
"""
from boar_c import flip
from boar_d import PAL, REF, S0, IDLE as IDLE_S  # noqa: F401

EARS_UP = IDLE_S["s"][1]

# 0: up a pixel (the right leg reaches the ground, a row longer), the left leg lifted and lit, both
# legs a column to the left (the body sways); the ears out low.
W0 = S0[:3] + [
    ".....ONNNO.....",
    "....OMqNqMO....",
    "..OODDlqlDDOO..",
    "OLHLDMLHLMDLHLO",
    ".OOpMMLLLMMpOO.",
] + S0[8:12] + [
    ".OLDOOODOOpDDO.",
    ".OHLDOOOOOODO..",
    ".OHHO....ODDO..",
    ".OHO.....ODO...",
    "..h......ODO...",
    ".........hh....",
]

# 1: as it stands, the left leg still lit and out a column.
W1 = S0[:12] + [
    ".OMDOOODOOODDO.",
    ".OLMDOOOOODDO..",
    "..OLDO...ODMO..",
    "..OLO.....ODO..",
    "..hh......hh...",
]

# 2: a pixel lower, the ears up, the right leg lit and stepping out a column, the left one back (dark).
W2 = EARS_UP[:12] + [
    "..ODOOODOppDMO.",
    "..OpOOOOOOOMMO.",
    "..hOO......OMO.",
    "...hh......hh..",
]

WALK6 = {"s": [W0, W1, W2, flip(W0), flip(W1), flip(W2)]}
WALK_A = {"s": [WALK6["s"][i] for i in (0, 2, 3, 5)]}
WALK_B = {"s": [WALK6["s"][i] for i in (0, 1, 3, 4)]}
