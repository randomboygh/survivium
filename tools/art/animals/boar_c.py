"""The boar, third drawing: the side (west, facing left) standing at the accepted size B, from the
reference's idle frame 1 facing west; the east is the west mirrored, as the reference has it (its east
row is its west row flipped, to within the JPEG's noise).

The letters are boar_a's, and g the grey-brown edge of the snout and jaw, u the tusk's middle.
"""
import boar_a
from boar_b import STAND as ACCEPTED
from boar_a import REF  # noqa: F401

PAL = dict(boar_a.PAL, g="#5c4238", u="#d6bb9c")


def flip(rows):
    return [r[::-1] for r in rows]


# The reference's west, pixel for pixel (27 x 20), cleaned.
FULL = {"w": [[
    ".........K.................",
    "..........KKK.K............",
    "......OOOKKNNKnK.K.........",
    ".....OLLHOONNKNNKnKK.K.....",
    "......ODLHLDMMMMKNNnKK.....",
    "......OMDLHMDMLLLMMqNnK....",
    ".....OHMDMLMDLLLLLLLMqK....",
    "....OHLDMDMMLLLLLLLLLMqK...",
    "..OOHLDEMMLLLLLLLLLLLMMK...",
    "..OlLMpWMMLLHHLLLHHLLLMO...",
    "..OMMMMMMMLHHLMLMLHHLLMDO..",
    "g.ODMMMMMMLLLLMMMLLHHLMDO..",
    ".gDDMuMMDMMLLMMMMMLLLLMDOhO",
    ".gTuuuDDDMMMMMDMDMMLLMMDO..",
    "..ggggOOODMMMMDDDDMMMMDO...",
    ".........ODMDDDDDDDMMDDO...",
    "..........ODDOOOOOOODDO....",
    "...........ODO......ODO....",
    "...........ODO......ODO....",
    "...........hh.......hh.....",
]]}

# B (23 x 16): the reference's columns 10, 14, 16, 18 and rows 1, 4, 10, 15 left out (a mane's spike
# row, a row of the back, of the cheek and of the belly), the belly's front edge drawn again.
WEST = [
    ".........K.............",
    "......OOOKNNKKK........",
    ".....OLLHONNKNnK.K.....",
    "......OMDLMDMLMqNnK....",
    ".....OHMDMMDLLLLMqK....",
    "....OHLDMDMLLLLLLMqK...",
    "..OOHLDEMMLLLLLLLMMK...",
    "..OlLMpWMMLHHLHLLLMO...",
    "g.ODMMMMMMLLLMLHHLMDO..",
    ".gDDMuMMDMLLMMMLLLMDOhO",
    ".gTuuuDDDMMMMMMLLMMDO..",
    "..ggggOOODMMMDDMMMDO...",
    ".........ODDOOOODDO....",
    "..........ODO...ODO....",
    "..........ODO...ODO....",
    "..........hh....hh.....",
]
STAND = dict(ACCEPTED, w=[WEST], e=[flip(WEST)])
