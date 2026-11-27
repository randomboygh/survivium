# Round 7: crowns of several shapes, modules the camera cannot see left out, leaf contrast,
# the trunk lit by the sun like the leaves.
# Space as in render2: x right, y up, z toward the viewer; the screen is (x, z - y), so the camera
# looks along V = (0, 1, 1) (from up and in front). The shapes' z radii are already squashed.
import sys, math, random, numpy as np
sys.path.insert(0, '.')
import module5 as M
import render6 as R6
from render2 import hexc, band

def norm(v):
    v = np.asarray(v, float); return v / np.linalg.norm(v)

V = norm((0, 1, 1))                         # toward the camera
SUN_R = (0.6, 0.75, -0.1)
LAYOUTS = (0, 1, 5, 17)
MODS = [M.module(s, flip=f) for f in (False, True) for s in LAYOUTS]
DISC = {f: M.disc(f) for f in (False, True)}

def contrast(ramp, k, mid=3):
    """Steps of the ramp pushed apart around its middle step, as a power of each colour's ratio
    to the middle one (the game's colours are products tint x tone x light, so this is the same
    as raising the tone and light steps to the power k)."""
    m = np.array(hexc(ramp[mid]), float)
    out = []
    for h in ramp:
        c = np.maximum(np.array(hexc(h), float), 1)
        c2 = np.clip(m * (c / m) ** k, 0, 255)
        out.append('%02x%02x%02x' % tuple(c2.round().astype(int)))
    return out

def species_tint(*hexes):
    """The mean of a species' tints (trees.yaml), 0..1."""
    return np.mean([[int(h.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4)] for h in hexes], 0) / 255.0

LINDEN = species_tint('#5a8f3a', '#62983f', '#548a36')

# ---------------------------------------------------------------- shapes
class Part:
    """A surface of revolution about a vertical axis with an elliptic section (rx, rz):
    prof(u) -> (r, y) for u in 0..1 from the bottom up, r relative (1 = rx, rz)."""
    def __init__(self, prof, rx, rz, x0=0.0, y0=0.0, z0=0.0, mode='arc', hc=None):
        self.prof, self.rx, self.rz, self.x0, self.y0, self.z0, self.mode, self.hc = prof, rx, rz, x0, y0, z0, mode, hc
        us = np.linspace(0, 1, 801)
        P = np.array([prof(u) for u in us])
        self.us, self.P = us, P
        o = np.argsort(P[:, 1])
        self.ytab, self.rtab = P[o, 1], P[o, 0]

    def r_at(self, y):
        return np.interp(y, self.ytab, self.rtab, left=-1.0, right=-1.0)

    def ring_us(self, step):
        if self.mode == 'phi':        # the hemisphere of render2: equal angles
            n = max(2, round((math.pi / 2) * (self.rx + self.hc) / 2 / step))
            return np.linspace(0, 1, n + 1)
        seg = np.hypot(np.diff(self.P[:, 0]) * (self.rx + self.rz) / 2, np.diff(self.P[:, 1]))
        s = np.concatenate([[0], np.cumsum(seg)])
        n = max(2, round(s[-1] / step))
        return np.interp(np.linspace(0, s[-1], n + 1), s, self.us)

    def normal(self, u, th):
        e = 1e-3
        r0, y0 = self.prof(max(0.0, u - e)); r1, y1 = self.prof(min(1.0, u + e))
        r, _ = self.prof(u)
        if r < 0.03:
            return np.array([0.0, 1.0 if u > 0.5 else -1.0, 0.0])
        dr, dy = r1 - r0, y1 - y0
        return norm((math.cos(th) * dy / self.rx, -dr, math.sin(th) * dy / self.rz))

def hemi(hc):
    return lambda u: (math.cos(u * math.pi / 2), hc * math.sin(u * math.pi / 2))

