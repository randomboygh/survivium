# Round 23: all approved trees on one sheet. Run from the merged src folder after `all23.py render`:
#   sheet23.py <out.png> [k=2] [row width in native px=1020: three species a row, 7 rows]
# Every species: thick, medium, thin from left to right (the user's reference sheets go big -> small; the sun is on
# the right, so each tree's shadow falls on its own ground and the thick one's long shadow stays inside the species'
# slot). One grass field, shadows first, then the trees from the back row to the front; a label under each species.
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
import all23 as A, render6 as R6
from render2 import hexc

FONT = lambda s, bold=False: ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else ''), s)
GAP, SGAP, LABEL = 8, 14, 25          # px: between crowns of one species, between species, label rows (native)
TOP, SIDE = 18, 12                    # native margins

SUB = {
    'oak': 'листья 122', 'linden': 'листья «точки»', 'birch': 'листья «точки»', 'acacia': 'листья «точки»',
    'mangrove': 'листья «точки»', 'apple': 'листья «круглые»', 'cherry': 'листья «круглые»',
    'poplar': 'листья «круглые»', 'ceiba': 'листья «круглые»', 'maple': 'кленовые листья',
    'red_maple': 'кленовые, цвета референса', 'bird_cherry': 'листья «клинки»', 'rowan': 'листья «клинки»',
    'willow': '«клинки», пряди до земли', 'deadwood': 'без листьев', 'spruce': 'хвоя 124', 'fir': 'хвоя 124',
    'larch': 'хвоя 124', 'pine': 'хвоя 124, зонтики', 'palm': 'перистая (как в игре)', 'fan_palm': 'новый вид',
}
NAME = {'palm': 'пальма', 'fan_palm': 'веерная пальма'}

def extents(img, ox, oy):
    kg, ks = np.array(hexc(A.KEY_G)), np.array(hexc(A.KEY_S))
    sh = (img == ks).all(2); tr = ~((img == kg).all(2) | sh)
    ys, xs = np.nonzero(tr); ys2, xs2 = np.nonzero(sh)
    r = lambda v: int(round(v))
    return dict(x0=r(xs.min() - ox), x1=r(xs.max() - ox), up=r(oy - ys.min()), sx0=r(xs2.min() - ox),
                sx1=r(xs2.max() - ox), dn=r(max(ys.max(), ys2.max()) - oy))

def slot(key):
    """The species' three trees (thick, medium, thin) placed side by side: feet x relative to the slot's left edge."""
    trees = []
    for s in reversed(A.SIZES):
        img, ox, oy = A.load(key, s)
        trees.append((img, ox, oy, extents(img, ox, oy)))
    T = trees[0][3]
    x = -min(T['x0'], T['sx0'])
    feet = [x]
    for (_, _, _, a), (_, _, _, b) in zip(trees, trees[1:]):
        x = x + a['x1'] - b['x0'] + GAP
        feet.append(x)
    S = trees[-1][3]
    width = feet[-1] + max(S['x1'], S['sx1']) + 1
    return dict(key=key, trees=trees, feet=feet, width=width, up=max(t[3]['up'] for t in trees),
                dn=max(t[3]['dn'] for t in trees), left=feet[0] + T['x0'], right=feet[-1] + S['x1'])

def rows_of(slots, wmax):
    rows, cur, w = [], [], 0
    for sl in slots:
        need = sl['width'] + (SGAP if cur else 0)
        if cur and w + need > wmax:
            rows.append(cur); cur, w = [], 0; need = sl['width']
        cur.append(sl); w += need
    if cur: rows.append(cur)
    return rows

def sheet(out, k=2, wmax=860, title=None, labels=True):
    labels_of = {key: (NAME.get(key, label), SUB.get(key, '')) for key, label, _ in A.TREES}
    slots = [slot(key) for key, *_ in A.TREES]
    rows = rows_of(slots, wmax)
    W = SIDE * 2 + max(sum(s['width'] for s in r) + SGAP * (len(r) - 1) for r in rows)
    # row baselines: each row's tallest crown over its foot line, its shadows and its label under it
    y, placed = TOP, []
    for r in rows:
        y += max(s['up'] for s in r)
        base = y
        rw = sum(s['width'] for s in r) + SGAP * (len(r) - 1)
        x = SIDE + (W - 2 * SIDE - rw) // 2
        rdn = max(s['dn'] for s in r)
        for s in r:
            placed.append((s, x, base, rdn))
            x += s['width'] + SGAP
        y = base + rdn + (LABEL + 8 if labels else 10)
    H = y + 4
    canvas = np.zeros((H, W, 3), np.uint8); canvas[:] = hexc(R6.GRASS)
    ks = np.array(hexc(A.KEY_S)); kg = np.array(hexc(A.KEY_G))
    jobs = []
    for s, x, base, _ in placed:
        for (img, ox, oy, e), fx in zip(s['trees'], s['feet']):
            jobs.append((base, x + fx, img, ox, oy))
    for base, fx, img, ox, oy in jobs:                        # all shadows first
        m = (img == ks).all(2)
        ys, xs = np.nonzero(m)
        Y, X = ys + int(round(base - oy)), xs + int(round(fx - ox))
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        canvas[Y[ok], X[ok]] = hexc(R6.GRASS_SHADE)
    for base, fx, img, ox, oy in sorted(jobs, key=lambda j: j[0]):   # trees, back rows first
        m = ~((img == ks).all(2) | (img == kg).all(2))
        ys, xs = np.nonzero(m)
        Y, X = ys + int(round(base - oy)), xs + int(round(fx - ox))
        ok = (Y >= 0) & (Y < H) & (X >= 0) & (X < W)
        canvas[Y[ok], X[ok]] = img[ys[ok], xs[ok]]
    big = Image.fromarray(canvas).resize((W * k, H * k), Image.NEAREST)
    d = ImageDraw.Draw(big)
    if labels:
        for s, x, base, rdn in placed:              # one label line per row, under the row's lowest shadow
            name, sub = labels_of[s['key']]
            cx = (x + (s['left'] + s['right']) / 2) * k
            ty = (base + rdn + 2) * k
            f1, f2 = FONT(12 * k, True), FONT(9 * k)
            w1 = d.textlength(name, font=f1); w2 = d.textlength(sub, font=f2)
            d.text((cx - w1 / 2, ty), name, font=f1, fill=(255, 255, 255), stroke_width=k, stroke_fill=(25, 35, 15))
            d.text((cx - w2 / 2, ty + 13 * k), sub, font=f2, fill=(235, 240, 225), stroke_width=k, stroke_fill=(25, 35, 15))
    if title:
        hdr = Image.new('RGB', (big.size[0], 22 * k), (250, 250, 250))
        ImageDraw.Draw(hdr).text((8, 4 * k), title, font=FONT(12 * k), fill=(10, 10, 30))
        sheet_ = Image.new('RGB', (big.size[0], big.size[1] + hdr.size[1]), (250, 250, 250))
        sheet_.paste(hdr, (0, 0)); sheet_.paste(big, (0, hdr.size[1]))
        big = sheet_
    big.save(out)
    return [(s['key'], x, base) for s, x, base, _ in placed], (W, H)

if __name__ == '__main__':
    out = sys.argv[1]
    k = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    wmax = int(sys.argv[3]) if len(sys.argv) > 3 else 1020
    title = 'Все деревья: 21 вид, у каждого толстое, среднее, тонкое; основание по размеру; солнце игры справа; ×%d' % k
    placed, size = sheet(out, k, wmax, title)
    print(size, [(p[0]) for p in placed])
