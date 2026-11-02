extends RefCounted
## The body's state: health, satiety, water, energy and stamina, each 0..MAX (plan/design/
## character.md), its warmth (0..MAX, COMFORT in between), how wet it is (0..1) and
## whether it sleeps.
## Survival is soft: hunger first lowers stamina and its recovery, and only a long
## neglect hurts (a day without food). Stamina pays for jumps, swimming and work and
## comes back at rest. Time-bound changes run on game days, so a stopped clock stops
## hunger; cold works as hunger does (a lower stamina cap, then health on a long
## freezing night), and so does heat, mildly; stamina follows real seconds, as the hands and feet do. Shared, so the
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
## Water lost per game day (THIRST_HOT times that while hot), and what is left when
## thirst starts to show: as hunger, a lower stamina cap and no healing; with none left
## health goes down DRY_PER_DAY a game day.
const THIRST_PER_DAY := 70.0
const THIRST_HOT := 1.5
const THIRSTY := 25.0
const DRY_PER_DAY := 120.0
## Energy lost per game day awake, and what is left when sleepiness starts to show (as
## hunger: a lower stamina cap, slower rest); with none left the body walks slowly.
## Asleep it comes back SLEEP_GAIN a game day, times the sleep's rate (a roof, bedding),
## and stamina twice as fast; the body heals twice as fast. It sleeps only below
## SLEEP_BELOW, and wakes by itself once rested by day.
const TIRE_PER_DAY := 45.0
const SLEEPY := 25.0
const SLEEP_GAIN := 150.0
const SLEEP_BELOW := 90.0
## Stamina back per second at rest, and its cap while hungry.
const REST := 12.0
const HUNGRY_CAP := 60.0
## Stamina per second while swimming; with none left a swimmer loses health this fast.
const SWIM_COST := 5.0
const DROWN := 8.0
## Health a touch of a burning campfire takes.
const BURN := 2.0
## Below this much stamina the body is tired and walks slower.
const TIRED := 10.0
const TIRED_PACE := 0.7
## The body's warmth while comfortable; how fast it goes towards what the air feels like
## (a share of the gap per game day); how warm it wants to be per degree of the feel off
## the comfortable band (Warmth.feel, degrees Celsius).
const COMFORT := 50.0
const WARM_PACE := 6.0
const COMFY_LOW := 12.0
const COMFY_HIGH := 26.0
const PER_DEGREE_COLD := 3.5
const PER_DEGREE_HOT := 4.0
## Below COLD the body is cold (stamina capped as by hunger, it does not heal); below
## FREEZING it freezes, losing FREEZE_PER_DAY health; over HOT it is hot (a lower cap).
const COLD := 30.0
const FREEZING := 12.0
const FREEZE_PER_DAY := 50.0
const HOT := 80.0
const HOT_CAP := 75.0
## Wetting per game day in rain of strength 1 under the open sky (snow wets
## SNOW_WETS of that), and drying per game day: in the open, under a roof, by a fire.
const RAIN_WETS := 25.0
const SNOW_WETS := 0.25
const DRY := 4.0
const DRY_ROOF := 8.0
const DRY_FIRE := 30.0
## What the actions cost.
const COSTS := {"jump": 4.0, "dig": 3.0, "place": 1.0, "chop": 5.0, "cut": 1.0, "gather": 1.0, "pick_up": 0.5, "swing": 0.5}

var health := MAX
var satiety := 80.0
var water := 80.0
var energy := 80.0
var stamina := MAX
## Asleep: energy comes back at `sleep_rate` (Character sets it: a roof, bedding).
var asleep := false
var sleep_rate := 1.0
## Whether satiety falls with time; a playtest switch turns it off.
var hunger := true
## Whether water falls with time; a playtest switch turns it off.
var thirst := true
## Whether energy falls with time; a playtest switch turns it off.
var fatigue := true
## Whether the body feels the cold and the heat; a playtest switch turns it off (warmth
## stays at COMFORT, wetness still comes and goes).
var cold := true
## Why health went down last ("hunger", "thirst", "water", "fire", "cold"), for the
## message on death.
var hurt_by := ""
var warmth := COMFORT
var wet := 0.0


