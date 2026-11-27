# Round 23 step 3b: the reference's broken trunk (references/user-palms-snow.jpg, right bottom: trunk_broken): the tree
# snapped well above the ground; what stands is its trunk with its own foot, the top broken off on a slant (the fresh
# light wood of the break, the trunk's wall left standing as splinters on its high side) and a sprout of the species'
# own leaves out of its side (mockup, no game code). Built on the approved stumps (stump23.Stump: the tree's own trunk
# picture, foot by size, the oval view FACE_ZS 0.6), with the break instead of the level cut.
import math, random, numpy as np
import stump23 as S, all23 as A

BROKEN = dict(h_k=1.55, h_min=10, slope=(0.32, 0.5), spikes=3, spike_h=(0.6, 1.3), spike_w=(1.6, 2.6),
              main_w=(0.55, 0.8))


def fresh_wood(fx, fz, rc, seed, Lf, out_side, key):
    """Roles of the break's face per pixel (cross-section coords px): the bark ring (outline at the back, lit bark at
    the front), then fresh light wood torn along one way: streaks a step darker, a few lit fibres, the pith."""
    rng = random.Random(seed)
    r3 = np.random.default_rng(seed + 3)
    d = np.sqrt(fx * fx + fz * fz)
    e = rc - d
    bark = np.full(fx.shape, -1, int); wd = np.full(fx.shape, -1, int)
    nl = (fx * Lf[0] + fz * Lf[1]) / np.maximum(d, 1e-6)
    band = np.where(nl > -0.05, 0, np.where(nl > -0.36, -1, -2))
    ring0 = e < 1.0
    bark[ring0 & out_side] = 0
    bark[ring0 & ~out_side] = (np.clip(2 + band, 1, 3) if rc >= 3 else np.full(fx.shape, 1))[ring0 & ~out_side]
    core = bark < 0
    wd[core] = 4
    a = rng.uniform(-0.6, 0.6)
    across = fx * math.cos(a) + fz * math.sin(a) * 1.0
    streak = (np.floor(across * 0.8 + r3.random(fx.shape) * 0.9) % 3 == 0)
    wd[core & streak] = 3
    wd[core & (e < 2.0) & (nl > 0.3)] = 5                         # the lit sapwood
    wd[core & ~streak & (r3.random(fx.shape) < 0.1)] = 5
    if key in ('palm', 'fan_palm'):
        dots = r3.random(fx.shape) < 0.3
        wd[core & dots] = 2
    elif rc >= 4:
        wd[core & (d < 0.8)] = 2
    return bark, wd


