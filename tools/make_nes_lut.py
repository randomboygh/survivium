#!/usr/bin/env python3
"""Makes assets/nes_lut.png, the colour lookup of the screen effect «8 bit» (src/client/view/crt.gd,
shaders/grade.gdshader `retro_lut`): for each colour of a 32×32×32 grid the nearest colour of the NES
palette (the 2C02's usual RGB, its repeated blacks left out), by the «redmean» distance, which follows
the eye better than plain RGB. The image is 1024×32: x is blue × 32 + red, y is green, each 0..31.

    python3 tools/make_nes_lut.py
"""
import os
from PIL import Image
import hand_art  # noqa: E402  (the pictures made by hand are left as they are)

NES = """
7C7C7C 0000FC 0000BC 4428BC 940084 A80020 A81000 881400 503000 007800 006800 005800 004058 000000
BCBCBC 0078F8 0058F8 6844FC D800CC E40058 F83800 E45C10 AC7C00 00B800 00A800 00A844 008888
F8F8F8 3CBCFC 6888FC 9878F8 F878F8 F85898 F87858 FCA044 F8B800 B8F818 58D854 58F898 00E8D8 787878
FCFCFC A4E4FC B8B8F8 D8B8F8 F8B8F8 F8A4C0 F0D0B0 FCE0A8 F8D878 D8F878 B8F8B8 B8F8D8 00FCFC F8D8F8
"""
N = 32


def palette():
    out = []
    for h in NES.split():
        c = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
        if c not in out:
            out.append(c)
    return out


def nearest(c, pal):
    best, best_d = pal[0], 1e18
    for p in pal:
        rm = (c[0] + p[0]) / 2.0
        dr, dg, db = c[0] - p[0], c[1] - p[1], c[2] - p[2]
        d = (2.0 + rm / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rm) / 256.0) * db * db
        if d < best_d:
            best, best_d = p, d
    return best


def main():
    pal = palette()
    img = Image.new("RGB", (N * N, N))
    px = img.load()
    for b in range(N):
        for g in range(N):
            for r in range(N):
                c = tuple(round(v * 255 / (N - 1)) for v in (r, g, b))
                px[b * N + r, g] = nearest(c, pal)
    path = os.path.join(os.path.dirname(__file__), "..", "assets", "nes_lut.png")
    hand_art.save(img, path)
    print(f"{path}: {len(pal)} colours")


if __name__ == "__main__":
    main()
