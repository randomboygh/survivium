extends ColorRect
## The screen while the character sleeps (Vitals.asleep): the game dimmed behind a line
## that says how to wake. A tap anywhere, a step of the stick or the keys, or the jump
## wakes them (Protocol.SLEEP); with every player asleep the night goes by fast
## (Session.sleep_speed). Built by the HUD, which runs it every frame.

const UiStyle := preload("res://src/client/ui/ui_style.gd")
const Protocol := preload("res://src/shared/net/protocol.gd")

## How dark the game is behind it.
const SHADE := Color(0.02, 0.02, 0.06, 0.6)
## Seconds between two asks to wake, while the answer is on its way.
const ASK_AGAIN := 0.5

var game
var _line: Label
var _wait := 0.0


func _init(g) -> void:
	game = g


func _ready() -> void:
	color = SHADE
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A panel a third of the way down, clear of the hotbar.
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_right = 1.0
	box.anchor_top = 0.25
	box.anchor_bottom = 0.45
	add_child(box)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.TIGHT))
	box.add_child(panel)
	_line = UiStyle.label("[sleeping_touch_the_screen_to]")
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_line)
	visible = false


## Shown while asleep; a step or a jump wakes.
func update(delta: float) -> void:
	_wait = maxf(0.0, _wait - delta)
	visible = game.character.vitals.asleep and not game.character.is_dead()
	if visible and (game.controls.read_move().length() > 0.1 or game.controls.jump()):
		wake()


func wake() -> void:
	if _wait > 0.0:
		return
	_wait = ASK_AGAIN
	game.net.request(Protocol.SLEEP, [false])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		accept_event()
		wake()
