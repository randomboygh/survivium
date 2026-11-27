"""The boar, fourth drawing: the idle (standing) animation at size B, direction by direction, from the
reference's four idle frames. The reference breathes and moves its ears: 1 as it stands (STAND); 2 the
body a pixel lower (the chest's lower row sinks onto the legs' tops) with the ears pricked up; 3 still
low, the ears out to the sides again; 4 up again, the ears a row lower (drooping).
"""
from boar_c import PAL, REF, STAND  # noqa: F401

S0 = STAND["s"][0]
# The chest's lower row on the legs' tops, for the frames where the body is a pixel lower.
S_SUNK = "..OMDOOOOODMO.."


def sunk(rows):
    """The body a row lower: the chest's lower row merged into the legs' tops."""
    return rows[:13] + [S_SUNK] + rows[15:]


IDLE = {"s": [
    S0,
    sunk([
        ".......K.......",
        "......KnK......",
        "..O..KNnNK..O..",
        ".OHO.ONNNO.OHO.",
        ".OMlOMqNqMOlMO.",
        ".OMMLDlqlDLMMO.",
    ] + S0[6:]),
    sunk(S0),
    [
        ".......K.......",
        "......KnK......",
        ".....KNnNK.....",
        ".....ONNNO.....",
        "..OOOMqNqMOOO..",
        ".OMHLDlqlDLHMO.",
        "OMDMMLHqHLMMDMO",
        ".OODMMLLLMMDOO.",
    ] + S0[8:],
]}
