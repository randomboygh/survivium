extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [name ...]
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png.

const Mat := preload("res://src/shared/materials.gd")

const SHOTS := {
	"day": {"time": 0.45, "season": 1},
	"morning": {"time": 0.29, "season": 0},
	"evening": {"time": 0.72, "season": 1},
	"night": {"time": 0.95, "season": 1},
	"rain": {"time": 0.5, "season": 1, "rain": true},
	"autumn": {"time": 0.42, "season": 2},
	"winter": {"time": 0.45, "season": 3, "rain": true},
	"cave": {"time": 0.45, "season": 1, "cut": -2},
	"shore": {"time": 0.4, "season": 1, "shore": true},
	"slopes": {"time": 0.42, "season": 1, "slopes": true},
	"forest": {"time": 0.42, "season": 1, "forest": true},
	"trees": {"time": 0.42, "season": 1, "trees": true},
	"forest-autumn": {"time": 0.42, "season": 2, "forest": true},
	"forest-winter": {"time": 0.45, "season": 3, "forest": true},
	"forest-evening": {"time": 0.7, "season": 1, "forest": true},
}

var main: Node
var out_dir := "user://shots"
var names: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	names = args.slice(1) if args.size() > 1 else SHOTS.keys()
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _run() -> void:
	while not main.ready_to_play:
		await process_frame
	var spawn: Vector3 = main.player.position
	for shot_name in names:
		main.player.position = spawn
		var shot: Dictionary = SHOTS[shot_name]
		main.time_of_day = shot.time
		main.time_speed = 0.0
		main.season = shot.season
		main.raining = shot.get("rain", false)
		main.show_help = false
		main.manual_level = -1
		if shot.has("cut"):
			main.manual_level = main.player.level() + shot.cut
		if shot.get("shore", false):
			main.player.position = _shore(main.world, main.player.position)
		if shot.get("slopes", false):
			main.player.position = _hills(main.world, main.player.position)
		if shot.get("trees", false):
			main.player.position = _lone_trees(main.world, main.player.position)
		if shot.get("forest", false):
			main.player.position = _forest(main.world, main.player.position)
		# Let snow, wetness, tints and particles settle.
		for i in 90:
			await process_frame
			main.snow = 1.0 if main.season == 3 else 0.0
			main.wet = 1.0 if main.raining and main.season != 3 else 0.0
			main.foliage = main.FOLIAGE[main.season]
			main.grass = main.GRASS[main.season]
			main.leaf_amount = main.LEAF_AMOUNT[main.season]
		var img := root.get_texture().get_image()
		print("player at ", main.player.position)
		img.save_png(out_dir.path_join(shot_name + ".png"))
		print("saved ", shot_name)
	quit()


## Nearest dry cell next to open water, to look at the shore.
func _shore(w, from: Vector3) -> Vector3:
	var best := from
	var best_d := INF
	for z in range(1, w.size_z - 1):
		for x in range(1, w.size_x - 1):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y > w.sea_level + 2:
				continue
			# Open water south of it, not a creek in a ravine.
			if w.get_cell(x, w.sea_level, z + 3) != Mat.WATER or w.get_cell(x, w.sea_level, z + 9) != Mat.WATER:
				continue
			var p := Vector3(x + 0.5, y, z + 0.5)
			if p.distance_to(from) < best_d:
				best_d = p.distance_to(from)
				best = p
	return best


## The spot near `from` with the most sloping ground around it.
func _hills(w, from: Vector3) -> Vector3:
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 24, int(from.z) + 25, 3):
		for x in range(int(from.x) - 24, int(from.x) + 25, 3):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-5, 6):
				for dx in range(-7, 8):
					var top: int = w.surface_y(x + dx, z + dz) - 1
					if top >= 0 and w.slope_mask(x + dx, top, z + dz) != w.FULL:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best


## The open spot near `from` with the most trees around it.
func _forest(w, from: Vector3) -> Vector3:
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 40, int(from.z) + 41, 3):
		for x in range(int(from.x) - 40, int(from.x) + 41, 3):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-8, 9):
				for dx in range(-12, 13):
					var top: int = w.surface_y(x + dx, z + dz)
					if top > 0 and w.get_cell(x + dx, top - 1, z + dz) == Mat.LEAVES:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best


## The open spot near `from` with the most trees standing apart from the others.
func _lone_trees(w, from: Vector3) -> Vector3:
	var trunks: Array[Vector2i] = []
	for z in range(1, w.size_z - 1):
		for x in range(1, w.size_x - 1):
			for y in range(w.surface_y(x, z) - 1, 0, -1):
				if w.get_cell(x, y, z) == Mat.LOG and w.get_cell(x, y - 1, z) != Mat.LOG:
					trunks.append(Vector2i(x, z))
					break
	var lone: Array[Vector2i] = []
	for t in trunks:
		var alone := true
		for o in trunks:
			if o != t and absi(o.x - t.x) <= 3 and absi(o.y - t.y) <= 3:
				alone = false
				break
		if alone:
			lone.append(t)
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 48, int(from.z) + 49, 2):
		for x in range(int(from.x) - 48, int(from.x) + 49, 2):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for t in lone:
				if absi(t.x - x) <= 12 and absi(t.y - z) <= 7:
					n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best
