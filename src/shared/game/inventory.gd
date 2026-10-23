extends RefCounted
## A bag of item stacks: a fixed number of slots, each empty or holding one item id up
## to its stack size, and the weight of it all (plan/design/character.md). Weight has a
## limit from strength: past it the carrier slows down (see speed_factor) but may
## still pick things up. A tool wears with use (see wear_tool): its slot keeps how many
## swings it has taken. A chest taken up with things in it keeps them (its contents,
## as to_dict() gives them) and weighs them too. Shared, so the server can keep the
## same bag.

const Items := preload("res://src/shared/content/items.gd")

## Slots of a bag without a backpack, and the weight carried at full pace (kg).
const SLOTS := 16
## The first row of slots, shown on the hotbar (taken into a hand from there).
const HOTBAR := 8
const WEIGHT_LIMIT := 40.0
## Past the limit the pace falls steadily, to OVERLOAD_PACE at OVERLOAD times the limit.
const OVERLOAD := 1.5
const OVERLOAD_PACE := 0.15

signal changed

## Each slot: [id, count], [id, count, worn] for a tool that has taken `worn` swings,
## [id, 1, 0, contents] for a chest with things in it, or null for an empty one.
var slots: Array = []
var weight_limit := WEIGHT_LIMIT
## Whether a chest with things in it may go in (not into another chest).
var nests := true
## Whether weight past the limit weighs on the carrier (slower pace, no jumps, slower
## recovery); a playtest switch turns it off.
var heavy := true


func _init(n := SLOTS) -> void:
	slots.resize(n)


## Puts up to `n` of item `id` (worn by `worn` swings) into the bag, topping up stacks
## first; returns how many went in (fewer when the slots are full). A chest with
## `contents` goes in alone, into a slot of its own.
func add(id: String, n: int, worn := 0, contents: Variant = null) -> int:
	if contents is Dictionary:
		var free := slots.find(null)
		if not nests or free < 0 or n < 1:
			return 0
		slots[free] = [id, 1, worn, contents]
		changed.emit()
		return 1
	var left := n
	var size := Items.stack_size(id)
	for s in slots:
		if left > 0 and s != null and s[0] == id and s[1] < size and _worn(s) == worn and s.size() < 4:
			var k := mini(left, size - s[1])
			s[1] += k
			left -= k
	for i in slots.size():
		if left > 0 and slots[i] == null:
			var k := mini(left, size)
			slots[i] = [id, k, worn] if worn > 0 else [id, k]
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


## Takes up to `n` of item `id` out of the bag, from the last stacks first, never a
## chest with things in it; returns how many were taken.
func remove(id: String, n: int) -> int:
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if left > 0 and s != null and s[0] == id and s.size() < 4:
			var k := mini(left, s[1])
			s[1] -= k
			left -= k
			if s[1] == 0:
				slots[i] = null
	if left < n:
		changed.emit()
	return n - left


## Takes up to `n` items out of slot `i`; returns the stack taken ([id, count],
## [id, count, worn] for a worn tool, [id, 1, 0, contents] for a chest with things in
## it) or null.
func take_slot(i: int, n: int):
	var s = slots[i]
	if s == null or n <= 0:
		return null
	var k := mini(n, s[1])
	s[1] -= k
	if s[1] == 0:
		slots[i] = null
	changed.emit()
	if s.size() > 3:
		return [s[0], k, _worn(s), s[3]]
	return [s[0], k, s[2]] if _worn(s) > 0 else [s[0], k]


## What the chest in slot `i` holds (as to_dict() gives it), or null.
func contents(i: int) -> Variant:
	var s = slots[i]
	return s[3] if s != null and s.size() > 3 else null


## Moves as much of slot `i` as fits into bag `to` (keeping its wear and contents);
## returns how many.
func move_slot(i: int, to) -> int:
	var s = slots[i]
	if s == null:
		return 0
	var n: int = to.add(s[0], s[1], _worn(s), contents(i))
	take_slot(i, n)
	return n


## Moves what fits of slots `from` on into bag `to` (the window's «всё в сундук» skips
## the hotbar row); returns how many things went.
func move_all(to, from := 0) -> int:
	var n := 0
	for i in range(from, slots.size()):
		n += move_slot(i, to)
	return n


## Ways to sort a bag (see sort), with their names for the window.
const SORTS := {"kind": "по виду", "weight": "по весу"}


