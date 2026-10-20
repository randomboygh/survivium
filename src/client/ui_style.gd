extends RefCounted
## Pixel-art look of the interface (see plan/design/ui.md): dark wooden panels with a
## two-pixel outline, square corners, a pixel font and icons drawn from text. Every
## size is in UI pixels; the UI root is scaled by a whole number so one UI pixel is
## one pixel of the world.

const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"
## Press Start 2P is drawn on an 8x8 grid, so at 8 px one pixel of a letter is one UI
## pixel and the letters stay sharp (finer pixel fonts lose rows at their small size).
const FONT_SIZE := 8
const FONT_SIZE_BIG := 16

const INK := Color("#f3e7cc")
const MUTED := Color("#c9b896")
const ACCENT := Color("#e9b44c")
const ACCENT_DARK := Color("#b98a2c")
const EDGE := Color("#0f0a06")
const HIGHLIGHT := Color("#5b4630")
const PANEL := Color(42 / 255.0, 32 / 255.0, 25 / 255.0, 0.92)
const WELL := Color(20 / 255.0, 14 / 255.0, 10 / 255.0, 0.82)
const WELL_SHADE := Color("#1a120c")
const BUTTON := Color("#3a2c20")
const BUTTON_HOVER := Color("#4a3828")
const BUTTON_SHADE := Color("#2a1f16")
const DARK_INK := Color("#1c140d")
const COLD := Color("#7cc0f0")
const DANGER := Color("#e0613f")
const GOOD := Color("#8fcf6a")

const PALETTE := {
	"w": INK, "m": MUTED, "a": ACCENT, "y": Color("#f6d27a"), "b": Color("#9fd2f7"),
	"g": Color("#a9b0b4"), "d": Color("#6f777b"), "r": Color("#8a5a2b"), "k": DARK_INK,
}

## Icons, one character per pixel (see PALETTE; "." is transparent).
const ICONS := {
	"sun": [
		"....y....",
		".y.....y.",
		"...aaa...",
		"..aaaaa..",
		"y.aaaaa.y",
		"..aaaaa..",
		"...aaa...",
		".y.....y.",
		"....y....",
	],
	"moon": [
		"..wwww...",
		".www.....",
		"www......",
		"www......",
		"www......",
		"www......",
		".www.....",
		"..wwww...",
	],
	"rain": [
		"..www....",
		".wwwww.w.",
		"wwwwwwwww",
		"wwwwwwwww",
		".........",
		".b..b..b.",
		"b..b..b..",
	],
	"snow": [
		"....b....",
		".b..b..b.",
		"..b.b.b..",
		"...bbb...",
		"bbbbbbbbb",
		"...bbb...",
		"..b.b.b..",
		".b..b..b.",
		"....b....",
	],
	"menu": [
		"wwwwwwwww",
		"wwwwwwwww",
		".........",
		".........",
		"wwwwwwwww",
		"wwwwwwwww",
		".........",
		".........",
		"wwwwwwwww",
		"wwwwwwwww",
	],
	"flask": [
		"..wwwww..",
		"...w.w...",
		"...w.w...",
		"...w.w...",
		"..w...w..",
		".w.....w.",
		"w..a.a..w",
		"w.aaaaa.w",
		".wwwwwww.",
	],
	"chart": [
		"........a",
		"......a.a",
		"......a.a",
		"..a...a.a",
		"..a.a.a.a",
		"a.a.a.a.a",
		"a.a.a.a.a",
		".........",
		"wwwwwwwww",
	],
	"up": [
		"....w....",
		"...www...",
		"..wwwww..",
		".wwwwwww.",
		"wwwwwwwww",
	],
	"down": [
		"wwwwwwwww",
		".wwwwwww.",
		"..wwwww..",
		"...www...",
		"....w....",
	],
	"prev": [
		"....w",
		"...ww",
		"..ww.",
		".ww..",
		"ww...",
		".ww..",
		"..ww.",
		"...ww",
		"....w",
	],
	"next": [
		"w....",
		"ww...",
		".ww..",
		"..ww.",
		"...ww",
		"..ww.",
		".ww..",
		"ww...",
		"w....",
	],
	"close": [
		"ww....ww",
		"www..www",
		".wwwwww.",
		"..wwww..",
		"..wwww..",
		".wwwwww.",
		"www..www",
		"ww....ww",
	],
	"pick": [
		"...gggggg...",
		"..ggdrrdgg..",
		".gg..rr..gg.",
		".g...rr...g.",
		".....rr.....",
		".....rr.....",
		".....rr.....",
		".....rr.....",
		".....rr.....",
		".....rr.....",
		".....rr.....",
	],
	"pick_dark": [
		"...kkkkkk...",
		"..kk.kk.kk..",
		".kk..kk..kk.",
		".k...kk...k.",
		".....kk.....",
		".....kk.....",
		".....kk.....",
		".....kk.....",
		".....kk.....",
		".....kk.....",
		".....kk.....",
	],
	"place_dark": [
		"....kk....",
		"....kk....",
		"..kkkkkk..",
		"....kk....",
		"....kk....",
		"..........",
		"kkkkkkkkkk",
		"k........k",
		"k........k",
		"kkkkkkkkkk",
	],
}

