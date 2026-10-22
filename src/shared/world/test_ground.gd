extends "res://src/shared/world/world_gen.gd"
## The test world (opened from the «Тестирование» page): flat meadow without end and,
## around the spawn, grounds laid out by hand for the tests of the game, so nobody has
## to look for a ledge, a pit, a cave or a pond in a generated world. It is made the
## way WorldGen makes a world, a chunk in three stages and in any order, only every
## column comes from the plan below instead of the noises. Its seed is SEED, so it is
## saved as a world of its own (WorldStore.world_dir).
##
## The grounds, x east and z south of the spawn, in cells; GROUND is the meadow's top:
##   steps      x -44..-12, z -44..-26  ledges of 1, 2, 3 and 5 cells, loose ground
##                                      (ramps) to the north, stone (sheer) to the south
##   pits       x -8..8,    z -44..-26  a pit 4 deep, a shaft 12 deep
##   cave       x 12..44,   z -46..-24  a stone hill 12 high, a tunnel from the south
##                                      into a hall, a dirt floor
##   forest     x -46..-14, z -10..10   rows of oaks and spruces, rows of bushes
##   materials  x 16..48,   z -10..10   strips of every top, 4 cells deep
##   hut        x 50..58,   z -4..4     plank walls with a door, a stone roof
##   pond       x -44..-14, z 14..38    water 1, 2, 3 and 5 cells deep over sand
##   biomes     x -8..48,   z 14..38    strips: meadow, forest, taiga, swamp, desert,
##                                      tundra, beach

## The seed of the test world; a rolled seed is never negative.
const SEED := -1
## Order of the grounds on the map (and in plan/design/ui.md).
const GROUNDS := ["Ступени", "Ямы", "Пещера", "Лес и кусты", "Материалы", "Домик", "Пруд", "Биомы"]

const STEPS := [0, 1, 0, 2, 0, 3, 0, 5]
const POND_DEPTHS := [1, 2, 3, 5]
const STRIP_BIOMES := [MEADOW, FOREST, TAIGA, SWAMP, DESERT, TUNDRA, BEACH]
const HILL := 12

## Top of the meadow (filled in _init: two cells above the sea).
var ground := 22
## Tops of the material strips, one each 4 cells from x = 16.
var strip_tops: Array = []


func _init(_seed_value := SEED, sy := 48, _options := {}) -> void:
	super(SEED, sy, {})
	ground = sea + 2
	strip_tops = [Mat.GRASS, Mat.DIRT, Mat.SAND, Mat.CLAY, Mat.STONE, Mat.COPPER_ORE, Mat.BRICK, Mat.PLANKS]


## The spawn: the middle of the meadow between the grounds.
func _pick_spawn() -> Vector3i:
	return Vector3i(0, ground + 1, 0)


# --- The plan -----------------------------------------------------------------------

## Column x, z: [height of its top cell, top water cell or -1, top, biome, sheer].
func column(x: int, z: int) -> Array:
	var g := ground
	# Steps: segments of 4 cells, loose ground to the north, stone to the south.
	if x >= -44 and x < -12 and z >= -44 and z < -26:
		var up: int = STEPS[(x + 44) / 4]
		if z < -36:
			return [g + up, -1, Mat.GRASS, MEADOW, false]
		if z >= -34:
			return [g + up, -1, Mat.STONE, ROCK, true]
	# Pits: a pit 4 deep, a shaft 12 deep.
	if x >= -6 and x < -3 and z >= -40 and z < -37:
		return [g - 4, -1, Mat.DIRT, MEADOW, false]
	if x >= 2 and x < 4 and z >= -40 and z < -38:
		return [g - 12, -1, Mat.STONE, MEADOW, false]
	# The cave's hill.
	if x >= 12 and x < 44 and z >= -46 and z < -24:
		return [g + HILL, -1, Mat.STONE, ROCK, true]
	# The pond: deeper to the east.
	if x >= -44 and x < -14 and z >= 14 and z < 38:
		var d: int = POND_DEPTHS[mini((x + 44) / 8, POND_DEPTHS.size() - 1)]
		return [g - d, g, Mat.SAND, SEA, false]
	# Biome strips, 8 cells each.
	if x >= -8 and x < 48 and z >= 14 and z < 38:
		var b: int = STRIP_BIOMES[(x + 8) / 8]
		match b:
			SWAMP:
				# Pools of 2 by 2 cells in clay.
				if posmod(x, 4) < 2 and posmod(z, 4) < 2:
					return [g - 1, g, Mat.CLAY, b, false]
				return [g, -1, Mat.GRASS, b, false]
			DESERT, BEACH:
				return [g, -1, Mat.SAND, b, false]
			TUNDRA:
				return [g, -1, Mat.STONE if posmod(x * 7 + z * 3, 11) == 0 else Mat.GRASS, b, false]
		return [g, -1, Mat.GRASS, b, false]
	# Material strips: 3 cells of each top, a cell of grass between.
	if x >= 16 and x < 48 and z >= -10 and z < 10 and posmod(x, 4) != 3:
		return [g, -1, strip_tops[(x - 16) / 4], MEADOW, false]
	return [g, -1, Mat.GRASS, MEADOW, false]


