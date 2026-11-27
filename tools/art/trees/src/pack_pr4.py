# PR 4 (seasons): packs export_pr4's winter layers into a species' files content/plants/<key>/tree/, over what PR 1-3
# packed there (frames.png, bare.png, look.yaml):
#   bare.png      the bare tree (winter) replaced where export_pr4 drew it anew (the twigs through the crown)
#   snow.png      the snow of the look the tree shows in winter (bare, or the evergreen's crown), LA8: L the code's low
#                 byte, A its high byte (export_pr4.py: kind, normal or tones, shade, lift); 0, 0 none
#   snow_dry.png  the snow on the crown of the trees of the species that keep their dry leaves (oak, linden, willow)
#   frames.png    re-laid into the grown cells, its alpha codes under 128 (1 dark mass, 2 bark, 3 palm outline) stored 64
#                 higher (the import's fix_alpha_border would give them a leaf's colour)
#   look.yaml     the cells grown where the twigs or the snow reach past them (the old drawing moved with its anchor;
#                 cell heights even, so every place in the atlas is even); `dry` (the leaves kept under snow) and
#                 `blossom` (the blossom's 7 steps) ramps; `snow`, `snow_dry` the files; `evergreen` for the trees of
#                 the hot zones (they keep their summer leaves, no snow: user 2026-11-24 «1. А»).
# python3 pack_pr4.py <export dir> <repo> [keys]   (run from tools/art/trees/src/)
import os, sys, re, math, numpy as np
from PIL import Image
import export_pr4 as X

BX = None
HOT = ('acacia', 'ceiba', 'mangrove', 'palm', 'fan_palm')
LOOK_RE = re.compile(r'size: ([\d.]+), variant: (\d+), x: (\d+), y: (\d+), w: (\d+), h: (\d+), ax: (\d+), ay: (\d+)')


def hexs(cs):
    return '[' + ', '.join('"#%s"' % c.lstrip('#').lower() for c in cs) + ']'


def leaf_ramp(lines):
    for ln in lines:
        if ln.startswith('leaves:'):
            return re.findall(r'#([0-9a-fA-F]{6})', ln)
    raise ValueError('no leaves')


def set_key(lines, key, value):
    """Sets the top-level `key: value` line (before `looks:`), replacing an old one."""
    lines = [ln for ln in lines if not ln.startswith(key + ':')]
    i = next(i for i, ln in enumerate(lines) if ln.startswith('looks:'))
    return lines[:i] + ['%s: %s' % (key, value)] + lines[i:]


