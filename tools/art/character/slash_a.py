"""Slash draft 1: a sideways sweep with a one-handed blade. Frame 1 the arm out to the
working side (the blade pointing out, the torso turned toward it), 2 drawn back and up
(the body a row taller), 3 the strike toward the work (crouched: the chest's row folds
away, the legs never move), 4 upright, the blade swept through to the other side."""
T = "sword"
def F(bob, top, r, a, f, rows):
    return {"bob": bob, "top": top, "r": r, "a": a, "f": f, "tool": T, "rows": rows}
S_LEGS = ["....TT..TT....", "....tt..TT....", "....BB..BB...."]
SE_LEGS = [".....TT.Tt....", ".....KB.KB...."]
E_LEGS = [".....ttt......", "......tTt.....", "......BBb....."]
NE_LEGS = [".....mm.tt....", ".....bb.BB...."]
N_LEGS = ["....mm..mm....", "....bb..bb...."]
SLASH = {
    "s": [
        F(0, 11, [1, 12], 6, True, [
            "...cVkkVc.....",
            "44ccCCCCcc....",
            "55.cCCCCc87...",
            "...UUuuUU87..."] + S_LEGS),
        F(-1, 9, [0, 9], 7, False, [
            "44............",
            "45..cVkkVc....",
            ".45ccCCCCcc...",
            "....cCCCCc....",
            "....cCCCCc87..",
            "....UUuuUU87.."] + S_LEGS),
        F(1, 12, [5, 13], 8, True, [
            "....cVkkVc....",
            "...c445CCcc...",
            "....UUuuUU87.."] + ["....TT..TT87..", "....tt..TT....", "....BB..BB...."]),
        F(0, 11, [8, 13], 2, True, [
            "....cVkkVc....",
            "...ccCCCCcc...",
            "...c44445c87..",
            "....UUuuUU87.."] + S_LEGS),
    ],
    "se": [
        F(1, 12, [1, 13], 6, True, [
            "....VkkVc.....",
            "444ccCCC......",
            "55..cCCC88....",
            "....UUuUU....."] + SE_LEGS),
        F(0, 10, [0, 10], 7, False, [
            "44............",
            ".45..VkkVc....",
            "..45ccCCC.....",
            ".....cCCC.....",
            ".....cCCC88...",
            ".....UUuUU...."] + SE_LEGS),
        F(2, 13, [6, 13], 8, True, [
            "....c445Vc....",
            "....ccCCC.....",
            ".....UUuUU88.."] + SE_LEGS),
        F(1, 12, [8, 13], 2, True, [
            ".....VkkVc....",
            "....c4444.....",
            ".....cCCC88...",
            ".....UUuUU...."] + SE_LEGS),
    ],
    "e": [
        F(1, 12, [2, 13], 6, True, [
            ".....CVk......",
            "..4444Cc......",
            "..55UUUu......"] + E_LEGS),
        F(0, 11, [2, 11], 7, True, [
            "..44..CVk.....",
            "...45cCCc.....",
            ".....cCCc.....",
            ".....UUUu....."] + E_LEGS),
        F(2, 13, [10, 14], 2, True, [
            "......CVk.....",
            ".....UU4444..."] + E_LEGS),
        F(1, 12, [9, 12], 1, False, [
            "......CVk4....",
            ".....cC44.....",
            ".....UUUu....."] + E_LEGS),
    ],
    "ne": [
        F(1, 12, [12, 13], 2, True, [
            "......VVVC....",
            "....88cccCCC44",
            "....88VcccC.55",
            "......uuuuu..."] + NE_LEGS),
        F(0, 10, [12, 10], 1, True, [
            "............44",
            ".....VVVC...45",
            "....ccccCCC45.",
            "...88cccCCC...",
            "...88VcccC....",
            ".....uuuuu...."] + NE_LEGS),
        F(2, 13, [10, 13], 1, False, [
            ".....VVVC.....",
            "...88cccCC4...",
            "...88uuuuu...."] + NE_LEGS),
        F(1, 12, [5, 13], 6, False, [
            ".....VVVC.....",
            "...88cccCCC...",
            "...88VcccC....",
            ".....uuuuu...."] + NE_LEGS),
    ],
    "n": [
        F(1, 12, [12, 13], 2, True, [
            "....CCVVVVCC..",
            "...77CccccCC44",
            "...88CccccC.55",
            ".....uuuuuu..."] + N_LEGS),
        F(0, 10, [12, 10], 1, True, [
            "............44",
            "...CCVVVVCC.45",
            "...CCccccCC45.",
            "..77ccccCC....",
            "..88CccccC....",
            "....uuuuuu...."] + N_LEGS),
        F(2, 13, [9, 13], 1, False, [
            "...CCVVVVCC...",
            "..77ccccCC4...",
            "..88uuuuuu...."] + N_LEGS),
        F(1, 12, [4, 13], 6, False, [
            "...CCVVVVCC...",
            "..77ccccCC....",
            "..88CccccC....",
            "....uuuuuu...."] + N_LEGS),
    ],
}
for d, frs in SLASH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i, f["top"], len(f["rows"]))
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
