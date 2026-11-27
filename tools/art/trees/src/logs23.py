# Round 23 step 3b: what lies on the ground after a tree falls, after the reference (references/user-palms-snow.jpg,
# right bottom): a short log, a long fallen trunk with its limbs, a broken trunk with a sprout (mockup, no game code).
# The pieces are bark tubes drawn as 3D surfaces in the stumps' view: the ground squashed to FACE_ZS 0.6 like the
# approved oval cut (screen X = x, Y = 0.6 z - y), each pixel the nearest point of a tube, lit by the game sun with the
# trees' own steps (render7.trunk_band) and the species' own bark (the tree's bark relief rows and colour ramp, as its
# trunk and limbs are drawn); cut ends show the stumps' wood (rings, pith, a check, resin, palms' fibres).
import math, random, numpy as np
from scipy import ndimage as ndi
import all23 as A, render7 as R, stump23 as S
from render14 import HALF, SPAN_LO, SPAN_HI

ZS = S.FACE_ZS

def unit(v):
    v = np.asarray(v, float); n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-9)

V = unit(np.array([0.0, ZS, 1.0]))                   # toward the camera
UP = np.array([0.0, 1.0, 0.0])


def bez(P, t):
    P = np.asarray(P, float); n = len(P) - 1
    t = np.asarray(t, float)[..., None]
    return sum(math.comb(n, i) * (1 - t) ** (n - i) * t ** i * P[i] for i in range(n + 1))


class Tube:
    """A piece of bark: centre curve through control points P (Bezier), radius r0 -> r1 (power k), its own bark seed.
    end0 / end1: None (open: hidden in something), 'cut' (the wood of a saw or axe cut), 'cap' (rounded bark),
    'broken' (dark splintered wood)."""
    def __init__(self, P, r0, r1, seed=7, k=1.0, end0=None, end1=None, l0=0.0, wood=None, cut0=None, cut1=None,
                 wob=0.0):
        self.P, self.r0, self.r1, self.k, self.seed = np.asarray(P, float), r0, r1, k, seed
        self.wob = wob                                  # the bark's bumps: the radius wobbles by this share
        self.cap0 = 0.0                                 # a rounded start this long (px): the radius closes in
        self.end0, self.end1, self.l0, self.wood = end0, end1, l0, wood
        self.cut0, self.cut1 = cut0, cut1           # the plane of an oblique cut: its outward normal (None: square)

    def r(self, t):
        return self.r1 + (self.r0 - self.r1) * (1 - np.asarray(t, float)) ** self.k

    def samples(self, step=0.3):
        tt = np.linspace(0, 1, 400)
        C = bez(self.P, tt)
        seg = np.linalg.norm(np.diff(C, axis=0), axis=1)
        arc = np.concatenate([[0], np.cumsum(seg)])
        n = max(2, int(arc[-1] / step) + 1)
        t = np.interp(np.linspace(0, arc[-1], n), arc, tt)
        C = bez(self.P, t)
        T = unit(np.gradient(C, axis=0))
        l = np.interp(t, tt, arc) + self.l0
        return t, C, T, l


def frame(T):
    """Two unit vectors across the tangent T (rows)."""
    ref = np.where(np.abs(T[:, 1:2]) > 0.9, np.array([[1.0, 0, 0]]), np.array([[0.0, 1.0, 0]]))
    e1 = unit(np.cross(T, ref)); e2 = unit(np.cross(T, e1))
    return e1, e2


