extends RefCounted
## Deterministic world generator: the same seed always gives the same world.
## The test island is laid out by hand so that every kind of place is a short walk from
## the spawn in the middle: mountains in the north cut by a canyon, a river from them
## past the spawn to the south coast, a lake fed by a creek in the west, a swamp in the
## south-west, a dense forest east of the river, a terraced plateau in the north-east,
## cliffs along the west coast and beaches elsewhere. Noise layers (relief, ridges,
## soil, caves, ores, forest, ravines, steepness) shape everything inside that layout,
## so rare places still come from rare combinations. Every generated cell is marked
## wild: loose ground lies as slopes wherever it steps down one cell, while stone, the
## steep patches, cliffs and canyon walls keep sheer walls; cliffs and banks turn their
## corners diagonally (see WorldData). Sizes are in cells (8 px).

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")

## Places of the layout, in fractions of the map (x east, y south): centres, and radii
## in fractions of the map's side.
const ISLAND := Vector2(0.5, 0.52)
const LAKE := Vector3(0.3, 0.44, 0.06)
const SWAMP := Vector4(0.26, 0.75, 0.12, 0.075)
const FOREST := Vector3(0.73, 0.6, 0.13)
const PLATEAU := Vector3(0.83, 0.3, 0.09)
## Courses of the river, from the mountains to the south coast, and of the creek that
## feeds the lake.
const RIVER := [Vector2(0.62, 0.13), Vector2(0.6, 0.24), Vector2(0.61, 0.34), Vector2(0.58, 0.45),
	Vector2(0.58, 0.57), Vector2(0.62, 0.7), Vector2(0.63, 0.83), Vector2(0.64, 0.99)]
const CREEK := [Vector2(0.19, 0.14), Vector2(0.23, 0.25), Vector2(0.26, 0.35), Vector2(0.3, 0.44)]

## Column flags while laying out: the top keeps a sheer wall, caves may open at the
## surface here, the column holds water above the sea that must not leak.
const SHEER_TOP := 1
const ENTRANCE := 2
const INLAND := 4


static func generate(world_seed: int, sx := 384, sy := 40, sz := 384) -> WorldData:
	var w := WorldData.new(sx, sy, sz)
	var sea := w.sea_level
	# Noise is sampled natively into byte grids (0..255 for -1..1): much faster than
	# calling the noise per cell from GDScript, which matters in the browser.
	var hills := _grid_2d(world_seed, 0.006, 4, sx, sz)
	var ridges := _grid_2d(world_seed + 1, 0.009, 3, sx, sz)
	var soil := _grid_2d(world_seed + 4, 0.025, 2, sx, sz)
	var forest := _grid_2d(world_seed + 5, 0.015, 2, sx, sz)
	var gullies := _grid_2d(world_seed + 6, 0.01, 1, sx, sz)
	var steep := _grid_2d(world_seed + 7, 0.045, 2, sx, sz)
	var shape := _grid_2d(world_seed + 8, 0.012, 2, sx, sz)
	var mouths := _grid_2d(world_seed + 9, 0.03, 1, sx, sz)
	var pools := _grid_2d(world_seed + 10, 0.07, 2, sx, sz)
	var layer := sx * sz
	var heights := PackedInt32Array()
	heights.resize(layer)
	var water_top := PackedInt32Array()
	water_top.resize(layer)
	water_top.fill(-1)
	var tops := PackedByteArray()
	tops.resize(layer)
	var flags := PackedByteArray()
	flags.resize(layer)
	_relief(sx, sz, sea, sy, hills, ridges, soil, gullies, steep, shape, mouths, heights, water_top, tops, flags)
	var lake_level := _lake(sx, sz, sea, shape, heights, water_top, tops, flags)
	var meander := _noise(world_seed + 11, 0.02, 1)
	_river(_course(CREEK, sx, sz, meander, 5.0), sea + 9, lake_level, 1.2, 1.8, sx, sz, sea, heights, water_top, tops, flags)
	_river(_course(RIVER, sx, sz, meander, 8.0), sea + 13, sea, 1.5, 3.4, sx, sz, sea, heights, water_top, tops, flags)
	_swamp(sx, sz, sea, shape, pools, soil, heights, water_top, tops, flags)
	_fill(w, world_seed + 2, heights, water_top, tops, flags)
	_seal(w, flags, tops)
	_forests(w, world_seed, forest, heights, water_top, tops)
	w.mark_all_dirty()
	w.refresh_shapes()
	return w


