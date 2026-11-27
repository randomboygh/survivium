"""The boar, first drawing: the front (south) standing, in three sizes, from the user's reference
(survivium-builds/animals/anim/boar/boar-reference.jpg, cut by ref_cut.py into ../boar/ref).

Letters: O the outline (dark red-brown), D M L H the fur from dark to light, l the warm light round
the tusks; K the mane's outline, N n its fill; P the brow, E W the eye (pale blue over white), p the
pupil; T t the tusk (light, shade); h the hoof. Front and back views are drawn as a left half to the
middle column and mirrored (proto.mirror).
"""
from proto import mirror

PAL = {
    "O": "#3b1e1f", "D": "#5f2e29", "M": "#7b4331", "L": "#8b5135", "H": "#9a5c3c",
    "l": "#86583f", "q": "#48303a", "K": "#1d2229", "N": "#2f3149", "n": "#3e425c",
    "P": "#80585a", "E": "#c8d8e0", "W": "#ece6e0", "p": "#4a2f2b", "T": "#e8d0b4",
    "t": "#bea78e", "h": "#3a2c30",
}

# The reference sheet: two bands of four rows (south, north, west, east); per state its band, first
# column and frames.
REF = {
    "dir": "../boar/ref",
    "dirs": ["s", "n", "w", "e"],
    "states": {"idle": (0, 0, 4), "walk": (0, 4, 6), "hurt": (0, 10, 4),
               "run": (1, 0, 5), "attack": (1, 5, 5), "death": (1, 10, 6)},
}

# A: the reference's size, pixel for pixel (17 x 21).
FULL = {"s": [mirror([
    "........K",
    "........K",
    ".......Kn",
    "......KNn",
    "..OO.OMNN",
    ".OMHOMDqN",
    "OMMMLDLlq",
    ".ODMMLLHq",
    "..OMDMLLH",
    ".OMDMMMLL",
    ".OMDMDMMM",
    ".OLDMEDMM",
    ".OMOMWpDM",
    ".OMOMMMDD",
    ".OMOTLDMM",
    ".ODOttDDM",
    ".ODDOOODD",
    "..ODDOOOO",
    "..OMDO...",
    "..OMO....",
    "...hh....",
])]}

# B: about 0.8 of it (15 x 17): the pupils a column nearer the middle, the mane's tip a row shorter,
# the row under the ears left out.
MID = {"s": [mirror([
    ".......K",
    "......Kn",
    ".....KNn",
    "..OO.ONN",
    ".OMHOMqN",
    "OMMMLDlq",
    ".ODMMLHq",
    ".OMDMMLL",
    ".OLDMEDM",
    ".OMOMWpM",
    ".OMOTLDM",
    ".ODOttDM",
    ".ODDOOOD",
    "..ODDOOO",
    "..OMDO..",
    "..OMO...",
    "...hh...",
])]}

# C: about 0.65 of it (13 x 14): the tusk at the face's edge, under the eye's outer side.
SMALL = {"s": [mirror([
    "......K",
    ".....Kn",
    ".OO.ONN",
    "OMHOMqN",
    "ODMLDlq",
    ".OMDMLL",
    ".OLDEDM",
    ".OMOWpM",
    ".OMTLDM",
    ".ODttDM",
    ".ODDOOD",
    "..ODOOO",
    "..OMO..",
    "...hh..",
])]}
