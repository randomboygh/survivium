# Checks export_pr2's frames of a conifer against the mockup pixel for pixel: python3 chk_pr2.py <npz> <key> <s>
# <v> [turns] [suns]. The mockup renders the tree at each turn and sun; the frame decoded by decode_pr2 must give the
# same colours (frond pixels whose n . L or e . L sit at a threshold may differ by the 8-bit quantisation).
import sys, numpy as np
import export_pr2 as E2, decode_pr2 as D, render7 as R, all23 as A, outline23 as O
import feet25 as F; F.install()
import conifer24 as C24

npz, key, s, v = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
turns = [int(x) for x in sys.argv[5].split(',')] if len(sys.argv) > 5 else [0, 3]
suns = [int(x) for x in sys.argv[6].split(',')] if len(sys.argv) > 6 else [0, 4, 7]
d = np.load(npz)
fr, bare = d['frames'], d['bare']
t = E2.build(key, s, v); snap = C24.snapshot(t)
tot = 0; bad = 0
for n in turns:
    C24.turn(t, n, snap)
    for k in suns:
        E2._suns(t, k)
        img = t.render(ground=A.KEY_G, shade=A.KEY_S); O.outline(img, key)
        dec, m = D.decode(fr[n], t.L, k, [list(c) for c in t.ramp], [list(c) for c in t.bark])
        diff = np.any(np.abs(dec.astype(int) - img.astype(int)) > 1, 2) & m
        # pixels the mockup draws in the tree's colours that the frame lacks
        tree_px = np.zeros(m.shape, bool)
        for c in list(t.ramp) + list(t.bark):
            tree_px |= np.all(img.astype(int) == np.array(c, int), 2)
        miss = tree_px & ~m
        imgb = E2.render_bare(t, key)
        decb, mb = D.decode_bare(bare[n], k, [list(c) for c in t.bark])
        diffb = np.any(np.abs(decb.astype(int) - imgb.astype(int)) > 1, 2) & mb
        print('turn', n, 'sun', k, 'pixels', int(m.sum()), 'differ', int(diff.sum()), 'missing', int(miss.sum()),
              '| bare', int(mb.sum()), 'differ', int(diffb.sum()), flush=True)
        tot += int(m.sum()); bad += int(diff.sum())
        ys, xs = np.nonzero(diff)
        for y, x in list(zip(ys, xs))[:3]:
            print('   ', (y, x), fr[n][y, x], dec[y, x], img[y, x])
print('total', tot, 'differ', bad)