def ellipsoid(ry_low, ry_up=None):
    ry_up = ry_up or ry_low
    def f(u):
        p = -math.pi / 2 + u * math.pi
        return (math.cos(p), ry_low * (1 + math.sin(p)) if p < 0 else ry_low + ry_up * math.sin(p))
    return f

def polyline(pts):
    """Profile through (r, y) points, smooth enough at these sizes."""
    pts = np.array(pts, float)
    seg = np.hypot(np.diff(pts[:, 0]) * 30, np.diff(pts[:, 1])); s = np.concatenate([[0], np.cumsum(seg)]) / np.sum(seg)
    return lambda u: (float(np.interp(u, s, pts[:, 0])), float(np.interp(u, s, pts[:, 1])))

def arc_pts(r0, y0, r1, y1, n=12, kind='out'):
    """Quarter-ellipse points from (r0, y0) to (r1, y1): 'out' bulges outward-up (a cap), 'in' a rounded foot."""
    out = []
    for i in range(n + 1):
        a = (math.pi / 2) * i / n
        if kind == 'out':   # r from r0 (at side) to r1 (top), y rising like sin
            out.append((r1 + (r0 - r1) * math.cos(a), y0 + (y1 - y0) * math.sin(a)))
        else:               # foot: r grows like sin, y like 1 - cos
            out.append((r0 + (r1 - r0) * math.sin(a), y0 + (y1 - y0) * (1 - math.cos(a))))
    return out

SHAPES = {}
def shape(name, label, parts, cy, trunk_cut=0):
    SHAPES[name] = dict(label=label, parts=parts, cy=cy, cut=trunk_cut)

shape('hemi', 'полусфера', [Part(hemi(21), 40, 22, mode='phi', hc=21)], 48)
shape('ellipsoid', 'эллипсоид', [Part(ellipsoid(42), 27, 15)], 28, trunk_cut=8)
shape('flat', 'плоская полусфера (пальма)', [Part(hemi(6), 44, 24, mode='phi', hc=6)], 78, trunk_cut=14)
shape('cone', 'конус', [Part(polyline(arc_pts(0.75, 0, 1.0, 6, 6, 'in') + [(0.0, 80)]), 36, 20)], 28)
shape('egg', 'яйцо (липа)', [Part(ellipsoid(17, 42), 36, 20)], 30)
shape('column', 'колонна (тополь)', [Part(polyline(arc_pts(0.6, 0, 1.0, 8, 6, 'in') + arc_pts(1.0, 62, 0.0, 88, 10, 'out')), 22, 12)], 26, trunk_cut=12)
shape('umbrella', 'зонтик (акация)', [Part(polyline(arc_pts(0.8, 0, 1.0, 4, 5, 'in') + arc_pts(1.0, 4, 0.0, 17, 10, 'out')), 47, 26)], 66)
shape('weeping', 'колокол (плакучая)', [Part(polyline([(1.06, -26), (1.03, -12)] + arc_pts(1.0, 0, 0.0, 22, 12, 'out')), 40, 22)], 60)
shape('lobed', 'шапки (дуб)', [Part(hemi(15), 19, 11, x0=-25, z0=-5, y0=8, mode='phi', hc=15),
                                Part(hemi(15), 19, 11, x0=25, z0=-5, y0=8, mode='phi', hc=15),
                                Part(hemi(14), 20, 11, x0=-15, z0=10, y0=0, mode='phi', hc=14),
                                Part(hemi(14), 20, 11, x0=16, z0=10, y0=0, mode='phi', hc=14),
                                Part(hemi(16), 21, 12, x0=1, z0=-2, y0=22, mode='phi', hc=16)], 42)

shape('lobed2', 'шапки врозь (разные)', [Part(hemi(17), 22, 12, x0=-6, z0=-4, y0=22, mode='phi', hc=17),
                                          Part(hemi(13), 17, 10, x0=38, z0=-2, y0=10, mode='phi', hc=13),
                                          Part(hemi(10), 12, 7, x0=-42, z0=-6, y0=8, mode='phi', hc=10),
                                          Part(hemi(11), 15, 8, x0=-22, z0=13, y0=-2, mode='phi', hc=11),
                                          Part(hemi(9), 11, 6, x0=22, z0=13, y0=-6, mode='phi', hc=9),
                                          Part(hemi(8), 10, 6, x0=20, z0=-12, y0=38, mode='phi', hc=8)], 46)

