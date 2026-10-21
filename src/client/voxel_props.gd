extends RefCounted
## Voxel models of the prototype props. Placeholder until the voxel editor exists.

const VoxelModel := preload("res://src/client/voxel_model.gd")
const RES := VoxelModel.RES


static func chest() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.55, 0.36, 0.2)
	var band := Color(0.35, 0.22, 0.12)
	var metal := Color(0.8, 0.68, 0.35)
	for y in range(0, 10):
		for z in range(4, 12):
			for x in range(2, 14):
				var c := wood
				if x == 2 or x == 13 or y == 0 or y == 9 or y == 6 or z == 4 or z == 11:
					c = band
				if (y + x) % 5 == 0 and c == wood:
					c = wood * 0.9
				m.set_voxel(Vector3i(x, y, z), c)
	for y in range(4, 8):
		for x in range(7, 9):
			m.set_voxel(Vector3i(x, y, 12), metal)
	return m


## Things lying on the ground (see WorldData.drops), centred on the origin and lying
## on it, by model name (an item's `model`): a log, a branch, an acorn, a cone, the
## tools, a dug-out bush, a sack left by a death and a bundle for any item without a
## model of its own (a block has one of its colour, see block()).
static func drop(model: String) -> VoxelModel:
	match model:
		"log":
			return _log()
		"branch":
			return _branch()
		"acorn":
			return _acorn()
		"cone":
			return _cone()
		"axe":
			return _tool(Color(0.42, 0.44, 0.46), [Vector3i(3, 0, -2), Vector3i(3, 0, -1), Vector3i(4, 0, -2), Vector3i(4, 0, -1), Vector3i(3, 0, 1), Vector3i(4, 0, 1), Vector3i(5, 0, -1), Vector3i(3, 1, -1), Vector3i(4, 1, -1)])
		"pickaxe":
			return _tool(Color(0.42, 0.44, 0.46), [Vector3i(4, 0, -3), Vector3i(4, 0, -2), Vector3i(4, 0, -1), Vector3i(4, 0, 1), Vector3i(4, 0, 2), Vector3i(4, 0, 3), Vector3i(5, 0, -3), Vector3i(5, 0, 3), Vector3i(4, 1, 0)])
		"shovel":
			return _tool(Color(0.42, 0.29, 0.18), [Vector3i(5, 0, -1), Vector3i(5, 0, 1), Vector3i(6, 0, -1), Vector3i(6, 0, 0), Vector3i(6, 0, 1), Vector3i(7, 0, -1), Vector3i(7, 0, 0), Vector3i(7, 0, 1), Vector3i(8, 0, 0)])
		"sword":
			return _sword()
		"bush":
			return _bush()
		"fiber":
			return _fiber()
		"raspberry":
			return _berries(Color(0.78, 0.13, 0.2))
		"blueberry":
			return _berries(Color(0.2, 0.24, 0.52))
		"sack":
			return _sack()
		"bundle":
			return _bundle()
	return null


## A log a cell and a half long along x, its cut ends light with a dark ring.
static func _log() -> VoxelModel:
	var m := VoxelModel.new()
	var bark := Color(0.27, 0.19, 0.13)
	var wood := Color(0.6, 0.46, 0.3)
	for x in range(-6, 6):
		for y in range(0, 4):
			for z in range(-2, 2):
				# Rounded: the corners of the cross-section are left out.
				if (y == 0 or y == 3) and (z == -2 or z == 1):
					continue
				var c := bark * (0.85 if (x * 3 + z) % 5 == 0 else 1.0) * (1.1 if y == 3 else 1.0)
				if x == -6 or x == 5:
					c = wood if (y == 1 or y == 2) and (z == -1 or z == 0) else wood * 0.8
				m.set_voxel(Vector3i(x, y, z), c)
	return m


## A branch with three twigs, leaves at their ends.
static func _branch() -> VoxelModel:
	var m := VoxelModel.new()
	var twig := Color(0.3, 0.21, 0.14)
	var leaf := Color(0.3, 0.45, 0.22)
	for x in range(-7, 8):
		m.set_voxel(Vector3i(x, 0, 0), twig)
		if x < -3:
			m.set_voxel(Vector3i(x, 0, 1), twig)
	for i in 4:
		m.set_voxel(Vector3i(-2 + i, 0, -1 - i), twig)
		m.set_voxel(Vector3i(1 + i, 0, 1 + i), twig)
		m.set_voxel(Vector3i(4 + i, 0, -1 - i / 2), twig)
	for p in [Vector3i(7, 0, 0), Vector3i(1, 0, -4), Vector3i(4, 0, 4), Vector3i(7, 0, -2)]:
		for d in [Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1)]:
			m.set_voxel(p + d, leaf, true)
	return m


static func _acorn() -> VoxelModel:
	var m := VoxelModel.new()
	for x in 2:
		for z in 2:
			m.set_voxel(Vector3i(x - 1, 0, z - 1), Color(0.62, 0.45, 0.22))
			m.set_voxel(Vector3i(x - 1, 1, z - 1), Color(0.42, 0.32, 0.2))
	return m


