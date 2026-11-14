extends "res://src/client/ui/ui_icons.gd"
## Pixel-art look of the interface (see plan/design/ui.md): dark wooden panels with a
## two-pixel outline, square corners, a pixel font and icons drawn from text. Every
## size is in UI pixels; the UI root is scaled by a whole number so one UI pixel is
## one pixel of the world. The icons' drawings are the part before this one (ui_icons.gd,
## decision 168): `UiStyle.ICONS` as before.

const Lang := preload("res://src/shared/content/lang.gd")

const FONT_PATH := "res://assets/fonts/PressStart2P.ttf"
## Press Start 2P is drawn on an 8x8 grid, so at 8 px one pixel of a letter is one UI
## pixel and the letters stay sharp (finer pixel fonts lose rows at their small size).
const FONT_SIZE := 8
const FONT_SIZE_BIG := 16

const INK := Color("#f3e7cc")
const MUTED := Color("#c9b896")
const ACCENT := Color("#e9b44c")
const ACCENT_DARK := Color("#b98a2c")
## The accent button's other states, as the plain one has them: lighter under the
## cursor, its shade's colour pressed, faded towards a plain button when it cannot be pressed.
const ACCENT_HOVER := Color("#f5c768")
const ACCENT_DIM := Color("#7d6236")
const ACCENT_DIM_SHADE := Color("#5a4528")
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
## The player's team: its members' names over their heads and its lines in the chat.
const TEAM := Color("#8fd16a")
## The colours an owner picks from for their land (Territory.COLORS of them; the
## borders on the ground and the maps, the buttons of the rights), the first by default.
const LAND_COLORS := [Color("#8fd16a"), Color("#6aa8e0"), Color("#e8c55a"), Color("#e8894a"),
	Color("#e0645a"), Color("#b07ae0"), Color("#5cd6c6"), Color("#ece4d2")]
const DANGER_DARK := Color("#a8432a")
const GOOD := Color("#8fcf6a")
const GOOD_DARK := Color("#5e9443")

const PALETTE := {
	"w": INK, "m": MUTED, "a": ACCENT, "y": Color("#f6d27a"), "b": Color("#9fd2f7"),
	"g": Color("#a9b0b4"), "d": Color("#6f777b"), "r": Color("#8a5a2b"), "k": DARK_INK,
	"e": GOOD, "n": DANGER,
}

static var _font: FontFile
static var _icons := {}
static var _weight: Texture2D
static var _centred := {}
## Pictures with a dark edge (see outlined), by the picture's instance id.
static var _outlined := {}
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
		# Drawn shapes whose slanted lines a doubled middle would break (the gestures)
		# get a clear column (row) instead.
		var even := _even(img, not (name == "gesture" or name.begins_with("g_")))
		_icons[name] = ImageTexture.create_from_image(even)
		remember(_icons[name], even)
	return _icons[name]


