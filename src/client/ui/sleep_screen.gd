extends Control
## The screen while the character sleeps (Vitals.asleep): clear, over the picture the
## camera dreams (CameraRig.dream). A tap anywhere, a step of the stick or the keys, or
## the jump wakes them (Protocol.SLEEP); with every player asleep the night goes by fast
## (Session.sleep_speed). Built by the HUD, which runs it every frame.

const Protocol := preload("res://src/shared/net/protocol.gd")

## Seconds between two asks to wake, while the answer is on its way.
const ASK_AGAIN := 0.5

var game
var _wait := 0.0


func _init(g) -> void:
	game = g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
