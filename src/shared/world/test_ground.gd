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
##   bushes     x 62..96,   z -9..2     rows of raspberries, blueberries, shrubs and
##                                      mixed, two cells apart, in the open
##   forest     x -46..-14, z -10..10   rows of oaks and spruces, rows of bushes
##   materials  x 16..48,   z -10..10   strips of every top, 4 cells deep
##   hut        x 50..58,   z -4..4     plank walls with a door, a stone roof
##   pond       x -44..-14, z 14..38    water 1, 2, 3 and 5 cells deep over sand
##   relief     x -70..74,  z 44..92    the shapes the mesher rounds and bevels (RELIEF),
##                                      a row each of grass, sand, clay and stone
##   biomes     x -70..70,  z 100..     plots of 24 by 24 cells of the loaded biomes (BIOME_*), five
##                                      in a row with 4 cells of meadow between: the climate ones in
##                                      load order, then the swamp (pools in its north, a pond running
##                                      into a bog in its south) and the beach; each grown the way the
##                                      generator grows the biome (its tree chance and shares, its
##                                      bushes), a pool in the south-east corner for the plants of the
##                                      banks (the animals of a biome come to its plot on their own)
##   stream     x 136..179, z 16..34    a stream coming down terraces (STREAM): falls of
##                                      4, 3 and 2 cells, a rapid of 1, a pool at the foot
##   ears       x 100..131, z -12..11   a field of ears (sparrows come to it), a row of
##                                      oaks along its north edge for them to sit in
##   grove      x 100..131, z 14..37    oaks and spruces over moss, then mushrooms, then
##                                      glowing mushrooms, west to east (GROVE_FLOOR)
##   mountain   x 98..142,  z 42..86    a peak of scree and stone up into the snow
##   camp       x 60..91,   z -30..-13  for FPS and freezes: things lying on every cell
##                                      (CAMP_DROPS), death's sacks, a row of chests,
##                                      workbenches and kilns, a row of lit campfires
##
## What grows on the field and in the grove is set by `growth` (WorldData.grows), not
## by the noises.

## The seed of the test world; a rolled seed is never negative.
const SEED := -1
const Grass := preload("res://src/shared/world/grass.gd")
const Items := preload("res://src/shared/content/items.gd")

## Order of the grounds on the map (and in plan/design/ui.md).
const GROUNDS := ["Ступени", "Ямы", "Пещера", "Кусты", "Лес", "Материалы", "Домик", "Пруд", "Рельеф", "Биомы",
	"Ручей", "Поле колосьев", "Роща", "Гора", "Лагерь"]

const STEPS := [0, 1, 0, 2, 0, 3, 0, 5]
## The biome plots: BIOME_PLOT cells square, BIOME_GAP cells of meadow between them,
## BIOME_PER_ROW in a row east from BIOME_X, the rows south from BIOME_Z. The pool of a
## plot is BIOME_POOL cells square in its south-east corner, BIOME_GAP from the edges.
const BIOME_PLOT := 24
const BIOME_GAP := 4
const BIOME_PER_ROW := 5
const BIOME_X := -70
const BIOME_Z := 100
const BIOME_POOL := 4
const POND_DEPTHS := [1, 2, 3, 5]
const HILL := 12
## The shapes of the relief ground, west to east, each on a plot of RELIEF_PLOT cells
## RELIEF_STRIDE apart (see relief_rise): a lone cell, a square, an L (inner corner), a
## ring round a hollow, a pit, a stepped pyramid, a diagonal stair, a two-cell cliff
## beside a one-cell step, a ridge and a trench, a checkerboard, a round hill, a cross.
const RELIEF := ["cell", "square", "ell", "ring", "pit", "pyramid", "stair", "cliff", "ridge", "checker",
	"round", "cross"]
