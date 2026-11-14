extends "res://src/shared/game/wildlife_move.gd"
## Wildlife, hunting and attacks (plan/design/creatures-ai.md: rules for all, kinds differ
## only by their properties): the blow of a person that lands on an animal, and the
## animals that go for the people.
## Only a kind with a `bite` goes for the people. One that does not fear them
## (`human_wariness` under 0.5) keeps its ground: one who comes within CLOSE of its
## sight is growled at for WARN seconds (it stands, facing them), and gone for if
## they stay; it fights back when hit. A meat eater hunts a person when it is very
## hungry (BOLD_HUNGER) and awake, and its flock is stronger than the person (see
## _strong_enough: a wounded one is weaker, an armed one stronger, a flock stronger in
## winter). A fire near keeps them off as it does any threat (a light in a hand not a
## hungry flock in winter, see _fire_near). A walker does not follow into the water nor
## up where it cannot step. One that defends gives up after DEFEND_BITES bites or
## its fury, one that hunts when its prey is dead, out of reach, or it is hurt to half
## its health; then it lets the people be for CALM seconds.


## How long a hit animal flees from the place of the hit, in seconds.
const HURT_FLEE := 8.0
## How far in front of the one who strikes a blow lands, in world units, and how wide
## (the cosine of the half angle): one right by their side is hit whichever way they face.
const STRIKE_REACH := 1.4
const STRIKE_CLOSE := 0.5
const STRIKE_CONE := 0.35

## The share of its sight within which one that does not fear people warns them off,
## and the seconds it warns before it goes for them.
const CLOSE := 0.25
const WARN := 1.5
## Seconds of fury: of one that defends itself (anew each time it is hit), and of one
## that hunts (anew each bite it lands); seconds it lets the people be after a fight.
const DEFEND_RAGE := 8.0
const HUNT_RAGE := 15.0
const CALM := 20.0
## Bites one that defends lands before it is done.
const DEFEND_BITES := 2
## The jaws: seconds from the leap to the bite (its `attack` frames), seconds between
## two bites, and how far past both bodies it reaches (world units).
const BITE_TIME := 0.4
const BITE_EVERY := 1.4
const BITE_REACH := 0.35
## A person's body for the bites: its radius and how far up or down a bite reaches it
## (world units).
const PERSON_RADIUS := 0.25
const BITE_HIGH := 1.0
## How a bite throws the one bitten (Body.knock).
const KNOCK := 2.5
const KNOCK_HOP := 1.0
## A person's strength against a flock (see _strong_enough): their mass times this (wits
## and hands), at full health; a wounded one has PERSON_WEAK of it plus the rest by
## the health left; a weapon in hand adds ARMED. A flock is WINTER_BOLD stronger in winter.
const PERSON_WITS := 2.0


## The animal a blow from `at` toward `dir` (over the ground, x east and y south)
## lands on: the nearest on the ground within `reach` (STRIKE_REACH) in front, within
## the angle whose cosine is `cone`, one that can be hit (its species has `health`); null
## for none.
func in_front(at: Vector3, dir: Vector2, reach := STRIKE_REACH, cone := STRIKE_CONE) -> Animal:
	var best: Animal = null
	var best_d := INF
	var way := dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	for a in animals:
		if a.gone or a.health <= 0 or a.aloft() or absf(a.pos.y - at.y) > 1.5:
			continue
		var off := Vector2(a.pos.x - at.x, a.pos.z - at.z)
		var d := maxf(0.0, off.length() - a.radius)
		if d > reach or d >= best_d:
			continue
		if d > STRIKE_CLOSE and off.normalized().dot(way) < cone:
			continue
		best = a
		best_d = d
	return best


## Animal `a` is hit with `power` from world point `from` (by `by`, one of the people,
## or null): it loses that much health and flees (its flock with it), or, when it fights
## back (see _fights_back), goes for `by`; at none it dies and is taken out of the world.
## Whether it died.
func hurt(a: Animal, power: int, from: Vector3, by = null) -> bool:
	if a.gone or a.health <= 0:
		return false
	a.health -= maxi(1, power)
	if a.health <= 0:
		_remove(a)
		return true
	if by != null and _fights_back(a, AiRules.SPECIES[a.kind], by):
		if a.foe != by:
			a.bites = 0
		a.foe = by
		a.rage = maxf(a.rage, DEFEND_RAGE)
		a.calm = 0.0
		a.warn = 0.0
		a.hurt = 0.0
		if a.state != "bite":
			a.state = "charge"
		a.idle = 0.0
		return false
	if a.foe != null:
		# Too hurt to fight on: it runs, and lets the people be a while.
		a.foe = null
		a.calm = CALM
	a.hurt = HURT_FLEE
	a.hurt_from = from
	a.idle = 0.0
	a.think = 0.0
	return false


