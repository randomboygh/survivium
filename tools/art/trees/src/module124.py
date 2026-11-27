# Conifer fronds ("лапы") of reference 124 (SLYNYRD, conifer tree) as modules.
# The fronds are cut pixel-exact from the reference's drawing frame 43 (the 25 fronds laid around the tree before
# they are put on it): roles O = outline and the needle strokes (the reference's 1d5217), B = body (4a6c24).
# Each frond has a rachis: from its root (the end toward the trunk; the ring of fronds points outward) to its tip.
# Tones (steps of a 7-colour ramp, darkest 0 .. lightest 6), the rule read off the reference's four sample
# fronds (its panel: frond 4 shade side, 8 front, 12 lit side, 21 top; rows = its three shading passes):
#   b = the frond's step from its place in the crown (normal . sun, in bands, like our leaf modules);
#   body on the half of the frond facing the sun = b, on the half turned away = b - 1 (the reference splits a
#   frond along its rachis, one step apart); outline and needle strokes = body - 1;
#   the root third under the tier above = -1 more (the reference darkens the root end), the tip on the sun
#   half of a lit frond = +1 more (its row 3).
import json, math, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
REF_RAMP = ['06051c', '2d1952', '0d3634', '1d5217', '4a6c24', '528635', '629f54']
CENTRE = (128.0, 100.0)            # the middle of the ring of fronds in frame 43 (native px)
SAMPLES = (4, 8, 12, 21)           # the fronds of the reference's panel, in its column order
FRONDS = json.load(open(os.path.join(HERE, 'fronds43.json')))

def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

class Frond:
    def __init__(self, i, d=None):
        d = d or FRONDS[i]
        self.i = i
        self.rows = d['rows']
        self.role = np.array([[{'.': -1, 'O': 0, 'B': 1}[c] for c in r] for r in self.rows])
        self.h, self.w = self.role.shape
        self.x0, self.y0 = d['x'], d['y']
        ys, xs = np.nonzero(self.role >= 0)
        P = np.stack([xs + 0.5, ys + 0.5], 1)
        m = P.mean(0)
        _, _, vt = np.linalg.svd(P - m)
        ax = vt[0]
        # the root is the end nearer the ring's middle
        c = np.array(CENTRE) - (np.array([self.x0, self.y0]) + m)
        if ax @ c > 0: ax = -ax                       # ax points root -> tip (outward)
        t = (P - m) @ ax
        lo, hi = np.percentile(t, 3), np.percentile(t, 97)
        self.u = np.full(self.role.shape, np.nan)
        self.u[ys, xs] = np.clip((t - lo) / (hi - lo), 0, 1)
        side = (P - m) @ np.array([-ax[1], ax[0]])     # + = to the right of the rachis (x right, y down)
        self.side = np.zeros(self.role.shape); self.side[ys, xs] = side
        self.ax = ax
        self.angle = math.degrees(math.atan2(-ax[1], ax[0]))     # screen angle root -> tip, up = +90
        self.root = m + ax * lo                        # continuous pixel coords (x, y) of the rachis ends
        self.tip = m + ax * hi
        self.length = float(hi - lo)
        self.flip = False

    def mirrored(self):
        f = Frond.__new__(Frond)
        f.__dict__.update(self.__dict__)
        f.role = self.role[:, ::-1]; f.u = self.u[:, ::-1]; f.side = -self.side[:, ::-1]
        f.ax = np.array([-self.ax[0], self.ax[1]])
        f.angle = math.degrees(math.atan2(-f.ax[1], f.ax[0]))
        f.rows = [r[::-1] for r in self.rows]
        f.root = np.array([self.w - self.root[0], self.root[1]])
        f.tip = np.array([self.w - self.tip[0], self.tip[1]])
        f.flip = True
        return f

    def tones(self, b, sun2=(0.58, -0.82), root=True, tip=True, split=True):
        """Steps of every pixel (-9 = empty) for a frond whose sun-facing half has body step b.
        sun2 = the sun's direction on the screen (x right, y down)."""
        s = np.array(sun2, float); s /= np.linalg.norm(s)
        nrm = np.array([-self.ax[1], self.ax[0]])            # the right side's normal
        k = float(nrm @ s)                                     # > 0: the right half faces the sun
        t = np.where(self.role == 1, b, b - 1).astype(float)
        if split:
            if abs(k) > 0.25:
                away = (self.side * np.sign(k)) < 0
            else:                                              # the rachis points along the light: the far end is lit
                away = (self.u < 0.45) if float(self.ax @ s) > 0 else (self.u > 0.55)
            t = np.where(away, t - 1, t)
        else:
            away = np.zeros(self.role.shape, bool)
        if root: t = np.where(self.u < 0.3, t - 1, t)
        if tip and b >= 4: t = np.where((self.u > 0.62) & ~away, t + 1, t)
        t = np.where(self.role >= 0, np.clip(t, 0, 6), -9)
        return t

def all_fronds():
    return [Frond(i) for i in range(len(FRONDS))]

def paint(t, ramp, bg='9ba38c'):
    rp = np.array([hexc(h) for h in ramp], np.uint8)
    img = np.zeros(t.shape + (3,), np.uint8); img[:] = hexc(bg)
    m = t > -9
    img[m] = rp[t[m].astype(int)]
    return img

def all_with_mirrors():
    out = []
    for f in all_fronds():
        out += [f, f.mirrored()]
    return out
