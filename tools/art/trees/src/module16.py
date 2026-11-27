# Round 16: smaller leaf modules for small crowns. The leaves stay the reference's stamps (pixel art
# cannot be scaled): a small module pulls every leaf of a layout toward the module's middle (factor k)
# and leaves out the leaves that would then hardly show, so the cluster is smaller and has fewer
# leaves; the dark disc under them shrinks by k too.
import math
import numpy as np
import module5 as M
from module5 import S, C, N4, ROLE, LEAVES, _pixels, _turn, _centre, layout

def _finish(placed, k, flip):
    leaf = -np.ones((S, S), int); role = np.zeros((S, S), int)
    for s, px in enumerate(placed):
        for x, y, ch in px:
            if 0 <= x < S and 0 <= y < S:
                leaf[y, x] = s; role[y, x] = ROLE[ch]
    n = len(placed)
    ang = np.zeros(n); top = np.zeros(n, bool)
    for q in range(n):
        ys, xs = np.nonzero(leaf == q)
        if len(ys):
            ang[q] = math.atan2(ys.mean() - C[1], xs.mean() - C[0])
            top[q] = math.hypot(ys.mean() - C[1], xs.mean() - C[0]) < 5.5 * k
    depth = np.zeros((S, S), int)
    for y in range(S):
        for x in range(S):
            q = leaf[y, x]
            if q < 0: continue
            d = 0
            while d < 4 and all(0 <= y + dy * (d + 1) < S and 0 <= x + dx * (d + 1) < S and
                                leaf[y + dy * (d + 1), x + dx * (d + 1)] == q for dx, dy in N4):
                d += 1
            depth[y, x] = d
    yy, xx = np.mgrid[0:S, 0:S]
    disc = (xx - C[0]) ** 2 + (yy - C[1] + 0.5) ** 2 < (8.6 * k) ** 2
    m = dict(leaf=leaf, role=role, ang=ang, depth=depth, top=top, flip=flip, disc=disc, k=k)
    if flip:
        for key in ('leaf', 'role', 'depth', 'disc'): m[key] = m[key][:, ::-1].copy()
        m['ang'] = math.pi - ang
    return m

def module_k(seed=0, k=1.0, flip=False):
    placed = [_turn(_pixels(j), t) for j, t in layout(seed)]
    if seed != 0:
        def key(px):
            cx, cy = _centre(px)
            return (0 if math.hypot(cx - C[0], cy - C[1]) < 5.5 else 1, cy)
        placed.sort(key=key)
    if k < 0.999:
        moved = []
        for px in placed:
            cx, cy = _centre(px)
            dx, dy = round((k - 1) * (cx - C[0])), round((k - 1) * (cy - C[1]))
            moved.append([(x + dx, y + dy, ch) for x, y, ch in px])
        # leave out the leaves that show least once the others are drawn over them
        keep = max(5, round(len(moved) * k * k * 1.15))
        idx = sorted(range(len(moved)), key=lambda q: -math.hypot(*np.subtract(_centre(moved[q]), C)))
        while len(idx) > keep:
            owner = {}
            for q in idx:
                for x, y, _ in moved[q]: owner[(x, y)] = q
            vis = {q: 0 for q in idx}
            for q in owner.values(): vis[q] += 1
            idx.remove(min(idx, key=lambda q: vis[q] / len(moved[q])))
        # the middle leaves on top, as a small cluster seen from above
        idx.sort(key=lambda q: -math.hypot(*np.subtract(_centre(moved[q]), C)))
        placed = [moved[q] for q in idx]
    return _finish(placed, k, flip)

_CACHE = {}
def modules(k, layouts=(0, 1, 5, 17)):
    k = round(k, 2)
    if k not in _CACHE:
        _CACHE[k] = [module_k(s, k, flip=f) for f in (False, True) for s in layouts]
    return _CACHE[k]
