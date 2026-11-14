extends RefCounted
## What the game's own bot (src/client/input/bot.gd, a client that plays itself) and the
## bot the server plays (src/server/server_bot.gd) share, so the two keep the same pace,
## tasks and lines: how far a bot walks and looks, how long a task goes on, how often
## each task is taken, what it says and writes, and the state of the task going on. Each
## bot adds how it acts: the first through the game's controls and requests, the second
## on its character on the server.

const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")

## How far from its spawn a bot walks about, and looks for a tree or an animal, in cells.
const WANDER := 12.0
const LOOK := 28.0
## Close enough to a point walked to, and to a tree or an animal to work at, in cells.
const ARRIVE := 0.8
const REACH := 1.3
## The longest a task goes on, in seconds; the pause between two tasks.
const TASK_MOST := 25.0
const PAUSE := Vector2(1.0, 4.0)
## The seconds between two swings asked for (the server paces them anyway).
const SWING_EVERY := 0.6
## Seconds before it accepts an invitation to a team.
const INVITE_WAIT := 2.0
## Seconds dead before it comes back.
const DEAD_WAIT := 6.0
## What it does and how often (weights).
const TASKS := {"walk": 5, "say": 2, "gesture": 2, "drop": 1, "sign": 1, "fire": 1, "chop": 2, "hunt": 3}
## What it says in the chat and writes on signs: keys, which each reader's game puts
## into its own language (Lang.written), as a player's words are not.
const LINES: Array[String] = ["[hi]", "[anyone_here]", "[look_what_i_found]", "[lets_go_to_the_river]",
	"[wolves_here_careful]", "[nice_weather]", "[i_put_up_a_sign]", "[need_branches]",
	"[lets_build_a_house]", "[wheres_the_campfire]", "[im_a_bot_but_im]"]
const SIGN_LINES: Array[String] = ["[a_bot_was_here]", "[beware_of_animals]", "[camp]", "[to_the_river]",
	"[do_not_cut]"]

## The task going on ("" between two), the seconds left of it and of the pause, where it
## walks to, the tree and the animal it works at.
var task := ""
var _left := 0.0
var _pause := 1.0
var _target := Vector3.INF
var _tree := Vector2i.ZERO
var _animal := 0
var _swing_in := 0.0
var _dead_for := 0.0
var _invited_for := 0.0
var _home := Vector3.INF
var _rng := RandomNumberGenerator.new()
## The item ids it works with, found by role: axe, weapon, sign, campfire.
var _axe := ""
var _weapon := ""
var _sign := ""
var _fire := ""
## Where it last was, to tell it is stuck.
var _last_pos := Vector3.INF
var _still := 0.0
var _stuck := 0
var _missed := 0


## The next task, by the weights of TASKS.
func _pick() -> String:
	var total := 0
	for k: String in TASKS:
		total += TASKS[k]
	var roll := _rng.randi_range(1, total)
	for k: String in TASKS:
		roll -= TASKS[k]
		if roll <= 0:
			return k
	return "walk"


## The task is over: a pause before the next.
func _stop() -> Vector2:
	task = ""
	_pause = _rng.randf_range(PAUSE.x, PAUSE.y)
	_still = 0.0
	_stuck = 0
	_missed = 0
	_last_pos = Vector3.INF
	return Vector2.ZERO


## The strongest blade of the world struck with (Tools.weapon), "" for none: a spear in
## hand is thrown, what shoots needs its ammunition too.
static func best_weapon() -> String:
	var best := ""
	var most := -1.0
	for id: String in Items.IDS:
		var w: Dictionary = Tools.weapon(id)
		if not w.is_empty() and w.tool in ["sword", "knife"] and float(w.get("power", 0)) > most:
			most = float(w.get("power", 0))
			best = id
	return best
