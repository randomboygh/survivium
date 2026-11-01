extends "res://tests/unit/test_case.gd"
## The generator: chunks the same in any order, mountains, rivers and caves, trees and bushes.


func run() -> void:
	_test_generation()
	_test_mountains()
	_test_caves()
	_test_relief()
	_test_trees()
	_test_bushes()
	_test_custom_plants()


func _test_generation() -> void:
	var a := _land(42)
	var b := _land(42)
	var c := _land(43)
	var keys: Array = a.area
	_check(_same(a.world, b.world, keys), "same seed gives the same world")
	_check(not _same(a.world, c.world, keys), "different seeds give different worlds")
	var counts := {}
	for key: Vector2i in keys:
		for m in a.world.chunks[key].cells:
			counts[m] = counts.get(m, 0) + 1
	# Water may lie beyond the area round the spawn: the chunk of the nearest lake then.
	if counts.get(Mat.WATER, 0) == 0:
		var lake: Vector2i = a.gen.find_place("lake", Vector2i(a.gen.spawn_guess.x, a.gen.spawn_guess.z))
		var key := WorldData.chunk_key(lake.x, lake.y)
		_ensure_stage(a.gen, key, WorldGen.TERRAIN)
		for m in a.world.chunks[key].cells:
			counts[m] = counts.get(m, 0) + 1
	for m in [Mat.GRASS, Mat.STONE, Mat.WATER, Mat.DIRT]:
		_check(counts.get(m, 0) > 0, "world contains %s" % Mat.NAMES[m])
	var w: WorldData = a.world
	var spawn := WorldGen.find_spawn(w, a.gen.spawn_guess)
	_check(spawn.y > w.sea_level, "spawn is above the sea")
	_check(w.get_cell(spawn.x, spawn.y, spawn.z) == Mat.AIR, "spawn cell is free")
	# The world does not depend on the order its chunks are made in: generated
	# chunk by chunk from the other corner, stage by stage, it is the same as
	# generated at once.
	var gen := WorldGen.new(42, 40)
	for i in range(keys.size() - 1, -1, -1):
		_ensure_stage(gen, keys[i], WorldGen.SHAPED)
	_check(_same(gen.world, w, keys), "chunks made in another order give the same cells and shapes")
	_check(gen.world.trees == w.trees and gen.world.bushes == w.bushes, "and the same trees and bushes")
	# Chunks dropped far away are made again the same, with the crowns of the trees
	# around that reach into them: a chunk of the area, a planted one beside it and
	# one with terrain only beyond that.
	var first: Vector2i = keys[0]
	var dropped: Array[Vector2i] = [first + Vector2i(1, 1), first + Vector2i(-1, 1), first + Vector2i(-2, 2)]
	var stages: Array[int] = []
	for k in dropped:
		stages.append(gen.stage_of(k))
		gen.forget(k)
	for i in dropped.size():
		_ensure_stage(gen, dropped[i], stages[i])
	for k in keys:
		_ensure_stage(gen, k, WorldGen.SHAPED)
	_check(_same_cells(gen.world, w, keys + dropped) and _same_view(gen, gen.world, w, keys + dropped),
		"chunks dropped and made again are the same")
	_check(gen.world.trees == w.trees and gen.world.bushes == w.bushes, "and so are their trees and bushes")
	# Water above the sea never leaks: nothing open under it, and no air beside it.
	var leaks := _leaks(w, keys)
	_check(leaks == 0, "water above the sea does not leak (%d leaks)" % leaks)
	# Sand lies deep: under a sand top, its own layers (Mat.layers), then dirt or stone.
	var shore: Vector2i = a.gen.find_place("beach", Vector2i(a.gen.spawn_guess.x, a.gen.spawn_guess.z))
	var shore_key := WorldData.chunk_key(shore.x, shore.y)
	_ensure_stage(a.gen, shore_key, WorldGen.TERRAIN)
	var deep := Mat.layers[Mat.BEACH]
	var sandy := 0
	var bedded := 0
	for lz in WorldData.CHUNK:
		for lx in WorldData.CHUNK:
			var x := shore_key.x * WorldData.CHUNK + lx
			var z := shore_key.y * WorldData.CHUNK + lz
			var y := w.size_y - 1
			while y > 0 and w.get_cell(x, y, z) in [Mat.AIR, Mat.WATER]:
				y -= 1
			if w.get_cell(x, y, z) != Mat.BEACH or y <= deep:
				continue
			sandy += 1
			var bed := w.get_cell(x, y - deep - 1, z)
			if range(1, deep + 1).all(func(d: int) -> bool: return w.get_cell(x, y - d, z) == Mat.BEACH) \
					and (bed == Mat.DIRT or bed == Mat.STONE):
				bedded += 1
	_check(deep >= 2 and sandy > 0 and bedded == sandy,
		"sand on the surface has %d more layers of sand under it (%d of %d columns)" % [deep, bedded, sandy])
	# Settings change the world: more water, a different world.
	var wet := WorldGen.new(42, 40, {"water": 2})
	_check(wet.coast_level > a.gen.coast_level, "more water lifts the coast")
	# A river runs into a lake without a step in its bed: where a river column
	# meets the lake, the lake floor is seldom higher (only beside the channel).
	var mouth := WorldGen.new(20261018).lay_out(72, -1844, 256, 256)
	var meets := 0
	var steps := 0
	for j in mouth.feature.size():
		if mouth.feature[j] != WorldGen.RIVER or j < 256 or j >= 255 * 256 or j % 256 == 0 or j % 256 == 255:
			continue
		for dj: int in [-1, 1, -256, 256]:
			if mouth.feature[j + dj] in [WorldGen.LAKE, WorldGen.OCEAN]:
				meets += 1
				if mouth.heights[j + dj] > mouth.heights[j]:
					steps += 1
	_check(meets > 0 and steps * 4 < meets, "rivers flow into lakes without a step (%d of %d higher)" % [steps, meets])


