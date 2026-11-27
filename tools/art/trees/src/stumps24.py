# Round 24 (pieces): the approved stumps (round 23, stump23) and broken trunks with a sprout (broken23, sprout23)
# standing in the world, seen from the camera's turns (n x 45 deg, or any angle `deg`; turn24's convention: a point at
# azimuth a about the trunk is seen at a + deg, x right, z toward the camera). As the trees of round 24 (variant A,
# the approved depth): the trunk limb turns like the trees' (turn24.XLimb), the foot picture stays (round), the bark is
# view-locked, the sun turns with the view (lit sides and shadows stay put on the screen). What a turn changes:
#   - stumps: the end grain turns with the trunk (the pith's offset, the rings' wobble and gaps, the checks, the resin
#     drops); the rim's light and outline stay with the view;
#   - broken trunks: the slanted break turns (its rise toward the high side points along the turned direction: seen
#     from the high side the face narrows, from the low side it opens up), the splinters are pieces of the trunk's wall
#     on the rim turned with it (behind the face from the back, in front of it from the front), the sprout's place on
#     the trunk turns (behind the trunk from the far side), the conifers' and palms' seedling turns round the foot.
# Turn 0 is the approved picture, pixel for pixel (checked in check24p.py).
import math, random, numpy as np
import stump23 as S, broken23 as BR, all23 as A, render7 as R, turn24 as TU

PALMS = ('palm', 'fan_palm')


def zs_of(key):
    """The squash of the tree's own frame (turn24 / conifer24): broadleaf 0.55, conifers' C.ZS."""
    import conifer21 as C
    return C.ZS if key in C.CSPEC else TU.ZSQ


class _Turned:
    """The tree's trunk limb turned by self.deg as turn24 turns the trees; the palms' short trunk: lean and scales."""
    def _with_build(self, fn):
        orig = A.build
        deg = self.deg
        def build(k, s_):
            t = orig(k, s_)
            if deg and k not in PALMS:
                zs = zs_of(k)
                pos, _, _ = TU.maps(0, zs, zs, deg=deg)
                t.limbs = [TU.XLimb(lb, pos) for lb in t.limbs]
            return t
        A.build = build
        try: return fn()
        finally: A.build = orig

    def _palm(self, sun):
        """stump23.Stump._palm with the short trunk's lean turned and its scales turned with it (kinds24.palm_turn)."""
        import palmtree22 as PT, palm22 as P, kinds24 as K
        K._patch_trunk()
        kind = 'feather' if self.key == 'palm' else 'fan'
        p = PT.Palm(kind, self.s)
        L = R.norm(sun if sun is not None else p.sun)
        self.L = np.asarray(L, float)
        tr = p.trunk
        r0 = float(tr.r_foot)
        self.hs = max(S.HS_MIN, int(round(self.hs_k * 2 * r0)))
        Ht = self.hs + 2 * r0 + 6
        lx = tr.lean[0] * Ht / tr.Ht * 0.3
        c, s_ = math.cos(self.rot), math.sin(self.rot)
        st = PT.Trunk(Ht=Ht, r_foot=tr.r_foot, r_top=tr.r_foot + (tr.r_top - tr.r_foot) * Ht / tr.Ht,
                      lean=(c * lx, s_ * lx), pu=tr.pu, pv=tr.pv, seed=tr.seed, spikes=tr.spikes,
                      spike2=tr.spike2, nubs=tr.nubs)
        st.turn_a = self.rot
        W, H = p.W, p.H
        ox, oy = p.ox, p.oy
        tx = {}
        steps, mask = PT.draw_trunk(st, W, H, ox, oy, L, None, spike_top=None, extra=tx)
        bark = np.array([S.hexc(h) for h in p.bark])
        img = np.zeros((H, W, 3), np.uint8); img[:] = S.hexc(A.KEY_G)
        m = steps >= 0
        img[m] = bark[steps[m]].round().astype(np.uint8)
        if p.soft != 1:
            ln = tx['line'] & m
            c_own = bark[np.clip(tx['pre'][ln], 0, 3)]
            img[ln] = (c_own + (bark[steps[ln]] - c_own) / p.soft).round().astype(np.uint8)
        self.bark = bark
        self.zs = P.ZS * self.face_zs
        self.ox, self.oy = float(ox), float(oy)
        self.t = None
        self._cut(img, m, ox)


