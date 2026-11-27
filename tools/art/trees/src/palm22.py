# Round 22: two palms after references/user-palms-snow.jpg (the user's upload; left column: top row = a fan palm
# with broad rounded leaves, middle row = a feather palm with long pointed fronds). The JPG is pixel art x4
# (palm_down2.py: ref/<name>.npy = art pixels of each sprite).
#
# A palm leaf is a 3D blade growing from the crown's centre: azimuth, length, a width profile (fan: an oval paddle on
# a short stalk; feather: a lance with a long pointed tip and leaflet teeth), an elevation that bends from the root to
# the tip (droop), a convex cross-section (the edges bend down: the reference shades its leaves like cushions).
# It is sampled densely, projected with the game's oblique view (screen y = ZS z - y; the game draws z and height
# 1:1, the reference's crowns fit ZS 0.9) at 4x, and a pixel belongs to the leaf where it covers half of it.
# The pixels are then drawn by the reference's rules (read off its big fan palm, palm_letters.py):
#   outline to the background = step 0 (the reference's darkest green, whatever the light);
#   a leaf's edge over a leaf drawn before it (a seam) = b - 2;
#   rim (one pixel inside its own outline) = b - 1, but b on the edges turned to the light;
#   ring = b; core (farther than `ring` px from its outline) = b + 1 on lit leaves (the highlight), b on shaded ones;
#   midrib = b (a line one step under the core, from the root to near the tip); the base near the crown's centre -1.
# b = the leaf's step from its middle normal . sun in bands (the leaf modules' d1 / d2), the lower layer of leaves one
# step darker (in the shade of the upper one). Steps index a 7-colour ramp (0 darkest .. 6 lightest).
import math
import numpy as np
from scipy import ndimage as ndi

UP = np.array([0.0, 1.0, 0.0])
ZS = 0.9
SS = 4                      # supersampling of the coverage


