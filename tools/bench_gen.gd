extends SceneTree
## Times generating the start world: godot --headless --path . --script res://tools/bench_gen.gd

const WorldGen := preload("res://src/shared/world_gen.gd")


func _initialize() -> void:
	var t0 := Time.get_ticks_usec()
	var w := WorldGen.generate(20261018)
	var t1 := Time.get_ticks_usec()
	w.mark_all_dirty()
	w.refresh_shapes()
	var t2 := Time.get_ticks_usec()
	var slopes := 0
	var corners := 0
	for col in w.size_x * w.size_z:
		slopes += 1 if w.sloped_cols[col] != 0 else 0
		corners += 1 if w.corner_cols[col] != 0 else 0
	print("generate %d ms (shapes alone %d ms); columns with slopes %d, with corners %d" % [
		(t1 - t0) / 1000, (t2 - t1) / 1000, slopes, corners])
	quit()
