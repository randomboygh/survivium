# Round 23 step 2: a bare crown for the winter trees (mockup, no game code). Run from the merged src folder.
# The approved skeleton's limbs end well inside the crown (the leaf modules overhang it), so a bare tree was a short
# pollard. Here the crown's own volume fills with twigs grown out of the approved limbs by space colonisation
# (Runions et al. 2007): attraction points spread through the crown's shape (a little past it, where the modules
# reached), each node grows a step toward the mean direction of the points it is nearest to, a point dies once a
# twig comes close. The twigs' thickness follows the pipe rule from 1 px at the tips; chains between forks become
# limbs of the skeleton, so the skeleton's own drawing lights them, hides them behind nearer limbs and casts them
# on the ground.
import math, numpy as np
from scipy.spatial import cKDTree
from render14 import Limb


class Twig(Limb):
    """A polyline with a radius at each point (one chain of the colonisation, fork to fork)."""
    def __init__(self, pts, rs, seed, level=5):
        self.P = np.asarray(pts, float); self.rs = np.asarray(rs, float)
        self.seed, self.level, self.l0, self.k = seed, level, 0.0, 1.0
        self.r0, self.r1 = float(self.rs[0]), float(self.rs[-1])
        seg = np.linalg.norm(np.diff(self.P, axis=0), axis=1)
        self.cum = np.concatenate([[0.0], np.cumsum(seg)]); self.total = max(1e-6, float(self.cum[-1]))

    def at(self, t):
        s = min(1.0, max(0.0, t)) * self.total
        return np.array([np.interp(s, self.cum, self.P[:, i]) for i in range(3)])

    def r(self, t):
        return float(np.interp(min(1.0, max(0.0, t)) * self.total, self.cum, self.rs))

    def length(self):
        return self.total


def attraction(t, per_mod, mod_r, rng, out=0.35):
    """Points where the crown's leaf modules were: per module per_mod points in an ellipsoid round its centre
    (screen radius mod_r, flat in depth like a module's sprite), pushed a little outward along its normal."""
    pts = []
    for p, n, mod in t.mods:
        n = np.asarray(n, float); n = n / max(1e-6, np.linalg.norm(n))
        c = np.asarray(p, float) + n * mod_r * out
        k = 0
        while k < per_mod:
            q = rng.uniform(-1, 1, 3)
            if q @ q > 1: continue
            pts.append(c + q * np.array([mod_r, mod_r * 0.85, mod_r * 0.45])); k += 1
    A = np.array(pts)
    A[:, 1] += t.cy
    return A


