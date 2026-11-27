# Round 23 step 2: the spring sheet (mockup, no game code). Run from the merged src folder (setup_run.sh):
#   spring23.py render [slot,slot..]   -> ../cache23s/<slot>_<s>.npz (keyed: ground KEY_G, shadow KEY_S)
#   spring23.py sheet <out.png> [k=2] [row width 1020]
# Every species of sheet 87 in spring by the game's rules: the spring tint of the leaves (sky.gd FOLIAGE[SPRING]
# 0.95, 1.1, 0.8, render6.SEASON['spring']; evergreens take only 0.15 of it: spruce, fir and pine left as they are),
# and blossom on the user's five (2026-11-24 «2. Б»): cherry pink (trees.yaml e396b6), bird cherry white (f4f2ea),
# apple white-pink, rowan creamy white, acacia cream. Blossom as the game draws it (leaves.gdshader: over most of
# the leaves, each leaf by its own number, lit like them) and as the reference's pink trees show it
# (references/user-palms-snow.jpg, bottom left): the blossom's own ramp step for step, and little light crosses of
# flowers on the lit side.
import os, sys, time, math, random, numpy as np
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, '..', 'cache23s')
KEY_G, KEY_S = 'ff00ff', '00ffff'
SIZES = (0.42, 0.68, 1.0)

# blossom ramps, dark -> light, the steps of a leaf ramp (0 outline .. 4 lit body .. 6 highlight)
BLOOM = {
    'cherry':      ['4a2338', '6e3552', '9a5277', 'c27597', 'e396b6', 'f0b6cf', 'fad7e6'],   # pink, trees.yaml e396b6
    'bird_cherry': ['39403a', '5a6358', '8a9384', 'bcc2b2', 'e2e4d6', 'f4f2ea', 'fffef8'],   # white, trees.yaml f4f2ea
    'apple':       ['4a3040', '6e4c5c', '9c7685', 'c9a2ae', 'e8c8d0', 'f6e0e5', 'fff4f6'],   # white-pink
    'rowan':       ['45402c', '6b6448', '978e6c', 'c3b994', 'e2d9b6', 'f2ecd2', 'fdfaea'],   # creamy white
    'acacia':      ['4a4426', '716a3a', '9e955a', 'cbc07e', 'e8dc9c', 'f6eebd', 'fffbe0'],   # cream puffs
}
BLOOM_NAME = {'cherry': 'цветёт розовым', 'bird_cherry': 'цветёт белым', 'apple': 'цветёт бело-розовым',
              'rowan': 'цветёт кремовым', 'acacia': 'цветёт кремовым'}
SHARE = 0.8                 # of the leaves in blossom (the game: blossom_amount x 0.75 at full bloom)
CROSS = dict(every=26, lo=3, hi=4)   # one little cross of flowers per this many blossom pixels of steps lo..hi


def spring_ramp(ramp, k=1.0):
    """A ramp as the game's spring tint makes it: undo the toning toward grey, times the tint, tone again."""
    import render6 as R6
    from render2 import hexc
    tint = 1 + (np.array(R6.SEASON['spring']) - 1) * k
    out = []
    for h in ramp:
        c = np.array(hexc(h)) / 255.0
        g = c @ R6.GREY
        raw = (g + (c - g) / R6.SAT) * tint
        g2 = raw @ R6.GREY
        c2 = np.clip(g2 + (raw - g2) * R6.SAT, 0, 1)
        out.append('%02x%02x%02x' % tuple((c2 * 255).round().astype(int)))
    return out


def _bloom0(self):
    if getattr(self, '_bloom_i0', None) is None:
        from render2 import hexc
        self._bloom_i0 = len(self.ramp)
        self.ramp = list(self.ramp) + [np.array(hexc(h), np.uint8) for h in BLOOM[self.bloom]]
    return self._bloom_i0


def bloom_pixels(self, p, n, mod, Y, X, c):
    """Turn the blossoming leaves of one module to the blossom's ramp, step for step."""
    if 'leaf' not in mod or len(X) == 0: return c
    import render7 as R
    M = R.M
    sx, sy = self.proj(p)
    cx = M.S - 1 - M.C[0] if mod['flip'] else M.C[0]
    X0 = int(round(sx)) - cx; Y0 = int(round(sy)) - M.C[1]
    ly, lx = Y - Y0, X - X0
    ok = (ly >= 0) & (ly < mod['leaf'].shape[0]) & (lx >= 0) & (lx < mod['leaf'].shape[1])
    leaf = np.full(len(X), -1)
    leaf[ok] = mod['leaf'][ly[ok], lx[ok]]
    rng = random.Random('%.1f,%.1f,%.1f' % tuple(p))
    ids = np.unique(leaf[leaf >= 0])
    on = {int(i) for i in ids if rng.random() < getattr(self, 'bloom_share', SHARE)}
    m = np.array([int(v) in on for v in leaf]) & (np.asarray(c) < len(BLOOM[self.bloom]))
    if not m.any(): return c
    c = np.asarray(c, float).copy()
    c[m] = _bloom0(self) + c[m]
    return c


