"""Eat draft 1, the front view. The food is the hand's thing as carried: its icon cut down
to 5 pixels, its middle at the hand's mark `r`, the hand's digits drawn over it, so the
hand is drawn beside the food, not across it. 1 the food lifted to the belly, the elbow
by the side (the arm a row shorter); 2 raised to the chin, the hand by it at the chest's
height, the elbow under it; 3 the bite; 4 lowered as on 1, chewing with the eyes shut.
EAT: the bite is a nod (the head a row down onto the food, which stays where it was: the
chest's row folds away, the legs never move). EAT_B: no nod, the food raised a row higher
on 2 and 3, the elbow at the shoulder's height."""


def F(bob, top, r, f, rows, **kw):
    d = {"bob": bob, "top": top, "r": r, "a": -1, "f": f, "rows": rows}
    d.update(kw)
    return d


S_LEGS = ["....TT..TT....", "....tt..TT....", "....BB..BB...."]
S_NECK = "....cVkkVc...."
S_HIPS = "....UUuuUU87.."
S_LOW = F(0, 11, [6, 13], True, [
    S_NECK,
    "...ccCCCCcc...",
    "..45cCCCCc87..",
    S_HIPS] + S_LEGS)
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
            "..55cCCCCcc...",
            S_HIPS,
            "....TT..TT87.."] + S_LEGS[1:], eyes="shut"),
        dict(S_LOW, eyes="shut"),
    ],
}
S_UP = F(0, 11, [7, 11], True, [
    "...44VkkVc....",
    "..55cCCCCcc...",
    "....cCCCCc87..",
    S_HIPS] + S_LEGS)
EAT_B = {
    "s": [S_LOW, S_UP, dict(S_UP, eyes="shut"), dict(S_LOW, eyes="shut")],
}
for data in (EAT, EAT_B):
    for d, frs in data.items():
        for i, f in enumerate(frs):
            assert f["top"] + len(f["rows"]) == 18, (d, i)
            assert all(len(r) == 14 for r in f["rows"]), (d, i)
