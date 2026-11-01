extends RefCounted
## The voxel models of the prototype's things, drawn in code: `tools/make_models.gd` writes
## them as PNG slices into `content/<mod>/models/`, where the game reads them and where they
## can be painted over by hand. Not loaded by the game.

const VoxelModel := preload("res://src/client/view/voxel_model.gd")

## The colour of copper heads, blades and bars.
const COPPER := Color(0.78, 0.46, 0.25)
## Bronze and tin.
const BRONZE := Color(0.6, 0.48, 0.27)
const TIN := Color(0.72, 0.74, 0.76)
## Iron (dark, bluish) and steel (pale, cold).
const IRON := Color(0.32, 0.34, 0.38)
const STEEL := Color(0.66, 0.72, 0.8)


## The model of a thing placed on two by two cells by its item's `prop` (16 voxels a
## world unit, the front to the south), null for none.
static func prop(kind: String) -> VoxelModel:
	match kind:
		"workbench":
			return workbench()
		"kiln":
			return kiln()
		"chest":
			return chest()
		"forge":
			return forge()
		"loom":
			return loom()
		"potters_wheel":
			return potters_wheel()
		"bloomery":
			return bloomery()
		"anvil":
			return anvil()
		"drying_rack":
			return drying_rack()
	return null


## Things lying on the ground (see WorldData.drops), centred on the origin and lying
## on it, by model name (an item's `model`), null for a name not drawn here.
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
		"copper_axe", "bronze_axe", "iron_axe", "steel_axe":
			return _tool(_head(model), [Vector3i(3, 0, -2), Vector3i(3, 0, -1), Vector3i(4, 0, -2), Vector3i(4, 0, -1), Vector3i(3, 0, 1), Vector3i(4, 0, 1), Vector3i(5, 0, -1), Vector3i(3, 1, -1), Vector3i(4, 1, -1)])
		"pickaxe", "wooden_pickaxe", "copper_pickaxe", "bronze_pickaxe", "iron_pickaxe", "steel_pickaxe":
			return _tool(_head(model), [Vector3i(4, 0, -3), Vector3i(4, 0, -2), Vector3i(4, 0, -1), Vector3i(4, 0, 1), Vector3i(4, 0, 2), Vector3i(4, 0, 3), Vector3i(5, 0, -3), Vector3i(5, 0, 3), Vector3i(4, 1, 0)])
		"shovel", "copper_shovel", "bronze_shovel", "iron_shovel", "steel_shovel":
			return _tool(Color(0.42, 0.29, 0.18) if model == "shovel" else _head(model), [Vector3i(5, 0, -1), Vector3i(5, 0, 1), Vector3i(6, 0, -1), Vector3i(6, 0, 0), Vector3i(6, 0, 1), Vector3i(7, 0, -1), Vector3i(7, 0, 0), Vector3i(7, 0, 1), Vector3i(8, 0, 0)])
		"sword", "stone_sword", "copper_sword", "bronze_sword", "iron_sword", "steel_sword":
			return _sword(Color(0.5, 0.37, 0.22) if model == "sword" else (Color(0.55, 0.57, 0.6) if model == "stone_sword" else _head(model)))
		"scythe", "wooden_scythe", "copper_scythe", "bronze_scythe", "iron_scythe", "steel_scythe":
			return _tool(_head(model), [Vector3i(4, 0, 2), Vector3i(4, 0, 3), Vector3i(3, 0, 4), Vector3i(2, 0, 5), Vector3i(1, 0, 5), Vector3i(0, 0, 6), Vector3i(-1, 0, 6), Vector3i(3, 1, 3)])
		"torch":
			return _torch()
		"tar_torch":
			return _torch(Color(0.12, 0.1, 0.08))
		"copper_bar":
			return _bar()
		"bronze_bar":
			return _bar(BRONZE)
		"tin_bar":
			return _bar(TIN)
		"iron_bar":
			return _bar(IRON)
		"steel_bar":
			return _bar(STEEL)
		"iron_bloom":
			return _bloom()
		"flint_knife", "copper_knife", "bronze_knife", "iron_knife", "steel_knife":
			return _knife(Color(0.3, 0.31, 0.34) if model == "flint_knife" else _head(model))
		"flint_spear", "bronze_spear", "iron_spear":
			return _spear(Color(0.3, 0.31, 0.34) if model == "flint_spear" else _head(model))
		"cord_sling":
			return _sling(Color(0.5, 0.36, 0.22), Color(0.8, 0.74, 0.6))
		"leather_sling":
			return _sling(Color(0.42, 0.27, 0.16), Color(0.62, 0.44, 0.28))
		"sling_stone":
			return _pebbles()
		"wooden_bow":
			return _bow(Color(0.55, 0.38, 0.2), Color(0.55, 0.38, 0.2))
		"composite_bow":
			return _bow(Color(0.45, 0.3, 0.16), Color(0.92, 0.9, 0.82))
		"arrow":
			return _arrow()
		"small_carcass":
			return _carcass(Color(0.55, 0.45, 0.36), Vector3i(3, 2, 1))
		"carcass":
			return _carcass(Color(0.5, 0.36, 0.24), Vector3i(6, 3, 3))
		"raw_meat":
			return _meat(Color(0.72, 0.2, 0.2), Color(0.92, 0.84, 0.8))
		"roasted_meat":
			return _meat(Color(0.48, 0.26, 0.12), Color(0.66, 0.42, 0.2))
		"hide":
			return _hide(Color(0.56, 0.4, 0.26), true)
		"leather":
			return _hide(Color(0.66, 0.45, 0.27), false)
		"jerky":
			return _meat(Color(0.4, 0.16, 0.12), Color(0.55, 0.3, 0.2))
		"bone_needle":
			return _needle()
		"bone_glue":
			return _heap(Color(0.82, 0.62, 0.3))
		"tallow_candle":
			return _candle()
		"bone":
			return _bone()
		"fat":
			return _heap(Color(0.95, 0.9, 0.74))
		"raw_crucible":
			return _crucible(Color(0.7, 0.64, 0.56))
		"crucible":
			return _crucible(Color(0.62, 0.36, 0.22))
		"charcoal":
			return _charcoal()
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
		"mushroom":
			return _mushroom(Color(0.48, 0.28, 0.15))
		"glow_mushroom":
			return _mushroom(Color(0.42, 0.95, 0.82))
		"fried_mushrooms":
			return _heap(Color(0.45, 0.3, 0.16))
		"moss":
			return _moss()
		"bandage":
			return _bandage()
		"raspberry":
			return _berries(Color(0.78, 0.13, 0.2))
		"blueberry":
			return _berries(Color(0.2, 0.24, 0.52))
		"flax_stalks":
			return _flax()
		"linen_thread":
			return _skein(Color(0.88, 0.84, 0.72))
		"cloth":
			return _cloth()
		"tar":
			return _tar()
		"glass":
			return _glass()
		"raw_pot":
			return _pot(Color(0.66, 0.6, 0.52))
		"pot":
			return _pot(Color(0.7, 0.4, 0.24))
		"roasted_acorns":
			return _roasted_acorns()
		"lantern":
			return _lantern()
	return null