## Heights, tops and flags of the island before the water bodies are cut in: plains of
## low hills, mountains in the north, the terraced plateau, cliffs on the west coast,
## beaches and ravines.
static func _relief(sx: int, sz: int, sea: int, sy: int, hills: PackedByteArray, ridges: PackedByteArray,
		soil: PackedByteArray, gullies: PackedByteArray, steep: PackedByteArray, shape: PackedByteArray,
		mouths: PackedByteArray, heights: PackedInt32Array, water_top: PackedInt32Array,
		tops: PackedByteArray, flags: PackedByteArray) -> void:
	var center := Vector2(ISLAND.x * sx, ISLAND.y * sz)
	var half := minf(sx, sz) * 0.5
	var plateau := Vector2(PLATEAU.x * sx, PLATEAU.y * sz)
	var plateau_r := PLATEAU.z * minf(sx, sz)
	var soil_t := _byte(0.25)
	var steep_t := _byte(0.4)
	var mouth_t := _byte(0.55)
	for z in sz:
		var v := z / float(sz)
		for x in sx:
			var col := z * sx + x
			var u := x / float(sx)
			var wobble := (shape[col] - 128) / 128.0
			# Island mask: land in the middle, sea at the edges, a ragged coast.
			var d := Vector2(x, z).distance_to(center) / half * (1.0 + 0.15 * wobble)
			var mask := 1.0 - smoothstep(0.7, 0.9, d)
			# Along the west coast the land keeps its height right up to the water and
			# drops into the sea in one sheer wall with a rocky rim.
			var cliff := smoothstep(0.36, 0.27, u) * smoothstep(0.66, 0.56, v)
			if cliff > 0.5:
				mask = 1.0 if mask > 0.5 else 0.0
			var h := hills[col] / 255.0
			var land := sea + 2.0 + h * 7.0 + 4.0 * cliff
			# Mountains in the north: sharp ridges along the noise's zero lines.
			var mountain := smoothstep(0.4, 0.2, v + 0.08 * wobble)
			var ridge := 1.0 - absf(ridges[col] / 127.5 - 1.0)
			land += mountain * (3.0 + h * 4.0 + ridge * ridge * 16.0)
			var sheer := steep[col] >= steep_t or cliff > 0.5
			# The land ends where the island mask flips at d = 0.8; the rim is rock.
			var rim := cliff > 0.5 and mask > 0.5 and d > 0.72
			# The plateau rises in terraces four cells apart, with sheer edges.
			if Vector2(x, z).distance_to(plateau) < plateau_r * (0.85 + 0.3 * wobble):
				land = sea + 6.0 + 4.0 * floorf(h * 4.0)
				sheer = true
			var height := clampi(int(round(lerpf(sea - 7.0, land, mask))), 2, sy - 6)
			var rocky := height > sea + 12
			# Ravines: narrow winding cuts six cells deep along a noise's zero line,
			# through the lowlands; below the sea they fill as creeks.
			var gully := absi(gullies[col] - 128)
			if not rocky and not sheer and height > sea and mask > 0.6 and mountain < 0.3 and gully < 5:
				height -= 6 if gully < 4 else 4
			heights[col] = height
			if height < sea:
				water_top[col] = sea
			if rocky or rim:
				tops[col] = Mat.STONE
			elif height <= sea + 2:
				tops[col] = Mat.SAND if soil[col] < soil_t else Mat.CLAY
			else:
				tops[col] = Mat.GRASS
			var f := SHEER_TOP if sheer else 0
			# In the hills caves come up to the surface here and there.
			if height > sea + 5 and mouths[col] > mouth_t:
				f |= ENTRANCE
			flags[col] = f


