#!/usr/bin/env python3
"""Draws the animals' pictures (all but the sparrow): content/animals/<bundle>/sprites/creatures/<sprite>.png, a row
of frames (the first standing, the next two a walk, or a flyer's wings up and down), the animal
facing right, with a dark outline round it like the player's. Each animal is a few filled
shapes on a pixel canvas, so the sheets are easy to change here and remake:
    python3 tools/make_creatures.py [name ...]
A sheet painted over by hand is overwritten by its name, so leave such a name out.
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content", "animals")
OUTLINE = (28, 22, 24, 255)
EYE = (236, 212, 72, 255)
DARK_EYE = (20, 16, 18, 255)


class Canvas:
    """A frame's pixels: (x, y) -> colour, y down, drawn within width x height."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.px = {}

    def dot(self, x, y, c):
        if 0 <= x < self.width and 0 <= y < self.height:
            self.px[(x, y)] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.dot(x, y, c)

    def ellipse(self, x0, y0, x1, y1, c):
        """A filled ellipse inside the box (inclusive corners)."""
        cx = (x0 + x1) / 2.0
        cy = (y0 + y1) / 2.0
        rx = (x1 - x0 + 1) / 2.0
        ry = (y1 - y0 + 1) / 2.0
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.dot(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.dot(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def outline(self):
        """Grows a dark outline round everything drawn (4-neighbours)."""
        edge = set()
        for (x, y) in self.px:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in self.px:
                    edge.add(p)
        for p in edge:
            self.dot(p[0], p[1], OUTLINE)

    def image(self):
        im = Image.new("RGBA", (self.width, self.height), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


def legs(c, f, pairs, colour, top, bottom, hoof=None, swing=1):
    """Four legs as 1-px columns: `pairs` = [(front_x, back_x)], frames 1 and 2 swing the
    front pair and the hind pair the opposite way."""
    for i, (fx, bx) in enumerate(pairs):
        for j, x in enumerate((fx, bx)):
            dx = 0
            if f == 1:
                dx = swing if (i + j) % 2 == 0 else -swing
            elif f == 2:
                dx = -swing if (i + j) % 2 == 0 else swing
            c.line(x, top, x + dx, bottom, colour)
            if hoof is not None:
                c.dot(x + dx, bottom, hoof)


# --- The animals, each a function of the frame ------------------------------------

def fox(f):
    o = (214, 112, 40, 255)
    w = (240, 230, 214, 255)
    k = (62, 40, 34, 255)
    c = Canvas(19, 13)
    # Tail: a long brush back, white at its tip.
    c.ellipse(0, 4, 7, 8, o)
    c.ellipse(0, 4, 2, 7, w)
    # Body and head.
    c.ellipse(5, 3, 15, 9, o)
    c.ellipse(11, 1, 17, 6, o)
    c.rect(15, 4, 18, 5, o)
    c.dot(18, 5, k)
    # Ears, chest, eye.
    c.line(12, 0, 12, 1, o)
    c.line(15, 0, 15, 1, o)
    c.ellipse(11, 5, 15, 8, w)
    c.dot(15, 3, DARK_EYE)
    legs(c, f, [(14, 12), (7, 5)], k if f else k, 9, 11)
    return c


def boar(f):
    b = (92, 72, 58, 255)
    d = (64, 48, 40, 255)
    t = (228, 220, 200, 255)
    c = Canvas(21, 14)
    c.ellipse(2, 2, 16, 11, b)
    c.rect(4, 2, 13, 4, d)  # bristles on the back
    c.ellipse(13, 4, 20, 10, b)
    c.rect(18, 7, 20, 9, d)  # snout
    c.dot(20, 8, (190, 120, 110, 255))
    c.dot(18, 10, t)  # tusk
    c.dot(16, 5, DARK_EYE)
    c.line(14, 3, 15, 2, d)  # ear
    c.line(1, 4, 0, 6, d)  # tail
    legs(c, f, [(16, 13), (6, 3)], d, 11, 13)
    return c


def bear(f):
    b = (104, 74, 52, 255)
    d = (72, 50, 36, 255)
    m = (150, 118, 86, 255)
    c = Canvas(24, 18)
    c.ellipse(1, 3, 18, 14, b)
    c.ellipse(4, 1, 15, 8, b)  # hump
    c.ellipse(14, 4, 23, 12, b)  # head
    c.rect(20, 8, 23, 10, m)  # muzzle
    c.dot(23, 9, d)
    c.dot(19, 7, DARK_EYE)
    c.ellipse(15, 2, 17, 4, b)  # ears
    c.ellipse(20, 2, 22, 4, b)
    c.ellipse(5, 9, 15, 14, d)  # belly shade
    legs(c, f, [(19, 16), (6, 3)], d, 14, 17, swing=1)
    c.rect(2, 16, 7, 17, d)  # paws, broad
    c.rect(15, 16, 20, 17, d)
    return c


def hedgehog(f):
    q = (96, 82, 72, 255)
    s = (168, 150, 126, 255)
    b = (190, 160, 130, 255)
    c = Canvas(12, 8)
    c.ellipse(0, 0, 8, 6, q)
    for x in range(1, 8, 2):  # spines
        c.dot(x, 0 if x % 4 == 1 else 1, s)
        c.dot(x + 1, 2, s)
    c.ellipse(6, 3, 11, 6, b)  # face
    c.dot(11, 5, DARK_EYE)  # nose
    c.dot(9, 4, DARK_EYE)
    legs(c, f, [(9, 2)], q, 6, 7)
    return c


def crow(f):
    k = (44, 42, 56, 255)
    g = (78, 76, 98, 255)
    c = Canvas(14, 11)
    if f == 0:
        c.ellipse(2, 4, 10, 9, k)
        c.ellipse(8, 2, 12, 6, k)
        c.line(12, 4, 13, 4, g)  # beak
        c.dot(10, 3, EYE)
        c.line(0, 5, 2, 6, k)  # tail
        c.line(5, 9, 5, 10, g)
        c.line(8, 9, 8, 10, g)
    else:
        c.ellipse(3, 5, 10, 8, k)
        c.ellipse(8, 3, 12, 7, k)
        c.line(12, 5, 13, 5, g)
        c.dot(10, 4, EYE)
        c.line(0, 6, 3, 7, k)
        if f == 1:  # wings up
            c.line(6, 4, 2, 0, k)
            c.line(6, 4, 10, 0, k)
            c.line(5, 4, 1, 1, k)
            c.line(7, 4, 11, 1, k)
        else:  # wings down
            c.line(6, 7, 1, 10, k)
            c.line(6, 7, 11, 10, k)
            c.line(5, 7, 1, 9, k)
            c.line(7, 7, 11, 9, k)
    return c


def owl(f):
    b = (140, 110, 78, 255)
    l = (206, 182, 142, 255)
    d = (96, 72, 50, 255)
    c = Canvas(14, 12)
    body = (3, 2, 10, 10) if f == 0 else (3, 4, 10, 10)
    c.ellipse(*body, b)
    c.rect(5, body[1] + 3, 8, body[3] - 1, l)  # breast
    c.rect(5, body[1] + 1, 9, body[1] + 3, l)  # face disc
    c.dot(5, body[1] + 2, DARK_EYE)
    c.dot(8, body[1] + 2, DARK_EYE)
    c.dot(9, body[1] + 3, d)  # beak
    c.dot(4, body[1] - 1, b)  # ear tufts
    c.dot(9, body[1] - 1, b)
    if f == 0:
        c.line(5, 10, 5, 11, d)
        c.line(8, 10, 8, 11, d)
    elif f == 1:
        c.line(3, 6, 0, 1, b)
        c.line(4, 6, 1, 1, b)
        c.line(10, 6, 13, 1, b)
        c.line(9, 6, 12, 1, b)
    else:
        c.line(3, 7, 0, 11, b)
        c.line(4, 7, 1, 11, b)
        c.line(10, 7, 13, 11, b)
        c.line(9, 7, 12, 11, b)
    return c


def duck(f):
    g = (58, 108, 60, 255)  # green head
    b = (120, 92, 66, 255)
    w = (226, 220, 200, 255)
    y = (228, 180, 60, 255)
    c = Canvas(14, 11)
    top = 4 if f == 0 else 5
    c.ellipse(1, top, 10, top + 5, b)  # body
    c.rect(3, top + 1, 8, top + 2, w)  # wing bar
    c.ellipse(8, 1, 12, 5, g)  # head
    c.rect(9, 4, 10, 5, w)  # neck ring
    c.line(12, 3, 13, 3, y)  # bill
    c.dot(10, 2, DARK_EYE)
    c.line(0, top + 1, 1, top + 1, b)  # tail
    if f == 0:
        c.line(4, top + 6, 4, 10, y)
        c.line(7, top + 6, 7, 10, y)
    elif f == 1:
        c.line(5, top + 1, 2, 0, b)
        c.line(6, top + 1, 3, 0, b)
        c.line(5, top + 1, 8, 0, b)
    else:
        c.line(5, top + 4, 2, 10, b)
        c.line(6, top + 4, 3, 10, b)
        c.line(5, top + 4, 8, 10, b)
    return c


def butterfly(f):
    o = (230, 150, 50, 255)
    d = (160, 70, 40, 255)
    k = (40, 30, 30, 255)
    c = Canvas(9, 7)
    c.rect(4, 1, 4, 5, k)  # body
    c.dot(3, 0, k)
    c.dot(5, 0, k)
    if f == 0:  # wings open flat
        c.ellipse(0, 1, 3, 3, o)
        c.ellipse(5, 1, 8, 3, o)
        c.ellipse(1, 4, 3, 5, d)
        c.ellipse(5, 4, 7, 5, d)
    elif f == 1:  # wings up, seen edge on
        c.rect(3, 1, 3, 3, o)
        c.rect(5, 1, 5, 3, o)
    else:
        c.ellipse(1, 2, 3, 4, o)
        c.ellipse(5, 2, 7, 4, o)
        c.dot(2, 4, d)
        c.dot(6, 4, d)
    return c


def perch(f):
    g = (104, 134, 76, 255)
    d = (66, 90, 50, 255)
    r = (200, 90, 50, 255)
    c = Canvas(14, 8)
    c.ellipse(3, 1, 12, 6, g)
    for x in (5, 7, 9):  # the perch's dark bars
        c.line(x, 2, x, 5, d)
    c.dot(11, 3, DARK_EYE)
    c.line(5, 0, 8, 0, d)  # dorsal fin
    c.dot(8, 7, r)  # belly fin
    tail = {0: [(0, 2, 2, 4)], 1: [(0, 1, 2, 4)], 2: [(0, 3, 2, 5)]}[f]
    for t in tail:
        c.rect(t[0], t[1], t[2], t[3], r)
    c.dot(2, 3, g)
    return c


def frog(f):
    g = (96, 150, 58, 255)
    d = (60, 104, 44, 255)
    c = Canvas(10, 7)
    c.ellipse(1, 2, 8, 6, g)
    c.rect(5, 2, 8, 3, d)  # back stripe
    c.rect(2, 0, 3, 1, g)  # eyes on top, bulging
    c.rect(6, 0, 7, 1, g)
    c.dot(3, 0, EYE)
    c.dot(7, 0, EYE)
    if f == 0:
        c.line(0, 4, 1, 6, d)
        c.line(9, 5, 9, 6, d)
    elif f == 1:  # legs stretched back
        c.line(0, 6, 2, 5, d)
        c.line(8, 6, 9, 6, d)
    else:  # legs tucked
        c.line(1, 6, 2, 6, d)
        c.line(8, 6, 9, 5, d)
    return c


def rabbit(f):
    b = (168, 134, 104, 255)
    l = (214, 190, 160, 255)
    c = Canvas(13, 12)
    c.ellipse(1, 5, 10, 11, b)  # body, hunched
    c.ellipse(7, 3, 12, 8, b)  # head
    c.rect(9, 0, 9, 3, b)  # ears
    c.rect(11, 0, 11, 3, b)
    c.dot(9, 1, l)
    c.dot(11, 1, l)
    c.ellipse(3, 8, 8, 11, l)  # belly
    c.dot(0, 7, l)  # tail
    c.dot(10, 5, DARK_EYE)
    c.dot(12, 6, (200, 130, 130, 255))  # nose
    legs(c, f, [(9, 2)], b, 10, 11)
    c.rect(1, 11, 3, 11, b) if f == 0 else None
    return c


def squirrel(f):
    r = (190, 96, 48, 255)
    l = (230, 200, 160, 255)
    c = Canvas(12, 12)
    # The tail curls up behind.
    c.ellipse(0, 1, 4, 9, r)
    c.ellipse(1, 2, 3, 6, (214, 120, 66, 255))
    c.ellipse(4, 6, 10, 11, r)  # body
    c.ellipse(7, 3, 11, 7, r)  # head
    c.dot(8, 2, r)  # ear tufts
    c.dot(10, 2, r)
    c.rect(6, 8, 8, 10, l)  # belly
    c.dot(10, 4, DARK_EYE)
    legs(c, f, [(9, 5)], r, 10, 11)
    return c


def cat(f):
    g = (124, 122, 132, 255)
    d = (84, 82, 94, 255)
    c = Canvas(16, 11)
    c.ellipse(3, 4, 13, 9, g)  # body
    c.ellipse(10, 1, 15, 6, g)  # head
    c.dot(11, 0, g)  # ears
    c.dot(14, 0, g)
    c.dot(13, 3, EYE)
    c.line(5, 5, 11, 5, d)  # a dark stripe along the back
    c.line(7, 6, 7, 8, d)
    c.line(10, 6, 10, 8, d)
    c.line(0, 2, 3, 5, d)  # tail up
    legs(c, f, [(12, 10), (6, 4)], g, 9, 10)
    return c


def deer(f):
    b = (160, 112, 64, 255)
    l = (214, 186, 140, 255)
    d = (96, 66, 40, 255)
    c = Canvas(17, 19)
    c.ellipse(1, 8, 12, 14, b)  # body
    c.line(11, 7, 13, 3, b)  # neck
    c.line(12, 7, 14, 3, b)
    c.ellipse(12, 2, 16, 5, b)  # head
    c.dot(16, 4, d)  # nose
    c.dot(14, 3, DARK_EYE)
    c.line(13, 1, 12, 0, d)  # antlers
    c.line(13, 1, 14, 0, d)
    c.dot(11, 0, d)
    c.rect(4, 12, 10, 14, l)  # belly
    c.dot(0, 9, l)  # tail
    legs(c, f, [(11, 9), (4, 2)], d, 14, 18, hoof=d)
    return c


def wolf(f):
    g = (120, 118, 122, 255)
    d = (74, 70, 76, 255)
    l = (190, 188, 192, 255)
    c = Canvas(20, 14)
    c.ellipse(2, 4, 15, 11, g)  # body
    c.rect(4, 4, 13, 5, d)  # dark back
    c.ellipse(12, 2, 18, 7, g)  # head
    c.rect(17, 5, 19, 6, g)  # muzzle
    c.dot(19, 6, d)
    c.dot(13, 1, d)  # ears
    c.dot(16, 1, d)
    c.dot(16, 4, EYE)
    c.rect(12, 7, 16, 9, l)  # chest
    c.line(0, 4, 3, 6, d)  # tail
    legs(c, f, [(14, 12), (6, 4)], d, 11, 13)
    return c


SHEETS = {
    "rabbit": rabbit, "squirrel": squirrel, "cat": cat, "deer": deer, "wolf": wolf,
    "fox": fox, "boar": boar, "bear": bear, "hedgehog": hedgehog, "crow": crow, "owl": owl,
    "duck": duck, "butterfly": butterfly, "perch": perch, "frog": frog,
}


def sheet(name):
    frames = [SHEETS[name](f) for f in range(3)]
    for c in frames:
        c.outline()
    w = frames[0].width
    h = frames[0].height
    im = Image.new("RGBA", (w * 3, h), (0, 0, 0, 0))
    for i, c in enumerate(frames):
        im.alpha_composite(c.image(), (i * w, 0))
    return im


def main():
    only = sys.argv[1:]
    for name in SHEETS:
        if only and name not in only:
            continue
        path = os.path.join(ROOT, name, "sprites", "creatures", "%s.png" % name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sheet(name).save(path)
        print(path)


if __name__ == "__main__":
    main()
