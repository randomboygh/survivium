extends RefCounted
## A bag of item stacks: a fixed number of slots, each empty or holding one item id up
## to its stack size, and the weight of it all (plan/design/character.md). Weight has a
## limit from strength: past it the carrier slows down (see speed_factor) but may
## still pick things up. Shared, so the server can keep the same bag.

const Items := preload("res://src/shared/items.gd")

## Slots of a bag without a backpack, and the weight carried at full pace (kg).
const SLOTS := 16
const WEIGHT_LIMIT := 40.0
## Past the limit the pace falls steadily, to OVERLOAD_PACE at OVERLOAD times the limit.
const OVERLOAD := 1.5
const OVERLOAD_PACE := 0.15

signal changed

## Each slot: [id, count], or null for an empty one.
var slots: Array = []
var weight_limit := WEIGHT_LIMIT


func _init(n := SLOTS) -> void:
	slots.resize(n)


## Puts up to `n` of item `id` into the bag, topping up stacks first; returns how many
## went in (fewer when the slots are full).
func add(id: String, n: int) -> int:
	var left := n
	var size := Items.stack_size(id)
	for s in slots:
		if left > 0 and s != null and s[0] == id and s[1] < size:
			var k := mini(left, size - s[1])
			s[1] += k
			left -= k
	for i in slots.size():
		if left > 0 and slots[i] == null:
			var k := mini(left, size)
			slots[i] = [id, k]
			left -= k
	if left < n:
		changed.emit()
	return n - left


## How many of `n` items `id` there is room for.
func room_for(id: String) -> int:
	var size := Items.stack_size(id)
	var room := 0
	for s in slots:
		if s == null:
			room += size
		elif s[0] == id:
			room += size - s[1]
	return room


## Takes up to `n` of item `id` out of the bag, from the last stacks first; returns
## how many were taken.
func remove(id: String, n: int) -> int:
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if left > 0 and s != null and s[0] == id:
			var k := mini(left, s[1])
			s[1] -= k
			left -= k
			if s[1] == 0:
				slots[i] = null
	if left < n:
		changed.emit()
	return n - left


## Takes up to `n` items out of slot `i`; returns the stack taken ([id, count]) or null.
func take_slot(i: int, n: int):
	var s = slots[i]
	if s == null or n <= 0:
		return null
	var k := mini(n, s[1])
	s[1] -= k
	if s[1] == 0:
		slots[i] = null
	changed.emit()
	return [s[0], k]


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s[0] == id:
			n += s[1]
	return n


## Every stack in the bag, and the bag emptied (what a death leaves in a sack).
func take_all() -> Array:
	var out := []
	for i in slots.size():
		if slots[i] != null:
			out.append(slots[i])
			slots[i] = null
	if not out.is_empty():
		changed.emit()
	return out


func is_empty() -> bool:
	for s in slots:
		if s != null:
			return false
	return true


## Weight of everything in the bag, kg.
func weight() -> float:
	var w := 0.0
	for s in slots:
		if s != null:
			w += Items.weight(s[0]) * s[1]
	return w


## How much of the carrying limit is used: 1 at the limit.
func load_share() -> float:
	return weight() / weight_limit


## The pace the load allows: 1 up to the limit, down to OVERLOAD_PACE at OVERLOAD
## times the limit and beyond.
func speed_factor() -> float:
	var over := (load_share() - 1.0) / (OVERLOAD - 1.0)
	return clampf(1.0 - over * (1.0 - OVERLOAD_PACE), OVERLOAD_PACE, 1.0)


func overloaded() -> bool:
	return load_share() > 1.0


## The bag as plain data for a save or the network: {"slots": [[id, count] or null...]}.
func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true)}


## Fills the bag from to_dict() data; unknown items are left out.
func from_dict(d: Dictionary) -> void:
	slots.fill(null)
	var saved: Array = d.get("slots", [])
	for i in mini(saved.size(), slots.size()):
		var s = saved[i]
		if s is Array and s.size() == 2 and Items.has(s[0]) and int(s[1]) > 0:
			slots[i] = [Items.get_item(s[0]).id, int(s[1])]
	changed.emit()