## A bloomery: a tall round clay furnace on a stone ring, a glowing mouth at the front
## (south) and a smoking top, a pile of charcoal beside it.
static func bloomery() -> VoxelModel:
	var m := VoxelModel.new()
	var clay := Color(0.66, 0.46, 0.32)
	var dark := Color(0.5, 0.33, 0.22)
	var stone := Color(0.5, 0.49, 0.47)
	var soot := Color(0.12, 0.1, 0.09)
	var glow := Color(0.98, 0.55, 0.16)
	for y in range(0, 22):
		var r := 5.6 - y * 0.12
		for z in range(1, 15):
			for x in range(1, 15):
				var d := Vector2(x - 7.5, z - 7.5).length()
				if y < 2:
					if d < 6.6:
						m.set_voxel(Vector3i(x, y, z), stone * (0.9 if (x + z) % 3 == 0 else 1.0))
					continue
				if d > r:
					continue
				var hollow := d < r - 1.6
				if hollow and y > 2:
					if y == 21:
						m.set_voxel(Vector3i(x, y, z), soot)
					continue
				# The mouth at the front, glowing, low down.
				if y >= 2 and y <= 5 and z > 11 and x >= 6 and x <= 9:
					m.set_voxel(Vector3i(x, y, z), glow if y <= 3 else glow * 0.7)
					continue
				m.set_voxel(Vector3i(x, y, z), dark if (y % 5 == 0 or (x * 3 + z + y) % 11 == 0) else clay)
	return m


