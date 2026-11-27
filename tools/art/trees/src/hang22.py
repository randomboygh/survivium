# Round 22 sandbox: hanging (weeping) leaf modules for the willow from reference 123's blade brushes.
import json, math, numpy as np
import render7 as R7, render6 as R6, sheet123 as S3
BR = json.load(open(__import__('os').path.join(__import__('os').path.dirname(__file__), 'leaves123.json')))['blades']['brushes']
WILLOW = R7.species_tint('#4e8a3e', '#56903f', '#48823a')
WR = R7.contrast(R6.ramp_for('summer', WILLOW), 1.3)

def turn(rows, q, m):
    px = [(x, y, c) for y, r in enumerate(rows) for x, c in enumerate(r) if c != '.']
    out = []
    for x, y, c in px:
        if m: x = -x
        for _ in range(q): x, y = -y, x
        out.append((x, y, c))
    mx = min(p[0] for p in out); my = min(p[1] for p in out)
    return [(x - mx, y - my, c) for x, y, c in out]

def mirror(px):
    mx = max(p[0] for p in px)
    return [(mx - x, y, c) for x, y, c in px]

class Brush:
    """A leaf: its pixels, base (stem end) and tip, and its way (screen angle, y down)."""
    def __init__(self, px, name):
        self.px, self.name = px, name
        P = np.array([(x, y) for x, y, _ in px], float)
        H = np.array([(x, y) for x, y, c in px if c == 'H'], float)
        c = P.mean(0)
        u, s, vt = np.linalg.svd(P - c)
        ax = vt[0]
        if (H.mean(0) - c) @ ax < 0: ax = -ax          # the axis points to the tip (the heart's end)
        proj = (P - c) @ ax
        self.tip = c + ax * proj.max(); self.base = c + ax * proj.min()
        self.way = math.atan2(ax[1], ax[0])
        self.w = int(P[:, 0].max()) + 1; self.h = int(P[:, 1].max()) + 1

B = {}
def _add(name, px): B[name] = Brush(px, name)
_add('shield', turn(BR[1], 0, 0))
_add('drop_l', turn(BR[0], 0, 0)); _add('drop_r', mirror(turn(BR[0], 0, 0)))
_add('steep_l', turn(BR[2], 1, 1)); _add('steep_r', mirror(turn(BR[2], 1, 1)))
_add('long_l', turn(BR[3], 1, 1)); _add('long_r', mirror(turn(BR[3], 1, 1)))
_add('flat_r', turn(BR[2], 0, 1)); _add('flat_l', mirror(turn(BR[2], 0, 1)))
_add('flat2_r', turn(BR[3], 0, 1)); _add('flat2_l', mirror(turn(BR[3], 0, 1)))

def nearest(angle, names=None):
    """The brush whose way is nearest a screen angle (radians, y down)."""
    names = names or list(B)
    return min(names, key=lambda n: abs(math.remainder(B[n].way - angle, math.tau)))

def place(name, bx, by):
    """A leaf with its base on (bx, by): (name, x0, y0)."""
    b = B[name]
    return (name, int(round(bx - b.base[0])), int(round(by - b.base[1])))

def raster(leaves, W, H):
    """leaf id and role maps, the leaves drawn in list order."""
    leaf = -np.ones((H, W), int); role = np.full((H, W), '.', object)
    for k, (name, x0, y0) in enumerate(leaves):
        for x, y, c in B[name].px:
            X, Y = x0 + x, y0 + y
            if 0 <= X < W and 0 <= Y < H: leaf[Y, X] = k; role[Y, X] = c
    return leaf, role
