# Round 20: maple leaves after the user's reference (user-maple-autumn.jpg, left half, bottom row: red-orange
# trees with five-pointed leaves). The reference has no modules, so the leaf brushes are drawn after its
# leaves (letter grids: O outline, B body, H the lit star of veins, V stem) and a module is laid the way the
# approved modules are: a dark disc, an outer ring of leaves pointing outwards (bottom first), then leaves on
# top near the middle. The result goes into module123's DATA as the style 'maple', so module123 / tree123
# build its 8 modules (layout 0 + three turned layouts, mirrored) and tones the same way as the others.
import math, random
import numpy as np
import module123 as MM, module5 as M5, tree123 as TT

S, C = M5.S, M5.C
BRUSHES = [
 [ # 0: big, upright: «П2», the classic maple (user's pick 2026-11-24)
'.....OO....',
'.OO.OHHO.OO',
'.OHOOHBOOHO',
'.OBHOHBOHBO',
'..OBHHHHBO.',
'OOBBBHHBBBO',
'OHHHHHHHHHO',
'.OOBBHBBBOO',
'..OOOVOOO..',
'.....V.....',
 ],
 [ # 1: big, tilted (top lobe up and to the right): approved as drawn (2026-11-24)
'......OO...',
'..O..OHO...',
'..OOOBHO.OO',
'..OHOHBOOHO',
'.OBBHHHHHO.',
'OHHHHHHBOO.',
'.OOBHHHHHBO',
'..OHBHHBOO.',
'..OOVOOBO..',
'.OV...OO...',
 ],
 [ # 2: small: «М1», the tilted one made smaller (one row and two columns dropped; user's pick 2026-11-24)
'.....O...',
'..O.OO...',
'..OOBO.OO',
'..OOHOOHO',
'.OBHHHHO.',
'.OOHHHHBO',
'..OBHBOO.',
'..OVOBO..',
'.OV..O...',
 ],
]
TIP_ANGLE = [90.0, 60.0, 60.0]      # where the top lobe points (deg, y up)


def _brush_px(b, cx, cy):
    g = BRUSHES[b]; h = len(g); w = len(g[0])
    x0 = int(round(cx - (w - 1) / 2)); y0 = int(round(cy - (h - 1) / 2))
    return [(x0 + i, y0 + r, ch) for r, row in enumerate(g) for i, ch in enumerate(row) if ch != '.']


def _orient(b, t):
    """The direction (deg) the top lobe of brush b points after turn t=(q, mirror) of module5._turn."""
    a = math.radians(TIP_ANGLE[b]); dx, dy = math.cos(a), -math.sin(a)      # screen y down
    q, mir = t
    if mir: dx = -dx
    for _ in range(q): dx, dy = -dy, dx
    return math.degrees(math.atan2(-dy, dx)) % 360


def _rows(px):
    xs = [p[0] for p in px]; ys = [p[1] for p in px]
    x0, y0 = min(xs), min(ys)
    g = [['.'] * (max(xs) - x0 + 1) for _ in range(max(ys) - y0 + 1)]
    for x, y, ch in px: g[y - y0][x - x0] = ch
    return x0, y0, [''.join(r) for r in g]


def build(seed=3, ring=7.0, n_ring=6, inner=((0, 0.5, 0),), small=(2, 4)):
    rng = random.Random(seed)
    allt = [(q, m) for q in range(4) for m in (0, 1)]
    leaves = []
    # outer ring: bottom first (larger screen y drawn first), each pointing outwards (+ jitter)
    places = []
    for i in range(n_ring):          # i = 0 top, then counter-clockwise; the `small` ones get the small brush
        a = 90 + 360 * i / n_ring + rng.uniform(-12, 12)
        r = ring - (1.0 if i in small else 0.0)
        places.append((a, C[0] + r * math.cos(math.radians(a)), C[1] + 0.5 - r * 0.92 * math.sin(math.radians(a)), i in small))
    places.sort(key=lambda p: -p[2])
    for a, cx, cy, sm in places:
        off = (a - 90 + 180) % 360 - 180            # leaves lean outwards but stay stem-down
        want = 90 + max(-75, min(75, off * 0.8))
        best = None
        for b in ((2,) if sm else (0, 1)):
            for t in allt:
                d = abs((_orient(b, t) - want + 180) % 360 - 180) + rng.uniform(0, 8)
                if best is None or d < best[0]: best = (d, b, t)
        _, b, t = best
        # place the turned brush with its middle on the place
        px = M5._turn(_brush_px(b, C[0], C[1]), t)
        mx, my = M5._centre(px)
        px = [(int(round(x + cx - mx)), int(round(y + cy - my)), ch) for x, y, ch in px]
        x0, y0, rows = _rows(px)
        leaves.append(dict(brush=b, turn=list(t), x=x0, y=y0, rows=rows))
    # leaves on top near the middle: upright or a little turned, small ones beside
    for dx, dy, b in inner:
        t = rng.choice([(0, 0), (0, 1)])
        px = M5._turn(_brush_px(b, C[0], C[1]), t)
        mx, my = M5._centre(px)
        px = [(int(round(x + C[0] + dx - mx)), int(round(y + C[1] + dy - my)), ch) for x, y, ch in px]
        x0, y0, rows = _rows(px)
        leaves.append(dict(brush=b, turn=list(t), x=x0, y=y0, rows=rows))
    leaf = -np.ones((S, S), int); role = [['.'] * S for _ in range(S)]
    for j, L in enumerate(leaves):
        for r, row in enumerate(L['rows']):
            for i, ch in enumerate(row):
                x, y = L['x'] + i, L['y'] + r
                if ch != '.' and 0 <= x < S and 0 <= y < S:
                    leaf[y, x] = j; role[y][x] = ch
    return dict(brushes=BRUSHES, leaves=leaves, ref_leaf=leaf.tolist(), ref_role=[''.join(r) for r in role])


