extends SceneTree
## Renders the game and saves screenshots, for looking at visual changes without a
## browser. Needs a display (not --headless), for example:
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/shot.gd -- /tmp/shots [name ...]
## Each shot sets the time of day, season, weather and an offset of the player from
## the spawn point, waits for the weather to settle and saves <name>.png. The spots are
## searched in cells (half a world unit); the player stands in world units.

const WorldData := preload("res://src/shared/world_data.gd")
const Mat := preload("res://src/shared/materials.gd")
const WorldGen := preload("res://src/shared/world_gen.gd")
const Trees := preload("res://src/shared/trees.gd")
const Foliage := preload("res://src/client/foliage.gd")
const CELL := 0.5

const SHOTS := {
	"day": {"time": 0.45, "season": 1},
	"morning": {"time": 0.29, "season": 0},
	"evening": {"time": 0.72, "season": 1},
	"night": {"time": 0.95, "season": 1},
	"rain": {"time": 0.5, "season": 1, "rain": true},
	"autumn": {"time": 0.42, "season": 2},
	"winter": {"time": 0.45, "season": 3, "rain": true},
	"winter-dusk": {"time": 0.74, "season": 3},
	"winter-night": {"time": 0.97, "season": 3},
	"cave": {"time": 0.45, "season": 1, "cut": -4},
	"underground": {"time": 0.45, "season": 1, "underground": true},
	"underground-winter": {"time": 0.45, "season": 3, "rain": true, "underground": true},
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
	"river": {"time": 0.42, "season": 1, "place": "river"},
	"canyon": {"time": 0.42, "season": 1, "place": "canyon"},
	"lake": {"time": 0.42, "season": 1, "place": "lake"},
	"swamp": {"time": 0.42, "season": 1, "place": "swamp"},
	"cliffs": {"time": 0.42, "season": 1, "place": "cliffs"},
	"beach": {"time": 0.42, "season": 1, "place": "beach"},
	"plateau": {"time": 0.42, "season": 1, "place": "plateau"},
	"tracks": {"time": 0.42, "season": 1, "walk": true},
	"hidden": {"time": 0.42, "season": 1, "wall": true},
	"pit": {"time": 0.42, "season": 1, "place": "canyon", "cut": -3},
	"pit-winter": {"time": 0.45, "season": 3, "place": "canyon", "cut": -3},
	"tracks-winter": {"time": 0.45, "season": 3, "walk": true},
	"wade": {"time": 0.42, "season": 1, "water": 1},
	"swim": {"time": 0.42, "season": 1, "water": 2},
	"ice": {"time": 0.45, "season": 3, "water": 2},
	"grove": {"time": 0.42, "season": 1, "grove": true},
	"grove-autumn": {"time": 0.42, "season": 2, "grove": true},
	"grove-winter": {"time": 0.45, "season": 3, "grove": true},
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
	# The shots look at far places too, so the whole map must be built: many chunks
	# a frame here, not the one a frame of the game.
	while not main.ready_to_play or not main.pending_chunks.is_empty():
		for i in 24:
			if main.ready_to_play and not main.pending_chunks.is_empty():
				main._build_chunk(main._next_chunk())
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
		if shot.has("place"):
			main.player.position = _place(main.world, shot.place)
		if shot.has("water"):
			main.player.position = _in_water(main.world, main.player.position, shot.water)
		if shot.get("grove", false):
			# Away from the campfire by the spawn, which melts the snow around it.
			_grove(main.world, Vector3i((spawn / CELL).floor()) + Vector3i(0, 0, -44))
		main._set_touch(shot.get("touch", false))
		main.hud.perf.visible = shot.get("stats", false)
		main.hud.show_keys(shot_name == "ui")
		if shot.get("lab", false):
			_lab(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.get("wall", false):
			_wall(main.world, Vector3i((main.player.position / CELL).floor()))
			main.roof.build(main.world)
		if shot.has("cut"):
			main.manual_level = main.player.level() + int(shot.cut)
			main._update_cut()
		# Let snow, wetness, tints and particles settle.
		for i in 90:
			await process_frame
			main.snow = 1.0 if main.season == 3 else 0.0
			main.wet = 1.0 if main.raining and main.season != 3 else 0.0
			main.foliage = main.FOLIAGE[main.season]
			main.grass = main.GRASS[main.season]
			main.leaf_amount = main.LEAF_AMOUNT[main.season]
		if shot.get("walk", false):
			# A walk in a hook south-east, then west, over a flat open spot, leaving
			# footprints.
			main.player.position = _flat_near(main.world, main.player.position)
			for i in 100:
				main.player.move_input = Vector2(0.6, 0.8) if i < 50 else Vector2(-1.0, 0.0)
				main.player.step(1.0 / 30.0, false)
				main._leave_footprints()
				await process_frame
			main.player.move_input = Vector2.ZERO
			for i in 10:
				await process_frame
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
		if shot.get("wall", false):
			_unwall(main.world, Vector3i((main.player.position / CELL).floor()))
		if shot.get("menu", false):
			main.hud.toggle_menu()
	quit()


## The nearest spot to `p` with level dry ground and no trees for 7 cells around.
func _flat_near(w, p: Vector3) -> Vector3:
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	for r in range(0, 60):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = w.surface_y(x, z)
				if y <= w.sea_level or w.get_cell(x, y - 1, z) != Mat.GRASS:
					continue
				var flat := true
				for oz in range(-7, 8):
					for ox in range(-7, 8):
						var nx := x + ox
						var nz := z + oz
						if nx < 1 or nz < 1 or nx >= w.size_x - 1 or nz >= w.size_z - 1 or w.surface_y(nx, nz) != y \
								or w.leaf_cols[nz * w.size_x + nx] != 0 or w.slope_mask(nx, y - 1, nz) != WorldData.FULL:
							flat = false
							break
					if not flat:
						break
				if flat:
					return (Vector3(x, y, z) + Vector3(0.5, 0.0, 0.5)) * CELL
	return p


## Standing spot at a place of the island's layout (see WorldGen).
func _place(w, what: String) -> Vector3:
	var size := Vector2(w.size_x, w.size_z)
	var side: float = minf(size.x, size.y)
	match what:
		"river":
			var p: Vector2 = WorldGen.RIVER[4] * size
			return _dry_near(w, p + Vector2(-6.0, 0.0), 12)
		"canyon":
			var p: Vector2 = WorldGen.RIVER[1] * size
			return _dry_near(w, p + Vector2(-4.0, 0.0), 10)
		"lake":
			var p := Vector2(WorldGen.LAKE.x, WorldGen.LAKE.y) * size + Vector2(0.0, WorldGen.LAKE.z * side + 4.0)
			return _dry_near(w, p, 12)
		"swamp":
			return _dry_near(w, Vector2(WorldGen.SWAMP.x, WorldGen.SWAMP.y) * size, 20)
		"plateau":
			return _dry_near(w, Vector2(WorldGen.PLATEAU.x, WorldGen.PLATEAU.y) * size + Vector2(0.0, 10.0), 20)
		"cliffs":
			return _coast(w, Vector2(0.4, 0.42) * size, Vector2(-1.0, 0.0), 3.0)
		"beach":
			return _coast(w, Vector2(0.72, 0.8) * size, Vector2(0.3, 1.0).normalized(), 4.0)
	return main.player.position


## Nearest dry standing spot to the cell point `p` within `radius` cells.
func _dry_near(w, p: Vector2, radius: int) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := int(p.x) + dx
			var z := int(p.y) + dz
			var y: int = w.surface_y(x, z)
			if y <= w.sea_level or y >= w.size_y - 2 or w.get_cell(x, y, z) != Mat.AIR:
				continue
			var d := Vector2(dx, dz).length()
			if d < best_d:
				best_d = d
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL if best_d < INF else main.player.position


## Walks from the cell point `from` toward `dir` until the sea, and stands `back`
## cells before it.
func _coast(w, from: Vector2, dir: Vector2, back: float) -> Vector3:
	var p := from
	for i in 200:
		var q := p + dir
		if w.surface_y(int(q.x), int(q.y)) <= w.sea_level:
			break
		p = q
	return _dry_near(w, p - dir * back, 4)


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


## Water near `at` at the edge of a sea or lake, with the feet on the bottom (a
## swimmer floats up from there): one cell deep for `depth` 1, else at least `depth`
## deep. Open water lies south, the shore a few cells north.
func _in_water(w, at: Vector3, depth: int) -> Vector3:
	var from := at / CELL
	var sea: int = w.sea_level
	var best := at
	var best_d := INF
	for z in range(8, w.size_z - 12):
		for x in range(8, w.size_x - 8):
			var d := Vector2(x, z).distance_to(Vector2(from.x, from.z))
			if d >= best_d or w.get_cell(x, sea + 1 - depth, z) != Mat.WATER:
				continue
			if depth == 1 and w.get_cell(x, sea - 1, z) == Mat.WATER:
				continue
			var open := true
			for o in [Vector2i(-5, 6), Vector2i(0, 6), Vector2i(5, 6), Vector2i(-5, 10), Vector2i(5, 10)]:
				open = open and w.get_cell(x + o.x, sea - 1, z + o.y) == Mat.WATER
			if not open or w.surface_y(x, z - (2 if depth == 1 else 4)) <= sea or w.surface_y(x, z - 1) > 0 and depth == 1:
				continue
			var y := sea + 1 - depth
			while w.get_cell(x, y - 1, z) == Mat.WATER:
				y -= 1
			if w.corner_fills(x, y, z) != 0 or w.corner_fills(x, sea, z) != 0:
				continue
			best = Vector3(x + 0.5, y, z + 0.5) * CELL
			best_d = d
	return best


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
## A stone wall three levels high two cells south of the player, between them and
## the camera, to look at how the player shows through what hides them.
## The cells a wall replaced, to put back after its shot: the world is shared by all
## the shots of one run.
var wall_cells: Array = []


func _wall(w, at: Vector3i) -> void:
	for z in range(at.z + 2, at.z + 4):
		for x in range(at.x - 5, at.x + 6):
			for y in range(at.y, at.y + 3):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.STONE)
				w.set_natural(x, y, z, false)
	_wall_changed(at)


func _unwall(w, at: Vector3i) -> void:
	for c in wall_cells:
		w.set_cell(c[0].x, c[0].y, c[0].z, c[1])
		w.set_natural(c[0].x, c[0].y, c[0].z, c[2])
	wall_cells.clear()
	_wall_changed(at)
	main.roof.build(w)


func _wall_changed(at: Vector3i) -> void:
	for x in range(at.x - 8, at.x + 9, 8):
		main._on_cell_changed(Vector3i(x, at.y, at.z + 2))


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
## bare in winter, the others keep their leaves), spruces of three sizes in front.
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
		var keep: Array[Vector3i] = []
		for b in main.bush_cells:
			if absi(b.x - at.x) > 46 or absi(b.z - at.z) > 36:
				keep.append(b)
		main.bush_cells = keep
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
