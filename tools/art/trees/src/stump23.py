# Round 23 step 3: stumps of felled trees (mockup, no game code).
# A stump is the approved tree's own trunk (its foot by size: 122 roots / 123 barrel / 124 tap root, its bark,
# its lean) cut low over the ground, with the cut face (the end grain) on top. The game looks straight down with
# the shear z -= y, so the cut face, a level disc, shows as a circle as wide as the trunk at the cut, standing on
# the bark of the front side (as the game's own stumps do today, survivium-builds/trees/stumps/).
#   body(t, hs)   the trunk drawn by the tree's own code with no crown and no limbs, cut at the front-edge row
#                 hs px over the ground row; the rows between the face's middle and the cut carry the bark row
#                 at the cut up (the side of the trunk beside the face's lower half)
#   face(...)     the end grain: bark ring, sapwood ring (lit on the sun's side), heartwood with wobbly growth rings
#                 round an off-centre pith, a check or two; palms fibrous dots, no rings; the dead tree grey, cracked
#   snow_cap(...) winter: a lumpy cushion of snow on the face (the approved snow ramp, soft outline /2)
#   shadow        the stump's ground shadow by the game sun (a short cylinder cast like the trunks of the trees)
import math, os, random, numpy as np
import all23 as A
import render7 as R

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '..', 'cache23st')

