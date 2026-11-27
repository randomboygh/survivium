"""Slash draft 14 (user 2026-11-20 11:45 MSK on the 9th GIF: straighten up in the last frame):
as slash_m, but frame 4 stands again; the hand stays on its pixel (the crouch only folded the
chest's row away), so the sword does not move."""
import copy
import slash_j, slash_m
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT
SLASH = copy.deepcopy(slash_m.SLASH)
# The front: the 8th GIF's stop, standing, the hand where the strike left it.
SLASH["s"][3] = copy.deepcopy(slash_j.STOP)
SE4 = F(1, 12, [6, 14], LOW, True, [
    ".....VkkVc....",
    "....ccCCC88...",
    "....c45CC88...",
    ".....UUuUU...."] + SE_LEGS)
SE4["of"] = False
SLASH["se"][3] = SE4
SLASH["e"][3] = F(1, 12, [10, 13], LOW, True, [
    "......CVk.....",
    ".....cC445....",
    ".....UUUu....."] + E_LEGS)
NE4 = F(1, 12, [8, 14], LOW_LEFT, False, [
    ".....VVVC.....",
    "....ccccCCC...",
    "...88Vcc544...",
    ".....uuuuu...."] + NE_LEGS)
SLASH["ne"][3] = NE4
N4 = F(1, 12, [7, 14], LOW_LEFT, False, [
    "...CCVVVVCC...",
    "..78CccccCC...",
    "..78Ccc544c...",
    "....uuuuuu...."] + N_LEGS)
SLASH["n"][3] = N4
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