static var _font: FontFile
static var _icons := {}


static func font() -> FontFile:
	if _font == null:
		_font = load(FONT_PATH)
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.generate_mipmaps = false
	return _font


static func icon(name: String) -> ImageTexture:
	if not _icons.has(name):
		var rows: Array = ICONS[name]
		var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if PALETTE.has(row[x]):
					img.set_pixel(x, y, PALETTE[row[x]])
		_icons[name] = ImageTexture.create_from_image(img)
	return _icons[name]


## The theme of the whole UI: pixel font, panels and buttons.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 4)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", button(state))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_pressed_color", "Button", MUTED)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.5))
	t.set_color("icon_normal_color", "Button", Color.WHITE)
	t.set_constant("h_separation", "Button", 6)
	return t


## Panel: two pixels of outline, two of highlight, then the fill.
static func panel() -> StyleBoxTexture:
	return _nine_patch(12, 4, "panel", PANEL, EDGE, Vector4(6, 6, 6, 6))


## Item slot: a sunken well with a shadow along the top and left edges.
static func slot(selected := false) -> StyleBoxTexture:
	return _nine_patch(12, 4, "slot", WELL, ACCENT if selected else EDGE, Vector4.ZERO)


static func button(state: String, accent := false) -> StyleBoxTexture:
	var fill := BUTTON
	var shade := BUTTON_SHADE
	if accent:
		fill = ACCENT
		shade = ACCENT_DARK
	elif state == "hover":
		fill = BUTTON_HOVER
	elif state == "pressed" or state == "hover_pressed":
		fill = BUTTON_SHADE
		shade = BUTTON_SHADE
	var box := _nine_patch(12, 4, "button", fill, shade, Vector4(10, 6, 10, 8))
	if state == "focus":
		box.draw_center = false
		box.modulate_color = Color(0, 0, 0, 0)
	return box


## Big round-ish action button: an octagon with cut corners.
static func octagon(fill: Color) -> StyleBoxTexture:
	return _nine_patch(24, 8, "octagon", fill, EDGE, Vector4(8, 8, 8, 8))


static func label(text := "", color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A square nine-patch `n` px across with `margin` px corners; `content` is the inner
## padding (left, top, right, bottom).
static func _nine_patch(n: int, margin: int, kind: String, fill: Color, edge: Color, content: Vector4) -> StyleBoxTexture:
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			img.set_pixel(x, y, _pixel(kind, x, y, n, fill, edge))
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(img)
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box


## Colour of one pixel of a nine-patch. For buttons `edge` is the shade along the bottom.
static func _pixel(kind: String, x: int, y: int, n: int, fill: Color, edge: Color) -> Color:
	var d := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
	match kind:
		"panel":
			if d < 2:
				return edge
			return HIGHLIGHT if d < 4 else fill
		"slot":
			if d < 2:
				return edge
			if edge == EDGE and (x < 4 or y < 4):
				return WELL_SHADE
			return fill
		"button":
			if d < 2:
				return EDGE
			return edge if y >= n - 4 else fill
		"octagon":
			var cx := mini(x, n - 1 - x)
			var cy := mini(y, n - 1 - y)
			if cx + cy < 7:
				return Color(0, 0, 0, 0)
			if cx + cy < 9 or cx < 2 or cy < 2:
				return edge
			return fill
	return fill