# ---------------------------------------------------------------- the trunk, lit by the sun
ST = np.load('stages.npy')                 # the reference's 4 drawing stages of the trunk (bark steps 0..3)
S3, S4 = ST[2], ST[3]
TW, TC, TRR = S4.shape[1], 18.0, 18.5      # map width, the barrel's middle column and radius
TROWS = S4.shape[0]
FOOT_STAGE = 17                            # the stage row standing on the ground
ROOT_GROUND = (S4 >= 0) & ((S3 < 0) | ((S4 != S3) & (np.arange(TROWS)[:, None] >= 14)))

def _barrel_normal(x, cx=TC, rr=TRR):
    nx = max(-1.0, min(1.0, (x - cx) / rr)); return np.array([nx, 0.0, math.sqrt(1 - nx * nx)])

def _root_normal(x, row):
    o = norm(((x - TC) / TRR, max(0.0, (row - 12) / 8.0)) if abs(x - TC) + max(0, row - 12) > 0 else (0, 1))
    return norm((0.65 * o[0], 0.75, 0.65 * o[1]))

def trunk_band(d):
    """Light steps of the bark (0 lit, -1 half, -2 shade) from n.L, the thresholds fitted so the
    reference's own sun (SUN_R) gives the reference's shading column for column."""
    return 0 if d > -0.05 else (-1 if d > -0.36 else -2)

def root_band(d):
    return min(0, band(d))

def _rel_map():
    L = norm(SUN_R)
    R = np.full(S4.shape, -99, int)
    for y in range(TROWS):
        for x in range(TW):
            v = S4[y, x]
            if v < 0: continue
            if ROOT_GROUND[y, x]: b = root_band(float(_root_normal(x, y) @ L))
            else: b = trunk_band(float(_barrel_normal(x) @ L))
            R[y, x] = v - b
    return R
REL = _rel_map()                           # bark steps relative to the light, the reference's structure

# The reference's stage 3 darkens the top rows on the lit side: that is the crown's shadow, not bark.
# Take it out (the shadow is cast by the crown at render time); keep the plates and cracks.
S2 = ST[1]
REL_CLEAN = REL.copy()
for _y in range(3):
    for _x in range(16, TW):
        if S3[_y, _x] >= 0 and S2[_y, _x] >= 0 and S3[_y, _x] < S2[_y, _x]:
            REL_CLEAN[_y, _x] += S2[_y, _x] - S3[_y, _x]

def bark_rows(n, seed=7):
    """n rows of bark relief to go on top of the reference's trunk (row 0 of REL_CLEAN), bottom row
    first: the reference's crevices (2, the deep ones 1) between plates (3) carried up, each line now and
    then stepping a pixel aside (a short level crack where it steps), plates broken by a level crack now
    and then, and raised plates (4) that catch the light in the half shade, as in the reference."""
    import random as _r
    rng = _r.Random(seed)
    base = REL_CLEAN[0].copy()
    span = [x for x in range(TW) if base[x] > -50]
    lo, hi = span[0], span[-1]
    lines = {x: int(base[x]) for x in range(lo + 1, hi) if base[x] <= 2}
    rows = []
    raised = {}                                   # plate start column -> rows of light left
    for k in range(n):
        row = np.full(TW, -99, int); row[lo:hi + 1] = 3
        row[lo] = base[lo]; row[hi] = base[hi]
        moved = {}
        for x, v in sorted(lines.items()):
            nx_ = x
            if rng.random() < 0.09:
                cand = x + rng.choice((-1, 1))
                if lo + 1 < cand < hi - 1 and all(abs(cand - o) >= 2 for o in list(lines) + list(moved.values()) if o != x):
                    nx_ = cand
            moved[x] = nx_
            row[nx_] = v
            if nx_ != x: row[x] = v                  # the step: both columns dark for a row
        lines = {moved[x]: v for x, v in lines.items()}
        cols = sorted(lines)
        for a, b in zip([lo] + cols, cols + [hi]):
            if b - a < 3: continue
            if rng.random() < 0.025:                  # a level crack across the plate
                row[a + 1:b] = 2
                raised.pop(a, None)
                continue
            if a not in raised and rng.random() < 0.05:
                raised[a] = rng.randint(3, 7)
            if raised.get(a, 0) > 0:
                row[a + 1:min(b, a + 3)] = 4          # the plate's edge lifts toward the light
                raised[a] -= 1
        rows.append(row)
    return np.array(rows[::-1]) if rows else np.zeros((0, TW), int)

