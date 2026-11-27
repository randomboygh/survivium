# Round 25 (user 2026-11-24 23:47 MSK «корни у пней (и деревьев) тоже нужно поворачивать»): trunk feet whose roots
# turn with the camera, for the trees and the stumps of round 24 (mockup, no game code).
#
# The approved feet (round 22, bases22) are 2D pictures cut from the references, the same at every camera turn. Here a
# foot is split in two:
#   - the body: the trunk's lowest part with its rounded bottom (the base seen from above), round, so the same from every
#     side: kept as the approved picture (its bark view-locked like the trunk's above it). For '122' it is the
#     reference's own drawing stage before the roots were added (render7.ST[2]); for '124' the cut with its root stubs
#     and its tap root taken off; '123' (a barrel, no roots) stays as it is;
#   - the roots: 3D tubes in the foot's own frame (unsquashed: x right, y up from the ground, z toward the camera at
#     turn 0, the trunk's axis at x = z = 0), placed so that at turn 0 they lie where the reference drew its roots
#     (122: the front root splitting in two on the ground, the left one in the trunk's shadow, the right one; 124: the
#     two side stubs and the lit tap root in front), plus roots at the back hidden by the trunk at turn 0, so that every
#     side shows about as many roots. A turn adds the turn's angle to every root's azimuth (turn24's convention).
# Each foot keeps the squash its reference drew it with (variant А, as the crowns: the base's oval, 122 ~0.31,
# 124 ~0.53): screen col = centre + x, row = yc + zs z - y (block units, then scaled like the approved block).
# The roots are drawn with z-buffer against the body's front surface, lit by the game sun from their own normals with
# the trees' light steps (render7.trunk_band), in the trunk's cast shadow a step darker, their relief 3 on top and 2 at
# the rims (the reference's roots), the trees' outline rule (a pixel behind a nearer edge one step darker).
import math, random, numpy as np
import render7 as R, render16 as G, bases22 as B

def unit(v):
    v = np.asarray(v, float); n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-9)


class Root:
    """One root at turn 0: azimuth a (deg; 0 right, 90 toward the camera), it leaves the trunk at height hs, reaches out
    `out` past the trunk's surface on the ground and sinks there; radius r0 at the trunk, r1 at its tip; bend = sideways
    offset of the tip (px, toward larger azimuths); kind 'knob' = a short stub sticking out level (a burl)."""
    def __init__(self, a, hs, out, r0, r1, bend=0.0, sink=0.6, k=1.3, seed=1, kind='root', mid=0.5, rise=0.0, cp=None):
        self.a, self.hs, self.out, self.r0, self.r1 = a, hs, out, r0, r1
        self.bend, self.sink, self.k, self.seed, self.kind, self.mid, self.rise = bend, sink, k, seed, kind, mid, rise
        self.cp = cp                     # explicit control points (radial distance past the trunk's surface, height, sideways)

    def path(self, rb):
        """Control points (radial distance, height, sideways) of the centre line; rb = the trunk's radius."""
        if self.cp is not None:
            return [(rb + d, y, sd) for d, y, sd in self.cp]
        if self.kind == 'knob':
            return [(rb - 1.2 * self.r0, self.hs, 0.0), (rb + 0.4 * self.out, self.hs + 0.15 * self.out, 0.0),
                    (rb + self.out, self.hs + 0.3 * self.out + self.rise, self.bend)]
        o = self.out
        return [(rb - 0.7 * self.r0, self.hs, 0.0),
                (rb + 0.15 * o, self.hs * 0.45 + 0.2 * self.r0, 0.1 * self.bend),
                (rb + self.mid * o, 0.35 * self.r1 + 0.25 * self.r0, 0.45 * self.bend),
                (rb + o, -self.sink * self.r1, self.bend)]

    def radius(self, t):
        return self.r1 + (self.r0 - self.r1) * (1 - t) ** self.k


def bez(P, t):
    P = np.asarray(P, float); n = len(P) - 1
    t = np.asarray(t, float)[..., None]
    return sum(math.comb(n, i) * (1 - t) ** (n - i) * t ** i * P[i] for i in range(n + 1))


