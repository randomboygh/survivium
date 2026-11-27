# Round 24: conifer21's fronds in two halves, so a camera turn can re-pick each branch's frond (the fronds are chosen by
# the branch's direction on the screen) from the same 3D branches: _geometry (where the branches are, 3D) and _pick
# (which frond, where on the screen, the pine's ball light, the paint order). The noise of the frond choice comes from the
# same random state at every turn, so a branch keeps its frond where its direction on the screen stays.
import math, copy, numpy as np
import conifer21 as C, render16 as G, turn24 as TU
from conifer21 import FRONDS, SPOKE_LEN, UP, unit


def _geometry(self):
    rng = self.crng
    mods = []
    for k, t in enumerate(self.tiers):
        Rk = t['R']
        a, b = Rk, C.ZS * Rk
        per = math.pi * (3 * (a + b) - math.sqrt(max(0.0, (3 * a + b) * (a + 3 * b))))
        rings = [(1.0, 0.0)]
        if self.inner and not t.get('spokes'):   # wide tiers: inner rings fill the gaps (deeper: -1)
            if Rk > 24: rings.append((0.6, -1.0))
            if Rk > 50: rings.append((0.32, -1.0))
        for rf, deep in rings:
            n = t['n'] if t.get('spokes') else max(3, int(round(per * rf / self.spacing)))
            off = rng.uniform(0, math.tau)
            for i in range(n):
                if t.get('fan') is not None:          # a twig's cap: its fronds fan out away from the umbrella
                    a0, hw = t['fan']
                    ph = a0 + hw * (2 * (i + 0.5) / n - 1) + rng.uniform(-0.15, 0.15)
                else:
                    ph = off + math.tau * (i + rng.uniform(-0.25, 0.25)) / n
                L_ = Rk * rf * rng.uniform(0.85, 1.05)
                root = np.array([t['c'][0], t['y'] + rng.uniform(-1, 1), t['c'][1]])
                tip = root + np.array([L_ * math.cos(ph), -t['d'] * L_, L_ * math.sin(ph)])
                mods.append(dict(root=root, tip=tip, tier=k, deep=deep + t['deep'], top=False, slope=t['slope'],
                                 axis=np.array([t['c'][0], 0.0, t['c'][1]]), spoke=bool(t.get('spokes')),
                                 umbel=t.get('umbel'), anchor=t.get('anchor', 'tip'), R=Rk * rf))
    if self.form == 'cone':      # the leader: one frond pointing up at the top
        mods.append(dict(root=np.array([0.0, self.top - 15, 0.0]), tip=np.array([0.0, self.top, 0.0]),
                         tier=len(self.tiers), deep=0.0, top=True, slope=90.0, axis=np.zeros(3)))
    return mods