def colonise(t, per_mod=3, mod_r=None, dk=None, di=30.0, step=1.6, up=0.18, seed=5, r_tip=0.5, r_max=None,
             expo=2.4, out=0.35, max_it=500):
    """Grow twigs out of t.limbs through the crown. Returns the new limbs (Twig) and the chains' data."""
    rng = np.random.default_rng(seed)
    s = getattr(t, 's', 1.0)
    mod_r = mod_r if mod_r is not None else 9.0
    dk = dk if dk is not None else 4.0
    A = attraction(t, per_mod, mod_r, rng, out)
    # the skeleton's limbs (not the bare trunk under the crown's foot) as the starting nodes, every ~1.5 px
    lo, hi = t.yrange()
    c_lo = lo + t.cy
    nodes, rad = [], []
    for lb in t.limbs:
        n = max(2, int(lb.length() / 1.5))
        for tt in np.linspace(0, 1, n + 1):
            p = lb.at(tt)
            if lb.level == 0 and p[1] < c_lo - 4: continue
            nodes.append(p); rad.append(float(lb.r(tt)))
    n0 = len(nodes)
    N = np.array(nodes, float)
    parent = [-1] * n0
    UPV = np.array([0.0, 1.0, 0.0])
    for it in range(max_it):
        kd = cKDTree(N)
        d, j = kd.query(A, distance_upper_bound=di)
        alive = d > dk
        A, d, j = A[alive], d[alive], j[alive]
        if len(A) == 0: break
        ok = np.isfinite(d)
        if not ok.any(): break
        js = j[ok]
        v = A[ok] - N[js]; v /= np.linalg.norm(v, axis=1, keepdims=True)
        acc = np.zeros((len(N), 3)); np.add.at(acc, js, v)
        ids = np.unique(js)
        dirs = acc[ids]
        dirs /= np.maximum(1e-9, np.linalg.norm(dirs, axis=1, keepdims=True))
        dirs = dirs + up * UPV + rng.normal(0, 0.12, dirs.shape)
        dirs /= np.maximum(1e-9, np.linalg.norm(dirs, axis=1, keepdims=True))
        new = N[ids] + step * dirs
        dd, _ = kd.query(new)
        keep = dd > step * 0.55
        if not keep.any(): break
        N = np.vstack([N, new[keep]])
        parent += [int(i) for i in ids[keep]]
    parent = np.array(parent)
    n = len(N)
    kids = [[] for _ in range(n)]
    for i in range(n0, n): kids[parent[i]].append(i)
    # thickness by the pipe rule, tips r_tip
    if r_max is None: r_max = 0.75 + 0.75 * s
    S = np.zeros(n)
    r = np.full(n, r_tip)
    for i in range(n - 1, n0 - 1, -1):
        r[i] = max(r_tip, S[i] ** (1 / expo)) if S[i] > 0 else r_tip
        r[i] = min(r[i], r_max)
        S[parent[i]] += r[i] ** expo
    # chains: from a skeleton node or a fork down through single children to a tip or a fork
    limbs, tips, forks = [], [], []
    starts = [i for i in range(n0, n) if parent[i] < n0 or len(kids[parent[i]]) >= 2]
    seed_rng = np.random.default_rng(seed + 1)
    for i0 in starts:
        chain = [i0]
        while len(kids[chain[-1]]) == 1:
            chain.append(kids[chain[-1]][0])
        p0 = parent[i0]
        pts = [N[p0]] + [N[i] for i in chain]
        rs = [min(r[i0] * 1.15, rad[p0] if p0 < n0 else r[p0])] + [r[i] for i in chain]
        P = np.array(pts)
        for _ in range(2):                         # soften the colonisation's steps
            if len(P) > 2: P[1:-1] = 0.25 * P[:-2] + 0.5 * P[1:-1] + 0.25 * P[2:]
        limbs.append(Twig(P, rs, int(seed_rng.integers(0, 999))))
        last = chain[-1]
        (tips if not kids[last] else forks).append((N[last], r[last]))
    return limbs, dict(nodes=N, parent=parent, r=r, n0=n0, tips=tips, forks=forks, kids=kids)


def bare_tree(t, **kw):
    """Add the colonised twigs to a bare tree's skeleton (t.crown is False)."""
    tw, info = colonise(t, **kw)
    t.limbs = list(t.limbs) + tw
    t.twig_info = info
    return t


# ---------------------------------------------------------------- snow on a bare crown, as the reference draws it
# The reference's snowy bare tree (references/user-palms-snow.jpg, right middle row): round snow balls of 4-9 px on
# the forks and twig ends, each with a dark blue-grey outline, white and lit on the sun's side, blue-grey below;
# little 5-px diamonds on some tips; the brown limbs between them.
SNOW = ['40545c', '748898', '88a0a8', 'a8bcc4', 'd0e4e4', 'f0fcfc']
SNOW_RGB = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in SNOW], np.uint8)
# The outline softened (user 2026-11-24 15:58 MSK: «в 2 раза уменьшь контраст обводки снежных комьев»): an outline
# pixel takes the colour between the outline and the tone the snow would have there, contrast / SOFT (as the palms'
# soft outline). Indices into SNOW_EXT: 0..5 the ramp, 5 + t the outline over own tone t (t 1..5), 10 + t the seam
# between two lumps (748898 toward t).
SOFT = 2.0

def snow_ext(soft=None):
    soft = SOFT if soft is None else soft
    base = SNOW_RGB.astype(float)
    out = [c for c in base]
    for t in range(1, 6): out.append(base[t] + (base[0] - base[t]) / soft)
    for t in range(1, 6): out.append(base[t] + (base[1] - base[t]) / soft)
    return np.round(np.array(out)).clip(0, 255).astype(np.uint8)

SNOW_EXT = snow_ext()
VV = np.array([0.0, 1.0, 1.0]) / math.sqrt(2)          # toward the camera
SUP = np.array([0.0, 1.0, -1.0]) / math.sqrt(2)        # screen up on the picture plane


