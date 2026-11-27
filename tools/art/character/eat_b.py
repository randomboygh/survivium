"""Eat draft 2: the nod (eat_a EAT, the user's pick 2026-11-20) in every drawn direction.
The left arm of the nod's frame hangs where it does standing (as the slash's crouch has
it). Turned, from the side and from behind the food is where the mouth is: before the
face's middle (se: between its west twin's place and its own, the icon is not mirrored), before the chin (e), behind the head (ne, n: `f` false, the body
hides it). A west direction is its east one mirrored, but the icon is not, so one of an
even width sits a pixel further out there: the hand reaches a pixel into the food from
the side (e), and turned (se) the other arm is behind the food (`of` false)."""
from eat_a import F, S_LEGS, S_NECK, S_HIPS, S_LOW

SE_LEGS = [".....TT.Tt....", ".....KB.KB...."]
E_LEGS = [".....ttt......", "......tTt.....", "......BBb....."]
NE_LEGS = [".....mm.tt....", ".....bb.BB...."]
N_LEGS = ["....mm..mm....", "....bb..bb...."]

SE_LOW = F(1, 12, [7, 14], True, [
    ".....VkkVc....",
    "....ccCCC88...",
    "...44cCCC88...",
    ".....UUuUU...."] + SE_LEGS, of=False)
E_LOW = F(1, 12, [10, 14], True, [
    "......CVk.....",
    ".....cCCc.....",
    ".....UU44....."] + E_LEGS)
NE_LOW = F(1, 12, [8, 13], False, [
    ".....VVVC.....",
    "....ccccCCC...",
    "...88VcccC44..",
    "...88uuuuu...."] + NE_LEGS)
N_LOW = F(1, 12, [7, 13], False, [
    "...CCVVVVCC...",
    "...CCccccCC...",
    "..77CccccC44..",
    "..88uuuuuu...."] + N_LEGS)
EAT = {
    "s": [
        S_LOW,
        F(0, 11, [7, 12], True, [
            S_NECK,
            "...44CCCCcc...",
            "..55cCCCCc87..",
            S_HIPS] + S_LEGS),
        F(1, 12, [7, 12], True, [
            "...44VkkVc....",
            "..55cCCCCc87..",
            S_HIPS] + S_LEGS, eyes="shut"),
        dict(S_LOW, eyes="shut"),
    ],
    "se": [
        SE_LOW,
        F(1, 12, [8, 13], True, [
            ".....VkkVc....",
            "....c44CC88...",
            "...55cCCC88...",
            ".....UUuUU...."] + SE_LEGS, of=False),
        F(2, 13, [8, 13], True, [
            ".....44kVc....",
            "...55cCCC88...",
            ".....UUuUU...."] + SE_LEGS, of=False, eyes="shut"),
        dict(SE_LOW, eyes="shut"),
    ],
    "e": [
        E_LOW,
        F(1, 12, [12, 13], True, [
            "......CVk444..",
            ".....cCC444...",
            ".....UU55....."] + E_LEGS),
        F(2, 12, [12, 13], True, [
            "...........4..",
            "......CV444...",
            ".....UU55....."] + E_LEGS, eyes="shut"),
        dict(E_LOW, eyes="shut"),
    ],
    "ne": [
        NE_LOW,
        F(1, 12, [11, 12], False, [
            ".....VVVC.....",
            "....ccccCC44..",
            "...88VcccC55..",
            "...88uuuuu...."] + NE_LEGS),
        F(2, 13, [11, 12], False, [
            ".....VVVCC44..",
            "...88VcccC55..",
            "...88uuuuu...."] + NE_LEGS, eyes="shut"),
        dict(NE_LOW, eyes="shut"),
    ],
    "n": [
        N_LOW,
        F(1, 12, [7, 12], False, [
            "...CCVVVVCC...",
            "...CCccccC44..",
            "..77CccccC....",
            "..88uuuuuu...."] + N_LEGS),
        F(2, 13, [7, 12], False, [
            "...CCVVVVC44..",
            "..77CccccC....",
            "..88uuuuuu...."] + N_LEGS, eyes="shut"),
        dict(N_LOW, eyes="shut"),
    ],
}
for d, frs in EAT.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i, [len(r) for r in f["rows"]])
