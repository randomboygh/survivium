extends SceneTree
## Times generating a world: the coarse layout, then each stage of the chunks around
## the spawn and of the whole map. godot --headless --path . --script res://tools/bench_gen.gd [size]

const WorldGen := preload("res://src/shared/world_gen.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var size: int = int(args[0]) if args.size() > 0 else 512
	var t0 := Time.get_ticks_usec()
	var gen := WorldGen.new(20261018, size, 48, size)
	var t1 := Time.get_ticks_usec()
	print("coarse layout of %dx%d: %d ms, %d rivers, spawn %s" % [size, size, (t1 - t0) / 1000, gen.rivers.size(), gen.spawn_guess])
	# The chunks around the spawn, stage by stage, as the loading screen makes them.
	var home := Vector2i(gen.spawn_guess.x / WorldGen.CHUNK, gen.spawn_guess.z / WorldGen.CHUNK)
	var times := [0, 0, 0]
	var counts := [0, 0, 0]
	var worst := [0, 0, 0]
	for stage: int in [WorldGen.TERRAIN, WorldGen.PLANTED, WorldGen.SHAPED]:
		var reach: int = 7 - stage
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var key := home + Vector2i(dx, dz)
				if not gen.in_map(key):
					continue
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
	gen.generate_all()
	var t3 := Time.get_ticks_usec()
	var w = gen.world
	var slopes := 0
	var corners := 0
	for col in w.size_x * w.size_z:
		slopes += 1 if w.sloped_cols[col] != 0 else 0
		corners += 1 if w.corner_cols[col] != 0 else 0
	print("whole map %d ms; columns with slopes %d, with corners %d, trees %d, bushes %d" % [
		(t3 - t2) / 1000, slopes, corners, w.trees.size(), w.bushes.size()])
	quit()
