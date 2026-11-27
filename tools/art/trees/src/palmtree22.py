# Round 22, step 2: whole palms. The user's picks (2026-11-24 14:13 MSK): leaf colours В = the reference's own
# palettes; trunk В = the fan palm keeps the reference's short trunk, the feather palm gets a tall curved one like
# the game's palm (content/plants/palm: a tall thin curved trunk, a tuft of feathery leaves on top).
#
# The trunk is the reference's (references/user-palms-snow.jpg, left column): a tube covered in diamond scales (the
# old leaf bases, "pineapple" bark), four colours 411f1f 664038 945a3e c88a40 (crevice and outline, shade, body, the
# lit tips), a dark outline all round, short dark spikes sticking out of its sides, root nubs under it. Ours:
#   - a tube along a curve from the foot to the crown's centre, sampled at 4x, projected like the crown
#     (screen y = ZS z - y), each pixel keeping the nearest sample (its normal and its place on the trunk);
#   - the scales: rows `pv` px apart along the trunk, about `pu` px around, every other row half a scale aside; a
#     pixel's relief from its place in its diamond: the crevice between diamonds 1, the body 2, the upper middle
#     of each diamond (its lifted rim, catching the light from above) 3;
#   - light as on our other trunks (render7.trunk_band of the normal . sun: 0 / -1 / -2), the crown's cast shadow
#     one step more (no darker than the trunk's own shade), the step = relief + light, clamped to 0..3;
#   - the outline to the background step 0, then spikes (1-2 px, down and out, on both sides every other row of
#     scales) and root nubs (one pixel under the foot), step 0.
# The crown is palms22's (the approved leaves; the frond teeth softened at the user's word) on the trunk's top.
# Shadows: every leaf and trunk sample is projected along the sun onto the ground (the ground shadow) and into a
# light-space depth map (the crown's shadow on its trunk).
import math, random
import numpy as np
from scipy import ndimage as ndi
import palm22 as P, palms22 as PS, render6 as R6

BARK_REF = ['411f1f', '664038', '945a3e', 'c88a40']        # the reference's trunks: dark .. lit tips
ZS = P.ZS
SS = 4
SIZES = (('тонкое', 0.42), ('среднее', 0.68), ('толстое', 1.0))   # render16's sizes: crown and height ~ s^(2/3)


def unit(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-9)


def trunk_band(d, deep=False):
    """render7.trunk_band, for arrays: 0 lit, -1 half, -2 shade (deep); the reference's palm trunks keep their
    pattern all round, so by default the shaded side is one step down, not two."""
    if deep: return np.where(d > -0.05, 0, np.where(d > -0.36, -1, -2))
    return np.where(d > -0.05, 0, -1)


