# Round 24: camera turns for the willow (willow22: its own module order) and the palms (palmtree22: true 3D drawn with
# ZS 0.9). The broadleaf trees turn with turn24, the conifers with conifer24.
import math, copy, numpy as np
import turn24 as TU, render16 as G


# ------------------------------------------------ willow
def willow_snapshot(t):
    return dict(mods=list(t.mods), ring=list(t.ring), limbs=list(t.limbs), inside=t.inside, part=t.parts[0])

def willow_turn(t, n, snap, zs_in=TU.ZSQ, zs_out=None):
    """willow22's order (back to front by depth in the bell, an upper ring over a lower one) rebuilt per view."""
    zs_out = zs_in if zs_out is None else zs_out
    pos, nrm, back = TU.maps(n, zs_in, zs_out)
    pt = snap['part']
    items = []
    for (p, nv, mod), rk in zip(snap['mods'], snap['ring']):
        q = pos(p)
        cx, cz = pt.axis(p[1] - pt.y0) if hasattr(pt, 'axis') else (pt.x0, pt.z0)
        cz2 = pos(np.array([cx, p[1], cz]))[2]
        zrel = (q[2] - cz2) / max(1e-6, pt.rz * zs_out / zs_in)
        items.append((zrel + 0.15 * rk, rk, zrel, (q, nrm(nv), mod)))
    items.sort(key=lambda it: it[0])
    t.mods = [it[3] for it in items]
    t.ring = [it[1] for it in items]
    t.zrel = [it[2] for it in items]
    inside = snap['inside']
    def inside_t(x, y, z, k=1.0, lim=1.0):
        x0, y0, z0 = back(x, y, z)
        return inside(x0, y0, z0, k, lim)
    t.inside = inside_t
    t.limbs = list(snap['limbs']) if n == 0 and zs_out == zs_in else [TU.XLimb(lb, pos) for lb in snap['limbs']]
    t._tones = {}; t._core = None; t._voidl = None
    return t


# ------------------------------------------------ palms
_PATCHED = {}

def _patch_trunk():
    import palmtree22 as PT
    if _PATCHED: return
    orig = PT.Trunk.samples
    def samples(self, step=0.25):
        a = getattr(self, 'turn_a', 0.0)
        if not a: return orig(self, step)
        ph = self.phase
        Pp, N, u, v, tg, n_around = orig(self, step)
        # u was th / 2pi x n + phase with th the view's azimuth: the world's is th - a
        u = u - a / (2 * math.pi) * n_around
        return Pp, N, u, v, tg, n_around
    PT.Trunk.samples = samples
    _PATCHED['v'] = True

def palm_snapshot(p):
    _patch_trunk()
    return dict(phis=[lf.phi for lf in p.leaves], lean=tuple(p.trunk.lean))

def palm_turn(p, n, snap):
    """Leaves' azimuths (0 right, 90 away, 270 toward the viewer) turn by -45 n, the trunk's lean turns, its scales turn
    with it; then the crown is rebuilt about the turned trunk's top."""
    import palmtree22 as PT, palm22 as P
    _patch_trunk()
    a = math.radians(45.0 * n)
    c, s = math.cos(a), math.sin(a)
    for lf, phi in zip(p.leaves, snap['phis']):
        lf.phi = (phi - 45.0 * n) % 360
    lx, lz = snap['lean']
    p.trunk.lean = (c * lx - s * lz, s * lx + c * lz)
    p.trunk.turn_a = a
    p.crown = P.Crown(p.leaves, W=p.W, H=p.H, ox=p.ox, oy=p.oy, C=p.trunk.top(), zs=PT.ZS)
    return p