## Cells of water above the sea in the chunks `keys` with air under them, or air beside
## them that is not over lower water (a waterfall).
func _leaks(w: WorldData, keys: Array) -> int:
	var leaks := 0
	for key: Vector2i in keys:
		var ch: WorldData.Chunk = w.chunks[key]
		for col in WorldData.LAYER:
			var water: int = ch.water[col]
			var x: int = key.x * 16 + (col & 15)
			var z: int = key.y * 16 + (col >> 4)
			while water != 0:
				var bit := water & -water
				water ^= bit
				var y := WorldData.level_of(bit)
				if y <= w.sea_level:
					continue
				if w.get_cell(x, y - 1, z) == Mat.AIR:
					leaks += 1
				for d: Vector2i in WorldData.SIDES:
					if w.get_cell(x + d.x, y, z + d.y) == Mat.AIR and w.water_col(x + d.x, z + d.y) & (bit - 1) == 0:
						leaks += 1
	return leaks


## Mountains rise to snowy rock near the top of the world; rivers come down them over
## waterfalls and rapids and part into deltas at the sea; caves open in their sides.
func _test_mountains() -> void:
	var gen := WorldGen.new(20261018)
	var near := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	var peak := gen.find_place("peak", near)
	var top := gen.lay_out(peak.x - 32, peak.y - 32, 64, 64)
	var highest := 0
	var bare := 0
	for j in top.heights.size():
		highest = maxi(highest, top.heights[j])
		if top.heights[j] >= gen.sea + WorldGen.ROCK_LINE + 3 and top.water[j] < 0:
			bare += 1 if top.tops[j] in [Mat.SCREE, Mat.STONE] else 0
	_check(peak != near and highest >= gen.size_y - 8, "high mountains reach near the top of the world (%d)" % highest)
	_check(bare > 0, "their high slopes are bare scree and stone")
	var w: WorldData = gen.world
	_check(w.peak_snow(w.sea_level + WorldData.SNOW_LINE + 2) == 1.0 and w.peak_snow(w.sea_level + 10) == 0.0,
		"snow lies all year above the snow line only")
	# A waterfall: river water beside air over water two levels or more below, the
	# same whichever order its chunks are made in, and nothing leaks.
	var fall := gen.find_place("waterfall", near)
	var from := WorldData.chunk_key(fall.x, fall.y) - Vector2i(1, 1)
	gen.generate_area(from, from + Vector2i(3, 3))
	var keys := []
	for cz in range(from.y, from.y + 3):
		for cx in range(from.x, from.x + 3):
			keys.append(Vector2i(cx, cz))
	var drops := 0
	for dz in range(-16, 17):
		for dx in range(-16, 17):
			var x := fall.x + dx
			var z := fall.y + dz
			var y := WorldData.top_level(w.water_col(x, z))
			if y <= w.sea_level or w.get_cell(x, y + 1, z) != Mat.AIR:
				continue
			for d: Vector2i in WorldData.SIDES:
				if w.get_cell(x + d.x, y, z + d.y) == Mat.AIR and w.get_cell(x + d.x, y - 1, z + d.y) == Mat.AIR:
					drops += 1
	_check(drops > 0, "rivers in the mountains fall over steps")
	_check(_leaks(w, keys) == 0, "and their water does not leak")
	var other := WorldGen.new(20261018)
	for i in range(keys.size() - 1, -1, -1):
		_ensure_stage(other, keys[i], WorldGen.SHAPED)
	_check(_same(other.world, w, keys), "made in another order the falls are the same")
	_check(gen.find_place("rapids", near) != near and gen.find_place("delta", near) != near,
		"rivers have rapids, and deltas at the sea")
	# A cave cut into a mountain's side: open to the air at its mouth, under a roof
	# further in.
	var mountain := gen.find_place("mountain", near)
	var cave := []
	for gz in range(-6, 7):
		for gx in range(-6, 7):
			if cave.is_empty():
				cave = gen._tunnel(floori(mountain.x / float(WorldGen.TUNNEL_GRID)) + gx,
					floori(mountain.y / float(WorldGen.TUNNEL_GRID)) + gz)
	_check(not cave.is_empty(), "mountains have caves in their sides")
	if not cave.is_empty():
		var mouth := Vector2(cave[0], cave[1])
		var floor_y: int = cave[3]
		var key := WorldData.chunk_key(int(mouth.x), int(mouth.y))
		gen.generate_area(key - Vector2i(2, 2), key + Vector2i(3, 3))
		var roofed := 0
		for along in range(4, WorldGen.TUNNEL_LEN):
			var p: Vector2 = mouth + cave[2] * along
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var x := int(p.x) + dx
					var z := int(p.y) + dz
					if w.get_cell(x, floor_y + 1, z) == Mat.AIR and w.surface_y(x, z) > floor_y + 4:
						roofed += 1
		_check(roofed > 0, "a gallery runs into the mountain under its roof (%d cells)" % roofed)


