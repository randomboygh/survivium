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


# --- Fox ---------------------------------------------------------------------------

def fox():
    fur = ramp("#d8662a", "#4a1e16")
    tail = ramp("#c85a26", "#4a1e16")
    white = ramp("#efe6d6", "#5a3a30")
    dark = ramp("#4a2c26", "#24120e")
    nose = flat("#2a1a1a")
    L = {
        "o": (fur, "body", None), "h": (fur, "head", None), "t": (tail, "tail", None),
        "W": (white, "tail", None), "w": (white, "body", None), "m": (white, "head", None),
        "e": (EYE, "head", None), "n": (nose, "head", None), "d": (dark, "head", None),
        "T": (tail, "tail", OUTLINE),
    }
    side = View("""
..............d..d..
.............hh.hh..
.............hhhhh..
............hhhhehh.
............hhhhhmmn
.....ooooooooohmmm..
..tttoooooooooomw...
.ttttooooooooowww...
tttt.oooooooooww....
WWt...oooooooow.....
WW..................
""", L, legs=[(5, 9, "B", False, fur, dark), (11, 9, "A", False, fur, dark),
              (7, 9, "A", True, fur, dark), (13, 9, "B", True, fur, dark)],
                idles=[{"tail": (0, -1)}, {"head": (1, 2)}])
    front = View("""
..d.......d..
.dhh.....hhd.
.hhhhhhhhhhh.
.hhhhhhhhhhh.
.hhehhhhhehh.
.mmhhhhhhhmm.
..mmmmnmmmm..
...mmmmmmm...
..oowwwwwoo..
.ooowwwwwooo.
.oooowwwoooo.
..ooo...ooo..
""", L, legs=[(3, 10, "B", False, fur, dark), (9, 10, "A", False, fur, dark),
              (4, 11, "A", True, white, dark), (8, 11, "B", True, white, dark)],
                 idles=[{"head": (1, 0)}, {"head": (0, 2)}], ox=4, straight=True)
    back = View("""
..d.......d..
.ddh.....hdd.
.dhhhhhhhhhd.
.hhhhhhhhhhh.
.hhhhhhhhhhh.
..hhhhhhhhh..
...hhhhhhh...
..oooooooooo.
.oooooTttTooo
.ooooTtttToo.
.ooooTtttToo.
..oooTtttTo..
.....TtttT...
.....WWWWW...
......WWW....
""", L, legs=[(4, 10, "A", True, fur, dark), (9, 10, "B", True, fur, dark)],
                idles=[{"tail": (1, 0)}, {"head": (0, 1)}], ox=4, order=("head", "body", "tail"), straight=True)
    return [walker(v, 22, 16) for v in (side, front, back)]


# --- Boar --------------------------------------------------------------------------

def boar():
    fur = ramp("#6e5444", "#2a1a16")
    mane = ramp("#3e2e28", "#1c1210")
    snout = ramp("#b88878", "#3a2420")
    tusk = ramp("#ece2c8", "#4a3a2e")
    L = {
        "o": (fur, "body", None), "h": (fur, "head", None), "m": (mane, "body", None),
        "M": (mane, "head", None), "s": (snout, "head", None), "n": (snout, "head", DARK),
        "T": (tusk, "head", MID), "e": (EYE, "head", None), "t": (mane, "tail", None),
    }
    side = View("""
.....m.m.m.m.........
....mmmmmmmmmm.M.....
..ommmmmmmmmmMhh.....
.ooooooooooooohhh....
tooooooooooooohhehh..
.oooooooooooooohhhhh.
.ooooooooooooooohhhsn
.ooooooooooooo..hhss.
..oooooooooooo...T...
...ooooooooooo.......
""", L, legs=[(3, 9, "B", False, fur, mane), (12, 9, "A", False, fur, mane),
              (5, 9, "A", True, fur, mane), (14, 9, "B", True, fur, mane)],
                idles=[{"tail": (0, -1)}, {"head": (1, 2)}])
    front = View("""
......m......
....mmmmm....
..MoMMMMMoM..
..hhhhhhhhh..
.hhehhhhhehh.
.hhhhhhhhhhh.
..hhhsssshh..
..ohsnssnsho.
.ooTssssssTo.
.ooohssssooo.
.oooohhhoooo.
..ooo...ooo..
""", L, legs=[(3, 10, "B", False, fur, mane), (9, 10, "A", False, fur, mane),
              (4, 11, "A", True, fur, mane), (8, 11, "B", True, fur, mane)],
                 idles=[{"head": (1, 0)}, {"head": (0, 1)}], ox=4, straight=True)
    back = View("""
......m......
....mmmmm....
..M.mmmmm.M..
..hmmmmmmmh..
.oooommmoooo.
.ooooomoooooo
.oooooooooooo
.oooooooooooo
.oooooooooooo
..ooooooooooo
..oooootooo..
......t......
""", L, legs=[(3, 10, "A", True, fur, mane), (9, 10, "B", True, fur, mane)],
                idles=[{"tail": (1, 0)}, {"head": (0, 1)}], ox=4, order=("head", "body", "tail"), straight=True)
    return [walker(v, 23, 15) for v in (side, front, back)]