## Puts the stacks of slots `from` on in order `by` (a key of SORTS): by kind (see
## Items.category, then the order of the data files) or heaviest stack first; stacks
## of one item are topped up first (a slot that keeps more than a count, a worn tool,
## moves whole) and the empty slots go last. The slots before `from` (the
## hotbar row) stay as they are.
func sort(by: String, from := 0) -> void:
	var counts := {}
	var stacks := []
	for i in range(from, slots.size()):
		var s = slots[i]
		if s == null:
			continue
		# A worn tool (or anything else a slot keeps beside the count) stays whole.
		if s.size() > 2:
			stacks.append(s)
		else:
			counts[s[0]] = counts.get(s[0], 0) + s[1]
	for id in counts:
		var size := Items.stack_size(id)
		var left: int = counts[id]
		while left > 0:
			stacks.append([id, mini(left, size)])
			left -= size
	var order := Items.CATEGORIES.keys()
	stacks.sort_custom(func(a: Array, b: Array) -> bool:
		if by == "weight":
			var wa := stack_weight(a)
			var wb := stack_weight(b)
			if wa != wb:
				return wa > wb
		else:
			var ka: int = order.find(Items.category(a[0]))
			var kb: int = order.find(Items.category(b[0]))
			if ka != kb:
				return ka < kb
		var ia: int = Items.IDS.find(a[0])
		var ib: int = Items.IDS.find(b[0])
		if ia != ib:
			return ia < ib
		# One item: fuller stacks first, then the less worn.
		if a[1] != b[1]:
			return a[1] > b[1]
		return _worn(a) < _worn(b))
	var before := slots.slice(from)
	for i in range(from, slots.size()):
		var k := i - from
		slots[i] = stacks[k] if k < stacks.size() else null
	if slots.slice(from) != before:
		changed.emit()


## Puts the stack of slot `i` into slot `j` of bag `to` (this bag or another, a
## chest): onto a stack of the same item as much as it takes, else the two swap. A
## chest with things in it does not go into a bag that does not take one (see
## nests); false then.
func put_into(i: int, to, j: int) -> bool:
	var a = slots[i]
	var b = to.slots[j]
	if a == null or (to == self and i == j):
		return true
	if (not to.nests and a.size() > 3) or (not nests and b != null and b.size() > 3):
		return false
	var room: int = Items.stack_size(a[0]) - b[1] if b != null and b[0] == a[0] and a.size() == 2 and b.size() == 2 else 0
	if room > 0:
		var k := mini(a[1], room)
		b[1] += k
		a[1] -= k
		if a[1] == 0:
			slots[i] = null
	else:
		to.slots[j] = a
		slots[i] = b
	changed.emit()
	if to != self:
		to.changed.emit()
	return true


## Swings the tool in slot `i` has taken.
func worn(i: int) -> int:
	return _worn(slots[i]) if slots[i] != null else 0


static func _worn(s: Array) -> int:
	return s[2] if s.size() > 2 else 0


## One swing of tool `id` that lasts `durability` swings: the first such tool in the
## bag wears; true when it broke and is gone.
func wear_tool(id: String, durability: int) -> bool:
	if durability <= 0:
		return false
	for i in slots.size():
		var s = slots[i]
		if s != null and s[0] == id:
			var w := _worn(s) + 1
			if w >= durability:
				take_slot(i, 1)
				return true
			slots[i] = [s[0], s[1], w]
			changed.emit()
			return false
	return false


## The tool in slot `i` is as good as new.
func mend(i: int) -> void:
	var s = slots[i]
	if s != null and _worn(s) > 0:
		slots[i] = [s[0], s[1]]
		changed.emit()


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


## Weight of everything in the bag, kg, with what chests in it hold.
func weight() -> float:
	var w := 0.0
	for i in slots.size():
		w += slot_weight(i)
	return w


## Weight of slot `i`, kg: its items and what a chest among them holds.
func slot_weight(i: int) -> float:
	return stack_weight(slots[i])


## Weight of stack `s` (a slot's array, or null), kg.
static func stack_weight(s) -> float:
	if s == null:
		return 0.0
	var w: float = Items.weight(s[0]) * s[1]
	if s.size() > 3:
		for held in s[3].get("slots", []):
			if held is Array and held.size() >= 2:
				w += Items.weight(held[0]) * float(held[1])
	return w


## How much of the carrying limit is used: 1 at the limit.
func load_share() -> float:
	return weight() / weight_limit


## The pace the load allows: 1 up to the limit, down to OVERLOAD_PACE at OVERLOAD
## times the limit and beyond.
func speed_factor() -> float:
	if not heavy:
		return 1.0
	var over := (load_share() - 1.0) / (OVERLOAD - 1.0)
	return clampf(1.0 - over * (1.0 - OVERLOAD_PACE), OVERLOAD_PACE, 1.0)


func overloaded() -> bool:
	return heavy and load_share() > 1.0


## The bag as plain data for a save or the network: {"slots": [[id, count] or null...]}.
func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true)}


## Fills the bag from to_dict() data; unknown items are left out.
func from_dict(d: Dictionary) -> void:
	slots.fill(null)
	var saved: Array = d.get("slots", [])
	for i in mini(saved.size(), slots.size()):
		var s = saved[i]
		if s is Array and s.size() in [2, 3, 4] and Items.has(s[0]) and int(s[1]) > 0:
			var w: int = int(s[2]) if s.size() >= 3 else 0
			var id: String = Items.get_item(s[0]).id
			if s.size() == 4 and s[3] is Dictionary:
				slots[i] = [id, 1, w, s[3]]
			else:
				slots[i] = [id, int(s[1]), w] if w > 0 else [id, int(s[1])]
	changed.emit()
