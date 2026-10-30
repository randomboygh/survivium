"""Draws the game's icon, 32 x 32 pixels, in the style of chunky pixel icons: a dark
outline round every part, three or four hard tones lit from the upper left. Needs
Pillow; run from the project folder:

    python3 tools/make_icon.py

writes icon.png (the project's icon: the browser tab's icon, which the engine also sets
when it starts, and the apps'), assets/web/apple-touch-icon.png (a phone's home screen)
and assets/web/og.png (the picture a messenger shows under a link; the page's og: tags
are in export_presets.cfg, html/head_include). CI copies assets/web/ next to index.html.

    python3 tools/make_icon.py --variants <dir>

draws every variant offered for the icon and preview.png, each large and at the sizes a
tab and a home screen show it. The pictures can be painted over by hand.
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

N = 32
FONT = "assets/fonts/PressStart2P.ttf"
# Files the web export does not make itself, put next to index.html by CI.
WEB = "assets/web"
TOUCH = 180
CARD_W, CARD_H = 1200, 630
CARD_PX = 4
NAME = "SURVIVIUM"
TAGLINE = ["Неспешное выживание", "в пиксельном мире"]
EDGE = (0x1A, 0x10, 0x14)

# Colours by name, a few tones of each from light to dark.
FIRE = [(0xFF, 0xF4, 0xC2), (0xFF, 0xD8, 0x4A), (0xFF, 0x9A, 0x2B), (0xE2, 0x4E, 0x1E), (0x9E, 0x24, 0x1C)]
WOOD = [(0xC8, 0x8A, 0x52), (0x9A, 0x5E, 0x34), (0x6E, 0x3E, 0x24), (0x4A, 0x28, 0x18)]
RING = [(0xE8, 0xC4, 0x8A), (0xC8, 0x96, 0x5A)]
STONE = [(0xB4, 0xB0, 0xA8), (0x86, 0x82, 0x80), (0x5E, 0x5A, 0x60)]
GRASS = [(0xB6, 0xE0, 0x5A), (0x6C, 0xB8, 0x3C), (0x3E, 0x86, 0x34), (0x26, 0x5A, 0x2C)]
PINE = [(0x5C, 0xB0, 0x5A), (0x2E, 0x84, 0x4A), (0x1C, 0x5A, 0x3C), (0x12, 0x3C, 0x2E)]
DIRT = [(0xA8, 0x74, 0x48), (0x84, 0x56, 0x34), (0x62, 0x3E, 0x28)]
NIGHT = [(0x3C, 0x5C, 0x8E), (0x2C, 0x44, 0x72), (0x22, 0x34, 0x5A), (0x1A, 0x26, 0x44)]
DUSK = [(0xFF, 0xD6, 0x8A), (0xF6, 0xA8, 0x6A), (0xD8, 0x7A, 0x6A), (0x8E, 0x5A, 0x7A), (0x4E, 0x3E, 0x6A)]
MOON = [(0xFF, 0xFA, 0xE0), (0xF2, 0xE2, 0xA8)]
BIRD = [(0xD8, 0xA0, 0x68), (0xA8, 0x6C, 0x40), (0x74, 0x46, 0x2C)]
CREAM = [(0xF4, 0xE8, 0xD0), (0xD8, 0xC8, 0xAC)]


class Canvas:
	def __init__(self, w: int = N, h: int = N) -> None:
		self.w, self.h = w, h
		self.px = [[None] * w for _ in range(h)]

	def put(self, x: int, y: int, c) -> None:
		if 0 <= x < self.w and 0 <= y < self.h:
			self.px[y][x] = c

	def get(self, x: int, y: int):
		if 0 <= x < self.w and 0 <= y < self.h:
			return self.px[y][x]
		return None

	def fill(self, inside, shade) -> None:
		"""Paints every pixel whose centre `inside(x, y)` holds with `shade(x, y)`."""
		for y in range(self.h):
			for x in range(self.w):
				if inside(x + 0.5, y + 0.5):
					self.put(x, y, shade(x + 0.5, y + 0.5))

	def outline(self, colour=EDGE) -> None:
		"""A dark pixel round the shape on its four sides, as the world's cells have."""
		add = []
		for y in range(self.h):
			for x in range(self.w):
				if self.px[y][x] is None and any(
					self.get(x + dx, y + dy) not in (None, colour)
					for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
				):
					add.append((x, y))
		for x, y in add:
			self.px[y][x] = colour

	def part(self, draw, edge=True) -> None:
		"""Draws a part of the picture on its own, outlines it and lays it over what is
		drawn, so parts are parted by the outline as in a hand-drawn icon."""
		layer = Canvas(self.w, self.h)
		draw(layer)
		if edge:
			layer.outline()
		for y in range(self.h):
			for x in range(self.w):
				if layer.px[y][x] is not None:
					self.px[y][x] = layer.px[y][x]

	def image(self) -> Image.Image:
		img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
		for y in range(self.h):
			for x in range(self.w):
				c = self.px[y][x]
				if c is not None:
					img.putpixel((x, y), c + (255,) if len(c) == 3 else c)
		return img


