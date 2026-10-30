"""Draws assets/splash.png, the logo the browser shows while the game downloads and the
engine shows as it starts: "SURVIVIUM" in the interface's pixel font, amber with a dark
outline as on the main menu (MainMenu, TITLE_SIZE 32, outline 8), and the sparrow of the
animals mod sitting on the S. Needs Pillow; run from the project folder:

    python3 tools/make_splash.py

The page's sky behind it and the progress bar are CSS in export_presets.cfg
(html/head_include).
"""

from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/PressStart2P.ttf"
SPARROW = "content/animals/sparrow/sprites/creatures/sparrow.png"
OUT = "assets/splash.png"
TEXT = "SURVIVIUM"
SIZE = 32
# Half of the menu's outline_size 8: Godot draws it around the glyph both ways.
OUTLINE = 4
# A pixel of the sparrow, as on the menu (MainMenu.BIRD_PX), its frames and where it
# sits from the left of the name.
BIRD_PX = 3
BIRD_FRAMES = 3
BIRD_X = 10
ACCENT = (0xE9, 0xB4, 0x4C, 255)
EDGE = (0x0F, 0x0A, 0x06, 255)
PAD = 4
# The picture is twice as wide and tall as the logo, the logo in the middle: the engine
# shows its boot splash as large as fits the screen, the logo then about half of it.
ROOM = 2


def main() -> None:
    font = ImageFont.truetype(FONT, SIZE)
    left, top, right, bottom = font.getbbox(TEXT)
    sheet = Image.open(SPARROW).convert("RGBA")
    frame = sheet.crop((0, 0, sheet.width // BIRD_FRAMES, sheet.height))
    bird = frame.resize((frame.width * BIRD_PX, frame.height * BIRD_PX), Image.NEAREST)
    text_w = right - left + 2 * OUTLINE
    text_h = bottom - top + 2 * OUTLINE
    w = text_w + 2 * PAD
    h = bird.height + text_h + 2 * PAD
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Hard pixel edges: the font's pixels are 4 px at 32.
    draw.fontmode = "1"
    at = (PAD + OUTLINE - left, PAD + bird.height + OUTLINE - top)
    draw.text(at, TEXT, font=font, fill=ACCENT, stroke_width=OUTLINE, stroke_fill=EDGE)
    # The sparrow's feet on the top of the outline of the S.
    img.alpha_composite(bird, (PAD + BIRD_X, PAD + 1))
    out = Image.new("RGBA", (w * ROOM, h * ROOM), (0, 0, 0, 0))
    out.alpha_composite(img, ((out.width - w) // 2, (out.height - h) // 2))
    out.save(OUT)
    print("saved %s, %dx%d" % (OUT, out.width, out.height))


if __name__ == "__main__":
    main()
