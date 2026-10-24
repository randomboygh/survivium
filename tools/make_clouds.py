"""Draws assets/menu_clouds.png, the cumulus clouds drifting over the main menu's
painted sky (MainMenu.CLOUDS): a row of CLOUDS cells CELL_W x CELL_H, a cloud in each,
sitting on the bottom of its cell. Each is a heap of round puffs on a flat base, lit
from the upper left and shaded in a few hard tones with a checker between them, so
it reads as a pixel picture with volume. Needs Pillow; run from the project folder:

    python3 tools/make_clouds.py

The picture can be painted over by hand afterwards.
"""

import math
import random

from PIL import Image

OUT = "assets/menu_clouds.png"
CELL_W = 160
CELL_H = 80
# Width of each cloud in its cell, and the seed of its puffs.
CLOUDS = [(150, 3), (120, 11), (96, 7), (70, 5), (132, 21), (54, 2)]
# Light from the upper left and a little in front.
LIGHT = (-0.4, -0.8, 0.45)
# Tones from the lit top to the underside: warm light, the body, the grey shade
# and the deep shade along the base.
TONES = [(0xFF, 0xF7, 0xE6), (0xF0, 0xE2, 0xC6), (0xC8, 0xC0, 0xB0), (0x96, 0x98, 0x98),
	(0x6C, 0x76, 0x7E)]
# How much of the light comes from each puff's own roundness, the rest from the heap's.
PUFF = 0.55
# Where the light (from 1 down to -1) turns from one tone to the next.
STEPS = [0.62, 0.32, -0.02, -0.4]
# The checker either side of each step.
DITHER = 0.04


def puffs(w: int, seed: int) -> list:
	"""Round puffs (x, y, r) heaped on a flat base: a row of small ones along the
	bottom, bigger ones over the middle and one or two on top, the heap as high as
	about half its width."""
	rng = random.Random(seed)
	base = CELL_H - 4
	high = min(0.5 * w, CELL_H - 8)
	out = []
	n = max(3, round(w / 22))
	for i in range(n):
		u = (i + 0.5) / n
		x = 6 + (w - 12) * u + rng.uniform(-4, 4)
		r = high * rng.uniform(0.2, 0.34) * (0.7 + 0.3 * math.sin(math.pi * u))
		out.append((x, base - r * rng.uniform(0.3, 0.55), r))
	m = max(2, round(w / 34))
	for i in range(m):
		u = (i + 0.5) / m
		x = w * (0.2 + 0.6 * u) + rng.uniform(-4, 4)
		r = high * rng.uniform(0.3, 0.38) * (0.8 + 0.2 * math.sin(math.pi * u))
		out.append((x, base - high * 0.42, r))
	for i in range(1 if w < 90 else 2):
		x = w * (0.42 + 0.2 * i + rng.uniform(-0.06, 0.06))
		r = high * rng.uniform(0.26, 0.32) * (1.0 - 0.25 * i)
		out.append((x, base - high + r + rng.uniform(0, 2) + 2 * i * r * 0.3, r))
	return out


def draw(w: int, seed: int) -> Image.Image:
	img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
	px = img.load()
	ox = (CELL_W - w) // 2
	ps = puffs(w, seed)
	base = CELL_H - 4
	top = min(y - r for x, y, r in ps)
	lx, ly, lz = LIGHT
	ll = math.sqrt(lx * lx + ly * ly + lz * lz)
	tone = {}
	which = {}
	for y in range(CELL_H):
		for x in range(w):
			best = None
			for k, (cx, cy, r) in enumerate(ps):
				dx = x + 0.5 - cx
				dy = y + 0.5 - cy
				d2 = dx * dx + dy * dy
				if d2 >= r * r:
					continue
				# The lower a puff the nearer the eye: it covers the ones over it.
				z = math.sqrt(r * r - d2) + 0.8 * cy
				if best is None or z > best[0]:
					best = (z, k, dx / r, dy / r, math.sqrt(max(0.0, 1.0 - d2 / (r * r))))
			if best is None or y > base:
				continue
			z, k, nx, ny, nz = best
			# Each puff's own roundness, half and half with the heap's as a whole (a
			# half dome on the base), so the light runs across the cloud.
			gx = (x + 0.5 - w * 0.5) / (w * 0.5)
			gy = (y + 0.5 - base) / max(1.0, base - top)
			gz = math.sqrt(max(0.0, 1.0 - gx * gx - gy * gy))
			s = (PUFF * (nx * lx + ny * ly + nz * lz) + (1.0 - PUFF) * (gx * lx + gy * ly + gz * lz)) / ll
			# Darker toward the base, as a cloud's underside is.
			s -= 0.7 * max(0.0, (y - top) / max(1.0, base - top) - 0.45)
			t = 0
			for i, step in enumerate(STEPS):
				if s < step - DITHER or (s < step + DITHER and (x + y) % 2 == 0):
					t = i + 1
			tone[x, y] = t
			which[x, y] = k
	for (x, y), t in tone.items():
		k = which[x, y]
		# A crevice a tone darker along the rim of the puff in front, on the one behind.
		for a, b in ((0, 1), (0, 2), (1, 1)):
			o = which.get((x + a, y + b))
			if o is not None and o != k and ps[o][1] > ps[k][1]:
				t = min(len(TONES) - 1, t + 1)
				break
		# The shaded edge against the sky below the middle, and the flat base.
		if y > (top + base) * 0.5 and any((x + a, y + b) not in tone for a, b in ((1, 0), (-1, 0), (0, 1))):
			t = min(len(TONES) - 1, t + 1)
		if y == base:
			t = len(TONES) - 1
		px[ox + x, y] = TONES[t] + (255,)
	return img


def main() -> None:
	sheet = Image.new("RGBA", (CELL_W * len(CLOUDS), CELL_H), (0, 0, 0, 0))
	for i, (w, seed) in enumerate(CLOUDS):
		sheet.alpha_composite(draw(w, seed), (i * CELL_W, 0))
	sheet.save(OUT)
	print("saved %s, %dx%d" % (OUT, sheet.width, sheet.height))


if __name__ == "__main__":
	main()
