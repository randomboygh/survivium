# Round 23 (user 2026-11-24 18:16 MSK): every trunk, stump, log and branch gets an outline round its perimeter, like the
# leaves': a wood pixel (the species' bark ramp, its cut wood, resin) next to the background (ground or shadow key) takes
# the darkest bark colour. A post-process of the keyed pictures, so every sheet can apply it when it loads them. Palms
# keep their own (softened, user's pick /2) outline: their trunk colours are not touched.
import numpy as np
import all23 as A, stump23 as S

_COLS = {}
PALMS = ('palm', 'fan_palm')

def wood_colours(key):
    if key not in _COLS:
        if key in PALMS:
            _COLS[key] = None
        else:
            t = A.build(key, 0.68)
            bark = np.array(t.bark, float).round().astype(int)
            wood = S.wood_ramp(key).round().astype(int)
            _COLS[key] = (bark, np.vstack([bark, wood, S.RESIN_RGB.round().astype(int)[None, :]]))
    return _COLS[key]

MODE = 'step'        # user 2026-11-24 18:47 MSK: less contrast, in the wood's own colour

def outline(img, key, bg=(A.KEY_G, A.KEY_S), mode=None):
    """img (keyed, H x W x 3 uint8) changed in place and returned. mode 'dark': the darkest bark (18:16 MSK);
    'step': one step darker of the pixel's own ramp (bark or cut wood); 'mix': half way from its own colour to the
    darkest bark (like the palms' softened outline)."""
    mode = mode or MODE
    c = wood_colours(key)
    if c is None: return img
    bark, cols = c
    a = img.astype(int)
    wood = np.zeros(img.shape[:2], bool)
    for col in cols:
        wood |= np.all(a == col, 2)
    back = np.zeros_like(wood)
    for h in bg:
        back |= np.all(a == S.hexc(h).round().astype(int), 2)
    nb = np.zeros_like(wood)
    nb[1:] |= back[:-1]; nb[:-1] |= back[1:]; nb[:, 1:] |= back[:, :-1]; nb[:, :-1] |= back[:, 1:]
    edge = wood & nb
    if mode == 'dark':
        img[edge] = bark[0].astype(np.uint8)
        return img
    ys, xs = np.nonzero(edge)
    wr = S.wood_ramp(key).round().astype(int)
    for y, x in zip(ys, xs):
        own = a[y, x]
        if mode == 'mix':
            img[y, x] = np.round(own + (bark[0] - own) / 2.0).astype(np.uint8)
            continue
        hit = np.nonzero(np.all(bark == own, 1))[0]
        if len(hit):
            img[y, x] = bark[max(0, hit[0] - 1)].astype(np.uint8)
            continue
        hit = np.nonzero(np.all(wr == own, 1))[0]
        if len(hit):
            img[y, x] = wr[max(0, hit[0] - 2)].astype(np.uint8)       # cut wood: two of its six steps
        else:
            img[y, x] = np.round(own * 0.7).astype(np.uint8)
    return img
