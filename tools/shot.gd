extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [name ...]
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png. The spots are
## searched in cells (half a world unit); the player stands in world units.

const Mat := preload("res://src/shared/materials.gd")
const Trees := preload("res://src/shared/trees.gd")
const Foliage := preload("res://src/client/foliage.gd")
const Bushes := preload("res://src/shared/bushes.gd")
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
	"underground": {"time": 0.45, "season": 1, "underground": true},
	"hut": {"time": 0.42, "season": 1, "hut": true},
	"shore": {"time": 0.4, "season": 1, "shore": true},
	"slopes": {"time": 0.42, "season": 1, "slopes": true},
	"corners": {"time": 0.42, "season": 1, "corners": true},
	"corners-winter": {"time": 0.45, "season": 3, "corners": true},
	"lab": {"time": 0.42, "season": 1, "lab": true},
	"trees": {"time": 0.42, "season": 1, "trees": true},
	"forest": {"time": 0.42, "season": 1, "forest": true},
	"forest-autumn": {"time": 0.42, "season": 2, "forest": true},
	"forest-winter": {"time": 0.45, "season": 3, "forest": true},
	"grove": {"time": 0.42, "season": 1, "grove": true},
	"grove-autumn": {"time": 0.42, "season": 2, "grove": true},
	"grove-winter": {"time": 0.45, "season": 3, "grove": true},
	"grove-spring": {"time": 0.42, "season": 0, "grove": true},
	# The interface: with a mouse, on a touch screen, with the statistics and the menu.
	"ui": {"time": 0.45, "season": 1, "stats": true},
	"ui-touch": {"time": 0.45, "season": 1, "touch": true, "toast": true},
	"ui-menu": {"time": 0.45, "season": 1, "touch": true, "menu": true},
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
		if shot.get("hut", false):
			main.player.position = _hut(main.world, main.player.position)
		if shot.get("underground", false):
			main.player.position = _cave(main.world, main.player.position)
		if shot.get("corners", false):
			main.player.position = _corners(main.world, main.player.position)
		if shot.get("trees", false):
			main.player.position = _lone_trees(main.world, main.player.position)
		if shot.get("forest", false):
			main.player.position = _forest(main.world, main.player.position)
		if shot.get("grove", false):
			# Away from the campfire by the spawn, which melts the snow around it.
			_grove(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(0, 0, -44))
		main._set_touch(shot.get("touch", false))
		main.hud.perf.visible = shot.get("stats", false)
		main.hud.show_keys(shot_name == "ui")
		if shot.get("lab", false):
			_lab(main.world, Vector3i((main.player.position / CELL).floor()))
		# Let snow, wetness, tints and particles settle.
		for i in 90:
			await process_frame
			main.snow = 1.0 if main.season == 3 else 0.0
			main.wet = 1.0 if main.raining and main.season != 3 else 0.0
			main.foliage = main.FOLIAGE[main.season]
			main.grass = main.GRASS[main.season]
			main.berry_amount = main.BERRY_AMOUNT[main.season]
			main.leaf_amount = main.LEAF_AMOUNT[main.season]
		# Messages fade after a few seconds, longer than the settling above takes here.
		if shot.get("toast", false):
			main.hud.toast("Наступило лето")
			await process_frame
			await process_frame
		if shot.get("menu", false):
			main.hud.toggle_menu()
			await process_frame
			await process_frame
		var img := root.get_texture().get_image()
		print("player at ", main.player.position)
		img.save_png(out_dir.path_join(shot_name + ".png"))
		print("saved ", shot_name)
		if shot.get("menu", false):
			main.hud.toggle_menu()
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


