# Round 21, step 2: conifers built from reference 124's fronds (module124), the way the reference builds its tree:
# a straight trunk, tiers of drooping branches (a cone of tiers; the pine: a few flat clumps on limbs at the top of a
# tall trunk), one frond at the end of every branch, picked among the 25 fronds and their mirror images by the
# branch's direction on the screen and its length, its tip on the branch's tip. Light like our leaf modules: a
# frond's step is the band of the crown's normal where it lies . sun (one band higher than the leaf modules': the
# frond darkens its turned-away half, its strokes and its root); the frond's half turned away from the sun -1,
# outline and needle strokes -1, the root third under the tier above -1, the tip of a lit half +1 (module124's rule,
# read off the reference's sample fronds). Fronds are drawn far to near.
# The trunk, roots, bark and the ground shadow are the approved ones (render16/17); the crown's outline for the
# shadow and the dark mass under the fronds is the union of the tiers' drooping skirts.
import math, random, numpy as np
import scipy.ndimage as ndi
import render7 as R, render16 as G, render17 as T, species19 as SP, module124 as F
from render14 import Limb, HALF

UP = np.array([0.0, 1.0, 0.0])
ZS = 0.45            # depth squash of the tiers on the screen (the reference draws its tiers shallow)
# the oblique view (screen y = ZS z - y): the ray toward the viewer, the screen's up and right in 3D
VIEW = np.array([0.0, ZS, 1.0]) / math.hypot(ZS, 1.0)
SUP = np.array([0.0, 1.0, -ZS]) / math.hypot(ZS, 1.0)
RIGHT = np.array([1.0, 0.0, 0.0])
SPOKE_LEN = 13.0    # a pine cap's fronds: the short ones
UMB_GAP = 5.5       # umbrellas on a ring of limbs: one per this x their twigs' length of the ring (4 in round 21b)
UMB_DROP = (8, 12)  # a ring of umbrellas hangs (a + b q) h x1.3 under the top one ((6, 10) in round 21b)
OUT_DROOP = 0.22    # 'out' caps: their fronds' droop (0.4 hung like a palm's, 0.15 a flat star; a leader frond
                    # up from the middle made every cap a little spruce top)
TOP_DROOP = 0.75    # the top tier's droop on thin and middle trees (side fronds ~37 deg down)
PINE_BASE, PINE_FLARE, PINE_TAPER = 0.8, 0.85, 0.25   # the pine's trunk: width x, flare floor, taper (were 1, 0.62, 0.6;
                                                       # 0.88, 0.72, 0.4 hardly showed)
BALL_WRAP = 1.0     # a pine cap's ball normal + this x UP: lit softly from above (1.6 was too flat)
FRONDS = F.all_with_mirrors()

# key: label, form, crown radius at the base (px, thick tree), crown height, trunk seen under the lowest tier's front,
#      tier spacing, frond spacing along a tier, girth (oak = 1), tints (trees.yaml), bark texture, droop
CSPEC = {
    'spruce': ('ель', 'cone', 38, 106, 9, 19, 12.0, 0.76, ('#3b6b40', '#40703d', '#376644'), None, 0.34),
    'fir':    ('пихта', 'cone', 27, 112, 9, 13, 9.0, 0.57, ('#3f7250', '#447755', '#3b6c4c'), 'grey_bark', 0.2),
    'larch':  ('лиственница', 'cone', 32, 98, 14, 19, 17.0, 0.62, ('#7aa04a', '#84a852', '#729846'), None, 0.28),
    'pine':   ('сосна', 'clumps', 40, 34, 78, 0, 15.0, 0.62, ('#3f6b3a', '#44703c', '#3a6638'), 'pine_bark', 0.12),
}
FORM_NAME = {'cone': 'конус ярусами', 'clumps': 'зонтик из шапок на сучьях'}

def unit(v):
    v = np.asarray(v, float); n = np.linalg.norm(v); return v / n if n > 1e-9 else v