class Trunk:
    def __init__(self, Ht, r_foot, r_top, lean=(0.0, 0.0), pu=6.0, pv=3.0, boot=0.0, boot_len=0.1, seed=1,
                 spikes=0.7, spike2=0.3, nubs=2):
        """Ht: height of the crown's centre over the foot; r_foot / r_top: radius at the foot / under the crown;
        lean: the top's offset (x, z), the trunk leaning out from its foot and growing straight up at the top;
        boot: the radius added under the crown (the bulge of the youngest leaf bases) over the top boot_len of it."""
        self.Ht, self.r_foot, self.r_top, self.lean = Ht, r_foot, r_top, lean
        self.pu, self.pv, self.boot, self.boot_len = pu, pv, boot, boot_len
        self.seed, self.spikes, self.spike2, self.nubs = seed, spikes, spike2, nubs
        rng = random.Random(seed)
        self.phase = rng.uniform(0, 1)

    def centre(self, t):
        t = np.asarray(t, float)
        a = 2 * t - t * t
        return np.stack([self.lean[0] * a, self.Ht * t, self.lean[1] * a], -1)

    def tangent(self, t):
        t = np.asarray(t, float)
        da = 2 - 2 * t
        return unit(np.stack([self.lean[0] * da, np.full_like(t, self.Ht), self.lean[1] * da], -1))

    def radius(self, t):
        t = np.asarray(t, float)
        r = self.r_foot + (self.r_top - self.r_foot) * t
        if self.boot:
            r = r + self.boot * np.clip(1 - (1 - t) / self.boot_len, 0, 1) ** 0.6
        return r

    def top(self):
        return self.centre(np.array([1.0]))[0]

    def samples(self, step=0.25):
        """Front-facing surface samples: points, normals, u (scales round), v (rows along), t."""
        tt = np.linspace(0, 1, 2001)
        seg = np.linalg.norm(np.diff(self.centre(tt), axis=0), axis=1)
        arc = np.concatenate([[0], np.cumsum(seg)])
        n_t = int(arc[-1] / step) + 2
        t = np.interp(np.linspace(0, arc[-1], n_t), arc, tt)
        s = np.interp(t, tt, arc)
        r = self.radius(t)
        rmax = float(r.max())
        n_th = int(2 * math.pi * rmax / step) + 8
        th = np.linspace(0, 2 * math.pi, n_th, endpoint=False)
        C = self.centre(t); T = self.tangent(t)
        X = np.array([1.0, 0.0, 0.0])
        ex = unit(X[None, :] - (T @ X)[:, None] * T)
        ez = np.cross(ex, T)
        cth, sth = np.cos(th), np.sin(th)
        N = cth[None, :, None] * ex[:, None, :] + sth[None, :, None] * ez[:, None, :]
        Pp = C[:, None, :] + r[:, None, None] * N
        V = unit(np.array([0.0, ZS, 1.0]))
        front = (N @ V) > -0.05
        n_around = max(4, int(round(2 * math.pi * float(np.mean(r)) / self.pu)))
        u = np.broadcast_to((th / (2 * math.pi) * n_around + self.phase)[None, :], front.shape)
        v = np.broadcast_to((s / self.pv)[:, None], front.shape)
        tg = np.broadcast_to(t[:, None], front.shape)
        return Pp[front], N[front], u[front], v[front], tg[front], n_around

    def all_points(self, step=0.6):
        """Points all round (front and back), for the shadows."""
        tt = np.linspace(0, 1, max(8, int(self.Ht / step)))
        r = self.radius(tt)
        th = np.linspace(0, 2 * math.pi, max(12, int(2 * math.pi * float(r.max()) / step)), endpoint=False)
        C = self.centre(tt); T = self.tangent(tt)
        X = np.array([1.0, 0.0, 0.0])
        ex = unit(X[None, :] - (T @ X)[:, None] * T)
        ez = np.cross(ex, T)
        N = np.cos(th)[None, :, None] * ex[:, None, :] + np.sin(th)[None, :, None] * ez[:, None, :]
        return (C[:, None, :] + r[:, None, None] * N).reshape(-1, 3)


RELIEF = dict(crev=0.86, rim=(0.05, 0.7, 0.34), under=(-0.6, 0.2))   # picked from relief22.py strips


def relief(u, v, crev=None, rim=None, under=None):
    """The diamond scales: per sample its relief (1 crevice, 2 body, 3 the lifted upper rim). crev: the diamond
    metric over which a pixel is the crevice between scales (0.84: a quarter of the area); rim = (dv_lo, dv_hi,
    du_max): the lit dash in the upper middle of each scale; under = (dv_hi, du_max): a dark notch under its foot."""
    crev = RELIEF['crev'] if crev is None else crev
    rim = RELIEF['rim'] if rim is None else rim
    under = RELIEF['under'] if under is None else under
    j0 = np.floor(v)
    best_m = np.full(u.shape, 9.0); best_du = np.zeros(u.shape); best_dv = np.zeros(u.shape)
    for dj in (0, 1):
        j = j0 + dj
        off = 0.5 * (np.mod(j, 2))
        i = np.round(u - off)
        du = u - (i + off); dv = v - j
        m = np.abs(du) / 0.5 + np.abs(dv) / 1.0
        better = m < best_m
        best_m = np.where(better, m, best_m); best_du = np.where(better, du, best_du); best_dv = np.where(better, dv, best_dv)
    rel = np.full(u.shape, 2)
    rel = np.where((best_dv > rim[0]) & (best_dv < rim[1]) & (np.abs(best_du) < rim[2]), 3, rel)
    if under is not None:
        rel = np.where((best_dv < under[0]) & (np.abs(best_du) < under[1]), 1, rel)
    rel = np.where(best_m > crev, 1, rel)
    return rel, best_m, best_du, best_dv


