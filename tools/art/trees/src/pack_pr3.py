# PR 3: packs export_pr3's frames of the willow and the palms into content/plants/<key>/tree/ (frames.png, bare.png,
# look.yaml), as pack_pr1/2 do, with:
#   - `since: 3` (they came with WorldCells.TREE_LOOKS 3: a chunk saved before grows its willows and palms again);
#   - `rule: hanging` (willow) / `rule: palms` (tree.gdshader, see export_pr3.py); a palm's bare layer under its leaves
#     holds suns 6 and 7 of the leaf (grey) and 0 (alpha);
#   - the willow's crown cells from its bell (squash 0.55, as the broadleaf crowns), not below LOWEST cells over the
#     foot (the old weeping crown's curtain kept a cell over the ground too: one walks in under the strands); its
#     trunk up to the dome's rim (the strands hang round it), capped by probe_cap;
#   - a palm's crown cells: those its leaves pass through (unsquashed: the palms are drawn in true 3D), its trunk the
#     drawn trunk's height in whole cells (to the crown's heart), capped by probe_cap.
# python3 pack_pr3.py <export dir> <repo> [keys]   (run from tools/art/trees/src/)
import os, sys, math, base64, numpy as np
from PIL import Image
import export_pr3 as E3, pack_pr1 as P1

SINCE = 3
RULE = {'willow': 'hanging', 'palm': 'palms', 'fan_palm': 'palms'}
LOWEST = 2          # the willow's crown cells begin this many cells over the foot's
R_ = 14


def grid_of(m):
    """(x0, z0, nx, ny, nz, bits) of a crown mask (z, y, x) over x, z in -R_..R_."""
    if not m.any(): return 0, 0, 0, 0, 0, b''
    zi, yi, xi = np.nonzero(m)
    z0, z1, x0, x1 = zi.min(), zi.max(), xi.min(), xi.max()
    m = m[z0:z1 + 1, :yi.max() + 1, x0:x1 + 1]
    nz, ny, nx = m.shape
    bits = np.packbits(m.reshape(-1), bitorder='little')
    return int(x0 - R_), int(z0 - R_), nx, ny, nz, bits.tobytes()


def willow_grid(t):
    x0, z0, nx, ny, nz, bits = P1.crown_grid(t)
    m = np.unpackbits(np.frombuffer(bits, np.uint8), bitorder='little')[:nx * ny * nz].reshape(nz, ny, nx).astype(bool)
    m[:, :LOWEST, :] = False
    full = np.zeros((2 * R_ + 1, ny, 2 * R_ + 1), bool)
    full[z0 + R_:z0 + R_ + nz, :, x0 + R_:x0 + R_ + nx] = m
    return grid_of(full)


def palm_grid(p):
    import palmtree22 as PT
    lp = PT.leaf_points(p.crown, 0.5)
    # the tree's own frame: x east, y up from the foot, z south; the foot's cell's middle at 0
    X = np.floor(lp[:, 0] / 8.0 + 0.5).astype(int); Z = np.floor(lp[:, 2] / 8.0 + 0.5).astype(int)
    Y = np.floor(lp[:, 1] / 8.0).astype(int)
    ny = Y.max() + 1
    m = np.zeros((2 * R_ + 1, ny, 2 * R_ + 1), bool)
    ok = (np.abs(X) <= R_) & (np.abs(Z) <= R_) & (Y >= 0)
    m[Z[ok] + R_, Y[ok], X[ok] + R_] = True
    return grid_of(m)


