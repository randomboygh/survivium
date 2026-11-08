extends "res://src/shared/game/actions_nature.gd"
## Taming by hand (plan/design/first-hours.md «Домашние животные», decision 178): an
## animal whose species has `tame_food` does not flee from one who holds it (Wildlife);
## the action button with that food in hand feeds the animal in front, and after its
## species' `tame_feeds` feedings it is tame, the feeder's (Animal.owner): it follows them
## (Wildlife._keep_by_owner). Its owner's action button with anything else in hand tells
## it to stay where it is or to follow again; a knife shears its `wool` every `wool_days`
## days. Two tame ones of a kind that stay near each other and both ate from a hand within
## a day have a young one every `breed_days` days, while fewer than `herd` live there
## (step_herds). Only the owner feeds, shears, calls or strikes a tame one (ActionsFight);
## a knife with no wool to shear strikes it, as a weapon does.
##
## Taming with a trap (decision 178, answer 3В): a thing set down whose item has `trap`
## holds bait like a chest; every TRAP_EVERY seconds a wild animal within its `trap`
## cells that eats that bait from a hand and has a `trapped` item may come to it
## (TRAP_LURE; Animal.bait), and once there eats one bait and sits in the trap as that
## item (step_traps), taken out into the bag like anything a chest holds. Held, the action
## button lets it out in front, tame and its holder's (release).

const PlacedScript := preload("res://src/shared/game/placed.gd")

## How far in front the animal fed or tended may be, in world units.
const TEND_REACH := 1.4
## A tame one counts as fed for breeding this many days after it last ate from a hand.
const FED_DAYS := 1.0
## Tame ones this near each other (world units) are a pair, and count in one herd.
const HERD_REACH := 4.0
## Seconds between two looks at the herds.
const HERD_EVERY := 5.0

## Seconds between two looks at the traps; the chance at each that an animal in reach
## comes to one with bait; how near its middle (world units, across the ground) one that
## came is caught, and the seconds it has to get there before it wanders off.
const TRAP_EVERY := 2.0
const TRAP_LURE := 0.3
const TRAP_NEAR := 1.0 * CELL
const TRAP_COME := 40.0

## Which of each owner's tame ones last had a young one, by animal id: when (days).
var _bred := {}
var _herd_wait := 0.0
## The animals coming to a trap, by the trap's cell: {"a": the animal, "t": seconds}.
var _lured := {}
var _trap_wait := 0.0
var _trap_rng := RandomNumberGenerator.new()


## The number `who` is known by as an owner (Player.id; 0 for one without).
static func owner_id(who) -> int:
	return int(who.get("id")) if "id" in who else 0


## The animal in front of `who` (Wildlife.in_front within TEND_REACH) they could tend with
## what they hold: a wild one that eats it from a hand, or their own tame one; null for none.
func tended(who):
	if wildlife == null:
		return null
	var a = wildlife.in_front(who.position, Vector2(who.facing_step()), TEND_REACH)
	if a == null:
		return null
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	if spec.tame_food.is_empty():
		return null
	if a.owner == owner_id(who):
		return a
	if a.owner < 0 and who.held() in spec.tame_food:
		return a
	return null


## What the action button does to the animal in front (see tended): "feed", "shear",
## "stay", "follow", "release" (a live animal in the hand), or "" for nothing.
func tend_kind(who) -> String:
	if released_kind(who.held()) != "":
		return "release"
	var a = tended(who)
	if a == null:
		return ""
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	if who.held() in spec.tame_food:
		return "feed"
	if Tools.shears(Items.get_item(who.held())) and wool_ready(a):
		return "shear"
	if Tools.weapon(who.held()).is_empty():
		return "follow" if a.stay.is_finite() else "stay"
	return ""


## Whether tame animal `a` has wool to shear (its species' `wool`, `wool_days` since the last).
func wool_ready(a) -> bool:
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	return a.owner >= 0 and spec.wool != "" and Items.has(spec.wool) and clock.now() - a.shorn_at >= spec.wool_days