## An anvil: a dark iron body with a horn to the east on a log stump.
static func anvil() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.45, 0.3, 0.17)
	var ring := Color(0.62, 0.48, 0.3)
	for y in range(0, 6):
		for z in range(3, 13):
			for x in range(3, 13):
				var d := Vector2(x - 7.5, z - 7.5).length()
				if d < 4.6:
					m.set_voxel(Vector3i(x, y, z), ring if y == 5 and d < 3.2 else wood * (0.85 if (x + y) % 3 == 0 else 1.0))
	# The waist, then the face and the horn.
	for y in range(6, 9):
		for z in range(6, 10):
			for x in range(5, 11):
				m.set_voxel(Vector3i(x, y, z), IRON * 0.8)
	for y in range(9, 12):
		for z in range(5, 11):
			for x in range(2, 13):
				m.set_voxel(Vector3i(x, y, z), IRON * (1.35 if y == 11 else 1.0))
		for x in range(13, 16):
			var w := 15 - x
			for z in range(8 - w, 8 + w):
				if y >= 10:
					m.set_voxel(Vector3i(x, y, z), IRON * (1.35 if y == 11 else 1.0))
	return m


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


## A forge: a waist-high brick hearth on a stone base, a bed of glowing coals in it, a
## short chimney at the back and a bellows' nozzle at the side.
static func forge() -> VoxelModel:
	var m := VoxelModel.new()
	var stone := Color(0.5, 0.49, 0.47)
	var brick := Color(0.72, 0.4, 0.3)
	var mortar := Color(0.82, 0.74, 0.62)
	var soot := Color(0.12, 0.1, 0.09)
	var glow := Color(0.98, 0.55, 0.16)
	var ember := Color(0.8, 0.22, 0.08)
	var wood := Color(0.45, 0.3, 0.17)
	# The stone base, a cell high.
	for y in range(0, 3):
		for z in range(1, 15):
			for x in range(1, 15):
				m.set_voxel(Vector3i(x, y, z), stone * (0.9 if (x + z + y) % 5 == 0 else 1.0))
	# The brick walls of the hearth, courses offset by a half brick, mortar between.
	for y in range(3, 8):
		for z in range(1, 15):
			for x in range(1, 15):
				var inside := x > 3 and x < 12 and z > 3 and z < 12
				if inside and y > 4:
					continue
				var seam := (y % 2 == 0) or ((x + (2 if y % 4 == 1 else 0)) % 4 == 0)
				m.set_voxel(Vector3i(x, y, z), mortar if seam else brick * (0.92 if (x * 3 + z) % 7 == 0 else 1.0))
	# The bed of coals: dark at the edge, glowing in the middle.
	for z in range(4, 12):
		for x in range(4, 12):
			var d := Vector2(x - 7.5, z - 7.5).length()
			m.set_voxel(Vector3i(x, 5, z), glow if d < 2.0 else (ember if d < 3.2 else soot))
	# The chimney at the north, brick with a sooty mouth.
	for y in range(8, 15):
		for z in range(1, 5):
			for x in range(5, 11):
				if x > 6 and x < 9 and z > 1 and z < 4 and y > 8:
					m.set_voxel(Vector3i(x, y, z), soot if y > 12 else glow * 0.6)
				else:
					m.set_voxel(Vector3i(x, y, z), mortar if y % 2 == 0 and (x + z) % 4 == 0 else brick)
	# The bellows' nozzle and its wooden boards at the east side.
	for x in range(14, 16):
		m.set_voxel(Vector3i(x, 5, 7), soot)
		m.set_voxel(Vector3i(x, 5, 8), soot)
	for y in range(3, 7):
		for z in range(5, 11):
			m.set_voxel(Vector3i(15, y, z), wood * (0.85 if z % 2 == 0 else 1.0))
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
## The colour of the head of a tool by its model name: stone, wooden or copper.
static func _head(model: String) -> Color:
	if model.begins_with("wooden_"):
		return Color(0.55, 0.4, 0.24)
	if model.begins_with("bronze_"):
		return BRONZE
	if model.begins_with("iron_"):
		return IRON
	if model.begins_with("steel_"):
		return STEEL
	return COPPER if model.begins_with("copper_") else Color(0.42, 0.44, 0.46)