const RELIEF_PLOT := 10
const RELIEF_STRIDE := 12
const RELIEF_X := -70
const RELIEF_Z := 44
## The stream's terraces, west to east: [first column, rise of the terrace]; the water
## stands at the terrace's top in a channel (STREAM_Z) between banks of stone, and
## falls to the next one, then into the pool from STREAM_POOL on.
const STREAM := [[136, 10], [146, 6], [154, 3], [162, 2]]
const STREAM_POOL := 170
const STREAM_END := 180
## Channel z from, to (inclusive); a bank of stone 2 cells wide on each side.
const STREAM_Z := Vector2i(23, 26)
## The grove's strips, each 10 or 11 cells wide from x 100: moss, mushrooms, glowing
## mushrooms (Grass.GROW_*).
const GROVE_FLOOR := [Grass.GROW_MOSS, Grass.GROW_MUSHROOMS, Grass.GROW_GLOW]
## The mountain: its middle, its reach (cells) and the height of its top over the meadow.
const PEAK := Vector2i(120, 64)
const PEAK_REACH := 22.0
const PEAK_RISE := 20
## The camp: its north-west corner and size in cells. Things lie on every cell of its
## north part (CAMP_DROPS in turn, some heaped), sacks on a row, then the placed things
## (CAMP_THINGS), then lit campfires.
const CAMP := Rect2i(60, -30, 32, 18)
const CAMP_DROPS := ["resources:log", "resources:branch", "resources:stone", "plants:acorn", "plants:cone", "plants:raspberry",
	"resources:dirt", "materials:planks", "resources:flint", "tools:stone_axe", "plants:mushroom", "resources:clay", "resources:fiber",
	"materials:brick", "tools:wooden_shovel", "plants:blueberry"]
const CAMP_THINGS := ["tools:chest", "tools:workbench", "tools:kiln", "tools:forge"]

## Top of the meadow (filled in _init: two cells above the sea).
var ground := 22
## Tops of the material strips, one each 4 cells from x = 16.
var strip_tops: Array = []
## Tops of the rows of the relief ground, north to south.
var relief_tops: Array = []
## The biomes of the plots: every climate biome in load order (NONE pads to 3 when fewer
## are loaded), then the swamp and the beach; the biome of the meadow (one the player may
## start in), of the rock and of the water.
var plot_biomes: Array = []
var meadow := Biomes.NONE
var rock := Biomes.NONE
var water := Biomes.NONE


func _init(_seed_value := SEED, sy := 48, _options := {}) -> void:
	super(SEED, sy, {})
	ground = sea + 2
	# A static func, so the world holds no reference back to its maker.
	world.grows = Callable(get_script(), "growth")
	# The strip of materials shows what the loaded mods give: the roles, and the built
	# blocks of the tools mod when it is loaded.
	strip_tops = [Mat.GRASS, Mat.DIRT, beach, bank, Mat.STONE, ore, _block("brick"), _block("planks")]
	relief_tops = [Mat.GRASS, beach, bank, Mat.STONE]
	for i in Biomes.RECORDS.size():
		if Biomes.RECORDS[i].where == "climate":
			plot_biomes.append(i)
		if Biomes.spawn_ok(i) and meadow == Biomes.NONE:
			meadow = i
	while plot_biomes.size() < 3:
		plot_biomes.append(Biomes.NONE)
	plot_biomes.append(_biome(Biomes.SWAMP))
	plot_biomes.append(_biome(Biomes.BEACH))
	rock = _biome(Biomes.ROCK)
	water = _biome(Biomes.SEA)


## The spawn: the middle of the meadow between the grounds.
## The material of a built block of the tools mod, stone when the mod is not loaded.
func _block(name: String) -> int:
	var m := Mat.index("materials:" + name)
	return m if m >= 0 else Mat.STONE


func _pick_spawn() -> Vector3i:
	return Vector3i(0, ground + 1, 0)


# --- The plan -----------------------------------------------------------------------

## The plot column x, z lies in, -1 outside the plots and in the meadow between them.
func plot_at(x: int, z: int) -> int:
	var px := x - BIOME_X
	var pz := z - BIOME_Z
	var stride := BIOME_PLOT + BIOME_GAP
	if px < 0 or pz < 0 or px >= BIOME_PER_ROW * stride or px % stride >= BIOME_PLOT or pz % stride >= BIOME_PLOT:
		return -1
	var i := (pz / stride) * BIOME_PER_ROW + px / stride
	return i if i < plot_biomes.size() else -1


