# Leaf modules after the reference's brushes (sheet 123, pointy style; sheet 122 module):
# every leaf is a BLADE, a sheared rectangle: rows of the same width, each row moved one pixel
# sideways, so the long edges are straight and parallel and the ends are cut at 45 degrees (the
# reference's parallelogram icon). Pointing straight down there is the drop tip. A module is a
# star of blades round the middle (the reference's rosette) with two or three blades on top.
# Per pixel: leaf (draw order, -1 none), role, way of the leaf (screen angle, y down), ring.
import numpy as np, math, random

OUT, BODY, VEIN, HIGH, LOW = 0, 1, 2, 3, 4   # LOW: the outline on the leaf's shade (lower) side

# The brushes as letter grids (O outline, B body, L light, V vein), drawn after the 123 icons.
# Pointing right and up: the "/" blade. The others are its mirrors and transposes.
def _blade(W, H):
    """A "/" blade: H rows of W pixels, each row one pixel left of the one above, outlined; a small
    light block under the top edge, toward the middle (the reference's lit hearts)."""
    rows = []
    for r in range(H):
        off = H - 1 - r
        line = ['.'] * (W + H - 1)
        for i in range(W):
            edge = r in (0, H - 1) or i in (0, W - 1)
            lit = (r == 1 and 2 <= i <= W - 3) or (r == 2 and 2 <= i <= min(3, W - 3))
            line[off + i] = 'O' if edge else ('L' if lit else 'B')
        rows.append(line)
    return [''.join(l) for l in rows]

STAMPS = {'long': _blade(7, 4), 'mid': _blade(6, 5), 'steep': _blade(5, 6)}
# the drop: a blade pointing straight down with a pointed end (the reference's lower tip)
DROP = [
    "OOOOO",
    "OLLBO",
    "OBBBO",
    "OBBBO",
    ".OBO.",
    "..O..",
]

def _grid(rows):
    return [(x, y, ch) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch != '.']

def stamp(kind, sx, sy, transpose=False):
    """Pixels of a brush pointing up-right ("/"), mirrored by sx, sy (+1/-1), optionally transposed
    (the steep and level kinds swap). Returns [(x, y, ch)] with the outer tip at the max of dir."""
    rows = DROP if kind == 'drop' else STAMPS[kind]
    px = _grid(rows)
    if transpose: px = [(y, x, ch) for x, y, ch in px]
    W = max(p[0] for p in px) + 1; H = max(p[1] for p in px) + 1
    out = []
    for x, y, ch in px:
        if sx < 0: x = W - 1 - x
        if sy < 0: y = H - 1 - y
        out.append((x, y, ch))
    # the light row is always the top one, whatever the mirror: an inside pixel under the outline
    S = {(x, y): ch for x, y, ch in out}
    res = []
    for x, y, ch in out:
        if ch in 'LB':
            ch = 'L' if S.get((x, y - 1)) == 'O' or (x, y - 1) not in S else 'B'
        res.append((x, y, ch))
    return res

ROLE = {'O': OUT, 'B': BODY, 'L': HIGH, 'V': BODY}   # the reference's leaves show no vein at this size

def _place(leaf_px, angle, r0, c):
    """Move a stamp so its inner end sits r0 px from the middle c along the leaf's way."""
    d = (math.cos(angle), math.sin(angle))
    proj = [x * d[0] + y * d[1] for x, y, _ in leaf_px]
    lo = min(proj)
    # the pixels at the inner end, their mean, goes to c + d * r0
    ends = [(x, y) for (x, y, _), p in zip(leaf_px, proj) if p < lo + 1.5]
    ex = sum(e[0] for e in ends) / len(ends); ey = sum(e[1] for e in ends) / len(ends)
    tx = c[0] + d[0] * r0 - ex; ty = c[1] + d[1] * r0 - ey
    return [(int(round(x + tx)), int(round(y + ty)), ch) for x, y, ch in leaf_px]

def _brush_for(angle, rng):
    """Which brush, mirrored how, for a leaf pointing at angle (screen, y down)."""
    dx, dy = math.cos(angle), math.sin(angle)
    sx = 1 if dx >= 0 else -1; sy = 1 if dy <= 0 else -1
    a = abs(math.degrees(math.atan2(-dy, abs(dx))))   # 0 level .. 90 vertical
    if a > 78 and dy > 0: return ('drop', 1, 1, False)
    if a < 22: kind, tr = 'long', False
    elif a < 38: kind, tr = 'mid', False
    elif a < 52: kind, tr = rng.choice([('steep', False), ('mid', False)])
    elif a < 70: kind, tr = 'steep', False
    else: kind, tr = 'mid', True
    return (kind, sx, sy, tr)

