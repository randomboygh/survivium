extends RefCounted
## Voxel models of the furniture of the "Furniture" bundle made of stone and iron, and
## the small interior things (a chair, a bench, a hide rug, a brine tub, a brick stove, a
## hide, a frame and a wreath for a wall). Called by `VoxelArt.prop`; one cell is 8 voxels,
## the front to the south (z grows to the viewer), the bed's head to the west.

const VoxelModel := preload("res://src/client/view/voxel_model.gd")

const WOOD := Color(0.64, 0.47, 0.29)
const WOOD_DARK := Color(0.42, 0.29, 0.17)
const STONE := Color(0.6, 0.6, 0.62)
const STONE_DARK := Color(0.42, 0.42, 0.45)
const IRON := Color(0.34, 0.36, 0.41)
const IRON_LIGHT := Color(0.5, 0.53, 0.58)
const CANVAS := Color(0.86, 0.82, 0.7)
const RED := Color(0.62, 0.25, 0.2)
const BLUE := Color(0.3, 0.38, 0.52)


static func prop(model: String):
	match model:
		"wooden_chair":
			return chair(WOOD, WOOD_DARK, false)
		"iron_chair":
			return chair(IRON, IRON_LIGHT, true)
		"wooden_bench":
			return bench(WOOD, WOOD_DARK, false)
		"stone_bench":
			return bench(STONE, STONE_DARK, true)
		"hide_rug":
			return hide_rug()
		"brine_tub":
			return brine_tub()
		"brick_stove":
			return brick_stove()
		"wall_hide":
			return wall_hide()
		"flower_frame":
			return flower_frame()
		"door_wreath":
			return door_wreath()
		"stone_bed":
			return bed(STONE, STONE_DARK, BLUE, true)
		"iron_bed":
			return bed(IRON, IRON_LIGHT, RED, false)
		"stone_table":
			return stone_table()
		"iron_safe":
			return iron_safe()
	return null


static func _box(m: VoxelModel, a: Vector3i, b: Vector3i, c: Color, shade := true) -> void:
	for y in range(a.y, b.y):
		for z in range(a.z, b.z):
			for x in range(a.x, b.x):
				var k := 1.0
				if shade:
					k = 1.08 if y == b.y - 1 else (0.92 if (x + z + y) % 5 == 0 else 1.0)
				m.set_voxel(Vector3i(x, y, z), c * k)


## A chair on one cell facing south: a seat half a cell high on four legs, a back at the north edge of two
## posts and two rails; the iron one has bars and a red cushion.
static func chair(body: Color, dark: Color, metal: bool) -> VoxelModel:
	var m := VoxelModel.new()
	for p: Vector2i in [Vector2i(1, 1), Vector2i(6, 1), Vector2i(1, 6), Vector2i(6, 6)]:
		_box(m, Vector3i(p.x, 0, p.y), Vector3i(p.x + 1, 3, p.y + 1), dark)
	_box(m, Vector3i(1, 3, 1), Vector3i(7, 4, 7), body)
	if metal:
		_box(m, Vector3i(2, 4, 2), Vector3i(6, 5, 6), RED)
	for y in range(4, 9):
		for x in [1, 6]:
			m.set_voxel(Vector3i(x, y, 1), dark)
	if metal:
		for y in range(5, 9):
			for x in [2, 4, 5]:
				m.set_voxel(Vector3i(x if x != 4 else 3, y, 1), body * 0.9)
		for x in range(1, 7):
			m.set_voxel(Vector3i(x, 8, 1), body)
	else:
		for x in range(2, 6):
			m.set_voxel(Vector3i(x, 5, 1), body)
			m.set_voxel(Vector3i(x, 7, 1), body * 1.08)
	return m


