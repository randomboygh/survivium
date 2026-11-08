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
const Warmth := preload("res://src/shared/game/warmth.gd")
const SkillSet := preload("res://src/shared/game/skill_set.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")

const CELL := WorldData.CELL
## A message for the same reason is not repeated sooner than this, in seconds.
const NAG_INTERVAL := 3.0
## Health after coming back from death, as a share of full.
const REVIVE_HEALTH := 0.5
## How many fires of the character and their team are offered to come back at.
const RESPAWNS_MAX := 4
## How much faster sleep rests under a roof (see sleep_rate).
const ROOF_SLEEP := 1.5
## How far (cells) a bed may stand for the sleep button to take the body to it.
const BED_REACH := 8.0
## Actions counted in this life's statistics when paid for, by the name they count as.
const COUNTED := {"dig": "dug", "place": "built"}
## A step longer than this (world units) is a jump of the body to another place, not
## a walk.
const STRIDE_MAX := 3.0
## A body that moved less than this (world units) since the last update stands still: a seat
## by it rests it (Placed.seat_near).
const STILL := 0.01
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


## A light is used up as it burns, as food is eaten: the stack holds whole ones, and
## each one held burns its Items.burns seconds (counted in `burning`), then one of the
## stack is gone and the next one lit; two of the same burn two of them. One put away
## keeps what it has burned, so taking it again goes on with it.
func _burn_light(delta: float) -> void:
	var lights := lights_held()
	for id: String in burning.keys():
		# Those thrown away or given up take their burning with them.
		var have := inventory.count(id)
		if have == 0:
			burning.erase(id)
		elif burning[id].size() > have:
			burning[id].resize(have)
	if lights.is_empty():
		return
	var seen := {}
	var told := false
	for id: String in lights:
		var k: int = seen.get(id, 0)
		seen[id] = k + 1
		var lasts := Items.burns(id)
		if lasts <= 0.0:
			continue
		var lit: Array = burning.get(id, [])
		while lit.size() <= k:
			lit.append(0.0)
		burning[id] = lit
		var was: float = lit[k]
		lit[k] = was + delta
		if was < lasts - BURN_WARN and lit[k] >= lasts - BURN_WARN and inventory.count(id) == 1 + k:
			say("%s догорает" % Items.title(id))
		if lit[k] >= lasts:
			lit.remove_at(k)
			if inventory.remove(id, 1) > 0:
				say("Догорело: %s" % Items.title(id))
			told = true
		elif floori(lit[k] / BURN_TELL) != floori(was / BURN_TELL):
			told = true
	if told:
		state_changed.emit()


## How much of light `id` held in its `k`th hand is left to burn, 0..1 (1 for a new one
## or one that burns for ever).
func burn_left(id: String, k := 0) -> float:
	var lasts := Items.burns(id)
	var lit: Array = burning.get(id, [])
	if lasts <= 0.0 or lit.size() <= k:
		return 1.0
	return clampf(1.0 - lit[k] / lasts, 0.0, 1.0)


