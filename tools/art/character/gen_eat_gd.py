"""Writes tools/art/player_eat_art.gd from an eat data module (eat_proto frames: rows from box
row `top`, `bob` with the stand's drop, the hand's mark `r` where the food's middle goes, `f` in
front of the body, `of` the other hand in front of the food, `eyes` "shut").
python3 -I gen_eat_gd.py <module> <out.gd>"""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
data = importlib.import_module(sys.argv[1]).EAT
out = sys.argv[2]
REST = {"s": [10, 14], "se": [9, 13], "e": [6, 14], "ne": [3, 14], "n": [3, 14]}
COMMENT = {
    "s": "\t# From the front: the food to the belly, the arm a row shorter; up to the chin, the hand by it\n\t# at the chest's height over the elbow; the head down onto it; down again.\n",
    "se": "\t# Turned, as from the front: the food before the face's middle, the other arm behind it.\n",
    "e": "\t# From the side the food is held against the belly, then before the chin, the hand under the\n\t# chin reaching a pixel into it (the west twin's food sits a pixel further out).\n",
    "ne": "\t# From behind the body hides the food but for its edge past the neck: the arm a row shorter,\n\t# then its elbow up at the shoulder.\n",
    "n": "\t# From the back the food is hidden: the elbow out at the shoulder and the nod show the bite.\n",
}


def other_hand(fr):
    pts = [(x, fr["top"] + y) for y, r in enumerate(fr["rows"]) for x, c in enumerate(r) if c in "789"]
    if not pts:
        return None
    low = max(p[1] for p in pts)
    xs = [p[0] for p in pts if p[1] == low]
    return [min(xs, key=lambda v: abs(v - 6.5)), low]


def first(fr, test):
    for y, r in enumerate(fr["rows"]):
        if any(test(c) for c in r):
            return fr["top"] + y
    return None


lines = []
for d in ["s", "se", "e", "ne", "n"]:
    lines.append(COMMENT[d].rstrip("\n"))
    lines.append(f'\t"{d}": [')
    for fr in data[d]:
        assert fr["top"] + len(fr["rows"]) == 18, (d, fr)
        bob = fr["bob"]
        l = other_hand(fr)
        l = [l[0], l[1] - bob] if l else REST[d]
        r = [fr["r"][0], fr["r"][1] - bob]
        hips = first(fr, lambda c: c in "Uu")
        neck = first(fr, lambda c: c not in ".456789")
        extra = ""
        if "of" in fr:
            extra += ', "of": %s' % ("true" if fr["of"] else "false")
        if fr.get("eyes"):
            extra += ', "eyes": "%s"' % fr["eyes"]
        f = "true" if fr.get("f", True) else "false"
        lines.append(f'\t\t{{"bob": {bob}, "top": {fr["top"]}, "neck": {neck}, "hips": {hips}, "hands": [{r}, {l}], "a": {fr["a"]}, "f": {f}{extra}, "rows": ['.replace("'", ""))
        for row in fr["rows"]:
            lines.append(f'\t\t\t"{row}",')
        lines.append("\t\t]},")
    lines.append("\t],")
body = "\n".join(lines)
src = f'''extends RefCounted
## The eat, drawn whole as the walk is (WalkArt), the food in one hand: four frames for
## each drawn direction (PlayerArt.VIEW), the west ones mirrored (the food with them, so
## there it is in the left hand). After the user's review (2026-11-20): the food lifted to
## the belly, the elbow by the side; raised to the chin, the hand beside it; the bite, a
## nod: the head a row down onto the food, which stays where it was, the eyes shut (the
## chest's row folds away, the legs never move); lowered again, chewing with the eyes
## shut. The bite is on the third frame, as the blow of the other works. Turned and from
## the side the food is before the face; from behind the body hides it, the elbow and
## the nod show the bite. What is eaten or drunk plays it (an item's `anim`).
##
## The food is the thing in the hand as it is carried, an icon cut down to a few pixels
## (Figure.icon_turns), its middle at the hand's place and the hand's skin drawn over it:
## so the hand is drawn beside the food, not across it. An icon is not mirrored with the
## figure and one of an even width has its middle a pixel left, so in a west direction it
## sits a pixel further from the body than in its east one: the frames are drawn to hold
## it both ways.
##
## A frame: the head's place `bob` (the stand's drop in it), `rows` from box row `top` in
## the letters of PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS (`neck`
## the first row of the body), the waistband's row `hips`, the hands' places `hands` ([the
## hand with the food: where the food's middle goes, the other: its lowest pixel next to
## the body], less the bob), `a` -1: the food as it is carried, `f` in front of the body,
## `of` false: the other hand behind the food, `eyes` "shut". Made with the review tools
## in the project library, written by tools/art/character/gen_eat_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The frames by drawn direction: to the belly, to the chin, the bite (a nod), down again.
const FRAMES := {{
{body}
}}


## Frame `i` of the eat drawn in direction `dir` (a drawn one), or {{}}.
static func frame(dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(dir, [])
	return frames[i] if i >= 0 and i < frames.size() else {{}}


## The rows of frame `f` for a body of build `build` and figure `figure`
## (FormsArt.body) drawn in direction `dir`, from row `top`.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	return FormsArt.body(f.rows, dir, build, figure, f.neck - f.top, f.hips - f.top)
'''
open(out, "w").write(src)
