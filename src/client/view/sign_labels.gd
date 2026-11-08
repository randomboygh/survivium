extends Node3D
## The text of the signs (Placed.is_sign, decision 183) hung over them, in the letters of
## the names over the players, to those within Placed.SIGN_READ cells of a sign: a label
## for each sign written, shown while the player is near, looked for a few times a second.
## A sign written anew or turned comes back as a thing placed anew (Placed.write), so the
## label follows the records the copy of the things (RemotePlaced) tells of. `game` is
## the Main node. While a sign's window is open, none shows.

const Placed := preload("res://src/shared/game/placed.gd")
const PixelView := preload("res://src/client/view/pixel_view.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const UiStyle := preload("res://src/client/ui/ui_style.gd")

const CELL := WorldData.CELL
## The letters' size in world pixels, and how far over the sign's top the text's lowest
## line hangs (world units).
const TEXT_SIZE := 8
const TEXT_OVER := 0.12
## Seconds between looks at which signs are near.
const LOOK_EVERY := 0.15

var game
## The labels of the signs written by their north-west cell: {"e": the record, "label": Label3D}.
var signs := {}
var _clock := 0.0


## Shows the signs of `placed` (the client's copy of the things) as they come and go.
func watch(placed) -> void:
	placed.added.connect(_on_added)
	placed.removed.connect(_on_removed)
	for e: Dictionary in placed.things:
		_on_added(e)


func _on_added(e: Dictionary) -> void:
	if not Placed.is_sign(e) or e.get("text", "") == "":
		return
	_on_removed(e)
	var label := Label3D.new()
	label.font = UiStyle.font()
	label.font_size = TEXT_SIZE
	label.outline_size = 4
	label.modulate = UiStyle.INK
	label.pixel_size = 1.0 / PixelView.PIXELS_PER_UNIT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.render_priority = 2
	label.top_level = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.text = e.text
	label.visible = false
	add_child(label)
	var mid := Placed.center(e)
	var at := Vector3(mid.x, (e.cell.y + _top(e)) * CELL + TEXT_OVER, mid.z)
	label.position = PixelView.shear(at)
	signs[e.cell] = {"e": e, "label": label, "at": mid}


func _on_removed(e: Dictionary) -> void:
	var one: Dictionary = signs.get(e.cell, {})
	if one.is_empty():
		return
	one.label.queue_free()
	signs.erase(e.cell)


## How many cells high sign `e` stands: the top of its solid boxes.
func _top(e: Dictionary) -> float:
	var top := 1.0
	for box in game.placed.boxes_of(e):
		for b: AABB in (box if box is Array else [box]):
			top = maxf(top, b.end.y)
	return top


func _process(delta: float) -> void:
	_clock += delta
	if _clock < LOOK_EVERY or signs.is_empty() or game.player == null:
		return
	_clock = 0.0
	var p: Vector3 = game.player.position
	var reach := Placed.SIGN_READ * CELL
	# A sign's window shows the text itself (and the labels would show over its shade).
	var open: bool = game.hud != null and game.hud.sign_window != null
	for cell in signs:
		var one: Dictionary = signs[cell]
		var d: Vector3 = one.at - p
		one.label.visible = not open and Vector2(d.x, d.z).length() <= reach and absf(d.y) <= reach
