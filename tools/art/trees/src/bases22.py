# Round 22: trunk variety. The lower trunk (the part standing on the ground, with its roots) of each of the three
# references, any tree can stand on any of them:
#   '122' the approved one: a wide flared foot with roots spreading on the ground (render7.REL_CLEAN, unchanged);
#   '123' the barrel of reference 123's trees: a short trunk swelling a little toward the ground, its foot a rounded
#         rim (the trunk goes straight into the ground, no roots), vertical bark plates;
#   '124' the conifer trunk of reference 124 (its panel's finished piece): a straight striped trunk with two short
#         root stubs at the sides and a pointed foot with a lit tap root toward the viewer.
# Every base is cut 1:1 from the reference's pixels into bark steps 0..3 and turned into relief the way the 122 one
# was (round 9): relief = the reference's step - the light step of its column (a barrel lit by the reference's own
# sun, fitted per reference so the relief comes out plainest: 122 SUN_R, 123 a little more frontal, 124 a little
# from behind). At render time the game's sun lights the relief again, so the bases follow the sun like the
# approved trunk. Above the base the trunk (render17 / conifer21 skeleton) carries the base's top row up as bark;
# its width over the base: 122 flares (0.55 + 0.45 e^-h of the root width), the others hardly (q 0.3 / 0.12 of that
# flare), so the trunk higher up keeps the approved girth of the species and size and only the foot changes.
import math, os, sys, random, numpy as np
from PIL import Image
import render7 as R, render16 as G, render17 as T
from render14 import Limb, HALF, UPS, V, SPAN_LO, SPAN_HI

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, '..', 'ref')

STEP = {'13051b': 0, '2d1952': 1, '4d1852': 2, '863945': 3,        # 122 / 123 bark ramp
        '06051c': 0, '2c0d37': 1, '6c3c27': 3}                      # 124 bark ramp (4d1852 shared)

def cut_steps(name, r0, r1, c0, c1):
    a = np.array(Image.open(os.path.join(REF, name)).convert('RGB'))[r0:r1, c0:c1]
    out = np.full(a.shape[:2], -1, int)
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            out[y, x] = STEP.get('%02x%02x%02x' % tuple(a[y, x]), -1)
    return out

def ref_pixels(name, r0, r1, c0, c1):
    return np.array(Image.open(os.path.join(REF, name)).convert('RGB'))[r0:r1, c0:c1]


class Base:
    """A trunk foot: relief `rel` (-99 empty), `rg` roots lying on the ground, the barrel's middle `tc` and
    radius `trr` (columns of the map, for the light), `foot` = the row standing on the ground, the trunk's
    columns at the top row `lo..hi`, `q` = how much the trunk flares over the foot (1 = the approved 122 flare)."""
    def __init__(self, key, label, rel, rg, tc, trr, foot, lo, hi, q, ref_sun, steps=None, ref=None, ref_ramp=None):
        self.key, self.label, self.rel, self.rg = key, label, rel, rg
        self.tc, self.trr, self.foot, self.lo, self.hi, self.q = tc, trr, foot, lo, hi, q
        self.ref_sun, self.steps, self.ref, self.ref_ramp = ref_sun, steps, ref, ref_ramp
        self.hw = (hi - lo) / 2.0                     # half-width of the trunk at the top row

    def band(self, x, row, L, rg=False):
        if rg: return R.root_band(float(R._root_normal(x, row) @ L))
        return R.trunk_band(float(R._barrel_normal(x, self.tc, self.trr) @ L))

    def lit(self, sun, rel=None, cm=None, rm=None, rg=None, shade=None):
        """Steps 0..3 of the (resampled) map lit by `sun`; cm/rm = the map's column/row of each pixel."""
        rel = self.rel if rel is None else rel
        rg = self.rg if rg is None else rg
        cm = np.arange(rel.shape[1], dtype=float) if cm is None else cm
        rm = np.arange(rel.shape[0], dtype=float) if rm is None else rm
        L = R.norm(sun)
        out = np.full(rel.shape, -1, int)
        for y in range(rel.shape[0]):
            for i in range(rel.shape[1]):
                r = rel[y, i]
                if r < -50: continue
                b = self.band(cm[i], rm[y], L, rg[y, i])
                if shade is not None and shade[y, i]: b = max(b - 1, -2)
                out[y, i] = max(0, min(3, r + b))
        return out


def _relief(S, tc, trr, sun):
    L = R.norm(sun)
    out = np.full(S.shape, -99, int)
    for y in range(S.shape[0]):
        for x in range(S.shape[1]):
            if S[y, x] < 0: continue
            out[y, x] = S[y, x] - R.trunk_band(float(R._barrel_normal(x, tc, trr) @ L))
    return out