class Broken(S.Stump):
    """S.Stump with the top broken: hs = the break's height at the trunk's middle (front edge)."""
    def __init__(self, key, s=0.68, seed=None, sun=None, sprout=True, **kw):
        P = dict(BROKEN, **kw); self.P = P
        self.key = key
        seed_ = seed if seed is not None else (sum(ord(c) * (i + 1) for i, c in enumerate(key)) + int(round(s * 100))) % 997
        # the break's height from the trunk's radius at the foot (as the stumps' cut)
        if key in ('palm', 'fan_palm'):
            import palmtree22 as PT
            r0 = float(PT.Palm('feather' if key == 'palm' else 'fan', s).trunk.r_foot)
        else:
            t = A.build(key, s); r0 = float(t.limbs[0].r(0.0))
        hb = max(P['h_min'], int(round(P['h_k'] * 2 * r0)))
        self.want_sprout = sprout
        super().__init__(key, s, hs=hb, seed=seed_, sun=sun)

    def _cut(self, img, mask, x_axis):
        P = self.P
        oy = int(round(self.oy))
        Yf = oy - self.hs
        xl, xr = S._run_at(mask[Yf], x_axis)
        rc = (xr - xl + 1) / 2.0
        xc = xl + rc
        zs = self.zs
        rng = random.Random(self.seed * 5 + 1)
        side = rng.choice((-1, 1))
        sl = rng.uniform(*P['slope'])
        H, W = mask.shape
        self.rc, self.xc, self.Yf, self.side = rc, xc, Yf, side
        u = np.arange(W) + 0.5 - xc
        inn = np.abs(u) <= rc
        yc_u = Yf - rc * zs - sl * side * u
        half = zs * np.sqrt(np.maximum(0.0, rc * rc - u * u))
        front, back = yc_u + half, yc_u - half
        self.yc_u, self.back, self.front = yc_u, back, front
        YY, XX = np.mgrid[0:H, 0:W]
        Yc = YY + 0.5
        pic = np.zeros_like(img); pic[:] = S.hexc(A.KEY_G)
        keep = np.zeros_like(mask)
        side_px = mask & ((inn[None, :] & (Yc >= front[None, :])) | (~inn[None, :] & (YY >= Yf)))
        pic[side_px] = img[side_px]; keep |= side_px
        # the wall left standing on the high side: splinters up from the back rim
        spikes = np.zeros_like(mask)
        n = P['spikes']
        for k in range(n):
            if k == 0:          # the main splinter: the wall of the high side, wide, its outer edge the trunk's edge
                wk = max(2.5, 2 * rc * rng.uniform(*P['main_w']))
                uk = side * (rc - wk / 2 + 0.5)
                hk = rc * rng.uniform(*P['spike_h']) * 1.15
            elif k < n - 1:
                uk = side * rc * rng.uniform(0.0, 0.5)
                hk = rc * rng.uniform(*P['spike_h']) * 0.7
                wk = rng.uniform(*P['spike_w'])
            else:
                uk = -side * rc * rng.uniform(0.2, 0.6)
                hk = rc * rng.uniform(*P['spike_h']) * 0.45
                wk = rng.uniform(*P['spike_w'])
            for X in range(W):
                du = abs(u[X] - uk)
                if du > wk / 2 + 0.5 or abs(u[X]) > rc: continue
                prof = max(0.0, 1 - du / (wk / 2 + 0.5))
                if k == 0:      # higher at the outer edge, torn toward the middle
                    prof = min(1.0, 0.35 + 0.65 * (0.5 + 0.5 * side * (u[X] - uk) / (wk / 2 + 0.5)))
                    prof *= 1.0 if (X * 7 + self.seed) % 5 else 0.8
                top = back[X] - hk * prof - (0.5 if du < 0.6 else 0)
                for Y in range(int(math.floor(top)), int(math.ceil(back[X] + 1))):
                    if 0 <= Y < H and Y + 0.5 >= top: spikes[Y, X] = True
        spikes &= mask
        pic[spikes] = img[spikes]; keep |= spikes
        # the light inner side of each splinter (the torn fibres), the pixel next to the face's middle
        wr = S.wood_ramp(self.key)
        ys, xs = np.nonzero(spikes)
        for y_, x_ in zip(ys, xs):
            inner = x_ - side if 0 <= x_ - side < W else x_
            if not spikes[y_, inner] and Yc[y_, x_] < back[x_]:
                pic[y_, x_] = wr[3].astype(np.uint8)
        # the face of the break
        face = inn[None, :] & (Yc >= back[None, :]) & (Yc < front[None, :])
        ys, xs = np.nonzero(face)
        fx = u[xs]; fz = (Yc[ys, xs] - yc_u[xs]) / zs
        L = self.L
        Lf = np.array([L[0], L[2]]); Lf = Lf / max(1e-6, np.linalg.norm(Lf))
        out_side = fz < 0
        bk, wd = fresh_wood(fx, fz, rc, self.seed * 3 + 7, Lf, out_side, self.key)
        for y_, x_, b_, w_ in zip(ys, xs, bk, wd):
            c = self.bark[b_] if b_ >= 0 else wr[w_]
            pic[y_, x_] = np.round(c).astype(np.uint8)
        keep |= face
        self.face = face
        # the ground shadow: the standing trunk as a cylinder up to the break (its high side a little taller)
        L = self.L
        sh = np.zeros_like(mask)
        if L[1] > 0.1:
            zc = oy - rc * zs
            hmax = self.hs + sl * rc * 0.5
            for h in np.arange(0, hmax + 0.01, 0.5):
                cx_ = xc - L[0] / L[1] * h; cz_ = zc - L[2] / L[1] * h * zs
                sh |= (XX + 0.5 - cx_) ** 2 + ((YY + 0.5 - cz_) / zs) ** 2 <= rc * rc
        pic[sh & ~keep] = S.hexc(A.KEY_S)
        self.pic, self.mask = pic, keep
        self.shadow = sh & ~keep
        self.sl = sl
        self.spikes_m = spikes
        self.base_pic, self.base_mask = pic.copy(), keep.copy()

    def summer(self):
        """The picture with the summer sprout."""
        import sprout23 as SP
        self.pic, self.mask = self.base_pic.copy(), self.base_mask.copy()
        if self.want_sprout: SP.add_sprout(self)
        return self.pic

    def winter(self):
        """Snow on the break (the stumps' approved layer, tilted with the face), a cap on the splinters, the sprout bare
        (a conifer's seedling keeps its needles, under snow); the hot-zone trees as in summer."""
        import sprout23 as SP
        if self.key in S.HOT: return self.summer()
        self.pic, self.mask = self.base_pic.copy(), self.base_mask.copy()
        if self.want_sprout: SP.add_sprout(self, winter=True)
        self.pic = snow_on_break(self)
        return self.pic


