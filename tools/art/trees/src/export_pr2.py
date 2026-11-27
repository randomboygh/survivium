# PR 2 (conifers in the game): export each approved conifer (round 21 fronds, turned per view by round 24's
# conifer24, round 25 feet) at the camera's 8 turns as "G-buffer" pictures the game lights live, as export_pr1.py does
# for the broadleaf trees. Run from tools/art/trees/src/ (README.md there):
#   python3 export_pr2.py <out dir> [keys] [workers]  -> <out>/<key>/<s>_<v>.npz  (one per size and variant)
# The wood (A = 2), the core (A = 1) and the bare layer are export_pr1's. A frond's pixel (A >= 128) holds what
# conifer21.Conifer.module_pixels lights it by:
#   R, G  the crown's normal where the frond lies (octahedral; a pine cap's pixel: its own normal on the cap's ball)
#   B     the frond's side axis e = cross(dir, up) (horizontal): its angle in the xz plane, 256 = a whole turn
#   A     128 | pos | stroke << 1 | rank << 2 | root << 4 | tip << 5 | deep << 6:
#         pos    the pixel lies on the frond's +e half (the half lit when e . L > 0.12)
#         stroke an outline or needle stroke (module124 role O): a step darker
#         rank   0..3 how far out in the crown the frond shows (as export_pr1's modules: autumn takes the outer first)
#         root   the root third of a frond under the tier above (not the leader, not a pine cap's): a step darker
#         tip    the tip's body (u > 0.68, role B): a step lighter where lit and the band is 4 or more
#         deep   an inner ring's frond: its band a step darker
# The game (tree.gdshader, `fronds`): d = n . L; band 5 / 4 / 3 / 2 / 1 over 0.8 / 0.5 / 0.2 / -0.15, + deep; the
# half turned away -1 (lit: all when |e . L| <= 0.12), stroke -1, root -1, lit tip +1 (band >= 4), at most 5 unless
# d > 0.92, clipped 0..6.
# The bare layer of the larch (it drops its needles) is the approved winter larch (winter23.twig2) without its snow:
# each frond a drooping branch from the trunk with a few hanging twiglets, in the bark's steps.
import os, sys, math, time, random, numpy as np
from multiprocessing import Pool
import export_pr1 as E

SIZES = E.SIZES
VARIANTS = E.VARIANTS
CONIFERS = ['spruce', 'fir', 'larch', 'pine']
SUN_T, sun_at, octa = E.SUN_T, E.sun_at, E.octa


def build(key, s, v):
    """The round-24 conifer of variant v (0 = the approved seed 11) as look24 builds it, on look24's canvas."""
    import all23 as A, shapes24 as S24, trees22 as TR, look24 as L, pine_pr2 as P2
    A._taller()
    S24.use3d(True)
    P2.install()          # the pine in flat tiers (user 2026-11-25 15:04-15:58 MSK, pine_pr2.py)
    P2.squash(key)
    return TR.conifer(key, s, W=L.W, H=L.H, seed=11 + 7 * v)


def _unit(v):
    v = np.asarray(v, float); n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v


def frond_bits(t, mod):
    """(ys, xs, n (k x 3 normals), e angle byte, a bits w/o rank) of a frond's pixels, by Conifer.module_pixels."""
    import conifer21 as C
    f = mod['frond']
    if mod['top']:
        e = np.array([1.0, 0.0, 0.0]); ncr = _unit(np.array([0.0, 1.0, 0.6]))
    else:
        dvec = mod['dir']
        e = _unit(np.cross(dvec, C.UP))
        out = _unit(np.array([dvec[0], 0.0, dvec[2]]))
        hy = (mod['ctr'][1] - (t.top - t.Hc)) / max(1.0, t.Hc)
        a = math.radians(min(85.0, mod['slope'] + (25 * hy if t.form == 'cone' else 0.0)))
        ncr = _unit(out * math.cos(a) + C.UP * math.sin(a))
    X0, Y0 = mod['org']
    ys, xs = np.nonzero(f.role >= 0)
    if 'ball' in mod:
        cx, cy, rx, ry = mod['ball']
        sx = (X0 + xs - cx) / rx; sy = (Y0 + ys - cy) / ry
        q = np.maximum(1.0, np.hypot(sx, sy)); sx, sy = sx / q, sy / q
        sz = np.sqrt(np.maximum(0.0, 1.0 - sx * sx - sy * sy))
        nb = sx[:, None] * C.RIGHT + (-sy)[:, None] * C.SUP + sz[:, None] * C.VIEW + C.BALL_WRAP * C.UP
        n = nb / np.linalg.norm(nb, axis=1, keepdims=True)
    else:
        n = np.repeat(ncr[None, :], len(ys), 0)
    es = np.array([e[0], C.ZS * e[2] - e[1]])
    nr = np.array([-f.ax[1], f.ax[0]])
    pos = (f.side[ys, xs] > 0) == (float(es @ nr) >= 0)
    stroke = f.role[ys, xs] == 0
    u = f.u[ys, xs]
    root = (u < 0.3) & (not mod['top']) & (not mod.get('spoke'))
    tip = (u > 0.68) & (f.role[ys, xs] == 1)
    deep = int(round(mod['deep']))
    assert deep in (0, -1), deep
    assert abs(e[1]) < 1e-9 and np.linalg.norm(e) > 0.5
    ang = int(round((math.atan2(e[2], e[0]) % math.tau) / math.tau * 256)) % 256
    a = 128 | pos.astype(int) | (stroke.astype(int) << 1) | (root.astype(int) << 4) | (tip.astype(int) << 5) \
        | ((1 if deep < 0 else 0) << 6)
    return ys + Y0, xs + X0, n, ang, a


