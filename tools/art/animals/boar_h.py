"""The boar, eighth drawing: the walk of the west and east at size B, in the user's variant B (the
reference's frames 1, 2, 4, 5 of six), from the reference's west row; the east is its mirror, as the
reference's is. 0 a pixel up, the ear laid back along the head, the near hind leg forward and lit,
the tail's tip drooping; 1 as it stands, the front legs apart (the near one forward and lit, the far
one lifted), the hind legs apart; 3 a pixel up, the ear laid back, the front leg forward, the tail
hanging lower; 4 as it stands, the far front leg reaching forward (its hoof a row up), the near hind
leg lit. The reference's column 10 (left out at size B) runs through the front legs, so they are
placed by hand.
"""
from boar_c import flip
from boar_e import W0, put
from boar_f import PAL, REF  # noqa: F401

# The ear laid back: a pixel longer to the back, over the mane's front.
EAR_BACK = [
    "..........K............",
    "......OOOONNKKK........",
    ".....OLLHHONKNnK.K.....",
    "......ODDLHDMLMqNnK....",
]


def tail(rows, at):
    """The tail's tip (W0 holds it out level at x 21-22 of row 9) at the given pixels instead."""
    put(rows, 9, 21, "..")
    for x, y in at:
        put(rows, y, x, "h")
    return rows


# 0: up a pixel; the near hind leg forward (lit); the tail's tip drooping.
WW0 = tail(EAR_BACK + W0[4:12] + [
    ".........ODDpOODLMOO...",
    ".........ODDO..OMDO....",
    "..........ODO..OMOO....",
    "..........ODO..ODO.....",
    "..........hh...hh......",
], [(21, 9), (22, 10)])

# 1: as it stands; the near front leg forward and lit, the far one lifted; the hind legs apart.
WW1 = W0[:12] + [
    "........OHLOOOOODDO....",
    "........OLOpO.OpODO....",
    "........OMOO...OODh....",
    ".........h.......h.....",
]

# 3: up a pixel; the front leg forward; the tail hanging lower.
WW3 = tail(EAR_BACK + W0[4:12] + [
    ".........OMDOOOODDO....",
    ".........ODDO..OODO....",
    ".........ODDO..OODO....",
    ".........ODh....ODh....",
    ".........hh.....hh.....",
], [(21, 9), (21, 10), (22, 11)])

# 4: as it stands; the far front leg reaching forward, its hoof a row up; the near hind leg lit.
WW4 = W0[:12] + [
    "........OpDDpOOLMDO....",
    "......hDO.ODO..OMOO....",
    "......hh..ODO..ODO.....",
    "...........h....h......",
]

WALK_B = {"w": [WW0, WW1, WW3, WW4]}
WALK_B["e"] = [flip(f) for f in WALK_B["w"]]

# Variant A's other two frames (the reference's 3 and 6), for the side-by-side review the user asked
# for: a pixel low (the accepted idle's sunk frame with the ear pricked up), the legs apart.
W_UP = __import__("boar_e").w_up()


def legs_low(rows, legs, tail_at):
    """The ear-up frame (a pixel low) with its legs and tail replaced."""
    rows = list(rows[:12])
    put(rows, 8, 21, "..")
    put(rows, 9, 21, "..")
    for x, y, ch in tail_at:
        put(rows, y, x, ch)
    return rows + legs


# 2: the near front leg forward (lit), the far one back; the far hind leg forward; the tail's tip
# down from a higher root.
WW2 = legs_low(W_UP, [
    "........OMDOOOOODDO....",
    ".......ODO.ODh.OpODO...",
    ".......hh...h..h..h....",
], [(21, 8, "h"), (22, 9, "h")])

# 5: the legs the other way round, the near hind leg lit; the tail's tip raised (as the idle's).
WW5 = legs_low(W_UP, [
    ".......OOODDDOOMOOO....",
    "......ODO.ODO.OMOODO...",
    "......hh...h...h..h....",
], [(22, 8, "h"), (21, 9, "O")])

WALK_A = {"w": [WW0, WW2, WW3, WW5]}
WALK_A["e"] = [flip(f) for f in WALK_A["w"]]

# The user's own mix (2026-11-21, «кадры 1, 2, 4, 6»): B's first half (up, legs apart) and A's second
# half (up, a pixel low with the ear pricked).
WALK_C = {"w": [WW0, WW1, WW3, WW5]}
WALK_C["e"] = [flip(f) for f in WALK_C["w"]]

# The user's fix to B (2026-11-21, «в четвертом кадре переднюю лапу нарисуй как в четвертом кадре
# варианта А»): frame 4's far front leg planted forward and straight as in A's frame 4 (`WW5`), a row
# longer since the body stands a pixel higher, instead of lifted and bent.
WW4B = list(WW4)
put(WW4B, 12, 7, "O")
put(WW4B, 13, 6, "ODO")
put(WW4B, 14, 6, "ODO")
put(WW4B, 15, 6, "hh")

WALK_B2 = {"w": [WW0, WW1, WW3, WW4B]}
WALK_B2["e"] = [flip(f) for f in WALK_B2["w"]]
