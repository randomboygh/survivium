extends "res://tests/unit/test_case.gd"
## Saving and loading a world and its chunks.


func run() -> void:
	_test_save()


func _test_save() -> void:
	var a := WorldGen.new(42)
	var at := a.find_place("forest", Vector2i(a.spawn_guess.x, a.spawn_guess.z))
	var home := WorldData.chunk_key(at.x, at.y)
	var area: Array[Vector2i] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			area.append(home + Vector2i(dx, dz))
	for k in area:
		_ensure_stage(a, k, WorldGen.SHAPED)
	var w := a.world
	_check(w.unsaved.is_empty(), "the generator's writes are not changes to save")
	var trunks: Array = w.tree_chunks.get(home, {}).keys()
	_check(not trunks.is_empty(), "the forest chunk has trees")
	if trunks.is_empty():
		return
	var trunk: Vector2i = trunks[0]
	var foot := w.surface_y(trunk.x, trunk.y)
	for y in range(w.size_y - 1, 0, -1):
		if w.get_cell(trunk.x, y, trunk.y) == Mat.LOG and w.get_cell(trunk.x, y - 1, trunk.y) != Mat.LOG:
			foot = y
			break
	Trees.fell(w, Vector3i(trunk.x, foot + 1, trunk.y), Vector2(1.0, 0.0))
	var x0 := home.x * WorldData.CHUNK
	var z0 := home.y * WorldData.CHUNK
	var top := w.surface_y(x0 + 1, z0 + 1)
	for y in range(top - 3, top):
		w.set_cell(x0 + 1, y, z0 + 1, Mat.AIR)
	var stone := Vector3i(x0 + 14, w.surface_y(x0 + 14, z0 + 8), z0 + 8)
	w.set_cell(stone.x, stone.y, stone.z, Mat.STONE)
	var bushes: Array = w.bush_chunks.get(home, {}).keys()
	if not bushes.is_empty():
		w.remove_bush(bushes[0])
	w.tree_twigs[trunk] = 2
	var lawn := Vector3i(x0 + 8, w.surface_y(x0 + 8, z0 + 3) - 1, z0 + 3)
	w.set_turf(lawn, "")
	# Grass cut off a natural slope leaves dirt of the same shape.
	var cut := Vector3i(-1, -1, -1)
	for z in range(z0, z0 + WorldData.CHUNK):
		for x in range(x0, x0 + WorldData.CHUNK):
			var y := w.surface_y(x, z) - 1
			if cut.y < 0 and w.get_cell(x, y, z) == Mat.GRASS and w.is_natural(x, y, z) and w.slope_mask(x, y, z) != WorldData.FULL:
				cut = Vector3i(x, y, z)
	if cut.y >= 0:
		var mask := w.slope_mask(cut.x, cut.y, cut.z)
		w.set_material(cut.x, cut.y, cut.z, Mat.DIRT)
		w.refresh_shapes()
		_check(w.get_cell(cut.x, cut.y, cut.z) == Mat.DIRT and w.slope_mask(cut.x, cut.y, cut.z) == mask, "cut grass keeps its slope")
	_check(w.unsaved.has(home) and not a.forget(home), "a changed chunk is kept and waits to be saved")
	var store := WorldStore.new("user://test_saves/save")
	store.erase()
	store = WorldStore.new("user://test_saves/save")
	for k: Vector2i in w.unsaved:
		_check(store.write_chunk(k, a.pack(k)), "chunk %s is written" % k)
	var written := w.unsaved.size()
	w.unsaved.clear()
	var again := WorldStore.new("user://test_saves/save")
	_check(again.chunk_count() == written, "the save lists its chunks")
	# A new run, the chunks made from the far corner: the changed chunk comes back
	# after some of its neighbours have their terrain.
	var b := WorldGen.new(42)
	b.saved = again
	for i in range(area.size() - 1, -1, -1):
		_ensure_stage(b, area[i], WorldGen.SHAPED)
	_check(_same_cells(b.world, w, area) and _same_view(b, b.world, w, area), "changed chunks come back from the save")
	# Only within the area: a chunk that comes back from the save is SHAPED at once, so
	# the test plants nothing beyond it, while the first run planted the ring around.
	_check(_within(b.world.trees, area) == _within(w.trees, area) and _within(b.world.bushes, area) == _within(w.bushes, area)
		and _within(b.world.drops, area, true) == _within(w.drops, area, true) and _within(b.world.tree_twigs, area) == _within(w.tree_twigs, area)
		and b.world.turf_at(lawn) == "", "with their trees, bushes, what was gathered and cut and what lies on the ground")
	_check(b.world.unsaved.is_empty() and b.world.chunks[home].edited, "and stay kept without a new save")
	# A neighbour dropped and made again regrows the crowns of the saved chunk's trees.
	var remade := 0
	for side in area:
		if not b.world.chunks[side].edited:
			b.forget(side)
			_ensure_stage(b, side, WorldGen.SHAPED)
			remade += 1
	_check(remade > 0 and _same_cells(b.world, w, area), "neighbours made again get the saved chunk's crowns")
	# A save made when the materials were numbered in another order (its world.json's
	# `materials`): read through Mat.remap, its stone comes back as stone by name. Here
	# the save's list says dirt where stone is and stone where dirt is.
	var swapped := Mat.IDS.duplicate()
	swapped[Mat.DIRT] = Mat.IDS[Mat.STONE]
	swapped[Mat.STONE] = Mat.IDS[Mat.DIRT]
	var c := WorldGen.new(42)
	c.saved = again
	c.material_map = Mat.remap(swapped)
	for i in range(area.size() - 1, -1, -1):
		_ensure_stage(c, area[i], WorldGen.SHAPED)
	_check(b.world.get_cell(stone.x, stone.y, stone.z) == Mat.STONE and c.world.get_cell(stone.x, stone.y, stone.z) == Mat.DIRT,
		"a saved chunk is read by the material order of its save (Mat.remap)")
	_check(WorldStore.materials_of({"content": 4}) == WorldStore.OLD_MATERIALS and WorldStore.materials_of({"content": 9}).is_empty()
		and WorldStore.materials_of({"content": 2, "materials": ["core:air"]}) == PackedStringArray(["core:air"]),
		"an old save without its list numbers by the core's first thirteen; a newer one by its own list")
	# The rest of the files.
	_check(store.write_json("world.json", {"seed": 42.0}) and store.exists() and store.read_json("world.json").seed == 42.0,
		"world.json is written and read")
	_check(WorldStore.world_dir(42, {"size": 2, "water": 0}) == WorldStore.root + "/42-20111", "a world's directory names its seed and settings")
	_check(WorldStore.world_dir(42, {"caves": 0}) == WorldStore.root + "/42-111110", "and its caves when they are not as before the setting")
	_check(WorldStore.world_dir(42, {"caves": 0, "relief": 1}) == WorldStore.root + "/42-111110r1", "and its relief")
	_check(WorldStore.world_dir(42, {"caves": 0, "relief": 1, "climate": 1}) == WorldStore.root + "/42-111110r1c1", "and its climate")
	store.erase()
	_check(not DirAccess.dir_exists_absolute("user://test_saves/save"), "a save is erased")


## The entries of `d` (keyed by a column or a cell, or by a chunk key when `by_chunk`)
## that lie in the chunks `area`.
func _within(d: Dictionary, area: Array, by_chunk := false) -> Dictionary:
	var out := {}
	for k in d:
		var key: Vector2i = k if by_chunk else WorldData.chunk_key(k.x, k.z if k is Vector3i else k.y)
		if key in area:
			out[k] = d[k]
	return out
