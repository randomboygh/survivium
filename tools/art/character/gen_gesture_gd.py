"""Writes tools/art/player_gesture_art.gd from gesture data modules (gestures_wide frames:
`top`, `x0` -3, rows 20 wide from box x -3; `bob` the head's place, the stand's drop if
not given; `body` how far the body under the head went down from the stand, the bob less
the drop if not given; `eyes` "shut" where they are not open; `head` the way the head is
turned where it is not the body's, a west one flipped from its east one; `head_shift` (x, 0)
how far the head goes aside, written as `lean`).
python3 -I gen_gesture_gd.py <out.gd> <gesture>=<module>:<attr>[:<columns>] ...
columns: the animation's own columns in the order it first plays them (player.yaml), where
it shows the stand's column 0 before its own (the nod: 0,50): {} stands for that frame, as
PlayerArt.column counts it."""
import sys as _s; _s.path.insert(0, __file__.rsplit("/", 1)[0])
import importlib, sys
import gestures_wide as gw

DROP = {"s": 0, "se": 1, "e": 1, "ne": 1, "n": 1}
# The stand's first row of the body and its waistband's row (PlayerArt.BODY).
NECK = {"s": 11, "se": 12, "e": 12, "ne": 12, "n": 12}
HIPS = {"s": 14, "se": 15, "e": 14, "ne": 15, "n": 15}
# Where the hands are standing (PlayerArt.pose of the stand, less the bob): a hand drawn where
# the stand has it keeps its place, so what it holds does not move.
STAND = {"s": [[3, 14], [10, 14]], "se": [[4, 14], [10, 13]], "e": [[7, 14], [6, 14]],
         "ne": [[10, 14], [3, 14]], "n": [[10, 14], [3, 14]]}
X0 = -2
W = 18
HEADER = '''extends RefCounted
## The gestures (Gestures, decision 183), drawn whole under the head as the walk is
## (WalkArt), frames for each drawn direction (PlayerArt.VIEW), the west ones mirrored, in
## the order of their animation's columns (player.yaml). After the user's review
## (2026-11-20):
## - the wave: the right hand up by the face at the eyes' rows, two pixels square, on a
##   short shoulder (two pixels on the diagonal, a pixel and a half wide: the light over its
##   shade, a pixel of shade under the hand next to it), the hand against the hair on its
##   top row; the hand and the shoulder go a pixel out and back. Turned a little the hand is a
##   pixel over the head's edge (a hand in front of the body is drawn with the fists, over the
##   head), so the shoulder is as short. From the side the near arm is in front of the head:
##   the hand over its side by the ear (its lower row, on the skin, in the shade), the forearm
##   up across the jaw. Turned away the hand is by the jaw, clear of the cheek; from behind by
##   the head at the ear's row.
## - the nod: the body stands and the head goes a pixel down over the neck, the eyes shut as
##   in the blink.
## - the shake: the body stands and the head turns an eighth to one side and to the other,
##   going a pixel the way the face turns (from the front to the south-east and the
##   south-west); from the side it turns toward and away without going aside, which would
##   take it off the neck.
## - the point: the right hand out level beside the body's first row, a pixel of arm from the
##   shoulder, the finger a pixel past the hand; from the side forward, from behind to the
##   side; the hand against the body where the arm would show only outline.
## - the beckon: the hand where the point holds it, without the finger, lifted a pixel and
##   back.
## - the bow: the body stands, the head a pixel down and then two, the chest's second row
##   folding away at the bottom with the eyes shut; turned and from the side the head goes a
##   pixel forward there.
## - the clap: the hands, two pixels square, out beside the chest a pixel from the shoulder,
##   then three pixels in, met in its middle, edged with the skin's deepest shade (the
##   outline's own would cut the chest); turned a little the near hand is against the body;
##   from the side the near hand is out in front and then against the chest; turned away and
##   from behind the hands are out at the shoulders, then before the body, where only the
##   forearms show.
##
## A frame: the head's place `bob` (the stand's drop in it), how far it goes aside `lean`
## where it does, its eyes `eyes` where they are not open ("shut" as in the blink,
## PlayerArt.pose), the way it is turned `head` where it is not the body's
## (PlayerArt.frame_letters), `rows` from box row `top` and from box
## column X0 (a hand goes out beside the head past the box's edge) in the letters of
## PlayerArt.INK with the hands' skin in the digits of WalkArt.HANDS, the body's first row
## `neck` (no higher than the frame's first: a bow's chest folds; rows over it hold only a
## raised arm, which stays where it is in every form), the
## waistband's row `hips` and the hands' places `hands` ([right, left]: the hand's lowest
## pixel under its middle, the one nearer the body on a tie, less the bob; so a hand that
## moves moves its place). Made with the review tools in the project library,
## written by tools/art/character/gen_gesture_gd.py.

const FormsArt := preload("res://tools/art/player_forms_art.gd")

## The rows' first column in the box: they reach as far past its other edge.
const X0 := %d
## The frames by gesture and drawn direction, in the order of the gesture's columns
## (PlayerArt.column); {} where it shows the stand (column 0), which is drawn as it is.
const FRAMES := {
''' % X0
FOOTER = '''}


## Frame `i` of gesture `gesture` in direction `dir`, with its rows' first column `x0`; {}
## for none.
static func frame(gesture: String, dir: String, i: int) -> Dictionary:
	var frames: Array = FRAMES.get(gesture, {}).get(dir, [])
	if i < 0 or i >= frames.size() or frames[i].is_empty():
		return {}
	var f: Dictionary = frames[i].duplicate()
	f.x0 = X0
	return f


## The rows of frame `f` for a body of build `build` and figure `figure` (FormsArt.body)
## drawn in direction `dir`, from column X0: the box's part made in the form, the hands out
## past its edges thinned with it.
static func rows(f: Dictionary, dir: String, build: String, figure: String) -> Array:
	var wide: Array = f.rows
	if build in FormsArt.NARROW:
		wide = wide.map(_thin)
	var box: Array = wide.map(func(r: String) -> String: return r.substr(-X0, 14))
	box = FormsArt.body(box, dir, build, figure, f.neck - f.top, f.hips - f.top)
	var out := []
	for y in wide.size():
		out.append(wide[y].substr(0, -X0) + box[y] + wide[y].substr(14 - X0))
	return out


## Row `r` (from column X0) with each hand a pixel narrower where it is wider than one: the
## pixel of it farthest from the box's middle left out (FormsArt's thin build).
static func _thin(r: String) -> String:
	var middle := 6.5 - X0
	for digits: String in ["456", "789"]:
		var xs := []
		for x in r.length():
			if r[x] in digits:
				xs.append(x)
		if xs.size() > 1:
			var far: int = xs[0] if absf(xs[0] - middle) > absf(xs[-1] - middle) else xs[-1]
			r[far] = "."
	return r
'''


