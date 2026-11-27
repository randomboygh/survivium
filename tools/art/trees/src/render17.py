# Round 17. The user kept the new limbs and took the crowns back to round 16 (full leaf modules): small=False
# is the default; small=True gives round 17's smaller modules (not chosen).
# Round 17 (user's pick «А» on round 16): small crowns get smaller leaf modules (module16: the leaves
# pulled toward the module's middle, the least visible left out), set closer together; and the limbs
# are no longer straight sticks: every limb grows in segments, forks leave at the bends and the limb
# turns away from each fork (the zigzag of real boughs), forks spread to the sides in the picture's
# plane, the tips curve up; each fork takes its share of the limb's thickness (pipe rule), so limbs
# thin step by step. The trunk rounds into the limbs at the split instead of ending in a flat top.
import math, random, numpy as np
import render7 as R, render14 as B, render16 as G, module16 as MK
from render14 import Limb, HALF

V = R.V
UP = np.array([0.0, 1.0, 0.0])

def unit(v):
    n = np.linalg.norm(v); return v / n if n > 1e-9 else v

def rot(v, axis, a):
    k = unit(np.asarray(axis, float)); c, s = math.cos(a), math.sin(a)
    return v * c + np.cross(k, v) * s + k * float(k @ v) * (1 - c)


class PathLimb(Limb):
    """A limb through points (a Catmull-Rom curve, by length); its radius drops by `steps` (t, factor)
    where forks leave and tapers a little along the way."""
    def __init__(self, pts, r0, r1, seed, level, steps=(), taper=0.35):
        super().__init__(pts, r0, r1, seed, level)
        Q = np.array(pts, float)
        E = np.vstack([2 * Q[0] - Q[1], Q, 2 * Q[-1] - Q[-2]])
        dense = []
        for i in range(1, len(E) - 2):
            p0, p1, p2, p3 = E[i - 1], E[i], E[i + 1], E[i + 2]
            for s in np.linspace(0, 1, 12, endpoint=False):
                dense.append(0.5 * (2 * p1 + (-p0 + p2) * s + (2 * p0 - 5 * p1 + 4 * p2 - p3) * s * s
                                    + (-p0 + 3 * p1 - 3 * p2 + p3) * s ** 3))
        dense.append(Q[-1])
        self.D = np.array(dense)
        self.cum = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(self.D, axis=0), axis=1))])
        self.total = max(1e-6, float(self.cum[-1]))
        self.steps, self.taper = list(steps), taper

    def at(self, t):
        s = min(1.0, max(0.0, t)) * self.total
        return np.array([np.interp(s, self.cum, self.D[:, i]) for i in range(3)])

    def length(self):
        return self.total

    def t_of_point(self, i):
        return float(self.cum[min(i * 12, len(self.cum) - 1)] / self.total)

    def r(self, t):
        f = 1.0
        for ts, fs in self.steps:
            w = min(1.0, max(0.0, (t - ts) / 0.08 + 0.5))
            f *= 1 - (1 - fs) * w
        return max(self.r1, self.r0 * f * (1 - self.taper * t))


