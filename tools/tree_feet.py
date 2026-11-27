#!/usr/bin/env python3
"""Measures the trunk in the pictures of the trees drawn so (content/*/*/tree/frames.png) and in the pictures of the
stumps they leave (the look.yaml's `stump_frames`), and writes what it finds into their look.yaml:

- `foot: [half width, front]` on each look of a tree: how wide the bark is just over the ground, either side of the
  trunk's axis, and how far below the anchor (the ground under the axis) the foot's lowest bark reaches, in pixels
  of the pictures. The grass round a tree's foot follows it (Foliage._foot_grass).
- `taper: [height, half width]` on each look of a tree: how high over the ground the bark of its trunk goes up
  unbroken through the axis before the crown hides it, and how wide the trunk is just under there, in pixels.
- `cut: [half width, half depth, across]` and `top` on each stump: the ellipse its cut wood is drawn as, in pixels
  (the same from every side): its half width and half depth, and how far its middle is to the right of the axis;
  and how high the cut is drawn over the ground. The trunk holds a body off this ring, from the ground up to the
  cut, and the standing tree off the ring of its stump, narrowing from the cut's height to the crown as its
  `taper` says (TreeLooks `ring`, Body._trunk_touched); a body stands on the cut.

    python3 tools/tree_feet.py          measure every look.yaml and write `foot`, `taper`, `cut` and `top`
    python3 tools/tree_feet.py --check  exit 1 when a look.yaml's `foot`, `taper`, `cut` or `top` is missing or
                                        differs

Run it after the pictures are packed again (tools/art/trees/src/pack_*.py); tools/lint.py runs --check.

The bark is a frame pixel of alpha 2 (a palm trunk's soft outline: 3), stored 64 higher (66, 67;
tree_pictures.gdshaderinc); the cut wood of a stump 4, 5 and the resin 6, stored 64 higher (tree.gdshader). `foot`:
the width is the bark run through the axis 4..12 rows over the anchor, in each row the narrowest of the 8 turns (the
round foot without the roots that turn round it), the median of the rows; the front the median over the turns of
the lowest bark row in the axis' three columns. `taper`: in each turn the highest row over the anchor up to which
some of the axis' three columns is bark in every row, and the median width of the bark run through the axis in the
TAPER_ROWS rows under it (the crown's edge hides some of a row's bark, a fork widens one), the medians over the
turns. `cut`: the box of the cut wood of each turn, the median over the turns. The ring stands with its front on the
axis (a body in front of the axis is drawn in front of the picture, one behind it behind), so the cut, as far over
the ground as its middle is over the anchor less its half depth, is `top` high (the pictures draw a height and a
depth behind the axis alike, a pixel up the picture each).
"""
import glob
import math
import os
import re
import statistics
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Frame alphas of bark: 2 and a palm trunk's soft outline 3, as stored (64 higher) or as before.
BARK = (2, 3, 66, 67)
# A stump picture's alphas of its cut wood: 4, 5 and the resin 6, stored 64 higher.
CUT = (68, 69, 70)
# The least height of a stump's cut (pixels).
MIN_TOP = 2.0
# How many rows under the crown a trunk's width is taken from (`taper`).
TAPER_ROWS = 6
# A look or a stump of look.yaml: its place in the frames, then what this writes (dropped and written again), then
# the rest.
LOOK = re.compile(r"^(\s*- \{size: [^}]*?\bx: (\d+), y: (\d+), w: (\d+), h: (\d+), ax: (\d+), ay: (\d+))(.*)$")
WRITTEN = re.compile(r", (?:foot|top|cut|taper): \[[^\]]*\]|, top: [-0-9.]+|, feet: \[(?:\[[^\]]*\](?:, )?)*\]")


def measure(alpha, x0, y0, w, h, ax, ay):
    rows = {}
    fronts = []
    for turn in range(8):
        left = x0 + turn * w

        def bark(x, y):
            return 0 <= x < w and 0 <= y < h and alpha[left + x, y0 + y] in BARK

        for k in range(4, 13):
            y = ay - k
            if not bark(ax, y):
                continue
            a = ax
            while bark(a - 1, y):
                a -= 1
            b = ax
            while bark(b + 1, y):
                b += 1
            rows.setdefault(k, []).append((b - a + 1) / 2.0)
        low = [y for x in (ax - 1, ax, ax + 1) for y in range(h) if bark(x, y)]
        if low:
            fronts.append(max(low) + 1 - ay)
    # A row's narrowest turn is the round foot without the roots that turn round it.
    width = statistics.median(min(r) for r in rows.values()) if rows else 1.0
    front = max(0.0, statistics.median(fronts)) if fronts else 0.0
    return width, front


