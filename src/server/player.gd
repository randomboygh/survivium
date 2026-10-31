extends "res://src/shared/game/character.gd"
## A player's character on the server (plan/architecture/server.md, decision 153): the
## one acting (`who`) for the rules, with the body and the hands as the client last
## told them (Protocol.INPUT: the client moves its own body, 3А; the server's check of
## that movement comes at stage С3). What it says, lays down or is done to it goes out
## as signals its link turns into events for the client's copy (PlayerLink).

const Tools := preload("res://src/shared/content/tools.gd")
const BodyScript := preload("res://src/shared/game/body.gd")

## A line for the player (say).
signal said(text: String)
## Things laid on the ground in chunk `key` (lay).
signal laid(key: Vector2i)
## The body is put at `at` (coming back to life).
signal moved(at: Vector3)
## The body is thrown (a burning campfire).
signal knocked(dir: Vector2, speed: float, hop: float)
## A swing of the tool in use wears it (Workshop.use_tool; the player does not hold
## the workshop, which holds the player).
signal tool_used
## Where the body is, in world units, and the cell its feet are in.
var at := Vector3.ZERO
var feet_cell := Vector3i.ZERO
var facing := Vector2i(0, 1)
## What each hand holds and which hand is in use.
var hands := ["", ""]
var active := 0
var brush_i := 0
var is_moving := false


## The server's stand-in for the client's body: what the rules read of it comes with
## INPUT; a knock goes back to the client as an event (a signal, not a reference back
## to the player: that would be a cycle never freed).
class ServerBody extends "res://src/shared/game/body.gd":
	signal thrown(dir: Vector2, speed: float, hop: float)

	func knock(dir: Vector2, speed: float, hop: float) -> void:
		thrown.emit(dir, speed, hop)


func _init() -> void:
	super()
	var b := ServerBody.new()
	b.thrown.connect(_on_thrown)
	body = b


func _on_thrown(dir: Vector2, speed: float, hop: float) -> void:
	knocked.emit(dir, speed, hop)


## Takes the client's body and hands from an INPUT event's `args`.
func take_input(args: Array) -> void:
	if args.size() != 11 or not args[0] is Vector3 or not args[1] is Vector3i or not args[2] is Vector2i \
			or not args[3] is Array or args[3].size() != 2 or not args[4] is int or not args[5] is int:
		return
	at = args[0]
	feet_cell = args[1]
	facing = args[2]
	hands = [str(args[3][0]), str(args[3][1])]
	active = clampi(args[4], 0, 1)
	brush_i = clampi(args[5], 0, Tools.BRUSHES.size() - 1)
	is_moving = bool(args[6])
	body.swimming = bool(args[7])
	body.jumped = bool(args[8])
	body.air_jumps = bool(args[9])
	body.bumped = args[10] if args[10] is Vector3 else Vector3.INF


func _where() -> Vector3:
	return at


func say(text: String) -> void:
	said.emit(text)


func lay(kind: String, data: Variant) -> Vector3:
	var p := super.lay(kind, data)
	laid.emit(WorldData.chunk_key(floori(p.x / CELL), floori(p.z / CELL)))
	return p


func _came_back(to: Vector3) -> void:
	at = to
	moved.emit(to)


## Puts the body at `to` (the playtest page, the save).
func teleport(to: Vector3) -> void:
	at = to
	moved.emit(to)


# --- What the rules ask of the one who acts (see WorldActions) ----------------------

func feet() -> Vector3i:
	return feet_cell


func facing_step() -> Vector2i:
	return facing


func moving() -> bool:
	return is_moving


func overlaps_cell(cell: Vector3i) -> bool:
	return BodyScript.overlaps(at, cell)


func held() -> String:
	return hands[active]


func in_hands() -> Array:
	return hands


func tool() -> Dictionary:
	return Tools.of(held())


func brush() -> Dictionary:
	return Tools.BRUSHES[brush_i]


func use_tool() -> void:
	tool_used.emit()
