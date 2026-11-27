# Round 24: crowns and limbs that are full from every side (the user's pick Б, 2026-11-24 22:16 MSK).
# Read as 3D (z / 0.55, turn24), the approved single-part crowns are already round (rz = 0.55 rx in the squashed frame);
# what was drawn for one view only:
#   - the lobed crowns: the oak's four caps sit left and right (3D azimuths 49, 130, 200, 340 deg): seen from the back
#     the crown has a 140 deg hole -> one more cap there ('lobed3d'); the maple's / ceiba's caps apart leave 118 deg
#     empty at the back left -> one more cap ('lobed2_3d');
#   - the limbs: the main limbs go left and right (and sometimes back): now 2-3 main limbs at azimuths all round, the
#     caps of a lobed crown fed by the limb of their sector (3D azimuth, not the screen's).
# Everything else (sizes, heights, leaves, light, trunks, feet) is the approved round 19-23 tree.
import math, numpy as np
import render7 as R, render16 as G, render17 as T, species19 as SP, trees22 as TR
from render7 import Part, hemi
from render14 import Limb, HALF
from render17 import unit, rot, UP, V
import turn24 as TU

ZSQ = TU.ZSQ

R.shape('lobed3d', 'шапки со всех сторон (дуб)',
        [Part(hemi(15), 19, 11, x0=-25, z0=-5, y0=8, mode='phi', hc=15),
         Part(hemi(15), 19, 11, x0=25, z0=-5, y0=8, mode='phi', hc=15),
         Part(hemi(14), 20, 11, x0=-15, z0=10, y0=0, mode='phi', hc=14),
         Part(hemi(14), 20, 11, x0=16, z0=10, y0=0, mode='phi', hc=14),
         Part(hemi(15), 19, 11, x0=1, z0=-13.5, y0=5, mode='phi', hc=15),       # new: the back (3D 25 px behind)
         Part(hemi(16), 21, 12, x0=1, z0=-2, y0=22, mode='phi', hc=16)], 42)

R.shape('lobed2_3d', 'шапки врозь со всех сторон',
        [Part(hemi(17), 22, 12, x0=-6, z0=-4, y0=22, mode='phi', hc=17),
         Part(hemi(13), 17, 10, x0=38, z0=-2, y0=10, mode='phi', hc=13),
         Part(hemi(10), 12, 7, x0=-42, z0=-6, y0=8, mode='phi', hc=10),
         Part(hemi(11), 15, 8, x0=-22, z0=13, y0=-2, mode='phi', hc=11),
         Part(hemi(9), 11, 6, x0=22, z0=13, y0=-6, mode='phi', hc=9),
         Part(hemi(11), 15, 8, x0=-9, z0=-17, y0=12, mode='phi', hc=11),        # new: the back left
         Part(hemi(8), 10, 6, x0=20, z0=-12, y0=38, mode='phi', hc=8)], 46)

SHAPE3D = {'lobed': 'lobed3d', 'lobed2': 'lobed2_3d'}


def az3(x, z, cx=0.0, cz=0.0):
    """3D azimuth of a squashed-frame point about (cx, cz)."""
    return math.atan2((z - cz) / ZSQ, x - cx)


