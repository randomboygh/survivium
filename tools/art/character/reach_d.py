"""Reach draft 3 (user 2026-11-20 17:55 MSK: «Тянем руку вместе с приседанием, присев руку
сокращаем»): the arm stretches down as the body crouches, and crouched it is short again.
1 the hand lifted to the waist, 2 the crouch (the chest's row folds away, the legs never
move) with the arm stretched down along the side, the hand a row over the ground, 3 still
crouched, the arm short again (the hand has what it took), 4 upright, the hand brought up to
the shoulder. The arm stays against the body in every frame (17:50 MSK)."""
def F(bob, top, r, f, rows, **kw):
    return dict({"bob": bob, "top": top, "r": r, "a": None, "f": f, "rows": rows}, **kw)
S_LEGS = ["....TT..TT....", "....tt..TT....", "....BB..BB...."]
REACH = {
    "s": [
        F(0, 10, [3, 13], True, [
            "..............",
            "....cVkkVc....",
            "..4ccCCCCcc...",
            "..45cCCCCc87..",
            "....UUuuUU87.."] + S_LEGS),
        F(1, 10, [3, 16], True, [
            "..............",
            "..............",
            "....cVkkVc....",
            "...ccCCCCcc...",
            "..45UUuuUU87..",
            "..45TT..TT87..",
            "..45tt..TT....",
            "....BB..BB...."]),
        F(1, 10, [3, 15], True, [
            "..............",
            "..............",
            "....cVkkVc....",
            "...ccCCCCcc...",
            "..45UUuuUU87..",
            "..45TT..TT87..",
            "....tt..TT....",
            "....BB..BB...."]),
        F(0, 10, [3, 12], True, [
            "..............",
            "..44cVkkVc....",
            "..45cCCCCcc...",
            "....cCCCCc87..",
            "....UUuuUU87.."] + S_LEGS),
    ],
}
# The other arm one row tall in the crouch, as the dig has it (to compare).
import copy
ALT = copy.deepcopy(REACH)
for i in (1, 2):
    ALT["s"][i]["rows"][5] = ALT["s"][i]["rows"][5].replace("87", "..")