def ball_parts(rb, L, shade=0, lit=0.0, flat=0.82, fx=0.0, fy=0.0):
    """(tone 1..5 without the rim, inside mask, nz, ri) of a ball of radius rb round (0, 0)."""
    ri = int(math.ceil(rb)) + 1
    yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
    ex, ey = (xx - fx), (yy - fy) / flat
    inside = ex * ex + ey * ey <= rb * rb + 0.3
    nx, nu = ex / max(rb, 0.8), -ey / max(rb, 0.8)
    nz = np.sqrt(np.maximum(0, 1 - nx * nx - nu * nu))
    d = nx * L[0] + nu * float(SUP @ L) + nz * float(VV @ L) + lit
    t = np.maximum(np.select([d > 0.78, d > 0.5, d > 0.2, d > -0.1], [5, 4, 3, 2], 1) - shade, 1)
    return t, inside, nz, ri


def rim_of(m):
    """Pixels of the mask m with a 4-neighbour outside it."""
    p = np.pad(m, 1)
    return m & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])


def patch_parts(grp, L, lit, flat, x0, y0, h_, w_, blend=0.5):
    """(inside mask, tone 1..5 without the rim, depth for the tree's z-buffer) over the box (x0, y0, w_, h_) of a
    patch of balls (sx, cy, rb, dep, shade) that stuck together, the light flowing from one into the next (user
    2026-11-24 16:17 MSK: «слипшиеся сделай не только общей обводкой, но и плавным переходом градиента из одного в
    другой»): one surface, the smooth union of the balls (a polynomial smooth min of their distance fields, blend
    width `blend` x their middle radius, all at one depth; a pad flat x as tall as wide, as ball_parts), each pixel
    lit by that surface's normal at its front with ball_parts' steps; one shade step for the whole patch."""
    S = np.array([[b[0], b[1], math.sqrt(b[2] ** 2 + 0.3), b[3] + b[2] * 0.6] for b in grp])
    k = float(np.clip(blend * np.median([b[2] for b in grp]), 0.8, 5.0))
    shade = int(math.floor(np.mean([b[4] for b in grp]) + 0.5))

    def field(x, y, z):
        F = A = None
        for sx, cy, re, vd in S:
            f = np.sqrt((x - sx) ** 2 + ((y - cy) / flat) ** 2 + z * z) - re
            if F is None:
                F, A = f, np.full_like(f, vd)
                continue
            h = np.clip(0.5 + 0.5 * (F - f) / k, 0.0, 1.0)
            F = F + (f - F) * h - k * h * (1 - h)
            A = A + (vd - A) * h
        return F, A

    yy, xx = np.mgrid[y0:y0 + h_, x0:x0 + w_].astype(float)
    m = field(xx, yy, 0.0)[0] <= 0
    xs, ys = xx[m], yy[m]
    lo, hi = np.zeros(len(xs)), np.full(len(xs), S[:, 2].max() + k)
    for _ in range(24):                          # the front of the surface: the field grows with |z|
        mid = (lo + hi) / 2
        ins = field(xs, ys, mid)[0] <= 0
        lo, hi = np.where(ins, mid, lo), np.where(ins, hi, mid)
    z, e = lo, 0.02
    gx = field(xs + e, ys, z)[0] - field(xs - e, ys, z)[0]
    gu = field(xs, ys - e * flat, z)[0] - field(xs, ys + e * flat, z)[0]      # toward screen up, in the pad's units
    gz = field(xs, ys, z + e)[0] - field(xs, ys, z - e)[0]
    g = np.sqrt(gx * gx + gu * gu + gz * gz) + 1e-12
    nx, nu, nz = gx / g, gu / g, np.maximum(0.0, gz / g)
    d = nx * L[0] + nu * float(SUP @ L) + nz * float(VV @ L) + lit
    tone = np.zeros((h_, w_), int); vdep = np.zeros((h_, w_))
    tone[m] = np.maximum(np.select([d > 0.78, d > 0.5, d > 0.2, d > -0.1], [5, 4, 3, 2], 1) - shade, 1)
    vdep[m] = field(xs, ys, z)[1]
    return m, tone, vdep


