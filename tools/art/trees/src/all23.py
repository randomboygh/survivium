# Round 23: every approved tree of the redraw on one sheet (mockup, no game code).
# Run from the merged src folder (all rounds' src copied in order src, round3 .. round22, round22-trunks, round22-willow;
# ref/ beside it as for round 22: c_n, l_n, k_n, frames124.npy, bark/ with pine_bark.png, maple_row.npy, fan_*/feather_*.npy).
#   all23.py render            -> ../cache23/<key>_<s>.npz   (keyed pictures: ground KEY_G, shadow KEY_S; foot ox, oy)
# What each tree is (all as approved, nothing new):
#   deciduous = trees22.tree (round 19 species, round 17 limbs + round 16 crowns, feet by size), maples with the
#   round 20 maple leaves (red maple in the reference's colours), willow = willow22.willow (round 22 defaults),
#   conifers = trees22.conifer (round 21 defaults, feet by size), palms = palmtree22.Palm (round 22, soft 2).
import os, sys, time, numpy as np
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '..', 'cache23')
KEY_G, KEY_S = 'ff00ff', '00ffff'
SIZES = (0.42, 0.68, 1.0)
MARGIN = 66        # px of canvas under the foot (render7 keeps 26, which cuts the long shadows' bottom off)

def _taller():
    """render7.Tree puts the foot 26 px over the canvas' bottom; the shadows reach ~31 px under it. Move the foot up
    (the tree's pixels stay the same: checked on oak and spruce), callers pass H + 40."""
    import render7 as R
    if getattr(R.Tree, '_taller', False): return
    orig = R.Tree.__init__
    def init(self, *a, **kw):
        orig(self, *a, **kw)
        self.oy = self.H - MARGIN
    R.Tree.__init__ = init
    R.Tree._taller = True

# (key, label, group); the order of the sheet
TREES = [
    ('oak', 'дуб', 'листья 122'),
    ('linden', 'липа', 'точки'), ('birch', 'берёза', 'точки'), ('acacia', 'акация', 'точки'),
    ('mangrove', 'мангр', 'точки'),
    ('apple', 'яблоня', 'круглые'), ('cherry', 'вишня', 'круглые'), ('poplar', 'тополь', 'круглые'),
    ('ceiba', 'сейба', 'круглые'),
    ('maple', 'клён', 'кленовые'), ('red_maple', 'красный клён', 'кленовые'),
    ('bird_cherry', 'черёмуха', 'клинки'), ('rowan', 'рябина', 'клинки'), ('willow', 'ива', 'клинки, свисают'),
    ('deadwood', 'сухое дерево', 'без листьев'),
    ('spruce', 'ель', 'хвоя 124'), ('fir', 'пихта', 'хвоя 124'), ('larch', 'лиственница', 'хвоя 124'),
    ('pine', 'сосна', 'хвоя 124'),
    ('palm', 'пальма (перистая)', 'пальма'), ('fan_palm', 'веерная пальма (новая)', 'пальма'),
]

def build(key, s):
    """The approved tree object for a species key and a size."""
    _taller()
    if key in ('palm', 'fan_palm'):
        import palmtree22 as PT
        return PT.Palm('feather' if key == 'palm' else 'fan', s)
    if key == 'willow':
        import willow22 as W22
        return W22.willow(s, H=440)
    import trees22 as TR, conifer21 as C, species19 as SP
    if key in C.CSPEC:
        return TR.conifer(key, s, H=460)
    if key in ('maple', 'red_maple'):
        import module_maple            # installs the maple leaf style into module123
        from sheet20 import RED
        SP.SPEC[key] = SP.SPEC[key][:5] + ('maple',) + SP.SPEC[key][6:]
        return TR.tree(key, s, H=440, **({'ramp': RED} if key == 'red_maple' else {}))
    return TR.tree(key, s, H=440)

def render_one(job):
    key, s = job
    out = os.path.join(CACHE, '%s_%.2f.npz' % (key, s))
    if os.path.exists(out): return out, 0.0
    t0 = time.time()
    t = build(key, s)
    img = t.render(ground=KEY_G, shade=KEY_S)
    np.savez_compressed(out, img=img, ox=t.ox, oy=t.oy)
    return out, time.time() - t0

def load(key, s):
    d = np.load(os.path.join(CACHE, '%s_%.2f.npz' % (key, s)))
    return d['img'], float(d['ox']), float(d['oy'])

if __name__ == '__main__':
    os.makedirs(CACHE, exist_ok=True)
    keys = sys.argv[2].split(',') if len(sys.argv) > 2 else [k for k, *_ in TREES]
    jobs = [(k, s) for k in keys for s in SIZES]
    with Pool(4) as p:
        for out, dt in p.imap_unordered(render_one, jobs):
            print('%-40s %.1fs' % (os.path.basename(out), dt), flush=True)
