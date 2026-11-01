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
const DANGER_DARK := Color("#a8432a")
const GOOD := Color("#8fcf6a")
const GOOD_DARK := Color("#5e9443")

const PALETTE := {
	"w": INK, "m": MUTED, "a": ACCENT, "y": Color("#f6d27a"), "b": Color("#9fd2f7"),
	"g": Color("#a9b0b4"), "d": Color("#6f777b"), "r": Color("#8a5a2b"), "k": DARK_INK,
	"e": GOOD,
}

## Icons, one character per pixel (see PALETTE; "." is transparent). An icon is cut to
## its drawn pixels and made even across and down (see _even), so a button centres
## what is drawn.
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
	"moon_full": [
		"..wwww...",
		".wwwwww..",
		"wwwmwwww.",
		"wwwwwwww.",
		"wwwwwmww.",
		"wwmwwwww.",
		".wwwwww..",
		"..wwww...",
	],
	"moon_new": [
		"..dddd...",
		".d....d..",
		"d......d.",
		"d......d.",
		"d......d.",
		"d......d.",
		".d....d..",
		"..dddd...",
	],
	"cloud": [
		".........",
		"...www...",
		"..wwwww..",
		".wwwwwww.",
		"wwwwwwwww",
		"wwwwwwwww",
		".........",
	],
	"fog": [
		".........",
		"wwwwww...",
		".........",
		"..wwwwwww",
		".........",
		"wwwwwww..",
		".........",
		"...wwwwww",
	],
	"storm": [
		"..www....",
		".wwwwww..",
		"wwwwwwwww",
		"wwwwwwwww",
		"....y....",
		"...yy....",
		"....yy...",
		"....y....",
	],
	"hail": [
		"..www....",
		".wwwwww..",
		"wwwwwwwww",
		"wwwwwwwww",
		".........",
		".w..w..w.",
		".........",
		"w..w..w..",
	],
	"sand": [
		".........",
		"aaaaaa...",
		"......a..",
		"..aaaaa..",
		"aa.......",
		"...aaaaa.",
		"........a",
		".aaaaaa..",
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
	"chat": [
		".wwwwwww.",
		"w.......w",
		"w.w.w.w.w",
		"w.......w",
		".wwwwwww.",
		".ww......",
		".w.......",
	],
	"person": [
		"..www......",
		"..www......",
		"...w.......",
		".wwwww.aaa.",
		"w.www.a...a",
		"w.www.aaaaa",
		"..www.aaaaa",
		"..w.w.aaaaa",
		"..w.w.aaaaa",
		"..w.w......",
		".ww.ww.....",
	],
	"wear_head": [
		"....gggg....",
		"...gggggd...",
		"...gggggd...",
		"...gggggd...",
		"..dddddddd..",
		".gggggggggd.",
		"..dddddddd..",
	],
	"wear_body": [
		"....gddg....",
		"..gggddggg..",
		".gggggggggg.",
		"gggggggggggd",
		"gggggggggggd",
		"dd.gggggg.dd",
		"...gggggd...",
		"...gggggd...",
		"...gggggd...",
		"...ddddddd..",
	],
	"wear_legs": [
		"dddddd",
		"gggggg",
		"ggggdg",
		"ggd.gd",
		"ggd.gd",
		"ggd.gd",
		"ggd.gd",
		"ggd.gd",
		"ddd.dd",
	],
	"wear_feet": [
		"gd....gd..",
		"gd....gd..",
		"gd....gd..",
		"gd....gd..",
		"ggd...ggd.",
		"gggd..gggd",
		"dddd..dddd",
	],
	"wear_back": [
		"...mmm...",
		"..m...m..",
		".mmmmmmm.",
		"mmmmmmmmm",
		"mmm.m.mmm",
		"mmmmmmmmm",
		"mmmmmmmmm",
		"mmmmmmmmm",
		".mmmmmmm.",
	],
	"bag": [
		"...www...",
		"..w...w..",
		".wwwwwww.",
		"wwwwwwwww",
		"wwwaaawww",
		"wwwwawwww",
		"wwwwwwwww",
		"wwwwwwwww",
		".wwwwwww.",
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
	"turn_left": [
		"...w.....",
		"..ww.....",
		".wwwwww..",
		"..ww...w.",
		"...w....w",
		"........w",
		"........w",
		".......w.",
		"..wwwww..",
	],
	"turn_right": [
		".....w...",
		".....ww..",
		"..wwwwww.",
		".w...ww..",
		"w....w...",
		"w........",
		"w........",
		".w.......",
		"..wwwww..",
	],
	"tilt_up": [
		"....w....",
		"...www...",
		"..w.w.w..",
		"....w....",
		"....w....",
		".........",
		"aaaaaaaaa",
		"wwwwwwwww",
		"wwwwwwwww",
	],
	"tilt_down": [
		"....w....",
		"....w....",
		"..w.w.w..",
		"...www...",
		"....w....",
		".........",
		"aaaaaaaaa",
		"wwwwwwwww",
		"wwwwwwwww",
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
	"prev_up": [
		"....w....",
		"...www...",
		"..ww.ww..",
		".ww...ww.",
		"ww.....ww",
	],
	"next_down": [
		"ww.....ww",
		".ww...ww.",
		"..ww.ww..",
		"...www...",
		"....w....",
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
	"all": [
		"www.www..",
		"www.www..",
		"www.www..",
		".........",
		"www.www..",
		"www.www..",
		"www.www..",
	],
	"sort_kind": [
		"aaa.wwwww",
		"aaa......",
		"aaa.www..",
		".........",
		"bbb.wwwww",
		"bbb......",
		"bbb.www..",
	],
	"drop_one": [
		"...wwwwww...",
		"..wwwwwwwww.",
		".wwwwwwwwww.",
		".w.ww.ww.ww.",
		"...ww.ww.ww.",
		"....w..w.w..",
		"............",
		"......aa....",
		".....aaaa...",
		"......aa....",
		"............",
		".wwwwwwwwww.",
	],
	"drop_all": [
		"...wwwwww...",
		"..wwwwwwwww.",
		".wwwwwwwwww.",
		".w.ww.ww.ww.",
		"...ww.ww.ww.",
		"....w..w.w..",
		"............",
		"...aa...aa..",
		"...aa...aa..",
		"......aa....",
		"......aa....",
		".wwwwwwwwww.",
	],
	"hammer": [
		"..wwwwwwww..",
		".wwwwwwwwww.",
		".wwwwwwwwww.",
		"..wwwwwwww..",
		".....ww.....",
		".....ww.....",
		".....ww.....",
		".....ww.....",
		".....ww.....",
		".....ww.....",
	],
	"cancel_all": [
		"mm....mm....",
		"mmm..mmm....",
		".mmmmmm.....",
		"..mkkk......",
		"..mkww....ww",
		".mmkwww..www",
		"mmm..wwwwww.",
		"mm....wwww..",
		"......wwww..",
		".....wwwwww.",
		"....www..www",
		"....ww....ww",
	],
	"pause": [
		"ww..ww",
		"ww..ww",
		"ww..ww",
		"ww..ww",
		"ww..ww",
		"ww..ww",
		"ww..ww",
	],
	"play": [
		"w.....",
		"www...",
		"wwww..",
		"wwwww.",
		"wwww..",
		"www...",
		"w.....",
	],
	"take": [
		".....w.....",
		"...w.w.w...",
		"....www....",
		".....w.....",
		"...wwwww...",
		"..w.....w..",
		".wwwwwwwww.",
		"wwwwwwwwwww",
		"wwwwaaawwww",
		"wwwwwwwwwww",
		".wwwwwwwww.",
	],
	"to_chest": [
		"....ww....",
		"....ww....",
		"..wwwwww..",
		"...wwww...",
		"....ww....",
		"..........",
		"wwwwwwwwww",
		"w...aa...w",
		"wwwwwwwwww",
		"w........w",
		"wwwwwwwwww",
	],
	"to_chest_all": [
		".ww....ww.",
		".ww....ww.",
		"wwww..wwww",
		".ww....ww.",
		"..........",
		"wwwwwwwwww",
		"w...aa...w",
		"wwwwwwwwww",
		"w........w",
		"wwwwwwwwww",
	],
	"put_out": [
		"....b....",
		"....b....",
		"...bbb...",
		"...bbb...",
		"..bbbbb..",
		".bbbbbbb.",
		".bbbbwbb.",
		".bbbbwbb.",
		"..bbbbb..",
		"...bbb...",
	],
	"light": [
		"....a....",
		"...aa....",
		"...aaa...",
		"..aaya.a.",
		"..ayyaaa.",
		".aayyyaa.",
		".ayyyyya.",
		".ayywyya.",
		"..ayyya..",
		"...aaa...",
	],
	"swap": [
		"......w...",
		"......ww..",
		"wwwwwwwww.",
		"......ww..",
		"......w...",
		"...w......",
		"..ww......",
		".wwwwwwwww",
		"..ww......",
		"...w......",
	],
	"power": [
		"y..y..y.",
		".y.y.y..",
		"..yyy...",
		"yyyayyyy",
		"..yyy...",
		".y.y.y..",
		"y..y..y.",
		"...y....",
	],
	"shield": [
		"gggggggg",
		"gwwwwwwg",
		"gwwwwwwg",
		"gwwwwwwg",
		".gwwwwg.",
		".gwwwwg.",
		"..gwwg..",
		"...gg...",
	],
	"trash": [
		"...www...",
		"wwwwwwwww",
		".........",
		".wwwwwww.",
		".w.w.w.w.",
		".w.w.w.w.",
		".w.w.w.w.",
		".w.w.w.w.",
		"..wwwww..",
	],
	"clock": [
		"..wwwww..",
		".w.....w.",
		"w...a...w",
		"w...a...w",
		"w...aaa.w",
		"w.......w",
		"w.......w",
		".w.....w.",
		"..wwwww..",
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
	"plus": [
		"...ww...",
		"...ww...",
		"...ww...",
		"wwwwwwww",
		"wwwwwwww",
		"...ww...",
		"...ww...",
		"...ww...",
	],
	# The kinds of change in «Что нового» (tools/build_info.py KINDS).
	"change_new": [
		"...ee...",
		"...ee...",
		"...ee...",
		"eeeeeeee",
		"eeeeeeee",
		"...ee...",
		"...ee...",
		"...ee...",
	],
	"change_better": [
		"...bb...",
		"..bbbb..",
		".bbbbbb.",
		"bbbbbbbb",
		"...bb...",
		"...bb...",
		"...bb...",
		"...bb...",
	],
	"change_fix": [
		"....g..g",
		"....g..g",
		"....gggg",
		"...ggg..",
		"..ggg...",
		".ggg....",
		"ggg.....",
		"gg......",
	],
	"change_fast": [
		"....yyy.",
		"...yyy..",
		"..yyy...",
		".yyyyyy.",
		"...yyy..",
		"..yyy...",
		".yy.....",
		"y.......",
	],
	"change_inside": [
		"...mm...",
		".m.mm.m.",
		"..mmmm..",
		"mmm..mmm",
		"mmm..mmm",
		"..mmmm..",
		".m.mm.m.",
		"...mm...",
	],
	"minus": [
		"........",
		"........",
		"........",
		"wwwwwwww",
		"wwwwwwww",
		"........",
		"........",
		"........",
	],
	"target": [
		"...www...",
		".ww...ww.",
		".w.....w.",
		"w...a...w",
		"w..aaa..w",
		"w...a...w",
		".w.....w.",
		".ww...ww.",
		"...www...",
	],
	"dice": [
		".wwwwwww.",
		"wwwwwwwww",
		"wkwwwwwkw",
		"wwwwwwwww",
		"wwwwkwwww",
		"wwwwwwwww",
		"wkwwwwwkw",
		"wwwwwwwww",
		".wwwwwww.",
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
static var _centred := {}
## Images that textures were made from, by the texture's instance id (see remember).
static var _images := {}


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
		var even := _even(img)
		_icons[name] = ImageTexture.create_from_image(even)
		remember(_icons[name], even)
	return _icons[name]


## Picture `texture` (an icon or an item's picture) for a button: cut to its drawn
## pixels and made even across and down, so it sits in the middle of the button's
## face (its sides are even) to the pixel.
static func centred(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var key := texture.get_instance_id()
	if not _centred.has(key):
		var img: Image = _images.get(key)
		if img == null:
			img = texture.get_image()
		var used := img.get_used_rect()
		_centred[key] = texture if used.position == Vector2i.ZERO and used.size == img.get_size() \
			and used.size.x % 2 == 0 and used.size.y % 2 == 0 else ImageTexture.create_from_image(_even(img))
	return _centred[key]


## Keeps the image `texture` was made from, so the picture is not read back from the
## texture, which in the browser waits for the graphics card.
static func remember(texture: Texture2D, img: Image) -> void:
	_images[texture.get_instance_id()] = img


## Image `img` cut to its drawn pixels, with the middle column (row) doubled when it is
## odd across (down): an odd picture has no middle on an even face.
static func _even(img: Image) -> Image:
	img = img.get_region(img.get_used_rect())
	if img.get_width() % 2 == 1:
		var w := img.get_width()
		var out := Image.create_empty(w + 1, img.get_height(), false, img.get_format())
		var mid := w / 2
		out.blit_rect(img, Rect2i(0, 0, mid + 1, img.get_height()), Vector2i.ZERO)
		out.blit_rect(img, Rect2i(mid, 0, w - mid, img.get_height()), Vector2i(mid + 1, 0))
		img = out
	if img.get_height() % 2 == 1:
		var h := img.get_height()
		var out := Image.create_empty(img.get_width(), h + 1, false, img.get_format())
		var mid := h / 2
		out.blit_rect(img, Rect2i(0, 0, img.get_width(), mid + 1), Vector2i.ZERO)
		out.blit_rect(img, Rect2i(0, mid, img.get_width(), h - mid), Vector2i(0, mid + 1))
		img = out
	return img


## The theme of the whole UI: pixel font, panels and buttons.
static func theme() -> Theme:
	# One for the HUD, the menu and the death screen: none of them changes it.
	if _theme != null:
		return _theme
	var t := Theme.new()
	_theme = t
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
	for state in ["normal", "focus", "read_only"]:
		t.set_stylebox(state, "LineEdit", field(state == "focus"))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", HIGHLIGHT)
	# A thin bar in a sunken groove for the lists that scroll.
	var groove := StyleBoxFlat.new()
	groove.bg_color = WELL
	groove.content_margin_left = SCROLL_BAR / 2.0
	groove.content_margin_right = SCROLL_BAR / 2.0
	t.set_stylebox("scroll", "VScrollBar", groove)
	t.set_stylebox("scroll_focus", "VScrollBar", groove)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = MUTED if state == "grabber" else ACCENT
		t.set_stylebox(state, "VScrollBar", grip)
	return t


## The room between a panel's edge and what it holds (left, top, right, bottom): its
## frame is 4 px, so text keeps a few pixels clear of it.
const PAD := Vector4(10, 8, 10, 8)
## The room in a frame round slots and buttons, or a line that must stay short (the
## clock): the old thin one.
const TIGHT := Vector4(6, 6, 6, 6)
## The room in a sunken well holding text (the bag's and the craft tab's panels).
const WELL_PAD := 8
## The width of a scroll bar.
const SCROLL_BAR := 6


## Panel: two pixels of outline, two of highlight, then the fill; `pad` round what it holds.
static func panel(pad := PAD) -> StyleBoxTexture:
	return _nine_patch(12, 4, "panel", PANEL, EDGE, pad)


## A button's frame like a panel's, see-through inside, for helpers that should hide
## little of the world (the level buttons); `pressed` shades the inside more.
static func frame(pressed := false) -> StyleBoxTexture:
	return _nine_patch(12, 4, "panel", Color(EDGE, 0.4 if pressed else 0.1), EDGE, Vector4(4, 4, 4, 4))


## A text field: a sunken well like a slot, with room around the text.
static func field(focused := false) -> StyleBoxTexture:
	return _nine_patch(12, 4, "slot", WELL, ACCENT if focused else EDGE, Vector4(6, 6, 6, 6))


## Item slot: a sunken well with a shadow along the top and left edges.
static func slot(selected := false) -> StyleBoxTexture:
	return _nine_patch(12, 4, "slot", WELL, ACCENT if selected else EDGE, Vector4.ZERO)


## The sunken well around a block of text (a slot's frame with WELL_PAD inside), made
## once and shared: no caller changes it.
static func well() -> StyleBox:
	if _well_box == null:
		_well_box = slot()
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_well_box.set_content_margin(side, WELL_PAD)
	return _well_box


static var _well_box: StyleBoxTexture


## A button's frame; `accent` lights it amber, `danger` red (a second tap destroys),
## `good` green (what it did worked).
static func button(state: String, accent := false, danger := false, good := false) -> StyleBoxTexture:
	var fill := BUTTON
	var shade := BUTTON_SHADE
	if danger:
		fill = DANGER
		shade = DANGER_DARK
	elif good:
		fill = GOOD
		shade = GOOD_DARK
	elif accent:
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


## The red and green frames of the window's buttons, made once.
static var _lit_boxes := {}


## Lights button `b` red while it waits for its second tap (as the bin in the bag), or
## puts it back; its text stays.
static func arm(b: Button, on: bool) -> void:
	_paint(b, "danger" if on else "")


## Lights button `b` green when what it did worked («Скопировано»), or puts it back.
static func succeed(b: Button, on: bool) -> void:
	_paint(b, "good" if on else "")


## Paints button `b` in the accent colour (the one to press: «Начать», the world in
## play), dark text on it; the boxes are made once and shared.
static func accent(b: Button) -> void:
	_paint(b, "accent")


static func _paint(b: Button, kind: String) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		if kind == "":
			b.remove_theme_stylebox_override(state)
			continue
		var key := kind + ":" + state
		if not _lit_boxes.has(key):
			_lit_boxes[key] = button(state, kind == "accent", kind == "danger", kind == "good")
		b.add_theme_stylebox_override(state, _lit_boxes[key])
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		if kind == "":
			b.remove_theme_color_override(c)
		else:
			b.add_theme_color_override(c, DARK_INK)


## Big round-ish touch button: an octagon with cut corners, a light rim along the top
## and a lip of `shade` along the bottom (none when pressed, `fill` darker then).
static func octagon(fill: Color, shade: Color, pressed := false) -> StyleBoxTexture:
	# Pressed, what is on it goes down by the lip.
	return _nine_patch(24, 9, "octagon_down" if pressed else "octagon", fill, shade,
		Vector4(8, 11, 8, 7) if pressed else Vector4(8, 8, 8, 10))


static func label(text := "", color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A square nine-patch `n` px across with `margin` px corners; `content` is the inner
## padding (left, top, right, bottom).
## The pictures of the nine-patches drawn so far, by n, margin, kind and colours.
static var _patches := {}
static var _theme: Theme = null


static func _nine_patch(n: int, margin: int, kind: String, fill: Color, edge: Color, content: Vector4) -> StyleBoxTexture:
	# The picture is drawn once per look and shared; the box is new each time, since
	# callers change its margins, centre and tint.
	var key := "%d:%d:%s:%d:%d" % [n, margin, kind, fill.to_rgba32(), edge.to_rgba32()]
	var tex: ImageTexture = _patches.get(key)
	if tex == null:
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				img.set_pixel(x, y, _pixel(kind, x, y, n, fill, edge))
		tex = ImageTexture.create_from_image(img)
		_patches[key] = tex
	var box := StyleBoxTexture.new()
	box.texture = tex
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
		"octagon", "octagon_down":
			var cx := mini(x, n - 1 - x)
			var cy := mini(y, n - 1 - y)
			if cx + cy < 7:
				return Color(0, 0, 0, 0)
			if cx + cy < 9 or cx < 2 or cy < 2:
				return EDGE
			if kind == "octagon_down":
				return edge.darkened(0.15) if y < 4 or cx + cy < 11 and y < n / 2 else edge
			if y >= n - 5:
				return edge
			if y < 4 or cx + cy < 11 and y < n / 2:
				return fill.lightened(0.3)
			return fill
	return fill
