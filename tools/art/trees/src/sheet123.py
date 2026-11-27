# Close-up sheets of the leaf modules in reference 123's three styles (round 18, step 1):
# reference module vs ours (in the reference's colours and in the game's linden colours), dark / mid /
# light, the brushes, and the 8 variants (4 layouts x mirror). Usage: sheet123.py <outdir>
import sys, numpy as np
from PIL import Image, ImageDraw
import module123 as MM, module5 as M5, ref123 as RF, render7 as R7, render6 as R6
from render2 import hexc
from sheets7 import tile, grid, vstack, FONT

L = R7.norm(R7.SUN_R)
LIGHT2 = R7.norm((L[0], L[2] - L[1]))
GAME = R7.contrast(R6.ramp_for('summer', R7.LINDEN), 1.3)
PANEL = '8c9fa3'
NAMES = {'dots': 'точки', 'blades': 'клинки', 'round': 'круглые', '122': 'листья 122 (сейчас)'}

def colours(c, ramp):
    rp = np.array([hexc(h) for h in ramp], float)
    c = np.clip(np.asarray(c, float), 0, len(rp) - 1)
    lo = np.floor(c).astype(int); hi = np.minimum(lo + 1, len(rp) - 1); f = (c - lo)[..., None]
    return np.round(rp[lo] * (1 - f) + rp[hi] * f).astype(np.uint8)

def tones_of(m):
    return MM.tones if 'style' in m else M5.tones

def paint(m, base, ramp, flat=False, quarter=True, bg=PANEL):
    """A module as the tree draws it (render7.module_pixels): base step + tones; the disc is base - 1;
    in the shade (base 2) the leaves turned away keep 3/4 of their step down (shade_flat 'quarter')."""
    T = tones_of(m)
    t = T(m, LIGHT2, flat=flat).astype(float)
    if base == 2 and quarter and not flat:
        fl = T(m, LIGHT2, flat=True)
        lt = t - fl
        t = np.where(t > -9, fl + np.where(lt < 0, lt * 0.75, lt), t)
    dsk = m['disc'] if 'disc' in m else M5.disc(m['flip'])
    mask = (t > -9) | dsk
    c = base + np.where(t > -9, t, -1)
    img = np.zeros((M5.S, M5.S, 3), np.uint8); img[:] = hexc(bg)
    img[mask] = colours(c, ramp)[mask]
    return img

def ref_module(style, row, col):
    """The reference's module in the 30 px box, its own colours."""
    a = RF.sheet()
    m = RF.module(style, row, col, a)
    ox, oy = MM.DATA[style]['offset']
    img = np.zeros((M5.S, M5.S, 3), np.uint8); img[:] = hexc(PANEL)
    ys, xs = np.nonzero(m >= 0)
    img[ys + oy, xs + ox] = colours(m[ys, xs], RF.RAMPS[style])
    return img

def brush_strip(style, k=10):
    """The reference's leaf icons as they are on the sheet, and our brushes (the same icons with the
    heart marked) lit: outline 0, body +1, heart +2 (in the reference's colours, step 3 = body)."""
    a = RF.sheet()
    import peel as P
    ics = P.icons(style, a)
    br = MM.DATA[style]['brushes'][:len(ics)]
    tiles = []
    for ic, rows in zip(ics, br):
        h, w = ic.shape
        pad = 2
        A = np.zeros((h + 2 * pad, w + 2 * pad, 3), np.uint8); A[:] = hexc(PANEL)
        ys, xs = np.nonzero(ic >= 0)
        A[ys + pad, xs + pad] = colours(ic[ys, xs], RF.RAMPS[style])
        B = np.zeros_like(A); B[:] = hexc(PANEL)
        G = np.zeros_like(A); G[:] = hexc(PANEL)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == '.': continue
                rel = {'O': -1, 'V': -1, 'B': 0, 'H': 1}[ch] + 1
                B[y + pad, x + pad] = colours(3 + rel, RF.RAMPS[style])
                G[y + pad, x + pad] = colours(3 + rel, GAME)
        tiles.append(np.concatenate([A, np.full((A.shape[0], 1, 3), 255, np.uint8), B,
                                     np.full((A.shape[0], 1, 3), 255, np.uint8), G], 1))
    H = max(t.shape[0] for t in tiles)
    row = []
    for t in tiles:
        t = np.pad(t, ((0, H - t.shape[0]), (0, 2), (0, 0)), constant_values=235)
        row.append(t)
    strip = np.concatenate(row, 1)
    return Image.fromarray(np.repeat(np.repeat(strip, k, 0), k, 1))

