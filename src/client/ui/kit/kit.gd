extends RefCounted
## The UI kit (decision of 2026-11-11, option Б): the ready pieces every window of the
## game is built from, so a new window is put together, not drawn anew. All static.
## Pieces: a window's title, a caption, a note; a window's button (plain, accent), a
## square button with an icon, a framed one of the game's screen, a switch (switch.gd); a text
## field; a column and a row; a list that scrolls (by finger too) with the settings'
## insets; the big touch buttons' looks and a colour swatch. With them: KitWindow
## (window.gd, a window over a shade of the screen), TwoTap (two_tap.gd, a button that
## asks first), ChoiceRows (choice_rows.gd, rows «name ‹ value ›»), SlotStrip
## (slot_strip.gd, cells between arrows: the hotbar, the build and farming palettes) and
## FadingList (fading_list.gd, lines that come and go: the toasts, the chat, the server's notices). «Тестирование» → «Отладка» → «Витрина интерфейса» shows them all;
## a new piece goes there too (docs/systems/ui.md).

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const DragScroll := preload("res://src/client/ui/drag_scroll.gd")
const TextField := preload("res://src/client/ui/text_field.gd")
const Switch := preload("res://src/client/ui/kit/switch.gd")

## The height of a window's buttons and tabs, in UI pixels.
const BUTTON_H := 30
## A text field's height.
const FIELD_H := 26
## A square button's side (the rows' arrows, the trash).
const SQUARE := 32


## A window's title: big, amber, centred.
static func title(text: String) -> Label:
	var l := UiStyle.label(text, UiStyle.ACCENT)
	l.add_theme_font_size_override("font_size", UiStyle.FONT_SIZE_BIG)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A muted line naming what follows (a field's name, «Недавние»).
static func caption(text: String) -> Label:
	return UiStyle.label(text, UiStyle.MUTED)


## Muted text wrapped at `width` (none: as wide as its parent lets it).
static func note(text: String, width := 0.0, color := UiStyle.MUTED) -> Label:
	var l := UiStyle.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	if width <= 0.0:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A window's button doing `action`, `width` × `height` at least (width 0: as its text).
static func button(text: String, action := Callable(), width := 0.0, height := BUTTON_H) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, height)
	if action.is_valid():
		b.pressed.connect(action)
	return b


## The button to press (amber, dark text): «Создать мир», «Подключиться», «Сохранить».
static func accent_button(text: String, action := Callable(), width := 0.0, height := BUTTON_H) -> Button:
	var b := button(text, action, width, height)
	UiStyle.accent(b)
	return b


## A square button with icon `icon` (a name of UiStyle.ICONS or a texture) and tooltip `tip`.
static func icon_button(icon: Variant, tip: String, action := Callable(), side := SQUARE) -> Button:
	var b := button("", action, side, side)
	b.icon = UiStyle.icon(icon) if icon is String else icon
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	return b


## A button of the game's screen in a panel's frame (the HUD's top buttons, the
## hotbar's arrows): icon `icon` (a name or a texture, none for ""), `size` large.
static func framed_button(icon: Variant, tip: String, action := Callable(), size := Vector2(40, 40)) -> Button:
	var b := button("", action, size.x, size.y)
	if not (icon is String and icon == ""):
		b.icon = UiStyle.icon(icon) if icon is String else icon
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.add_theme_stylebox_override("normal", UiStyle.panel())
	b.add_theme_stylebox_override("hover", UiStyle.panel())
	return b


## A switch (switch.gd: a round knob in a pill-shaped track, amber when on) with `text` left of it, on
## when `on` («Доступ из интернета»). Every setting that is only on or off is one: the
## rows «name ‹ value ›» make one of a row whose values are «выкл | вкл» (ChoiceRows).
static func check(text: String, on := false, width := 0.0, height := BUTTON_H) -> Switch:
	var c := Switch.new(text, on)
	c.custom_minimum_size = Vector2(width, height)
	return c


## The game's text field: `hint` while empty, at most `most` letters (0: any), the
## caret and the web's tab switch of TextField.fit.
static func field(hint := "", width := 0.0, most := 0, height := FIELD_H) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = hint
	f.max_length = most
	f.custom_minimum_size = Vector2(width, height)
	if width <= 0.0:
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TextField.fit(f)
	return f


## Things one under another, `gap` apart.
static func column(gap := 4) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", gap)
	return c


## Things side by side, `gap` apart.
static func row(gap := 4) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", gap)
	return r


## The height of a section strip (`section`).
const SECTION_H := 14


## A strip between groups: a pale line across with a picture in its middle (an icon's
## name of UiStyle.ICONS, or a texture) and `text` beside it if given, `tip` on hover.
## It parts the bag from a chest in the inventory and the sections of the settings.
static func section(icon: Variant, tip := "", text := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = SECTION_H
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = tip
	row.add_child(_section_bar())
	var pic := TextureRect.new()
	pic.texture = UiStyle.icon(icon) if icon is String else icon
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(pic)
	if text != "":
		var l := UiStyle.label(text, UiStyle.MUTED)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	row.add_child(_section_bar())
	return row


static func _section_bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = UiStyle.HIGHLIGHT
	bar.custom_minimum_size = Vector2(0, 2)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Empty room `height` tall in a column.
static func gap(height := 8.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A list that scrolls `content` up and down, by its bar and by a finger or the mouse
## dragged over it (DragScroll); `inset`: the rows keep BAR_GAP from its sides as the
## settings' do (UiStyle.inset). Without it the rows stand flush with the window's
## other parts, and only while the list scrolls the bar and BAR_GAP before it get
## room of their own on the right (UiStyle.bar_room), so the bar never covers a row's
## end (a world's trash button); `content` that is a MarginContainer is that room itself.
static func scroll(content: Control, inset := true) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if inset:
		s.add_child(UiStyle.inset(content))
	else:
		var room: MarginContainer = content if content is MarginContainer else MarginContainer.new()
		if room != content:
			for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
				room.add_theme_constant_override(side, 0)
			room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			room.add_child(content)
		s.add_child(room)
		var bar := s.get_v_scroll_bar()
		bar.visibility_changed.connect(func() -> void: UiStyle.bar_room(room, bar.visible, s))
	DragScroll.attach(s)
	return s


## The look of a big touch button of the game's screen: an octagon of `fill` with a lip
## of `shade`, pressed down while held; `ink` for its words (the action, the jump).
static func octagon_look(b: Button, fill: Color, shade: Color, ink: Color) -> void:
	for state in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.octagon(fill, shade, true))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)


## A helper button framed like the others but see-through inside, so it hides little of
## the world (the level and camera buttons); its icon and its letters edged dark
## (UiStyle.outlined, outline_size) to read over any ground.
static func see_through(b: Button) -> void:
	b.icon = UiStyle.outlined(b.icon)
	for state in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, UiStyle.frame())
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, UiStyle.frame(true))
	b.add_theme_color_override("font_outline_color", UiStyle.EDGE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))


## A square of `color` `side` across in a dark frame of a pixel (a marker's, a land's).
static func swatch(color: Color, side := 14.0) -> Control:
	var frame := ColorRect.new()
	frame.color = UiStyle.DARK_INK
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(side - 4, side - 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fill)
	return frame
