# PR 2: the pine in flat tiers (the user on the in-game sheets, 2026-11-25: 15:04 MSK «Сосну выше, ярусов больше ...
# для средней плюс один ярус, для высокой - плюс два»; 15:22 «Ярусы еще сильнее разнести друг от друга по вертикали»;
# 15:58 «Нужны более плоские ярусы. То есть один ярус - несколько веток с зонтиками на примерно одной высоте,
# следующий ярус - тоже несколько веток на одной высоте, верхушка - тоже самое»; 17:07 «Ярусы должны быть разного
# диаметра, расстояние между ними тоже разное / Ветви должны быть вокруг ствола, не только спереди / Стволы у маленькой
# и средней тоже должны быть с рельефной корой»; 17:09 «... не видно ни на одном ракурсе, как ствол перекрывает задние
# ветви с зонтиками»).
# conifer21's pine (form 'clumps', style 'out': umbrellas of caps whose fronds grow out of the twigs' ends) is built
# here in whorls instead of its rings and top umbrella: a tier is 3-4 limbs from the trunk at one height, each ending
# in an umbrella whose 2-3 twigs spread out nearly level, the umbrellas of a tier at one height; the top is a whorl
# too, narrower. The lowest tier stands where the approved lowest ring stood (the bare trunk under the crown as
# approved); the tiers go up to the top (the thin pine's approved top umbrella, the medium and thick ones 1.6 times
# the approved gap under the top umbrella apart over the approved top ring, sheet 161 А): thin 2 tiers, medium 3,
# thick 4, the gaps between them and the reaches of the tiers under the top uneven (shuffled spreads). The pine is
# drawn with a flatter depth squash (ZS_PINE): its whorls read as flat tiers on the screen from every side. Its trunk
# is drawn over the fronds behind it (trunk_front: the render and export_pr2.frond_layer), so the whorls stand round
# it, and shows the bark's relief down to RELIEF_R (the thin and medium trunks too). install() and squash(key) before
# building a conifer (export_pr2.build does).
import math, numpy as np
import conifer21 as C, render7 as R, render16 as G, trees22 as TR, bases22 as B
from render14 import Limb, HALF, UPS, V, SPAN_LO, SPAN_HI

MORE = {0.68: 1, 1.0: 2}   # tiers over the approved two (the thin pine's) by size
STEP_K = 1.6               # the medium and thick tops: tiers this x the approved gap under the top umbrella apart
TOP_REACH = 0.5            # the top whorl's reach: the lowest approved ring's x this
GAP_SPREAD = (0.8, 1.2)    # the gaps between the tiers: these x their mean, spread evenly, shuffled (user 17:07 MSK;
                           # 0.65-1.35 merged a close pair of tiers into one clump)
REACH_SPREAD = (0.62, 1.08)  # the tiers under the top: reaches these x the lowest approved ring's, spread, shuffled
RELIEF_R = 1.5             # the trunk shows the bark's relief down to this radius (px; the other trees' limbs 3.5)
BEHIND = 1.5               # a frond whose middle is this far behind the trunk's axis (px) goes behind the trunk
TWIG_EL = (5.0, 20.0)      # an umbrella's twigs rise this many degrees: the umbrella nearly flat (was 35-60)
LEVEL_JIT = 1.0            # an umbrella's height in its tier: +- this x the size factor (px)
LIMB_DROP = (0.1, 0.3)     # a limb leaves the trunk this x its reach under its umbrella
ZS_PINE = 0.3              # the pine's depth squash on the screen (conifer21.ZS 0.45 for the others): its tiers
                           # flat (sheet 164 Б, the user's pick 16:13 MSK; 0.2 shown as А, 0.45 drew each whorl as a
                           # tall ellipse)
_ORIG = {}


def squash(key):
    """conifer21's depth squash (ZS and the view vectors made of it) for conifer `key`: the pine's own, the
    approved 0.45 for the others. Set before building a conifer; pack_pr2 reads C.ZS for its crown cells."""
    zs = ZS_PINE if key == 'pine' else _ORIG.get('zs', C.ZS)
    _ORIG.setdefault('zs', C.ZS)
    C.ZS = zs
    C.VIEW = np.array([0.0, zs, 1.0]) / math.hypot(zs, 1.0)
    C.SUP = np.array([0.0, 1.0, -zs]) / math.hypot(zs, 1.0)


