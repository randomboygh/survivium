"""Slash draft 10, the front only (user 2026-11-20 04:27-04:28 MSK on the 7th GIF: the sword did
not move between frames 3 and 4, only the trail went; the trail shows on frame 3 only):
1 raised upright beside the head; 2 swept down that side, the blade out to the left (no
trail: the blade itself shows); 3 the strike, crouched, the blade at the bottom of the arc
in the middle, pointing at the viewer between the legs, the trail along the user's arc
behind it; 4 stopped, the blade down to the right about 30 degrees."""
import copy
import slash_i, slash_f
from slash_a import F, S_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
RAISE = copy.deepcopy(slash_i.RAISE)
# 2: the body of the frame pointing at the viewer by the chin (slash_f.DOWN), the blade out.
def _down(a):
    f = copy.deepcopy(slash_f.DOWN)
    f["a"] = a
    f.pop("smear", None)
    return f
DOWN_L, DOWN_UL, DOWN_LL, DOWN_DL = _down(6), _down(7), _down(LOW_LEFT), _down(5)
# 3: the strike, crouched: the hand in the middle, the blade at the viewer between the legs.
STRIKE = F(1, 12, [6, 13], TOWARD, True, [
    "....cVkkVc....",
    "...c445CCc87..",
    "....UUuuUU87..",
    "....TT..TT....",
    "....tt..TT....",
    "....BB..BB...."])
STRIKE["of"] = False
STRIKE["smear"] = {"at": [0, 11], "rows": [
    "..........-.....................",
    ".........--.....................",
    "........--......................",
    ".......-+.......................",
    ".......++.......................",
    "......++........................",
    "......++........................",
    "......+o........................",
    "......oo........................",
    "......oo........................",
    "......oo........................",
    ".......oo.......................",
    ".......oo.......................",
    "........oo......................",
    "........ooo.....................",
    ".........ooo....................",
    "..........oo....................",
    "...........oo...................",
    "............oo..................",
    ".............o.................."]}
# 4: stopped, the hand where it was, the blade down to the right about 30 degrees.
STOP = F(0, 11, [6, 13], LOW, True, [
    "....cVkkVc....",
    "...ccCCCCc87..",
    "...c445CCc87..",
    "....UUuuUU...."] + S_LEGS)
STOP["of"] = False
SLASH = copy.deepcopy(slash_i.SLASH)
SLASH["s"] = [RAISE, DOWN_LL, STRIKE, STOP]
TRY = {"s": [DOWN_L, DOWN_UL, DOWN_LL, DOWN_DL, STRIKE, STOP]}
for data in (SLASH, TRY):
    for d, frs in data.items():
        for i, f in enumerate(frs):
            assert f["top"] + len(f["rows"]) == 18, (d, i)
            assert all(len(r) == 14 for r in f["rows"]), (d, i)
