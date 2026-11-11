extends RefCounted
## Buttons that ask first (part of the UI kit, kit.gd): the first tap on one turns it red
## (UiStyle.arm), the second does what it does; a tap on another of the same group asks
## with that one instead. With `wait` the red goes out by itself after that many
## seconds. The trash of a saved world or server and of the build and farming modes'
## marks, «Очистить все данные».

const UiStyle := preload("res://src/client/ui/ui_style.gd")

## Seconds a button stays red waiting for its second tap; 0: until another is tapped.
var wait := 0.0
## The button waiting for its second tap, or null.
var armed: Button = null
## How a button shows it waits, `paint(b, on)`; none: red (UiStyle.arm). The mode
## bars light theirs as their tabs (TabRow.light).
var paint := Callable()


func _init(seconds := 0.0) -> void:
	wait = seconds


## Whether this tap on `b` is its second (then it is put back and the caller acts); else
## `b` turns red and waits, the one waiting before put back.
func ask(b: Button) -> bool:
	if is_instance_valid(armed) and armed == b:
		disarm()
		return true
	disarm()
	armed = b
	_paint(b, true)
	if wait > 0.0 and b.is_inside_tree():
		b.get_tree().create_timer(wait, true).timeout.connect(_expire.bind(b))
	return false


## Makes `b` ask before `action`: its press calls `action` on the second tap only.
func guard(b: Button, action: Callable) -> Button:
	b.pressed.connect(_guarded.bind(b, action))
	return b


## Puts the button waiting back to its look.
func disarm() -> void:
	if is_instance_valid(armed):
		_paint(armed, false)
	armed = null


func _guarded(b: Button, action: Callable) -> void:
	if ask(b):
		action.call()


func _expire(b: Button) -> void:
	if is_instance_valid(armed) and armed == b:
		disarm()


func _paint(b: Button, on: bool) -> void:
	if paint.is_valid():
		paint.call(b, on)
	else:
		UiStyle.arm(b, on)