## Picture `texture` with a dark edge a pixel wide round its drawn pixels (sides and
## corners), like the outline of the letters on the see-through buttons (Kit.see_through:
## the level and camera buttons), so it reads over any ground. Made once per picture.
static func outlined(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var key := texture.get_instance_id()
	if not _outlined.has(key):
		var img: Image = _images.get(key)
		if img == null:
			img = texture.get_image()
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var out := Image.create_empty(w + 2, h + 2, false, Image.FORMAT_RGBA8)
		out.fill(Color(0, 0, 0, 0))
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a <= 0.0:
					continue
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						out.set_pixel(x + 1 + dx, y + 1 + dy, EDGE)
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					out.set_pixel(x + 1, y + 1, c)
		var made := ImageTexture.create_from_image(out)
		remember(made, out)
		_outlined[key] = made
	return _outlined[key]


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


## Lets go of the pictures made from others (outlined, centred) and of the images kept of
## textures (remember), but those of the interface's own icons (icon), which stay: the
## mods' pictures were read anew (ModReload, ItemIcons.forget), and each reload or change of
## server would keep one more copy of every one.
static func forget() -> void:
	var kept := {}
	for t: Texture2D in _icons.values():
		var key := t.get_instance_id()
		if _images.has(key):
			kept[key] = _images[key]
	_images = kept
	_outlined = {}
	_centred = {}


## Keeps the image `texture` was made from, so the picture is not read back from the
## texture, which in the browser waits for the graphics card.
static func remember(texture: Texture2D, img: Image) -> void:
	_images[texture.get_instance_id()] = img


## Image `img` cut to its drawn pixels, with the middle column (row) doubled when it is
## odd across (down): an odd picture has no middle on an even face. Without `stretch`
## a clear column (row) goes on the right (bottom) instead, the picture as drawn.
static func _even(img: Image, stretch := true) -> Image:
	img = img.get_region(img.get_used_rect())
	if not stretch:
		var w := img.get_width() + img.get_width() % 2
		var h := img.get_height() + img.get_height() % 2
		if w != img.get_width() or h != img.get_height():
			var out := Image.create_empty(w, h, false, img.get_format())
			out.fill(Color(0, 0, 0, 0))
			out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
			img = out
		return img
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
	groove.content_margin_left = floorf(SCROLL_BAR / 2.0)
	groove.content_margin_right = SCROLL_BAR - floorf(SCROLL_BAR / 2.0)
	t.set_stylebox("scroll", "VScrollBar", groove)
	t.set_stylebox("scroll_focus", "VScrollBar", groove)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grip := StyleBoxFlat.new()
		grip.bg_color = MUTED if state == "grabber" else ACCENT
		t.set_stylebox(state, "VScrollBar", grip)
	return t


## The weight of the limit, `weight` of `limit` kg with the weight's picture, in `r`
## (red past the limit).
static func draw_weight(c: CanvasItem, r: Rect2, weight: float, limit: int) -> void:
	var f := font()
	var fs := FONT_SIZE
	var y := floorf(r.position.y + (r.size.y - f.get_height(fs)) * 0.5) + f.get_ascent(fs)
	var mid := r.position.y + r.size.y * 0.5
	var x := r.position.x
	var kg := _weight_icon()
	if kg != null:
		c.draw_texture(kg, Vector2(x, floorf(mid - kg.get_height() * 0.5)))
		x += kg.get_width() + 4
	# A dark outline keeps it legible over the filled divisions.
	var text := Lang.f("[kg_n3]", [roundi(weight), limit])
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		c.draw_string(f, Vector2(x, y) + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, EDGE)
	c.draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DANGER if weight > limit else INK)


## The width draw_weight takes for a limit of `limit` kg, the weight up to ten times
## the limit.
static func weight_width(limit: int) -> int:
	var kg := _weight_icon()
	return int((kg.get_width() + 4 if kg != null else 0) + _text_width(Lang.f("[kg_n3]", [limit * 10, limit])))


static func _text_width(t: String) -> float:
	return ceilf(text_width(t))