# The rosette, laid by hand after the reference's module: (x, y of the stamp's top-left corner,
# W, H, mirror: "/" or "\\" or "drop", ring). The lower blades first, the upper ones over them,
# the blades on top last.
LAYOUT = [   # drawn top row first: each lower blade lies over the one above it, like shingles
    (3, 0, 5, 6, '\\', 0),      # up-left, steep
    (12, 1, 7, 4, '/', 0),      # up-right, level
    (8, 2, 4, 6, '/', 1),       # up, middle, steep
    (0, 5, 7, 4, '\\', 0),      # left, level
    (15, 4, 5, 6, '/', 0),      # right, steep
    (5, 7, 6, 5, '\\', 1),      # middle left
    (11, 8, 7, 4, '/', 1),      # middle right, level
    (0, 10, 6, 5, '/', 0),      # left, low
    (15, 11, 7, 4, '\\', 0),    # right, low, level
    (6, 12, 5, 6, '\\', 1),     # low middle, steep
    (11, 13, 6, 5, '/', 1),     # low middle right
    (2, 14, 5, 6, '/', 0),      # down-left, steep
    (14, 15, 6, 5, '\\', 0),    # down-right
    (9, 17, 0, 0, 'drop', 0),   # down
]

def module(seed, size=25, upto=99):
    rng = random.Random(seed)
    flip = seed % 2 == 1
    c = (size - 1) / 2.0
    leaf = -np.ones((size, size), int); role = np.zeros((size, size), int)
    ang = np.zeros((size, size)); ring = np.zeros((size, size), int)
    sides = np.zeros((size, size), int)   # bits: 1 outline above, 2 right, 4 left, 8 below
    for k, (x0, y0, W, H, m, rg) in enumerate(LAYOUT):
        if k >= upto: break
        x0 += rng.randint(-1, 1); y0 += rng.randint(-1, 1) if rg == 0 else 0
        if m == 'drop': px = _grid(DROP)
        else:
            px = _grid(_blade(W + rng.randint(0, 1), H))
            if m == '\\':
                w = max(p[0] for p in px)
                px = [(w - x, y, ch) for x, y, ch in px]
        px = [(x + x0, y + y0, ch) for x, y, ch in px]
        if flip: px = [(size - 1 - x, y, ch) for x, y, ch in px]
        S = {(x, y): ch for x, y, ch in px}
        mx = sum(p[0] for p in px) / len(px); my = sum(p[1] for p in px) / len(px)
        a = math.atan2(my - c, mx - c) if rg == 0 else math.atan2(my - c - 4, mx - c)
        for x, y, ch in px:
            if not (0 <= x < size and 0 <= y < size): continue
            r = ROLE[ch]
            leaf[y, x] = k; role[y, x] = r; ang[y, x] = a; ring[y, x] = rg
    # the outline along the module's lower rim is the shade side
    for y in range(size):
        for x in range(size):
            if role[y, x] == OUT and leaf[y, x] >= 0 and (y + 1 == size or leaf[y + 1, x] < 0) and y > 0 and leaf[y - 1, x] >= 0:
                role[y, x] = LOW
    return dict(leaf=leaf, role=role, ang=ang, ring=ring, sides=sides, size=size)

def tones(mod, light2, lift=0.0):
    """Relative tones of a module lit from the screen way light2 (unit, y down): a leaf pointing to
    the light +2, across +1, away 0; the blades on top +1 (max +2); outline -1, shade outline -2,
    vein -1, light +1 (only on leaves that face the light). -9 = empty."""
    S = mod['size']; out = np.full((S, S), -9, int)
    for y in range(S):
        for x in range(S):
            k = mod['leaf'][y, x]
            if k < 0: continue
            a = mod['ang'][y, x]
            f = math.cos(a) * light2[0] + math.sin(a) * light2[1]
            body = (2 if f > 0.25 else (1 if f > -0.45 else 0)) + round(lift)
            if mod['ring'][y, x] == 1: body = min(2, body + 1)
            r = mod['role'][y, x]
            if r == VEIN and body >= 2: t = body
            elif r == OUT or r == VEIN: t = body - 1
            elif r == LOW: t = body - 2
            elif r == HIGH: t = body + 1 if body >= 1 else body
            else: t = body
            out[y, x] = t
    return out