## A burning campfire touched throws the body back at this speed (cells a second) with
## this hop, and burns again no sooner than BURN_PAUSE seconds after.
const BURN_KNOCK := 6.0
const BURN_HOP := 4.0
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
## What the character has learned by doing (SkillSet), kept with the player.
var skills := SkillSet.new()
## Playtest multiplier of the pace of work («Скорость игрока», as Body.speed_scale is of
## walking): swings, crafts and the like take 1/haste of their time.
var haste := 1.0
## The screen of the character's player, as their client told it (zero: not told):
## half its width and height in world units, the width along `view_right` over the
## ground (the way the camera is turned), the height across it. The animals someone
## looks at are those on a screen (Wildlife.look_from).
var view_half := Vector2.ZERO
var view_right := Vector2(1.0, 0.0)
## Where the character comes back after death, in world units: beside the campfire
## (the spawn's, until fires are made), else where they first stood.
var home := Vector3.ZERO
## The other places to come back at, best first, as find_respawns found them on the
## server (the client's copy is told them with the state): [[title, position]…].
var respawns: Array = []
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
## Where the float of the character's fishing line lies on the water, in world units,
## INF while none is cast; `bite` while a fish bites at it (Fishing sets both on the
## server; the client's copy is told them, Protocol.LINE).
var line := Vector3.INF
var bite := false
## The vessel the character sits in afloat (Vessels): its item (one with `vessel`) and
## id ("" and 0 on foot), and the seat (0 rows it, 1 is carried). Kept in the save.
var riding := ""
var vessel := 0
var seat := 0
## The current of the river where the body is (Currents), in cells a second: set on
## the server's (Session), told to the client's copy (Protocol.FLOW); Body.flow.
var flow := Vector2.ZERO
## A boat rowed without its `oars` in the bag goes at this share of its pace.
const OARLESS := 0.2
## Where the body is, in world units (see _where).
var position: Vector3:
	get:
		return _where()
var _nagged := {}
## Seconds until a fire burns the body again (see BURN_PAUSE).
var _burn_wait := 0.0
## The lights lit, by item id: the seconds each one lit has burned (see _burn_light),
## the first for the first hand that holds one. Kept in the save.
var burning := {}
## The last seconds of the last light of a stack are told of (it is about to go out).
const BURN_WARN := 20.0
## A copy of the character (a client's) learns of a light burning this often, in
## seconds, besides when one burns out.
const BURN_TELL := 5.0
## Seconds of one step of the body (Vitals.step) within a longer frame.
const VITALS_STEP := 0.05
## Game days a death's sack lies before it is gone with what it holds (plan/design/
## character.md «Смерть»: 2 days, about 80 minutes).
const SACK_DAYS := 2.0
## When each of `sacks` is gone, in game days (Clock.now), in the same order; INF for a
## sack of an old save (it stays).
var sack_ends: Array[float] = []
## The level (cells) the feet last stood on, for the height of a fall (_fall); -INF
## before the body has stood anywhere since it came (a new life, a teleport).
var _ground_y := -INF
## Where the feet were at the last update, in cells; INF before the first.
var _prev_y := INF


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
	# The body runs in short steps, so a long frame drowns or heals as short ones would.
	var share := inventory.load_share() if inventory.heavy else 0.0
	var was := vitals.health
	if vitals.asleep:
		vitals.sleep_rate = sleep_rate(p)
	vitals.rest_rate = placed.seat_near(p) if placed != null and stride < STILL else 1.0
	var left := delta
	while left > 0.0:
		var d := minf(left, VITALS_STEP)
		vitals.step(d, clock.days(d), body.swimming, share)
		left -= d
	_spoil(p, clock.days(delta))
	_warm(p, clock.days(delta))
	if vitals.asleep:
		if vitals.health < was - 0.5 or body.swimming:
			vitals.sleep(false)
			say("Вы проснулись")
		elif vitals.energy >= vitals.MAX and clock.daylight() > 0.5:
			vitals.sleep(false)
			say("Вы выспались")
	body.load_scale = inventory.speed_factor() * vitals.speed_factor()
	body.swim_scale = skills.boost("swim")
	body.vessel = vessel_pace()
	# Swimming somewhere, or rowing, is the work of the skill of swimming.
	if (body.swimming or riding != "") and stride > STILL and stride < STRIDE_MAX:
		skills.gain("swim", delta)
	if body.jumped:
		note("jumps")
		if not body.air_jumps:
			vitals.spend("jump")
	_burn_wait = maxf(0.0, _burn_wait - delta)
	if placed != null and _burn_wait <= 0.0:
		_touch_fire(p)
	_burn_light(delta)
	_fall(p, delta, stride >= STRIDE_MAX)
	_forget_old_sacks()
	if vitals.is_dead():
		die()