# --- Deer --------------------------------------------------------------------------

def deer():
    fur = ramp("#a8703e", "#3a2214")
    light = ramp("#e2cba0", "#5a4028")
    dark = ramp("#5a3a22", "#24140c")
    horn = ramp("#d8c8a8", "#4a3a28")
    L = {
        "o": (fur, "body", None), "h": (fur, "head", None), "l": (light, "body", None),
        "m": (light, "head", None), "W": (light, "tail", None), "a": (horn, "head", None),
        "e": (EYE, "head", None), "n": (dark, "head", OUTLINE), "d": (dark, "head", None),
    }
    side = View("""
...........a.a...
...........aaa...
............dhh..
...........hhhhh.
...........hhehhh
...........hhhhmn
..........hhh....
..........hhh....
.W........hhh....
WWoooooooohhh....
.ooooooooooooo...
.ooooooooooooo...
.ooooooooooooo...
..ollllllloo.....
""", L, legs=[(2, 13, "B", False, fur, dark), (10, 13, "A", False, fur, dark),
              (3, 13, "A", True, fur, dark), (11, 13, "B", True, fur, dark)],
                idles=[{"tail": (0, -1)}, {"head": (2, 5)}])
    front = View("""
..a.....a..
..aa...aa..
...aa.aa...
.dhhhhhhhd.
..hhhhhhh..
..hehhheh..
...hhhhh...
...hmmmh...
....mnm....
....hhh....
...ohhho...
..ooommoo..
..oooooooo.
..oooooooo.
...oo..oo..
""", L, legs=[(2, 14, "B", False, fur, dark), (8, 14, "A", False, fur, dark),
              (3, 14, "A", True, fur, dark), (7, 14, "B", True, fur, dark)],
                 idles=[{"head": (1, 0)}, {"head": (0, 3)}], ox=4, straight=True)
    back = View("""
..a.....a..
..aa...aa..
...aa.aa...
.dhhhhhhhd.
..hhhhhhh..
..hhhhhhh..
...hhhhh...
...hhhhh...
....hhh....
....hhh....
...ooooo...
..ooooooo..
..oooWWooo.
..oooWWooo.
...oollo...
""", L, legs=[(3, 14, "A", True, fur, dark), (7, 14, "B", True, fur, dark)],
                idles=[{"tail": (0, -1)}, {"head": (0, 3)}], ox=4, order=("head", "body", "tail"), straight=True)
    return [walker(v, 19, 21) for v in (side, front, back)]


# --- Duck --------------------------------------------------------------------------

def bear():
    fur = ramp("#7a5638", "#2a1810")
    muzzle = ramp("#b8946a", "#3a2614")
    paw = ramp("#4e3424", "#1e120c")
    nose = flat("#1e1410")
    L = {
        "o": (fur, "body", None), "h": (fur, "head", None), "m": (muzzle, "head", None),
        "e": (EYE, "head", None), "n": (nose, "head", None), "t": (fur, "tail", None),
    }
    side = View("""
..................h..h..
.......ooooooo...hhhhhh.
....ooooooooooo.hhhhhhh.
..ooooooooooooooohhhhehh
.oooooooooooooooohhhhhmm
toooooooooooooooohhhmmmn
.ooooooooooooooooohhmmm.
.oooooooooooooooooo.....
.oooooooooooooooooo.....
..oooooooooooooooo......
..ooooooooooooooo.......
""", L, legs=[(2, 9, "B", False, fur, paw, 2), (13, 9, "A", False, fur, paw, 2),
              (5, 9, "A", True, fur, paw, 2), (15, 9, "B", True, fur, paw, 2)],
                idles=[{"head": (0, -1)}, {"head": (1, 2)}])
    front = View("""
...hh.......hh...
...hhhhhhhhhhh...
...hhhhhhhhhhh...
..hhhhhhhhhhhhh..
..hhhehhhhhehhh..
..hhhhhmmmhhhhh..
...hhhmmnmmhhh...
.oooohhmmmhhoooo.
.ooooohhhhhooooo.
ooooooooooooooooo
ooooooooooooooooo
.ooooooooooooooo.
..oooo.....oooo..
""", L, legs=[(2, 11, "B", False, fur, paw, 2), (13, 11, "A", False, fur, paw, 2),
              (4, 11, "A", True, fur, paw, 2), (11, 11, "B", True, fur, paw, 2)],
                 idles=[{"head": (1, 0)}, {"head": (0, 2)}], ox=4, straight=True)
    back = View("""
...hh.......hh...
...hhhhhhhhhhh...
...hhhhhhhhhhh...
..hhhhhhhhhhhhh..
..hhhhhhhhhhhhh..
...hhhhhhhhhhh...
....ooooooooo....
.ooooooooooooooo.
ooooooooooooooooo
ooooooooooooooooo
ooooooooooooooooo
.ooooooootooooooo
..oooo.....oooo..
""", L, legs=[(3, 11, "A", True, fur, paw, 2), (12, 11, "B", True, fur, paw, 2)],
                idles=[{"tail": (0, -1)}, {"head": (0, 2)}], ox=4, order=("head", "body", "tail"), straight=True)
    return [walker(v, 26, 17) for v in (side, front, back)]


