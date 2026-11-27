# PR 3 (willow and palms in the game): export the approved willow (round 22 hanging modules, cascade, voids Б, turned
# per view by round 24's kinds24, round 25 feet) and both palms (round 22 palmtree22, soft outline /2, turned by
# kinds24.palm_turn) at the camera's 8 turns, as export_pr1/2 do for the other trees. Run from
# tools/art/trees/src/ (README.md there):
#   python3 export_pr3.py <out dir> [keys] [workers] [sizes]  -> <out>/<key>/<s>_<v>.npz
#
# Willow (look.yaml `rule: hanging`, tree.gdshader hanging_steps): the wood (A = 2), the core (A = 1) and the bare
# layer are export_pr1's. A leaf pixel (A >= 128) of a hanging module holds what willow22.Willow.module_pixels and
# hangmod22.tones light it by:
#   R, G  the module's normal (octahedral): base 4 / 3 / 2 over 0.64 / 0.36, as the leaf modules
#   A     128 | body | heart << 1 | rank << 2 | code << 4; the module's dark backing: body 0, heart 1 (base - 1)
#         code 0: a leaf of the cap over the anchor (lies on top: +1, its heart +1 more where it faces the sun)
#              B = the blade's way (256 = a whole turn)
#         code 1: a leaf of a strand; B = (its strand's x - the anchor's x + 32) | place << 6, place 0..3: the top
#              leaf, the upper 40 %, the others, the lowest: f = dx / 12 x (sun right ? 1 : -1) x 0.9 + 0.45 / 0.2 /
#              -0.15 / -0.35; +1 over 0.3 (its heart +1 more over 0.55), -1 under -0.4 (the quarter rule in shade)
#         code 2: as 1, a strand of the far curtain seen through the voids (drawn behind the trunk): base 2, d = -1
# Palms (look.yaml `rule: palms`): the leaves' light is baked, as the bark's: the mockup's step at each of the 8 suns
# in half steps (0..12), 4 bits a sun: R = suns 0, 1, G = 2, 3, B = 4, 5 (low nibble first), the bare layer's L, A =
# suns 6, 7 and 0 (palms keep their leaves: the bare layer under a leaf is free); A = 128 | outline (the soft outline:
# the step is the leaf's own, drawn half way to the ramp's step 0). The trunk: A = 2 wood as the others' (2 bits a
# sun), A = 3 its soft outline (spikes, root nubs: the trunk's own step, drawn half way to the bark's step 0); the
# bare layer under the trunk = the trunk without the crown's contact shadow (the bark where no crown shades it).
import os, sys, math, time, numpy as np
from multiprocessing import Pool
import export_pr1 as E

SIZES = E.SIZES
VARIANTS = E.VARIANTS
KEYS = ['willow', 'palm', 'fan_palm']
SUN_T, sun_at, octa = E.SUN_T, E.sun_at, E.octa


def _sun(t, k):
    import render7 as R
    L = R.norm(sun_at(SUN_T[k]))
    t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
    for a_ in ('_cover', '_shadow_cache'):
        if hasattr(t, a_): setattr(t, a_, None)
    return L


# ------------------------------------------------------------------ willow
def build_willow(s, v):
    import all23 as A, shapes24 as S24, willow22 as W22, look24 as L
    A._taller()
    S24.use3d(True)
    extra = {} if v == 0 else dict(seed=1 + 7 * v, warp=11 + 5 * v)
    return W22.willow(s, W=L.W, H=L.H, **extra)


def _place(i, n):
    return 0 if i == 0 else (1 if i < n * 0.4 else (2 if i < n - 1 else 3))


