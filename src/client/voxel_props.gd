extends RefCounted
## Voxel models of the prototype props. Placeholder until the voxel editor exists.

const VoxelModel := preload("res://src/client/voxel_model.gd")
const RES := VoxelModel.RES


## The model of a thing placed on two by two cells by its item's `prop` (16 voxels a
## world unit, the front to the south).
static func prop(kind: String) -> VoxelModel:
	match kind:
		"workbench":
			return workbench()
		"kiln":
			return kiln()
	return chest()


## A workbench: a plank top on four legs, a log for a stool's worth of work on it.
static func workbench() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.62, 0.45, 0.27)
	var dark := Color(0.4, 0.27, 0.15)
	var stone := Color(0.5, 0.52, 0.54)
	for y in range(0, 7):
		for p in [Vector2i(2, 4), Vector2i(13, 4), Vector2i(2, 11), Vector2i(13, 11)]:
			m.set_voxel(Vector3i(p.x, y, p.y), dark)
	for z in range(3, 13):
		for x in range(1, 15):
			var c := wood if z % 3 != 0 else wood * 0.88
			m.set_voxel(Vector3i(x, 7, z), c)
			if x == 1 or x == 14 or z == 3 or z == 12:
				m.set_voxel(Vector3i(x, 6, z), dark)
	# A flint and a cut branch lying on top.
	for x in range(4, 7):
		m.set_voxel(Vector3i(x, 8, 6), stone)
	for x in range(8, 13):
		m.set_voxel(Vector3i(x, 8, 9), dark)
	return m


## A kiln: a squat dome of clay-daubed stone with a dark mouth to the south and a glow in it.
static func kiln() -> VoxelModel:
	var m := VoxelModel.new()
	var clay := Color(0.66, 0.42, 0.3)
	var stone := Color(0.52, 0.5, 0.48)
	var soot := Color(0.12, 0.1, 0.09)
	var glow := Color(0.95, 0.5, 0.18)
	for y in range(0, 12):
		var r := 6.5 - maxf(0.0, y - 5.0) * 0.75
		for z in range(1, 15):
			for x in range(1, 15):
				var d := Vector2(x - 7.5, z - 7.5).length()
				if d > r:
					continue
				var c := clay if (x * 7 + y * 3 + z * 5) % 4 != 0 else stone
				if y == 0 or (d > r - 1.2 and (x + y) % 5 == 0):
					c = stone
				m.set_voxel(Vector3i(x, y, z), c * (1.08 if y >= 9 else 1.0))
	for y in range(1, 5):
		for x in range(6, 10):
			m.set_voxel(Vector3i(x, y, 13), soot if y > 1 else glow)
			m.set_voxel(Vector3i(x, y, 14), soot if y > 1 else glow)
	for y in range(12, 14):
		for x in range(7, 9):
			for z in range(7, 9):
				m.set_voxel(Vector3i(x, y, z), soot)
	return m


## A chest: a plank box with a rounded lid, iron bands over it and an iron lock plate
## with a keyhole on the front (to the south).
static func chest() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.6, 0.4, 0.22)
	var seam := Color(0.36, 0.23, 0.12)
	var iron := Color(0.38, 0.38, 0.4)
	var rivet := Color(0.62, 0.62, 0.64)
	var brass := Color(0.86, 0.7, 0.32)
	# The body: planks lying along x, a dark seam between them every three voxels, each
	# plank its own shade so the wood reads as boards.
	for y in range(0, 7):
		for z in range(3, 13):
			for x in range(1, 15):
				var inside: bool = x > 1 and x < 14 and z > 3 and z < 12 and y > 0
				if inside:
					continue
				var c := wood * (0.92 + 0.08 * float((floori(y / 3.0) * 5 + 3) % 3))
				if y % 3 == 2:
					c = seam
				if (x * 7 + y * 13 + z * 3) % 11 == 0:
					c = c * 0.9
				m.set_voxel(Vector3i(x, y, z), c)
	# The lid: a half round over the box, planks along x again.
	for z in range(3, 13):
		var t := (z - 7.5) / 5.0
		var top := 7 + int(round(2.0 * sqrt(maxf(0.0, 1.0 - t * t))))
		for y in range(7, top + 1):
			for x in range(1, 15):
				var shell: bool = x == 1 or x == 14 or y == top or z == 3 or z == 12
				if not shell:
					continue
				var c := wood * (1.06 if (z + y) % 2 == 0 else 1.0)
				if (z - 3) % 3 == 0 and y == top:
					c = seam
				m.set_voxel(Vector3i(x, y, z), c)
	# Iron bands over the lid and down the front and the back, and on the corners.
	for x in [3, 12]:
		for z in range(3, 13):
			var t := (z - 7.5) / 5.0
			var top := 7 + int(round(2.0 * sqrt(maxf(0.0, 1.0 - t * t))))
			m.set_voxel(Vector3i(x, top, z), iron)
		for y in range(0, 10):
			for z in [3, 12]:
				if m.voxels.has(Vector3i(x, y, z)):
					m.set_voxel(Vector3i(x, y, z), rivet if y % 3 == 1 else iron)
	for y in range(0, 7):
		for c in [Vector3i(1, y, 3), Vector3i(14, y, 3), Vector3i(1, y, 12), Vector3i(14, y, 12)]:
			m.set_voxel(c, iron)
	# The lid's rim and the lock plate with its keyhole.
	for x in range(1, 15):
		m.set_voxel(Vector3i(x, 7, 12), iron if x % 4 != 2 else rivet)
	for y in range(4, 9):
		for x in range(6, 10):
			m.set_voxel(Vector3i(x, y, 13), brass)
	m.set_voxel(Vector3i(7, 5, 13), seam * 0.5)
	m.set_voxel(Vector3i(8, 5, 13), seam * 0.5)
	m.set_voxel(Vector3i(7, 6, 13), seam * 0.5)
	return m