def hexc(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


class CutLimb:
    """A limb cut at its parameter tc: the same curve and radius below the cut, sampled over its first part."""
    def __init__(self, lb, tc):
        self.lb, self.tc = lb, tc
        self.seed, self.level = lb.seed, lb.level
        self.P = getattr(lb, 'P', None)
    def at(self, t):
        return self.lb.at(t * self.tc)
    def r(self, t):
        return self.lb.r(t * self.tc)
    def length(self):
        pts = [self.at(t) for t in np.linspace(0, 1, 40)]
        return float(sum(np.linalg.norm(b - a) for a, b in zip(pts, pts[1:])))


def t_at_height(lb, h):
    ts = np.linspace(0, 1, 600); ys = np.array([lb.at(x)[1] for x in ts])
    if h <= ys[0]: return 0.02
    if h >= ys[-1]: return 1.0
    return float(np.interp(h, ys, ts))


def trunk_picture(t, h_top):
    """The tree's trunk alone (no crown, no limbs), up to h_top over the ground, on the key colour; foot ox, oy."""
    tl = t.limbs[0]
    t.limbs = [CutLimb(tl, t_at_height(tl, h_top))]
    t.crown = False
    t.mods = []
    img = t.render(ground=A.KEY_G, shade=A.KEY_G)
    mask = np.any(img != hexc(A.KEY_G).astype(np.uint8), 2)
    return img, mask


# ---------------------------------------------------------------- the wood of the cut face
# The reference's cut face (references/user-palms-snow.jpg, the stumps at the right bottom): light wood c4a07c with
# growth rings 906854, a mid ring a48068 inside the outline on the side away from the sun, the dark bark 4c2420
# round the back. Ramp steps: 0 cracks and the pith, 1 a deep ring, 2 the rings, 3 mid, 4 the wood, 5 lit sapwood.
WOOD = ['5e3e30', '7a5442', '906854', 'a48068', 'c4a07c', 'dcbc96']

# per species: (hue shift deg, saturation x, value x, coloured heartwood, cracks, ring spacing x)
SPECIES_WOOD = {
    'oak':         (0, 1.00, 1.00, False, 1, 1.0),
    'linden':      (8, 0.62, 1.08, False, 1, 1.15),
    'birch':       (12, 0.45, 1.13, False, 1, 1.15),
    'acacia':      (10, 1.10, 1.02, True, 1, 1.0),
    'mangrove':    (-12, 1.15, 0.92, True, 1, 1.0),
    'apple':       (-6, 0.95, 1.02, False, 1, 1.0),
    'cherry':      (-14, 1.12, 0.96, True, 1, 1.0),
    'poplar':      (10, 0.55, 1.10, False, 1, 1.2),
    'ceiba':       (12, 0.55, 1.10, False, 1, 1.3),
    'maple':       (6, 0.72, 1.08, False, 1, 1.0),
    'red_maple':   (-8, 0.82, 1.05, False, 1, 1.0),
    'bird_cherry': (0, 0.90, 1.02, False, 1, 1.0),
    'rowan':       (-5, 1.00, 1.00, False, 1, 1.0),
    'willow':      (-4, 0.72, 1.06, False, 1, 1.2),
    'deadwood':    (0, 0.22, 0.86, False, 4, 1.0),
    'spruce':      (10, 0.78, 1.08, False, 1, 0.9),
    'fir':         (10, 0.70, 1.10, False, 1, 0.9),
    'larch':       (-8, 1.10, 0.98, True, 1, 0.85),
    'pine':        (4, 1.18, 1.04, True, 1, 0.9),
    'palm':        (0, 0.85, 0.92, False, 0, 1.0),
    'fan_palm':    (0, 0.85, 0.92, False, 0, 1.0),
}
RESIN = ('spruce', 'fir', 'larch', 'pine')
RESIN_RGB = hexc('e0a040')

def _hsv(rgb):
    import colorsys
    return colorsys.rgb_to_hsv(*(np.asarray(rgb, float) / 255.0))

def _rgb(h, s, v):
    import colorsys
    return np.array(colorsys.hsv_to_rgb(h % 1.0, min(1.0, s), min(1.0, v))) * 255.0

def wood_ramp(key):
    dh, ks, kv = SPECIES_WOOD.get(key, SPECIES_WOOD['oak'])[:3]
    out = []
    for h in WOOD:
        hh, ss, vv = _hsv(hexc(h))
        out.append(_rgb(hh + dh / 360.0, ss * ks, vv * kv))
    return np.round(np.array(out)).clip(0, 255)


def face_roles(rc, xc, yc, box, seed, key, L, zs=1.0):
    """Per pixel of the box (Y0, Y1, X0, X1) the face's tone: ('bark', step) for the bark ring, ('wood', step);
    returned as two int maps (-1 outside): bark step and wood step."""
    Y0, Y1, X0, X1 = box
    rng = random.Random(seed)
    yy, xx = np.mgrid[Y0:Y1, X0:X1]
    dx = xx + 0.5 - xc; dy = (yy + 0.5 - yc) / zs
    d = np.sqrt(dx * dx + dy * dy)
    inside = dx * dx + dy * dy <= rc * rc + 0.3
    e = rc - d
    bark = np.full(dx.shape, -1, int); wood = np.full(dx.shape, -1, int)
    dh, ks, kv, heart, cracks, spk = SPECIES_WOOD.get(key, SPECIES_WOOD['oak'])
    nl = (dx * L[0] + dy * zs * L[2]) / np.maximum(d, 1e-6)           # the rim's facing to the sun (level part)
    # 1. the bark ring: the back half dark (the outline), the front half the bark lit by its side
    ring0 = inside & (e < 1.0)
    back = dy < 0.0
    thick = rc >= 3.5
    band = np.where(nl > -0.05, 0, np.where(nl > -0.36, -1, -2))
    bark[ring0 & back] = 0
    if thick:
        bark[ring0 & ~back] = np.clip(2 + band, 1, 3)[ring0 & ~back]
    # 2. the sapwood ring: lit on the sun's side, mid on the other
    ring1 = inside & ~(bark >= 0) & (e < (2.0 if thick else 1.6))
    wood[ring1] = np.where(nl > 0.3, 5, np.where(nl < -0.3, 3, 4))[ring1]
    core = inside & (bark < 0) & (wood < 0)
    wood[core] = 4
    if key in ('palm', 'fan_palm'):
        # a palm has no rings: fibres, dark dots all over, the middle a little lighter
        r2 = np.random.default_rng(seed)
        dots = r2.random(dx.shape) < 0.32
        wood[core & dots] = 2
        wood[core & dots & (r2.random(dx.shape) < 0.3)] = 1
        wood[core & (d < 0.35 * rc) & ~dots] = 5
        return bark, wood, inside
    # 3. the heartwood: wobbly growth rings round an off-centre pith
    phi = rng.uniform(0, math.tau)
    off = rng.uniform(0.1, 0.22) * rc
    px_, py_ = xc + off * math.cos(phi), yc + off * math.sin(phi) * zs
    ddx = xx + 0.5 - px_; ddy = (yy + 0.5 - py_) / zs
    dp = np.sqrt(ddx * ddx + ddy * ddy); th = np.arctan2(ddy, ddx)
    f1, f2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    dw = dp * (1 + 0.07 * np.sin(2 * th + f1) + 0.05 * np.sin(3 * th + f2))
    if heart:
        wood[core & (dw < 0.55 * (rc - 2))] = 3
    sp = max(2.6, rc / 3.0) * spk
    k_max = int((rc - 2.2) / sp)
    # the screen distance to a ring: the squashed face packs the rings closer in y, so measure across the line
    grad = np.sqrt(np.cos(th) ** 2 + (np.sin(th) / zs) ** 2) * np.maximum(0.6, dw / np.maximum(dp, 1e-6))
    r3 = np.random.default_rng(seed + 5)
    for k in range(1, k_max + 1):
        dist = np.abs(dw - k * sp) / grad
        on = core & (dist < 0.5)
        # a gap or two in each ring, as the reference's broken arcs
        for _ in range(rng.randint(0, 2) if k > 1 else 0):
            a0 = rng.uniform(-math.pi, math.pi); w_ = rng.uniform(0.3, 0.7)
            on &= np.abs(np.remainder(th - a0 + math.pi, math.tau) - math.pi) > w_ / 2
        # the latewood beside the line, now and then (the reference's mid tone along its rings)
        soft = core & ~on & (dist < 1.5) & (dw < k * sp) & (r3.random(dw.shape) < 0.3)
        wood[soft & (wood == 4)] = 3
        wood[on] = 2
    # a few specks of the mid tone in the wood
    wood[core & (wood == 4) & (r3.random(dw.shape) < 0.04)] = 3
    # the pith
    pith = core & (dp < (0.9 if rc >= 4 else 0.6))
    wood[pith] = 0 if rc >= 5 else 2
    # checks: dry cracks out from the pith
    n_cr = cracks if rc >= 6 else (1 if (cracks > 1 and rc >= 4) else 0)
    for _ in range(n_cr):
        a = rng.uniform(-math.pi, math.pi)
        ln = rng.uniform(0.45, 0.8) * rc if cracks < 3 else rng.uniform(0.6, 0.95) * rc
        ux, uy = math.cos(a), math.sin(a)
        along = ddx * ux + ddy * uy
        across = np.abs(-ddx * uy + ddy * ux)
        cr = core & (along > 0.5) & (along < ln) & (across < 0.5 + 0.25 * (along < ln * 0.4))
        wood[cr] = np.where(along[cr] < ln * 0.7, 0, 1)
    # resin: a few amber drops in the sapwood of the conifers
    if key in RESIN and rc >= 4:
        cand = np.argwhere(ring1 | (core & (e < 3)))
        for _ in range(rng.randint(1, 3)):
            if len(cand) == 0: break
            y_, x_ = cand[rng.randrange(len(cand))]
            wood[y_, x_] = 9
    return bark, wood, inside


# ---------------------------------------------------------------- the stump
HS_K = 0.4           # the cut's height over the ground (the front edge of the face): 0.4 of the trunk's width
FACE_ZS = 0.6        # the face's height / width on the screen (the reference's ~0.6; the game's straight-down view: 1)
HS_MIN = 3

def _run_at(row, x_axis):
    """The run of True in `row` that holds (or is nearest to) the column x_axis: (x_left, x_right)."""
    xs = np.nonzero(row)[0]
    if len(xs) == 0: return None
    runs, st = [], xs[0]
    for a, b in zip(xs, xs[1:]):
        if b != a + 1: runs.append((st, a)); st = b
    runs.append((st, xs[-1]))
    return min(runs, key=lambda r: 0 if r[0] <= x_axis <= r[1] else min(abs(r[0] - x_axis), abs(r[1] - x_axis)))


class Stump:
    """The stump of the approved tree `key` of size s: picture on the key colours (ground KEY_G, shadow KEY_S),
    with its foot at (ox, oy) like the trees' cache; hs = the cut's height (front edge) over the ground row."""
    def __init__(self, key, s, hs=None, hs_k=HS_K, seed=None, sun=None, face_zs=FACE_ZS):
        self.key, self.s, self.hs_k, self.face_zs = key, s, hs_k, face_zs
        self.seed = seed if seed is not None else (sum(ord(c) * (i + 1) for i, c in enumerate(key)) + int(round(s * 100))) % 997
        if key in ('palm', 'fan_palm'):
            self._palm(sun)
            return
        t = A.build(key, s)
        if sun is not None:
            t.L = R.norm(sun)
        self.t, self.L = t, np.asarray(t.L, float)
        tl = t.limbs[0]
        r0 = float(tl.r(0.0))
        self.hs = hs if hs is not None else max(HS_MIN, int(round(hs_k * 2 * r0)))
        img, mask = trunk_picture(t, self.hs + 3 * r0 + 6)
        self.zs = face_zs
        self.bark = np.array(t.bark, float)
        self.ox, self.oy = float(t.ox), float(t.oy)
        x_axis = t.ox + float(tl.at(t_at_height(tl, self.hs))[0])
        self._cut(img, mask, x_axis)

    def _palm(self, sun):
        import palmtree22 as PT, palm22 as P
        kind = 'feather' if self.key == 'palm' else 'fan'
        p = PT.Palm(kind, self.s)
        L = R.norm(sun if sun is not None else p.sun)
        self.L = np.asarray(L, float)
        tr = p.trunk
        r0 = float(tr.r_foot)
        self.hs = max(HS_MIN, int(round(self.hs_k * 2 * r0)))
        # a short trunk of the palm's own: its foot's radius and scales, standing straight
        Ht = self.hs + 2 * r0 + 6
        st = PT.Trunk(Ht=Ht, r_foot=tr.r_foot, r_top=tr.r_foot + (tr.r_top - tr.r_foot) * Ht / tr.Ht,
                      lean=(tr.lean[0] * Ht / tr.Ht * 0.3, 0.0), pu=tr.pu, pv=tr.pv, seed=tr.seed, spikes=tr.spikes,
                      spike2=tr.spike2, nubs=tr.nubs)
        W, H = p.W, p.H
        ox, oy = p.ox, p.oy
        tx = {}
        steps, mask = PT.draw_trunk(st, W, H, ox, oy, L, None, spike_top=None, extra=tx)
        bark = np.array([hexc(h) for h in p.bark])
        img = np.zeros((H, W, 3), np.uint8); img[:] = hexc(A.KEY_G)
        m = steps >= 0
        img[m] = bark[steps[m]].round().astype(np.uint8)
        if p.soft != 1:                             # the approved soft outline (contrast / 2)
            ln = tx['line'] & m
            c_own = bark[np.clip(tx['pre'][ln], 0, 3)]
            img[ln] = (c_own + (bark[steps[ln]] - c_own) / p.soft).round().astype(np.uint8)
        self.bark = bark
        self.zs = P.ZS * self.face_zs
        self.ox, self.oy = float(ox), float(oy)
        self.t = None
        self._cut(img, m, ox)

    def _cut(self, img, mask, x_axis):
        """Cut the trunk picture at the front-edge row Yf = oy - hs: the face is a disc as wide as the trunk at that
        row, its lower edge on the row; between the face's middle and the cut the side carries row Yf's bark up."""
        oy = int(round(self.oy))
        Yf = oy - self.hs
        run = _run_at(mask[Yf], x_axis)
        xl, xr = run
        rc = (xr - xl + 1) / 2.0
        xc = xl + rc
        yc = Yf - rc * self.zs
        self.rc, self.xc, self.yc, self.Yf = rc, xc, yc, Yf
        H, W = mask.shape
        pic = np.zeros_like(img); pic[:] = hexc(A.KEY_G)
        keep = np.zeros_like(mask)
        keep[Yf:] = mask[Yf:]
        pic[keep] = img[keep]
        Y0 = int(math.floor(yc - rc * self.zs)) - 1
        box = (Y0, Yf, xl - 1, xr + 2)
        bark_s, wood_s, inside = face_roles(rc, xc, yc, box, self.seed, self.key, self.L, self.zs)
        # the side beside the face's lower half
        for Y in range(int(math.floor(yc)), Yf):
            for X in range(xl, xr + 1):
                if mask[Yf, X] and not inside[Y - Y0, X - box[2]] and Y + 0.5 >= yc:
                    pic[Y, X] = img[Yf, X]; keep[Y, X] = True
        wr = wood_ramp(self.key)
        ys, xs = np.nonzero(inside)
        for y_, x_ in zip(ys, xs):
            Y, X = y_ + Y0, x_ + box[2]
            if bark_s[y_, x_] >= 0:
                c = self.bark[bark_s[y_, x_]]
            elif wood_s[y_, x_] == 9:
                c = RESIN_RGB
            else:
                c = wr[wood_s[y_, x_]]
            pic[Y, X] = np.round(c).astype(np.uint8); keep[Y, X] = True
        self.face = np.zeros_like(mask)
        self.face[ys + Y0, xs + box[2]] = True
        # the ground shadow: the stump as a short cylinder (axis rc behind the front edge), cast by the sun
        L = self.L
        sh = np.zeros_like(mask)
        if L[1] > 0.1:
            YY, XX = np.mgrid[0:H, 0:W]
            zc = oy - rc * self.zs                # the axis on the ground (its front at the ground row)
            for h in np.arange(0, self.hs + 0.01, 0.5):
                cx_ = xc - L[0] / L[1] * h; cz_ = zc - L[2] / L[1] * h * self.zs
                sh |= (XX + 0.5 - cx_) ** 2 + ((YY + 0.5 - cz_) / self.zs) ** 2 <= rc * rc
        pic[sh & ~keep] = hexc(A.KEY_S)
        self.pic, self.mask = pic, keep
        self.shadow = sh & ~keep

    def picture(self):
        return self.pic


# ---------------------------------------------------------------- winter: a cushion of snow on the cut
# The approved snow (round 23 winter, bare23): the reference's ramp 40545c .. f0fcfc, round lumps lit by the game sun,
# neighbours merged into one patch with the light running over smoothly (patch_soft, tau 1.5), the outline soft (/2).
# On a stump the snow lies on the level cut: lumps along the face's long axis, each as tall as the face, their union
# clipped to the face (a pixel over its front edge, a pixel or two over its back edge where a lump rises), and one or
# two smaller lumps on top so the cushion's top is uneven. The hot-zone trees (palms, acacia, ceiba, mangrove) keep
# no snow, as their trees (user 2026-11-24 15:20 MSK «1. А»).
HOT = ('palm', 'fan_palm', 'acacia', 'ceiba', 'mangrove')
SNOWCAP = dict(flat=0.85, lift=0.5, over=1.0, rise=2.0, top=2, top_k=0.55, lit=0.25, tau=1.5, jit=0.12)

def snow_cap(st, P=None):
    """The stump's picture (key colours) with snow on its cut: a copy of st.pic; also st.snow (the snow's mask)."""
    import bare23 as B
    P = dict(SNOWCAP, **(P or {}))
    rng = random.Random(st.seed * 7 + 31)
    rc, rz, xc, yc = st.rc, st.rc * st.zs, st.xc, st.yc
    L = st.L
    flat = P['flat']
    rb0 = (rz + 0.9) / flat                           # a lump as tall as the face (and a little more)
    n = max(1, int(round(2 * rc / (1.25 * rb0))))
    if n == 1: xs = [xc]
    else:
        span = max(0.0, rc - 0.75 * rb0)
        xs = [xc - span + 2 * span * i / (n - 1) for i in range(n)]
    grp = []
    for x_ in xs:
        rb = rb0 * (1 + rng.uniform(-P['jit'], P['jit']))
        grp.append((x_ + rng.uniform(-0.3, 0.3), yc - P['lift'] + rng.uniform(-0.3, 0.3), rb, 0.0, 0))
    for _ in range(P['top'] if rc >= 4 else 0):       # smaller lumps on top: an uneven top edge
        rb = rb0 * P['top_k'] * (1 + rng.uniform(-0.15, 0.15))
        x_ = xc + rng.uniform(-0.55, 0.55) * rc
        grp.append((x_, yc - rz * 0.45 - P['lift'], rb, 0.0, 0))
    x0 = int(math.floor(xc - rc)) - 3; x1 = int(math.ceil(xc + rc)) + 3
    y0 = int(math.floor(yc - rz - P['rise'])) - 4; y1 = int(math.ceil(yc + rz + P['over'])) + 3
    h_, w_ = y1 - y0 + 1, x1 - x0 + 1
    if len(grp) > 1:
        m, tone, _ = B.patch_soft(grp, L, P['lit'], flat, x0, y0, h_, w_, P['tau'])
    else:
        sx, cy, rb, _, _ = grp[0]
        tt, ins, nz, ri = B.ball_parts(rb, L, 0, P['lit'], flat, sx - round(sx), cy - round(cy))
        m = np.zeros((h_, w_), bool); tone = np.zeros((h_, w_), int)
        oy_, ox_ = int(round(cy)) - ri - y0, int(round(sx)) - ri - x0
        m[oy_:oy_ + ins.shape[0], ox_:ox_ + ins.shape[1]] = ins
        tone[oy_:oy_ + ins.shape[0], ox_:ox_ + ins.shape[1]] = tt
    # the clip: the face's width, from `rise` px over its back edge to `over` px under its front edge
    yy, xx = np.mgrid[y0:y0 + h_, x0:x0 + w_]
    cy_c = yc + (P['over'] - P['rise']) / 2; ry_c = rz + (P['over'] + P['rise']) / 2
    clip = ((xx + 0.5 - xc) / (rc + 0.45)) ** 2 + ((yy + 0.5 - cy_c) / ry_c) ** 2 <= 1.0
    m &= clip
    tv = np.where(B.rim_of(m), 5 + tone, tone)
    pic = st.pic.copy()
    H, W = pic.shape[:2]
    ys, xs_ = np.nonzero(m)
    Y, X = ys + y0, xs_ + x0
    ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
    pic[Y[ok], X[ok]] = B.SNOW_EXT[tv[ys[ok], xs_[ok]]]
    snow = np.zeros((H, W), bool); snow[Y[ok], X[ok]] = True
    st.snow = snow
    return pic


# The cushion as a layer (second try: the first, lumps as tall as the face, read as a ball of snow on the stump): a
# snow layer of thickness T over the face, flat on top with rounded edges, T0 = 0.22 x the trunk's radius (1.2..3.2
# px), two or three soft bumps on it; each pixel shows the nearest point of the layer (the game's view: a level top
# lit by the sun is the palest tone, its front rim and the side away from the sun go blue-grey), outline soft (/2).
# T0 0.22 x the radius looked like a marshmallow on the stump: 0.14 (0.9..2.6 px).
LAYER = dict(t_k=0.14, t_lo=0.9, t_hi=2.6, edge=8, bumps=3, bump_h=(0.4, 0.8), bump_s=(0.2, 0.3), over=0.7,
             grow=0.0, lit=0.2, wob=0.06)

def snow_layer(st, P=None):
    import bare23 as B
    P = dict(LAYER, **(P or {}))
    rng = random.Random(st.seed * 7 + 31)
    rc, zs, xc, yc = st.rc, st.zs, st.xc, st.yc
    L = np.asarray(st.L, float)
    T0 = float(np.clip(P['t_k'] * rc, P['t_lo'], P['t_hi']))
    rx = rc + P['grow']; rzw = rc + P['grow'] + P['over'] / zs     # footprint radii (world x, world z)
    zc = (yc + P['over'] * 0.5)                                       # the footprint's middle on the screen
    bumps = []
    for i in range(P['bumps'] if rc >= 3.5 else 1):
        # mostly over the back half, so the top edge of the cushion goes up and down
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9) if i < 2 else rng.uniform(0, math.tau)
        q = rng.uniform(0.25, 0.65)
        bumps.append((q * rx * math.cos(a), q * rzw * math.sin(a), T0 * rng.uniform(*P['bump_h']),
                      rc * rng.uniform(*P['bump_s'])))
    w1, w2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    def thick(x, z):                                                  # x, z world units from the middle
        th_ = np.arctan2(z / rzw, x / rx)
        wob = 1 + P['wob'] * (0.6 * np.sin(3 * th_ + w1) + 0.4 * np.sin(5 * th_ + w2))
        u = np.sqrt((x / rx) ** 2 + (z / rzw) ** 2) / wob
        t = T0 * np.sqrt(np.clip(1 - u ** P['edge'], 0, 1))
        for bx, bz, bh, bs in bumps:
            t = t + bh * np.exp(-((x - bx) ** 2 + (z - bz) ** 2) / (2 * bs * bs)) * (u < 1)
        return np.where(u < 1, t, -1.0)
    X0 = int(math.floor(xc - rx * 1.1)) - 1; X1 = int(math.ceil(xc + rx * 1.1)) + 1
    zs_ = np.arange(-rzw * 1.1, rzw * 1.1 + 1e-6, 0.08)
    H, W = st.pic.shape[:2]
    nrm = {}
    for X in range(X0, X1 + 1):
        x = X + 0.5 - xc
        t = thick(np.full(zs_.shape, x), zs_)
        ok = t >= 0
        if not ok.any(): continue
        z_ok, t_ok = zs_[ok], t[ok]
        dz = 0.04; dx = 0.04
        tz = (thick(np.full(z_ok.shape, x), z_ok + dz) - thick(np.full(z_ok.shape, x), z_ok - dz)) / (2 * dz)
        tx = (thick(np.full(z_ok.shape, x + dx), z_ok) - thick(np.full(z_ok.shape, x - dx), z_ok)) / (2 * dx)
        tz = np.where(np.isfinite(tz) & (np.abs(tz) < 40), tz, 0.0); tx = np.where(np.isfinite(tx) & (np.abs(tx) < 40), tx, 0.0)
        for z, tt, gx, gz in zip(z_ok, t_ok, tx, tz):             # far to near: the nearer column wins
            Yg = zc + z * zs
            top, base = Yg - tt, Yg
            n = np.array([-gx, 1.0, -gz]); n /= np.linalg.norm(n)
            for Y in range(int(math.floor(top)), int(math.floor(base)) + 1):
                if Y + 0.5 < top - 0.25 or Y + 0.5 > base + 0.5: continue
                nrm[(Y, X)] = n
    m = np.zeros((H, W), bool); tone = np.zeros((H, W), int)
    for (Y, X), n in nrm.items():
        if 0 <= Y < H and 0 <= X < W:
            d = float(n @ L) + P['lit']
            m[Y, X] = True
            tone[Y, X] = 5 if d > 0.78 else 4 if d > 0.5 else 3 if d > 0.2 else 2 if d > -0.1 else 1
    tv = np.where(B.rim_of(m), 5 + tone, tone)
    pic = st.pic.copy()
    pic[m] = B.SNOW_EXT[tv[m]]
    st.snow = m
    return pic


