# Round 22: the willow with hanging leaf modules (hangmod22), on the approved chain (round 19
# species19 -> tree123 -> render17 limbs + round 16 crowns, render12 distortion).
# The crown is the 'weeping' bell: a dome on a skirt `depth` px deep (the bell's own skirt: 26). Rings
# are laid on the dome only, the lowest exactly on the rim, then up to the top (bottom ring first, as
# the user asked for every crown); the skirt is what the modules hang down over.
#   mode 'cascade': every module hangs; the rim's reach the skirt's bottom, the next ring's 3/4 of
#                   the way, the higher ones hang 22-30 px over the rings below;
#   mode 'fringe':  the dome keeps the round blade modules, only the rim and the ring above it hang.
# The dark mass: the dome's silhouette, and in the skirt only where the hanging modules are (the gaps
# between strands filled across, never below the tips).
import math, random, numpy as np
from scipy import ndimage
import render7 as R, render12 as W12, render16 as G, tree123 as TT, species19 as SP, hangmod22 as HM, module123 as MM
import bases22 as B22, trees22 as T22     # the approved trunk feet (round 22 trunks): by size

def willow_shape(depth):
    """The weeping bell with its skirt `depth` px below the dome's rim, flaring a little."""
    name = 'willow%d' % depth
    if name not in R.SHAPES:
        prof = R.polyline([(1.07, -depth), (1.05, -depth * 0.5), (1.02, -depth * 0.2)] + R.arc_pts(1.0, 0, 0.0, 22, 12, 'out'))
        R.shape(name, 'ива', [R.Part(prof, 40, 22)], 60)
    return name