## Whether the animals may go for the people now (the rules' `animal_attacks`).
func _attacks_on() -> bool:
	return rules == null or not "animal_attacks" in rules or rules.animal_attacks


## Whether animal `a` (of `spec`) is a fighter: its kind bites, it is wild and the
## rules let the animals attack.
func _fighter(a: Animal, spec: Dictionary) -> bool:
	return float(spec.get("bite", 0.0)) > 0.0 and a.owner < 0 and _attacks_on()


## Animal `a`'s fight with the people, when it thinks (from _decide): true when it
## took the decision (it goes for a person, keeps on at one, or warns one off). `fire`
## is the fire that keeps it off, if any: it breaks off then.
func _fights(a: Animal, spec: Dictionary, fire: Variant) -> bool:
	if not _fighter(a, spec) or fire != null or a.flying or a.perched:
		if a.foe != null or a.state == "warn" or a.state == "charge":
			_calm_down(a)
		return false
	if a.foe != null:
		if a.rage > 0.0 and _reachable(a, a.foe):
			a.state = "charge"
			a.idle = 0.0
			a.target = a.foe.position
			return true
		if a.hunting and a.foe in people and a.foe.has_method("is_dead") and a.foe.is_dead():
			# It got its prey.
			a.hunger = 0.0
		_calm_down(a)
		return false
	if a.calm > 0.0 or a.hurt > 0.0:
		return false
	var hungry: bool = "meat" in spec.diet and a.hunger > BOLD_HUNGER and AiRules.is_active(a.kind, _daylight)
	var bold: bool = spec.human_wariness < 0.5
	var near_d := INF
	var near_who = null
	for who in people:
		if not _reachable(a, who):
			continue
		var d := a.pos.distance_to(who.position)
		if d < near_d:
			near_d = d
			near_who = who
	if near_who != null and hungry and near_d < spec.sight and _strong_enough(a, spec, near_who):
		_go_for(a, near_who, true)
		return true
	if near_who != null and bold and near_d < spec.sight * CLOSE:
		if a.state == "warn" and a.warn <= 0.0:
			_go_for(a, near_who, false)
			return true
		if a.state != "warn":
			# It growls (its alarm) and stands, facing them.
			a.state = "warn"
			a.warn = WARN
			a.idle = 0.0
			if near_who.has_method("nag"):
				near_who.nag("beast_warn", Lang.line("[is_threatening_step_back]", [spec.title]))
		a.target = a.pos
		a.facing = signf(near_who.position.x - a.pos.x) if absf(near_who.position.x - a.pos.x) > 0.01 else a.facing
		return true
	if a.state == "warn":
		# They went away: it lets them be.
		a.state = "wander"
		a.warn = 0.0
	return false


## Animal `a` goes for `who`: to hunt them (`hunting`), or to drive them off.
func _go_for(a: Animal, who, hunting: bool) -> void:
	if a.foe != who:
		a.bites = 0
	a.foe = who
	a.hunting = hunting
	a.rage = HUNT_RAGE if hunting else DEFEND_RAGE
	a.state = "charge"
	a.warn = 0.0
	a.idle = 0.0
	a.target = who.position


## Animal `a` is done with its fight: it lets the people be for CALM seconds.
func _calm_down(a: Animal) -> void:
	a.foe = null
	a.hunting = false
	a.rage = 0.0
	a.warn = 0.0
	a.bites = 0
	a.calm = CALM
	if a.state in ["charge", "warn", "bite"]:
		a.state = "wander"
		a.target = a.pos


## Whether animal `a`, hit by `who`, goes for them rather than run: a fighter that still
## has half its health and does not fear people, or is in a fight already.
func _fights_back(a: Animal, spec: Dictionary, who) -> bool:
	if not _fighter(a, spec) or a.health * 2 < int(spec.health) or not _reachable(a, who):
		return false
	return spec.human_wariness < 0.5 or a.foe != null


