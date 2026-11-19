extends PanelContainer
## The character drawn big, the same on every «Персонаж» tab (the inventory's, PersonPanel;
## those of «Новая игра», «Создать сервер» and «Присоединиться», CharacterPage): `preview`
## (FigurePreview) in a window's frame (UiStyle.stage), the part CROP of its frame drawn
## PIXELS screen pixels a pixel on an upright screen and PIXELS_WIDE on a wide one
## (set_wide), the arrows that turn it in the frame's bottom corners.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const FigurePreview := preload("res://src/client/ui/figure_preview.gd")

## The part of the figure's frame drawn (FigurePreview.crop): its whole width (a scythe
## carried reaches both edges), the rows over the head left out (nothing standing, the
## things held neither, reaches above row 15: the room of the works' swings).
const CROP := Rect2i(0, 12, 32, 20)
## Screen pixels a pixel of the figure on an upright screen and on a wide one (where what
## is beside it keeps its room: the skills' names, the looks' rows), and the fewest where
## a window is short of room (shrink).
const PIXELS := 7
const PIXELS_WIDE := 5
const PIXELS_LEAST := 3
## The side of the arrows that turn the figure, in the bottom corners of its frame, by the
## stand (nothing held hangs below the feet).
const ARROW := 22

var preview: FigurePreview


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.stage())
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview = FigurePreview.new([], PIXELS, CROP)
	preview.tooltip_text = "[drag_to_turn_the_character]"
	add_child(preview)
	for d: int in [-1, 1]:
		var b := Kit.icon_button("prev" if d < 0 else "next",
			"[turn_the_character_left]" if d < 0 else "[turn_the_character_right]", preview.turn.bind(d), ARROW)
		b.focus_mode = Control.FOCUS_NONE
		preview.add_child(b)
		# Pinned to its corner and growing from it into the frame, as large as it asks:
		# what it asks is known only in the tree (the theme), after this.
		b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT if d < 0 else Control.PRESET_BOTTOM_RIGHT, true)
		b.grow_horizontal = Control.GROW_DIRECTION_END if d < 0 else Control.GROW_DIRECTION_BEGIN
		b.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Drawn for a wide screen (a phone on its side, a PC) or an upright one.
func set_wide(wide: bool) -> void:
	preview.set_pixels(PIXELS_WIDE if wide else PIXELS)


## The figure drawn a step smaller, a window having no room for it; whether it could be.
func shrink() -> bool:
	if preview.pixels <= PIXELS_LEAST:
		return false
	preview.set_pixels(preview.pixels - 1)
	return true
