# Round 23 step 2: the approved trees in winter (mockup, no game code). Run from the merged src folder.
# The game's rules (src/client/world/foliage.gd, shaders/leaves.gdshader): a broadleaf tree goes bare (the share
# `bare` of trees.yaml) or keeps DRY leaves under snow; snow lies on the crown's top (crown normal up > 0.5), on the
# upper half of an evergreen's sprigs (up > 0.4) and on some bare twigs. Drawn here in the manner of the user's
# reference (references/user-palms-snow.jpg, right half): round snow lumps with the reference's snow ramp, lit by the
# game's sun (right, above), a dark blue-grey outline, a blue-grey seam where the snow overhangs the leaves.
# User's pick 2026-11-24 «1. А»: palms, acacia, ceiba, mangrove (hot zones) stay green, no snow.
import math, random, numpy as np
import render7 as R

SNOW = ['40545c', '748898', '88a0a8', 'a8bcc4', 'd0e4e4', 'f0fcfc']    # the reference's snow: outline .. highlight
SNOW_RGB = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in SNOW], np.uint8)

def _snow0(self):
    """Append the snow colours to the tree's ramp once; return the index of SNOW[0]."""
    if getattr(self, '_snow_i0', None) is None:
        self._snow_i0 = len(self.ramp)
        import bare23 as B
        self.ramp = list(self.ramp) + [c.copy() for c in B.SNOW_EXT]     # 0..5 snow, 5 + t soft outline, 10 + t seam
    return self._snow_i0

def tone(score):
    return np.select([score > 0.62, score > 0.36, score > 0.1, score > -0.15], [5, 4, 3, 2], 1)

def cap(self, Y, X, c, n, p, mode):
    """Snow over the top of one module (crown) or one frond (evergreen), drawn with it so the modules laid later
    cover it. Returns the new c."""
    up = float(n[1]) / max(1e-6, float(np.linalg.norm(n)))
    if mode == 'ever':
        amount = np.clip((up - 0.25) / 0.45, 0, 1)
    else:
        amount = np.clip((up - 0.35) / 0.4, 0, 1)
    if amount <= 0 or len(X) == 0: return c
    i0 = _snow0(self)
    x0 = X.min(); w = X.max() - x0 + 1
    top = np.full(w, 10 ** 6); np.minimum.at(top, X - x0, Y)
    rng = random.Random(int(abs(p[0]) * 131 + abs(p[1]) * 17 + abs(p[2]) * 7) + 3)
    if mode == 'ever':
        dep = np.array([amount * (1.6 + 1.6 * rng.random()) for _ in range(w)])
        dep = np.convolve(dep, np.ones(3) / 3, 'same')
    else:
        nl = 2 if w < 18 else 3
        base = amount * w * rng.uniform(0.28, 0.36)
        cxs = [x0 + w * (i + 0.5) / nl + rng.uniform(-2, 2) for i in range(nl)]
        rs = [base * rng.uniform(0.8, 1.2) for _ in range(nl)]
        xs = np.arange(w) + x0
        dep = np.zeros(w)
        for cx, r in zip(cxs, rs):
            dep = np.maximum(dep, np.sqrt(np.maximum(0, r * r - (xs - cx) ** 2)) * 0.95)
    bot = top + np.round(dep).astype(int) - 1
    col = X - x0
    snow = (Y <= bot[col]) & (dep[col] >= 0.6)
    if not snow.any(): return c
    c = c.copy()
    v = (Y - top[col]) / np.maximum(1, bot[col] - top[col] + 1)
    hx = (X - (x0 + (w - 1) / 2)) / max(1.0, w / 2)
    d = float(np.dot(n / max(1e-6, np.linalg.norm(n)), self.L))
    score = 0.55 * (1 - v) + 0.3 * hx * np.sign(self.L[0]) + 0.3 * d - 0.1
    t = tone(score)
    # the seam under the snow where the leaves of this module go on below it
    have = set(zip(Y.tolist(), X.tolist()))
    below = np.array([(y + 1, x) in have and not (y + 1 <= bot[x - x0]) for y, x in zip(Y.tolist(), X.tolist())])
    t = np.where(below, 1, t)
    # the top edge of the cap against what lies behind: the reference's dark outline where the module had its own
    edge = (Y == top[col]) & (c <= getattr(self, 'last_base', 9) - 1)
    t = np.where(edge, 0, t)
    c[snow] = i0 + t[snow]
    return c