def pixels(rows, top, digits, x0=-3):
    return {(x + x0, top + y) for y, r in enumerate(rows) for x, c in enumerate(r) if c in digits}


def lowest(fr, digits, bob):
    pts = [(x + fr["x0"], fr["top"] + y) for y, r in enumerate(fr["rows"]) for x, c in enumerate(r) if c in digits]
    if not pts:
        return None
    low = max(p[1] for p in pts)
    mid = sum(p[0] for p in pts) / len(pts)
    xs = [p[0] for p in pts if p[1] == low]
    return [min(xs, key=lambda v: (abs(v - mid), abs(v - 6.5))), low - bob]


def main():
    out = sys.argv[1]
    lines = [HEADER]
    for spec in sys.argv[2:]:
        name, src = spec.split("=")
        m, a, *cols = src.split(":")
        data = getattr(importlib.import_module(m), a)
        stand_first = bool(cols) and cols[0].split(",")[0] == "0"
        lines.append('\t"%s": {\n' % name)
        for d in ["s", "se", "e", "ne", "n"]:
            lines.append('\t\t"%s": [\n' % d)
            if stand_first:
                lines.append('\t\t\t{},\n')
            for fr in data[d]:
                assert fr["x0"] == -3 and all(len(r) == 20 for r in fr["rows"]), (name, d)
                assert fr["top"] + len(fr["rows"]) == 18, (name, d, fr["top"])
                assert all(r[0] == "." and r[-1] == "." for r in fr["rows"]), (name, d, "past X0")
                bob = fr.get("bob", DROP[d])
                # How far the body went down from the stand (a nod's stays as the head goes).
                shift = fr.get("body", bob - DROP[d])
                st = gw.stand(d)
                hands = []
                for i, digits in enumerate(["456", "789"]):
                    drawn = pixels(fr["rows"], fr["top"], digits)
                    still = {(x, y + shift) for x, y in pixels([st[y] for y in sorted(st)], 10, digits)}
                    if drawn == still:
                        hands.append([STAND[d][i][0], STAND[d][i][1] + shift - (bob - DROP[d])])
                    else:
                        hands.append(lowest(fr, digits, bob) or STAND[d][i])
                rows = [row[1:-1] for row in fr["rows"]]
                eyes = ' "eyes": "%s",' % fr["eyes"] if fr.get("eyes", "open") != "open" else ""
                if fr.get("head", d) != d:
                    eyes += ' "head": "%s",' % fr["head"]
                assert not fr.get("rot") and not fr.get("tilt"), (name, d, "the game turns no head about the neck")
                lean, rise = fr.get("head_shift", (0, 0))
                assert rise == 0, (name, d, "the head goes only aside")
                if lean:
                    eyes = ' "lean": %d,' % lean + eyes
                lines.append('\t\t\t{"bob": %d,%s "top": %d, "neck": %d, "hips": %d, "hands": [[%d, %d], [%d, %d]], "rows": [\n'
                             % (bob, eyes, fr["top"], max(NECK[d] + shift, fr["top"]), HIPS[d] + shift, hands[0][0], hands[0][1], hands[1][0], hands[1][1]))
                lines += ['\t\t\t\t"%s",\n' % row for row in rows]
                lines.append("\t\t\t]},\n")
            lines.append("\t\t],\n")
        lines.append("\t},\n")
    lines.append(FOOTER)
    open(out, "w").write("".join(lines))


main()