def tone(tones: list, light: float, steps: list):
	"""The tone for `light` (1 lit .. -1 shaded): steps are where one tone turns into
	the next, from the lit end."""
	for i, s in enumerate(steps):
		if light > s:
			return tones[i]
	return tones[len(steps)]


def ellipse(cx, cy, rx, ry):
	return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def ball_light(cx, cy, rx, ry, lx=-0.6, ly=-0.7):
	"""Light on a round thing from the upper left: 1 at the lit side, -1 at the dark."""
	def f(x, y):
		u, v = (x - cx) / rx, (y - cy) / ry
		return -(u * lx + v * ly) / math.sqrt(lx * lx + ly * ly) - 0.25 * (u * u + v * v)
	return f


def flame_inside(cx, base, w, h, lean=1.5):
	"""A tongue of fire: round at the base, widest a third of the way up, then narrowing
	in a curve to a point that leans a little."""
	def f(x, y):
		t = (base - y) / h
		if t < 0 or t > 1:
			return False
		if t < 0.3:
			half = w * math.sqrt(max(0.0, 1 - ((0.3 - t) / 0.32) ** 2))
		else:
			half = w * ((1 - t) / 0.7) ** 1.4
		return abs(x - cx - lean * t * t) <= half
	return f


def log(c: Canvas, x0, y0, x1, y1, r) -> None:
	"""A log lying from (x0, y0) to (x1, y1), r thick, lit on top, its far end a cut ring."""
	dx, dy = x1 - x0, y1 - y0
	ln = math.hypot(dx, dy)
	ux, uy = dx / ln, dy / ln

	def inside(x, y):
		t = (x - x0) * ux + (y - y0) * uy
		d = (x - x0) * -uy + (y - y0) * ux
		return 0 <= t <= ln and abs(d) <= r

	def shade(x, y):
		d = (x - x0) * -uy + (y - y0) * ux
		s = d / r if ux > 0 else -d / r
		return tone(WOOD, -s, [0.45, -0.1, -0.6])

	c.fill(inside, shade)
	c.fill(ellipse(x1, y1, r * 0.75, r), lambda x, y: tone(RING, ball_light(x1, y1, r, r)(x, y), [0.1]))


def stone(c: Canvas, sx, sy, rx, ry) -> None:
	c.fill(ellipse(sx, sy, rx, ry), lambda x, y: tone(STONE, ball_light(sx, sy, rx, ry)(x, y), [0.3, -0.3]))


def fire(c: Canvas, cx, base, w, h, lean=1.5) -> None:
	"""A flame in four tones, the right side in the shade, the white heart low."""
	c.fill(flame_inside(cx, base, w, h, lean), lambda x, y: FIRE[3] if x > cx + w * 0.45 + lean * ((base - y) / h) ** 2 else FIRE[2])
	c.fill(flame_inside(cx - 0.4, base, w * 0.62, h * 0.68, lean * 0.7), lambda x, y: FIRE[1])
	c.fill(flame_inside(cx - 0.6, base, w * 0.3, h * 0.36, lean * 0.4), lambda x, y: FIRE[0])


def campfire() -> Canvas:
	"""A campfire: two crossed logs, a tall flame and two small ones, sparks, stones in
	front."""
	c = Canvas()
	c.part(lambda l: fire(l, 8.5, 24, 3.8, 13, -1.5))
	c.part(lambda l: fire(l, 23.5, 24, 3.8, 14, 1.5))
	c.part(lambda l: fire(l, 16, 25.5, 8.5, 23.5))
	c.part(lambda l: log(l, 22, 23.5, 5, 29, 2.0))
	c.part(lambda l: log(l, 10, 23.5, 27, 29, 2.0))
	for sx, sy in ((9, 6), (24, 4), (27, 9), (6, 10)):
		c.part(lambda l, sx=sx, sy=sy: l.put(sx, sy, FIRE[1]), edge=False)
	return c


