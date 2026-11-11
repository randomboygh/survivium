extends Control
## A window of the UI kit (kit.gd): it covers the whole screen over a shade of what is
## behind, its panel in the middle, or at the top when the panel is taller than the
## screen (the phone's keyboard is up). A window extends this script, calls `build` in
## its `_ready` with its title, adds its parts to `box` and calls `show_fitted` last;
## it lays its parts out for the screen in `layout` and does in `back` what its «Назад»
## does (Escape too). The parent is the screen: its size, in UI pixels, is the window's.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Kit := preload("res://src/client/ui/kit/kit.gd")

## The shade over what is behind.
const BACKDROP := Color(0.03, 0.03, 0.04, 0.55)
## The room kept round the panel.
const MARGIN := 8

## The panel and the column of the window's parts in it.
var panel: PanelContainer
var box: VBoxContainer


## Makes the panel with `heading` on top (none when empty), its parts `gap` apart, and
## returns the column to add them to.
func build(heading := "", gap := 6) -> VBoxContainer:
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	add_child(panel)
	box = Kit.column(gap)
	panel.add_child(box)
	if heading != "":
		box.add_child(Kit.title(heading))
	return box


## Lays the window out now and again whenever the screen changes size.
func show_fitted() -> void:
	get_parent().resized.connect(fit)
	fit()


## Covers the screen, lets the window lay its parts out (`layout`) and places the panel.
func fit() -> void:
	var screen: Vector2 = get_parent().size
	position = Vector2.ZERO
	size = screen
	layout(screen)
	panel.reset_size()
	var s := panel.size
	panel.position = Vector2(floorf((screen.x - s.x) * 0.5),
		floorf((screen.y - s.y) * 0.5) if s.y + 2 * MARGIN <= screen.y else float(MARGIN))
	move_to_front()
	queue_redraw()


## Sizes the window's parts for a screen `screen` UI pixels large (a list's height); the
## panel is placed after.
func layout(_screen: Vector2) -> void:
	pass


## What «Назад» and Escape do.
func back() -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back()