## The action button on the animal in front (see tend_kind): feeds, shears, or tells it
## to stay or follow. The swing done, {} for nothing.
func tend(who) -> Dictionary:
	var kind := tend_kind(who)
	if kind == "release":
		return release(who)
	if kind == "":
		return {}
	var a = tended(who)
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	if not _may(who, _cell_at(a.pos), "hit_animals"):
		return {"swing": IDLE_SWING}
	match kind:
		"feed":
			if not who.act("gather", "hunt"):
				return {}
			who.inventory.remove(who.held(), 1)
			a.fed_at = clock.now()
			a.idle = 1.5
			if a.owner < 0:
				a.fed += 1
				if a.fed >= spec.tame_feeds:
					a.owner = owner_id(who)
					a.stay = Vector3.INF
					a.shorn_at = clock.now()
					who.say(Lang.line("%s теперь ваш и ходит за вами", [spec.title]))
				else:
					who.say(Lang.line("%s ест с руки (%d из %d)", [spec.title, a.fed, spec.tame_feeds]))
		"shear":
			if not who.act("gather", "hunt"):
				return {}
			a.shorn_at = clock.now()
			var q := _got(who, "hunt")
			var n: int = who.give(spec.wool, 1, 0, q)
			if n < 1:
				world.heap_drop(spec.wool, who.position, 1, 0.0, q)
				drops_changed.emit(WorldData.chunk_key(floori(who.position.x / CELL), floori(who.position.z / CELL)))
			who.use_tool()
		"stay":
			a.stay = a.pos
			who.say(Lang.line("%s остаётся здесь", [spec.title]))
		"follow":
			a.stay = Vector3.INF
			who.say(Lang.line("%s идёт за вами", [spec.title]))
	return _work(TEND_SWING, "", a.pos + Vector3(0.0, 0.2, 0.0))


## Seconds of the hands a tending takes.
const TEND_SWING := 0.6

## The herds over `seconds` of play, looked at every HERD_EVERY (see the top): a pair of
## fed tame ones staying together has a young one.
func step_herds(seconds: float) -> void:
	_herd_wait -= seconds
	if _herd_wait > 0.0 or wildlife == null:
		return
	_herd_wait = HERD_EVERY
	var now: float = clock.now()
	var tame := []
	for a in wildlife.animals:
		if a.owner >= 0 and a.stay.is_finite() and not a.gone:
			tame.append(a)
	for a in tame:
		var spec: Dictionary = AiRules.SPECIES[a.kind]
		if now - a.fed_at > FED_DAYS or now - _bred.get(a.id, -INF) < spec.breed_days:
			continue
		var mate = null
		var herd := 0
		for o in tame:
			if o.kind != a.kind or o.owner != a.owner or o.pos.distance_to(a.pos) > HERD_REACH:
				continue
			herd += 1
			if o != a and mate == null and now - o.fed_at <= FED_DAYS and now - _bred.get(o.id, -INF) >= spec.breed_days:
				mate = o
		if mate == null or herd >= spec.herd:
			continue
		_bred[a.id] = now
		_bred[mate.id] = now
		var young = wildlife.breed(a)
		_bred[young.id] = now



## The kind of animal live item `id` is (a creature's `trapped`), "" for none.
static func released_kind(id: String) -> String:
	if id == "" or not Items.has(id) or not Items.get_item(id).get("alive", false):
		return ""
	for kind in AiRules.SPECIES:
		if AiRules.SPECIES[kind].get("trapped", "") == id:
			return kind
	return ""


## Lets the live animal `who` holds out a cell in front, tame and theirs. The swing done,
## {} for nothing.
func release(who) -> Dictionary:
	var item: String = who.held()
	var kind := released_kind(item)
	if kind == "" or wildlife == null or who.is_dead():
		return {}
	var dir := Vector2(who.facing_step())
	dir = dir.normalized() if dir != Vector2.ZERO else Vector2(0.0, 1.0)
	var at: Vector3 = who.position + Vector3(dir.x, 0.0, dir.y) * CELL
	if world.get_cell(floori(at.x / CELL), floori(at.y / CELL + 0.25), floori(at.z / CELL)) != Mat.AIR:
		at = who.position
	if who.inventory.remove(item, 1) < 1:
		return {}
	var a = wildlife.release(kind, at, owner_id(who))
	who.say(Lang.line("%s теперь ваш и ходит за вами", [AiRules.SPECIES[kind].title]))
	return _work(TEND_SWING, "", a.pos + Vector3(0.0, 0.2, 0.0))


