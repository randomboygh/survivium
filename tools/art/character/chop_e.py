"""Chop, edits of 2026-11-19 22:53 over chop_d."""
import copy
import chop_d
from chop_d import E
CHOP = copy.deepcopy(chop_d.CHOP)
# South-east, the top: the hand and the axe a pixel nearer the middle.
f = CHOP["se"][1]
f["rows"][:4] = ["." + r[:-1] for r in f["rows"][:3]] + ["...45VkkVc...."]
f["r"] = [1, f["r"][1]]
# South-east, the strike: the hand up at the chest so the axe shows.
CHOP["se"][2] = {"bob": 2, "top": 13, "r": [6, 13], "a": 8, "f": True, "rows": [
    "....c445Vc....",
    ".....cCCC88...",
    ".....cCCC88...",
    ".....UUuUU....",
    ".....KB.KB...."]}
# East: the top's edge toward the chop; the strike's edge as in the first two frames.
CHOP["e"][1]["ccw"] = False
CHOP["e"][2]["ccw"] = True
# North-east, the wind-up: the armpit a pixel thinner.
CHOP["ne"][0]["rows"][3] = "....88cccCC..."
# North, the strike and the follow-through: the old frames (the arm behind the body).
CHOP["n"][2] = {"bob": 2, "top": 13, "r": [8, 15], "a": 0, "f": False, "rows": [
    "...CCVVVVCC...",
    "...CCccccCC...",
    "..77CccccC4...",
    "..88uuuuuu5...",
    "....bb..bb...."]}
CHOP["n"][3] = {"bob": 1, "top": 12, "r": [8, 14], "a": 0, "f": False, "rows": [
    "...CCVVVVCC...",
    "...CCccccCC...",
    "..77CccccC4...",
    "..88uuuuuu5...",
    "....mm..mm....",
    "....bb..bb...."]}
