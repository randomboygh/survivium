"""Slash draft 8, the front only (user 2026-11-20 03:57 MSK: find references and adapt):
after Puny Characters (Shade, CC0, opengameart.org/content/puny-characters), whose sword is
raised upright beside the head, swept in an arc (a white smear) down that side and low in
front, and stopped at the other side pointing down; along the user's pink arc, fast at
first and slowing to the end: 1 raised beside the head, 2 swept down that side (the
smear from 1), 3 the strike across the front, crouched (the smear from 2), 4 stopped at
the other side, the blade down about 30 degrees."""
import copy
import slash_f
from slash_a import F, S_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
# 1: raised upright beside the head (Puny's first frame), the tip over the head's corner.
RAISE = F(-1, 7, [0, 7], 0, True, [
    "44............",
    "45............",
    ".45...........",
    "..45cVkkVc....",
    "...ccCCCCcc...",
    "....cCCCCc....",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
RAISE["ccw"] = True
# 2: swept down that side: the hand by the chin, the blade still up and out.
SWING = F(0, 9, [1, 10], 7, True, [
    "4.............",
    "45............",
    ".45.cVkkVc....",
    "...ccCCCCcc...",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
SWING_B = F(0, 11, [3, 12], 7, True, [
    "....cVkkVc....",
    "..c45CCCCcc...",
    "...ccCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
# 3: the strike across the front, crouched (the chest's row folded).
STRIKE = F(1, 12, [8, 13], LOW, True, [
    "....cVkkVc....",
    "...c44445cc...",
    "....UUuuUU87..",
    "....TT..TT87..",
    "....tt..TT....",
    "....BB..BB...."])
STRIKE["of"] = False
# 4: stopped at the other side, the blade down about 30 degrees.
STOP = F(0, 11, [9, 13], LOW, True, [
    "....cVkkVc....",
    "...ccCCCCcc...",
    "...c444445c...",
    "....UUuuUU87.."] + S_LEGS)
STOP["of"] = False
SLASH = copy.deepcopy(slash_f.SLASH)
SLASH["s"] = [RAISE, SWING, STRIKE, STOP]
TRY = {"s": [RAISE, SWING, SWING_B, STRIKE, STOP]}
for data in (SLASH, TRY):
    for d, frs in data.items():
        for i, f in enumerate(frs):
            assert f["top"] + len(f["rows"]) == 18, (d, i)
            assert all(len(r) == 14 for r in f["rows"]), (d, i)

# The variant after the user's arc literally: 2 the blade pointing at the viewer by the chin
# (the smear from 1 down that side), 3 the strike (the smear on along the waist).
def _sm(y0, rows):
    return {"at": [0, y0], "rows": rows}
DOWN = copy.deepcopy(slash_f.DOWN)
DOWN["smear"] = _sm(11, [
    "..........-.....................",
    ".........--.....................",
    "........+-......................",
    ".......++.......................",
    ".......o+.......................",
    "......oo+.......................",
    "......oo+.......................",
    "......ooo.......................",
    "......ooo.......................",
    ".......oo.......................",
    ".......oo.......................",
    "........o.......................",
    "........o......................."])
STRIKE_S = copy.deepcopy(STRIKE)
STRIKE_S["smear"] = _sm(23, [
    ".........-......................",
    ".........-......................",
    ".........+-.....................",
    "..........++....................",
    "...........+oo..................",
    "............oooo................",
    "..............ooooo............."])
SMEARED = copy.deepcopy(SLASH)
SMEARED["s"] = [RAISE, DOWN, STRIKE_S, STOP]
