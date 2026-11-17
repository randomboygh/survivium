extends SceneTree
## Times building the meshes and plants of 16 by 16 chunks around the spawn:
## godot --headless --path . --script res://tools/bench_mesh.gd [-- --sharp]
## (`--sharp`: with the setting «rounded terrain» off, ChunkMesher.rounded).

const WorldGen := preload("res://src/shared/world/world_gen.gd")
const ChunkMesher := preload("res://src/client/world/chunk_mesher.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const CHUNK := 16


func _initialize() -> void:
	ChunkMesher.rounded = not OS.get_cmdline_user_args().has("--sharp")
	var t0 := Time.get_ticks_usec()
	var gen := WorldGen.new(20261018)
	var home := Vector2i(gen.spawn_guess.x >> 4, gen.spawn_guess.z >> 4) - Vector2i(8, 8)
	gen.generate_area(home, home + Vector2i(16, 16))
	var w := gen.world
	var t1 := Time.get_ticks_usec()
	var verts := 0
	for cz in range(home.y, home.y + 16):
		for cx in range(home.x, home.x + 16):
			for mesh in ChunkMesher.build_chunk(w, cx * CHUNK, cz * CHUNK, CHUNK):
				if mesh != null:
					verts += mesh.surface_get_array_len(0)
	var t2 := Time.get_ticks_usec()
	for cz in range(home.y, home.y + 16):
		for cx in range(home.x, home.x + 16):
			Foliage.build_chunk(w, cx * CHUNK, cz * CHUNK, CHUNK)
	var t3 := Time.get_ticks_usec()
	# Again, with what the meshers keep between chunks made (as after a while of play).
	for cz in range(home.y, home.y + 16):
		for cx in range(home.x, home.x + 16):
			ChunkMesher.build_chunk(w, cx * CHUNK, cz * CHUNK, CHUNK)
	var t4 := Time.get_ticks_usec()
	print("generate %d ms, meshes %d ms (%d vertices), again %d ms, foliage %d ms" % [
		(t1 - t0) / 1000, (t2 - t1) / 1000, verts, (t4 - t3) / 1000, (t3 - t2) / 1000])
	quit()