## A knife lying flat: a short blade of `blade` along x, a dark wooden grip.
static func _knife(blade: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(0, 5):
		m.set_voxel(Vector3i(x, 0, 0), blade * (1.15 if x % 2 == 0 else 1.0))
		if x < 3:
			m.set_voxel(Vector3i(x, 0, 1), blade * 0.85)
	for x in range(-4, 0):
		m.set_voxel(Vector3i(x, 0, 0), Color(0.3, 0.2, 0.12))
		m.set_voxel(Vector3i(x, 0, 1), Color(0.36, 0.24, 0.14))
	return m


## A spear lying flat: a long shaft along x, a head of `tip` at the east end.
static func _spear(tip: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-10, 7):
		m.set_voxel(Vector3i(x, 0, 0), Color(0.5, 0.35, 0.2) * (0.9 if x % 3 == 0 else 1.0))
	for x in range(7, 10):
		m.set_voxel(Vector3i(x, 0, 0), tip * (1.15 if x == 8 else 1.0))
	m.set_voxel(Vector3i(7, 0, -1), tip)
	m.set_voxel(Vector3i(7, 0, 1), tip)
	m.set_voxel(Vector3i(6, 0, 0), Color(0.8, 0.74, 0.6))
	return m


## A sling lying: two cords of `cord` and the pouch of `pouch` between them.
static func _sling(pouch: Color, cord: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-6, 7):
		m.set_voxel(Vector3i(x, 0, 1 if x < 0 else -1), cord * (0.9 if x % 2 == 0 else 1.0))
	for x in range(-1, 2):
		for z in range(-1, 2):
			m.set_voxel(Vector3i(x, 0, z), pouch)
	return m


## A few round pebbles.
static func _pebbles() -> VoxelModel:
	var m := VoxelModel.new()
	var grey := Color(0.6, 0.6, 0.58)
	for o in [Vector3i(-2, 0, -1), Vector3i(1, 0, 0), Vector3i(-1, 0, 2), Vector3i(2, 0, -2)]:
		m.set_voxel(o, grey)
		m.set_voxel(o + Vector3i(1, 0, 0), grey * 0.85)
		m.set_voxel(o + Vector3i(0, 0, 1), grey * 0.9)
	return m


## A bow lying flat: its curved limb of `wood`, `tips` at both ends and the grip (bone on a
## composite bow), and the string straight across.
static func _bow(wood: Color, tips: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-6, 7):
		var bend := 3 - int(round(x * x / 12.0))
		var c := tips if tips != wood and (abs(x) >= 5 or x == 0) else wood * (1.1 if x % 2 == 0 else 1.0)
		m.set_voxel(Vector3i(x, 0, bend), c)
		m.set_voxel(Vector3i(x, 0, 0), Color(0.86, 0.82, 0.72))
	return m


## An arrow lying flat: a thin shaft, a flint head, fletching at the tail.
static func _arrow() -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-5, 4):
		m.set_voxel(Vector3i(x, 0, 0), Color(0.6, 0.45, 0.28))
	m.set_voxel(Vector3i(4, 0, 0), Color(0.3, 0.31, 0.34))
	m.set_voxel(Vector3i(5, 0, 0), Color(0.4, 0.41, 0.44))
	for x in [-5, -4]:
		m.set_voxel(Vector3i(x, 0, -1), Color(0.85, 0.82, 0.76))
		m.set_voxel(Vector3i(x, 0, 1), Color(0.85, 0.82, 0.76))
	return m


## A dead animal on its side: a body of fur `c` with half sizes `half` (x long, y high,
## z wide), its legs out to the south, a darker back.
static func _carcass(c: Color, half: Vector3i) -> VoxelModel:
	var m := VoxelModel.new()
	for y in range(0, half.y * 2):
		for z in range(-half.z, half.z):
			for x in range(-half.x, half.x):
				var d := Vector3((x + 0.5) / half.x, (y + 0.5 - half.y) / half.y, (z + 0.5) / half.z)
				if d.length() > 1.05:
					continue
				m.set_voxel(Vector3i(x, y, z), c * (0.8 if z < 0 else (1.1 if y >= half.y else 1.0)))
	for x in [-half.x + 1, -half.x + 2, half.x - 3, half.x - 2]:
		for z in range(half.z, half.z + maxi(2, half.z)):
			m.set_voxel(Vector3i(x, 0, z), c * 0.7)
	# The head at the east end.
	for y in range(0, maxi(2, half.y)):
		for z in range(-1, 1):
			m.set_voxel(Vector3i(half.x, y, z), c * 0.9)
			m.set_voxel(Vector3i(half.x + 1, y, z), c * 0.9)
	return m