def more(s):
    return MORE.get(round(float(s), 2), 0)


def _tiers(self):
    if self.form != 'clumps' or self.style != 'out':
        return _ORIG['tiers'](self)
    rng = self.crng
    h, s = self.hk_, self.size_
    reach = self.Rb0 * h * 2.0 / 1.5                    # as conifer21
    Rc = 1.3 * max(9.0, 14.0 * h) / 1.5
    FR = 11.0
    small = h <= 0.7
    top0 = self.bare + self.Hc
    apex0 = top0 - 0.55 * Rc                            # the approved top umbrella
    nr = max(1, int(round(2 * self.tiers_k * h)) - 1)
    gap0 = (C.UMB_DROP[0] + C.UMB_DROP[1] / nr) * h * 1.3 + 2.0 * h     # the approved top ring under it (mean)
    gap1 = (C.UMB_DROP[0] + C.UMB_DROP[1]) * h * 1.3 + 2.0 * h          # the approved lowest ring under it
    E = more(s)
    low = apex0 - gap1
    top_level = apex0 if not E else apex0 - gap0 + (E + 1) * STEP_K * gap0
    T = 2 + E
    w = list(np.linspace(GAP_SPREAD[0], GAP_SPREAD[1], T - 1)) if T > 2 else [1.0]
    rng.shuffle(w)                                      # (one gap or one tier under the top: no draws, the thin pine
    if T > 2: w = [x * rng.uniform(0.92, 1.08) for x in w]          # as it was)
    w = np.array(w) / sum(w)
    levels = [low] + [low + float(c) * (top_level - low) for c in np.cumsum(w)]
    under = list(np.linspace(REACH_SPREAD[0], REACH_SPREAD[1], T - 1)) if T > 2 else [1.0]
    rng.shuffle(under)
    reach_k = under + [TOP_REACH]
    dist_low = reach * 0.75                             # the approved lowest ring's reach
    out = []
    self.limb_ends, self.limb_y0, self.twigs = [], [], []
    ui = 0
    for j, level in enumerate(levels):
        dist = dist_low * reach_k[j]
        m = max(3, int(round(math.tau * dist / (C.UMB_GAP * Rc))))
        off = rng.uniform(0, math.tau)
        for i in range(m):
            a = off + math.tau * (i + rng.uniform(-0.15, 0.15)) / m
            dd = dist * rng.uniform(0.85, 1.0)
            A = np.array([dd * math.cos(a), level + rng.uniform(-LEVEL_JIT, LEVEL_JIT) * h, dd * math.sin(a)])
            self.limb_ends.append(np.array([G.BX + A[0], A[1] - 1, C.ZS * A[2]]))
            self.limb_y0.append(A[1] - dd * rng.uniform(*LIMB_DROP))
            rc = Rc * rng.uniform(0.8, 0.95)
            k = 2 if small else rng.randint(2, 3)
            toff = rng.uniform(0, math.tau)
            out_dir = C.unit(np.array([A[0], 0.0, A[2]]))
            for q in range(k):
                b = toff + math.tau * (q + rng.uniform(-0.2, 0.2)) / k
                el = math.radians(rng.uniform(*TWIG_EL))
                dvec = C.unit(np.array([math.cos(b) * math.cos(el), math.sin(el), math.sin(b) * math.cos(el)]) + 0.35 * out_dir)
                P = A + dvec * rc * rng.uniform(0.95, 1.2)
                out.append(dict(y=P[1], R=FR, d=C.OUT_DROOP, c=(P[0], P[2]), slope=60.0, deep=0.0, spokes=True,
                                n=5 if small else 6, fan=None, umbel=ui, anchor='root'))
                self.twigs.append((np.array([G.BX + A[0], A[1], C.ZS * A[2]]), np.array([G.BX + P[0], P[1] - 1, C.ZS * P[2]])))
            ui += 1
    self.whorls_ = True
    self.apex0_ = apex0
    self.apex_y = top_level
    self.trunk_top_ = top_level + 2.0 * h               # the leader's tip among the top whorl's caps
    self.top = top_level + 0.55 * Rc
    out.sort(key=lambda t: t['y'])
    return out