def hang_pixels(t, p, n, mod):
    """(Y, X, A bits w/o rank and code, code, B, leaf mask) of a hanging module's pixels, as Willow.module_pixels lays
    them (leaves and the dark backing)."""
    import hang22 as HG
    assert mod.get('style') == 'hang' and 'half_w' not in mod
    leaf, role = mod['leaf'], mod['role']
    mask = (leaf >= 0) | mod['back']
    sx, sy = t.proj(p)
    ax0, ay0 = mod['anchor']
    X0 = int(round(sx)) - ax0; Y0 = int(round(sy)) - ay0
    ys, xs = np.nonzero(mask)
    a = np.zeros(len(ys), int); code = np.zeros(len(ys), int); b = np.zeros(len(ys), int)
    lm = np.zeros(len(ys), bool)
    for q, (y, x) in enumerate(zip(ys, xs)):
        k = leaf[y, x]
        if k < 0:
            a[q] = 2
            continue
        lm[q] = True
        c = role[y, x]
        body = c not in 'OV'; heart = c == 'H'
        a[q] = int(body) | (int(heart) << 1)
        nm, x0, y0, ax, si, i, nn = mod['leaves'][k]
        if si < 0:
            br = HG.B[nm]
            way = br.way if not mod['flip'] else math.pi - br.way
            b[q] = int(round((way % math.tau) / math.tau * 256)) % 256
        else:
            dx = ax - ax0
            assert -32 <= dx < 32, dx
            code[q] = 1
            b[q] = (dx + 32) | (_place(i, nn) << 6)
    return ys + Y0, xs + X0, a, code, b, lm


def willow_layer(t, skip):
    """(H, W, 4) of the leaf pixels as Willow.render lays them: the far curtain's strands in the voids (code 2) first,
    then (after the wood and the core, see frames) every module in the cascade order. -> (inner layer, front layer,
    owner of each pixel)"""
    H, W = t.H, t.W
    inner = np.zeros((H, W, 4), np.uint8); front = np.zeros((H, W, 4), np.uint8)
    owner = np.full((H, W), -1, int)
    for j, (p, n, mod) in enumerate(t.mods):
        if not t.voids or t.zrel[j] >= 0: continue
        Y, X, a, code, b, lm = hang_pixels(t, p, n, mod)
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        k = ok.copy()
        k[ok] = t.in_void(Y[ok], X[ok], 'back') & t.in_void(Y[ok], X[ok], 'front') & lm[ok]
        nr, ng = octa(n)
        cd = np.where(code[k] == 1, 2, code[k])
        inner[Y[k], X[k]] = np.stack([np.full(k.sum(), nr), np.full(k.sum(), ng), b[k], 128 | a[k] | (cd << 4)], 1)
        owner[Y[k], X[k]] = j
    fowner = np.full((H, W), -1, int)
    for j, (p, n, mod) in enumerate(t.mods):
        if j in skip: continue
        Y, X, a, code, b, lm = hang_pixels(t, p, n, mod)
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        Y, X, a, code, b, lm = Y[ok], X[ok], a[ok], code[ok], b[ok], lm[ok]
        if t.voids:
            if t.zrel[j] < 0:
                fv = t.in_void(Y, X, 'front')
                k = ~fv | (lm & ~t.in_void(Y, X, 'back'))
            else:
                k = lm | ~t.in_void(Y, X, 'front')
            Y, X, a, code, b = Y[k], X[k], a[k], code[k], b[k]
        nr, ng = octa(n)
        front[Y, X] = np.stack([np.full(len(Y), nr), np.full(len(Y), ng), b, 128 | a | (code << 4)], 1)
        fowner[Y, X] = j
    return inner, front, owner, fowner


