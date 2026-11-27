"""Prototype of hand-drawn body frames under our head: rows of letters (box rows 10-17,
the art's INK as the bare look shows it, hand digits 4-9 as in WalkArt), the head taken
from the stand frame of a quick sheet, outlined as Figure does (no soles off the walk).
Used as a module: render(q_dir, dir, rows, drop) -> RGBA 32x32 image."""
from PIL import Image

ORIGIN = (9, 14)
OUTLINE = (0x1e, 0x19, 0x14, 255)
SKIN = {"S": "e8b48a", "s": "c98a62", "k": "a0603e"}
BARE = {  # the bare look: what each letter shows with only the loincloth worn
    "S": "S", "s": "s", "k": "k", "C": "S", "L": "S", "c": "s", "V": "k",
    "T": "S", "t": "s", "B": "s", "b": "k", "K": "S", "m": "k",
    "4": "S", "5": "s", "6": "k", "7": "S", "8": "s", "9": "k",
}
CLOTH = {"U": "c9a66e", "u": "9c7c4c", "N": "c9a66e", "n": "9c7c4c", "E": "1f1a14"}
DIRS = ["s", "se", "e", "ne", "n", "sw", "w", "nw"]


def rgba(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def render(q, d, rows, drop=0, first=10, head_col=0, head_up=0):
    sheet = Image.open(f"{q}/bare.png").convert("RGBA")
    r = DIRS.index(d)
    stand = sheet.crop((head_col * 32, r * 32, head_col * 32 + 32, r * 32 + 32))
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    # The body rows first.
    for i, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            if ch in CLOTH:
                col = rgba(CLOTH[ch])
            else:
                col = rgba(SKIN[BARE[ch]])
            out.putpixel((ORIGIN[0] + x, ORIGIN[1] + first + i), col)
    # The head over them: the stand's pixels above the neck, without their outline.
    for y in range(0, ORIGIN[1] + 11 + drop + head_up):
        for x in range(32):
            p = stand.getpixel((x, y))
            if p[3] and p != OUTLINE:
                out.putpixel((x, y - head_up), p)
    return outline(out)


def outline(img):
    w, h = img.size
    res = img.copy()
    for y in range(h):
        for x in range(w):
            if img.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x - dx, y - dy
                if 0 <= nx < w and 0 <= ny < h and img.getpixel((nx, ny))[3]:
                    res.putpixel((x, y), OUTLINE)
                    break
    return res