## A slab of meat `c` with a streak of fat `streak` across it.
static func _meat(c: Color, streak: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for y in range(0, 2):
		for z in range(-2, 2):
			for x in range(-3, 3):
				if (abs(x + 0.5) > 2.0 and abs(z + 0.5) > 1.0) or (y == 1 and (x == -3 or x == 2)):
					continue
				m.set_voxel(Vector3i(x, y, z), streak if x == z or x == z + 1 else c * (1.1 if y == 1 else 1.0))
	return m


## A hide spread flat: a skin of `skin`, rough with the legs' flaps at its corners when
## `raw`, smooth and square when tanned into leather.
static func _hide(skin: Color, raw: bool) -> VoxelModel:
	var m := VoxelModel.new()
	for z in range(-3, 3):
		for x in range(-4, 4):
			if (abs(x + 0.5) > 3.0 and abs(z + 0.5) > 1.5):
				continue
			m.set_voxel(Vector3i(x, 0, z), skin * (0.85 if raw and (x * 3 + z * 5) % 4 == 0 else 1.0))
	if not raw:
		for x in range(-4, 4):
			m.set_voxel(Vector3i(x, 1, -3), skin * 0.9)
		return m
	for o in [Vector3i(-5, 0, -3), Vector3i(4, 0, -3), Vector3i(-5, 0, 2), Vector3i(4, 0, 2)]:
		m.set_voxel(o, skin * 0.8)
	return m


## A bone needle: a thin white sliver with an eye at its blunt end.
static func _needle() -> VoxelModel:
	var m := VoxelModel.new()
	var white := Color(0.92, 0.9, 0.82)
	for x in range(-3, 4):
		m.set_voxel(Vector3i(x, 0, 0), white * (0.85 if x == 3 else 1.0))
	m.set_voxel(Vector3i(-4, 0, -1), white * 0.9)
	m.set_voxel(Vector3i(-4, 0, 1), white * 0.9)
	m.set_voxel(Vector3i(-5, 0, 0), white * 0.9)
	return m


## A tallow candle standing: a pale yellow stick with a dark wick on top.
static func _candle() -> VoxelModel:
	var m := VoxelModel.new()
	var tallow := Color(0.94, 0.88, 0.66)
	for y in range(0, 5):
		for z in range(-1, 1):
			for x in range(-1, 1):
				m.set_voxel(Vector3i(x, y, z), tallow * (0.9 if x + z == -1 else 1.0))
	m.set_voxel(Vector3i(0, 5, 0), Color(0.2, 0.16, 0.12))
	return m


## A bone: a white shaft with knobs at both ends.
static func _bone() -> VoxelModel:
	var m := VoxelModel.new()
	var white := Color(0.92, 0.9, 0.82)
	for x in range(-3, 3):
		m.set_voxel(Vector3i(x, 0, 0), white)
	for x in [-4, 3]:
		m.set_voxel(Vector3i(x, 0, -1), white * 0.92)
		m.set_voxel(Vector3i(x, 0, 1), white * 0.92)
		m.set_voxel(Vector3i(x, 1, 0), white)
	return m


## An iron bloom: a porous lump, dark slag in its pits, rusty here and there.
static func _bloom() -> VoxelModel:
	var m := VoxelModel.new()
	for y in range(0, 4):
		for z in range(-3, 3):
			for x in range(-3, 3):
				var d := Vector3(x + 0.5, y * 1.3, z + 0.5).length()
				if d > 3.3 - (0.6 if (x * 7 + z * 3 + y * 5) % 4 == 0 else 0.0):
					continue
				var pit := (x * 5 + z * 11 + y * 3) % 7 == 0
				var rust := (x * 3 + z * 7 + y) % 9 == 0
				m.set_voxel(Vector3i(x, y, z), Color(0.12, 0.11, 0.1) if pit else (Color(0.48, 0.3, 0.2) if rust else IRON * (1.1 if y == 3 else 1.0)))
	return m


## A bar of metal `c` (copper by default): a flat ingot with sloped sides, a bright top edge.
static func _bar(c := COPPER) -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-3, 4):
		for z in range(-1, 2):
			m.set_voxel(Vector3i(x, 0, z), c * (0.85 if abs(x) == 3 or abs(z) == 1 else 1.0))
	for x in range(-2, 3):
		m.set_voxel(Vector3i(x, 1, 0), c * (1.2 if x % 2 == 0 else 1.1))
	return m