## How wide `text` is drawn in `f` (the game's font by default) at `font_size`, in the
## player's language: a key in brackets or a Lang.line is measured as the words a label
## shows for it, never as the key itself. Every measure of a text goes through here or
## text_lines (tools/lint.py), as the key is shorter or longer than its words.
static func text_width(text: String, font_size := FONT_SIZE, f: Font = null) -> float:
	return (f if f != null else font()).get_string_size(Lang.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## How many lines `text`, in the player's language, takes wrapped by words to `width`
## pixels, as a label with AUTOWRAP_WORD_SMART wraps it.
static func text_lines(text: String, width: float, font_size := FONT_SIZE, f: Font = null) -> int:
	var para := TextParagraph.new()
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(Lang.t(text), f if f != null else font(), font_size)
	para.width = width
	return maxi(1, para.get_line_count())


## The weight's picture (assets/ui/weight.png), as the bag's sorting by weight shows it.
## Read once into a texture of its own, as ItemIcons reads pictures.
static func _weight_icon() -> Texture2D:
	if _weight == null and ResourceLoader.exists("res://assets/ui/weight.png"):
		var img: Image = load("res://assets/ui/weight.png").get_image()
		_weight = ImageTexture.create_from_image(img)
		remember(_weight, img)
	return _weight


## The room between a panel's edge and what it holds (left, top, right, bottom): its
## frame is 4 px, so text keeps a few pixels clear of it.
const PAD := Vector4(10, 8, 10, 8)
## The room in a frame round slots and buttons, or a line that must stay short (the
## clock): the old thin one.
const TIGHT := Vector4(6, 6, 6, 6)
## The room in a sunken well holding text (the bag's and the craft tab's panels).
const WELL_PAD := 8
## The width of a scroll bar.
const SCROLL_BAR := 3
## The room between the rows of a window's scrolled list and its sides: a little on the
## left, as much before the scroll bar on the right (the settings, the testing page, the
## inventory's tabs «Земля» and «Команда»; the user's ask 2026-11-02: everywhere so).
const BAR_GAP := 6


## `content` in a box with BAR_GAP of room on its left and right, to put in a
## ScrollContainer (its bar takes its own room right of that). With no bar the rows
## keep as much room on the right as on the left, with a bar BAR_GAP before it (the
## user's ask 2026-11-12: no more on the right than on the left of a window that does
## not scroll; the rows fill the width they are given, ChoiceRows). `bottom`: room under
## the last row, for a list that ends at the window's frame (its text would touch it).
static func inset(content: Control, bottom := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", BAR_GAP)
	m.add_theme_constant_override("margin_right", BAR_GAP)
	m.add_theme_constant_override("margin_top", 0)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(content)
	return m


## Room on the right of `room` (a MarginContainer between a ScrollContainer and what it
## holds) for the scroll's bar and BAR_GAP before it while `on` (the list is taller than
## its window), none otherwise: the bar never covers the rows. A room marked inset
## (meta "inset", `inset_room`) keeps BAR_GAP on the right with no bar too, as on its left.
static func bar_room(room: MarginContainer, on: bool, scroll: ScrollContainer = null) -> void:
	var bar := 0.0
	if on and scroll != null:
		bar = scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var off := BAR_GAP if room.get_meta("inset", false) else 0
	room.add_theme_constant_override("margin_right", int(BAR_GAP + bar) if on else off)


## Makes `room` (the box between a list's scroll and its rows, see bar_room) keep the
## settings' insets: BAR_GAP on the left, and on the right before the bar or the frame.
static func inset_room(room: MarginContainer) -> void:
	room.set_meta("inset", true)
	room.add_theme_constant_override("margin_left", BAR_GAP)
	bar_room(room, false)


## How wide a balloon's tail is (odd: it ends in one pixel).
const BALLOON_TAIL := 9


## Panel: two pixels of outline, two of highlight, then the fill; `pad` round what it holds.
static func panel(pad := PAD) -> StyleBoxTexture:
	return _nine_patch(12, 4, "panel", PANEL, EDGE, pad)


## A button's frame like a panel's, see-through inside, for helpers that should hide
## little of the world (the level buttons); `pressed` shades the inside more.
static func frame(pressed := false) -> StyleBoxTexture:
	return _nine_patch(12, 4, "panel", Color(EDGE, 0.4 if pressed else 0.1), EDGE, Vector4(4, 4, 4, 4))


## A speech balloon: `fill` inside one pixel of `edge`, its corners cut in steps of whole
## pixels, `pad` round the words.
static func balloon(fill: Color, edge: Color, pad := Vector4(5, 2, 5, 3)) -> StyleBoxTexture:
	return _nine_patch(12, 4, "balloon", fill, edge, pad)


## The tail under a balloon (balloon), BALLOON_TAIL wide, pointing down in steps of whole
## pixels; its top row lies over the balloon's bottom edge, so the two are one shape.
static func balloon_tail(fill: Color, edge: Color) -> ImageTexture:
	var key := "tail:%d:%d" % [fill.to_rgba32(), edge.to_rgba32()]
	var tex: ImageTexture = _patches.get(key)
	if tex == null:
		var half := BALLOON_TAIL / 2
		var img := Image.create_empty(BALLOON_TAIL, half + 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in half + 1:
			for x in range(y, BALLOON_TAIL - y):
				img.set_pixel(x, y, edge if x == y or x == BALLOON_TAIL - 1 - y else fill)
		tex = ImageTexture.create_from_image(img)
		_patches[key] = tex
	return tex


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
		if state == "hover":
			fill = ACCENT_HOVER
		elif state == "pressed" or state == "hover_pressed":
			fill = ACCENT_DARK
		elif state == "disabled":
			fill = ACCENT_DIM
			shade = ACCENT_DIM_SHADE
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


## A button's frame filled with `fill` (a land's colour on the rights' buttons), made
## once for each colour and state.
static func button_in(state: String, fill: Color) -> StyleBoxTexture:
	var key := "%s:%s" % [fill.to_html(), state]
	if not _tinted.has(key):
		var f := fill.darkened(0.25) if state == "pressed" or state == "hover_pressed" else fill
		_tinted[key] = _nine_patch(12, 4, "button", f, fill.darkened(0.35), Vector4(10, 6, 10, 8))
	return _tinted[key]


static var _tinted := {}


## Paints button `b` in `fill` (see button_in), dark text on it.
static func tint(b: Button, fill: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, button_in(state, fill))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, DARK_INK)


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
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
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
	if kind == "":
		b.remove_theme_color_override("font_disabled_color")
	else:
		b.add_theme_color_override("font_disabled_color", Color(DARK_INK, 0.6))


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
		"balloon":
			var bx := mini(x, n - 1 - x)
			var by := mini(y, n - 1 - y)
			if bx + by < 2:
				return Color(0, 0, 0, 0)
			if bx == 0 or by == 0 or bx + by == 2:
				return edge
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
