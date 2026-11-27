# PR 1 (broadleaf trees in the game): export each approved tree (round 24 crowns and limbs all round, squash А,
# round 25 feet) at the camera's 8 turns as "G-buffer" pictures the game lights live.
# Run from tools/art/trees/src/ (README.md there):
#   python3 export_pr1.py <out dir> [keys] [workers]  -> <out>/<key>/<s>_<v>.npz  (one per size and variant)
# A pixel of a frame (RGBA8, see pack_pr1.py for the layout the game reads):
#   leaf : A = 128 | body | heart<<1 | rank<<2 | code<<4 (no leaf, the module's disc: body 0 and heart 1, which a
#          leaf never has: a heart is body). code: the leaf's light share in 7ths (1, 4..7: the dots' small leaves
#          light less; 7 whole), 0 a leaf on top (share whole: only 122 / blade / round / maple leaves are on top),
#          2 / 3 a maple leaf's outline, half a step darker (module_maple.OUT_EXTRA), not on top / on top (share
#          whole); a share under 2/7 lights as 1/7 (f never reaches a step), 2/7 and 3/7 never come (asserted).
#          R, G = the module's normal (octahedral); B = the leaf's angle (256 = a whole turn). rank 0..3: how far out in the crown the module
#          shows (4 r^2, r its distance from the crown's middle over the crown's edge that way), so autumn takes
#          the outer modules first. The game: base 4/3/2 from n.L over 0.64 / 0.36, the leaf's tone from its facing
#          (module5 / module123 .tones), the shade's quarter rule, palest only over 0.8.
#   core : A = 1 (the leaves' ramp step 1); R = 255 r^2 of the pixel (as the modules' rank)
#   wood : A = 2; R, G = the bark ramp's step (0..3, outline included) at 8 suns of the game's day path (2 bits each,
#          sun k in bits 2k of R | G << 8), as the mockup draws it under that sun (crown shade, roots' shade).
#   bare : a second layer per frame, the tree without its crown (autumn's last leaves, winter): bit 16 = wood,
#          bits 0..15 the bark steps at the 8 suns as above.
import os, sys, math, time, numpy as np
from multiprocessing import Pool

SIZES = (0.42, 0.68, 1.0)
VARIANTS = 2
BROADLEAF = ['oak', 'linden', 'birch', 'acacia', 'mangrove', 'apple', 'cherry', 'poplar', 'ceiba', 'maple',
             'red_maple', 'bird_cherry', 'rowan', 'deadwood']
# the game's day path (Sky: az = (t - 0.5) 180 - 25, el = lerp(14, 55, -cos 2 pi t)), 8 times from dawn to dusk
SUN_T = [0.22 + k * 0.56 / 7 for k in range(8)]

def sun_at(t):
    az = math.radians((t - 0.5) * 180 - 25)
    el = math.radians(14 + 41 * -math.cos(t * math.tau))
    return np.array([-math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el)])

# The crowns lowered (user 2026-11-25 03:57 MSK: lower the new trees' crowns by about 20% of the tree's height): by
# LOWER of the tree's height, but only as far as keeps KEEP of the new height (and MIN_SEEN px) of trunk in sight under
# the crown, so the short trunks (oak, apple, cherry, bird cherry, poplar) are not buried. SEEN: per size, the tree's
# height and the trunk seen under the crown at the trunk's middle (px, foot to the crown's lowest pixel there), measured
# on the approved round 24/25 pictures (both variants, the lowest over the 8 turns; None: no crown, all limbs).
LOWER, KEEP, MIN_SEEN = 0.2, 0.12, 6
SEEN = {
    'oak': ((72, 8), (96, 15), (120, 20)), 'linden': ((86, 22), (113, 36), (141, 51)),
    'birch': ((90, 27), (123, 41), (155, 54)), 'acacia': ((76, 22), (98, 33), (125, 48)),
    'mangrove': ((62, 11), (80, 22), (100, 29)), 'apple': ((59, 4), (75, 13), (95, 19)),
    'cherry': ((55, 3), (70, 9), (86, 13)), 'poplar': ((87, 9), (118, 15), (150, 26)),
    'ceiba': ((108, 33), (148, 56), (182, 76)), 'maple': ((78, 12), (102, 21), (126, 31)),
    'red_maple': ((67, 8), (89, 19), (112, 28)), 'bird_cherry': ((60, 2), (73, 9), (92, 17)),
    'rowan': ((63, 14), (84, 26), (104, 39)), 'deadwood': ((47, None), (65, None), (84, None)),
}

def drop(key, s):
    """How far (px) the crown of `key` at size s goes down from the approved height."""
    H, seen = SEEN[key][min(range(len(SIZES)), key=lambda i: abs(SIZES[i] - s))]
    if seen is None: return 0.0         # no crown (deadwood): its limbs stay as approved, a dead tree stands tall
    d = max(0.0, min(LOWER * H, (seen - KEEP * H) / (1 - KEEP), seen - MIN_SEEN))
    return d if d >= 2 else 0.0         # less than 2 px: the approved tree as it is

