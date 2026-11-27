# Round 14: the trunk above the roots and the boughs as one skeleton of tapering limbs.
# The trunk rises from the reference's root block, thins (pipe rule: what leaves as boughs is taken
# from it) and ends as the thinnest bough at the top of the crown. Boughs leave the trunk at the height
# of the cap they feed, fork once or twice, thick at the trunk, thin at the cap. The skeleton is drawn
# as stacked discs with a z-buffer, lit per pixel by the sun like the trunk (bark relief carried along
# each limb, its crevices narrowing with it), in the crown's cast shadow, and casts its own ground shadow.
# The crown distortion's strength is random per tree, 0.10..0.30.
import math, random, numpy as np
import render7 as R, render12 as W

V = R.V
UPS = np.array([0.0, -1.0, 1.0]) / math.sqrt(2)      # world direction of +screen y on the picture plane
H0 = R.FOOT_STAGE                                    # height of the root block's top row
SPAN_LO, SPAN_HI = 2, 34
HALF = (SPAN_HI - SPAN_LO) / 2.0                     # 16: the trunk's radius at the root block's top

def bez(P, t):
    P = np.asarray(P, float); n = len(P) - 1
    return sum(math.comb(n, i) * (1 - t) ** (n - i) * t ** i * P[i] for i in range(n + 1))

class Limb:
    def __init__(self, P, r0, r1, seed, level, l0=0.0, k=1.0):
        self.P, self.r0, self.r1, self.seed, self.level, self.l0, self.k = P, r0, r1, seed, level, l0, k
    def at(self, t):
        return bez(self.P, t)
    def r(self, t):
        return self.r1 + (self.r0 - self.r1) * (1 - t) ** self.k
    def length(self):
        pts = [self.at(t) for t in np.linspace(0, 1, 40)]
        return float(sum(np.linalg.norm(b - a) for a, b in zip(pts, pts[1:])))


