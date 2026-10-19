extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [name ...]
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png. The spots are
## searched in cells (half a world unit); the player stands in world units.

const Mat := preload("res://src/shared/materials.gd")
const CELL := 0.5

const SHOTS := {
	"day": {"time": 0.45, "season": 1},
	"morning": {"time": 0.29, "season": 0},
	"evening": {"time": 0.72, "season": 1},
	"night": {"time": 0.95, "season": 1},
	"rain": {"time": 0.5, "season": 1, "rain": true},
	"autumn": {"time": 0.42, "season": 2},
	"winter": {"time": 0.45, "season": 3, "rain": true},
	"cave": {"time": 0.45, "season": 1, "cut": -4},
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
			_lab(main.world, Vector3i((main.player.position / CELL).floor()))
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
func _shore(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_d := INF
	for z in range(1, w.size_z - 1):
		for x in range(1, w.size_x - 1):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y > w.sea_level + 2:
				continue
			# Open water south of it, not a creek in a ravine.
			if w.get_cell(x, w.sea_level, z + 6) != Mat.WATER or w.get_cell(x, w.sea_level, z + 18) != Mat.WATER:
				continue
			var p := Vector3(x + 0.5, y, z + 0.5)
			if p.distance_to(from) < best_d:
				best_d = p.distance_to(from)
				best = p
	return best * CELL


## The spot near `at` with the most sloping ground around it.
func _hills(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 48, int(from.z) + 49, 6):
		for x in range(int(from.x) - 48, int(from.x) + 49, 6):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-10, 11, 2):
				for dx in range(-14, 15, 2):
					var top: int = w.surface_y(x + dx, z + dz) - 1
					if top >= 0 and w.slope_mask(x + dx, top, z + dz) != w.FULL:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## The dry spot near `at` with the most cut or filled corners on the cliffs around it.
func _corners(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 80, int(from.z) + 81, 8):
		for x in range(int(from.x) - 80, int(from.x) + 81, 8):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-10, 11, 2):
				for dx in range(-16, 17, 2):
					var top: int = w.surface_y(x + dx, z + dz)
					for ty in range(maxi(0, top - 8), top):
						if w.corner_cuts(x + dx, ty, z + dz) != 0:
							n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## Replaces the ground around cell `at` with test shapes for corners: a diagonal creek,
## a stone plateau with outer and inner corners, a channel two cells wide with a bend.
func _lab(w, at: Vector3i) -> void:
	var h := at.y
	for z in range(at.z - 18, at.z + 20):
		for x in range(at.x - 28, at.x + 30):
			var lx := x - at.x
			var lz := z - at.z
			var top := h
			var water := -1
			if lx - lz >= 8 and lx - lz <= 13:
				top = h - 8
				water = h - 5
			elif lx + lz >= 18 and lx + lz <= 21 and lx < 20:
				top = h - 4
				water = h - 3
			elif lx >= -24 and lx <= -11 and lz >= -14 and lz <= -3 and not (lx >= -16 and lz <= -9):
				top = h + 4
			elif (lz == 8 or lz == 9) and lx >= -24 and lx <= -3 or (lx == -4 or lx == -3) and lz >= 8 and lz <= 17:
				top = h - 4
			for y in w.size_y:
				var m := Mat.AIR
				if y < top:
					m = Mat.STONE if top > h or y < top - 4 else Mat.DIRT
					if y == top - 1 and top <= h:
						m = Mat.GRASS
				elif y <= water:
					m = Mat.WATER
				w.set_cell(x, y, z, m)
				w.set_natural(x, y, z, true)
	for z in range(at.z - 22, at.z + 25, 8):
		for x in range(at.x - 32, at.x + 35, 8):
			main._on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5) * CELL