def install():
    """Wrap the module classes' module_pixels: a tree with .bloom (a key of BLOOM) blossoms."""
    import render7 as R, render17, tree123
    for cls in {R.Tree, render17.Tree, tree123.Tree}:
        if 'module_pixels' not in cls.__dict__ or getattr(cls.__dict__['module_pixels'], '_bloom', False): continue
        orig = cls.__dict__['module_pixels']
        def wrapped(self, p, n, mod, *a, _orig=orig, **kw):
            res = _orig(self, p, n, mod, *a, **kw)
            if getattr(self, '_in_bloom', False) or not getattr(self, 'bloom', None): return res
            Y, X, c = res[:3]
            return (Y, X, bloom_pixels(self, p, n, mod, Y, X, c)) + tuple(res[3:])
        wrapped._bloom = True
        cls.module_pixels = wrapped


def crosses(t, img, seed=3, P=None):
    """Little crosses of flowers (the lightest step in the middle, the next on its arms) on the lit blossom."""
    P = P or CROSS
    b0 = getattr(t, '_bloom_i0', None)
    if b0 is None: return img
    idx = t.index
    lit = (idx >= b0 + P['lo']) & (idx <= b0 + P['hi'])
    any_b = idx >= b0 + 2
    ys, xs = np.nonzero(lit)
    if len(ys) == 0: return img
    rng = np.random.default_rng(seed)
    n = max(1, len(ys) // P['every'])
    pick = rng.choice(len(ys), size=min(n * 3, len(ys)), replace=False)
    placed = []
    ramp = np.array(t.ramp)
    H, W = idx.shape
    for i in pick:
        y, x = ys[i], xs[i]
        if any(abs(y - a) + abs(x - b) < 4 for a, b in placed): continue
        placed.append((y, x))
        img[y, x] = ramp[b0 + 6]
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < H and 0 <= xx < W and any_b[yy, xx]: img[yy, xx] = ramp[b0 + 5]
        if len(placed) >= n: break
    return img


# (slot, species key, name, what it shows)
SLOTS = [(k, k, n) for k, n, _ in []]


def slots():
    import all23 as A, sheet23 as S23
    out = []
    for key, label, _ in A.TREES:
        name = S23.NAME.get(key, label)
        if key in BLOOM: sub = BLOOM_NAME[key]
        elif key in ('spruce', 'fir', 'pine'): sub = 'хвоя как летом'
        elif key == 'deadwood': sub = 'без листьев'
        elif key == 'red_maple': sub = 'свои красные, как летом'
        else: sub = 'весенняя листва'
        out.append((key, key, name, sub))
    return out


def build(key, s):
    import all23 as A, species19 as SP, trees22 as TR
    A._taller(); install()
    if key in ('palm', 'fan_palm'):
        import palmtree22 as PT, palms22 as PS
        kind = 'feather' if key == 'palm' else 'fan'
        return PT.Palm(kind, s, ramp=spring_ramp(PS.FEA_REF if kind == 'feather' else PS.FAN_REF))
    if key == 'willow':
        import willow22 as W22
        return W22.willow(s, H=440, season='spring')
    import conifer21 as C
    if key in C.CSPEC:
        if key == 'larch': return TR.conifer(key, s, H=460, season='spring')
        return TR.conifer(key, s, H=460)
    if key in ('maple', 'red_maple'):
        import module_maple
        from sheet20 import RED
        SP.SPEC[key] = SP.SPEC[key][:5] + ('maple',) + SP.SPEC[key][6:]
        if key == 'red_maple': return TR.tree(key, s, H=440, ramp=RED)   # its own approved reds, as in summer
        return TR.tree(key, s, H=440, season='spring')
    t = TR.tree(key, s, H=440, season='spring')
    if key in BLOOM: t.bloom = key
    return t


def render_one(job):
    key, s = job
    out = os.path.join(CACHE, '%s_%.2f.npz' % (key, s))
    if os.path.exists(out): return out, 0.0
    t0 = time.time()
    t = build(key, s)
    img = t.render(ground=KEY_G, shade=KEY_S)
    if getattr(t, 'bloom', None): crosses(t, img)
    np.savez_compressed(out, img=img, ox=t.ox, oy=t.oy)
    return out, time.time() - t0


def load(slot, s):
    d = np.load(os.path.join(CACHE, '%s_%.2f.npz' % (slot, s)))
    return d['img'], float(d['ox']), float(d['oy'])


if __name__ == '__main__':
    if sys.argv[1] == 'render':
        os.makedirs(CACHE, exist_ok=True)
        names = sys.argv[2].split(',') if len(sys.argv) > 2 else [s[0] for s in slots()]
        jobs = [(n, s) for n in names for s in SIZES]
        jobs.sort(key=lambda j: -j[1])
        with Pool(4) as p:
            for out, dt in p.imap_unordered(render_one, jobs):
                print('%-40s %.1fs' % (os.path.basename(out), dt), flush=True)
    else:
        import winter_sheet23 as WS, render6 as R6
        out = sys.argv[2]
        k = int(sys.argv[3]) if len(sys.argv) > 3 else 2
        wmax = int(sys.argv[4]) if len(sys.argv) > 4 else 1020
        title = ('Весна: весенний оттенок листвы (как в игре), цветут вишня, черёмуха, яблоня, рябина, акация; '
                 'хвойные как летом. ×%d' % k)
        sl = [(a, b, None, c, d, 'all') for a, b, c, d in slots()]
        print(WS.sheet(out, k, wmax, title, slots=sl, ground=(R6.GRASS, R6.GRASS_SHADE), loader=load, patch=()))
