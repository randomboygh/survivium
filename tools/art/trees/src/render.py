import numpy as np, math, random, sys
from PIL import Image
sys.path.insert(0, '.')
from module import rosette

def hexc(h): return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
RAMPS = {
 'summer': ['13051b','2d1952','3c3787','386386','368578','549f73','629f54','a1b875'],
 'spring': ['13051b','2d1952','3c3787','2f6d7d','3f8f6a','6aaa58','95c25c','cfe08a'],
 'autumn': ['13051b','2d1952','4d1852','863945','b35a3a','d08a3c','e0b45a','f0dc8c'],
}
TRUNK = ['13051b','2d1952','4d1852','863945']
SHADOW = '3c3787'

STEP = 13.5
DROP = True
def norm(v): v = np.asarray(v, float); return v / np.linalg.norm(v)

MODS = [rosette(s) for s in (3, 11, 17, 29)]

def crown_points(rx, ry, rz, step, seed=1):
    rng = random.Random(seed)
    pts = []
    n = int(4 * math.pi * ((rx * ry + ry * rz + rx * rz) / 3) / (step * step))
    for i in range(n):
        yy = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - yy * yy)
        th = math.pi * (3 - math.sqrt(5)) * i
        u = np.array([math.cos(th) * r, yy, math.sin(th) * r])
        if u[1] < -0.35: continue
        jit = 1 + rng.uniform(-0.12, 0.12)
        p = u * np.array([rx, ry, rz]) * jit
        pts.append((p, norm(u / np.array([rx, ry, rz]) ** 1 * np.array([rx, ry, rz]) ** 0)))
    return pts

def leaf_shift(mod, y, x, L):
    d = float(mod['n'][y, x] @ L)
    lit = round((d - L[1] * 0.75) * 2.8 + 0.3)
    dep = mod['depth'][y, x]
    if mod['over'][y, x] and mod['low'][y, x]: return lit - 2   # a leaf's edge over another, on its shade side
    if mod['low'][y, x]: return lit - 1                         # its outline on the shade side
    if dep >= 2 and d - L[1] * 0.75 > 0.15: return lit + 1  # the bright heart of a lit leaf
    return lit

def band(d):
    return 2 if d > 0.75 else (1 if d > 0.45 else (0 if d > 0.1 else -1))