def patch_soft(grp, L, lit, flat, x0, y0, h_, w_, tau=2.0):
    """As patch_parts, but each ball keeps its own shape and bulge (the patch's outline is the union of the balls'
    pads, as before): the balls sit at one depth and a pixel is lit by the normals of all the balls over it, each
    weighted by how near its surface is to the front one there (exp((h - h_front) / tau), h a ball's height over
    the pixel), so where one ball runs into the next the light goes over smoothly in a band of a few pixels."""
    yy, xx = np.mgrid[y0:y0 + h_, x0:x0 + w_].astype(float)
    shade = int(math.floor(np.mean([b[4] for b in grp]) + 0.5))
    m = np.zeros((h_, w_), bool); hmax = np.full((h_, w_), -1e9); parts = []
    for sx, cy, rb, dep, _ in grp:
        ex, ey = xx - sx, (yy - cy) / flat
        r2 = ex * ex + ey * ey
        ins = r2 <= rb * rb + 0.3
        h = np.sqrt(np.maximum(0.0, rb * rb - r2))
        nx, nu = ex / max(rb, 0.8), -ey / max(rb, 0.8)
        nz = np.sqrt(np.maximum(0.0, 1 - nx * nx - nu * nu))
        parts.append((ins, h, nx, nu, nz, dep + rb * 0.6))
        m |= ins; hmax = np.where(ins, np.maximum(hmax, h), hmax)
    sx_ = su = sz = sw = sv = 0.0
    for ins, h, nx, nu, nz, vd in parts:
        w = np.where(ins, np.exp(np.minimum(0.0, h - hmax) / tau), 0.0)
        sx_ = sx_ + w * nx; su = su + w * nu; sz = sz + w * nz; sw = sw + w; sv = sv + w * vd
    g = np.sqrt(sx_ * sx_ + su * su + sz * sz) + 1e-12
    d = (sx_ * L[0] + su * float(SUP @ L) + sz * float(VV @ L)) / g + lit
    tone = np.where(m, np.maximum(np.select([d > 0.78, d > 0.5, d > 0.2, d > -0.1], [5, 4, 3, 2], 1) - shade, 1), 0)
    return m, tone, np.where(m, sv / np.maximum(sw, 1e-12), 0.0)


def ball_tones(rb, L, shade=0, lit=0.0, flat=0.82, fx=0.0, fy=0.0):
    """Tone (0..5) per pixel of a ball of radius rb drawn round (0, 0) (a pad: its height flat x its width; fx, fy
    the centre's sub-pixel place): -1 outside. Lit by the sun L."""
    ri = int(math.ceil(rb)) + 1
    yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
    ex, ey = (xx - fx), (yy - fy) / flat
    dd = ex * ex + ey * ey
    inside = dd <= rb * rb + 0.3
    nx, nu = ex / max(rb, 0.8), -ey / max(rb, 0.8)
    nz = np.sqrt(np.maximum(0, 1 - nx * nx - nu * nu))
    d = nx * L[0] + nu * float(SUP @ L) + nz * float(VV @ L)
    d = d + lit
    t = np.select([d > 0.78, d > 0.5, d > 0.2, d > -0.1], [5, 4, 3, 2], 1) - shade
    t = np.maximum(t, 1)
    # the rim: a pixel of the ball with a 4-neighbour outside it
    rim = np.zeros_like(inside)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = np.zeros_like(inside)
        sl_d = (slice(max(0, dy), inside.shape[0] + min(0, dy)), slice(max(0, dx), inside.shape[1] + min(0, dx)))
        sl_s = (slice(max(0, -dy), inside.shape[0] + min(0, -dy)), slice(max(0, -dx), inside.shape[1] + min(0, -dx)))
        nb[sl_s] = inside[sl_d]
        rim |= inside & ~nb
    t = np.where(rim, 5 + t, t)                        # the soft outline over the ball's own tone
    return np.where(inside, t, -1), ri


def zbuffer(t, rmin=0.0):
    """Depth (toward the camera) of the skeleton's discs of radius >= rmin; -inf where none."""
    H, W = t.H, t.W
    zb = np.full((H, W), -1e9)
    for p, r, tan, l, j in t._samples():
        if r < rmin: continue
        sx, sy = t.proj_abs(p)
        ri = int(math.ceil(r)) + 1
        yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
        ok = xx * xx + yy * yy <= r * r + 0.3
        Y, X = yy[ok] + int(round(sy)), xx[ok] + int(round(sx))
        k = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        np.maximum.at(zb, (Y[k], X[k]), float(p @ VV) + r)
    return zb