class Tree(W.Tree):
    def __init__(self, sun, warp=None, amp=None, jy=4.0, crown=True, **kw):
        if amp is None:
            amp = 0.10 + 0.20 * random.Random('amp%d' % warp).random() if warp is not None else 0.0
        self.amp_used = amp
        super().__init__(sun, warp=warp, amp=max(amp, 1e-6), jy=jy if warp is not None else 0.0, **kw)
        self.crown = crown
        self.rng = random.Random((warp or 0) * 977 + 13)
        self.limbs = self._skeleton()

    # ------------------------------------------------ skeleton
    def _cap_info(self, pt):
        foot = pt.y0 + pt.ytab[0] + self.cy
        top = pt.y0 + pt.ytab[-1] + self.cy
        return foot, top

    def _skeleton(self):
        rng = self.rng
        cut = self.cut
        base = np.array([R.TC - cut / 2 - (40 - cut) // 2 + 0.0, H0, 0.0])
        base[0] = (R.TC - cut / 2) - ((R.TW - cut) // 2)
        r_base = HALF - cut / 2
        parts = self.parts
        many = len(parts) > 1
        lo, hi = self.yrange()
        c_lo, c_hi = lo + self.cy, hi + self.cy
        # where the trunk ends: the highest cap, or the crown's upper middle
        if many:
            top_part = max(parts, key=lambda p: p.y0 + p.ytab[-1])
            tx, tz = top_part.axis(top_part.ytab[-1] * 0.4)
            T = np.array([tx, top_part.y0 + self.cy + (top_part.ytab[-1] - top_part.ytab[0]) * 0.45 + top_part.ytab[0], tz])
        else:
            pt = parts[0]
            T = np.array([pt.axis(0)[0], c_lo + (c_hi - c_lo) * 0.72, pt.axis(0)[1]])
        bend = np.array([rng.uniform(-6, 6), 0, rng.uniform(-3, 3)])
        tr_P = [base, base + (T - base) * 0.35 + bend, base + (T - base) * 0.7 - bend * 0.5, T]
        trunk_len = float(T[1] - H0)
        # boughs: (height on trunk, end point, size)
        boughs = []
        if many:
            for pt in parts:
                if pt is top_part: continue
                foot, top = self._cap_info(pt)
                h = max(H0 + 4, min(T[1] - 4, foot - rng.uniform(3, 8)))
                ex, ez = pt.axis((pt.ytab[-1] - pt.ytab[0]) * 0.3 + pt.ytab[0])
                end = np.array([ex, foot + (top - foot) * 0.35, ez])
                boughs.append((h, end, pt.rx, pt))
        else:
            pt = parts[0]
            n = rng.randint(3, 5)
            off = rng.uniform(0, math.tau)
            for i in range(n):
                th = off + math.tau * i / n + rng.uniform(-0.4, 0.4)
                fy = rng.uniform(0.15, 0.55)
                yy = pt.ytab[0] + (pt.ytab[-1] - pt.ytab[0]) * fy
                rr = max(0.2, pt.r_at(yy)) * pt.wf(th, pt.t_of(yy)) * rng.uniform(0.55, 0.75)
                cx, cz = pt.axis(yy)
                end = np.array([cx + rr * pt.rx * math.cos(th), pt.y0 + yy + self.cy, cz + rr * pt.rz * math.sin(th)])
                h = max(H0 + 4, min(T[1] - 6, c_lo + (c_hi - c_lo) * rng.uniform(0.0, 0.3)))
                boughs.append((h, end, pt.rx * 0.5, pt))
        boughs.sort(key=lambda b: b[0])
        # pipe rule: each bough takes its share of the trunk where it leaves (r^2 = r_up^2 + s^2), so the
        # trunk steps down bough by bough and the last stretch is a bough itself
        r_tip = 1.3
        sizes, r_now = [], r_base
        for h, end, rx, pt in boughs:
            s_ = max(2.0, min(r_now * 0.66, 2.5 + rx * 0.42))
            sizes.append(s_)
            r_now = math.sqrt(max(r_now * r_now - s_ * s_, 2.5 ** 2))
        limbs = []
        tl = Limb(tr_P, r_base, r_tip, rng.randint(0, 999), 0)
        hs = [b[0] for b in boughs]
        def trunk_r(t):
            h = tl.at(t)[1]
            r2 = r_base ** 2
            for hb, s_ in zip(hs, sizes):
                r2 -= s_ * s_ * min(1.0, max(0.0, (h - hb + 2) / 8))
            r = math.sqrt(max(r2, 1.0)) * (1 - 0.15 * t)
            tail = max(0.0, (t - 0.75) / 0.25)            # the last quarter thins to the tip
            return max(r_tip, r * (1 - tail) + r_tip * tail)
        tl.r = trunk_r
        limbs.append(tl)
        for (h, end, rx, pt), s in zip(boughs, sizes):
            # the trunk's t at height h
            ts = np.linspace(0, 1, 200); ys = np.array([tl.at(t)[1] for t in ts])
            t0 = float(np.interp(h, ys, ts))
            p0 = tl.at(t0)
            d = end - p0
            out = np.array([d[0], 0, d[2]]); n_out = np.linalg.norm(out)
            out = out / n_out if n_out > 1e-6 else np.array([1.0, 0, 0])
            p0 = p0 + out * trunk_r(t0) * 0.45
            d = end - p0
            L_ = np.linalg.norm(d)
            P = [p0, p0 + out * L_ * 0.3 + np.array([0, L_ * 0.12, 0]), end - np.array([0, L_ * 0.3, 0]) - out * L_ * 0.1, end]
            b = Limb(P, s, 1.0, rng.randint(0, 999), 1, k=0.55)
            limbs.append(b)
            self._forks(b, pt, limbs, 2)
        # a fork or two near the trunk's top as well
        self._forks(tl, parts[0] if not many else top_part, limbs, 1, t_lo=0.7)
        return limbs

    def _forks(self, limb, pt, limbs, depth, t_lo=0.35):
        rng = self.rng
        if depth <= 0: return
        n = rng.randint(2, 3) if limb.level < 2 else rng.randint(1, 2)
        Lb = limb.length()
        for _ in range(n):
            t = rng.uniform(t_lo, 0.8)
            p0 = limb.at(t); tan = limb.at(min(1, t + 0.02)) - limb.at(max(0, t - 0.02))
            tan = tan / max(1e-6, np.linalg.norm(tan))
            # turn the limb's way around the vertical by 30..60 degrees, rising
            a = rng.choice((-1, 1)) * rng.uniform(0.5, 1.05)
            c, s_ = math.cos(a), math.sin(a)
            d = np.array([tan[0] * c - tan[2] * s_, max(tan[1], 0.2) + rng.uniform(0.15, 0.5), tan[0] * s_ + tan[2] * c])
            d = d / np.linalg.norm(d)
            ln = Lb * (1 - t) * rng.uniform(0.45, 0.8) + 3
            end = p0 + d * ln
            # keep the tip inside its cap
            yy = end[1] - self.cy - pt.y0
            r = pt.r_at(np.clip(yy, pt.ytab[0], pt.ytab[-1]))
            cx, cz = pt.axis(yy)
            q = math.hypot((end[0] - cx) / pt.rx, (end[2] - cz) / pt.rz)
            lim = max(0.15, r) * 0.85
            if q > lim and q > 1e-6:
                f = lim / q; end[0] = cx + (end[0] - cx) * f; end[2] = cz + (end[2] - cz) * f
            rr = max(1.1, limb.r(t) * rng.uniform(0.6, 0.8))
            if rr < 1.0 or np.linalg.norm(end - p0) < 3: continue
            mid = p0 + (end - p0) * 0.5 + np.array([0, rng.uniform(0, 2), 0])
            f = Limb([p0, mid, end], rr, 0.8, rng.randint(0, 999), limb.level + 1, k=0.7)
            limbs.append(f)
            self._forks(f, pt, limbs, depth - 1)

    # ------------------------------------------------ drawing
    def _samples(self):
        """All discs of the skeleton: centre, radius, tangent, length from the limb's start, limb."""
        out = []
        for j, lb in enumerate(self.limbs):
            ln = lb.length(); n = max(2, int(ln * 2.5))
            l = 0.0; prev = lb.at(0)
            for i in range(n + 1):
                t = i / n; p = lb.at(t)
                l += float(np.linalg.norm(p - prev)); prev = p
                tan = lb.at(min(1, t + 0.01)) - lb.at(max(0, t - 0.01))
                tan = tan / max(1e-6, np.linalg.norm(tan))
                out.append((p, float(lb.r(t)), tan, l, j))
        return out

    def proj_abs(self, p):
        return self.ox + p[0], self.oy + p[2] - p[1]

    def skeleton_shadow(self, m):
        L = self.L
        if L[1] < 0.1: return
        for p, r, tan, l, j in self._samples()[::2]:
            g = p - L * (p[1] / L[1])
            sx, sy = self.ox + g[0], self.oy + g[2]
            ri = int(math.ceil(r)) + 1
            y0, x0 = int(round(sy)), int(round(sx))
            ys, xs = np.mgrid[-ri:ri + 1, -ri:ri + 1]
            ok = xs * xs + ys * ys <= r * r + 0.5
            Y, X = ys[ok] + y0, xs[ok] + x0
            k = (Y >= 0) & (Y < self.H) & (X >= 0) & (X < self.W)
            m[Y[k], X[k]] = True

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
        hw = (R.TRR - self.cut / 2) * 0.9
        Y, X = np.mgrid[0:self.H, 0:self.W]
        gx = (X - self.ox).astype(float); gz = (Y - self.oy).astype(float)
        for h in np.arange(0, H0 + 1, 2):
            m |= (np.abs(gx + L[0] / L[1] * h) < hw) & (np.abs(gz + L[2] / L[1] * h) < 6)
        self.skeleton_shadow(m)
        return m

    def _bark_tex(self, seed, n):
        return R.bark_rows(n, seed)[::-1]            # row l = l px above the start

    def draw_branches(self, img):
        pass                                          # the skeleton draws them

    def draw_trunk(self, img):
        L = self.L
        # 1. the reference's root block, with the crown's shadow
        rel, rg = R.trunk_relief(0, self.cut)
        w = rel.shape[1]; X0 = self.ox - w // 2
        Y0 = self.oy - H0
        shade = np.zeros(rel.shape, bool)
        if self.crown and L[1] > 0.1:
            gshadow = self.shadow()
            for y in range(rel.shape[0]):
                for i in range(w):
                    if rel[y, i] < -50: continue
                    X, Y = X0 + i, Y0 + y
                    if rg[y, i] and 0 <= Y < self.H and 0 <= X < self.W:
                        shade[y, i] = gshadow[Y, X]
            shade |= self._crown_shade_px(np.array([[X0 + i - self.ox, H0 - y, 0.0] for y in range(rel.shape[0]) for i in range(w)])).reshape(rel.shape) & ~rg
        t = R.lit_trunk(rel, rg, L, self.cut, shade)
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
        has[self.oy - H0 + 1:, :] &= False                # the root block owns its rows
        if self.crown and L[1] > 0.1:
            yy, xx = np.nonzero(has)
            sh = self._crown_shade_px(pts[yy, xx] - np.array([0, 0, 0]))
            v = idx[yy, xx] - np.where(sh, 1, 0)
            idx[yy, xx] = v
        c = np.clip(idx[has], 0, 3)
        img[has] = np.array(self.bark)[c]

    def _crown_shade_px(self, P):
        """For world points P (x, h, z), whether the crown stands between them and the sun."""
        L = self.L
        P = np.asarray(P, float)
        res = np.zeros(len(P), bool)
        if not self.crown or L[1] < 0.1 or len(P) == 0: return res
        lo, hi = self.yrange()
        for hh in np.arange(self.cy + lo, self.cy + hi + 1, 1.5):
            t_ = (hh - P[:, 1]) / L[1]
            okk = t_ > 0
            px, pz = P[:, 0] + L[0] * t_, P[:, 2] + L[2] * t_
            res |= okk & self.inside(px, np.full(len(P), hh - self.cy), pz, lim=0.95)
        return res

    def render(self, **kw):
        if self.crown: return super().render(**kw)
        img = np.zeros((self.H, self.W, 3), np.uint8); img[:] = R.hexc(kw.get('ground', R.R6.GRASS))
        img[self.shadow()] = R.hexc(kw.get('shade', R.R6.GRASS_SHADE))
        self.draw_trunk(img)
        self.skipped = set()
        return img
