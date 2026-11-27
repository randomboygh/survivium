# Round 7 pictures: 19 contrast, 20 hidden modules, 21 shapes, 22 the trunk under the sun.
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, '.')
import render7 as R, render6 as R6
from render2 import hexc
FONT = lambda s: ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', s)
up = lambda a, k: np.repeat(np.repeat(a, k, 0), k, 1)
D = sys.argv[1] if __name__ == "__main__" else None
BG = (235, 235, 235)
K = 1.3                                      # the recommended contrast
SUNS = [('солнце справа', (0.6, 0.75, -0.1)), ('солнце слева', (-0.6, 0.75, -0.1)),
        ('солнце спереди', (0.35, 0.7, 0.6)), ('солнце сзади', (-0.2, 0.65, -0.75))]

def tile(img, k, txt, sub=None, size=22):
    a = up(img, k)
    pad = 34 if sub is None else 60
    a = np.pad(a, ((pad, 0), (0, 0), (0, 0)), constant_values=235)
    im = Image.fromarray(a); d = ImageDraw.Draw(im)
    d.text((8, 5), txt, font=FONT(size), fill=(20, 20, 40))
    if sub: d.text((8, 32), sub, font=FONT(size - 4), fill=(70, 70, 90))
    return im

def grid(tiles, cols, gap=8):
    w = max(t.size[0] for t in tiles); h = max(t.size[1] for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    sh = Image.new('RGB', (cols * (w + gap) - gap, rows * (h + gap) - gap), BG)
    for i, t in enumerate(tiles): sh.paste(t, ((i % cols) * (w + gap), (i // cols) * (h + gap)))
    return sh

def vstack(ims, gap=14):
    sh = Image.new('RGB', (max(i.size[0] for i in ims), sum(i.size[1] + gap for i in ims) - gap), BG)
    y = 0
    for i in ims: sh.paste(i, (0, y)); y += i.size[1] + gap
    return sh

def bbox_crop(imgs, ground, margin=6):
    """One crop box for several pictures: where anything differs from the ground."""
    g = np.array(hexc(ground), np.uint8)
    m = np.zeros(imgs[0].shape[:2], bool)
    for a in imgs: m |= (a != g).any(2)
    ys, xs = np.nonzero(m)
    H, W = m.shape
    return max(0, ys.min() - margin), min(H, ys.max() + margin + 1), max(0, xs.min() - margin), min(W, xs.max() + margin + 1)

if __name__ == "__main__":
    # 19: contrast
    tiles = []
    for k, name in ((1.0, 'сейчас'), (1.15, 'В1: чуть'), (1.3, 'В2: заметнее (рекомендую)'), (1.5, 'В3: сильно')):
        img = R.Tree(R.SUN_R, k=k, W=170, H=150).render()[12:140, 12:162]
        ramp = R.contrast(R6.ramp_for('summer'), k)
        bar = np.zeros((10, img.shape[1], 3), np.uint8)
        w = img.shape[1] // 7
        for i, h in enumerate(ramp): bar[:, i * w:(i + 1) * w] = hexc(h)
        bar[:, 7 * w:] = hexc(ramp[-1])
        gap = np.full((3, img.shape[1], 3), 235, np.uint8)
        tiles.append(tile(np.concatenate([img, gap, bar], 0), 3, name, 'контраст ×%.2f' % k))
    grid(tiles, 2).save(D + '/19-contrast.png')

    # 20 and 21: shapes, with and without the hidden modules
    names = list(R.SHAPES)
    shape_tiles, xray_tiles = [], []
    for i, name in enumerate(names):
        lab = R.SHAPES[name]['label']
        t = R.Tree(R.SUN_R, shape=name, k=K)
        img = t.render()
        full = R.Tree(R.SUN_R, shape=name, k=K, cull=False).render()
        diff = int((img != full).any(2).sum())
        n, skip = len(t.mods), len(t.skipped)
        # x-ray: the drawn modules in greys (in drawing order), the left-out ones in red on top
        xr = np.zeros((t.H, t.W, 3), np.uint8); xr[:] = (250, 250, 250)
        core = t.core(); xr[core] = (205, 205, 210)
        greys = [(150, 150, 160), (120, 120, 132), (175, 175, 185)]
        for j, (p, nn, mod) in enumerate(t.mods):
            if j in t.skipped: continue
            Y, X, _ = t.module_pixels(p, nn, mod); xr[Y, X] = greys[j % 3]
        for j in sorted(t.skipped):
            p, nn, mod = t.mods[j]
            Y, X, _ = t.module_pixels(p, nn, mod)
            xr[Y, X] = (0.45 * xr[Y, X] + 0.55 * np.array([225, 40, 40])).astype(np.uint8)
        y0, y1, x0, x1 = bbox_crop([full], R6.GRASS)
        x0, x1 = t.ox - 78, t.ox + 78                 # centred on the trunk
        tag = '' if i < 3 else '+ '
        print(name, n, skip, 'px changed by leaving out:', diff)
        shape_tiles.append((y1 - y0, x1 - x0, img[y0:y1, x0:x1], tag + lab, 'рисуем %d из %d модулей' % (n - skip, n)))
        xray_tiles.append((y1 - y0, x1 - x0, xr[y0:y1, x0:x1], tag + lab, 'не рисуем %d (красные)' % skip))
    def sheet(items, k):
        H = max(h for h, w, *_ in items); Wd = max(w for h, w, *_ in items)
        out = []
        for h, w, a, txt, sub in items:
            b = np.zeros((H, Wd, 3), np.uint8); b[:] = a[0, 0]
            b[H - h:, (Wd - w) // 2:(Wd - w) // 2 + w] = a
            out.append(tile(b, k, txt, sub, 20))
        return grid(out, 4)
    sheet(shape_tiles, 2).save(D + '/21-shapes.png')
    sheet(xray_tiles, 2).save(D + '/20-hidden-modules.png')

    # 22: the trunk under the sun from four sides
    trees, trunks = [], []
    for name, sun in SUNS:
        t = R.Tree(sun, k=K, W=170, H=170)
        img = t.render()
        trees.append(tile(img[20:166, 5:165], 2, name))
        cx, fy = t.ox, t.oy
        trunks.append(tile(img[fy - 30:fy + 8, cx - 26:cx + 26], 6, name))
    vstack([grid(trees, 4), grid(trunks, 4)]).save(D + '/22-trunk-light.png')
    print('ok')
