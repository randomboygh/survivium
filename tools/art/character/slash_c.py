"""Slash draft 3 (user 2026-11-20 02:50 MSK): frame 2's arm a pixel shorter in every
direction; from the side frame 1 does not lean back (only the arm goes back); frame 4
the blade about 30 degrees down to the ground (work_proto.LOW, LOW_LEFT)."""
import copy
import slash_b
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT
SLASH = copy.deepcopy(slash_b.SLASH)
# Frame 2: the hand a pixel nearer the shoulder.
SLASH["s"][1] = F(-1, 10, [0, 10], 7, False, [
    "44..cVkkVc....",
    ".45ccCCCCcc...",
    "....cCCCCc....",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
SLASH["se"][1] = F(0, 11, [1, 11], 7, False, [
    ".44..VkkVc....",
    "..45ccCCC.....",
    ".....cCCC.....",
    ".....cCCC88...",
    ".....UUuUU...."] + SE_LEGS)
SLASH["e"][1] = F(0, 11, [3, 11], 7, True, [
    "...44.CVk.....",
    "....45CCc.....",
    ".....cCCc.....",
    ".....UUUu....."] + E_LEGS)
SLASH["ne"][1] = F(0, 11, [12, 11], 1, True, [
    ".....VVVC...44",
    "....ccccCCC45.",
    "...88cccCCC...",
    "...88VcccC....",
    ".....uuuuu...."] + NE_LEGS)
SLASH["n"][1] = F(0, 11, [12, 11], 1, True, [
    "...CCVVVVCC.44",
    "...CCccccCC45.",
    "..77CccccCC...",
    "..88CccccC....",
    "....uuuuuu...."] + N_LEGS)
# From the side, frame 1: the body upright as it stands, the arm back.
SLASH["e"][0] = F(1, 12, [3, 13], 6, True, [
    "......CVk.....",
    "...4444Cc.....",
    "...55UUUu....."] + E_LEGS)
# Frame 4: the blade swept through and down, about 30 degrees to the ground.
SLASH["s"][3] = F(0, 11, [7, 12], LOW, True, [
    "....cVkkVc....",
    "...c4445Ccc...",
    "....cCCCCc87..",
    "....UUuuUU87.."] + S_LEGS)
SLASH["s"][3]["of"] = False
SLASH["se"][3] = F(1, 12, [8, 13], LOW, True, [
    ".....VkkVc....",
    "....c4445.....",
    ".....cCCC88...",
    ".....UUuUU...."] + SE_LEGS)
SLASH["se"][3]["of"] = False
SLASH["e"][3] = F(1, 12, [10, 13], LOW, True, [
    "......CVk.....",
    ".....cC444....",
    ".....UUU55...."] + E_LEGS)
SLASH["ne"][3] = F(1, 12, [5, 12], LOW_LEFT, False, [
    ".....VVVC.....",
    "...88cccCCC...",
    "...88VcccC....",
    ".....uuuuu...."] + NE_LEGS)
SLASH["n"][3] = F(1, 12, [4, 12], LOW_LEFT, False, [
    "...CCVVVVCC...",
    "..77CccccCC...",
    "..88CccccC....",
    "....uuuuuu...."] + N_LEGS)
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