## A body that lands more than Vitals.FALL_SAFE levels below where it last stood is hurt
## (Vitals.fall): measured from the ground, not from the top of a jump; deep water under
## the landing takes the whole fall, shallow water half. What the body stands on is
## asked of the world at the place the client told (Body.standing), not of the client's
## word. A drop faster than any fall or a step longer than any stride (`leapt`: a
## teleport, the test page's «перейти») or the playtest's jumps in the air start the
## count again.
func _fall(p: Vector3, delta: float, leapt := false) -> void:
	if body == null or body.world == null:
		return
	var y := p.y / CELL
	var prev := _prev_y
	_prev_y = y
	if leapt or body.air_jumps or not is_finite(prev) or prev - y > body.MAX_FALL * delta + 1.0:
		_ground_y = -INF
	var water: int = body.water_under(p)
	if water == 0 and not body.standing(p):
		return
	var levels := _ground_y - y
	_ground_y = y
	if levels <= vitals.FALL_SAFE or water >= 2:
		return
	var hurt: float = vitals.fall(levels, water == 1)
	if hurt > 0.0:
		note("falls")
		say("Падение с высоты: −%d здоровья" % roundi(hurt))


## The sacks whose SACK_DAYS have passed are no longer marked on the maps (the world
## takes them off the ground where it holds their chunk, WorldActions.expire_sacks).
func _forget_old_sacks() -> void:
	if clock == null or sacks.is_empty():
		return
	var now: float = clock.now()
	var gone := false
	for i in range(sacks.size() - 1, -1, -1):
		if i < sack_ends.size() and sack_ends[i] <= now:
			sacks.remove_at(i)
			sack_ends.remove_at(i)
			gone = true
	if gone:
		state_changed.emit()


## The sack lying at `at` is gone (taken back whole, or its time is up): the maps no
## longer mark it.
func forget_sack(at: Vector3) -> void:
	for i in range(sacks.size() - 1, -1, -1):
		if sacks[i].distance_to(at) < 0.01:
			sacks.remove_at(i)
			if i < sack_ends.size():
				sack_ends.remove_at(i)
			state_changed.emit()


## The body warms or cools towards what the air feels like where it stands (Warmth):
## the biome, season, time and weather, a campfire near, a roof, the clothes worn, how
## wet it is; rain and snow wet it under the open sky.
func _warm(p: Vector3, days: float) -> void:
	var roofed := _roofed(p)
	var fire := Warmth.fire_heat(placed, p)
	var feel := Warmth.feel(Warmth.air(world, clock, p, roofed), fire, Warmth.clothes(inventory.gear), vitals.wet,
		roofed, body.swimming)
	var rain := 0.0
	var snow := 0.0
	if not roofed and clock != null:
		var w: Dictionary = clock.WEATHERS[clock.weather]
		rain = w.get("rain", 0.0) + w.get("hail", 0.0) * 0.5
		snow = w.get("snow", 0.0)
	vitals.warm(days, feel, rain, snow, body.swimming, roofed, fire)


## Whether a roof (a cave, a house: anything over the head that keeps the rain off,
## WorldData.roof_level) is over the body at `p`.
func _roofed(p: Vector3) -> bool:
	if world == null:
		return false
	var c := (p / WorldData.CELL).floor()
	return world.roof_level(int(c.x), int(c.z)) > int(c.y) + 1


## The food in the bag spoils, slower in winter and under a roof (Inventory.spoil_rate).
func _spoil(p: Vector3, days: float) -> void:
	var roofed := _roofed(p)
	inventory.spoil(days, Inventory.spoil_rate(clock.season == clock.WINTER, roofed))


## A burning campfire the body at `p` touches the logs of (Placed.burning), or tried to
## walk into this step (Body.bumped: a step stops short of what is in the way), burns
## it and throws it back, away from the fire's middle.
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


## Pays the stamina for `action` (see Vitals.COSTS), less of it by the skill of work
## `role` (SkillSet.effort) when given; says so and returns false when the character is
## too tired.
func act(action: String, role := "") -> bool:
	if vitals.spend(action, skills.effort(role) if role != "" else 1.0):
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


