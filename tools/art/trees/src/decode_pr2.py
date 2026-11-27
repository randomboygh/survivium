# The game shader's conifer rule in numpy (tree.gdshader `fronds`): a G-buffer frame of export_pr2 + sun -> RGB,
# for checking the export against the mockup pixel for pixel (chk_pr2.py).
import math, numpy as np
from decode_pr1 import unocta

BANDS = ((0.8, 5), (0.5, 4), (0.2, 3), (-0.15, 2))


def band(d):
    for lim, b in BANDS:
        if d > lim: return b
    return 1


def frond_step(r, g, b, a, L):
    n = unocta(r, g); d = float(n @ L)
    bb = band(d) - (1 if a & 64 else 0)
    ang = b / 256 * math.tau
    el = math.cos(ang) * L[0] + math.sin(ang) * L[2]
    pos = bool(a & 1)
    lit = (pos if el > 0 else not pos) if abs(el) > 0.12 else True
    t = (bb if lit else bb - 1) - (1 if a & 2 else 0) - (1 if a & 16 else 0)
    if a & 32 and lit and bb >= 4: t += 1
    t = min(t, 5 if d < 0.92 else 6)
    return max(0, min(6, t))


def decode(fr, L, k, ramp, bark):
    ramp = np.array(ramp, float); bark = np.array(bark, float)
    H, W = fr.shape[:2]; out = np.zeros((H, W, 3), np.uint8); m = np.zeros((H, W), bool)
    for y, x in zip(*np.nonzero(fr[..., 3])):
        r, g, b, a = map(int, fr[y, x])
        if a == 1: out[y, x] = ramp[1]
        elif a == 2: out[y, x] = bark[((r | g << 8) >> (2 * k)) & 3]
        else: out[y, x] = ramp[frond_step(r, g, b, a, L)]
        m[y, x] = True
    return out, m


def decode_bare(bare, k, bark):
    bark = np.array(bark, float)
    H, W = bare.shape; out = np.zeros((H, W, 3), np.uint8)
    m = bare > 0
    st = (bare >> (2 * k)) & 3
    out[m] = bark[st[m]]
    return out, m
