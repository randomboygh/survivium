extends RefCounted
## The markers the player sets on the map: a column and a colour each, drawn on the
## whole map as flags and on the minimap as dots (kept at its edge while beyond it),
## kept in the player's save (see SaveGame.track) and listed on the playtest page,
## which can take the player to any of them.

## The colours a marker can have: name and colour.
const COLORS := [
	["красный", Color("#e0483a")], ["оранжевый", Color("#ee8a2e")], ["жёлтый", Color("#f2d24a")],
	["зелёный", Color("#6cc24a")], ["голубой", Color("#55b4ec")], ["фиолетовый", Color("#b07ae0")],
]
## How many markers a player keeps at most.
const MAX := 64

## {"cell": Vector2i column, "color": index into COLORS} each, the first set first.
var list: Array = []
## A marker was set, recoloured or taken off.
signal changed


## Sets a marker of colour `color` at column `cell`; the index of the new marker, -1
## when there are MAX already.
func add(cell: Vector2i, color: int) -> int:
	if list.size() >= MAX:
		return -1
	list.append({"cell": cell, "color": clampi(color, 0, COLORS.size() - 1)})
	changed.emit()
	return list.size() - 1


func recolor(i: int, color: int) -> void:
	if i >= 0 and i < list.size():
		list[i].color = clampi(color, 0, COLORS.size() - 1)
		changed.emit()


func remove(i: int) -> void:
	if i >= 0 and i < list.size():
		list.remove_at(i)
		changed.emit()


## The index of the marker nearest column `cell` within `reach` cells, else -1.
func near(cell: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in list.size():
		var d := Vector2(list[i].cell).distance_to(cell)
		if d <= best_d:
			best = i
			best_d = d
	return best


static func color_of(m: Dictionary) -> Color:
	return COLORS[m.color][1]


func to_dict() -> Dictionary:
	return {"list": list.map(func(m: Dictionary) -> Array: return [m.cell.x, m.cell.y, m.color])}


func from_dict(d: Dictionary) -> void:
	list.clear()
	for m in d.get("list", []):
		if m is Array and m.size() == 3:
			list.append({"cell": Vector2i(int(m[0]), int(m[1])), "color": clampi(int(m[2]), 0, COLORS.size() - 1)})
	changed.emit()