# Heavier, lumpier caps (round 23 step 2, second try): a few round bumps across each module or frond, the snow
# standing over its top edge (lift) and reaching down into it, lit like the reference's snow lumps, its top edge
# outlined, a step of shadow on the leaves just under it.
CAP = dict(ever=dict(d0=1.6, d1=2.4, lift=0.4, bump=9.0, u0=0.12, lit=0.15),
           crown=dict(k_lo=0.42, k_hi=0.6, up0=-0.15, up1=0.45, lift=0.3, bump=8.0, lit=0.2))

def cap2(self, Y, X, c, n, p, mode, mod=None):
    if len(X) == 0: return Y, X, c
    P = CAP['ever' if mode == 'ever' else 'crown']
    rng = random.Random(int(abs(p[0]) * 131 + abs(p[1]) * 17 + abs(p[2]) * 7) + 3)
    s = getattr(self, 's', 1.0)
    x0 = int(X.min()); w = int(X.max()) - x0 + 1
    top = np.full(w, 10 ** 6); np.minimum.at(top, X - x0, Y)
    bot = np.full(w, -1); np.maximum.at(bot, X - x0, Y)
    col_has = top < 10 ** 6
    if mode == 'ever':
        f = mod['frond']
        dv = mod.get('dir', np.array([1.0, 0, 0]))
        amount = 0.45 if mod.get('top') else float(np.clip(1.15 - abs(dv[1]) * 1.2, 0.3, 1.0))
        # the root end lies under the tier above: no snow where the top pixel of a column is near the root
        X0, Y0 = mod['org']
        uu = np.full(w, 1.0)
        for xx in range(w):
            if not col_has[xx]: continue
            fy, fx = top[xx] - Y0, xx + x0 - X0
            if 0 <= fy < f.u.shape[0] and 0 <= fx < f.u.shape[1] and not np.isnan(f.u[fy, fx]): uu[xx] = f.u[fy, fx]
        D = (P['d0'] + P['d1'] * s) * amount
    else:
        up = float(n[1]) / max(1e-6, float(np.linalg.norm(n)))
        amount = float(np.clip((up - P['up0']) / (P['up1'] - P['up0']), 0, 1))
        uu = np.ones(w)
        D = w * rng.uniform(P['k_lo'], P['k_hi']) * amount
    if D < 0.8: return Y, X, c
    nb = max(1, int(round(w / P['bump'])))
    xs = np.arange(w)
    dep = np.zeros(w)
    span = (w - 1) / nb
    for b in range(nb):
        cx = span * (b + 0.5) + rng.uniform(-0.25, 0.25) * span
        bw = span * rng.uniform(0.6, 0.85) + 1.0
        h = D * rng.uniform(0.75, 1.2)
        dep = np.maximum(dep, h * np.sqrt(np.maximum(0, 1 - ((xs - cx) / bw) ** 2)))
    if mode == 'ever': dep = dep * np.clip((uu - P['u0']) / 0.25, 0, 1)
    dep = np.where(col_has, dep, 0)
    lift = np.floor(dep * P['lift'] + 0.35).astype(int)
    d_int = np.round(dep).astype(int)
    if d_int.max() < 1: return Y, X, c
    i0 = _snow0(self)
    L = np.asarray(self.L, float)
    have = {}
    for k_, (y, x) in enumerate(zip(Y.tolist(), X.tolist())): have[(y, x)] = k_
    c = np.asarray(c, float).copy()
    addY, addX, addC = [], [], []
    nn = np.asarray(n, float); nn = nn / max(1e-6, np.linalg.norm(nn))
    back = 1 if mode != 'ever' and float(nn @ R.V) < -0.2 else 0
    for xx in range(w):
        dd = int(d_int[xx])
        if dd < 1: continue
        t0 = int(top[xx]) - int(lift[xx])
        rows = list(range(t0, t0 + dd))
        for k_, y in enumerate(rows):
            x = xx + x0
            v = (k_ + 0.5) / dd                       # 0 top .. 1 bottom of the snow
            hx = (xx - (w - 1) / 2) / max(1.0, w / 2)
            nu = 1 - 2 * v
            nx = 0.6 * hx
            nz = math.sqrt(max(0.0, 1 - nx * nx - nu * nu * 0.6))
            d = nx * L[0] + nu * 0.62 + nz * 0.48 + P['lit']
            tn = 5 if d > 0.78 else 4 if d > 0.5 else 3 if d > 0.2 else 2 if d > -0.1 else 1
            tn = max(1, tn - back)
            own = (y, x) in have
            if k_ == 0 and (not own or c[have[(y, x)]] <= getattr(self, 'last_base', 9) - 1):
                tn = 5 + tn                           # the snow's top edge: the reference's outline, softened
            if own:
                c[have[(y, x)]] = i0 + tn
            elif y < top[xx]:                         # standing over the module's top edge
                addY.append(y); addX.append(x); addC.append(i0 + tn)
        yb = t0 + dd                                  # a step of shadow on the leaves just under the snow
        if (yb, xx + x0) in have:
            j = have[(yb, xx + x0)]
            if c[j] < i0: c[j] = max(0, c[j] - 1)
    if addY:
        ok = (np.array(addY) >= 0) & (np.array(addY) < self.H)
        Y = np.concatenate([Y, np.array(addY)[ok]]); X = np.concatenate([X, np.array(addX)[ok]])
        c = np.concatenate([c, np.array(addC, float)[ok]])
    return Y, X, c