## Cuts the lake into the ground: its level is one below the lowest ground around it,
## so it never spills, and it deepens from the shore to the middle. Returns the level
## (the top water cell).
static func _lake(sx: int, sz: int, sea: int, shape: PackedByteArray, heights: PackedInt32Array,
		water_top: PackedInt32Array, tops: PackedByteArray, flags: PackedByteArray) -> int:
	var c := Vector2(LAKE.x * sx, LAKE.y * sz)
	var r := LAKE.z * minf(sx, sz)
	var x0 := maxi(1, int(c.x - r * 1.6))
	var x1 := mini(sx - 1, int(c.x + r * 1.6))
	var z0 := maxi(1, int(c.y - r * 1.6))
	var z1 := mini(sz - 1, int(c.y + r * 1.6))
	var level := 1000
	for z in range(z0, z1):
		for x in range(x0, x1):
			var d := _blob(x, z, c, r, shape[z * sx + x])
			if d >= 1.0 and d < 1.25:
				level = mini(level, heights[z * sx + x] - 1)
	level = maxi(level, sea)
	for z in range(z0, z1):
		for x in range(x0, x1):
			var col := z * sx + x
			var d := _blob(x, z, c, r, shape[col])
			if d < 1.0:
				var depth := 1 + int(3.5 * smoothstep(1.0, 0.35, d))
				heights[col] = mini(heights[col], level - depth)
				water_top[col] = level
				tops[col] = Mat.SAND if d > 0.7 else Mat.CLAY
				flags[col] = INLAND
			elif d < 1.5:
				heights[col] = mini(heights[col], level + 1 + int((d - 1.0) * r))
				if d < 1.15 and heights[col] <= level + 2:
					tops[col] = Mat.SAND
	return level


## Distance from the middle of a noisy round blob, 1 on its edge.
static func _blob(x: int, z: int, c: Vector2, r: float, wobble: int) -> float:
	return Vector2(x + 0.5, z + 0.5).distance_to(c) / (r * (0.8 + 0.4 * wobble / 255.0))


## A smooth course through `points` (fractions of the map) in steps of half a cell,
## meandering sideways by up to `amp` cells.
static func _course(points: Array, sx: int, sz: int, meander: FastNoiseLite, amp: float) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	for p in points:
		pts.append(Vector2(p.x * sx, p.y * sz))
	var line := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		var steps := ceili(p1.distance_to(p2) * 2.0)
		for k in steps:
			var t := k / float(steps)
			line.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	line.append(pts.back())
	var out := PackedVector2Array()
	out.resize(line.size())
	for i in line.size():
		var along := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		out[i] = line[i] + Vector2(-along.y, along.x) * meander.get_noise_1d(i * 0.5) * amp
	return out