## Runs the body for `delta` real seconds in which `days` of game time passed.
## `swimming`: in deep water; `load_factor`: Inventory.load_share() (recovery halves
## past the limit).
func step(delta: float, days: float, swimming: bool, load_factor := 0.0) -> void:
	if hunger:
		satiety = maxf(0.0, satiety - HUNGER_PER_DAY * days)
	if thirst:
		water = maxf(0.0, water - THIRST_PER_DAY * days * (THIRST_HOT if warmth > HOT else 1.0))
	if asleep:
		energy = minf(MAX, energy + SLEEP_GAIN * sleep_rate * days)
	elif fatigue:
		energy = maxf(0.0, energy - TIRE_PER_DAY * days)
	if satiety <= 0.0:
		_hurt(STARVE_PER_DAY * days, "hunger")
	if water <= 0.0:
		_hurt(DRY_PER_DAY * days, "thirst")
	elif satiety > WELL_FED and water >= THIRSTY and warmth >= COLD:
		health = minf(MAX, health + HEAL_PER_DAY * days * (2.0 if asleep else 1.0))
	if swimming:
		stamina = maxf(0.0, stamina - SWIM_COST * delta)
		if stamina <= 0.0:
			_hurt(DROWN * delta, "water")
	else:
		var rest := REST * delta
		if satiety < HUNGRY or water < THIRSTY or warmth < COLD or energy < SLEEPY:
			rest *= 0.5
		if asleep:
			rest *= 2.0
		if load_factor > 1.0:
			rest *= 0.5
		stamina = minf(stamina_cap(), stamina + rest)


## Runs the body's warmth and wetness for `days` of game time: it goes towards what air
## that feels `feel` degrees calls for (Warmth.feel), is wet by `rain` and `snow` falling
## on it (strengths 0..1) or fully when swimming, and dries, faster under a roof or by a
## fire giving `fire` degrees. A body freezing loses health.
func warm(days: float, feel: float, rain := 0.0, snow := 0.0, swimming := false, roofed := false, fire := 0.0) -> void:
	var want := COMFORT
	if feel < COMFY_LOW:
		want = COMFORT - (COMFY_LOW - feel) * PER_DEGREE_COLD
	elif feel > COMFY_HIGH:
		want = COMFORT + (feel - COMFY_HIGH) * PER_DEGREE_HOT
	want = clampf(want, 0.0, MAX)
	if not cold:
		want = COMFORT
		warmth = COMFORT
	warmth += (want - warmth) * minf(1.0, WARM_PACE * days)
	if swimming:
		wet = 1.0
	elif rain > 0.0 or snow > 0.0:
		wet = minf(1.0, wet + RAIN_WETS * (rain + SNOW_WETS * snow) * days)
	else:
		var dry := DRY_FIRE * clampf(fire / 15.0, 0.0, 1.0) + (DRY_ROOF if roofed else DRY)
		wet = maxf(0.0, wet - dry * days)
	if warmth < FREEZING:
		_hurt(FREEZE_PER_DAY * days, "cold")


## The body touched a burning fire.
func burn() -> void:
	_hurt(BURN, "fire")


func _hurt(amount: float, why: String) -> void:
	if amount > 0.0:
		health = maxf(0.0, health - amount)
		hurt_by = why


## The most stamina the body can have now: less while hungry, thirsty, sleepy or cold, a
## little less while hot.
func stamina_cap() -> float:
	var cap := MAX
	if satiety < HUNGRY or water < THIRSTY or warmth < COLD or energy < SLEEPY:
		cap = HUNGRY_CAP
	elif warmth > HOT:
		cap = HOT_CAP
	return cap


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


## Drinks something worth `amount` water; false when not thirsty at all.
func drink(amount: float) -> bool:
	if water >= MAX - 0.5:
		return false
	water = minf(MAX, water + amount)
	return true


## Puts back `amount` health (a bandage); false when not hurt.
func heal(amount: float) -> bool:
	if health >= MAX - 0.5:
		return false
	health = minf(MAX, health + amount)
	return true


## The pace the body allows: slower when tired or with no energy left.
func speed_factor() -> float:
	return TIRED_PACE if stamina < TIRED or energy <= 0.0 else 1.0


## Lies down to sleep (`on`) or wakes; "" or why not ("rested": not sleepy enough).
func sleep(on: bool) -> String:
	if on and not asleep and energy >= SLEEP_BELOW:
		return "rested"
	asleep = on
	return ""


func is_dead() -> bool:
	return health <= 0.0


## A fresh body after death, at `share` of full health.
func revive(share: float) -> void:
	health = MAX * share
	stamina = MAX
	satiety = maxf(satiety, HUNGRY + 10.0)
	water = maxf(water, THIRSTY + 10.0)
	energy = maxf(energy, SLEEPY + 10.0)
	asleep = false
	warmth = maxf(warmth, COMFORT)
	wet = 0.0
	hurt_by = ""


func to_dict() -> Dictionary:
	return {"health": health, "satiety": satiety, "water": water, "energy": energy, "stamina": stamina, "warmth": warmth, "wet": wet}


func from_dict(d: Dictionary) -> void:
	health = clampf(float(d.get("health", MAX)), 1.0, MAX)
	satiety = clampf(float(d.get("satiety", satiety)), 0.0, MAX)
	water = clampf(float(d.get("water", water)), 0.0, MAX)
	energy = clampf(float(d.get("energy", energy)), 0.0, MAX)
	stamina = clampf(float(d.get("stamina", MAX)), 0.0, MAX)
	warmth = clampf(float(d.get("warmth", COMFORT)), 0.0, MAX)
	wet = clampf(float(d.get("wet", 0.0)), 0.0, 1.0)
