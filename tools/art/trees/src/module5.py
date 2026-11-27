# Leaf modules after reference 122. The reference's module is laid as it is drawn there: a dark
# disc, then 14 leaves one by one (leaves.json: the leaves cut out of the reference's drawing
# frames, letter rows O outline, B body, V vein, and where each lies). New layouts put other
# leaves into the same 14 places: a leaf is turned by quarter turns (or mirrored) about the
# module's middle, so it still grows from the middle and points out, and it takes the place whose
# position it then fits best; the places keep the reference's order of drawing.
import json, math, os, random
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
LEAVES = json.load(open(os.path.join(HERE, 'leaves.json')))
OUT, BODY, VEIN = 0, 1, 2
ROLE = {'O': OUT, 'B': BODY, 'V': VEIN}
S = 30                      # the module's box
C = (13, 14)                # the module's middle (x, y)
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))

def _pixels(j):
    L = LEAVES[j]
    return [(L['x'] + i, L['y'] + r, ch) for r, row in enumerate(L['rows']) for i, ch in enumerate(row) if ch != '.']

def _turn(px, t):
    """t = (quarter turns 0..3, mirror 0/1) about the middle."""
    q, mir = t
    out = []
    for x, y, ch in px:
        dx, dy = x - C[0], y - C[1]
        if mir: dx = -dx
        for _ in range(q): dx, dy = -dy, dx
        out.append((C[0] + dx, C[1] + dy, ch))
    return out

def _centre(px):
    return (sum(p[0] for p in px) / len(px), sum(p[1] for p in px) / len(px))

SLOTS = [_centre(_pixels(j)) for j in range(len(LEAVES))]       # the 14 places, in drawing order

# The new layouts: the reference's places turned as a whole (a quarter turn, a mirror...), then
# every place gets ANOTHER leaf, turned so that it covers the place's leaf best (most shared pixels),
# so the module stays as full as the reference's while no leaf repeats where it was.
TURNS = {1: (1, 0), 2: (2, 1), 3: (3, 0), 4: (0, 1), 5: (2, 0), 6: (1, 1), 7: (3, 1)}

def layout(seed):
    """Which leaf, turned how, lies in each place. Seed 0 is the reference's own module."""
    if seed == 0: return [(j, (0, 0)) for j in range(len(LEAVES))]
    rng = random.Random(seed)
    T0 = TURNS[(seed - 1) % 7 + 1]
    targets = [set((x, y) for x, y, _ in _turn(_pixels(s), T0)) for s in range(len(LEAVES))]
    cands = []
    for j in range(len(LEAVES)):
        for q in range(4):
            for mir in (0, 1):
                pts = set((x, y) for x, y, _ in _turn(_pixels(j), (q, mir)))
                cands.append((j, (q, mir), pts))
    scores = []
    for s, tg in enumerate(targets):
        for j, t, pts in cands:
            if j == s and t == T0: continue           # not the same leaf in the same place
            iou = len(tg & pts) / len(tg | pts)
            scores.append((iou + rng.uniform(0, 0.08), s, j, t))
    scores.sort(reverse=True)
    res = [None] * len(LEAVES); used = set()
    for sc, s, j, t in scores:
        if res[s] is None and j not in used:
            res[s] = (j, t); used.add(j)
    # then mend it: swap leaves between places and try their other turns while the module gets
    # fuller (fewer holes over the disc) and keeps the reference's outline (few pixels outside it)
    allt = [(q, m) for q in range(4) for m in (0, 1)]
    pts = {(j, t): set((x, y) for x, y, _ in _turn(_pixels(j), t)) for j in range(len(LEAVES)) for t in allt}
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
            a, b = rng.sample(range(len(r)), 2)
            r[a], r[b] = (r[b][0], rng.choice(allt)), (r[a][0], rng.choice(allt))
        else:
            a = rng.randrange(len(r)); r[a] = (r[a][0], rng.choice(allt))
        if any(r[k] == (k, T0) for k in range(len(r))): continue
        c = cost(r)
        if c <= cur:
            res, cur = r, c
    return res

def layout_cost(seed):
    r = layout(seed)
    allt = [(q, m) for q in range(4) for m in (0, 1)]
    cov = set()
    for j, t in r: cov |= set((x, y) for x, y, _ in _turn(_pixels(j), t))
    yy, xx = np.mgrid[0:S, 0:S]
    dsk = set(zip(*np.nonzero(((xx - C[0]) ** 2 + (yy - C[1] + 0.5) ** 2 < 8.6 ** 2).T)))
    return len(dsk - cov), len(cov)

def module(seed=0, upto=99, flip=False):
    leaf = -np.ones((S, S), int); role = np.zeros((S, S), int)
    placed = [_turn(_pixels(j), t) for j, t in layout(seed)]
    if seed != 0:
        def key(px):
            cx, cy = _centre(px)
            return (0 if math.hypot(cx - C[0], cy - C[1]) < 5.5 else 1, cy)
        placed.sort(key=key)
    for s, px in enumerate(placed):
        if s >= upto: break
        for x, y, ch in px:
            if 0 <= x < S and 0 <= y < S:
                leaf[y, x] = s; role[y, x] = ROLE[ch]
    # a vein is an inside line; an outline pixel with leaf all round it after the overlaps stays outline
    ang = np.zeros(len(LEAVES)); top = np.zeros(len(LEAVES), bool)
    for k in range(len(LEAVES)):
        ys, xs = np.nonzero(leaf == k)
        if len(ys):
            ang[k] = math.atan2(ys.mean() - C[1], xs.mean() - C[0])
            top[k] = math.hypot(ys.mean() - C[1], xs.mean() - C[0]) < 5.5
    depth = np.zeros((S, S), int)
    for y in range(S):
        for x in range(S):
            k = leaf[y, x]
            if k < 0: continue
            d = 0
            while d < 4 and all(0 <= y + dy * (d + 1) < S and 0 <= x + dx * (d + 1) < S and
                                leaf[y + dy * (d + 1), x + dx * (d + 1)] == k for dx, dy in N4):
                d += 1
            depth[y, x] = d
    m = dict(leaf=leaf, role=role, ang=ang, depth=depth, top=top, flip=flip)
    if flip:
        for k in ('leaf', 'role', 'depth'): m[k] = m[k][:, ::-1].copy()
        m['ang'] = math.pi - ang
    return m

def disc(flip=False):
    """The dark disc under the leaves (the reference's first step)."""
    yy, xx = np.mgrid[0:S, 0:S]
    cx = S - 1 - C[0] if flip else C[0]
    return (xx - cx) ** 2 + (yy - C[1] + 0.5) ** 2 < 8.6 ** 2

def tones(m, light2, flat=False):
    """Relative tones: 0 = the flat body, outline and vein -1. light2: the light's way on the
    screen (unit, y down). A leaf facing the light (or lying on top, in the middle) +1, across 0,
    away -1; a lit leaf's inside (off its outline) +1 more, the heart. -9 = empty."""
    out = np.full((S, S), -9, int)
    for y in range(S):
        for x in range(S):
            k = m['leaf'][y, x]
            if k < 0: continue
            r = m['role'][y, x]
            t = 0 if r == BODY else -1
            if not flat:
                a = m['ang'][k]
                f = math.cos(a) * light2[0] + math.sin(a) * light2[1]
                if m['top'][k]: f = max(f, 0.5)
                s = 1 if f > 0.2 else (0 if f > -0.5 else -1)
                t += s
                if s == 1 and r == BODY and m['depth'][y, x] >= 1 and f > 0.45: t += 1
            out[y, x] = t
    return out