def spruce(c: Canvas, cx, top, h, w) -> None:
	"""A spruce: three tiers of needles, lit from the left, on a short trunk."""
	c.fill(lambda x, y: abs(x - cx) <= 1.2 and top + h * 0.8 <= y <= top + h + 2.5,
		lambda x, y: WOOD[1] if x < cx else WOOD[2])
	for i in range(3):
		t0 = top + i * h * 0.26
		th = h * 0.42
		half = w * (0.5 + 0.25 * i)

		def inside(x, y, t0=t0, th=th, half=half):
			t = (y - t0) / th
			return 0 <= t <= 1 and abs(x - cx) <= half * t + 0.5

		def shade(x, y, t0=t0, th=th, half=half):
			t = (y - t0) / th
			u = (x - cx) / max(0.8, half * t + 0.5)
			light = -u * 0.9 - (t - 0.5) * 0.8
			return tone(PINE, light, [0.55, -0.05, -0.55])

		c.fill(inside, shade)


def world_block() -> Canvas:
	"""A cell of the world as the game shows it, from above and in front: a grassy top
	with a spruce and a small fire on it, the earth and a stone in its front face."""
	c = Canvas()
	x0, x1 = 2, 29
	top0, top1 = 14, 22
	bottom = 29

	def block(l):
		def top_shade(x, y):
			if y < top0 + 1.2 or x < x0 + 1.2:
				return GRASS[0]
			return GRASS[0] if (int(x) * 3 + int(y) * 5) % 11 == 0 else GRASS[1]

		l.fill(lambda x, y: x0 <= x <= x1 and top0 <= y <= top1, top_shade)

		def front(x, y):
			d = y - top1
			if d < 1.2:
				return GRASS[2]
			if d < 2.2 + (1.0 if (int(x) * 5) % 4 == 1 else 0):
				return GRASS[3]
			if x < x0 + 1.2:
				return DIRT[0]
			if (int(x) * 7 + int(y) * 3) % 9 == 0:
				return DIRT[2]
			return DIRT[1]

		l.fill(lambda x, y: x0 <= x <= x1 and top1 < y <= bottom, front)

	c.part(block)
	c.part(lambda l: stone(l, 9, 26.5, 2.4, 1.6))
	c.part(lambda l: stone(l, 23, 27, 1.6, 1.1))
	c.part(lambda l: spruce(l, 9, 1, 16, 7))
	c.part(lambda l: log(l, 17, 20.5, 25, 18.5, 1.1))
	c.part(lambda l: fire(l, 21, 19.5, 3.3, 9))
	c.part(lambda l: l.put(25, 8, FIRE[1]), edge=False)
	return c


def disc(c: Canvas, cx, cy, r, shade) -> None:
	c.fill(lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r, shade)


def badge(c: Canvas, tones: list) -> None:
	"""The round badge: a sky in bands from the top down."""
	disc(c, 16, 16, 14.5, lambda x, y: tones[min(len(tones) - 1, int((y - 1.5) / 29 * len(tones)))])