def build(key, s, v, lower=True):
    """The round-24 tree of variant v (0 = the approved seed), its crown lowered by drop() (lower=False: as approved)."""
    import all23 as A, shapes24 as S24, trees22 as TR, species19 as SP, look24 as L, render7 as R
    A._taller()
    S24.use3d(True)
    extra = dict(seed=1 + 7 * v, warp=11 + 5 * v)
    if key in ('maple', 'red_maple'):
        import module_maple
        from sheet20 import RED
        SP.SPEC[key] = SP.SPEC[key][:5] + ('maple',) + SP.SPEC[key][6:]
        if key == 'red_maple': extra['ramp'] = RED
    spec = SP.SPEC[key]
    dz = drop(key, s) if lower else 0.0
    if dz > 0:      # the bare trunk under the crown (the shape's cy x bole k x s^(2/3), render16) shorter by dz
        cy = R.SHAPES[spec[1]]['cy'] * spec[3] * s ** (2 / 3)
        SP.SPEC[key] = spec[:3] + (spec[3] * (cy - dz) / cy,) + spec[4:]
    try:
        return TR.tree(key, s, W=L.W, H=L.H, **extra)
    finally:
        SP.SPEC[key] = spec

def octa(n):
    n = np.asarray(n, float); n = n / max(1e-9, np.abs(n).sum())
    x, y = n[0], n[1]
    if n[2] < 0:
        x, y = (1 - abs(n[1])) * math.copysign(1, n[0]), (1 - abs(n[0])) * math.copysign(1, n[1])
    return int(round((x * 0.5 + 0.5) * 255)), int(round((y * 0.5 + 0.5) * 255))

EDGE_BINS = 72

def edge_reach(mask):
    """The crown's middle (centroid of `mask`) and its reach toward each of EDGE_BINS angles (the farthest pixel of
    the crown that way, the widest of the bin and its neighbours, so a gap between lobes is still inside)."""
    ys, xs = np.nonzero(mask)
    cx, cy = xs.mean(), ys.mean()
    ang = np.arctan2(ys - cy, xs - cx); d = np.hypot(xs - cx, ys - cy)
    b = ((ang + math.pi) / math.tau * EDGE_BINS).astype(int) % EDGE_BINS
    reach = np.zeros(EDGE_BINS)
    np.maximum.at(reach, b, d)
    reach = np.maximum(reach, np.maximum(np.roll(reach, 1), np.roll(reach, -1)))
    return cx, cy, np.maximum(reach, 1.0)

def edge_r2(cx, cy, reach, x, y):
    """r^2 (0 the middle, 1 the edge) of points x, y against edge_reach's crown."""
    x = np.asarray(x, float); y = np.asarray(y, float)
    a = (np.arctan2(y - cy, x - cx) + math.pi) / math.tau * EDGE_BINS - 0.5
    i0 = np.floor(a).astype(int); f = a - i0
    R = reach[i0 % EDGE_BINS] * (1 - f) + reach[(i0 + 1) % EDGE_BINS] * f
    return np.clip(np.hypot(x - cx, y - cy) / R, 0.0, 1.0) ** 2

def leaf_layer(t, skip):
    """(A, R, G, B) arrays of the leaf pixels as the mockup draws the modules (later ones over earlier ones)."""
    import render7 as R, module5 as M5, module123 as MM
    M = R.M
    H, W = t.H, t.W
    out = np.zeros((H, W, 4), np.uint8)
    owner = np.full((H, W), -1, int)
    for j, (p, n, mod) in enumerate(t.mods):
        if j in skip: continue
        style = 'style' in mod
        leaf, role = mod['leaf'], mod['role']
        disc = mod['disc'] if 'disc' in mod else R.DISC[mod['flip']]
        mask = (leaf >= 0) | disc
        sx, sy = t.proj(p)
        cx = M.S - 1 - M.C[0] if mod['flip'] else M.C[0]
        X0 = int(round(sx)) - cx; Y0 = int(round(sy)) - M.C[1]
        nr, ng = octa(n)
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            Y, X = y + Y0, x + X0
            if not (0 <= Y < H and 0 <= X < W): continue
            k = leaf[y, x]
            if k < 0:
                a = 128 | 2; ang = 0
            else:
                r = role[y, x]
                if style:
                    body = r in (MM.BODY, MM.HEART); heart = r == MM.HEART
                    dots = mod['style'] == 'dots'
                    top = (not dots) and bool(mod['top'][k])
                    sc = min(1.0, mod['rad'][k] / 4.0) if dots else 1.0
                    rim = mod['style'] == 'maple' and r == MM.OUT
                else:
                    body = r == M5.BODY; heart = body and mod['depth'][y, x] >= 1
                    top = bool(mod['top'][k]); sc = 1.0; rim = False
                q = max(1, int(round(sc * 7)))
                assert q not in (2, 3) and (q == 7 or not (top or rim))
                if rim:
                    import module_maple as MP
                    assert MP.OUT_EXTRA == 0.5
                code = (3 if top else 2) if rim else (0 if top else q)
                a = 128 | int(body) | (int(heart) << 1) | (code << 4)
                ang = int(round((mod['ang'][k] % math.tau) / math.tau * 256)) % 256
            out[Y, X] = (nr, ng, ang, a)
            owner[Y, X] = j
    # each module's edge rank in A's bits 2..3 (see the header), from where it shows
    leaf = out[..., 3] >= 128
    if leaf.any():
        cx, cy, reach = edge_reach(leaf)
        ys, xs = np.nonzero(leaf)
        js = owner[ys, xs]
        n = np.bincount(js, minlength=len(t.mods)).astype(float)
        mx = np.bincount(js, xs, minlength=len(t.mods)) / np.maximum(n, 1)
        my = np.bincount(js, ys, minlength=len(t.mods)) / np.maximum(n, 1)
        rank = np.minimum(3, (4 * edge_r2(cx, cy, reach, mx, my)).astype(int))
        out[ys, xs, 3] |= rank[js].astype(np.uint8) << 2
        t._edge = (cx, cy, reach)
    else:
        t._edge = None
    return out

