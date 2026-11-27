# Round 24 (trees fixed in the world, user's pick Б 2026-11-24 22:16 MSK): a tree is a 3D thing that stands in the
# world; the camera's turns (n x 45 deg, PixelView.view_of: right = (cos a, -sin a), toward the camera = (sin a, cos a))
# show its other sides, and the sun turns with the view (lit sides and shadows stay put on the screen).
#
# How the approved mockups are drawn: every tree is drawn in a "squashed frame", its depth toward the camera squashed
# (broadleaf crowns rz ~ 0.55 rx, limbs' fork directions z x 0.6, conifer tiers ZS 0.45, palms 0.9, stump faces 0.6).
# Read as 3D, the approved tree = the squashed-frame tree with its z divided by the squash. So a turn is
#     p' = S_out . Rot(n) . S_in^-1 . p        (positions, about the trunk's axis x = BX, z = 0)
#     n' ~ S_out^-1 . Rot(n) . S_in . n        (normals: the inverse transpose)
# with S = diag(1, 1, zs). zs_out = zs_in: the tree drawn as approved from every side ("approved depth"); zs_out = 1:
# the tree drawn exactly as the game's camera sees a 3D body (screen y = z - y; crowns and tiers come out taller).
# The paint order is rebuilt per view as the mockup builds it (parts by y0 + z0', rings bottom to top, a ring by z').
import math, numpy as np
import render7 as R, render12 as R12, render16 as G

ZSQ = 0.55          # the broadleaf crowns' squash (rz / rx of render7's shapes: 0.545 .. 0.58)


class XLimb:
    """A limb seen from another view: its points mapped by f; radius as it was."""
    def __init__(self, lb, f):
        self.lb, self.f = lb, f
        self.seed, self.level = lb.seed, getattr(lb, 'level', 0)
        self._len = None
    def at(self, t): return self.f(self.lb.at(t))
    def r(self, t): return self.lb.r(t)
    def length(self):
        if self._len is None:
            pts = [self.at(t) for t in np.linspace(0, 1, 40)]
            self._len = float(sum(np.linalg.norm(b - a) for a, b in zip(pts, pts[1:])))
        return self._len


def maps(n, zs_in, zs_out, bx=None, deg=None):
    """(pos, nrm, back) for camera turn n: pos/nrm map the approved frame to the view's frame, back maps arrays of the
    view's frame back to the approved frame (for the crown's inside test)."""
    bx = G.BX if bx is None else bx
    a = math.radians(45.0 * n if deg is None else deg)
    c, s = math.cos(a), math.sin(a)
    def pos(p):
        x, z = p[0] - bx, p[2] / zs_in
        return np.array([bx + c * x - s * z, p[1], (s * x + c * z) * zs_out])
    def nrm(v):
        x, y, z = v[0], v[1], v[2] * zs_in
        w = np.array([c * x - s * z, y, (s * x + c * z) / zs_out])
        return w / max(1e-9, float(np.linalg.norm(w)))
    def back(x, y, z):
        xx, zz = x - bx, z / zs_out
        return c * xx + s * zz + bx, y, (-s * xx + c * zz) * zs_in
    return pos, nrm, back


def snapshot(t):
    """What a turn needs of the tree as built (turn 0)."""
    return dict(mods=list(t.mods), groups=list(getattr(t, '_groups', [(None, 0)] * len(t.mods))),
                limbs=list(t.limbs), inside=t.inside, parts=list(t.parts))


def turn(t, n, snap, zs_in=ZSQ, zs_out=None, deg=None):
    """Set the broadleaf tree t to camera turn n (0..7) from its snapshot."""
    zs_out = zs_in if zs_out is None else zs_out
    pos, nrm, back = maps(n, zs_in, zs_out, deg=deg)
    inside = snap['inside']
    def inside_t(x, y, z, k=1.0, lim=1.0):
        x0, y0, z0 = back(x, y, z)
        return inside(x0, y0, z0, k, lim)
    t.inside = inside_t
    ident = (n == 0 and deg is None and zs_out == zs_in)
    t.limbs = list(snap['limbs']) if ident else [XLimb(lb, pos) for lb in snap['limbs']]
    pz = {}
    for p in snap['parts']:
        pz[id(p)] = float(pos(np.array([p.x0, 0.0, p.z0]))[2])
    items = []
    for i, ((p, nv, mod), (part, k_)) in enumerate(zip(snap['mods'], snap['groups'])):
        q = pos(p)
        key = (part.y0 + pz[id(part)], id(part), k_, q[2]) if part is not None else (q[2], 0, 0, 0)
        items.append((key, i, (q, nrm(nv), mod)))
    items.sort(key=lambda it: (it[0], it[1]))
    t.mods = [m for _, _, m in items]
    t._tones = {}
    for a in ('_cover', '_shadow_cache'):
        if hasattr(t, a): setattr(t, a, None)
    return t


# ------------------------------------------------ _place recording each module's part and ring (export0b's patch)
def _place(self, step, hstep):
    """render12.Tree._place as it is, also recording each module's part and ring (self._groups)."""
    import random
    rng = random.Random(self.seed)
    jr = random.Random((self.warp_seed or 0) * 7919 + 3)
    mods = []
    self._groups = []
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
            tt = float(part.t_of(y))
            ring = []
            for i in range(n):
                th = off + math.tau * i / n
                w = float(part.wf(th, tt)) if n > 1 else 1.0
                rr = 0.0 if n == 1 else w
                dy = jr.uniform(-self.jy, self.jy) if (n > 1 and self.jy) else 0.0
                p = np.array([cx + rr * a0 * math.cos(th), part.y0 + y + dy, cz + rr * b0 * math.sin(th)])
                ring.append((p, part.normal(u, th)))
            ring.sort(key=lambda q: q[0][2])
            mods += ring
            self._groups += [(part, k_)] * len(ring)
            if part.mode != 'phi' and n == 1 and u > 0.5:
                break
    self.mods = [(p, n, R.MODS[(i * 5 + self.seed) % len(R.MODS)]) for i, (p, n) in enumerate(mods)]
    self._tones = {}

R12.Tree._place = _place