def pack(exp, repo, key):
    import render16 as G
    looks = []
    for s in E3.SIZES:
        for v in range(E3.VARIANTS):
            d = np.load(os.path.join(exp, key, '%.2f_%d.npz' % (s, v)))
            fr, bare = d['frames'], d['bare']
            m = ((fr[..., 3] > 0) | (bare > 0)).any(0)
            ys, xs = np.nonzero(m)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            if key == 'willow':
                t = E3.build_willow(s, v)
                lo, hi = t.yrange()
                grid = willow_grid(t)
                trunk = max(LOWEST, int((t.y_rim + t.cy) / 8.0))     # up to the dome's rim, as drawn
                ax = int(d['ox']) + G.BX - x0
            else:
                t = E3.build_palm(key, s, v)
                grid = palm_grid(t)
                trunk = max(2, int(t.trunk.Ht / 8.0))
                ax = int(math.floor(float(d['ox']))) - x0
            cap = P1.probe_cap(grid)
            drawn = trunk
            if cap is not None: trunk = min(trunk, cap)
            looks.append(dict(s=s, v=v, fr=fr[:, y0:y1, x0:x1], bare=bare[:, y0:y1, x0:x1],
                              ax=ax, ay=int(math.floor(float(d['oy']))) - y0, trunk=trunk, cap=cap,
                              grid=grid, ramp=d['ramp'], bark=d['bark'], drawn=drawn))
    for v in range(E3.VARIANTS):
        nxt = None
        for lk in sorted([l for l in looks if l['v'] == v], key=lambda l: -l['s']):
            if nxt is not None and lk['trunk'] >= nxt: lk['trunk'] = nxt - 1
            assert 1 <= lk['trunk'] and (lk['cap'] is None or lk['trunk'] <= lk['cap']), (key, lk['s'], v, lk['trunk'], lk['cap'])
            nxt = lk['trunk']
    W = max(8 * l['fr'].shape[2] for l in looks)
    Ht = sum(l['fr'].shape[1] for l in looks)
    top = np.zeros((Ht, W, 4), np.uint8); bare = np.full((Ht, W, 2), 255, np.uint8)
    y = 0
    for l in looks:
        h, w = l['fr'].shape[1:3]
        for n in range(8):
            top[y:y + h, n * w:(n + 1) * w] = l['fr'][n]
            b = l['bare'][n].astype(np.int64)
            leaf = (b & (1 << 17)) != 0
            bits = b & 0xffff
            bits = np.where(bits == 0xffff, 0xfeff, bits)
            bits = np.where(b > 0, bits, 0xffff)
            lo_ = np.where(leaf, b & 255, bits & 255); hi_ = np.where(leaf, 0, bits >> 8)
            bare[y:y + h, n * w:(n + 1) * w, 0] = lo_
            bare[y:y + h, n * w:(n + 1) * w, 1] = hi_
        l['x'], l['y'], l['w'], l['h'] = 0, y, w, h
        y += h
    out = os.path.join(repo, 'content', 'plants', key, 'tree')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(top, 'RGBA').save(os.path.join(out, 'frames.png'), optimize=True)
    Image.fromarray(bare, 'LA').save(os.path.join(out, 'bare.png'), optimize=True)
    hx = lambda c: '"#%02x%02x%02x"' % tuple(int(a) for a in c)
    L = ['# The tree drawn from 8 sides (generated by tools/art/trees/src/pack_pr3.py',
         '# from the approved mockup; do not edit by hand). frames.png / bare.png: a row of 8 turns per look; a look:',
         '# its size and variant, cell (x, y, w, h) of turn 0 in px, anchor (ax, ay: the ground under the trunk),',
         '# trunk (cells of log up from the foot), crown (cells of the tree\'s own frame: x0, z0, nx, ny, nz, bits).',
         '# since: the trees\' looks (WorldCells.TREE_LOOKS) these pictures came with; rule: how its leaves are lit.',
         'since: %d' % SINCE,
         'rule: %s' % RULE[key],
         'leaves: [%s]' % ', '.join(hx(c) for c in looks[0]['ramp']),
         'bark: [%s]' % ', '.join(hx(c) for c in looks[0]['bark']),
         'looks:']
    for l in looks:
        x0, z0, nx, ny, nz, bits = l['grid']
        L.append('  - {size: %.2f, variant: %d, x: %d, y: %d, w: %d, h: %d, ax: %d, ay: %d, trunk: %d, crown: [%d, %d, %d, %d, %d, "%s"]}'
                 % (l['s'], l['v'], l['x'], l['y'], l['w'], l['h'], l['ax'], l['ay'], l['trunk'],
                    x0, z0, nx, ny, nz, base64.b64encode(bits).decode()))
    open(os.path.join(out, 'look.yaml'), 'w').write('\n'.join(L) + '\n')
    info = [(l['s'], l['v'], l['w'], l['h'], 'trunk %d (drawn %d, cap %s)' % (l['trunk'], l['drawn'], l['cap']),
             'crown %dx%dx%d at %d,%d' % (l['grid'][2], l['grid'][3], l['grid'][4], l['grid'][0], l['grid'][1])) for l in looks]
    return (W, Ht, os.path.getsize(os.path.join(out, 'frames.png')), os.path.getsize(os.path.join(out, 'bare.png'))), info


if __name__ == '__main__':
    exp, repo = sys.argv[1], sys.argv[2]
    keys = sys.argv[3].split(',') if len(sys.argv) > 3 else E3.KEYS
    for k in keys:
        if all(os.path.exists(os.path.join(exp, k, '%.2f_%d.npz' % (s, v))) for s in E3.SIZES for v in range(E3.VARIANTS)):
            size, info = pack(exp, repo, k)
            print(k, size, flush=True)
            for i in info: print('   ', *i, flush=True)
        else:
            print(k, 'not exported yet')