# --- Wolf --------------------------------------------------------------------------

def wolf():
    fur = ramp("#8a8890", "#26242c")
    back_ = ramp("#5a5860", "#1c1a22")
    light = ramp("#d4d2d4", "#4a4850")
    paw = ramp("#4c4a52", "#1c1a20")
    nose = flat("#18161a")
    yellow = flat("#e8c040")
    L = {
        "o": (fur, "body", None), "h": (fur, "head", None), "s": (back_, "body", None),
        "S": (back_, "head", None), "w": (light, "body", None), "m": (light, "head", None),
        "e": (yellow, "head", None), "n": (nose, "head", None), "t": (back_, "tail", None),
        "W": (fur, "tail", None),
    }
    side = View("""
...............S..S..
..............hh.hh..
..............hhhhh..
.............hhhhehh.
.....sssssss.hhhhhmmn
...ssssssssssshhmmm..
..tooooooooooohmmm...
.ttoooooooooooomw....
tWt.oooooooooowww....
Wt...oooooooooww.....
W....................
""", L, legs=[(5, 9, "B", False, fur, paw), (12, 9, "A", False, fur, paw),
              (7, 9, "A", True, fur, paw), (14, 9, "B", True, fur, paw)],
                idles=[{"tail": (0, -1)}, {"head": (1, 2)}])
    front = View("""
..S.......S..
.Shh.....hhS.
.hhhhhhhhhhh.
.hhhhhhhhhhh.
.hhehhhhhehh.
.hhhhmmmhhhh.
..mmmmnmmmm..
...mmmmmmm...
..sswwwwwss..
.oooowwwoooo.
.oooowwwoooo.
..ooo...ooo..
""", L, legs=[(3, 10, "B", False, fur, paw), (9, 10, "A", False, fur, paw),
              (4, 11, "A", True, light, paw), (8, 11, "B", True, light, paw)],
                 idles=[{"head": (1, 0)}, {"head": (0, 2)}], ox=4, straight=True)
    back = View("""
..S.......S..
.SSh.....hSS.
.Shhhhhhhhhs.
.hhhhhhhhhhh.
.hhhhhhhhhhh.
..hhhhhhhhh..
...SSSSSSS...
..sssssssss..
.ooosssssooo.
.oooootttooo.
.ooootWtttoo.
..ooottttoo..
.....tttt....
......tt.....
""", L, legs=[(4, 10, "A", True, fur, paw), (9, 10, "B", True, fur, paw)],
                idles=[{"tail": (1, 0)}, {"head": (0, 1)}], ox=4, order=("head", "body", "tail"), straight=True)
    return [walker(v, 23, 17) for v in (side, front, back)]



# --- Cat ---------------------------------------------------------------------------

def cat():
    fur = ramp("#8c8a96", "#26242e")
    stripe = ramp("#5a5866", "#1e1c26")
    light = ramp("#d8d4d8", "#4a4650")
    green = flat("#a8d048")
    nose = flat("#d08a8a")
    L = {
        "o": (fur, "body", None), "h": (fur, "head", None), "s": (stripe, "body", None),
        "S": (stripe, "head", None), "t": (stripe, "tail", None), "m": (light, "head", None),
        "l": (light, "body", None), "e": (green, "head", None), "n": (nose, "head", None),
    }
    side = View("""
t...........h..h.
t...........hhhh.
.t.........hhhhhh
.t.........hhhehh
..t.oooooooShhhmn
...tosososooommm.
...ooooooooooo...
...ooooooooooo...
....olllllloo....
""", L, legs=[(4, 8, "B", False, fur, fur), (10, 8, "A", False, fur, fur),
              (5, 8, "A", True, fur, light), (11, 8, "B", True, fur, light)],
                idles=[{"tail": (1, 0)}, {"head": (0, 1)}])
    front = View("""
.h.....h.
.hh...hh.
.hhhhhhh.
hhShShShh
hhehhhehh
hhhmnmhhh
.hmmmmmh.
..ollllo.
.ooolllooo
.oo...oo.
""", L, legs=[(2, 8, "A", True, fur, light), (6, 8, "B", True, fur, light)],
                 idles=[{"head": (1, 0)}, {"head": (0, 1)}], ox=4, straight=True)
    back = View("""
.h.....h.
.hh...hh.
.hhhhhhh.
hhShShShh
hhhhhhhhh
hhhhhhhhh
.hhhhhhh.
..sssss..
.osososo.
.ooootoo.
.oo..toot
......tt.
""", L, legs=[(2, 9, "A", True, fur, fur), (6, 9, "B", True, fur, fur)],
                idles=[{"tail": (1, -1)}, {"head": (0, 1)}], ox=4, order=("head", "body", "tail"), straight=True)
    return [walker(v, 19, 14) for v in (side, front, back)]


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
    "fox": fox, "boar": boar, "deer": deer, "bear": bear, "wolf": wolf,
    "cat": cat, "hedgehog": hedgehog,
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
