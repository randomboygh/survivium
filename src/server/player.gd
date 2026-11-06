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
const Protocol := preload("res://src/shared/net/protocol.gd")
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
## How fast (cells a second) and how far at most (cells) the server's body is drawn
## towards the claims it took but did not reach itself (the two bodies part a little on
## ice, at corners, in a crowd): so a client that keeps claiming more than its legs give
## gains no more than this, however many claims it sends (a claim is run for the time
## since the last one, never for more than passed).
const CATCH_UP := 2.0
const CATCH_UP_MAX := 2.5
## Half the screen a client may say it has, at most (world units; Wildlife.NEAR is 28).
const VIEW_MAX := 64.0

## The player's number and name on the server (the account's), told to the others.
var id := 0
var player_name := ""
## Over a socket the body told is checked (see above), and so are the hands (only what
## the bag holds is held, see in_hands), the feet (the cell of the body taken), the way
## the body faces (one of 8 steps) and the playtest's air jumps (none); over the loop it
## is all taken as is (one process: the player is the server's own).
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
## Where the server's own body is (world units; INF: not run yet, at `at`), and the
## cells it may still be drawn towards the claims (CATCH_UP).
var _sim := Vector3.INF
var _credit := CATCH_UP_MAX
## Claims refused since joining (for the server's log of what looks wrong).
var refused_moves := 0


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
	if args.size() != Protocol.INPUT_SIZE or not args[0] is Vector3 or not args[1] is Vector3i or not args[2] is Vector2i \
			or not args[3] is Array or args[3].size() != 2 or not args[4] is int or not args[5] is int \
			or not args[11] is Vector2 or not args[12] is Vector2 or not args[16] is int \
			or not (args[6] is bool and args[7] is bool and args[8] is bool and args[9] is bool and args[13] is bool) \
			or not (args[15] is float or args[15] is int):
		# A malformed INPUT is left out whole, before any of it is taken.
		return
	var claim: Vector3 = args[0]
	if check_moves and not (claim.is_finite() and args[11].is_finite() and args[12].is_finite()):
		return
	feet_cell = args[1]
	facing = args[2]
	if check_moves:
		facing = facing.clamp(-Vector2i.ONE, Vector2i.ONE)
	hands = [str(args[3][0]), str(args[3][1])]
	active = clampi(args[4], 0, 1)
	brush_i = clampi(args[5], 0, Tools.BRUSHES.size() - 1)
	is_moving = bool(args[6])
	body.swimming = bool(args[7])
	body.jumped = bool(args[8])
	# The playtest's jumps in the air are the server's own player's only.
	body.air_jumps = bool(args[9]) and not check_moves
	body.bumped = args[10] if args[10] is Vector3 and args[10].is_finite() else Vector3.INF
	view_right = args[11].normalized() if args[11].length_squared() > 0.5 else Vector2(1.0, 0.0)
	view_half = args[12].abs().min(Vector2(VIEW_MAX, VIEW_MAX)) if check_moves else args[12].abs()
	on_ground = bool(args[13])
	var length: float = float(args[15])
	work = [str(args[14]).left(32), length if is_finite(length) else 0.0, args[16],
		args[17] if args[17] is Vector3 and args[17].is_finite() else Vector3.INF]
	if check_moves and body.world != null:
		_take_claim(claim, bool(args[8]))
		# The feet are where the body taken is, whatever the client says.
		feet_cell = Vector3i(floori(at.x / CELL), BodyScript.level_at(at), floori(at.z / CELL))
	else:
		at = claim


## Runs the server's body from where it is towards `claim` for the time since the last
## claim (3А, never more than passed: claims sent faster go no farther) and takes the
## claim if the body got near it and the claim is not inside a wall; the body is then
## drawn towards it by what CATCH_UP has left. Else the body's place is the player's,
## and after STRIKES such claims the client is told to come there.
func _take_claim(claim: Vector3, jumped_told: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - _claim_at, 0.0, CLAIM_GAP_MAX) if _claim_at >= 0.0 else 1.0 / 60.0
	_claim_at = now
	if not _sim.is_finite():
		_sim = at
	_credit = minf(CATCH_UP_MAX * CELL, _credit + CATCH_UP * CELL * dt)
	var to := Vector2(claim.x - _sim.x, claim.z - _sim.z) / CELL
	var reach: float = body.speed_at(_sim) * dt
	body.move_input = (to / reach).limit_length(1.0) if reach > 0.0 else Vector2.ZERO
	var jump: bool = jumped_told or (claim.y > _sim.y + 0.01 * CELL and body.on_ground)
	var got: Vector3 = body.step(_sim, dt, jump) if dt > 0.0 else _sim
	# The jumps counted and paid for are the client's (Character.update).
	body.jumped = jumped_told
	var err := got.distance_to(claim)
	if err <= MOVE_TOLERANCE * CELL and not body.blocked(claim):
		at = claim
		var pull := minf(err, _credit)
		_credit -= pull
		_sim = got.move_toward(claim, pull)
		_strikes = 0
		return
	_sim = got
	at = got
	_strikes += 1
	refused_moves += 1
	if _strikes >= STRIKES:
		_strikes = 0
		moved.emit(at)


## The things in the hands that the bag holds (over a socket the client's word is not
## enough: a tool it does not have works as bare hands); one the bag holds one of is in
## the hand in use only, as on the client (Controls._check_hands).
func in_hands() -> Array:
	if not check_moves:
		return hands
	var out := [hands[0], hands[1]]
	for h in 2:
		if out[h] != "" and inventory.count(out[h]) == 0:
			out[h] = ""
	if out[0] != "" and out[0] == out[1] and inventory.count(out[0]) < 2:
		out[1 - active] = ""
	return out


func _where() -> Vector3:
	return at


func say(text: String) -> void:
	said.emit(text)


func lay(kind: String, data: Variant) -> Vector3:
	var p := super.lay(kind, data)
	laid.emit(WorldData.chunk_key(floori(p.x / CELL), floori(p.z / CELL)))
	return p


func _came_back(to: Vector3) -> void:
	teleport(to)


## Puts the body at `to` (the playtest page, the save).
func teleport(to: Vector3) -> void:
	at = to
	_sim = to
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
	return in_hands()[active]


func tool() -> Dictionary:
	return Tools.of(held())


func brush() -> Dictionary:
	return Tools.BRUSHES[brush_i]


func use_tool() -> void:
	tool_used.emit()
