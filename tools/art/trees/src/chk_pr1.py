import sys, numpy as np, export_pr1 as E, decode_pr1 as D, render7 as R, all23 as A, outline23 as O
import feet25 as F; F.install()
import turn24 as TU
key, s, n, k = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
fr = np.load(sys.argv[5]); fr = fr['frames'] if hasattr(fr, 'files') else fr
t = E.build(key, s, 0); snap = TU.snapshot(t); TU.turn(t, n, snap)
L = R.norm(E.sun_at(E.SUN_T[k])); t.L = L; t.light2 = R.norm((L[0], L[2] - L[1])); t._tones = {}
img = t.render(ground=A.KEY_G, shade=A.KEY_S); O.outline(img, key)
dec, m = D.decode(fr[n], L, k, [list(c) for c in t.ramp], [list(c) for c in t.bark])
diff = np.any(np.abs(dec.astype(int) - img.astype(int)) > 1, 2) & m
print('pixels', m.sum(), 'differ', diff.sum())
ys, xs = np.nonzero(diff); print(list(zip(ys[:10], xs[:10])))
for y, x in list(zip(ys, xs))[:6]:
    print(fr[n][y, x], dec[y, x], img[y, x])
