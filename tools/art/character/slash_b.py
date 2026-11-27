"""Slash draft 2: a sideways sweep with a one-handed blade, the same in every direction:
1 the arm out to the working side, the blade pointing out (the torso turned toward it);
2 drawn back and up (the body a row taller); 3 the strike: the blade swept across the
front toward the work (crouched: the chest's row folds away, the legs never move);
4 upright, the blade swept through and up on the other side. From behind the sweep is
mirrored and the blade passes behind the body."""
import copy
import slash_a
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
SLASH = copy.deepcopy(slash_a.SLASH)
SLASH["s"][2] = F(1, 12, [6, 13], 2, True, [
    "....cVkkVc....",
    "...c4445Ccc...",
    "....UUuuUU87.."] + ["....TT..TT87..", "....tt..TT....", "....BB..BB...."])
SLASH["s"][3] = F(0, 11, [8, 13], 1, True, [
    "....cVkkVc....",
    "...ccCCCCcc...",
    "...c44445c87..",
    "....UUuuUU87.."] + S_LEGS)
SLASH["se"][2] = F(2, 13, [7, 14], 2, True, [
    ".....VkkVc....",
    "....c4445C....",
    ".....UUuUU88.."] + SE_LEGS)
SLASH["se"][3] = F(1, 12, [9, 13], 1, True, [
    ".....VkkVc....",
    "....c44445....",
    ".....cCCC88...",
    ".....UUuUU...."] + SE_LEGS)
SLASH["ne"][2] = F(2, 13, [6, 14], 6, False, [
    ".....VVVC.....",
    "...88cccCCC...",
    "...88uuuuu...."] + NE_LEGS)
SLASH["ne"][3] = F(1, 12, [5, 13], 7, False, [
    ".....VVVC.....",
    "...88cccCCC...",
    "...88VcccC....",
    ".....uuuuu...."] + NE_LEGS)
SLASH["n"][1]["rows"][3] = "..77CccccCC..."
SLASH["n"][2] = F(2, 13, [5, 14], 6, False, [
    "...CCVVVVCC...",
    "..77CccccCC...",
    "..88uuuuuu...."] + N_LEGS)
SLASH["n"][3] = F(1, 12, [4, 13], 7, False, [
    "...CCVVVVCC...",
    "..77CccccCC...",
    "..88CccccC....",
    "....uuuuuu...."] + N_LEGS)
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
SLASH["s"][3]["f"] = False
SLASH["se"][3]["f"] = False
# The blade sweeps across in front of the other hand.
SLASH["s"][2]["of"] = False
SLASH["se"][2]["of"] = False
