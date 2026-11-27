"""Slash draft 4 (user 2026-11-20 03:07 MSK): the follow-through dropped, the first three
frames spread over four: out to the side, drawn back and up, the swing (the blade coming
down at the working side, about 30 degrees, the body upright), the strike (crouched)."""
import copy
import slash_c
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT
C = slash_c.SLASH
SWING = {
    "s": F(0, 11, [2, 13], LOW_LEFT, True, [
        "....cVkkVc....",
        "...ccCCCCcc...",
        "..45cCCCCc87..",
        "....UUuuUU87.."] + S_LEGS),
    "se": F(1, 12, [2, 13], LOW_LEFT, True, [
        ".....VkkVc....",
        "..44ccCCC.....",
        "..55.cCCC88...",
        ".....UUuUU...."] + SE_LEGS),
    "e": F(1, 12, [4, 13], LOW_LEFT, True, [
        "......CVk.....",
        "....44CCc.....",
        "....55UUu....."] + E_LEGS),
    "ne": F(1, 12, [11, 13], LOW, True, [
        ".....VVVC.....",
        "...88cccCCC44.",
        "...88VcccC.55.",
        ".....uuuuu...."] + NE_LEGS),
    "n": F(1, 12, [11, 13], LOW, True, [
        "...CCVVVVCC...",
        "..77CccccCC44.",
        "..88CccccC.55.",
        "....uuuuuu...."] + N_LEGS),
}
SLASH = {d: [copy.deepcopy(C[d][0]), copy.deepcopy(C[d][1]), SWING[d], copy.deepcopy(C[d][2])] for d in C}
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