## The caves setting: more caves under the ground, more mouths and more galleries cut
## into mountain sides the higher it is.
func _test_caves() -> void:
	var counts := []
	for level in 3:
		var gen := WorldGen.new(20261018, 48, {"caves": level})
		var near := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
		var mountain := gen.find_place("mountain", near)
		var tunnels := 0
		for gz in range(-8, 9):
			for gx in range(-8, 9):
				if not gen._tunnel(floori(mountain.x / float(WorldGen.TUNNEL_GRID)) + gx,
						floori(mountain.y / float(WorldGen.TUNNEL_GRID)) + gz).is_empty():
					tunnels += 1
		var key := WorldData.chunk_key(mountain.x, mountain.y)
		gen.generate_area(key - Vector2i(1, 1), key + Vector2i(2, 2))
		var hollow := 0
		var mouths := 0
		var lay := gen.lay_out(key.x * WorldData.CHUNK - 32, key.y * WorldData.CHUNK - 32, 96, 96)
		for f in lay.flags:
			mouths += 1 if f & WorldGen.ENTRANCE else 0
		for dz in range(-WorldData.CHUNK, 2 * WorldData.CHUNK):
			for dx in range(-WorldData.CHUNK, 2 * WorldData.CHUNK):
				var x := key.x * WorldData.CHUNK + dx
				var z := key.y * WorldData.CHUNK + dz
				var top := gen.world.surface_y(x, z)
				for y in range(1, top - 3):
					hollow += 1 if gen.world.get_cell(x, y, z) == Mat.AIR else 0
		counts.append([tunnels, mouths, hollow])
	_check(counts[0][0] < counts[1][0] and counts[1][0] < counts[2][0], "more caves in mountain sides with the setting %s" % [counts])
	_check(counts[0][1] < counts[1][1] and counts[1][1] < counts[2][1], "more cave mouths with the setting")
	_check(counts[0][2] < counts[1][2] and counts[1][2] < counts[2][2], "more hollows under the ground with the setting")
	_check(WorldGen.new(20261018).settings.caves == 1, "a world made before the setting keeps its caves")


