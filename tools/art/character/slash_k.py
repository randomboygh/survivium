"""Slash draft 11: every direction in the logic of the front (slash_j, user's arc): 1 raised
beside the head on the hand's side, 2 swept down, 3 the strike crouched with the trail, 4 stopped
about 30 degrees down. From the side the arc is seen edge on: up behind the head, over in
front of the face, forward at the strike, down forward. From behind it is the front mirrored."""
import copy
import slash_j
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT, TOWARD
SLASH = copy.deepcopy(slash_j.SLASH)
E = [
    # 1: raised behind the head, the arm up from the shoulder, the blade upright.
    F(0, 8, [0, 8], 0, True, [
        "44............",
        "45............",
        ".45...........",
        "..4455CVk.....",
        ".....cCCc.....",
        ".....cCCc.....",
        ".....UUUu....."] + E_LEGS),
    # 2: over, in front of the face, the blade up forward.
    F(1, 10, [13, 10], 1, True, [
        "............44",
        "..........445.",
        "......CV445...",
        ".....cCCc.....",
        ".....UUUu....."] + E_LEGS),
    # 3: the strike, crouched, the blade straight forward.
    F(2, 13, [11, 13], 2, True, [
        "......CV4445..",
        ".....UUUu....."] + E_LEGS),
    # 4: stopped, the hand back by the belly, the blade down forward.
    F(1, 12, [9, 13], LOW, True, [
        "......CVk.....",
        ".....cCC45....",
        ".....UUUu....."] + E_LEGS),
]
E[2]["smear"] = {"at": [0, 12], "rows": [r.ljust(32, ".") for r in [
    "....................--",
    "......................--",
    "........................-+",
    ".........................++",
    "..........................++",
    "...........................++",
    "...........................+o",
    "............................oo",
    "............................oo",
    "............................oo",
    "............................oo",
    "............................oo",
    "...........................ooo",
    "..........................ooo",
    "........................oooo"]]}
SLASH["e"] = E

FRONT_TRAIL = slash_j.SLASH["s"][2]["smear"]
def moved(t, dx, dy, mirror=False, keep=None):
    """The front's trail moved (and mirrored about the frame's middle); rows below `keep` dropped."""
    rows = [r[::-1] if mirror else r for r in t["rows"]]
    rows = [("." * dx + r)[:32] if dx >= 0 else (r[-dx:] + "." * -dx) for r in rows]
    if keep is not None:
        rows = rows[:keep - t["at"][1] - dy + 1]
    return {"at": [0, t["at"][1] + dy], "rows": rows}
SE = [
    F(0, 8, [0, 8], 0, True, [
        "44............",
        "45............",
        ".45...........",
        "..45cVkkVc....",
        "....ccCCC.....",
        ".....cCCC.....",
        ".....cCCC88...",
        ".....UUuUU...."] + SE_LEGS),
    F(1, 10, [0, 10], LOW_LEFT, True, [
        "45............",
        ".45...........",
        "..45cVkkVc....",
        "....ccCCC.....",
        ".....cCCC88...",
        ".....UUuUU...."] + SE_LEGS),
    F(2, 13, [7, 14], TOWARD, True, [
        ".....VkkVc....",
        "....c445C88...",
        ".....UUuUU...."] + SE_LEGS),
    F(1, 12, [6, 13], LOW, True, [
        ".....VkkVc....",
        "....c45CC88...",
        ".....cCCC88...",
        ".....UUuUU...."] + SE_LEGS),
]
SE[0]["ccw"] = True
E[0]["ccw"] = True
SE[2]["of"] = False
SE[3]["of"] = False
SE[2]["smear"] = moved(FRONT_TRAIL, 1, 1, keep=30)
NE = [
    F(0, 8, [13, 8], 0, True, [
        "............44",
        "............54",
        "...........54.",
        ".....VVVCc54..",
        "....ccccCCC...",
        ".....VcccC....",
        "...88VcccC....",
        ".....uuuuu...."] + NE_LEGS),
    F(1, 10, [13, 10], LOW, True, [
        "............54",
        "...........54.",
        ".....VVVCc54..",
        "....ccccCCC...",
        "...88VcccC....",
        ".....uuuuu...."] + NE_LEGS),
    F(2, 13, [8, 14], TOWARD, False, [
        ".....VVVC.....",
        "...88Vcc544...",
        ".....uuuuu...."] + NE_LEGS),
    F(1, 12, [8, 13], LOW_LEFT, False, [
        ".....VVVC.....",
        "...88Vcc544...",
        ".....VcccC....",
        ".....uuuuu...."] + NE_LEGS),
]
NE[2]["smear"] = moved(FRONT_TRAIL, 0, 1, True, 28)
N = [
    F(0, 8, [13, 8], 0, True, [
        "............44",
        "............54",
        "...........54.",
        "...CCVVVVCC54.",
        "...CCccccCC...",
        "....CccccC....",
        "..78CccccC....",
        "..78uuuuuu...."] + N_LEGS),
    F(1, 10, [13, 10], LOW, True, [
        "............54",
        "...........54.",
        "...CCVVVVCC54.",
        "...CCccccCC...",
        "..78CccccC....",
        "..78uuuuuu...."] + N_LEGS),
    F(2, 13, [7, 14], TOWARD, False, [
        "...CCVVVVCC...",
        "..78Ccc544c...",
        "..78uuuuuu...."] + N_LEGS),
    F(1, 12, [7, 13], LOW_LEFT, False, [
        "...CCVVVVCC...",
        "..78Ccc544c...",
        "..78CccccC....",
        "....uuuuuu...."] + N_LEGS),
]
N[2]["smear"] = moved(FRONT_TRAIL, 0, 1, True, 28)
SLASH["se"], SLASH["ne"], SLASH["n"] = SE, NE, N
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
