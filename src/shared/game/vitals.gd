extends RefCounted
## The body's state: health, satiety and stamina, each 0..MAX (plan/design/character.md).
## Survival is soft: hunger first lowers stamina and its recovery, and only a long
## neglect hurts (a day without food). Stamina pays for jumps, swimming and work and
## comes back at rest. Time-bound changes run on game days, so a stopped clock stops
## hunger; stamina follows real seconds, as the hands and feet do. Shared, so the
## server can run the same rules; these numbers are the default difficulty.

const MAX := 100.0
## Satiety lost per game day, and what is left when hunger starts to show.
const HUNGER_PER_DAY := 60.0
const HUNGRY := 25.0
## With no satiety left health goes down this much per game day; with satiety above
## WELL_FED it comes back this much.
const STARVE_PER_DAY := 100.0
const WELL_FED := 50.0
const HEAL_PER_DAY := 50.0
## Stamina back per second at rest, and its cap while hungry.
const REST := 12.0
const HUNGRY_CAP := 60.0
## Stamina per second while swimming; with none left a swimmer loses health this fast.
const SWIM_COST := 5.0
const DROWN := 8.0
## Health lost per second touching a burning campfire.
const BURN := 6.0
## Below this much stamina the body is tired and walks slower.
const TIRED := 10.0
const TIRED_PACE := 0.7
## What the actions cost.
const COSTS := {"jump": 4.0, "dig": 3.0, "place": 1.0, "chop": 5.0, "cut": 1.0, "gather": 1.0, "pick_up": 0.5, "swing": 0.5}

var health := MAX
var satiety := 80.0
var stamina := MAX
## Why health went down last ("hunger", "water", "fire"), for the message on death.
var hurt_by := ""


## Runs the body for `delta` real seconds in which `days` of game time passed.
## `swimming`: in deep water; `load_factor`: Inventory.load_share() (recovery halves
## past the limit).
func step(delta: float, days: float, swimming: bool, load_factor := 0.0) -> void:
	satiety = maxf(0.0, satiety - HUNGER_PER_DAY * days)
	if satiety <= 0.0:
		_hurt(STARVE_PER_DAY * days, "hunger")
	elif satiety > WELL_FED:
		health = minf(MAX, health + HEAL_PER_DAY * days)
	if swimming:
		stamina = maxf(0.0, stamina - SWIM_COST * delta)
		if stamina <= 0.0:
			_hurt(DROWN * delta, "water")
	else:
		var rest := REST * delta
		if satiety < HUNGRY:
			rest *= 0.5
		if load_factor > 1.0:
			rest *= 0.5
		stamina = minf(stamina_cap(), stamina + rest)


## The body touches a burning fire for `delta` seconds.
func burn(delta: float) -> void:
	_hurt(BURN * delta, "fire")


func _hurt(amount: float, why: String) -> void:
	if amount > 0.0:
		health = maxf(0.0, health - amount)
		hurt_by = why


## The most stamina the body can have now: less while hungry.
func stamina_cap() -> float:
	return HUNGRY_CAP if satiety < HUNGRY else MAX


## Pays for `action` (see COSTS) if there is stamina enough; false when too tired.
func spend(action: String) -> bool:
	var cost: float = COSTS.get(action, 0.0)
	if stamina < cost:
		return false
	stamina -= cost
	return true


func can(action: String) -> bool:
	return stamina >= COSTS.get(action, 0.0)


## Eats something worth `food` satiety; false when already full.
func eat(food: float) -> bool:
	if satiety >= MAX - 0.5:
		return false
	satiety = minf(MAX, satiety + food)
	return true


## The pace the body allows: slower when tired.
func speed_factor() -> float:
	return TIRED_PACE if stamina < TIRED else 1.0


func is_dead() -> bool:
	return health <= 0.0


## A fresh body after death, at `share` of full health.
func revive(share: float) -> void:
	health = MAX * share
	stamina = MAX
	satiety = maxf(satiety, HUNGRY + 10.0)
	hurt_by = ""


func to_dict() -> Dictionary:
	return {"health": health, "satiety": satiety, "stamina": stamina}


func from_dict(d: Dictionary) -> void:
	health = clampf(float(d.get("health", MAX)), 1.0, MAX)
	satiety = clampf(float(d.get("satiety", satiety)), 0.0, MAX)
	stamina = clampf(float(d.get("stamina", MAX)), 0.0, MAX)
