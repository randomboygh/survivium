extends Node
## The server's loop in the scene tree (plan/architecture/server.md, С2.3): a node under
## the tree's root, not under the client's scene, so the world goes on while the client
## restarts its scene (a server made from the menu, С5). Every frame, before the
## client's own work (process_priority), it ticks the session's steps and has the world
## made around the players (Session.make_chunks) within the budgets the client gives it
## (near_us, far_us), then forgets the far chunks. In single player the game's pause
## (its menu open) stops the tick but not the making of the world, which reaches
## farther then (PAUSE_ZONE); a server's world never pauses (`pausable`). What each
## step took is kept for the client's statistics (took_us).

const Session := preload("res://src/shared/game/session.gd")

## Microseconds a frame may generate by default: a server without a client to tell it.
const BUDGET_US := 8000

var session: Session
## The game's pause stops the tick (single player); false on a server.
var pausable := true
## The players are in the world: the characters, the animals and the wind step. Before
## that (the world being made ready) only the clock goes.
var playing := false
## Microseconds a frame generation may take: when the chunk being made is within
## Session.NEAR of a player, and when farther (see Session.make_chunks).
var near_us := BUDGET_US
var far_us := BUDGET_US
## Microseconds the last frame spent making the world (take_spent gives them once),
## and what each step of the tick took, by step: "clock", "players", "wildlife",
## "storms".
var spent_us := 0
var took_us := {}


func _init(s: Session) -> void:
	session = s
	name = "ServerRunner"
	process_mode = PROCESS_MODE_ALWAYS
	process_priority = -10


func _process(delta: float) -> void:
	var paused := pausable and is_inside_tree() and get_tree().paused
	took_us.clear()
	if not paused:
		var t := Time.get_ticks_usec()
		session.step_clock(delta)
		t = _took("clock", t)
		if playing:
			session.step_players(delta)
			t = _took("players", t)
			session.step_wildlife(delta)
			t = _took("wildlife", t)
			session.step_storms(delta)
			_took("storms", t)
	var t0 := Time.get_ticks_usec()
	session.make_chunks(near_us, far_us, Session.PAUSE_ZONE if paused else Session.ZONE)
	session.forget_far()
	spent_us += Time.get_ticks_usec() - t0


func _took(step: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	took_us[step] = now - since
	return now


## The time spent making the world since the last call, and the count starts anew.
func take_spent() -> int:
	var spent := spent_us
	spent_us = 0
	return spent