def _b122():
    # reference 122's trunk panel, its last piece (with the roots): rows 202..223, cols 173..212 = stages.npy[3]
    rel, rg = R.trunk_relief(0, 0)
    return Base('122', 'корни 122', rel, rg, R.TC, R.TRR, R.FOOT_STAGE, SPAN_LO, SPAN_HI, 1.0, R.SUN_R,
                steps=R.S4.copy(), ref=ref_pixels('c_n.png', 202, 224, 173, 213),
                ref_ramp=('13051b', '2d1952', '4d1852', '863945'))

SUN_123 = (0.6, 0.75, 0.1)      # fitted: the barrel of 123 is lit a little more from the front than 122's trunk
SUN_124 = (0.3, 0.75, -0.2)     # fitted: 124's panel (its flat stage lit by this sun = its finished stage)

def _b123():
    # reference 123, the left tree ('dots'); rows 104..115 are the same in all three trees (the piece is reused),
    # the rows above are under the crown. Columns 34..55: the trunk is cols 35..54 (1..20 here).
    S = cut_steps('l_n.png', 104, 116, 34, 56)
    tc, trr = 10.5, 10.25
    rel = _relief(S, tc, trr, SUN_123)
    return Base('123', 'бочка 123', rel, np.zeros(S.shape, bool), tc, trr, 9, 2, 19, 0.3, SUN_123,
                steps=S, ref=ref_pixels('l_n.png', 104, 116, 34, 56), ref_ramp=('13051b', '2d1952', '4d1852', '863945'))

def _b124():
    # reference 124's trunk panel, its finished (third) piece, rows 212..226: the straight part's last 5 rows, the
    # root stubs, the pointed foot. The flat first piece of the same rows (161..175) is the relief this sun gives.
    S = cut_steps('k_n.png', 212, 227, 176, 202)
    tc, trr = 11.0, 8.75
    rel = _relief(S, tc, trr, SUN_124)
    return Base('124', 'стержень 124', rel, np.zeros(S.shape, bool), tc, trr, 10, 3, 19, 0.12, SUN_124,
                steps=S, ref=ref_pixels('k_n.png', 212, 227, 176, 202), ref_ramp=('06051c', '2c0d37', '4d1852', '6c3c27'))

BASES = {'122': _b122(), '123': _b123(), '124': _b124()}
CUT = {'122': ('c_n.png', 202, 224, 173, 213), '123': ('l_n.png', 104, 116, 34, 56), '124': ('k_n.png', 212, 227, 176, 202)}
KEYS = ('122', '123', '124')
WIDE_Q = 0.78        # option Б: a 123/124 foot as wide at its top as ~0.9 of the 122 root block's top

# The user's pick (2026-11-24 14:08 MSK, «1. В  2. А»): the foot goes by the tree's size: thin -> 124 (tap root),
# medium -> 123 (barrel), thick -> 122 (spreading roots), at the approved width (q of each base, option А). The
# splits are the midpoints between the shown sizes 0.42 / 0.68 / 1.0, so a tree growing thicker changes its foot
# from 124 to 123 to 122 (young trees straight into the ground, old ones on spreading roots).
SIZE_SPLITS = (0.55, 0.84)

def foot_for(s):
    return '124' if s < SIZE_SPLITS[0] else ('123' if s < SIZE_SPLITS[1] else '122')


def bark_rows_from(base, n, seed=7):
    """render7.bark_rows with the base row given (its own width): the base's crevices carried up, stepping aside
    now and then, plates broken by level cracks, raised plate edges. Bottom row first is returned reversed like
    the original (row 0 = the top)."""
    rng = random.Random(seed)
    base = np.asarray(base, int).copy()
    TW = len(base)
    span = [x for x in range(TW) if base[x] > -50]
    lo, hi = span[0], span[-1]
    lines = {x: int(min(2, base[x])) for x in range(lo + 1, hi) if base[x] <= 2}
    rows = []
    raised = {}
    for k in range(n):
        row = np.full(TW, -99, int); row[lo:hi + 1] = 3
        row[lo] = min(base[lo], 3); row[hi] = min(base[hi], 3)
        moved = {}
        for x, v in sorted(lines.items()):
            nx_ = x
            if rng.random() < 0.09:
                cand = x + rng.choice((-1, 1))
                if lo + 1 < cand < hi - 1 and all(abs(cand - o) >= 2 for o in list(lines) + list(moved.values()) if o != x):
                    nx_ = cand
            moved[x] = nx_
            row[nx_] = v
            if nx_ != x: row[x] = v
        lines = {moved[x]: v for x, v in lines.items()}
        cols = sorted(lines)
        for a, b in zip([lo] + cols, cols + [hi]):
            if b - a < 3: continue
            if rng.random() < 0.025:
                row[a + 1:b] = 2
                raised.pop(a, None)
                continue
            if a not in raised and rng.random() < 0.05:
                raised[a] = rng.randint(3, 7)
            if raised.get(a, 0) > 0:
                row[a + 1:min(b, a + 3)] = 4
                raised[a] -= 1
        rows.append(row)
    return np.array(rows[::-1]) if rows else np.zeros((0, TW), int)