## Eats one item from bag slot `i`, drinks it (a full waterskin, which becomes its
## `empties_to`), or puts it on the wounds when it heals (a bandage); false if it is
## none of these, the character is full, not thirsty or not hurt.
func eat(i: int) -> bool:
	var s = inventory.slots[i]
	if s == null:
		return false
	if Items.heal(s[0]) > 0.0 and Items.food(s[0]) <= 0.0 and Items.heal_time(s[0]) > 0.0:
		if vitals.mending > 0.0:
			nag("mending", "Припарка ещё лечит")
			return false
		if not vitals.mend(Items.heal(s[0]), Items.heal_time(s[0])):
			nag("not_hurt", "Здоровье и так полное")
			return false
		inventory.take_slot(i, 1)
		note("healed")
		say("+%d здоровья за %d с" % [roundi(Items.heal(s[0])), roundi(Items.heal_time(s[0]))])
		return true
	if Items.heal(s[0]) > 0.0 and Items.food(s[0]) <= 0.0:
		if not vitals.heal(Items.heal(s[0])):
			nag("not_hurt", "Здоровье и так полное")
			return false
		inventory.take_slot(i, 1)
		note("healed")
		say("+%d здоровья" % roundi(Items.heal(s[0])))
		return true
	if Items.drink(s[0]) > 0.0 and Items.food(s[0]) <= 0.0:
		if not vitals.drink(Items.drink(s[0])):
			nag("not_thirsty", "Пить не хочется")
			return false
		var empty := Items.get_item(s[0]).get("empties_to", "") as String
		inventory.take_slot(i, 1)
		if empty != "" and give(empty, 1) == 0:
			nag("full", "Сумка полна")
		note("drunk")
		return true
	if Items.food(s[0]) <= 0.0:
		return false
	if not vitals.eat(Items.food(s[0])):
		nag("full_belly", "Больше не хочется")
		return false
	# Good food also heals a little and quenches thirst (its `heal` and `drink`).
	if Items.heal(s[0]) > 0.0:
		vitals.heal(Items.heal(s[0]))
	if Items.drink(s[0]) > 0.0:
		vitals.drink(Items.drink(s[0]))
	inventory.take_slot(i, 1)
	note("eaten")
	return true


## Lies down to sleep (`on`), or wakes; false, and says why, if not. Off a bed, the body
## goes to lie in the nearest one within BED_REACH cells (`to_bed`), else sleeps where it
## is. Asleep the body stays put, rests faster, and with every player asleep the night
## goes by fast (Session.sleep_speed).
func sleep(on: bool, to_bed := true) -> bool:
	if on and body.swimming:
		nag("sleep", "В воде не уснуть")
		return false
	var why := vitals.sleep(on)
	if why == "rested":
		nag("sleep", "Спать не хочется")
		return false
	if on and to_bed and placed != null and placed.bed_under(position).is_empty():
		var bed: Dictionary = placed.nearest_bed(position, BED_REACH)
		if not bed.is_empty():
			_came_back(placed.lying_spot(bed))
	return true


## How fast sleep at `p` rests the body: ROOF_SLEEP under a roof, times the `bedding` of
## the bed lain on (Placed.bed_under: a mat, a bedroll set down).
func sleep_rate(p: Vector3) -> float:
	var rate := ROOF_SLEEP if _roofed(p) else 1.0
	var bed: Dictionary = placed.bed_under(p) if placed != null else {}
	if not bed.is_empty():
		rate *= Items.get_item(bed.item).get("bedding", 1.0)
	return rate


## Lies down in bed `e` (Placed: a thing with `bedding`) to sleep: the body is put on it
## (_came_back) and falls asleep; not sleepy (Vitals.sleepy), it is told so (a bed is
## taken up only in the build mode). False if it did not lie down.
func lie_in(e: Dictionary) -> bool:
	if not vitals.asleep and not vitals.sleepy():
		nag("sleep", "Спать пока не хочется")
		return false
	if not sleep(true, false):
		return false
	_came_back(placed.lying_spot(e))
	return true


