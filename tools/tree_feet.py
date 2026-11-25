#!/usr/bin/env python3
"""Measures the trunk's foot in the pictures of the trees drawn so (content/*/*/tree/frames.png) and writes it
into each look of their look.yaml as `foot: [half width, front]` in pixels of the pictures: how wide the bark is
just over the ground, either side of the trunk's axis, and how far below the anchor (the ground under the axis)
the foot's lowest bark reaches. The game holds a body's feet off the trunk by these (TreeLooks.reach).

    python3 tools/tree_feet.py          measure every look.yaml and write `foot`
    python3 tools/tree_feet.py --check  exit 1 when a look.yaml's `foot` is missing or differs

Run it after the pictures are packed again (survivium-builds/trees-redraw/integration/*/src/pack_*.py).
The bark is a frame pixel of alpha 2 (tree.gdshader). The width is the bark run through the axis 4..12 rows over the anchor, in
each row the narrowest of the 8 turns (the round foot without the roots that turn round it), the median of the
rows; the front the median over the turns of the lowest bark row in the axis' three columns.
"""
import glob
import os
import re
import statistics
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOOK = re.compile(r"^(\s*- \{size: [^}]*?\bx: (\d+), y: (\d+), w: (\d+), h: (\d+), ax: (\d+), ay: (\d+),)( foot: \[[^\]]*\],)?(.*)$")


def measure(alpha, x0, y0, w, h, ax, ay):
    rows = {}
    fronts = []
    for turn in range(8):
        left = x0 + turn * w

        def bark(x, y):
            return 0 <= x < w and 0 <= y < h and alpha[left + x, y0 + y] == 2

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


def main():
    check = "--check" in sys.argv
    bad = 0
    for path in sorted(glob.glob(os.path.join(ROOT, "content", "*", "*", "tree", "look.yaml"))):
        alpha = Image.open(os.path.join(os.path.dirname(path), "frames.png")).getchannel("A").load()
        lines = open(path, encoding="utf-8").read().split("\n")
        out = []
        for line in lines:
            m = LOOK.match(line)
            if m:
                x0, y0, w, h, ax, ay = (int(m.group(i)) for i in range(2, 8))
                width, front = measure(alpha, x0, y0, w, h, ax, ay)
                line = "%s foot: [%g, %g],%s" % (m.group(1), width, front, m.group(9))
            out.append(line)
        if out != lines:
            bad += 1
            if check:
                print("%s: `foot` missing or out of date (python3 tools/tree_feet.py)" % os.path.relpath(path, ROOT))
            else:
                open(path, "w", encoding="utf-8").write("\n".join(out))
                print("wrote", os.path.relpath(path, ROOT))
    if check and bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