def trunk_relief(ext, cut=0, seed=7):
    rel = np.vstack([bark_rows(ext, seed), REL_CLEAN]) if ext > 0 else REL_CLEAN.copy()
    rg = np.vstack([np.zeros((ext, TW), bool), ROOT_GROUND])
    keep = [x for x in range(TW) if not (4 <= x < 4 + cut)]
    return rel[:, keep], rg[:, keep]

def lit_trunk(rel, rg, sun, cut=0, shade=None):
    """Index map 0..3 of the trunk: relief + the light step of its column (roots: of their slope)
    + the crown's shadow (shade: a bool map of the same size, one step off)."""
    L = norm(sun)
    w = rel.shape[1]; cx = TC - cut / 2; rr = TRR - cut / 2
    out = np.full(rel.shape, -1, int)
    ext = rel.shape[0] - TROWS
    for y in range(rel.shape[0]):
        for i in range(w):
            r = rel[y, i]
            if r < -50: continue
            xo = (i - cx) / rr * TRR + TC
            if rg[y, i]: b = root_band(float(_root_normal(xo, y - ext) @ L))
            else: b = trunk_band(float(_barrel_normal(i, cx, rr) @ L))
            if shade is not None and shade[y, i]: b = max(b - 1, -2)     # a cast shadow is no darker than the trunk's own shade
            out[y, i] = max(0, min(3, r + b))
    return out

def trunk_pixels(sun, ext, cut=0):
    """(index map 0..3 / -1) of the trunk lit by `sun`, `ext` rows of bark carried up under the crown,
    `cut` columns taken out of the shaded half for narrow crowns."""
    L = norm(sun)
    keep = [x for x in range(TW) if not (4 <= x < 4 + cut)]
    rel = REL[:, keep]; rg = ROOT_GROUND[:, keep]
    w = len(keep); cx = TC - cut / 2; rr = TRR - cut / 2
    xs = np.array(keep, float)
    out = np.full(rel.shape, -1, int)
    for y in range(TROWS):
        for i in range(w):
            r = rel[y, i]
            if r < -50: continue
            xo = (i - cx) / rr * TRR + TC           # where this column sits on the full barrel
            if rg[y, i]: b = root_band(float(_root_normal(xo, y) @ L))
            else: b = trunk_band(float(_barrel_normal(i, cx, rr) @ L))
            out[y, i] = max(0, min(3, r + b))
    top = out[0].copy()
    return np.vstack([np.tile(top, (ext, 1)), out])