## Relief 1: ranges with gorges, tors, mesas with banded walls and canyons, the same
## whichever order the chunks are made in; worlds without the setting keep relief 0.
func _test_relief() -> void:
	_check(WorldGen.new(20261018).settings.relief == 0, "a world made before the relief setting keeps its relief")
	var gen := WorldGen.new(20261018, 48, {"relief": 1})
	var near := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	for what in ["gorge", "tor", "mesa", "canyon"]:
		_check(gen.find_place(what, near) != near, "relief 1 has a %s" % what)
	# A gorge: ground on both sides of its floor rises sheer above it.
	var gorge := gen.find_place("gorge", near)
	var lay := gen.lay_out(gorge.x - 8, gorge.y - 8, 17, 17)
	var floor_h: int = lay.heights[8 * 17 + 8]
	var walls := 0
	for j in lay.heights.size():
		walls += 1 if lay.heights[j] >= floor_h + 4 else 0
	_check(walls > 0, "a gorge has walls over its floor")
	# A mesa: its walls are banded (clay and sand under its top), and its chunks are the
	# same made in another order.
	var mesa := gen.find_place("mesa", near)
	var from := WorldData.chunk_key(mesa.x, mesa.y) - Vector2i(1, 1)
	gen.generate_area(from, from + Vector2i(3, 3))
	var w: WorldData = gen.world
	var kinds := {}
	var top := w.surface_y(mesa.x, mesa.y)
	for y in range(w.sea_level, top - 1):
		kinds[w.get_cell(mesa.x, y, mesa.y)] = true
	_check(kinds.size() >= 3, "a mesa's walls are banded (%d kinds of layer)" % kinds.size())
	var keys := []
	for cz in range(from.y, from.y + 3):
		for cx in range(from.x, from.x + 3):
			keys.append(Vector2i(cx, cz))
	var other := WorldGen.new(20261018, 48, {"relief": 1})
	for i in range(keys.size() - 1, -1, -1):
		_ensure_stage(other, keys[i], WorldGen.SHAPED)
	_check(_same(other.world, w, keys), "made in another order the mesas are the same")
	_check(_leaks(w, keys) == 0, "and water does not leak there")


func _test_trees() -> void:
	# Every species at every scale stays within the height it promises, so the
	# generator can tell whether a tree fits under the top of the world.
	var rng := RandomNumberGenerator.new()
	var fits := true
	for species in Trees.SPECIES.size():
		for scale in [0.6, 0.8, 1.0, 1.3]:
			for k in 6:
				rng.seed = k
				var w := WorldData.new(40, Vector2i(32, 32))
				Trees.place(w, 15, 1, 15, species, rng, scale)
				var top := 0
				for c: WorldData.Chunk in w.chunks.values():
					for col in WorldData.LAYER:
						top = maxi(top, WorldData.top_level(c.leaf[col] | c.logs[col]))
				fits = fits and top <= Trees.height(species, scale)
	_check(fits, "trees stay within Trees.height")
	var strips := _woods()
	var w: WorldData = strips.world
	var kinds := {}
	var trunks := true
	for at in w.trees:
		kinds[w.trees[at]] = true
		trunks = trunks and w.log_col(at.x, at.y) != 0
	_check(not w.trees.is_empty() and trunks, "every noted tree has a trunk")
	# The rare ones (a share of a few hundredths) may miss the few dozen trees of the strips.
	_check(_named("trees", Trees.SPECIES, ["biomes:taiga", "biomes:forest"], 0.1).all(func(k: int) -> bool: return kinds.has(k))
		and kinds.keys().all(func(k: int) -> bool: return k in _named("trees", Trees.SPECIES, Biomes.IDS)),
		"the generator grows every species the taiga and the forest name by a tenth or more, and only species some biome names: %s" % [kinds.keys()])
	# Crowns of spruces take needle cards, of oaks leaf cards.
	var rows := {}
	for key: Vector2i in strips.keys:
		var chunk: Dictionary = Foliage.build_chunk(w, key.x * 16, key.y * 16, 16)
		var buf: PackedFloat32Array = chunk.clumps[1]
		for i in chunk.clumps[0]:
			var row := int(buf[i * 20 + 19]) % Foliage.DEEP_ROW
			rows[row >= 3] = true
	_check(rows.size() == 2, "crowns have both broad leaves and needles")


