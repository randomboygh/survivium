"""Slash draft 15 (user 2026-11-20 12:17 MSK on the 11th GIF): from the side the trail is the
front's crescent at the side (beside the back of the head, down and under to the blade in
front), not over the head; the arm with the sword held in nearer, the sword's tip in the
trail's start; from behind the trail passes behind the body (work_proto draws a trail behind
the figure where the thing is behind it)."""
import copy
import os
import slash_n
from slash_a import F, E_LEGS
from work_proto import LOW
from slash_m import moved
SLASH = copy.deepcopy(slash_n.SLASH)
FRONT = slash_n.SLASH["s"][2]["smear"]
DX = int(os.environ.get("ODX", 1))
GX = int(os.environ.get("OGX", 8))
# From the side, as the front: 1 up beside the back of the head at the shoulders, the hand
# by the chin and the arm bent; 2 higher (as before); 3 crouched, swept down behind and
# under to the blade low in front, the front's crescent behind it; 4 standing again.
E1 = F(1, 11, [0, 11], 0, True, [
    "44............",
    ".45555CVk.....",
    ".....cCCc.....",
    ".....UUUu....."] + E_LEGS)
E1["ccw"] = True
E3 = F(2, 13, [GX, 13], LOW, True, [
    "......CV......"[:GX - 1] + "45" + "......CV......"[GX + 1:],
    ".....UUUu....."] + E_LEGS)
E3["smear"] = moved(FRONT, DX, 1)
E4 = F(1, 12, [GX, 13], LOW, True, [
    "......CVk.....",
    ".....cCCc....."[:GX - 1] + "45" + ".....cCCc....."[GX + 1:],
    ".....UUUu....."] + E_LEGS)
SLASH["e"] = [E1, copy.deepcopy(slash_n.SLASH["e"][1]), E3, E4]
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
