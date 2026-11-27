"""Small helpers: fill-only drawings outlined automatically, layers, shifts, canvases."""
def outline(rows, k='K', skip=''):
    """Adds `k` on every empty pixel 4-touching a fill (letters in `skip` get no outline, e.g. legs)."""
    h = len(rows) + 2; w = max(len(r) for r in rows) + 2
    g = [['.'] * w for _ in range(h)]
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c not in '. ': g[y + 1][x + 1] = c
    out = [row[:] for row in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] != '.': continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and g[yy][xx] not in '.' + skip + k:
                    out[y][x] = k; break
    return [''.join(r) for r in out]
def blank(w, h): return ['.' * w for _ in range(h)]
def put(base, top, x, y):
    """`top` over `base` at (x, y); '.' in top leaves base."""
    b = [list(r) for r in base]
    for j, r in enumerate(top):
        for i, c in enumerate(r):
            if c != '.' and 0 <= y + j < len(b) and 0 <= x + i < len(b[0]): b[y + j][x + i] = c
    return [''.join(r) for r in b]
def trim(rows):
    """Cuts empty columns and rows round the figure (keeps the last row as ground)."""
    ys = [y for y, r in enumerate(rows) if r.strip('.')]
    xs = [x for x in range(max(len(r) for r in rows)) if any(x < len(r) and r[x] != '.' for r in rows)]
    return [r[xs[0]:xs[-1] + 1].ljust(xs[-1] - xs[0] + 1, '.') for r in rows[ys[0]:ys[-1] + 1]]
def mir(h): return [r + r[-2::-1] for r in h]
def flip(rows): return [r[::-1] for r in rows]
def paint(rows, marks):
    b = [list(r) for r in rows]
    for (x, y, s) in marks:
        for i, c in enumerate(s):
            if c != '.': b[y][x + i] = c if c != '_' else '.'
    return [''.join(r) for r in b]
def canvas(frames, pad_x=0):
    """All frames of a view on one canvas: bottoms aligned (last row the ground), centred."""
    w = max(len(f[0]) for f in frames) + pad_x; h = max(len(f) for f in frames)
    out = []
    for f in frames:
        fw = len(f[0]); x = (w - fw) // 2
        c = blank(w, h); out.append(put(c, f, x, h - len(f)))
    return out
def squash(rows, r):
    """Row r taken out, an empty row on top: a crouch or a fluffed rest."""
    return [blank(len(rows[0]), 1)[0]] + rows[:r] + rows[r + 1:]
def up(rows, n, drop_legs=0):
    """The figure raised n rows (its last `drop_legs` rows dropped first), same height."""
    body = rows[:len(rows) - drop_legs] if drop_legs else rows
    body = body[n:] if n > 0 else body
    w = len(rows[0])
    return body + ['.' * w] * (len(rows) - len(body))
def shiftx(rows, dx, r0=0, r1=None):
    r1 = len(rows) if r1 is None else r1
    out = list(rows)
    for y in range(r0, r1):
        r = rows[y]
        out[y] = ('.' * dx + r[:len(r) - dx]) if dx > 0 else (r[-dx:] + '.' * -dx)
    return out
def pad(rows, l=0, r=0, t=0):
    w = len(rows[0]) + l + r
    return ['.' * w] * t + ['.' * l + x + '.' * r for x in rows]
def no_inner(rows, k='K', keep=''):
    """Outline pixels with no empty 4-neighbour (lines inside the body) take the commonest fill around them."""
    h = len(rows); w = len(rows[0]); out = [list(r) for r in rows]
    for y in range(h):
        for x in range(w):
            if rows[y][x] != k: continue
            edge = False; around = {}
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < w and 0 <= yy < h) or rows[yy][xx] == '.': edge = True
            if edge: continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and rows[yy][xx] not in '.' + k + keep:
                        around[rows[yy][xx]] = around.get(rows[yy][xx], 0) + 1
            if around: out[y][x] = max(around, key=around.get)
    return [''.join(r) for r in out]