## A crucible of clay `c`: a thick squat cup, dark inside.
static func _crucible(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for y in range(0, 4):
		for z in range(-2, 2):
			for x in range(-2, 2):
				var inside := y > 0 and x >= -1 and x <= 0 and z >= -1 and z <= 0
				if inside and y == 3:
					continue
				m.set_voxel(Vector3i(x, y, z), c * 0.4 if inside else c * (0.85 if x == -2 or z == 1 else 1.0))
	return m


## Charcoal: a few black lumps with an ashen edge.
static func _charcoal() -> VoxelModel:
	var m := VoxelModel.new()
	var coal := Color(0.13, 0.12, 0.12)
	var ash := Color(0.3, 0.29, 0.28)
	for p in [Vector3i(-2, 0, -1), Vector3i(-1, 0, -1), Vector3i(-2, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, 0),
			Vector3i(2, 0, -1), Vector3i(-1, 0, 1), Vector3i(0, 0, -1)]:
		m.set_voxel(p, coal if (p.x + p.z) % 2 == 0 else ash)
	m.set_voxel(Vector3i(-1, 1, 0), coal)
	m.set_voxel(Vector3i(1, 1, 0), coal)
	return m


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


## A torch lying on the ground: a stick, its head wrapped and charred (`wrap`: tarred cloth
## on a tar torch), an ember on it.
static func _torch(wrap := Color(0.28, 0.2, 0.13)) -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.5, 0.35, 0.2)
	for x in range(-5, 3):
		m.set_voxel(Vector3i(x, 0, 0), wood * (0.85 if x % 3 == 0 else 1.0))
	for x in range(3, 6):
		for z in range(-1, 2):
			m.set_voxel(Vector3i(x, 0, z), wrap)
		m.set_voxel(Vector3i(x, 1, 0), wrap * 1.2)
	m.set_voxel(Vector3i(4, 1, 0), Color(0.85, 0.4, 0.15))
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


## A mushroom with a cap of colour `c`, lying on its side.
static func _mushroom(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	var stem := Color(0.86, 0.82, 0.7)
	for x in range(-2, 1):
		m.set_voxel(Vector3i(x, 0, 0), stem)
	for z in range(-1, 2):
		for y in range(0, 2):
			m.set_voxel(Vector3i(1, y, z), c * (1.15 if y == 1 else 1.0))
	m.set_voxel(Vector3i(2, 0, 0), c * 0.85)
	return m


## A clump of moss: a low green cushion.
static func _moss() -> VoxelModel:
	var m := VoxelModel.new()
	var moss := Color(0.26, 0.42, 0.16)
	for z in range(-2, 2):
		for x in range(-2, 2):
			if absi(x * 2 + 1) + absi(z * 2 + 1) < 7:
				m.set_voxel(Vector3i(x, 0, z), moss * (1.2 if (x * 3 + z) % 3 == 0 else 1.0), true)
	m.set_voxel(Vector3i(0, 1, -1), moss * 1.3, true)
	m.set_voxel(Vector3i(-1, 1, 0), moss * 1.3, true)
	return m


## A rolled bandage.
static func _bandage() -> VoxelModel:
	var m := VoxelModel.new()
	var cloth := Color(0.9, 0.87, 0.78)
	for x in range(-2, 2):
		for y in range(0, 3):
			for z in range(-1, 2):
				if (y == 0 or y == 2) and z != 0:
					continue
				m.set_voxel(Vector3i(x, y, z), cloth * (0.85 if x == -2 or x == 1 else 1.0))
	m.set_voxel(Vector3i(2, 0, 0), cloth * 0.9)
	m.set_voxel(Vector3i(3, 0, 0), cloth * 0.9)
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


## A loom: two wooden uprights joined by beams, warp threads strung between them and a band
## of woven cloth across the middle; it stands along x, its face to the south.
static func loom() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.58, 0.4, 0.23)
	var dark := Color(0.38, 0.25, 0.14)
	var thread := Color(0.88, 0.84, 0.72)
	var cloth := Color(0.8, 0.74, 0.6)
	for y in range(0, 15):
		for p in [Vector2i(1, 7), Vector2i(14, 7), Vector2i(1, 8), Vector2i(14, 8)]:
			m.set_voxel(Vector3i(p.x, y, p.y), dark)
	for x in range(1, 15):
		for z in range(7, 9):
			m.set_voxel(Vector3i(x, 14, z), wood)
			m.set_voxel(Vector3i(x, 3, z), wood)
	for x in range(3, 13):
		for y in range(4, 14):
			if y >= 7 and y <= 9:
				m.set_voxel(Vector3i(x, y, 8), cloth * (0.9 if (x + y) % 2 == 0 else 1.0))
			elif x % 2 == 0:
				m.set_voxel(Vector3i(x, y, 8), thread)
	# The feet, a bench in front for the weaver.
	for x in range(0, 16):
		if x < 3 or x > 12:
			for z in range(4, 12):
				m.set_voxel(Vector3i(x, 0, z), dark)
	for x in range(5, 11):
		for z in range(12, 14):
			m.set_voxel(Vector3i(x, 4, z), wood)
		m.set_voxel(Vector3i(x, 3, 12), dark)
	for y in range(0, 4):
		m.set_voxel(Vector3i(5, y, 13), dark)
		m.set_voxel(Vector3i(10, y, 13), dark)
	return m