def willow_frames(s, v):
    import feet25 as F
    F.install()
    import kinds24 as K, outline23 as O, all23 as A, bases22 as B22
    from render2 import hexc
    t = build_willow(s, v)
    snap = K.willow_snapshot(t)
    bark = np.array(t.bark, int)
    res = []; bares = []
    for n in range(8):
        K.willow_turn(t, n, snap)
        _sun(t, 0)
        t.render(ground=A.KEY_G, shade=A.KEY_S)          # sets t.skipped (sun-independent)
        skip = set(t.skipped)
        core = t.core()
        inner, front, iown, fown = willow_layer(t, skip)
        innerm = inner[..., 3] >= 128; frontm = front[..., 3] >= 128
        wood16 = np.zeros((t.H, t.W), np.int64); woodm = np.zeros((t.H, t.W), bool)
        for k in range(8):
            _sun(t, k)
            t._core = core
            img = t.render(ground=A.KEY_G, shade=A.KEY_S, skip=skip)
            O.outline(img, 'willow')
            a = img.astype(int)
            for i in range(4):
                m = np.all(a == bark[i], 2) & ~frontm & ~core
                wood16[m] |= i << (2 * k); woodm |= m
        g = inner.copy()
        w = woodm
        g[w, 0] = wood16[w] & 255; g[w, 1] = (wood16[w] >> 8) & 255; g[w, 2] = 0; g[w, 3] = 2
        cm = core & ~frontm
        g[cm] = 0; g[cm, 3] = 1
        g[frontm] = front[frontm]
        own = np.where(frontm, fown, np.where(g[..., 3] >= 128, iown, -1))
        leaf = g[..., 3] >= 128
        if leaf.any():
            cx, cy, reach = E.edge_reach(leaf)
            ys, xs = np.nonzero(leaf)
            js = own[ys, xs]
            cnt = np.bincount(js, minlength=len(t.mods)).astype(float)
            mx = np.bincount(js, xs, minlength=len(t.mods)) / np.maximum(cnt, 1)
            my = np.bincount(js, ys, minlength=len(t.mods)) / np.maximum(cnt, 1)
            rank = np.minimum(3, (4 * E.edge_r2(cx, cy, reach, mx, my)).astype(int))
            g[ys, xs, 3] |= rank[js].astype(np.uint8) << 2
            cy_, cx_ = np.nonzero(g[..., 3] == 1)
            g[cy_, cx_, 0] = np.round(255 * E.edge_r2(cx, cy, reach, cx_, cy_)).astype(np.uint8)
        # the bare tree: the whole skeleton without the crown's shade
        bare16 = np.zeros((t.H, t.W), np.int64); barem = np.zeros((t.H, t.W), bool)
        t.crown = False
        try:
            for k in range(8):
                _sun(t, k)
                img = np.zeros((t.H, t.W, 3), np.uint8); img[:] = hexc(A.KEY_G)
                B22.Based.draw_trunk(t, img)
                O.outline(img, 'willow')
                a = img.astype(int)
                for i in range(4):
                    m = np.all(a == bark[i], 2)
                    bare16[m] |= i << (2 * k); barem |= m
        finally:
            t.crown = True
        bare16[~barem] = 0
        res.append(g); bares.append(np.where(barem, bare16 | (1 << 16), 0).astype(np.uint32))
    meta = dict(ox=float(t.ox), oy=float(t.oy), ramp=[list(map(int, c)) for c in t.ramp],
                bark=[list(map(int, c)) for c in t.bark])
    meta['bare'] = np.array(bares)
    return np.array(res), meta


# ------------------------------------------------------------------ palms
def build_palm(key, s, v):
    import palmtree22 as PT, look24 as L
    return PT.Palm('feather' if key == 'palm' else 'fan', s, W=L.W, H=L.H, ox=L.W / 2 + 0.5, seed=11 + 7 * v)


def palm_steps(p, L):
    """Palm.layers' steps at sun L: (trunk steps 0..3 / -1, trunk own steps, trunk soft-outline mask, crown steps (half
    steps, -9 empty), crown own steps, crown outline mask, trunk steps without the crown's shadow)."""
    import palmtree22 as PT, palm22 as P, palms22 as PS
    L = PT.unit(L)
    W, H, ox, oy = p.W, p.H, p.ox, p.oy
    lp = PT.leaf_points(p.crown)
    smap = PT.ShadowMap(lp, L)
    top = p.trunk.top()
    cy = oy + PT.ZS * top[2] - top[1]
    tx = {}
    st, mask = PT.draw_trunk(p.trunk, W, H, ox, oy, L, smap, reach=14 * p.k, spike_top=int(cy + p.trunk.r_top + 3), extra=tx)
    open_, _ = PT.draw_trunk(p.trunk, W, H, ox, oy, L, None, reach=14 * p.k, spike_top=int(cy + p.trunk.r_top + 3))
    kw = dict(PS.FAN_DRAW if p.kind == 'fan' else PS.FEATHER_DRAW)
    if kw.get('heart'):
        r = max(2, kw['heart'][0] * p.k)
        if p.kind == 'fan' and p.k < 0.9:
            r = max(r, p.trunk.r_top + 0.5)
        kw['heart'] = (r, kw['heart'][1])
    if p.kind == 'fan': kw['ring'] = max(1, int(round(kw['ring'] * (0.6 + 0.4 * p.k))))
    cx = {}
    cs, _ = P.draw(p.crown, Lsun=L, extra=cx, **kw)
    assert p.soft == 2.0
    return st, tx['pre'], tx['line'] & (st >= 0), cs, cx['pre'], cx['out'], open_