## Whether animal `a` can get at `who`: one of the people, alive, with a body, on land a
## walker stands on (not in the water nor in a boat), not much above or below it.
func _reachable(a: Animal, who) -> bool:
	if who == null or not who in people or not "vitals" in who:
		return false
	if who.has_method("is_dead") and who.is_dead():
		return false
	var at: Vector3 = who.position
	if absf(at.y - a.pos.y) > MAX_STEP * 3.0 or ground(at.x, at.z) <= 0.0:
		return false
	if "riding" in who and str(who.riding) != "":
		return false
	return true


## Whether the flock of animal `a` (it and those of its flock within its sight) is
## strong enough to hunt person `who`: its masses, WINTER_BOLD in winter, taken as
## prey are (AiRules.PREY_RATIO) against the person's strength (PERSON_WITS times
## their mass, less as they are hurt, more with a weapon in hand).
func _strong_enough(a: Animal, spec: Dictionary, who) -> bool:
	var pack := 0.0
	var lead := _lead(a)
	if lead == null:
		pack = spec.mass
	else:
		for o: Animal in _kin().get(a.kind, []):
			if not o.gone and _lead(o) == lead and a.pos.distance_to(o.pos) < spec.sight:
				pack += float(spec.mass)
	if clock != null and clock.season == clock.WINTER:
		pack *= WINTER_BOLD
	var share: float = clampf(float(who.vitals.health) / 100.0, 0.0, 1.0)
	var person: float = float(AiRules.SPECIES[AiRules.HUMAN].mass) * PERSON_WITS * (PERSON_WEAK + (1.0 - PERSON_WEAK) * share)
	if who.has_method("held") and not Tools.weapon(str(who.held())).is_empty():
		person *= ARMED
	return pack * AiRules.PREY_RATIO >= person


## The timers of a fight, every step of animal `a`: its warning, its fury and its calm
## run out; one going for a person runs at them and, once near, leaps (`bite`, its
## attack frames) and bites when the leap ends, if they are still in reach.
func _fight_step(a: Animal, spec: Dictionary, dt: float) -> void:
	a.warn = maxf(0.0, a.warn - dt)
	a.calm = maxf(0.0, a.calm - dt)
	a.rage = maxf(0.0, a.rage - dt)
	a.bite_wait = maxf(0.0, a.bite_wait - dt)
	if a.bite > 0.0 and a.state != "bite":
		# Set off its leap by something else (a test, a hit).
		a.bite = 0.0
	if a.bite > 0.0:
		a.bite -= dt
		a.vel = Vector2.ZERO
		if a.bite > 0.0:
			return
		a.bite = 0.0
		if a.foe == null:
			a.state = "wander"
			a.target = a.pos
			return
		a.state = "charge"
		a.bite_wait = BITE_EVERY
		if _reachable(a, a.foe) and _in_reach(a, a.foe, 1.3):
			_land_bite(a, spec, a.foe)
		return
	if a.foe == null or a.state != "charge":
		return
	if not _reachable(a, a.foe):
		return
	a.target = a.foe.position
	if a.bite_wait <= 0.0 and _in_reach(a, a.foe):
		a.state = "bite"
		a.bite = BITE_TIME
		a.vel = Vector2.ZERO
		a.idle = 0.0


## Whether `who` is within the bite of animal `a` (BITE_REACH past both bodies, `more`
## times as far).
func _in_reach(a: Animal, who, more := 1.0) -> bool:
	var at: Vector3 = who.position
	var d := Vector2(at.x - a.pos.x, at.z - a.pos.z).length()
	return d <= (a.radius + PERSON_RADIUS + BITE_REACH) * more and absf(at.y - a.pos.y) <= BITE_HIGH


## Animal `a` bites `who`: they lose its kind's `bite` of health and are thrown back;
## one that hunts is furious anew, one that defends is done after DEFEND_BITES.
func _land_bite(a: Animal, spec: Dictionary, who) -> void:
	who.vitals.wound(float(spec.bite), "animal:" + a.kind)
	var away := Vector2(who.position.x - a.pos.x, who.position.z - a.pos.z)
	if away.length() > 0.01 and "body" in who and who.body != null:
		who.body.knock(away, KNOCK, KNOCK_HOP)
	if who.has_method("nag"):
		who.nag("beast_bite", Lang.line("[attacks]", [spec.title]))
	a.bites += 1
	bit.emit(a, who)
	if a.hunting:
		a.rage = HUNT_RAGE
	elif a.bites >= DEFEND_BITES:
		_calm_down(a)