## The north-west corner of plot i.
func plot_origin(i: int) -> Vector2i:
	var stride := BIOME_PLOT + BIOME_GAP
	return Vector2i(BIOME_X + (i % BIOME_PER_ROW) * stride, BIOME_Z + (i / BIOME_PER_ROW) * stride)


## Column x, z: [height of its top cell, top water cell or -1, top, biome, sheer].
func column(x: int, z: int) -> Array:
	var g := ground
	# Steps: segments of 4 cells, loose ground to the north, stone to the south.
	if x >= -44 and x < -12 and z >= -44 and z < -26:
		var up: int = STEPS[(x + 44) / 4]
		if z < -36:
			return [g + up, -1, Mat.GRASS, meadow, false]
		if z >= -34:
			return [g + up, -1, Mat.STONE, rock, true]
	# Pits: a pit 4 deep, a shaft 12 deep.
	if x >= -6 and x < -3 and z >= -40 and z < -37:
		return [g - 4, -1, Mat.DIRT, meadow, false]
	if x >= 2 and x < 4 and z >= -40 and z < -38:
		return [g - 12, -1, Mat.STONE, meadow, false]
	# The cave's hill.
	if x >= 12 and x < 44 and z >= -46 and z < -24:
		return [g + HILL, -1, Mat.STONE, rock, true]
	# The pond: deeper to the east.
	if x >= -44 and x < -14 and z >= 14 and z < 38:
		var d: int = POND_DEPTHS[mini((x + 44) / 8, POND_DEPTHS.size() - 1)]
		return [g - d, g, beach, water, false]
	# The biome plots.
	var plot := plot_at(x, z)
	if plot >= 0:
		var b: int = plot_biomes[plot]
		var at := Vector2i(x, z) - plot_origin(plot)
		var top := beach if b == Biomes.BEACH or Biomes.top(b, beach, bank) == beach else Mat.GRASS
		if b == Biomes.SWAMP:
			# Swamp water a cell deep in clay, two in a corner of the pond; its
			# murk is in extras.
			if _swamp_water(at):
				return [g - (2 if at.x >= 8 and at.x < 10 and at.y >= 14 and at.y < 16 else 1), g, bank, b, false]
			return [g, -1, Mat.GRASS, b, false]
		if _plot_pool(at):
			return [g - 1, g, beach if top == beach else bank, b, false]
		if top == Mat.GRASS and Biomes.of(b).get("stone_below", -1.0) > -1.0:
			# Stone shows through the ground here and there (the tundra).
			return [g, -1, Mat.STONE if posmod(x * 7 + z * 3, 11) == 0 else Mat.GRASS, b, false]
		return [g, -1, top, b, false]
	# Relief: a row of shapes for each top.
	var rx := x - RELIEF_X
	var rz := z - RELIEF_Z
	if rx >= 0 and rz >= 0 and rx < RELIEF.size() * RELIEF_STRIDE and rz < relief_tops.size() * RELIEF_STRIDE:
		var px := rx % RELIEF_STRIDE
		var pz := rz % RELIEF_STRIDE
		if px < RELIEF_PLOT and pz < RELIEF_PLOT:
			var top: int = relief_tops[rz / RELIEF_STRIDE]
			return [g + relief_rise(RELIEF[rx / RELIEF_STRIDE], px, pz), -1, top,
				rock if top == Mat.STONE else meadow, false]
	# The stream, the grove's ground is the meadow's.
	if x >= STREAM[0][0] and x < STREAM_END and z >= 16 and z < 35:
		return _stream(x, z)
	# The mountain: scree, stone jutting out of it, grass at its foot.
	var d := Vector2(x - PEAK.x, z - PEAK.y).length()
	if d < PEAK_REACH:
		var rise := clampi(int(PEAK_RISE * (1.0 - d / PEAK_REACH) + 0.5), 0, PEAK_RISE)
		if rise < 6:
			return [g + rise, -1, Mat.GRASS, meadow, false]
		if posmod(x * 7 + z * 13, 9) == 0:
			return [g + rise, -1, Mat.STONE, rock, true]
		return [g + rise, -1, scree, rock, false]
	# Material strips: 3 cells of each top, a cell of grass between.
	if x >= 16 and x < 48 and z >= -10 and z < 10 and posmod(x, 4) != 3:
		return [g, -1, strip_tops[(x - 16) / 4], meadow, false]
	return [g, -1, Mat.GRASS, meadow, false]