class Willow(B22.Based, TT.Tree):
    def __init__(self, sun, mode='cascade', depth=26, kind='mix', hang_k=(1.0, 0.78, 0.6), spread=10, close=7, light='leaf', voids=0.0, void_jit=0.0, base='122', q=None, **kw):
        self.base, self.q = base, q
        self.mode, self.depth, self.kind, self.hang_k, self.voids = mode, depth, kind, hang_k, voids
        self.void_jit = void_jit
        self._voidl = None
        self.spread, self.close, self.light = spread, close, light
        self._core = None
        super().__init__(sun, **kw)
        pt = self.parts[0]
        # the rim in the part's own heights: the profile's y where the dome begins
        us = np.linspace(0, 1, 2001)
        ys = np.array([pt.prof(u)[1] for u in us])
        crown_k = (pt.ytab[-1] - pt.ytab[0]) / (self.depth + 22.0)       # scale of this tree's crown
        self.u_rim = float(us[np.argmin(np.abs(ys - 0.0))]) if ys.min() < 0 < ys.max() else 0.0
        self.y_rim = pt.y0 + pt.prof(self.u_rim)[1]
        self.y_bot = pt.y0 + pt.ytab[0]
        self._place_dome(kw.get('step', 15 * TT.RATIO['blades']), kw.get('hstep', 15 * TT.RATIO['blades']))

    def _place_dome(self, step, hstep):
        """render12._place on the dome only: rings from the rim (u_rim) to the top, equal arc length."""
        rng = random.Random(self.seed)
        jr = random.Random((getattr(self, 'warp_seed', 0) or 0) * 7919 + 3)
        lr = random.Random(self.seed * 31 + 7)
        blade = MM.modules('blades')
        pt = self.parts[0]
        us = np.linspace(self.u_rim, 1, 400)
        P = np.array([pt.prof(u) for u in us])
        seg = np.hypot(np.diff(P[:, 0]) * (pt.rx + pt.rz) / 2, np.diff(P[:, 1]))
        s = np.concatenate([[0], np.cumsum(seg)])
        nr = max(2, round(s[-1] / step))
        uks = np.interp(np.linspace(0, s[-1], nr + 1), s, us)
        mods = []
        info = []
        i = 0
        for k_, u in enumerate(uks):
            r, y = pt.prof(u)
            a0, b0 = pt.rx * r, pt.rz * r
            per = math.pi * (3 * (a0 + b0) - math.sqrt(max(0.0, (3 * a0 + b0) * (a0 + 3 * b0))))
            n = 1 if r < 0.12 else max(1, round(per / hstep))
            if n == 2 and r < 0.35: n = 1
            off = rng.uniform(0, math.tau)
            cx, cz = pt.axis(y) if hasattr(pt, 'axis') else (pt.x0, pt.z0)
            t = float(pt.t_of(y)) if hasattr(pt, 't_of') else 0.0
            ring = []
            for j in range(n):
                th = off + math.tau * j / n
                w = float(pt.wf(th, t)) if (n > 1 and hasattr(pt, 'wf')) else 1.0
                rr = 0.0 if n == 1 else w
                dy = jr.uniform(-self.jy, self.jy) if (n > 1 and self.jy and k_ > 0) else 0.0
                p = np.array([cx + rr * a0 * math.cos(th), pt.y0 + y + dy, cz + rr * b0 * math.sin(th)])
                ring.append((p, pt.normal(u, th)))
            ring.sort(key=lambda q: q[0][2])
            for p, nrm in ring:
                info.append((k_, (p[2] - cz) / max(1e-6, pt.rz)))
                hang = self.mode == 'cascade' or k_ <= 1
                if not hang:
                    mods.append((p, nrm, blade[(i * 5 + self.seed) % len(blade)]))
                else:
                    drop = (p[1] - self.y_bot) + max(0.0, p[2]) * 0.07       # to the skirt's bottom on the screen
                    if k_ < len(self.hang_k):
                        ln = drop * self.hang_k[k_] + lr.uniform(1, 6)
                    else:
                        ln = lr.uniform(22, 30)
                    ln = max(14, ln)
                    seed = HM.SEEDS[(i * 5 + self.seed) % len(HM.SEEDS)]
                    mods.append((p, nrm, HM.module(seed, flip=bool(i % 2), length=HM.length_class(ln), kind=self.kind, spread=self.spread)))
                i += 1
            if n == 1 and u > 0.5: break
        # draw order: back to front, and at about the same depth an upper ring over a lower one (the
        # cascade: an upper ring's strands hang over the lower ring's tops)
        order = sorted(range(len(mods)), key=lambda j: info[j][1] + 0.15 * info[j][0])
        self.mods = [mods[j] for j in order]
        self.ring = [info[j][0] for j in order]
        self.zrel = [info[j][1] for j in order]
        self._tones = {}
        self._core = None
        self._voidl = None

    def _skeleton(self):
        if self.base == '122': return super()._skeleton()
        return T22.skeleton17(self)

    def tones(self, mod, shade=False):
        if mod.get('style') != 'hang': return super().tones(mod, shade)
        key = (id(mod), bool(shade))
        if key not in self._tones:
            self._tones[key] = HM.tones(mod, self.light2, shade=bool(shade), light=self.light)
        return self._tones[key]

    def module_pixels(self, p, n, mod, inner=None):
        if mod.get('style') != 'hang': return super().module_pixels(p, n, mod)
        d = float(n @ self.L)
        base = 4 if d > self.d1 else (3 if d > self.d2 else 2)
        if inner: base, d = 2, -1.0                      # the curtain's inner side: in the crown's shade
        t = self.tones(mod, shade=(base == 2))
        mask = (t > -9) | mod['back']
        v = np.where(t > -9, t, -1)
        c = base + v
        if d < self.dp: c = np.minimum(c, 5)
        c = np.clip(c, 0, len(self.ramp) - 1)
        sx, sy = self.proj(p)
        ax, ay = mod['anchor']
        X0 = int(round(sx)) - ax; Y0 = int(round(sy)) - ay
        ys, xs = np.nonzero(mask)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
        self.last_base = base
        if inner is None: return Y[ok], X[ok], c[ys[ok], xs[ok]]
        return Y[ok], X[ok], c[ys[ok], xs[ok]], (t > -9)[ys[ok], xs[ok]]

    def draw_trunk(self, img):
        """The approved trunk and limbs; a twig tip poking out over the crown's top is left out (the
        limbs were grown for a crown whose modules stand out of its shape; hanging ones stay under it)."""
        before = img.copy()
        super().draw_trunk(img)
        A = np.zeros((self.H, self.W), bool)
        for p, n, mod in self.mods:
            Yp, Xp, _ = self.module_pixels(p, n, mod)
            A[Yp, Xp] = True
        has = A.any(0)
        top = np.where(has, A.argmax(0), self.H)
        above = (np.arange(self.H)[:, None] < top[None, :] + 2) & has[None, :]
        changed = (img != before).any(2)
        img[changed & above] = before[changed & above]

    def void_lines(self):
        """Screen rows where the voids begin, per column: for the front curtain and for the back one.
        The voids are the lowest `voids` part of the skirt (between y_void and the bottom)."""
        if self._voidl is not None: return self._voidl
        yv = self.y_bot + self.voids * (self.y_rim - self.y_bot)
        zs = np.linspace(-self.parts[0].rz * 1.4, self.parts[0].rz * 1.4, 240)
        front = np.full(self.W, np.nan); back = np.full(self.W, np.nan)
        for x in range(self.W):
            ins = self.inside(np.full(zs.shape, float(x - self.ox)), np.full(zs.shape, yv - 0.0), zs)
            if ins.any():
                zf, zb = zs[ins].max(), zs[ins].min()
                front[x] = self.oy - self.cy + zf - yv
                back[x] = self.oy - self.cy + zb - yv
        # columns just past the skirt's sides: carry the nearest values
        ok = ~np.isnan(front)
        if ok.any():
            idx = np.arange(self.W)
            front = np.interp(idx, idx[ok], front[ok]); back = np.interp(idx, idx[ok], back[ok])
        # each gap between strands opens at its own height (one line across them all looks ruled):
        # the gaps are the runs of columns without a leaf a little below the line
        if self.void_jit:
            Lf = np.zeros((self.H, self.W), bool)
            for p, n, mod in self.mods:
                if mod.get('style') != 'hang': continue
                Y, X, _, lm = self.module_pixels(p, n, mod, inner=False)
                Lf[Y[lm], X[lm]] = True
            zone = self.voids * (self.y_rim - self.y_bot)
            a = self.void_jit * zone
            rng = random.Random(self.seed * 131 + 17)
            rows = np.clip(np.round(front).astype(int) + 3, 0, self.H - 1)
            gap = ~Lf[rows, np.arange(self.W)]
            off = np.zeros(self.W)
            x = 0
            while x < self.W:
                e = x
                while e < self.W and gap[e] == gap[x]: e += 1
                if gap[x]: off[x:e] = round(rng.uniform(-a, a))
                x = e
            front = front + off
        self._voidl = (front, back)
        return self._voidl

    def in_void(self, Y, X, which='front'):
        if not self.voids: return np.zeros(len(Y), bool)
        f, b = self.void_lines()
        line = f if which == 'front' else b
        return Y > line[np.clip(X, 0, self.W - 1)]

    def render(self, ground=R.R6.GRASS, shade=R.R6.GRASS_SHADE, with_trunk=True, with_shadow=True, skip=None):
        """As render7.Tree.render, with voids low in the curtain: there the dark mass and the modules'
        dark backing are left out, the back curtain's strands (their inner, shaded side) are drawn behind
        the trunk, the front strands over it."""
        img = np.zeros((self.H, self.W, 3), np.uint8); img[:] = R.hexc(ground)
        core = self.core()
        if skip is None:
            skip = set()
            if self.cull:
                vis = self.visibility(core)
                skip = {j for j in range(len(self.mods)) if vis[j] == 0}
        self.skipped = skip
        if with_shadow: img[self.shadow()] = R.hexc(shade)
        # 1. the back curtain's low strands, behind the trunk: leaves only, in the shade
        for j, (p, n, mod) in enumerate(self.mods):
            if not self.voids or self.zrel[j] >= 0: continue
            Y, X, c, leafm = self.module_pixels(p, n, mod, inner=True)
            k = self.in_void(Y, X, 'back') & self.in_void(Y, X, 'front') & leafm
            img[Y[k], X[k]] = self.colour(c[k])
        if with_trunk: self.draw_trunk(img)
        img[core] = self.ramp[1]
        # 2. every module, in the cascade order; in the voids only the leaves (no backing); the back
        #    curtain's low part is already drawn
        for j, (p, n, mod) in enumerate(self.mods):
            if j in skip: continue
            if mod.get('style') != 'hang':
                Y, X, c = self.module_pixels(p, n, mod)
                img[Y, X] = self.colour(c); continue
            Y, X, c, leafm = self.module_pixels(p, n, mod, inner=False)
            if self.voids:
                if self.zrel[j] < 0:          # where the dark mass stays, over it as before
                    fv = self.in_void(Y, X, 'front')
                    k = ~fv | (leafm & ~self.in_void(Y, X, 'back'))
                else:
                    k = leafm | ~self.in_void(Y, X, 'front')
                Y, X, c = Y[k], X[k], c[k]
            img[Y, X] = self.colour(c)
        return img

    def core(self):
        if self._core is not None: return self._core
        full = super().core()
        if not hasattr(self, 'y_rim'): return full
        Y, X = np.mgrid[0:self.H, 0:self.W]
        sx = (X - self.ox).astype(float); sy = (Y - self.oy + self.cy).astype(float)
        lo, hi = self.yrange()
        dome = np.zeros((self.H, self.W), bool)
        for y in np.arange(self.y_rim, hi + 0.5, 0.5):
            dome |= self.inside(sx, y, sy + y, k=0.92)
        U = np.zeros((self.H, self.W), bool)
        for p, n, mod in self.mods:
            if mod.get('style') != 'hang': continue
            Yp, Xp, _ = self.module_pixels(p, n, mod)
            U[Yp, Xp] = True
        yy, xx = np.mgrid[-3:4, -(self.close // 2):self.close // 2 + 1]
        el = (xx / (self.close / 2.0)) ** 2 + (yy / 3.5) ** 2 <= 1.0
        Uc = ndimage.binary_fill_holes(ndimage.binary_closing(np.pad(U, 8), structure=el))[8:-8, 8:-8]
        core = dome | (full & Uc)
        # nor above the modules: the top ring hangs from its anchor, so the dome's top edge may peek out
        A = np.zeros((self.H, self.W), bool)
        for p, n, mod in self.mods:
            Yp, Xp, _ = self.module_pixels(p, n, mod)
            A[Yp, Xp] = True
        has = A.any(0)
        top = np.where(has, A.argmax(0), self.H)
        core &= np.arange(self.H)[:, None] > top[None, :]
        if self.voids:
            f, b = self.void_lines()
            core &= np.arange(self.H)[:, None] <= f[None, :]
        self._core = core
        return self._core

def willow(s, mode='cascade', depth=54, warp=11, sun=R.SUN_R, W=320, H=400, kind='mix', spread=10, close=7, light='leaf', voids=0.65, void_jit=0.3, base=None, **extra):
    SP.register()
    base = base or B22.foot_for(s)
    label, shape, ck, bk, wk, leaves, tints, bark, bare = SP.SPEC['willow']
    name = willow_shape(depth)
    G.SPECIES['willow22'] = ('ива', name, ck, bk)
    G.WIDTH = 0.8 * wk
    kw = dict(k=1.3, tint=R.species_tint(*tints), d1=0.64, d2=0.36, dp=0.8, shade_flat='quarter', W=W, H=H,
              bark=SP.bark_ramp(bark))
    kw.update(extra)
    t = Willow(sun, mode=mode, depth=depth, kind=kind, spread=spread, close=close, light=light, voids=voids, void_jit=void_jit, base=base, leaves='blades', species='willow22', s=s, warp=warp, **kw)
    G.WIDTH = 0.8
    return t
