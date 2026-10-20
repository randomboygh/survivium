extends SceneTree
## Times generating a world: finding the spawn, then each stage of the chunks around
## it, then a square of `size` chunks at once.
## godot --headless --path . --script res://tools/bench_gen.gd [size]

const WorldGen := preload("res://src/shared/world_gen.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var size: int = int(args[0]) if args.size() > 0 else 16
	var t0 := Time.get_ticks_usec()
	var gen := WorldGen.new(20261018)
	var t1 := Time.get_ticks_usec()
	print("spawn %s found in %d ms" % [gen.spawn_guess, (t1 - t0) / 1000])
	# The chunks around the spawn, stage by stage, as the loading screen makes them.
	var home := Vector2i(gen.spawn_guess.x >> 4, gen.spawn_guess.z >> 4)
	var times := [0, 0, 0]
	var counts := [0, 0, 0]
	var worst := [0, 0, 0]
	for stage: int in [WorldGen.TERRAIN, WorldGen.PLANTED, WorldGen.SHAPED]:
		var reach: int = 7 - stage
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var key := home + Vector2i(dx, dz)
				var job := gen.start(key, stage)
				var t := Time.get_ticks_usec()
				while not job.done:
					var ts := Time.get_ticks_usec()
					gen.step(job, 1)
					worst[stage - 1] = maxi(worst[stage - 1], Time.get_ticks_usec() - ts)
				times[stage - 1] += Time.get_ticks_usec() - t
				counts[stage - 1] += 1
	for s in 3:
		print("stage %d: %d chunks, %.2f ms each, longest step %.2f ms" % [s + 1, counts[s], times[s] / 1000.0 / maxi(1, counts[s]), worst[s] / 1000.0])
	var t2 := Time.get_ticks_usec()
	gen.generate_area(home + Vector2i(8, 8), home + Vector2i(8 + size, 8 + size))
	var t3 := Time.get_ticks_usec()
	var w = gen.world
	var slopes := 0
	var corners := 0
	for c in w.chunks.values():
		for col in WorldGen.CHUNK * WorldGen.CHUNK:
			slopes += 1 if c.sloped[col] != 0 else 0
			corners += 1 if c.corner[col] != 0 else 0
	print("%dx%d chunks %d ms; columns with slopes %d, with corners %d, trees %d, bushes %d" % [
		size, size, (t3 - t2) / 1000, slopes, corners, w.trees.size(), w.bushes.size()])
	quit()