def snow_balls(t, img, kg, ks, seed=7, r_lo=None, r_hi=None, gap=0.6, share=1.0, tiny=0.6, every=3.0, lit=0.0,
               flat=0.8, per_mod=0, back=1, size=1.0, merge=0.0, touch=0.92, keep=1.0, blend=0.0, soft=0.0):
    """Snow balls on the forks of a bare crown and along its level twigs (t.twig_info from colonise), as the
    reference's clumps: drawn far to near, each with its outline; a little diamond on some of the bare tips."""
    rng = np.random.default_rng(seed)
    s = getattr(t, 's', 1.0)
    L = np.asarray(t.L, float)
    r_lo = (r_lo if r_lo is not None else 1.8 + 1.2 * s) * size
    r_hi = (r_hi if r_hi is not None else 2.8 + 2.6 * s) * size
    info = t.twig_info
    lo, hi = t.yrange(); c_lo, c_hi = lo + t.cy, hi + t.cy
    N, parent, n0, kids = info['nodes'], info['parent'], info['n0'], info['kids']
    cands = []                                   # (priority, point, kind)
    for i in range(n0, len(N)):
        p = N[i]; q = N[parent[i]]
        d = p - q; d = d / max(1e-6, np.linalg.norm(d))
        nk = len(kids[i])
        if nk >= 2: kind, pr = 'fork', 1.0
        elif nk == 0: kind, pr = 'tip', 0.35
        else:
            if rng.random() > 1.0 / every: continue
            if d[1] > 0.8: continue              # steep twigs hold little snow
            kind, pr = 'on', 0.6
        cands.append((pr + 0.25 * (p[1] - c_lo) / max(1, c_hi - c_lo) + rng.normal(0, 0.18), p, kind))
    if per_mod:                                  # clumps where the leaf modules were, on the twig nearest each
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
        if any((sx - x) ** 2 + (cy_ - y) ** 2 < (gap * (rb + r2)) ** 2 for x, y, r2, _, _ in placed):
            if kind == 'tip': tips_left.append(p)
            continue
        hrel = (p[1] - c_lo) / max(1.0, c_hi - c_lo)
        shade = 1 if hrel < 0.25 else 0
        if back and p[2] < -6: shade = min(2, shade + back)
        placed.append((sx, cy_, rb, float(p @ VV), shade))
    n_big = len(placed)
    for p in tips_left:                          # little diamonds on some of the other tips
        if rng.random() < tiny:
            sx, sy = t.proj_abs(p)
            if all((sx - x) ** 2 + (sy - 1 - y) ** 2 >= (r2 + 1.2) ** 2 for x, y, r2, _, _ in placed):
                placed.append((sx, sy - 1, 2.1, float(p @ VV), 0))
    if keep < 1.0:                               # fewer lumps of the same size (user 2026-11-24 16:22 MSK: «размер
        r2 = np.random.default_rng(seed + 101)   # оставить, количество уменьшить»); the little diamonds all stay
        placed = [b for i, b in enumerate(placed) if i >= n_big or r2.random() < keep]
    zb = zbuffer(t, rmin=1.4)                    # limbs thick enough to hide snow behind them
    H, W = img.shape[:2]
    # some neighbours that touch merge into one patch (user 2026-11-24 16:04 MSK: «чтобы некоторые объединялись в
    # пятна»): one outline round the patch, each pixel lit by the ball whose surface is in front there
    n = len(placed)
    up_ = list(range(n))
    def root(a):
        while up_[a] != a: up_[a] = up_[up_[a]]; a = up_[a]
        return a
    for a in range(n):
        for b in range(a + 1, n):
            xa, ya, ra, _, _ = placed[a]; xb, yb, rb_, _, _ = placed[b]
            if min(ra, rb_) < 2.2: continue                 # the little diamonds stay apart
            if (xa - xb) ** 2 + (ya - yb) ** 2 < (touch * (ra + rb_)) ** 2 and rng.random() < merge:
                up_[root(a)] = root(b)
    groups = {}
    for a in range(n): groups.setdefault(root(a), []).append(placed[a])
    snow = np.zeros((H, W), bool)
    for grp in sorted(groups.values(), key=lambda g: max(b[3] for b in g)):
        x0 = int(math.floor(min(b[0] - b[2] for b in grp))) - 3; x1 = int(math.ceil(max(b[0] + b[2] for b in grp))) + 3
        y0 = int(math.floor(min(b[1] - b[2] for b in grp))) - 3; y1 = int(math.ceil(max(b[1] + b[2] for b in grp))) + 3
        h_, w_ = y1 - y0 + 1, x1 - x0 + 1
        if len(grp) > 1 and soft > 0:
            m, tone, vdep = patch_soft(grp, L, lit, flat, x0, y0, h_, w_, soft)
        elif len(grp) > 1 and blend > 0:
            m, tone, vdep = patch_parts(grp, L, lit, flat, x0, y0, h_, w_, blend)
        else:
            front = np.full((h_, w_), -1e9); tone = np.zeros((h_, w_), int); vdep = np.zeros((h_, w_))
            for sx, cy_, rb, dep, shade in grp:
                tt, ins, nz, ri = ball_parts(rb, L, shade, lit, flat if rb > 2.2 else 1.0, sx - round(sx),
                                             cy_ - round(cy_))
                oy_, ox_ = int(round(cy_)) - ri - y0, int(round(sx)) - ri - x0
                sl = (slice(oy_, oy_ + tt.shape[0]), slice(ox_, ox_ + tt.shape[1]))
                f = np.where(ins, dep + rb * nz, -1e9)
                w = f > front[sl]
                front[sl] = np.where(w, f, front[sl]); tone[sl] = np.where(w, tt, tone[sl])
                vdep[sl] = np.where(w, dep + rb * 0.6, vdep[sl])
            m = front > -1e8
        tv = np.where(rim_of(m), 5 + tone, tone)          # the soft outline round the whole patch
        ys, xs = np.nonzero(m)
        Y, X = ys + y0, xs + x0
        k_ = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        ys, xs, Y, X = ys[k_], xs[k_], Y[k_], X[k_]
        vis = zb[Y, X] <= vdep[ys, xs]
        ys, xs, Y, X = ys[vis], xs[vis], Y[vis], X[vis]
        v = tv[ys, xs]
        v = np.where((v >= 6) & snow[Y, X], v + 5, v)      # the blue-grey seam where it lies over another patch
        img[Y, X] = SNOW_EXT[v]
        snow[Y, X] = True
    t.snow_mask = snow
    return img