def snow_on_break(st, P=None):
    """stump23.snow_layer for the slanted face of the break: the footprint is the face's disc, its ground row runs
    up the slope (the face's height grows toward the high side by sl px per px), the snow's normals tilted with it;
    the layer a little thinner (snow slides off a slope). Plus a pixel of snow on each splinter's top."""
    import bare23 as B
    P = dict(S.LAYER, **(P or {}))
    P['t_k'] *= 0.85
    rng = random.Random(st.seed * 7 + 31)
    rc, zs, xc = st.rc, st.zs, st.xc
    sl, side = st.sl, st.side
    L = np.asarray(st.L, float)
    T0 = float(np.clip(P['t_k'] * rc, P['t_lo'], P['t_hi']))
    rx = rc + P['grow']; rzw = rc + P['grow'] + P['over'] / zs
    yc0 = st.Yf - rc * zs + P['over'] * 0.5
    bumps = []
    for i in range(P['bumps'] if rc >= 3.5 else 1):
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9) if i < 2 else rng.uniform(0, math.tau)
        q = rng.uniform(0.25, 0.65)
        bumps.append((q * rx * math.cos(a), q * rzw * math.sin(a), T0 * rng.uniform(*P['bump_h']),
                      rc * rng.uniform(*P['bump_s'])))
    w1, w2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    def thick(x, z):
        th_ = np.arctan2(z / rzw, x / rx)
        wob = 1 + P['wob'] * (0.6 * np.sin(3 * th_ + w1) + 0.4 * np.sin(5 * th_ + w2))
        u = np.sqrt((x / rx) ** 2 + (z / rzw) ** 2) / wob
        t = T0 * np.sqrt(np.clip(1 - u ** P['edge'], 0, 1))
        for bx, bz, bh, bs in bumps:
            t = t + bh * np.exp(-((x - bx) ** 2 + (z - bz) ** 2) / (2 * bs * bs)) * (u < 1)
        return np.where(u < 1, t, -1.0)
    X0 = int(math.floor(xc - rx * 1.1)) - 1; X1 = int(math.ceil(xc + rx * 1.1)) + 1
    zz = np.arange(-rzw * 1.1, rzw * 1.1 + 1e-6, 0.08)
    H, W = st.pic.shape[:2]
    nrm = {}
    for X in range(X0, X1 + 1):
        x = X + 0.5 - xc
        t = thick(np.full(zz.shape, x), zz)
        ok = t >= 0
        if not ok.any(): continue
        z_ok, t_ok = zz[ok], t[ok]
        dz = dx = 0.04
        tz = (thick(np.full(z_ok.shape, x), z_ok + dz) - thick(np.full(z_ok.shape, x), z_ok - dz)) / (2 * dz)
        tx = (thick(np.full(z_ok.shape, x + dx), z_ok) - thick(np.full(z_ok.shape, x - dx), z_ok)) / (2 * dx)
        tz = np.where(np.isfinite(tz) & (np.abs(tz) < 40), tz, 0.0); tx = np.where(np.isfinite(tx) & (np.abs(tx) < 40), tx, 0.0)
        for z, tt, gx, gz in zip(z_ok, t_ok, tx, tz):
            Yg = yc0 + z * zs - sl * side * x
            top, base = Yg - tt, Yg
            n = np.array([-gx - sl * side, 1.0, -gz]); n /= np.linalg.norm(n)
            for Y in range(int(math.floor(top)), int(math.floor(base)) + 1):
                if Y + 0.5 < top - 0.25 or Y + 0.5 > base + 0.5: continue
                nrm[(Y, X)] = n
    m = np.zeros((H, W), bool); tone = np.zeros((H, W), int)
    for (Y, X), n in nrm.items():
        if 0 <= Y < H and 0 <= X < W:
            d = float(n @ L) + P['lit']
            m[Y, X] = True
            tone[Y, X] = 5 if d > 0.78 else 4 if d > 0.5 else 3 if d > 0.2 else 2 if d > -0.1 else 1
    # the splinters stand in front of the layer where they rise over it; a pixel of snow on each one's top
    sp = st.spikes_m & ~st.face
    m &= ~(sp & (np.arange(H)[:, None] < st.back[None, :] - 1))
    for X in np.nonzero(sp.any(0))[0]:
        Y = int(np.nonzero(sp[:, X])[0].min())
        if Y - 1 >= 0 and not m[Y - 1, X] and Y < st.back[X] - 1:
            m[Y - 1, X] = True; tone[Y - 1, X] = 4
    tv = np.where(B.rim_of(m), 5 + tone, tone)
    pic = st.pic.copy()
    pic[m] = B.SNOW_EXT[tv[m]]
    st.snow = m
    st.mask = st.mask | m
    return pic