def palm_frames(key, s, v):
    import feet25 as F
    F.install()
    import kinds24 as K
    p = build_palm(key, s, v)
    snap = K.palm_snapshot(p)
    res = []; bares = []
    for n in range(8):
        K.palm_turn(p, n, snap)
        H, W = p.H, p.W
        crown = None; tm = None
        cst = np.zeros((8, H, W), int); tst = np.zeros((8, H, W), int); ost = np.zeros((8, H, W), int)
        for k in range(8):
            st, tpre, tline, cs, cpre, cout, op = palm_steps(p, sun_at(SUN_T[k]))
            cm = cs > -9
            if crown is None:
                crown, couts, tm, tlines = cm, cout, st >= 0, tline
            assert (crown == cm).all() and (couts == cout).all() and (tm == (st >= 0)).all() and (tlines == tline).all()
            own = np.where(cout, cpre, cs)
            h2 = np.round(np.clip(own, 0, 6) * 2)
            assert np.abs(h2[cm] - np.clip(own, 0, 6)[cm] * 2).max() < 1e-6, 'a step off the half-step grid'
            cst[k] = h2.astype(int)
            tst[k] = np.where(tline, np.clip(tpre, 0, 3), st)
            ost[k] = np.where(tline, np.clip(tpre, 0, 3), op)    # the soft outline keeps its own step in the open too
        g = np.zeros((H, W, 4), np.uint8)
        bare = np.zeros((H, W), np.uint32)
        wood = tm & ~crown
        w16 = np.zeros((H, W), np.int64); o16 = np.zeros((H, W), np.int64)
        for k in range(8):
            w16 |= tst[k].astype(np.int64) << (2 * k); o16 |= ost[k].astype(np.int64) << (2 * k)
        g[wood, 0] = w16[wood] & 255; g[wood, 1] = (w16[wood] >> 8) & 255
        g[wood, 3] = np.where(tlines[wood], 3, 2)
        bare[wood] = (o16[wood] | (1 << 16)).astype(np.uint32)
        c = cst
        g[crown, 0] = c[0][crown] | (c[1][crown] << 4)
        g[crown, 1] = c[2][crown] | (c[3][crown] << 4)
        g[crown, 2] = c[4][crown] | (c[5][crown] << 4)
        g[crown, 3] = 128 | couts[crown].astype(np.uint8)
        # the bare layer under a palm's leaf: suns 6, 7 (bit 17 marks it for pack_pr3)
        bare[crown] = (c[6][crown] | (c[7][crown] << 4) | (1 << 17)).astype(np.uint32)
        res.append(g); bares.append(bare)
    meta = dict(ox=float(p.ox), oy=float(p.oy), ramp=[[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in p.ramp],
                bark=[[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in p.bark])
    meta['bare'] = np.array(bares)
    return np.array(res), meta


def frames(key, s, v):
    return willow_frames(s, v) if key == 'willow' else palm_frames(key, s, v)


def job(args):
    out, key, s, v = args
    t0 = time.time()
    fr, meta = frames(key, s, v)
    os.makedirs(os.path.join(out, key), exist_ok=True)
    np.savez_compressed(os.path.join(out, key, '%.2f_%d.npz' % (s, v)), frames=fr, **{k: np.array(x) for k, x in meta.items()})
    return key, s, v, round(time.time() - t0, 1)


if __name__ == '__main__':
    out = sys.argv[1]
    keys = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] else KEYS
    nw = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    sizes = [float(x) for x in sys.argv[4].split(',')] if len(sys.argv) > 4 else SIZES[::-1]
    jobs = [(out, k, s, v) for s in sizes for k in keys for v in range(VARIANTS)]
    jobs = [j for j in jobs if not os.path.exists(os.path.join(out, j[1], '%.2f_%d.npz' % (j[2], j[3])))]
    with Pool(nw) as p:
        for r in p.imap_unordered(job, jobs):
            print(*r, flush=True)