# ---------------------------------------------------------------- the end grain, turned
def face_roles24(rc, xc, yc, box, seed, key, L, zs=1.0, rot=0.0):
    """stump23.face_roles with the wood's own pattern turned by rot (rad): the same random draws, each angle of the
    pattern + rot (the rings' wobble phases - k rot), the resin drops moved round the pith's middle; the bark ring
    and the sapwood's light keep to the view."""
    Y0, Y1, X0, X1 = box
    rng = random.Random(seed)
    yy, xx = np.mgrid[Y0:Y1, X0:X1]
    dx = xx + 0.5 - xc; dy = (yy + 0.5 - yc) / zs
    d = np.sqrt(dx * dx + dy * dy)
    inside = dx * dx + dy * dy <= rc * rc + 0.3
    e = rc - d
    bark = np.full(dx.shape, -1, int); wood = np.full(dx.shape, -1, int)
    dh, ks, kv, heart, cracks, spk = S.SPECIES_WOOD.get(key, S.SPECIES_WOOD['oak'])
    nl = (dx * L[0] + dy * zs * L[2]) / np.maximum(d, 1e-6)
    ring0 = inside & (e < 1.0)
    back = dy < 0.0
    thick = rc >= 3.5
    band = np.where(nl > -0.05, 0, np.where(nl > -0.36, -1, -2))
    bark[ring0 & back] = 0
    if thick:
        bark[ring0 & ~back] = np.clip(2 + band, 1, 3)[ring0 & ~back]
    ring1 = inside & ~(bark >= 0) & (e < (2.0 if thick else 1.6))
    wood[ring1] = np.where(nl > 0.3, 5, np.where(nl < -0.3, 3, 4))[ring1]
    core = inside & (bark < 0) & (wood < 0)
    wood[core] = 4
    if key in PALMS:
        r2 = np.random.default_rng(seed)
        dots = r2.random(dx.shape) < 0.32
        wood[core & dots] = 2
        wood[core & dots & (r2.random(dx.shape) < 0.3)] = 1
        wood[core & (d < 0.35 * rc) & ~dots] = 5
        return bark, wood, inside
    phi = rng.uniform(0, math.tau) + rot
    off = rng.uniform(0.1, 0.22) * rc
    px_, py_ = xc + off * math.cos(phi), yc + off * math.sin(phi) * zs
    ddx = xx + 0.5 - px_; ddy = (yy + 0.5 - py_) / zs
    dp = np.sqrt(ddx * ddx + ddy * ddy); th = np.arctan2(ddy, ddx)
    f1, f2 = rng.uniform(0, math.tau) - 2 * rot, rng.uniform(0, math.tau) - 3 * rot
    dw = dp * (1 + 0.07 * np.sin(2 * th + f1) + 0.05 * np.sin(3 * th + f2))
    if heart:
        wood[core & (dw < 0.55 * (rc - 2))] = 3
    sp = max(2.6, rc / 3.0) * spk
    k_max = int((rc - 2.2) / sp)
    grad = np.sqrt(np.cos(th) ** 2 + (np.sin(th) / zs) ** 2) * np.maximum(0.6, dw / np.maximum(dp, 1e-6))
    r3 = np.random.default_rng(seed + 5)
    for k in range(1, k_max + 1):
        dist = np.abs(dw - k * sp) / grad
        on = core & (dist < 0.5)
        for _ in range(rng.randint(0, 2) if k > 1 else 0):
            a0 = rng.uniform(-math.pi, math.pi) + rot; w_ = rng.uniform(0.3, 0.7)
            on &= np.abs(np.remainder(th - a0 + math.pi, math.tau) - math.pi) > w_ / 2
        soft = core & ~on & (dist < 1.5) & (dw < k * sp) & (r3.random(dw.shape) < 0.3)
        wood[soft & (wood == 4)] = 3
        wood[on] = 2
    wood[core & (wood == 4) & (r3.random(dw.shape) < 0.04)] = 3
    pith = core & (dp < (0.9 if rc >= 4 else 0.6))
    wood[pith] = 0 if rc >= 5 else 2
    n_cr = cracks if rc >= 6 else (1 if (cracks > 1 and rc >= 4) else 0)
    for _ in range(n_cr):
        a = rng.uniform(-math.pi, math.pi) + rot
        ln = rng.uniform(0.45, 0.8) * rc if cracks < 3 else rng.uniform(0.6, 0.95) * rc
        ux, uy = math.cos(a), math.sin(a)
        along = ddx * ux + ddy * uy
        across = np.abs(-ddx * uy + ddy * ux)
        cr = core & (along > 0.5) & (along < ln) & (across < 0.5 + 0.25 * (along < ln * 0.4))
        wood[cr] = np.where(along[cr] < ln * 0.7, 0, 1)
    if key in S.RESIN and rc >= 4:
        candm = ring1 | (core & (e < 3))
        cand = np.argwhere(candm)
        c, s_ = math.cos(rot), math.sin(rot)
        for _ in range(rng.randint(1, 3)):
            if len(cand) == 0: break
            y_, x_ = cand[rng.randrange(len(cand))]
            if rot:
                # the drop's place on the face (true frame) turned with the trunk, back to the nearest candidate pixel
                fx, fz = x_ + X0 + 0.5 - xc, (y_ + Y0 + 0.5 - yc) / zs
                gx, gz = c * fx - s_ * fz, s_ * fx + c * fz
                X, Y = xc + gx - X0 - 0.5, yc + gz * zs - Y0 - 0.5
                i = int(np.argmin((cand[:, 0] - Y) ** 2 + (cand[:, 1] - X) ** 2))
                y_, x_ = cand[i]
            wood[y_, x_] = 9
    return bark, wood, inside


