# Round 6: the crown in the game's own colours and the trunk of reference 122.
# Leaf ramp: 7 steps sampled from today's in-game oak (chop-tree shot, summer day), darkest to
# lightest, in the game's hue path (blue-grey shade -> grey-green -> yellow-green light). Other
# species and seasons: the game's own math (tint x season, then 0.6 saturation, leaves.gdshader).
# Trunk: the reference's stage-4 trunk cut from its sheet as ramp indices (b c d e = 0..3),
# its top line repeated upward under the crown, mirrored when the sun is on the left.
import sys, numpy as np
sys.path.insert(0, '.')
import render2, render5
from render2 import hexc
from PIL import Image

REF_RAMP = list(render2.RAMP)
# steps 0..4 at the quantiles where the crown uses them (so the crown's share of each tone matches the
# game's), 5..6 the game's lit and warm-highlight greens
OAK_RAMP = ['162c32', '223e42', '3b5643', '496856', '5e816b', '80a16d', '98bc76']
OAK_TINT = np.array([0x53, 0x7f, 0x47]) / 255.0          # mean of oak's tints
SEASON = {'spring': (0.95, 1.1, 0.8), 'summer': (1, 1, 1), 'autumn': (2.2, 1.05, 0.55), 'late autumn': (1.3, 0.9, 0.7)}
GREY = np.array([0.3, 0.55, 0.15])
SAT = 0.6
REF_BARK = ['13051b', '2d1952', '4d1852', '863945']
OUR_BARK = ['1b130f', '3d2a1e', '62452f', '946b4b']       # in-game oak trunk, shade to light
GRASS, GRASS_SHADE = '6fa143', '4c6c2d'                    # in-game lit grass and grass in a tree's shadow

def ramp_for(season='summer', tint=None):
    k = np.array(SEASON[season]) * (np.ones(3) if tint is None else np.array(tint) / OAK_TINT)
    out = []
    for h in OAK_RAMP:
        c = np.array(hexc(h)) / 255.0
        g = c @ GREY
        raw = g + (c - g) / SAT                     # undo the game's toning toward grey
        raw = raw * k
        g2 = raw @ GREY
        c2 = np.clip(g2 + (raw - g2) * SAT, 0, 1)
        out.append('%02x%02x%02x' % tuple((c2 * 255).round().astype(int)))
    return out

def _trunk_map():
    a = np.array(Image.open('../ref/c_n.png').convert('RGB'))[200:224, 170:216]
    idx = {h: i for i, h in enumerate(REF_BARK)}
    m = np.full(a.shape[:2], -1, int)
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            h = '%02x%02x%02x' % tuple(a[y, x])
            if h in idx: m[y, x] = idx[h]
    ys = np.where((m >= 0).any(1))[0]; xs = np.where((m >= 0).any(0))[0]
    m = m[ys[0]:ys[-1] + 1, xs[0]:xs[-1] + 1]
    top = m[0].copy()                                        # the bark lines, carried up under the crown
    return np.vstack([np.tile(top, (12, 1)), m])

TRUNK = _trunk_map()
FOOT = 17 + 12      # row of the barrel's foot in TRUNK (stage row 217..219 -> its ground line)

class Tree(render5.Tree):
    def __init__(self, sun, season='summer', ramp=None, bark=None, trunk_ref=False, **kw):
        kw.setdefault('step', 15); kw.setdefault('hstep', 15)
        super().__init__(sun, **kw)
        self.ramp = ramp or ramp_for(season)
        self.bark = bark or OUR_BARK
        self.trunk_ref = trunk_ref

    def module_at(self, img, p, n, i):
        old = render5.RAMP
        render5.RAMP = self.ramp
        try: super().module_at(img, p, n, i)
        finally: render5.RAMP = old

    def silhouette(self, img):
        old = render2.RAMP; render2.RAMP = self.ramp
        try: super().silhouette(img)
        finally: render2.RAMP = old

    def trunk_layer(self):
        im = np.zeros((self.H, self.W, 3), np.uint8); mask = np.zeros((self.H, self.W), bool)
        t = TRUNK[:, ::-1] if self.light2[0] < 0 else TRUNK
        h, w = t.shape
        X0 = self.ox - w // 2; Y0 = self.oy - FOOT
        for y in range(h):
            for x in range(w):
                v = t[y, x]
                if v < 0: continue
                X, Y = X0 + x, Y0 + y
                if 0 <= X < self.W and 0 <= Y < self.H:
                    im[Y, X] = hexc(self.bark[v]); mask[Y, X] = True
        return im, mask

    def shadow_mask(self):
        m = super().shadow_mask()
        return m

def picture(tree, ground=GRASS, shade=GRASS_SHADE):
    """The finished tree on the ground, its shadow the ground's own darker colour."""
    stages = list(tree.stages(ground=ground))
    img = stages[-1][1]
    sh = tree.shadow_mask()
    # the base draws the shadow in render2.SHADOW; repaint it in the ground's own shade
    sel = np.all(img == np.array(hexc(render2.SHADOW), np.uint8), axis=2) & sh
    img[sel] = hexc(shade)
    return img