def frond_layer(t):
    """(A, R, G, B) arrays of the frond pixels as the mockup draws them (later fronds over earlier ones)."""
    H, W = t.H, t.W
    out = np.zeros((H, W, 4), np.uint8)
    owner = np.full((H, W), -1, int)
    for j, (p, n_, mod) in enumerate(t.mods):
        Y, X, n, ang, a = frond_bits(t, mod)
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        Y, X, n, a = Y[ok], X[ok], n[ok], a[ok]
        rg = np.array([octa(v) for v in n], np.uint8).reshape(-1, 2)
        out[Y, X, 0] = rg[:, 0]; out[Y, X, 1] = rg[:, 1]; out[Y, X, 2] = ang; out[Y, X, 3] = a
        owner[Y, X] = j
    if getattr(t, 'whorls_', False):     # the pine's trunk over the fronds behind it (pine_pr2.trunk_front)
        import pine_pr2 as P2
        f = P2.trunk_front(t)
        out[f] = 0; owner[f] = -1
    leaf = out[..., 3] >= 128
    if leaf.any():
        cx, cy, reach = E.edge_reach(leaf)
        ys, xs = np.nonzero(leaf)
        js = owner[ys, xs]
        cnt = np.bincount(js, minlength=len(t.mods)).astype(float)
        mx = np.bincount(js, xs, minlength=len(t.mods)) / np.maximum(cnt, 1)
        my = np.bincount(js, ys, minlength=len(t.mods)) / np.maximum(cnt, 1)
        rank = np.minimum(3, (4 * E.edge_r2(cx, cy, reach, mx, my)).astype(int))
        out[ys, xs, 3] |= rank[js].astype(np.uint8) << 2
        t._edge = (cx, cy, reach)
    else:
        t._edge = None
    return out


def bare_twigs(t, mod):
    """winter23.twig2 without its snow lumps: (ys, xs, bark step) of the bare larch's branch for frond `mod`."""
    import winter23 as WI
    P = WI.LARCH
    f = mod['frond']; X0, Y0 = mod['org']
    rng = random.Random(int(abs(mod['ctr'][0]) * 97 + abs(mod['ctr'][1]) * 13 + abs(mod['ctr'][2]) * 5) + 1)
    if mod.get('deep', 0) < 0 and rng.random() > P['keep_inner']:
        return np.zeros(0, int), np.zeros(0, int), np.zeros(0, int)
    a = np.array([X0 + f.root[0], Y0 + f.root[1]]); b = np.array([X0 + f.tip[0], Y0 + f.tip[1]])
    back, trunk_x, trunk_r = False, None, 0.0
    if not mod.get('top') and P.get('to_trunk', True):
        a = np.asarray(t.scr(mod['root']), float)
        back = float(mod['dir'][2]) < -0.05
        tl = t.limbs[0]
        tts = np.linspace(0, 1, 60); ys_ = np.array([tl.at(t_)[1] for t_ in tts])
        t_ = float(tts[np.argmin(np.abs(ys_ - mod['root'][1]))])
        trunk_x, trunk_r = t.ox + float(tl.at(t_)[0]), float(tl.r(t_))
        a[0] = trunk_x
    Ln = float(np.linalg.norm(b - a))
    if mod.get('top'):
        ctl = (a + b) / 2; b2 = b
    else:
        sag = P['sag'] * min(Ln, 20.0) + P.get('sag_far', 0.08) * max(0.0, Ln - 20.0)
        ctl = (a + b) / 2 + np.array([0.0, sag])
        b2 = b - np.array([0.0, P['tip_up'] * min(Ln, 24.0)])
    ts = np.linspace(0, 1, int(Ln * 2.5) + 2)
    curve = ((1 - ts) ** 2)[:, None] * a + (2 * ts * (1 - ts))[:, None] * ctl + (ts ** 2)[:, None] * b2
    pts = [tuple(q) for q in np.round(curve).astype(int)]
    seen, line = set(), []
    for q in pts:
        if q not in seen: seen.add(q); line.append(q)
    lit = (b[0] - a[0]) * t.L[0] >= 0
    Ys, Xs, cs = [], [], []
    for k_, (x, y) in enumerate(line):
        if back and trunk_x is not None and abs(x - trunk_x) <= trunk_r + 0.5: continue
        Ys.append(y); Xs.append(x); cs.append(2 if lit else 1)
        if Ln > 14 and k_ < len(line) * 0.3:
            Ys.append(y + 1); Xs.append(x); cs.append(1)
    if not mod.get('top') and Ln > 6:
        for _ in range(rng.randint(*P['side'])):
            t0 = rng.uniform(0.3, 0.85)
            k = int(t0 * (len(curve) - 1))
            q = curve[k]; tan = curve[min(len(curve) - 1, k + 1)] - curve[max(0, k - 1)]
            tan = tan / max(1e-6, np.linalg.norm(tan))
            ang = rng.uniform(0.6, 1.0) * (1 if tan[0] >= 0 else -1)
            dvec = np.array([tan[0] * math.cos(ang) - tan[1] * math.sin(ang), tan[0] * math.sin(ang) + tan[1] * math.cos(ang)])
            if dvec[1] < 0: dvec[1] = -dvec[1]
            ln = rng.uniform(2, 4) * min(1.0, Ln / 14)
            for s_ in np.linspace(0.5, ln, int(ln * 2) + 1):
                x, y = np.round(q + dvec * s_).astype(int)
                Ys.append(y); Xs.append(x); cs.append(1)
    Y, X, c = np.array(Ys, int), np.array(Xs, int), np.array(cs, int)
    ok = (Y >= 0) & (Y < t.H) & (X >= 0) & (X < t.W)
    return Y[ok], X[ok], c[ok]