def pack(exp, repo, key):
    import render16 as G
    import winter23 as WI, spring23 as SP
    d_out = os.path.join(repo, 'content', 'plants', key, 'tree')
    lines = open(os.path.join(d_out, 'look.yaml')).read().split('\n')
    fr = np.array(Image.open(os.path.join(d_out, 'frames.png')).convert('RGBA'))
    ba = np.array(Image.open(os.path.join(d_out, 'bare.png')).convert('LA'))
    looks = []
    for i, ln in enumerate(lines):
        m = LOOK_RE.search(ln)
        if m:
            s, v, x, y, w, h, ax, ay = m.groups()
            looks.append(dict(line=i, s=float(s), v=int(v), x=int(x), y=int(y), w=int(w), h=int(h), ax=int(ax), ay=int(ay)))
    has = os.path.isdir(os.path.join(exp, key))
    layers = {}
    for lk in looks:
        old_fr = [fr[lk['y']:lk['y'] + lk['h'], lk['x'] + n * lk['w']:lk['x'] + (n + 1) * lk['w']] for n in range(8)]
        old_ba = [ba[lk['y']:lk['y'] + lk['h'], lk['x'] + n * lk['w']:lk['x'] + (n + 1) * lk['w']] for n in range(8)]
        lk['old'] = (old_fr, old_ba)
        lk['new'] = {}
        bx0, by0, bx1, by1 = 0, 0, lk['w'], lk['h']
        if has:
            d = np.load(os.path.join(exp, key, '%.2f_%d.npz' % (lk['s'], lk['v'])))
            cx = int(float(d['ox'])) + G.BX - lk['ax']          # the cell's corner on the export's canvas
            cy = int(math.floor(float(d['oy']))) - lk['ay']
            oy_, ox_ = int(d['box'][0]) - cy, int(d['box'][1]) - cx
            for k in ('bare', 'snow', 'snow_dry'):
                if k in d.files:
                    a = d[k]
                    lk['new'][k] = (oy_, ox_, a)
                    nz = (a != 0).any(0)
                    ys, xs = np.nonzero(nz)
                    if len(ys):
                        by0 = min(by0, oy_ + ys.min()); by1 = max(by1, oy_ + ys.max() + 1)
                        bx0 = min(bx0, ox_ + xs.min()); bx1 = max(bx1, ox_ + xs.max() + 1)
        dx, dy = -bx0, -by0
        W, H = bx1 - bx0, by1 - by0
        H += H & 1
        lk.update(dx=dx, dy=dy, W=W, H=H)
    Wt = max(8 * lk['W'] for lk in looks)
    Ht = sum(lk['H'] for lk in looks)
    top = np.zeros((Ht, Wt, 4), np.uint8)
    bare = np.full((Ht, Wt, 2), 255, np.uint8)
    snow = {k: np.zeros((Ht, Wt, 2), np.uint8) for k in ('snow', 'snow_dry')}
    used = set()
    y = 0
    grown = 0
    for lk in looks:
        W, H, dx, dy = lk['W'], lk['H'], lk['dx'], lk['dy']
        for n in range(8):
            X0 = n * W
            of, ob = lk['old'][0][n], lk['old'][1][n]
            top[y + dy:y + dy + lk['h'], X0 + dx:X0 + dx + lk['w']] = of
            if 'bare' in lk['new']:
                oy_, ox_, a = lk['new']['bare']
                b = a[n].astype(np.int64)
                bits = (b & 0xffff)
                bits = np.where(bits == 0xffff, 0xfeff, bits)
                bits = np.where(b > 0, bits, 0xffff)
                Y0, XX0 = y + dy + oy_, X0 + dx + ox_
                blk = bare[Y0:Y0 + b.shape[0], XX0:XX0 + b.shape[1]]
                blk[..., 0] = bits & 255; blk[..., 1] = bits >> 8
            else:
                bare[y + dy:y + dy + lk['h'], X0 + dx:X0 + dx + lk['w']] = ob
            for k in ('snow', 'snow_dry'):
                if k not in lk['new']: continue
                used.add(k)
                oy_, ox_, a = lk['new'][k]
                c = a[n].astype(np.int64)
                Y0, XX0 = y + dy + oy_, X0 + dx + ox_
                blk = snow[k][Y0:Y0 + c.shape[0], XX0:XX0 + c.shape[1]]
                blk[..., 0] = np.where(c > 0, c & 255, blk[..., 0]); blk[..., 1] = np.where(c > 0, c >> 8, blk[..., 1])
        if (W, H) != (lk['w'], lk['h']): grown += 1
        new_line = LOOK_RE.sub('size: %.2f, variant: %d, x: 0, y: %d, w: %d, h: %d, ax: %d, ay: %d'
                               % (lk['s'], lk['v'], y, W, H, lk['ax'] + dx, lk['ay'] + dy), lines[lk['line']])
        lines[lk['line']] = new_line
        y += H
    # The codes under 128 (dark mass 1, bark 2, palm outline 3) 64 higher: the engine's import (fix_alpha_border) gives
    # a texel under alpha 20 the colour of a leaf near it (tree_pictures.gdshaderinc frame_code).
    al = top[..., 3]
    top[..., 3] = np.where((al >= 1) & (al <= 3), al | 64, al)
    Image.fromarray(top, 'RGBA').save(os.path.join(d_out, 'frames.png'), optimize=True)
    Image.fromarray(bare, 'LA').save(os.path.join(d_out, 'bare.png'), optimize=True)
    for k in ('snow', 'snow_dry'):
        if k in used:
            Image.fromarray(snow[k], 'LA').save(os.path.join(d_out, k + '.png'), optimize=True)
            lines = set_key(lines, k, '%s.png' % k)
    if key in X.DRY:
        lines = set_key(lines, 'dry', hexs(WI.dry_ramp(leaf_ramp(lines))))
    if key in SP.BLOOM:
        lines = set_key(lines, 'blossom', hexs(SP.BLOOM[key]))
    if key in HOT:
        lines = set_key(lines, 'evergreen', 'true')
    head = ('# Seasons (tools/art/trees/src/pack_pr4.py): bare.png the winter tree with its'
            ' twigs, snow.png / snow_dry.png the snow (LA8 codes, see shaders/tree_pictures.gdshaderinc), dry / blossom'
            ' ramps; frames.png alpha 65-67 = codes 1-3.')
    lines = [head] + (lines[1:] if lines[0].startswith('# Seasons') else lines)
    open(os.path.join(d_out, 'look.yaml'), 'w').write('\n'.join(lines))
    return key, len(looks), grown, sorted(used), top.shape


if __name__ == '__main__':
    exp, repo = sys.argv[1], sys.argv[2]
    keys = sys.argv[3].split(',') if len(sys.argv) > 3 else X.ALL + ['acacia', 'ceiba', 'mangrove', 'palm', 'fan_palm', 'cherry']
    for k in dict.fromkeys(keys):
        print(*pack(exp, repo, k), flush=True)