## A bench on two cells long, one deep: a thick seat on legs (wooden planks) or on two blocks (stone).
static func bench(body: Color, dark: Color, solid: bool) -> VoxelModel:
	var m := VoxelModel.new()
	if solid:
		_box(m, Vector3i(2, 0, 1), Vector3i(5, 3, 7), dark)
		_box(m, Vector3i(11, 0, 1), Vector3i(14, 3, 7), dark)
		_box(m, Vector3i(0, 3, 0), Vector3i(16, 5, 8), body)
	else:
		for x in [1, 14]:
			_box(m, Vector3i(x, 0, 1), Vector3i(x + 1, 3, 7), dark)
		_box(m, Vector3i(0, 3, 1), Vector3i(16, 4, 7), body)
		for x in range(0, 16, 4):
			for z in range(1, 7):
				m.set_voxel(Vector3i(x, 3, z), body * 0.85)
	return m


## A hide laid out on two by two cells, one voxel thick: a body, four legs, a head and a tail, a lighter
## belly, dark patches.
static func hide_rug() -> VoxelModel:
	var m := VoxelModel.new()
	var fur := Color(0.5, 0.36, 0.22)
	var pale := Color(0.68, 0.55, 0.38)
	var dark := Color(0.34, 0.24, 0.15)
	for z in range(0, 16):
		for x in range(0, 16):
			var u := (x - 8.0 + 0.5) / 5.5
			var v := (z - 8.0 + 0.5) / 4.6
			var inside := u * u + v * v <= 1.0
			# Legs at the four corners, a head at the south-east and a tail at the north-west.
			if (x in [2, 3] or x in [12, 13]) and (z in [2, 3, 4, 12, 13, 14]):
				inside = true
			if x >= 12 and x <= 14 and z >= 7 and z <= 9 and x != 12:
				inside = true
			if x == 1 and z in [8, 9]:
				inside = true
			if not inside:
				continue
			var c := fur
			if u * u + v * v < 0.35:
				c = pale
			if (x * 7 + z * 3) % 11 == 0:
				c = dark
			m.set_voxel(Vector3i(x, 0, z), c)
	return m


## A brine tub on one cell: a wide low tub of staves with a salt rim, a round wooden lid with a stone on it.
static func brine_tub() -> VoxelModel:
	var m := VoxelModel.new()
	var hoop := Color(0.3, 0.26, 0.22)
	for y in 5:
		for z in 8:
			for x in 8:
				var d := Vector2(x + 0.5 - 4.0, z + 0.5 - 4.0).length()
				if d > 3.9:
					continue
				var c := WOOD * (0.86 if (x + z * 3) % 4 == 0 else 1.0)
				if y == 1 or y == 3:
					c = hoop
				if y == 4:
					c = Color(0.9, 0.9, 0.86) if d > 3.0 else WOOD * (1.1 if x % 3 else 0.9)
				m.set_voxel(Vector3i(x, y, z), c)
	for z in range(3, 5):
		for x in range(3, 5):
			m.set_voxel(Vector3i(x, 5, z), STONE)
	m.set_voxel(Vector3i(3, 6, 3), STONE * 1.1)
	m.set_voxel(Vector3i(4, 6, 4), STONE * 1.1)
	return m


## A brick stove ("Dutch") on one cell, two cells tall: a brick body with a whitewashed band, an iron firebox
## door and a small ash door on its front, a chimney pipe of iron on top.
static func brick_stove() -> VoxelModel:
	var m := VoxelModel.new()
	var brick := Color(0.66, 0.33, 0.24)
	var mortar := Color(0.74, 0.68, 0.6)
	var white := Color(0.86, 0.84, 0.78)
	for y in 13:
		for z in range(1, 7):
			for x in range(1, 7):
				var c := brick * (0.9 if (x + z + y / 2) % 3 == 0 else 1.0)
				if y % 3 == 2:
					c = mortar * 0.95
				if y >= 9 and y <= 11:
					c = white * (0.95 if (x + y) % 4 == 0 else 1.0)
				if y == 12:
					c = mortar
				m.set_voxel(Vector3i(x, y, z), c)
	# The iron doors on the south face.
	for y in range(5, 9):
		for x in range(2, 6):
			m.set_voxel(Vector3i(x, y, 7), IRON_LIGHT if y == 8 or x == 2 else IRON)
	m.set_voxel(Vector3i(4, 6, 7), Color(0.8, 0.7, 0.3))
	for x in range(2, 6):
		m.set_voxel(Vector3i(x, 1, 7), IRON)
		m.set_voxel(Vector3i(x, 2, 7), IRON_LIGHT)
	for y in range(13, 16):
		for z in range(3, 5):
			for x in range(3, 5):
				m.set_voxel(Vector3i(x, y, z), IRON * (1.2 if x == 3 else 1.0))
	return m


## A hide stretched on a frame of sticks for a wall: a thin sheet on the cell's north edge, tied with cords at
## the corners.
static func wall_hide() -> VoxelModel:
	var m := VoxelModel.new()
	var fur := Color(0.55, 0.4, 0.25)
	var pale := Color(0.72, 0.6, 0.43)
	for y in range(1, 12):
		for x in range(0, 8):
			var half := 3.5 - 0.5 * absf(y - 6.0) * 0.35 if y > 2 and y < 10 else 2.5
			if absf(x + 0.5 - 4.0) > half + 0.5 and y > 2 and y < 10:
				continue
			var c := fur
			if (x + y * 2) % 5 == 0:
				c = pale
			m.set_voxel(Vector3i(x, y, 1), c)
	for x in range(0, 8):
		m.set_voxel(Vector3i(x, 12, 0), WOOD_DARK)
		m.set_voxel(Vector3i(x, 0, 0), WOOD_DARK)
	for p: Vector2i in [Vector2i(1, 11), Vector2i(6, 11), Vector2i(1, 1), Vector2i(6, 1)]:
		m.set_voxel(Vector3i(p.x, p.y, 0), Color(0.82, 0.72, 0.5))
	return m


## A framed dried flower on the cell's north edge: a plank frame, a pale sheet, a flower with a stem.
static func flower_frame() -> VoxelModel:
	var m := VoxelModel.new()
	var paper := Color(0.9, 0.86, 0.74)
	for y in range(3, 11):
		for x in range(1, 7):
			var rim := x == 1 or x == 6 or y == 3 or y == 10
			m.set_voxel(Vector3i(x, y, 1), WOOD_DARK * 1.2 if rim else paper)
	for y in range(4, 8):
		m.set_voxel(Vector3i(3, y, 1), Color(0.35, 0.55, 0.28))
	m.set_voxel(Vector3i(2, 5, 1), Color(0.3, 0.5, 0.25))
	for p: Vector2i in [Vector2i(3, 8), Vector2i(2, 8), Vector2i(4, 8), Vector2i(3, 9)]:
		m.set_voxel(Vector3i(p.x, p.y, 1), Color(0.55, 0.3, 0.6))
	m.set_voxel(Vector3i(3, 8, 1), Color(0.95, 0.8, 0.25))
	return m


## A wreath of fir with berries for a door: a ring six voxels across, one voxel thick, a red bow at the bottom.
static func door_wreath() -> VoxelModel:
	var m := VoxelModel.new()
	for y in range(1, 9):
		for x in range(0, 8):
			var d := Vector2(x + 0.5 - 4.0, y + 0.5 - 4.5).length()
			if d > 3.8 or d < 1.9:
				continue
			var c := Color(0.2, 0.42, 0.24) * (1.15 if (x + y) % 3 == 0 else 1.0)
			if (x * 3 + y) % 7 == 0:
				c = Color(0.75, 0.15, 0.15)
			m.set_voxel(Vector3i(x, y, 1), c)
	m.set_voxel(Vector3i(3, 1, 2), RED)
	m.set_voxel(Vector3i(4, 1, 2), RED)
	m.set_voxel(Vector3i(2, 0, 2), RED * 0.8)
	m.set_voxel(Vector3i(5, 0, 2), RED * 0.8)
	return m


