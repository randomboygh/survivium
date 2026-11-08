extends RefCounted
## What a character has learned by doing (plan/design/character.md «Навыки», decision
## 164): the points of each skill (Skills), grown only by useful work. The rules give the
## seconds of a work that did something to `gain` (a swing that dug, chopped, cut, gathered,
## built or struck a beast, the time swimming), a whole thing to `gain_each` (a beast
## killed, a fish caught) and a recipe made to `gain_recipe`, which gives less for the same
## recipe made again and again (REPEAT_FADE, REPEAT_LEAST). A skill makes its work faster:
## `boost` is how many times as fast the work goes, `pace` what is left of its time. Kept
## with the player (to_dict, from_dict); a client's copy is told the points by the server
## (Protocol.SKILLS, `take`), and `leveled` says which skill rose to which level.

const Skills := preload("res://src/shared/content/skills.gd")

## The same recipe made again gives this share of the points of the one before, down to
## REPEAT_LEAST of its time.
const REPEAT_FADE := 0.85
const REPEAT_LEAST := 0.2

## The points changed.
signal changed
## Skill `id` rose to `level` (on the server as it is earned, on a client as it is told).
signal leveled(id: String, level: int)

## What every gain is multiplied by: 1, more only as a playtest switch (Settings).
var rate := 1.0
## Points by skill id, and the level they make (asked every frame, so kept: see _level).
var points := {}
var _levels := {}
## The last recipe made and how many times in a row, for REPEAT_FADE.
var _recipe := ""
var _repeat := 0


## The points of skill `id`.
func points_of(id: String) -> float:
	return points.get(id, 0.0)


## The level of skill `id` (0 for a skill not loaded).
func level(id: String) -> int:
	return _levels.get(id, 0)


## Works out the level of skill `id` from its points again.
func _level(id: String) -> void:
	var s: Dictionary = Skills.BY_ID.get(id, {})
	var n := 0 if s.is_empty() else Skills.level_at(s, points_of(id))
	if n > 0:
		_levels[id] = n
	else:
		_levels.erase(id)


## The level of the skill of work `role`.
func level_of(role: String) -> int:
	var s := Skills.of_role(role)
	return 0 if s.is_empty() else level(s.id)


## How far skill `id` has come to its next level, 0..1.
func progress(id: String) -> float:
	var s: Dictionary = Skills.BY_ID.get(id, {})
	return 0.0 if s.is_empty() else Skills.progress(s, points_of(id))


## The share of the levels of the skill of work `role` learned, 0..1.
func share_of(role: String) -> float:
	var s := Skills.of_role(role)
	return 0.0 if s.is_empty() else float(level(s.id)) / s.levels


## What is left of the time of work `role` at the skill's level: 1 at none, 1 / (1 +
## `speed`) at the last (the work goes `boost` times as fast).
func pace(role: String) -> float:
	return 1.0 / boost(role)


## What the pace of work `role` is multiplied by: 1 at none, 1 + `speed` at the last.
func boost(role: String) -> float:
	var s := Skills.of_role(role)
	return 1.0 if s.is_empty() else 1.0 + s.speed * share_of(role)


## The chance that work `role` gives one more of what it gives: the skill's `yield` at
## the last level.
func extra_chance(role: String) -> float:
	var s := Skills.of_role(role)
	return 0.0 if s.is_empty() else s.yield * share_of(role)


## Whether work `role` gives one more this time (see extra_chance).
func extra(role: String) -> bool:
	var k := extra_chance(role)
	return k > 0.0 and randf() < k


## The quality the skill of work `role` adds at its last level (its `quality`): to what
## the work gets from the world, or to the most a thing made can be (Quality).
func quality_most(role: String) -> float:
	var s := Skills.of_role(role)
	return 0.0 if s.is_empty() else float(s.quality)


## What the stamina a work of `role` costs is multiplied by: 1 at no skill, 1 - `effort`
## at the last level (the skilled hand spends less on each swing).
func effort(role: String) -> float:
	var s := Skills.of_role(role)
	return 1.0 if s.is_empty() else 1.0 - s.effort * share_of(role)


## The blow a tool of `power` deals at work `role`: the power, more by the skill's `might`
## share of it at the last level (hunting), rounded; at least 1. The tool decides the blow,
## the skill adds to it only where the skill says so.
func blow(role: String, power: int) -> int:
	var s := Skills.of_role(role)
	var p: float = float(power) if s.is_empty() else power * (1.0 + s.might * share_of(role))
	return maxi(1, roundi(p))


## The chance a swing of work `role` does not wear the tool: the skill's `care` at the
## last level.
func care_chance(role: String) -> float:
	var s := Skills.of_role(role)
	return 0.0 if s.is_empty() else s.care * share_of(role)


## Whether the tool is spared its wear this swing (see care_chance).
func spares(role: String) -> bool:
	var k := care_chance(role)
	return k > 0.0 and randf() < k


## The sum of the levels of every skill (the land a player may hold, Territory.budget).
func total() -> int:
	var n := 0
	for id: String in _levels:
		n += _levels[id]
	return n


## Adds `amount` points to the skill of work `role`.
func gain(role: String, amount: float) -> void:
	var s := Skills.of_role(role)
	if s.is_empty() or amount <= 0.0:
		return
	var was := level(s.id)
	points[s.id] = points_of(s.id) + amount * rate
	_level(s.id)
	changed.emit()
	var now := level(s.id)
	if now > was:
		leveled.emit(s.id, now)


## Adds the points of a whole thing done (`each`) to the skill of work `role`.
func gain_each(role: String) -> void:
	var s := Skills.of_role(role)
	if not s.is_empty():
		gain(role, s.each)


## Adds the points of recipe `id` of `seconds` to the skill of work `role`: less for each
## one made again right after the same.
func gain_recipe(role: String, id: String, seconds: float) -> void:
	if id == _recipe:
		_repeat += 1
	else:
		_recipe = id
		_repeat = 0
	gain(role, seconds * maxf(REPEAT_LEAST, pow(REPEAT_FADE, _repeat)))


## Takes the points a SKILLS event gives (a client's copy): `leveled` for each skill that
## rose, unless nothing was told before (`told`).
func take(d: Dictionary, told := true) -> void:
	var was := {}
	for s: Dictionary in Skills.ALL:
		was[s.id] = level(s.id)
	from_dict(d)
	if told:
		for s: Dictionary in Skills.ALL:
			var now := level(s.id)
			if now > was[s.id]:
				leveled.emit(s.id, now)


func to_dict() -> Dictionary:
	return {"points": points.duplicate()}


func from_dict(d: Dictionary) -> void:
	points = {}
	var p: Variant = d.get("points")
	if p is Dictionary:
		for k: Variant in p:
			if (p[k] is float or p[k] is int) and p[k] > 0:
				points[str(k)] = float(p[k])
	_levels = {}
	for id: String in points:
		_level(id)
	changed.emit()
