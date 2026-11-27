# Round 12: a little random distortion of the crown shapes, per tree seed.
# Each part gets a radius factor w(theta, t) = 1 + sum_k A_k(t) cos(k theta + phi_k) (k = 1..3, the
# amplitudes blend from the bottom to the top of the part, t = 0..1 by height), a height factor, a
# lean (the axis drifts sideways with height) and, for crowns of several caps, small moves and sizes
# of the caps. Modules, the dark mass, the ground shadow and the bark's shadow all use the same
# distorted shape (Tree.inside).
import math, random, numpy as np
import render7 as R

class WarpPart(R.Part):
    def __init__(self, base, rng, amp, many):
        g = amp / 0.14      # everything else grows with the amplitude too
        hs = 1 + rng.uniform(-0.10, 0.10) * g
        sx = 1 + rng.uniform(-0.12, 0.12) * g if many else 1.0
        ax, az = sx * (1 + rng.uniform(-0.06, 0.06) * g), sx * (1 + rng.uniform(-0.06, 0.06) * g)
        dx = rng.uniform(-5, 5) * g if many else 0.0
        dz = rng.uniform(-4, 4) * g if many else 0.0
        dy = rng.uniform(-3, 3) * g if many else 0.0
        prof = base.prof
        super().__init__(lambda u: (prof(u)[0], prof(u)[1] * hs * sx), base.rx * ax, base.rz * az,
                         base.x0 + dx, base.y0 + dy, base.z0 + dz, base.mode,
                         None if base.hc is None else base.hc * hs * sx)
        self.lean = (rng.uniform(-0.14, 0.14) * g, rng.uniform(-0.08, 0.08) * g)
        self.harm = [(k, amp * rng.uniform(0.3, 1.0) / k ** 0.5, amp * rng.uniform(0.3, 1.0) / k ** 0.5,
                      rng.uniform(0, math.tau)) for k in (1, 2, 3)]
        self.harm.append((rng.choice((4, 5)), amp * 0.5, amp * 0.5, rng.uniform(0, math.tau)))
        self.y_lo, self.y_hi = self.ytab[0], self.ytab[-1]

    def t_of(self, y):
        return np.clip((y - self.y_lo) / max(1e-6, self.y_hi - self.y_lo), 0, 1)

    def wf(self, th, t):
        f = 1.0
        for k, a0, a1, ph in self.harm:
            f = f + (a0 + (a1 - a0) * t) * np.cos(k * th + ph)
        return f

    def axis(self, y):
        return self.x0 + self.lean[0] * y, self.z0 + self.lean[1] * y


class Tree(R.Tree):
    def __init__(self, sun, warp=None, amp=0.10, jy=0.0, **kw):
        self.jy = jy
        super().__init__(sun, **kw)
        if warp is None: return
        rng = random.Random(warp)
        many = len(self.parts) > 1
        self.warp_seed = warp
        self.parts = [WarpPart(p, rng, amp, many) for p in self.parts]
        self._place(kw.get('step', 15), kw.get('hstep', 15))

    def _place(self, step, hstep):
        rng = random.Random(self.seed)
        jr = random.Random((self.warp_seed or 0) * 7919 + 3)
        mods = []
        for part in sorted(self.parts, key=lambda p: p.y0 + p.z0):
            uks = part.ring_us(step)
            for k_, u in enumerate(uks):
                r, y = part.prof(u)
                last = k_ == len(uks) - 1
                a0, b0 = part.rx * r, part.rz * r
                per = math.pi * (3 * (a0 + b0) - math.sqrt(max(0.0, (3 * a0 + b0) * (a0 + 3 * b0))))
                n = 1 if (last and part.mode == 'phi') or r < 0.12 else max(1, round(per / hstep))
                if n == 2 and r < 0.35: n = 1
                off = rng.uniform(0, math.tau)
                cx, cz = part.axis(y)
                t = float(part.t_of(y))
                ring = []
                for i in range(n):
                    th = off + math.tau * i / n
                    w = float(part.wf(th, t)) if n > 1 else 1.0
                    rr = 0.0 if n == 1 else w
                    dy = jr.uniform(-self.jy, self.jy) if (n > 1 and self.jy) else 0.0
                    p = np.array([cx + rr * a0 * math.cos(th), part.y0 + y + dy, cz + rr * b0 * math.sin(th)])
                    ring.append((p, part.normal(u, th)))
                ring.sort(key=lambda q: q[0][2])
                mods += ring
                if part.mode != 'phi' and n == 1 and u > 0.5:
                    break
        self.mods = [(p, n, R.MODS[(i * 5 + self.seed) % len(R.MODS)]) for i, (p, n) in enumerate(mods)]
        self._tones = {}

    def inside(self, x, y, z, k=1.0, lim=1.0):
        if not isinstance(self.parts[0], WarpPart):
            return super().inside(x, y, z, k, lim)
        res = np.zeros(np.broadcast(x, y, z).shape, bool)
        for pt in self.parts:
            yy = y - pt.y0
            r = pt.r_at(yy)
            cx, cz = pt.axis(yy)
            ex, ez = (x - cx) / (pt.rx * k), (z - cz + pt.z0 - pt.z0) / (pt.rz * k)
            ez = (z - cz) / (pt.rz * k)
            r = r * pt.wf(np.arctan2(ez, ex), pt.t_of(yy))
            res |= (r > 0) & (ex * ex + ez * ez < r * r * lim)
        return res

    def draw_branches(self, img):
        # boughs end at each cap's leaning foot
        saved = [(p.x0, p.z0) for p in self.parts]
        for p in self.parts:
            if isinstance(p, WarpPart): p.x0, p.z0 = p.axis(p.y_lo + 3)
        try:
            super().draw_branches(img)
        finally:
            for p, (x0, z0) in zip(self.parts, saved): p.x0, p.z0 = x0, z0