class Foot:
    """A foot in block units: body relief `rel` (-99 empty; rows/cols of the approved block), its middle column tcc
    (continuous), the base's oval: centre row yc, squash zs; trunk radius rb; roots; tc/trr = the barrel used for the
    body's light (as bases22 / render7)."""
    def __init__(self, key, rel, tcc, yc, zs, rb, roots, tc, trr):
        self.key, self.rel, self.tcc, self.yc, self.zs, self.rb = key, rel, tcc, yc, zs, rb
        self.roots, self.tc, self.trr = roots, tc, trr

    def V(self):
        """The view direction in the foot's unsquashed frame: a ray keeps (x, zs z - y)."""
        return unit(np.array([0.0, 1.0, 1.0 / self.zs]))

    # ---------------------------------------------------------------- the roots as surface samples
    def samples(self, deg, step=0.22):
        """All roots' surface points at turn deg: P (unsquashed, turned), N, s (across the tube on the screen, -1..1),
        l (along, px), r, j (root index)."""
        V = self.V()
        out = []
        for j, rt in enumerate(self.roots):
            a = math.radians(rt.a + deg)
            ca, sa = math.cos(a), math.sin(a)
            cp = rt.path(self.rb)
            tt = np.linspace(0, 1, 300)
            C = bez(cp, tt)
            seg = np.linalg.norm(np.diff(C, axis=0), axis=1)
            arc = np.concatenate([[0], np.cumsum(seg)])
            n = max(3, int(arc[-1] / step) + 1)
            t = np.interp(np.linspace(0, arc[-1], n), arc, tt)
            C = bez(cp, t)                                     # (rho, y, side)
            l = np.interp(t, tt, arc)
            # to x, y, z: radial (ca, sa), sideways (-sa, ca)
            X = C[:, 0] * ca - C[:, 2] * sa
            Z = C[:, 0] * sa + C[:, 2] * ca
            Cw = np.stack([X, C[:, 1], Z], 1)
            T = unit(np.gradient(Cw, axis=0))
            r = rt.radius(t)
            if rt.kind == 'knob':
                # a rounded end: the radius closes in over the last r1 px
                rem = arc[-1] - l
                r = np.where(rem < rt.r1, np.sqrt(np.clip(rem / max(rt.r1, 1e-6), 0, 1)) * r, r)
            ref = np.where(np.abs(T[:, 1:2]) > 0.9, np.array([[1.0, 0, 0]]), np.array([[0.0, 1.0, 0]]))
            e1 = unit(np.cross(T, ref)); e2 = unit(np.cross(T, e1))
            rmax = float(r.max())
            nth = max(16, int(2 * math.pi * rmax / step))
            th = np.linspace(0, 2 * math.pi, nth, endpoint=False)
            N = np.cos(th)[None, :, None] * e1[:, None, :] + np.sin(th)[None, :, None] * e2[:, None, :]
            P = Cw[:, None, :] + r[:, None, None] * N
            A = unit(np.cross(T, V))
            s = np.einsum('ijk,ik->ij', N, A)
            keep = ((N @ V) > -0.3) & (P[..., 1] > -0.25)
            nk = int(keep.sum())
            out.append(dict(P=P[keep], N=N[keep], s=s[keep], l=np.broadcast_to(l[:, None], keep.shape)[keep],
                            r=np.broadcast_to(r[:, None], keep.shape)[keep], j=np.full(nk, j)))
        if not out:
            return {k: np.zeros((0, 3) if k in ('P', 'N') else 0) for k in ('P', 'N', 's', 'l', 'r', 'j')}
        return {k: np.concatenate([o[k] for o in out]) for k in out[0]}

    def proj(self, P):
        """Block coordinates (col, row), continuous."""
        return self.tcc + P[..., 0], self.yc + self.zs * P[..., 2] - P[..., 1]

    def depth(self, P):
        return P[..., 1] + self.zs * P[..., 2]

    def in_trunk_shadow(self, P, L):
        """Whether the trunk (a vertical cylinder of radius rb about the axis, any height) stands between P and the sun."""
        Lh = np.array([L[0], L[2]]); lh = float(np.linalg.norm(Lh))
        if lh < 1e-6: return np.zeros(len(P), bool)
        d = Lh / lh
        px, pz = P[:, 0], P[:, 2]
        tc = -(px * d[0] + pz * d[1])                       # closest approach along the sun's ground direction
        cx, cz = px + tc * d[0], pz + tc * d[1]
        return (tc > 0) & (cx * cx + cz * cz < (self.rb * 0.92) ** 2) & (px * px + pz * pz > (self.rb * 0.95) ** 2)