## The cave floor near `at` deepest under the ground, with room to stand around it.
func _cave(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_depth := 0
	for z in range(int(from.z) - 80, int(from.z) + 81, 2):
		for x in range(int(from.x) - 80, int(from.x) + 81, 2):
			var top: int = w.surface_y(x, z)
			for y in range(1, top - 6):
				if w.get_cell(x, y, z) != Mat.AIR or w.get_cell(x, y + 1, z) != Mat.AIR \
						or w.get_cell(x, y - 1, z) == Mat.AIR or w.get_cell(x, y - 1, z) == Mat.WATER:
					continue
				var room := 0
				for dz in range(-3, 4):
					for dx in range(-3, 4):
						if w.get_cell(x + dx, y, z + dz) == Mat.AIR and w.get_cell(x + dx, y + 1, z + dz) == Mat.AIR:
							room += 1
				if room >= 30 and top - y > best_depth:
					best_depth = top - y
					best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## Builds a plank hut on flat grass near `at` with the most trees around and puts the
## player in it, so the cut under its roof shows the walls and crowns above as ghosts.
func _hut(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := Vector3i(from.floor())
	var best_n := -1
	for z in range(int(from.z) - 60, int(from.z) + 61, 4):
		for x in range(int(from.x) - 60, int(from.x) + 61, 4):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y + 8 >= w.size_y:
				continue
			var flat := true
			for dz in range(-4, 4):
				for dx in range(-4, 4):
					if w.surface_y(x + dx, z + dz) != y or w.get_cell(x + dx, y - 1, z + dz) != Mat.GRASS:
						flat = false
			if not flat:
				continue
			var n := 0
			for dz in range(-14, 15, 2):
				for dx in range(-20, 21, 2):
					for dy in range(4, 16, 2):
						if w.get_cell(x + dx, y + dy, z + dz) == Mat.LEAVES:
							n += 1
			if n > best_n:
				best_n = n
				best = Vector3i(x, y, z)
	for dz in range(-4, 4):
		for dx in range(-4, 4):
			var wall := dx == -4 or dx == 3 or dz == -4 or dz == 3
			var door := dz == 3 and (dx == -1 or dx == 0)
			for dy in 5:
				var m := Mat.PLANKS if dy == 4 or wall and not (door and dy < 2) else Mat.AIR
				w.set_cell(best.x + dx, best.y + dy, best.z + dz, m)
	# Bushes inside would hide the player.
	for c: Vector3i in main.bush_cells.duplicate():
		if absi(c.x - best.x) <= 5 and absi(c.z - best.z) <= 5:
			main.bush_cells.erase(c)
	main._refresh_bushes()
	for dz in range(-8, 9, 8):
		for dx in range(-8, 9, 8):
			main._on_cell_changed(best + Vector3i(dx, 0, dz))
	return (Vector3(best) + Vector3(0.5, 0.0, 0.5)) * CELL


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


## A flat meadow at `at` with trees of every species: oaks in the back row (some go
## bare in winter, the others keep their leaves), spruces of three sizes in front,
## bushes of every type between them.
## Grown once; later grove shots reuse it.
func _grove(w, at: Vector3i) -> void:
	var h := at.y
	var oaks := [-24, -8, 8, 24]
	var spruces := [-16, 0, 16]
	if w.get_cell(at.x, h - 1, at.z - 30) != Mat.GRASS or w.get_cell(at.x, h, at.z - 30) != Mat.AIR:
		for z in range(at.z - 34, at.z + 30):
			for x in range(at.x - 44, at.x + 46):
				for y in w.size_y:
					var m := Mat.AIR
					if y < h:
						m = Mat.GRASS if y == h - 1 else Mat.DIRT
					w.set_cell(x, y, z, m)
					w.set_natural(x, y, z, true)
		for key in w.trees.keys():
			if absi(key.x - at.x) < 52 and absi(key.y - at.z) < 40:
				w.trees.erase(key)
		for b: Vector3i in w.bushes.keys():
			if absi(b.x - at.x) <= 46 and absi(b.z - at.z) <= 36:
				w.bushes.erase(b)
		# Bushes of every type in turn in a row before the spruces, blueberries between
		# them.
		var k := 0
		for dx in range(-21, 22, 6):
			Bushes.place(w, at.x + dx, h, at.z + 10 + (k % 2), k % Bushes.TYPES.size())
			k += 1
		for dx in [-9, -7, 7, 9]:
			Bushes.place(w, at.x + dx, h, at.z + 4 + absi(dx) % 3, Bushes.BLUEBERRY)
		main.bush_cells.assign(w.bushes.keys())
		main._refresh_bushes()
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		# Oaks that go bare in winter and oaks that keep their leaves, in turn.
		for i in oaks.size():
			var x: int = (at.x + oaks[i]) | 1
			while Foliage.goes_bare(Vector2i(x, (at.z - 8) | 1), Trees.OAK) != (i % 2 == 0):
				x += 2
			Trees.place(w, x, h, (at.z - 8) | 1, Trees.OAK, rng)
		var sizes := [0.75, 1.0, 1.2]
		for i in spruces.size():
			Trees.place(w, (at.x + spruces[i]) | 1, h, (at.z + 6) | 1, Trees.SPRUCE, rng, sizes[i])
		for z in range(at.z - 38, at.z + 34, 8):
			for x in range(at.x - 48, at.x + 50, 8):
				main._on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5) * CELL


## The open spot near `at` with the most crowns around it.
func _forest(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 80, int(from.z) + 81, 6):
		for x in range(int(from.x) - 80, int(from.x) + 81, 6):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for dz in range(-16, 17, 2):
				for dx in range(-24, 25, 2):
					var top: int = w.surface_y(x + dx, z + dz)
					if top > 0 and w.get_cell(x + dx, top - 1, z + dz) == Mat.LEAVES:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## The open spot near `at` with the most trees standing apart from the others.
func _lone_trees(w, at: Vector3) -> Vector3:
	var from := at / CELL
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
			if o != t and absi(o.x - t.x) <= 6 and absi(o.y - t.y) <= 6:
				alone = false
				break
		if alone:
			lone.append(t)
	var best := from
	var best_n := -1
	for z in range(int(from.z) - 96, int(from.z) + 97, 4):
		for x in range(int(from.x) - 96, int(from.x) + 97, 4):
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var n := 0
			for t in lone:
				if absi(t.x - x) <= 24 and absi(t.y - z) <= 14:
					n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL
