"""Slash draft 5 (user 2026-11-20 03:17 MSK): the sword goes along an arc from the upper
left corner to the lower right: out to the side, drawn back and up (the upper left), the
swing (the blade up and over to the right in front of the chest), the strike (crouched,
the blade down at the lower right about 30 degrees). From behind it is mirrored: the
blade passes in front of the body, hidden but for what shows past it."""
import copy
import slash_d
from slash_a import F, S_LEGS, SE_LEGS, E_LEGS, NE_LEGS, N_LEGS
from work_proto import LOW, LOW_LEFT
D = slash_d.SLASH
SWING = {
    "s": F(0, 11, [9, 12], 1, True, [
        "....cVkkVc....",
        "...c444445c...",
        "....cCCCCc87..",
        "....UUuuUU87.."] + S_LEGS),
    "se": F(1, 12, [9, 13], 1, True, [
        ".....VkkVc....",
        "....c44445....",
        ".....cCCC88...",
        ".....UUuUU...."] + SE_LEGS),
    "e": F(1, 12, [10, 13], 1, True, [
        "......CVk.....",
        ".....cC4445...",
        ".....UUUu....."] + E_LEGS),
    "ne": F(1, 12, [4, 12], 7, False, [
        ".....VVVC.....",
        "...88cccCCC...",
        "...88VcccC....",
        ".....uuuuu...."] + NE_LEGS),
    "n": F(1, 12, [3, 12], 7, False, [
        "...CCVVVVCC...",
        "..77CccccCC...",
        "..88CccccC....",
        "....uuuuuu...."] + N_LEGS),
}
STRIKE = {
    "s": F(1, 12, [9, 13], LOW, True, [
        "....cVkkVc....",
        "...c444445c...",
        "....UUuuUU87..",
        "....TT..TT87..",
        "....tt..TT....",
        "....BB..BB...."]),
    "se": F(2, 13, [10, 13], LOW, True, [
        ".....VkkVc45..",
        "....c4444C....",
        ".....UUuUU88.."] + SE_LEGS),
    "e": F(2, 13, [11, 13], LOW, True, [
        "......CV4445..",
        ".....UUUu....."] + E_LEGS),
    "ne": F(2, 13, [4, 13], LOW_LEFT, False, [
        ".....VVVC.....",
        "...88cccCCC...",
        "...88uuuuu...."] + NE_LEGS),
    "n": F(2, 13, [4, 13], LOW_LEFT, False, [
        "...CCVVVVCC...",
        "..77CccccCC...",
        "..88uuuuuu...."] + N_LEGS),
}
SLASH = {d: [copy.deepcopy(D[d][0]), copy.deepcopy(D[d][1]), SWING[d], STRIKE[d]] for d in D}
SLASH["s"][3]["of"] = False
SLASH["se"][3]["of"] = False
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
