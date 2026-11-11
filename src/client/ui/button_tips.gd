extends Control
## The hints of the interface's buttons with a mouse: the tooltip of the control under the
## pointer (its tooltip_text, or what its get_tooltip says there), shown after DELAY
## seconds beside the pointer in the same panel and at the same scale as the hint over
## the ground (Hud.show_tip), over every window and the main menu. Godot's own tooltips
## are off (`gui/timers/tooltip_delay_sec` in project.godot): they came at the screen's
## own pixel size, unlike the rest of the interface. Nothing shows on a touch screen, nor
## for a button whose hint says only what its label already says («Назад»). `game` is the
## Main node.

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Seconds the pointer rests on a control before its hint shows.
const DELAY := 0.45
## The hint sits this far right of and below the pointer, in UI pixels (as Hud.show_tip).
const OFFSET := Vector2(12, 8)

var game
var _panel: PanelContainer
var _label: Label
## The control the pointer is on and its hint, and how long it has rested there.
var _over: Control = null
var _text := ""
var _rest := 0.0
## A click hides the hint until the pointer goes to another control.
var _clicked := false


func _init(g) -> void:
	game = g
	name = "ButtonTips"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiStyle.label()
	_panel.add_child(_label)
	_panel.visible = false
	add_child(_panel)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_clicked = true
		_panel.visible = false


func _process(delta: float) -> void:
	var c: Control = null
	if not _touch():
		c = get_viewport().gui_get_hovered_control()
	var text := _tip_of(c)
	if c != _over or text != _text:
		if c != _over:
			_clicked = false
		_over = c
		_text = text
		_rest = 0.0
		_panel.visible = false
	if _text == "" or _clicked:
		return
	_rest += delta
	if _rest >= DELAY:
		_show(get_viewport().get_mouse_position())


## The hint of control `c` where the pointer is on it; empty for none, or for a button
## whose label says the same.
func _tip_of(c: Control) -> String:
	if c == null or not c.is_visible_in_tree():
		return ""
	var text := c.get_tooltip(c.get_local_mouse_position()).strip_edges()
	if c is Button and text == (c as Button).text.strip_edges():
		return ""
	return text


func _show(screen_pos: Vector2) -> void:
	var s := _scale()
	scale = Vector2(s, s)
	size = (get_viewport_rect().size / s).floor()
	_label.text = _text
	_panel.visible = true
	_panel.reset_size()
	var p := (screen_pos / s + OFFSET).floor()
	# Beside the pointer, kept on the screen: to its left or above it near an edge.
	if p.x + _panel.size.x > size.x - 2:
		p.x = screen_pos.x / s - _panel.size.x - 4
	if p.y + _panel.size.y > size.y - 2:
		p.y = screen_pos.y / s - _panel.size.y - 4
	_panel.position = p.clamp(Vector2.ZERO, (size - _panel.size).max(Vector2.ZERO)).floor()


## The interface's scale: the HUD's, as the hint over the ground has it.
func _scale() -> float:
	if game.hud != null and game.hud.scale.x > 0.0:
		return game.hud.scale.x
	return 1.0


func _touch() -> bool:
	return game.controls == null or game.controls.touch
