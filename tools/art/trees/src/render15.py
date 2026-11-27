# Round 15: boughs thinner where they leave the trunk, forks spread wide to the sides (the user's two bare
# tree pictures): each fork turns 35..75 degrees off its parent's heading, alternating sides, rises 10..50
# degrees, leaves fairly level and curves up to its tip; depth 3 (bough -> forks -> twigs -> tips of 1 px).
# Tips are kept inside the (distorted) crown, so the bare skeleton is the one under the leaves.
# The trunk narrows a little above the roots (a flare, as in the pictures).
import math, random, numpy as np
import render7 as R, render14 as B
from render14 import Limb, H0, HALF

def unit(v):
    n = np.linalg.norm(v); return v / n if n > 1e-9 else v

class Tree(B.Tree):
    def __init__(self, sun, flare=True, **kw):
        self.flare = flare
        super().__init__(sun, **kw)

    def _fit(self, p0, end, lim=0.8):
        """Pull a tip back toward p0 until it is inside the crown."""
        for _ in range(14):
            if bool(self.inside(np.array(end[0]), np.array(end[1] - self.cy), np.array(end[2]), lim=lim)):
                return end
            end = p0 + (end - p0) * 0.85
        return end

    def _skeleton(self):
        """A short trunk that narrows above the roots and splits in a V into 2-3 limbs just under the
        crown; one limb goes on up as the leader (the trunk becoming a bough), the others lean out to the
        sides. Caps of a lobed crown hang on the limb of their side, each fed by a bough leaving that limb
        at the cap's height. Every limb then forks, the forks spreading wide."""
        rng = self.rng
        cut = self.cut
        base = np.array([(R.TC - cut / 2) - ((R.TW - cut) // 2), H0, 0.0])
        r_base = HALF - cut / 2
        parts = self.parts
        many = len(parts) > 1
        lo, hi = self.yrange()
        c_lo, c_hi = lo + self.cy, hi + self.cy
        flare = (lambda h: 0.55 + 0.45 * math.exp(-max(0.0, h - H0) / 14.0)) if self.flare else (lambda h: 1.0)
        hs = max(H0 + 8, c_lo + rng.uniform(0, 5))
        S = np.array([base[0] + rng.uniform(-3, 3), hs, rng.uniform(-1.5, 1.5)])
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

    def _forks(self, limb, limbs, depth, t_lo=0.3):
        rng = self.rng
        if depth <= 0: return
        n = (rng.randint(3, 4), rng.randint(2, 3))[min(1, limb.level - 1)] if limb.level >= 1 else 2
        if limb.level >= 3: n = rng.randint(0, 1)
        Lb = limb.length()
        side = rng.choice((-1, 1))
        for t in sorted(rng.uniform(t_lo, 0.92) for _ in range(n)):
            p0 = limb.at(t)
            tan = unit(limb.at(min(1, t + 0.02)) - limb.at(max(0, t - 0.02)))
            flat = math.hypot(tan[0], tan[2])
            az0 = math.atan2(tan[2], tan[0]) if flat > 0.2 else rng.uniform(0, math.tau)
            want = max(5.0, Lb * (1 - t) * rng.uniform(0.8, 1.2) + rng.uniform(4, 10))
            best = None
            for _try in range(4):          # a fork that would poke out of the crown turns another way
                az = az0 + side * rng.uniform(0.6, 1.3)
                el = math.radians(rng.uniform(15, 55) + 12 * _try)
                d = unit(np.array([math.cos(el) * math.cos(az), math.sin(el), 0.6 * math.cos(el) * math.sin(az)]))
                end = self._fit(p0, p0 + d * want, lim=0.9)
                ln = float(np.linalg.norm(end - p0))
                if best is None or ln > best[0]: best = (ln, d, end)
                if ln >= 0.6 * want: break
            side = -side
            ln, d, end = best
            if ln < 3: continue
            hd = unit(np.array([d[0], 0.0, d[2]]))
            c = p0 + hd * ln * 0.55 + np.array([0, ln * 0.06, 0])   # leaves level, the tip curves up
            rr = max(0.7, limb.r(t) * rng.uniform(0.5, 0.68))
            f = Limb([p0, c, end], rr, 0.6, rng.randint(0, 999), limb.level + 1, k=0.8)
            limbs.append(f)
            self._forks(f, limbs, depth - 1)