## A drying rack: two A-shaped frames of branches tied with cord, a pole across them,
## a hide hanging over the pole and strips of meat drying beside it.
static func drying_rack() -> VoxelModel:
	var m := VoxelModel.new()
	var wood := Color(0.5, 0.35, 0.2)
	var dark := Color(0.36, 0.24, 0.13)
	var cord := Color(0.8, 0.74, 0.6)
	var skin := Color(0.62, 0.43, 0.26)
	var meat := Color(0.48, 0.18, 0.14)
	# The frames at the west and east ends: two legs leaning together.
	for x in [1, 14]:
		for y in range(0, 15):
			var lean := int(y / 3.0)
			m.set_voxel(Vector3i(x, y, 3 + lean), dark if y % 4 == 0 else wood)
			m.set_voxel(Vector3i(x, y, 12 - lean), dark if y % 4 == 0 else wood)
		m.set_voxel(Vector3i(x, 13, 7), cord)
		m.set_voxel(Vector3i(x, 13, 8), cord)
	# The pole on top, a lower bar on each side.
	for x in range(0, 16):
		m.set_voxel(Vector3i(x, 14, 7), wood * (1.1 if x % 3 == 0 else 1.0))
		m.set_voxel(Vector3i(x, 14, 8), wood)
	# A hide hung over the pole, its two halves down the sides.
	for x in range(3, 9):
		for y in range(7, 14):
			var side := int((14 - y) / 3.0)
			m.set_voxel(Vector3i(x, y, 6 - side), skin * (0.88 if (x + y) % 3 == 0 else 1.0))
			m.set_voxel(Vector3i(x, y, 9 + side), skin * 0.85)
	# Strips of meat hanging from the pole.
	for x in [10, 12]:
		for y in range(9, 14):
			m.set_voxel(Vector3i(x, y, 7), meat * (1.15 if y == 13 else 1.0))
	return m


## A potter's wheel: a stone kick wheel at the foot, a wooden shaft, a round head with a
## lump of clay turning on it, and a low bench to the south.
static func potters_wheel() -> VoxelModel:
	var m := VoxelModel.new()
	var stone := Color(0.52, 0.51, 0.5)
	var wood := Color(0.58, 0.4, 0.23)
	var dark := Color(0.38, 0.25, 0.14)
	var clay := Color(0.7, 0.44, 0.3)
	for z in range(1, 15):
		for x in range(1, 15):
			var d := Vector2(x - 7.5, z - 7.5).length()
			if d < 6.0:
				m.set_voxel(Vector3i(x, 0, z), stone * (0.9 if (x + z) % 3 == 0 else 1.0))
				m.set_voxel(Vector3i(x, 1, z), stone * (1.05 if d < 5.0 else 0.85))
	for y in range(2, 8):
		for x in range(7, 9):
			for z in range(7, 9):
				m.set_voxel(Vector3i(x, y, z), dark)
	for z in range(3, 13):
		for x in range(3, 13):
			if Vector2(x - 7.5, z - 7.5).length() < 4.8:
				m.set_voxel(Vector3i(x, 8, z), wood * (0.9 if (x * 3 + z) % 5 == 0 else 1.0))
	for y in range(9, 12):
		for z in range(6, 10):
			for x in range(6, 10):
				if y < 11 or (x > 6 and x < 9 and z > 6 and z < 9):
					m.set_voxel(Vector3i(x, y, z), clay * (1.1 if y == 11 else 1.0))
	return m


