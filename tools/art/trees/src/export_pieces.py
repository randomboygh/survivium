# Trees PR 6a (world pieces in the game): export each species' approved log, fallen trunk and broken trunk with a
# sprout (round 23 step 3 + round 24 turns, soft outline 'step', medium size s 0.68) at the camera's 8 turns, summer
# and winter (hot species: winter = summer), as pictures the game lights live, like the stumps (export_pr5.py): per
# texel the step it takes under each of the 8 suns of the game's day path.
# Run from tools/art/trees/src/ (README.md there):  python3 export_pieces.py <out dir> [keys] [workers]  -> <out>/<key>.npz
# A texel: the codes of export_pr5.py (2 bark, 3 palm soft outline, 4 cut wood, 5 snow, 6 snow outline) and
#   7 a sprout's leaf: R, G, B = the step of the tree's leaf ramp (0..6) at the 8 suns, 3 bits each.
import os, sys, time, numpy as np
from multiprocessing import Pool
import export_pr5 as X

S = 0.68
KINDS = ('log', 'fallen', 'broken')


def picture(kind, key, deg, sun, winter):
    import stumps24 as S24, pieces24 as P, stump23 as ST, outline23 as OL, logs23 as LG
    if kind == 'broken':
        br = S24.Broken24(key, S, deg=deg, sun=sun)
        a = (br.winter() if winter and key not in ST.HOT else br.summer()).copy()
        OL.outline(a, key)
        return place(a, br.ox, br.oy), br
    cls = LG.Log if kind == 'log' else LG.Fallen
    p = cls(key, S, sun=sun)
    P.turn_scene(p.sc, deg)
    a = p.picture(snow=LG.SNOW_T if winter and key not in ST.HOT else None).copy()
    OL.outline(a, key)
    return place(a, p.ox, p.oy), p


CANVAS = (360, 520)   # h, w: every view put on one canvas with the piece's origin at ORIGIN
ORIGIN = (240, 260)   # y, x


def place(a, ox, oy):
    import all23 as A
    from render2 import hexc
    out = np.zeros(CANVAS + (3,), np.uint8); out[:] = hexc(A.KEY_G)
    # the origin's pixel (pack_pr5 took int() of the stumps' too)
    dy, dx = ORIGIN[0] - int(oy), ORIGIN[1] - int(ox)
    import all23 as A2
    from render2 import hexc as hx
    h, w = a.shape[:2]
    ya, xa = max(0, -dy), max(0, -dx)
    yb, xb = min(h, CANVAS[0] - dy), min(w, CANVAS[1] - dx)
    keep = a.copy()
    # what falls off the canvas must be only ground or shadow
    m = ~(np.all(keep == hx(A2.KEY_G), 2) | np.all(keep == hx(A2.KEY_S), 2))
    m[ya:yb, xa:xb] = False
    assert not m.any(), (a.shape, ox, oy)
    out[dy + ya:dy + yb, dx + xa:dx + xb] = a[ya:yb, xa:xb]
    return out


def views(kind, key):
    import export_pr1 as E, all23 as A, stump23 as ST, sprout23 as SP
    from render2 import hexc
    kg, ks = tuple(hexc(A.KEY_G)), tuple(hexc(A.KEY_S))
    pics = np.zeros((2, 8, 8), object)
    obj = None
    for season in range(2):
        for n in range(8):
            for k, ts in enumerate(E.SUN_T):
                pics[season, n, k], obj = picture(kind, key, 45 * n, E.sun_at(ts), season == 1)
    return pics, obj, kg, ks


def ramps(kind, key, obj):
    import stump23 as ST, sprout23 as SP, logs23 as LG
    bark = wood = leaves = None
    if kind == 'broken':
        bark = obj.bark
        leaves = SP.ramp_of(obj)
    else:
        sc = obj.sc
        bark = sc.bark if hasattr(sc, 'bark') else obj.bark
    wood = ST.wood_ramp(key)
    rnd = lambda cs: [tuple(int(v) for v in np.round(c[:3])) for c in cs]
    return rnd(bark), rnd(wood), (rnd(leaves) if leaves is not None else [])


def export(kind, key):
    import stump23 as ST
    pics, obj, kg, ks = views(kind, key)
    bark, wood, leaves = ramps(kind, key, obj)
    cls = X.classes(bark, wood, tuple(int(v) for v in ST.RESIN_RGB))
    for i, c in enumerate(leaves):
        cls.setdefault(tuple(c), (7, i))
    out = []; bad = {}; mixed = 0
    codes = (2, 3, 4, 5, 6, 7)
    for season in range(2):
        for n in range(8):
            seen = None
            for k in range(8):
                a = pics[season, n, k].astype(int)
                m = ~(np.all(a == kg, 2) | np.all(a == ks, 2))
                seen = m if seen is None else seen | m
            ys, xs = np.nonzero(seen)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            h, w = y1 - y0, x1 - x0
            code = np.zeros((8, h, w), int); step = np.zeros((8, h, w), int)
            for k in range(8):
                a = pics[season, n, k][y0:y1, x0:x1]
                for c in set(map(tuple, a.reshape(-1, 3))):
                    if c == kg or c == ks:
                        continue
                    m = np.all(a == c, 2)
                    if c not in cls:
                        bad[c] = bad.get(c, 0) + int(m.sum()); continue
                    cd, st = cls[c]
                    code[k][m] = cd; step[k][m] = st
            cnt = np.array([(code == cd).sum(0) for cd in codes])
            best = np.where(cnt.max(0) > 0, np.array(codes)[cnt.argmax(0)], 0)
            for k in range(8):
                diff = (code[k] != best) & (best > 0)
                mixed += int(diff.sum())
                for dk in (1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 7, -7):
                    j = k + dk
                    if 0 <= j < 8:
                        fix = diff & (code[j] == best)
                        step[k][fix] = step[j][fix]; diff &= ~fix
            bits = np.zeros((h, w), np.int64)
            for k in range(8):
                two = (best == 2) | (best == 3)
                bits |= np.where(two, (step[k] & 3) << (2 * k), (step[k] & 7) << (3 * k))
            o = np.zeros((h, w, 4), np.uint8)
            on = best > 0
            o[..., 0] = np.where(on, bits & 255, 0)
            o[..., 1] = np.where(on, (bits >> 8) & 255, 0)
            o[..., 2] = np.where(on & (best >= 4), (bits >> 16) & 255, 0)
            o[..., 3] = np.where(on, best + 64, 0)
            out.append((o, ORIGIN[1] - x0, ORIGIN[0] - y0))
    res = dict(bark=np.array(bark), wood=np.array(wood), leaves=np.array(leaves if leaves else [[0, 0, 0]]),
               bad=sum(bad.values()), mixed=mixed, badc=repr(sorted(bad.items(), key=lambda t: -t[1])[:8]))
    for i, (o, ax, ay) in enumerate(out):
        res['v%d' % i] = o; res['a%d' % i] = np.array([ax, ay])
    return res


def job(args):
    out, key = args
    t0 = time.time()
    res = {}
    for kind in KINDS:
        e = export(kind, key)
        for k, v in e.items():
            res['%s_%s' % (kind, k)] = np.array(v)
    np.savez_compressed(os.path.join(out, '%s.npz' % key), **res)
    return key, [(kd, int(res['%s_bad' % kd]), int(res['%s_mixed' % kd]), str(res['%s_badc' % kd])[:80])
                 for kd in KINDS], round(time.time() - t0, 1)


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
