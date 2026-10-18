extends RefCounted
## Shared behaviour rules. A species only lists its properties; whether another
## creature is food, a threat or nobody is derived here, so a newly added species
## fits into the world without any per-species rules.

## Species properties. "human" stands for players.
const SPECIES := {
	"human": {"name": "Человек", "mass": 70.0, "diet": ["plants", "meat"], "speed": 4.0,
		"sight": 0.0, "human_wariness": 0.0, "active": "day", "count": 0},
	"rabbit": {"name": "Заяц", "mass": 2.0, "diet": ["plants"], "speed": 5.5,
		"sight": 9.0, "human_wariness": 0.9, "active": "day", "count": 14},
	"squirrel": {"name": "Белка", "mass": 0.5, "diet": ["plants"], "speed": 5.0,
		"sight": 7.0, "human_wariness": 0.7, "active": "day", "count": 10},
	"cat": {"name": "Дикая кошка", "mass": 4.0, "diet": ["meat"], "speed": 5.5,
		"sight": 10.0, "human_wariness": 0.6, "active": "any", "count": 4},
	"deer": {"name": "Олень", "mass": 60.0, "diet": ["plants"], "speed": 6.5,
		"sight": 13.0, "human_wariness": 0.8, "active": "day", "count": 8},
	"wolf": {"name": "Волк", "mass": 40.0, "diet": ["meat"], "speed": 6.0,
		"sight": 14.0, "human_wariness": 0.6, "active": "night", "count": 4},
}

## A predator takes prey up to this share of its own mass.
const PREY_RATIO := 0.8
## A meat eater this much heavier is dangerous even if it would not hunt you.
const THREAT_RATIO := 1.25


static func is_food(eater: String, target: String) -> bool:
	var a: Dictionary = SPECIES[eater]
	var b: Dictionary = SPECIES[target]
	return "meat" in a.diet and b.mass <= a.mass * PREY_RATIO


static func is_threat(self_kind: String, other: String) -> bool:
	var a: Dictionary = SPECIES[self_kind]
	var b: Dictionary = SPECIES[other]
	if other == "human":
		return a.human_wariness >= 0.5
	return is_food(other, self_kind) or ("meat" in b.diet and b.mass >= a.mass * THREAT_RATIO)


## `daylight` is 0 at night and 1 at day.
static func is_active(kind: String, daylight: float) -> bool:
	match SPECIES[kind].active:
		"day":
			return daylight > 0.25
		"night":
			return daylight < 0.75
	return true
