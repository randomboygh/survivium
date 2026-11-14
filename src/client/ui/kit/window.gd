extends Control
## A window of the UI kit (kit.gd): it covers the whole screen over a shade of what is
## behind, its panel in the middle, or at the top when the panel is taller than the
## screen (the phone's keyboard is up). A window extends this script, calls `build` in
## its `_ready` with its title, adds its parts to `box` and calls `show_fitted` last;
## it lays its parts out for the screen in `layout` and does in `back` what its «Назад»
## does (Escape too). The parent is the screen: its size, in UI pixels, is the window's.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")
const Shade := preload("res://src/client/ui/kit/shade.gd")

## The shade over what is behind.
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)
## The room kept round the panel.
const MARGIN := 8

## The panel and the column of the window's parts in it.
var panel: PanelContainer
var box: VBoxContainer
## The panel's least size when it was last fitted: a part that asks for more or less
## room after it (a wrapped text measured anew at its width, a row added) fits it again.
var _fitted := Vector2(-1, -1)
var _refit_asked := false


## Makes the panel with `heading` on top (none when empty), its parts `gap` apart, and
## returns the column to add them to. `width`: how wide the column is, whatever its parts
## say (a text shown, a list's bar), so the window never changes its width while open;
## its parts fill it (0: as wide as its widest part).
func build(heading := "", gap := 6, width := 0.0) -> VBoxContainer:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the whole window, the camera cutout too.
	add_child(Shade.new(BACKDROP))
	panel = PanelContainer.new()
	add_child(panel)
	box = Kit.column(gap)
	box.custom_minimum_size.x = width
	# A text put straight into the column keeps the rows' room from its sides
	# (Kit.text_room), as every list's rows do.
	box.child_order_changed.connect(_pad_texts)
	panel.add_child(box)
	panel.minimum_size_changed.connect(_ask_refit)
	if heading != "":
		box.add_child(Kit.title(heading))
	return box


func _pad_texts() -> void:
	for node in box.get_children():
		if node is Label:
			Kit.text_room(node)


## Lays the window out now and again whenever the screen changes size.
func show_fitted() -> void:
	get_parent().resized.connect(fit)
	fit()


## A part asked for other room: the window is fitted again once its containers have
## sorted (a wrapped text knows its height only at its width), until it holds still.
func _ask_refit() -> void:
	if _refit_asked or not is_inside_tree():
		return
	_refit_asked = true
	_refit.call_deferred()


func _refit() -> void:
	_refit_asked = false
	if panel.get_combined_minimum_size() != _fitted or panel.size != _fitted:
		fit()


## Covers the screen, lets the window lay its parts out (`layout`) and places the panel.
func fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	layout(screen)
	panel.reset_size()
	var s := panel.size
	_fitted = s
	panel.position = Vector2(floorf((screen.x - s.x) * 0.5),
		floorf((screen.y - s.y) * 0.5) if s.y + 2 * MARGIN <= screen.y else float(MARGIN))
	move_to_front()


## Sizes the window's parts for a screen `screen` UI pixels large (a list's height); the
## panel is placed after.
func layout(_screen: Vector2) -> void:
	pass


## What «Назад» and Escape do.
func back() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back()
