# PR 1: packs export_pr1's frames of a species into the game's files content/plants/<key>/tree/:
#   frames.png  the G-buffer frames (RGBA8, see export_pr1.py), a row of 8 turns per look (size x variant)
#   bare.png    the bare tree's frames in the same places, grey + alpha (LA8): L, A = bark steps at the 8 suns
#               (low, high byte); 255, 255 where no wood (a wood texel of those steps keeps one step less at sun 4)
#   look.yaml   ramps, each look's cell (x, y, w, h), anchor (the ground under the trunk's axis), trunk cells and
#               the crown's cells (a grid in the tree's own frame, see Growth)
# python3 pack_pr1.py <export dir> <repo> [keys]   (run from tools/art/trees/src/, for the crown grids)
import os, sys, math, base64, numpy as np
from PIL import Image
import export_pr1 as E

ZSQ = 0.55          # turn24.ZSQ: the crowns' approved depth squash

def crown_grid(t):
    """The crown in cells of the tree's own frame (x east, y up from the foot's cell, z south at turn 0, unsquashed):
    a cell is crown when its middle is inside the crown's shape. -> (x0, z0, nx, ny, nz, bits)"""
    import render16 as G
    # A tree drawn without its crown (deadwood) keeps the crown's cells where its limbs spread, as the game's dead
    # trees always had them (twigs to gather, the cursor).
    lo, hi = t.yrange()
    ny = int(math.ceil((t.cy + hi) / 8.0)) + 1
    R_ = 14
    xs = np.arange(-R_, R_ + 1); zs = np.arange(-R_, R_ + 1); ys = np.arange(ny)
    Z, Y, X = np.meshgrid(zs, ys, xs, indexing='ij')
    px = G.BX + X * 8.0; py = (Y + 0.5) * 8.0 - t.cy; pz = Z * 8.0 * ZSQ
    m = t.inside(px, py, pz)
    if not m.any():
        # a crown thinner than a cell (the acacia's flat one) that no cell's middle is in: any of 8 heights in a cell
        for f in np.arange(1, 16, 2) / 16.0:
            m |= t.inside(px, (Y + f) * 8.0 - t.cy, pz)
    if not m.any(): return 0, 0, 0, 0, 0, b''
    zi, yi, xi = np.nonzero(m)
    z0, z1, x0, x1 = zi.min(), zi.max(), xi.min(), xi.max()
    y1 = yi.max()
    m = m[z0:z1 + 1, :y1 + 1, x0:x1 + 1]
    nz, ny, nx = m.shape
    bits = np.packbits(m.transpose(0, 1, 2).reshape(-1), bitorder='little')   # index (z * ny + y) * nx + x
    return int(x0 - R_), int(z0 - R_), nx, ny, nz, bits.tobytes()

def _roundi(v):
    return int(math.copysign(math.floor(abs(v) + 0.5), v))

def probe_cap(grid):
    """The highest trunk (cells of log) whose top the crown's leaves still reach over for every turn and either
    parity of the foot, as the game lays crown points (Growth._offsets: every other level, every other cell, turned
    by TreeLooks.to_own; a point's leaves span its level and the ones under and over it): Growth.standing_look tells
    a standing tree from a stump cut as high by the leaves over the trunk's top (Growth._probes). None: no crown."""
    x0, z0, nx, ny, nz, bits = grid
    if nx == 0: return None
    m = np.unpackbits(np.frombuffer(bits, np.uint8), bitorder='little')[:nx * ny * nz].reshape(nz, ny, nx)
    reach = int(math.ceil(max(abs(x0), abs(x0 + nx), abs(z0), abs(z0 + nz)) * 1.42)) + 1
    cap = None
    for turn in range(8):
        a = -turn * math.pi / 4.0
        for odd in (0, 1):
            top = -1
            for dy in range(odd, ny, 2):
                for dz in range(-reach - (reach & 1), reach + 1, 2):
                    for dx in range(-reach - (reach & 1), reach + 1, 2):
                        ox = _roundi(dx * math.cos(a) - dz * math.sin(a)) - x0
                        oz = _roundi(dx * math.sin(a) + dz * math.cos(a)) - z0
                        if 0 <= ox < nx and 0 <= oz < nz and m[oz, dy, ox]:
                            top = dy
            if top >= 0:
                cap = top + 1 if cap is None else min(cap, top + 1)
    return cap