class Tree(G.Tree):
    def __init__(self, sun, species='oak', s=1.0, ex=2 / 3, small=False, **kw):
        h = s ** ex
        self.mk = min(1.0, 0.35 + 0.65 * h) if small else 1.0     # leaf module size: 0.72 / 0.85 / 1
        kw.setdefault('step', 15 * self.mk); kw.setdefault('hstep', 15 * self.mk)
        kw.setdefault('jy', 4.0 * self.mk)
        super().__init__(sun, species=species, s=s, ex=ex, **kw)
        if self.mk < 0.999:
            mods = MK.modules(self.mk)
            self.mods = [(p, n, mods[(i * 5 + self.seed) % len(mods)]) for i, (p, n, _) in enumerate(self.mods)]
            self._tones = {}

    def module_pixels(self, p, n, mod):
        if 'disc' not in mod: return super().module_pixels(p, n, mod)
        M = R.M
        d = float(n @ self.L)
        base = 4 if d > self.d1 else (3 if d > self.d2 else 2)
        t = self.tones(mod, shade=(('flat' if self.shade_flat is True else self.shade_flat) if base == 2 else False))
        mask = (t > -9) | mod['disc']
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

    # ------------------------------------------------ the skeleton
    def _in_crown(self, p, k=1.25):
        # a little beyond the shape: the leaf modules reach past it, so twigs there are still covered
        return bool(self.inside(np.array(p[0]), np.array(p[1] - self.cy), np.array(p[2]), k=k))

    def _fork_dir(self, d, sd):
        """A fork turns 35..75 degrees off its parent's heading around the vertical and rises 15..50
        degrees (z squashed as on the screen), so forks fan out to the sides as in round 15."""
        rng = self.rng
        flat = math.hypot(d[0], d[2])
        az0 = math.atan2(d[2], d[0]) if flat > 0.2 else rng.uniform(0, math.tau)
        az = az0 + sd * rng.uniform(0.6, 1.3)
        el = math.radians(rng.uniform(15, 50))
        return unit(np.array([math.cos(el) * math.cos(az), math.sin(el), 0.6 * math.cos(el) * math.sin(az)]))

    def grow(self, limbs, p0, d0, length, r0, level, target=None, steer=0.0, nf=None, contain=True):
        """Grow a limb from p0 along d0 in segments; a fork leaves at each bend and the limb turns away
        from it; forks grow the same way, one level down."""
        rng = self.rng
        if length < 2.5 or r0 < 0.45: return None
        if nf is None:
            nf = {1: rng.randint(3, 4), 2: rng.randint(2, 3), 3: rng.randint(2, 2)}.get(level, rng.randint(0, 1))
            if r0 < 0.9: nf = min(nf, 1)
            if length < 7: nf = min(nf, 1)
        nseg = max(2, nf + 1)
        fr = np.array([rng.uniform(0.8, 1.25) for _ in range(nseg)])
        if level == 1: fr[0] = fr[1:].sum() * rng.uniform(0.35, 0.6)    # a limb runs a while before it forks
        fr = fr / fr.sum() * length
        p, d = np.array(p0, float), unit(np.array(d0, float))
        pts, bends = [p.copy()], []
        sd = rng.choice((-1, 1))
        entered = (not contain) or level < 2 or self._in_crown(p)
        for i in range(nseg):
            d = rot(d, V, rng.uniform(-0.14, 0.14))
            d = rot(d, UP, rng.uniform(-0.2, 0.2))
            if target is not None:
                d = unit(d + steer * (unit(target - p) - d))
            if i == nseg - 1 and level >= 2:
                d = unit(d + UP * 0.45)                       # the tip curves up
            if d[1] < 0.06: d = unit(np.array([d[0], 0.06, d[2]]))
            q = p + d * fr[i]
            if not entered:
                if not self._in_crown(q):
                    if i <= 1 and nseg > 2 and i < nseg - 1:
                        p = q; pts.append(p.copy()); continue  # one more segment to reach the crown
                    return None
                entered = True
            elif contain and level >= 2 and not self._in_crown(q):
                ok = False
                for f in (0.8, 0.6, 0.4):                  # shorter, or turned another way, or up
                    for a in (0.0, 0.45, -0.45, 0.9, -0.9):
                        d2 = rot(d, V, a) if a else d
                        d2 = unit(d2 + UP * (1 - f) * 0.8)
                        q2 = p + d2 * fr[i] * f
                        if self._in_crown(q2): q, d, ok = q2, d2, True; break
                    if ok: break
                if not ok:
                    break
            p = q
            pts.append(p.copy())
            if i < nseg - 1 and len(bends) < nf:
                fd = self._fork_dir(d, sd)
                bends.append((len(pts) - 1, sd, d.copy(), fd))
                # the limb turns away from its fork, as it shows on the screen
                a2 = (d[0], d[2] - d[1]); b2 = (fd[0], fd[2] - fd[1])
                cr = a2[0] * b2[1] - a2[1] * b2[0]
                d = rot(d, V, (1 if cr >= 0 else -1) * rng.uniform(0.18, 0.32))
                sd = -sd
        if len(pts) < 2 or np.linalg.norm(pts[-1] - pts[0]) < 2: return None
        if len(pts) == 2: pts.insert(1, (pts[0] + pts[1]) / 2)
        # forks and their share of the thickness
        forks = []
        for i, sd_, db, fd in bends:
            if i >= len(pts) - 1: continue
            c = rng.uniform(0.55, 0.72)
            forks.append((i, sd_, db, fd, c))
        tmp = PathLimb(pts, r0, 0.5, rng.randint(0, 999), level)
        steps = [(tmp.t_of_point(i), math.sqrt(max(0.2, 1 - c * c))) for i, _, _, _, c in forks]
        lb = PathLimb(pts, r0, 0.5, tmp.seed, level, steps)
        limbs.append(lb)
        for i, sd_, db, fd, c in forks:
            t = lb.t_of_point(i)
            rr = lb.r(max(0.0, t - 0.05)) * c
            rest = lb.length() * (1 - t)
            want = rest * rng.uniform(0.75, 1.05) + rng.uniform(3, 7) * (0.75 ** (level - 1)) * self.hk
            for k_ in range(4):         # a fork that cannot stay in the crown tries steeper, then another way
                if k_ == 2: fd = self._fork_dir(db, -sd_)
                if self.grow(limbs, lb.at(t), fd, want * (1 - 0.15 * k_), rr, level + 1) is not None: break
                fd = unit(fd + UP * 0.5)
        return lb

    def _skeleton(self):
        rng = self.rng
        base = np.array([G.BX, self.h0, 0.0])
        r_base = HALF * self.sx
        parts = self.parts
        many = len(parts) > 1
        lo, hi = self.yrange()
        c_lo, c_hi = lo + self.cy, hi + self.cy
        fl = lambda h: 0.55 + 0.45 * math.exp(-max(0.0, h - self.h0) / (14.0 * self.sy))
        if many:      # the trunk splits low enough that the limbs rise to the farthest caps at ~30 degrees
            far_ = max(parts, key=lambda p: math.hypot(p.x0 - G.BX, p.z0))
            f_foot = far_.y0 + far_.ytab[0] + self.cy
            hs = f_foot - math.tan(math.radians(rng.uniform(26, 36))) * math.hypot(far_.x0 - G.BX, far_.z0)
            hs = max(self.h0 + 8 * self.sy, min(c_lo + rng.uniform(0, 5) * self.sy, hs))
        else:
            hs = max(self.h0 + 8 * self.sy, c_lo + rng.uniform(0, 5) * self.sy)
        S = np.array([base[0] + rng.uniform(-3, 3) * self.sx, hs, rng.uniform(-1.5, 1.5)])
        rs = r_base * fl(hs)
        # the trunk: narrows above the roots, and rounds into the limbs over its last stretch
        sh0 = hs - 1.6 * rs
        tl = Limb([base, base + (S - base) * 0.5 + np.array([rng.uniform(-2, 2), 0, 0]), S], r_base, 1, rng.randint(0, 999), 0)
        def trunk_r(t):
            h = tl.at(t)[1]
            w = min(1.0, max(0.0, (h - sh0) / max(1e-6, hs - sh0)))
            return r_base * fl(h) * (1 - 0.3 * w * w)
        tl.r = trunk_r
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
        sides = [-1, 1]
        rng.shuffle(sides)
        heads = [(math.pi if sd < 0 else 0.0) + rng.uniform(-0.35, 0.35) for sd in sides]
        if rng.random() < 0.5:
            heads.append(-math.pi / 2 + rng.uniform(-0.4, 0.4))
        groups = {i: [] for i in range(len(heads))}
        if many:
            for pt in parts:
                if pt is top_part: continue
                ang = math.atan2(pt.z0 * 0.6, pt.x0 - S[0])
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
                el = math.radians(rng.uniform(28, 42))           # lower than before: the limbs spread wider
                d = unit(np.array([math.cos(el) * math.cos(az), math.sin(el), 0.6 * math.cos(el) * math.sin(az)]))
                end = self._fit(S, S + d * 90, lim=0.8)
            prim.append((end, groups[i], False))
        prim.append((T, [], True))
        rl = rs * math.sqrt(1.0 / len(prim)) * 1.08
        for end, grp, leader in prim:
            out = unit(np.array([end[0] - S[0], 0, end[2] - S[2]]))
            if np.linalg.norm(out) < 0.5: out = np.array([1.0, 0, 0])
            p0 = S - UP * rs * 0.7 + out * rs * 0.15            # inside the trunk's rounded top
            d0 = unit(unit(end - p0) + UP * rng.uniform(0.15, 0.35))      # a little steeper than the way to its end
            d0 = rot(d0, V, rng.uniform(-0.12, 0.12))
            L_ = float(np.linalg.norm(end - p0)) * 1.08
            lb = self.grow(limbs, p0, d0, L_, rl * (0.95 if leader else rng.uniform(0.95, 1.05)), 1,
                           target=end, steer=0.3, nf=rng.randint(2, 3) if grp else None, contain=False)
            if lb is None: continue
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
                d2 = unit(o2 + UP * 0.5)
                self.grow(limbs, q0, d2, float(np.linalg.norm(e2 - q0)) * 1.08, max(1.0, lb.r(t0) * 0.75), 2,
                          target=e2, steer=0.45, contain=False)
        return limbs