## Cuts a river along `course`. Its level (the top water cell) starts at `top`, never
## rises, keeps two cells under the lowest bank around and ends at `end`. Where the
## ground stands far above the water the river runs in a canyon: a wide dry floor
## between sheer walls. The water widens from `w0` to `w1` cells (half widths).
static func _river(course: PackedVector2Array, top: int, end: int, w0: float, w1: float, sx: int, sz: int,
		sea: int, heights: PackedInt32Array, water_top: PackedInt32Array, tops: PackedByteArray,
		flags: PackedByteArray) -> void:
	var n := course.size()
	var levels := PackedInt32Array()
	levels.resize(n)
	var canyon := PackedByteArray()
	canyon.resize(n)
	var level := top
	for i in n:
		var t := i / float(n - 1)
		var p := course[i]
		var along := (course[mini(i + 1, n - 1)] - course[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-along.y, along.x) * (lerpf(w0, w1, t) + 1.5)
		var ground := mini(_height_at(heights, sx, sz, p), mini(_height_at(heights, sx, sz, p + side),
			_height_at(heights, sx, sz, p - side)))
		level = mini(level, mini(ground - 2, int(round(lerpf(top, end, t)))))
		level = maxi(level, maxi(end, sea))
		levels[i] = level
		canyon[i] = int(ground - level > 5)
	# Each column takes the nearest point of the course.
	var best := {}
	for i in n:
		var t := i / float(n - 1)
		var rw := lerpf(w0, w1, t)
		var rf := rw + (3.5 if canyon[i] else 1.5)
		var reach := rf + (2.0 if canyon[i] else 5.0)
		var p := course[i]
		for z in range(maxi(0, floori(p.y - reach)), mini(sz, ceili(p.y + reach + 1.0))):
			for x in range(maxi(0, floori(p.x - reach)), mini(sx, ceili(p.x + reach + 1.0))):
				var d := Vector2(x + 0.5, z + 0.5).distance_to(p)
				if d > reach:
					continue
				var col := z * sx + x
				var prev: Variant = best.get(col)
				if prev == null or d < prev[0]:
					best[col] = [d, i, rw, rf]
	for col: int in best:
		var b: Array = best[col]
		var d: float = b[0]
		var i: int = b[1]
		var rw: float = b[2]
		var rf: float = b[3]
		var lv := levels[i]
		if d <= rw:
			heights[col] = mini(heights[col], lv - (2 if d < rw - 1.0 else 1))
			water_top[col] = maxi(water_top[col], lv)
			tops[col] = Mat.SAND
			flags[col] = INLAND
		elif d <= rf:
			if water_top[col] >= 0:
				continue
			if canyon[i]:
				heights[col] = lv
				tops[col] = Mat.SAND
				flags[col] = 0
			else:
				heights[col] = clampi(heights[col], lv, lv + 1)
				flags[col] &= ~ENTRANCE
		elif canyon[i]:
			# The canyon walls stay sheer.
			if heights[col] > lv + 2:
				flags[col] |= SHEER_TOP
		elif water_top[col] < 0:
			# A valley: the ground beyond the bank rises a cell per cell at most, so
			# loose ground lies as slopes down to the river.
			heights[col] = mini(heights[col], lv + 1 + int(d - rf))


## Ground height of the column under a point, or of the nearest column on the map.
static func _height_at(heights: PackedInt32Array, sx: int, sz: int, p: Vector2) -> int:
	return heights[clampi(floori(p.y), 0, sz - 1) * sx + clampi(floori(p.x), 0, sx - 1)]


## The swamp: flat wet ground a level or two above the sea, full of shallow pools with
## clay around them.
static func _swamp(sx: int, sz: int, sea: int, shape: PackedByteArray, pools: PackedByteArray,
		soil: PackedByteArray, heights: PackedInt32Array, water_top: PackedInt32Array,
		tops: PackedByteArray, flags: PackedByteArray) -> void:
	var c := Vector2(SWAMP.x * sx, SWAMP.y * sz)
	var r := Vector2(SWAMP.z * sx, SWAMP.w * sz)
	var pool := _byte(0.12)
	var mud := _byte(0.0)
	var bump := _byte(0.4)
	for z in range(maxi(1, int(c.y - r.y * 1.3)), mini(sz - 1, int(c.y + r.y * 1.3))):
		for x in range(maxi(1, int(c.x - r.x * 1.3)), mini(sx - 1, int(c.x + r.x * 1.3))):
			var col := z * sx + x
			var e := Vector2((x - c.x) / r.x, (z - c.y) / r.y).length() * (0.8 + 0.4 * shape[col] / 255.0)
			if e >= 1.0 or heights[col] < sea:
				continue
			var base := sea + 1 + int(soil[col] > bump)
			var p := pools[col]
			flags[col] = 0
			if p > pool and e < 0.92:
				heights[col] = base - (1 if p < pool + 20 else 2)
				water_top[col] = base
				tops[col] = Mat.CLAY
				flags[col] = INLAND
			else:
				heights[col] = base
				tops[col] = Mat.CLAY if p > mud else Mat.GRASS


## Writes the cells and the column masks from the laid-out heights: stone with ore,
## a few cells of dirt (not in the mountains), the top, water up to its level, and
## caves under dry land.
static func _fill(w: WorldData, noise_seed: int, heights: PackedInt32Array, water_top: PackedInt32Array,
		tops: PackedByteArray, flags: PackedByteArray) -> void:
	var sx := w.size_x
	var sy := w.size_y
	var sz := w.size_z
	var sea := w.sea_level
	var layer := sx * sz
	# 3D grids hold every other level (y / 2 * sx * sz + z * sx + x), see _grid_3d.
	var caves := _grid_3d(noise_seed, 0.03, 2, sx, sz, sy)
	var ores := _grid_3d(noise_seed + 1, 0.075, 1, sx, sz, sy)
	var cave_t := _byte(0.42)
	var ore_t := _byte(0.55)
	var cells := PackedByteArray()
	cells.resize(sx * sy * sz)
	var natural := PackedByteArray()
	natural.resize(sx * sy * sz)
	natural.fill(WorldData.WILD)
	var air := PackedInt64Array()
	air.resize(layer)
	var water := PackedInt64Array()
	water.resize(layer)
	var all := w.all_bits
	for col in layer:
		var height := heights[col]
		var wt := water_top[col]
		var top: int = tops[col]
		var rocky := top == Mat.STONE
		var dirt := height if rocky else maxi(0, height - 4)
		var i := col
		for y in dirt:
			cells[i] = Mat.COPPER_ORE if ores[(y >> 1) * layer + col] > ore_t else Mat.STONE
			i += layer
		for y in range(dirt, height):
			cells[i] = Mat.DIRT
			i += layer
		cells[i] = Mat.COPPER_ORE if rocky and ores[(height >> 1) * layer + col] > ore_t else top
		if flags[col] & SHEER_TOP:
			natural[i] = WorldData.WILD | WorldData.SHEER
		for y in range(height + 1, wt + 1):
			i += layer
			cells[i] = Mat.WATER
		var air_bits := all & ~((1 << (maxi(height, wt) + 1)) - 1)
		if wt > height:
			water[col] = ((1 << (wt + 1)) - 1) & ~((1 << (height + 1)) - 1)
		# Caves stay under dry land so they never touch the sea; in the mountains and
		# at the cave mouths of the hills they may break through the surface.
		if height > sea + 2 and wt < 0:
			var cave_top := height + 1 if rocky or flags[col] & ENTRANCE else height - 3
			i = layer + col
			for y in range(1, cave_top):
				if caves[(y >> 1) * layer + col] + caves[((y + 1) >> 1) * layer + col] > 2 * cave_t:
					cells[i] = Mat.AIR
					air_bits |= 1 << y
				i += layer
		air[col] = air_bits
	w.cells = cells
	w.natural = natural
	w.air_cols = air
	w.water_cols = water
	w.wild_cols.fill(all)


## Water above the sea must not stand beside or over open air: such air (a lower bank,
## a cave) becomes ground, except where the water steps down onto lower water of a
## river, which stays as a little waterfall.
static func _seal(w: WorldData, flags: PackedByteArray, tops: PackedByteArray) -> void:
	var sx := w.size_x
	var sz := w.size_z
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for col in sx * sz:
		if not flags[col] & INLAND:
			continue
		var x := col % sx
		var z := col / sx
		var wt: int = w.water_cols[col]
		while wt != 0:
			var bit := wt & -wt
			wt ^= bit
			var y := WorldData.level_of(bit)
			if w.get_cell(x, y - 1, z) == Mat.AIR:
				w.set_cell(x, y - 1, z, Mat.STONE)
				w.set_natural(x, y - 1, z, true)
			for dv: Vector2i in dirs:
				var nx := x + dv.x
				var nz := z + dv.y
				if nx < 0 or nz < 0 or nx >= sx or nz >= sz or w.get_cell(nx, y, nz) != Mat.AIR:
					continue
				var ncol := nz * sx + nx
				if w.water_cols[ncol] & (bit - 1):
					continue
				# Ground up to this level: the top keeps the column's material.
				var yy := y
				while yy >= 0 and w.get_cell(nx, yy, nz) == Mat.AIR:
					w.set_cell(nx, yy, nz, tops[ncol] if yy == y else Mat.DIRT)
					w.set_natural(nx, yy, nz, true)
					yy -= 1
				if yy >= 0 and w.get_cell(nx, yy, nz) == Mat.GRASS:
					w.set_cell(nx, yy, nz, Mat.DIRT)
					w.set_natural(nx, yy, nz, true)


## Trees on grass two cells apart (the middle of the leaf clumps, see _place_tree):
## a dense forest east of the river, groves where the forest noise is high, a few in
## the swamp and lone trees on open ground.
static func _forests(w: WorldData, world_seed: int, forest: PackedByteArray, heights: PackedInt32Array,
		water_top: PackedInt32Array, tops: PackedByteArray) -> void:
	var sx := w.size_x
	var sy := w.size_y
	var sz := w.size_z
	var center := Vector2(FOREST.x * sx, FOREST.y * sz)
	var radius := FOREST.z * minf(sx, sz)
	var swamp := Vector2(SWAMP.x * sx, SWAMP.y * sz)
	var swamp_r := Vector2(SWAMP.z * sx, SWAMP.w * sz)
	var grove_t := _byte(0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for z in range(5, sz - 5, 2):
		for x in range(5, sx - 5, 2):
			var col := z * sx + x
			var hh := heights[col]
			if water_top[col] >= 0 or tops[col] != Mat.GRASS or w.get_cell(x, hh, z) != Mat.GRASS \
					or w.get_cell(x, hh + 1, z) != Mat.AIR or hh + 14 >= sy:
				continue
			# Trunks side by side would merge into a wall of logs.
			if w.get_cell(x - 2, hh + 1, z) == Mat.LOG or w.get_cell(x + 2, hh + 1, z) == Mat.LOG \
					or w.get_cell(x, hh + 1, z - 2) == Mat.LOG or w.get_cell(x, hh + 1, z + 2) == Mat.LOG:
				continue
			var dense := 1.0 - smoothstep(0.6, 1.0, Vector2(x, z).distance_to(center) / radius)
			var chance := lerpf(0.004, 0.2, dense)
			if forest[col] > grove_t:
				chance = maxf(chance, 0.1)
			if Vector2((x - swamp.x) / swamp_r.x, (z - swamp.y) / swamp_r.y).length() < 1.0:
				chance = 0.03
			if rng.randf() < chance:
				_place_tree(w, x, hh + 1, z, rng)


## Nearest dry grass cell to the middle of the map.
static func find_spawn(w: WorldData) -> Vector3i:
	var cx := int(w.size_x / 2.0)
	var cz := int(w.size_z / 2.0)
	for r in range(0, maxi(w.size_x, w.size_z) / 2):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y := w.surface_y(x, z)
				if y > w.sea_level + 2 and y < w.size_y - 4 and w.get_cell(x, y - 1, z) == Mat.GRASS \
						and w.get_cell(x, y, z) == Mat.AIR and w.get_cell(x, y + 1, z) == Mat.AIR \
						and w.slope_mask(x, y - 1, z) == WorldData.FULL:
					return Vector3i(x, y, z)
	return Vector3i(cx, w.size_y - 1, cz)


## A trunk of 6 or 8 cells and a crown of leaves around points two cells apart, each
## point becoming one place for leaf cards (see Foliage). The points fill a low, wide
## ellipsoid: in the oblique view the top and the front of a crown both show, so a ball
## would look tall and narrow, while this one reads as round on screen (width about
## equal to height plus depth). Cells and column masks are written directly: a forest
## has a few hundred thousand leaves, too many for set_cell.
static func _place_tree(w: WorldData, x: int, y: int, z: int, rng: RandomNumberGenerator) -> void:
	var sx := w.size_x
	var sy := w.size_y
	var sz := w.size_z
	var layer := sx * sz
	var cells := w.cells
	var air := w.air_cols
	var leaf := w.leaf_cols
	var trunk := 6 + 2 * rng.randi_range(0, 1)
	var col := z * sx + x
	for i in trunk:
		cells[(y + i) * layer + col] = Mat.LOG
	var trunk_bits := ((1 << trunk) - 1) << y
	w.log_cols[col] |= trunk_bits
	air[col] &= ~trunk_bits
	# Radii in points; points sit on even levels, the middle one just above the trunk.
	var rx := 2.2 + rng.randf_range(-0.2, 0.3)
	var rz := 1.8 + rng.randf_range(-0.2, 0.2)
	var ry := 1.5 + rng.randf_range(-0.1, 0.3)
	var middle := ((y + trunk - 1) & ~1) + 2
	for dy in range(-2, 3):
		for dz in range(-2, 3):
			for dx in range(-3, 4):
				var d := Vector3(dx / rx, dy / ry, dz / rz)
				if d.length() > 1.0 + rng.randf_range(-0.1, 0.1):
					continue
				var py := middle + 2 * dy
				for oz in range(-1, 2):
					var pz := z + 2 * dz + oz
					if pz < 0 or pz >= sz:
						continue
					for ox in range(-1, 2):
						var px := x + 2 * dx + ox
						if px < 0 or px >= sx:
							continue
						var c := pz * sx + px
						var bits := 0
						for oy in range(-1, 2):
							var yy := py + oy
							if yy < 0 or yy >= sy:
								continue
							var i := yy * layer + c
							if cells[i] == Mat.AIR:
								cells[i] = Mat.LEAVES
								bits |= 1 << yy
						if bits != 0:
							leaf[c] |= bits
							air[c] &= ~bits


## Byte value of a noise level in the grids below.
static func _byte(v: float) -> int:
	return int((v * 0.5 + 0.5) * 255.0)


static func _grid_2d(s: int, freq: float, octaves: int, w: int, h: int) -> PackedByteArray:
	return _noise(s, freq, octaves).get_image(w, h, false, false, false).get_data()


## A 3D noise for every other level 0, 2, 4.. up to `depth` (the level between two is
## their average). Sampled at half the resolution and scaled up smoothly in x and z,
## which is much faster than the full grid and looks the same at this frequency.
static func _grid_3d(s: int, freq: float, octaves: int, w: int, h: int, depth: int) -> PackedByteArray:
	var data := PackedByteArray()
	for img in _noise(s, freq * 2.0, octaves).get_image_3d(w / 2, h / 2, depth / 2 + 1, false, false):
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		data.append_array(img.get_data())
	return data


static func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n
