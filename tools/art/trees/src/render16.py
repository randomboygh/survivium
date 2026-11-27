# Round 16: thin, medium and thick trees. One number per tree, the trunk's size s (its radius at the
# roots = s x the reference's 16 px), and a proportion per species: height grows with thickness as
# h = s^(2/3) (like real trees: a trunk twice as thick stands ~1.6 times as tall). The crown's size and the
# bare trunk under it follow h times the species' own factors; the root block (the reference's bitmap)
# is resampled to the trunk's width and height; limbs follow the trunk by the pipe rule of round 15.
import math, random, numpy as np
import render7 as R, render14 as B, render15 as F
from render14 import Limb, HALF, UPS, V, SPAN_LO, SPAN_HI
from render15 import unit

BX = int(R.TC) - R.TW // 2          # -2: the barrel middle relative to the foot, as before

def scaled_part(p, c):
    prof = p.prof
    return R.Part(lambda u: (prof(u)[0], prof(u)[1] * c), p.rx * c, p.rz * c, p.x0 * c, p.y0 * c, p.z0 * c,
                  p.mode, None if p.hc is None else p.hc * c)

def scaled_shape(name, crown_k, bole_k):
    """Register `name` scaled: crown dimensions x crown_k, the bare trunk under it (cy) x bole_k."""
    sh = R.SHAPES[name]
    key = '%s@%.3f,%.3f' % (name, crown_k, bole_k)
    if key not in R.SHAPES:
        R.SHAPES[key] = dict(label=sh['label'], parts=[scaled_part(p, crown_k) for p in sh['parts']],
                             cy=sh['cy'] * bole_k, cut=0)
    return key

def lit_scaled(rel, rg, cm, rm, sun, shade=None):
    """lit_trunk for a resampled root block: light by each pixel's place on the reference's barrel."""
    L = R.norm(sun)
    out = np.full(rel.shape, -1, int)
    for y in range(rel.shape[0]):
        for i in range(rel.shape[1]):
            r = rel[y, i]
            if r < -50: continue
            xo, yo = cm[i], rm[y]
            if rg[y, i]: b = R.root_band(float(R._root_normal(xo, yo) @ L))
            else: b = R.trunk_band(float(R._barrel_normal(xo) @ L))
            if shade is not None and shade[y, i]: b = max(b - 1, -2)
            out[y, i] = max(0, min(3, r + b))
    return out

# species: (label, crown shape, height ~ k * s^(2/3): crown factor, bare-trunk factor)
SPECIES = {
    'oak':    ('дуб: коренастый', 'lobed', 1.00, 1.45),
    'spread': ('шапки врозь', 'lobed2', 1.00, 1.6),
    'linden': ('липа: стройная', 'egg', 0.9, 2.4),
}
WIDTH = 0.8                    # the thickest trunk: 0.8 of the reference's
SIZES = (('тонкое', 0.42), ('среднее', 0.68), ('толстое', 1.0))