# An evergreen's fronds (third try): snow over the upper half of each frond (the game's rule: the upper half of the
# sprigs on top of the tiers), from a little past its root to its tip, its lower edge a row of round lumps hanging
# a little under the rachis, its upper edge standing a pixel or two over the frond's outline in bumps; lit like the
# reference's lumps (white on top and toward the sun, blue-grey along the rachis), outlined on top.
FROND = dict(u0=0.4, below=-1.0, lump=1.6, lump_w=5.0, lift=1.2, lit=0.2, keep=0.0)

def frond_snow(self, Y, X, c, mod, P=None):
    P = P or FROND
    if len(X) == 0: return Y, X, c
    f = mod['frond']; X0, Y0 = mod['org']
    rng = random.Random(int(abs(mod['ctr'][0]) * 131 + abs(mod['ctr'][1]) * 17 + abs(mod['ctr'][2]) * 7) + 5)
    fy, fx = Y - Y0, X - X0
    u = f.u[fy, fx]
    ax = np.asarray(f.ax, float)
    nrm = np.array([-ax[1], ax[0]])
    if nrm[1] > 0: nrm = -nrm                        # points up on the screen
    rel = np.stack([fx + 0.5 - f.root[0], fy + 0.5 - f.root[1]], 1)
    off = rel @ nrm                                  # > 0 over the rachis
    along = rel @ ax
    amount = 0.6 if mod.get('top') else 1.0
    # the lower edge: lumps along the rachis, each hanging `lump` px under it at its middle
    L_ = max(4.0, f.length)
    nl = max(1, int(round(L_ / P['lump_w'])))
    cs = [L_ * (k + 0.5) / nl + rng.uniform(-1, 1) for k in range(nl)]
    hw = L_ / nl * 0.55 + 0.5
    hang = np.zeros(len(X))
    for cx in cs:
        hang = np.maximum(hang, P['lump'] * rng.uniform(0.6, 1.2) * np.sqrt(np.maximum(0, 1 - ((along - cx) / hw) ** 2)))
    u0 = P['u0'] + rng.uniform(-0.05, 0.08)
    snow = (off > -(P['below'] + hang) * amount) & (np.nan_to_num(u, nan=0.0) > u0)
    if not snow.any(): return Y, X, c
    i0 = _snow0(self)
    Lv = np.asarray(self.L, float)
    # how far up each snow pixel is between its lower edge and the frond's top at that place
    top_off = np.zeros(len(X))
    key = np.round(along).astype(int)
    for k in np.unique(key[snow]):
        m = snow & (key == k)
        top_off[m] = off[m].max()
    lo = -(P['below'] + hang) * amount
    v = np.clip((off - lo) / np.maximum(1.0, top_off - lo), 0, 1)     # 0 bottom .. 1 top
    sun_side = 1.0 if (nrm[0] * Lv[0]) >= 0 else -1.0
    d = 0.75 * (v - 0.35) + 0.25 * np.clip(along / L_, 0, 1) + 0.15 * sun_side + P['lit']
    tn = np.select([d > 0.62, d > 0.38, d > 0.12, d > -0.12], [5, 4, 3, 2], 1)
    deep = mod.get('deep', 0.0)
    if deep < 0: tn = np.maximum(1, tn - 1)
    c = np.asarray(c, float).copy()
    c[snow] = i0 + tn[snow]
    # the pixel under the snow's lower edge in the frond: a step of shadow
    have = {(y, x): k for k, (y, x) in enumerate(zip(Y.tolist(), X.tolist()))}
    ys_s, xs_s = Y[snow], X[snow]
    sset = set(zip(ys_s.tolist(), xs_s.tolist()))
    for y, x in zip(ys_s.tolist(), xs_s.tolist()):
        j = have.get((y + 1, x))
        if j is not None and (y + 1, x) not in sset and c[j] < i0: c[j] = max(0, c[j] - 1)
    # over the frond's top: the snow stands a pixel or two above its outline in bumps
    addY, addX, addC = [], [], []
    cols = {}
    for y, x in sset:
        if (y - 1, x) not in have: cols.setdefault(x, []).append(y)
    for x, ys_ in cols.items():
        y = min(ys_)
        k = have[(y, x)]
        a_ = float(along[k])
        lift = 0.0
        for cx in cs:
            lift = max(lift, P['lift'] * np.sqrt(max(0.0, 1 - ((a_ - cx) / hw) ** 2)))
        n_up = int(lift * amount * rng.uniform(0.7, 1.3) + 0.3)
        c[k] = i0 + max(3, int(tn[k]))             # the old top edge is now inside the snow
        for dy in range(1, n_up + 1):
            top_t = 5 if sun_side > 0 else 4
            addY.append(y - dy); addX.append(x); addC.append(i0 + (5 + top_t if dy == n_up else top_t))
        if n_up == 0: c[k] = i0 + 5 + max(1, int(tn[k]))
    if addY:
        aY = np.array(addY); ok = (aY >= 0) & (aY < self.H)
        Y = np.concatenate([Y, aY[ok]]); X = np.concatenate([X, np.array(addX)[ok]])
        c = np.concatenate([c, np.array(addC, float)[ok]])
    return Y, X, c

