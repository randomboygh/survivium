extends RefCounted
## Shared behaviour rules. A species only lists its properties; whether another
## creature is food, a threat or nobody is derived here, so a newly added species
## fits into the world without any per-species rules.

const Content := preload("res://src/shared/content/content.gd")

## Players.
const HUMAN := "core:human"

## id -> record from `content/*/data/creatures.yaml` (see Content): title, mass,
## diet, speed, sight, human_wariness, active, count, sprite, frames, flies, swims,
## flock, roost, likes.
static var SPECIES := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	SPECIES = {}
	for r in Content.records("creatures"):
		SPECIES[r.id] = r


## What is wrong with the loaded creatures for the engine, if anything.
static func check() -> PackedStringArray:
	var out: PackedStringArray = []
	if not SPECIES.has(HUMAN):
		out.append("creatures: the engine needs `%s` for the players" % HUMAN)
	for id in SPECIES:
		if id != HUMAN and SPECIES[id].sprite == "":
			out.append("creatures: `%s` has no sprite" % id)
		if SPECIES[id].flock[0] > SPECIES[id].flock[1]:
			out.append("creatures: `%s`: flock [from, to] has from above to" % id)
	return out


## A predator takes prey up to this share of its own mass.
const PREY_RATIO := 0.8
## A meat eater this much heavier is dangerous even if it would not hunt you.
const THREAT_RATIO := 1.25


## Whether `hunter` can get at `other` at all: a flyer reaches everything, a walker
## only what is on land and a swimmer only what is in the water.
static func reaches(hunter: String, other: String) -> bool:
	var a: Dictionary = SPECIES[hunter]
	return a.flies or a.swims == SPECIES[other].swims


static func is_food(eater: String, target: String) -> bool:
	var a: Dictionary = SPECIES[eater]
	var b: Dictionary = SPECIES[target]
	return "meat" in a.diet and b.mass <= a.mass * PREY_RATIO and reaches(eater, target)


static func is_threat(self_kind: String, other: String) -> bool:
	var a: Dictionary = SPECIES[self_kind]
	var b: Dictionary = SPECIES[other]
	if other == HUMAN:
		return a.human_wariness >= 0.5
	return is_food(other, self_kind) or ("meat" in b.diet and b.mass >= a.mass * THREAT_RATIO and reaches(other, self_kind))


## `daylight` is 0 at night and 1 at day.
static func is_active(kind: String, daylight: float) -> bool:
	match SPECIES[kind].active:
		"day":
			return daylight > 0.25
		"night":
			return daylight < 0.75
	return true
