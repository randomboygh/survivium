# Round 24 (pieces): the stumps, logs, fallen trunks and broken trunks of round 23 standing / lying in the world, seen
# from the camera's turns (n x 45 deg, or any angle). The pieces are drawn in the approved "oval" view (screen
# X = x, Y = 0.6 z - y): a turn turns the piece about the vertical before that projection (variant A of round 24, the
# approved depth: p' = S Rot S^-1 p with S = diag(1, 1, 0.6)); the sun turns with the view (lit sides and shadows stay
# put on the screen).
import math, numpy as np
import logs23 as LG


def rot_y(P, deg):
    """Points (... x 3) turned by the camera's turn deg (turn24.maps: x' = c x - s z, z' = s x + c z)."""
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    P = np.array(P, float)
    x, z = P[..., 0].copy(), P[..., 2].copy()
    P[..., 0] = c * x - s * z; P[..., 2] = s * x + c * z
    return P


def turn_scene(sc, deg):
    """Every tube of a logs23.Scene turned about the vertical through the scene's origin."""
    if not deg: return sc
    for tb in sc.tubes:
        tb.P = rot_y(tb.P, deg)
        if tb.cut0 is not None: tb.cut0 = rot_y(tb.cut0, deg)
        if tb.cut1 is not None: tb.cut1 = rot_y(tb.cut1, deg)
    return sc


def piece(kind, key, s=0.68, deg=0.0, snow=False):
    """A log ('log') or fallen trunk ('fallen') at a view angle: keyed picture with the wood outline."""
    import outline23 as OL
    cls = LG.Log if kind == 'log' else LG.Fallen
    p = cls(key, s)
    turn_scene(p.sc, deg)
    img = p.picture(snow=LG.SNOW_T if snow else None).copy()
    OL.outline(img, key)
    return img