# ------------------------------------------------------------------ the three feet
def _relief(S, tc, trr, sun):
    L = R.norm(sun)
    out = np.full(S.shape, -99, int)
    for y in range(S.shape[0]):
        for x in range(S.shape[1]):
            if S[y, x] < 0: continue
            out[y, x] = S[y, x] - R.trunk_band(float(R._barrel_normal(x, tc, trr) @ L))
    return out

def _foot122():
    # the reference's drawing stage before its roots (ST[2]): the trunk with its rounded bottom; the same crown-shadow
    # clean-up as render7.REL_CLEAN on the top rows
    S = R.ST[2].copy()
    rel = _relief(S, R.TC, R.TRR, R.SUN_R)
    for y in range(3):
        for x in range(16, R.TW):
            if R.ST[2][y, x] >= 0 and R.ST[1][y, x] >= 0 and R.ST[2][y, x] < R.ST[1][y, x]:
                rel[y, x] += R.ST[1][y, x] - R.ST[2][y, x]
    # padded to the approved block's rows (22: the roots in front reach row 21)
    roots = [
        # the front root: a buttress down the trunk's front, splitting on the ground in two (the reference's lit root)
        Root(84, 6.0, 2.5, 1.8, 4.0, k=0.8, seed=11, cp=[(-1.6, 6.4, 0.4), (0.3, 4.0, 0.0), (1.1, 2.2, -0.3), (2.0, 1.0, -0.2)]),
        Root(84, 0, 0, 3.3, 1.8, k=1.1, seed=12, cp=[(1.2, 2.2, 0.4), (4.0, 1.6, 2.6), (8.0, 0.9, 5.4), (12.2, -0.5, 6.8)]),
        Root(84, 0, 0, 3.1, 1.7, k=1.1, seed=13, cp=[(1.2, 2.2, -0.6), (3.8, 1.6, -2.8), (7.4, 0.9, -6.0), (11.2, -0.5, -8.4)]),
        # the left one (in the trunk's shadow) and the right one: low ropes on the ground toward the front corners
        Root(140, 1.4, 6.5, 2.7, 1.7, bend=1.2, seed=14, mid=0.45),
        Root(38, 1.4, 6.3, 2.5, 1.6, bend=-1.0, seed=15, mid=0.45),
        # at the back: hidden by the trunk at turn 0
        Root(230, 2.4, 7.0, 2.8, 1.8, bend=1.4, seed=16, mid=0.45),
        Root(292, 2.6, 7.5, 2.9, 1.8, bend=-1.4, seed=17, mid=0.45),
        # the burl high on the right (the reference's bump at the block's top right)
        Root(6, 8.2, 2.8, 2.1, 1.3, kind='knob', seed=18),
    ]
    f = Foot('122', rel, R.TC + 0.5, 11.3, 0.31, 17.0, roots, R.TC, R.TRR)
    f.fs = R.FOOT_STAGE
    return f

def _foot124():
    b = B.BASES['124']
    rel = b.rel.copy()
    rel[5:9, :3] = -99; rel[5:9, 20:] = -99          # the side stubs
    rel[13:] = -99                                    # the tap root under the base
    for x in range(8, 15):                            # the base's last row: carry the row above down, a step darker
        if rel[12, x] > -50: rel[12, x] = max(1, rel[11, x] - 1)
    roots = [
        Root(0, 1.6, 1.6, 1.8, 1.2, seed=21, k=1.0),
        Root(180, 1.7, 1.7, 1.8, 1.2, seed=22, k=1.0),
        Root(90, 1.0, 2.2, 1.7, 1.3, seed=23, k=1.0),
        Root(270, 1.4, 1.8, 1.8, 1.2, seed=24, k=1.0),
    ]
    f = Foot('124', rel, b.tc + 0.5, 8.4, 0.53, 8.5, roots, b.tc, b.trr)
    f.fs = b.foot
    return f

