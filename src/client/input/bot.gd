extends "res://src/shared/game/bot_brain.gd"
## A bot: a game joined to a server with `--bot` that plays by itself, for a playtest
## (.github/workflows/playtest.yml), so a person alone on a phone sees other players
## around: it walks about its spawn, talks in the chat, makes gestures, throws things
## out, sets signs down and writes on them, lights campfires, fells trees and hunts the
## animals near (which may turn on it), and accepts invitations to a team. It asks the server as a player does, by the
## same requests (Protocol); what it has comes from the recipes given for nothing, so
## the server runs with the rule «Бесплатные предметы» (Rules.free_items). It takes the
## place of the keys and the stick: `move` is the way it walks (Main sets the body's
## move_input from it), and it comes back to life by itself.

const Protocol := preload("res://src/shared/net/protocol.gd")
const Crafting := preload("res://src/shared/content/crafting.gd")
const Gestures := preload("res://src/shared/game/gestures.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const SpriteSheet := preload("res://src/client/view/sprite_sheet.gd")

const CELL := WorldData.CELL
## The frames a second a bot runs at (Main sets Engine.max_fps).
const FPS := 15

var game


func _init(g) -> void:
	game = g
	_rng.randomize()


## Whether the command line asks for a bot (`--bot`).
static func asked() -> bool:
	return OS.get_cmdline_user_args().has("--bot")


## Runs the bot for `delta` seconds of play; returns the way the body walks (x, z).
func move(delta: float) -> Vector2:
	if not _home.is_finite():
		# The world's content is the server's, known only once in.
		_home = game.player.position
		_axe = Items.with_tool("axe")
		_weapon = best_weapon()
		_sign = Items.with_prop("sign")
		_fire = Items.with_prop("campfire")
		print("bot: axe %s, weapon %s, sign %s, campfire %s" % [_axe, _weapon, _sign, _fire])
		_gear_up()
	if game.character.is_dead():
		_dead_for += delta
		if _dead_for > DEAD_WAIT:
			_dead_for = 0.0
			var at: Vector3 = game.character.home if game.character.home.is_finite() else _home
			game.net.request(Protocol.REVIVE, [at])
		return Vector2.ZERO
	if not game.team.invites.is_empty():
		# Called into a team: it says yes after a moment.
		_invited_for += delta
		if _invited_for > INVITE_WAIT:
			_invited_for = 0.0
			game.team.accept(int(game.team.invites[0][0]))
			game.net.request(Protocol.CHAT, ["[accepted_im_with_you]"])
	if task == "":
		_pause -= delta
		if _pause <= 0.0:
			_start(_pick())
		return Vector2.ZERO
	_left -= delta
	_swing_in -= delta
	if _left <= 0.0:
		return _stop()
	match task:
		"walk":
			return _walk_to(_target, ARRIVE, delta) if not _near(_target, ARRIVE) else _stop()
		"chop":
			if not game.world.trees.has(_tree) or game.world.log_col(_tree.x, _tree.y) == 0:
				return _stop()
			var at := (Vector3(_tree.x + 0.5, 0.0, _tree.y + 0.5)) * CELL
			at.y = game.player.position.y
			# The axe works the trunk in the column beside the feet.
			var f: Vector3i = game.controls.feet()
			if maxi(absi(f.x - _tree.x), absi(f.z - _tree.y)) != 1:
				return _walk_to(at, 0.0, delta)
			_work_at(at, _axe)
		"hunt":
			var a = game.wildlife._by_id.get(_animal)
			if a == null or Vector2(a.pos.x - _home.x, a.pos.z - _home.z).length() > (LOOK + 8.0) * CELL:
				return _stop()
			if not _near(a.pos, REACH):
				return _walk_to(a.pos, REACH, delta)
			_work_at(a.pos, _weapon)
	return Vector2.ZERO


func _start(kind: String) -> void:
	task = kind
	_left = TASK_MOST
	var p: Vector3 = game.player.position
	print("bot %s: %s at (%d, %d)" % [game.link.player_name, kind, floori(p.x / CELL), floori(p.z / CELL)])
	match kind:
		"walk":
			var turn := _rng.randf() * TAU
			var far := _rng.randf_range(3.0, WANDER) * CELL
			_target = _home + Vector3(cos(turn) * far, 0.0, sin(turn) * far)
		"say":
			game.net.request(Protocol.CHAT, [LINES[_rng.randi() % LINES.size()]])
			_stop()
		"gesture":
			var g: Dictionary = Gestures.LIST[_rng.randi() % Gestures.LIST.size()]
			game.player.set_gesture(g.name)
			game.net.request(Protocol.GESTURE, [g.name])
			_stop()
		"drop":
			_drop()
			_stop()
		"sign":
			_put(_sign, func(cell: Vector3i) -> void:
				var text: String = SIGN_LINES[_rng.randi() % SIGN_LINES.size()]
				game.net.request(Protocol.SIGN_WRITE, [cell, text]))
			_stop()
		"fire":
			_put(_fire, func(cell: Vector3i) -> void: game.net.request(Protocol.PROP_FIRE, [cell, true]))
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
			if a == null:
				_stop()
			else:
				_animal = a.id
				_hold(_weapon)


## The way to `to` (world units), and a new task when the body has not moved for a while.
func _walk_to(to: Vector3, arrive: float, delta: float) -> Vector2:
	var p: Vector3 = game.player.position
	# Each second: has the body gone a third of a cell since the last? (Not each frame:
	# at a headless frame rate a step is too short to tell.)
	_still += delta
	if _still >= 1.0:
		_still = 0.0
		if _last_pos.is_finite() and p.distance_to(_last_pos) < 0.3 * CELL:
			_stuck += 1
			if _stuck >= 3:
				# At a wall or a cliff: on to another task.
				print("bot %s: stuck on the way to %s" % [game.link.player_name, to / CELL])
				return _stop()
		else:
			_stuck = 0
		_last_pos = p
	var d := Vector2(to.x - p.x, to.z - p.z)
	if d.length() < arrive * CELL:
		return Vector2.ZERO
	return d.normalized()


func _near(to: Vector3, cells: float) -> bool:
	var p: Vector3 = game.player.position
	return Vector2(to.x - p.x, to.z - p.z).length() < cells * CELL


## Turns to `at` with `item` in hand and asks for the action button's work there.
func _work_at(at: Vector3, item: String) -> void:
	var p: Vector3 = game.player.position
	var to := Vector2(at.x - p.x, at.z - p.z)
	if to.length() > 0.05 * CELL:
		game.player.facing = SpriteSheet.direction_of(to)
	if _swing_in > 0.0:
		return
	_swing_in = SWING_EVERY
	_hold(item)
	game.net.request(Protocol.FRONT, [game.chunks.cut_level]).then(func(done: Variant) -> void:
		if not done is Dictionary or not done.has("work"):
			return
		game.player.work(done.work, done.time, done.at)
		# A swing at the air: nothing is left there (the tree is down, the animal away).
		_missed = _missed + 1 if not done.at.is_finite() else 0
		if _missed >= 2 and task != "":
			print("bot %s: nothing left at the %s" % [game.link.player_name, task])
			_stop()
		if done.get("hit", false):
			print("bot %s: hit" % game.link.player_name))


## Puts `item` in the hand in use, getting one first if the bag has none.
func _hold(item: String) -> void:
	if item == "":
		return
	if game.character.inventory.count(item) == 0:
		_obtain(item)
	game.controls.hands[game.controls.active] = item


## Asks for one `item` for nothing, by a recipe that makes it.
func _obtain(item: String) -> void:
	for r: Dictionary in Crafting.RECIPES:
		if r.makes == item:
			game.net.request(Protocol.CRAFT_FREE, [r.id])
			return


func _gear_up() -> void:
	for item: String in [_axe, _weapon, _sign, _fire]:
		if item != "" and game.character.inventory.count(item) == 0:
			_obtain(item)


## Sets `item` down in front, then calls `then` with its cell.
func _put(item: String, then: Callable) -> void:
	if item == "":
		return
	if game.character.inventory.count(item) == 0:
		_obtain(item)
	var before := _cells_of(item)
	game.net.request(Protocol.PROP_PUT, [item, -1, game.chunks.cut_level]).then(func(ok: Variant) -> void:
		print("bot %s: %s set down: %s" % [game.link.player_name, item, ok])
		if not ok is bool or not ok:
			return
		# The thing's own event may come a little after the reply.
		game.get_tree().create_timer(1.0).timeout.connect(func() -> void:
			for cell: Vector3i in _cells_of(item):
				if not before.has(cell):
					print("bot %s: %s at %s" % [game.link.player_name, item, cell])
					then.call(cell)
					return))


func _cells_of(item: String) -> Array:
	var out := []
	for e: Dictionary in game.placed.things:
		if e.item == item:
			out.append(e.cell)
	return out


## Throws one of something out of the bag that is no tool it works with.
func _drop() -> void:
	var slots: Array = game.character.inventory.slots
	var keep := [_axe, _weapon, _sign, _fire]
	var choice := []
	for i in slots.size():
		if slots[i] is Array and not keep.has(slots[i][0]) and game.character.inventory.worn_on(i) == "":
			choice.append(i)
	if choice.is_empty():
		return
	game.net.request(Protocol.THROW, [choice[_rng.randi() % choice.size()], 1])


func _nearest_tree() -> Variant:
	var p: Vector3 = game.player.position
	var here := Vector2(p.x, p.z) / CELL
	var home := Vector2(_home.x, _home.z) / CELL
	var best: Variant = null
	var best_d := LOOK
	for col: Vector2i in game.world.trees:
		var d := here.distance_to(Vector2(col) + Vector2(0.5, 0.5))
		if d < best_d and home.distance_to(Vector2(col)) < LOOK and game.world.log_col(col.x, col.y) != 0:
			best_d = d
			best = col
	return best


func _nearest_animal():
	var p: Vector3 = game.player.position
	var best = null
	var best_d := LOOK * CELL
	for a in game.wildlife.animals:
		# Not far from its spawn, where the players are.
		if a.flying or a.perched or Vector2(a.pos.x - _home.x, a.pos.z - _home.z).length() > LOOK * CELL:
			continue
		# Only what a blow can hurt (its species' `health`).
		if int(AiRules.SPECIES.get(a.kind, {}).get("health", 0)) <= 0:
			continue
		var d := Vector2(a.pos.x - p.x, a.pos.z - p.z).length()
		if d < best_d:
			best_d = d
			best = a
	return best
