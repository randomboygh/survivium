extends Node3D
## The text of the signs (Placed.is_sign, decision 183) shown over them to those within
## Placed.SIGN_READ cells of a sign, drawn like the notices (HudMessages.toast): the same
## framed panel and letters, over the interface, its bottom middle at the sign's top as
## it is on the screen. A panel for each sign written, shown while the player is near
## (looked for a few times a second) and moved with the view each frame. A sign written
## anew or turned comes back as a thing placed anew (Placed.write), so the panel follows
## the records the copy of the things (RemotePlaced) tells of. `game` is the Main node.
## While a sign's window is open, none shows. A cross (Placed.is_grave) shows who died
## there the same way (DeathScreen.grave_text), in the language in use.

const Placed := preload("res://src/shared/game/placed.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")
const DeathScreen := preload("res://src/client/ui/death_screen.gd")

const CELL := WorldData.CELL
## How far over the sign's top the panel's bottom stands (world units).
const TEXT_OVER := 0.12
## Seconds between looks at which signs are near.
const LOOK_EVERY := 0.15

var game
## The panels of the signs written by their north-west cell: {"e": the record, "panel":
## PanelContainer, "at": the middle of the sign's top, "mid": its middle (world)}.
var signs := {}
## The layer the panels are on: the whole interface, under its other parts.
var _layer: Control
var _clock := 0.0


## Shows the signs of `placed` (the client's copy of the things) as they come and go.
func watch(placed) -> void:
	placed.added.connect(_on_added)
	placed.removed.connect(_on_removed)
	for e: Dictionary in placed.things:
		_on_added(e)


func _layer_made() -> Control:
	if _layer == null:
		_layer = Control.new()
		_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		game.hud.add_child(_layer)
		game.hud.move_child(_layer, 0)
	return _layer


func _exit_tree() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null


func _on_added(e: Dictionary) -> void:
	var grave := Placed.is_grave(e) and e.get("grave") is Dictionary
	if not grave and (not Placed.is_sign(e) or e.get("text", "") == ""):
		return
	_on_removed(e)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiStyle.label(DeathScreen.grave_text(e.grave) if grave else e.text)
	# The sign's words as written; a cross's are put in the language already.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	panel.visible = false
	_layer_made().add_child(panel)
	var mid := Placed.center(e)
	var at := Vector3(mid.x, (e.cell.y + _top(e)) * CELL + TEXT_OVER, mid.z)
	signs[e.cell] = {"e": e, "panel": panel, "at": at, "mid": mid}


func _on_removed(e: Dictionary) -> void:
	var one: Dictionary = signs.get(e.cell, {})
	if one.is_empty():
		return
	one.panel.queue_free()
	signs.erase(e.cell)


## How many cells high sign `e` stands: the top of its solid boxes.
func _top(e: Dictionary) -> float:
	var top := 1.0
	for box in game.placed.boxes_of(e):
		for b: AABB in (box if box is Array else [box]):
			top = maxf(top, b.end.y)
	return top


func _process(delta: float) -> void:
	if signs.is_empty() or game.player == null:
		return
	_clock += delta
	if _clock >= LOOK_EVERY:
		_clock = 0.0
		_look()
	var t := _layer.get_global_transform()
	for cell in signs:
		var one: Dictionary = signs[cell]
		var panel: PanelContainer = one.panel
		if panel.visible:
			panel.reset_size()
			var at: Vector2 = (game.view.screen_of(one.at) - t.origin) / t.get_scale()
			panel.position = (at - Vector2(panel.size.x * 0.5, panel.size.y)).floor()


## Shows the panels of the signs near the player.
func _look() -> void:
	var p: Vector3 = game.player.position
	var reach := Placed.SIGN_READ * CELL
	# A sign's window shows the text itself (and the panels would show over its shade).
	var open: bool = game.hud != null and game.hud.sign_window != null
	for cell in signs:
		var one: Dictionary = signs[cell]
		var d: Vector3 = one.mid - p
		one.panel.visible = not open and Vector2(d.x, d.z).length() <= reach and absf(d.y) <= reach
