extends RefCounted
## Deterministic world generator: the same seed always gives the same world.
## Layers (relief, ridges, soil, caves, ores, forest, ravines, steepness) are independent
## noises, so rare places come from rare combinations rather than from hand-made
## "special places". Every generated cell is marked wild: loose ground lies as slopes
## wherever it steps down one cell, while stone, the steep patches and the ravines keep
## sheer walls; cliffs and banks turn their corners diagonally (see WorldData).
## Sizes are in cells (8 px); the relief is laid out in world units of two cells.

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")
const Trees := preload("res://src/shared/trees.gd")


static func generate(world_seed: int, sx := 256, sy := 40, sz := 256) -> WorldData:
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
	# 3D grids hold every other level (y / 2 * sx * sz + z * sx + x), see _grid_3d.
	var caves := _grid_3d(world_seed + 2, 0.03, 2, sx, sz, sy)
	var ores := _grid_3d(world_seed + 3, 0.075, 1, sx, sz, sy)
	var cave_t := _byte(0.42)
	var ore_t := _byte(0.55)
	var soil_t := _byte(0.25)
	var steep_t := _byte(0.4)
	var center := Vector2(sx, sz) * 0.5
	var radius := minf(sx, sz) * 0.5
	var layer := sx * sz
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
	var heights := PackedInt32Array()
	heights.resize(layer)

	for z in sz:
		for x in sx:
			var col := z * sx + x
			# Island mask: land in the middle, ocean at the edges.
			var d := Vector2(x, z).distance_to(center) / radius
			var mask := 1.0 - smoothstep(0.55, 0.95, d)
			var h := hills[col] / 255.0
			var r := maxf(0.0, ridges[col] / 127.5 - 1.0)
			var height := int(round(sea - 8 + (6.0 + h * 12.0 + r * r * 60.0) * mask))
			height = clampi(height, 2, sy - 6)
			var rocky := height > sea + 12
			# Ravines: narrow winding cuts six cells deep along a noise's zero line,
			# through the lowlands; below the sea they fill as creeks.
			var gully := absi(gullies[col] - 128)
			if not rocky and height > sea and mask > 0.6 and gully < 5:
				height -= 6 if gully < 4 else 4
			heights[col] = height
			var top := Mat.GRASS
			if rocky:
				top = Mat.STONE
			elif height <= sea + 2:
				top = Mat.SAND if soil[col] < soil_t else Mat.CLAY
			# Stone with ore in it, a few cells of dirt (not in the mountains), the top.
			var dirt := height if rocky else maxi(0, height - 4)
			var i := col
			for y in dirt:
				cells[i] = Mat.COPPER_ORE if ores[(y >> 1) * layer + col] > ore_t else Mat.STONE
				i += layer
			for y in range(dirt, height):
				cells[i] = Mat.DIRT
				i += layer
			cells[i] = Mat.COPPER_ORE if top == Mat.STONE and ores[(height >> 1) * layer + col] > ore_t else top
			if steep[col] >= steep_t:
				natural[i] = WorldData.WILD | WorldData.SHEER
			for y in range(height + 1, sea + 1):
				i += layer
				cells[i] = Mat.WATER
			var air_bits := all & ~((1 << (maxi(height, sea) + 1)) - 1)
			if height < sea:
				water[col] = ((1 << (sea + 1)) - 1) & ~((1 << (height + 1)) - 1)
			# Caves stay under dry land so they never touch the sea; in mountains
			# they may break through the surface and make entrances.
			if height > sea + 2:
				var cave_top := height + 1 if rocky else height - 3
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

	# Trees grow only where the forest noise allows, their trunks on odd cells (the
	# middle of the leaf clumps, see _place_tree).
	var forest_t := _byte(0.1)
	for col in layer:
		if forest[col] < forest_t:
			heights[col] = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for z in range(5, sz - 5, 2):
		for x in range(5, sx - 5, 2):
			var hh := heights[z * sx + x]
			if hh < 0 or w.get_cell(x, hh, z) != Mat.GRASS:
				continue
			# Trunks side by side would merge into a wall of logs.
			if w.get_cell(x - 2, hh + 1, z) == Mat.LOG or w.get_cell(x + 2, hh + 1, z) == Mat.LOG \
					or w.get_cell(x, hh + 1, z - 2) == Mat.LOG or w.get_cell(x, hh + 1, z + 2) == Mat.LOG:
				continue
			if rng.randf() > 0.06:
				continue
			# Spruces on the higher ground, oaks below, mixed where they meet.
			var species := Trees.SPRUCE if hh + rng.randi_range(-2, 2) > sea + 4 else Trees.OAK
			# Under the top of the world trees grow smaller, or not at all.
			var scale := Trees.fit(species, sy - 1 - hh)
			if scale > 0.0:
				Trees.place(w, x, hh + 1, z, species, rng, scale)
	w.mark_all_dirty()
	w.refresh_shapes()
	return w


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