## Puts on what lies in bag slot `i` (see Inventory.wear); false, and says why, if not.
func wear(i: int) -> bool:
	var why := inventory.wear(i)
	if why == "inside":
		nag("wear", "Сумку не надеть из её же ячеек: переложи её выше")
	return why == ""


## Takes off what is worn in body slot `on` (see Inventory.take_off); false, and says
## why, if not.
func take_off(on: String) -> bool:
	var why := inventory.take_off(on)
	if why == "full":
		nag("take_off", "Нет свободной ячейки в сумке")
	return why == ""


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
## A sack lies until `until` (game days, Clock.now; below 0: for ever).
func lay(kind: String, data: Variant, until := -1.0) -> Vector3:
	var p := position
	var h: float = world.ground_height(p.x / CELL, p.z / CELL)
	var at := Vector3(p.x, h * CELL if h >= 0.0 else p.y, p.z)
	world.add_drop(kind, at, randf() * TAU, data, until)
	return at


## Health is gone: the bag's things stay in a sack where the character fell, and the
## character lies dead until revive().
func die() -> void:
	var at := position
	# The vessel ridden stays where it floats.
	riding = ""
	vessel = 0
	seat = 0
	var stacks := inventory.take_all()
	var sack: Variant = null
	if not stacks.is_empty():
		var ends: float = clock.now() + SACK_DAYS
		sack = lay(Items.SACK, stacks, ends)
		sacks.append(sack)
		sack_ends.append(ends)
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
		"sack_days": SACK_DAYS,
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


## The places the character may come back at, best first, as [title, position in
## world units]: their bed, the fires of theirs and of their team (respawns), then the
## spawn's campfire.
func respawn_points() -> Array:
	return respawns + [["У костра старта", home]]


## Finds the places the character may come back at (respawns) among the things of `camp`
## (Placed) with the teams `teams` (Teams, null for none): the last bed they set down
## first (they come back lying in it), then the last fire they made themselves, then
## the last of each member of their team, at most RESPAWNS_MAX; a fire put out counts
## too. True when the list changed.
func find_respawns(camp, teams) -> bool:
	var me: Variant = get("id")
	var id: int = me if me is int else 0
	var out: Array = []
	var seen := {}
	var things: Array = camp.things
	var bed: Array = []
	for i in range(things.size() - 1, -1, -1):
		var e: Dictionary = things[i]
		if bed.is_empty() and e.get("by") == id and camp.is_bed(e):
			bed = ["У своей кровати", camp.lying_spot(e)]
		if not e.has("by") or seen.has(e.by) or not camp.is_fire(e):
			continue
		var by: int = e.by
		if by != id and (teams == null or not teams.together(by, id)):
			continue
		seen[by] = true
		var title := "У своего костра" if by == id else "У костра «%s»" % str(teams.names.get(by, "?"))
		var at: Vector3 = camp.stand_by(e)
		if by == id:
			out.push_front([title, at])
		else:
			out.append([title, at])
	if not bed.is_empty():
		out.push_front(bed)
	out.resize(mini(out.size(), RESPAWNS_MAX))
	if out == respawns:
		return false
	respawns = out
	return true


## Brings the dead character back at `at` (world units) with part of their health.
func revive(at: Vector3) -> void:
	death = {}
	life = {}
	born = _now()
	_last_at = Vector3.INF
	forget_fall()
	vitals.revive(REVIVE_HEALTH)
	body.velocity_y = 0.0
	_came_back(at)
	state_changed.emit()


## The body was put somewhere (coming back, a teleport): a fall counts from where it
## next stands.
func forget_fall() -> void:
	_ground_y = -INF
	_prev_y = INF