## Flax stalks in a bundle, blue flowers at one end.
static func _flax() -> VoxelModel:
	var m := VoxelModel.new()
	var stalk := Color(0.45, 0.58, 0.28)
	var flower := Color(0.42, 0.5, 0.88)
	for z in range(-1, 2):
		for x in range(-4, 3):
			m.set_voxel(Vector3i(x, 0, z), stalk * (0.85 if (x + z) % 2 == 0 else 1.0))
		m.set_voxel(Vector3i(3, 0, z), flower)
	m.set_voxel(Vector3i(4, 0, 0), flower * 1.15)
	m.set_voxel(Vector3i(-1, 1, 0), Color(0.72, 0.6, 0.38))
	return m


## A skein of thread of colour `c`.
static func _skein(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for x in range(-2, 3):
		for z in range(-1, 2):
			m.set_voxel(Vector3i(x, 0, z), c * (0.85 if x % 2 == 0 else 1.0))
	for x in range(-1, 2):
		m.set_voxel(Vector3i(x, 1, 0), c * 1.05)
	return m


## A folded piece of cloth, a few layers high.
static func _cloth() -> VoxelModel:
	var m := VoxelModel.new()
	var cloth := Color(0.86, 0.8, 0.66)
	for y in range(0, 2):
		for z in range(-2, 3):
			for x in range(-3, 3):
				m.set_voxel(Vector3i(x, y, z), cloth * (0.82 if z == 2 or (y == 0 and x == -3) else 1.0))
	return m


## A lump of tar: a black blob with a shine on top.
static func _tar() -> VoxelModel:
	var m := VoxelModel.new()
	var tar := Color(0.1, 0.08, 0.07)
	for z in range(-2, 2):
		for x in range(-2, 2):
			if absi(x * 2 + 1) + absi(z * 2 + 1) < 7:
				m.set_voxel(Vector3i(x, 0, z), tar)
	m.set_voxel(Vector3i(0, 1, 0), tar)
	m.set_voxel(Vector3i(-1, 1, -1), Color(0.35, 0.3, 0.26))
	return m


## A pane of greenish glass lying flat, a pale edge.
static func _glass() -> VoxelModel:
	var m := VoxelModel.new()
	var glass := Color(0.55, 0.78, 0.7)
	for z in range(-2, 2):
		for x in range(-3, 3):
			var edge := x == -3 or x == 2 or z == -2 or z == 1
			m.set_voxel(Vector3i(x, 0, z), glass * (1.25 if edge else 1.0))
	return m


## A clay pot of colour `c` standing on the ground.
static func _pot(c: Color) -> VoxelModel:
	var m := VoxelModel.new()
	for y in range(0, 5):
		var r := 1.6 if y == 0 or y == 4 else 2.4
		for z in range(-3, 3):
			for x in range(-3, 3):
				var d := Vector2(x + 0.5, z + 0.5).length()
				if d > r:
					continue
				if y == 4 and d < 1.0:
					continue
				m.set_voxel(Vector3i(x, y, z), c * (0.85 if x == -3 or z == 2 else 1.0))
	return m


## A few roasted acorns, dark caps.
static func _roasted_acorns() -> VoxelModel:
	var m := VoxelModel.new()
	for p in [Vector2i(-2, -1), Vector2i(1, 0), Vector2i(-1, 1)]:
		for x in 2:
			for z in 2:
				m.set_voxel(Vector3i(p.x + x, 0, p.y + z), Color(0.5, 0.32, 0.16))
				m.set_voxel(Vector3i(p.x + x, 1, p.y + z), Color(0.28, 0.2, 0.13))
	return m


## A lantern: a copper frame round green glass, a glow inside, a ring on top.
static func _lantern() -> VoxelModel:
	var m := VoxelModel.new()
	var frame := COPPER
	var glass := Color(0.6, 0.82, 0.72)
	var glow := Color(1.0, 0.75, 0.3)
	for y in range(0, 7):
		for z in range(-1, 2):
			for x in range(-1, 2):
				var rim := y == 0 or y == 6
				var corner := absi(x) == 1 and absi(z) == 1
				if rim or corner:
					m.set_voxel(Vector3i(x, y, z), frame * (0.85 if y == 0 else 1.0))
				elif x == 0 and z == 0 and y >= 2 and y <= 4:
					m.set_voxel(Vector3i(x, y, z), glow)
				else:
					m.set_voxel(Vector3i(x, y, z), glass)
	m.set_voxel(Vector3i(0, 7, 0), frame)
	m.set_voxel(Vector3i(0, 8, -1), frame)
	m.set_voxel(Vector3i(0, 8, 1), frame)
	m.set_voxel(Vector3i(0, 9, 0), frame)
	return m