def install():
    """Wrap every class's own module_pixels so a tree with .snow ('crown' | 'ever') gets its caps (the willow's
    module_pixels takes `inner` and then returns a 4th array, the leaf mask: padded for the snow's new pixels)."""
    import render17, conifer21, tree123, willow22
    for cls in {R.Tree, render17.Tree, conifer21.Conifer, tree123.Tree, willow22.Willow}:
        if 'module_pixels' not in cls.__dict__ or getattr(cls.__dict__['module_pixels'], '_snow', False): continue
        orig = cls.__dict__['module_pixels']
        def wrapped(self, p, n, mod, *a, _orig=orig, **kw):
            if getattr(self, '_in_cap', False) or not getattr(self, 'snow', None):
                return _orig(self, p, n, mod, *a, **kw)
            self._in_cap = True
            try:
                res = _orig(self, p, n, mod, *a, **kw)
            finally:
                self._in_cap = False
            Y, X, c = res[:3]
            n0 = len(Y)
            if self.snow == 'ever' and 'frond' in mod and getattr(self, 'cap_v', 3) == 3:
                Y, X, c = frond_snow(self, Y, X, c, mod, getattr(self, 'frond_p', None))
            elif getattr(self, 'cap_v', 3) >= 2:
                Y, X, c = cap2(self, Y, X, c, np.asarray(n, float), np.asarray(p, float), self.snow, mod)
            else:
                c = cap(self, Y, X, np.asarray(c, float), np.asarray(n, float), np.asarray(p, float), self.snow)
            if len(res) == 4:
                return Y, X, c, np.concatenate([res[3], np.zeros(len(Y) - n0, bool)])
            return Y, X, c
        wrapped._snow = True
        cls.module_pixels = wrapped