## How many cells the relief shape `shape` rises (or sinks) at cell px, pz of its plot.
func relief_rise(shape: String, px: int, pz: int) -> int:
	var inside := px >= 3 and px < 7 and pz >= 3 and pz < 7
	match shape:
		"cell":
			return 1 if px == 4 and pz == 4 else 0
		"square":
			return 1 if inside else 0
		"ell":
			return 1 if px >= 2 and pz >= 2 and px < 8 and pz < 8 and (px < 5 or pz >= 5) else 0
		"ring":
			var edge := px >= 2 and pz >= 2 and px < 8 and pz < 8
			return 1 if edge and not inside else 0
		"pit":
			return -1 if inside else 0
		"pyramid":
			return clampi(mini(mini(px, pz), mini(9 - px, 9 - pz)) - 1, 0, 3)
		"stair":
			return clampi((px + pz) / 3 - 1, 0, 4)
		"cliff":
			if pz < 2 or pz >= 8:
				return 0
			return 2 if px >= 6 else (1 if px >= 3 else 0)
		"ridge":
			return 1 if px == 3 and pz >= 1 and pz < 9 else (-1 if px == 6 and pz >= 1 and pz < 9 else 0)
		"checker":
			return 1 if px >= 1 and pz >= 1 and px < 9 and pz < 9 and ((px - 1) / 2 + (pz - 1) / 2) % 2 == 0 else 0
		"round":
			var d := Vector2(px - 4.5, pz - 4.5).length()
			return clampi(int(3.5 - d * 0.8), 0, 3)
		"cross":
			return 1 if (px >= 4 and px < 6 and pz >= 1 and pz < 9) or (pz >= 4 and pz < 6 and px >= 1 and px < 9) else 0
	return 0


## The stream ground's column x, z (see STREAM): terraces of grass with sheer sides,
## the channel with its banks across them, the pool at the foot.
func _stream(x: int, z: int) -> Array:
	var g := ground
	if x >= STREAM_POOL:
		if z >= STREAM_Z.x - 3 and z <= STREAM_Z.y + 3:
			return [g - 3, g, beach, water, false]
		return [g, -1, Mat.GRASS, meadow, false]
	var rise := 0
	for t: Array in STREAM:
		if x >= t[0]:
			rise = t[1]
	var channel := z >= STREAM_Z.x and z <= STREAM_Z.y
	# The channel starts two cells in, behind a head of stone.
	if channel and x >= STREAM[0][0] + 2:
		return [g + rise - 2, g + rise, beach, water, false]
	if channel or (z >= STREAM_Z.x - 2 and z <= STREAM_Z.y + 2):
		return [g + rise, -1, Mat.STONE, rock, true]
	return [g + rise, -1, Mat.GRASS, meadow, true]


## What grows on grass column x, z of the test world in place of what the noises give
## (Grass.GROW_*), 0 where they decide: the field of ears and the grove's floor.
static func growth(x: int, z: int) -> int:
	if x < 100 or x >= 132:
		return 0
	if z >= -8 and z < 12:
		return Grass.GROW_EARS
	if z >= 14 and z < 38:
		return GROVE_FLOOR[mini((x - 100) / 11, GROVE_FLOOR.size() - 1)]
	return 0


## True where the swamp plot has water at `at` (a cell of the plot from its corner):
## pools of 2 by 2 cells in its north, a pond in its south whose southern part is a
## bog (see _bog).
static func _swamp_water(at: Vector2i) -> bool:
	if at.x < 2 or at.x >= BIOME_PLOT - 2 or at.y < 2 or at.y >= BIOME_PLOT - 1:
		return false
	if at.y < 12:
		return posmod(at.x, 4) < 2 and posmod(at.y, 4) < 2
	return at.x >= 6 and at.x < 18 and at.y >= 13


## True on the bog of the swamp plot's pond.
static func _bog(at: Vector2i) -> bool:
	return _swamp_water(at) and at.y >= 18


