# PR 5 (stumps in the game): export each species' approved stump (round 23 stump23 + round 24 turns + round 25 feet,
# soft outline 'step') at 3 sizes, the camera's 8 turns, summer and winter (the snow layer; hot species none), as
# pictures the game lights live, like the trees' frames (export_pr1.py): per texel the step it takes under each of the
# 8 suns of the game's day path.
# Run from tools/art/trees/src/ (README.md there):  python3 export_pr5.py <out dir> [keys] [workers]  -> <out>/<key>.npz
# A texel (RGBA8; alpha = the code, stored 64 higher, as pack_pr4 does for 1-3: the engine's import gives a texel
# under alpha 20 a neighbour's colour):
#   2 bark : R, G = the bark ramp's step (0..3) at the 8 suns, 2 bits each (sun k in bits 2k of R | G << 8)
#   3 a palm trunk's soft outline: as bark, drawn half way to the darkest step
#   4 cut wood: R, G, B = the wood ramp's step (0..5, 6 resin) at the 8 suns, 3 bits each (bits 3k of R|G<<8|B<<16)
#   5 snow : as wood, the snow's step (0..5, tree_pictures.gdshaderinc SNOW_STEPS)
#   6 the snow's soft outline: as snow, drawn half way to the darkest step
import os, sys, time, math, numpy as np
from multiprocessing import Pool

SIZES = (0.42, 0.68, 1.0)
SNOW = ['40545c', '748898', '88a0a8', 'a8bcc4', 'd0e4e4', 'f0fcfc']

def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def classes(bark, wood, resin):
    """colour -> (code, step)"""
    m = {}
    b0 = np.array(bark[0], float)
    for i, c in enumerate(bark):
        m[tuple(c)] = (2, i)
    for i, c in enumerate(bark):
        mix = tuple(int(round(v)) for v in (np.array(c, float) + (b0 - c) / 2))
        for d in ((0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)):
            k = tuple(v + e for v, e in zip(mix, d))
            m.setdefault(k, (3, i))
    for i, c in enumerate(wood):
        m.setdefault(tuple(c), (4, i))
    m.setdefault(tuple(resin), (4, 6))
    s0 = np.array(hx(SNOW[0]), float)
    for i, h in enumerate(SNOW):
        c = hx(h)
        m.setdefault(c, (5, i))
        mix = tuple(int(v) for v in (np.array(c, float) + s0) // 2)
        for d in ((0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 1)):
            m.setdefault(tuple(v + e for v, e in zip(mix, d)), (6, i))
    return m

def views(key, s):
    import feet25 as F
    F.install()
    import stumps24 as S24, stump23 as S, outline23 as OL, all23 as A, export_pr1 as E
    from render2 import hexc
    kg, ks = tuple(hexc(A.KEY_G)), tuple(hexc(A.KEY_S))
    pics = np.zeros((2, 8, 8), object)
    st = None
    for n in range(8):
        for k, ts in enumerate(E.SUN_T):
            st = S24.Stump24(key, s, deg=45 * n, sun=E.sun_at(ts))
            a = st.pic.copy()
            b = a.copy() if key in S.HOT else S.snow_layer(st).copy()
            OL.outline(a, key); OL.outline(b, key)
            pics[0, n, k] = a; pics[1, n, k] = b
    bark = [tuple(int(v) for v in np.round(c)) for c in st.bark]
    wood = [tuple(int(v) for v in np.round(c)) for c in S.wood_ramp(key)]
    return pics, bark, wood, (st.ox, st.oy), kg, ks, key not in S.HOT

def export(key, s):
    import stump23 as S
    pics, bark, wood, (ox, oy), kg, ks, snowy = views(key, s)
    cls = classes(bark, wood, tuple(int(v) for v in S.RESIN_RGB))
    H, W, _ = pics[0, 0, 0].shape
    seen = np.zeros((H, W), bool)
    for p in pics.flat:
        a = p.astype(int)
        seen |= ~(np.all(a == kg, 2) | np.all(a == ks, 2))
    ys, xs = np.nonzero(seen)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    h, w = y1 - y0, x1 - x0
    out = np.zeros((2, 8, h, w, 4), np.uint8)
    bad = 0; mixed = 0
    for season in range(2):
        for n in range(8):
            code = np.zeros((8, h, w), int); step = np.zeros((8, h, w), int)
            for k in range(8):
                a = pics[season, n, k][y0:y1, x0:x1]
                for c in set(map(tuple, a.reshape(-1, 3))):
                    if c == kg or c == ks:
                        continue
                    m = np.all(a == c, 2)
                    if c not in cls:
                        bad += int(m.sum()); continue
                    cd, st = cls[c]
                    code[k][m] = cd; step[k][m] = st
            # a texel's code: the most common over the suns (it is the same at every sun but at a few edges)
            cnt = np.array([(code == cd).sum(0) for cd in (2, 3, 4, 5, 6)])
            best = np.where(cnt.max(0) > 0, cnt.argmax(0) + 2, 0)
            for k in range(8):
                diff = (code[k] != best) & (best > 0)
                mixed += int(diff.sum())
                # a sun where the texel is of another kind: the step of the nearest sun where it is of its own
                for dk in (1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7):
                    j = k + dk
                    if 0 <= j < 8:
                        fix = diff & (code[j] == best)
                        step[k][fix] = step[j][fix]; diff &= ~fix
            bits = np.zeros((h, w), np.int64)
            for k in range(8):
                two = (best == 2) | (best == 3)
                bits |= np.where(two, (step[k] & 3) << (2 * k), (step[k] & 7) << (3 * k))
            o = out[season, n]
            on = best > 0
            o[..., 0] = np.where(on, bits & 255, 0)
            o[..., 1] = np.where(on, (bits >> 8) & 255, 0)
            o[..., 2] = np.where(on & (best >= 4), (bits >> 16) & 255, 0)
            o[..., 3] = np.where(on, best + 64, 0)
    return dict(frames=out, ax=ox - x0, ay=oy - y0, bark=np.array(bark), wood=np.array(wood),
                snow=snowy, bad=bad, mixed=mixed)

def job(args):
    out, key = args
    t0 = time.time()
    res = {}
    for i, s in enumerate(SIZES):
        e = export(key, s)
        for k, v in e.items():
            res['%d_%s' % (i, k)] = np.array(v)
    np.savez_compressed(os.path.join(out, '%s.npz' % key), **res)
    return key, [(int(res['%d_bad' % i]), int(res['%d_mixed' % i]), res['%d_frames' % i].shape[2:4]) for i in range(3)], \
        round(time.time() - t0, 1)

if __name__ == '__main__':
    import all23 as A
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    keys = sys.argv[2].split(',') if len(sys.argv) > 2 and sys.argv[2] else [k for k, *_ in A.TREES]
    nw = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    jobs = [(out, k) for k in keys if not os.path.exists(os.path.join(out, '%s.npz' % k))]
    with Pool(nw) as p:
        for r in p.imap_unordered(job, jobs):
            print(*r, flush=True)
