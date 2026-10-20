extends SceneTree
## Times building the meshes and plants of the whole start world, stage by stage:
## godot --headless --path . --script res://tools/bench_mesh.gd

const WorldGen := preload("res://src/shared/world_gen.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const Foliage := preload("res://src/client/foliage.gd")
const CHUNK := 16


func _initialize() -> void:
	var t0 := Time.get_ticks_usec()
	var w := WorldGen.generate(20261018, 256, 48, 256)
	var t1 := Time.get_ticks_usec()
	var chunks_x := w.size_x / CHUNK
	var chunks_z := w.size_z / CHUNK
	var verts := 0
	for cz in chunks_z:
		for cx in chunks_x:
			for mesh in ChunkMesher.build_chunk(w, cx * CHUNK, cz * CHUNK, CHUNK):
				if mesh != null:
					verts += mesh.surface_get_array_len(0)
	var t2 := Time.get_ticks_usec()
	for cz in chunks_z:
		for cx in chunks_x:
			Foliage.build_chunk(w, cx * CHUNK, cz * CHUNK, CHUNK)
	var t3 := Time.get_ticks_usec()
	print("generate %d ms, meshes %d ms (%d vertices), foliage %d ms" % [
		(t1 - t0) / 1000, (t2 - t1) / 1000, verts, (t3 - t2) / 1000])
	quit()