def _skel(self, flare):
    """conifer21.Conifer._skeleton / trees22.skeleton21 for the whorls: the trunk up to the top whorl, its width at a
    height as the approved trunk's (the taper by the height over the approved trunk's length), the twigs, and a limb
    from the trunk to each umbrella."""
    rng = self.rng
    base = np.array([G.BX, self.h0, 0.0])
    r_base = HALF * self.sx
    y_app, y_new = self.apex0_ - 1, self.trunk_top_
    top = np.array([G.BX + rng.uniform(-1, 1), y_new, 0.0])
    tl = Limb([base, base + (top - base) * 0.5, top], r_base, 0.8, rng.randint(0, 999), 0)
    L1 = y_new - self.h0
    k = L1 / (y_app - self.h0)
    tl.r = lambda t, f=flare: max(0.8, r_base * f(tl.at(t)[1]) * (1 - C.PINE_TAPER * t * k))
    limbs = [tl]
    for a_, b_ in self.twigs:
        limbs += C.crooked(a_, b_, max(0.9, 1.4 * self.hk_), 0.6, 2, rng, bends=1, amp=0.18)
    for end, y0 in zip(self.limb_ends, self.limb_y0):
        t = min(0.98, max(0.05, (y0 - self.h0) / L1))
        limbs += C.crooked(tl.at(t), end, max(1.0, tl.r(t) * 0.6), 0.8, 1, rng, bends=2, amp=0.16, rise=0.2)
    return limbs


def _wood(t):
    """The sun-free part of bases22.Based._draw_skeleton (render16.Tree.draw_trunk's part 2) for the pine: per pixel
    the nearest disc's depth, limb, normal, point and bark step (the trunk's relief down to RELIEF_R); once per turn
    (a turn sets new limbs)."""
    c = getattr(t, '_wood_c', None)
    if c is not None and c[0] is t.limbs: return c[1]
    H, W = t.H, t.W
    zb = np.full((H, W), -1e9); jb = np.full((H, W), -1, int); rel = np.zeros((H, W), int)
    nb = np.zeros((H, W, 3)); pts = np.zeros((H, W, 3))
    texs = {}
    for p, r, tan, l, j in t._samples():
        lb = t.limbs[j]
        sx, sy = t.proj_abs(p)
        ts = np.array([tan[0], tan[2] - tan[1]]); nt = np.linalg.norm(ts)
        perp = np.array([-ts[1], ts[0]]) / nt if nt > 1e-3 else np.array([1.0, 0.0])
        ri = int(math.ceil(r)) + 1
        ys, xs = np.mgrid[-ri:ri + 1, -ri:ri + 1]
        fx, fy = xs + (round(sx) - sx), ys + (round(sy) - sy)
        ok = fx * fx + fy * fy <= r * r + 0.3
        s = np.clip((fx * perp[0] + fy * perp[1]) / max(r, 0.5), -1, 1)
        pw = perp[0] * np.array([1.0, 0, 0]) + perp[1] * UPS
        vp = V - tan * float(V @ tan); vp = vp / max(1e-6, np.linalg.norm(vp))
        nrm = s[..., None] * pw + np.sqrt(np.maximum(0, 1 - s * s))[..., None] * vp
        depth = (p @ V) + r * (nrm @ V)
        Y, X = ys + int(round(sy)), xs + int(round(sx))
        k = ok & (Y >= 0) & (Y < H) & (X >= 0) & (X < W) & (depth > zb[np.clip(Y, 0, H - 1), np.clip(X, 0, W - 1)])
        if not np.any(k): continue
        if r >= 3.5 or (j == 0 and r >= RELIEF_R):
            if j not in texs: texs[j] = t._bark_tex(lb.seed if j else 7, 400)
            tex = texs[j]
            col = np.clip(np.round(R.TC + s[k] * HALF).astype(int), SPAN_LO, SPAN_HI)
            row = min(len(tex) - 1, int(l))
            rel_ = tex[row][col]
            rel_ = np.where(rel_ < -50, 2, rel_)
        else:
            rel_ = np.where(np.abs(s[k]) > 0.8, 2, 3)
            if r < 1.6: rel_ = np.full(rel_.shape, 3)
        if r >= 1.6: rel_ = np.where(np.abs(s[k]) > 0.86, rel_ - 1, rel_)
        zb[Y[k], X[k]] = depth[k]; jb[Y[k], X[k]] = j; rel[Y[k], X[k]] = rel_
        nb[Y[k], X[k]] = nrm[k]; pts[Y[k], X[k]] = p + r * nrm[k]
    has = zb > -1e8
    near = np.zeros_like(has)
    for dy_, dx_ in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        zn = np.roll(np.roll(zb, dy_, 0), dx_, 1)
        near |= has & (zn > zb + 2.5)
    rel[near] -= 1
    has[t.oy - t.h0 + 1:, :] = False                    # the foot owns its rows
    w = dict(has=has, jb=jb, rel=rel, nb=nb, pts=pts)
    t._wood_c = (t.limbs, w)
    return w


