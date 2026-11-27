# Round 22: the approved trees (round 19 species, round 21 conifers) standing on any of the three trunk feet of
# bases22. skeleton17 / skeleton21 are render17.Tree._skeleton and conifer21.Conifer._skeleton copied with one
# change: the trunk's flare over the foot comes from the base (Based._flare); base '122' calls the originals.
import math, random, numpy as np
import render7 as R, render16 as G, render17 as T, tree123 as TT, species19 as SP, conifer21 as C
from render14 import Limb, HALF
from render17 import unit, rot, UP, V
from conifer21 import crooked, PINE_FLARE, PINE_TAPER
from bases22 import Based, BASES, KEYS, foot_for

def skeleton17(self):
    rng = self.rng
    base = np.array([G.BX, self.h0, 0.0])
    r_base = HALF * self.sx
    parts = self.parts
    many = len(parts) > 1
    lo, hi = self.yrange()
    c_lo, c_hi = lo + self.cy, hi + self.cy
    fl = self._flare()
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


def skeleton21(self):
    rng = self.rng
    base = np.array([G.BX, self.h0, 0.0])
    r_base = HALF * self.sx
    top = np.array([G.BX + rng.uniform(-1, 1), self.top - 14 if self.form == 'cone' else self.apex_y - 1, 0.0])
    tl = Limb([base, base + (top - base) * 0.5, top], r_base, 0.8, rng.randint(0, 999), 0)
    # the pine's trunk is straighter (user 2026-11-24 13:29 MSK: a little narrower at the foot, a little wider
    # toward its end): a smaller flare over the roots and less taper
    lo_ = 0.62 if self.form == 'cone' else PINE_FLARE
    flare = self._flare()
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


class DTree(Based, TT.Tree):
    def __init__(self, sun, base='122', q=None, **kw):
        self.base, self.q = base, q
        super().__init__(sun, **kw)

    def _skeleton(self):
        if self.base == '122': return super()._skeleton()
        return skeleton17(self)


class CTree(Based, C.Conifer):
    def __init__(self, key, base='122', q=None, **kw):
        self.base, self.q = base, q
        super().__init__(key, **kw)

    def flare_lo(self):
        return 0.62 if self.form == 'cone' else PINE_FLARE

    def flare_len(self):
        return 12.0

    def _skeleton(self):
        if self.base == '122': return super()._skeleton()
        return skeleton21(self)


def tree(key, s, base=None, warp=11, sun=R.SUN_R, W=320, H=400, **extra):
    """species19.tree on a base (None = by size, the user's rule: foot_for(s))."""
    base = base or foot_for(s)
    SP.register()
    label, shape, ck, bk, wk, leaves, tints, bark, bare = SP.SPEC[key]
    G.WIDTH = 0.8 * wk
    kw = dict(k=1.3, tint=R.species_tint(*tints), d1=0.64, d2=0.36, dp=0.8, shade_flat='quarter', W=W, H=H,
              bark=SP.bark_ramp(bark))
    kw.update(extra)
    try:
        t = DTree(sun, base=base, leaves=leaves or '122', species=key, s=s, warp=warp, crown=not bare, **kw)
    finally:
        G.WIDTH = 0.8
    return t

def conifer(key, s, base=None, **kw):
    return CTree(key, base=base or foot_for(s), s=s, **kw)

def any_tree(key, s, base=None, **kw):
    return conifer(key, s, base, **kw) if key in C.CSPEC else tree(key, s, base, **kw)
