"""Prototype of a work"s frames drawn whole with the tool held: body rows (box rows from
`top`, letters of PlayerArt.INK as the bare look shows them, hand digits 4-9), the head of
a quick sheet"s stand moved down by `bob` less the stand"s drop, the tool (ToolArt"s
shape) at hand `r` pointing `a` (ccw mirrors it), behind the body or in front (`f`), the
front hand"s digits over it; outlined as Figure does.
render(q_dir, dir, frame) -> RGBA 32x32."""
from PIL import Image
import proto

ORIGIN = (9, 14)
DROP = {"s": 0, "se": 1, "e": 1, "ne": 1, "n": 1}
TOWARD = 8
TINK = {"d": "5a3b22", "w": "84593a", "W": "a77850", "g": "5a3b22", "s": "e2dfc8", "k": "3e2a1c", "K": "1e1914", "x": "2e3136", "n": "c97b43", "o": "8c4a26",
        "m": "9a7646", "p": "c39c64", "P": "e2c48c",
        "q": "5a5e66", "a": "8a8f97", "A": "c3c8cc", "r": "c8ad78", "R": "8e7650"}
SHAPES = {
    "shovel": {
        "up": [".pPp.", "mpPPp", "mppPp", "mpppp", "mmmmm", "..w..", "..W..", "..w..", "..w..", "..W..", "..w..", "..d..", "..g.."],
        "diagonal": ["......pPp.", ".....mpPPp", "......mpPp", "......wmpp", ".....W..m.", "....w.....", "...w......", "..W.......", ".d........", "g........."],
        "toward": [".g..", ".w..", ".W..", ".w..", "mppP", "mpPP", ".mp."],
    },
    "sword": {
        "up": [".P.", ".Pp", ".Pp", ".Pp", ".Pp", ".Pp", "ddd", ".w.", ".g."],
        "diagonal": ["......P", ".....Pp", "....Pp.", ".d.Pp..", "..d....", ".w.d...", "g......"],
        "toward": [".g.", "ddd", ".P.", ".p."],
    },
    "knife": {
        "up": [".A.", ".Aa", ".Aa", "ddd", ".w.", ".g."],
        "diagonal": ["....A", "...Aa", ".dAa.", "..d..", ".w...", "g...."],
        "toward": [".g.", "ddd", ".a."],
    },
    "spear": {
        "up": [".A.", "Aa.", ".w.", ".w.", ".W.", ".w.", ".g.", ".w.", ".W."],
        "diagonal": [".......A", "......Aa", ".....w..", "....W...", "...w....", "..g.....", ".w......", "W......."],
        "toward": [".g.", ".w.", ".a."],
    },
    "rod": {
        "up": [".Wr", ".wr", ".wr", ".w.", ".w.", ".w.", ".W.", ".g."],
        "diagonal": ["......Wr", ".....w.r", "....w..r", "...w....", "..W.....", ".w......", "g......."],
        "toward": [".g.", ".w.", ".W."],
    },
    "axe": {
        "up": [".d...", "rqaA.", "rqaaA", "rqaA.", ".w...", ".w...", ".W...", ".d...", ".g..."],
        "diagonal": ["......d", ".....r.", "....rqa", "...W.aA", "..w..A.", ".d.....", "g......"],
        "toward": [".g.", ".w.", ".W.", "qaA", "qaA", ".A."],
    },
}


def _pixels(rows, ccw, turns, diagonal, slide=0, toward=False):
    grip = (0, 0)
    for y, r in enumerate(rows):
        if "g" in r:
            grip = (r.index("g"), y)
    out = {}
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == ".":
                continue
            p = (x - grip[0], y - grip[1])
            # Held `slide` pixels up the shaft: the head comes nearer the hand.
            if slide:
                if toward:
                    p = (p[0], p[1] - slide)
                elif diagonal:
                    p = (p[0] - slide, p[1] + slide)
                else:
                    p = (p[0], p[1] + slide)
            if ccw:
                p = (-p[1], -p[0]) if diagonal else (-p[0], p[1])
            for _ in range(turns):
                p = (-p[1], p[0])
            out[p] = c
    return out


LOW, LOW_LEFT = 9, 10