class Stump24(_Turned, S.Stump):
    """stump23.Stump seen from the view angle deg."""
    def __init__(self, key, s, deg=0.0, **kw):
        self.deg = float(deg) % 360.0
        self.rot = math.radians(self.deg)
        self._with_build(lambda: S.Stump.__init__(self, key, s, **kw))

    def _cut(self, img, mask, x_axis):
        orig = S.face_roles
        rot = self.rot
        S.face_roles = lambda *a, **k: face_roles24(*a, rot=rot, **k)
        try: S.Stump._cut(self, img, mask, x_axis)
        finally: S.face_roles = orig


# ---------------------------------------------------------------- the broken trunk, turned
def _splinter_profile(P, rc, side, seed, rng):
    """The splinters of broken23.Broken._cut as functions of the turn-0 screen column offset u (px from the axis):
    [(H(u, X) -> height over the back rim or None)], drawing the same random numbers in the same order."""
    out = []
    n = P['spikes']
    for k in range(n):
        if k == 0:
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
        def H(u, X, k=k, uk=uk, wk=wk, hk=hk):
            du = abs(u - uk)
            if du > wk / 2 + 0.5 or abs(u) > rc: return None
            prof = max(0.0, 1 - du / (wk / 2 + 0.5))
            if k == 0:
                prof = min(1.0, 0.35 + 0.65 * (0.5 + 0.5 * side * (u - uk) / (wk / 2 + 0.5)))
                prof *= 1.0 if (X * 7 + seed) % 5 else 0.8
            return hk * prof + (0.5 if du < 0.6 else 0)
        out.append((H, uk))
    return out


