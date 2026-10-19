extends SceneTree
## Times building the meshes and plants of the whole start world, stage by stage:
## godot --headless --path . --script res://tools/bench_mesh.gd

const WorldGen := preload("res://src/shared/world_gen.gd")
const ChunkMesher := preload("res://src/client/chunk_mesher.gd")
const Foliage := preload("res://src/client/foliage.gd")


func _initialize() -> void:
	var w := WorldGen.generate(20261018, 128, 20, 128)
	var t := [0, 0, 0, 0]
	var t0 := Time.get_ticks_usec()
	for cz in 8:
		for cx in 8:
			var x0 := cx * 16 - 2
			var z0 := cz * 16 - 2
			var a := Time.get_ticks_usec()
			var c := ChunkMesher.padded(w, x0, z0, x0 + 20, z0 + 20)
			var b := Time.get_ticks_usec()
			var d := Time.get_ticks_usec()
			ChunkMesher.shapes_and_corners(w, c, x0, z0, x0 + 20, z0 + 20)
			var e := Time.get_ticks_usec()
			t[0] += b - a
			t[1] += d - b
			t[2] += e - d
	var t1 := Time.get_ticks_usec()
	for cz in 8:
		for cx in 8:
			ChunkMesher.build_chunk(w, cx * 16, cz * 16, 16)
	var t2 := Time.get_ticks_usec()
	for cz in 8:
		for cx in 8:
			Foliage.build_chunk(w, cx * 16, cz * 16, 16)
	var t3 := Time.get_ticks_usec()
	print("padded %d, slopes %d, plan %d ms; meshes %d ms, foliage %d ms" % [t[0] / 1000, t[1] / 1000, t[2] / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000])
	quit()