## True on the pool in the south-east corner of a plot (not the swamp's).
static func _plot_pool(at: Vector2i) -> bool:
	var from := BIOME_PLOT - BIOME_GAP - BIOME_POOL
	return at.x >= from and at.x < from + BIOME_POOL and at.y >= from and at.y < from + BIOME_POOL


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
	# The water of the swamp plot is murky, the bog's murkier.
	var plot := plot_at(x, z)
	if plot >= 0 and plot_biomes[plot] == Biomes.SWAMP:
		var at := Vector2i(x, z) - plot_origin(plot)
		if _swamp_water(at):
			out.append([column(x, z)[0] + 1, g, Mat.WATER, WorldData.WILD | (WorldData.BOG if _bog(at) else WorldData.SWAMP)])
	# Material strips are 4 cells deep.
	if x >= 16 and x < 48 and z >= -10 and z < 10 and posmod(x, 4) != 3:
		out.append([g - 3, g, strip_tops[(x - 16) / 4], WorldData.WILD])
	# The hut: walls of planks, a door in the south wall, a roof of stone.
	if x >= 50 and x < 58 and z >= -4 and z < 4:
		var wall := x == 50 or x == 57 or z == -4 or z == 3
		var door := z == 3 and (x == 53 or x == 54)
		if wall and not door:
			out.append([g + 1, g + 3, _block("planks"), 0])
		out.append([g + 4, g + 4, Mat.STONE, 0])
	return out


## The trees of the plan: [x, z, species] on odd columns; the first broad-leaved species
## where the plan says oak, the first needled one where spruce (none loaded: no trees,
## one kind loaded: that one everywhere).
func plan_trees() -> Array:
	var out := []
	var oak := Trees.first(Trees.BROAD)
	var spruce := Trees.first(Trees.NEEDLES)
	if oak < 0:
		oak = spruce
	if spruce < 0:
		spruce = oak
	if oak < 0:
		return out
	for x in range(-45, -30, 4):
		out.append([x, -7, oak])
		out.append([x, 7, oak])
	for x in range(-27, -14, 4):
		out.append([x, -7, spruce])
		out.append([x, 7, spruce])
	# Oaks along the north edge of the field of ears, the grove in rows.
	for x in range(101, 132, 6):
		out.append([x, -11, oak])
		for z in range(17, 38, 6):
			out.append([x, z, spruce if x >= 122 else oak])
	return out


## What lies on the ground of the camp: [kind, x, z, data] (see WorldData.drops), a
## thing on each cell of its first 8 rows, every fifth a heap of 5, then a row of
## sacks, each holding a few stacks.
func plan_drops() -> Array:
	var out := []
	# Drops of mods the world is without are left out.
	var drops: Array = CAMP_DROPS.filter(func(id: String) -> bool: return Items.has(id))
	for z in range(CAMP.position.y, CAMP.position.y + 8):
		for x in range(CAMP.position.x, CAMP.end.x):
			var k := posmod(x * 3 + z * 5, drops.size())
			var kind: String = drops[k]
			var tool: bool = Items.get_item(kind).get("tool", "none") != "none"
			out.append([kind, x, z, 1 if tool or posmod(x + z, 5) != 0 else 5])
	for x in range(CAMP.position.x + 1, CAMP.end.x, 3):
		var stacks := []
		for i in 4:
			stacks.append([Items.get_item(drops[(x + i * 3) % drops.size()]).id, 1 + i * 2])
		out.append([Items.SACK, x, CAMP.position.y + 9, stacks])
	return out


## The things placed in the camp: [item, north-west cell], chests, workbenches and
## kilns on a row, then a row of campfires, lit.
func plan_things() -> Array:
	var out := []
	var i := 0
	for x in range(CAMP.position.x, CAMP.end.x - 1, 3):
		out.append([CAMP_THINGS[i % CAMP_THINGS.size()], Vector3i(x, ground + 1, CAMP.position.y + 11)])
		i += 1
	for x in range(CAMP.position.x, CAMP.end.x - 1, 4):
		out.append(["core:campfire", Vector3i(x, ground + 1, CAMP.position.y + 15)])
	return out


