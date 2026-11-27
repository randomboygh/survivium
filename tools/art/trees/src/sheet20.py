# Round 20 sheets: maple leaf modules beside the reference (step 1), both maples in three sizes (step 2).
import sys, numpy as np
from PIL import Image, ImageDraw
import module_maple as MP, module123 as MM, module5 as M5, render7 as R7, render6 as R6
from sheet123 import paint, header, colours, PANEL
from render2 import hexc
from sheets7 import tile, grid, vstack, FONT

REF = '/mnt/project-files/survivium-builds/trees-redraw/references/user-maple-autumn.jpg'
# the reference's own seven leaf colours (modes of its flat art pixels), darkest to lightest
RED = ['451b1c', '6e2428', '92322c', 'b1553d', 'c27044', 'd78a4b', 'e8a152']
GREEN = R7.contrast(R6.ramp_for('summer', R7.species_tint('#4f8a3a', '#58923f', '#4a8236')), 1.3)

def quick(out, k=10):
    st = MM.Style('maple')
    m0 = st.module(0)
    row = [tile(paint(m0, b, RED), k, n) for b, n in ((2, 'тень'), (3, 'полутень'), (4, 'свет'))]
    row += [tile(paint(m0, b, GREEN), k, n) for b, n in ((2, 'тень'), (3, 'полутень'), (4, 'свет'))]
    var = [tile(paint(st.module(s, flip=f), 4, RED), k, '%d%s' % (s, 'з' if f else '')) for f in (False, True) for s in MM.LAYOUTS]
    vstack([grid(row, 6), grid(var, 4)], gap=6).save(out)


def ref_crop(x0, y0, x1, y1):
    """The reference's red maples, one art pixel per cell (the 1800x1200 JPG is pixel art x4.005)."""
    a = np.load('../ref/maple_row.npy')
    return np.clip(a[y0:y1, x0:x1], 0, 255).astype(np.uint8)

def brush_tiles(ramp, base=4, k=10):
    """Each brush alone: unlit (outline -2, body 0) and lit (body +1, star +2)."""
    tiles = []
    for b, g in enumerate(MP.BRUSHES):
        h = len(g); w = len(g[0]); pad = 2
        out = []
        for lit in (False, True):
            A = np.zeros((h + 2 * pad, w + 2 * pad, 3), np.uint8); A[:] = hexc(PANEL)
            for y, row in enumerate(g):
                for x, ch in enumerate(row):
                    if ch == '.': continue
                    t = {'O': -1 - MP.OUT_EXTRA, 'V': -1, 'B': 0, 'H': 0}[ch] + (1 if lit else 0) + (1 if lit and ch == 'H' else 0)
                    A[y + pad, x + pad] = colours(base - 1 + t, ramp)
            out.append(A)
        tiles.append(np.concatenate([out[0], np.full((out[0].shape[0], 1, 3), 255, np.uint8), out[1]], 1))
    H = max(t.shape[0] for t in tiles)
    strip = np.concatenate([np.pad(t, ((0, H - t.shape[0]), (0, 3), (0, 0)), constant_values=235) for t in tiles], 1)
    return Image.fromarray(np.repeat(np.repeat(strip, k, 0), k, 1))

def modules_sheet(out, k=10):
    st = MM.Style('maple')
    m0 = st.module(0)
    W = 6 * (30 * k + 8)
    refs = [tile(ref_crop(97, 10, 127, 40), k, 'референс: верх'),
            tile(ref_crop(20, 20, 50, 50), k, 'референс: середина')]
    red = [tile(paint(m0, b, RED), k, n) for b, n in ((2, 'тень'), (3, 'полутень'), (4, 'свет'))]
    grn = [tile(paint(m0, b, GREEN), k, n) for b, n in ((2, 'тень'), (3, 'полутень'), (4, 'свет'))]
    names = ['A', 'B', 'C', 'D']
    var = [tile(paint(st.module(s, flip=f), 4, RED), k, names[i] + (', зеркально' if f else ''))
           for f in (False, True) for i, s in enumerate(MM.LAYOUTS)]
    parts = [header('Листья клёна по референсу (левая половина, нижний ряд), ×%d' % k, W, 28, 44),
             header('Референс: одна клетка = один пиксель арта (картинка 1800×1200 — пиксель-арт ×4)', W, 18, 30),
             grid(refs, 2),
             header('Кисти листа: большой прямо, большой наклонный, малый; каждый в тени и на свету (цвета референса)', W, 18, 30),
             brush_tiles(RED, k=k),
             header('Наш модуль A, красный клён (цвета референса)', W, 18, 30), grid(red, 3),
             header('Тот же модуль A, зелёный клён (цвета игры, контраст ×1.3)', W, 18, 30), grid(grn, 3),
             header('8 вариантов модуля: 4 раскладки × зеркало, на свету, красный клён', W, 18, 30), grid(var, 4)]
    vstack(parts, gap=6).save(out)

if __name__ == '__main__':
    modules_sheet(sys.argv[1]) if len(sys.argv) < 3 else quick(sys.argv[1])
