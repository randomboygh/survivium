# The tree assembled as the reference does it, on a hemisphere: a dark silhouette, then rings of
# leaf modules from the bottom diameter up to the top, then the trunk and the cast shadow.
# Each step is a layer, so the stages can be shown one by one.
import numpy as np, math, random, sys
sys.path.insert(0, '.')
from module3 import module, tones
import render  # trunk, roots, branches, shadow helpers and colours

hexc = render.hexc
RAMP = ['13051b', '2d1952', '3c3787', '386386', '368578', '629f54', 'a1b875']
TRUNK = render.TRUNK
SHADOW = '3c3787'
MODS = [module(s) for s in (3, 7, 12, 21, 30, 44)]

def norm(v):
    v = np.asarray(v, float); return v / np.linalg.norm(v)

def band(d):
    return 1 if d > 0.7 else (0 if d > 0.4 else (-1 if d > 0.05 else -2))

class Tree:
    def __init__(self, sun, W=170, H=150, rx=44, rz=24, hc=22, cy=48, step=13.5, seed=1, cloudy=False, hstep=None):
        self.L = norm(sun); self.W, self.H = W, H
        self.ox, self.oy = W // 2, H - 26
        self.rx, self.rz, self.hc, self.cy = rx, rz, hc, cy
        self.seed, self.cloudy = seed, cloudy
        L = self.L
        self.light2 = norm((L[0], L[2] - L[1]))   # the sun's way on the screen (y down)
        # rings: elevation steps from the bottom diameter to the top
        self.rings = []
        rng = random.Random(seed)
        n_rings = max(2, round((math.pi / 2) * (rx + hc) / 2 / step))
        for k in range(n_rings + 1):
            phi = (math.pi / 2) * k / n_rings
            r = math.cos(phi)
            circ = math.pi * (3 * (rx + rz) - math.sqrt((3 * rx + rz) * (rx + 3 * rz))) * r
            n = max(1, round(circ / (hstep or step))) if k < n_rings else 1   # hstep: spacing along a ring
            off = rng.uniform(0, math.tau)
            ring = []
            for i in range(n):
                th = off + math.tau * i / n
                p = np.array([rx * r * math.cos(th), hc * math.sin(phi), rz * r * math.sin(th)])
                nn = norm(np.array([p[0] / rx ** 2, p[1] / hc ** 2, p[2] / rz ** 2]))
                ring.append((p, nn))
            ring.sort(key=lambda t: t[0][2])      # far side first
            self.rings.append(ring)

    def proj(self, p):
        return self.ox + p[0], self.oy + p[2] - (p[1] + self.cy)

    def blank(self, ground='8da38c'):
        img = np.zeros((self.H, self.W, 3), np.uint8); img[:] = hexc(ground); return img

    def silhouette(self, img):
        """The dark shape under the modules: the hemisphere's outline (the union of its rings'
        ellipses on the screen), filled with ramp 1, a little inside the modules' reach."""
        k = 0.92
        for y in range(self.H):
            for x in range(self.W):
                sx, sy = x - self.ox, y - self.oy + self.cy
                for j in range(0, 21):
                    phi = (math.pi / 2) * j / 20
                    c = math.cos(phi)
                    if c < 0.05: continue
                    ey = sy + self.hc * math.sin(phi)
                    if (sx / (self.rx * c * k)) ** 2 + (ey / (self.rz * c * k)) ** 2 < 1:
                        img[y, x] = hexc(RAMP[1]); break

    def module_at(self, img, p, n, i):
        mod = MODS[(i * 5 + self.seed) % len(MODS)]
        t = tones(mod, self.light2)
        d = float(n @ self.L)
        base = 2 + band(d) - (1 if self.cloudy else 0)
        sx, sy = self.proj(p)
        S = mod['size']; X0 = int(round(sx)) - S // 2; Y0 = int(round(sy)) - S // 2
        for yy in range(S):
            for xx in range(S):
                if t[yy, xx] <= -9: continue
                X, Y = X0 + xx, Y0 + yy
                if 0 <= X < self.W and 0 <= Y < self.H:
                    img[Y, X] = hexc(RAMP[max(0, min(len(RAMP) - 1, base + t[yy, xx]))])

    def trunk_layer(self):
        """Trunk and roots alone (a mask and colours), drawn under the crown."""
        bg = np.zeros((self.H, self.W, 3), np.uint8); bg[:] = (1, 2, 3)
        im = render.draw_tree(tuple(self.L), W=self.W, H=self.H, ground='010203', bare=True, snow=0,
                              trunk_only=True, oy=self.oy, cy=self.cy)
        mask = np.any(im != np.array([1, 2, 3], np.uint8), axis=2)
        return im, mask

    def shadow_mask(self):
        L = self.L; m = np.zeros((self.H, self.W), bool)
        if L[1] < 0.1 or self.cloudy: return m
        for y in range(self.H):
            for x in range(self.W):
                gx, gz = x - self.ox, y - self.oy
                hit = False
                for h in range(int(self.cy), int(self.cy + self.hc) + 1, 2):
                    px = gx + L[0] / L[1] * h; pz = gz + L[2] / L[1] * h
                    rr = (px / self.rx) ** 2 + (pz / self.rz) ** 2
                    lim = 1 - ((h - self.cy) / self.hc) ** 2
                    if rr < lim * (0.92 + 0.08 * ((x // 2 * 7 + y // 2 * 13) % 5) / 4):
                        hit = True; break
                if not hit:
                    # the trunk's own shadow, a band from its foot
                    for h in range(0, int(self.cy), 2):
                        px = gx + L[0] / L[1] * h; pz = gz + L[2] / L[1] * h
                        if abs(px) < 11 and abs(pz) < 6: hit = True; break
                m[y, x] = hit
        return m

    def stages(self, ground='8da38c', per_module=False):
        """Pictures of the tree as it is put together: yields (label, image)."""
        crown = self.blank(ground); crown_mask = np.zeros((self.H, self.W), bool)
        trunk, tmask = self.trunk_layer()
        shadow = self.shadow_mask()
        def compose(with_trunk, with_shadow):
            img = self.blank(ground)
            if with_shadow: img[shadow] = hexc(SHADOW)
            if with_trunk: img[tmask] = trunk[tmask]
            cm = np.any(crown != np.array(hexc(ground), np.uint8), axis=2)
            img[cm] = crown[cm]
            return img
        self.silhouette(crown)
        yield ('silhouette', compose(False, False))
        i = 0
        for k, ring in enumerate(self.rings):
            for p, n in ring:
                self.module_at(crown, p, n, i); i += 1
                if per_module: yield ('ring %d' % k, compose(False, False))
            if not per_module: yield ('ring %d' % k, compose(False, False))
        yield ('trunk', compose(True, False))
        yield ('shadow', compose(True, True))
