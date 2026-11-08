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

## How far in front the animal fed or tended may be, in world units.
const TEND_REACH := 1.4
## A tame one counts as fed for breeding this many days after it last ate from a hand.
const FED_DAYS := 1.0
## Tame ones this near each other (world units) are a pair, and count in one herd.
const HERD_REACH := 4.0
## Seconds between two looks at the herds.
const HERD_EVERY := 5.0

## Which of each owner's tame ones last had a young one, by animal id: when (days).
var _bred := {}
var _herd_wait := 0.0


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
## "stay", "follow", or "" for nothing.
func tend_kind(who) -> String:
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
					who.say("%s теперь ваш и ходит за вами" % spec.title)
				else:
					who.say("%s ест с руки (%d из %d)" % [spec.title, a.fed, spec.tame_feeds])
		"shear":
			if not who.act("gather", "hunt"):
				return {}
			a.shorn_at = clock.now()
			var n: int = who.give(spec.wool, 1)
			if n < 1:
				world.heap_drop(spec.wool, who.position, 1, 0.0)
				drops_changed.emit(WorldData.chunk_key(floori(who.position.x / CELL), floori(who.position.z / CELL)))
			who.use_tool()
		"stay":
			a.stay = a.pos
			who.say("%s остаётся здесь" % spec.title)
		"follow":
			a.stay = Vector3.INF
			who.say("%s идёт за вами" % spec.title)
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

