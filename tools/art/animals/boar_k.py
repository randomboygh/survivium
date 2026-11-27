"""The boar, eleventh drawing: the run (gallop) of the west and east at size B, the reference's
frames 1-4 (the user's pick, 2026-11-21 «А»). From the side the reference gallops: 0 gathered, the
ear pricked up, the back a column fuller, no tail (as in every run frame), the front legs under the
chest bent back, the hind ones slanting forward; 1 reaching, the body a pixel up on legs a row
longer, the ear laid back, the back flatter and a column longer, the front legs reaching forward off
the ground, the hind ones thrown back; 2 stretched, the ear laid flat (the head's top a row lower),
the mane flat, the body a column longer, the front legs reaching forward, the hind ones back to the
ground; 3 the back arched, the mane up in spikes, the ear pricked forward, the front legs under the
chin, the hind ones lifted. The reduction is the stand's (boar_c): the reference's columns 10, 14,
16 and 18 and the rows under the ear and the eye left out, the face as the stand's; every frame 24
wide so the head keeps its place; the east is the west mirrored.
"""
from boar_c import flip
from boar_e import W0
from boar_f import PAL as PAL_F
from boar_f import REF  # noqa: F401

# The reference's grey of the hooves' soles seen from below (the arched frame's front legs): no
# letter of the stand's is near it ('t', the tusks' tan, is far too light).
PAL = dict(PAL_F, G="#8a8b87")


def pad(rows, w=24):
    return [r.ljust(w, ".") for r in rows]


def face(rows, at):
    """The stand's face (columns 0-9 of its rows 6-11: the eye to the jaw) put at row `at`."""
    rows = list(rows)
    for i in range(6):
        rows[at + i] = W0[6 + i][:10] + rows[at + i][10:]
    return rows


# 0: gathered; the idle's pricked ear on the standing body, the back a column fuller, no tail.
RW0 = pad([
    ".......O.K.............",
    "......OlOKNNKKK........",
    ".......OLONNKNnK.K.....",
    "......OMDLMDMLMMqNnK...",
    ".....OHMDMMDLLLLMMqK...",
    "....OHLDMDMLLLLLLMMqK..",
    "..OOHLDEMMLLLLLLLMMNK..",
    "..OlLMpWMMLHHLHLLLMqK..",
    "g.ODMMMMMMLLLMLHHLMDO..",
    ".gDDMuMMDMLLMMMLLLMDO..",
    ".gTuuuDDDMMMMMMLLMMDO..",
    "..ggggOOODMMMDDMMMDO...",
    ".........OMDDOODDDO....",
    "..........ODO..ODO.....",
    "..........ODO.ODO......",
    "...........hh.hh.......",
])

# 1: reaching; a pixel up, the ear laid back, the back flatter and longer; the front legs forward off
# the ground, the hind ones back.
RW1 = face(pad([
    "..........K.............",
    "......OOOKNK.K..........",
    ".....OHHHONNKhK.........",
    "......OMDLDDMMNnK.......",
    ".....OHMDMMDDMMNNK......",
    "....OHLDMDMMDLLMMqKK....",
    "..OOHLDEMMMMLLLMMMNnK...",
    "..OlLMhWMMMLHLLLLMMNK...",
    "g.ODMMMMMMLLLLLHHLLMO...",
    ".gDDguMMDMLLLMMLHLLMO...",
    ".gWuuuDDDMLLLMMLLLLMO...",
    "..ggggOOOMMMMDDMMLMMO...",
    ".........OMDOOOODMMDO...",
    "........ODOOO...hDDO....",
    "........ODhOO....hDO....",
    "........OO.hO.....ODO...",
    "...................OO...",
]), 6)

# 2: stretched; the head's top a row lower with the ear flat, the mane flat, the body a column
# longer; the front legs reaching forward, the hind ones back.
RW2 = face(pad([
    "..........KKK...........",
    "......OOOOKnNK..........",
    ".....OlLHHDMMMKKK.......",
    ".....OlMDMMDDMLMqNKK....",
    "....OHHDMDMDDLLLMMNnK...",
    "..OOHLDEMMMMDLLLLMMqnK..",
    "..OMLMpWMMMMLLLLLLMMNK..",
    "g.ODMMMMMMLLHLLLHLLMMO..",
    ".ggDMuMDDMLLLLLLHHLLMO..",
    ".gTuuuDDDMLLLMMLLHLLMO..",
    "..ggggOOOMMLMMMMLLLMMO..",
    ".......OODDDOOOMMMMMDO..",
    "......pDDOOOh..OODDDDOp.",
    ".......OOOh......OOODDpp",
    "........OO..........hOOp",
]), 5)

# 3: the back arched with the mane up in three spikes (kept a row taller than the cut would leave
# them, or they read as a flat band), the ear pricked forward; the front legs under the chin with
# the hooves' light soles, the hind ones lifted.
RW3 = face(pad([
    ".........K...K..........",
    ".........KN..KN..K......",
    ".....OO..KnK.KnK.KN.....",
    ".....hHOOOqqONhNNKK.....",
    "......ODMLMDLLLLMMqnK...",
    ".....OlMDMLDDLLLLMMNK...",
    "....OHLDMMLMDLLLLLMNK...",
    "..OOlLDEMMMMMLLHLLLMO...",
    "..OMLMqWMMMMMLLHHLLMO...",
    "g.ODMMMMMMMLHLMLLLMMO...",
    ".ggDMuMMDMMLLMMMLMMMO...",
    ".gTuuuDDDMMMLMDMMMMO....",
    "..ggggOOOMMMMMODMMDO....",
    "......OpOODDOh.hODDDO...",
    ".....qpOGODO.....hOO....",
    "......hGODO.............",
    ".......OO...............",
]), 7)

RUN4 = {"w": [RW0, RW1, RW2, RW3]}
RUN4["e"] = [flip(f) for f in RUN4["w"]]
