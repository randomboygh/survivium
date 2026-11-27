# The crown from the reference-122 modules (module5): the hemisphere of render2 (a dark silhouette,
# rings of modules from the bottom diameter up to the top, then the trunk and the cast shadow),
# each module drawn as the reference draws it: its dark disc, then its leaves, lit per leaf.
import sys, math, numpy as np
sys.path.insert(0, '.')
import render2, module5 as M
from render2 import RAMP, hexc, band

LAYOUTS = (0, 1, 5, 17)                      # A = the reference's, B, C, D the new ones
MODS = [M.module(s, flip=f) for f in (False, True) for s in LAYOUTS]

class Tree(render2.Tree):
    def __init__(self, sun, **kw):
        # the reference crown's proportions (about 100 x 75 px with its leaves)
        kw.setdefault('rx', 40); kw.setdefault('rz', 22); kw.setdefault('hc', 21)
        super().__init__(sun, **kw)

    def module_at(self, img, p, n, i):
        mod = MODS[(i * 5 + self.seed) % len(MODS)]
        t = M.tones(mod, self.light2)
        d = float(n @ self.L)
        # the reference's three module lights, by the crown's facing to the sun: light 4, half 3,
        # shade 2 (its tones overall then match the reference's crown: mean 2.9 against 2.8)
        base = max(2, 3 + band(d) - (1 if self.cloudy else 0))
        sx, sy = self.proj(p)
        cx = M.S - 1 - M.C[0] if mod['flip'] else M.C[0]
        X0 = int(round(sx)) - cx; Y0 = int(round(sy)) - M.C[1]
        dsk = M.disc(mod['flip'])
        for yy in range(M.S):
            for xx in range(M.S):
                v = t[yy, xx]
                if v <= -9:
                    if not dsk[yy, xx]: continue
                    v = -1                           # the disc, a step under the leaves' body
                X, Y = X0 + xx, Y0 + yy
                if 0 <= X < self.W and 0 <= Y < self.H:
                    c = base + v
                    if c > 5 and d < 0.85: c = 5          # the palest yellow only on the top-lit modules
                    img[Y, X] = hexc(RAMP[max(0, min(len(RAMP) - 1, c))])
