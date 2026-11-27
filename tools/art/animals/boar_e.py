"""The boar, fifth drawing: the idle animation of the north, west and east at size B, as the south's
(boar_d): 1 standing; 2 the body a pixel lower (onto the legs) with the ears pricked up (from the side,
the tail's tip lifted); 3 still low, the ears as they stand; 4 up again, the ears drooping (from the
side, the tail's tip down; from behind the tail swings as the reference's does). The east is the
west mirrored, as in the reference.
"""
from boar_c import STAND, flip
from proto import mirror, paint
from boar_d import IDLE as IDLE_S
from boar_d import PAL, REF  # noqa: F401

W0 = STAND["w"][0]

# The north without its tail (boar_b's half, mirrored); the tail is painted per frame, as the
# reference swings it: curled to the right (1, 3), its loop swung to the middle (2), hanging straight
# down (4).
N_BASE = mirror([
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
])
TAIL_CURLED = ["8,8:M", "7,9:M.D", "7,10:DLD", "6,11:DDD"]
TAIL_SWUNG = ["8,8:M", "7,9:M.D", "6,10:DLD", "7,11:D"]
TAIL_DOWN = ["8,8:M", "7,9:MLD", "7,10:DLD", "6,11:DLD"]
N0 = paint(N_BASE, TAIL_CURLED)


def put(rows, y, x, letters):
    r = rows[y]
    rows[y] = r[:x] + letters + r[x + len(letters):]


def n_sunk(rows):
    """The body a row lower: the legs' tops under the body's lowest row left out."""
    return rows[:13] + rows[14:]


def w_sunk(rows):
    """The body a row lower: one of the legs' two rows left out."""
    return rows[:13] + rows[14:]


def n_up():
    rows = paint(N_BASE, TAIL_SWUNG)
    rows[1] = "..O....K....O.."
    rows[2] = ".OHO..KNK..OHO."
    rows[3] = ".OMlOONnNOOlMO."
    rows[4] = ".OMMLlNNNlLMMO."
    return n_sunk(rows)


def n_droop():
    rows = paint(N_BASE, TAIL_DOWN)
    rows[2] = "......KNK......"
    rows[3] = "..OOOONnNOOOO.."
    rows[4] = ".OMHLlNNNlLHMO."
    rows[5] = "OMDMMLqNqLMMDMO"
    rows[6] = ".ODMLHHqHHLMDO."
    return rows


def w_up():
    rows = list(W0)
    put(rows, 0, 7, "O")
    put(rows, 1, 6, "OlO")
    put(rows, 2, 5, "..OLO")
    # The tail's tip lifted.
    put(rows, 8, 21, ".h")
    put(rows, 9, 21, "O.")
    return w_sunk(rows)


def w_droop():
    rows = list(W0)
    put(rows, 1, 6, "...")
    put(rows, 2, 5, ".OOOO")
    put(rows, 3, 5, "OLLHH")
    put(rows, 4, 6, "l")
    put(rows, 5, 6, "l")
    # The tail's tip down.
    put(rows, 9, 21, "h.")
    put(rows, 10, 22, "h")
    return rows


WEST = [W0, w_up(), w_sunk(list(W0)), w_droop()]
IDLE = dict(IDLE_S, n=[N0, n_up(), n_sunk(list(N0)), n_droop()], w=WEST, e=[flip(f) for f in WEST])
