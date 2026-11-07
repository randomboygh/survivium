"""The kit tools/make_creatures.py draws the animals with: pictures written as text (a
character a pixel, each character a colour region and a body part), shaded by their shape
and outlined in the darkest tone of their own colour, put together into frames by moving
the parts (a walk, a tail flicked, the head bent to the grass) and into a sheet of rows
(the side, the front, the back) of such frames.

A region's colours are a ramp of five tones made from one base colour (`ramp`): the
outline, the shadow, the base, the light and the highlight, the shadows leaning to violet
and the lights to yellow as hand-shaded pixel art does. A pixel left to the shape is lit
from above: the top rim light, the corner it turns at the highlight, the low part and
the far side in shadow.
"""
import colorsys

from PIL import Image

EMPTY = ". "
OUTLINE, DARK, MID, LIGHT, HIGH = range(5)


def rgba(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _lean(h, target, most):
    d = (target - h + 0.5) % 1.0 - 0.5
    return max(-most, min(most, d))


def ramp(base, outline=None):
    """The five tones of colour `base` ("#rrggbb"); `outline` overrides the darkest."""
    r, g, b = [v / 255.0 for v in rgba(base)[:3]]
    h, l, s = colorsys.rgb_to_hls(r, g, b)

    def tone(dl, dh, ds):
        rr, gg, bb = colorsys.hls_to_rgb((h + dh) % 1.0, min(max(l + dl, 0.0), 1.0), min(max(s + ds, 0.0), 1.0))
        return (round(rr * 255), round(gg * 255), round(bb * 255), 255)

    shade = _lean(h, 0.72, 0.035) if s > 0.08 else 0.0
    light = _lean(h, 0.14, 0.025) if s > 0.08 else 0.0
    tones = [tone(-l * 0.66, shade, -0.08), tone(-l * 0.24, shade * 0.6, 0.0), tone(0, 0, 0),
             tone((1 - l) * 0.18, light, 0.0), tone((1 - l) * 0.38, light * 1.5, -0.04)]
    if outline is not None:
        tones[OUTLINE] = rgba(outline)
    return tones


def flat(colour):
    """One colour for every tone (an eye, a nose)."""
    return [rgba(colour)] * 5


class Frame:
    """The pixels of one frame, (x, y) -> [ramp, tone or None (shaded by the shape)],
    with a free pixel left round it (but under the feet) for the outline."""

    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.px = {}

    def put(self, x, y, rp, tone=None):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = [rp, tone]

    def stamp(self, art, legend, ox, oy, moves, order):
        """Draws `art` (rows of characters) at (ox, oy); each character's legend entry is
        (ramp, group, tone); each group moved by moves[group] and drawn in `order`."""
        # One newline after the opening quotes is not a row; the rest are (empty rows put
        # a part lower in the frame).
        rows = (art[1:] if art.startswith("\n") else art).rstrip("\n").split("\n")
        for group in order:
            dx, dy = moves.get(group, (0, 0))
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    if ch in EMPTY:
                        continue
                    rp, g, tone = legend[ch]
                    if g == group:
                        self.put(ox + x + dx, oy + y + dy, rp, tone)

    def line(self, x0, y0, x1, y1, rp, tone=None):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), rp, tone)

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), (rp, tone) in self.px.items():
            im.putpixel((x, y), rp[self._shade(x, y, rp) if tone is None else tone])
        for x in range(self.w):
            for y in range(self.h):
                if (x, y) in self.px:
                    continue
                best = None
                for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    n = self.px.get((x + dx, y + dy))
                    # The darkest neighbour's outline (the fur's, not an eye's).
                    if n is not None and (best is None or sum(n[0][OUTLINE][:3]) < sum(best[:3])):
                        best = n[0][OUTLINE]
                if best is not None:
                    im.putpixel((x, y), best)
        return im

    def _shade(self, x, y, rp):
        px = self.px
        if px.get((x, y - 1)) is None:
            corner = px.get((x - 1, y)) is None or px.get((x - 1, y - 1)) is None and px.get((x + 1, y - 1)) is None
            return HIGH if corner else LIGHT
        if px.get((x, y + 1)) is None:
            return DARK
        top = y
        while px.get((x, top - 1)) is not None and px[(x, top - 1)][0] is rp:
            top -= 1
        bottom = y
        while px.get((x, bottom + 1)) is not None and px[(x, bottom + 1)][0] is rp:
            bottom += 1
        span = bottom - top + 1
        if span >= 3 and y == top:
            return LIGHT
        if span >= 4 and (y - top) / (span - 1) >= 0.7:
            return DARK
        if span >= 3 and px.get((x + 1, y)) is None:
            return DARK
        return MID


# A walk of four frames: (the foot shift of legs A, of legs B, the pair lifted, the body's
# bob). Legs A are the near front and the far hind one, B the other two.
WALK = [(1, -1, None, 0), (0, 0, "A", -1), (-1, 1, None, 0), (0, 0, "B", -1)]


