#!/usr/bin/env python3
"""Draws the animals' pictures: content/animals/<bundle>/sprites/creatures/<sprite>.png.

A sheet has a row a view (the side, the animal facing right; the front, coming at the
camera; the back, going away) and in each row the frames of creatures.yaml: the first
standing, then `walk` frames of its walk, swim or wing beat, then its idle frames (a tail
flicked, the head bent to the grass, a wing preened). The pictures are written as text a
character a pixel in this file and shaded and outlined by tools/creature_kit.py, so they
are easy to change here and remake:
    python3 tools/make_creatures.py [name ...]
"""
import os
import sys

from creature_kit import at_row, DARK, HIGH, LIGHT, MID, OUTLINE, View, compose, flat, flyer, poses, ramp, sheet, walker

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals")
EYE = flat("#1c1214")
GLINT = flat("#f4efe6")


# --- Hedgehog ----------------------------------------------------------------------

def hedgehog():
    spine = ramp("#6e5a4c", "#22180e")
    tip = ramp("#b8a488", "#3a2a1c")
    face = ramp("#c8a482", "#4a3020")
    L = {
        "q": (spine, "body", None), "Q": (tip, "body", MID), "h": (face, "head", None),
        "e": (EYE, "head", None), "n": (EYE, "head", None),
    }
    side = View("""
...Q.Q.Q.....
.QqQqQqQq....
QqqQqqQqqhh..
qQqqQqqQhhhe.
qqqqqqqqhhhhn
.qqqqqqqhhh..
""", L, legs=[(2, 5, "B", False, face, face), (8, 5, "A", False, face, face),
              (3, 5, "A", True, face, face), (9, 5, "B", True, face, face)],
                idles=[{"head": (0, 1)}, {"head": (1, 1)}])
    front = View("""
.Q.Q.Q.Q.
QqQqQqQqQ
qQqhhhqQq
qqhehehqq
qqhhnhhqq
.qhhhhhq.
""", L, legs=[(2, 5, "A", True, face, face), (6, 5, "B", True, face, face)],
                 idles=[{"head": (0, 1)}, {"head": (0, 1)}], ox=3, straight=True)
    back = View("""
.Q.Q.Q.Q.
QqQqQqQqQ
qQqQqQqQq
QqQqQqQqQ
qqQqqqQqq
.qqqqqqq.
""", L, legs=[(2, 5, "A", True, face, face), (6, 5, "B", True, face, face)],
                idles=[{}, {}], ox=3, straight=True)
    return [walker(v, 15, 8) for v in (side, front, back)]


# --- Birds -------------------------------------------------------------------------
# Each part is drawn where it sits in the frame (rows from the top), so a frame is its
# parts laid over each other (creature_kit.flyer).

WINGS_FRONT_13 = ["""
..............
..g.......g...
..gg.....gg...
...gg...gg....
....gg.gg.....
""", """
..............
..............
..............
..............
..............
..............
gggg.....gggg.
.ggg.....ggg..
""", """
..............
..............
..............
..............
..............
..............
..............
...gg...gg....
..gg.....gg...
.gg.......gg..
"""]


def butterfly():
    # Light wings: each butterfly is drawn in one of its species' tints (creatures.yaml),
    # which multiply the picture.
    wing = ramp("#f8f6ee", "#6a6460")
    under = ramp("#d8d4cc", "#5a5450")
    body = flat("#2e2424")
    L = {"w": (wing, "wing", None), "u": (under, "wing", None), "k": (body, "body", None)}
    W, H = 9, 7
    frames = []
    for art in ["""
.k...k.
ww.k.ww
wwwkwww
.uuku..
.uu.uu.
""", """
.k...k.
..wkw..
..wkw..
..uku..
...u...
""", """
.k...k.
...k...
wwwkwww
uu.k.uu
.u...u.
"""]:
        frames.append(compose([(art, 0, 0)], L, W, H))
    return [frames]


SHEETS = {
    "hedgehog": hedgehog,
    "butterfly": butterfly,
}


def main():
    only = sys.argv[1:]
    for name in SHEETS:
        if only and name not in only:
            continue
        path = os.path.join(ROOT, name, "sprites", "creatures", "%s.png" % name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sheet(SHEETS[name]()).save(path)
        print(path)


if __name__ == "__main__":
    main()
