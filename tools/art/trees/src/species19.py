# Round 19: every deciduous species of the game (content/plants/*/data/trees.yaml; conifers and the palm
# left out) as the chosen tree (round 17 limbs + round 16 crowns), with a crown shape, trunk proportions,
# leaf style, leaf tint and bark colours picked from its data:
#   leaf style = the species' `leaf` field, one to one: soft -> dots, scales -> round, pointed -> blades,
#                curly -> today's 122 leaves (the game already sorts its species into these four kinds);
#   crown shape from `shape` (round -> egg / dome, lobed -> caps, column, umbrella, weeping), its size from
#   `crown` and the bare trunk from `trunk`, both relative to the approved oak and linden;
#   trunk width from `girth` (oak = 1); leaf colours from `tints`; bark from the species' bark texture.
import numpy as np, os
from PIL import Image
import render16 as G, render7 as R7, render6 as R6
HERE = os.path.dirname(os.path.abspath(__file__))
BARK_DIR = os.path.join(HERE, '..', 'ref', 'bark')

# key: (label, shape, crown k, bole k, girth k, leaves, tints, bark texture or None, bare)
SPEC = {
    'oak':         ('дуб', 'lobed', 1.00, 1.45, 1.00, '122', ('#527d47', '#5a8442', '#4d784e'), None, False),
    'linden':      ('липа', 'egg', 0.90, 2.40, 1.00, 'dots', ('#5a8f3a', '#62983f', '#548a36'), 'grey_bark', False),
    'birch':       ('берёза', 'ellipsoid', 0.85, 2.50, 0.57, 'dots', ('#6fa04a', '#7aa852', '#659a46'), 'birch_bark', False),
    'acacia':      ('акация', 'flat', 0.95, 1.10, 0.40, 'dots', ('#7c8a3e', '#86913f', '#728238'), None, False),
    'mangrove':    ('мангр', 'hemi', 0.76, 1.30, 0.48, 'dots', ('#4b7a3c', '#537f37', '#46733f'), None, False),
    'apple':       ('яблоня', 'hemi', 0.86, 1.10, 0.67, 'round', ('#4e8a3e', '#558f42', '#48843c'), 'apple_bark', False),
    'cherry':      ('вишня', 'hemi', 0.78, 1.00, 0.62, 'round', ('#4f8a40', '#578f44', '#4a823c'), 'cherry_bark', False),
    'maple':       ('клён', 'lobed2', 0.75, 1.40, 0.80, 'round', ('#4f8a3a', '#58923f', '#4a8236'), None, False),
    'red_maple':   ('красный клён', 'lobed', 0.85, 1.45, 0.80, 'round', ('#b8432a', '#cf6a2c', '#a83a26'), None, False),
    'poplar':      ('тополь', 'column', 1.00, 1.80, 0.62, 'round', ('#4d8a46', '#56914a', '#478242'), 'grey_bark', False),
    'ceiba':       ('сейба', 'lobed2', 0.90, 2.40, 1.00, 'round', ('#3f7a34', '#467f2e', '#3a7140'), None, False),
    'bird_cherry': ('черёмуха', 'lobed', 0.75, 1.10, 0.62, 'blades', ('#4c8540', '#538c44', '#477d3c'), 'grey_bark', False),
    'rowan':       ('рябина', 'lobed', 0.55, 1.55, 0.52, 'blades', ('#5c8f3c', '#649644', '#56893a'), 'rowan_bark', False),
    'willow':      ('ива', 'weeping', 0.92, 1.45, 0.80, 'blades', ('#4e8a3e', '#56903f', '#48823a'), 'willow_bark', False),
    'deadwood':    ('сухое дерево', 'lobed', 0.75, 1.20, 0.71, None, ('#6b6a55',), 'deadwood_bark', True),
}
STYLE_NAME = {'122': 'листья 122', 'dots': 'точки', 'blades': 'клинки', 'round': 'круглые', None: 'без листьев'}
SHAPE_NAME = {'lobed': 'шапки', 'lobed2': 'шапки врозь', 'egg': 'яйцо', 'ellipsoid': 'эллипсоид', 'umbrella': 'зонтик',
              'hemi': 'купол', 'column': 'колонна', 'weeping': 'плакучая', 'flat': 'плоский зонтик'}

def _quantiles(path):
    a = np.array(Image.open(path).convert('RGB'), float)[:, 16:32].reshape(-1, 3)
    lum = a @ np.array([0.3, 0.59, 0.11])
    order = np.argsort(lum)
    out = []
    for q in (0.08, 0.38, 0.66, 0.88):
        i = order[min(len(order) - 1, int(q * len(order)))]
        lo = max(0, int((q - 0.08) * len(order))); hi = min(len(order), int((q + 0.08) * len(order)) + 1)
        out.append(a[order[lo:hi]].mean(0))
    return np.array(out)

def bark_ramp(tex):
    """Our lit oak-trunk ramp (render6.OUR_BARK, from the game) times the species' bark texture over the
    log's, step by step: the bark's own colours as the game lights them."""
    if tex is None: return list(R6.OUR_BARK)
    q = _quantiles(os.path.join(BARK_DIR, tex + '.png')); q0 = _quantiles(os.path.join(BARK_DIR, 'log.png'))
    out = []
    for h, a, b in zip(R6.OUR_BARK, q, q0):
        c = np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) * a / np.maximum(b, 1)
        out.append('%02x%02x%02x' % tuple(np.clip(c, 0, 236).round().astype(int)))
    return out

def register():
    for key, (label, shape, ck, bk, wk, *_rest) in SPEC.items():
        G.SPECIES[key] = (label, shape, ck, bk)

def tree(key, s, warp=11, sun=R7.SUN_R, W=320, H=400, **extra):
    import tree123 as TT
    register()
    label, shape, ck, bk, wk, leaves, tints, bark, bare = SPEC[key]
    G.WIDTH = 0.8 * wk
    kw = dict(k=1.3, tint=R7.species_tint(*tints), d1=0.64, d2=0.36, dp=0.8, shade_flat='quarter', W=W, H=H,
              bark=bark_ramp(bark))
    kw.update(extra)
    t = TT.Tree(sun, leaves=leaves or '122', species=key, s=s, warp=warp, crown=not bare, **kw)
    G.WIDTH = 0.8
    return t