class Broken24(_Turned, BR.Broken):
    """broken23.Broken seen from the view angle deg."""
    def __init__(self, key, s=0.68, deg=0.0, **kw):
        self.deg = float(deg) % 360.0
        self.rot = math.radians(self.deg)
        self._with_build(lambda: BR.Broken.__init__(self, key, s, **kw))

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
        ca, sa = math.cos(self.rot), math.sin(self.rot)
        if abs(ca) < 1e-12: ca = 0.0
        if abs(sa) < 1e-12: sa = 0.0
        gx, gz = side * ca, side * sa                   # the break rises this way (view frame, unit)
        kz = zs - sl * gz                               # screen rows per px of depth over the slanted face
        self.gx, self.gz, self.kz = gx, gz, kz
        u = np.arange(W) + 0.5 - xc
        inn = np.abs(u) <= rc
        yc_u = Yf - rc * zs - sl * gx * u
        half = kz * np.sqrt(np.maximum(0.0, rc * rc - u * u))
        front, back = yc_u + half, yc_u - half
        self.yc_u, self.back, self.front = yc_u, back, front
        YY, XX = np.mgrid[0:H, 0:W]
        Yc = YY + 0.5
        pic = np.zeros_like(img); pic[:] = S.hexc(A.KEY_G)
        keep = np.zeros_like(mask)
        side_px = mask & ((inn[None, :] & (Yc >= front[None, :])) | (~inn[None, :] & (YY >= Yf)))
        pic[side_px] = img[side_px]; keep |= side_px
        # the wall left standing on the high side: the turn-0 splinters (over the back rim at screen column u0) are
        # pieces of the trunk's wall at the rim azimuth -acos(u0 / rc); turned with the trunk they stand on the rim
        # at that azimuth + rot: behind the face on the far half, in front of it on the near half
        prof = _splinter_profile(P, rc, side, self.seed, rng)
        sp_back = np.zeros_like(mask); sp_front = np.zeros_like(mask)
        for X in range(W):
            uu = u[X]
            if abs(uu) > rc: continue
            for near in (False, True):
                thv = math.acos(max(-1.0, min(1.0, uu / rc))) * (1 if near else -1)     # the view's rim azimuth
                th0 = thv - self.rot                                                       # the same point at turn 0
                s0 = math.sin(th0)
                if s0 > 1e-9: continue                                                     # turn 0's near half: none
                u0 = rc * math.cos(th0)
                X0 = int(math.floor(u0 + xc)) if self.rot else X
                if not self.rot: u0 = uu
                hh = [h for h in (Hf(u0, X0) for Hf, _ in prof) if h is not None]
                if not hh: continue
                y_rim = front[X] if near else back[X]
                tgt = sp_front if near else sp_back
                for hk_ in hh:
                    top = y_rim - hk_
                    for Y in range(int(math.floor(top)), int(math.ceil(y_rim + 1))):
                        if 0 <= Y < H and Y + 0.5 >= top: tgt[Y, X] = True
        sp_back &= mask; sp_front &= mask
        pic[sp_back] = img[sp_back]; keep |= sp_back
        # the light inner side of each splinter (the torn fibres), the pixel next to it toward the face's middle: on
        # the screen side of the high wall's middle (turn 0: the high side)
        main_uk = prof[0][1]
        th_mid = -math.acos(max(-1.0, min(1.0, main_uk / rc))) + self.rot
        cm = math.cos(th_mid)
        s_scr = side if (not self.rot or abs(cm) < 0.2) else (1 if cm > 0 else -1)
        wr = S.wood_ramp(self.key)
        ys, xs = np.nonzero(sp_back)
        for y_, x_ in zip(ys, xs):
            inner = x_ - s_scr if 0 <= x_ - s_scr < W else x_
            if not sp_back[y_, inner] and Yc[y_, x_] < back[x_]:
                pic[y_, x_] = wr[3].astype(np.uint8)
        # the face of the break
        face = inn[None, :] & (Yc >= back[None, :]) & (Yc < front[None, :])
        ys, xs = np.nonzero(face)
        uu = u[xs]; zv = (Yc[ys, xs] - yc_u[xs]) / kz
        fx, fz = uu * ca + zv * sa, -uu * sa + zv * ca              # the face's own frame (turn 0)
        L = self.L
        Lf = np.array([L[0], L[2]]); Lf = Lf / max(1e-6, np.linalg.norm(Lf))
        Lf0 = np.array([Lf[0] * ca + Lf[1] * sa, -Lf[0] * sa + Lf[1] * ca])
        out_side = zv < 0
        bk, wd = BR.fresh_wood(fx, fz, rc, self.seed * 3 + 7, Lf0, out_side, self.key)
        for y_, x_, b_, w_ in zip(ys, xs, bk, wd):
            c = self.bark[b_] if b_ >= 0 else wr[w_]
            pic[y_, x_] = np.round(c).astype(np.uint8)
        keep |= face
        # the near splinters stand in front of the face: bark outside, the torn top edge light (the pixel under the
        # top one: the top one takes the wood's outline against the ground)
        if sp_front.any():
            pic[sp_front] = img[sp_front]; keep |= sp_front
            for X in np.nonzero(sp_front.any(0))[0]:
                Y = int(np.nonzero(sp_front[:, X])[0].min())
                if Y + 1 < H and sp_front[Y + 1, X]: pic[Y + 1, X] = wr[3].astype(np.uint8)
        self.face = face & ~sp_front
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
        self.spikes_m = sp_back | sp_front
        self.sp_front = sp_front
        self.base_pic, self.base_mask = pic.copy(), keep.copy()

    def summer(self):
        self.pic, self.mask = self.base_pic.copy(), self.base_mask.copy()
        if self.want_sprout: add_sprout24(self)
        return self.pic

    def winter(self):
        if self.key in S.HOT: return self.summer()
        self.pic, self.mask = self.base_pic.copy(), self.base_mask.copy()
        if self.want_sprout: add_sprout24(self, winter=True)
        self.pic = snow_on_break24(self)
        return self.pic