def sparrow() -> Canvas:
	"""The sparrow of the animals mod, large, on a branch, the setting sun behind, in a round
	badge."""
	c = Canvas()
	inside = lambda x, y: (x - 16) ** 2 + (y - 16) ** 2 <= 14.5 ** 2

	def sky(l):
		badge(l, [DUSK[4], DUSK[3], DUSK[2], DUSK[1], DUSK[0]])
		l.fill(lambda x, y: (x - 9) ** 2 + (y - 10) ** 2 <= 19, lambda x, y: MOON[0] if (x - 8) ** 2 + (y - 9) ** 2 < 8 else MOON[1])

	c.part(sky)
	c.part(lambda l: l.fill(lambda x, y: inside(x, y) and abs(y - (24.5 - 0.12 * (x - 16))) <= 1.1,
		lambda x, y: WOOD[1] if y < 24.2 - 0.12 * (x - 16) else WOOD[2]))
	for lx, ly in ((4, 22), (5, 21), (6, 22), (27, 21), (28, 22)):
		c.part(lambda l, lx=lx, ly=ly: l.put(lx, ly, GRASS[1]), edge=False)

	def tail(l):
		# Down and back to the left, as the sprite's.
		l.fill(lambda x, y: 2.5 <= x <= 11 and abs(y - (17 + 0.45 * (11 - x))) <= 1.2 + 0.1 * (11 - x),
			lambda x, y: BIRD[2] if y > 17 + 0.45 * (11 - x) else BIRD[1])

	c.part(tail)

	def bird(l):
		l.fill(ellipse(14.5, 17.5, 6.6, 4.6), lambda x, y: tone(BIRD, ball_light(14.5, 17.5, 6.6, 4.6)(x, y), [0.4, -0.25]))
		l.fill(lambda x, y: ellipse(15.5, 19, 5.4, 3.2)(x, y) and y > 18.2, lambda x, y: CREAM[0] if x > 13 else CREAM[1])
		head = ellipse(20.5, 12.5, 4.0, 3.7)
		l.fill(head, lambda x, y: tone(BIRD, ball_light(20.5, 12.5, 4, 3.7)(x, y), [0.3, -0.4]))
		# The grey crown, the white cheek, the black bib under the beak.
		l.fill(lambda x, y: head(x, y) and y < 11 and x > 18, lambda x, y: STONE[0] if y < 10 and x < 22 else STONE[1])
		l.fill(ellipse(21, 14.2, 1.8, 1.1), lambda x, y: CREAM[0])
		for bx, by in ((23, 14), (23, 15), (22, 16), (23, 16), (21, 16)):
			l.put(bx, by, EDGE)
		# The eye with a glint.
		l.put(22, 11, EDGE)
		l.put(22, 12, EDGE)
		l.put(23, 12, EDGE)
		l.put(23, 11, CREAM[0])
		# Streaked wing over the back and its white bar.
		for wx, wy in ((10, 15), (11, 14), (12, 15), (13, 14), (14, 15), (15, 14), (16, 15),
				(11, 16), (13, 16), (15, 16), (17, 16)):
			l.put(wx, wy, BIRD[2])
		for wx in range(10, 17):
			l.put(wx, 17, CREAM[0] if wx % 2 else BIRD[2])

	c.part(bird)
	beak = (0xE9, 0xB4, 0x4C)
	c.part(lambda l: (l.put(25, 12, beak), l.put(26, 13, beak), l.put(25, 13, (0xB0, 0x7A, 0x2A))))
	for fx in (13, 17):
		c.part(lambda l, fx=fx: (l.put(fx, 22, (0x6A, 0x50, 0x40)), l.put(fx + 1, 23, (0x6A, 0x50, 0x40))), edge=False)
	return c


def night_camp() -> Canvas:
	"""A round badge: a night under the moon, spruces on a hill and a campfire lit on it."""
	c = Canvas()
	inside = lambda x, y: (x - 16) ** 2 + (y - 16) ** 2 <= 14.5 ** 2

	def sky(l):
		badge(l, [NIGHT[3], NIGHT[2], NIGHT[1], NIGHT[0]])
		for sx, sy in ((7, 8), (12, 4), (18, 6), (5, 13), (14, 10), (27, 15)):
			l.put(sx, sy, MOON[1])
		l.put(12, 4, MOON[0])
		l.fill(lambda x, y: (x - 22) ** 2 + (y - 8) ** 2 <= 17 and (x - 20) ** 2 + (y - 6.4) ** 2 > 12,
			lambda x, y: MOON[0] if x > 23.5 else MOON[1])

	c.part(sky)
	c.part(lambda l: spruce(l, 7, 8, 15, 4.6))
	c.part(lambda l: spruce(l, 25.5, 11, 12, 4.0))
	hill = lambda x, y: inside(x, y) and y >= 22.5 + 0.02 * (x - 16) ** 2

	def ground(l):
		l.fill(hill, lambda x, y: GRASS[1] if ((x - 16) / 8) ** 2 + ((y - 25) / 3) ** 2 <= 1 else (GRASS[2] if y < 25.5 else GRASS[3]))

	c.part(ground)
	c.part(lambda l: log(l, 10.5, 25.5, 19.5, 23, 1.3))
	c.part(lambda l: log(l, 21.5, 25.5, 12.5, 23, 1.3))
	c.part(lambda l: fire(l, 16, 24, 3.6, 12))
	c.part(lambda l: (l.put(20, 10, FIRE[1]), l.put(12, 12, FIRE[2])), edge=False)
	return c


# The one the game uses (chosen 2026-10-24), and the others drawn for the choice.
ICON = night_camp
VARIANTS = {
	"campfire": campfire,
	"block": world_block,
	"sparrow": sparrow,
	"night": night_camp,
}


