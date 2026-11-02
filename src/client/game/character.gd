extends "res://src/shared/game/character.gd"
## The player's character on this device: the client's copy of the one on the server
## (Player in src/server, fed by the server's events through Mirror: the bag, the body's
## state, death), and the one who acts for what the client reads of the rules itself
## (the cursor's preview): the body is the player's node, the hands are the controls'.
## It runs no rule: what it speaks (say) and a death (the player hidden behind the
## death screen, DeathScreen) come from the server. The playtest page can take them to
## any column (go_to_column). `game` is the Main node.

const WorldGen := preload("res://src/shared/world/world_gen.gd")

var game
## The column the player was taken to, held there until its chunk is made; else null.
var arriving: Variant = null


func _init(g) -> void:
	super()
	game = g


func _where() -> Vector3:
	return game.player.position


## Says `text` under the clock at once.
func say(text: String) -> void:
	game.hud.toast(text)


## Takes the state a YOU event gives (see PlayerLink.flush): the bag, the body's state,
## death and the life's statistics, home, where things were thrown.
func take(d: Dictionary) -> void:
	var was_dead := is_dead()
	if d.get("vitals") is Array:
		take_vitals(d.vitals)
	if d.get("state") is Dictionary:
		from_dict(d.state)
	if d.get("home") is Vector3:
		home = d.home
	held_back.clear()
	for p in d.get("held_back", []):
		if p is Vector3:
			held_back.append(p)
	if is_dead() and not was_dead:
		_fell()
		game.save.flush()
	# The bag last: its `changed` tells the state changed (see _on_bag_changed), once.
	if d.get("inventory") is Dictionary:
		inventory.from_dict(d.inventory)
	elif is_dead() != was_dead:
		state_changed.emit()


## Takes the body's state a VITALS event gives.
func take_vitals(v: Array) -> void:
	if v.size() != 7:
		return
	vitals.health = float(v[0])
	vitals.satiety = float(v[1])
	vitals.stamina = float(v[2])
	vitals.hunger = bool(v[3])
	vitals.hurt_by = str(v[4])
	vitals.warmth = float(v[5])
	vitals.wet = float(v[6])


func _fell() -> void:
	game.player.visible = false
	if game.hud.bag.visible:
		game.hud.toggle_bag()


## Takes the player to column `cell` (the playtest page): over the ground as the
## generator lays it out, held there until the chunk is made, then onto level grass
## near it (see WorldGen.find_spawn), or onto the water where there is none.
func go_to_column(cell: Vector2i) -> void:
	var lay: Dictionary = game.gen.lay_out(cell.x, cell.y, 1, 1)
	var y := maxi(int(lay.heights[0]), int(lay.water[0])) + 2
	game.player.position = Vector3(cell.x + 0.5, y, cell.y + 0.5) * CELL
	game.player.body.velocity_y = 0.0
	arriving = cell
	game.view.look_at_player()


## The copy runs no rule (the server does); it only puts the player down where
## go_to_column took them.
func update(_delta: float) -> void:
	if arriving != null:
		_arrive()


## Holds the player over the column go_to_column took them to until its chunk is made,
## then puts them down.
func _arrive() -> void:
	var cell: Vector2i = arriving
	var c: WorldData.Chunk = world.chunk_at(cell.x, cell.y)
	if c == null or not c.final:
		game.player.position = Vector3(cell.x + 0.5, game.player.position.y / CELL, cell.y + 0.5) * CELL
		game.player.body.velocity_y = 0.0
		return
	arriving = null
	var spot: Vector3i = WorldGen.find_spawn(world, Vector3i(cell.x, 0, cell.y))
	if spot.y < world.size_y - 1:
		game.player.position = (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL
	_last_at = Vector3.INF
	game.view.look_at_player()


## Puts the body at `at` (world units) at once, the view with it.
func teleport(at: Vector3) -> void:
	game.player.position = at
	body.velocity_y = 0.0
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


func in_hands() -> Array:
	return game.controls.hands


## The record of what the hand in use holds as a tool (see Tools.of).
func tool() -> Dictionary:
	return game.controls.tool_record()


## The brush blocks are placed with (one of Tools.BRUSHES).
func brush() -> Dictionary:
	return game.controls.brush_record()


## A swing of the tool in use wears it on the server (Player.use_tool); the copy's
## tools wear by its events.
func use_tool() -> void:
	pass