# ---------------------------------------------------------------- bare trees: snow on the limbs and lumps at the tips
def limb_snow(t, img, kg, seed=5):
    """Post-process a bare tree's keyed picture: a thin layer on the top of near-level limbs and round lumps on the
    twig ends and some forks, hidden where a limb in front covers them (a z-buffer of the skeleton's discs)."""
    H, W = img.shape[:2]
    zb = np.full((H, W), -1e9)
    S = t._samples()
    for p, r, tan, l, j in S:
        sx, sy = t.proj_abs(p)
        ri = int(math.ceil(r)) + 1
        yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
        ok = xx * xx + yy * yy <= r * r + 0.5
        Yy, Xx = yy[ok] + int(round(sy)), xx[ok] + int(round(sx))
        k = (Yy >= 0) & (Yy < H) & (Xx >= 0) & (Xx < W)
        np.maximum.at(zb, (Yy[k], Xx[k]), p[2])
    L = np.asarray(t.L, float)
    snowmask = np.zeros((H, W), bool); tones = np.zeros((H, W), int)
    # a layer on the top of level-ish limbs (not the trunk)
    for p, r, tan, l, j in S:
        if t.limbs[j].level < 1 or r > 4.5: continue
        flat = 1 - abs(tan[1])
        if flat < 0.35: continue
        sx, sy = t.proj_abs(p)
        th = 1 if flat < 0.75 else 2
        for dy in range(th):
            y = int(round(sy - r)) - 1 - dy
            for x in range(int(round(sx - r * 0.7)), int(round(sx + r * 0.7)) + 1):
                if 0 <= y < H and 0 <= x < W and zb[y, x] <= p[2] + 0.5:
                    snowmask[y, x] = True; tones[y, x] = 4 if dy == th - 1 else 3
    # lumps
    rng = random.Random(seed)
    s = getattr(t, 's', 1.0)
    balls = []
    for lb in t.limbs:
        if lb.level < 1: continue
        ends = [1.0] + ([0.55] if lb.level >= 1 and rng.random() < 0.45 else [])
        for tt in ends:
            p = lb.at(tt)
            if lb.level >= 2 or tt == 1.0:
                rb = (1.3 + 2.0 * s) * rng.uniform(0.75, 1.25) * (0.8 if tt < 1 else 1.0)
                balls.append((p, rb))
    balls.sort(key=lambda b: b[0][2])
    for p, rb in balls:
        sx, sy = t.proj_abs(p)
        cy = sy - rb * 0.45
        ri = int(math.ceil(rb)) + 1
        yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
        dx = xx + (round(sx) - sx); dy = yy + (round(cy) - cy)
        ok = dx * dx + dy * dy <= rb * rb + 0.3
        Yy, Xx = yy[ok] + int(round(cy)), xx[ok] + int(round(sx))
        nx, nu = dx[ok] / rb, -dy[ok] / rb
        nz = np.sqrt(np.maximum(0, 1 - nx * nx - nu * nu))
        d = nx * L[0] + nu * L[1] - nz * L[2] * 0.3
        tt_ = np.select([d > 0.55, d > 0.25, d > -0.05, d > -0.4], [5, 4, 3, 2], 1)
        k = (Yy >= 0) & (Yy < H) & (Xx >= 0) & (Xx < W)
        Yy, Xx, tt_ = Yy[k], Xx[k], tt_[k]
        vis = zb[Yy, Xx] <= p[2] + rb
        snowmask[Yy[vis], Xx[vis]] = True; tones[Yy[vis], Xx[vis]] = tt_[vis]
        zb[Yy[vis], Xx[vis]] = np.maximum(zb[Yy[vis], Xx[vis]], p[2])
    # outline: snow pixels next to the background (not next to bark or other snow)
    bgm = (img == kg).all(2) | (img == np.array(R.hexc('00ffff'))).all(2)
    out = np.zeros_like(snowmask)
    for ddy, ddx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        nb_s = np.roll(np.roll(snowmask, ddy, 0), ddx, 1); nb_bg = np.roll(np.roll(bgm & ~snowmask, ddy, 0), ddx, 1)
        out |= snowmask & nb_bg & ~nb_s
    tones[out] = 0
    img[snowmask] = SNOW_RGB[tones[snowmask]]
    return img