# ---------------------------------------------------------------- the tree
class Tree:
    def __init__(self, sun, shape='hemi', season='summer', k=1.0, step=15, hstep=15, seed=1,
                 W=200, H=200, order='rings', cull=True, ramp=None, bark=None, tint=None,
                 d1=0.7, d2=0.4, dp=0.85, shade_flat=False):
        # light of a module by its facing to the sun d = n.L: light (base 4) over d1, half (3) over d2,
        # shade (2) below; the palest step only over dp. shade_flat: in the shade the leaves facing the
        # sun lose their own light (no +1, no heart), so the shade is nearly one dark.
        self.d1, self.d2, self.dp, self.shade_flat = d1, d2, dp, shade_flat
        sh = SHAPES[shape]
        self.shape, self.parts, self.cy, self.cut = shape, sh['parts'], sh['cy'], sh['cut']
        self.L = norm(sun); L = self.L
        self.light2 = norm((L[0], L[2] - L[1]))
        self.W, self.H = W, H
        self.ox, self.oy = W // 2, H - 26
        self.ramp = [np.array(hexc(h), np.uint8) for h in (ramp or contrast(R6.ramp_for(season, tint), k))]
        self.bark = [np.array(hexc(h), np.uint8) for h in (bark or R6.OUR_BARK)]
        self.seed, self.order, self.cull = seed, order, cull
        rng = random.Random(seed)
        mods = []
        parts = sorted(self.parts, key=lambda p: p.y0 + p.z0)     # back and low parts first
        for part in parts:
            uks = part.ring_us(step)
            for k_, u in enumerate(uks):
                r, y = part.prof(u)
                a, b = part.rx * r, part.rz * r
                per = math.pi * (3 * (a + b) - math.sqrt(max(0.0, (3 * a + b) * (a + 3 * b))))
                last = k_ == len(uks) - 1
                n = 1 if (last and part.mode == 'phi') or r < 0.12 else max(1, round(per / hstep))
                if n == 2 and r < 0.35: n = 1           # a narrow top: one module on the axis
                off = rng.uniform(0, math.tau)
                ring = []
                for i in range(n):
                    th = off + math.tau * i / n
                    rr = 0.0 if n == 1 else 1.0
                    p = np.array([part.x0 + rr * a * math.cos(th), part.y0 + y, part.z0 + rr * b * math.sin(th)])
                    ring.append((p, part.normal(u, th)))
                ring.sort(key=lambda t: t[0][2])
                mods += ring
                if part.mode != 'phi' and n == 1 and u > 0.5:
                    break       # a narrow top ends in one module: its leaves reach the tip
        self.mods = [(p, n, MODS[(i * 5 + seed) % len(MODS)]) for i, (p, n) in enumerate(mods)]
        if order == 'depth':
            self.mods.sort(key=lambda m: float(m[0] @ V))
        self._tones = {}

    # geometry
    def proj(self, p):
        return self.ox + p[0], self.oy + p[2] - (p[1] + self.cy)

    def inside(self, x, y, z, k=1.0, lim=1.0):
        res = np.zeros(np.broadcast(x, y, z).shape, bool)
        for pt in self.parts:
            r = pt.r_at(y - pt.y0)
            q = ((x - pt.x0) / (pt.rx * k)) ** 2 + ((z - pt.z0) / (pt.rz * k)) ** 2
            res |= (r > 0) & (q < r * r * lim)
        return res

    def yrange(self):
        lo = min(pt.y0 + pt.ytab[0] for pt in self.parts); hi = max(pt.y0 + pt.ytab[-1] for pt in self.parts)
        return lo, hi

    def core(self):
        """The dark mass under the modules: the shape's outline on the screen, a little inside."""
        Y, X = np.mgrid[0:self.H, 0:self.W]
        sx = (X - self.ox).astype(float); sy = (Y - self.oy + self.cy).astype(float)
        lo, hi = self.yrange()
        m = np.zeros((self.H, self.W), bool)
        for y in np.arange(lo, hi + 0.5, 0.5):
            m |= self.inside(sx, y, sy + y, k=0.92)
        return m

    def shadow(self):
        L = self.L
        if L[1] < 0.1: return np.zeros((self.H, self.W), bool)
        Y, X = np.mgrid[0:self.H, 0:self.W]
        gx = (X - self.ox).astype(float); gz = (Y - self.oy).astype(float)
        jit = 0.92 + 0.08 * (((X // 2) * 7 + (Y // 2) * 13) % 5) / 4
        lo, hi = self.yrange()
        m = np.zeros((self.H, self.W), bool)
        for h in np.arange(self.cy + lo, self.cy + hi + 1, 1.5):
            m |= self.inside(gx + L[0] / L[1] * h, h - self.cy, gz + L[2] / L[1] * h, lim=jit)
        hw = (TRR - self.cut / 2) * 0.9
        for h in np.arange(0, self.cy + lo + 1, 2):
            m |= (np.abs(gx + L[0] / L[1] * h) < hw) & (np.abs(gz + L[2] / L[1] * h) < 6)
        return m

    def tones(self, mod, shade=False):
        key = (id(mod), shade)
        if key not in self._tones:
            t = M.tones(mod, self.light2)
            if shade == 'flat':
                flat = M.tones(mod, self.light2, flat=True)
                t = np.where(t > -9, flat + np.minimum(t - flat, 0), t)
            elif shade == 'lift':
                flat = M.tones(mod, self.light2, flat=True)
                t = np.where(t > -9, flat + np.maximum(t - flat, 0), t)
            elif shade in ('half', 'quarter'):
                # leaves turned away keep their shade, but half (a quarter) of a step lighter: colours
                # between two steps of the ramp
                keep = 0.5 if shade == 'half' else 0.75
                flat = M.tones(mod, self.light2, flat=True)
                lt = (t - flat).astype(float)
                t = np.where(t > -9, flat + np.where(lt < 0, lt * keep, lt), t).astype(float)
            self._tones[key] = t
        return self._tones[key]

    def module_pixels(self, p, n, mod):
        """(Y, X, colour) of one module where it lands."""
        d = float(n @ self.L)
        base = 4 if d > self.d1 else (3 if d > self.d2 else 2)
        t = self.tones(mod, shade=(('flat' if self.shade_flat is True else self.shade_flat) if base == 2 else False))
        dsk = DISC[mod['flip']]
        mask = (t > -9) | dsk
        v = np.where(t > -9, t, -1)
        c = base + v
        if d < self.dp: c = np.minimum(c, 5)
        c = np.clip(c, 0, len(self.ramp) - 1)
        sx, sy = self.proj(p)
        cx = M.S - 1 - M.C[0] if mod['flip'] else M.C[0]
        X0 = int(round(sx)) - cx; Y0 = int(round(sy)) - M.C[1]
        ys, xs = np.nonzero(mask)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
        self.last_base = base
        return Y[ok], X[ok], c[ys[ok], xs[ok]]

    def visibility(self, core):
        """Pixels each module shows when all are drawn: its own where it is on top, and for a module
        on the far half (n.V < 0) only outside the dark mass (inside, the mass is in front of it)."""
        owner = np.full((self.H, self.W), -1, int)
        for j, (p, n, mod) in enumerate(self.mods):
            Y, X, _ = self.module_pixels(p, n, mod)
            owner[Y, X] = j
        vis = np.zeros(len(self.mods), int)
        for j, (p, n, mod) in enumerate(self.mods):
            own = owner == j
            if float(n @ V) < 0: own &= ~core
            vis[j] = int(own.sum())
        return vis

    def render(self, ground=R6.GRASS, shade=R6.GRASS_SHADE, with_trunk=True, with_shadow=True, skip=None):
        img = np.zeros((self.H, self.W, 3), np.uint8); img[:] = hexc(ground)
        core = self.core()
        if skip is None:
            skip = set()
            if self.cull:
                vis = self.visibility(core)
                skip = {j for j in range(len(self.mods)) if vis[j] == 0}
        self.skipped = skip
        if with_shadow: img[self.shadow()] = hexc(shade)
        if with_trunk: self.draw_trunk(img)
        if with_trunk and len(self.parts) > 1: self.draw_branches(img)
        img[core] = self.ramp[1]
        self.index = np.full((self.H, self.W), -1, int); self.index[core] = 1
        self.basebuf = np.full((self.H, self.W), -1, int); self.basebuf[core] = 1
        for j, (p, n, mod) in enumerate(self.mods):
            if j in skip: continue
            Y, X, c = self.module_pixels(p, n, mod)
            img[Y, X] = self.colour(c)
            self.index[Y, X] = np.floor(c).astype(int)
            self.basebuf[Y, X] = self.last_base
        return img

    def colour(self, c):
        """Ramp colours for (possibly half) steps: a half step is the mean of its two neighbours."""
        ramp = np.array(self.ramp, float)
        lo = np.floor(c).astype(int); hi = np.minimum(lo + 1, len(ramp) - 1); f = (np.asarray(c, float) - lo)[..., None]
        return np.round(ramp[lo] * (1 - f) + ramp[hi] * f).astype(np.uint8)

    def draw_branches(self, img):
        """A bough from the top of the trunk to the foot of each cap: bark, its side to the sun lit."""
        sx0, sy0 = self.ox, self.oy - self.cy + 8
        side = 1 if self.light2[0] >= 0 else -1
        for pt in self.parts:
            ex, ey = self.proj(np.array([pt.x0, pt.y0 + 3, pt.z0]))
            n = int(max(abs(ex - sx0), abs(ey - sy0))) + 1
            for k in range(n + 1):
                f = k / max(1, n)
                x = sx0 + (ex - sx0) * f; y = sy0 + (ey - sy0) * f
                w = 3 if f < 0.6 else 2
                for dx in range(-(w // 2), w - w // 2):
                    X, Y = int(round(x)) + dx, int(round(y))
                    if 0 <= X < self.W and 0 <= Y < self.H:
                        edge = dx * side
                        img[Y, X] = self.bark[2 if edge > 0 else (0 if edge < 0 else 1)]

    def draw_trunk(self, img):
        # carry the bark up until it is under the dark mass at every column of the trunk
        core = self.core()
        rel0, _ = trunk_relief(0, self.cut)
        w = rel0.shape[1]; X0 = self.ox - w // 2
        cols = [x for x in range(X0, X0 + w) if 0 <= x < self.W]
        top = self.oy - FOOT_STAGE
        bottoms = []
        for x in cols:
            ys = np.nonzero(core[:, x])[0]
            bottoms.append(ys.max() if len(ys) else top)
        need = max(0, top - (min(bottoms) - 3))
        rel, rg = trunk_relief(need, self.cut)
        Y0 = self.oy - FOOT_STAGE - need
        # the crown's shadow: from each bark pixel's place on the trunk toward the sun
        L = self.L
        shade = np.zeros(rel.shape, bool)
        gshadow = self.shadow() if L[1] > 0.1 else np.zeros((self.H, self.W), bool)
        cx = TC - self.cut / 2; rr = TRR - self.cut / 2
        lo, hi = self.yrange()
        for y in range(rel.shape[0]):
            for i in range(w):
                if rel[y, i] < -50: continue
                X, Y = X0 + i, Y0 + y
                if rg[y, i]:
                    shade[y, i] = 0 <= Y < self.H and 0 <= X < self.W and gshadow[Y, X]
                    continue
                if L[1] < 0.1: continue
                nx_ = max(-1.0, min(1.0, (i - cx) / rr))
                z = rr * 0.55 * math.sqrt(1 - nx_ * nx_)
                h = (self.oy - Y) + z
                x = X - self.ox
                for hh in np.arange(max(h, self.cy + lo), self.cy + hi + 1, 1.5):
                    t_ = (hh - h) / L[1]
                    px, pz = x + L[0] * t_, z + L[2] * t_
                    jit = 0.92 + 0.08 * (((X // 2) * 7 + (Y // 2) * 13) % 5) / 4
                    if self.inside(np.array(px), np.array(hh - self.cy), np.array(pz), lim=jit):
                        shade[y, i] = True; break
        t = lit_trunk(rel, rg, L, self.cut, shade)
        ys, xs = np.nonzero(t >= 0)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
        img[Y[ok], X[ok]] = np.array(self.bark)[t[ys[ok], xs[ok]]]
