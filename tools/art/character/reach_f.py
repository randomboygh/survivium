"""Reach, every direction (the front accepted by the user 2026-11-20 17:59 MSK as drawn in
reach_d): 1 upright, the hand lifted to the waist; 2 the crouch (the chest's row folds away,
the legs never move) with the arm stretched down, the hand a row over the ground; 3 still
crouched, the arm short again (the hand has what it took), two rows over the ground;
4 upright, the hand brought up to the shoulder. The arm stays against the body in every
frame: no empty pixel between them (17:50 MSK). The views where the body stands a row lower
(se, e, ne, n) have the hands at the same heights over the ground as the front, so their arms
are a row shorter crouched: stretched the arm is two rows, short one (the other arm too)."""
import reach_d
def F(bob, top, r, f, rows, **kw):
    return dict({"bob": bob, "top": top, "r": r, "a": None, "f": f, "rows": rows}, **kw)
SE_LEGS = [".....TT.Tt....", ".....KB.KB...."]
E_LEGS = [".....ttt......", "......tTt.....", "......BBb....."]
NE_LEGS = [".....mm.tt....", ".....bb.BB...."]
N_LEGS = ["....mm..mm....", "....bb..bb...."]
REACH = {
    "s": reach_d.REACH["s"],
    # Turned, the right arm is the near one, on the picture's left; the far arm ends a row
    # higher, beside the shoulders' row.
    "se": [
        F(1, 12, [4, 14], True, [
            ".....VkkVc....",
            "....4cCCC88...",
            "...44cCCC88...",
            ".....UUuUU...."] + SE_LEGS),
        F(2, 13, [4, 16], True, [
            ".....VkkVc....",
            "....ccCCC88...",
            "...44UUuUU....",
            "...44TT.Tt....",
            ".....KB.KB...."]),
        F(2, 13, [4, 15], True, [
            ".....VkkVc....",
            "....ccCCC88...",
            "...44UUuUU....",
            ".....TT.Tt....",
            ".....KB.KB...."]),
        F(1, 12, [4, 13], True, [
            "...44VkkVc....",
            "...44cCCC88...",
            ".....cCCC88...",
            ".....UUuUU...."] + SE_LEGS),
    ],
    # From the side the arm goes down and forward in front of the body.
    "e": [
        F(1, 12, [8, 14], True, [
            "......CVk.....",
            ".....cC4c.....",
            ".....UUU44....",
            ] + E_LEGS),
        F(2, 13, [9, 16], True, [
            "......CVk.....",
            ".....UUU4.....",
            ".....ttt44....",
            "......tTt44...",
            "......BBb....."]),
        F(2, 13, [8, 15], True, [
            "......CVk.....",
            ".....UUU4.....",
            ".....ttt44....",
            "......tTt.....",
            "......BBb....."]),
        F(1, 12, [8, 13], True, [
            "......CVk.....",
            ".....cC444....",
            ".....UUU......",
            ] + E_LEGS),
    ],
    # From behind the right arm is on the picture's right, what it holds behind the body.
    "ne": [
        F(1, 12, [10, 14], False, [
            ".....VVVC.....",
            "....ccccCCC4..",
            "...88VcccC44..",
            "...88uuuuu...."] + NE_LEGS),
        F(2, 13, [10, 16], False, [
            ".....VVVC.....",
            "....ccccCCC...",
            "...88uuuuu44..",
            ".....mm.tt44..",
            ".....bb.BB...."]),
        F(2, 13, [10, 15], False, [
            ".....VVVC.....",
            "....ccccCCC...",
            "...88uuuuu44..",
            ".....mm.tt....",
            ".....bb.BB...."]),
        F(1, 12, [9, 13], False, [
            ".....VVVC44...",
            "....ccccC44...",
            "...88VcccC....",
            "...88uuuuu...."] + NE_LEGS),
    ],
    "n": [
        F(1, 12, [10, 14], False, [
            "...CCVVVVCC...",
            "...CCccccCC4..",
            "..77CccccC55..",
            "..88uuuuuu...."] + N_LEGS),
        F(2, 13, [10, 16], False, [
            "...CCVVVVCC...",
            "...CCccccCC...",
            "..88uuuuuu44..",
            "....mm..mm55..",
            "....bb..bb...."]),
        F(2, 13, [10, 15], False, [
            "...CCVVVVCC...",
            "...CCccccCC...",
            "..88uuuuuu55..",
            "....mm..mm....",
            "....bb..bb...."]),
        F(1, 12, [10, 13], False, [
            "...CCVVVVC44..",
            "...CCccccC55..",
            "..77CccccC....",
            "..88uuuuuu...."] + N_LEGS),
    ],
}
for d, frs in REACH.items():
    for i, f in enumerate(frs):
        assert f["top"] + len(f["rows"]) == 18, (d, i)
        assert all(len(r) == 14 for r in f["rows"]), (d, i)
