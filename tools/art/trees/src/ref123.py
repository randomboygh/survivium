# Reference 123 lookup: the three leaf styles' ramps and module boxes (native 256 px coordinates of the
# last frame), as found in earlier threads (HANDOFF «Round 18»).
import os, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, '..', 'ref')
DARK = ['13051b', '2d1952', '3c3787']
RAMPS = {'dots': DARK + ['6a3787', '9155a0', 'b476b8'],
         'blades': DARK + ['27596c', '368578', '549e9f', '76b899'],
         'round': DARK + ['27596c', '528635', '629f54', 'a1b875']}
# (rows of the stage row, rows of the dark/mid/light row, the three column ranges), inclusive
BOX = {'dots': ((151, 171), (184, 204), ((11, 31), (35, 55), (60, 80))),
       'blades': ((151, 172), (184, 205), ((92, 113), (117, 138), (142, 163))),
       'round': ((150, 172), (183, 205), ((174, 196), (199, 221), (223, 245)))}

def sheet(frame=None):
    if frame is None:
        return np.array(Image.open(os.path.join(REF, 'l_n.png')).convert('RGB'))
    im = Image.open(os.path.join(REF, '123-leaf-styles.gif')); im.seek(frame)
    return np.array(im.convert('RGB').resize((256, 256), Image.NEAREST))

def index(a, style):
    """Ramp index per pixel, -1 elsewhere."""
    lut = {tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)): k for k, h in enumerate(RAMPS[style])}
    out = np.full(a.shape[:2], -1, int)
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            out[y, x] = lut.get(tuple(int(v) for v in a[y, x]), -1)
    return out

def module(style, row, col, a=None):
    """row 0 = drawing stages, 1 = dark/mid/light; col 0..2."""
    a = sheet() if a is None else a
    rr = BOX[style][row]; cc = BOX[style][2][col]
    return index(a[rr[0]:rr[1] + 1, cc[0]:cc[1] + 1], style)

def show(m):
    return '\n'.join(''.join('.' if v < 0 else str(v) for v in r) for r in m)