# ---------------------------------------------------------------- the sprout, turned
def add_sprout24(st, winter=False):
    """sprout23.add_sprout with the sprout's place turned round the trunk: it comes out of the trunk at the turn-0
    side's azimuth + rot (screen x = cos, depth = sin); on the far half the trunk covers it."""
    import sprout23 as SP
    key = st.key
    sty = SP.style_of(key)
    ramp = SP.ramp_of(st)
    if len(ramp) < 7: ramp = np.vstack([ramp[:1], ramp, ramp[-1:]])[:7]
    rng = random.Random(st.seed * 11 + 3)
    pic, keep = st.pic, st.mask
    H, W = keep.shape
    oy = int(round(st.oy))
    out0 = -st.side
    th = (0.0 if out0 > 0 else math.pi) + st.rot
    cth, sth = math.cos(th), math.sin(th)
    if abs(cth) < 1e-9: cth = 0.0
    if abs(sth) < 1e-9: sth = 0.0
    out = 1 if cth > 0 else (-1 if cth < 0 else out0)
    behind = sth < -0.05
    solid = keep.copy()
    zs = st.zs
    trunk = keep & ~st.shadow

    def put(Y, X, c):
        Y, X = int(round(Y)), int(round(X))
        if not (0 <= Y < H and 0 <= X < W): return
        if behind and solid[Y, X]: return
        pic[Y, X] = c; keep[Y, X] = True

    def stamp(a, X0, Y0, tone):
        X0, Y0 = int(round(X0)), int(round(Y0))
        for (y, x), ch in np.ndenumerate(a):
            if ch == '.' or ch not in tone: continue
            put(Y0 + y, X0 + x, np.round(ramp[tone[ch]]).astype(np.uint8))

    def ground_spot(rows, extra):
        """Where a seedling stands: the trunk's middle at the ground +- (half width + extra) along the azimuth."""
        cols = np.nonzero(trunk[max(0, rows[0]):rows[1]].any(0))[0]
        if not len(cols): return None
        m = (cols.min() + cols.max()) / 2.0; hw = (cols.max() - cols.min()) / 2.0
        d = hw + extra
        return m + d * cth, zs * d * sth

    if sty == 'palm':
        g = ground_spot((oy - 2, oy + 2), 6)
        if g is None: return
        T = (g[0], oy + 1 + g[1])
        br = SP.L123['blades']['brushes']
        fan = [(0, False, SP.TONE_DARK), (0, True, SP.TONE_MID), (1, False, SP.TONE_MID), (3, True, SP.TONE_LIT)]
        if key == 'palm': fan = [(0, False, SP.TONE_MID), (0, True, SP.TONE_LIT), (1, True, SP.TONE_DARK)]
        for k, fl, tone in fan:
            a, (by, bx) = SP.based(br[2 if key == 'fan_palm' else 3], k, fl)
            stamp(a, T[0] - bx, T[1] - by, tone)
        return
    if sty == 'needles':
        a = np.array([list(r) for r in SP.SEEDLING])
        if out > 0: a = a[:, ::-1]
        w_ = a.shape[1]
        if winter:
            g = ground_spot((oy - 2, oy + 2), 2 + w_ / 2.0)
            if g is None: return
            xe, Y0 = g[0] - w_ / 2.0, oy + 1 - a.shape[0] + 1 + g[1]
            stamp(a, xe, Y0, SP.TONE_DARK)
            import bare23 as B
            for x in range(a.shape[1]):
                for y in range(a.shape[0]):
                    if a[y, x] == '.': continue
                    if (y == 0 or a[y - 1, x] == '.') and a[y, x] in 'OH':
                        put(round(Y0) + y, round(xe) + x, B.SNOW_RGB[4 if x > a.shape[1] // 2 else 3])
            return
        Yg = oy + 1
        g = ground_spot((Yg - 3, Yg + 1), 2 + w_ / 2.0)
        if g is None: return
        xe, Y0 = g[0] - w_ / 2.0, Yg - a.shape[0] + 1 + g[1]
        stamp(a, xe, Y0, SP.TONE_MID)
        st.sprout_box = (int(round(Y0)), int(round(xe)), a.shape)
        return
    # on the trunk's side at about half the break's height, at the turned azimuth
    Ys = oy - int(round(st.hs * rng.uniform(0.45, 0.6)))
    xs_ = np.nonzero(trunk[Ys])[0]
    if not len(xs_): return
    m = (xs_.min() + xs_.max()) / 2.0; hw = (xs_.max() - xs_.min()) / 2.0
    sx, sy = m + hw * cth, Ys + zs * hw * sth
    for k in range(3):
        sx += cth; sy += zs * sth - (1 if k % 2 else 0)
        put(sy, sx, np.round(ramp[2]).astype(np.uint8))
    tip = (sx + 2 * cth, sy + 2 * zs * sth - 2)
    if winter:
        import bare23 as B
        bark = np.asarray(st.bark, float)
        tw = [(1, -1), (2, -2), (3, -3), (2, -1), (3, 0), (4, -1)]
        for dx, dy in tw:
            put(sy + dy + dx * zs * sth, sx + dx * cth, np.round(bark[2 if dy < -1 else 1]).astype(np.uint8))
        for dx, dy in ((3, -4), (4, -2)):
            put(sy + dy + dx * zs * sth, sx + dx * cth, B.SNOW_RGB[4])
        return
    tx, ty = int(round(tip[0])), int(round(tip[1]))
    if sty == 'dots':
        br = SP.L123['dots']['brushes']
        spots = [(-3, -2, 0), (2, -3, 0), (-1, 1, 1), (3, 0, 1), (0, -5, 1), (-4, 2, 2), (1, -1, 2), (4, -3, 2)]
        for dx, dy, lay in spots:
            b = br[rng.choice((0, 0, 2, 3, 4))]
            a = SP.turned(b, rng.randint(0, 3), rng.random() < 0.5)
            tone = (SP.TONE_DARK, SP.TONE_MID, SP.TONE_LIT)[lay]
            stamp(a, tx + dx * out - a.shape[1] // 2, ty + dy - a.shape[0] // 2, tone)
        return
    if sty == '122':
        pool = SP.L122
    elif sty == 'maple':
        import module_maple as MM
        pool = [MM.BRUSHES[2], MM.BRUSHES[1]]
    else:
        pool = SP.L123[sty]['brushes']
    if sty == 'blades':
        br = pool
        fan = [(0, out < 0, SP.TONE_DARK), (0, out > 0, SP.TONE_MID), (3 if out > 0 else 1, out < 0, SP.TONE_LIT),
               (0, out < 0, SP.TONE_LIT)]
        for i, (k, fl, tone) in enumerate(fan):
            a, (by, bx) = SP.based(br[rng.randrange(len(br))], k, fl)
            dx = (i == 3) * out * 2
            stamp(a, tx + dx - bx, ty + 1 - by, tone)
        return
    places = [(-2, -5, SP.TONE_DARK), (3, -5, SP.TONE_MID), (-2, -1, SP.TONE_MID), (3, -1, SP.TONE_MID),
              (1, -7, SP.TONE_LIT), (1, -2, SP.TONE_LIT)]
    if sty == 'maple': places = [(-1, -5, SP.TONE_MID), (3, -1, SP.TONE_LIT)]
    for i, (dx, dy, tone) in enumerate(places):
        b = pool[rng.randrange(len(pool))]
        k = rng.randint(0, 3) if sty == '122' else (0 if i != 1 else (1 if out > 0 else 3))
        a = SP.turned(b, k, (out > 0) ^ (rng.random() < 0.3))
        stamp(a, tx + dx * out - a.shape[1] // 2, ty + dy - a.shape[0] // 2, tone)


# ---------------------------------------------------------------- winter: snow on the turned break
def snow_on_break24(st, P=None):
    """broken23.snow_on_break for the turned break: the layer's footprint over the face's disc, its ground row rising
    along the turned slope (sl (gx x + gz z)), the bumps and the outline's wobble turned with the trunk; the near
    splinters in front of it."""
    import bare23 as B
    P = dict(S.LAYER, **(P or {}))
    P['t_k'] *= 0.85
    rng = random.Random(st.seed * 7 + 31)
    rc, zs, xc = st.rc, st.zs, st.xc
    sl, gx, gz, rot = st.sl, st.gx, st.gz, st.rot
    ca, sa = math.cos(rot), math.sin(rot)
    L = np.asarray(st.L, float)
    T0 = float(np.clip(P['t_k'] * rc, P['t_lo'], P['t_hi']))
    rx = rc + P['grow']; rzw = rc + P['grow'] + P['over'] / zs
    yc0 = st.Yf - rc * zs + P['over'] * 0.5
    bumps = []
    for i in range(P['bumps'] if rc >= 3.5 else 1):
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9) if i < 2 else rng.uniform(0, math.tau)
        q = rng.uniform(0.25, 0.65)
        bx, bz = q * rx * math.cos(a), q * rzw * math.sin(a)
        if rot: bx, bz = ca * bx - sa * bz, sa * bx + ca * bz
        bumps.append((bx, bz, T0 * rng.uniform(*P['bump_h']), rc * rng.uniform(*P['bump_s'])))
    w1, w2 = rng.uniform(0, math.tau) - 3 * rot, rng.uniform(0, math.tau) - 5 * rot
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
        for z, tt, gx_, gz_ in zip(z_ok, t_ok, tx, tz):
            Yg = yc0 + z * zs - sl * (gx * x + gz * z)
            top, base = Yg - tt, Yg
            n = np.array([-gx_ - sl * gx, 1.0, -gz_ - sl * gz]); n /= np.linalg.norm(n)
            for Y in range(int(math.floor(top)), int(math.floor(base)) + 1):
                if Y + 0.5 < top - 0.25 or Y + 0.5 > base + 0.5: continue
                nrm[(Y, X)] = n
    m = np.zeros((H, W), bool); tone = np.zeros((H, W), int)
    for (Y, X), n in nrm.items():
        if 0 <= Y < H and 0 <= X < W:
            d = float(n @ L) + P['lit']
            m[Y, X] = True
            tone[Y, X] = 5 if d > 0.78 else 4 if d > 0.5 else 3 if d > 0.2 else 2 if d > -0.1 else 1
    sp = st.spikes_m & ~st.face
    spb = sp & ~st.sp_front
    m &= ~(spb & (np.arange(H)[:, None] < st.back[None, :] - 1))
    m &= ~st.sp_front
    for X in np.nonzero(sp.any(0))[0]:
        Y = int(np.nonzero(sp[:, X])[0].min())
        front_col = bool(st.sp_front[Y, X])
        if Y - 1 >= 0 and not m[Y - 1, X] and (front_col or Y < st.back[X] - 1):
            m[Y - 1, X] = True; tone[Y - 1, X] = 4
    tv = np.where(B.rim_of(m), 5 + tone, tone)
    pic = st.pic.copy()
    pic[m] = B.SNOW_EXT[tv[m]]
    st.snow = m
    st.mask = st.mask | m
    return pic