# ---------------------------------------------------------------- a bare larch: each frond's rachis as a twig
def twig(self, mod):
    """(Y, X, c) of a bare larch twig in place of a frond: its rachis root -> tip, 1 px of bark, a snow layer over the
    level parts and a lump on the tip."""
    i0 = _snow0(self)
    if getattr(self, '_bark_i0', None) is None:
        self._bark_i0 = len(self.ramp); self.ramp = list(self.ramp) + [np.asarray(b, np.uint8) for b in self.bark]
    f = mod['frond']; X0, Y0 = mod['org']
    a = np.array([X0 + f.root[0], Y0 + f.root[1]]); b = np.array([X0 + f.tip[0], Y0 + f.tip[1]])
    n = int(max(abs(b - a))) + 1
    pts = np.round(a[None] + (b - a)[None] * np.linspace(0, 1, n + 1)[:, None]).astype(int)
    pts = np.unique(pts, axis=0)
    X, Y = pts[:, 0], pts[:, 1]
    c = np.full(len(X), float(self._bark_i0 + 1))
    level = abs(b[1] - a[1]) < 0.8 * abs(b[0] - a[0])
    Ys, Xs, cs = [Y], [X], [c]
    if level and mod.get('top') is not True:
        Ys.append(Y - 1); Xs.append(X); cs.append(np.full(len(X), float(i0 + 4)))
    rb = 1.6
    yy, xx = np.mgrid[-2:3, -2:3]
    ok = xx * xx + yy * yy <= rb * rb + 0.3
    d = (xx[ok] / rb) * self.L[0] + (-yy[ok] / rb) * self.L[1]
    Ys.append(yy[ok] + int(round(b[1])) - 1); Xs.append(xx[ok] + int(round(b[0])))
    cs.append((i0 + np.select([d > 0.4, d > 0.0, d > -0.4], [5, 4, 3], 2)).astype(float))
    Y, X, c = np.concatenate(Ys), np.concatenate(Xs), np.concatenate(cs)
    ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
    self.last_base = 3
    return Y[ok], X[ok], c[ok]

# A bare larch (second try): each frond becomes a drooping branch (a curve from its root that sags and turns its
# tip up a little), 1 px of bark, with one or two short twigs hanging off it and a few small snow lumps on its
# upper side; the inner rings' fronds are mostly left out (the first try's straight spokes read as a fishbone).
LARCH = dict(sag=0.2, tip_up=0.08, keep_inner=0.35, side=(1, 3), lumps=(2, 3), r_lump=(2.2, 3.6),   # x1.4 (16:04 MSK)
             keep=0.75)                  # a quarter fewer lumps, the same size (user 2026-11-24 16:22 MSK)

