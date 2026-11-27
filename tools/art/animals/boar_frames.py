"""The boar's accepted frames, from the library modules: state -> direction -> frames, and the
column of each state's canvas where the standing body's left edge is."""
import os
import sys

SRC = os.environ.get("SRC", os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SRC)

from boar_e import IDLE  # noqa: E402
from boar_f import WALK_B as WALK_S  # noqa: E402
from boar_g import WALK_B as WALK_N  # noqa: E402
from boar_h import WALK_B2 as WALK_W  # noqa: E402
from boar_i import RUN_A as RUN_S  # noqa: E402
from boar_j import RUN4 as RUN_N  # noqa: E402
from boar_k import RUN4 as RUN_W, PAL as PAL_K  # noqa: E402
from boar_l import ATK  # noqa: E402
from boar_m import HURT  # noqa: E402
from boar_n import DEATH, PAL as PAL_N  # noqa: E402

PAL = dict(PAL_N, **PAL_K)
DIRS = ("s", "n", "w")
STATES = {
    "idle": {d: IDLE[d] for d in DIRS},
    "walk": {"s": WALK_S["s"], "n": WALK_N["n"], "w": WALK_W["w"]},
    "run": {"s": RUN_S["s"], "n": RUN_N["n"], "w": RUN_W["w"]},
    "attack": {d: ATK[d] for d in DIRS},
    "hurt": {d: HURT[d] for d in DIRS},
    "death": {d: DEATH[d] for d in DIRS},
}
# The stand's left edge in each state's canvas (0 when it is the stand's own width or padded on the right).
AT = {"attack": {"s": 4, "n": 4, "w": 3}, "death": {"s": 1}}
# A row of the sheet, in the game's order: the standing, the walk, the idle's other frames, the attack,
# the run, the hurt, the death.
ROW = [("idle", 0)] + [("walk", i) for i in range(4)] + [("idle", i) for i in (1, 2, 3)] + \
    [(s, i) for s in ("attack", "run", "hurt", "death") for i in range(4)]
CELL = (29, 18)
# The sheet's rows: the side (the west drawn, mirrored to face right), the front (south), the back (north).
VIEWS = ("w", "s", "n")


def sheet():
    """The sheet as the game takes it, drawn here from the library's letters (a check of the art module)."""
    from PIL import Image
    W, H = CELL
    im = Image.new("RGBA", (W * len(ROW), H * len(VIEWS)), (0, 0, 0, 0))
    for v, d in enumerate(VIEWS):
        x0 = (W - len(STATES["idle"][d][0][0])) // 2
        for c, (s, i) in enumerate(ROW):
            rows = STATES[s][d][i]
            left = x0 - AT.get(s, {}).get(d, 0)
            top = H - len(rows)
            for y, r in enumerate(rows):
                for x, ch in enumerate(r):
                    if ch != ".":
                        px = left + x
                        if d == "w":
                            px = W - 1 - px
                        assert 0 <= px < W and 0 <= top + y < H, (s, d, i)
                        h = PAL[ch].lstrip("#")
                        im.putpixel((c * W + px, v * H + top + y), tuple(int(h[k:k + 2], 16) for k in (0, 2, 4)) + (255,))
    return im