## How high model `m` stands, in voxels (16 a world unit).
static func height(m: VoxelModel) -> float:
	var top := 0
	for p: Vector3i in m.voxels:
		top = maxi(top, p.y + 1)
	return top


## Things lying on the ground (see WorldData.drops), centred on the origin and lying
## on it, by model name (an item's `model`): a log, a branch, an acorn, a cone, the
## tools, a dug-out bush, grain, flour, a flatbread, seeds, a sack left by a death and a bundle for any item without a
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
		"pickaxe", "wooden_pickaxe":
			return _tool(Color(0.42, 0.44, 0.46) if model == "pickaxe" else Color(0.55, 0.4, 0.24), [Vector3i(4, 0, -3), Vector3i(4, 0, -2), Vector3i(4, 0, -1), Vector3i(4, 0, 1), Vector3i(4, 0, 2), Vector3i(4, 0, 3), Vector3i(5, 0, -3), Vector3i(5, 0, 3), Vector3i(4, 1, 0)])
		"shovel":
			return _tool(Color(0.42, 0.29, 0.18), [Vector3i(5, 0, -1), Vector3i(5, 0, 1), Vector3i(6, 0, -1), Vector3i(6, 0, 0), Vector3i(6, 0, 1), Vector3i(7, 0, -1), Vector3i(7, 0, 0), Vector3i(7, 0, 1), Vector3i(8, 0, 0)])
		"sword", "stone_sword":
			return _sword(Color(0.5, 0.37, 0.22) if model == "sword" else Color(0.55, 0.57, 0.6))
		"scythe", "wooden_scythe":
			return _tool(Color(0.42, 0.44, 0.46) if model == "scythe" else Color(0.55, 0.4, 0.24), [Vector3i(4, 0, 2), Vector3i(4, 0, 3), Vector3i(3, 0, 4), Vector3i(2, 0, 5), Vector3i(1, 0, 5), Vector3i(0, 0, 6), Vector3i(-1, 0, 6), Vector3i(3, 1, 3)])
		"grain":
			return _heap(Color(0.82, 0.66, 0.32))
		"flour":
			return _heap(Color(0.92, 0.9, 0.84))
		"flatbread":
			return _flatbread()
		"seeds":
			return _seeds()
		"bush":
			return _bush()
		"fiber":
			return _fiber()
		"flint":
			return _flint()
		"cord":
			return _cord()
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
static func _sword(blade: Color) -> VoxelModel:
	var m := VoxelModel.new()
	var wood := blade
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


## A small heap of something loose (grain, flour) of colour `c`.
static func _heap(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for z in range(-2, 2):
		for x in range(-2, 2):
			m.set_voxel(Vector3i(x, 0, z), c * (0.88 if (x + z) % 2 == 0 else 1.0))
	for p in [Vector3i(-1, 1, -1), Vector3i(0, 1, -1), Vector3i(-1, 1, 0), Vector3i(0, 1, 0)]:
		m.set_voxel(p, c * 1.1)
	return m


## A round flatbread lying flat.
static func _flatbread() -> VoxelModel:
	var m := VoxelModel.new()
	var crust := Color(0.72, 0.5, 0.26)
	var top := Color(0.84, 0.66, 0.38)
	for z in range(-3, 3):
		for x in range(-3, 3):
			if (x == -3 or x == 2) and (z == -3 or z == 2):
				continue
			m.set_voxel(Vector3i(x, 0, z), crust)
			if absi(x * 2 + 1) < 5 and absi(z * 2 + 1) < 5:
				m.set_voxel(Vector3i(x, 1, z), top * (0.9 if (x * 3 + z) % 4 == 0 else 1.0))
	return m


## A small heap of seeds.
static func _seeds() -> VoxelModel:
	var m := VoxelModel.new()
	var seed := Color(0.6, 0.45, 0.25)
	for p in [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 0, 1),
			Vector3i(-1, 0, -1), Vector3i(0, 1, 0), Vector3i(2, 0, -1), Vector3i(-2, 0, 1)]:
		m.set_voxel(p, seed * (1.2 if p.y > 0 else (0.85 if (p.x + p.z) % 2 == 0 else 1.0)))
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


## A knapped flint: a dark grey lump with a pale edge.
static func _flint() -> VoxelModel:
	var m := VoxelModel.new()
	var dark := Color(0.3, 0.31, 0.34)
	var edge := Color(0.62, 0.62, 0.6)
	for x in range(-2, 2):
		for z in range(-1, 2):
			m.set_voxel(Vector3i(x, 0, z), dark)
	for x in range(-1, 1):
		m.set_voxel(Vector3i(x, 1, 0), dark)
	m.set_voxel(Vector3i(1, 0, -1), edge)
	m.set_voxel(Vector3i(1, 0, 0), edge)
	return m


## A coil of cord.
static func _cord() -> VoxelModel:
	var m := VoxelModel.new()
	var cord := Color(0.72, 0.6, 0.38)
	for x in range(-2, 3):
		for z in range(-2, 3):
			var d := Vector2(x, z).length()
			if d > 1.2 and d < 2.6:
				m.set_voxel(Vector3i(x, 0, z), cord * (0.85 if (x + z) % 2 == 0 else 1.0))
	m.set_voxel(Vector3i(2, 0, 0), cord * 0.8)
	m.set_voxel(Vector3i(3, 0, 1), cord * 0.8)
	return m