def taper_of(alpha, x0, y0, w, h, ax, ay):
    """[height, half width] of a tree's trunk where the crown hides it (pixels; see the module's doc), None when no
    turn shows its bark going up through the axis."""
    heights = []
    widths = []
    for turn in range(8):
        left = x0 + turn * w

        def bark(x, y):
            return 0 <= x < w and 0 <= y < h and alpha[left + x, y0 + y] in BARK

        def axis(k):
            return any(bark(x, ay - k) for x in (ax - 1, ax, ax + 1))

        k = 2
        while k < ay and axis(k):
            k += 1
        if k < 6:
            continue
        runs = []
        for r in range(max(2, k - TAPER_ROWS), k):
            y = ay - r
            x = next(x for x in (ax, ax - 1, ax + 1) if bark(x, y))
            a = b = x
            while bark(a - 1, y):
                a -= 1
            while bark(b + 1, y):
                b += 1
            runs.append(b - a + 1)
        heights.append(k)
        widths.append(statistics.median(runs) / 2.0)
    if not heights:
        return None
    return [statistics.median(heights), statistics.median(widths)]


def cut_of(alpha, x0, y0, w, h, ax, ay):
    """The ring of a stump's picture: [half width, half depth, across] of its cut and the cut's height (pixels),
    None when no turn draws cut wood."""
    boxes = []
    for turn in range(8):
        left = x0 + turn * w
        cells = [(x, y) for y in range(h) for x in range(w) if alpha[left + x, y0 + y] in CUT]
        if not cells:
            continue
        xs = [x for x, _ in cells]
        ys = [y for _, y in cells]
        boxes.append((min(xs), max(xs) + 1, min(ys), max(ys) + 1))
    if not boxes:
        return None
    width = statistics.median(b[1] - b[0] for b in boxes)
    depth = statistics.median(b[3] - b[2] for b in boxes)
    # The middle of the cut from the middle of the anchor texel (the axis): to the right, and up the picture.
    across = statistics.median((b[0] + b[1]) / 2.0 for b in boxes) - (ax + 0.5)
    up = (ay + 0.5) - statistics.median((b[2] + b[3]) / 2.0 for b in boxes)
    return [width / 2.0, depth / 2.0, across], max(MIN_TOP, up - depth / 2.0)


def num(v):
    return "%g" % (math.floor(v * 2.0 + 0.5) / 2.0)


def main():
    check = "--check" in sys.argv
    bad = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "content", "*", "*", "tree", "look.yaml"))):
        folder = os.path.dirname(path)
        alpha = Image.open(os.path.join(folder, "frames.png")).getchannel("A").load()
        lines = open(path, encoding="utf-8").read().split("\n")
        stump_file = next((ln.split(":", 1)[1].strip() for ln in lines if ln.startswith("stump_frames:")), "")
        stumps = Image.open(os.path.join(folder, stump_file)).getchannel("A").load() if stump_file else None
        out = []
        section = ""
        for line in lines:
            if line and not line.startswith(" "):
                section = line.split(":", 1)[0]
            m = LOOK.match(line)
            if m and section == "looks":
                x0, y0, w, h, ax, ay = (int(m.group(i)) for i in range(2, 8))
                width, front = measure(alpha, x0, y0, w, h, ax, ay)
                taper = taper_of(alpha, x0, y0, w, h, ax, ay)
                taper_text = ", taper: [%s]" % ", ".join(num(v) for v in taper) if taper else ""
                line = "%s, foot: [%g, %g]%s%s" % (m.group(1), width, front, taper_text, WRITTEN.sub("", m.group(8)))
            elif m and section == "stumps" and stumps is not None:
                x0, y0, w, h, ax, ay = (int(m.group(i)) for i in range(2, 8))
                found = cut_of(stumps, x0, y0, w, h, ax, ay)
                rest = WRITTEN.sub("", m.group(8))
                if found is None:
                    line = m.group(1) + rest
                else:
                    ring, top = found
                    line = "%s, top: %s, cut: [%s]%s" % (m.group(1), num(top), ", ".join(num(v) for v in ring), rest)
            out.append(line)
        if out != lines:
            bad += 1
            if check:
                print("%s: `foot`, `cut` or `top` missing or out of date (python3 tools/tree_feet.py)"
                      % os.path.relpath(path, ROOT))
            else:
                open(path, "w", encoding="utf-8").write("\n".join(out))
                print("wrote", os.path.relpath(path, ROOT))
    if check and bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