static func _cone() -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-1, 3):
		for z in 2:
			var c := Color(0.45, 0.3, 0.18) * (0.8 if (x + z) % 2 == 0 else 1.0)
			m.set_voxel(Vector3i(x, 0, z - 1), c)
			if x >= 0 and x <= 1:
				m.set_voxel(Vector3i(x, 1, z - 1), c * 1.1)
	return m


## A tool lying flat: a wooden handle along x and a head of `head` colour in `cells`
## (voxels about its far end).
static func _tool(head: Color, cells: Array) -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.4, 0.28, 0.16)
	for x in range(-6, 5):
		for z in 2:
			m.set_voxel(Vector3i(x, 0, z), wood * (0.8 if (x + z) % 3 == 0 else 1.0))
	for c: Vector3i in cells:
		for z in 2:
			m.set_voxel(c + Vector3i(0, 0, z if c.z >= 0 else -z), head * (1.15 if c.y > 0 else 1.0))
	return m


## A wooden sword lying flat: the blade along x, a cross guard and a grip.
static func _sword() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.5, 0.37, 0.22)
	var dark := Color(0.3, 0.2, 0.12)
	for x in range(-2, 8):
		for z in 2:
			m.set_voxel(Vector3i(x, 0, z), wood * (1.1 if (x + z) % 2 == 0 else 1.0))
	for z in range(-2, 4):
		m.set_voxel(Vector3i(-3, 0, z), dark)
		m.set_voxel(Vector3i(-3, 1, z), dark)
	for x in range(-6, -3):
		m.set_voxel(Vector3i(x, 0, 0), dark)
		m.set_voxel(Vector3i(x, 0, 1), dark)
	return m


## A bush dug out whole: a clump of leaves on a ball of earth.
static func _bush() -> VoxelModel:
	var m := VoxelModel.new()
	var earth := Color(0.4, 0.28, 0.17)
	var leaf := Color(0.3, 0.46, 0.22)
	for z in range(-2, 2):
		for x in range(-2, 2):
			m.set_voxel(Vector3i(x, 0, z), earth)
	for y in range(1, 5):
		var r := 3 if y < 4 else 2
		for z in range(-r, r):
			for x in range(-r, r):
				if (x == -r or x == r - 1) and (z == -r or z == r - 1):
					continue
				if (x * 7 + z * 3 + y * 5) % 6 == 0:
					continue
				m.set_voxel(Vector3i(x, y, z), leaf * (1.15 if (x + y + z) % 3 == 0 else 1.0), true)
	return m


## A twist of grass fibre lying flat.
static func _fiber() -> VoxelModel:
	var m := VoxelModel.new()
	var light := Color(0.62, 0.6, 0.36)
	var green := Color(0.38, 0.5, 0.25)
	for x in range(-4, 5):
		m.set_voxel(Vector3i(x, 0, 0), light if x % 2 == 0 else green)
		m.set_voxel(Vector3i(x, 0, 1 if x % 3 == 0 else -1), green)
	m.set_voxel(Vector3i(0, 1, 0), light)
	return m


## A handful of berries of colour `c` with a leaf.
static func _berries(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for p in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 1), Vector3i(1, 0, -1), Vector3i(0, 1, 0), Vector3i(-1, 0, -1)]:
		m.set_voxel(p, c * (1.2 if p.y > 0 else 1.0))
	m.set_voxel(Vector3i(2, 0, 1), Color(0.3, 0.46, 0.22), true)
	return m


## A clod of a dug block, four voxels a side, of colour `c`.
static func block(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for y in 4:
		for z in range(-2, 2):
			for x in range(-2, 2):
				m.set_voxel(Vector3i(x, y, z), c * (1.12 if y == 3 else (0.9 if (x + z) % 2 == 0 else 1.0)))
	return m


## A tied cloth sack, a little taller than wide.
static func _sack() -> VoxelModel:
	var m := VoxelModel.new()
	var cloth := Color(0.62, 0.52, 0.36)
	var rope := Color(0.36, 0.26, 0.16)
	for y in range(0, 8):
		var r := 4 if y < 5 else (3 if y < 6 else 1)
		for z in range(-r, r):
			for x in range(-r, r):
				if (x == -r or x == r - 1) and (z == -r or z == r - 1):
					continue
				var c := cloth * (0.88 if (x + y * 2 + z) % 4 == 0 else 1.0)
				m.set_voxel(Vector3i(x, y, z), rope if y == 6 else c)
	m.set_voxel(Vector3i(0, 8, 0), rope)
	m.set_voxel(Vector3i(-1, 8, -1), rope)
	return m


## A small bundle of cloth for things without a model of their own.
static func _bundle() -> VoxelModel:
	var m := VoxelModel.new()
	var cloth := Color(0.55, 0.47, 0.34)
	for y in range(0, 3):
		for z in range(-2, 2):
			for x in range(-3, 3):
				if y == 2 and (x == -3 or x == 2):
					continue
				m.set_voxel(Vector3i(x, y, z), cloth * (0.85 if (x + z) % 3 == 0 else 1.0))
	return m