def _low(rows, ccw, left, slide=0):
    """The thing pointing right (or left) and down about 30 degrees: the up shape laid
    along a line two pixels across for each one down, its edge below."""
    grip = (0, 0)
    for y, r in enumerate(rows):
        if "g" in r:
            grip = (r.index("g"), y)
    reach = max(abs(y - grip[1]) for y, r in enumerate(rows) if r.replace(".", ""))
    slide = max(0, min(slide, max(0, reach - 3)))
    out = {}
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == ".":
                continue
            w = x - grip[0]
            n = grip[1] - y - slide
            if ccw:
                w = -w
            drop = 0 if n == 0 else (1 if n > 0 else -1) * ((abs(n) - 1) // 2)
            p = (n, drop + w)
            if left:
                p = (-p[0], p[1])
            out[p] = c
    return out


def turned(shape, a, ccw, slide=0):
    if a in (LOW, LOW_LEFT):
        return _low(shape["up"], ccw, a == LOW_LEFT, slide)
    if a == TOWARD:
        return _pixels(shape["toward"], ccw, 0, False, slide, True)
    return _pixels(shape["up"] if a % 2 == 0 else shape["diagonal"], ccw, a // 2, a % 2 == 1, slide)


def rgba(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


FRONT_HANDS = "456"  # the working hand"s digits; the other hand"s (789) go with the body


def parts(q, d, fr, tool=None, head_col=0, letters=False):
    """The frame's layers before the outline: (body, thing, fists), each {image pixel: colour}
    (with `letters`, the thing's values are its letters)."""
    tool = tool or fr.get("tool", "axe")
    sheet = Image.open(f"{q}/bare.png").convert("RGBA")
    row = proto.DIRS.index(d)
    stand = sheet.crop((head_col * 32, row * 32, head_col * 32 + 32, row * 32 + 32))
    drop = DROP[d]
    shift = fr.get("bob", drop) - drop
    top = fr.get("top", 10)
    body, fists = {}, {}
    for i, r in enumerate(fr["rows"]):
        for x, ch in enumerate(r):
            if ch == ".":
                continue
            col = rgba(proto.CLOTH[ch]) if ch in proto.CLOTH else rgba(proto.SKIN[proto.BARE[ch]])
            at = (ORIGIN[0] + x, ORIGIN[1] + top + i)
            front_hand = (ch in "456" and fr.get("f", True)) or (ch in "789" and fr.get("of", d in ("s", "se")))
            (fists if front_hand else body)[at] = col
    # The head: the stand"s pixels above the neck, without the outline, moved by the bob.
    for y in range(0, ORIGIN[1] + 11 + drop):
        for x in range(32):
            p = stand.getpixel((x, y))
            if p[3] and p != proto.OUTLINE:
                body[(x, y + shift)] = p
    thing = {}
    if "a" in fr and fr["a"] is not None:
        gx, gy = ORIGIN[0] + fr["r"][0], ORIGIN[1] + fr["r"][1]
        # A thing drawn for the frame (a bow drawn, its arrow): {offset from the grip: letter}.
        drawn = fr["draw"] if "draw" in fr else turned(SHAPES[tool], fr["a"], fr.get("ccw", False), fr.get("slide", 0))
        for p, c in drawn.items():
            x, y = gx + p[0], gy + p[1]
            if 1 <= x <= 30 and 1 <= y <= 30:
                thing[(x, y)] = c if letters else rgba(TINK[c])
    return body, thing, fists


def render(q, d, fr, tool=None, head_col=0):
    body, thing, fists = parts(q, d, fr, tool, head_col)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    layers = ([thing, body] if not fr.get("f", True) else [body, thing]) + [fists]
    # A smear (the blade's trail): drawn with the thing, outlined ("outlined"), or over
    # the outlined figure ("free", the default), or not at all ("none").
    mode = __import__("os").environ.get("SMEAR", "free")
    trail = smear_pixels(fr)
    if trail and mode == "outlined":
        layers.insert(len(layers) - 1, trail)
    for layer in layers:
        for at, c in layer.items():
            if 0 <= at[0] < 32 and 0 <= at[1] < 32:
                out.putpixel(at, c)
    out = proto.outline(out)
    if trail and mode == "free":
        # Over the outlined figure, or behind it (only where the frame is still empty) when
        # the thing swung is behind the body (seen from behind).
        behind = not fr.get("f", True)
        for at, c in trail.items():
            if 1 <= at[0] < 31 and 1 <= at[1] < 31:
                if behind and out.getpixel(at)[3] > 0:
                    continue
                out.alpha_composite(Image.new("RGBA", (1, 1), c), at)
    return out


SMEAR_INK = {"o": (247, 241, 230, 255), "+": (226, 216, 198, 255), "-": (201, 189, 169, 255),
             "O": (247, 241, 230, 170), "*": (226, 216, 198, 130), "~": (226, 216, 198, 80)}


def smear_pixels(fr):
    """fr["smear"]: {"at": [x, y] image pixel of the rows' corner, "rows": [...]}, letters of
    SMEAR_INK, "." nothing."""
    sm = fr.get("smear")
    if not sm:
        return {}
    out = {}
    for j, r in enumerate(sm["rows"]):
        for i, ch in enumerate(r):
            if ch in SMEAR_INK:
                out[(sm["at"][0] + i, sm["at"][1] + j)] = SMEAR_INK[ch]
    return out
