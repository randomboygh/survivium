# Trees PR 6a: packs export_pieces.py's world pieces into the game: content/plants/<key>/tree/pieces.png (RGBA8: a row
# a kind (log, fallen, broken), each the 8 turns of summer then the 8 of winter, every view cropped to itself, places
# even) and look.yaml's piece lines (piece_frames, pieces: {<kind>: {logs, twigs, reach, views: [[x, y, w, h, ax, ay]
# x 16]}}), replacing earlier ones (re-runnable). The leaf ramp of the sprout (sprout23.ramp_of) is checked against
# look.yaml's `leaves` (the game's ramp row).   python3 pack_pieces.py <export dir> <repo> [keys]
import os, sys, re, numpy as np
from PIL import Image

KINDS = ('log', 'fallen', 'broken')
TEXELS_CELL = 8
# What chopping a piece gives (logs of the species, twigs): data, the game reads it.
GIVES = dict(log=(2, 1), fallen=(3, 4), broken=(1, 1))


def pack(exp, repo, key):
    d = np.load(os.path.join(exp, key + '.npz'), allow_pickle=True)
    tree = os.path.join(repo, 'content', 'plants', key, 'tree')
    yaml_p = os.path.join(tree, 'look.yaml')
    text = open(yaml_p).read()
    leaves = re.search(r'^leaves: \[(.*)\]', text, re.M)
    game = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in re.findall(r'"(#[0-9a-f]{6})"', leaves.group(1))]
    sprout = [tuple(int(v) for v in c) for c in d['broken_leaves']]
    if sprout != [(0, 0, 0)] and sprout[:len(game)] != game:
        print('  note: %s sprout ramp differs from the game leaves' % key, sprout, game)
    rows = []; info = {}; y = 0; width = 0
    for kind in KINDS:
        views = [(d['%s_v%d' % (kind, i)], d['%s_a%d' % (kind, i)]) for i in range(16)]
        H = max(v.shape[0] for v, _ in views); H += H & 1
        x = 0; at = []
        for i, (v, a) in enumerate(views):
            # a winter view the same as its summer one (no snow: the hot species) is that one
            if i >= 8 and v.shape == views[i - 8][0].shape and np.array_equal(v, views[i - 8][0]) \
                    and int(a[0]) == int(views[i - 8][1][0]) and int(a[1]) == int(views[i - 8][1][1]):
                at.append(at[i - 8]); continue
            at.append((x, y, v.shape[1], v.shape[0], int(a[0]), int(a[1])))
            x += v.shape[1] + (v.shape[1] & 1)
        row = np.zeros((H, x, 4), np.uint8)
        for i, ((vx, _, w, h, _, _), (v, _)) in enumerate(zip(at, views)):
            row[:h, vx:vx + w] = v
        rows.append((y, row)); width = max(width, x); y += H
        # how far the piece reaches from its column along its length (cells), from the turn-0 summer view
        _, _, w0, _, ax0, _ = at[0]
        reach = max(ax0, w0 - ax0) / TEXELS_CELL
        info[kind] = (at, reach)
    img = np.zeros((y, width, 4), np.uint8)
    for ry, r in rows:
        img[ry:ry + r.shape[0], :r.shape[1]] = r
    Image.fromarray(img, 'RGBA').save(os.path.join(tree, 'pieces.png'), optimize=True)
    lines = ['# The pieces lying in the woods (tools/art/trees/src/pack_pieces.py): a row a',
             '# kind in pieces.png, its views the 8 turns of summer then the 8 of winter, each [x, y, w, h, ax, ay]; logs and',
             '# twigs: what the axe makes of it; reach: cells it lies out from its column at most.',
             'piece_frames: pieces.png',
             'pieces:']
    for kind in KINDS:
        at, reach = info[kind]
        logs, twigs = GIVES[kind]
        lines.append('  %s:' % kind)
        lines.append('    logs: %d' % logs)
        lines.append('    twigs: %d' % twigs)
        lines.append('    reach: %.1f' % reach)
        lines.append('    views: [%s]' % ', '.join('[%d, %d, %d, %d, %d, %d]' % v for v in at))
    text = re.sub(r'\n# The pieces lying in the woods.*?(?=\n# The stump|\Z)', '', text, flags=re.S).rstrip('\n')
    open(yaml_p, 'w').write(text + '\n' + '\n'.join(lines) + '\n')
    return key, img.shape, {k: round(info[k][1], 1) for k in KINDS}


if __name__ == '__main__':
    exp, repo = sys.argv[1], sys.argv[2]
    keys = sys.argv[3].split(',') if len(sys.argv) > 3 and sys.argv[3] else \
        sorted(f[:-4] for f in os.listdir(exp) if f.endswith('.npz'))
    for k in keys:
        print(*pack(exp, repo, k))