TWIG = dict(per_mod=6, mod_r=10, r_tip=0.75, expo=2.0, out=0.1)
# ball radii 1.8 + 1.2 s .. 2.8 + 2.6 s, x1.4 (user 2026-11-24 16:04 MSK: «процентов на 30-50 крупнее»), half of
# the touching neighbours merge into patches
# a quarter fewer of them, the same size (user 16:22 MSK); a patch is one smooth surface (user 16:17 MSK)
SNOWK = dict(flat=0.92, gap=0.45, per_mod=3, lit=0.25, every=2, size=1.4, merge=0.5, keep=0.75, soft=1.5)


def render_bare(key, s, G='ff00ff', S='00ffff', twig=None, snow=None, with_snow=True, colours=None):
    """A species' bare winter tree: the approved tree without leaves, the colonised twigs, the snow balls."""
    import winter23 as W
    t, _ = W.build(key, s, 'bare')
    bare_tree(t, **(twig or TWIG))
    img = t.render(ground=G, shade=S)
    if colours is not False:
        twig_colours(t, img, **(colours or {}))
    if with_snow:
        import render7 as R
        snow_balls(t, img, np.array(R.hexc(G)), np.array(R.hexc(S)), **(snow or SNOWK))
    return img


def owner(t):
    """Per pixel the skeleton limb on top (-1 none) and its radius there (the same depth rule as the drawing)."""
    H, W = t.H, t.W
    zb = np.full((H, W), -1e9); own = np.full((H, W), -1, int); rad = np.zeros((H, W))
    for p, r, tan, l, j in t._samples():
        sx, sy = t.proj_abs(p)
        ri = int(math.ceil(r)) + 1
        yy, xx = np.mgrid[-ri:ri + 1, -ri:ri + 1]
        fx, fy = xx + (round(sx) - sx), yy + (round(sy) - sy)
        ok = fx * fx + fy * fy <= r * r + 0.3
        Y, X = yy[ok] + int(round(sy)), xx[ok] + int(round(sx))
        dep = float(p @ VV) + r * np.sqrt(np.maximum(0, 1 - (fx[ok] ** 2 + fy[ok] ** 2) / max(r * r, 0.25)))
        k = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        Y, X, dep = Y[k], X[k], dep[k]
        w = dep > zb[Y, X]
        zb[Y[w], X[w]] = dep[w]; own[Y[w], X[w]] = j; rad[Y[w], X[w]] = r
    return own, rad