def preview(icons: dict) -> Image.Image:
	"""Every variant large, then on a light and a dark tab at 16 and 56 (scaled down
	smoothly, as a browser does) and at 32 and 48."""
	big = 8
	w = len(icons) * (N * big + 40) + 40
	img = Image.new("RGBA", (w, N * big + 200), (0xE8, 0xE0, 0xD2, 255))
	for i, (name, ic) in enumerate(icons.items()):
		x = 40 + i * (N * big + 40)
		img.alpha_composite(ic.resize((N * big, N * big), Image.NEAREST), (x, 30))
		ImageDraw.Draw(img).text((x, 6), str(i + 1), fill=EDGE, font=ImageFont.truetype(FONT, 16))
		y = N * big + 60
		for j, bg in enumerate(((0xF4, 0xF4, 0xF4), (0x2A, 0x2A, 0x30))):
			yy = y + j * 70
			img.paste(Image.new("RGBA", (N * big, 60), bg + (255,)), (x, yy))
			img.alpha_composite(ic.resize((16, 16), Image.LANCZOS), (x + 14, yy + 22))
			img.alpha_composite(ic, (x + 44, yy + 14))
			img.alpha_composite(ic.resize((48, 48), Image.NEAREST), (x + 90, yy + 6))
			img.alpha_composite(ic.resize((56, 56), Image.LANCZOS), (x + 150, yy + 2))
	return img


def touch_icon(icon: Image.Image) -> Image.Image:
	"""The home screen's icon: the badge five times as large on the night's darkest blue,
	which the phone rounds the corners of."""
	img = Image.new("RGBA", (TOUCH, TOUCH), NIGHT[3] + (255,))
	big = icon.resize((N * 5, N * 5), Image.NEAREST)
	img.alpha_composite(big, ((TOUCH - big.width) // 2, (TOUCH - big.height) // 2))
	return img


def card(icon: Image.Image) -> Image.Image:
	"""The picture a messenger shows under a link: a night sky in bands as the loading
	page's, stars, spruces along the bottom, the badge and the name with a line under it.
	Drawn CARD_PX times smaller and scaled up, so its pixels are as coarse as the icon's."""
	w, h = CARD_W // CARD_PX, CARD_H // CARD_PX + 1
	c = Image.new("RGBA", (w, h), NIGHT[3] + (255,))
	d = ImageDraw.Draw(c)
	bands = [NIGHT[3], NIGHT[2], NIGHT[1], NIGHT[0], (0x4F, 0x6C, 0x96)]
	for i, col in enumerate(bands):
		d.rectangle((0, i * h // 7, w, h), fill=col)
	rng = random.Random(7)
	for i in range(46):
		x, y = rng.randrange(w), rng.randrange(h * 3 // 5)
		c.putpixel((x, y), MOON[i % 2] + (255,))
	# A row of spruces on a dark hill along the bottom, the near ones taller.
	trees = Canvas(w, 56)
	x = -4
	while x < w + 8:
		height = rng.randint(18, 34)
		spruce(trees, x, 52 - height, height, height * 0.24)
		x += rng.randint(8, 14)
	trees.fill(lambda x, y: y > 51 - 1.5 * math.sin(x / 23.0), lambda x, y: PINE[3])
	trees.outline()
	c.alpha_composite(trees.image(), (0, h - 56))
	big = icon.resize((N * 2, N * 2), Image.NEAREST)
	top = (h - 30 - big.height) // 2
	c.alpha_composite(big, (24, top))
	title = ImageFont.truetype(FONT, 16)
	small = ImageFont.truetype(FONT, 8)
	tx = 24 + big.width + 14
	d.fontmode = "1"
	d.text((tx, top + 12), NAME, font=title, fill=(0xE9, 0xB4, 0x4C), stroke_width=2, stroke_fill=EDGE)
	for i, line in enumerate(TAGLINE):
		d.text((tx, top + 36 + 12 * i), line, font=small, fill=(0xF3, 0xE7, 0xCC), stroke_width=1, stroke_fill=EDGE)
	return c.resize((w * CARD_PX, h * CARD_PX), Image.NEAREST).crop((0, 0, CARD_W, CARD_H))


def main() -> None:
	if len(sys.argv) > 2 and sys.argv[1] == "--variants":
		out = sys.argv[2]
		os.makedirs(out, exist_ok=True)
		icons = {}
		for name, draw in VARIANTS.items():
			icons[name] = draw().image()
			icons[name].save(os.path.join(out, name + ".png"))
		preview(icons).save(os.path.join(out, "preview.png"))
		return
	icon = ICON().image()
	icon.save("icon.png")
	touch_icon(icon).save(os.path.join(WEB, "apple-touch-icon.png"))
	card(icon).convert("RGB").save(os.path.join(WEB, "og.png"))


if __name__ == "__main__":
	main()
