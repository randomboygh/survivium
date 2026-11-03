extends RefCounted
## The skills, read from `content/*/data/skills.yaml` (see Content; decision 164): each
## grows from one kind of work (`role`: gather, chop, dig, craft, build, cook, hunt, fish,
## swim) and makes it faster. The engine asks for a skill by its role (`of_role`), never by
## id. How many points each level takes (`need`) and which level some points make (`level_at`)
## follow the record's `first` and `growth`. Shared, so the server tells the same. What a
## character has learned is SkillSet (src/shared/game/skill_set.gd).

const Content := preload("res://src/shared/content/content.gd")

## The skills loaded, by `order` (then id); each by id and by role (the first of a role).
static var ALL: Array = []
static var BY_ID := {}
static var BY_ROLE := {}


static func _static_init() -> void:
	refresh()


static func refresh() -> void:
	ALL = Content.records("skills").duplicate()
	ALL.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.order < b.order or (a.order == b.order and a.id < b.id))
	BY_ID = {}
	BY_ROLE = {}
	for s: Dictionary in ALL:
		BY_ID[s.id] = s
		if not BY_ROLE.has(s.role):
			BY_ROLE[s.role] = s


## The skill of work `role`; {} when no skill of it is loaded.
static func of_role(role: String) -> Dictionary:
	return BY_ROLE.get(role, {})


## The points skill `s` takes to reach level `n` from nothing.
static func need(s: Dictionary, n: int) -> float:
	if n <= 0:
		return 0.0
	var g: float = s.growth
	if g <= 1.0001:
		return s.first * n
	return s.first * (pow(g, n) - 1.0) / (g - 1.0)


## The level `points` make in skill `s`, 0..its `levels`.
static func level_at(s: Dictionary, points: float) -> int:
	var n := 0
	while n < s.levels and points >= need(s, n + 1) - 0.0001:
		n += 1
	return n


## How far `points` are from the level they make to the next one, 0..1 (1 at the last).
static func progress(s: Dictionary, points: float) -> float:
	var n := level_at(s, points)
	if n >= s.levels:
		return 1.0
	var a := need(s, n)
	return clampf((points - a) / maxf(0.001, need(s, n + 1) - a), 0.0, 1.0)
