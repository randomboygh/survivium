extends RefCounted
## The player's character: the bag (Inventory) and the body (Vitals), what the load and
## tiredness do to the pace, what actions cost, eating, throwing things away, and
## death: the bag's contents stay on the spot in a sack and the character comes back
## at the spawn (plan/design/character.md). `game` is the Main node.

const Inventory := preload("res://src/shared/inventory.gd")
const Vitals := preload("res://src/shared/vitals.gd")
const Items := preload("res://src/shared/items.gd")
const WorldData := preload("res://src/shared/world_data.gd")

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


## Throws `n` items of bag slot `i` on the ground at the player's feet.
func throw_away(i: int, n: int) -> void:
	var taken = inventory.take_slot(i, n)
	if taken == null:
		return
	game.gathering.hold_back(game.player.position)
	lay(taken[0], {"n": taken[1], "worn": taken[2]} if taken.size() > 2 else taken[1])


## Health is gone: the bag's things stay in a sack where the character fell, and the
## character comes back at the spawn.
func die() -> void:
	var cause := "от голода" if vitals.hurt_by == "hunger" else ("в воде" if vitals.hurt_by == "water" else "")
	var stacks := inventory.take_all()
	if not stacks.is_empty():
		lay(Items.SACK, stacks)
	vitals.revive(REVIVE_HEALTH)
	var player = game.player
	player.position = home
	player.velocity_y = 0.0
	game.view.look_at_player()
	game.hud.toast("Персонаж погиб %s. Вещи остались в мешке." % cause if cause != "" else "Персонаж погиб. Вещи остались в мешке.")
	state_changed.emit()


## Lays a thing of `kind` (an item or a sack, see WorldData.drops; `data` how many, a
## sack's stacks, or {"n", "worn"} for a worn tool) at the player's feet.
func lay(kind: String, data: Variant) -> void:
	var world = game.world
	var p: Vector3 = game.player.position
	var h: float = world.ground_height(p.x / CELL, p.z / CELL)
	var at := Vector3(p.x, h * CELL if h >= 0.0 else p.y, p.z)
	world.add_drop(kind, at, randf() * TAU, data)
	game.props.show_drops(WorldData.chunk_key(floori(at.x / CELL), floori(at.z / CELL)))


## A message under the clock, at most once in NAG_INTERVAL for the same `reason`.
func nag(reason: String, text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _nagged.get(reason, -100.0) < NAG_INTERVAL:
		return
	_nagged[reason] = now
	game.hud.toast(text)
