"""Slash draft 16 (user 2026-11-20 13:13 MSK on the 12th GIF): from the side (east and west)
on frames 1 and 2 the arm with the sword pressed a pixel nearer the body (toward the head)."""
import copy
import slash_o
from slash_a import F, E_LEGS
SLASH = copy.deepcopy(slash_o.SLASH)
E1 = F(1, 11, [1, 11], 0, True, [
    ".44...........",
    "..4555CVk.....",
    ".....cCCc.....",
    ".....UUUu....."] + E_LEGS)
E1["ccw"] = True
E2 = F(0, 8, [1, 8], 0, True, [
    ".44...........",
    ".45...........",
    "..45..........",
    "...455CVk.....",
    ".....cCCc.....",
    ".....cCCc.....",
    ".....UUUu....."] + E_LEGS)
E2["ccw"] = True
SLASH["e"] = [E1, E2] + SLASH["e"][2:]
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
