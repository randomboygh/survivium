# The game shader's rule in numpy: a G-buffer frame + sun -> RGB (for checking the export).
import math, numpy as np
D1, D2, DP = 0.64, 0.36, 0.8
def unocta(r, g):
    x = r / 255 * 2 - 1; y = g / 255 * 2 - 1
    z = 1 - abs(x) - abs(y)
    if z < 0: x, y = (1 - abs(y)) * math.copysign(1, x), (1 - abs(x)) * math.copysign(1, y)
    n = np.array([x, y, z]); return n / np.linalg.norm(n)
def decode(fr, L, k, ramp, bark):
    ramp = np.array(ramp, float); bark = np.array(bark, float)
    light2 = np.array([L[0], L[2] - L[1]]); light2 /= np.linalg.norm(light2)
    H, W = fr.shape[:2]; out = np.zeros((H, W, 3), np.uint8); m = np.zeros((H, W), bool)
    for y, x in zip(*np.nonzero(fr[..., 3])):
        r, g, b, a = map(int, fr[y, x])
        if a == 1: out[y, x] = ramp[1]
        elif a == 2: out[y, x] = bark[((r | g << 8) >> (2 * k)) & 3]
        else:
            n = unocta(r, g); d = float(n @ L)
            base = 4 if d > D1 else (3 if d > D2 else 2)
            body, heart, noleaf, code = a & 1, a >> 1 & 1, (a & 3) == 2, a >> 4 & 7
            top, rim = code in (0, 3), code in (2, 3)
            q = 7 if code in (0, 2, 3) else code
            if noleaf: c = base - 1.0
            else:
                t0 = 0 if body else (-1.5 if rim else -1)
                ang = b / 256 * math.tau
                f = (math.cos(ang) * light2[0] + math.sin(ang) * light2[1]) * q / 7
                if top: f = max(f, 0.5)
                s = 1 if f > 0.2 else (0 if f > -0.5 else -1)
                t = t0 + s + (1 if (s == 1 and heart and f > 0.45) else 0)
                if base == 2 and t < t0: t = t0 + 0.75 * (t - t0)
                c = base + t
            if d < DP: c = min(c, 5)
            c = max(0, min(6, c)); lo = int(math.floor(c)); hi = min(lo + 1, 6); f_ = c - lo
            out[y, x] = np.round(ramp[lo] * (1 - f_) + ramp[hi] * f_)
        m[y, x] = True
    return out, m
