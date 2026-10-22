extends SceneTree
## Times what a single edit, a cut-level change and a roof touch cost, as the game does
## them, so freezes can be chased without a phone:
## godot --headless --path . --script res://tools/bench_edit.gd

const WorldGen := preload("res://src/shared/world/world_gen.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")
const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const RoofMap := preload("res://src/client/world/roof_map.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const CHUNK := 16


func _initialize() -> void:
	var gen := WorldGen.new(20261018)
	var x: int = gen.spawn_guess.x
	var z: int = gen.spawn_guess.z
	var home := Vector2i(x >> 4, z >> 4)
	gen.generate_area(home - Vector2i(8, 8), home + Vector2i(8, 8))
	var w := gen.world
	var y := w.surface_y(x, z)
	var cx0 := (x >> 4) * CHUNK
	var cz0 := (z >> 4) * CHUNK
	# Warm up (shapes, tables).
	ChunkMesher.build_chunk(w, cx0, cz0, CHUNK)
	Foliage.build_chunk(w, cx0, cz0, CHUNK)
	var t := Time.get_ticks_usec()
	for i in 5:
		ChunkMesher.build_chunk(w, cx0, cz0, CHUNK)
	print("one chunk mesh: %.1f ms" % ((Time.get_ticks_usec() - t) / 5000.0))
	t = Time.get_ticks_usec()
	for i in 5:
		Foliage.build_chunk(w, cx0, cz0, CHUNK)
	print("one chunk foliage: %.1f ms" % ((Time.get_ticks_usec() - t) / 5000.0))
	# The longest single column of each, the smallest step the game can take in a frame.
	var worst_mesh := 0
	var worst_plants := 0
	var job := ChunkMesher.start(w, cx0, cz0, CHUNK)
	var plants := Foliage.start(w, cx0, cz0, CHUNK)
	for i in CHUNK * CHUNK:
		t = Time.get_ticks_usec()
		ChunkMesher.step(job, 1)
		worst_mesh = maxi(worst_mesh, Time.get_ticks_usec() - t)
		t = Time.get_ticks_usec()
		Foliage.step(plants, 1)
		worst_plants = maxi(worst_plants, Time.get_ticks_usec() - t)
	print("longest column: mesh %.2f ms, foliage %.2f ms" % [worst_mesh / 1000.0, worst_plants / 1000.0])
	for level in [y - 1, y + 4, 10]:
		t = Time.get_ticks_usec()
		var n := 0
		var verts := 0
		for cz in range(home.y - 6, home.y + 7):
			for cx in range(home.x - 6, home.x + 7):
				var cap := ChunkMesher.build_cap(w, level, cx * CHUNK, cz * CHUNK, CHUNK)
				verts += 0 if cap == null else cap.surface_get_array_len(0)
				n += 1
		print("cap at level %d: %d chunks around the player %d ms (%d verts)" % [
			level, n, (Time.get_ticks_usec() - t) / 1000, verts])
	var roof := RoofMap.new()
	t = Time.get_ticks_usec()
	roof.build(w)
	print("roof build: %d ms" % ((Time.get_ticks_usec() - t) / 1000))
	# A dig at a chunk corner touches four chunks.
	var cx := cx0
	var cz := cz0
	t = Time.get_ticks_usec()
	w.set_cell(cx, y - 1, cz, Mat.AIR)
	roof.touch(w, Vector3i(cx, y - 1, cz))
	var t1 := Time.get_ticks_usec()
	var keys := {}
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			keys[Vector2i(floori((cx + dx) / float(CHUNK)), floori((cz + dz) / float(CHUNK)))] = true
	for key: Vector2i in keys:
		ChunkMesher.build_chunk(w, key.x * CHUNK, key.y * CHUNK, CHUNK)
		Foliage.build_chunk(w, key.x * CHUNK, key.y * CHUNK, CHUNK)
	print("dig at a chunk corner: set+roof %.1f ms, %d chunks remeshed %d ms" % [
		(t1 - t) / 1000.0, keys.size(), (Time.get_ticks_usec() - t1) / 1000])
	quit()

