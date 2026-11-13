extends RefCounted
## A bot the server plays itself (TestCommands, Server.add_bot): where no process of the
## game can be started for a bot (a server made on a phone), a player with no connection
## whose body the server walks and whose requests it makes, as the game's own bot does
## from a client (src/client/input/bot.gd: the same tasks, lines and pace). It walks
## about its spawn, talks in the chat, makes gestures, throws things out, sets signs down
## and writes on them, lights campfires, fells trees and hunts the animals near, accepts
## invitations to a team and comes back to life by itself. What it works with it is given
## (a test's bot, whatever the rules of free items say).

const Protocol := preload("res://src/shared/net/protocol.gd")
const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const Gestures := preload("res://src/shared/game/gestures.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const Body := preload("res://src/shared/game/body.gd")

const CELL := WorldData.CELL
## The longest step of the body in one go (a slow frame is cut into steps).
const STEP_MOST := 0.05
## How far from its spawn it walks about, and looks for a tree or an animal, in cells.
const WANDER := 12.0
const LOOK := 28.0
## Close enough to a point walked to, and to an animal to work at, in cells.
const ARRIVE := 0.8
const REACH := 1.3
## The longest a task goes on, in seconds; the pause between two tasks.
const TASK_MOST := 25.0
const PAUSE := Vector2(1.0, 4.0)
## The seconds between two swings asked for (the requests pace them anyway).
const SWING_EVERY := 0.6
## Seconds before it accepts an invitation to a team; dead before it comes back.
const INVITE_WAIT := 2.0
const DEAD_WAIT := 6.0
## The tasks and how often each is picked.
const TASKS := {"walk": 5, "say": 2, "gesture": 2, "drop": 1, "sign": 1, "fire": 1, "chop": 2, "hunt": 3}
## What it says and writes: the lines of the game's own bot (src/client/input/bot.gd).
const LINES: Array[String] = ["[hi]", "[anyone_here]", "[look_what_i_found]", "[lets_go_to_the_river]",
	"[wolves_here_careful]", "[nice_weather]", "[i_put_up_a_sign]", "[need_branches]", "Hello!",
	"[lets_build_a_house]", "[wheres_the_campfire]", "[im_a_bot_but_im]"]
const SIGN_LINES: Array[String] = ["[a_bot_was_here]", "[beware_of_animals]", "[camp]", "[to_the_river]",
	"[do_not_cut]", "[bot]"]

## Its account on the server (Server.Account): `link.who` is the character, `link.requests`
## what it asks.
var account
var session
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
var _seq := 0
var _swings := 0
## Tasks taken since it came (a test reads it).
var tasks := 0
## The item ids it works with, found by role.
var _axe := ""
var _weapon := ""
var _sign := ""
var _fire := ""
## Where it last was, to tell it is stuck.
var _last_pos := Vector3.INF
var _still := 0.0
var _stuck := 0
var _missed := 0


func _init(a, s) -> void:
	account = a
	session = s
	_rng.randomize()
	_axe = Items.with_tool("axe")
	_weapon = best_weapon()
	_sign = Items.with_prop("sign")
	_fire = Items.with_prop("campfire")


## Runs the bot for `delta` seconds: its choices, then its body.
func step(delta: float) -> void:
	var who = account.link.who
	if not _home.is_finite():
		_home = who.position
		for item: String in [_axe, _weapon, _sign, _fire]:
			_obtain(item)
	var dir := _think(delta)
	_walk(dir, delta)


## The request `kind` with `args` made as the player's own; what the rule gave back.
func ask(kind: String, args: Array) -> Variant:
	_seq += 1
	var reply: Array = account.link.requests.handle([kind, _seq, args])
	return reply[1] if reply.size() > 1 else null


## The way the body walks this step (x, z), after doing what the task asks.
func _think(delta: float) -> Vector2:
	var who = account.link.who
	if who.is_dead():
		_dead_for += delta
		if _dead_for > DEAD_WAIT:
			_dead_for = 0.0
			ask(Protocol.REVIVE, [who.home if who.home.is_finite() else _home])
		return Vector2.ZERO
	var invites: Array = session.teams.invites_of(who.id, Time.get_ticks_msec() / 1000.0)
	if not invites.is_empty():
		# Called into a team: it says yes after a moment.
		_invited_for += delta
		if _invited_for > INVITE_WAIT:
			_invited_for = 0.0
			ask(Protocol.TEAM_ACCEPT, [int(invites[0][0])])
			ask(Protocol.CHAT, ["[accepted_im_with_you]"])
	if task == "":
		_pause -= delta
		if _pause <= 0.0:
			_start(_pick())
		return Vector2.ZERO
	_left -= delta
	_swing_in -= delta
	if _left <= 0.0:
		return _stop()
	var world = session.world
	match task:
		"walk":
			return _walk_to(_target, ARRIVE, delta) if not _near(_target, ARRIVE) else _stop()
		"chop":
			if not world.trees.has(_tree) or world.log_col(_tree.x, _tree.y) == 0:
				return _stop()
			var at := Vector3(_tree.x + 0.5, who.position.y / CELL, _tree.y + 0.5) * CELL
			# The axe works the trunk in the column beside the feet: the tree's own, or a
			# log of a wide trunk the body stopped at.
			var f: Vector3i = who.feet_cell
			var facing := Vector2i(signi(_tree.x - f.x), signi(_tree.y - f.z))
			if maxi(absi(f.x - _tree.x), absi(f.z - _tree.y)) != 1 and world.log_col(f.x + facing.x, f.z + facing.y) == 0:
				return _walk_to(at, 0.0, delta)
			who.facing = facing
			_swing(_axe)
		"hunt":
			var a = _animal_of(_animal)
			if a == null or Vector2(a.pos.x - _home.x, a.pos.z - _home.z).length() > (LOOK + 8.0) * CELL:
				return _stop()
			if not _near(a.pos, REACH):
				return _walk_to(a.pos, REACH, delta)
			_face(Vector2(a.pos.x - who.position.x, a.pos.z - who.position.z))
			_swing(_weapon)
	return Vector2.ZERO


## Moves the body `dir` for `delta` seconds by the world's rules, as a client moves its own
## (Body.step): up a step it bumps into with a jump.
func _walk(dir: Vector2, delta: float) -> void:
	var who = account.link.who
	var body = who.body
	if who.is_dead() or body.world == null:
		who.is_moving = false
		return
	body.move_input = dir
	var at: Vector3 = who.position
	var left := minf(delta, 0.25)
	while left > 0.0:
		var dt := minf(left, STEP_MOST)
		left -= dt
		var jump: bool = dir != Vector2.ZERO and body.on_ground and body.bumped.is_finite()
		at = body.step(at, dt, jump)
		body.jumped = jump
	who.at = at
	who.feet_cell = Vector3i(floori(at.x / CELL), Body.level_at(at), floori(at.z / CELL))
	who.on_ground = body.on_ground
	who.is_moving = dir != Vector2.ZERO
	if dir != Vector2.ZERO:
		_face(dir)


## Turns the body towards `to` (x, z), one of 8 ways.
func _face(to: Vector2) -> void:
	if to.length() > 0.001:
		var d := to.normalized()
		account.link.who.facing = Vector2i(roundi(d.x), roundi(d.y))


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


func _start(kind: String) -> void:
	var who = account.link.who
	task = kind
	_left = TASK_MOST
	tasks += 1
	match kind:
		"walk":
			var turn := _rng.randf() * TAU
			var far := _rng.randf_range(3.0, WANDER) * CELL
			_target = _home + Vector3(cos(turn) * far, 0.0, sin(turn) * far)
		"say":
			ask(Protocol.CHAT, [LINES[_rng.randi() % LINES.size()]])
			_stop()
		"gesture":
			var g: Dictionary = Gestures.LIST[_rng.randi() % Gestures.LIST.size()]
			ask(Protocol.GESTURE, [g.name])
			_stop()
		"drop":
			_drop()
			_stop()
		"sign":
			var cell: Variant = _put(_sign)
			if cell != null:
				var text: String = SIGN_LINES[_rng.randi() % SIGN_LINES.size()]
				ask(Protocol.SIGN_WRITE, [cell, text])
			_stop()
		"fire":
			var cell: Variant = _put(_fire)
			if cell != null:
				ask(Protocol.PROP_FIRE, [cell, true])
			_stop()
		"chop":
			var t: Variant = _nearest_tree()
			if t == null or _axe == "":
				_stop()
			else:
				_tree = t
				_hold(_axe)
		"hunt":
			var a = _nearest_animal()
			if a == null or _weapon == "":
				_stop()
			else:
				_animal = a.id
				_hold(_weapon)
	if task != "":
		var p: Vector3 = who.position
		print("bot %s: %s at (%d, %d)" % [who.player_name, kind, floori(p.x / CELL), floori(p.z / CELL)])


func _stop() -> Vector2:
	task = ""
	_pause = _rng.randf_range(PAUSE.x, PAUSE.y)
	_still = 0.0
	_stuck = 0
	_missed = 0
	_last_pos = Vector3.INF
	return Vector2.ZERO


## The way to `to` (world units), and a new task when the body has not moved for a while.
func _walk_to(to: Vector3, arrive: float, delta: float) -> Vector2:
	var p: Vector3 = account.link.who.position
	_still += delta
	if _still >= 1.0:
		_still = 0.0
		if _last_pos.is_finite() and p.distance_to(_last_pos) < 0.3 * CELL:
			_stuck += 1
			if _stuck >= 3:
				# At a wall or a cliff: on to another task.
				return _stop()
		else:
			_stuck = 0
		_last_pos = p
	var d := Vector2(to.x - p.x, to.z - p.z)
	if d.length() < arrive * CELL:
		return Vector2.ZERO
	return d.normalized()


func _near(to: Vector3, cells: float) -> bool:
	var p: Vector3 = account.link.who.position
	return Vector2(to.x - p.x, to.z - p.z).length() < cells * CELL


## A swing of `item` at what is in front (Protocol.FRONT), shown to the others as the
## work of the hands (Player.work).
func _swing(item: String) -> void:
	if _swing_in > 0.0:
		return
	_swing_in = SWING_EVERY
	_hold(item)
	var who = account.link.who
	var done: Variant = ask(Protocol.FRONT, [session.world.size_y])
	if not done is Dictionary or not done.has("work"):
		return
	_swings += 1
	who.work = [str(done.work), float(done.get("time", 0.0)), _swings, done.get("at", Vector3.INF)]
	# A swing at the air: nothing is left there (the tree is down, the animal away).
	var at: Variant = done.get("at", Vector3.INF)
	_missed = _missed + 1 if not (at is Vector3 and at.is_finite()) else 0
	if _missed >= 2 and task != "":
		_stop()


## Puts `item` in the hand in use, given one first if the bag has none.
func _hold(item: String) -> void:
	if item == "":
		return
	_obtain(item)
	var who = account.link.who
	who.hands = [item, ""]
	who.active = 0


func _obtain(item: String) -> void:
	var who = account.link.who
	if item != "" and who.inventory.count(item) == 0:
		who.give(item, 1)


## Sets `item` down in front; its cell, null when it was not set down.
func _put(item: String) -> Variant:
	if item == "":
		return null
	_obtain(item)
	var before := _cells_of(item)
	if ask(Protocol.PROP_PUT, [item, -1, session.world.size_y]) != true:
		return null
	for cell: Vector3i in _cells_of(item):
		if not before.has(cell):
			return cell
	return null


func _cells_of(item: String) -> Array:
	var out := []
	for e: Dictionary in session.placed.things:
		if e.item == item:
			out.append(e.cell)
	return out


## Throws one of something out of the bag that is no tool it works with.
func _drop() -> void:
	var inv = account.link.who.inventory
	var keep := [_axe, _weapon, _sign, _fire]
	var choice := []
	for i in inv.slots.size():
		if inv.slots[i] is Array and not keep.has(inv.slots[i][0]) and inv.worn_on(i) == "":
			choice.append(i)
	if not choice.is_empty():
		ask(Protocol.THROW, [choice[_rng.randi() % choice.size()], 1])


func _nearest_tree() -> Variant:
	var p: Vector3 = account.link.who.position
	var here := Vector2(p.x, p.z) / CELL
	var home := Vector2(_home.x, _home.z) / CELL
	var world = session.world
	var best: Variant = null
	var best_d := LOOK
	for col: Vector2i in world.trees:
		var d := here.distance_to(Vector2(col) + Vector2(0.5, 0.5))
		if d < best_d and home.distance_to(Vector2(col)) < LOOK and world.log_col(col.x, col.y) != 0:
			best_d = d
			best = col
	return best


## The animal of `id` in the world, null when it is gone.
func _animal_of(id: int):
	for a in session.wildlife.animals:
		if a.id == id:
			return a
	return null


func _nearest_animal():
	var p: Vector3 = account.link.who.position
	var best = null
	var best_d := LOOK * CELL
	for a in session.wildlife.animals:
		# Not far from its spawn, and only what a blow can hurt (its species' `health`).
		if a.flying or a.perched or Vector2(a.pos.x - _home.x, a.pos.z - _home.z).length() > LOOK * CELL:
			continue
		if int(AiRules.SPECIES.get(a.kind, {}).get("health", 0)) <= 0:
			continue
		var d := Vector2(a.pos.x - p.x, a.pos.z - p.z).length()
		if d < best_d:
			best_d = d
			best = a
	return best


## The strongest blade of the world (Tools.weapon), "" for none.
static func best_weapon() -> String:
	var best := ""
	var most := -1.0
	for id: String in Items.IDS:
		var w: Dictionary = Tools.weapon(id)
		if not w.is_empty() and w.tool in ["sword", "knife"] and float(w.get("power", 0)) > most:
			most = float(w.get("power", 0))
			best = id
	return best
