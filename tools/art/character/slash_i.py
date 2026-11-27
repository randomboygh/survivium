"""Slash draft 9, the front only (user 2026-11-20 04:22 MSK on the 6th GIF: follow the
reference's sword frame by frame, the last two frames looked as if the sword were in the
other hand): as Puny Characters has it, the hand holding the hilt stays left of the
middle of the belly in the strike and the stop, the arm short from its shoulder, and
the blade goes out to the right from there: across, then down about 30 degrees. The
other hand is raised a little at its side, clear of the blade."""
import copy
import slash_h
from slash_a import F, S_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
RAISE = copy.deepcopy(slash_h.RAISE)
DOWN = copy.deepcopy(slash_h.DOWN)
# 3: the strike, crouched: the hand left of the middle, the blade across to the right.
STRIKE = F(1, 12, [5, 13], 2, True, [
    "....cVkkVc....",
    "...c45CCCc87..",
    "....UUuuUU87..",
    "....TT..TT....",
    "....tt..TT....",
    "....BB..BB...."])
STRIKE["of"] = False
STRIKE["smear"] = {"at": [0, 23], "rows": [
    ".........-......................",
    ".........-......................",
    ".........+-.....................",
    ".........++.....................",
    "..........oo....................",
    "..........ooo...................",
    "...........oooooooooo...........",
    ".............ooooooo............"]}
# 4: stopped, the hand where it was, the blade down about 30 degrees.
STOP = F(0, 11, [5, 13], LOW, True, [
    "....cVkkVc....",
    "...ccCCCCc87..",
    "...c45CCCc87..",
    "....UUuuUU....."[:14]] + S_LEGS)
STOP["of"] = False
SLASH = copy.deepcopy(slash_h.SLASH)
SLASH["s"] = [RAISE, DOWN, STRIKE, STOP]
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
