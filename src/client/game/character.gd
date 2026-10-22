extends RefCounted
## The player's character: the bag (Inventory) and the body (Vitals), what the load and
## tiredness do to the pace, what actions cost, eating, throwing things away, and
## death: the bag's contents stay on the spot in a sack and the character lies dead
## (the death screen, DeathScreen) until the player brings them back at a respawn
## point (plan/design/character.md). The death is kept in the save, so a world left
## dead is entered dead. `game` is the Main node.

const Inventory := preload("res://src/shared/game/inventory.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")
const Items := preload("res://src/shared/content/items.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## A message for the same reason is not repeated sooner than this, in seconds.
const NAG_INTERVAL := 3.0
## Health after coming back from death, as a share of full.
const REVIVE_HEALTH := 0.5

signal state_changed

var game
var inventory := Inventory.new()
var vitals := Vitals.new()
## Where the character comes back after death, in world units: beside the campfire
## (the spawn's, until fires are made), else where the player first stood.
var home := Vector3.ZERO
## The character's death while they lie dead, else empty: "cause" (Vitals.hurt_by),
## "day" and "time" (the clock), "at" (where they fell, world units), "sack" (where
## the sack lies, or null) and "lost" ([id, count] of each stack the sack holds).
var death := {}
var _nagged := {}


func _init(g) -> void:
	game = g
	inventory.changed.connect(func() -> void: state_changed.emit())


## Picks the place to come back to after death, once the props are placed.
func find_home() -> void:
	var fire: Variant = game.props.cell_of(game.props.CAMPFIRE)
	if fire is Vector3i:
		home = (Vector3(fire) + Vector3(2.5, 0.0, 0.5)) * CELL
	else:
		home = game.player.position


## Runs the body for a frame of `delta` seconds and sets the pace of the player.
func update(delta: float) -> void:
	if is_dead():
		return
	var player = game.player
	var days: float = delta * game.sky.time_speed / game.sky.DAY_LENGTH
	vitals.step(delta, days, player.swimming, inventory.load_share())
	player.load_scale = inventory.speed_factor() * vitals.speed_factor()
	if player.jumped and not player.air_jumps:
		vitals.spend("jump")
	if vitals.is_dead():
		die()


## Whether the player may jump now: not when overloaded or out of breath.
func can_jump() -> bool:
	return vitals.can("jump") and not inventory.overloaded()


## Pays the stamina for `action` (see Vitals.COSTS); says so and returns false when the
## character is too tired.
func act(action: String) -> bool:
	if vitals.spend(action):
		return true
	nag("tired", "Нет сил, нужно отдышаться")
	return false


## Puts `n` of item `id` (a tool worn by `worn` swings) into the bag and says what
## came in; returns how many fit.
func give(id: String, n: int, worn := 0) -> int:
	var got := inventory.add(id, n, worn)
	if got > 0:
		game.hud.toast("+%d %s" % [got, Items.title(id)])
		if inventory.overloaded():
			nag("heavy", "Перегруз: %.1f из %d кг" % [inventory.weight(), inventory.weight_limit])
	if got < n:
		nag("full", "Сумка полна")
	return got


## Eats one item from bag slot `i`; false if it is not food or the character is full.
func eat(i: int) -> bool:
	var s = inventory.slots[i]
	if s == null or Items.food(s[0]) <= 0.0:
		return false
	if not vitals.eat(Items.food(s[0])):
		nag("full_belly", "Больше не хочется")
		return false
	inventory.take_slot(i, 1)
	return true


## Throws `n` items of bag slot `i` on the ground at the player's feet; not a chest
## with things in it (it is put down instead).
func throw_away(i: int, n: int) -> void:
	if inventory.contents(i) != null:
		nag("throw", "Сундук с вещами не бросить: поставь его")
		return
	var taken = inventory.take_slot(i, n)
	if taken == null:
		return
	game.gathering.hold_back(game.player.position)
	lay(taken[0], {"n": taken[1], "worn": taken[2]} if taken.size() > 2 else taken[1])


## Health is gone: the bag's things stay in a sack where the character fell, and the
## character lies dead until revive().
func die() -> void:
	var player = game.player
	var at: Vector3 = player.position
	var stacks := inventory.take_all()
	var sack: Variant = null
	if not stacks.is_empty():
		sack = lay(Items.SACK, stacks)
	death = {
		"cause": vitals.hurt_by,
		"day": game.sky.day,
		"time": game.sky.time_of_day,
		"at": [at.x, at.y, at.z],
		"sack": [sack.x, sack.y, sack.z] if sack is Vector3 else null,
		"lost": stacks.map(func(st: Array) -> Array: return [st[0], st[1]]),
	}
	player.velocity_y = 0.0
	player.visible = false
	if game.hud.bag.visible:
		game.hud.toggle_bag()
	state_changed.emit()
	game.save.flush()


func is_dead() -> bool:
	return not death.is_empty()


## The places the character may come back at, as [title, position in world units]:
## the spawn's campfire for now (beds and the player's own fires later).
func respawn_points() -> Array:
	return [["У костра старта", home]]


## Brings the dead character back at `at` with part of their health.
func revive(at: Vector3) -> void:
	death = {}
	vitals.revive(REVIVE_HEALTH)
	var player = game.player
	player.position = at
	player.velocity_y = 0.0
	player.visible = true
	game.view.look_at_player()
	state_changed.emit()


## How the character died, for the death screen: a title and a line under it.
static func cause_text(cause: String) -> Array:
	match cause:
		"hunger":
			return ["Вы умерли", "от голода"]
		"water":
			return ["Вы утонули", "в воде кончились силы"]
	return ["Вы погибли", ""]


## The death, kept in the player's save (see SaveGame.track).
func to_dict() -> Dictionary:
	return {"death": death.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	var saved: Variant = d.get("death")
	death = {}
	if saved is Dictionary and not saved.is_empty():
		death = saved.duplicate(true)
		# Counts come back from JSON as floats.
		var lost := []
		for st: Variant in death.get("lost", []):
			if st is Array and st.size() >= 2 and Items.has(str(st[0])):
				lost.append([str(st[0]), int(st[1])])
		death.lost = lost


## Lays a thing of `kind` (an item or a sack, see WorldData.drops; `data` how many, a
## sack's stacks, or {"n", "worn"} for a worn tool) at the player's feet; returns where.
func lay(kind: String, data: Variant) -> Vector3:
	var world = game.world
	var p: Vector3 = game.player.position
	var h: float = world.ground_height(p.x / CELL, p.z / CELL)
	var at := Vector3(p.x, h * CELL if h >= 0.0 else p.y, p.z)
	world.add_drop(kind, at, randf() * TAU, data)
	game.props.show_drops(WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)))
	return at


## A message under the clock, at most once in NAG_INTERVAL for the same `reason`.
func nag(reason: String, text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _nagged.get(reason, -100.0) < NAG_INTERVAL:
		return
	_nagged[reason] = now
	game.hud.toast(text)