def twig2(self, mod, P=None):
    import bare23 as B
    P = P or LARCH
    i0 = _snow0(self)
    if getattr(self, '_bark_i0', None) is None:
        self._bark_i0 = len(self.ramp); self.ramp = list(self.ramp) + [np.asarray(b, np.uint8) for b in self.bark]
    f = mod['frond']; X0, Y0 = mod['org']
    rng = random.Random(int(abs(mod['ctr'][0]) * 97 + abs(mod['ctr'][1]) * 13 + abs(mod['ctr'][2]) * 5) + 1)
    self.last_base = 3
    if mod.get('deep', 0) < 0 and rng.random() > P['keep_inner']:
        return np.zeros(0, int), np.zeros(0, int), np.zeros(0)
    a = np.array([X0 + f.root[0], Y0 + f.root[1]]); b = np.array([X0 + f.tip[0], Y0 + f.tip[1]])
    # the branch grows out of the trunk (user 2026-11-24 15:58 MSK: «продли голые ветки до ствола»): it starts on
    # the trunk's axis at its tier's height, where the frond's branch starts, and a branch going away from us is
    # hidden behind the trunk
    back, trunk_x, trunk_r = False, None, 0.0
    if not mod.get('top') and P.get('to_trunk', True):
        a = np.asarray(self.scr(mod['root']), float)
        back = float(mod['dir'][2]) < -0.05
        tl = self.limbs[0]
        tts = np.linspace(0, 1, 60); ys_ = np.array([tl.at(t_)[1] for t_ in tts])
        t_ = float(tts[np.argmin(np.abs(ys_ - mod['root'][1]))])
        trunk_x, trunk_r = self.ox + float(tl.at(t_)[0]), float(tl.r(t_))
        a[0] = trunk_x
    Ln = float(np.linalg.norm(b - a))
    if mod.get('top'):
        ctl = (a + b) / 2; b2 = b
    else:
        sag = P['sag'] * min(Ln, 20.0) + P.get('sag_far', 0.08) * max(0.0, Ln - 20.0)
        ctl = (a + b) / 2 + np.array([0.0, sag])
        b2 = b - np.array([0.0, P['tip_up'] * min(Ln, 24.0)])
    ts = np.linspace(0, 1, int(Ln * 2.5) + 2)
    curve = ((1 - ts) ** 2)[:, None] * a + (2 * ts * (1 - ts))[:, None] * ctl + (ts ** 2)[:, None] * b2
    pts = [tuple(q) for q in np.round(curve).astype(int)]
    seen, line = set(), []
    for q in pts:
        if q not in seen: seen.add(q); line.append(q)
    lit = (b[0] - a[0]) * self.L[0] >= 0
    Ys, Xs, cs = [], [], []
    for k_, (x, y) in enumerate(line):
        if back and trunk_x is not None and abs(x - trunk_x) <= trunk_r + 0.5: continue     # behind the trunk
        Ys.append(y); Xs.append(x); cs.append(self._bark_i0 + (2 if lit else 1))
        if Ln > 14 and k_ < len(line) * 0.3:      # thicker near the trunk: a second, shaded pixel under it
            Ys.append(y + 1); Xs.append(x); cs.append(self._bark_i0 + 1)
    # short side twigs hanging off it
    if not mod.get('top') and Ln > 6:
        for _ in range(rng.randint(*P['side'])):
            t0 = rng.uniform(0.3, 0.85)
            k = int(t0 * (len(curve) - 1))
            q = curve[k]; tan = curve[min(len(curve) - 1, k + 1)] - curve[max(0, k - 1)]
            tan = tan / max(1e-6, np.linalg.norm(tan))
            ang = rng.uniform(0.6, 1.0) * (1 if tan[0] >= 0 else -1)
            dvec = np.array([tan[0] * math.cos(ang) - tan[1] * math.sin(ang), tan[0] * math.sin(ang) + tan[1] * math.cos(ang)])
            if dvec[1] < 0: dvec[1] = -dvec[1]
            ln = rng.uniform(2, 4) * min(1.0, Ln / 14)
            for s_ in np.linspace(0.5, ln, int(ln * 2) + 1):
                x, y = np.round(q + dvec * s_).astype(int)
                Ys.append(y); Xs.append(x); cs.append(self._bark_i0 + 1)
    # snow lumps on its upper side
    nl = rng.randint(*P['lumps']) if not mod.get('top') else 1
    rk = random.Random(int(abs(mod['ctr'][0]) * 97 + abs(mod['ctr'][1]) * 13 + abs(mod['ctr'][2]) * 5) + 8)
    #   (its own draws, so the lumps that stay keep their places)
    for _ in range(nl):
        t0 = rng.uniform(0.35, 0.95) if not mod.get('top') else 1.0
        k = int(t0 * (len(curve) - 1))
        q = curve[k]
        rb = rng.uniform(*P['r_lump']) * (0.8 + 0.2 * getattr(self, 's', 1.0))
        if not mod.get('top') and rk.random() > P.get('keep', 1.0): continue
        tt, ri = B.ball_tones(rb, np.asarray(self.L, float), 0, 0.25, 1.0, 0.0, 0.0)
        ys, xs = np.nonzero(tt >= 0)
        cyy = q[1] - rb * 0.6
        for yy, xx in zip(ys, xs):
            Ys.append(int(round(cyy)) + yy - ri); Xs.append(int(round(q[0])) + xx - ri); cs.append(i0 + tt[yy, xx])
    Y, X, c = np.array(Ys), np.array(Xs), np.array(cs, float)
    ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
    return Y[ok], X[ok], c[ok]

def _install_twigs():
    import conifer21
    cls = conifer21.Conifer
    if getattr(cls.module_pixels, '_twig', False): return
    prev = cls.module_pixels
    def mp(self, p, n, mod, _prev=prev):
        if getattr(self, 'snow', None) == 'larch' and 'frond' in mod:
            return twig2(self, mod, getattr(self, 'larch_p', None)) if getattr(self, 'cap_v', 3) >= 2 else twig(self, mod)
        return _prev(self, p, n, mod)
    mp._twig = True; mp._snow = True
    cls.module_pixels = mp