def pack(exp, repo, key):
    looks = []
    for s in E.SIZES:
        for v in range(E.VARIANTS):
            d = np.load(os.path.join(exp, key, '%.2f_%d.npz' % (s, v)))
            fr, bare = d['frames'], d['bare']
            m = (fr[..., 3] > 0) | (bare > 0)
            m = m.any(0)
            ys, xs = np.nonzero(m)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            import render16 as G
            t = E.build(key, s, v)
            lo, hi = t.yrange()
            trunk = max(2, int(round((t.cy + lo) / 8.0)) + 1)
            grid = crown_grid(t)
            cap = probe_cap(grid)
            if cap is not None: trunk = min(trunk, cap)      # a flat crown's points may all sit under a higher top
            looks.append(dict(s=s, v=v, fr=fr[:, y0:y1, x0:x1], bare=bare[:, y0:y1, x0:x1],
                              ax=int(d['ox']) + G.BX - x0, ay=int(d['oy']) - y0, trunk=trunk, cap=cap,
                              grid=grid, ramp=d['ramp'], bark=d['bark'], t=t))
    # the trunk's cells tell a standing tree's size: keep them apart per variant, a smaller look's lower (a higher
    # one could rise over its crown's points, see probe_cap)
    for v in range(E.VARIANTS):
        nxt = None
        for lk in sorted([l for l in looks if l['v'] == v], key=lambda l: -l['s']):
            if nxt is not None and lk['trunk'] >= nxt: lk['trunk'] = nxt - 1
            assert 2 <= lk['trunk'] and (lk['cap'] is None or lk['trunk'] <= lk['cap']), (key, lk['s'], v, lk['trunk'], lk['cap'])
            nxt = lk['trunk']
    W = max(8 * l['fr'].shape[2] for l in looks)
    Ht = sum(l['fr'].shape[1] for l in looks)
    top = np.zeros((Ht, W, 4), np.uint8); bare = np.full((Ht, W, 2), 255, np.uint8)
    y = 0
    for l in looks:
        h, w = l['fr'].shape[1:3]
        for n in range(8):
            top[y:y + h, n * w:(n + 1) * w] = l['fr'][n]
            b = l['bare'][n]
            bits = (b & 0xffff).astype(np.int64)
            bits = np.where(bits == 0xffff, 0xfeff, bits)
            bits = np.where(b > 0, bits, 0xffff)
            bare[y:y + h, n * w:(n + 1) * w, 0] = bits & 255
            bare[y:y + h, n * w:(n + 1) * w, 1] = bits >> 8
        l['x'], l['y'], l['w'], l['h'] = 0, y, w, h
        y += h
    out = os.path.join(repo, 'content', 'plants', key, 'tree')
    os.makedirs(out, exist_ok=True)
    Image.fromarray(top, 'RGBA').save(os.path.join(out, 'frames.png'), optimize=True)
    Image.fromarray(bare, 'LA').save(os.path.join(out, 'bare.png'), optimize=True)
    hx = lambda c: '"#%02x%02x%02x"' % tuple(int(a) for a in c)
    L = ['# The tree drawn from 8 sides (generated by tools/art/trees/src/pack_pr1.py',
         '# from the approved mockup; do not edit by hand). frames.png / bare.png: a row of 8 turns per look; a look:',
         '# its size and variant, cell (x, y, w, h) of turn 0 in px, anchor (ax, ay: the ground under the trunk),',
         '# trunk (cells of log up from the foot), crown (cells of the tree\'s own frame: x0, z0, nx, ny, nz, bits).',
         'leaves: [%s]' % ', '.join(hx(c) for c in looks[0]['ramp']),
         'bark: [%s]' % ', '.join(hx(c) for c in looks[0]['bark']),
         'looks:']
    for l in looks:
        x0, z0, nx, ny, nz, bits = l['grid']
        L.append('  - {size: %.2f, variant: %d, x: %d, y: %d, w: %d, h: %d, ax: %d, ay: %d, trunk: %d, crown: [%d, %d, %d, %d, %d, "%s"]}'
                 % (l['s'], l['v'], l['x'], l['y'], l['w'], l['h'], l['ax'], l['ay'], l['trunk'],
                    x0, z0, nx, ny, nz, base64.b64encode(bits).decode()))
    open(os.path.join(out, 'look.yaml'), 'w').write('\n'.join(L) + '\n')
    return W, Ht, os.path.getsize(os.path.join(out, 'frames.png')), os.path.getsize(os.path.join(out, 'bare.png'))

if __name__ == '__main__':
    exp, repo = sys.argv[1], sys.argv[2]
    keys = sys.argv[3].split(',') if len(sys.argv) > 3 else E.BROADLEAF
    for k in keys:
        if all(os.path.exists(os.path.join(exp, k, '%.2f_%d.npz' % (s, v))) for s in E.SIZES for v in range(E.VARIANTS)):
            print(k, pack(exp, repo, k), flush=True)
        else:
            print(k, 'not exported yet')