def unit(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


class Leaf:
    def __init__(self, phi, L, W, e0, e1, q=1.6, arch=0.3, fold=0.0, layer=0, kind='fan', r0=1.5,
                 sw=None, g0=0.18, tipk=None, roll=0.0, base=None, teeth=0, seed=0, gk=0.8, tooth_depth=0.55,
                 tooth_from=0.3):
        """phi: azimuth in degrees (0 = right, 90 = away from the viewer, 270 = toward him); L: length (px along the
        blade); W: half width at the widest; e0 / e1: elevation (deg) at the root / at the tip, bending as s^q;
        arch: the edges lower than the midrib by arch x half width (a convex cross-section); fold: the edges higher
        by fold x |v| x half width (a V trough); layer 0 = upper (drawn over), 1 = lower; base: a fixed step (the
        reference's pose), else from the sun."""
        self.phi, self.L, self.W, self.e0, self.e1, self.q = phi, L, W, e0, e1, q
        self.arch, self.fold, self.layer, self.kind, self.r0 = arch, fold, layer, kind, r0
        self.sw = sw if sw is not None else (0.55 if kind == 'fan' else 0.36)
        self.g0, self.roll, self.base, self.teeth, self.seed, self.gk = g0, roll, base, teeth, seed, gk
        self.tooth_depth, self.tooth_from = tooth_depth, tooth_from
        self.tipk = tipk if tipk is not None else (0.5 if kind == 'fan' else 1.15)

    def width(self, s):
        """Half width along the blade, 0..1 x W."""
        s = np.asarray(s, float)
        a = np.clip(s / self.sw, 0, 1)
        up = self.g0 + (1 - self.g0) * np.sin(a * math.pi / 2) ** self.gk
        b = np.clip((s - self.sw) / (1 - self.sw), 0, 1)
        if self.kind == 'fan':
            down = np.maximum(0.0, 1 - b ** 2) ** self.tipk          # a round end
        else:
            down = np.maximum(0.0, 1 - b) ** self.tipk                # a long point
        return np.where(s <= self.sw, up, down)

    def axis(self, C, s):
        ph = math.radians(self.phi)
        h = np.array([math.cos(ph), 0.0, -math.sin(ph)])
        th = np.radians(self.e0 + (self.e1 - self.e0) * s ** self.q)
        tang = np.cos(th)[:, None] * h + np.sin(th)[:, None] * UP
        ds = np.diff(s, prepend=s[0]) * self.L
        P = np.asarray(C, float) + self.r0 * h + np.cumsum(tang * ds[:, None], 0)
        n0 = -np.sin(th)[:, None] * h + np.cos(th)[:, None] * UP
        return P, tang, n0, h

    def surface(self, C, ns, nv):
        s = np.linspace(0.0, 1.0, ns)
        v = np.linspace(-1.0, 1.0, nv)
        P, tang, n0, h = self.axis(C, s)
        c = np.array([math.sin(math.radians(self.phi)), 0.0, math.cos(math.radians(self.phi))])   # across, level
        if self.roll:                                             # the blade turned about its axis
            r = math.radians(self.roll)
            cs = math.cos(r) * c[None, :] + math.sin(r) * n0
            n0 = -math.sin(r) * c[None, :] + math.cos(r) * n0
        else:
            cs = np.repeat(c[None, :], ns, 0)
        w = self.W * self.width(s)
        if self.teeth:                                            # leaflet tips: the edge notched toward the tip
            ph = np.random.default_rng(self.seed).uniform(0, 1, 2)
            out = []
            for side in (0, 1):
                k = np.clip((s - self.tooth_from) / (1 - self.tooth_from), 0, 1) ** 0.7
                saw = (s * self.teeth + ph[side]) % 1.0
                out.append(1 - k * self.tooth_depth * np.maximum(0, saw - 0.3) / 0.7)
            wt = np.where(v[None, :] < 0, out[0][:, None], out[1][:, None])
        else:
            wt = np.ones((ns, nv))
        ww = w[:, None] * wt                                      # (ns, nv) half widths
        off_c = v[None, :] * ww
        off_n = (self.fold * np.abs(v)[None, :] - self.arch * (v ** 2)[None, :]) * ww
        Q = P[:, None, :] + off_c[..., None] * cs[:, None, :] + off_n[..., None] * n0[:, None, :]
        return s, v, Q


def normals(Q):
    dS = np.gradient(Q, axis=0)
    dV = np.gradient(Q, axis=1)
    N = np.cross(dV, dS)
    n = np.linalg.norm(N, axis=-1, keepdims=True)
    N = N / np.maximum(n, 1e-9)
    N = np.where(N[..., 1:2] < 0, -N, N)                          # the upper side
    return N


class Crown:
    def __init__(self, leaves, W=120, H=110, ox=None, oy=None, C=(0.0, 0.0, 0.0), zs=ZS):
        self.leaves = leaves
        self.Wimg, self.Himg = W, H
        self.ox = W / 2 if ox is None else ox
        self.oy = H / 2 if oy is None else oy
        self.C = np.array(C, float)
        self.zs = zs

    def proj(self, Q):
        return self.ox + Q[..., 0], self.oy + self.zs * Q[..., 2] - Q[..., 1]

    def raster(self, leaf):
        """Per pixel of one leaf: coverage (0..1) and the nearest sample's s, v, normal, depth."""
        Wp = self.Wimg
        ns = int(leaf.L * 2.2 * SS) + 8
        nv = int(leaf.W * 2 * 2.2 * SS) + 8
        s, v, Q = leaf.surface(self.C, ns, nv)
        N = normals(Q)
        X, Y = self.proj(Q)
        D = self.zs * Q[..., 1] + Q[..., 2]
        sx = np.floor(X * SS).astype(int).ravel()
        sy = np.floor(Y * SS).astype(int).ravel()
        ok = (sx >= 0) & (sy >= 0) & (sx < Wp * SS) & (sy < self.Himg * SS)
        key = np.unique(sy[ok] * (Wp * SS) + sx[ok])
        cov = np.zeros((self.Himg, Wp))
        np.add.at(cov, ((key // (Wp * SS)) // SS, (key % (Wp * SS)) // SS), 1.0 / SS ** 2)
        px = np.floor(X).astype(int).ravel()
        py = np.floor(Y).astype(int).ravel()
        Sg = np.broadcast_to(s[:, None], X.shape).ravel()
        Vg = np.broadcast_to(v[None, :], X.shape).ravel()
        Dg = D.ravel()
        ok = (px >= 0) & (py >= 0) & (px < Wp) & (py < self.Himg)
        o = np.argsort(Dg[ok])                                    # far first: the nearest sample is written last
        idx = np.nonzero(ok)[0][o]
        att = {k: np.full((self.Himg, Wp), np.nan) for k in ('s', 'v', 'd')}
        nrm = np.full((self.Himg, Wp, 3), np.nan)
        att['s'][py[idx], px[idx]] = Sg[idx]
        att['v'][py[idx], px[idx]] = Vg[idx]
        att['d'][py[idx], px[idx]] = Dg[idx]
        nrm[py[idx], px[idx]] = N.reshape(-1, 3)[idx]
        return cov, att, nrm

    def mask(self, cov, att, lim=0.5):
        m = (cov >= lim) & ~np.isnan(att['s'])
        # pixel-art clean-up: no spurs (pixels with one 4-neighbour), no pinholes
        for _ in range(2):
            nb = ndi.convolve(m.astype(int), np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]), mode='constant')
            m &= nb >= 2
        m = ndi.binary_fill_holes(m)
        return m


def edge_dist(m):
    """Chamfer distance (in px, 4-steps) from the outside of a mask: 1 on its edge pixels."""
    return ndi.distance_transform_cdt(np.pad(m, 1), metric='taxicab')[1:-1, 1:-1]


def axis_pixels(crown, leaf, s0=0.06, s1=0.88):
    """The midrib: the blade's axis on the screen as a clean 1-px line (8-connected, no L corners)."""
    s = np.linspace(s0, s1, int(leaf.L * 8) + 4)
    P, _, _, _ = leaf.axis(crown.C, s)
    X, Y = crown.proj(P)
    pts = []
    for x, y in zip(np.floor(X).astype(int), np.floor(Y).astype(int)):
        if not pts or pts[-1] != (y, x): pts.append((y, x))
    out = []
    for i, p in enumerate(pts):            # drop a corner pixel between two 4-neighbours that touch diagonally
        if 0 < i < len(pts) - 1:
            a, b = pts[i - 1], pts[i + 1]
            if abs(a[0] - b[0]) == 1 and abs(a[1] - b[1]) == 1 and out and out[-1] == a:
                continue
        out.append(p)
    return out, s


FROND_BANDS = ((0.8, 5), (0.5, 4), (0.2, 3), (-0.15, 2))   # conifer21's: a frond darkens its edges, half and root


def leaf_base(leaf, crown, Lsun, d1=0.64, d2=0.36):
    """A leaf's step from its middle normal . sun, the lower layer one darker: a fan leaf in the leaf modules'
    bands (it adds a light core), a frond one band higher (conifer21's: it darkens its edges, half and root)."""
    if leaf.base is not None: return leaf.base, None
    _, _, Q = leaf.surface(crown.C, 3, 3)
    N = normals(Q)[1, 1]
    d = float(N @ Lsun)
    if leaf.kind == 'fan':
        b = 4 if d > d1 else (3 if d > d2 else 2)
    else:
        b = 1
        for lim, bb in FROND_BANDS:
            if d > lim: b = bb; break
    return b - leaf.layer, d


def draw(crown, Lsun=None, ring=4, seam=2, dark_base=(0.12, 0.3), core_plus=1, mid_dark=0, heart=None, split=True,
         split_off=0.1, feather_drop=2.5, feather_exp=1.4, feather_base=(0.12, 0.3), core_inner=None, verbose=False,
         extra=None):
    """Steps per pixel (float; -9 = empty) and the leaf drawn on each pixel. Leaves are drawn lower layer first,
    far to near; then each leaf's own edge pixels become the outline (to the background), a seam (over a leaf
    drawn before it) or its rim (where a later leaf covers it)."""
    H, W = crown.Himg, crown.Wimg
    Lsun = unit(Lsun if Lsun is not None else (0.6, 0.75, -0.1))
    steps = np.full((H, W), -9.0)
    owner = np.full((H, W), -1)
    rank = np.full(len(crown.leaves), -1)
    if heart is not None:                    # the dark middle where the leaves meet (no gap through the crown)
        r, st = heart
        Y, X = np.mgrid[0:H, 0:W]
        cx, cy = crown.proj(crown.C)
        hm = ((X + 0.5 - cx) / r) ** 2 + ((Y + 0.5 - cy) / (r * 0.8)) ** 2 <= 1
        steps[hm] = st
    info = []
    def depth(i):
        lf = crown.leaves[i]
        P, _, _, _ = lf.axis(crown.C, np.array([0.0, 0.6]))
        return float(crown.zs * P[-1, 1] + P[-1, 2])
    order = sorted(range(len(crown.leaves)), key=lambda i: (-crown.leaves[i].layer, depth(i)))
    for r, i in enumerate(order):
        lf = crown.leaves[i]
        cov, att, nrm = crown.raster(lf)
        m = crown.mask(cov, att, 0.5 if lf.kind == 'fan' else 0.42)
        b, d = leaf_base(lf, crown, Lsun)
        de = edge_dist(m)
        # light-facing pixels: the cushion's normal turned toward the sun more than the leaf's middle
        _, _, Qm = lf.surface(crown.C, 3, 3)
        nmid = normals(Qm)[1, 1]
        lfac = np.nan_to_num((nrm @ Lsun) - float(nmid @ Lsun))
        t = np.full((H, W), float(b))
        t[de == 2] = b - 1
        t[(de == 2) & (lfac > 0.04)] = b
        core = np.where(lfac > 0.0, de >= 3, de > ring)
        # the half of the blade turned away from the sun one step darker (the reference's leaves are lit on the
        # half toward the light, like 124's fronds), unless the blade points along the light
        ph = math.radians(lf.phi)
        cdir = np.array([math.sin(ph), 0.0, math.cos(ph)])
        cl = float(cdir @ Lsun)
        far = np.zeros((H, W), bool)
        if split and abs(cl) > 0.12:
            far = np.nan_to_num(att['v']) * np.sign(cl) < -split_off
        if lf.kind == 'fan':                 # the core keeps away from the round end too
            core &= att['s'] < 0.93
        if lf.kind != 'fan':
            pass
        elif split == 'ring':                  # the far half: a wider ring (the core keeps to the lit half)
            core &= ~(far & (de <= ring + 3))
            t[core] = b + core_plus
            if core_inner is not None:         # a half-step core with a full step in its middle
                t[core & (de >= ring + core_inner) & ~far] = b + 1
            t[far & (de == 2)] = b - 1
        else:
            t[core] = b + core_plus
            t[far & (de >= 2)] -= 1
        if lf.kind == 'fan':
            mid, _ = axis_pixels(crown, lf)
            for (y, x) in mid:
                if 0 <= y < H and 0 <= x < W and m[y, x] and de[y, x] >= 2:
                    t[y, x] = b - mid_dark
        else:
            # a frond is shaded smoothly across: its midrib is the lit ridge (the reference's lightest stripe),
            # its edges two and a half steps under it, the half turned away half a step darker, the tip darker;
            # half steps are drawn as the mean of two ramp colours
            av = np.abs(np.nan_to_num(att['v']))
            t = b + 1 - feather_drop * av ** feather_exp
            t = np.where(far, t - 0.5, t)
            sgn = np.nan_to_num(att['s'])
            t = np.where(sgn > 0.86, t - 1, t)
            t = np.round(t * 2) / 2
        sg = att['s']
        db = dark_base if lf.kind == 'fan' else feather_base
        t[(sg < db[1]) & m] -= 1
        t[(sg < db[0]) & m] -= 1
        if d is not None:                      # the palest step only where the leaf faces the sun squarely
            t = np.minimum(t, 6 if d > (0.92 if lf.kind != 'fan' else 0.85) else 5)
        steps[m] = t[m]
        owner[m] = i
        rank[i] = r
        info.append((i, de == 1, m, b))
        if verbose: print('leaf %d phi %.0f layer %d base %s d %s' % (i, lf.phi, lf.layer, b, None if d is None else round(d, 2)))
    # edges, once everything is drawn (extra, a dict: gets 'pre' = the steps before the edges and 'out' = the
    # outline pixels, for a softer outline mixed toward each pixel's own colour)
    out = steps.copy()
    outm = np.zeros((H, W), bool)
    for i, e1, m, b in info:
        ys, xs = np.nonzero(e1 & (owner == i))
        for y, x in zip(ys, xs):
            kind = 'rim'
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                yy, xx = y + dy, x + dx
                if not (0 <= yy < H and 0 <= xx < W) or owner[yy, xx] < 0:
                    kind = 'out'; break
                if m[yy, xx]: continue
                if rank[owner[yy, xx]] < rank[i]: kind = 'seam'
            out[y, x] = 0 if kind == 'out' else (max(1, b - seam) if kind == 'seam' else b - 1)
            if kind == 'out': outm[y, x] = True
    if extra is not None:
        extra['pre'] = steps
        extra['out'] = outm
    return out, owner


def paint(steps, ramp, bg):
    rp = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in ramp], float)
    H, W = steps.shape
    img = np.zeros((H, W, 3))
    img[:] = [int(bg[i:i + 2], 16) for i in (0, 2, 4)]
    m = steps > -9
    c = np.clip(steps[m], 0, len(ramp) - 1)
    lo = np.floor(c).astype(int); hi = np.minimum(lo + 1, len(ramp) - 1); f = (c - lo)[:, None]
    img[m] = rp[lo] * (1 - f) + rp[hi] * f
    return img.round().astype(np.uint8)