FEET = {'122': _foot122(), '124': _foot124()}


# ------------------------------------------------------------------ drawing a foot into a tree's picture
def root_relief(foot, smp, tex):
    """Bark relief of root samples (block px): the tree's own bark relief rows run along each root (its plates and
    crevices at their size, as on the trunk), the rims a step darker (as the limbs)."""
    s, l, j, r = smp['s'], smp['l'], smp['j'], smp['r']
    rel = np.where(np.abs(s) < 0.8, 3, 2)
    if tex is not None:
        for jj in np.unique(j):
            m = j == jj
            tx = tex(foot.roots[jj].seed)
            col = np.clip(np.round(R.TC + s[m] * r[m]).astype(int), 0, tx.shape[1] - 1)
            row = np.clip(l[m].astype(int), 0, len(tx) - 1)
            rv = tx[row, col]
            rel[m] = np.where(rv < -50, 2, np.minimum(rv, 3))
    return np.where((r >= 1.6) & (np.abs(s) > 0.86), rel - 1, rel)

def root_band(foot, smp, L):
    """Light steps of root samples from their normals (the trees' thresholds); in the trunk's cast shadow a step down."""
    d = smp['N'] @ L
    band = np.where(d > -0.05, 0, np.where(d > -0.36, -1, -2))
    sh = foot.in_trunk_shadow(smp['P'], L)
    return np.where(sh, np.maximum(band - 1, -2), band)


PAD_L, PAD_R, PAD_T, PAD_B = 16, 16, 10, 12      # block px of room round the approved block for the roots

def foot_block(foot, deg, L, tex=None):
    """The foot at the reference's own scale (block px) at turn deg, on the block padded by PAD_*: kind (-1 none, 0 body,
    1 + j root j), rel (relief, the outline step in), band (light step), P (3D point of root pixels), h (height)."""
    n0, w0 = foot.rel.shape
    Hb, Wb = n0 + PAD_T + PAD_B, w0 + PAD_L + PAD_R
    kind = np.full((Hb, Wb), -1, int); rel = np.zeros((Hb, Wb), int); band = np.zeros((Hb, Wb), int)
    zb = np.full((Hb, Wb), -1e9); P3 = np.zeros((Hb, Wb, 3))
    for r in range(n0):
        for c in range(w0):
            v = foot.rel[r, c]
            if v < -50: continue
            x = c + 0.5 - foot.tcc
            z = math.sqrt(max(0.0, foot.rb ** 2 - x * x))
            y3 = foot.yc + foot.zs * z - (r + 0.5)
            R_, C_ = r + PAD_T, c + PAD_L
            kind[R_, C_] = 0; rel[R_, C_] = v
            band[R_, C_] = R.trunk_band(float(R._barrel_normal(c, foot.tc, foot.trr) @ L))
            zb[R_, C_] = y3 + foot.zs * z
            P3[R_, C_] = (x, y3, z)
    body0 = kind == 0                                 # the body's silhouette, roots in front or not
    smp = foot.samples(deg)
    if len(smp['j']):
        P = smp['P']
        col, row = foot.proj(P)
        cb = np.floor(col).astype(int) + PAD_L; rb_ = np.floor(row).astype(int) + PAD_T
        dep = foot.depth(P)
        rr = root_relief(foot, smp, tex); bb = root_band(foot, smp, L)
        ok = (cb >= 0) & (cb < Wb) & (rb_ >= 0) & (rb_ < Hb)
        idx = np.nonzero(ok)[0]
        pix = rb_[idx] * Wb + cb[idx]
        order = np.lexsort((dep[idx], pix))
        last = np.r_[pix[order][1:] != pix[order][:-1], True]
        win = idx[order][last]
        yy, xx = rb_[win], cb[win]
        front = dep[win] > zb[yy, xx] - 0.05
        yy, xx, win = yy[front], xx[front], win[front]
        zb[yy, xx] = dep[win]; rel[yy, xx] = rr[win]; band[yy, xx] = bb[win]
        kind[yy, xx] = 1 + smp['j'][win]; P3[yy, xx] = P[win]
    has = kind >= 0
    # the trees' outline: a pixel just behind the edge of a nearer piece (another root, or a root over the body) goes a
    # step darker; within one root, a pixel behind a fold of it. The burl belongs to the trunk (no line round it).
    grp = kind.copy()
    for j, rt in enumerate(foot.roots):
        if rt.kind == 'knob': grp[kind == 1 + j] = 0
    near = np.zeros_like(has)
    for dy_, dx_ in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        zn = np.roll(np.roll(zb, dy_, 0), dx_, 1)
        kn = np.roll(np.roll(grp, dy_, 0), dx_, 1)
        near |= has & (kn >= 0) & (((kn != grp) & (zn > zb + 1.0)) | (zn > zb + 2.0))
    rel[near] -= 1
    return dict(kind=kind, rel=rel, band=band, P=P3, n0=n0, w0=w0, body=body0)


