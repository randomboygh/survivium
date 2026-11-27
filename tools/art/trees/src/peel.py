# Split a reference module of sheet 123 into its leaves: the module is the leaf icons ("brushes")
# stamped one over another, so take it apart from the top: a stamp whose every pixel shows (matches
# the flat module) lies on top; its pixels then may be anything for the stamps under it.
import numpy as np, sys
import ref123 as R
from scipy import ndimage

ICON_BOX = {'dots': (133, 140, 38, 52), 'blades': (131, 142, 104, 150), 'round': (131, 142, 188, 231)}

def icons(style, a=None):
    a = R.sheet() if a is None else a
    r0, r1, c0, c1 = ICON_BOX[style]
    m = R.index(a[r0:r1 + 1, c0:c1 + 1], style)
    lab, n = ndimage.label(m >= 0, structure=np.ones((3, 3)))
    out = []
    for k in range(1, n + 1):
        ys, xs = np.nonzero(lab == k)
        sub = np.where(lab[ys.min():ys.max() + 1, xs.min():xs.max() + 1] == k,
                       m[ys.min():ys.max() + 1, xs.min():xs.max() + 1], -1)
        out.append(sub)
    out.sort(key=lambda s: 0)
    return out

def transforms(b):
    res = []
    for mir in (0, 1):
        x = b[:, ::-1] if mir else b
        for q in range(4):
            res.append(((q, mir), np.rot90(x, -q).copy()))     # q quarter turns clockwise
    # drop duplicates (symmetric brushes)
    uniq = []
    for t, s in res:
        if not any(s.shape == u.shape and (s == u).all() for _, u in uniq):
            uniq.append((t, s))
    return uniq

def peel(F, brushes, min_new=3, max_bad=0, verbose=False):
    """F: flat module (-1 empty, else ramp index). brushes: list of index maps. Returns the stamps
    top first: (brush, turn, y, x, stamp)."""
    H, W = F.shape
    done = np.zeros((H, W), bool)
    cands = []
    for bi, b in enumerate(brushes):
        for t, s in transforms(b):
            h, w = s.shape
            for y in range(-h + 1, H):
                for x in range(-w + 1, W):
                    cands.append((bi, t, y, x, s))
    stamps = []
    while not done[F >= 0].all():
        best = None
        for bi, t, y, x, s in cands:
            h, w = s.shape
            ys, xs = np.nonzero(s >= 0)
            Y, X = ys + y, xs + x
            ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
            if not ok.all(): continue          # a leaf never pokes out of the module's box
            if (F[Y, X] < 0).any(): continue  # nor out of its silhouette
            new = ~done[Y, X]
            nn = int(new.sum())
            if nn < min_new: continue
            bad = int((F[Y, X][new] != s[ys, xs][new]).sum())
            if bad > max_bad: continue
            # prefer stamps that show whole (few hidden pixels), then big ones
            score = (nn - 3 * bad) + 0.5 * nn / len(ys) * len(ys) - 0.2 * (len(ys) - nn)
            if best is None or score > best[0]:
                best = (score, bi, t, y, x, s, nn, bad)
        if best is None:
            if verbose: print('stuck, left', int((~done & (F >= 0)).sum()))
            break
        sc, bi, t, y, x, s, nn, bad = best
        ys, xs = np.nonzero(s >= 0)
        done[ys + y, xs + x] = True
        stamps.append((bi, t, y, x, s))
        if verbose: print('brush %d turn %s at %d,%d new %d bad %d' % (bi, t, y, x, nn, bad))
    return stamps, done

def compose(stamps, shape):
    """Draw the stamps bottom first (the list is top first)."""
    out = np.full(shape, -1, int); own = np.full(shape, -1, int)
    for k in range(len(stamps) - 1, -1, -1):
        bi, t, y, x, s = stamps[k]
        ys, xs = np.nonzero(s >= 0)
        out[ys + y, xs + x] = s[ys, xs]; own[ys + y, xs + x] = k
    return out, own

if __name__ == '__main__':
    st = sys.argv[1]
    a = R.sheet()
    br = icons(st, a)
    for b in br: print(R.show(b)); print()
    F = R.module(st, 0, 0, a)
    stamps, done = peel(F, br, verbose=True, max_bad=int(sys.argv[2]) if len(sys.argv) > 2 else 0)
    out, own = compose(stamps, F.shape)
    print('stamps', len(stamps), 'mismatch', int(((out != F) & (F >= 0)).sum()), 'extra', int(((out >= 0) & (F < 0)).sum()),
          'unexplained', int(((out < 0) & (F >= 0)).sum()))