def crooked(a, b, r0, r1, level, rng, bends=2, amp=0.16, rise=0.0):
    """A pine's limb or twig from a to b (limb coordinates: x, y up, screen-squashed z) as a chain of bent
    segments (the user 2026-11-24 13:01 MSK: crooked, not a straight line): its knots step off the straight
    line by turns, on the screen, each segment a quadratic curve bowed a little; the radius tapers r0 -> r1
    along the chain; rise lifts the middle (a limb arching up before it reaches its umbrella)."""
    v = b - a
    L = float(np.linalg.norm(v))
    if L < 1e-6: return []
    sd = np.array([v[0], v[2] - v[1]])                 # the branch's direction on the screen
    sp = np.array([-sd[1], sd[0]]) / max(1e-6, float(np.linalg.norm(sd)))
    perp = np.array([sp[0], -sp[1], 0.0])               # a screen offset (x right, down) in limb coordinates
    n = bends + 1
    knots = [a]
    sgn = rng.choice((-1.0, 1.0))
    for i in range(1, n):
        t = i / n + rng.uniform(-0.08, 0.08)
        off = sgn * L * amp * rng.uniform(0.6, 1.0)
        sgn = -sgn
        knots.append(a + v * t + perp * off + np.array([0.0, L * rise * math.sin(math.pi * t) * 0.3, 0.0]))
    knots.append(b)
    out = []
    for i in range(n):
        p, q = knots[i], knots[i + 1]
        mid = (p + q) / 2 + perp * float(np.linalg.norm(q - p)) * rng.uniform(-0.12, 0.12)
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        out.append(Limb([p, mid, q], ra, rb, rng.randint(0, 999), level, k=1.0))
    return out


