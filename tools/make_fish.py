"""Draws the fish's sheets: content/animals/perch/sprites/creatures/perch.png and the
fish of the bundle «Рыба», content/animals/fish/sprites/creatures/<fish>.png.

The fish of the old kit (make_creatures.py) in the sparrow's style (2026-11-07): a dark
outline in the fish's own darkest hue round it, a darker back, a light stripe under it,
a pale belly. Each fish is a body w x h pixels (tail and all) on a canvas a pixel
larger every way.

Rows (creatures.yaml `views: 5`): the side (E, facing right), head on (S), from behind
(N), the front three-quarter (SE) and the back three-quarter (NE), foreshortened; the
game mirrors them for the other three ways. Columns (`frames: 6`, `walk: 4`): still,
four of the tail beating, one of the fins stirring.

    python3 tools/make_fish.py [perch roach ...]
"""
import os
import sys

from PIL import Image


def hexc(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


class Fish:
    def __init__(self, name, w, h, body, back, belly, fin, bars=(), spots=(), spot="#000000",
                 whiskers=False, long_jaw=False):
        self.name, self.w, self.h = name, w, h
        self.W, self.H = w + 2, h + 2
        body, back, belly, fin = hexc(body), hexc(back), hexc(belly), hexc(fin)
        self.pal = {
            "b": back, "o": body, "h": mix(body, (255, 255, 255), 0.22), "l": belly, "t": fin,
            "f": mix(fin, (0, 0, 0), 0.25), "e": (16, 14, 12), "s": hexc(spot), "k": mix(back, (0, 0, 0), 0.4),
            "O": mix(back, (0, 0, 0), 0.62),
        }
        self.bars, self.spots, self.whiskers, self.long_jaw = bars, spots, whiskers, long_jaw

    # -- shapes -----------------------------------------------------------------------
    def body(self, x0, x1, top, bottom, back_rows=1):
        px = {}
        cx, rx = (x0 + x1 + 1) / 2, (x1 - x0 + 1) / 2
        cy, ry = (top + bottom + 1) / 2, (bottom - top + 1) / 2
        inside = lambda x, y: ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0
        for x in range(x0, x1 + 1):
            col = [y for y in range(top, bottom + 1) if inside(x, y)]
            for i, y in enumerate(col):
                if i < back_rows:
                    ch = "b"
                elif i == back_rows and len(col) > 3:
                    ch = "h"
                elif i == len(col) - 1 or (i == len(col) - 2 and len(col) > 4):
                    ch = "l"
                else:
                    ch = "o"
                px[(x, y)] = ch
        return px

    def side(self, tail_dy=0, fin_dx=0, scale=1.0, away=False):
        w, h = self.w, self.h
        top, bottom = 2, h - 1
        length = max(5, round((w - 2) * scale))
        x1 = self.W - 2
        x0 = x1 - length + 1
        px = self.body(x0, x1, top, bottom, back_rows=2 if away else 1)
        if scale == 1.0:
            for x in self.bars:
                for y in range(top + 1, bottom):
                    if px.get((x + 1, y)) in ("o", "h", "l"):
                        px[(x + 1, y)] = "b"
            for x, y in self.spots:
                if (x + 1, y + 1) in px:
                    px[(x + 1, y + 1)] = "s"
        mid = (x0 + x1) // 2
        for x in range(mid - 1, mid + 2):
            px[(x, top - 1)] = "t"
        if not away:
            px[(mid + fin_dx, bottom + 1)] = "t"
        my = (top + bottom + 1) // 2
        for y in range(my - 1, my + 2):
            px[(x0 - 1, y + tail_dy)] = "t"
        px[(x0 - 2, my - 1 + tail_dy)] = px[(x0 - 2, my + 1 + tail_dy)] = "t"
        if not away:
            px[(x1 - 1, top + 1)] = "e"
            if self.long_jaw:
                px[(x1 + 1, top + 2)] = "k"
            if self.whiskers:
                px[(x1 - 1, bottom + 1)] = "k"
        else:
            px[(x1 - 1, top + 1)] = "e"
        return px

    def head_on(self, back=False, fin_dy=0, tail_dx=0):
        h = self.h
        fw = 5 if h <= 6 else 6
        x0 = (self.W - fw) // 2
        top, bottom = 2, h - 1
        px = {}
        for y in range(top, bottom + 1):
            cut = 1 if y in (top, bottom) else 0
            for x in range(x0 + cut, x0 + fw - cut):
                if back or y == top:
                    ch = "b"
                elif y == top + 1:
                    ch = "h"
                elif y >= bottom - 1:
                    ch = "l"
                else:
                    ch = "o"
                px[(x, y)] = ch
        if back:
            for (x, y), ch in list(px.items()):
                if y > top and x not in (x0, x0 + fw - 1):
                    px[(x, y)] = "o" if y < bottom else "b"
        c = x0 + fw // 2
        px[(c, top - 1)] = "t"
        if fw % 2 == 0:
            px[(c - 1, top - 1)] = "t"
        if back:
            px[(c + tail_dx, bottom + 1)] = "t"
            if fw % 2 == 0:
                px[(c - 1 + tail_dx, bottom + 1)] = "t"
        else:
            px[(x0, top + 1)] = px[(x0 + fw - 1, top + 1)] = "e"
        fy = bottom - 1 + fin_dy
        px[(x0 - 1, fy)] = px[(x0 + fw, fy)] = "t"
        if self.whiskers and not back:
            px[(x0 + 1, bottom + 1)] = px[(x0 + fw - 2, bottom + 1)] = "k"
        return px

    # -- frames -----------------------------------------------------------------------
    def render(self, px):
        im = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        out = {k: v for k, v in px.items() if 0 <= k[0] < self.W and 0 <= k[1] < self.H}
        for (x, y), ch in out.items():
            im.putpixel((x, y), self.pal[ch] + (255,))
        for x in range(self.W):
            for y in range(self.H):
                if (x, y) in out:
                    continue
                if any((x + dx, y + dy) in out for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    im.putpixel((x, y), self.pal["O"] + (255,))
        return im

    def frames(self, view):
        beat = [0, -1, 0, 1]
        if view == "E":
            return [self.side()] + [self.side(tail_dy=d) for d in beat] + [self.side(fin_dx=1)]
        if view in ("SE", "NE"):
            s, a = 0.62, view == "NE"
            return [self.side(scale=s, away=a)] + [self.side(tail_dy=d, scale=s, away=a) for d in beat] + \
                [self.side(fin_dx=1, scale=s, away=a)]
        back = view == "N"
        sway = [0, -1, 0, 1]
        if back:
            return [self.head_on(True)] + [self.head_on(True, tail_dx=d) for d in sway] + [self.head_on(True, fin_dy=-1)]
        return [self.head_on()] + [self.head_on(fin_dy=d) for d in sway] + [self.head_on(fin_dy=-1)]

    def sheet(self, order=("E", "S", "N", "SE", "NE")):
        rows = [[self.render(p) for p in self.frames(v)] for v in order]
        im = Image.new("RGBA", (self.W * 6, self.H * len(order)), (0, 0, 0, 0))
        for j, r in enumerate(rows):
            for i, f in enumerate(r):
                im.alpha_composite(f, (i * self.W, j * self.H))
        return im


FISH = [
    Fish("perch", 11, 6, "#a4bc84", "#5e7c48", "#e2e8cc", "#e07848", bars=(5, 7)),
    Fish("roach", 10, 6, "#b8c0c8", "#5e6878", "#e8ecee", "#d0583c"),
    Fish("pike", 15, 6, "#7a9a54", "#465e30", "#d0d4a0", "#6a8040",
         spots=[(5, 2), (8, 3), (11, 2), (6, 3)], spot="#c4d48a", long_jaw=True),
    Fish("salmon", 13, 6, "#d08a6c", "#6e7488", "#f0d8c0", "#a06058", spots=[(5, 2), (8, 2)], spot="#3a3a46"),
    Fish("cod", 13, 7, "#a89060", "#6e5c38", "#e4d8b4", "#867048",
         spots=[(5, 2), (7, 3), (9, 2), (6, 4)], spot="#6e5c38", whiskers=True),
    Fish("parrotfish", 11, 7, "#4cc4a8", "#2a8a78", "#c4f6e4", "#e878aa", bars=(5,)),
    Fish("catfish", 16, 6, "#5a5650", "#33302c", "#9a9a9c", "#46423e", whiskers=True),
]

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals")


def main():
    only = sys.argv[1:]
    for f in FISH:
        if only and f.name not in only:
            continue
        bundle = "perch" if f.name == "perch" else "fish"
        path = os.path.join(ROOT, bundle, "sprites", "creatures", "%s.png" % f.name)
        f.sheet().save(path)
        print(path, f.W, f.H)


if __name__ == "__main__":
    main()