class Scene:
    """Tubes of one tree drawn together: z-buffer of their surfaces and cut faces, on the key colours."""
    def __init__(self, t, key, W=260, H=200, ox=None, oy=None, sun=None, zs=ZS):
        self.t, self.key = t, key
        self.W, self.H = W, H
        self.ox = W / 2 if ox is None else ox
        self.oy = H - 40 if oy is None else oy
        self.L = unit(np.asarray(sun if sun is not None else (t.L if t is not None else R.SUN_R), float))
        self.zs = zs
        self.V = unit(np.array([0.0, zs, 1.0]))
        self.tubes = []
        self.bark = np.array(t.bark, float) if t is not None else None
        self.texs = {}
        self.thin = 1.6                     # under this radius a piece is drawn plain (the trees: 3.5, in the crown)
        self.palm = None                    # palms: dict(pu, pv, phase, soft): the scales of the palm's trunk
        self.geo = {}
        self.rim_thin = 0.5                 # thin pieces (r < 3) get a wider dark rim, so that each one reads

    def add(self, tube):
        self.tubes.append(tube); return tube

    def proj(self, P):
        P = np.asarray(P, float)
        return self.ox + P[..., 0], self.oy + self.zs * P[..., 2] - P[..., 1]

    def tex(self, seed):
        if seed not in self.texs: self.texs[seed] = self.t._bark_tex(seed, 400)
        return self.texs[seed]

    # ------------------------------------------------------------------ rasterising
    def _points(self):
        """All surface points as flat arrays; kind 0 bark, 1 cut face, 2 broken face. An end cut obliquely (cut0 /
        cut1: the plane's outward normal) trims the bark by its plane and shows an elliptic face."""
        out = []
        for j, tb in enumerate(self.tubes):
            t, C, T, l = tb.samples()
            r = tb.r(t)
            if tb.wob:
                g = random.Random(tb.seed * 7 + 1)
                f1, f2, f3 = g.uniform(0, 6.3), g.uniform(0, 6.3), g.uniform(0, 6.3)
                w1, w2 = g.uniform(0.35, 0.5), g.uniform(0.8, 1.1)
                r = r * (1 + tb.wob * (0.6 * np.sin(l * w1 + f1) + 0.4 * np.sin(l * w2 + f2) * np.sin(l * 0.13 + f3)))
            if tb.cap0 > 0:
                x = (l - l[0]) / tb.cap0
                r = r * np.where(x < 1, 0.5 + 0.5 * np.sqrt(np.clip(x, 0, 1)), 1.0)
            planes = []
            for end, i_, nc in ((tb.end0, 0, tb.cut0), (tb.end1, -1, tb.cut1)):
                out_n = T[i_] * (1 if i_ == -1 else -1)
                nc_ = out_n if nc is None else unit(np.asarray(nc, float))
                planes.append((end, i_, nc_, C[i_].copy(), out_n, float(r[i_])))
            # the bark goes on past an oblique cut up to its plane
            for end, i_, nc_, c_end, out_n, rr in planes:
                cb = float(nc_ @ out_n)
                if cb > 0.999: continue
                e = rr * math.sqrt(max(0.0, 1 - cb * cb)) / max(cb, 0.2) + 1.0
                k = np.arange(0.3, e + 0.3, 0.3)
                Ce = c_end[None, :] + out_n[None, :] * k[:, None]
                Te = np.broadcast_to(T[i_], Ce.shape)
                le = l[i_] + (k if i_ == -1 else -k)
                re_ = np.full(len(k), rr)
                if i_ == -1:
                    C, T, l, r = np.vstack([C, Ce]), np.vstack([T, Te]), np.r_[l, le], np.r_[r, re_]
                else:
                    C, T, l, r = np.vstack([Ce[::-1], C]), np.vstack([Te[::-1], T]), np.r_[le[::-1], l], np.r_[re_, r]
            e1, e2 = frame(T)
            rmax = float(r.max())
            nth = max(12, int(2 * math.pi * rmax / 0.3))
            th = np.linspace(0, 2 * math.pi, nth, endpoint=False)
            N = np.cos(th)[None, :, None] * e1[:, None, :] + np.sin(th)[None, :, None] * e2[:, None, :]
            P = C[:, None, :] + r[:, None, None] * N
            keep = (N @ self.V) > -0.25
            for end, i_, nc_, c_end, out_n, rr in planes:
                keep &= ((P - c_end) @ nc_) <= 0.05
            self.geo[j] = (C, N, r, [(nc_, c_end) for end, i_, nc_, c_end, out_n, rr in planes])
            A_ = unit(np.cross(T, self.V))
            s = np.einsum('ijk,ik->ij', N, A_)
            nk = int(keep.sum())
            out.append(dict(P=P[keep], N=N[keep], kind=np.zeros(nk, int), j=np.full(nk, j),
                            s=s[keep], l=np.broadcast_to(l[:, None], keep.shape)[keep],
                            r=np.broadcast_to(r[:, None], keep.shape)[keep], fx=np.zeros(nk), fy=np.zeros(nk),
                            th=np.broadcast_to(th[None, :], keep.shape)[keep]))
            for end, i_, nc_, c_end, out_n, rr in planes:
                if end not in ('cut', 'broken'): continue
                if nc_ @ self.V <= 0.02: continue
                cb = max(0.2, float(nc_ @ out_n))
                w = np.cross(out_n, nc_)
                if np.linalg.norm(w) < 1e-3:
                    w = unit(np.cross(nc_, self.V)) if abs(nc_ @ self.V) < 0.999 else np.array([1.0, 0, 0])
                w = unit(w)
                q = unit(np.cross(nc_, w))                 # in the plane, along the ellipse's long axis
                qx = unit(q - (q @ out_n) * out_n)           # its image across the axis (the rings' frame)
                ys, xs = np.mgrid[-rr / cb:rr / cb + 0.01:0.25, -rr:rr + 0.01:0.25]
                ins = xs * xs + (ys * cb) ** 2 <= rr * rr
                fx, fy = xs[ins], ys[ins] * cb
                P = c_end[None, :] + xs[ins][:, None] * w[None, :] + ys[ins][:, None] * q[None, :]
                n_ = len(fx)
                out.append(dict(P=P, N=np.broadcast_to(nc_, (n_, 3)), kind=np.full(n_, 1 if end == 'cut' else 2),
                                j=np.full(n_, j), s=np.zeros(n_), l=np.zeros(n_), r=np.full(n_, rr), fx=fx, fy=fy,
                                th=np.zeros(n_),
                                face=(j, i_, rr, w, qx, nc_, c_end, out_n)))
        return out

    def raster(self):
        parts = self._points()
        keys = ('P', 'N', 'kind', 'j', 's', 'l', 'r', 'fx', 'fy', 'th')
        cat = {k: np.concatenate([np.asarray(p[k]).reshape(len(p['kind']), -1) if k in ('P', 'N') else np.asarray(p[k])
                                  for p in parts]) for k in keys}
        X, Y = self.proj(cat['P'])
        Xi, Yi = np.floor(X).astype(int), np.floor(Y).astype(int)
        depth = cat['P'] @ self.V + np.where(cat['kind'] > 0, 0.05, 0.0)
        ok = (Xi >= 0) & (Xi < self.W) & (Yi >= 0) & (Yi < self.H)
        idx = np.nonzero(ok)[0]
        pix = Yi[idx] * self.W + Xi[idx]
        order = np.lexsort((depth[idx], pix))
        last = np.r_[pix[order][1:] != pix[order][:-1], True]
        win = idx[order][last]
        self.zb = np.full((self.H, self.W), -1e9)
        self.att = {k: np.zeros((self.H, self.W) + ((3,) if k in ('P', 'N') else ()), float) for k in keys}
        yy, xx = Yi[win], Xi[win]
        self.zb[yy, xx] = depth[win]
        for k in keys:
            self.att[k][yy, xx] = cat[k][win]
        self.has = self.zb > -1e8
        self.faces = [p['face'] for p in parts if 'face' in p]
        self.allP = cat['P']
        return self

    # ------------------------------------------------------------------ colours
    def paint(self, img, wood_key=None):
        """Bark steps from the relief and the light, the trees' rim and outline rules; faces in the stumps' wood."""
        wood_key = wood_key or self.key
        L = self.L
        has = self.has
        kind = self.att['kind'].astype(int); j = self.att['j'].astype(int)
        steps = np.full((self.H, self.W), -1, int)
        ys, xs = np.nonzero(has & (kind == 0))
        n = self.att['N'][ys, xs]
        d = n @ L
        band = np.where(d > -0.05, 0, np.where(d > -0.36, -1, -2))
        s = self.att['s'][ys, xs]; l = self.att['l'][ys, xs]; r = self.att['r'][ys, xs]
        rel = np.full(len(ys), 3)
        if self.palm is not None:
            return self._paint_palm(img, wood_key, ys, xs, d)
        for jj in np.unique(j[ys, xs]):
            m = j[ys, xs] == jj
            tb = self.tubes[jj]
            tex = self.tex(tb.seed)
            col = np.clip(np.round(R.TC + s[m] * HALF).astype(int), SPAN_LO, SPAN_HI)
            row = np.clip(l[m].astype(int), 0, len(tex) - 1)
            rv = tex[row, col]
            rv = np.where(rv < -50, 2, rv)
            if getattr(tb, 'vein', None): rv = np.full(rv.shape, 2)
            thin = r[m] < self.thin
            rv = np.where(thin, np.where(np.abs(s[m]) > 0.8, 2, 3), rv)
            rv = np.where(r[m] < 1.6, 3, rv)
            rim = np.where(r[m] < 3.0, self.rim_thin, 0.86)
            rv = np.where(np.abs(s[m]) > rim, rv - 1, rv)
            rel[m] = rv
        steps[ys, xs] = rel + band
        self._veins(steps, ys, xs, j)
        # the trees' outline: a pixel just behind the edge of a nearer piece goes a step darker
        zb = self.zb
        near = np.zeros_like(has)
        for dy_, dx_ in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            zn = np.roll(np.roll(zb, dy_, 0), dx_, 1)
            near |= has & (zn > zb + 2.5)
        steps[near & (kind == 0)] -= 1
        bark_px = has & (kind == 0)
        img[bark_px] = self.bark[np.clip(steps[bark_px], 0, 3)].round().astype(np.uint8)
        return self._paint_faces(img, wood_key)

    def _veins(self, steps, ys, xs, j):
        """Tubes with .vein (the fallen trunk, like the reference's): the bark as long raised ridges along the length,
        each lit a step on top with a step of shadow on the screen row under it, broken into strips."""
        for jj, tb in enumerate(self.tubes):
            if not getattr(tb, 'vein', None): continue
            m = j[ys, xs] == jj
            if not m.any(): continue
            yy, xx = ys[m], xs[m]
            th = self.att['th'][yy, xx]; l = self.att['l'][yy, xx]; r = self.att['r'][yy, xx]
            g = np.random.default_rng(tb.seed * 13 + 5)
            nr = max(5, int(round(2 * math.pi * float(np.median(r)) / tb.vein)))
            off = g.uniform(0, 100, nr + 1); amp = g.uniform(0.15, 0.35, nr + 1)
            ph = th / (2 * math.pi) * nr
            k = np.floor(ph).astype(int) % nr
            ph = ph + amp[k] * np.sin(l * 0.07 + off[k])
            k = np.floor(ph).astype(int) % nr
            fr = ph - np.floor(ph)
            width = np.abs(fr - 0.5) * 2 * math.pi * r / nr
            seg_l = g.uniform(4, 8)
            seg = np.floor((l + off[k] * 3) / seg_l)
            h_ = (seg * 7 + k * 13 + (seg * k) % 3) % 5
            ridge = (width < 0.6) & (h_ < 3)
            # dark grooves between the ridges, in shorter dashes
            fr2 = (fr + 0.5) % 1.0
            width2 = np.abs(fr2 - 0.5) * 2 * math.pi * r / nr
            seg2 = np.floor((l + off[k] * 5 + 2) / (seg_l * 0.7))
            groove = (width2 < 0.55) & (((seg2 * 5 + k * 7) % 5) < 2) & ~ridge
            R2 = np.zeros(steps.shape, bool); R2[yy[ridge], xx[ridge]] = True
            G2 = np.zeros(steps.shape, bool); G2[yy[groove], xx[groove]] = True
            mine = np.zeros(steps.shape, bool); mine[yy, xx] = True
            steps[R2] += 1
            under = np.zeros_like(R2); under[1:] = R2[:-1]
            steps[under & mine & ~R2] -= 1
            steps[G2 & ~under] -= 1

    def _paint_palm(self, img, wood_key, ys, xs, d):
        """The palm trunks' look (palmtree22.draw_trunk): diamond scales by (around, along), the shaded side one step
        down, an outline to the background, softened like the approved palms (contrast / soft)."""
        import palmtree22 as PT
        pm = self.palm
        th = self.att['th'][ys, xs]; l = self.att['l'][ys, xs]; r = self.att['r'][ys, xs]
        n_around = np.maximum(4, np.round(2 * math.pi * r / pm['pu']))
        u = th / (2 * math.pi) * n_around + pm['phase']
        v = l / pm['pv']
        rel = PT.relief(u, v)[0]
        rel = np.where(r < 1.6, 2, rel)
        b = PT.trunk_band(d)
        steps = np.full((self.H, self.W), -1, int)
        steps[ys, xs] = np.clip(rel + b, 0, 3)
        has = self.has; kind = self.att['kind'].astype(int)
        bark_px = has & (kind == 0)
        pre = steps.copy()
        edge = bark_px & ~ndi.binary_erosion(has, np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
        zb = self.zb
        near = np.zeros_like(has)
        for dy_, dx_ in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            zn = np.roll(np.roll(zb, dy_, 0), dx_, 1)
            near |= has & (zn > zb + 2.5)
        line = (edge | near) & bark_px
        img[bark_px] = self.bark[np.clip(steps[bark_px], 0, 3)].round().astype(np.uint8)
        c_own = self.bark[np.clip(pre[line], 0, 3)]
        img[line] = (c_own + (self.bark[0] - c_own) / pm['soft']).round().astype(np.uint8)
        return self._paint_faces(img, wood_key)

    def _paint_faces(self, img, wood_key):
        L = self.L; has = self.has
        kind = self.att['kind'].astype(int); j = self.att['j'].astype(int)
        # cut and broken faces
        wr = S.wood_ramp(wood_key)
        for (jj, i_, rr, w, qx, nc_, c_end, out_n) in self.faces:
            m = has & (kind > 0) & (j == jj)
            if not m.any(): continue
            yy, xx = np.nonzero(m)
            pts = self.att['P'][yy, xx]
            mine = np.abs((pts - c_end) @ nc_) < 0.6
            yy, xx = yy[mine], xx[mine]
            if not len(yy): continue
            fx, fy = self.att['fx'][yy, xx], self.att['fy'][yy, xx]
            tb = self.tubes[jj]
            Lf = np.array([L @ w, L @ qx]); Lf = Lf / max(1e-6, np.linalg.norm(Lf))
            # the outline side of the face's bark ring: away from the tube's body on the screen
            T_scr = np.array([out_n[0], self.zs * out_n[2] - out_n[1]])
            dP = self.att['P'][yy, xx] - c_end
            off = np.stack([dP[:, 0], self.zs * dP[:, 2] - dP[:, 1]], 1)
            out_side = off @ T_scr > 0
            kind_here = int(self.att['kind'][yy[0], xx[0]])
            bk, wd = wood_uv(fx, fy, rr, tb.seed * 3 + (0 if i_ == 0 else 1) + 5, wood_key, Lf, out_side,
                             broken=(kind_here == 2), wood=tb.wood)
            fd = float(nc_ @ L)
            fb = 0 if fd > 0.1 else (-1 if fd > -0.3 else -2)
            for y_, x_, b_, w_ in zip(yy, xx, bk, wd):
                if b_ >= 0: img[y_, x_] = self.bark[b_].round().astype(np.uint8)
                elif w_ == 9: img[y_, x_] = S.RESIN_RGB.astype(np.uint8)
                else: img[y_, x_] = wr[max(0, w_ + fb)].round().astype(np.uint8)
        return img

    def shadow(self, extra=None):
        """The ground shadow of every tube by the sun (points cast to y = 0), closed and filled like the palms'."""
        L = self.L
        m = np.zeros((self.H, self.W), bool)
        if L[1] < 0.1: return m
        P = self.allP if extra is None else np.concatenate([self.allP, extra])
        g = P - L[None, :] * (P[:, 1:2] / L[1])
        X = np.floor(self.ox + g[:, 0]).astype(int); Y = np.floor(self.oy + self.zs * g[:, 2]).astype(int)
        ok = (X >= 0) & (Y >= 0) & (X < self.W) & (Y < self.H)
        m[Y[ok], X[ok]] = True
        m = ndi.binary_closing(m, np.ones((3, 3)), iterations=1)
        m = ndi.binary_fill_holes(m)
        return m

    def picture(self, snow=None):
        """Keyed picture: ground KEY_G, shadow KEY_S, the pieces; snow (a dict of SNOW_T, or None) lays the winter's
        layer on their tops."""
        self.raster()
        img = np.zeros((self.H, self.W, 3), np.uint8); img[:] = S.hexc(A.KEY_G)
        sh = self.shadow()
        img[sh] = S.hexc(A.KEY_S)
        self.paint(img)
        self.mask = self.has.copy()
        self.snow_m = np.zeros_like(self.has)
        if snow is not None:
            self.snow_pass(img, snow)
        return img

    def snow_pass(self, img, P):
        """Winter: a layer of snow on the upper side of every piece (the approved snow: bare23's ramp lit by the sun,
        its soft outline): over the surface where it faces up, as thick as SNOW_T says for the piece's radius, thinning
        to nothing where the side turns down; nearer than the bark there, it covers it."""
        import bare23 as B
        L = self.L
        pts, nrm = [], []
        for j, (C, N, r, planes) in self.geo.items():
            tb = self.tubes[j]
            ny = N[..., 1]
            rr = np.broadcast_to(r[:, None], ny.shape)
            T = np.clip(P['k'] * rr, P['lo'], P['hi'])
            T = np.where(rr < P['thin'], np.minimum(T, P['thin_t']), T)
            q = np.clip((ny - P['n0']) / (1 - P['n0']), 0, 1)
            t = T * np.sqrt(q)
            on = (q > 0) & (t > 0.2)
            Ps = C[:, None, :] + (rr + t)[..., None] * N
            ok = on.copy()
            for nc_, c_end in planes:
                ok &= ((Ps - c_end) @ nc_) <= 0.6
            # the snow's own normal: the surface's, tipped up as the layer thins out at its edge
            Ns = unit(N + np.array([0.0, 1.0, 0.0]) * 0.6)
            pts.append(Ps[ok]); nrm.append(Ns[ok])
            # and the layer's edge down to the bark, so that it has no gap
            for f_ in (0.33, 0.66):
                Pm = C[:, None, :] + (rr + t * f_)[..., None] * N
                pts.append(Pm[ok]); nrm.append(Ns[ok])
        if not pts: return
        Pa = np.concatenate(pts); Na = np.concatenate(nrm)
        X, Y = self.proj(Pa)
        Xi, Yi = np.floor(X).astype(int), np.floor(Y).astype(int)
        depth = Pa @ self.V
        ok = (Xi >= 0) & (Xi < self.W) & (Yi >= 0) & (Yi < self.H)
        idx = np.nonzero(ok)[0]
        pix = Yi[idx] * self.W + Xi[idx]
        order = np.lexsort((depth[idx], pix))
        last = np.r_[pix[order][1:] != pix[order][:-1], True]
        win = idx[order][last]
        yy, xx = Yi[win], Xi[win]
        nearer = depth[win] > self.zb[yy, xx] - 0.3
        yy, xx, win = yy[nearer], xx[nearer], win[nearer]
        m = np.zeros((self.H, self.W), bool); tone = np.zeros((self.H, self.W), int)
        d = Na[win] @ L + P['lit']
        m[yy, xx] = True
        tone[yy, xx] = np.where(d > 0.78, 5, np.where(d > 0.5, 4, np.where(d > 0.2, 3, np.where(d > -0.1, 2, 1))))
        # the outline: against the background (and the bark under it), soft as the approved snow
        tv = np.where(B.rim_of(m), 5 + tone, tone)
        img[m] = B.SNOW_EXT[tv[m]]
        self.snow_m = m
        self.mask = self.mask | m


def wood_uv(fx, fy, rc, seed, key, Lf, out_side, broken=False, wood=None):
    """The stumps' face_roles for points of a face in its own axes (px): bark ring (the outline on the side away from
    the body, lit bark on the other), sapwood, rings round an off-centre pith, a check, resin; palms fibres. broken:
    splintered wood, darker, fibres across instead of rings."""
    rng = random.Random(seed)
    d = np.sqrt(fx * fx + fy * fy)
    e = rc - d
    bark = np.full(fx.shape, -1, int); wd = np.full(fx.shape, -1, int)
    dh, ks, kv, heart, cracks, spk = S.SPECIES_WOOD.get(key, S.SPECIES_WOOD['oak'])
    nl = (fx * Lf[0] + fy * Lf[1]) / np.maximum(d, 1e-6)
    ring0 = e < 1.0
    thick = rc >= 3.0
    band = np.where(nl > -0.05, 0, np.where(nl > -0.36, -1, -2))
    bark[ring0 & out_side] = 0
    if thick: bark[ring0 & ~out_side] = np.clip(2 + band, 1, 3)[ring0 & ~out_side]
    else: bark[ring0 & ~out_side] = 1
    ring1 = (bark < 0) & (e < (2.0 if thick else 1.5))
    wd[ring1] = np.where(nl > 0.3, 5, np.where(nl < -0.3, 3, 4))[ring1]
    core = (bark < 0) & (wd < 0)
    wd[core] = 4
    r3 = np.random.default_rng(seed + 5)
    if broken:
        # splintered: fibres along one way, light and dark streaks, the middle darker (deep in the break)
        a = rng.uniform(-0.5, 0.5)
        across = fx * math.cos(a) + fy * math.sin(a)
        streak = (np.floor(across + r3.random(fx.shape) * 0.8) % 3 == 0)
        wd[core] = 3
        wd[core & streak] = 2
        wd[core & (d < 0.45 * rc)] = 2
        wd[core & (d < 0.45 * rc) & streak] = 1
        return bark, wd
    if key in ('palm', 'fan_palm'):
        dots = r3.random(fx.shape) < 0.32
        wd[core & dots] = 2
        wd[core & (d < 0.35 * rc) & ~dots] = 5
        return bark, wd
    phi = rng.uniform(0, math.tau); off = rng.uniform(0.1, 0.22) * rc
    px_, py_ = off * math.cos(phi), off * math.sin(phi)
    ddx, ddy = fx - px_, fy - py_
    dp = np.sqrt(ddx * ddx + ddy * ddy); th = np.arctan2(ddy, ddx)
    f1, f2 = rng.uniform(0, math.tau), rng.uniform(0, math.tau)
    dw = dp * (1 + 0.07 * np.sin(2 * th + f1) + 0.05 * np.sin(3 * th + f2))
    if heart: wd[core & (dw < 0.55 * (rc - 2))] = 3
    sp = max(2.6, rc / 3.0) * spk
    for k in range(1, int((rc - 2.2) / sp) + 1):
        on = core & (np.abs(dw - k * sp) < 0.55)
        wd[core & ~on & (np.abs(dw - k * sp) < 1.4) & (dw < k * sp) & (r3.random(fx.shape) < 0.3) & (wd == 4)] = 3
        wd[on] = 2
    wd[core & (wd == 4) & (r3.random(fx.shape) < 0.04)] = 3
    wd[core & (dp < (0.9 if rc >= 4 else 0.6))] = 0 if rc >= 5 else 2
    if cracks and rc >= 5:
        for _ in range(cracks if cracks > 1 else 1):
            a = rng.uniform(-math.pi, math.pi); ln = rng.uniform(0.45, 0.8) * rc
            along = ddx * math.cos(a) + ddy * math.sin(a); acr = np.abs(-ddx * math.sin(a) + ddy * math.cos(a))
            cr = core & (along > 0.5) & (along < ln) & (acr < 0.55)
            wd[cr] = np.where(along[cr] < ln * 0.7, 0, 1)
    if key in S.RESIN and rc >= 4:
        cand = np.nonzero(ring1 | (core & (e < 3)))[0]
        for _ in range(rng.randint(1, 2)):
            if len(cand): wd[cand[rng.randrange(len(cand))]] = 9
    return bark, wd


# ---------------------------------------------------------------------------------------------------- the pieces
def seed_of(key, s, salt=0):
    return (sum(ord(c) * (i + 1) for i, c in enumerate(key)) + int(round(s * 100)) + salt * 131) % 997


def ground_clamp(P, r):
    """Control points of a tube lifted so that it does not go into the ground (centre >= its radius)."""
    P = np.array(P, float)
    rr = np.broadcast_to(np.asarray(r, float), (len(P),))
    P[:, 1] = np.maximum(P[:, 1], rr * 0.92)
    return P


def fit(scene, pad=4):
    """Size the canvas to the pieces and their shadow; ox, oy so that everything is inside with pad px."""
    pts = []
    for tb in scene.tubes:
        t, C, T, l = tb.samples(step=0.8)
        r = tb.r(t)[:, None]
        for dx in (-1, 1):
            for dy in (-1, 1):
                pts.append(C + np.hstack([dx * r, dy * r, dx * r]))
    P = np.concatenate(pts)
    X = P[:, 0]; Y = scene.zs * P[:, 2] - P[:, 1]
    L = scene.L
    if L[1] > 0.1:
        g = P - L[None, :] * (P[:, 1:2] / L[1])
        X = np.concatenate([X, g[:, 0]]); Y = np.concatenate([Y, scene.zs * g[:, 2]])
    x0, x1, y0, y1 = X.min(), X.max(), Y.min(), Y.max()
    scene.W = int(math.ceil(x1 - x0)) + 2 * pad
    scene.H = int(math.ceil(y1 - y0)) + 2 * pad
    scene.ox = pad - math.floor(x0)
    scene.oy = pad - math.floor(y0)
    return scene


SNOW_T = dict(k=0.28, lo=0.8, hi=2.4, thin=1.6, thin_t=0.9, n0=0.62, lit=0.2)


class Piece:
    """Common parts: the species' tree (bark, ramp, sun), the trunk's radius above the stump's cut."""
    def __init__(self, key, s=0.68, seed=None, sun=None):
        self.key, self.s = key, s
        self.seed = seed if seed is not None else seed_of(key, s)
        self.rng = random.Random(self.seed)
        self.is_palm = key in ('palm', 'fan_palm')
        if self.is_palm:
            p = A.build(key, s)
            tr = p.trunk
            self.t, self.palm_obj = None, p
            self.r0 = float(tr.r_foot)
            self.rt = float(tr.radius(0.1))
            sc = Scene(None, key, sun=sun if sun is not None else p.sun)
            sc.bark = np.array([S.hexc(h) for h in p.bark], float)
            sc.palm = dict(pu=tr.pu, pv=tr.pv, phase=tr.phase, soft=p.soft)
            self.sc = sc
            return
        t = A.build(key, s)
        if sun is not None: t.L = R.norm(sun)
        self.t = t
        tl = t.limbs[0]
        self.r0 = float(tl.r(0.0))
        hs = max(S.HS_MIN, int(round(S.HS_K * 2 * self.r0)))
        # the piece over the stump: the trunk's radius a little above the cut
        self.rt = float(tl.r(S.t_at_height(tl, hs + self.r0)))
        self.sc = Scene(t, key)

    def picture(self, snow=None):
        fit(self.sc, pad=6)
        img = self.sc.picture(snow=snow)
        self.mask = self.sc.mask
        self.ox, self.oy = self.sc.ox, self.sc.oy
        return img


LOG = dict(phi=10, cut=32, cut_up=10, len_k=2.6, taper=0.92, bend=0.05, wob=0.07, stubs=5, stub_r=(0.3, 0.4),
           stub_l=(1.2, 2.2), top_stub=True)

class Log(Piece):
    """The reference's short log (log_a): a piece of the trunk lying on the ground, turned phi degrees toward the
    viewer at its right end, sawn there (the stumps' wood, the oval face), the crown's limbs broken off short at its
    left end, one more broken stub on its top."""
    def __init__(self, key, s=0.68, seed=None, sun=None, **kw):
        super().__init__(key, s, seed, sun)
        P = dict(LOG, **kw); self.P = P
        rng = self.rng
        r = self.rt
        ph = math.radians(P['phi'])
        d = np.array([math.cos(ph), 0.0, math.sin(ph)])
        up = np.array([0.0, 1.0, 0.0])
        side = unit(np.cross(d, up))                       # toward the viewer for a small phi
        half = P['len_k'] * r
        a, b = -d * half, d * half
        r_a, r_b = r, r * P['taper']
        # a slight bend in the ground plane and up
        mid1 = a + (b - a) / 3 + side * rng.uniform(-1, 1) * P['bend'] * half
        mid2 = a + 2 * (b - a) / 3 + side * rng.uniform(-1, 1) * P['bend'] * half
        C = np.array([a, mid1, mid2, b]) + np.array([0, r, 0])
        g = math.radians(P['phi'] + P['cut'])
        ncut = unit(np.array([math.cos(g), math.sin(math.radians(P['cut_up'])), math.sin(g)]))
        body = self.sc.add(Tube(C, r_a, r_b, seed=7, end1='cut', end0=None, l0=0.0, cut1=ncut, wob=P['wob']))
        body.wood = None
        # the left end frays into broken limbs and splinters (the reference's spikes): thin, long, pointed, out from
        # the end's rim and splayed back from the axis, from the far side over the top to the near side
        body.cap0 = r * 0.8
        if self.is_palm:
            # a palm has no limbs: its broken end frays into the trunk's fibres, many thin short splinters
            for i in range(9):
                thr = math.radians(-120 + i * 30 + rng.uniform(-10, 10))
                rad = math.cos(thr) * up + math.sin(thr) * side
                al = math.radians(rng.uniform(15, 55))
                dirn = unit(-d * math.cos(al) + rad * math.sin(al))
                rs = r * rng.uniform(0.14, 0.2)
                ln = r * rng.uniform(0.7, 1.3)
                p0 = C[0] + d * r * 0.25 + rad * (r - rs) * 0.75
                Q = ground_clamp([p0, p0 + dirn * ln * 0.5, p0 + dirn * ln], [rs, rs * 0.7, 0.4])
                self.sc.add(Tube(Q, rs, 0.3, seed=rng.randint(1, 999), k=1.0, l0=rng.uniform(5, 30)))
            return
        # (angle around the axis from the top toward the viewer, splay from the axis): far-up, up, along, near, low
        fan = [(-80, 62), (-15, 50), (20, 16), (75, 58), (118, 75), (40, 30)][:P['stubs']]
        for i, (th, al) in enumerate(fan):
            thr = math.radians(th + rng.uniform(-12, 12))
            rad = math.cos(thr) * up + math.sin(thr) * side
            al = math.radians(al + rng.uniform(-8, 8))
            dirn = unit(-d * math.cos(al) + rad * math.sin(al))
            rs = r * rng.uniform(*P['stub_r'])
            ln = r * rng.uniform(*P['stub_l'])
            p0 = C[0] + d * r * 0.25 + rad * (r - rs) * 0.7
            p2 = p0 + dirn * ln
            p1 = p0 + dirn * ln * 0.5 + rad * rs * 0.5
            Q = ground_clamp([p0, p1, p2], [rs, rs * 0.7, 0.5])
            self.sc.add(Tube(Q, rs, 0.3, seed=rng.randint(1, 999), k=1.3, l0=rng.uniform(40, 300)))
        if P['top_stub']:
            u = rng.uniform(0.25, 0.4)
            c0 = bez(C, u)
            thr = math.radians(rng.uniform(-50, -15))
            rad = math.cos(thr) * up + math.sin(thr) * side
            rs = r * rng.uniform(0.28, 0.36)
            dirn = unit(rad * 0.85 + d * 0.45)
            p0 = c0 + rad * (r * 0.5)
            p2 = p0 + dirn * r * rng.uniform(1.8, 2.3)
            self.sc.add(Tube([p0, (p0 + p2) / 2, p2], rs, 0.35, seed=rng.randint(1, 999), k=0.8,
                             l0=rng.uniform(40, 300)))


class PolyTube(Tube):
    """A tube through dense points (a polyline: no smoothing), with a radius per point."""
    def __init__(self, pts, radii, **kw):
        pts = np.asarray(pts, float); radii = np.asarray(radii, float)
        super().__init__(pts, float(radii[0]), float(radii[-1]), **kw)
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        self.arc = np.concatenate([[0.0], np.cumsum(seg)])
        self.total = max(1e-6, float(self.arc[-1]))
        self.radii = radii

    def at(self, t):
        a = np.asarray(t, float) * self.total
        return np.stack([np.interp(a, self.arc, self.P[:, i]) for i in range(3)], -1)

    def r(self, t):
        return np.interp(np.asarray(t, float) * self.total, self.arc, self.radii)

    def samples(self, step=0.3):
        n = max(2, int(self.total / step) + 1)
        t = np.linspace(0, 1, n)
        C = self.at(t)
        # tangents smoothed over a couple of px, so that the rings do not twist at the polyline's corners
        T = np.gradient(C, axis=0)
        k = max(1, int(1.5 / step))
        if len(T) > 2 * k + 1:
            ker = np.ones(2 * k + 1) / (2 * k + 1)
            T = np.stack([np.convolve(np.pad(T[:, i], k, mode='edge'), ker, mode='valid') for i in range(3)], -1)
        T = unit(T)
        l = t * self.total + self.l0
        return t, C, T, l


def tree_skeleton(piece, keep=3):
    """The species' limbs as (points, radii, level, seed): the approved skeleton (round 17), or for the cone conifers
    (spruce, fir, larch: their limbs are under the fronds) a whorl of bare branches per tier of fronds."""
    t = piece.t
    out = []
    for lb in t.limbs:
        if lb.level > keep: continue
        ln = lb.length(); n = max(3, int(ln / 1.5) + 1)
        tt = np.linspace(0, 1, n)
        pts = np.array([lb.at(x) for x in tt]); rr = np.array([float(lb.r(x)) for x in tt])
        out.append((pts, rr, lb.level, lb.seed))
    if len(t.limbs) == 1 and hasattr(t, 'tiers'):
        rng = random.Random(piece.seed + 17)
        tl = t.limbs[0]
        y0 = float(tl.at(0.0)[1]); y1 = float(tl.at(1.0)[1])
        for i, tier in enumerate(t.tiers):
            y = tier['y'] - t.cy * 0 if False else tier['y']
            if not (y0 + 4 < y < y1 - 2): continue
            # the trunk's radius there
            tq = min(1.0, max(0.0, (y - y0) / max(1e-6, y1 - y0)))
            rt = float(tl.r(tq))
            nq = rng.choice((3, 4))
            for kq in range(nq):
                a = rng.uniform(0, math.tau) if kq == 0 else a + math.tau / nq + rng.uniform(-0.5, 0.5)
                low = i < 2                                    # the lowest whorls: dead stubs, broken short
                ln = tier['R'] * (rng.uniform(0.12, 0.22) if low else rng.uniform(0.3, 0.52))
                rise = rng.uniform(0.2, 0.55)                  # dead branches point up toward the top
                dr = unit(np.array([math.cos(a), rise, math.sin(a)]))
                c0 = np.array([float(tl.at(tq)[0]), y, float(tl.at(tq)[2])])
                q = np.linspace(0, 1, 6)
                pts = c0[None, :] + dr[None, :] * (ln * q)[:, None]
                pts[:, 0] += np.sin(q * 3 + a) * 0.6           # a little crooked
                r_b = max(0.9, rt * 0.3)
                rr = np.linspace(r_b, 0.5, 6)
                out.append((pts, rr, 1, rng.randint(1, 999)))
    return out


FALLEN = dict(psi=20, spin=None, lift=0.0, keep=2, brk=0.6, splinters=2, sq=1.0, limb_k=0.6, trunk_min=4.5,
              taper=2.2, mode='rigid', bend=0.7, arc=0.6, vein=2.5)

class Fallen(Piece):
    """The reference's fallen trunk (trunk_fallen): the species' own tree snapped above its stump and lying on the
    ground toward the right and away, bare (its limbs flattened onto the ground and spread, those that pointed at the
    viewer a little off the ground), its snapped end splintered (the dark broken wood and long splinters)."""
    def __init__(self, key, s=0.68, seed=None, sun=None, **kw):
        super().__init__(key, s, seed, sun)
        P = dict(FALLEN, **kw); self.P = P
        rng = self.rng
        ps = math.radians(P['psi'])
        f = np.array([math.cos(ps), 0.0, -math.sin(ps)])
        c = np.array([math.sin(ps), 0.0, math.cos(ps)])
        up = np.array([0.0, 1.0, 0.0])
        spin = rng.uniform(0, math.tau) if P['spin'] is None else math.radians(P['spin'])
        cs, sn = math.cos(spin), math.sin(spin)
        if self.is_palm:
            return self._palm(P, f, c, up)
        sk = tree_skeleton(self, P['keep'])
        trunk_pts, trunk_r = sk[0][0], sk[0][1]
        y_b = float(trunk_pts[0, 1]) + P['brk'] * self.r0          # snapped this high over the trunk's start
        self.y_break = y_b
        # a short trunk (the oak's) is drawn longer, so that the fallen tree reads as a trunk with its limbs
        y_top = float(trunk_pts[-1, 1])
        need = P['trunk_min'] * 2 * self.r0
        stretch = max(0.0, need - (y_top - y_b))
        if spin is not None and P['spin'] is None:
            spin = (0.0 if rng.random() < 0.5 else math.pi) + math.radians(rng.uniform(-25, 25))
            cs, sn = math.cos(spin), math.sin(spin)
        ty, tx, tz = trunk_pts[:, 1], trunk_pts[:, 0], trunk_pts[:, 2]
        len_tr = (y_top - y_b) + stretch
        arc_s = rng.choice((-1.0, 1.0))
        def place(pts, rr, is_trunk=False):
            x, y, z = pts[:, 0], pts[:, 1], pts[:, 2]
            along = y - y_b
            along = along + np.clip((y - y_b) / max(1e-6, y_top - y_b), 0, 1) * stretch
            if P['mode'] == 'flat':
                xr = x * cs - z * sn; zr = x * sn + z * cs
                h = rr + P['lift'] * np.maximum(0.0, zr)
                return along[:, None] * f[None, :] + (xr * P['sq'])[:, None] * c[None, :] + h[:, None] * up[None, :]
            # rigid: the tree turned over onto its side; offsets from the (straightened) trunk keep their way, those
            # that would go into the ground bend over onto it, sideways
            x0 = np.interp(y, ty, tx); z0 = np.interp(y, ty, tz)
            dx, dz = x - x0, z - z0
            a = dx * cs - dz * sn; b = dx * sn + dz * cs
            rt_ = np.interp(y, ty, trunk_r)
            h = rt_ + a
            if is_trunk: h = rr.copy(); b = b * 0 + (x0 - tx[0]) * 0.5
            low = h < rr
            sgn = np.where(b >= 0, 1.0, -1.0)
            b = np.where(low, b + sgn * (rr - h) * P['bend'], b)
            h = np.where(low, rr, h)
            # the trunk lies in a gentle arc (the reference's is bent), the limbs follow it
            b = b + arc_s * self.r0 * P['arc'] * np.sin(math.pi * np.clip(along / max(1e-6, len_tr), 0, 1))
            return along[:, None] * f[None, :] + (b * P['sq'])[:, None] * c[None, :] + h[:, None] * up[None, :]
        # the trunk from the break up; its snapped end narrows into the splinters
        keep = trunk_pts[:, 1] >= y_b
        i0 = max(0, int(np.argmax(keep)) - 1)
        tp, tr = trunk_pts[i0:].copy(), trunk_r[i0:].copy()
        tp[0, 1] = y_b
        # denser points near the break for the taper
        ys_ = np.r_[np.linspace(y_b, min(y_top, y_b + P['taper'] * self.r0 * 1.5), 8)[:-1], tp[1:, 1]]
        ys_ = np.unique(np.clip(ys_, y_b, None))
        tp = np.stack([np.interp(ys_, tp[:, 1], tp[:, 0]), ys_, np.interp(ys_, tp[:, 1], tp[:, 2])], -1)
        tr = np.interp(ys_, np.r_[y_b, trunk_pts[i0 + 1:, 1]], np.r_[trunk_r[i0], trunk_r[i0 + 1:]])
        self.rb = float(tr[0])
        u = np.clip((ys_ - y_b) / (P['taper'] * self.r0), 0, 1)
        tr_t = tr * (0.45 + 0.55 * np.sqrt(u))
        Q = place(tp, tr_t, is_trunk=True)
        # the narrowed part lies on the ground too
        Q[:, 1] = tr_t
        body = self.sc.add(PolyTube(Q, tr_t, seed=7, end0='broken', l0=P['brk'] * self.r0, wob=0.07))
        if self.key != 'birch': body.vein = P['vein']          # birch keeps its own white bark with black marks
        for pts, rr, lev, sd in sk[1:]:
            if pts[0, 1] < y_b: continue
            rl = np.maximum(0.6, rr * P['limb_k'])
            lb_ = self.sc.add(PolyTube(place(pts, rl), rl, seed=sd, l0=rng.uniform(20, 200)))
            if self.key != 'birch' and rl.max() >= 2.2: lb_.vein = P['vein']
        # splinters at the snapped end: a long sliver along the ground and a shorter one up and back
        r = self.rb
        e0 = Q[0]
        for i in range(P['splinters']):
            th = math.radians([160, 10][i % 2] + rng.uniform(-15, 15))
            rad = math.cos(th) * up + math.sin(th) * c
            ln = r * [2.4, 1.3][i % 2] * rng.uniform(0.85, 1.15)
            rs = r * [0.3, 0.22][i % 2]
            al = math.radians([8, 35][i % 2])
            dirn = unit(-f * math.cos(al) + rad * math.sin(al))
            p0 = e0 + f * r * 0.8 + rad * (0.45 * r - rs) * 0.5
            Qs = ground_clamp([p0, p0 + dirn * ln * 0.5, p0 + dirn * ln], [rs, rs * 0.6, 0.4])
            self.sc.add(Tube(Qs, rs, 0.3, seed=rng.randint(1, 999), k=1.2, l0=rng.uniform(5, 60)))

    def _palm(self, P, f, c, up):
        p = self.palm_obj; tr = p.trunk
        rng = self.rng
        tt = np.linspace(0, 1, 60)
        Cc = tr.centre(tt); rr = tr.radius(tt)
        y_b = P['brk'] * self.r0
        keep = Cc[:, 1] >= y_b
        Cc, rr = Cc[keep], rr[keep]
        along = Cc[:, 1] - y_b
        Q = along[:, None] * f[None, :] + Cc[:, 0:1] * c[None, :] * 0.6 + rr[:, None] * up[None, :]
        self.rb = float(rr[0])
        self.sc.add(PolyTube(Q, rr, seed=7, end0='broken', wob=0.03))
        # the crown rotted away: the bases of its leaf stalks stick out of the top, broken short (like the log's end)
        top = Q[-1]
        rt = float(rr[-1])
        d_ = unit(Q[-1] - Q[-4])
        side_ = unit(np.cross(d_, up))
        for i in range(7):
            th = math.radians(-120 + i * 40 + rng.uniform(-12, 12))
            rad = math.cos(th) * up + math.sin(th) * side_
            al = math.radians(rng.uniform(25, 60))
            dirn = unit(d_ * math.cos(al) + rad * math.sin(al))
            rs = rt * rng.uniform(0.28, 0.38)
            ln = rt * rng.uniform(1.4, 2.4)
            p0 = top - d_ * rt * 0.3 + rad * (rt - rs) * 0.6
            Qs = ground_clamp([p0, p0 + dirn * ln * 0.5, p0 + dirn * ln], [rs, rs * 0.7, 0.4])
            self.sc.add(Tube(Qs, rs, 0.35, seed=rng.randint(1, 999), k=1.1, l0=rng.uniform(5, 40)))
        r = self.rb; e0 = Q[0]
        for i in range(3):
            th = math.radians([200, 20, 110][i] + rng.uniform(-20, 20))
            rad = math.cos(th) * up + math.sin(th) * c
            ln = r * [1.6, 1.1, 0.8][i]; rs = r * 0.22
            dirn = unit(-f * 0.9 + rad * 0.4)
            p0 = e0 + f * r * 0.4 + rad * (r - rs) * 0.7
            self.sc.add(Tube(ground_clamp([p0, p0 + dirn * ln * 0.5, p0 + dirn * ln], [rs, rs * 0.6, 0.4]), rs, 0.3,
                             seed=rng.randint(1, 999), k=1.0))
