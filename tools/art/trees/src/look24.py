# Round 24: render trees at camera turns (approved depth or the game's true depth) and lay them out.
import os, sys, json, math, time, numpy as np
from PIL import Image, ImageDraw, ImageFont
import all23 as A, outline23 as O, render6 as R6, render7 as R
from render2 import hexc
import turn24 as TU, shapes24 as S24

W, H = 440, 600

def build(key, s, r24=True, W=W, H=H):
    """The approved tree (r24 False) or the round-24 one (crowns and limbs all round) on a W x H canvas."""
    A._taller()
    S24.use3d(r24)
    import trees22 as TR, conifer21 as C, species19 as SP
    if key in C.CSPEC:
        return TR.conifer(key, s, W=W, H=H)
    if key in ('maple', 'red_maple'):
        import module_maple
        from sheet20 import RED
        SP.SPEC[key] = SP.SPEC[key][:5] + ('maple',) + SP.SPEC[key][6:]
        return TR.tree(key, s, W=W, H=H, **({'ramp': RED} if key == 'red_maple' else {}))
    return TR.tree(key, s, W=W, H=H)

KG = np.array(hexc(A.KEY_G)); KS = np.array(hexc(A.KEY_S))

def picture(t, key):
    """The mockup picture (grass, shadow, wood outline) and the foot (ox, oy)."""
    img = t.render(ground=A.KEY_G, shade=A.KEY_S)
    O.outline(img, key)
    a = img.astype(int)
    m = img.copy()
    m[np.all(a == KG, 2)] = hexc(R6.GRASS); m[np.all(a == KS, 2)] = hexc(R6.GRASS_SHADE)
    return m

def views(t, key, ns=(0, 1, 2, 3, 4), zs_out=None, zs_in=TU.ZSQ):
    snap = TU.snapshot(t)
    out = []
    for n in ns:
        TU.turn(t, n, snap, zs_in=zs_in, zs_out=zs_out)
        out.append(picture(t, key))
    TU.turn(t, 0, snap, zs_in=zs_in)
    return out

def crop_box(imgs, pad=6):
    """One box over all pictures: everything that is not plain grass."""
    g = np.array(hexc(R6.GRASS))
    m = np.zeros(imgs[0].shape[:2], bool)
    for im in imgs: m |= ~np.all(im.astype(int) == g, 2)
    ys, xs = np.nonzero(m)
    return max(0, xs.min() - pad), max(0, ys.min() - pad), min(m.shape[1], xs.max() + pad + 1), min(m.shape[0], ys.max() + pad + 1)

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONTB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def font(size, bold=False):
    try: return ImageFont.truetype(FONTB if bold else FONT, size)
    except Exception: return ImageFont.load_default()

def grid(rows, cols_title, out, k=2, title=None, label_w=190, gap=8, bg=(245, 245, 240)):
    """rows: [(label, [img, ...])] all cells of a row share one crop; cols_title: column titles."""
    cells = []
    for label, imgs in rows:
        x0, y0, x1, y1 = crop_box(imgs)
        cells.append((label, [im[y0:y1, x0:x1] for im in imgs]))
    ncol = max(len(c[1]) for c in cells)
    cw = [0] * ncol
    for _, ims in cells:
        for j, im in enumerate(ims): cw[j] = max(cw[j], im.shape[1] * k)
    rh = [max(im.shape[0] for im in ims) * k for _, ims in cells]
    th = 44 if title else 0
    Wt = label_w + sum(cw) + gap * (ncol + 1)
    Ht = th + 30 + sum(rh) + gap * (len(cells) + 1)
    sheet = Image.new('RGB', (Wt, Ht), bg)
    d = ImageDraw.Draw(sheet)
    if title: d.text((10, 8), title, fill=(20, 20, 20), font=font(24, True))
    x = label_w + gap
    for j in range(ncol):
        if j < len(cols_title): d.text((x + 4, th + 4), cols_title[j], fill=(20, 20, 20), font=font(20))
        x += cw[j] + gap
    y = th + 30 + gap
    for (label, ims), h in zip(cells, rh):
        yy = y
        for line in label.split('\n'):
            d.text((10, yy), line, fill=(20, 20, 20), font=font(20, bold=(yy == y)))
            yy += 26
        x = label_w + gap
        for j, im in enumerate(ims):
            pim = Image.fromarray(im).resize((im.shape[1] * k, im.shape[0] * k), Image.NEAREST)
            sheet.paste(pim, (x, y + h - pim.size[1]))
            x += cw[j] + gap
        y += h + gap
    sheet.save(out)
    return sheet.size


def grid2(groups, cols_title, out, k=2, title=None, label_w=200, gap=8, bg=(245, 245, 240), notes=None):
    """groups: [(group label, [(row label, [img or None, ...]), ...])]; every picture of a group shares one crop, so
    sizes compare; cols_title: one title per column."""
    blocks = []
    for glabel, rows in groups:
        imgs = [im for _, r in rows for im in r if im is not None]
        x0, y0, x1, y1 = crop_box(imgs)
        blocks.append((glabel, [(rl, [None if im is None else im[y0:y1, x0:x1] for im in r]) for rl, r in rows],
                       (x1 - x0) * k, (y1 - y0) * k))
    ncol = max(len(r) for _, rows, _, _ in blocks for _, r in rows)
    cw = [0] * ncol
    for _, rows, w, h in blocks:
        for j in range(ncol): cw[j] = max(cw[j], w)
    th = 44 if title else 0
    nh = 30 * len(notes) if notes else 0
    Wt = label_w + sum(cw) + gap * (ncol + 1)
    Ht = th + nh + 30 + sum(h + gap for _, rows, w, h in blocks for _ in rows) + gap * (len(blocks) + 1)
    sheet = Image.new('RGB', (Wt, Ht), bg)
    d = ImageDraw.Draw(sheet)
    if title: d.text((10, 8), title, fill=(20, 20, 20), font=font(24, True))
    y = th
    for nl in (notes or []):
        d.text((10, y + 2), nl, fill=(40, 40, 40), font=font(19)); y += 30
    x = label_w + gap
    for j in range(ncol):
        if j < len(cols_title): d.text((x + 4, y + 4), cols_title[j], fill=(20, 20, 20), font=font(20, True))
        x += cw[j] + gap
    y += 30 + gap
    for glabel, rows, w, h in blocks:
        for ri, (rl, ims) in enumerate(rows):
            yy = y
            gl = glabel.split('\n') if ri == 0 else []
            lines = gl + (rl.split('\n') if rl else [])
            for li, line in enumerate(lines):
                d.text((10, yy), line, fill=(20, 20, 20), font=font(21 if li < len(gl) else 18, bold=li < len(gl)))
                yy += 26
            x = label_w + gap
            for j, im in enumerate(ims):
                if im is not None:
                    pim = Image.fromarray(im).resize((im.shape[1] * k, im.shape[0] * k), Image.NEAREST)
                    sheet.paste(pim, (x, y))
                x += cw[j] + gap
            y += h + gap
        y += gap
    sheet.save(out)
    return sheet.size