ROLE_V = 'V'
MM.ROLE.setdefault('V', MM.VEIN)
MM.TOP_R['maple'] = 3.0


def install(**kw):
    MM.DATA['maple'] = build(**kw)
    MM._CACHE.pop('maple', None)
    m = MM.Style('maple').module(0)
    ys, xs = np.nonzero(m['leaf'] >= 0)
    rms = float(np.sqrt(((xs - C[0]) ** 2 + (ys - C[1]) ** 2).mean()))
    TT.RATIO['maple'] = rms / 8.72
    return rms

install()

# The reference outlines its leaves in its darkest reds whatever the light: maple outlines (not stems) go
# lower than the other styles' (-1): -3 was shown first; the user compared -3 .. -1 and picked -1.5 (2026-11-24;
# a half step = the mean of two ramp colours, as the trees already draw half steps).
_tones = MM.tones
def tones(m, light2, flat=False):
    t = _tones(m, light2, flat)
    if m.get('style') == 'maple':
        t = np.where((t > -9) & (m['role'] == MM.OUT), t - OUT_EXTRA, t)
    return t
OUT_EXTRA = 0.5
MM.tones = tones


# The turned layouts (B, C, D) may give a place any of 8 turns of a leaf; an upside-down maple leaf reads as a
# bell, so maple leaves keep to upright and sideways turns (no half turn).
KEEP_Q = (0, 1, 3)
from module123 import TURNS, _turn, S as _S, C as _C
import random
def _layout_maple(self, seed):
    """Which leaf, turned how, lies in each place (module5.layout with this style's leaves)."""
    if seed in self._lay: return self._lay[seed]
    n = len(self.leaves)
    if seed == 0:
        res = [(j, (0, 0)) for j in range(n)]
        self._lay[seed] = res; return res
    rng = random.Random(seed)
    T0 = TURNS[(seed - 1) % 7 + 1]
    allt = [(q, m) for q in KEEP_Q for m in (0, 1)]
    pts = {(j, t): set((x, y) for x, y, _ in _turn(self.pixels(j), t)) for j in range(n) for t in allt}
    targets = [set((x, y) for x, y, _ in _turn(self.pixels(s), T0)) for s in range(n)]
    scores = []
    for s, tg in enumerate(targets):
        for (j, t), p in pts.items():
            if j == s and t == T0: continue
            iou = len(tg & p) / len(tg | p)
            if iou > 0: scores.append((iou + rng.uniform(0, 0.08), s, j, t))
    scores.sort(reverse=True)
    res = [None] * n; used = set()
    for sc, s, j, t in scores:
        if res[s] is None and j not in used:
            res[s] = (j, t); used.add(j)
    left = [j for j in range(n) if j not in used]
    for s in range(n):
        if res[s] is None: res[s] = (left.pop(), T0)
    want = set().union(*targets)
    yy, xx = np.mgrid[0:_S, 0:_S]
    dsk = set(zip(*np.nonzero(((xx - _C[0]) ** 2 + (yy - _C[1] + 0.5) ** 2 < 8.6 ** 2).T)))
    def cost(r):
        cov = set().union(*(pts[a] for a in r))
        return len(dsk - cov) + 0.4 * len(cov - want) + 0.4 * len(want - cov)
    cur = cost(res)
    for it in range(2500):
        r = list(res)
        if rng.random() < 0.5:
            a, b = rng.sample(range(n), 2)
            r[a], r[b] = (r[b][0], rng.choice(allt)), (r[a][0], rng.choice(allt))
        else:
            a = rng.randrange(n); r[a] = (r[a][0], rng.choice(allt))
        if any(r[k] == (k, T0) for k in range(n)): continue
        c = cost(r)
        if c <= cur:
            res, cur = r, c
    self._lay[seed] = res
    return res


_orig_layout = MM.Style.layout
def _layout(self, seed):
    return _layout_maple(self, seed) if self.name == 'maple' else _orig_layout(self, seed)
MM.Style.layout = _layout
install()


def use(big=None, small=None, small_tip=None):
    """Swap the upright big brush and/or the small one (round 20 step 1b variants) and rebuild the style."""
    if big is not None: BRUSHES[0] = list(big)
    if small is not None: BRUSHES[2] = list(small)
    if small_tip is not None: TIP_ANGLE[2] = small_tip
    return install()