def _index(i, n_lo, k, split, n_split, n0):
    """The approved block's resampling (render16._root_block / bases22._vgeom) for screen offsets i (rows or columns)
    from the block's origin, carried on past the block (unclamped) for the roots' room. split: the screen offset where
    the block's index `n_split` begins (rows: the ground row; columns: none)."""
    if split is None:
        if 0 <= i < n_lo: return min(n0 - 1, int((i + 0.5) / k))
        return int(math.floor((i + 0.5) / k)) if i < 0 else max(n0, int(math.floor((i + 0.5) / k)))
    if i < split:
        return min(n_split - 1, int(math.floor((i + 0.5) / k))) if i >= 0 else int(math.floor((i + 0.5) / k))
    j = n_split + int(math.floor((i - split + 0.5) / k))
    return min(n0 - 1, j) if (i - split) < n_lo else max(n0, j)


def draw_foot(t, img, foot, deg, X0, Y0, kx, ky, up, down, w, shade_body=None, shade_root=None, gshadow=None):
    """Paint the foot into img (the tree's picture) at turn deg: the block drawn at the reference's scale, resampled to
    the tree's size as the approved block (kx, ky; `up` rows over the ground row, `down` under it, `w` columns), the
    crown's shadow on it as the approved block's (body by shade_body(Xs, hs), roots by gshadow on the ground or
    shade_root(P) up on the trunk)."""
    H, W = img.shape[:2]
    L = np.asarray(t.L, float)
    bark = np.array(t.bark)
    texs = {}
    def tex(seed):
        if seed not in texs: texs[seed] = t._bark_tex(seed, 200)
        return texs[seed]
    blk = foot_block(foot, deg, L, tex)
    kind, rel, band, P3, n0, w0 = blk['kind'], blk['rel'], blk['band'], blk['P'], blk['n0'], blk['w0']
    fs = foot.fs
    i_lo, i_hi = -int(math.ceil(PAD_L * kx)) - 1, w + int(math.ceil(PAD_R * kx)) + 1
    y_lo, y_hi = -int(math.ceil(PAD_T * ky)) - 1, up + down + int(math.ceil(PAD_B * ky)) + 1
    ii = np.arange(i_lo, i_hi); yy = np.arange(y_lo, y_hi)
    Cc = np.array([_index(i, w, kx, None, 0, w0) for i in ii]) + PAD_L
    Rr = np.array([_index(y, down, ky, up, fs, n0) for y in yy]) + PAD_T
    Y = Y0 + yy[:, None] + 0 * ii[None, :]; X = X0 + ii[None, :] + 0 * yy[:, None]
    ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W) & (Rr[:, None] >= 0) & (Rr[:, None] < kind.shape[0]) & \
         (Cc[None, :] >= 0) & (Cc[None, :] < kind.shape[1])
    Rg = np.clip(np.broadcast_to(Rr[:, None], ok.shape), 0, kind.shape[0] - 1)
    Cg = np.clip(np.broadcast_to(Cc[None, :], ok.shape), 0, kind.shape[1] - 1)
    k = np.where(ok, kind[Rg, Cg], -1)
    drawn = k >= 0
    b = band[Rg, Cg].copy()
    sh = np.zeros(ok.shape, bool)
    body = drawn & (k == 0)
    if shade_body is not None and body.any():
        ys_, xs_ = np.nonzero(body)
        sh[ys_, xs_] = shade_body(X[ys_, xs_] - t.ox, up - yy[ys_])
    roots = drawn & (k > 0)
    if roots.any():
        ys_, xs_ = np.nonzero(roots)
        p = P3[Rg[ys_, xs_], Cg[ys_, xs_]]
        low = p[:, 1] < 2.5
        if gshadow is not None:
            sh[ys_[low], xs_[low]] = gshadow[Y[ys_[low], xs_[low]], X[ys_[low], xs_[low]]]
        if shade_root is not None and (~low).any():
            sh[ys_[~low], xs_[~low]] = shade_root(p[~low])
    b = np.where(sh, np.maximum(b - 1, -2), b)
    st = np.clip(rel[Rg, Cg] + b, 0, 3)
    img[Y[drawn], X[drawn]] = bark[st[drawn]]
    # the roots' pixels off the trunk (a stump's cut measures the trunk without them; a root or the burl over the
    # trunk's front stays part of its width)
    on_body = np.where(ok, blk['body'][Rg, Cg], False)
    rp = np.zeros((H, W), bool)
    rp[Y[roots & ~on_body], X[roots & ~on_body]] = True
    t._root_px = rp
    return blk


