# PR 3: numpy model of tree.gdshader's willow (hanging) and palm (baked) rules, to check export_pr3's frames pixel for
# pixel against the mockup at the 8 suns:  python3 decode_pr3.py <export dir> <key> <s> <v> [turns]
import sys, math, numpy as np
import export_pr1 as E, export_pr3 as E3

D1, D2, DP = 0.64, 0.36, 0.8


def unocta(r, g):
    ex = r / 255.0 * 2 - 1; ey = g / 255.0 * 2 - 1
    n = np.stack([ex, ey, 1 - np.abs(ex) - np.abs(ey)], -1)
    neg = n[..., 2] < 0
    x = (1 - np.abs(n[..., 1])) * np.where(n[..., 0] >= 0, 1, -1)
    y = (1 - np.abs(n[..., 0])) * np.where(n[..., 1] >= 0, 1, -1)
    n[..., 0] = np.where(neg, x, n[..., 0]); n[..., 1] = np.where(neg, y, n[..., 1])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def colour(ramp, c):
    ramp = np.asarray(ramp, float)
    lo = np.floor(c).astype(int); hi = np.minimum(lo + 1, len(ramp) - 1); f = (c - lo)[..., None]
    return ramp[lo] * (1 - f) + ramp[hi] * f


def hanging_steps(g, L):
    """Steps (0..6, quarters) of willow leaf texels g (k x 4 uint8) under L, as tree.gdshader's hanging_steps."""
    a = g[:, 3].astype(int)
    d = unocta(g[:, 0].astype(float), g[:, 1].astype(float)) @ L
    code = (a >> 4) & 7
    inner = code == 2
    d = np.where(inner, -1.0, d)
    base = np.where(d > D1, 4.0, np.where(d > D2, 3.0, 2.0))
    shade = base < 2.5
    body = (a & 1) != 0; heart = (a & 2) != 0
    v = np.where(body, 0.0, -1.0)
    l2 = np.array([L[0], L[2] - L[1]]); l2 = l2 / np.linalg.norm(l2)
    ang = g[:, 2] / 256.0 * math.tau
    fcap = np.cos(ang) * l2[0] + np.sin(ang) * l2[1]
    vcap = v + 1 + np.where(heart & (fcap > 0.45), 1.0, 0.0)
    dx = (g[:, 2].astype(int) & 63) - 32
    place = g[:, 2].astype(int) >> 6
    cv = np.array([0.45, 0.2, -0.15, -0.35])[place]
    sgn = 1.0 if L[0] >= 0 else -1.0
    f = dx / 12.0 * sgn * 0.9 + cv
    s = np.where(f > 0.3, 1, np.where(f > -0.4, 0, -1))
    vs = v + np.where(s > 0, 1 + np.where(heart & (f > 0.55), 1.0, 0.0), np.where(s < 0, np.where(shade, -0.75, -1.0), 0.0))
    vv = np.where(code == 0, vcap, vs)
    vv = np.where((a & 3) == 2, -1.0, vv)
    c = base + vv
    c = np.where(d < DP, np.minimum(c, 5), c)
    return np.clip(c, 0, 6)


def palm_steps(g, b, k):
    """Half steps of palm leaf texels at sun k (g frames, b bare: 2 bytes)."""
    words = [g[:, 0], g[:, 1], g[:, 2], b[:, 0]]
    byte = words[k // 2].astype(int)
    return ((byte >> (4 * (k % 2))) & 15) / 2.0


def picture(fr, bare, ramp, bark, k, kind):
    """The picture at sun k (the drawn sun itself, no crossfade) as the game draws it (wood steps exact)."""
    H, W = fr.shape[:2]
    img = np.zeros((H, W, 3)); m = np.zeros((H, W), bool)
    a = fr[..., 3].astype(int)
    wood = (a == 2) | (a == 3)
    bits = fr[..., 0].astype(int) | (fr[..., 1].astype(int) << 8)
    st = (bits >> (2 * k)) & 3
    bk = np.asarray(bark, float)
    img[wood] = bk[st[wood]]
    soft = a == 3
    img[soft] = (bk[st[soft]] + bk[0]) / 2
    m |= wood
    core = a == 1
    img[core] = np.asarray(ramp, float)[1]; m |= core
    lf = a >= 128
    if lf.any():
        g = fr[lf]
        if kind == 'palm':
            b = np.stack([bare[..., 0][lf] & 255, bare[..., 0][lf] >> 8], 1) if bare.ndim == 2 else bare[lf]
            c = palm_steps(g, b, k)
            col = colour(ramp, c)
            out = (g[:, 3] & 1) != 0
            col[out] = (col[out] + np.asarray(ramp, float)[0]) / 2
        else:
            c = hanging_steps(g, E.sun_at(E.SUN_T[k]) / np.linalg.norm(E.sun_at(E.SUN_T[k])))
            col = colour(ramp, c)
        img[lf] = col; m |= lf
    return np.round(img).astype(np.uint8), m


if __name__ == '__main__':
    import os
    exp, key, s, v = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
    turns = [int(x) for x in sys.argv[5].split(',')] if len(sys.argv) > 5 else range(8)
    d = np.load(os.path.join(exp, key, '%.2f_%d.npz' % (s, v)))
    fr, bare = d['frames'], d['bare']
    kind = 'palm' if key != 'willow' else 'willow'
    import kinds24 as K, feet25 as F, all23 as A, look24 as L_, outline23 as O
    from render2 import hexc
    F.install()
    if kind == 'palm':
        p = E3.build_palm(key, s, v); snap = K.palm_snapshot(p)
    else:
        p = E3.build_willow(s, v); snap = K.willow_snapshot(p)
    for n in turns:
        (K.palm_turn(p, n, snap) if kind == 'palm' else K.willow_turn(p, n, snap))
        b2 = np.stack([(bare[n] & 255), (bare[n] >> 8) & 255], -1) if kind == 'willow' else None
        tot = []
        for k in range(8):
            if kind == 'palm':
                p.sun = E.sun_at(E.SUN_T[k])
                gs, ref, mref = p.layers(A.KEY_G)
                bb = np.stack([bare[n] & 255, (bare[n] >> 8) & 255], -1)
            else:
                E3._sun(p, k)
                ref = p.render(ground=A.KEY_G, shade=A.KEY_S); O.outline(ref, 'willow')
                kg = np.array(hexc(A.KEY_G)); ks = np.array(hexc(A.KEY_S))
                mref = ~(np.all(ref.astype(int) == kg, 2) | np.all(ref.astype(int) == ks, 2))
                bb = None
            got, m = picture(fr[n], bb if bb is not None else bare[n], d['ramp'], d['bark'], k, kind)
            miss = (mref != m).sum()
            both = mref & m
            diff = np.abs(got[both].astype(int) - ref[both].astype(int)).max(1)
            tot.append((int(miss), int((diff > 2).sum()), int(both.sum())))
        print(key, s, v, 'turn', n, tot, flush=True)
