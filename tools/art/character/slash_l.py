"""Slash draft 12, the front (user 2026-11-20 11:41 MSK on the 8th GIF): 1 the sword up at the
shoulders; 2 raised higher (the 8th GIF's first frame); 3 the swing with its trail along the
whole arc, to halfway between the 7th and 8th GIFs' third frames (the blade down to the right
about 30 degrees, crouched); 4 the sword where it was, the trail gone."""
import copy
import slash_j, slash_k
from slash_a import F, S_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
# 1: the sword upright at the shoulders, the arm bent up beside them.
SHOULDER = F(0, 11, [0, 11], 0, True, [
    "44..cVkkVc....",
    ".455cCCCCcc...",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
SHOULDER["ccw"] = True
RAISE = copy.deepcopy(slash_j.RAISE)
# 3: the strike, crouched: the hand left of the belly's middle, the blade down to the right.
STRIKE = F(1, 12, [6, 13], LOW, True, [
    "....cVkkVc....",
    "...c445CCc87..",
    "....UUuuUU87..",
    "....TT..TT....",
    "....tt..TT....",
    "....BB..BB...."])
STRIKE["of"] = False
STRIKE["smear"] = {"at": [0, 11], "rows": [r.ljust(32, ".") for r in [
    "..........-",
    ".........--",
    "........--",
    ".......-+",
    ".......++",
    "......++",
    "......++",
    "......+o",
    "......oo",
    "......oo",
    "......oo",
    ".......oo",
    ".......oo",
    "........oo",
    "........ooo",
    ".........ooo",
    "..........ooo",
    "...........oooo",
    "............ooooo",
    "..............ooooo"]]}
STOP = copy.deepcopy(STRIKE)
STOP.pop("smear")
SLASH = copy.deepcopy(slash_k.SLASH)
SLASH["s"] = [SHOULDER, RAISE, STRIKE, STOP]
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