## The share of the walking pace the vessel ridden goes at (Body.vessel): the item's
## `vessel`, OARLESS of it when the one rowing has not its `oars` in the bag; 0 on foot.
func vessel_pace() -> float:
	if riding == "" or not Items.has(riding):
		return 0.0
	var it := Items.get_item(riding)
	var oars: String = it.get("oars", "")
	var pace := float(it.get("vessel", 0.0))
	return pace * OARLESS if seat == 0 and oars != "" and inventory.count(oars) == 0 else pace


## Puts the body at `at` (world units; a vessel launched or left, ActionsBoat).
func move_to(at: Vector3) -> void:
	_came_back(at)


## The owner's part of coming back: puts the body at `at`.
func _came_back(_at: Vector3) -> void:
	pass


## How the character died, for the death screen: a title and a line under it.
static func cause_text(cause: String) -> Array:
	if cause.begins_with("player:"):
		var by := cause.substr(7)
		return ["Вас убили", "игрок «%s»" % by if by != "" else "другой игрок"]
	if cause.begins_with("animal:"):
		var spec: Dictionary = AiRules.SPECIES.get(cause.substr(7), {})
		return ["Вас загрыз зверь", str(spec.get("title", "")).to_lower()]
	match cause:
		"hunger":
			return ["Вы умерли", "от голода"]
		"water":
			return ["Вы утонули", "в воде кончились силы"]
		"fire":
			return ["Вы сгорели", "в огне костра"]
		"cold":
			return ["Вы замёрзли", "ночь без огня и тёплой одежды"]
		"thirst":
			return ["Вы умерли", "от жажды"]
		"fall":
			return ["Вы разбились", "упали с большой высоты"]
	return ["Вы погибли", ""]


## The death and this life's statistics, kept in the player's save (see SaveGame.track).
func to_dict() -> Dictionary:
	return {"death": death.duplicate(true), "life": life.duplicate(), "born": born, "deaths": deaths,
		"best_days": best_days, "sacks": sacks.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z]),
		"sack_ends": Array(sack_ends).map(func(t: float) -> Variant: return t if is_finite(t) else null),
		"fell_at": [fell_at.x, fell_at.y, fell_at.z] if fell_at.is_finite() else null,
		"burning": burning.duplicate(true), "riding": riding, "vessel": vessel, "seat": seat}


func from_dict(d: Dictionary) -> void:
	life = {}
	var saved_life: Variant = d.get("life")
	if saved_life is Dictionary:
		for k: Variant in saved_life:
			life[str(k)] = float(saved_life[k])
	born = float(d.get("born", -1.0))
	burning = {}
	var lit: Variant = d.get("burning")
	if lit is Dictionary:
		for k: Variant in lit:
			var id := Items.canon(str(k))
			if Items.has(id) and lit[k] is Array:
				burning[Items.get_item(id).id] = Array(lit[k]).map(func(t: Variant) -> float: return float(t))
	riding = str(d.get("riding", ""))
	if riding != "":
		riding = Items.canon(riding)
		riding = riding if Items.has(riding) else ""
	vessel = int(d.get("vessel", 0)) if riding != "" else 0
	seat = clampi(int(d.get("seat", 0)), 0, 1) if riding != "" else 0
	deaths = int(d.get("deaths", 0))
	best_days = float(d.get("best_days", 0.0))
	var fell: Variant = d.get("fell_at")
	fell_at = Vector3(fell[0], fell[1], fell[2]) if fell is Array and fell.size() == 3 else Vector3.INF
	sacks.clear()
	sack_ends.clear()
	var ends: Variant = d.get("sack_ends", [])
	var saved_sacks: Variant = d.get("sacks", [])
	for k in (saved_sacks.size() if saved_sacks is Array else 0):
		var p: Variant = saved_sacks[k]
		if p is Array and p.size() == 3:
			sacks.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
			var t: Variant = ends[k] if ends is Array and k < ends.size() else null
			sack_ends.append(float(t) if t is float or t is int else INF)
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