def _pick(self, mods):
    rng = self.crng
    # pick a frond for each branch
    last = None
    for m in mods:
        a_s, b_s = self.scr(m['root']), self.scr(m['tip'])
        v = b_s - a_s
        ln = float(np.linalg.norm(v))
        ang = math.degrees(math.atan2(-v[1], v[0])) if ln > 1e-6 else 90.0
        if m.get('anchor') == 'root': want = SPOKE_LEN
        else: want = min(24.0, max(13.0 if m.get('spoke') else self.min_len, ln * 0.95))
        best = None
        for j, f in enumerate(FRONDS):
            if m['top']:
                c = abs((f.angle - 90 + 180) % 360 - 180) / 10.0 + rng.uniform(0, 0.3)
            else:
                da = abs((f.angle - ang + 180) % 360 - 180)
                c = da / 18.0 + abs(f.length - want) / 4.0 + rng.uniform(0, 0.8)
                if last is not None and f.i == last: c += 1.5
                if f.i in (1, 16): c += 0.8           # the round end-on fronds: fewer
                if m.get('spoke') and f.i in (1, 7, 16): c += 3.0     # a pine's tuft: long fronds that spread
            if best is None or c < best[0]: best = (c, j)
        m['frond'] = FRONDS[best[1]]; last = m['frond'].i
        f = m['frond']
        # a frond much longer than its branch (a narrow top's) would reach back past the trunk, its shaded root
        # sticking out on the far side as a dark hook: it grows out of the trunk instead, like 124's top
        if not m['top'] and not m.get('spoke') and m.get('R', 99.0) < 0.75 * f.length: m['anchor'] = 'root'
        if m.get('anchor') == 'root':     # a frond growing out of its twig's end: its root there
            m['org'] = (int(round(a_s[0] - f.root[0])), int(round(a_s[1] - f.root[1])))
        else:                  # a cone's frond ends at its branch's tip
            m['org'] = (int(round(b_s[0] - f.tip[0])), int(round(b_s[1] - f.tip[1])))
        m['dir'] = unit(m['tip'] - m['root'])
        ctr = m['root'] + (m['tip'] - m['root']) * 0.65
        m['depth'] = float(ctr[1] + ctr[2] * C.ZS)
        m['ctr'] = ctr
    # a pine's umbrella is lit as a ball (a dome): each pixel by its place in the ellipse the umbrella's fronds
    # cover on the screen (a frond's own normal lit the fronds of one cap against each other)
    caps = {}
    for m in mods:
        if m.get('umbel') is None: continue
        f = m['frond']
        X0, Y0 = m['org']
        ys, xs = np.nonzero(f.role >= 0)
        caps.setdefault(m['umbel'], []).append((xs + X0, ys + Y0))
    balls = {}
    for c, pts in caps.items():
        xs = np.concatenate([q[0] for q in pts]); ys = np.concatenate([q[1] for q in pts])
        balls[c] = ((xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2,
                    (xs.max() - xs.min()) / 2 + 1, (ys.max() - ys.min()) / 2 + 1)
    for m in mods:
        if m.get('umbel') is not None: m['ball'] = balls[m['umbel']]
    mods.sort(key=lambda m: m['depth'])
    return [(m['ctr'], UP, m) for m in mods]          # render7.Tree.render loops over (p, n, mod)


def _fronds(self):
    mods = _geometry(self)
    self._geom = copy.deepcopy(mods)
    self._rstate = self.crng.getstate()
    return _pick(self, mods)

C.Conifer._fronds = _fronds


def snapshot(t):
    return dict(geom=copy.deepcopy(t._geom), rstate=t._rstate, limbs=list(t.limbs), inside=t.inside)


def turn(t, n, snap, deg=None):
    """Conifer t seen from camera turn n: its 3D branches turned about the trunk, fronds re-picked; limbs and the
    crown's shape (squashed frame, C.ZS) turned as turn24 does."""
    a = math.radians(45.0 * n if deg is None else deg)
    c, s = math.cos(a), math.sin(a)
    bx = G.BX
    def rot3(p):
        x, z = p[0] - bx, p[2]
        return np.array([bx + c * x - s * z, p[1], s * x + c * z])
    mods = copy.deepcopy(snap['geom'])
    if n or deg is not None:
        for m in mods:
            for k_ in ('root', 'tip', 'axis'):
                if k_ in m: m[k_] = rot3(m[k_])
    t.crng.setstate(snap['rstate'])
    t.mods = _pick(t, mods)
    zs = C.ZS
    pos, nrm, back = TU.maps(n, zs, zs, deg=deg)
    ident = n == 0 and deg is None
    t.limbs = list(snap['limbs']) if ident else [TU.XLimb(lb, pos) for lb in snap['limbs']]
    inside = snap['inside']
    def inside_t(x, y, z, k=1.0, lim=1.0):
        x0, y0, z0 = back(x, y, z)
        return inside(x0, y0, z0, k, lim)
    t.inside = inside_t
    t._cover = None
    t._tones = {}
    return t
