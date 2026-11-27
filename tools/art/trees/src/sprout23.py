# A sprout of the species' own leaves out of a broken trunk's side (round 23 step 3b, mockup): the approved leaf
# brushes (122's leaves, 123's dots / blades / round, the maple brushes) in the tree's own leaf ramp, a few of them round
# a short stem out of the trunk's side away from the high splinter (as the reference's); conifers and palms have no
# shoots on the trunk: a seedling stands on the ground beside the foot (a little spruce of needles, a young palm leaf).
import json, math, os, random, numpy as np
import stump23 as S, all23 as A

HERE = os.path.dirname(os.path.abspath(__file__))
L122 = [e['rows'] for e in json.load(open(os.path.join(HERE, 'leaves.json')))]
L123 = json.load(open(os.path.join(HERE, 'leaves123.json')))
CONIFERS = ('spruce', 'fir', 'larch', 'pine')
PALMS = ('palm', 'fan_palm')

SEEDLING = [            # a little conifer (T: its stem)
    '...O...',
    '..OHO..',
    '..OBO..',
    '.OBBHO.',
    '..OBO..',
    '.OBBHO.',
    'OBBBBHO',
    '.OOTOO.',
    '...T...',
]
PALM_FAN = [            # a young fan palm leaf on its stalk
    'O.O.O.O',
    'OBOBOHO',
    '.OBBHO.',
    '..OBO..',
    '...T...',
    '...T...',
]
PALM_FEATHER = [        # a young feather palm leaf: two arching blades
    '.OOO...OO.',
    'OBBBO.OHHO',
    '.O..OTO..O',
    '.....T....',
    '.....T....',
]


def style_of(key):
    if key in ('maple', 'red_maple'): return 'maple'
    if key in CONIFERS: return 'needles'
    if key in PALMS: return 'palm'
    import species19 as SP
    st = SP.SPEC.get(key, (None,) * 6)[5]
    return st or '122'


def ramp_of(st):
    if st.key in PALMS:
        import palmtree22 as PT
        p = PT.Palm('feather' if st.key == 'palm' else 'fan', st.s)
        return np.array([S.hexc(h) if isinstance(h, str) else np.asarray(h[:3], float) for h in p.ramp], float)
    t = st.t if st.key != 'deadwood' else A.build('oak', st.s)
    return np.array([S.hexc(h) if isinstance(h, str) else np.asarray(h[:3], float) for h in t.ramp], float)


def turned(rows, k, flip):
    a = np.array([list(r) for r in rows])
    if flip: a = a[:, ::-1]
    return np.rot90(a, k)


def based(rows, k, flip):
    """The brush turned, and where its base (the stalk end: the bottom-left-most pixel as drawn) went."""
    a = np.array([list(r) for r in rows])
    m = np.zeros(a.shape, int)
    ys, xs = np.nonzero(a != '.')
    i = int(np.argmax(ys - xs)); m[ys[i], xs[i]] = 1
    if flip: a, m = a[:, ::-1], m[:, ::-1]
    a, m = np.rot90(a, k), np.rot90(m, k)
    by, bx = np.argwhere(m == 1)[0]
    return a, (int(by), int(bx))


def stamp(pic, keep, a, X0, Y0, tone, ramp):
    H, W = keep.shape
    for (y, x), ch in np.ndenumerate(a):
        if ch == '.' : continue
        Y, X = Y0 + y, X0 + x
        if not (0 <= Y < H and 0 <= X < W): continue
        if ch not in tone: continue
        pic[Y, X] = np.round(ramp[tone[ch]]).astype(np.uint8); keep[Y, X] = True


TONE_LIT = dict(O=2, B=5, V=4, H=6, T=3)        # young leaves: a step lighter than the crown's
TONE_MID = dict(O=1, B=4, V=3, H=5, T=2)
TONE_DARK = dict(O=1, B=3, V=2, H=4, T=2)