def _suns(t, k):
    import render7 as R
    L = R.norm(sun_at(SUN_T[k]))
    t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
    for a_ in ('_shadow_cache',):
        if hasattr(t, a_): setattr(t, a_, None)
    return L


def render_bare(t, key):
    """The tree without its crown under t.L: the trunk (and the pine's limbs) with the trunk's shadow only; the larch's
    drooping branches drawn over it. -> image (the bark's colours where wood)."""
    import all23 as A, outline23 as O
    t.crown = False
    try:
        img = t.render(ground=A.KEY_G, shade=A.KEY_S)
    finally:
        t.crown = True
    if key == 'larch':
        bark = np.array(t.bark, np.uint8)
        for p, n, mod in t.mods:
            Y, X, c = bare_twigs(t, mod)
            img[Y, X] = bark[c]
    O.outline(img, key)
    return img


def frames(key, s, v):
    import feet25 as F
    F.install()
    import conifer24 as C24, outline23 as O, all23 as A, render7 as R
    t = build(key, s, v)
    snap = C24.snapshot(t)
    bark = np.array(t.bark, int)
    res = []; bares = []
    for n in range(8):
        C24.turn(t, n, snap)
        core = t.core()
        g = frond_layer(t)
        leafm = g[..., 3] >= 128
        g[core & ~leafm, 3] = 1
        if t._edge is not None:
            cy_, cx_ = np.nonzero(core & ~leafm)
            g[cy_, cx_, 0] = np.round(255 * E.edge_r2(*t._edge, cx_, cy_)).astype(np.uint8)
        t.core = lambda core=core: core          # sun-independent: once per turn
        wood16 = np.zeros((t.H, t.W), np.int64); woodm = np.zeros((t.H, t.W), bool)
        for k in range(8):
            _suns(t, k)
            img = t.render(ground=A.KEY_G, shade=A.KEY_S)
            O.outline(img, key)
            a = img.astype(int)
            for i in range(4):
                m = np.all(a == bark[i], 2) & ~leafm & ~core
                wood16[m] |= i << (2 * k); woodm |= m
        if 'core' in t.__dict__: del t.__dict__['core']
        w = woodm & ~leafm & ~core
        g[w, 0] = wood16[w] & 255; g[w, 1] = (wood16[w] >> 8) & 255; g[w, 2] = 0; g[w, 3] = 2
        bare16 = np.zeros((t.H, t.W), np.int64); barem = np.zeros((t.H, t.W), bool)
        for k in range(8):
            _suns(t, k)
            a = render_bare(t, key).astype(int)
            for i in range(4):
                m = np.all(a == bark[i], 2)
                bare16[m] |= i << (2 * k); barem |= m
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
    keys = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] else CONIFERS
    nw = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    sizes = [float(x) for x in sys.argv[4].split(',')] if len(sys.argv) > 4 else SIZES[::-1]
    jobs = [(out, k, s, v) for s in sizes for k in keys for v in range(VARIANTS)]
    jobs = [j for j in jobs if not os.path.exists(os.path.join(out, j[1], '%.2f_%d.npz' % (j[2], j[3])))]
    with Pool(nw) as p:
        for r in p.imap_unordered(job, jobs):
            print(*r, flush=True)
