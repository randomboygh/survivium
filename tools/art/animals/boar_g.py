"""The boar, seventh drawing: the walk of the north at size B, from the reference's six frames, as the
south's (boar_f) but as the reference draws the back: 0 the left leg lifted toward us (lit), the right
one reaching the ground a row longer, the body a pixel up, the ears out low (a row under the droop);
1 both feet down, the left leg back (dark), the right one lit; 2 the right leg lit, stepping out a
column, the ears pricked up at the height the standing ears' tips have (the body NOT lower, unlike
the south); 3, 4, 5 the same with the legs swapped. The tail wags on its own: hanging (0, 5), curled
as standing (1, 3), swung to the middle (2), hanging a column to the right (4).
"""
from boar_c import flip
from boar_e import N_BASE, TAIL_CURLED, TAIL_DOWN, TAIL_SWUNG
from boar_f import PAL, REF  # noqa: F401
from proto import paint

TAIL_RIGHT = ["8,8:M", "8,9:MLD", "8,10:DLD", "7,11:DLD"]

# 0: up a pixel; the ears out low over the rump's top row.
N_W0 = N_BASE[:2] + [
    "......KNK......",
    "....OONnNOO....",
    "..OOLlNNNlLOO..",
    ".OMMMLqNqLMMMO.",
    "ODOMLHHqHHLMODO",
    ".ODLLHHqHHLLDO.",
] + N_BASE[8:11] + [
    ".OLMMMMMMMMMDO.",
    ".OHLDDOODDDDO..",
    ".OHLOO..OpDDO..",
    ".OHO.....OpO...",
    "..h......OpO...",
    ".........hh....",
]

# 1: as it stands; the left leg back and dark, the right one lit.
N_W1 = N_BASE[:12] + [
    ".ODDDDOOODDMO..",
    "..OpDO...OMMO..",
    "..OpO.....OgO..",
    "..hh......hh...",
]

# 2: the ears pricked up, their tips where the standing ears' are; the right leg lit, out a column.
N_W2 = N_BASE[:2] + [
    "..O...KNK...O..",
    ".OHO.ONnNO.OHO.",
    ".OMlOlNNNlOlMO.",
    ".OMMLLqNqLLMMO.",
] + N_BASE[6:11] + [
    ".OpMMMMMMMMMMO.",
    "..ODDpOOODDMMO.",
    "..OpDO...OOMMO.",
    "..OpO......OMO.",
    "...hh......hh..",
]

WALK6 = {"n": [paint(N_W0, TAIL_DOWN), paint(N_W1, TAIL_CURLED), paint(N_W2, TAIL_SWUNG),
               paint(flip(N_W0), TAIL_CURLED), paint(flip(N_W1), TAIL_RIGHT), paint(flip(N_W2), TAIL_DOWN)]}
WALK_A = {"n": [WALK6["n"][i] for i in (0, 2, 3, 5)]}
WALK_B = {"n": [WALK6["n"][i] for i in (0, 1, 3, 4)]}