def to_frame(rows, lo, hi):
    """Stretch rows whose trunk spans columns lo..hi onto the skeleton's bark frame (40 columns, the trunk on
    SPAN_LO..SPAN_HI, where render16 reads a limb's bark: col = TC + s x HALF), nearest."""
    out = np.full((rows.shape[0], R.TW), -99, int)
    for c in range(SPAN_LO, SPAN_HI + 1):
        u = (c - SPAN_LO) / (SPAN_HI - SPAN_LO)
        out[:, c] = rows[:, lo + int(round(u * (hi - lo)))]
    return out


# ------------------------------------------------------------------ the trees
class Based:
    """Mix in before render17.Tree / conifer21.Conifer: base='122' keeps the approved trunk pixel for pixel.
    q (None = the base's own) sets how much of the 122 flare the trunk keeps over a 123/124 foot: the foot's top
    is (lo + (1 - lo) q) of the 122 root width; 'wide' = WIDE_Q, the foot as wide as the 122 one's top."""
    base = '122'
    q = None

    def _q(self):
        return BASES[self.base].q if self.q is None else self.q

    @property
    def h0(self):
        if self.base == '122': return self._h0
        return self._vgeom()['h0']

    @h0.setter
    def h0(self, v):
        self._h0 = v

    # the trunk's flare over the foot: 122 = the approved one; the others keep only q of it
    def flare_lo(self):
        return 0.55

    def flare_len(self):
        return 14.0

    def _vgeom(self):
        g = self.__dict__.get('_vg')
        if g is not None: return g
        b = BASES[self.base]
        lo_ = self.flare_lo()
        r_base = HALF * self.sx
        r_top = r_base * (lo_ + (1 - lo_) * self._q())
        kx = r_top / b.hw
        aniso = math.sqrt(max(0.5, 0.8 * self.sy / max(1e-6, self.sx)))
        ky = max(0.45, kx * aniso)
        n0, w0 = b.rel.shape
        w = max(4, int(round(w0 * kx)))
        up = max(2, int(round(b.foot * ky))); down = max(1, int(round((n0 - b.foot) * ky)))
        rm = [min(b.foot - 1, int((y + 0.5) / ky)) for y in range(up)] + \
             [min(n0 - 1, b.foot + int((y + 0.5) / ky)) for y in range(down)]
        cm = [min(w0 - 1, int((i + 0.5) / kx)) for i in range(w)]
        g = dict(kx=kx, ky=ky, r_top=r_top, h0=up, rel=b.rel[np.ix_(rm, cm)], rg=b.rg[np.ix_(rm, cm)],
                 cm=np.array(cm, float), rm=np.array(rm, float), xm=int(round(b.tc * kx)))
        self.__dict__['_vg'] = g
        return g

    def _flare(self):
        b = BASES[self.base]
        lo_, ln = self.flare_lo(), self.flare_len()
        q = self._q()
        return lambda h: lo_ + (1 - lo_) * q * math.exp(-max(0.0, h - self.h0) / (ln * self.sy))

    def _root_block(self):
        if self.base == '122': return super()._root_block()
        g = self._vgeom()
        return g['rel'], g['rg'], g['cm'], g['rm']

    def _bark_tex(self, seed, n):
        if self.base == '122': return super()._bark_tex(seed, n)
        b = BASES[self.base]
        top = b.rel[0].copy()
        rows = bark_rows_from(top, n, seed)
        return to_frame(rows, b.lo, b.hi)[::-1]

    def shadow(self):
        if self.base == '122': return super().shadow()
        L = self.L
        m = np.zeros((self.H, self.W), bool)
        if L[1] < 0.1: return m
        if self.crown:
            Y, X = np.mgrid[0:self.H, 0:self.W]
            gx = (X - self.ox).astype(float); gz = (Y - self.oy).astype(float)
            jit = 0.92 + 0.08 * (((X // 2) * 7 + (Y // 2) * 13) % 5) / 4
            lo, hi = self.yrange()
            for h in np.arange(self.cy + lo, self.cy + hi + 1, 1.5):
                m |= self.inside(gx + L[0] / L[1] * h, h - self.cy, gz + L[2] / L[1] * h, lim=jit)
        b = BASES[self.base]
        hw = b.trr * self._vgeom()['kx'] * 0.9
        Y, X = np.mgrid[0:self.H, 0:self.W]
        gx = (X - self.ox).astype(float); gz = (Y - self.oy).astype(float)
        for h in np.arange(0, self.h0 + 1, 2):
            m |= (np.abs(gx + L[0] / L[1] * h) < hw) & (np.abs(gz + L[2] / L[1] * h) < 6)
        self.skeleton_shadow(m)
        return m

    def draw_trunk(self, img):
        if self.base == '122': return super().draw_trunk(img)
        b = BASES[self.base]
        g = self._vgeom()
        L = self.L
        rel, rg, cm, rm = g['rel'], g['rg'], g['cm'], g['rm']
        w = rel.shape[1]; X0 = self.ox + G.BX - g['xm']
        Y0 = self.oy - self.h0
        shade = np.zeros(rel.shape, bool)
        if self.crown and L[1] > 0.1:
            gshadow = self.shadow()
            for y in range(rel.shape[0]):
                for i in range(w):
                    if rel[y, i] < -50: continue
                    X, Y = X0 + i, Y0 + y
                    if rg[y, i] and 0 <= Y < self.H and 0 <= X < self.W:
                        shade[y, i] = gshadow[Y, X]
            shade |= self._crown_shade_px(np.array([[X0 + i - self.ox, self.h0 - y, 0.0] for y in range(rel.shape[0]) for i in range(w)])).reshape(rel.shape) & ~rg
        t = b.lit(L, rel, cm, rm, rg, shade)
        ys, xs = np.nonzero(t >= 0)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
        img[Y[ok], X[ok]] = np.array(self.bark)[t[ys[ok], xs[ok]]]
        self._draw_skeleton(img)

    def _draw_skeleton(self, img):
        """render16.Tree.draw_trunk's part 2 (the skeleton), unchanged."""
        L = self.L
        zb = np.full((self.H, self.W), -1e9)
        idx = np.full((self.H, self.W), -1, int)
        pts = np.zeros((self.H, self.W, 3))
        texs = {}
        for p, r, tan, l, j in self._samples():
            lb = self.limbs[j]
            sx, sy = self.proj_abs(p)
            ts = np.array([tan[0], tan[2] - tan[1]]); nt = np.linalg.norm(ts)
            perp = np.array([-ts[1], ts[0]]) / nt if nt > 1e-3 else np.array([1.0, 0.0])
            ri = int(math.ceil(r)) + 1
            ys, xs = np.mgrid[-ri:ri + 1, -ri:ri + 1]
            fx, fy = xs + (round(sx) - sx), ys + (round(sy) - sy)
            dd = fx * fx + fy * fy
            ok = dd <= r * r + 0.3
            s = np.clip((fx * perp[0] + fy * perp[1]) / max(r, 0.5), -1, 1)
            pw = perp[0] * np.array([1.0, 0, 0]) + perp[1] * UPS
            vp = V - tan * float(V @ tan); vp = vp / max(1e-6, np.linalg.norm(vp))
            nrm = s[..., None] * pw + np.sqrt(np.maximum(0, 1 - s * s))[..., None] * vp
            depth = (p @ V) + r * (nrm @ V)
            Y, X = ys + int(round(sy)), xs + int(round(sx))
            k = ok & (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W) & (depth > zb[np.clip(Y, 0, self.H - 1), np.clip(X, 0, self.W - 1)])
            if not np.any(k): continue
            d = nrm[k] @ L
            band = np.where(d > -0.05, 0, np.where(d > -0.36, -1, -2))
            if r >= 3.5:
                if j not in texs: texs[j] = self._bark_tex(lb.seed if j else 7, 400)
                tex = texs[j]
                col = np.clip(np.round(R.TC + s[k] * HALF).astype(int), SPAN_LO, SPAN_HI)
                row = min(len(tex) - 1, int(l))
                rel_ = tex[row][col]
                rel_ = np.where(rel_ < -50, 2, rel_)
            else:
                rel_ = np.where(np.abs(s[k]) > 0.8, 2, 3)
                if r < 1.6: rel_ = np.full(rel_.shape, 3)
            if r >= 1.6: rel_ = np.where(np.abs(s[k]) > 0.86, rel_ - 1, rel_)
            zb[Y[k], X[k]] = depth[k]
            idx[Y[k], X[k]] = rel_ + band
            pts[Y[k], X[k]] = p + r * nrm[k]
        has = zb > -1e8
        near = np.zeros_like(has)
        for dy_, dx_ in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            zn = np.roll(np.roll(zb, dy_, 0), dx_, 1)
            near |= has & (zn > zb + 2.5)
        idx[near] -= 1
        has[self.oy - self.h0 + 1:, :] &= False
        if self.crown and L[1] > 0.1:
            yy, xx = np.nonzero(has)
            sh = self._crown_shade_px(pts[yy, xx] - np.array([0, 0, 0]))
            v = idx[yy, xx] - np.where(sh, 1, 0)
            idx[yy, xx] = v
        c = np.clip(idx[has], 0, 3)
        img[has] = np.array(self.bark)[c]
