# Round 22: hanging (weeping) leaf modules for the willow, from reference 123's blade brushes.
# A hanging module = a short arch of twig (hidden under a cap of three blades) with 3-4 strands of
# leaves hanging from it. A strand is a column of the reference's hanging leaf (the "shield", the 4th
# blade icon of 123: a leaf hanging tip down) now and then swapped for its drops (the 3rd icon, tip to
# one side), each leaf 5 px under the one above and laid bottom first, so every upper leaf lies over
# the stem of the one below, as hanging leaves overlap; a strand ends in one point. Strands of one
# module differ in length (the middle one longest) and drift a pixel aside now and then. The dark
# backing (the module's base step - 1, like the disc under a leaf module) fills the gaps inside.
# Modules come in length classes (LENGTHS) x 4 layouts (seeds) x mirror.
import math, random, numpy as np
from scipy import ndimage
import hang22 as HG

HW, HH = 40, 96              # the module's box
AX, AY = 20, 5               # where the module hangs from (its anchor, under the cap)
LENGTHS = (14, 20, 26, 32, 40, 48, 58, 68, 80)
STEP = 5                     # a leaf every 5 px down a strand (the shield is 9 px tall)
SEEDS = (0, 1, 2, 3)

def _strand(x, y, n, si, rng, kind):
    """Leaves of one strand from its top (x, y), top first: (name, x0, y0, axis x, strand, i, n)."""
    out = []
    ph = rng.uniform(0, math.tau); amp = rng.choice((0, 1, 1)) if kind != 'shield' else 0
    drops = kind in ('mix', 'zig')
    for i in range(n):
        ax = x + int(round(amp * math.sin(0.8 * i + ph)))          # the strand drifts a pixel aside
        nm, dx = 'shield', 0
        if drops and i < n - 1 and rng.random() < (0.45 if kind == 'mix' else 0.2):
            nm = rng.choice(('drop_l', 'drop_r')); dx = 1 if nm == 'drop_l' else -1
        out.append(HG.place(nm, ax + dx, y + i * STEP) + (ax, si, i, n))
    return out

def build(seed, length, kind='mix', nstr=None, spread=10, cap=True):
    """The leaves of one hanging module in drawing order. length: px from the anchor to the longest
    strand's tip."""
    rng = random.Random(seed * 1000 + length)
    n = nstr or (3 if seed % 2 == 0 else 4)
    xs = [(i - (n - 1) / 2) * spread + rng.choice((-1, 0, 0, 1)) for i in range(n)]
    longest = rng.randrange(n) if n == 4 else 1
    if n == 4 and longest in (0, 3): longest = rng.choice((1, 2))
    leaves = []
    for si, dx in enumerate(xs):
        top = AY - 2 + (0 if si == longest else rng.randint(1, 4))
        want = length if si == longest else length * rng.uniform(0.55, 0.95)
        ln = max(1, int(round((AY + want - top - 9) / STEP)) + 1)
        leaves += _strand(int(round(AX + dx)), top, ln, si, rng, kind)
    leaves.sort(key=lambda q: (-q[2], q[4]))      # bottom first: each upper leaf over the one below
    if cap:                                        # the arch: blades spreading from the anchor
        for nm, dx in (('flat_l', -1), ('flat_r', 1)):
            leaves.append(HG.place(nm, AX + dx, AY - 1) + (AX, -1, 0, 1))
        leaves.append(HG.place('shield', AX, AY - 4) + (AX, -1, 0, 1))
    return leaves

def raster(leaves):
    leaf = -np.ones((HH, HW), int); role = np.full((HH, HW), '.', object)
    for k, L in enumerate(leaves):
        name, x0, y0 = L[:3]
        for x, y, c in HG.B[name].px:
            X, Y = x0 + x, y0 + y
            if 0 <= X < HW and 0 <= Y < HH: leaf[Y, X] = k; role[Y, X] = c
    return leaf, role

def length_class(px):
    return min(LENGTHS, key=lambda L: abs(L - px))

_CACHE = {}
def module(seed, flip=False, length=32, kind='mix', **kw):
    key = (seed, flip, length, kind, tuple(sorted(kw.items())))
    if key in _CACHE: return _CACHE[key]
    leaves = build(seed, length, kind, **kw)
    leaf, role = raster(leaves)
    m = leaf >= 0
    back = ndimage.binary_fill_holes(ndimage.binary_closing(m, iterations=2))
    back = ndimage.binary_erosion(back, iterations=1) & ~m          # inside only: the edge stays the leaves'
    mod = dict(style='hang', leaves=leaves, leaf=leaf, role=role, back=back, flip=flip, W=HW, H=HH,
               anchor=(AX, AY), length=length, seed=seed)
    if flip:
        for k in ('leaf', 'role', 'back'): mod[k] = mod[k][:, ::-1].copy()
        mod['anchor'] = (HW - 1 - AX, AY)
        mod['leaves'] = [(nm, HW - 1 - (x0 + HG.B[nm].w - 1), y0, HW - 1 - ax) + tuple(rest)
                         for nm, x0, y0, ax, *rest in leaves]
    _CACHE[key] = mod
    return mod

LIGHT = 'leaf'               # 'leaf': whole leaves lit by their place in the module; 'half': strands split

def tones(mod, light2, flat=False, shade=False, light=None):
    """Relative tones (to the module's base step): outline and vein -1, body and heart 0. Light by the
    conifer fronds' rule (round 21): the half of each strand toward the sun +1 (its heart +1 more), the
    half away -1 (in shade modules -0.75, the 'quarter' rule); the cap's blades by their way, like the
    leaves of a leaf module. -9 = empty."""
    leaf, role = mod['leaf'], mod['role']
    t = np.full(leaf.shape, -9.0)
    sgn = 1 if light2[0] >= 0 else -1
    ys, xs = np.nonzero(leaf >= 0)
    for y, x in zip(ys, xs):
        k = leaf[y, x]
        c = role[y, x]
        v = -1.0 if c in 'OV' else 0.0
        if not flat:
            nm, x0, y0, ax, si, i, n = mod['leaves'][k]
            if si < 0:                         # the cap lies on top: it counts as lit, like the
                b = HG.B[nm]                   # middle leaves of a leaf module; the heart only
                a = b.way if not mod['flip'] else math.pi - b.way      # where it faces the sun
                f = max(0.3, math.cos(a) * light2[0] + math.sin(a) * light2[1])
                v += 1
                if c == 'H' and f > 0.45: v += 1
                t[y, x] = v
                continue
            elif (light or LIGHT) == 'half':
                s = 1 if (x - ax) * sgn >= 0 else -1
            else:
                # the module as a curtain bulging toward the viewer: a leaf on the sun's side of it,
                # or high on its strand, faces the light; low on the far side, away
                hw = mod.get('half_w', 12.0)
                ox = mod['anchor'][0]
                f = (ax - ox) / hw * sgn * 0.9 + (0.45 if i == 0 else (0.2 if i < n * 0.4 else (-0.15 if i < n - 1 else -0.35)))
                s = 1 if f > 0.3 else (0 if f > -0.4 else -1)
                if s > 0 and c == 'H' and f > 0.55: v += 1
                if s > 0: v += 1
                elif s < 0: v -= 0.75 if shade else 1
                t[y, x] = v
                continue
            if s > 0:
                v += 1
                if c == 'H': v += 1
            else:
                v -= 0.75 if shade else 1
        t[y, x] = v
    return t
