extends RefCounted
## Tools and what they can do to cells: a material says what digs it (its `dig`) and how
## hard it is (`hardness`), a tool item says what it is (`tool`), its power, how many
## cells a swing takes (`area`) and how long a swing lasts (plan/design/character.md,
## "Копание"). Bare hands are the tool when nothing is held. Also the order cells are
## worked in: around a cell that was tapped, and in front of the body for the action
## button (as in Terraria). Shared, so the server can check the same rules.

const Mat := preload("res://src/shared/materials.gd")
const Items := preload("res://src/shared/items.gd")

## Bare hands: leaves, soft ground (slowly, see HAND_SLOW), berries and branches. Not an
## item, so not in the data files.
const HAND := {"id": "", "title": "Руки", "tool": "hand", "power": 1, "area": 1, "swing": 0.45}
## Hands dig soft ground this many times slower than they swing.
const HAND_SLOW := 2.0


## The tool record of item `id` (see Items), bare hands for "" or an item that is no tool.
static func of(id: String) -> Dictionary:
	if id == "":
		return HAND
	var item := Items.get_item(id)
	return item if not item.is_empty() and item.tool != "none" else HAND


static func is_tool_item(id: String) -> bool:
	return of(id) != HAND


## Whether tool `t` (see of) can dig a cell of material `m`.
static func can_dig(t: Dictionary, m: int) -> bool:
	var rec: Dictionary = Mat.RECORDS[m]
	match rec.dig:
		"hand":
			return true
		"shovel":
			return t.tool in ["hand", "shovel", "pickaxe"]
		"pickaxe", "axe":
			return t.tool == rec.dig and t.power >= rec.hardness
	return false


## Why tool `t` cannot dig material `m`, for a message; "" when it can.
static func why_not(t: Dictionary, m: int) -> String:
	if can_dig(t, m):
		return ""
	var rec: Dictionary = Mat.RECORDS[m]
	match rec.dig:
		"pickaxe":
			return "Нужна кирка покрепче" if t.tool == "pickaxe" else "%s: нужна кирка" % rec.title
		"axe":
			return "%s: нужен топор" % rec.title
		"shovel":
			return "%s: копают руками, лопатой или киркой" % rec.title
	return ""


## Seconds a swing of tool `t` at material `m` takes: hands are slow in the ground.
static func swing_time(t: Dictionary, m: int) -> float:
	var slow: bool = t.tool == "hand" and Mat.RECORDS[m].dig == "shovel"
	return t.swing * (HAND_SLOW if slow else 1.0)


## The column step (x, z) for a direction the body faces, snapped to 8 ways.
static func step_of(dir: Vector2) -> Vector2i:
	if dir.length() < 0.01:
		return Vector2i(0, 1)
	var a := snappedf(dir.angle(), PI / 4.0)
	return Vector2i(roundi(cos(a)), roundi(sin(a)))


## Cells the action button works on, in order, for a body with its feet in `feet`
## facing `step`: in front at the feet, the one above it, the one below it, then above
## the head (the body is two cells tall) and under the feet.
static func front_cells(feet: Vector3i, step: Vector2i) -> Array[Vector3i]:
	var front := feet + Vector3i(step.x, 0, step.y)
	return [front, front + Vector3i.UP, front + Vector3i.DOWN, feet + Vector3i(0, 2, 0), feet + Vector3i.DOWN]


## Cells a swing at `hit` works on, in order, when the face `normal` was tapped: the
## cell itself, then its neighbours across that face (up and down first, so a wall
## opens into a passage two cells tall), then the ones at their corners.
static func area_cells(hit: Vector3i, normal: Vector3i) -> Array[Vector3i]:
	var axes := _axes(normal)
	var u := axes[0]
	var v := axes[1]
	return [hit, hit + u, hit - u, hit + v, hit - v, hit + u + v, hit + u - v, hit - u + v, hit - u - v]


## Cells of a square brush `n` cells across, lying across face `normal`, around `center`
## (the centre cell first, then outwards, so each cell placed props up the next).
static func brush_cells(center: Vector3i, normal: Vector3i, n: int) -> Array[Vector3i]:
	var axes := _axes(normal)
	var lo := -((n - 1) / 2)
	var out: Array[Vector3i] = []
	for i in range(lo, lo + n):
		for j in range(lo, lo + n):
			out.append(center + axes[0] * i + axes[1] * j)
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared())
	return out


## The two directions lying across a face with `normal`, up first when it is one of them.
static func _axes(normal: Vector3i) -> Array[Vector3i]:
	var axes: Array[Vector3i] = []
	for d in [Vector3i.UP, Vector3i.RIGHT, Vector3i.BACK]:
		if _across(d, normal):
			axes.append(d)
	return axes


## Whether direction `d` lies across a face with `normal` (is at right angles to it).
static func _across(d: Vector3i, normal: Vector3i) -> bool:
	return d.x * normal.x + d.y * normal.y + d.z * normal.z == 0