def twig_colours(t, img, thin=1, top=2, body=1, rmax=1.6):
    """Recolour the colonised twigs (thinner than rmax) in the bark ramp: 1-px twigs `thin`, wider ones their top
    pixel `top` (lit) over `body`."""
    own, rad = owner(t)
    tw = np.array([isinstance(lb, Twig) for lb in t.limbs] + [False])
    m = tw[own] & (own >= 0) & (rad < rmax)
    bark = np.array(t.bark)
    above = np.roll(own, 1, 0)
    below = np.roll(own, -1, 0)
    wide = (rad >= 0.85)
    c = np.where(wide & (above != own), top, np.where(wide, body, thin))
    c = np.where(wide & (above == own) & (below != own), max(0, body - 1) if body > 0 else 0, c)
    img[m] = bark[c[m]]
    return img


def skeleton_info(t, step=2.0):
    """t.twig_info built from the skeleton itself (no colonised twigs: the dead tree keeps its own limbs): nodes
    every `step` px along each limb of level >= 1, each linked to the one before; a limb's first node hangs on the
    nearest node of the limbs before it (a fork)."""
    nodes, parent = [np.zeros(3)], [-1]          # node 0: a dummy root (n0 = 1)
    for lb in t.limbs:
        if lb.level < 1: continue
        n = max(2, int(lb.length() / step))
        prev = None
        for tt in np.linspace(0, 1, n + 1):
            p = lb.at(tt)
            if prev is None:
                if len(nodes) > 1:
                    d = np.linalg.norm(np.array(nodes) - p, axis=1); d[0] = 1e9
                    prev = int(d.argmin())
                else:
                    prev = 0
            nodes.append(p); parent.append(prev); prev = len(nodes) - 1
    N = np.array(nodes); parent = np.array(parent)
    kids = [[] for _ in range(len(N))]
    for i in range(1, len(N)): kids[parent[i]].append(i)
    tips = [(N[i], 0.5) for i in range(1, len(N)) if not kids[i]]
    forks = [(N[i], 0.5) for i in range(1, len(N)) if len(kids[i]) >= 2]
    return dict(nodes=N, parent=parent, r=np.full(len(N), 0.5), n0=1, tips=tips, forks=forks, kids=kids)


def render_dead(key, s, G='ff00ff', S='00ffff', snow=None):
    """The dead tree in winter: its own bare limbs (no new twigs), snow balls on their forks, ends and level runs."""
    import winter23 as W, render7 as R
    t, _ = W.build(key, s, 'bare')
    t.twig_info = skeleton_info(t)
    img = t.render(ground=G, shade=S)
    kw = dict(SNOWK); kw.update(per_mod=0, every=3)
    kw.update(snow or {})
    snow_balls(t, img, np.array(R.hexc(G)), np.array(R.hexc(S)), **kw)
    return img


def weeping(t, share=0.55, k_len=(0.45, 0.8), seed=9):
    """A bare willow's hanging twigs: from a share of the upper tips a thin twig arcs outward and hangs down,
    nearly to the ground for the long ones (the summer willow's strands reach depth 54 of its crown)."""
    rng = np.random.default_rng(seed)
    info = t.twig_info
    lo, hi = t.yrange(); c_lo, c_hi = lo + t.cy, hi + t.cy
    out = []
    for p, r in info['tips']:
        hrel = (p[1] - c_lo) / max(1.0, c_hi - c_lo)
        if hrel < 0.25 or rng.random() > share: continue
        o = np.array([p[0], 0.0, p[2]]); o = o / max(1e-6, np.linalg.norm(o))
        drop = (p[1] - 4) * rng.uniform(*k_len)
        n = max(4, int(drop / 2))
        pts = [p]
        for i in range(1, n + 1):
            f = i / n
            out_k = 3.0 * math.sin(min(1.0, f * 3) * math.pi / 2)        # arcs out first, then hangs
            pts.append(p + o * out_k + np.array([rng.normal(0, 0.15), -drop * f ** 1.15, 0.0]))
        out.append(Twig(np.array(pts), [0.5] * len(pts), int(rng.integers(0, 999)), level=6))
    t.limbs = list(t.limbs) + out
    return out
