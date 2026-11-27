"""Dig draft 4 (user 2026-11-20 01:52): the legs never move (a crouch folds the chest
row away), the blade beside the feet with the outline between, its tip at the feet's
level on frame 1 and deeper on 2 and 3."""
import copy
import dig_d
T = "shovel"
def F(bob, top, r, a, slide, f, rows):
    return {"bob": bob, "top": top, "r": r, "a": a, "slide": slide, "f": f, "tool": T, "rows": rows}
S_LEGS = ["....TT..TT....", "....tt..TT....", "....BB..BB...."]
SE_LEGS = [".....UUuUU....", ".....TT.Tt....", ".....KB.KB...."]
E_LEGS = [".....ttt......", "......tTt.....", "......BBb....."]
NE_LEGS = [".....uuuuu....", ".....mm.tt....", ".....bb.BB...."]
N_LEGS = ["....uuuuuu....", "....mm..mm....", "....bb..bb...."]
DIG = {
    "s": [
        F(0, 10, [0, 13], 8, 3, True, [
            "..............",
            "...ccVkkVc....",
            "..4cCCCCCcc...",
            "44.cCCCCc87...",
            "....UUuuUU87.."] + S_LEGS),
        F(0, 10, [0, 14], 8, 3, True, [
            "..............",
            "....cVkkVc....",
            "...ccCCCCcc...",
            "..4.cCCCCc87..",
            "44..UUuuUU87.."] + S_LEGS),
        F(1, 10, [0, 15], 8, 3, True, [
            "..............",
            "..............",
            "....cVkkVc....",
            "...ccCCCCcc...",
            "..4.UUuuUU87..",
            "44..TT..TT....",
            "....tt..TT....",
            "....BB..BB...."]),
        dig_d.DIG["s"][3],
    ],
    "se": [
        F(1, 12, [11, 13], 3, 6, True, [
            ".....VkkVc....",
            "....ccCCC444..",
            ".....cCCC88..."] + SE_LEGS),
        F(1, 12, [11, 14], 3, 6, True, [
            "......VkkVc...",
            ".....ccCCC....",
            ".....cCCC444.."] + SE_LEGS),
        F(2, 13, [11, 15], 3, 6, True, [
            ".....VkkVc....",
            "....ccCCC.....",
            ".....UUuUU444.",
            ".....TT.Tt....",
            ".....KB.KB...."]),
        dict(dig_d.DIG["se"][3], top=12),
    ],
    "e": [
        F(1, 12, [10, 13], 3, 6, False, [
            "......CVk.....",
            ".....cC4444...",
            ".....UUU......"] + E_LEGS),
        F(1, 12, [10, 14], 3, 6, False, [
            ".......CVk....",
            "......cC4.....",
            ".....UUU444..."] + E_LEGS),
        F(2, 13, [10, 15], 3, 6, False, [
            "......CVk.....",
            ".....UUU44....",
            ".....ttt.444..",
            "......tTt.....",
            "......BBb....."]),
        dig_d.DIG["e"][3],
    ],
    "ne": [
        F(1, 12, [11, 13], 3, 6, False, [
            ".....VVVC.....",
            "....ccccCC44..",
            ".....VcccC...."] + NE_LEGS),
        F(1, 12, [11, 14], 3, 6, False, [
            ".....VVVC.....",
            "....ccccCC....",
            ".....VcccC44.."] + NE_LEGS),
        F(2, 13, [11, 15], 3, 6, False, [
            ".....VVVC.....",
            "....ccccCC....",
            ".....uuuuu44..",
            ".....mm.tt....",
            ".....bb.BB...."]),
        dig_d.DIG["ne"][3],
    ],
    "n": [
        F(1, 12, [11, 13], 3, 6, False, [
            "...CCVVVVCC...",
            "...CCccccCC44.",
            "....CccccC...."] + N_LEGS),
        F(1, 12, [11, 14], 3, 6, False, [
            "...CCVVVVCC...",
            "...CCccccCC...",
            "....CccccC44.."] + N_LEGS),
        F(2, 13, [11, 15], 3, 6, False, [
            "...CCVVVVCC...",
            "...CCccccCC...",
            "....uuuuuu44..",
            "....mm..mm....",
            "....bb..bb...."]),
        dig_d.DIG["n"][3],
    ],
}
# Every frame's rows reach the feet's row 17.
for d, frs in DIG.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
