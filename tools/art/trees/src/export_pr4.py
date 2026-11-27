# PR 4 (seasons in the game): the approved winter of the trees (round 23, sheets 95 / 96) exported at the camera's
# 8 turns, in the cells of the looks PR 1-3 packed (content/plants/<key>/tree/look.yaml), as the game needs them:
#   bare   the bare tree of winter: the approved skeleton and the twigs grown through the crown (bare23.colonise, the
#          same draws as the approved sheet), at the 8 suns of the game's day (export_pr1's bare layer), the bare willow
#          with its hanging twigs (bare23.weeping), the larch's drooping branches (export_pr2's), the dead tree its own.
#   snow   one layer a look (two for oak, linden, willow: bare and dry), a texel 16 bits (pack_pr4.py, tree.gdshader):
#          kind 0 none (but a texel 1..: a leaf or frond under the snow's edge, a step darker), 1 snow, 2 its soft
#          outline, 3 the seam where it lies over other snow; mode 0: lit by a normal (a ball, a patch, a cap: octa
#          on the hemisphere facing the camera, 5 + 5 bits, in the picture's frame: x right, u up the picture, z toward
#          the camera), its shade (0..2 steps) and its light's lift (0.25 / 0.2); mode 1 (a conifer's frond): its tone
#          when the sun is on the frond's upper side and when not.
# Placement of the balls is done once on the tree as approved (turn 0, the approved sheet's draws) and kept in 3D: the
# camera's turns show the same balls on the same twigs, each drawn and hidden per view.
# Run from tools/art/trees/src/:  python3 export_pr4.py <out dir> [keys] [workers] [sizes]
import os, sys, math, time, random, numpy as np
from multiprocessing import Pool
import export_pr1 as E

SIZES = E.SIZES
VARIANTS = E.VARIANTS
SUN_T, sun_at = E.SUN_T, E.sun_at
BARE = ['oak', 'linden', 'birch', 'apple', 'cherry', 'poplar', 'maple', 'red_maple', 'bird_cherry', 'rowan']
DRY = ('oak', 'linden', 'willow')
EVER = ('spruce', 'fir', 'pine')
ALL = BARE + ['willow', 'deadwood', 'larch'] + list(EVER)

VV = np.array([0.0, 1.0, 1.0]) / math.sqrt(2)          # toward the camera (the mockup's view)
SUP = np.array([0.0, 1.0, -1.0]) / math.sqrt(2)        # up the picture


def _sun(t, k):
    import render7 as R
    L = R.norm(sun_at(SUN_T[k]))
    t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
    for a_ in ('_cover', '_shadow_cache'):
        if hasattr(t, a_): setattr(t, a_, None)
    return L


# ------------------------------------------------------------------ the snow texel
def hemi(nx, nu, nz):
    """5 + 5 bits of a normal on the hemisphere facing the camera (octahedral, nz >= 0)."""
    s = np.abs(nx) + np.abs(nu) + np.maximum(nz, 0.0) + 1e-9
    u = np.clip(np.round((nx / s * 0.5 + 0.5) * 31), 0, 31).astype(np.int64)
    v = np.clip(np.round((nu / s * 0.5 + 0.5) * 31), 0, 31).astype(np.int64)
    return u, v


