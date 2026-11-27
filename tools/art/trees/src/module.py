# Leaf module: a dense pinwheel rosette of broad pointed leaves, SLYNYRD-like.
# Per pixel: leaf id, depth from the leaf's edge (1 = outline), whether that edge lies over
# an earlier leaf, the leaf's normal (dome of the module + leaf tilt).
import numpy as np, math, random

def _kite(x, y, c, a, L, W, r0, skew):
    d = np.array([math.cos(a), math.sin(a)]); p = np.array([-d[1], d[0]])
    v = np.array([x - c, y - c]); t = v @ d - r0; s = v @ p
    if t < -0.6 or t > L: return None
    u = max(t, 0.0) / L
    mid = skew * u * u                      # the tip hooks sideways (a pinwheel)
    widest = 0.42
    hw = W / 2 * (u / widest if u < widest else (1 - u) / (1 - widest))
    hw = max(hw, 0.7 if u < 0.15 else 0.0)
    return (abs(s - mid) <= hw + 0.25), u, s - mid, d

def rosette(seed, size=25, n_out=7, n_in=4):
    rng = random.Random(seed)
    c = (size - 1) / 2.0
    leaf = -np.ones((size, size), int); nrm = np.zeros((size, size, 3)); t_of = np.zeros((size, size))
    base = rng.uniform(0, math.tau)
    spec = []
    for i in range(n_out):
        spec.append((0, base + i * math.tau / n_out + rng.uniform(-0.18, 0.18), rng.uniform(10.0, 11.5), rng.uniform(6.6, 7.6), 2.0))
    for i in range(n_in):
        spec.append((1, base + (i + 0.5) * math.tau / n_in + rng.uniform(-0.3, 0.3), rng.uniform(7.0, 8.0), rng.uniform(6.5, 7.5), 0.5))
    spec.sort(key=lambda t: (t[0], math.sin(t[1])))
    for k, (ring, a, L, W, r0) in enumerate(spec):
        lift = 0.35 if ring == 0 else 1.0
        for y in range(size):
            for x in range(size):
                r = _kite(x, y, c, a, L, W, r0, 2.4)
                if not r or not r[0]: continue
                _, u, s, d = r
                leaf[y, x] = k; t_of[y, x] = u
                rr = min(1.0, math.hypot(x - c, y - c) / (size / 2))
                n = np.array([(x - c) / (size / 2), lift + (1 - rr) * 0.8, (y - c) / (size / 2)])
                n = n / np.linalg.norm(n)
                # the leaf itself tilts out along its length and folds at the midrib
                n += np.array([d[0], 0.3, d[1]]) * 0.25 + np.array([-d[1], 0, d[0]]) * (0.15 if s > 0 else -0.15)
                nrm[y, x] = n / np.linalg.norm(n)
    # depth from the leaf's own edge, and edges lying over an earlier leaf
    depth = np.zeros((size, size), int); over = np.zeros((size, size), bool)
    low = np.zeros((size, size), bool)
    for y in range(size):
        for x in range(size):
            k = leaf[y, x]
            if k < 0: continue
            for dx, dy in ((0, 1), (-1, 0), (-1, 1)):
                X, Y = x + dx, y + dy
                q = leaf[Y, X] if 0 <= X < size and 0 <= Y < size else -1
                if q != k: low[y, x] = True
    for y in range(size):
        for x in range(size):
            k = leaf[y, x]
            if k < 0: continue
            dd = 9
            for r in (1, 2, 3):
                hit = False
                for dx in range(-r, r + 1):
                    for dy in range(-r, r + 1):
                        if abs(dx) + abs(dy) != r: continue
                        X, Y = x + dx, y + dy
                        q = leaf[Y, X] if 0 <= X < size and 0 <= Y < size else -1
                        if q != k:
                            hit = True
                            if r == 1 and 0 <= q < k: over[y, x] = True
                if hit: dd = r; break
            depth[y, x] = dd
    return dict(leaf=leaf, n=nrm, depth=depth, over=over, t=t_of, low=low)
