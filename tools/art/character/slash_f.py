"""Slash draft 6, the front only (user 2026-11-20 03:46 MSK, the pink arc on the 4th GIF):
the sword from behind the head along an arc down the right side (the picture's left) and
in front of the body to the other side, fast at first, slowing to the end (the tip at
the user's points 1-4): raised behind the head, pointing at the viewer by the chin, swept
low across the front (the strike, crouched), held out across the chest at the other side."""
import copy
import slash_e
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
E = slash_e.SLASH
# Two ways to raise it behind the head: A the blade up beside the head, B the hand behind
# the head, the blade out past its top left.
RAISE_A = F(-1, 7, [0, 7], 0, False, [
    "44............",
    "45............",
    ".45...........",
    "..45cVkkVc....",
    "...ccCCCCcc...",
    "....cCCCCc....",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
RAISE_B = F(-1, 7, [3, 4], 7, False, [
    "44............",
    "45............",
    ".45...........",
    "..45cVkkVc....",
    "...ccCCCCcc...",
    "....cCCCCc....",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
DOWN = F(0, 9, [0, 9], TOWARD, True, [
    "45............",
    ".45...........",
    "..45cVkkVc....",
    "...ccCCCCcc...",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
STRIKE = F(1, 12, [1, 13], LOW, True, [
    "....cVkkVc....",
    ".45ccCCCCcc...",
    "....UUuuUU87..",
    "....TT..TT87..",
    "....tt..TT....",
    "....BB..BB...."])
THROUGH = F(0, 11, [6, 13], 2, True, [
    "....cVkkVc....",
    "...ccCCCCcc...",
    "...c445CCc87..",
    "....UUuuUU87.."] + S_LEGS)
THROUGH["of"] = False
SLASH = {d: [copy.deepcopy(f) for f in E[d]] for d in E}
SLASH["s"] = [RAISE_B, DOWN, STRIKE, THROUGH]
SLASH_A = copy.deepcopy(SLASH)
SLASH_A["s"] = [RAISE_A, DOWN, STRIKE, THROUGH]
for data in (SLASH, SLASH_A):
    for d, frs in data.items():
        for i, f in enumerate(frs):
            assert f["top"] + len(f["rows"]) == 18, (d, i)
            assert all(len(r) == 14 for r in f["rows"]), (d, i)