class Tree(F.Tree):
    def __init__(self, sun, species='oak', s=1.0, ex=2 / 3, **kw):
        label, shape, ck, bk = SPECIES[species]
        h = s ** ex
        self.s, self.hk = s, h
        self.sx = s * WIDTH               # trunk width
        self.sy = max(0.45, h)            # root block height
        self.h0 = int(round(R.FOOT_STAGE * self.sy))
        kw['shape'] = scaled_shape(shape, ck * h, bk * h)
        super().__init__(sun, **kw)

    def _root_block(self):
        rel0, rg0 = R.trunk_relief(0, 0)
        n0, w0 = rel0.shape
        fs = R.FOOT_STAGE
        w = max(6, int(round(w0 * self.sx)))
        # rows above the ground row scale by sy, the roots lying on the ground (rows from fs on) too
        up = self.h0; down = max(2, int(round((n0 - fs) * self.sy)))
        rm = [min(fs - 1, int((y + 0.5) / self.sy)) for y in range(up)] + \
             [min(n0 - 1, fs + int((y + 0.5) / self.sy)) for y in range(down)]
        cm = [min(w0 - 1, int((i + 0.5) / self.sx)) for i in range(w)]
        rel = rel0[np.ix_(rm, cm)]; rg = rg0[np.ix_(rm, cm)]
        return rel, rg, np.array(cm, float), np.array(rm, float)

    def _skeleton(self):
        """A short trunk that narrows above the roots and splits in a V into 2-3 limbs just under the
        crown; one limb goes on up as the leader (the trunk becoming a bough), the others lean out to the
        sides. Caps of a lobed crown hang on the limb of their side, each fed by a bough leaving that limb
        at the cap's height. Every limb then forks, the forks spreading wide."""
        rng = self.rng
        cut = self.cut
        base = np.array([BX, self.h0, 0.0])
        r_base = HALF * self.sx
        parts = self.parts
        many = len(parts) > 1
        lo, hi = self.yrange()
        c_lo, c_hi = lo + self.cy, hi + self.cy
        flare = (lambda h: 0.55 + 0.45 * math.exp(-max(0.0, h - self.h0) / (14.0 * self.sy))) if self.flare else (lambda h: 1.0)
        hs = max(self.h0 + 8 * self.sy, c_lo + rng.uniform(0, 5) * self.sy)
        S = np.array([base[0] + rng.uniform(-3, 3) * self.sx, hs, rng.uniform(-1.5, 1.5)])
        tl = Limb([base, base + (S - base) * 0.5 + np.array([rng.uniform(-2, 2), 0, 0]), S], r_base, 1, rng.randint(0, 999), 0)
        tl.r = lambda t: r_base * flare(tl.at(t)[1])
        rs = tl.r(1.0)
        limbs = [tl]
        # the leader's top
        if many:
            top_part = max(parts, key=lambda p: p.y0 + p.ytab[-1])
            tx, tz = top_part.axis(top_part.ytab[-1] * 0.4)
            T = np.array([tx, top_part.y0 + self.cy + top_part.ytab[0] + (top_part.ytab[-1] - top_part.ytab[0]) * 0.5, tz])
        else:
            pt = parts[0]
            T = np.array([pt.axis(0)[0] + rng.uniform(-4, 4), c_lo + (c_hi - c_lo) * 0.8, pt.axis(0)[1]])
        T = self._fit(S, T)
        # the side limbs: left and right (and sometimes a third, to the back)
        sides = [-1, 1]
        rng.shuffle(sides)
        heads = [(math.pi if sd < 0 else 0.0) + rng.uniform(-0.35, 0.35) for sd in sides]
        if rng.random() < 0.5:
            heads.append(-math.pi / 2 + rng.uniform(-0.4, 0.4))            # away from the camera
        groups = {i: [] for i in range(len(heads))}
        if many:
            for pt in parts:
                if pt is top_part: continue
                ang = math.atan2((pt.z0) * 0.6, pt.x0 - S[0])
                i = min(range(len(heads)), key=lambda j: abs(math.remainder(ang - heads[j], math.tau)))
                groups[i].append(pt)
        prim = []
        for i, az in enumerate(heads):
            if many and not groups[i]: continue
            if many:
                far = max(groups[i], key=lambda p: math.hypot(p.x0 - S[0], p.z0))
                foot, top = self._cap_info(far)
                ex, ez = far.axis((far.ytab[-1] - far.ytab[0]) * 0.3 + far.ytab[0])
                end = np.array([ex, foot + (top - foot) * 0.35, ez])
            else:
                el = math.radians(rng.uniform(38, 58))
                d = unit(np.array([math.cos(el) * math.cos(az), math.sin(el), 0.6 * math.cos(el) * math.sin(az)]))
                end = self._fit(S, S + d * 90, lim=0.7)
            prim.append((end, 0.6 * rs * rng.uniform(0.9, 1.05), groups[i]))
        prim.append((T, 0.62 * rs, []))
        for end, r0, grp in prim:
            d = end - S
            out = unit(np.array([d[0], 0, d[2]]))
            if np.linalg.norm(out) < 0.5: out = np.array([1.0, 0, 0])
            p0 = S + out * rs * 0.25 - np.array([0, rs * 1.2, 0])      # the crotch: limbs grow out of the trunk
            L_ = np.linalg.norm(end - p0)
            wob = np.array([rng.uniform(-1, 1), 0, 0]) * L_ * 0.12
            P = [p0, p0 + (end - p0) * 0.3 + out * L_ * 0.12 + np.array([0, L_ * 0.12, 0]) + wob, end - (end - p0) * 0.3 - wob, end]
            lb = Limb(P, r0, 0.8, rng.randint(0, 999), 1, k=0.9)
            base_r, extra = lb.r, max(0.0, 0.85 * rs - r0)
            lb.r = (lambda t, f=base_r, e=extra: f(t) + e * max(0.0, 1 - t / 0.2) ** 2)
            limbs.append(lb)
            # caps of this side: a bough from the limb at the cap's height
            for pt in grp:
                if np.allclose(end[[0, 2]], np.array(pt.axis(0)), atol=0.01): continue
                foot, top = self._cap_info(pt)
                ts = np.linspace(0, 1, 120); ys = np.array([lb.at(t)[1] for t in ts])
                t0 = float(np.interp(foot - rng.uniform(2, 5), ys, ts)) if ys[-1] > ys[0] else 0.5
                t0 = min(0.85, max(0.15, t0))
                q0 = lb.at(t0)
                ex, ez = pt.axis((pt.ytab[-1] - pt.ytab[0]) * 0.3 + pt.ytab[0])
                e2 = np.array([ex, foot + (top - foot) * 0.35, ez])
                o2 = unit(np.array([e2[0] - q0[0], 0, e2[2] - q0[2]]))
                L2 = np.linalg.norm(e2 - q0)
                b = Limb([q0, q0 + o2 * L2 * 0.5 + np.array([0, L2 * 0.05, 0]), e2], max(1.6, lb.r(t0) * 0.7), 0.7,
                         rng.randint(0, 999), 2, k=0.8)
                limbs.append(b)
                self._forks(b, limbs, 2)
            self._forks(lb, limbs, 3, t_lo=0.2)
        return limbs


    def shadow(self):
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
        hw = R.TRR * self.sx * 0.9
        Y, X = np.mgrid[0:self.H, 0:self.W]
        gx = (X - self.ox).astype(float); gz = (Y - self.oy).astype(float)
        for h in np.arange(0, self.h0 + 1, 2):
            m |= (np.abs(gx + L[0] / L[1] * h) < hw) & (np.abs(gz + L[2] / L[1] * h) < 6)
        self.skeleton_shadow(m)
        return m


    def draw_trunk(self, img):
        L = self.L
        # 1. the reference's root block, with the crown's shadow
        rel, rg, cm, rm = self._root_block()
        w = rel.shape[1]; X0 = self.ox + BX - int(round(R.TC * self.sx))
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
        t = lit_scaled(rel, rg, cm, rm, L, shade)
        ys, xs = np.nonzero(t >= 0)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
        img[Y[ok], X[ok]] = np.array(self.bark)[t[ys[ok], xs[ok]]]
        # 2. the skeleton
        zb = np.full((self.H, self.W), -1e9)
        idx = np.full((self.H, self.W), -1, int)
        pts = np.zeros((self.H, self.W, 3))
        texs = {}
        for p, r, tan, l, j in self._samples():
            lb = self.limbs[j]
            sx, sy = self.proj_abs(p)
            # the across direction on the screen: perpendicular to the tangent's screen image
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
            # don't paint into the root block's top rows
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
            if r >= 1.6: rel_ = np.where(np.abs(s[k]) > 0.86, rel_ - 1, rel_)   # each limb's own rim
            zb[Y[k], X[k]] = depth[k]
            idx[Y[k], X[k]] = rel_ + band
            pts[Y[k], X[k]] = p + r * nrm[k]
        has = zb > -1e8
        near = np.zeros_like(has)
        for dy_, dx_ in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            zn = np.roll(np.roll(zb, dy_, 0), dx_, 1)
            near |= has & (zn > zb + 2.5)
        idx[near] -= 1
        has[self.oy - self.h0 + 1:, :] &= False                # the root block owns its rows
        if self.crown and L[1] > 0.1:
            yy, xx = np.nonzero(has)
            sh = self._crown_shade_px(pts[yy, xx] - np.array([0, 0, 0]))
            v = idx[yy, xx] - np.where(sh, 1, 0)
            idx[yy, xx] = v
        c = np.clip(idx[has], 0, 3)
        img[has] = np.array(self.bark)[c]


    def height_px(self):
        """Ground to the crown's top."""
        lo, hi = self.yrange()
        return int(round(self.cy + hi))