def _draw_skel(t, img):
    """Based._draw_skeleton for the pine: _wood lit by t.L, the crown's shade; the picture kept for trunk_front."""
    w = _wood(t)
    L = t.L
    yy, xx = np.nonzero(w['has'])
    d = w['nb'][yy, xx] @ L
    v = w['rel'][yy, xx] + np.where(d > -0.05, 0, np.where(d > -0.36, -1, -2))
    if t.crown and L[1] > 0.1:
        v = v - np.where(t._crown_shade_px(w['pts'][yy, xx]), 1, 0)
    img[yy, xx] = np.array(t.bark)[np.clip(v, 0, 3)]
    t._wood_img = img.copy()


def _owner(t):
    """The frond on top at each pixel (the render's order, -1: none) and whether each frond (and -1) lies behind the
    trunk's axis; once per turn."""
    c = getattr(t, '_own_c', None)
    if c is not None and c[0] is t.mods: return c[1]
    H, W = t.H, t.W
    owner = np.full((H, W), -1, int)
    for j, (p, n, mod) in enumerate(t.mods):
        f = mod['frond']; X0, Y0 = mod['org']
        ys, xs = np.nonzero(f.role >= 0)
        Y, X = ys + Y0, xs + X0
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        owner[Y[ok], X[ok]] = j
    back = np.array([m['ctr'][2] < -BEHIND for _, _, m in t.mods] + [False])
    t._own_c = (t.mods, (owner, back))
    return owner, back


def trunk_front(t):
    """The pixels where the pine's trunk is drawn over its fronds: the trunk is the nearest wood there and the frond
    on top lies behind the trunk's axis (the whorls stand round the trunk, user 2026-11-25 17:09 MSK)."""
    if not getattr(t, 'whorls_', False): return np.zeros((t.H, t.W), bool)
    w = _wood(t)
    owner, back = _owner(t)
    return w['has'] & (w['jb'] == 0) & back[owner]


def install():
    if 'tiers' in _ORIG: return
    _ORIG['tiers'] = C.Conifer._tiers
    C.Conifer._tiers = _tiers
    _ORIG['sk'] = C.Conifer._skeleton

    def sk(self):
        if not getattr(self, 'whorls_', False): return _ORIG['sk'](self)
        lo_ = C.PINE_FLARE
        return _skel(self, lambda hh: lo_ + (1 - lo_) * math.exp(-max(0.0, hh - self.h0) / (12.0 * self.sy)))
    C.Conifer._skeleton = sk
    _ORIG['sk21'] = TR.skeleton21

    def sk21(self):
        if not getattr(self, 'whorls_', False): return _ORIG['sk21'](self)
        return _skel(self, self._flare())
    TR.skeleton21 = sk21
    _ORIG['dskel'] = B.Based._draw_skeleton

    def dskel(self, img):
        if not getattr(self, 'whorls_', False): return _ORIG['dskel'](self, img)
        return _draw_skel(self, img)
    B.Based._draw_skeleton = dskel
    _ORIG['render'] = TR.CTree.render

    def render(self, **kw):
        img = _ORIG['render'](self, **kw)
        if getattr(self, 'whorls_', False) and self.crown and kw.get('with_trunk', True):
            f = trunk_front(self)
            img[f] = self._wood_img[f]
        return img
    TR.CTree.render = render