def raster(points, W, H, ox, oy, attrs):
    """Supersampled coverage and the nearest sample's attributes per pixel."""
    X = ox + points[:, 0]; Y = oy + ZS * points[:, 2] - points[:, 1]
    D = ZS * points[:, 1] + points[:, 2]
    sx = np.floor(X * SS).astype(int); sy = np.floor(Y * SS).astype(int)
    ok = (sx >= 0) & (sy >= 0) & (sx < W * SS) & (sy < H * SS)
    key = np.unique(sy[ok] * (W * SS) + sx[ok])
    cov = np.zeros((H, W))
    np.add.at(cov, ((key // (W * SS)) // SS, (key % (W * SS)) // SS), 1.0 / SS ** 2)
    px = np.floor(X).astype(int); py = np.floor(Y).astype(int)
    ok = (px >= 0) & (py >= 0) & (px < W) & (py < H)
    o = np.argsort(D[ok])
    idx = np.nonzero(ok)[0][o]
    out = {}
    for name, a in attrs.items():
        a = np.asarray(a)
        shp = (H, W) + a.shape[1:]
        arr = np.full(shp, np.nan)
        arr[py[idx], px[idx]] = a[idx]
        out[name] = arr
    return cov, out


class ShadowMap:
    """Occluders (leaf samples) in a voxel grid; a point is in shadow when the way from it toward the sun meets one
    between eps and reach px away (palm leaves let the light through: only the dense middle right over the trunk
    shades it, as the reference darkens just the trunk's top under the crown)."""
    def __init__(self, points, L, cell=1.0):
        self.L = unit(L)
        self.cell = cell
        self.lo = points.min(0) - 2 * cell
        ijk = np.floor((points - self.lo) / cell).astype(int)
        shp = tuple(ijk.max(0) + 3)
        occ = np.zeros(shp, bool)
        occ[ijk[:, 0], ijk[:, 1], ijk[:, 2]] = True
        self.occ = ndi.binary_dilation(occ, np.ones((2, 2, 2)))

    def shaded(self, Q, eps=1.5, reach=None):
        reach = 400.0 if reach is None else reach
        out = np.zeros(len(Q), bool)
        for d in np.arange(eps, reach, 0.7 * self.cell):
            R = Q + d * self.L
            ijk = np.floor((R - self.lo) / self.cell).astype(int)
            ok = np.all((ijk >= 0) & (ijk < np.array(self.occ.shape)), axis=1)
            hit = np.zeros(len(Q), bool)
            hit[ok] = self.occ[ijk[ok, 0], ijk[ok, 1], ijk[ok, 2]]
            out |= hit
        return out


def leaf_points(crown, step=0.5):
    pts = []
    for lf in crown.leaves:
        ns = int(lf.L / step) + 4
        nv = int(2 * lf.W / step) + 4
        _, _, Q = lf.surface(crown.C, ns, nv)
        pts.append(Q.reshape(-1, 3))
    return np.concatenate(pts)


def ground_shadow(points, L, W, H, ox, oy):
    L = unit(L)
    if L[1] < 0.1: return np.zeros((H, W), bool)
    g = points - L[None, :] * (points[:, 1:2] / L[1])
    X = np.floor(ox + g[:, 0]).astype(int); Y = np.floor(oy + ZS * g[:, 2]).astype(int)
    ok = (X >= 0) & (Y >= 0) & (X < W) & (Y < H)
    m = np.zeros((H, W), bool)
    m[Y[ok], X[ok]] = True
    m = ndi.binary_closing(m, np.ones((3, 3)), iterations=1)
    m = ndi.binary_fill_holes(m)
    m = ndi.binary_opening(m, np.ones((2, 2)))
    return m


def draw_trunk(trunk, W, H, ox, oy, Lsun, smap=None, reach=None, spike_top=None, extra=None):
    """Steps 0..3 of the trunk per pixel (-1 empty); spikes only below the screen row spike_top. extra (a dict) gets
    'pre' (each pixel's own step before the outline; a spike's or nub's = its trunk pixel's) and 'line' (the outline,
    spikes and nubs), for a softer outline."""
    Lsun = unit(Lsun)
    Pp, N, u, v, t, n_around = trunk.samples()
    rel, m, du, dv = relief(u, v)
    cov, att = raster(Pp, W, H, ox, oy, dict(rel=rel, n=N, p=Pp, t=t))
    mask = (cov >= 0.5) & ~np.isnan(att['rel'])
    for _ in range(2):
        nb = ndi.convolve(mask.astype(int), np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]), mode='constant')
        mask &= nb >= 2
    mask = ndi.binary_fill_holes(mask)
    ys, xs = np.nonzero(mask)
    # holes filled from neighbours
    relp = att['rel'].copy(); nrm = att['n'].copy(); pts = att['p'].copy()
    miss = mask & np.isnan(relp)
    if miss.any():
        _, (iy, ix) = ndi.distance_transform_edt(np.isnan(relp), return_indices=True)
        relp[miss] = relp[iy[miss], ix[miss]]; nrm[miss] = nrm[iy[miss], ix[miss]]; pts[miss] = pts[iy[miss], ix[miss]]
    d = nrm[ys, xs] @ Lsun
    b = trunk_band(d)
    if smap is not None:
        sh = smap.shaded(pts[ys, xs], reach=reach)
        b = np.where(sh, np.maximum(b - 1, -1), b)
    steps = np.full((H, W), -1)
    steps[ys, xs] = np.clip(relp[ys, xs].astype(int) + b, 0, 3)
    # the outline to the background
    edge = mask & ~ndi.binary_erosion(mask, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
    pre = steps.copy()
    line = edge.copy()
    steps[edge] = 0
    def own(yy, xx):                          # a spike's / nub's own colour: its trunk pixel's, one step in
        _, (iy, ix) = ndi.distance_transform_edt(~(mask & ~edge), return_indices=True)
        return pre[iy[yy, xx], ix[yy, xx]]
    # spikes: old leaf stalks sticking out of the sides, down and out, every other row of scales
    rng = random.Random(trunk.seed * 7 + 3)
    rows = np.nonzero(mask.any(1))[0]
    if len(rows):
        y_top, y_bot = rows.min(), rows.max()
        gap = max(3, int(round(2 * trunk.pv)))
        y = y_bot - 3 - rng.randint(0, gap - 1)
        y_stop = y_top + 1 if spike_top is None else max(y_top + 1, spike_top)
        while y > y_stop:
            xs_row = np.nonzero(mask[y])[0]
            if len(xs_row) >= 3:
                for side, x0 in ((-1, xs_row.min()), (1, xs_row.max())):
                    if rng.random() > trunk.spikes: continue
                    ln = 2 if rng.random() < trunk.spike2 else 1
                    for k in range(1, ln + 1):
                        yy, xx = y + k, x0 + side * k
                        if 0 <= yy < H and 0 <= xx < W and not mask[yy, xx]:
                            steps[yy, xx] = 0; line[yy, xx] = True; pre[yy, xx] = own(yy, xx)
            y -= gap + rng.choice((-1, 0, 0, 1))
        # root nubs under the foot
        bot = np.nonzero(mask[y_bot])[0]
        if len(bot) and trunk.nubs:
            cx = (bot.min() + bot.max()) / 2
            w = bot.max() - bot.min() + 1
            cand = [int(round(cx + f * w)) for f in (-0.3, 0.3, -0.05, 0.15)][:trunk.nubs]
            for xx in cand:
                col = np.nonzero(mask[:, xx])[0] if 0 <= xx < W else []
                if len(col):
                    yy = col.max() + 1
                    if yy < H: steps[yy, xx] = 0; line[yy, xx] = True; pre[yy, xx] = own(yy, xx)
    if extra is not None:
        extra['pre'] = pre
        extra['line'] = line
    return steps, mask


# ------------------------------------------------------------------ whole palms
FAN_COUNT = {0.42: 7, 0.68: 8, 1.0: 10}
FEA_COUNT = {0.42: 9, 0.68: 11, 1.0: 13}


def make_trunk(kind, s, seed=11, tall=None):
    k = s ** (2 / 3)
    if tall is None: tall = kind == 'feather'
    if not tall:                               # the reference's: short and stout, wider under the crown
        # (the reference's trunk is a plain cylinder r ~8: its round foot is the base circle seen from above)
        return Trunk(Ht=44 * k ** 1.25, r_foot=8.0 * k, r_top=8.4 * k, pu=max(4.0, 6.0 * k), pv=max(2.0, 3.0 * k), seed=seed,
                     spikes=0.75, nubs=3 if k > 0.7 else 2)
    rng = random.Random(seed * 13 + 5)
    side = rng.choice((-1, 1))
    Ht = 100 * k
    return Trunk(Ht=Ht, r_foot=max(2.8, 5.5 * k), r_top=max(2.5, 4.8 * k), lean=(side * 0.16 * Ht, rng.uniform(-0.04, 0.04) * Ht),
                 pu=max(3.5, 5.0 * k), pv=max(2.0, 2.6 * k), boot=1.6 * k, boot_len=0.12, seed=seed, spikes=0.55,
                 spike2=0.25, nubs=2)


class Palm:
    def __init__(self, kind, s=1.0, sun=PS.SUN_R, seed=11, tall=None, W=None, H=None, ramp=None, bark=None,
                 ox=None, oy=None, soft=2.0):
        self.kind, self.s, self.sun, self.seed, self.soft = kind, s, sun, seed, soft
        self.k = k = s ** (2 / 3)
        self.trunk = make_trunk(kind, s, seed, tall)
        n = (FAN_COUNT if kind == 'fan' else FEA_COUNT).get(s) or int(round((10 if kind == 'fan' else 13) * k ** 0.7))
        self.leaves = PS.fan_leaves(k, n, seed) if kind == 'fan' else PS.feather_leaves(k, n, seed)
        top = self.trunk.top()
        self.W = W or int(260 * max(0.6, k)) + 40
        self.H = H or int(self.trunk.Ht + 90 * k) + 60
        self.ox = self.W * 0.62 + 0.5 if ox is None else ox
        self.oy = self.H - 46.5 if oy is None else oy
        self.crown = P.Crown(self.leaves, W=self.W, H=self.H, ox=self.ox, oy=self.oy, C=top, zs=ZS)
        self.ramp = ramp or (PS.FAN_REF if kind == 'fan' else PS.FEA_REF)
        self.bark = bark or BARK_REF

    def layers(self, ground=R6.GRASS, soft=None):
        """(ground shadow mask, picture of the trunk and crown, its mask). soft: the outline's contrast divided by this
        (each outline pixel mixed from its own colour toward the outline's: 1 = as the reference, 2 = half way: the
        user's pick 2026-11-24 14:48 MSK, the default)."""
        soft = self.soft if soft is None else soft
        L = unit(self.sun)
        W, H, ox, oy = self.W, self.H, self.ox, self.oy
        lp = leaf_points(self.crown)
        tp = self.trunk.all_points()
        smap = ShadowMap(lp, L)
        gs = ground_shadow(np.concatenate([lp, tp]), L, W, H, ox, oy)
        img = np.zeros((H, W, 3), np.uint8)
        top = self.trunk.top()
        cy = oy + ZS * top[2] - top[1]
        tx = {}
        st, mask = draw_trunk(self.trunk, W, H, ox, oy, L, smap, reach=14 * self.k,
                              spike_top=int(cy + self.trunk.r_top + 3), extra=tx)
        bark = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in self.bark], float)
        img[st >= 0] = bark[st[st >= 0]].round().astype(np.uint8)
        if soft != 1:
            ln = tx['line'] & (st >= 0)
            c_own = bark[np.clip(tx['pre'][ln], 0, 3)]
            img[ln] = (c_own + (bark[st[ln]] - c_own) / soft).round().astype(np.uint8)
        kw = dict(PS.FAN_DRAW if self.kind == 'fan' else PS.FEATHER_DRAW)
        if kw.get('heart'):
            r = max(2, kw['heart'][0] * self.k)
            if self.kind == 'fan' and self.k < 0.9:     # small fans' thin stalks: the dark middle covers the trunk's top
                r = max(r, self.trunk.r_top + 0.5)
            kw['heart'] = (r, kw['heart'][1])
        if self.kind == 'fan': kw['ring'] = max(1, int(round(kw['ring'] * (0.6 + 0.4 * self.k))))
        cx = {}
        cs, own = P.draw(self.crown, Lsun=L, extra=cx, **kw)
        cimg = P.paint(cs, self.ramp, ground)
        if soft != 1:
            o = cx['out']
            pimg = P.paint(cx['pre'], self.ramp, ground).astype(float)
            cimg[o] = (pimg[o] + (cimg[o].astype(float) - pimg[o]) / soft).round().astype(np.uint8)
        m = cs > -9
        img[m] = cimg[m]
        self.trunk_mask = mask
        return gs, img, m | (st >= 0)

    def render(self, ground=R6.GRASS, shade=R6.GRASS_SHADE, with_shadow=True, soft=None):
        gs, pic, m = self.layers(ground, soft)
        img = np.zeros((self.H, self.W, 3), np.uint8)
        img[:] = [int(ground[i:i + 2], 16) for i in (0, 2, 4)]
        if with_shadow:
            img[gs] = [int(shade[i:i + 2], 16) for i in (0, 2, 4)]
        img[m] = pic[m]
        return img

    def trunk_px(self):
        """(width at the foot, height of the crown's centre over the foot) in px."""
        return int(round(2 * self.trunk.r_foot)), int(round(self.trunk.Ht))

    def height_px(self):
        """The foot to the crown's top on the screen."""
        lp = leaf_points(self.crown, 1.0)
        return int(round((lp[:, 1] - ZS * lp[:, 2]).max()))


if __name__ == '__main__':
    import sys
    from PIL import Image
    kind = sys.argv[2] if len(sys.argv) > 2 else 'fan'
    s = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    p = Palm(kind, s)
    img = p.render()
    Image.fromarray(img).resize((img.shape[1] * 4, img.shape[0] * 4), Image.NEAREST).save(sys.argv[1])