## Strips of chunks across a taiga and a forest near the spawn, where both species of
## tree and every type of bush grow: the world the tree and bush tests look at
## ({"world", "keys"}).
const STRIP_CHUNKS := 6


## The indices in `list` of the records the `field` shares of biomes `ids` name (a
## species no biome grows is not expected in the strips; the strips across the taiga
## and the forest cross other biomes too).
func _named(field: String, list: Array, ids: Array, least := 0.0) -> Array:
	var out := []
	for id in ids:
		var shares: Dictionary = Biomes.of(Biomes.index(id)).get(field, {})
		for key in shares:
			if shares[key] < least:
				continue
			for i in list.size():
				if list[i].id == key and not i in out:
					out.append(i)
	return out


func _woods() -> Dictionary:
	var gen := WorldGen.new(42)
	var keys: Array[Vector2i] = []
	var near := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	for what in ["taiga", "forest"]:
		var at := WorldData.chunk_key(gen.find_place(what, near).x, gen.find_place(what, near).y)
		for x in range(at.x - STRIP_CHUNKS / 2, at.x + STRIP_CHUNKS / 2):
			_ensure_stage(gen, Vector2i(x, at.y), WorldGen.SHAPED)
			keys.append(Vector2i(x, at.y))
	return {"world": gen.world, "keys": keys}


func _test_bushes() -> void:
	var w: WorldData = _woods().world
	var kinds := {}
	var on_grass := true
	for at: Vector3i in w.bushes:
		kinds[w.bushes[at]] = true
		on_grass = on_grass and w.get_cell(at.x, at.y - 1, at.z) == Mat.GRASS and w.get_cell(at.x, at.y, at.z) == Mat.AIR
	_check(on_grass, "bushes stand in air on grass")
	_check(_named("bushes", Bushes.TYPES, ["biomes:taiga", "biomes:forest"]).all(func(k: int) -> bool: return kinds.has(k))
		and kinds.keys().all(func(k: int) -> bool: return k in _named("bushes", Bushes.TYPES, Biomes.IDS)),
		"the generator grows every type of bush the taiga and the forest name, and only types some biome names: %s" % [kinds.keys()])
	# Each bush draws its type's clusters, berry bushes some with berries.
	var cells: Array[Vector3i] = []
	cells.assign(w.bushes.keys())
	var part: Array = Foliage.bushes(cells, w.bushes)
	var want := 0
	for at in cells:
		want += Bushes.TYPES[w.bushes[at]].cards
	_check(part[0] == want, "bushes draw their clusters")
	var buf: PackedFloat32Array = part[1]
	var ripe := false
	for i in part[0]:
		ripe = ripe or int(buf[i * 20 + 19]) % Foliage.DEEP_ROW >= PixelTextures.BERRY_ROW
	_check(ripe, "berry bushes have clusters with berries")
	# The plants on grass, for what cutting it gives, are the ones drawn there.
	var found := {}
	var same := true
	for at: Vector3i in w.bushes:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var c := at + Vector3i(dx, -1, dz)
				var ids := Grass.plants_on(w, c.x, c.y, c.z)
				same = same and ids == Grass.plants_on(w, c.x, c.y, c.z)
				for id in ids:
					found[id] = true
	_check(same and found.has(Plants.TUFT), "grass has its plants, the same each time")
	# Cut short, grass keeps only its low tufts; sown with grain, ears stand on it.
	var tall := Vector3i(-1, -1, -1)
	for at: Vector3i in w.bushes:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var c := at + Vector3i(dx, -1, dz)
				if tall.y < 0 and Grass.plants_on(w, c.x, c.y, c.z).any(func(id) -> bool: return id != Plants.TUFT):
					tall = c
	_check(tall.y >= 0, "some grass has more than tufts on it")
	if tall.y >= 0:
		w.set_turf(tall, "")
		var short := Grass.plants_on(w, tall.x, tall.y, tall.z)
		_check(not short.is_empty() and short.all(func(id) -> bool: return id == Plants.TUFT), "grass cut short has only tufts")
		w.set_turf(tall, Plants.EARS)
		_check(Grass.plants_on(w, tall.x, tall.y, tall.z).count(Plants.EARS) >= 2, "sown grass grows ears")
		w.set_cell(tall.x, tall.y, tall.z, Mat.DIRT)
		_check(w.turf_at(tall) == null, "a changed cell forgets what grew on it")
	# Moss and mushrooms grow in the shade of the crowns, and are picked with the rest.
	var shade := {}
	var open_moss := false
	var picked := Vector3i(-1, -1, -1)
	for col: Vector2i in w.trees:
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				var x := col.x + dx
				var z := col.y + dz
				var c := Vector3i(x, w.surface_y(x, z) - 1, z)
				for id in Grass.plants_on(w, c.x, c.y, c.z):
					if id in [Plants.MOSS, Plants.MUSHROOMS, Plants.GLOW]:
						shade[id] = true
						open_moss = open_moss or w.leaf_col(x, z) == 0
						if picked.y < 0:
							picked = c
	_check(shade.has(Plants.MOSS) and (shade.has(Plants.MUSHROOMS) or shade.has(Plants.GLOW)) and not open_moss,
		"moss and mushrooms grow under the crowns, not in the open: %s" % [shade.keys()])
	if picked.y >= 0:
		w.set_turf(picked, "")
		_check(not Grass.plants_on(w, picked.x, picked.y, picked.z).any(func(id) -> bool: return Plants.BY_ID[id].pick),
			"picked moss and mushrooms are gone until spring")
		w.set_turf(picked, null)


