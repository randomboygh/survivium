extends SceneTree
## Times what a turn of the camera costs at once: fitting the culling boxes of every
## chunk shown to the views on the way (CameraRig._aim), and the frames of the glide.
## godot --headless --path . --script res://tools/bench_turn.gd
## A phone runs the game's code about ten times slower than these numbers.

var main


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_setup = true
	root.add_child(main)
	_run()


func _run() -> void:
	while not main.ready_to_play:
		await process_frame
	for i in 900:
		await process_frame
	var nodes := 0
	for parts: Array in main.chunks.chunk_nodes.values():
		nodes += parts.size()
	var t := Time.get_ticks_usec()
	main.view.turn_by(1)
	var aim := Time.get_ticks_usec() - t
	t = Time.get_ticks_usec()
	main.view.turn_by(2)
	var aim3 := Time.get_ticks_usec() - t
	print("chunks %d, nodes %d: one step %d us, three steps on the way %d us" % [
		main.chunks.chunk_nodes.size(), nodes, aim, aim3])
	main.view.reset_turn()
	quit()
