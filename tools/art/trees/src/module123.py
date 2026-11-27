# Leaf modules in the three styles of reference 123 (dots, blades, round), built the way module5.py
# builds the approved modules of reference 122: a dark disc, then the leaves; layout 0 is the
# reference's own module (pixel-exact, from leaves123.json); layouts 1, 5, 17 put the reference's
# places turned as a whole (a quarter, half, three-quarter turn) and give each place ANOTHER leaf
# turned about the middle to cover it best, then mend holes; 8 modules = 4 layouts x mirror.
# Drawing order of a new layout = the order of its places in the reference (each place keeps how
# deep it lies there: in the round style the inner leaves lie over the outer ones, in the blades a
# pinwheel, each blade over the next).
# Tones as in module5 (relative to the module's base step): body 0, outline and vein -1; a leaf facing
# the light +1, across 0, away -1; on a lit leaf facing the light the heart pixels (H, where the
# reference puts its brightest pixels) +1 more. Dots have no hearts, and a dot near the middle counts
# as across (a dot has no way of its own: its way is where it lies).
import json, math, os, random
import numpy as np
import module5 as M5
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = json.load(open(os.path.join(HERE, 'leaves123.json')))
OUT, BODY, VEIN, HEART = 0, 1, 2, 3
ROLE = {'O': OUT, 'B': BODY, 'V': VEIN, 'H': HEART}
S, C = M5.S, M5.C
TOP_R = {'dots': 0.0, 'blades': 4.0, 'round': 3.0}
TURNS = M5.TURNS
LAYOUTS = (0, 1, 5, 17)
STYLES = ('dots', 'blades', 'round')


def _turn(px, t):
    return M5._turn(px, t)


def _centre(px):
    return M5._centre(px)


class Style:
    def __init__(self, name):
        d = DATA[name]
        self.name = name
        self.leaves = d['leaves']
        self.ref_leaf = np.array(d['ref_leaf'])
        self.ref_role = d['ref_role']
        self._lay = {}

    def pixels(self, j):
        L = self.leaves[j]
        return [(L['x'] + i, L['y'] + r, ch) for r, row in enumerate(L['rows']) for i, ch in enumerate(row) if ch != '.']

    def layout(self, seed):
        """Which leaf, turned how, lies in each place (module5.layout with this style's leaves)."""
        if seed in self._lay: return self._lay[seed]
        n = len(self.leaves)
        if seed == 0:
            res = [(j, (0, 0)) for j in range(n)]
            self._lay[seed] = res; return res
        rng = random.Random(seed)
        T0 = TURNS[(seed - 1) % 7 + 1]
        allt = [(q, m) for q in range(4) for m in (0, 1)]
        pts = {(j, t): set((x, y) for x, y, _ in _turn(self.pixels(j), t)) for j in range(n) for t in allt}
        targets = [pts[(s, T0)] for s in range(n)]
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
        yy, xx = np.mgrid[0:S, 0:S]
        dsk = set(zip(*np.nonzero(((xx - C[0]) ** 2 + (yy - C[1] + 0.5) ** 2 < 8.6 ** 2).T)))
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

    def module(self, seed=0, flip=False):
        leaf = -np.ones((S, S), int); role = np.zeros((S, S), int)
        if seed == 0:
            leaf[:] = self.ref_leaf
            for y, row in enumerate(self.ref_role):
                for x, ch in enumerate(row):
                    if ch != '.': role[y, x] = ROLE[ch]
            cents = [_centre(self.pixels(j)) for j in range(len(self.leaves))]
        else:
            placed = [_turn(self.pixels(j), t) for j, t in self.layout(seed)]
            for s, px in enumerate(placed):
                for x, y, ch in px:
                    if 0 <= x < S and 0 <= y < S:
                        leaf[y, x] = s; role[y, x] = ROLE[ch]
            cents = [_centre(px) for px in placed]
        n = len(cents)
        ang = np.array([math.atan2(cy - C[1], cx - C[0]) for cx, cy in cents])
        rad = np.array([math.hypot(cy - C[1], cx - C[0]) for cx, cy in cents])
        top = rad < TOP_R[self.name]
        dsk = M5.disc(False)
        m = dict(leaf=leaf, role=role, ang=ang, rad=rad, top=top, flip=flip, style=self.name, disc=dsk,
                 depth=np.zeros((S, S), int))
        if flip:
            for k in ('leaf', 'role', 'disc'): m[k] = m[k][:, ::-1].copy()
            m['ang'] = math.pi - ang
        return m


def facing(m, k, light2):
    """How leaf k faces the light: -1..1 (module5's rule; dots by where they lie)."""
    a = m['ang'][k]
    f = math.cos(a) * light2[0] + math.sin(a) * light2[1]
    if m['style'] == 'dots':
        f *= min(1.0, m['rad'][k] / 4.0)
    elif m['top'][k]:
        f = max(f, 0.5)
    return f


def tones(m, light2, flat=False):
    out = np.full((S, S), -9, int)
    nl = len(m['ang'])
    fs = [facing(m, k, light2) for k in range(nl)]
    for y in range(S):
        for x in range(S):
            k = m['leaf'][y, x]
            if k < 0: continue
            r = m['role'][y, x]
            t = 0 if r in (BODY, HEART) else -1
            if not flat:
                f = fs[k]
                s = 1 if f > 0.2 else (0 if f > -0.5 else -1)
                t += s
                if s == 1 and r == HEART and f > 0.45: t += 1
            out[y, x] = t
    return out


_CACHE = {}
def modules(style):
    """The 8 modules of a style: layouts 0, 1, 5, 17, then the same mirrored (as render7.MODS)."""
    if style not in _CACHE:
        st = Style(style)
        _CACHE[style] = [st.module(s, flip=f) for f in (False, True) for s in LAYOUTS]
    return _CACHE[style]