## What column x, z has over its plain fill: [from y, to y (inclusive), material,
## natural flags] each, written in order.
func extras(x: int, z: int) -> Array:
	var g := ground
	var out := []
	# The tunnel (3 wide, 2 high) from the south face of the hill into the hall.
	var tunnel := x >= 26 and x < 29 and z >= -34 and z < -24
	var hall := x >= 18 and x < 38 and z >= -42 and z < -34
	if tunnel or hall:
		out.append([g, g, Mat.DIRT, WorldData.WILD])
		out.append([g + 1, g + (4 if hall else 2), Mat.AIR, WorldData.WILD])
	# Material strips are 4 cells deep.
	if x >= 16 and x < 48 and z >= -10 and z < 10 and posmod(x, 4) != 3:
		out.append([g - 3, g, strip_tops[(x - 16) / 4], WorldData.WILD])
	# The hut: walls of planks, a door in the south wall, a roof of stone.
	if x >= 50 and x < 58 and z >= -4 and z < 4:
		var wall := x == 50 or x == 57 or z == -4 or z == 3
		var door := z == 3 and (x == 53 or x == 54)
		if wall and not door:
			out.append([g + 1, g + 3, Mat.PLANKS, 0])
		out.append([g + 4, g + 4, Mat.STONE, 0])
	return out


## The trees of the plan: [x, z, species] on odd columns.
func plan_trees() -> Array:
	var out := []
	for x in range(-45, -30, 4):
		out.append([x, -7, Trees.OAK])
		out.append([x, 7, Trees.OAK])
	for x in range(-27, -14, 4):
		out.append([x, -7, Trees.SPRUCE])
		out.append([x, 7, Trees.SPRUCE])
	# A few in the forest and taiga strips.
	for z in range(17, 38, 6):
		out.append([3, z, Trees.OAK])
		out.append([11, z, Trees.SPRUCE])
	return out


## The bushes of the plan: [x, z, type].
func plan_bushes() -> Array:
	var out := []
	for x in range(-45, -32, 3):
		out.append([x, 0, Bushes.RASPBERRY])
	for x in range(-30, -20, 3):
		out.append([x, 0, Bushes.BLUEBERRY])
	for x in range(-18, -14, 3):
		out.append([x, 0, Bushes.SHRUB])
	return out


# --- WorldGen's steps, from the plan ------------------------------------------------

func _sample(_lay: Dictionary, _k: int) -> void:
	pass


func _lattice(_lay: Dictionary) -> void:
	pass


func _entrances(_lay: Dictionary) -> void:
	pass


func _layout_row(lay: Dictionary, lz: int) -> void:
	var w: int = lay.w
	var step: int = lay.step
	for lx in w:
		var j := lz * w + lx
		var c := column(lay.x0 + lx * step, lay.z0 + lz * step)
		lay.heights[j] = c[0]
		lay.water[j] = c[1]
		lay.tops[j] = c[2]
		lay.biome[j] = c[3]
		lay.flags[j] = SHEER_TOP if c[4] else 0
		lay.kind[j] = PLAIN
		lay.feature[j] = LAKE if c[1] >= 0 else DRY
		lay.coast[j] = 1000.0
		lay.river[j] = 1000.0
		lay.lake[j] = -1000.0


## One row of cells of the chunk: stone, a few cells of dirt (stone tops are stone
## through), the top, water, air, then the column's extras.
func _fill_row(key: Vector2i, lay: Dictionary, row: int) -> void:
	var c: WorldData.Chunk = world.chunks[key]
	var layer := WorldData.LAYER
	var z := key.y * CHUNK + row
	for lx in CHUNK:
		var j := (row + MARGIN) * WINDOW + lx + MARGIN
		var col := (row << WorldData.SHIFT) | lx
		var height: int = lay.heights[j]
		var wt: int = lay.water[j]
		var top: int = lay.tops[j]
		var dirt := height if top == Mat.STONE else maxi(0, height - 4)
		var air_bits := 0
		var water_bits := 0
		var wild_bits := 0
		for y in size_y:
			var m := Mat.AIR
			if y < dirt:
				m = Mat.STONE
			elif y < height:
				m = Mat.DIRT
			elif y == height:
				m = top
			elif y <= wt:
				m = Mat.WATER
			var i := y * layer + col
			c.cells[i] = m
			c.natural[i] = WorldData.WILD | WorldData.SHEER if y == height and lay.flags[j] & SHEER_TOP else WorldData.WILD
		for e: Array in extras(key.x * CHUNK + lx, z):
			for y in range(e[0], e[1] + 1):
				c.cells[y * layer + col] = e[2]
				c.natural[y * layer + col] = e[3]
		for y in size_y:
			var m: int = c.cells[y * layer + col]
			if m == Mat.AIR:
				air_bits |= 1 << y
			elif m == Mat.WATER:
				water_bits |= 1 << y
			if c.natural[y * layer + col] & WorldData.WILD:
				wild_bits |= 1 << y
		c.air[col] = air_bits
		c.water[col] = water_bits
		c.wild[col] = wild_bits


func _tree_candidates(key: Vector2i, _lay: Dictionary) -> Array:
	var out := []
	for t: Array in plan_trees():
		if t[0] >> WorldData.SHIFT == key.x and t[1] >> WorldData.SHIFT == key.y:
			out.append([t[0], t[1], t[2], column(t[0], t[1])[0]])
	return out


func _bushes(key: Vector2i, _lay: Dictionary) -> void:
	for b: Array in plan_bushes():
		if b[0] >> WorldData.SHIFT != key.x or b[1] >> WorldData.SHIFT != key.y:
			continue
		var y: int = world.surface_y(b[0], b[1])
		if Bushes.fits(world, b[0], y, b[1]):
			Bushes.place(world, b[0], y, b[1], b[2])