## The mods' own plants (`kind: custom`): their frames follow the engine's in one row,
## each grows where its record says (the fern in the shade of crowns, the nettle in the
## open, the cranberry by the water) and is a plant with what it gives like the others.
func _test_custom_plants() -> void:
	var frames := 0
	var ordered := true
	for c in Plants.CUSTOM:
		ordered = ordered and c.first == frames and Grass.plant_of(Grass.CUSTOM + c.first) == c.id \
			and Grass.plant_of(Grass.CUSTOM + c.first + c.frames - 1) == c.id
		frames += c.frames
	_check(Plants.CUSTOM.size() >= 3 and ordered and Plants.custom_frames() == frames and Grass.plant_of(Grass.CUSTOM + frames) == "",
		"custom plants take the kinds after the engine's, a kind per frame")
	var by_where := {}
	for c in Plants.CUSTOM:
		if not by_where.has(c.grows):
			by_where[c.grows] = c.id
	_check(by_where.has("shade") and by_where.has("meadow") and by_where.has("bank"), "the test plants grow in the shade, the open and on the banks")
	var strips := _woods()
	var w: WorldData = strips.world
	var seen := {}
	var wrong := {}
	for key: Vector2i in strips.keys:
		for dz in 16:
			for dx in 16:
				var x := key.x * 16 + dx
				var z := key.y * 16 + dz
				var y := w.surface_y(x, z) - 1
				var shaded := w.leaf_col(x, z) != 0
				for id in Grass.plants_on(w, x, y, z):
					var c: Dictionary = Plants.BY_ID.get(id, {})
					if c.get("kind", "") != Plants.KINDS.CUSTOM:
						continue
					seen[id] = true
					if (c.grows == "shade" and not shaded) or (c.grows == "meadow" and shaded):
						wrong[id] = true
	_check(seen.has(by_where.shade) and seen.has(by_where.meadow) and wrong.is_empty(),
		"the fern grows under the crowns and the nettle in the open, not the other way: %s, wrong %s" % [seen.keys(), wrong.keys()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var got := Plants.harvest([by_where.meadow, by_where.meadow, by_where.meadow], rng)
	_check(not got.is_empty(), "a custom plant gives what its record says")
