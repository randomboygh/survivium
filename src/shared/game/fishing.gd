extends RefCounted
## Fishing (plan/design: the user's ask of 2026-11-02): a line cast with a rod into open
## water (WorldActions.fish casts it and pulls it out), its float lying where it fell.
## The fish are the animals that swim and have a `catch` (Wildlife, content `creatures`):
## every LURE_EVERY seconds one within LURE_REACH of the float may come to it, with
## chance LURE_BAIT while bait is on the hook (one of the rod's `ammo` from the bag a
## cast) and LURE_BARE without. It swims there (Animal.bait) and once at the float bites
## for BITE seconds (Character.bite: the float dips): a pull then takes it out of the
## water into the bag as its `catch`. A bite let go, the fish has eaten the bait and swims
## off. A line is reeled in by itself when its angler walks off or puts the rod away,
## sleeps or dies, or the water freezes. A step of the session (Session.step_things).

const Items := preload("res://src/shared/content/items.gd")
const Tools := preload("res://src/shared/content/tools.gd")
const AiRules := preload("res://src/shared/content/ai_rules.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const CELL := WorldData.CELL
## Seconds between the rolls for a fish to come to the float, and the chance of one with
## bait on the hook and without.
const LURE_EVERY := 1.0
const LURE_BAIT := 0.3
const LURE_BARE := 0.04
## How far from the float a fish sees it, in world units.
const LURE_REACH := 5.0
## A fish this near the float (world units, over the ground) bites; one that has not got
## there in COME_MAX seconds swims off.
const BITE_NEAR := 0.3
const COME_MAX := 10.0
## Seconds a fish bites: the time to pull it out.
const BITE := 2.5
## A fish let go flees from the float this long, in seconds.
const SCARED := 2.0
## The angler may stand this far from where they cast before the line is reeled in, in
## world units.
const WANDER := 0.75


class Line:
	## Where the float lies, and where the angler stood when casting.
	var at := Vector3.ZERO
	var from := Vector3.ZERO
	## The rod's bait on the hook ("" none).
	var bait := ""
	## The fish coming to the float or biting (Wildlife.Animal), and the seconds it has come.
	var fish = null
	var coming := 0.0
	## Seconds of the bite left, 0 when none bites.
	var bite := 0.0
	## Seconds to the next roll for a fish to come.
	var wait := 0.0


var world
## The animals (Wildlife): the fish come from them.
var wildlife
var rng := RandomNumberGenerator.new()
## The lines cast, by character.
var lines := {}


## Whether `who` has a line in the water.
func has_line(who) -> bool:
	return lines.has(who)


## Casts the line of `who` with the float at world point `at`: one `bait` from the bag
## goes on the hook when there is any ("" for a rod without).
func cast(who, at: Vector3, bait: String) -> void:
	var line := Line.new()
	line.at = at
	line.from = who.position
	if bait != "" and who.inventory.count(bait) > 0:
		who.inventory.remove(bait, 1)
		line.bait = bait
	line.wait = rng.randf() * LURE_EVERY
	lines[who] = line
	who.line = at
	who.bite = false


## Pulls the line of `who` out of the water: {"from": the float, "caught": the item of
## the fish taken out while it bit ("" none), "bit": whether one bit, "full": the bag
## had no room for it}. The bait not eaten goes back into the bag. Empty without a line.
func pull(who) -> Dictionary:
	var line: Line = lines.get(who)
	if line == null:
		return {}
	_end(who, line)
	var out := {"from": line.at, "caught": "", "bit": line.bite > 0.0, "full": false}
	var fish = line.fish
	if line.bite > 0.0 and fish != null and not fish.gone:
		var catch := catch_of(fish)
		if catch != "" and who.give(catch, 1) > 0:
			out.caught = catch
			wildlife.take(fish)
			return out
		out.full = catch != ""
	if line.bait != "" and line.bite <= 0.0:
		who.give(line.bait, 1)
	return out


## The lines for `delta` seconds (see the top).
func step(delta: float) -> void:
	for who in lines.keys():
		var line: Line = lines[who]
		if not _holds(who, line):
			_end(who, line)
			if line.bait != "" and not who.is_dead():
				who.give(line.bait, 1)
			continue
		var fish = line.fish
		if fish != null and fish.gone:
			line.fish = null
			line.bite = 0.0
			who.bite = false
			fish = null
		if fish == null:
			line.wait -= delta
			if line.wait <= 0.0:
				line.wait = LURE_EVERY
				if rng.randf() < (LURE_BAIT if line.bait != "" else LURE_BARE):
					_lure(line)
			continue
		if line.bite > 0.0:
			line.bite -= delta
			if line.bite <= 0.0:
				# Let go: it took the bait and swims off.
				line.bite = 0.0
				line.bait = ""
				_let_go(line)
				who.bite = false
			continue
		line.coming += delta
		if Vector2(fish.pos.x - line.at.x, fish.pos.z - line.at.z).length() <= BITE_NEAR:
			line.bite = BITE
			who.bite = true
		elif line.coming > COME_MAX:
			_let_go(line)


## The nearest fish that would bite within `reach` of world point `at` (null none).
func fish_near(at: Vector3, reach := LURE_REACH):
	if wildlife == null:
		return null
	var best = null
	var best_d := reach
	for a in wildlife.animals:
		if a.gone or a.bait.is_finite() or catch_of(a) == "":
			continue
		var d := Vector2(a.pos.x - at.x, a.pos.z - at.z).length()
		if d < best_d:
			best = a
			best_d = d
	return best


## The item animal `a` becomes in the bag when pulled out ("" for one that does not bite:
## not a swimmer, or nothing to catch).
static func catch_of(a) -> String:
	var spec: Dictionary = AiRules.SPECIES.get(a.kind, {})
	var id: String = spec.get("catch", "")
	return id if id != "" and spec.get("swims", false) and Items.has(id) else ""


## Whether the line of `who` stays in the water.
func _holds(who, line: Line) -> bool:
	if who.is_dead() or who.vitals.asleep or world.water_frozen or not Tools.can_fish(who.tool()):
		return false
	var at: Vector3 = who.position
	return Vector2(at.x - line.from.x, at.z - line.from.z).length() <= WANDER


func _lure(line: Line) -> void:
	var fish = fish_near(line.at)
	if fish == null:
		return
	line.fish = fish
	line.coming = 0.0
	fish.bait = line.at
	# It turns to the float at once.
	fish.think = 0.0


func _let_go(line: Line) -> void:
	var fish = line.fish
	line.fish = null
	line.bite = 0.0
	if fish == null or fish.gone:
		return
	fish.bait = Vector3.INF
	fish.hurt = SCARED
	fish.hurt_from = line.at
	fish.think = 0.0


func _end(who, line: Line) -> void:
	lines.erase(who)
	if line.fish != null and line.bite <= 0.0:
		_let_go(line)
	elif line.fish != null and not line.fish.gone:
		line.fish.bait = Vector3.INF
	who.line = Vector3.INF
	who.bite = false