class View:
    """One way an animal is seen: its picture, its legs and how its idle frames move it.

    art      rows of characters, drawn one pixel in from the frame's left and top
    legend   character -> (ramp, group, tone or None)
    legs     [(x, top, pair "A"/"B", near, ramp, foot ramp[, width])] in the art's pixels;
             each is a line down to the ground: its top in the ramp, the rest in the foot's
    idles    [{group: (dx, dy)}] a frame each
    ox       how far right the art is drawn (a front or back view centred in the frame)
    order    groups drawn first to last (a head before the body is behind it)
    straight legs seen from the front or back: they lift, they do not swing
    """

    def __init__(self, art, legend, legs=(), idles=(), ox=0, order=("tail", "body", "head"), straight=False):
        self.art = art
        self.legend = legend
        self.legs = legs
        self.idles = idles
        self.ox = ox
        self.order = order
        self.straight = straight


def walker(view, w, h, walk=WALK):
    """The frames of a view of a walker: standing, the walk, the idles."""
    frames = [_walker_frame(view, w, h, {}, None)]
    for step in walk:
        frames.append(_walker_frame(view, w, h, {}, step))
    for moves in view.idles:
        frames.append(_walker_frame(view, w, h, moves, None))
    return frames


def _walker_frame(view, w, h, moves, step):
    f = Frame(w, h)
    bob = step[3] if step is not None else 0
    all_moves = {g: (dx, dy + bob) for g, (dx, dy) in moves.items()}
    for g in view.order:
        all_moves.setdefault(g, (0, bob))
    ground = h - 1
    for near in (False, True):
        for leg in view.legs:
            x, top, pair, is_near, rp, foot = leg[:6]
            width = leg[6] if len(leg) > 6 else 1
            if is_near != near:
                continue
            dx = 0
            lift = 0
            if step is not None:
                if not view.straight:
                    dx = step[0] if pair == "A" else step[1]
                lift = 1 if step[2] == pair else 0
            tone = MID if is_near else DARK
            for i in range(width):
                x0 = x + i + 1 + view.ox
                f.line(x0, top + 1 + bob, x0 + dx, ground - lift, foot, tone if i == 0 or width == 1 else DARK if is_near else OUTLINE)
                f.put(x0, top + 1 + bob, rp, tone)
                if dx == 0 and lift == 0 and ground - (top + 1 + bob) > 2:
                    f.put(x0, top + 2 + bob, rp, tone)
        if not near:
            f.stamp(view.art, view.legend, 1 + view.ox, 1, all_moves, view.order)
    return f


def poses(view, w, h, moves_list):
    """Frames of a view made by moving its groups: one frame each {group: (dx, dy)} (a
    fish's tail beat, a bird's wings)."""
    out = []
    for moves in moves_list:
        f = Frame(w, h)
        f.stamp(view.art, view.legend, 1 + view.ox, 1, moves, view.order)
        out.append(f)
    return out


def drawn(art, legend, w, h, ox=0, order=("tail", "body", "head", "wing")):
    """One frame from its own picture (a bird's wing beat, drawn whole)."""
    f = Frame(w, h)
    f.stamp(art, legend, 1 + ox, 1, {}, order)
    return f


def sheet(rows):
    """Rows of frames (each a Frame or an image, all of one size) as one picture."""
    rows = [[f.image() if isinstance(f, Frame) else f for f in r] for r in rows]
    w, h = rows[0][0].size
    cols = max(len(r) for r in rows)
    for r in rows:
        assert len(r) == cols, "every row has as many frames"
        for f in r:
            assert f.size == (w, h), "every frame is the same size"
    im = Image.new("RGBA", (w * cols, h * len(rows)), (0, 0, 0, 0))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            im.alpha_composite(f, (i * w, j * h))
    return im


def at_row(n, text):
    """A picture of one row of pixels, `n` rows down from the frame's top."""
    return "\n" * (n + 1) + text


def compose(arts, legend, w, h, ox=0, order=("tail", "body", "head", "wing"), moves=None):
    """One frame from pictures laid one over another: [(art, dx, dy)] (a bird's body and
    the wings of this beat), its groups moved by `moves` {group: (dx, dy)}."""
    f = Frame(w, h)
    for group in order:
        for art, dx, dy in arts:
            f.stamp(art, legend, 1 + ox + dx, 1 + dy, moves or {}, (group,))
    return f


def flyer(legend, w, h, body, fold, feet, wings, ox=0, peck=(1, 2), order=("tail", "body", "head", "wing")):
    """The frames of a view of a bird, each part a picture drawn at the frame's corner:
    sitting (its body, folded wing and feet), the wing beat (the body and each of `wings`,
    feet tucked), pecking (the head moved by `peck`) and ruffling (the wing raised)."""
    sit = [(body, 0, 0), (fold, 0, 0), (feet, 0, 0)]
    frames = [compose(sit, legend, w, h, ox, order)]
    for wing in wings:
        frames.append(compose([(body, 0, 0), (wing, 0, 0)], legend, w, h, ox, order))
    frames.append(compose(sit, legend, w, h, ox, order, {"head": peck}))
    frames.append(compose(sit, legend, w, h, ox, order, {"wing": (0, -1)}))
    return frames
