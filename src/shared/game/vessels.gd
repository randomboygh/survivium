extends RefCounted
## The rafts and boats on the water (decision 178, answer 4Б): each launched from the bag
## (ActionsBoat) floats where it was left, moored, until it is boarded again or taken back
## up into the bag. Two may sit in one: the first aboard rows it (seat 0, the body moves
## it), the other is carried (seat 1). Who sits where is the characters' (Character.vessel,
## seat), not kept here. A record: {"id", "item" (the vessel's item), "at" (world units,
## the middle of the hull on the water), "turn" (radians, the way it last went: 0 south)}.
## Kept in the world's save (to_list); told to the clients by `changed` and `gone`.

const Items := preload("res://src/shared/content/items.gd")

## A vessel was launched or moved (a move told once it went TELL_MOVE or turned TELL_TURN).
signal changed(v: Dictionary)
## A vessel was taken up.
signal gone(id: int)

## How far (world units) and how much (radians) a vessel moves before it is told again.
const TELL_MOVE := 0.1
const TELL_TURN := 0.3
## The seats of a vessel.
const SEATS := 2

## The vessels by id.
var list := {}
var _next := 1


## A new vessel of item `item` floating at `at`, turned `turn`.
func launch(item: String, at: Vector3, turn: float) -> Dictionary:
	var v := {"id": _next, "item": item, "at": at, "turn": turn, "told": at, "told_turn": turn}
	_next += 1
	list[v.id] = v
	changed.emit(v)
	return v


func of(id: int) -> Dictionary:
	return list.get(id, {})


## Moves vessel `v` to `at`, turned `turn`; told when it went far enough.
func move(v: Dictionary, at: Vector3, turn: float) -> void:
	v.at = at
	v.turn = turn
	if at.distance_to(v.told) >= TELL_MOVE or absf(angle_difference(turn, v.told_turn)) >= TELL_TURN:
		v.told = at
		v.told_turn = turn
		changed.emit(v)


func remove(id: int) -> void:
	if list.erase(id):
		gone.emit(id)


## The vessel nearest `at` (world units, across the ground) within `reach`, {} for none.
func near(at: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for v: Dictionary in list.values():
		var d := Vector2(v.at.x - at.x, v.at.z - at.z).length()
		if d <= best_d and absf(v.at.y - at.y) < 2.0:
			best_d = d
			best = v
	return best


## What a client is told of vessel `v`: [id, item, at, turn].
static func record(v: Dictionary) -> Array:
	return [v.id, v.item, v.at, v.turn]


func records() -> Array:
	return list.values().map(func(v: Dictionary) -> Array: return record(v))


## The vessels for the world's save (numbers only: it is JSON).
func to_list() -> Array:
	return list.values().map(func(v: Dictionary) -> Dictionary:
		return {"id": v.id, "item": v.item, "at": [v.at.x, v.at.y, v.at.z], "turn": v.turn})


func from_list(saved: Array) -> void:
	list.clear()
	for d: Variant in saved:
		if not d is Dictionary or not d.get("at") is Array or d.at.size() != 3:
			continue
		var item := Items.canon(str(d.get("item", "")))
		if not Items.has(item):
			continue
		var at := Vector3(float(d.at[0]), float(d.at[1]), float(d.at[2]))
		var turn := float(d.get("turn", 0.0))
		var id := int(d.get("id", _next))
		list[id] = {"id": id, "item": item, "at": at, "turn": turn, "told": at, "told_turn": turn}
		_next = maxi(_next, id + 1)