## A bed on two by two cells, the head to the west: a frame, a headboard, a pale mattress, a pillow and a
## blanket on the foot half. Stone: a slab on a plinth; iron: a rail with bars at the head and foot.
static func bed(body: Color, dark: Color, blanket: Color, solid: bool) -> VoxelModel:
	var m := VoxelModel.new()
	for z in range(2, 14):
		for x in range(0, 16):
			var edge := x == 0 or x == 15 or z == 2 or z == 13
			if solid:
				m.set_voxel(Vector3i(x, 0, z), dark)
				m.set_voxel(Vector3i(x, 1, z), body * (1.1 if edge else 1.0))
			else:
				m.set_voxel(Vector3i(x, 0, z), dark if edge else body * 0.8)
				m.set_voxel(Vector3i(x, 1, z), body if edge else CANVAS * 0.92)
	var base := 2 if solid else 2
	for z in range(3, 13):
		for x in range(1, 15):
			var top := CANVAS * 0.95
			if x >= 8:
				top = blanket * (0.85 if z == 3 or z == 12 else (1.08 if (x + z) % 5 == 0 else 1.0))
			if solid:
				m.set_voxel(Vector3i(x, 2, z), top)
			else:
				m.set_voxel(Vector3i(x, 2, z), top)
	for z in range(4, 12):
		for x in range(2, 5):
			m.set_voxel(Vector3i(x, 3, z), CANVAS * (1.08 if (x + z) % 3 else 1.0))
	if solid:
		for z in range(2, 14):
			for y in range(2, 5):
				m.set_voxel(Vector3i(0, y, z), body * (1.1 if y == 4 else 1.0))
	else:
		for y in range(2, 7):
			for z in [2, 13]:
				m.set_voxel(Vector3i(0, y, z), dark)
				m.set_voxel(Vector3i(15, y, z), dark if y < 5 else body)
		for z in range(2, 14):
			m.set_voxel(Vector3i(0, 6, z), dark)
			if z % 3 != 0:
				for y in range(2, 6):
					m.set_voxel(Vector3i(0, y, z), body * 0.9)
		for z in range(2, 14):
			m.set_voxel(Vector3i(15, 4, z), dark)
	return m


## A stone table on two by two cells: a slab of cut stone on two thick pillars, seams across the slab.
static func stone_table() -> VoxelModel:
	var m := VoxelModel.new()
	for y in 4:
		for z in range(2, 14):
			for x in list_range(2, 5) + list_range(11, 14):
				m.set_voxel(Vector3i(x, y, z), STONE_DARK * (1.1 if x in [2, 11] else 1.0))
	for z in range(1, 15):
		for x in range(0, 16):
			var c := STONE * (0.86 if x % 5 == 0 else 1.0)
			if x == 0 or x == 15 or z == 1 or z == 14:
				c = STONE * 1.12
			m.set_voxel(Vector3i(x, 4, z), c)
			m.set_voxel(Vector3i(x, 5, z), c * 1.04)
	return m


static func list_range(a: int, b: int) -> Array:
	var r := []
	for i in range(a, b):
		r.append(i)
	return r


## A safe on one cell, two cells tall: a riveted iron body, a heavy door with a wheel handle and hinges, a
## plinth.
static func iron_safe() -> VoxelModel:
	var m := VoxelModel.new()
	for y in 14:
		for z in range(1, 7):
			for x in range(0, 8):
				var c := IRON * (1.15 if y == 13 or x == 0 else (0.9 if (x + y) % 6 == 0 else 1.0))
				if y == 0 or y == 1:
					c = IRON * 0.7
				m.set_voxel(Vector3i(x, y, z), c)
	# The door on the south face: a lighter plate, rivets at its corners, a wheel in the middle.
	for y in range(3, 12):
		for x in range(1, 7):
			m.set_voxel(Vector3i(x, y, 7), IRON_LIGHT * (0.9 if x == 1 or x == 6 else 1.0))
	for p: Vector2i in [Vector2i(2, 4), Vector2i(5, 4), Vector2i(2, 10), Vector2i(5, 10)]:
		m.set_voxel(Vector3i(p.x, p.y, 7), IRON * 0.7)
	var gold := Color(0.85, 0.7, 0.3)
	for p: Vector2i in [Vector2i(3, 7), Vector2i(4, 7), Vector2i(3, 8), Vector2i(4, 8)]:
		m.set_voxel(Vector3i(p.x, p.y, 8), gold)
	for p: Vector2i in [Vector2i(3, 6), Vector2i(4, 6), Vector2i(3, 9), Vector2i(4, 9), Vector2i(2, 7), Vector2i(2, 8), Vector2i(5, 7), Vector2i(5, 8)]:
		m.set_voxel(Vector3i(p.x, p.y, 7), gold * 0.85)
	return m
