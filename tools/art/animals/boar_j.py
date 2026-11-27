"""The boar, tenth drawing: the run (gallop) of the north at size B, the reference's frames 1-4 (the
user picked them for the south, 2026-11-21 «А»). From behind the reference gallops: 0 the ears
pricked up as the idle's raised ones but the body at the stand's height, the hind legs folded under
with the hooves' soles toward us; 1 the body a pixel up on legs a row longer, the ears flat out to
the sides, the mane bristling a row taller; 2 the body as standing, the ears laid back along the
head (only their points out at the sides), the mane two rows taller, the legs thrown back toward us
(lit) and splayed; 3 the body a pixel low, the head's top flat with the ears hanging out to the
sides, the left leg down, the right one lifted. The reduction is the stand's (boar_b): a column
less each side (the half's sixth, between the legs below the belly), the rows under the head and two
of the rump left out; the back is mirrored as the stand is, the legs are drawn as the reference
has them.
"""
from boar_e import IDLE as IDLE_N
from boar_e import N_BASE, TAIL_CURLED, TAIL_DOWN, TAIL_SWUNG
from boar_f import PAL, REF  # noqa: F401
from proto import paint

N_UP = IDLE_N["n"][1]


def body(tail):
    return paint(N_BASE, tail)


# 0: the idle's raised ears and head on the standing body, the hind legs folded.
RN0 = N_UP[:7] + body(TAIL_CURLED)[7:12] + [
    "..OODDOOODDpO..",
    "..hOOO...OppO..",
    "...hpO...OOh...",
    "....OO...Oh....",
]

# 1: a pixel up on longer legs; the ears flat out, the mane a row taller.
RN1 = [
    ".......K.......",
    ".......K.......",
    "......KnK......",
    "..OOO.KnK.OOO..",
    ".OLHLONNNOLHLO.",
    "OLMLMlNNNlMLMLO",
    ".ODDMLqNqLMDDO.",
] + body(TAIL_DOWN)[6:12] + [
    "..ODDDOOODDDO..",
    "..ODDO...ODDO..",
    "..OMO.....OMO..",
    "..OgO.....OgO..",
    "...OO.....OO...",
]

# 2: as standing; the head a narrow dome with the ears laid back to points, the mane two rows taller,
# the legs lit and splayed.
RN2 = [
    ".......K.......",
    ".......K.......",
    "......KnK......",
    "......KnK......",
    ".....ONNNO.....",
    "...OOLNNNLOO...",
    "..pDMlhNhlMDp..",
    ".OOMLHHNHHLMOO.",
    "OLOMLHHqHHLMOLO",
] + body(TAIL_CURLED)[7:12] + [
    "..OLMDOOODMlO..",
    "..OLOO...OOLO..",
    "..OlO.....OLO..",
    "...p.......h...",
]

# 3: a pixel low; the head's top flat, the ears hanging out to the sides; the left leg down, the
# right one lifted, both lit.
RN3 = [
    ".......K.......",
    ".......K.......",
    "......KnK......",
    "....OOKnKOO....",
    "..OODLNNNLDOO..",
    ".OMDMLhNhLMDMO.",
    "OMDMLHlqlHLMDMO",
] + body(TAIL_SWUNG)[7:11] + [
    ".ODLMMMDMMLHDO.",
    "..OlOOOOOOOHO..",
    "..OLO......O...",
    "...O...........",
]

RUN4 = {"n": [RN0, RN1, RN2, RN3]}
