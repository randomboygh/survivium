"""Slash draft 13: every direction in the logic of the 9th GIF's front (slash_l): 1 the sword up at
the shoulders, 2 raised higher, 3 the swing (crouched) with its trail along the whole arc to the
blade about 30 degrees down, 4 the same without the trail. Turned (se) as the front; from the side
(e) up behind the head, then forward and down in front with a crescent of a trail; from behind (ne,
n) the front mirrored, the blade in front of the body, but for its tip past the left side."""
import copy
import slash_k, slash_l
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
SLASH = copy.deepcopy(slash_l.SLASH)
FRONT = slash_l.STRIKE["smear"]


def moved(t, dx, dy, mirror=False, keep=30):
    rows = [r[::-1] if mirror else r for r in t["rows"]]
    rows = [("." * dx + r)[:32] if dx >= 0 else (r[-dx:] + "." * -dx) for r in rows]
    rows = rows[:keep - t["at"][1] - dy + 1]
    return {"at": [0, t["at"][1] + dy], "rows": rows}


def held(fr):
    """Frame 4: frame 3 without its trail."""
    f = copy.deepcopy(fr)
    f.pop("smear", None)
    return f


# Turned: the front's frames on the turned body, a row lower.
SE1 = F(1, 12, [0, 12], 0, True, [
    "44...VkkVc....",
    ".455ccCCC.....",
    ".....cCCC88...",
    ".....UUuUU...."] + SE_LEGS)
SE1["ccw"] = True
SE3 = F(2, 13, [6, 14], LOW, True, [
    ".....VkkVc....",
    "....c45CC88...",
    ".....UUuUU...."] + SE_LEGS)
SE3["of"] = False
SE3["smear"] = moved(FRONT, 1, 1)
SLASH["se"] = [SE1, copy.deepcopy(slash_k.SE[0]), SE3, held(SE3)]
# From the side: up behind the head at the shoulders, higher, then forward and down.
E1 = F(1, 12, [0, 12], 0, True, [
    "444455CVk.....",
    ".....cCCc.....",
    ".....UUUu....."] + E_LEGS)
E1["ccw"] = True
E3 = F(2, 13, [10, 13], LOW, True, [
    "......CV445...",
    ".....UUUu....."] + E_LEGS)
E3["smear"] = {"at": [0, 12], "rows": [r.ljust(32, ".") for r in [
    "...................--",
    ".....................--",
    ".......................-+",
    "........................++",
    ".........................++",
    "..........................++",
    "..........................+o",
    "...........................oo",
    "...........................oo",
    "...........................oo",
    "...........................oo",
    "...........................oo",
    "...........................oo",
    "..........................ooo",
    "..........................oo",
    ".........................ooo",
    "........................ooo",
    "......................oooo"]]}
SLASH["e"] = [E1, copy.deepcopy(slash_k.E[0]), E3, held(E3)]
# From behind: the front mirrored.
NE1 = F(1, 12, [13, 12], 0, True, [
    ".....VVVC...44",
    "....ccccCCC554",
    "...88VcccC....",
    ".....uuuuu...."] + NE_LEGS)
NE3 = F(2, 13, [8, 14], LOW_LEFT, False, [
    ".....VVVC.....",
    "...88Vcc544...",
    ".....uuuuu...."] + NE_LEGS)
NE3["smear"] = moved(FRONT, 0, 1, True)
SLASH["ne"] = [NE1, copy.deepcopy(slash_k.NE[0]), NE3, held(NE3)]
N1 = F(1, 12, [13, 12], 0, True, [
    "...CCVVVVCC.44",
    "...CCccccCC554",
    "..78CccccC....",
    "..78uuuuuu...."] + N_LEGS)
N3 = F(2, 13, [7, 14], LOW_LEFT, False, [
    "...CCVVVVCC...",
    "..78Ccc544c...",
    "..78uuuuuu...."] + N_LEGS)
N3["smear"] = moved(FRONT, 0, 1, True)
SLASH["n"] = [N1, copy.deepcopy(slash_k.N[0]), N3, held(N3)]
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
