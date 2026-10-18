extends RefCounted
## Deterministic world generator: the same seed always gives the same world.
## Layers (relief, ridges, soil, caves, ores, forest) are independent noises, so rare
## places come from rare combinations rather than from hand-made "special places".

const Mat := preload("res://src/shared/materials.gd")
const WorldData := preload("res://src/shared/world_data.gd")


static func generate(world_seed: int, sx := 128, sy := 20, sz := 128) -> WorldData:
	var w := WorldData.new(sx, sy, sz)
	var sea := w.sea_level
	var hills := _noise(world_seed, 0.012, 4)
	var ridges := _noise(world_seed + 1, 0.018, 3)
	var caves := _noise(world_seed + 2, 0.06, 2)
	var ores := _noise(world_seed + 3, 0.15, 1)
	var soil := _noise(world_seed + 4, 0.05, 2)
	var forest := _noise(world_seed + 5, 0.03, 2)
	var center := Vector2(sx, sz) * 0.5
	var radius := minf(sx, sz) * 0.5
	var heights := PackedInt32Array()
	heights.resize(sx * sz)

	for z in sz:
		for x in sx:
			# Island mask: land in the middle, ocean at the edges.
			var d := Vector2(x, z).distance_to(center) / radius
			var mask := 1.0 - smoothstep(0.55, 0.95, d)
			var h := hills.get_noise_2d(x, z) * 0.5 + 0.5
			var r := maxf(0.0, ridges.get_noise_2d(x, z))
			var height := int(round(sea - 4 + (3.0 + h * 6.0 + r * r * 30.0) * mask))
			height = clampi(height, 1, sy - 3)
			heights[z * sx + x] = height
			var rocky := height > sea + 6
			for y in range(0, height + 1):
				var m := Mat.STONE
				if y >= height - 2 and not rocky:
					m = Mat.DIRT
				if y == height:
					if rocky:
						m = Mat.STONE
					elif height <= sea + 1:
						m = Mat.SAND if soil.get_noise_2d(x, z) < 0.25 else Mat.CLAY
					else:
						m = Mat.GRASS
				if m == Mat.STONE and ores.get_noise_3d(x, y * 2.0, z) > 0.55:
					m = Mat.COPPER_ORE
				w.set_cell(x, y, z, m)
			for y in range(height + 1, sea + 1):
				w.set_cell(x, y, z, Mat.WATER)
			# Caves stay under dry land so they never touch the sea; in mountains
			# they may break through the surface and make entrances.
			if height > sea + 1:
				var top := height + 1 if rocky else height - 1
				for y in range(1, top):
					if caves.get_noise_3d(x, y * 1.8, z) > 0.42:
						w.set_cell(x, y, z, Mat.AIR)

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for z in range(2, sz - 2):
		for x in range(2, sx - 2):
			var hh := heights[z * sx + x]
			if w.get_cell(x, hh, z) != Mat.GRASS or hh + 7 >= sy:
				continue
			if forest.get_noise_2d(x, z) < 0.1 or rng.randf() > 0.08:
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


static func _noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n
