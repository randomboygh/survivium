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
	"corners": {"time": 0.42, "season": 1, "corners": true},
	"corners-winter": {"time": 0.45, "season": 3, "corners": true},
	"lab": {"time": 0.42, "season": 1, "lab": true},
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
		if shot.get("corners", false):
			main.player.position = _corners(main.world, main.player.position)
		if shot.get("lab", false):
			_lab(main.world, Vector3i(main.player.position))
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


## The dry spot near `from` with the most cut or filled corners on the cliffs around it.
func _corners(w, from: Vector3) -> Vector3:
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 40, int(from.z) + 41, 4):
		for x in range(int(from.x) - 40, int(from.x) + 41, 4):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-5, 6):
				for dx in range(-8, 9):
					var top: int = w.surface_y(x + dx, z + dz)
					for ty in range(maxi(0, top - 4), top):
						if w.corner_cuts(x + dx, ty, z + dz) != 0:
							n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best


## Replaces the ground around `at` with test shapes for corners: a diagonal creek, a
## stone plateau with outer and inner corners, a one-wide channel with a bend.
func _lab(w, at: Vector3i) -> void:
	var h := at.y
	for z in range(at.z - 9, at.z + 10):
		for x in range(at.x - 14, at.x + 15):
			var lx := x - at.x
			var lz := z - at.z
			var top := h
			var water := -1
			if lx - lz >= 4 and lx - lz <= 6:
				top = h - 4
				water = h - 3
			elif lx + lz >= 9 and lx + lz <= 10 and lx < 10:
				top = h - 2
				water = h - 2
			elif lx >= -12 and lx <= -6 and lz >= -7 and lz <= -2 and not (lx >= -8 and lz <= -5):
				top = h + 2
			elif lz == 4 and lx >= -12 and lx <= -2 or lx == -2 and lz >= 4 and lz <= 8:
				top = h - 2
			for y in w.size_y:
				var m := Mat.AIR
				if y < top:
					m = Mat.STONE if top > h or y < top - 2 else Mat.DIRT
					if y == top - 1 and top <= h:
						m = Mat.GRASS
				elif y <= water:
					m = Mat.WATER
				w.set_cell(x, y, z, m)
				w.natural[(y * w.size_z + z) * w.size_x + x] = w.WILD
	for z in range(at.z - 11, at.z + 12, 4):
		for x in range(at.x - 16, at.x + 17, 4):
			main._on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5)