# ---------------------------------------------------------------- builders
HOT = ('palm', 'fan_palm', 'acacia', 'ceiba', 'mangrove')
EVER = ('spruce', 'fir', 'pine')
BOTH = ('oak', 'linden', 'willow')         # bare 0.6 / 0.8 / 0.8: some trees keep dry leaves under snow
R.R6.SEASON['winter_dry'] = (1.55, 1.0, 0.6)  # the dry leaves a tree keeps under snow: brown, a little toward orange

# Dry leaves a tree keeps under snow: the tree's own ramp, step by step at the same brightness, turned brown (dark
# steps cooler and greyer, light steps warmer: the game's darks go toward blue). The game's own winter tint
# (sky.gd FOLIAGE[WINTER] 1.3, 0.9, 0.7) gave olive greens (first try).
import colorsys
DRY = dict(h_lo=0.03, h_hi=0.09, s_lo=0.2, s_hi=0.45, bright=1.0)

def _lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]

def dry_ramp(ramp, P=None):
    P = P or DRY
    out = []
    cs = [np.array(R.hexc(h), float) / 255 for h in ramp]
    lums = [_lum(c) * P['bright'] for c in cs]
    lo, hi = min(lums), max(lums)
    for c, y in zip(cs, lums):
        f = (y - lo) / max(1e-6, hi - lo)
        h = P['h_lo'] + (P['h_hi'] - P['h_lo']) * f
        s = P['s_lo'] + (P['s_hi'] - P['s_lo']) * f
        a, b = 0.0, 1.0
        for _ in range(30):                     # the lightness that gives the step's brightness
            m = (a + b) / 2
            r, g, bl = colorsys.hls_to_rgb(h, m, s)
            if _lum((r, g, bl)) < y: a = m
            else: b = m
        r, g, bl = colorsys.hls_to_rgb(h, (a + b) / 2, s)
        out.append('%02x%02x%02x' % tuple(int(round(v * 255)) for v in (r, g, bl)))
    return out

def looks(key):
    if key in HOT: return ['hot']
    if key in EVER: return ['ever']
    if key == 'larch': return ['larch']
    if key == 'deadwood': return ['bare']
    return ['bare', 'dry'] if key in BOTH else ['bare']

def build(key, s, look, dry=None):
    """(tree, post) for a look: 'hot' as summer, 'ever' snow on the fronds, 'larch' bare twigs, 'bare' bare limbs
    (snow added after render by limb_snow), 'dry' dry leaves with snow caps."""
    import all23 as A, species19 as SP
    A._taller(); install(); _install_twigs()
    if look == 'hot': return A.build(key, s), None
    if look in ('ever', 'larch'):
        t = A.build(key, s); t.snow = look
        if look == 'larch':
            H, W = t.H, t.W
            t.core = lambda: np.zeros((H, W), bool)
            def sh(t=t):
                m = np.zeros((t.H, t.W), bool); t.skeleton_shadow(m); return m
            t.shadow = sh
        return t, None
    if look == 'bare':
        spec = SP.SPEC[key]
        SP.SPEC[key] = spec[:8] + (True,)
        try:
            if key == 'willow':
                import trees22 as TR
                t = TR.tree('willow', s, H=440)
            else:
                t = A.build(key, s)
        finally:
            SP.SPEC[key] = spec
        return t, 'limbs'
    if look == 'dry':
        import species19 as SP
        tints = SP.SPEC[key][6]
        ramp = dry_ramp(R.contrast(R.R6.ramp_for('summer', R.species_tint(*tints)), 1.3), dry)
        if key == 'willow':
            import willow22 as W22
            t = W22.willow(s, H=440, ramp=ramp)
        else:
            import trees22 as TR
            t = TR.tree(key, s, H=440, ramp=ramp)
        t.snow = 'crown'
        return t, None

def render(key, s, look, KEY_G='ff00ff', KEY_S='00ffff'):
    t, post = build(key, s, look)
    img = t.render(ground=KEY_G, shade=KEY_S)
    if post == 'limbs':
        img = limb_snow(t, img, np.array(R.hexc(KEY_G)))
    return img, t.ox, t.oy