def draw_tree(sun, season='summer', W=150, H=150, snow=0.0, bare=False, ground='8da38c', seed=1, scale_mark=None, cloudy=False, trunk_only=False, oy=None, cy=None):
    L = norm(sun)
    ramp = [hexc(h) for h in RAMPS[season]]
    img = np.zeros((H, W, 3), np.uint8); img[:] = hexc(ground)
    zbuf = np.full((H, W), -1e9)
    ox = W // 2
    oy = H - 22 if oy is None else oy        # ground point of the trunk
    rx, ry, rz = 42, 16, 26
    cy = 56 if cy is None else cy            # crown center height
    def proj(p):                   # world px (x, y up, z toward viewer) -> screen
        return ox + p[0], oy + p[2] - p[1]
    # cast shadow on the ground: ellipsoid squashed onto y=0 along the sun
    sh = np.zeros((H, W), bool)
    rng = random.Random(seed)
    if L[1] > 0.1 and not bare and not cloudy and not trunk_only:
        for y in range(H):
            for x in range(W):
                gx, gz = x - ox, y - oy
                # point on ground; walk back up the sun ray to crown heights
                hit = False
                for h in range(int(cy - ry), int(cy + ry) + 1, 2):
                    px = gx + L[0] / L[1] * h; pz = gz + L[2] / L[1] * h
                    q = ((px) / rx) ** 2 + ((h - cy) / ry) ** 2 + (pz / rz) ** 2
                    if q < 1.0 - 0.12 * ((hash((x // 2, y // 2, seed)) % 7) / 6.0):
                        hit = True; break
                tr = False
                if hit or tr: sh[y, x] = True
        img[sh] = hexc(SHADOW)
    # trunk: columns lit by their facing (4-colour bark ramp), grooves, a flared foot, roots
    tr_r = 15
    top = int(cy - ry * 0.2)
    tb = np.full((H, W), -1, int)
    sun_x = 1 if L[0] >= 0 else -1
    for xx in range(-tr_r - 4, tr_r + 5):
        r0 = tr_r + 3.0
        if abs(xx) > r0: continue
        for sy in range(oy - top, oy + 6):
            h = oy - sy
            r = tr_r + max(0.0, 3.0 - max(h, 0) * 0.5)
            if abs(xx) > r: continue
            a = math.asin(max(-1, min(1, xx / r)))
            if sy > oy + int(round(r * math.cos(a) * 0.3)): continue
            d = np.array([math.sin(a), 0, math.cos(a)]) @ L
            k = 3 if d > 0.1 else (2 if d > -0.35 else 1)
            groove = (xx + 50) % 4 == 0 and (h * 5 + xx * 11) % 19 > 4
            if groove or abs(xx) >= r - 0.7: k = max(0, k - 1)
            if h > top - 7: k = max(0, k - 1)
            if 0 <= ox + xx < W and 0 <= sy < H: tb[sy, ox + xx] = k
    # roots: flat wedges from the foot along the ground
    for ang, ln in ((0.25, 12), (0.9, 10), (2.5, 11), (1.7, 8)):
        dx, dz = math.cos(ang), math.sin(ang)
        for y in range(H):
            for x in range(W):
                gx, gz = x - ox, (y - oy) / 0.6
                t = gx * dx + gz * dz - (tr_r - 4); s = -gx * dz + gz * dx
                if t < 0 or t > ln: continue
                w = 3.2 * (1 - t / ln) + 0.4
                if abs(s) > w: continue
                lit = (dx * L[0] - dz * L[2] * 0.5) > 0.0
                k = 3 if (lit and s < w * 0.3) else 2
                if s > w - 1: k = 1
                if tb[y, x] < 0 or y > oy - 2: tb[y, x] = k
    for y in range(H):
        for x in range(W):
            if tb[y, x] >= 0: img[y, x] = hexc(TRUNK[tb[y, x]])
    if trunk_only:
        return img
    # dark backing silhouette of the crown (index 1), then modules into an index buffer
    ib = np.full((H, W), -1, int); snowb = np.zeros((H, W), bool)
    if bare:
        _branches(img, ox, oy - top + 8, L, snow, seed)
        return img
    for y in range(H):
        for x in range(W):
            sx, sy = x - ox, y - oy
            if (sx / (rx * 0.9)) ** 2 + ((sy + cy) / (math.hypot(ry, rz) * 0.72)) ** 2 < 1:
                ib[y, x] = 1
    pts = crown_points(rx, ry, rz, STEP, seed)
    pts.sort(key=lambda t: t[0][1] * 0.4 + t[0][2])
    # shade a module casts on what lies under it: its silhouette moved away from the sun
    sdx = -int(round(np.sign(L[0]))) * (1 if abs(L[0]) > 0.3 else 0)
    for i, (p, n) in enumerate(pts):
        c = np.array([0, cy, 0]) + p
        sx, sy = proj(c)
        mod = MODS[(i * 7 + seed) % len(MODS)]
        dn = float(n @ L)
        under = n[1] < -0.2
        cshift = band(dn) - (1 if under else 0) - (1 if cloudy else 0)
        S = mod['leaf'].shape[0]
        X0 = int(round(sx)) - S // 2; Y0 = int(round(sy)) - S // 2
        if DROP:
            for yy in range(S):
                for xx in range(S):
                    if mod['leaf'][yy, xx] < 0: continue
                    for X, Y in ((X0 + xx + sdx, Y0 + yy + 2), (X0 + xx + sdx, Y0 + yy + 1)):
                        if 0 <= X < W and 0 <= Y < H and ib[Y, X] > 1:
                            ib[Y, X] = -100 - ib[Y, X]   # mark, darken once
            m = ib < -50; ib[m] = np.maximum(1, -ib[m] - 100 - 1)
        for yy in range(S):
            for xx in range(S):
                if mod['leaf'][yy, xx] < 0: continue
                X = X0 + xx; Y = Y0 + yy
                if not (0 <= X < W and 0 <= Y < H): continue
                nn = mod['n'][yy, xx]
                idx = 3 + cshift + leaf_shift(mod, yy, xx, L)
                ib[Y, X] = max(0, min(len(ramp) - 1, idx))
                snowb[Y, X] = snow > 0 and n[1] > 0.3 and nn[1] > 0.55 and not mod['low'][yy, xx]
    for y in range(H):
        for x in range(W):
            if ib[y, x] >= 0:
                img[y, x] = ramp[ib[y, x]]
                if snowb[y, x]:
                    img[y, x] = hexc('e8ecf4') if ib[y, x] >= 3 else hexc('aab4d0')
    return img

def _branches(img, x0, y0, L, snow, seed):
    rng = random.Random(seed + 5)
    H, W = img.shape[:2]
    cols = [hexc(h) for h in TRUNK]
    buf = {}
    def seg(x, y, z, ang, tilt, length, w, depth):
        dx, dy, dz = math.cos(ang) * math.sin(tilt), math.cos(tilt), math.sin(ang) * math.sin(tilt) * 0.6
        n = max(2, int(length))
        for i in range(n + 1):
            f = i / n
            px, py, pz = x + dx * i, y + dy * i, z + dz * i
            ww = w * (1 - f * 0.45)
            sx, sy = x0 + px, y0 + pz - py
            for ox_ in range(-int(ww) - 1, int(ww) + 2):
                for oy_ in (0, 1):
                    if abs(ox_) > ww + 0.3: continue
                    X, Y = int(round(sx + ox_)), int(round(sy)) + oy_
                    if not (0 <= X < W and 0 <= Y < H): continue
                    side = ox_ / max(ww, 0.5)
                    k = 3 if side * (1 if L[0] >= 0 else -1) > -0.1 else 1
                    if abs(ox_) >= ww - 0.2 and ww >= 1: k = 0 if k == 1 else 2
                    buf[(X, Y)] = k
            if snow and tilt > 0.6:
                X, Y = int(round(sx)), int(round(sy - max(ww, 0.5) * math.cos(tilt) - 1))
                buf[(X, Y)] = 9; buf[(X + 1, Y)] = 9
        ex, ey, ez = x + dx * n, y + dy * n, z + dz * n
        if depth > 0:
            k = 2 if depth < 3 else 3
            for j in range(k):
                seg(ex, ey, ez, ang + (j - (k - 1) / 2) * 1.1 + rng.uniform(-0.3, 0.3),
                    min(1.25, tilt + rng.uniform(0.1, 0.35)), length * rng.uniform(0.62, 0.78), w * 0.62, depth - 1)
    for j in range(4):
        seg(0, 0, 0, j * 1.57 + 0.4 + rng.uniform(-0.25, 0.25), rng.uniform(0.3, 0.55), rng.uniform(20, 24), 6.0, 3)
    for (X, Y), k in buf.items():
        if 0 <= X < W and 0 <= Y < H:
            img[Y, X] = hexc('e8ecf4') if k == 9 else cols[k]

def up(a, k): return np.repeat(np.repeat(a, k, 0), k, 1)

if __name__ == '__main__':
    out = sys.argv[1]
    im = draw_tree((0.8, 0.55, 0.0), W=190, H=150)
    Image.fromarray(up(im, 4)).save(out)
