extends RefCounted
## The one who plays, as the rules see them (plan/design/character.md): the bag
## (Inventory) and the body's state (Vitals), what the load and tiredness do to the
## pace, what actions cost, eating, throwing things away, what this life has done (for
## the death screen's statistics), and death: the bag's
## contents stay on the spot in a sack and the character lies dead until brought back
## at a respawn point. The death is kept in the save. A character new to the world starts
## with the bag of the start (Starts). The rules in src/shared/game/ take
## a character as `who`; where it stands, what its hands hold and how it speaks to the
## player its owner fills in by extending this (on the client
## src/client/game/character.gd).

const Inventory := preload("res://src/shared/game/inventory.gd")
const Vitals := preload("res://src/shared/game/vitals.gd")
const Items := preload("res://src/shared/content/items.gd")
const Starts := preload("res://src/shared/content/starts.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## A message for the same reason is not repeated sooner than this, in seconds.
const NAG_INTERVAL := 3.0
## Health after coming back from death, as a share of full.
const REVIVE_HEALTH := 0.5
## Actions counted in this life's statistics when paid for, by the name they count as.
const COUNTED := {"dig": "dug", "place": "built"}
## A step longer than this (world units) is a jump of the body to another place, not
## a walk.
const STRIDE_MAX := 3.0
## What the two hands hold, "" for an empty one; the owner fills it in.
func in_hands() -> Array:
	return []


## The thing held that gives light (an item with `light`), the one whose light reaches
## farthest; "" for none. In water it goes out.
func light_held() -> String:
	var lights := lights_held()
	var best := ""
	for id: String in lights:
		if Items.get_item(id).light > Items.get_item(best).get("light", 0.0):
			best = id
	return best


## The things held that give light, one for each hand that holds one (as many as the
## bag has); a swimmer holds them over the water (sky.gd draws their light shorter).
func lights_held() -> Array:
	var out := []
	if body == null:
		return out
	for id: String in in_hands():
		# Both hands may hold the same one: it lights once.
		if id != "" and Items.get_item(id).get("light", 0.0) > 0.0 and out.count(id) < inventory.count(id):
			out.append(id)
	return out


## Each light held burns down a unit of its `durability` a second and is gone once it
## has burned it all; two of the same burn the first two of them in the bag.
func _burn_light(delta: float) -> void:
	var lights := lights_held()
	if lights.is_empty():
		return
	_burnt += delta
	if _burnt < 1.0:
		return
	_burnt -= 1.0
	var seen := {}
	for id: String in lights:
		if inventory.wear_tool(id, Items.get_item(id).durability, seen.get(id, 0)):
			say("Догорело: %s" % Items.title(id))
		else:
			seen[id] = seen.get(id, 0) + 1


## A burning campfire touched throws the body back at this speed (cells a second) with
## this hop, and burns again no sooner than BURN_PAUSE seconds after.
const BURN_KNOCK := 11.0
const BURN_HOP := 7.0
const BURN_PAUSE := 0.4

signal state_changed

## The world the character lives in, its clock (Clock), its body (Body) and the
## things placed in it (Placed: its fires burn), set by the owner as they come.
var world
var clock
var body
var placed
var inventory := Inventory.new()
var vitals := Vitals.new()
## Where the character comes back after death, in world units: beside the campfire
## (the spawn's, until fires are made), else where they first stood.
var home := Vector3.ZERO
## The character's death while they lie dead, else empty: "cause" (Vitals.hurt_by),
## "day" and "time" (the clock), "at" (where they fell, world units), "sack" (where
## the sack lies, or null), "lost" ([id, count] of each stack the sack holds), "life"
## (what that life did, see `life`, with "days" lived), "deaths" and "best" (see below).
var death := {}
## What this life has done, by name: "walked" (world units), "dug", "built", "trees",
## "got" (things taken into the bag), "eaten", "crafted", "jumps".
var life := {}
## When this life began, in game days (Clock day plus time of day); -1 before the first
## frame of a new character.
var born := -1.0
## Deaths in this world and the longest life before one, in game days.
var deaths := 0
var best_days := 0.0
## Where the character last fell, in world units; INF before the first death.
var fell_at := Vector3.INF
var _last_at := Vector3.INF
## Where things were thrown away: those are not taken by themselves until the
## character has walked off (see WorldActions.pick_up_near).
var held_back: Array[Vector3] = []
## Where the sacks of this character's deaths lie, in world units, until they are
## taken back whole: the maps mark them.
var sacks: Array[Vector3] = []
## Where the body is, in world units (see _where).
var position: Vector3:
	get:
		return _where()
var _nagged := {}
## Seconds until a fire burns the body again (see BURN_PAUSE).
var _burn_wait := 0.0
## Seconds the light held has burned towards its next unit of wear (see _burn_light).
var _burnt := 0.0


func _init() -> void:
	# A method, not a lambda: a lambda would keep the character, and the world it
	# holds, alive through its own bag after the scene is gone.
	inventory.changed.connect(_on_bag_changed)


func _on_bag_changed() -> void:
	state_changed.emit()


## Where the body stands, in world units: the owner keeps it.
func _where() -> Vector3:
	return Vector3.ZERO


## Tells the player `text` at once (on the client a line under the clock).
func say(_text: String) -> void:
	pass


## Says `text`, at most once in NAG_INTERVAL for the same `reason`.
func nag(reason: String, text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _nagged.get(reason, -100.0) < NAG_INTERVAL:
		return
	_nagged[reason] = now
	say(text)


## Fills the bag of a character new to the world with what the start gives (its `bag`).
func start_bag() -> void:
	for id: String in Starts.START.bag:
		inventory.add(id, Starts.START.bag[id])


## Picks the place to come back to after death, once the things of `camp` (Placed)
## are put down; a new one is told (state_changed), so a copy learns it.
func find_home(camp) -> void:
	var fire: Variant = camp.cell_of(camp.CAMPFIRE)
	var was := home
	if fire is Vector3i:
		home = (Vector3(fire) + Vector3(2.5, 0.0, 0.5)) * CELL
	else:
		home = position
	if home != was:
		state_changed.emit()


## Runs the body's state for `delta` seconds and sets the pace of the body.
func update(delta: float) -> void:
	if is_dead():
		return
	if born < 0.0:
		born = _now()
	var p := position
	var stride := Vector2(p.x - _last_at.x, p.z - _last_at.z).length() if _last_at.is_finite() else 0.0
	if stride < STRIDE_MAX:
		note("walked", stride)
	_last_at = p
	vitals.step(delta, clock.days(delta), body.swimming, inventory.load_share() if inventory.heavy else 0.0)
	body.load_scale = inventory.speed_factor() * vitals.speed_factor()
	if body.jumped:
		note("jumps")
		if not body.air_jumps:
			vitals.spend("jump")
	_burn_wait = maxf(0.0, _burn_wait - delta)
	if placed != null and _burn_wait <= 0.0:
		_touch_fire(p)
	_burn_light(delta)
	if vitals.is_dead():
		die()


## A burning campfire the body at `p` stands by or pushed against burns it and throws
## it back, away from the fire's middle.
func _touch_fire(p: Vector3) -> void:
	var fire: Dictionary = placed.burning(p)
	if fire.is_empty() and body.bumped.is_finite():
		fire = placed.burning(body.bumped)
	if fire.is_empty():
		return
	vitals.burn()
	_burn_wait = BURN_PAUSE
	var mid: Vector3 = placed.center(fire)
	var away := Vector2(p.x - mid.x, p.z - mid.z)
	if away.length() < 0.01:
		away = Vector2(0.0, 1.0)
	body.knock(away, BURN_KNOCK, BURN_HOP)
	nag("fire", "Горячо!")


## Whether the character may jump now: not when overloaded or out of breath.
func can_jump() -> bool:
	return vitals.can("jump") and not inventory.overloaded()


## Pays the stamina for `action` (see Vitals.COSTS); says so and returns false when the
## character is too tired.
func act(action: String) -> bool:
	if vitals.spend(action):
		if COUNTED.has(action):
			note(COUNTED[action])
		return true
	nag("tired", "Нет сил, нужно отдышаться")
	return false


## Puts `n` of item `id` (a tool worn by `worn` swings) into the bag and says what
## came in; returns how many fit.
func give(id: String, n: int, worn := 0) -> int:
	var got := inventory.add(id, n, worn)
	note("got", got)
	if got > 0:
		say("+%d %s" % [got, Items.title(id)])
		if inventory.overloaded():
			nag("heavy", "Перегруз: %.1f из %d кг" % [inventory.weight(), inventory.weight_limit])
	if got < n:
		nag("full", "Сумка полна")
	return got


## Eats one item from bag slot `i`, or puts it on the wounds when it heals (a bandage);
## false if it is neither, the character is full or not hurt.
func eat(i: int) -> bool:
	var s = inventory.slots[i]
	if s == null:
		return false
	if Items.heal(s[0]) > 0.0:
		if not vitals.heal(Items.heal(s[0])):
			nag("not_hurt", "Здоровье и так полное")
			return false
		inventory.take_slot(i, 1)
		note("healed")
		say("+%d здоровья" % roundi(Items.heal(s[0])))
		return true
	if Items.food(s[0]) <= 0.0:
		return false
	if not vitals.eat(Items.food(s[0])):
		nag("full_belly", "Больше не хочется")
		return false
	inventory.take_slot(i, 1)
	note("eaten")
	return true


## Counts `n` more of `stat` in this life's statistics (see `life`).
func note(stat: String, n: float = 1.0) -> void:
	if n != 0.0:
		life[stat] = life.get(stat, 0.0) + n


## The clock in game days, for how long a life lasts.
func _now() -> float:
	return clock.day + clock.time_of_day


## Throws `n` items of bag slot `i` on the ground at the feet; not a chest with
## things in it (it is put down instead).
func throw_away(i: int, n: int) -> void:
	if inventory.contents(i) != null:
		nag("throw", "Сундук с вещами не бросить: поставь его")
		return
	var taken = inventory.take_slot(i, n)
	if taken == null:
		return
	held_back.append(position)
	lay(taken[0], {"n": taken[1], "worn": taken[2]} if taken.size() > 2 else taken[1])


## Lays a thing of `kind` (an item or a sack, see WorldData.drops; `data` how many, a
## sack's stacks, or {"n", "worn"} for a worn tool) at the feet; returns where.
func lay(kind: String, data: Variant) -> Vector3:
	var p := position
	var h: float = world.ground_height(p.x / CELL, p.z / CELL)
	var at := Vector3(p.x, h * CELL if h >= 0.0 else p.y, p.z)
	world.add_drop(kind, at, randf() * TAU, data)
	return at


## Health is gone: the bag's things stay in a sack where the character fell, and the
## character lies dead until revive().
func die() -> void:
	var at := position
	var stacks := inventory.take_all()
	var sack: Variant = null
	if not stacks.is_empty():
		sack = lay(Items.SACK, stacks)
		sacks.append(sack)
	var lived := maxf(0.0, _now() - born) if born >= 0.0 else 0.0
	deaths += 1
	fell_at = at
	var summary := life.duplicate()
	summary.days = lived
	death = {
		"life": summary,
		"deaths": deaths,
		"best": best_days,
		"cause": vitals.hurt_by,
		"day": clock.day,
		"time": clock.time_of_day,
		"at": [at.x, at.y, at.z],
		"sack": [sack.x, sack.y, sack.z] if sack is Vector3 else null,
		"lost": stacks.map(func(st: Array) -> Array: return [st[0], st[1]]),
	}
	body.velocity_y = 0.0
	best_days = maxf(best_days, lived)
	_fell()
	state_changed.emit()


## The owner's part of a death (on the client: the body is no longer drawn).
func _fell() -> void:
	pass


func is_dead() -> bool:
	return not death.is_empty()


## The places the character may come back at, as [title, position in world units]:
## the spawn's campfire for now (beds and the player's own fires later).
func respawn_points() -> Array:
	return [["У костра старта", home]]


## Brings the dead character back at `at` (world units) with part of their health.
func revive(at: Vector3) -> void:
	death = {}
	life = {}
	born = _now()
	_last_at = Vector3.INF
	vitals.revive(REVIVE_HEALTH)
	body.velocity_y = 0.0
	_came_back(at)
	state_changed.emit()


## The owner's part of coming back: puts the body at `at`.
func _came_back(_at: Vector3) -> void:
	pass


## How the character died, for the death screen: a title and a line under it.
static func cause_text(cause: String) -> Array:
	match cause:
		"hunger":
			return ["Вы умерли", "от голода"]
		"water":
			return ["Вы утонули", "в воде кончились силы"]
		"fire":
			return ["Вы сгорели", "в огне костра"]
	return ["Вы погибли", ""]


## The death and this life's statistics, kept in the player's save (see SaveGame.track).
func to_dict() -> Dictionary:
	return {"death": death.duplicate(true), "life": life.duplicate(), "born": born, "deaths": deaths,
		"best_days": best_days, "sacks": sacks.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z]),
		"fell_at": [fell_at.x, fell_at.y, fell_at.z] if fell_at.is_finite() else null}


func from_dict(d: Dictionary) -> void:
	life = {}
	var saved_life: Variant = d.get("life")
	if saved_life is Dictionary:
		for k: Variant in saved_life:
			life[str(k)] = float(saved_life[k])
	born = float(d.get("born", -1.0))
	deaths = int(d.get("deaths", 0))
	best_days = float(d.get("best_days", 0.0))
	var fell: Variant = d.get("fell_at")
	fell_at = Vector3(fell[0], fell[1], fell[2]) if fell is Array and fell.size() == 3 else Vector3.INF
	sacks.clear()
	for p: Variant in d.get("sacks", []):
		if p is Array and p.size() == 3:
			sacks.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	var saved: Variant = d.get("death")
	death = {}
	if saved is Dictionary and not saved.is_empty():
		death = saved.duplicate(true)
		# Counts come back from JSON as floats.
		var lost := []
		for st: Variant in death.get("lost", []):
			if st is Array and st.size() >= 2 and Items.has(Items.canon(str(st[0]))):
				lost.append([Items.canon(str(st[0])), int(st[1])])
		death.lost = lost