# ------------------------------------------------------------------ hooks into the round 22/24 trees and stumps
_ORIG = {}
OLD_FEET = False         # True: every foot drawn as approved (round 22 pictures, palms' nubs view-locked)

def install():
    """Based.draw_trunk draws the 3D foot (base '122' / '124') at the tree's foot_deg; the turn functions of round 24
    set foot_deg. Base '123' and old_feet=True keep the approved pictures."""
    if _ORIG: return
    import turn24 as TU, conifer24 as C24, stumps24 as S24
    _ORIG['draw'] = B.Based.draw_trunk
    def draw_trunk(self, img):
        if self.base not in FEET or OLD_FEET or getattr(self, 'old_feet', False):
            return _ORIG['draw'](self, img)
        foot = FEET[self.base]
        if self.base == '122':
            _, _, cm, rm = self._root_block()
            kx, ky = self.sx, self.sy
            X0 = self.ox + G.BX - int(round(R.TC * self.sx))
        else:
            g = self._vgeom()
            kx, ky, cm, rm = g['kx'], g['ky'], g['cm'], g['rm']
            X0 = self.ox + G.BX - g['xm']
        Y0 = self.oy - self.h0
        L = self.L
        if self.base == '122':
            up, down, w = self.h0, max(2, int(round((R.TROWS - R.FOOT_STAGE) * self.sy))), max(6, int(round(R.TW * self.sx)))
        else:
            b_ = B.BASES[self.base]
            up = max(2, int(round(b_.foot * ky))); down = max(1, int(round((b_.rel.shape[0] - b_.foot) * ky)))
            w = max(4, int(round(b_.rel.shape[1] * kx)))
        shade_body = shade_root = gshadow = None
        if self.crown and L[1] > 0.1:
            gshadow = self.shadow()
            zsq = getattr(self, 'foot_zsq', 0.55)
            def shade_body(x, h):
                x = np.asarray(x, float); h = np.asarray(h, float)
                return self._crown_shade_px(np.stack([x, h, np.zeros_like(x)], 1))
            def shade_root(p, X0=X0, kx=kx, ky=ky):
                q = np.stack([X0 + (foot.tcc + p[:, 0]) * kx - self.ox, p[:, 1] * ky, p[:, 2] * kx * zsq], 1)
                return self._crown_shade_px(q)
        draw_foot(self, img, foot, getattr(self, 'foot_deg', 0.0), int(X0), int(Y0), kx, ky, up, down, w,
                  shade_body, shade_root, gshadow)
        self._draw_skeleton(img)
    B.Based.draw_trunk = draw_trunk
    # the turns record their angle on the tree
    _ORIG['turn'] = TU.turn
    def turn(t, n, snap, zs_in=TU.ZSQ, zs_out=None, deg=None):
        t.foot_deg = 45.0 * n if deg is None else float(deg)
        return _ORIG['turn'](t, n, snap, zs_in=zs_in, zs_out=zs_out, deg=deg)
    TU.turn = turn
    _ORIG['cturn'] = C24.turn
    def cturn(t, n, snap, deg=None):
        t.foot_deg = 45.0 * n if deg is None else float(deg)
        t.foot_zsq = 0.45
        return _ORIG['cturn'](t, n, snap, deg=deg)
    C24.turn = cturn
    _ORIG['with_build'] = S24._Turned._with_build
    def _with_build(self, fn):
        import all23 as A
        orig = A.build
        deg = self.deg
        def build(k, s_):
            t = orig(k, s_)
            t.foot_deg = deg
            return t
        A.build = build
        try: return _ORIG['with_build'](self, fn)
        finally: A.build = orig
    S24._Turned._with_build = _with_build
    # a stump's cut face is as wide as the trunk at the cut row: the roots beside it do not count
    import stump23 as ST
    _ORIG['scut'] = ST.Stump._cut
    def scut(self, img, mask, x_axis):
        rp = getattr(getattr(self, 't', None), '_root_px', None)
        if rp is None: return _ORIG['scut'](self, img, mask, x_axis)
        Yf = int(round(self.oy)) - self.hs
        orig_run = ST._run_at
        def run_at(row, xa, rr=rp[Yf]):
            r = orig_run(row & ~rr, xa)
            return r if r is not None else orig_run(row, xa)
        ST._run_at = run_at
        try: return _ORIG['scut'](self, img, mask, x_axis)
        finally: ST._run_at = orig_run
    ST.Stump._cut = scut
    import kinds24 as K
    _ORIG['wturn'] = K.willow_turn
    def wturn(t, n, snap, zs_in=TU.ZSQ, zs_out=None):
        t.foot_deg = 45.0 * n
        return _ORIG['wturn'](t, n, snap, zs_in=zs_in, zs_out=zs_out)
    K.willow_turn = wturn
    # the palms' root nubs (one pixel under the foot) turn round the foot too; as many at the back, hidden at turn 0
    import palmtree22 as PT
    from scipy import ndimage as ndi
    _ORIG['palm'] = PT.draw_trunk
    def palm_draw_trunk(trunk, W, H, ox, oy, Lsun, smap=None, reach=None, spike_top=None, extra=None):
        if OLD_FEET: return _ORIG['palm'](trunk, W, H, ox, oy, Lsun, smap, reach, spike_top, extra)
        nubs = trunk.nubs
        ex = {} if extra is None else extra
        trunk.nubs = 0
        try: steps, mask = _ORIG['palm'](trunk, W, H, ox, oy, Lsun, smap, reach, spike_top, ex)
        finally: trunk.nubs = nubs
        rows = np.nonzero(mask.any(1))[0]
        if not nubs or not len(rows): return steps, mask
        pre, line = ex['pre'], ex['line']
        edge = mask & ~ndi.binary_erosion(mask, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
        _, (iy, ix) = ndi.distance_transform_edt(~(mask & ~edge), return_indices=True)
        bot = np.nonzero(mask[rows.max()])[0]
        cx = (bot.min() + bot.max()) / 2; w = bot.max() - bot.min() + 1
        fs = (-0.3, 0.3, -0.05, 0.15)[:nubs]
        azs = [math.acos(max(-1.0, min(1.0, 2 * f))) for f in fs]
        azs += [-(a + 0.35) for a in azs]
        turn = getattr(trunk, 'turn_a', 0.0) or 0.0
        for k, az in enumerate(azs):
            a = az + turn
            if math.sin(a) <= 0.15: continue                # behind the trunk (or on its very side)
            if k < len(fs) and abs(turn) < 1e-9:
                xx = int(round(cx + fs[k] * w))              # turn 0: exactly where round 22 put it
            else:
                xx = int(round(cx + 0.5 * w * math.cos(a)))
            col = np.nonzero(mask[:, xx])[0] if 0 <= xx < W else []
            if len(col):
                yy = col.max() + 1
                if yy < H:
                    steps[yy, xx] = 0; line[yy, xx] = True; pre[yy, xx] = pre[iy[yy, xx], ix[yy, xx]]
        return steps, mask
    PT.draw_trunk = palm_draw_trunk
