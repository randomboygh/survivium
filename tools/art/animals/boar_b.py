"""The boar, second drawing: the size the user picked (B, about 0.8 of the reference, 2026-11-20)
and the back (north) standing, from the reference's idle frame 1 facing north.

The letters are boar_a's. The back view is a mirrored half with the tail, curled to one side, painted
over it (proto.paint).
"""
from boar_a import MID, PAL, REF  # noqa: F401
from proto import mirror, paint

# The reference's back, pixel for pixel (17 x 20), cleaned: the tail curls from the spine's end down
# to the right and back to the left.
FULL = {"n": [paint(mirror([
    "........K",
    "........K",
    "..OO...KN",
    ".OMHOOONn",
    "OMMMLMlNN",
    ".OOMMLLqN",
    "..OMLLHHq",
    "..OLLHHHq",
    ".OMLHHHHH",
    ".OMLHHHHL",
    ".OMLLHHHH",
    ".OMMLLHHH",
    ".OMMMLLLL",
    ".OMMMMMMM",
    ".ODMMMMMM",
    ".ODDDMMMM",
    "..ODDDOOO",
    "..ODDO...",
    "..ODO....",
    "...hh....",
]), ["9,10:M", "7,11:M..D", "8,12:MLD", "7,13:DLD", "6,14:DDD"])]}

# B: the accepted size. The south as accepted (boar_a.MID); the north: a column less each side, the
# row under the ears and three rows of the rump left out, the tail a row shorter.
STAND = {
    "s": MID["s"],
    "n": [paint(mirror([
        ".......K",
        ".......K",
        "..OO..KN",
        ".OMHOONn",
        "OMMMLlNN",
        ".OOMMLqN",
        "..OMLHHq",
        ".OMLHHHL",
        ".OMLLHHH",
        ".OMMLLHH",
        ".OMMMLLL",
        ".ODMMMMM",
        "..ODDDOO",
        "..ODDO..",
        "..ODO...",
        "...hh...",
    ]), ["8,8:M", "7,9:M.D", "7,10:DLD", "6,11:DDD"])],
}