# Option Б: the approved snow balls of the bare trees (bare23: radii x1.4, half of the touching ones merged into one
# patch, the light running over smoothly, soft outline) lying on the cut, the wood showing between them.
LUMPS = dict(rb_k=0.3, rb_lo=1.6, rb_hi=4.6, gap=0.95, cover=0.55, merge=0.5, flat=0.92, lit=0.25, tau=1.5)

def snow_lumps(st, P=None):
    import bare23 as B
    P = dict(LUMPS, **(P or {}))
    rng = random.Random(st.seed * 11 + 7)
    rc, zs, xc, yc = st.rc, st.zs, st.xc, st.yc
    rz = rc * zs
    L = np.asarray(st.L, float)
    rb0 = float(np.clip(P['rb_k'] * rc, P['rb_lo'], P['rb_hi']))
    area = math.pi * rc * rz
    n_want = max(1, int(round(P['cover'] * area / (math.pi * rb0 * rb0))))
    placed = []
    for _ in range(400):
        if len(placed) >= n_want: break
        a = rng.uniform(0, math.tau); q = math.sqrt(rng.uniform(0, 1)) * 0.75
        x = xc + q * rc * math.cos(a); y = yc + q * rz * math.sin(a)
        rb = rb0 * rng.uniform(0.8, 1.2)
        cy = y - rb * 0.45                             # it lies on the cut: its pad's foot at the point
        if any((x - x2) ** 2 + (cy - y2) ** 2 < (P['gap'] * (rb + r2)) ** 2 for x2, y2, r2, _, _ in placed): continue
        placed.append((x, cy, rb, y, 0))
    if not placed: placed = [(xc, yc - rb0 * 0.45, rb0, yc, 0)]
    # merge some touching neighbours into one patch (union-find, as bare23.snow_balls)
    n = len(placed); up = list(range(n))
    def root(a):
        while up[a] != a: up[a] = up[up[a]]; a = up[a]
        return a
    for a in range(n):
        for b in range(a + 1, n):
            xa, ya, ra, _, _ = placed[a]; xb, yb, rb_, _, _ = placed[b]
            if (xa - xb) ** 2 + (ya - yb) ** 2 < (1.15 * (ra + rb_)) ** 2 and rng.random() < P['merge']:
                up[root(a)] = root(b)
    groups = {}
    for a in range(n): groups.setdefault(root(a), []).append(placed[a])
    pic = st.pic.copy(); H, W = pic.shape[:2]
    snow = np.zeros((H, W), bool)
    for grp in sorted(groups.values(), key=lambda g: max(b[3] for b in g)):     # far to near
        x0 = int(math.floor(min(b[0] - b[2] for b in grp))) - 3; x1 = int(math.ceil(max(b[0] + b[2] for b in grp))) + 3
        y0 = int(math.floor(min(b[1] - b[2] for b in grp))) - 3; y1 = int(math.ceil(max(b[1] + b[2] for b in grp))) + 3
        h_, w_ = y1 - y0 + 1, x1 - x0 + 1
        g2 = [(b[0], b[1], b[2], b[3], b[4]) for b in grp]
        if len(g2) > 1:
            m, tone, _ = B.patch_soft(g2, L, P['lit'], P['flat'], x0, y0, h_, w_, P['tau'])
        else:
            sx, cy, rb, _, _ = g2[0]
            tt, ins, nz, ri = B.ball_parts(rb, L, 0, P['lit'], P['flat'], sx - round(sx), cy - round(cy))
            m = np.zeros((h_, w_), bool); tone = np.zeros((h_, w_), int)
            oy_, ox_ = int(round(cy)) - ri - y0, int(round(sx)) - ri - x0
            m[oy_:oy_ + ins.shape[0], ox_:ox_ + ins.shape[1]] = ins
            tone[oy_:oy_ + ins.shape[0], ox_:ox_ + ins.shape[1]] = tt
        tv = np.where(B.rim_of(m), 5 + tone, tone)
        ys, xs_ = np.nonzero(m)
        Y, X = ys + y0, xs_ + x0
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        ys, xs_, Y, X = ys[ok], xs_[ok], Y[ok], X[ok]
        v = tv[ys, xs_]
        v = np.where((v >= 6) & snow[Y, X], v + 5, v)            # the seam where it lies over another patch
        pic[Y, X] = B.SNOW_EXT[v]
        snow[Y, X] = True
    st.snow = snow
    return pic