def header(txt, W, size=22, h=36, bg=(250, 250, 250)):
    im = Image.new('RGB', (W, h), bg)
    ImageDraw.Draw(im).text((8, 5), txt, font=FONT(size), fill=(10, 10, 30))
    return im

def style_sheet(style, k=10):
    S = MM.Style(style)
    m0 = S.module(0)
    LB = ('плоский', 'тень', 'полутень', 'свет')
    ref_row = [tile(ref_module(style, 0, 0), k, LB[0]), tile(ref_module(style, 1, 0), k, LB[1]),
               tile(ref_module(style, 1, 1), k, LB[2]), tile(ref_module(style, 1, 2), k, LB[3])]
    rr = RF.RAMPS[style]
    our_ref = [tile(paint(m0, 3, rr, flat=True), k, LB[0]), tile(paint(m0, 2, rr), k, LB[1]),
               tile(paint(m0, 3, rr), k, LB[2]), tile(paint(m0, 4, rr), k, LB[3])]
    our_game = [tile(paint(m0, 3, GAME, flat=True), k, LB[0]), tile(paint(m0, 2, GAME), k, LB[1]),
                tile(paint(m0, 3, GAME), k, LB[2]), tile(paint(m0, 4, GAME), k, LB[3])]
    names = ['A (референс)', 'B', 'C', 'D']
    var = []
    for f in (False, True):
        for i, s in enumerate(MM.LAYOUTS):
            var.append(tile(paint(S.module(s, flip=f), 4, GAME), k, (names[i] if not f else names[i][0] + ', зеркально')))
    g = [grid(ref_row, 4), grid(our_ref, 4), grid(our_game, 4), grid(var, 4)]
    W = max(p.size[0] for p in g)
    br = brush_strip(style, k)
    W = max(W, br.size[0])
    parts = [header('Листья «%s»: модули (×%d)' % (NAMES[style], k), W, 28, 44),
             header('Кисти: референс · наша при свете (цвета референса) · наша при свете (цвета игры)', W, 18, 30), br,
             header('Референс 123, модуль в его цветах', W), g[0],
             header('Наш модуль A (листья и раскладка референса, свет по нашим правилам), цвета референса', W, 18, 30), g[1],
             header('Тот же модуль A в цветах игры (липа, контраст ×1.3)', W), g[2],
             header('Наши 8 вариантов: 4 раскладки × зеркало, на свету, цвета игры', W), g[3]]
    return vstack(parts, gap=6)

def overview(k=8):
    """All four leaf styles side by side in the game's colours: shade / half / light, layout A."""
    rows = []
    mods = {'122': R7.MODS[0]}
    for st in MM.STYLES: mods[st] = MM.Style(st).module(0)
    for key in ('122', 'dots', 'blades', 'round'):
        m = mods[key]
        rows += [tile(paint(m, 2, GAME), k, '%s' % NAMES[key], sub='тень', size=18),
                 tile(paint(m, 3, GAME), k, ' ', sub='полутень', size=18),
                 tile(paint(m, 4, GAME), k, ' ', sub='свет', size=18)]
    g = grid(rows, 3)
    hdr = Image.new('RGB', (g.size[0], 44), (250, 250, 250))
    ImageDraw.Draw(hdr).text((8, 6), 'Четыре вида листьев, цвета игры (липа ×1.3)', font=FONT(24), fill=(10, 10, 30))
    return vstack([hdr, g], gap=8)

if __name__ == '__main__':
    D = sys.argv[1]
    for i, st in enumerate(MM.STYLES):
        style_sheet(st).save('%s/42-%d-leaves-%s.png' % (D, i + 1, st))
    overview().save('%s/43-four-leaf-styles.png' % D)
    print('ok')
