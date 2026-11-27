"""Flight frames from parts: a body and wings, each outlined on its own, the wing over the body."""
from eng import *
def lay(parts, w, h, k='K'):
    """parts: (fill rows, x, y) placed on a w x h canvas (coordinates of the fills), each outlined then stacked."""
    c = blank(w + 2, h + 2)
    for rows, x, y in parts:
        c = put(c, outline(rows, k), x, y)
    return c
def side_flight(body, bx, by, wings, w, h, k='K'):
    """wings: list of (rows, x, y) per frame, or None for no wing; returns frames on one canvas."""
    return [lay([(body, bx, by)] + ([wg] if wg else []), w, h, k) for wg in wings]
def front_flight(body, bx, by, halves, w, h, k='K'):
    """halves: per frame (left wing rows, x, y); the right wing is its mirror about the body's middle."""
    mid = bx + len(body[0]) // 2  # middle column of the fills (odd body width)
    out = []
    for (wr, x, y) in halves:
        ww = len(wr[0])
        rx = 2 * mid - (x + ww - 1)
        out.append(lay([(body, bx, by), (wr, x, y), (flip(wr), rx, y)], w, h, k))
    return out
def merged(parts, w, h, k='K'):
    """parts' fills stacked (later over earlier), then one outline round the whole: no line between wing and body."""
    c = blank(w, h)
    for rows, x, y in parts:
        c = put(c, rows, x, y)
    return outline(c, k)
def side_flight(body, bx, by, wings, w, h, k='K'):
    return [merged([(body, bx, by)] + ([wg] if wg else []), w, h, k) for wg in wings]
def front_flight(body, bx, by, halves, w, h, k='K'):
    mid = bx + len(body[0]) // 2
    out = []
    for (wr, x, y) in halves:
        ww = len(wr[0]); rx = 2 * mid - (x + ww - 1)
        out.append(merged([(wr, x, y), (flip(wr), rx, y), (body, bx, by)], w, h, k))
    return out