def unhemi(u, v):
    x = u / 31.0 * 2 - 1; y = v / 31.0 * 2 - 1
    z = np.maximum(0.0, 1 - np.abs(x) - np.abs(y))
    n = np.stack([x, y, z], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def _suns():
    """The suns a snow texel's code is fitted under: the approved sheet's (SUN_R, twice) and the game's day path at
    its 8 drawn times seen from the camera's 8 turns."""
    import render7 as R
    out = [np.asarray(R.norm(R.SUN_R))] * 2
    for k in range(8):
        L = np.asarray(R.norm(sun_at(SUN_T[k])))
        for n in range(8):
            a = math.radians(45 * n); c, s_ = math.cos(a), math.sin(a)
            out.append(np.array([c * L[0] - s_ * L[2], L[1], s_ * L[0] + c * L[2]]))
    return np.array(out)

FIT_SUNS = _suns()


def _bands(d):
    return np.select([d > 0.78, d > 0.5, d > 0.2, d > -0.1], [5, 4, 3, 2], 1)


def _dirs(L):
    return np.stack([L[:, 0], L @ SUP, L @ VV], 1)          # (x, up the picture, toward the camera) per sun


def ball_code(nx, nu, nz, kind, shade, lit):
    """The 16 bits of a lit snow texel: R = u | shade << 5 (mode 0), G = v | lit << 5 | kind << 6. lit 0: a ball
    (lift 0.25, unit normal), 1: a cap (lift 0.2, its normal's length found from its up part, see tone_of). The
    5 + 5 bits of the normal are fitted: of the codes round the nearest, the one whose steps match the exact
    normal's under most of FIT_SUNS."""
    nx, nu, nz = np.broadcast_arrays(np.asarray(nx, float), np.asarray(nu, float), np.asarray(nz, float))
    shp = nx.shape
    nx, nu, nz = nx.ravel(), nu.ravel(), nz.ravel()
    lit_a = np.broadcast_to(np.asarray(lit, np.int64), shp).ravel()
    D = _dirs(FIT_SUNS)                                       # (S, 3)
    lift = np.where(lit_a == 1, 0.2, 0.25)
    want = _bands(np.stack([nx, nu, nz], 1) @ D.T + lift[:, None])      # (P, S)
    u0, v0 = hemi(nx, nu, nz)
    best = None
    for du in (0, -1, 1):
        for dv in (0, -1, 1):
            u = np.clip(u0 + du, 0, 31); v = np.clip(v0 + dv, 0, 31)
            n = unhemi(u, v)
            mag = np.where(lit_a == 1, 1.0 / np.sqrt(np.maximum(1e-6, 1 - 0.4 * n[:, 1] ** 2)), 1.0)
            got = _bands(mag[:, None] * (n @ D.T) + lift[:, None])
            miss = (got != want).sum(1) * 4 + abs(du) + abs(dv)
            if best is None:
                best, bu, bv = miss, u, v
            else:
                w = miss < best
                best = np.where(w, miss, best); bu = np.where(w, u, bu); bv = np.where(w, v, bv)
    u, v = bu.reshape(shp), bv.reshape(shp)
    return (u | (np.asarray(shade, np.int64) << 5)) | ((v | (np.asarray(lit, np.int64) << 5) | (np.asarray(kind, np.int64) << 6)) << 8)


def frond_code(tone_pos, tone_neg, up_pos, kind):
    """A frond's snow texel: R = tone_pos | tone_neg << 3 | 1 << 7 (mode 1), G = up_pos << 5 | kind << 6."""
    return (np.asarray(tone_pos, np.int64) | (np.asarray(tone_neg, np.int64) << 3) | 128) | \
           ((np.asarray(up_pos, np.int64) << 5 | (np.asarray(kind, np.int64) << 6)) << 8)


LIT = {0.25: 0, 0.2: 1}


def tone_of(code, L):
    """The snow's tone index (SNOW_EXT: 0..5, 5 + t outline, 10 + t seam) a code shows under the sun L (the mockup's
    frame), -1 none; the leaf-under-snow mark is -2. The game's rule (tree.gdshader snow_tone)."""
    code = np.asarray(code, np.int64)
    r, g = code & 255, code >> 8
    kind = g >> 6
    out = np.full(code.shape, -1, np.int64)
    out[(kind == 0) & (code != 0)] = -2
    m = kind > 0
    mode1 = (r & 128) > 0
    a = m & ~mode1
    n = unhemi(r & 31, g & 31)
    cap = ((g >> 5) & 1) == 1
    mag = np.where(cap, 1.0 / np.sqrt(np.maximum(1e-6, 1 - 0.4 * n[..., 1] ** 2)), 1.0)
    d = mag * (n[..., 0] * L[0] + n[..., 1] * float(SUP @ L) + n[..., 2] * float(VV @ L)) + np.where(cap, 0.2, 0.25)
    tb = np.select([d > 0.78, d > 0.5, d > 0.2, d > -0.1], [5, 4, 3, 2], 1)
    tb = np.maximum(tb - ((r >> 5) & 3), 1)
    b = m & mode1
    pos = (((g >> 5) & 1) == 1) == (L[0] >= 0)
    tf = np.where(pos, r & 7, (r >> 3) & 7)
    t = np.where(mode1, tf, tb)
    out[m] = np.where(kind[m] == 1, t[m], np.where(kind[m] == 2, 5 + t[m], 10 + t[m]))
    return out


# ------------------------------------------------------------------ snow balls placed once, drawn per view
def place_balls(t, seed=7, r_lo=None, r_hi=None, gap=0.6, share=1.0, tiny=0.6, every=3.0, lit=0.0, flat=0.8,
                per_mod=0, back=1, size=1.0, merge=0.0, touch=0.92, keep=1.0, blend=0.0, soft=0.0):
    """bare23.snow_balls' placement as drawn on the approved sheet (the same draws, at the tree's own view): the
    balls (3D point, radius, its height's shade, tiny), and the patches they stick into."""
    import bare23 as B
    rng = np.random.default_rng(seed)
    s = getattr(t, 's', 1.0)
    r_lo = (r_lo if r_lo is not None else 1.8 + 1.2 * s) * size
    r_hi = (r_hi if r_hi is not None else 2.8 + 2.6 * s) * size
    info = t.twig_info
    lo, hi = t.yrange(); c_lo, c_hi = lo + t.cy, hi + t.cy
    N, parent, n0, kids = info['nodes'], info['parent'], info['n0'], info['kids']
    cands = []
    for i in range(n0, len(N)):
        p = N[i]; q = N[parent[i]]
        d = p - q; d = d / max(1e-6, np.linalg.norm(d))
        nk = len(kids[i])
        if nk >= 2: kind, pr = 'fork', 1.0
        elif nk == 0: kind, pr = 'tip', 0.35
        else:
            if rng.random() > 1.0 / every: continue
            if d[1] > 0.8: continue
            kind, pr = 'on', 0.6
        cands.append((pr + 0.25 * (p[1] - c_lo) / max(1, c_hi - c_lo) + rng.normal(0, 0.18), p, kind))
    if per_mod:
        from scipy.spatial import cKDTree
        kd = cKDTree(N[n0:])
        cands = [c for c in cands if c[2] == 'tip']
        for p_, n_, mod in t.mods:
            n_ = np.asarray(n_, float); n_ = n_ / max(1e-6, np.linalg.norm(n_))
            c = np.asarray(p_, float) + np.array([0, t.cy, 0]) + n_ * 2.0
            for k_ in range(per_mod):
                q = c + rng.uniform(-1, 1, 3) * np.array([6, 4, 3])
                d_, i_ = kd.query(q)
                pr = 2.0 + 0.4 * (q[1] - c_lo) / max(1, c_hi - c_lo) + rng.normal(0, 0.2)
                cands.append((pr, N[n0 + i_], 'mod'))
    cands.sort(key=lambda c: -c[0])
    placed, tips_left = [], []
    for pr, p, kind in cands:
        if rng.random() > share:
            if kind == 'tip': tips_left.append(p)
            continue
        rb = rng.uniform(r_lo, r_hi) * (0.8 if kind == 'tip' else 1.0)
        sx, sy = t.proj_abs(p)
        cy_ = sy - rb * 0.5
        if any((sx - x) ** 2 + (cy_ - y) ** 2 < (gap * (rb + r2)) ** 2 for x, y, r2, _, _, _ in placed):
            if kind == 'tip': tips_left.append(p)
            continue
        hrel = (p[1] - c_lo) / max(1.0, c_hi - c_lo)
        placed.append((sx, cy_, rb, np.array(p, float), 1 if hrel < 0.25 else 0, False))
    n_big = len(placed)
    for p in tips_left:
        if rng.random() < tiny:
            sx, sy = t.proj_abs(p)
            if all((sx - x) ** 2 + (sy - 1 - y) ** 2 >= (r2 + 1.2) ** 2 for x, y, r2, _, _, _ in placed):
                placed.append((sx, sy - 1, 2.1, np.array(p, float), 0, True))
    if keep < 1.0:
        r2_ = np.random.default_rng(seed + 101)
        placed = [b for i, b in enumerate(placed) if i >= n_big or r2_.random() < keep]
    n = len(placed)
    up_ = list(range(n))
    def root(a):
        while up_[a] != a: up_[a] = up_[up_[a]]; a = up_[a]
        return a
    for a in range(n):
        for b in range(a + 1, n):
            xa, ya, ra = placed[a][:3]; xb, yb, rb_ = placed[b][:3]
            if min(ra, rb_) < 2.2: continue
            if (xa - xb) ** 2 + (ya - yb) ** 2 < (touch * (ra + rb_)) ** 2 and rng.random() < merge:
                up_[root(a)] = root(b)
    balls = [dict(p=b[3], rb=b[2], hshade=b[4], tiny=b[5], group=root(i)) for i, b in enumerate(placed)]
    return dict(balls=balls, flat=flat, lit=lit, back=back, soft=soft)


def draw_balls(t, B_, pos=None):
    """The snow codes (H x W, int64; 0 none) of the placed balls seen in t's current view (pos maps the approved
    frame to it; None: the approved view), hidden behind the limbs in front (bare23.zbuffer)."""
    import bare23 as B
    H, W = t.H, t.W
    flat, lit, back, soft = B_['flat'], B_['lit'], B_['back'], B_['soft']
    groups = {}
    for b in B_['balls']:
        p = pos(b['p']) if pos is not None else b['p']
        sx, sy = t.proj_abs(p)
        rb = b['rb']
        cy_ = sy - (1 if b['tiny'] else rb * 0.5)
        shade = b['hshade']
        if back and p[2] < -6: shade = min(2, shade + back)
        groups.setdefault(b['group'], []).append((sx, cy_, rb, float(p @ VV), shade))
    zb = B.zbuffer(t, rmin=1.4)
    code = np.zeros((H, W), np.int64)
    snow = np.zeros((H, W), bool)
    litb = LIT[0.25] if abs(lit - 0.25) < 1e-6 else LIT[0.2]
    for grp in sorted(groups.values(), key=lambda g: max(b[3] for b in g)):
        x0 = int(math.floor(min(b[0] - b[2] for b in grp))) - 3; x1 = int(math.ceil(max(b[0] + b[2] for b in grp))) + 3
        y0 = int(math.floor(min(b[1] - b[2] for b in grp))) - 3; y1 = int(math.ceil(max(b[1] + b[2] for b in grp))) + 3
        h_, w_ = y1 - y0 + 1, x1 - x0 + 1
        yy, xx = np.mgrid[y0:y0 + h_, x0:x0 + w_].astype(float)
        if len(grp) > 1 and soft > 0:
            shade = int(math.floor(np.mean([b[4] for b in grp]) + 0.5))
            m = np.zeros((h_, w_), bool); hmax = np.full((h_, w_), -1e9); parts = []
            for sx, cy, rb, dep, _ in grp:
                ex, ey = xx - sx, (yy - cy) / flat
                r2 = ex * ex + ey * ey
                ins = r2 <= rb * rb + 0.3
                hh = np.sqrt(np.maximum(0.0, rb * rb - r2))
                nx, nu = ex / max(rb, 0.8), -ey / max(rb, 0.8)
                nz = np.sqrt(np.maximum(0.0, 1 - nx * nx - nu * nu))
                parts.append((ins, hh, nx, nu, nz, dep + rb * 0.6))
                m |= ins; hmax = np.where(ins, np.maximum(hmax, hh), hmax)
            sx_ = su = sz = sw = sv = 0.0
            for ins, hh, nx, nu, nz, vd in parts:
                w = np.where(ins, np.exp(np.minimum(0.0, hh - hmax) / soft), 0.0)
                sx_ = sx_ + w * nx; su = su + w * nu; sz = sz + w * nz; sw = sw + w; sv = sv + w * vd
            NX, NU, NZ = sx_, su, sz
            SH = np.full((h_, w_), shade)
            vdep = np.where(m, sv / np.maximum(sw, 1e-12), 0.0)
        else:
            front = np.full((h_, w_), -1e9); vdep = np.zeros((h_, w_))
            NX = np.zeros((h_, w_)); NU = np.zeros((h_, w_)); NZ = np.zeros((h_, w_)); SH = np.zeros((h_, w_), int)
            for sx, cy_, rb, dep, shade in grp:
                fl = flat if rb > 2.2 else 1.0
                ex, ey = xx - sx, (yy - cy_) / fl
                ins = ex * ex + ey * ey <= rb * rb + 0.3
                nx, nu = ex / max(rb, 0.8), -ey / max(rb, 0.8)
                nz = np.sqrt(np.maximum(0, 1 - nx * nx - nu * nu))
                f = np.where(ins, dep + rb * nz, -1e9)
                w = f > front
                front = np.where(w, f, front); NX = np.where(w, nx, NX); NU = np.where(w, nu, NU)
                NZ = np.where(w, nz, NZ); SH = np.where(w, shade, SH)
                vdep = np.where(w, dep + rb * 0.6, vdep)
            m = front > -1e8
        kind = np.where(B.rim_of(m), 2, 1)
        ys, xs = np.nonzero(m)
        Y, X = ys + y0, xs + x0
        k_ = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        ys, xs, Y, X = ys[k_], xs[k_], Y[k_], X[k_]
        vis = zb[Y, X] <= vdep[ys, xs]
        ys, xs, Y, X = ys[vis], xs[vis], Y[vis], X[vis]
        kd = kind[ys, xs]
        kd = np.where((kd == 2) & snow[Y, X], 3, kd)
        code[Y, X] = ball_code(NX[ys, xs], NU[ys, xs], NZ[ys, xs], kd, SH[ys, xs], litb)
        snow[Y, X] = True
    return code


# ------------------------------------------------------------------ the bare broadleaf tree
def twigged(t):
    """bare23's winter tree on t (round 24 build, crown=False drawn): the approved twigs and their snow balls."""
    import bare23 as B
    B.bare_tree(t, **B.TWIG)
    return place_balls(t, **B.SNOWK)


def bare_wood(t, key, k):
    """The bare tree's picture at sun k (bark colours where wood): the skeleton with its twigs (bare23.twig_colours),
    the approved wood outline."""
    import all23 as A, outline23 as O, bare23 as B
    _sun(t, k)
    img = t.render(ground=A.KEY_G, shade=A.KEY_S)
    twig_colours(t, img)
    O.outline(img, key)
    return img


def twig_colours(t, img, thin=1, top=2, body=1, rmax=1.6):
    """bare23.twig_colours for a view whose limbs may be turned (turn24.XLimb around the Twig)."""
    import bare23 as B
    own, rad = B.owner(t)
    tw = np.array([isinstance(getattr(lb, 'lb', lb), B.Twig) for lb in t.limbs] + [False])
    m = tw[own] & (own >= 0) & (rad < rmax)
    bark = np.array(t.bark)
    above = np.roll(own, 1, 0)
    below = np.roll(own, -1, 0)
    wide = (rad >= 0.85)
    c = np.where(wide & (above != own), top, np.where(wide, body, thin))
    c = np.where(wide & (above == own) & (below != own), max(0, body - 1) if body > 0 else 0, c)
    img[m] = bark[c[m]]
    return img


def paint(img, code, L):
    """The snow drawn over a picture (a check: the mockup's colours under the sun L)."""
    import bare23 as B
    tn = tone_of(code, L)
    m = tn >= 0
    img[m] = B.SNOW_EXT[tn[m]]
    return img


# ------------------------------------------------------------------ snow on a crown's modules and on fronds
# winter23.cap2 and winter23.frond_snow as drawn on the approved sheet, each also giving the code of every snow
# pixel it lays (the game lights them: cap2's d = nx L.x + nu 0.62 + nz 0.48 + lit is the ball's rule at the approved
# sun, its normal (0.6 hx, nu, nz) as long as sqrt(1 + 0.4 nu^2): the game finds the length again from the stored
# direction); `dark=False` leaves out the step of shadow on the leaves under the snow (two renders tell those pixels).
def cap2_code(self, Y, X, c, n, p, mode, mod=None, dark=True):
    import winter23 as WI, render7 as R
    if len(X) == 0: return Y, X, c, None
    P = WI.CAP['crown']
    rng = random.Random(int(abs(p[0]) * 131 + abs(p[1]) * 17 + abs(p[2]) * 7) + 3)
    x0 = int(X.min()); w = int(X.max()) - x0 + 1
    top = np.full(w, 10 ** 6); np.minimum.at(top, X - x0, Y)
    col_has = top < 10 ** 6
    up = float(n[1]) / max(1e-6, float(np.linalg.norm(n)))
    amount = float(np.clip((up - P['up0']) / (P['up1'] - P['up0']), 0, 1))
    D = w * rng.uniform(P['k_lo'], P['k_hi']) * amount
    if D < 0.8: return Y, X, c, None
    nb = max(1, int(round(w / P['bump'])))
    xs = np.arange(w)
    dep = np.zeros(w)
    span = (w - 1) / nb
    for b in range(nb):
        cx = span * (b + 0.5) + rng.uniform(-0.25, 0.25) * span
        bw = span * rng.uniform(0.6, 0.85) + 1.0
        h = D * rng.uniform(0.75, 1.2)
        dep = np.maximum(dep, h * np.sqrt(np.maximum(0, 1 - ((xs - cx) / bw) ** 2)))
    dep = np.where(col_has, dep, 0)
    lift = np.floor(dep * P['lift'] + 0.35).astype(int)
    d_int = np.round(dep).astype(int)
    if d_int.max() < 1: return Y, X, c, None
    i0 = WI._snow0(self)
    L = np.asarray(self.L, float)
    have = {}
    for k_, (y, x) in enumerate(zip(Y.tolist(), X.tolist())): have[(y, x)] = k_
    c = np.asarray(c, float).copy()
    addY, addX, addC = [], [], []
    rec = []                                          # (y, x, code)
    nn = np.asarray(n, float); nn = nn / max(1e-6, np.linalg.norm(nn))
    back = 1 if float(nn @ R.V) < -0.2 else 0
    for xx in range(w):
        dd = int(d_int[xx])
        if dd < 1: continue
        t0 = int(top[xx]) - int(lift[xx])
        for k_, y in enumerate(range(t0, t0 + dd)):
            x = xx + x0
            v = (k_ + 0.5) / dd
            hx = (xx - (w - 1) / 2) / max(1.0, w / 2)
            nu = 1 - 2 * v
            nx = 0.6 * hx
            nz = math.sqrt(max(0.0, 1 - nx * nx - nu * nu * 0.6))
            d = nx * L[0] + nu * 0.62 + nz * 0.48 + P['lit']
            tn = 5 if d > 0.78 else 4 if d > 0.5 else 3 if d > 0.2 else 2 if d > -0.1 else 1
            tn = max(1, tn - back)
            own = (y, x) in have
            kind = 1
            if k_ == 0 and (not own or c[have[(y, x)]] <= getattr(self, 'last_base', 9) - 1):
                tn = 5 + tn; kind = 2
            if own:
                c[have[(y, x)]] = i0 + tn
            elif y < top[xx]:
                addY.append(y); addX.append(x); addC.append(i0 + tn)
            else:
                continue
            rec.append((y, x, int(ball_code(nx, nu, nz, kind, back, 1))))
        yb = t0 + dd
        if dark and (yb, xx + x0) in have:
            j = have[(yb, xx + x0)]
            if c[j] < i0: c[j] = max(0, c[j] - 1)
    if addY:
        ok = (np.array(addY) >= 0) & (np.array(addY) < self.H)
        Y = np.concatenate([Y, np.array(addY)[ok]]); X = np.concatenate([X, np.array(addX)[ok]])
        c = np.concatenate([c, np.array(addC, float)[ok]])
    return Y, X, c, rec


def frond_snow_code(self, Y, X, c, mod, dark=True):
    """winter23.frond_snow (FROND), each snow pixel's tone under a sun on the frond's upper side's side and not."""
    import winter23 as WI
    P = WI.FROND
    if len(X) == 0: return Y, X, c, None
    f = mod['frond']; X0, Y0 = mod['org']
    rng = random.Random(int(abs(mod['ctr'][0]) * 131 + abs(mod['ctr'][1]) * 17 + abs(mod['ctr'][2]) * 7) + 5)
    fy, fx = Y - Y0, X - X0
    u = f.u[fy, fx]
    ax = np.asarray(f.ax, float)
    nrm = np.array([-ax[1], ax[0]])
    if nrm[1] > 0: nrm = -nrm
    rel = np.stack([fx + 0.5 - f.root[0], fy + 0.5 - f.root[1]], 1)
    off = rel @ nrm
    along = rel @ ax
    amount = 0.6 if mod.get('top') else 1.0
    L_ = max(4.0, f.length)
    nl = max(1, int(round(L_ / P['lump_w'])))
    cs = [L_ * (k + 0.5) / nl + rng.uniform(-1, 1) for k in range(nl)]
    hw = L_ / nl * 0.55 + 0.5
    hang = np.zeros(len(X))
    for cx in cs:
        hang = np.maximum(hang, P['lump'] * rng.uniform(0.6, 1.2) * np.sqrt(np.maximum(0, 1 - ((along - cx) / hw) ** 2)))
    u0 = P['u0'] + rng.uniform(-0.05, 0.08)
    snow = (off > -(P['below'] + hang) * amount) & (np.nan_to_num(u, nan=0.0) > u0)
    if not snow.any(): return Y, X, c, None
    i0 = WI._snow0(self)
    Lv = np.asarray(self.L, float)
    top_off = np.zeros(len(X))
    key = np.round(along).astype(int)
    for k in np.unique(key[snow]):
        m = snow & (key == k)
        top_off[m] = off[m].max()
    lo = -(P['below'] + hang) * amount
    v = np.clip((off - lo) / np.maximum(1.0, top_off - lo), 0, 1)
    sun_side = 1.0 if (nrm[0] * Lv[0]) >= 0 else -1.0
    deep = mod.get('deep', 0.0)
    def tones(side):
        d = 0.75 * (v - 0.35) + 0.25 * np.clip(along / L_, 0, 1) + 0.15 * side + P['lit']
        tn = np.select([d > 0.62, d > 0.38, d > 0.12, d > -0.12], [5, 4, 3, 2], 1)
        if deep < 0: tn = np.maximum(1, tn - 1)
        return tn
    tp, tq = tones(1.0), tones(-1.0)                  # the sun on the frond's upper side's side / not
    tn = tp if sun_side > 0 else tq
    upx = 1 if nrm[0] >= 0 else 0
    c = np.asarray(c, float).copy()
    c[snow] = i0 + tn[snow]
    kind = np.where(snow, 1, 0); TP = tp.copy(); TQ = tq.copy()
    have = {(y, x): k for k, (y, x) in enumerate(zip(Y.tolist(), X.tolist()))}
    ys_s, xs_s = Y[snow], X[snow]
    sset = set(zip(ys_s.tolist(), xs_s.tolist()))
    if dark:
        for y, x in zip(ys_s.tolist(), xs_s.tolist()):
            j = have.get((y + 1, x))
            if j is not None and (y + 1, x) not in sset and c[j] < i0: c[j] = max(0, c[j] - 1)
    addY, addX, addC, rec = [], [], [], []
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
        c[k] = i0 + max(3, int(tn[k]))
        TP[k], TQ[k] = max(3, int(tp[k])), max(3, int(tq[k]))
        for dy in range(1, n_up + 1):
            top_t = 5 if sun_side > 0 else 4
            addY.append(y - dy); addX.append(x); addC.append(i0 + (5 + top_t if dy == n_up else top_t))
            rec.append((y - dy, x, int(frond_code(5, 4, upx, 2 if dy == n_up else 1))))
        if n_up == 0:
            c[k] = i0 + 5 + max(1, int(tn[k]))
            TP[k], TQ[k] = max(1, int(tp[k])), max(1, int(tq[k])); kind[k] = 2
    for k in np.nonzero(snow)[0]:
        rec.append((int(Y[k]), int(X[k]), int(frond_code(TP[k], TQ[k], upx, kind[k]))))
    if addY:
        aY = np.array(addY); ok = (aY >= 0) & (aY < self.H)
        Y = np.concatenate([Y, aY[ok]]); X = np.concatenate([X, np.array(addX)[ok]])
        c = np.concatenate([c, np.array(addC, float)[ok]])
    return Y, X, c, rec


def install_codes():
    """Every class's module_pixels lays the snow (t.snow 'crown' | 'ever') as winter23.install does, through the
    ports above, recording the code of each snow pixel laid into t._rec (H x W, the last one laid wins: the one seen,
    see snow_layer) unless t._dark is False (then no shadow under the snow)."""
    import render7 as R, render17, conifer21, tree123, willow22
    for cls in {R.Tree, render17.Tree, conifer21.Conifer, tree123.Tree, willow22.Willow}:
        if 'module_pixels' not in cls.__dict__ or getattr(cls.__dict__['module_pixels'], '_code', False): continue
        orig = cls.__dict__['module_pixels']
        orig = getattr(orig, '_inner', orig)
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
            dk = getattr(self, '_dark', True)
            if self.snow == 'ever' and 'frond' in mod:
                Y, X, c, rec = frond_snow_code(self, Y, X, c, mod, dk)
            elif self.snow == 'crown':
                Y, X, c, rec = cap2_code(self, Y, X, np.asarray(c, float), np.asarray(n, float), np.asarray(p, float),
                                         self.snow, mod, dk)
            else:
                rec = None
            if rec and getattr(self, '_rec', None) is not None:
                for y, x, cd in rec:
                    if 0 <= y < self.H and 0 <= x < self.W: self._rec[y, x] = cd
            if len(res) == 4:
                return Y, X, c, np.concatenate([res[3], np.zeros(len(Y) - n0, bool)])
            return Y, X, c
        wrapped._code = True; wrapped._inner = orig
        cls.module_pixels = wrapped


def snow_tones(img, t):
    """Per pixel of a rendered picture the SNOW_EXT index of its colour (-1: not snow)."""
    import bare23 as B
    out = np.full(img.shape[:2], -1, int)
    for i, c in enumerate(B.SNOW_EXT):
        out[np.all(img == c, 2)] = i
    return out


# ------------------------------------------------------------------ per look
SUN_R = None


def _sun_r(t):
    import render7 as R
    L = R.norm(R.SUN_R)
    t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
    for a_ in ('_cover', '_shadow_cache'):
        if hasattr(t, a_): setattr(t, a_, None)
    return L


def _classify(img, bark):
    st = np.full(img.shape[:2], -1, int)
    a = img.astype(int)
    for i in range(4):
        st[np.all(a == bark[i], 2)] = i
    return st


def bare16_of(render_k, bark, H, W):
    """The bare layer's bits (export_pr1's: bark steps at the 8 suns, bit 16 wood) from render_k(k) -> image."""
    b16 = np.zeros((H, W), np.int64); bm = np.zeros((H, W), bool)
    for k in range(8):
        st = _classify(render_k(k), bark)
        m = st >= 0
        b16[m] |= st[m] << (2 * k); bm |= m
    return np.where(bm, b16 | (1 << 16), 0).astype(np.uint32)


DARK = 1                     # the code of a leaf (frond) under the snow's edge: a step darker


def leafy_snow(t, render, mode):
    """The snow layer of a crowned look in t's current view: render(t) draws it (the skip set and the dark mass
    fixed beforehand, without snow); t.snow = mode ('crown' | 'ever'). -> (codes, mismatches at the approved sun)."""
    t.snow = mode
    t._rec = np.zeros((t.H, t.W), np.int64)
    _sun_r(t)
    t._dark = True
    img1 = render(t)
    t._dark = False
    img2 = render(t)
    t.snow = None
    rec = t._rec; t._rec = None
    tones = snow_tones(img1, t)
    sm = tones >= 0
    import bare23 as B
    got = tone_of(rec, t.L)
    gc = B.SNOW_EXT[np.clip(got, 0, 15)]
    bad = int((sm & ((got < 0) | np.any(gc != img1, 2))).sum())
    dark = np.any(img1 != img2, 2) & ~sm & (snow_tones(img2, t) < 0)
    code = np.where(sm, rec, 0)
    code[dark] = DARK
    return code, bad, int(sm.sum())


def larch_snow(t, key):
    """The bare larch's snow lumps (winter23.twig2's, as drawn on the approved sheet) in t's current view, each
    hidden where a branch drawn later lies over it. -> codes."""
    import winter23 as WI, bare23 as B
    P = WI.LARCH
    _sun_r(t)
    code = np.zeros((t.H, t.W), np.int64)
    for p, n, mod in t.mods:
        Yb, Xb, cb = __import__('export_pr2').bare_twigs(t, mod)
        code[Yb, Xb] = 0
        if 'frond' not in mod: continue
        for y, x, cd in larch_lumps(t, mod, P):
            if 0 <= y < t.H and 0 <= x < t.W: code[y, x] = cd
    return code


def larch_lumps(t, mod, P):
    """The snow lumps of winter23.twig2 for one frond (the same draws): [(y, x, code)]."""
    f = mod['frond']; X0, Y0 = mod['org']
    rng = random.Random(int(abs(mod['ctr'][0]) * 97 + abs(mod['ctr'][1]) * 13 + abs(mod['ctr'][2]) * 5) + 1)
    if mod.get('deep', 0) < 0 and rng.random() > P['keep_inner']:
        return []
    a = np.array([X0 + f.root[0], Y0 + f.root[1]]); b = np.array([X0 + f.tip[0], Y0 + f.tip[1]])
    if not mod.get('top') and P.get('to_trunk', True):
        a = np.asarray(t.scr(mod['root']), float)
        tl = t.limbs[0]
        tts = np.linspace(0, 1, 60); ys_ = np.array([tl.at(t_)[1] for t_ in tts])
        t_ = float(tts[np.argmin(np.abs(ys_ - mod['root'][1]))])
        a[0] = t.ox + float(tl.at(t_)[0])
    Ln = float(np.linalg.norm(b - a))
    if mod.get('top'):
        ctl = (a + b) / 2; b2 = b
    else:
        sag = P['sag'] * min(Ln, 20.0) + P.get('sag_far', 0.08) * max(0.0, Ln - 20.0)
        ctl = (a + b) / 2 + np.array([0.0, sag])
        b2 = b - np.array([0.0, P['tip_up'] * min(Ln, 24.0)])
    ts = np.linspace(0, 1, int(Ln * 2.5) + 2)
    curve = ((1 - ts) ** 2)[:, None] * a + (2 * ts * (1 - ts))[:, None] * ctl + (ts ** 2)[:, None] * b2
    if not mod.get('top') and Ln > 6:
        for _ in range(rng.randint(*P['side'])):
            rng.uniform(0.3, 0.85); rng.uniform(0.6, 1.0); rng.uniform(2, 4)
    nl = rng.randint(*P['lumps']) if not mod.get('top') else 1
    rk = random.Random(int(abs(mod['ctr'][0]) * 97 + abs(mod['ctr'][1]) * 13 + abs(mod['ctr'][2]) * 5) + 8)
    out = []
    for _ in range(nl):
        t0 = rng.uniform(0.35, 0.95) if not mod.get('top') else 1.0
        k = int(t0 * (len(curve) - 1))
        q = curve[k]
        rb = rng.uniform(*P['r_lump']) * (0.8 + 0.2 * getattr(t, 's', 1.0))
        if not mod.get('top') and rk.random() > P.get('keep', 1.0): continue
        ri = int(math.ceil(rb)) + 1
        yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
        inside = xx * xx + yy * yy <= rb * rb + 0.3
        import bare23 as B
        rim = B.rim_of(inside)
        nx, nu = xx / max(rb, 0.8), -yy / max(rb, 0.8)
        nz = np.sqrt(np.maximum(0, 1 - nx * nx - nu * nu))
        cyy = q[1] - rb * 0.6
        ys, xs = np.nonzero(inside)
        cds = ball_code(nx[ys, xs], nu[ys, xs], nz[ys, xs], np.where(rim[ys, xs], 2, 1), 0, 0)
        for yy_, xx_, cd in zip(ys, xs, cds):
            out.append((int(round(cyy)) + yy_ - ri, int(round(q[0])) + xx_ - ri, int(cd)))
    return out


def _crop(arrs):
    """The box (y0, y1, x0, x1) of what any of the (8, H, W) arrays holds."""
    m = None
    for a in arrs:
        if a is None: continue
        mm = (a != 0).any(0)
        m = mm if m is None else (m | mm)
    ys, xs = np.nonzero(m)
    return int(ys.min()), int(ys.max()) + 1, int(xs.min()), int(xs.max()) + 1


def look(key, s, v):
    """{'bare', 'snow', 'snow_dry'} ((8, H, W) arrays on the build's canvas, None where the look keeps PR 1-3's or has
    none), ox, oy and the checks."""
    import feet25 as F
    F.install()
    install_codes()
    import turn24 as TU, all23 as A, outline23 as O, bare23 as B
    out = dict(bare=None, snow=None, snow_dry=None, bad=0, snowpx=0)
    if key in BARE or key == 'deadwood':
        t = E.build(key, s, v)
        out['ox'], out['oy'] = float(t.ox), float(t.oy)
        bark = np.array(t.bark, int)
        if key == 'deadwood':
            t.twig_info = B.skeleton_info(t)
            kw = dict(B.SNOWK); kw.update(per_mod=0, every=3)
            P = place_balls(t, **kw)
        else:
            t.crown = False
            P = twigged(t)
        snap = TU.snapshot(t)
        bares, snows = [], []
        for n in range(8):
            TU.turn(t, n, snap)
            pos = TU.maps(n, TU.ZSQ, TU.ZSQ)[0]
            if key != 'deadwood':
                bares.append(bare16_of(lambda k: bare_wood(t, key, k), bark, t.H, t.W))
            snows.append(draw_balls(t, P, pos).astype(np.uint16))
        out['bare'] = np.array(bares) if bares else None
        out['snow'] = np.array(snows)
        if key in DRY:
            t = E.build(key, s, v)
            snap = TU.snapshot(t)
            dry = []
            for n in range(8):
                TU.turn(t, n, snap)
                core = t.core()
                vis = t.visibility(core)
                skip = {j for j in range(len(t.mods)) if vis[j] == 0}
                t.core = lambda core=core: core
                code, bad, px = leafy_snow(t, lambda t: t.render(ground=A.KEY_G, shade=A.KEY_S, skip=skip), 'crown')
                del t.__dict__['core']
                dry.append(code.astype(np.uint16)); out['bad'] += bad; out['snowpx'] += px
            out['snow_dry'] = np.array(dry)
    elif key == 'willow':
        import export_pr3 as E3, kinds24 as K, bases22 as B22
        from render2 import hexc
        t = E3.build_willow(s, v)
        out['ox'], out['oy'] = float(t.ox), float(t.oy)
        bark = np.array(t.bark, int)
        t.crown = False
        B.bare_tree(t, **B.TWIG)
        B.weeping(t)
        P = place_balls(t, **B.SNOWK)
        snap = K.willow_snapshot(t)
        bares, snows = [], []
        def wood(k):
            _sun(t, k)
            img = np.zeros((t.H, t.W, 3), np.uint8); img[:] = hexc(A.KEY_G)
            B22.Based.draw_trunk(t, img)
            twig_colours(t, img)
            O.outline(img, 'willow')
            return img
        for n in range(8):
            K.willow_turn(t, n, snap)
            pos = TU.maps(n, TU.ZSQ, TU.ZSQ)[0]
            bares.append(bare16_of(wood, bark, t.H, t.W))
            snows.append(draw_balls(t, P, pos).astype(np.uint16))
        out['bare'] = np.array(bares); out['snow'] = np.array(snows)
        t = E3.build_willow(s, v)
        snap = K.willow_snapshot(t)
        dry = []
        for n in range(8):
            K.willow_turn(t, n, snap)
            E3._sun(t, 0)
            t.render(ground=A.KEY_G, shade=A.KEY_S)
            skip = set(t.skipped)
            core = t.core()
            def rd(t, skip=skip, core=core):
                t._core = core
                return t.render(ground=A.KEY_G, shade=A.KEY_S, skip=skip)
            code, bad, px = leafy_snow(t, rd, 'crown')
            dry.append(code.astype(np.uint16)); out['bad'] += bad; out['snowpx'] += px
        out['snow_dry'] = np.array(dry)
    elif key == 'larch' or key in EVER:
        import export_pr2 as E2, conifer24 as C24
        t = E2.build(key, s, v)
        out['ox'], out['oy'] = float(t.ox), float(t.oy)
        snap = C24.snapshot(t)
        snows = []
        for n in range(8):
            C24.turn(t, n, snap)
            if key == 'larch':
                snows.append(larch_snow(t, key).astype(np.uint16))
                continue
            core = t.core()
            t.core = lambda core=core: core
            code, bad, px = leafy_snow(t, lambda t: t.render(ground=A.KEY_G, shade=A.KEY_S), 'ever')
            del t.__dict__['core']
            snows.append(code.astype(np.uint16)); out['bad'] += bad; out['snowpx'] += px
        out['snow'] = np.array(snows)
    return out


def job(args):
    outd, key, s, v = args
    t0 = time.time()
    r = look(key, s, v)
    y0, y1, x0, x1 = _crop([r['bare'], r['snow'], r['snow_dry']])
    sv = dict(ox=r['ox'], oy=r['oy'], box=np.array([y0, x0]))
    for k in ('bare', 'snow', 'snow_dry'):
        if r[k] is not None: sv[k] = r[k][:, y0:y1, x0:x1]
    os.makedirs(os.path.join(outd, key), exist_ok=True)
    np.savez_compressed(os.path.join(outd, key, '%.2f_%d.npz' % (s, v)), **sv)
    return key, s, v, round(time.time() - t0, 1), r['bad'], r['snowpx']


if __name__ == '__main__':
    outd = sys.argv[1]
    keys = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] else ALL
    nw = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    sizes = [float(x) for x in sys.argv[4].split(',')] if len(sys.argv) > 4 else SIZES
    jobs = [(outd, k, s, v) for k in keys for s in sorted(sizes, reverse=True) for v in range(VARIANTS)]
    jobs = [j for j in jobs if not os.path.exists(os.path.join(outd, j[1], '%.2f_%d.npz' % (j[2], j[3])))]
    with Pool(nw) as p:
        for r in p.imap_unordered(job, jobs):
            print(*r, flush=True)