def frames(key, s, v):
    import feet25 as F
    F.install()
    import turn24 as TU, outline23 as O, all23 as A, render7 as R
    from render2 import hexc
    t = build(key, s, v)
    snap = TU.snapshot(t)
    bark = np.array(t.bark, int)
    res = []; bares = []
    for n in range(8):
        TU.turn(t, n, snap)
        crown = getattr(t, 'crown', True)
        if crown:
            core = t.core()
            vis = t.visibility(core)
            skip = {j for j in range(len(t.mods)) if vis[j] == 0}
            t.core = lambda core=core: core          # sun-independent: once per turn
            g = leaf_layer(t, skip)
        else:
            core = np.zeros((t.H, t.W), bool); skip = set()
            g = np.zeros((t.H, t.W, 4), np.uint8)
        leafm = g[..., 3] >= 128
        g[core & ~leafm, 3] = 1
        if crown and t._edge is not None:
            cy_, cx_ = np.nonzero(core & ~leafm)
            g[cy_, cx_, 0] = np.round(255 * edge_r2(*t._edge, cx_, cy_)).astype(np.uint8)
        wood16 = np.zeros((t.H, t.W), np.int64); woodm = np.zeros((t.H, t.W), bool)
        for k, ts in enumerate(SUN_T):
            L = R.norm(sun_at(ts))
            t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
            for a_ in ('_cover', '_shadow_cache'):
                if hasattr(t, a_): setattr(t, a_, None)
            img = t.render(ground=A.KEY_G, shade=A.KEY_S, skip=skip) if crown else t.render(ground=A.KEY_G, shade=A.KEY_S)
            O.outline(img, key)
            a = img.astype(int)
            for i in range(4):
                m = np.all(a == bark[i], 2) & ~leafm & ~core
                wood16[m] |= i << (2 * k); woodm |= m
        if 'core' in t.__dict__: del t.__dict__['core']
        w = woodm & ~leafm & ~core
        g[w, 0] = wood16[w] & 255; g[w, 1] = (wood16[w] >> 8) & 255; g[w, 2] = 0; g[w, 3] = 2
        # the bare tree (winter, autumn's last leaves): the whole skeleton, no crown shade
        bare16 = np.zeros((t.H, t.W), np.int64); barem = np.zeros((t.H, t.W), bool)
        if crown:
            t.crown = False
            for k, ts in enumerate(SUN_T):
                L = R.norm(sun_at(ts))
                t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
                for a_ in ('_cover', '_shadow_cache'):
                    if hasattr(t, a_): setattr(t, a_, None)
                img = t.render(ground=A.KEY_G, shade=A.KEY_S)
                O.outline(img, key)
                a = img.astype(int)
                for i in range(4):
                    m = np.all(a == bark[i], 2)
                    bare16[m] |= i << (2 * k); barem |= m
            t.crown = True
        else:
            bare16, barem = wood16, woodm
        bare16[~barem] = 0
        res.append(g); bares.append(np.where(barem, bare16 | (1 << 16), 0).astype(np.uint32))
    meta = dict(ox=float(t.ox), oy=float(t.oy), ramp=[list(map(int, c)) for c in t.ramp],
                bark=[list(map(int, c)) for c in t.bark])
    meta['bare'] = np.array(bares)
    return np.array(res), meta

def job(args):
    out, key, s, v = args
    t0 = time.time()
    fr, meta = frames(key, s, v)
    os.makedirs(os.path.join(out, key), exist_ok=True)
    np.savez_compressed(os.path.join(out, key, '%.2f_%d.npz' % (s, v)), frames=fr, **{k: np.array(x) for k, x in meta.items()})
    return key, s, v, round(time.time() - t0, 1)

if __name__ == '__main__':
    out = sys.argv[1]
    keys = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] else BROADLEAF
    nw = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    jobs = [(out, k, s, v) for k in keys for s in SIZES[::-1] for v in range(VARIANTS)]
    jobs = [j for j in jobs if not os.path.exists(os.path.join(out, j[1], '%.2f_%d.npz' % (j[2], j[3])))]
    with Pool(nw) as p:
        for r in p.imap_unordered(job, jobs):
            print(*r, flush=True)