## The bushes of the plan: [x, z, type].
func plan_bushes() -> Array:
	var out := []
	# The bush garden: a row of each kind and a mixed one.
	var raspberry := Bushes.first(true)
	var blueberry := Bushes.first(true, 1)
	var shrub := Bushes.first(false)
	if blueberry < 0:
		blueberry = raspberry
	if shrub < 0:
		shrub = raspberry
	if raspberry < 0:
		raspberry = shrub
	var kinds := [raspberry, blueberry, shrub]
	if raspberry < 0:
		return out
	for row in 4:
		for x in range(63, 95, 2):
			var kind: int = kinds[row] if row < 3 else kinds[posmod(x, 3)]
			out.append([x, -8 + row * 3, kind])
	for x in range(-45, -32, 3):
		out.append([x, 0, raspberry])
	for x in range(-30, -20, 3):
		out.append([x, 0, blueberry])
	for x in range(-18, -14, 3):
		out.append([x, 0, shrub])
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
		var dirt := height if top == Mat.STONE or top == scree else maxi(0, height - 4)
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


## True when chunk `key` has cells of the biome plots.
func _in_plots(key: Vector2i) -> bool:
	var stride := BIOME_PLOT + BIOME_GAP
	var rows := (plot_biomes.size() + BIOME_PER_ROW - 1) / BIOME_PER_ROW
	var plots := Rect2i(BIOME_X, BIOME_Z, BIOME_PER_ROW * stride, rows * stride)
	return plots.intersects(Rect2i(key.x * CHUNK, key.y * CHUNK, CHUNK, CHUNK))


## The species of the tree a lattice column of a plot wants, -1 for none: its biome's
## chance and one of its species by their shares, the way WorldGen._tree_at decides for
## a generated world (no groves here).
func _plot_tree(x: int, z: int) -> int:
	var plot := plot_at(x, z)
	if plot < 0:
		return -1
	var c := column(x, z)
	if c[2] != Mat.GRASS or c[1] >= 0:
		return -1
	var b: int = plot_biomes[plot]
	if _chance(x, z, 1) >= Biomes.tree_chance(b):
		return -1
	return Biomes.tree(b, _chance(x, z, 6))


## The trees of the plan in the chunk, and in the biome plots the trees of the lattice
## (odd columns, not beside a candidate to the west or north, as WorldGen lays them).
func _tree_candidates(key: Vector2i, _lay: Dictionary) -> Array:
	var out := []
	for t: Array in plan_trees():
		if t[0] >> WorldData.SHIFT == key.x and t[1] >> WorldData.SHIFT == key.y:
			out.append([t[0], t[1], t[2], column(t[0], t[1])[0]])
	if not _in_plots(key):
		return out
	for z in range(key.y * CHUNK, key.y * CHUNK + CHUNK):
		if z & 1 == 0:
			continue
		for x in range(key.x * CHUNK, key.x * CHUNK + CHUNK):
			if x & 1 == 0:
				continue
			var species := _plot_tree(x, z)
			if species < 0 or _plot_tree(x - 2, z) >= 0 or _plot_tree(x, z - 2) >= 0:
				continue
			out.append([x, z, species, column(x, z)[0]])
	return out


## The bushes of the plan, and in the biome plots the bushes of each biome by its
## sparsity and shares (WorldGen's rule; the layout of the chunk says the biome of each
## column, the meadow between the plots gets its few as well).
func _bushes(key: Vector2i, lay: Dictionary) -> void:
	if _in_plots(key):
		super(key, lay)
	# The things lying in the camp come with its chunk, the way trees do.
	for d: Array in plan_drops():
		if d[1] >> WorldData.SHIFT == key.x and d[2] >> WorldData.SHIFT == key.y:
			var at := Vector3(d[1] + 0.5, world.surface_y(d[1], d[2]), d[2] + 0.5) * WorldData.CELL
			world.add_drop(d[0], at, posmod(d[1] * 7 + d[2] * 3, 8) * PI / 4.0, d[3])
	for b: Array in plan_bushes():
		if b[0] >> WorldData.SHIFT != key.x or b[1] >> WorldData.SHIFT != key.y:
			continue
		var y: int = world.surface_y(b[0], b[1])
		if Bushes.fits(world, b[0], y, b[1]):
			Bushes.place(world, b[0], y, b[1], b[2])
