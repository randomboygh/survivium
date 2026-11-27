"""Dig, first draft for review: lift, thrust, push (crouched), toss; the near hand holds the
shaft halfway (`slide`), the other near the handle's end."""
import copy
import dig_c
T = "shovel"
DIG = {}
DIG["e"] = copy.deepcopy(dig_c.DIG["e"])
DIG["e"][2].update({"r": [10, 14], "slide": 5})
DIG["e"][3] = {"bob": 1, "top": 11, "r": [11, 11], "a": 1, "slide": 4, "f": False, "tool": T, "rows": [
    "..............",
    "......CVk.44..",
    ".....cC444....",
    ".....UUU......",
    ".....ttt......",
    "......tTt.....",
    "......BBb....."]}
DIG["s"] = [
    {"bob": -1, "top": 10, "r": [6, 12], "a": 8, "slide": 2, "f": True, "tool": T, "rows": [
        "....cVkkVc....",
        "...ccCCCCcc...",
        "...c4458Cc....",
        "....cCCCCc....",
        "....UUuuUU....",
        "....TT..TT....",
        "....tt..TT....",
        "....BB..BB...."]},
    {"bob": 0, "top": 10, "r": [6, 13], "a": 8, "slide": 2, "f": True, "tool": T, "rows": [
        "..............",
        "....cVkkVc....",
        "...ccCCCCcc...",
        "...c4458Cc....",
        "....UUuuUU....",
        "....TT..TT....",
        "....tt..TT....",
        "....BB..BB...."]},
    {"bob": 1, "top": 10, "r": [6, 14], "a": 8, "slide": 1, "f": True, "tool": T, "rows": [
        "..............",
        "..............",
        "....cVkkVc....",
        "...ccCCCCcc...",
        "...cc4458c....",
        "....UUuuUU....",
        "....TT..TT....",
        "....BB..BB...."]},
    {"bob": 0, "top": 10, "r": [2, 12], "a": 7, "slide": 4, "f": False, "tool": T, "rows": [
        "..............",
        "...4cVkkVc....",
        "..45CCCCCcc...",
        "...ccCCCC87...",
        "....UUuuUU....",
        "....TT..TT....",
        "....tt..TT....",
        "....BB..BB...."]},
]
DIG["se"] = [
    {"bob": 1, "top": 11, "r": [9, 13], "a": 3, "slide": 6, "f": True, "tool": T, "rows": [
        ".....VkkVc....",
        "....ccC4488...",
        ".....cCCC.....",
        ".....UUuUU....",
        ".....TT.Tt....",
        ".....KB.KB...."]},
    {"bob": 1, "top": 11, "r": [9, 14], "a": 3, "slide": 6, "f": True, "tool": T, "rows": [
        "..............",
        ".....VkkVc....",
        "....ccC4488...",
        ".....UUuUU....",
        ".....TT.Tt....",
        ".....KB.KB...."]},
    {"bob": 2, "top": 12, "r": [9, 15], "a": 3, "slide": 5, "f": True, "tool": T, "rows": [
        "..............",
        ".....VkkVc....",
        "....ccC4488...",
        ".....UUuUU....",
        ".....KB.KB...."]},
    {"bob": 1, "top": 11, "r": [11, 12], "a": 1, "slide": 4, "f": False, "tool": T, "rows": [
        ".....VkkVc....",
        "....ccCC4488..",
        ".....cCCC.....",
        ".....UUuUU....",
        ".....TT.Tt....",
        ".....KB.KB...."]},
]
DIG["ne"] = [
    {"bob": 1, "top": 11, "r": [11, 12], "a": 2, "slide": 3, "f": False, "tool": T, "rows": [
        ".....VVVC.....",
        "....cccc8844..",
        ".....VcccC....",
        ".....uuuuu....",
        ".....mm.tt....",
        ".....bb.BB...."]},
    {"bob": 1, "top": 11, "r": [11, 13], "a": 1, "slide": 5, "f": False, "tool": T, "rows": [
        ".....VVVC.....",
        "....ccccCC....",
        ".....Vccc8844.",
        ".....uuuuu....",
        ".....mm.tt....",
        ".....bb.BB...."]},
    {"bob": 2, "top": 12, "r": [11, 14], "a": 1, "slide": 4, "f": False, "tool": T, "rows": [
        ".....VVVC.....",
        "....ccccCC....",
        ".....Vccc8844.",
        ".....uuuuu....",
        ".....bb.BB...."]},
    {"bob": 1, "top": 10, "r": [12, 11], "a": 1, "slide": 4, "f": False, "tool": T, "rows": [
        "..............",
        "...........44.",
        ".....VVVC884..",
        "....ccccCC....",
        ".....VcccC....",
        ".....uuuuu....",
        ".....mm.tt....",
        ".....bb.BB...."]},
]
DIG["n"] = [
    {"bob": 1, "top": 11, "r": [8, 12], "a": 0, "slide": 5, "f": False, "tool": T, "rows": [
        "...CCVVVVCC...",
        "...CCcc7744...",
        "....CccccC....",
        "....uuuuuu....",
        "....mm..mm....",
        "....bb..bb...."]},
    {"bob": 1, "top": 11, "r": [8, 13], "a": 0, "slide": 3, "f": False, "tool": T, "rows": [
        "...CCVVVVCC...",
        "...CCccccCC...",
        "....Ccc7744...",
        "....uuuuuu....",
        "....mm..mm....",
        "....bb..bb...."]},
    {"bob": 2, "top": 12, "r": [8, 14], "a": 0, "slide": 3, "f": False, "tool": T, "rows": [
        "...CCVVVVCC...",
        "...CCccccCC...",
        "....Ccc7744...",
        "....uuuuuu....",
        "....bb..bb...."]},
    {"bob": 1, "top": 10, "r": [12, 11], "a": 1, "slide": 4, "f": False, "tool": T, "rows": [
        "..............",
        "...........44.",
        "...CCVVVVC.4..",
        "...CCcccc774..",
        "....CccccC....",
        "....uuuuuu....",
        "....mm..mm....",
        "....bb..bb...."]},
]
