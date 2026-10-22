extends "res://src/shared/game/character.gd"
## The player's character (Character, src/shared: the bag, the body's state, what
## actions cost, death) on this device: the body is the player's node, the hands are
## the controls', it speaks in lines under the clock, and a death hides the player
## behind the death screen (DeathScreen) and is saved at once. `game` is the Main node.

var game


func _init(g) -> void:
	super()
	game = g


func _where() -> Vector3:
	return game.player.position


## Says `text` under the clock at once.
func say(text: String) -> void:
	game.hud.toast(text)


func lay(kind: String, data: Variant) -> Vector3:
	var at := super.lay(kind, data)
	game.props.show_drops(WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)))
	return at


func die() -> void:
	super.die()
	game.save.flush()


func _fell() -> void:
	game.player.visible = false
	if game.hud.bag.visible:
		game.hud.toggle_bag()


func _came_back(at: Vector3) -> void:
	game.player.position = at
	game.player.visible = true
	game.view.look_at_player()


# --- What the rules ask of the one who acts (see WorldActions) ----------------------

## The cell the feet are in.
func feet() -> Vector3i:
	return game.controls.feet()


## The column step the body faces (one of 8 ways).
func facing_step() -> Vector2i:
	return game.controls.step()


func moving() -> bool:
	return game.player.body.move_input.length() > 0.1


func overlaps_cell(cell: Vector3i) -> bool:
	return game.player.overlaps_cell(cell)


## The item in the hand in use, "" for nothing.
func held() -> String:
	return game.controls.held()


## The record of what the hand in use holds as a tool (see Tools.of).
func tool() -> Dictionary:
	return game.controls.tool_record()


## The brush blocks are placed with (one of Tools.BRUSHES).
func brush() -> Dictionary:
	return game.controls.brush_record()


## A swing of the tool in use wears it (see Workshop.use_tool).
func use_tool() -> void:
	game.workshop.use_tool()