def skeleton24(self):
    """trees22.skeleton17 (render17's limbs on the round-22 feet) with the main limbs all round: 2 or 3 heads at even
    3D azimuths from a random start (was: left, right and sometimes back); a lobed crown's caps go to the head nearest
    their 3D azimuth."""
    rng = self.rng
    base = np.array([G.BX, self.h0, 0.0])
    r_base = HALF * self.sx
    parts = self.parts
    many = len(parts) > 1
    lo, hi = self.yrange()
    c_lo, c_hi = lo + self.cy, hi + self.cy
    if getattr(self, 'base', '122') != '122':
        fl = self._flare()
    else:
        fl = lambda h: 0.55 + 0.45 * math.exp(-max(0.0, h - self.h0) / (14.0 * self.sy))
    if many:
        far_ = max(parts, key=lambda p: math.hypot(p.x0 - G.BX, p.z0 / ZSQ))
        f_foot = far_.y0 + far_.ytab[0] + self.cy
        hs = f_foot - math.tan(math.radians(rng.uniform(26, 36))) * math.hypot(far_.x0 - G.BX, far_.z0)
        hs = max(self.h0 + 8 * self.sy, min(c_lo + rng.uniform(0, 5) * self.sy, hs))
    else:
        hs = max(self.h0 + 8 * self.sy, c_lo + rng.uniform(0, 5) * self.sy)
    S = np.array([base[0] + rng.uniform(-3, 3) * self.sx, hs, rng.uniform(-1.5, 1.5)])
    rs = r_base * fl(hs)
    sh0 = hs - 1.6 * rs
    tl = Limb([base, base + (S - base) * 0.5 + np.array([rng.uniform(-2, 2), 0, 0]), S], r_base, 1, rng.randint(0, 999), 0)
    def trunk_r(t):
        h = tl.at(t)[1]
        w = min(1.0, max(0.0, (h - sh0) / max(1e-6, hs - sh0)))
        return r_base * fl(h) * (1 - 0.3 * w * w)
    tl.r = trunk_r
    limbs = [tl]
    if many:
        top_part = max(parts, key=lambda p: p.y0 + p.ytab[-1])
        tx, tz = top_part.axis(top_part.ytab[-1] * 0.4)
        Tp = np.array([tx, top_part.y0 + self.cy + top_part.ytab[0] + (top_part.ytab[-1] - top_part.ytab[0]) * 0.5, tz])
    else:
        pt = parts[0]
        Tp = np.array([pt.axis(0)[0] + rng.uniform(-4, 4), c_lo + (c_hi - c_lo) * 0.8, pt.axis(0)[1]])
    Tp = self._fit(S, Tp)
    k = 3 if rng.random() < 0.6 else 2
    off = rng.uniform(0, math.tau)
    heads = [off + math.tau * i / k + rng.uniform(-0.3, 0.3) for i in range(k)]
    groups = {i: [] for i in range(len(heads))}
    if many:
        for pt in parts:
            if pt is top_part: continue
            ang = az3(pt.x0, pt.z0, S[0], S[2])
            i = min(range(len(heads)), key=lambda j: abs(math.remainder(ang - heads[j], math.tau)))
            groups[i].append(pt)
    prim = []
    for i, az in enumerate(heads):
        if many and not groups[i]: continue
        if many:
            far = max(groups[i], key=lambda p: math.hypot(p.x0 - S[0], (p.z0 - S[2]) / ZSQ))
            foot, top = self._cap_info(far)
            ex, ez = far.axis((far.ytab[-1] - far.ytab[0]) * 0.3 + far.ytab[0])
            end = np.array([ex, foot + (top - foot) * 0.35, ez])
        else:
            el = math.radians(rng.uniform(28, 42))
            d = unit(np.array([math.cos(el) * math.cos(az), math.sin(el), ZSQ * math.cos(el) * math.sin(az)]))
            end = self._fit(S, S + d * 90, lim=0.8)
        prim.append((end, groups[i], False))
    prim.append((Tp, [], True))
    rl = rs * math.sqrt(1.0 / len(prim)) * 1.08
    for end, grp, leader in prim:
        out = unit(np.array([end[0] - S[0], 0, end[2] - S[2]]))
        if np.linalg.norm(out) < 0.5: out = np.array([1.0, 0, 0])
        p0 = S - UP * rs * 0.7 + out * rs * 0.15
        d0 = unit(unit(end - p0) + UP * rng.uniform(0.15, 0.35))
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


_ON = {'v': False}
_ORIG = {}

def use3d(on=True):
    """Switch the broadleaf builder (trees22.tree) to the round-24 crowns and limbs (on) or back to the approved."""
    if not _ORIG:
        _ORIG['spec'] = dict(SP.SPEC)
        _ORIG['sk17'] = TR.skeleton17
        _ORIG['r17'] = T.Tree._skeleton
    if on:
        for k, v in _ORIG['spec'].items():
            if v[1] in SHAPE3D: SP.SPEC[k] = v[:1] + (SHAPE3D[v[1]],) + v[2:]
        TR.skeleton17 = skeleton24
        T.Tree._skeleton = skeleton24
    else:
        SP.SPEC.clear(); SP.SPEC.update(_ORIG['spec'])
        TR.skeleton17 = _ORIG['sk17']
        T.Tree._skeleton = _ORIG['r17']
    _ON['v'] = on
