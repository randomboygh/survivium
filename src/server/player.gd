extends "res://src/shared/game/character.gd"
## A player's character on the server (plan/architecture/server.md, decision 153): the
## one acting (`who`) for the rules, with the body and the hands as the client last
## told them (Protocol.INPUT: the client moves its own body, 3А). Over a socket the
## position told is checked (С3.3): the server's body is run towards it with the world's
## rules (walls, slopes, water, the pace of the load and the weather), and a claim
## farther than MOVE_TOLERANCE from where it got is not taken; after STRIKES refused in
## a row the client is put where the server's body is (`moved`, TELEPORT). What it
## says, lays down or is done to it goes out as signals its link turns into events for
## the client's copy (PlayerLink).

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
## Cells a claim may part from the server's body by; claims refused in a row before the
## client is put back; the longest a step of the check covers (a claim long after the
## last is not run as one leap).
const MOVE_TOLERANCE := 2.5
const STRIKES := 10
const CLAIM_GAP_MAX := 0.5

## The player's number and name on the server (the account's), told to the others.
var id := 0
var player_name := ""
## Over a socket the body told is checked (see above); over the loop it is taken as is.
var check_moves := false
## Where the body is, in world units, and the cell its feet are in.
var at := Vector3.ZERO
var feet_cell := Vector3i.ZERO
var facing := Vector2i(0, 1)
## What each hand holds and which hand is in use.
var hands := ["", ""]
var active := 0
var brush_i := 0
var is_moving := false
var on_ground := true
## The work the hands do, as the client tells it: [kind, length, count, at].
var work: Array = ["", 0.0, 0, Vector3.INF]
var _claim_at := -1.0
var _strikes := 0


## The server's stand-in for the client's body: what the rules read of it comes with
## INPUT; a knock goes back to the client as an event (a signal, not a reference back
## to the player: that would be a cycle never freed).
class ServerBody extends "res://src/shared/game/body.gd":
	signal thrown(dir: Vector2, speed: float, hop: float)

	func knock(dir: Vector2, speed: float, hop: float) -> void:
		super(dir, speed, hop)
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
	if args.size() != 18 or not args[0] is Vector3 or not args[1] is Vector3i or not args[2] is Vector2i \
			or not args[3] is Array or args[3].size() != 2 or not args[4] is int or not args[5] is int \
			or not args[11] is Vector2 or not args[12] is Vector2 or not args[16] is int \
			or not (args[6] is bool and args[7] is bool and args[8] is bool and args[9] is bool and args[13] is bool) \
			or not (args[15] is float or args[15] is int):
		# A malformed INPUT is left out whole, before any of it is taken.
		return
	var claim: Vector3 = args[0]
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
	view_right = args[11].normalized() if args[11].length_squared() > 0.5 else Vector2(1.0, 0.0)
	view_half = args[12].abs()
	on_ground = bool(args[13])
	work = [str(args[14]), float(args[15]), args[16], args[17] if args[17] is Vector3 else Vector3.INF]
	if check_moves and body.world != null:
		_take_claim(claim, bool(args[8]))
	else:
		at = claim


## Runs the server's body from `at` towards `claim` for the time since the last claim
## (3А) and takes the claim if the body got near it; else the body's place is the
## player's, and after STRIKES such claims the client is told to come there.
func _take_claim(claim: Vector3, jumped_told: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - _claim_at, 1.0 / 60.0, CLAIM_GAP_MAX) if _claim_at >= 0.0 else 1.0 / 60.0
	_claim_at = now
	var to := Vector2(claim.x - at.x, claim.z - at.z) / CELL
	var reach: float = body.speed_at(at) * dt
	body.move_input = (to / reach).limit_length(1.0) if reach > 0.0 else Vector2.ZERO
	var jump: bool = jumped_told or (claim.y > at.y + 0.01 * CELL and body.on_ground)
	var got: Vector3 = body.step(at, dt, jump)
	# The jumps counted and paid for are the client's (Character.update).
	body.jumped = jumped_told
	if got.distance_to(claim) <= MOVE_TOLERANCE * CELL:
		at = claim
		_strikes = 0
		return
	at = got
	_strikes += 1
	if _strikes >= STRIKES:
		_strikes = 0
		moved.emit(at)


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
	_strikes = 0
	_claim_at = -1.0
	body.velocity_y = 0.0
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
