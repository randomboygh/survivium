extends RefCounted
## Tools and what they can do to cells: a material says what digs it (its `dig`) and how
## hard it is (`hardness`), a tool item says what it is (`tool`), its power, how many
## cells a swing takes (`area`), how long a swing lasts and how far it reaches
## (plan/design/character.md, "Взаимодействие с миром"). Bare hands are the tool when
## nothing is held. Hands, a sword and a scythe cut the top of grass (the material's
## `mow`) before anything digs the ground under it. Also what a held item is used for,
## the order cells are worked in (around a cell that was tapped, and in front of the
## body for the action button, outward from it so the body is dug under last), and the
## shapes of the brush blocks are placed with. Shared, so the server can check the same
## rules.

const Mat := preload("res://src/shared/materials.gd")
const Items := preload("res://src/shared/items.gd")

## Bare hands: grass, leaves, soft ground (slowly, see HAND_SLOW), berries and branches.
## Not an item, so not in the data files.
const HAND := {"id": "", "title": "Руки", "tool": "hand", "power": 1, "area": 1, "swing": 0.45, "reach": 8}
## Hands dig soft ground this many times slower than they swing.
const HAND_SLOW := 2.0
## How far blocks, plants and seeds are placed from the body, in cells.
const PLACE_REACH := 10
## Tools that cut the top of grass.
const MOWERS := ["hand", "sword", "scythe"]
## Brushes of the hand that places: squares across the tapped face, two cells one on
## top of the other (a wall a body tall, or the opening of a passage), and a line (one
## cell, the stroke kept straight along the way it first went).
const BRUSHES := [
	{"title": "1×1", "size": 1},
	{"title": "2×2", "size": 2},
	{"title": "3×3", "size": 3},
	{"title": "1×2", "size": 1, "tall": true},
	{"title": "линия", "size": 1, "line": true},
]


## The tool record of item `id` (see Items), bare hands for "" or an item that is no tool.
static func of(id: String) -> Dictionary:
	if id == "":
		return HAND
	var item := Items.get_item(id)
	return item if not item.is_empty() and item.tool != "none" else HAND


static func is_tool_item(id: String) -> bool:
	return of(id) != HAND


## What item `id` in a hand is used for: "tool" (dig, chop, mow with it), "place" (a
## block), "plant" (a bush), "sow" (seeds), "prop" (a thing set on the ground), "eat"
## (food), else "hand" (the hand works as bare hands).
static func use_of(id: String) -> String:
	if id == "":
		return "hand"
	var item := Items.get_item(id)
	if item.is_empty():
		return "hand"
	if item.tool != "none":
		return "tool"
	if item.place != "":
		return "place"
	if item.plant != "":
		return "plant"
	if item.sow != "":
		return "sow"
	if item.prop != "none":
		return "prop"
	if item.food > 0.0:
		return "eat"
	return "hand"


## The material a cell of `m` becomes when its top is cut, -1 when it has no top to cut.
static func mown(m: int) -> int:
	var to: String = Mat.RECORDS[m].mow
	return Mat.index(to) if to != "" else -1


## Whether tool `t` cuts the top of grass.
static func mows(t: Dictionary) -> bool:
	return t.tool in MOWERS


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


## Seconds a swing of tool `t` at material `m` takes: hands are slow in the ground (not
## when they cut grass).
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
## facing `step`, outward from the body like a pit dug around it: at the feet's level
## the cell in front, the one beyond it, the ones left and right of the first, the ones
## beyond those (see front_ring); then the same a level lower and a level higher; then
## the cell over the head (the body is two cells tall) and last the one under the feet.
static func front_cells(feet: Vector3i, step: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for dy in [0, -1, 1]:
		for o in front_ring(step):
			out.append(feet + o + Vector3i(0, dy, 0))
	out.append(feet + Vector3i(0, 2, 0))
	out.append(feet + Vector3i.DOWN)
	return out


## The columns in front of a body facing `step`, as offsets from its feet, in the order
## of front_cells: in front, beyond it, left and right of the first, beyond those. Facing
## a diagonal, left and right are the two columns that touch both the body's and the
## front one.
static func front_ring(step: Vector2i) -> Array[Vector3i]:
	var s := Vector3i(step.x, 0, step.y)
	var sides := _sides(step)
	return [s, s * 2, s + sides[0], s + sides[1], s * 2 + sides[0], s * 2 + sides[1]]


## Offsets from the column in front to the ones left and right of it (see front_ring).
static func _sides(step: Vector2i) -> Array[Vector3i]:
	if step.x == 0 or step.y == 0:
		return [Vector3i(-step.y, 0, step.x), Vector3i(step.y, 0, -step.x)]
	return [Vector3i(0, 0, -step.y), Vector3i(-step.x, 0, 0)]


## Cells a scythe sweeps when it swings at `cell` facing `step`: that cell and the ones
## left and right of it, in an arc in front of the body.
static func sweep(cell: Vector3i, step: Vector2i) -> Array[Vector3i]:
	var sides := _sides(step)
	return [cell, cell + sides[0], cell + sides[1]]


## Columns around a body facing `step` (offsets from its feet) where it can reach a tree
## or a bush with the action button: up to two columns away and not behind it, the
## nearest first and, at one distance, the ones most ahead.
static func sector(step: Vector2i) -> Array[Vector2i]:
	var ahead := Vector2(step).normalized()
	var out: Array[Vector2i] = []
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var o := Vector2i(dx, dz)
			var d := Vector2(o)
			if o == Vector2i.ZERO:
				continue
			var cos_a := d.normalized().dot(ahead)
			if cos_a >= 0.3 or d.length() < 1.5 and cos_a >= -0.1:
				out.append(o)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var la := Vector2(a).length() - Vector2(a).normalized().dot(ahead) * 0.4
		var lb := Vector2(b).length() - Vector2(b).normalized().dot(ahead) * 0.4
		return la < lb)
	return out


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


## Cells of `brush` (one of BRUSHES) placed around `center` on face `normal`, in the
## order of brush_cells.
static func brush_shape(center: Vector3i, normal: Vector3i, brush: Dictionary) -> Array[Vector3i]:
	if brush.get("tall", false):
		return [center, center + Vector3i.UP]
	return brush_cells(center, normal, brush.size)


## Whether direction `d` lies across a face with `normal` (is at right angles to it).
static func _across(d: Vector3i, normal: Vector3i) -> bool:
	return d.x * normal.x + d.y * normal.y + d.z * normal.z == 0