def add_sprout(st, winter=False):
    key = st.key
    sty = style_of(key)
    ramp = ramp_of(st)
    if len(ramp) >= 7: pass
    else: ramp = np.vstack([ramp[:1], ramp, ramp[-1:]])[:7]
    rng = random.Random(st.seed * 11 + 3)
    pic, keep = st.pic, st.mask
    H, W = keep.shape
    oy = int(round(st.oy))
    out = -st.side                                       # away from the high splinter
    trunk = keep & ~st.shadow
    if sty == 'palm':
        cols = np.nonzero(trunk[max(0, oy - 2):oy + 2].any(0))[0]
        if not len(cols): return
        T = ((cols.min() - 6) if out < 0 else (cols.max() + 6), oy + 1)
        br = L123['blades']['brushes']
        fan = [(0, False, TONE_DARK), (0, True, TONE_MID), (1, False, TONE_MID), (3, True, TONE_LIT)]
        if key == 'palm': fan = [(0, False, TONE_MID), (0, True, TONE_LIT), (1, True, TONE_DARK)]
        for k, fl, tone in fan:
            a, (by, bx) = based(br[2 if key == 'fan_palm' else 3], k, fl)
            stamp(pic, keep, a, T[0] - bx, T[1] - by, tone, ramp)
        return
    if sty == 'needles' and winter:
        a = np.array([list(r) for r in SEEDLING])
        if out > 0: a = a[:, ::-1]
        cols = np.nonzero(trunk[max(0, oy - 2):oy + 2].any(0))[0]
        if not len(cols): return
        xe = cols.min() - 2 - a.shape[1] if out < 0 else cols.max() + 2
        Y0 = oy + 1 - a.shape[0] + 1
        stamp(pic, keep, a, xe, Y0, TONE_DARK, ramp)
        import bare23 as B
        for x in range(a.shape[1]):                   # snow on each tier's upper edge
            ys = [y for y in range(a.shape[0]) if a[y, x] != '.']
            for y in ys:
                if (y == 0 or a[y - 1, x] == '.') and a[y, x] in 'OH':
                    Y, X = Y0 + y, xe + x
                    if 0 <= Y < H and 0 <= X < W: pic[Y, X] = B.SNOW_RGB[4 if x > a.shape[1] // 2 else 3]
        return
    if sty == 'needles':
        rows = SEEDLING
        a = np.array([list(r) for r in rows])
        if out > 0: a = a[:, ::-1]
        # beside the foot on the ground, a little in front
        Yg = oy + 1
        cols = np.nonzero(trunk[max(0, Yg - 3):Yg + 1].any(0))[0]
        if not len(cols): return
        xe = cols.min() - 2 - a.shape[1] if out < 0 else cols.max() + 2
        Y0 = Yg - a.shape[0] + 1
        stamp(pic, keep, a, xe, Y0, TONE_MID, ramp)
        st.sprout_box = (Y0, xe, a.shape)
        return
    # on the trunk's side at about half the break's height
    Ys = oy - int(round(st.hs * rng.uniform(0.45, 0.6)))
    xs_ = np.nonzero(trunk[Ys])[0]
    if not len(xs_): return
    xe = xs_.min() if out < 0 else xs_.max()
    # the stem: out and a little up
    sx, sy = xe, Ys
    for k in range(3):
        sx += out; sy -= (1 if k % 2 else 0)
        if 0 <= sx < W and 0 <= sy < H:
            pic[sy, sx] = np.round(ramp[2]).astype(np.uint8); keep[sy, sx] = True
    tip = (sx + out * 2, sy - 2)
    if winter:
        # the leaves fell: the shoot's bare twigs (bark), a pinch of snow on them
        import bare23 as B
        bark = np.asarray(st.bark, float)
        tw = [(1, -1), (2, -2), (3, -3), (2, -1), (3, 0), (4, -1)]
        for dx, dy in tw:
            X, Y = sx + out * dx, sy + dy
            if 0 <= X < W and 0 <= Y < H:
                pic[Y, X] = np.round(bark[2 if dy < -1 else 1]).astype(np.uint8); keep[Y, X] = True
        for dx, dy in ((3, -4), (4, -2)):
            X, Y = sx + out * dx, sy + dy
            if 0 <= X < W and 0 <= Y < H:
                pic[Y, X] = B.SNOW_RGB[4]; keep[Y, X] = True
        return
    if sty == 'dots':
        br = L123['dots']['brushes']
        spots = [(-3, -2, 0), (2, -3, 0), (-1, 1, 1), (3, 0, 1), (0, -5, 1), (-4, 2, 2), (1, -1, 2), (4, -3, 2)]
        for dx, dy, lay in spots:
            b = br[rng.choice((0, 0, 2, 3, 4))]
            a = turned(b, rng.randint(0, 3), rng.random() < 0.5)
            tone = (TONE_DARK, TONE_MID, TONE_LIT)[lay]
            stamp(pic, keep, a, tip[0] + dx * out - a.shape[1] // 2, tip[1] + dy - a.shape[0] // 2, tone, ramp)
        return
    if sty == '122':
        pool = L122
    elif sty == 'maple':
        import module_maple as MM
        pool = [MM.BRUSHES[2], MM.BRUSHES[1]]
    else:
        pool = L123[sty]['brushes']
    if sty == 'blades':
        # blades out of the tip: up, up and out, out (the back one darker)
        br = pool
        fan = [(0, out < 0, TONE_DARK), (0, out > 0, TONE_MID), (3 if out > 0 else 1, out < 0, TONE_LIT),
               (0, out < 0, TONE_LIT)]
        for i, (k, fl, tone) in enumerate(fan):
            a, (by, bx) = based(br[rng.randrange(len(br))], k, fl)
            dx = (i == 3) * out * 2
            stamp(pic, keep, a, tip[0] + dx - bx, tip[1] + 1 - by, tone, ramp)
        return
    # a rounded clump: leaves round the tip, the back ones darker, the front top one lit
    places = [(-2, -5, TONE_DARK), (3, -5, TONE_MID), (-2, -1, TONE_MID), (3, -1, TONE_MID), (1, -7, TONE_LIT),
              (1, -2, TONE_LIT)]
    if sty == 'maple': places = [(-1, -5, TONE_MID), (3, -1, TONE_LIT)]
    for i, (dx, dy, tone) in enumerate(places):
        b = pool[rng.randrange(len(pool))]
        k = rng.randint(0, 3) if sty == '122' else (0 if i != 1 else (1 if out > 0 else 3))
        a = turned(b, k, (out > 0) ^ (rng.random() < 0.3))
        stamp(pic, keep, a, tip[0] + dx * out - a.shape[1] // 2, tip[1] + dy - a.shape[0] // 2, tone, ramp)
