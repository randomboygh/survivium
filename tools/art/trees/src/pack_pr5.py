# PR 5: packs export_pr5.py's stumps into the game: content/plants/<key>/tree/stumps.png (RGBA8: a row a size, each
# the 8 turns of summer then, for a species with snow, the 8 of winter; cells even-sized) and look.yaml's stump lines
# (wood, stump_frames, stump_snow, stumps: [{size, x, y, w, h, ax, ay}]), replacing earlier ones (re-runnable).
# python3 pack_pr5.py <export dir> <repo> [keys]
import os, sys, re, numpy as np
from PIL import Image

SIZES = (0.42, 0.68, 1.0)

def hexs(c):
    return '"#%02x%02x%02x"' % tuple(int(v) for v in c)

def pack(exp, repo, key):
    d = np.load(os.path.join(exp, key + '.npz'))
    snowy = bool(d['0_snow'])
    rows = []; looks = []; y = 0; width = 0
    for i, s in enumerate(SIZES):
        fr = d['%d_frames' % i]                       # (2, 8, h, w, 4)
        _, _, h, w, _ = fr.shape
        H, W = h + (h & 1), w + (w & 1)              # even cells: half-float instance data
        n = 16 if snowy else 8
        row = np.zeros((H, W * n, 4), np.uint8)
        for season in range(2 if snowy else 1):
            for t in range(8):
                x = (season * 8 + t) * W
                row[:h, x:x + w] = fr[season, t]
        rows.append(row)
        looks.append(dict(size=s, x=0, y=y, w=W, h=H, ax=int(d['%d_ax' % i]), ay=int(d['%d_ay' % i])))
        y += H; width = max(width, W * n)
    img = np.zeros((y, width, 4), np.uint8)
    for r, l in zip(rows, looks):
        img[l['y']:l['y'] + r.shape[0], :r.shape[1]] = r
    tree = os.path.join(repo, 'content', 'plants', key, 'tree')
    Image.fromarray(img, 'RGBA').save(os.path.join(tree, 'stumps.png'), optimize=True)
    wood = list(d['0_wood']) + [(0xe0, 0xa0, 0x40)]
    lines = ['# The stump a felled tree leaves (tools/art/trees/src/pack_pr5.py): a row a size',
             '# in stumps.png, 8 turns of summer then 8 of winter (stump_snow); wood = the cut wood\'s 6 steps and the resin.',
             'wood: [%s]' % ', '.join(hexs(c) for c in wood),
             'stump_frames: stumps.png',
             'stump_snow: %s' % ('true' if snowy else 'false'),
             'stumps:']
    for l in looks:
        lines.append('  - {size: %.2f, x: %d, y: %d, w: %d, h: %d, ax: %d, ay: %d}' % (
            l['size'], l['x'], l['y'], l['w'], l['h'], l['ax'], l['ay']))
    p = os.path.join(tree, 'look.yaml')
    text = open(p).read()
    text = re.sub(r'\n# The stump a felled tree leaves.*', '', text, flags=re.S).rstrip('\n')
    open(p, 'w').write(text + '\n' + '\n'.join(lines) + '\n')
    return key, img.shape

if __name__ == '__main__':
    exp, repo = sys.argv[1], sys.argv[2]
    keys = sys.argv[3].split(',') if len(sys.argv) > 3 and sys.argv[3] else \
        sorted(f[:-4] for f in os.listdir(exp) if f.endswith('.npz'))
    for k in keys:
        print(*pack(exp, repo, k))