class Conifer(T.Tree):
    BANDS = ((0.8, 5), (0.5, 4), (0.2, 3), (-0.15, 2))

    def __init__(self, key, s=1.0, sun=R.SUN_R, seed=11, W=460, H=420, wide=1.5, tiers_k=1.5, style='out', **kw):
        """wide: the crown's base radius x this (round 21b: the user's x2); tiers_k: the number of tiers x this
        (x1.5 and x2 shown); for the pine both act on its clumps (spread, rings of clumps)."""
        label, form, Rb, Hc, bare, gap, spacing, gk, tints, bark, droop = CSPEC[key]
        h = s ** (2 / 3)
        self.key, self.form, self.droop, self.spacing = key, form, droop, spacing
        self.Rb, self.Hc, self.bare, self.gap = Rb * h * wide, Hc * h, bare * h, gap * (0.75 + 0.25 * h)
        self.wide, self.tiers_k = wide, tiers_k
        self.Rb0 = Rb
        self.style = style            # the pine's umbrellas: 'out' (caps' fronds grow outward) or 'dome' (turned over)
        self.hk_ = h
        self.size_ = s
        self.crng = random.Random(seed * 131 + int(s * 100))
        self.core_k = {'larch': 0.3, 'pine': 0.0}.get(key, 0.7)   # the larch and the pine are airy: gaps show through
        self.inner = key != 'larch' or wide > 1.0     # a wide larch's outer fronds would float away from the trunk
        self.tiers = self._tiers()
        # the name carries every parameter of the shape: render16.scaled_shape caches by name, and a pool worker
        # rendering two variants of one tree would draw the second with the first's shadow and dark mass
        name = 'conifer:%s:%.3f:%d:%.2f:%.2f:%s' % (key, s, seed, wide, tiers_k, style)
        self._register(name)
        G.SPECIES[name] = (label, name, 1.0 / h, 1.0 / h)
        G.WIDTH = 0.8 * gk * (PINE_BASE if form == 'clumps' else 1.0)
        kw.setdefault('k', 1.3)
        kw.setdefault('tint', R.species_tint(*tints))
        for a, v in (('d1', 0.64), ('d2', 0.36), ('dp', 0.8)): kw.setdefault(a, v)
        kw.setdefault('bark', SP.bark_ramp(bark))
        try:
            super().__init__(sun, species=name, s=s, W=W, H=H, cull=False, seed=seed, **kw)
        finally:
            G.WIDTH = 0.8
        self.mods = self._fronds()

    # ------------------------------------------------ geometry
    def _tiers(self):
        """Tiers: dict(y = height of the branches' roots, R = branch length, d = droop, c = (x, z) of the axis they
        grow from, slope = the crown's normal elevation there, deep = step offset), bottom first."""
        rng = self.crng
        out = []
        if self.form == 'cone':
            # the lowest tier stands so high that its front frond ends `bare` over the ground on the screen
            y0 = self.bare + (ZS + self.droop) * (self.Rb + 2) + 2
            self.top = y0 + self.Hc
            n = max(3, int(round((self.Hc - 10) / self.gap * self.tiers_k)) + 1)
            for k in range(n):
                f = k / n
                y = y0 + (self.top - 10 - y0) * (1 - (1 - k / max(1, n - 1)) ** 1.35) + rng.uniform(-1.0, 1.0)
                r = (self.Rb * (1 - f) ** 0.9 + 2.0) * (0.88 if k % 2 else 1.0)
                d = self.droop * rng.uniform(0.9, 1.1)
                # the top tiers of a thin or middle tree (user 2026-11-24 13:29 MSK): their fronds (grown out of the
                # trunk, the tiers are narrow) stuck out across the trunk; they droop along the others instead. The
                # top 15% of the crown: one tier on a spruce, two on a fir (its tiers crowd at the top)
                if y > self.top - 10 - 0.15 * self.Hc - 0.5 and self.size_ < 0.95: d = max(d, TOP_DROOP)
                out.append(dict(y=y, R=r, d=d, c=(0.0, 0.0), slope=45.0, deep=0.0))
            self.limb_ends = []
        else:
            # the pine: an umbrella pine (user 2026-11-24 05:18 MSK «расходящиеся зонтики из шапок в точке конца
            # ветки»; 13:01 MSK: the umbrellas had their fronds turned inward, turn them over; the limbs' reach
            # 1.5 times smaller; crooked limbs). Limbs from the trunk's upper part; each ends in an umbrella: its top
            # is the limb's end, a cap of fronds all around it, and 2-4 twigs spread out and DOWN from it (a dome,
            # not a cup), each with a cap whose fronds grow out of the twig's end, away from the umbrella's axis.
            h = self.hk_
            self.top = self.bare + self.Hc
            reach = self.Rb0 * h * 2.0 / 1.5                # round 21b's reach (wide 2) / 1.5
            Rc = 1.3 * max(9.0, 14.0 * h) / 1.5             # an umbrella's twigs: round 21b's / 1.5
            FR = 11.0                                       # a cap's reach (its fronds, 13-16 px), for the shape
            self.apex_y = self.top - (0.3 if self.style == 'dome' else 0.55) * Rc   # caps reach the top
            apexes = [(0.0, 0.0, self.apex_y, Rc)]
            # rings of limbs grow with the tier factor and the tree's size: a small pine has a few umbrellas, or its
            # caps (the fronds keep their pixel size) merge into one lump
            nr = max(1, int(round(2 * self.tiers_k * h)) - 1)
            for ring in range(nr):
                q = (ring + 1) / nr                                 # 1 = the lowest, widest ring
                dist = reach * (0.3 + 0.45 * q)
                m = max(3, int(round(math.tau * dist / (UMB_GAP * Rc))))
                off = rng.uniform(0, math.tau)
                for i in range(m):
                    a = off + math.tau * (i + rng.uniform(-0.15, 0.15)) / m
                    dd = dist * rng.uniform(0.85, 1.0)
                    ya = self.apex_y - (UMB_DROP[0] + UMB_DROP[1] * q) * h * 1.3 - rng.uniform(0, 4) * h
                    apexes.append((dd * math.cos(a), dd * math.sin(a), ya, Rc * rng.uniform(0.8, 0.95)))
            self.limb_ends, self.twigs = [], []
            small = h <= 0.7
            for ui, (cx, cz, ya, rc) in enumerate(apexes):
                A = np.array([cx, ya, cz])
                if cx or cz: self.limb_ends.append(np.array([G.BX + cx, ya - 1, ZS * cz]))   # limbs: screen-squashed z
                k = 2 if small else rng.randint(2, 3)
                off = rng.uniform(0, math.tau)
                out_dir = unit(np.array([cx, 0.0, cz])) if (cx or cz) else np.zeros(3)
                if self.style == 'dome':
                    # the umbrella turned over: a compact cap on its top, twigs spread out and DOWN from it
                    out += self._cap(A + np.array([0.0, 1.0, 0.0]), 0.5 * rc, ui)
                for j in range(k):
                    a = off + math.tau * (j + rng.uniform(-0.2, 0.2)) / k
                    if self.style == 'dome':
                        el = math.radians(-rng.uniform(15, 35))
                        dvec = unit(np.array([math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el)]) + 0.25 * out_dir)
                        P = A + dvec * rc * rng.uniform(0.85, 1.05)
                        out += self._cap(P, 0.5 * rc, ui)
                    else:
                        # caps out: twigs spread out and up (an umbel), each cap a small umbrella whose fronds grow
                        # out of the twig's end all around and droop
                        el = math.radians(rng.uniform(35, 60))
                        dvec = unit(np.array([math.cos(a) * math.cos(el), math.sin(el), math.sin(a) * math.cos(el)]) + 0.35 * out_dir)
                        P = A + dvec * rc * rng.uniform(0.95, 1.2)
                        out.append(dict(y=P[1], R=FR, d=OUT_DROOP, c=(P[0], P[2]), slope=60.0, deep=0.0, spokes=True,
                                        n=5 if small else 6, fan=None, umbel=ui, anchor='root'))
                    self.twigs.append((np.array([G.BX + A[0], A[1], ZS * A[2]]), np.array([G.BX + P[0], P[1] - 1, ZS * P[2]])))
            out.sort(key=lambda t: t['y'])
        return out

    def _cap(self, P, cr, ui):
        """Round 21b's compact cap at P: a ring of fronds drooping a little and two rising, their tips on the
        branch tips (the fronds outgrow the cap and cross it: a round tuft)."""
        return [dict(y=P[1], R=cr, d=0.12, c=(P[0], P[2]), slope=62.0, deep=0.0, spokes=True, n=5, fan=None,
                     umbel=ui, anchor='tip'),
                dict(y=P[1], R=0.55 * cr, d=-0.6, c=(P[0], P[2]), slope=75.0, deep=0.0, spokes=True, n=2, fan=None,
                     umbel=ui, anchor='tip')]

    def _skirt(self, t, y):
        if t['d'] < 0:                  # a rising ring: from its root up to its tips
            return t['R'] * min(1.0, max(0.0, (y - t['y'] + 2) / (-t['d'] * t['R'] + 2))) if t['y'] - 2 <= y <= t['y'] - t['d'] * t['R'] + 1 else 0.0
        tip = t['y'] - t['d'] * t['R']
        if tip - 2 <= y <= t['y'] + 3:
            return t['R'] if t['d'] < 1e-3 else min(t['R'], (t['y'] + 3 - y) / max(t['d'], 0.08))
        return 0.0

    def _register(self, name):
        """The crown's shape for the shadow, the trunk's shade and the dark mass: per axis (the cone's one, or each
        pine clump's) a surface of revolution whose radius at each height is the union of its tiers' skirts."""
        groups = {}
        for t in self.tiers: groups.setdefault(t['c'], []).append(t)
        lo = min(t['y'] - max(0.0, t['d']) * t['R'] for t in self.tiers) - 2
        hi = max(self.top, max(t['y'] - min(0.0, t['d']) * t['R'] for t in self.tiers)) + 1
        cy = lo
        parts = []
        for (cx, cz), ts in groups.items():
            rmax = max(t['R'] for t in ts)
            ys = np.linspace(lo, hi, 801)
            rs = np.array([max(self._skirt(t, y) for t in ts) for y in ys])
            if cx == 0 and cz == 0 and self.form == 'cone':
                rs = np.maximum(rs, np.where((ys >= self.top - 8) & (ys <= self.top), 3.0 * (self.top - ys) / 8, 0))
            rs = rs / rmax
            uu = np.linspace(0, 1, 801)
            prof = lambda u, ys=ys, rs=rs, uu=uu: (float(np.interp(u, uu, rs)), float(np.interp(u, uu, ys - cy)))
            parts.append(R.Part(prof, rmax, ZS * rmax, x0=cx, z0=ZS * cz))
        R.SHAPES[name] = dict(label=name, parts=parts, cy=cy, cut=0)

    def scr(self, P):
        """Screen point of a true 3D point (x, y, z): z is squashed by ZS on the screen."""
        return np.array([self.ox + P[0], self.oy + ZS * P[2] - P[1]])

    def _fronds(self):
        rng = self.crng
        mods = []
        for k, t in enumerate(self.tiers):
            Rk = t['R']
            a, b = Rk, ZS * Rk
            per = math.pi * (3 * (a + b) - math.sqrt(max(0.0, (3 * a + b) * (a + 3 * b))))
            rings = [(1.0, 0.0)]
            if self.inner and not t.get('spokes'):   # wide tiers: inner rings fill the gaps (deeper: -1)
                if Rk > 24: rings.append((0.6, -1.0))
                if Rk > 50: rings.append((0.32, -1.0))
            for rf, deep in rings:
                n = t['n'] if t.get('spokes') else max(3, int(round(per * rf / self.spacing)))
                off = rng.uniform(0, math.tau)
                for i in range(n):
                    if t.get('fan') is not None:          # a twig's cap: its fronds fan out away from the umbrella
                        a0, hw = t['fan']
                        ph = a0 + hw * (2 * (i + 0.5) / n - 1) + rng.uniform(-0.15, 0.15)
                    else:
                        ph = off + math.tau * (i + rng.uniform(-0.25, 0.25)) / n
                    L_ = Rk * rf * rng.uniform(0.85, 1.05)
                    root = np.array([t['c'][0], t['y'] + rng.uniform(-1, 1), t['c'][1]])
                    tip = root + np.array([L_ * math.cos(ph), -t['d'] * L_, L_ * math.sin(ph)])
                    mods.append(dict(root=root, tip=tip, tier=k, deep=deep + t['deep'], top=False, slope=t['slope'],
                                     axis=np.array([t['c'][0], 0.0, t['c'][1]]), spoke=bool(t.get('spokes')),
                                     umbel=t.get('umbel'), anchor=t.get('anchor', 'tip'), R=Rk * rf))
        if self.form == 'cone':      # the leader: one frond pointing up at the top
            mods.append(dict(root=np.array([0.0, self.top - 15, 0.0]), tip=np.array([0.0, self.top, 0.0]),
                             tier=len(self.tiers), deep=0.0, top=True, slope=90.0, axis=np.zeros(3)))
        # pick a frond for each branch
        last = None
        for m in mods:
            a_s, b_s = self.scr(m['root']), self.scr(m['tip'])
            v = b_s - a_s
            ln = float(np.linalg.norm(v))
            ang = math.degrees(math.atan2(-v[1], v[0])) if ln > 1e-6 else 90.0
            if m.get('anchor') == 'root': want = SPOKE_LEN
            else: want = min(24.0, max(13.0 if m.get('spoke') else self.min_len, ln * 0.95))
            best = None
            for j, f in enumerate(FRONDS):
                if m['top']:
                    c = abs((f.angle - 90 + 180) % 360 - 180) / 10.0 + rng.uniform(0, 0.3)
                else:
                    da = abs((f.angle - ang + 180) % 360 - 180)
                    c = da / 18.0 + abs(f.length - want) / 4.0 + rng.uniform(0, 0.8)
                    if last is not None and f.i == last: c += 1.5
                    if f.i in (1, 16): c += 0.8           # the round end-on fronds: fewer
                    if m.get('spoke') and f.i in (1, 7, 16): c += 3.0     # a pine's tuft: long fronds that spread
                if best is None or c < best[0]: best = (c, j)
            m['frond'] = FRONDS[best[1]]; last = m['frond'].i
            f = m['frond']
            # a frond much longer than its branch (a narrow top's) would reach back past the trunk, its shaded root
            # sticking out on the far side as a dark hook: it grows out of the trunk instead, like 124's top
            if not m['top'] and not m.get('spoke') and m.get('R', 99.0) < 0.75 * f.length: m['anchor'] = 'root'
            if m.get('anchor') == 'root':     # a frond growing out of its twig's end: its root there
                m['org'] = (int(round(a_s[0] - f.root[0])), int(round(a_s[1] - f.root[1])))
            else:                  # a cone's frond ends at its branch's tip
                m['org'] = (int(round(b_s[0] - f.tip[0])), int(round(b_s[1] - f.tip[1])))
            m['dir'] = unit(m['tip'] - m['root'])
            ctr = m['root'] + (m['tip'] - m['root']) * 0.65
            m['depth'] = float(ctr[1] + ctr[2] * ZS)
            m['ctr'] = ctr
        # a pine's umbrella is lit as a ball (a dome): each pixel by its place in the ellipse the umbrella's fronds
        # cover on the screen (a frond's own normal lit the fronds of one cap against each other)
        caps = {}
        for m in mods:
            if m.get('umbel') is None: continue
            f = m['frond']
            X0, Y0 = m['org']
            ys, xs = np.nonzero(f.role >= 0)
            caps.setdefault(m['umbel'], []).append((xs + X0, ys + Y0))
        balls = {}
        for c, pts in caps.items():
            xs = np.concatenate([q[0] for q in pts]); ys = np.concatenate([q[1] for q in pts])
            balls[c] = ((xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2,
                        (xs.max() - xs.min()) / 2 + 1, (ys.max() - ys.min()) / 2 + 1)
        for m in mods:
            if m.get('umbel') is not None: m['ball'] = balls[m['umbel']]
        mods.sort(key=lambda m: m['depth'])
        return [(m['ctr'], UP, m) for m in mods]          # render7.Tree.render loops over (p, n, mod)

    @property
    def min_len(self):
        return 9.0 if self.form != 'cone' or self.Rb > 30 else 12.0

    def core(self):
        if self.core_k <= 0: return np.zeros((self.H, self.W), bool)
        Y, X = np.mgrid[0:self.H, 0:self.W]
        sx = (X - self.ox).astype(float); sy = (Y - self.oy + self.cy).astype(float)
        lo, hi = self.yrange()
        m = np.zeros((self.H, self.W), bool)
        for y in np.arange(lo, hi + 0.5, 0.5):
            m |= self.inside(sx, y, sy + y, k=self.core_k)
        # only inside the fronds' silhouette: the shape's skirts are wider than the fronds near a narrow top (the
        # fir's), and the dark mass stuck out there as flat dark hooks
        if getattr(self, 'mods', None):
            if getattr(self, '_cover', None) is None:
                cov = np.zeros((self.H, self.W), bool)
                for p, n, mod in self.mods:
                    Y, X, _ = self.module_pixels(p, n, mod)
                    cov[Y, X] = True
                cov = ndi.binary_closing(cov, structure=np.ones((5, 5), bool))
                self._cover = ndi.binary_fill_holes(cov)
            m &= self._cover
        return m

    # ------------------------------------------------ light
    def band(self, d):
        """A frond's step by its crown normal . sun: one step above the leaf modules' bands, as the frond
        darkens its turned-away half, its strokes and its root (the reference's sample fronds: sun-facing
        halves at 5 on top, 4 on the lit side and in front, 2 in the shade)."""
        for lim, b in self.BANDS:
            if d > lim: return b
        return 1

    def band_arr(self, d):
        out = np.ones(np.shape(d))
        for lim, b in reversed(self.BANDS): out = np.where(d > lim, b, out)
        return out

    def module_pixels(self, p, n, mod):
        """A frond's steps: the band of the crown's normal where it lies (the side of its tier's cone or clump,
        tilted up more near the top) . sun; the half of the frond turned away from the sun one step darker; then
        module124's outline / root / tip rule."""
        if 'frond' not in mod: return super().module_pixels(p, n, mod)
        f = mod['frond']
        L = self.L
        if mod['top']:
            e = np.array([1.0, 0.0, 0.0]); ncr = unit(np.array([0.0, 1.0, 0.6]))
        else:
            dvec = mod['dir']
            e = unit(np.cross(dvec, UP))
            out = unit(np.array([dvec[0], 0.0, dvec[2]]))
            hy = (mod['ctr'][1] - (self.top - self.Hc)) / max(1.0, self.Hc)
            a = math.radians(min(85.0, mod['slope'] + (25 * hy if self.form == 'cone' else 0.0)))
            ncr = unit(out * math.cos(a) + UP * math.sin(a))
        X0, Y0 = mod['org']
        if 'ball' in mod:
            cx, cy, rx, ry = mod['ball']
            rows, cols = np.mgrid[0:f.role.shape[0], 0:f.role.shape[1]]
            sx = (X0 + cols - cx) / rx; sy = (Y0 + rows - cy) / ry
            q = np.maximum(1.0, np.hypot(sx, sy)); sx, sy = sx / q, sy / q
            sz = np.sqrt(np.maximum(0.0, 1.0 - sx * sx - sy * sy))
            nb = sx[..., None] * RIGHT + (-sy)[..., None] * SUP + sz[..., None] * VIEW + BALL_WRAP * UP  # soft: lit from above
            d = (nb @ L) / np.linalg.norm(nb, axis=-1)
            b = self.band_arr(d) + mod['deep']
        else:
            d = float(ncr @ L)
            b = self.band(d) + mod['deep']
        es = np.array([e[0], ZS * e[2] - e[1]])            # where e points on the screen
        nr = np.array([-f.ax[1], f.ax[0]])
        onpos = (f.side > 0) == (float(es @ nr) >= 0)      # pixels on the +e half of the frond
        el = float(e @ L)
        lit = (onpos if el > 0 else ~onpos) if abs(el) > 0.12 else np.ones(f.role.shape, bool)
        t = np.where(lit, b, b - 1).astype(float) - (f.role == 0)
        if not mod['top'] and not mod.get('spoke'): t = np.where(f.u < 0.3, t - 1, t)   # a pine's tuft: nothing above it
        t = np.where((f.u > 0.68) & lit & (b >= 4) & (f.role == 1), t + 1, t)    # the lit tip's body
        t = np.minimum(t, np.where(d < 0.92, 5, 6))
        t = np.clip(t, 0, len(self.ramp) - 1)
        ys, xs = np.nonzero(f.role >= 0)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
        self.last_base = int(np.median(b))
        return Y[ok], X[ok], t[ys[ok], xs[ok]]

    # ------------------------------------------------ the skeleton: one straight trunk (+ the pine's limbs)
    def _skeleton(self):
        rng = self.rng
        base = np.array([G.BX, self.h0, 0.0])
        r_base = HALF * self.sx
        top = np.array([G.BX + rng.uniform(-1, 1), self.top - 14 if self.form == 'cone' else self.apex_y - 1, 0.0])
        tl = Limb([base, base + (top - base) * 0.5, top], r_base, 0.8, rng.randint(0, 999), 0)
        # the pine's trunk is straighter (user 2026-11-24 13:29 MSK: a little narrower at the foot, a little wider
        # toward its end): a smaller flare over the roots and less taper
        lo_ = 0.62 if self.form == 'cone' else PINE_FLARE
        flare = lambda hh: lo_ + (1 - lo_) * math.exp(-max(0.0, hh - self.h0) / (12.0 * self.sy))
        taper = 0.85 if self.form == 'cone' else PINE_TAPER
        tl.r = lambda t, f=flare: max(0.8, r_base * f(tl.at(t)[1]) * (1 - taper * t))
        limbs = [tl]
        for a_, b_ in getattr(self, 'twigs', []):
            limbs += crooked(a_, b_, max(0.9, 1.4 * self.hk_), 0.6, 2, rng, bends=1, amp=0.18)
        for end in getattr(self, 'limb_ends', []):
            t0 = 0.62 + rng.uniform(-0.05, 0.05)        # from lower on the trunk: the crooked limbs show under the umbrellas
            p0 = tl.at(t0)
            r0 = max(1.0, tl.r(t0) * 0.6)
            limbs += crooked(p0, end, r0, 0.8, 1, rng, bends=2, amp=0.16, rise=0.3)
        return limbs

    def height_px(self):
        return int(round(self.top))
