extends RefCounted
## Deterministic world generator: the same seed always gives the same world.
## Layers (relief, ridges, soil, caves, ores, forest, ravines, steepness) are independent
## noises, so rare places come from rare combinations rather than from hand-made
## "special places". Every generated cell is marked wild: loose ground lies as slopes
## wherever it steps down one level, while stone, the steep patches and the ravines keep
## sheer walls; cliffs and banks turn their corners diagonally (see WorldData).

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")


static func generate(world_seed: int, sx := 128, sy := 20, sz := 128) -> WorldData:
	var w := WorldData.new(sx, sy, sz)
	var sea := w.sea_level
	# Noise is sampled natively into byte grids (0..255 for -1..1): much faster than
	# calling the noise per cell from GDScript, which matters in the browser.
	var hills := _grid_2d(world_seed, 0.012, 4, sx, sz)
	var ridges := _grid_2d(world_seed + 1, 0.018, 3, sx, sz)
	var soil := _grid_2d(world_seed + 4, 0.05, 2, sx, sz)
	var forest := _grid_2d(world_seed + 5, 0.03, 2, sx, sz)
	var gullies := _grid_2d(world_seed + 6, 0.02, 1, sx, sz)
	var steep := _grid_2d(world_seed + 7, 0.09, 2, sx, sz)
	# 3D grids use the same layout as the cells: (y * sz + z) * sx + x.
	var caves := _grid_3d(world_seed + 2, 0.06, 2, sx, sz, sy)
	var ores := _grid_3d(world_seed + 3, 0.15, 1, sx, sz, sy)
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
			var height := int(round(sea - 4 + (3.0 + h * 6.0 + r * r * 30.0) * mask))
			height = clampi(height, 1, sy - 3)
			var rocky := height > sea + 6
			# Ravines: narrow winding cuts three levels deep along a noise's zero
			# line, through the lowlands; below the sea they fill as creeks.
			var gully := absi(gullies[col] - 128)
			if not rocky and height > sea and mask > 0.6 and gully < 5:
				height -= 3 if gully < 4 else 2
			heights[col] = height
			var top := Mat.GRASS
			if rocky:
				top = Mat.STONE
			elif height <= sea + 1:
				top = Mat.SAND if soil[col] < soil_t else Mat.CLAY
			var sloping := steep[col] < steep_t
			for y in range(0, height + 1):
				var i := y * layer + col
				var m := Mat.STONE
				if y == height:
					m = top
				elif y >= height - 2 and not rocky:
					m = Mat.DIRT
				if m == Mat.STONE and ores[i] > ore_t:
					m = Mat.COPPER_ORE
				cells[i] = m
				if y == height and not sloping:
					natural[i] = WorldData.WILD | WorldData.SHEER
			for y in range(height + 1, sea + 1):
				cells[y * layer + col] = Mat.WATER
			# Caves stay under dry land so they never touch the sea; in mountains
			# they may break through the surface and make entrances.
			if height > sea + 1:
				var cave_top := height + 1 if rocky else height - 1
				for y in range(1, cave_top):
					var i := y * layer + col
					if caves[i] > cave_t:
						cells[i] = Mat.AIR
	w.cells = cells
	w.natural = natural

	# Trees grow only where the forest noise allows.
	var forest_t := _byte(0.1)
	for col in layer:
		if forest[col] < forest_t:
			heights[col] = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for z in range(2, sz - 2):
		for x in range(2, sx - 2):
			var hh := heights[z * sx + x]
			if hh < 0 or w.get_cell(x, hh, z) != Mat.GRASS or hh + 7 >= sy:
				continue
			# Trunks side by side would merge into a wall of logs.
			if w.get_cell(x - 1, hh + 1, z) == Mat.LOG or w.get_cell(x + 1, hh + 1, z) == Mat.LOG \
					or w.get_cell(x, hh + 1, z - 1) == Mat.LOG or w.get_cell(x, hh + 1, z + 1) == Mat.LOG:
				continue
			if rng.randf() > 0.08:
				continue
			_place_tree(w, x, hh + 1, z, rng)
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
				if y > w.sea_level + 1 and y < w.size_y - 2 and w.get_cell(x, y - 1, z) == Mat.GRASS \
						and w.get_cell(x, y, z) == Mat.AIR:
					return Vector3i(x, y, z)
	return Vector3i(cx, w.size_y - 1, cz)


static func _place_tree(w: WorldData, x: int, y: int, z: int, rng: RandomNumberGenerator) -> void:
	var trunk := 3 + rng.randi_range(0, 1)
	for i in trunk:
		w.set_cell(x, y + i, z, Mat.LOG)
	for dy in range(trunk - 1, trunk + 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var corner := absi(dx) == 1 and absi(dz) == 1
				if corner and (dy == trunk + 1 or rng.randf() < 0.3):
					continue
				if w.get_cell(x + dx, y + dy, z + dz) == Mat.AIR:
					w.set_cell(x + dx, y + dy, z + dz, Mat.LEAVES)
	w.set_cell(x, y + trunk + 2, z, Mat.LEAVES)


## Byte value of a noise level in the grids below.
static func _byte(v: float) -> int:
	return int((v * 0.5 + 0.5) * 255.0)


static func _grid_2d(s: int, freq: float, octaves: int, w: int, h: int) -> PackedByteArray:
	return _noise(s, freq, octaves).get_image(w, h, false, false, false).get_data()


static func _grid_3d(s: int, freq: float, octaves: int, w: int, h: int, depth: int) -> PackedByteArray:
	var data := PackedByteArray()
	for img in _noise(s, freq, octaves).get_image_3d(w, h, depth, false, false):
		data.append_array(img.get_data())
	return data


static func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n