## The kinds the bait in trap `e` lures (their `trapped` set, one of their `tame_food`
## in it), by kind: the bait.
static func _trap_baits(e: Dictionary) -> Dictionary:
	var out := {}
	for kind in AiRules.SPECIES:
		var spec: Dictionary = AiRules.SPECIES[kind]
		var caught: String = spec.get("trapped", "")
		if caught == "" or not Items.has(caught):
			continue
		for food: String in spec.get("tame_food", []):
			if e.items.count(food) > 0:
				out[kind] = food
				break
	return out


## Whether trap `e` holds a live animal already.
static func _trap_full(e: Dictionary) -> bool:
	for kind in AiRules.SPECIES:
		var caught: String = AiRules.SPECIES[kind].get("trapped", "")
		if caught != "" and e.items.count(caught) > 0:
			return true
	return false


## The traps over `seconds` of play, looked at every TRAP_EVERY (see the top): an animal
## that smells the bait comes, and one that came is caught; one that does not get there
## in TRAP_COME seconds, or whose trap is gone, emptied of bait or full, goes its way.
func step_traps(seconds: float) -> void:
	_trap_wait -= seconds
	if _trap_wait > 0.0 or wildlife == null or wildlife.placed == null:
		return
	_trap_wait = TRAP_EVERY
	var traps := {}
	for e: Dictionary in wildlife.placed.things:
		if e.items != null and float(Items.get_item(e.item).get("trap", 0.0)) > 0.0:
			traps[e.cell] = e
	for cell in _lured.keys():
		var lure: Dictionary = _lured[cell]
		var a = lure.a
		var e: Dictionary = traps.get(cell, {})
		lure.t += TRAP_EVERY
		if e.is_empty() or a.gone or a.owner >= 0 or a.hurt > 0.0 or _trap_full(e) or not _trap_baits(e).has(a.kind):
			_let_go_trap(cell)
			continue
		var mid := PlacedScript.center(e)
		if Vector2(a.pos.x - mid.x, a.pos.z - mid.z).length() <= TRAP_NEAR:
			_catch(e, a)
			_lured.erase(cell)
		elif lure.t > TRAP_COME:
			_let_go_trap(cell)
	for cell in traps:
		var e: Dictionary = traps[cell]
		if _lured.has(cell) or _trap_full(e) or _trap_rng.randf() >= TRAP_LURE:
			continue
		var baits := _trap_baits(e)
		if baits.is_empty():
			continue
		var mid := PlacedScript.center(e)
		var reach: float = float(Items.get_item(e.item).trap) * CELL
		var best = null
		var best_d := reach
		for a in wildlife.animals:
			if a.gone or a.owner >= 0 or a.hurt > 0.0 or a.bait.is_finite() or a.aloft() or not baits.has(a.kind):
				continue
			var d := Vector2(a.pos.x - mid.x, a.pos.z - mid.z).length()
			if d < best_d:
				best = a
				best_d = d
		if best != null:
			best.bait = Vector3(mid.x, best.pos.y, mid.z)
			best.think = 0.0
			_lured[cell] = {"a": best, "t": 0.0}


## Animal `a` caught in trap `e`: it eats a bait and sits in it as its `trapped` item.
func _catch(e: Dictionary, a) -> void:
	var spec: Dictionary = AiRules.SPECIES[a.kind]
	var bait: String = _trap_baits(e).get(a.kind, "")
	a.bait = Vector3.INF
	if bait == "" or e.items.remove(bait, 1) < 1:
		return
	if e.items.add(spec.trapped, 1) < 1:
		e.items.add(bait, 1)
		return
	wildlife.take(a)


## The animal coming to the trap at `cell` turns away.
func _let_go_trap(cell: Vector3i) -> void:
	var a = _lured[cell].a
	_lured.erase(cell)
	if not a.gone:
		a.bait = Vector3.INF
		a.think = 0.0
