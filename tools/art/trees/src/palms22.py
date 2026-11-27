# Round 22: palm crowns for the game (palm22's leaves, lit by the game's sun, in the game's colours).
# A crown = two layers of leaves around the top of the trunk: the upper one (younger leaves, rising a little, lit)
# and the lower one between them (older leaves, drooping, one step darker: in the shade of the upper layer). The
# leaf nearest the viewer always belongs to the lower layer and hangs over the trunk, as in the reference.
import math, random
import numpy as np
import palm22 as P
import render7 as R, render6 as R6

GAME_PALM = ('#6e9a3a', '#78a242', '#679236')        # content/plants/palm/data/trees.yaml tints
REF_FAN = ('#66943d',)                                # the reference's fan leaves: between its M and L
REF_FEATHER = ('#348844',)                            # the reference's fronds: between its 4 and 5
FAN_REF = ['163422', '255434', '336c38', '568a3d', '769f3d', '97ba3a', 'b4cc5a']
FEA_REF = ['0e2922', '1b473e', '266943', '2d7b44', '3b9441', '43a83b', '4ab835']
SUN_R = (0.6, 0.75, -0.1)
SUN_L = (-0.6, 0.75, -0.1)
SUN_F = (0.35, 0.7, 0.6)

# the leaf models fitted to the reference's big palms (fit22.py, sheets 72/73): k scales a crown
FAN = dict(L=31.0, W=10.5, up=(8, -42), lo=(0, -50), q=1.6, arch=0.35, sw=0.72, tipk=0.65, g0=0.08, gk=1.6, Llo=32.0)
FEATHER = dict(L=37.0, W=8.5, up=(35, -70), lo=(25, -80), q=1.3, arch=0.6, sw=0.42, tipk=0.9, teeth=5, tooth_depth=0.6,
               tooth_from=0.55)     # user 14:13 MSK: tips a little less ragged (was 1.0 / 0.5)
FAN_DRAW = dict(ring=2, split='ring', heart=(6, 1), core_plus=0.5, core_inner=4)
FEATHER_DRAW = dict(feather_drop=3.5, feather_exp=1.0, heart=(3, 1), seam=3, feather_base=(0.2, 0.4))


def ramp(tints, season='summer', k=1.3):
    return R.contrast(R6.ramp_for(season, R.species_tint(*tints)), k)


def fan_leaves(k=1.0, n=10, seed=11, jitter=7.0):
    """n leaves: the upper layer evenly round the crown, the lower one between them; a lower leaf in front."""
    rng = random.Random(seed)
    m = (n + 1) // 2
    step = 360.0 / m
    off = 270.0 + step / 2 + rng.uniform(-8, 8)        # an upper leaf half a step off the front: a lower one in front
    out = []
    p = FAN
    for i in range(n):
        if n % 2:      # odd: evenly round from the front, every other one lower (the front one too; the last upper)
            layer = 1 if (i % 2 == 0 and i < n - 1) else 0
            phi = 270.0 + i * 360.0 / n + rng.uniform(-jitter, jitter)
        else:
            layer = i % 2
            phi = off + (i // 2) * step + (step / 2 if layer else 0.0) + rng.uniform(-jitter, jitter)
        front = math.cos(math.radians(phi - 270.0))   # 1 = toward the viewer
        e0, e1 = p['up'] if layer == 0 else p['lo']
        L = (p['L'] if layer == 0 else p['Llo']) * k * rng.uniform(0.94, 1.04)
        W = p['W'] * k * rng.uniform(0.95, 1.03) * (10.0 / n) ** 0.8   # fewer leaves (small palms) are wider:
        if layer == 1 and front > 0.8:                   # the hanging front leaf: narrower, longer      the crown stays closed
            L *= 1.05; W *= 0.85
        elif layer == 1 and front > 0.3:
            L *= 0.92; W *= 0.85
        out.append(P.Leaf(phi % 360, L, W, e0, e1, q=p['q'], arch=p['arch'], layer=layer, kind='fan', sw=p['sw'],
                          tipk=p['tipk'], g0=p['g0'], gk=p['gk']))
    return out


def feather_leaves(k=1.0, n=13, seed=11, jitter=6.0):
    rng = random.Random(seed)
    step = 360.0 / n
    off = 270.0 + rng.uniform(-6, 6)                 # a frond hangs straight toward the viewer
    out = []
    p = FEATHER
    for i in range(n):
        phi = off + i * step + rng.uniform(-jitter, jitter)
        layer = i % 2 if n % 2 == 0 or i < n - 1 else 0
        if i == 0: layer = 1
        back = math.sin(math.radians(phi))              # 1 = away from the viewer
        e0, e1 = p['up'] if layer == 0 else p['lo']
        L = p['L'] * k * rng.uniform(0.93, 1.05) * (0.8 if back > 0.85 else 1.0)
        W = p['W'] * k * rng.uniform(0.93, 1.05)
        out.append(P.Leaf(phi % 360, L, W, e0, e1, q=p['q'], arch=p['arch'], layer=layer, kind='feather',
                          sw=p['sw'], tipk=p['tipk'], teeth=p['teeth'], seed=seed * 31 + i, tooth_depth=p['tooth_depth'],
                          tooth_from=p['tooth_from']))
    return out


def crown_steps(kind, k=1.0, n=None, seed=11, sun=SUN_R, W=None, H=None, leaves=None):
    """(steps, owner, crown) of a palm's crown alone, its centre in the middle of a W x H picture."""
    if leaves is None:
        leaves = fan_leaves(k, n or 10, seed) if kind == 'fan' else feather_leaves(k, n or 13, seed)
    W = W or int(80 * k) + 10
    H = H or int(84 * k) + 10
    cr = P.Crown(leaves, W=W, H=H, ox=W / 2 + 0.5, oy=H * 0.32 + 0.5)
    kw = dict(FAN_DRAW if kind == 'fan' else FEATHER_DRAW)
    if kw.get('heart'): kw['heart'] = (max(2, kw['heart'][0] * k), kw['heart'][1])
    if kind == 'fan': kw['ring'] = max(1, int(round(kw['ring'] * (0.6 + 0.4 * k))))
    st, own = P.draw(cr, Lsun=sun, **kw)
    return st, own, cr
