extends RefCounted
## Where tools/shot.gd puts the player: spots searched in the world around them (a
## shore, deep water, hills, corners, a cave, a forest, lone trees, dry ground by the
## sea or a waterfall) and scenes built out of cells for a shot (a hut, walls, a trench,
## a lab of ground shapes, a grove, a clearing, blocks round a fire), put back after it,
## since all the shots of one run share one world. `main` is the game.


const WorldData := preload("res://src/shared/world/world_data.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Foliage := preload("res://src/client/world/foliage.gd")
const Grass := preload("res://src/shared/world/grass.gd")
const Bushes := preload("res://src/shared/content/bushes.gd")
const CELL := 0.5
## How far around the player (in cells) the shore, water and lone tree searches look:
## the world has no edge, only the chunks generated around.
const SEARCH := 120
var main: Node
## Replaces the ground around cell `at` with test shapes for corners: a diagonal creek,
## a stone plateau with outer and inner corners, a channel two cells wide with a bend.
## A stone wall three levels high two cells south of the player, between them and
## the camera, to look at how the player shows through what hides them.
## The cells a wall replaced, to put back after its shot: the world is shared by all
## the shots of one run.
var wall_cells: Array = []
## The campfire a shot put out, to be lit again after it.
var out_fire := {}


func flat_near(w, p: Vector3) -> Vector3:
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
						if w.surface_y(nx, nz) != y or w.leaf_col(nx, nz) != 0 \
								or w.slope_mask(nx, y - 1, nz) != WorldData.FULL:
							flat = false
							break
					if not flat:
						break
				if flat:
					return (Vector3(x, y, z) + Vector3(0.5, 0.0, 0.5)) * CELL
	return p


## The nearest spot to `p` inside a tall-grass meadow or a field of ears (see Grass):
## flat grass with the same cover for 2 cells around.
func find(w, p: Vector3, what: String) -> Vector3:
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	if what.contains(":"):
		return find_plant(w, cx, cz, what)
	for r in range(0, 150):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = w.surface_y(x, z)
				if y <= w.sea_level or w.get_cell(x, y - 1, z) != Mat.GRASS:
					continue
				var ok := true
				for oz in range(-2, 3):
					for ox in range(-2, 3):
						var nx := x + ox
						var nz := z + oz
						if w.surface_y(nx, nz) != y or w.get_cell(nx, y - 1, nz) != Mat.GRASS or w.leaf_col(nx, nz) != 0:
							ok = false
						elif what == "meadow" and Grass.tier_at(nx, nz) != Grass.TALL_TIER:
							ok = false
						elif what == "ears" and not Grass.ear_field_at(w, nx, y, nz):
							ok = false
						if not ok:
							break
					if not ok:
						break
				if ok:
					return (Vector3(x, y, z) + Vector3(0.5, 0.0, 0.5)) * CELL
	return p


## A spot two cells south of the nearest grass with plant `id` on it (see Grass.plants_on),
## where the plants are in front of the player; `p` when there is none.
func find_plant(w, cx: int, cz: int, id: String) -> Vector3:
	for r in range(0, 150):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = w.surface_y(x, z)
				# Crowns to the south would hide it in the 3/4 view.
				var open := true
				for k in range(1, 7):
					open = open and w.leaf_col(x, z + k) == 0
				if open and y > w.sea_level and Grass.plants_on(w, x, y - 1, z).has(id) and w.surface_y(x, z + 2) == y \
						and not w.trees.has(Vector2i(x, z + 2)):
					return (Vector3(x, y, z + 2) + Vector3(0.5, 0.0, 0.5)) * CELL
	return Vector3(cx + 0.5, w.surface_y(cx, cz), cz + 0.5) * CELL


## The nearest stone top with moss all round it (see Grass.stone_moss) and open
## ground to the south of it to stand on, or Vector3i.MIN.
func stone_moss_near(w, at: Vector3i) -> Vector3i:
	for r in range(0, 120):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := at.x + dx
				var z := at.z + dz
				var y: int = w.surface_y(x, z) - 1
				var ok: bool = w.surface_y(x, z + 3) - 1 == y
				for oz in range(-3, 2):
					for ox in range(-2, 4):
						ok = ok and Grass.stone_moss(w, x + ox, y, z + oz)
				if ok:
					return Vector3i(x, y, z)
	return Vector3i.MIN


## Turns a patch of the stone tops round `at` into copper ore, as the mountains have
## it, kept in wall_cells to be put back.
func copper_patch(w, at: Vector3i) -> void:
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
			Vector2i(-1, -1), Vector2i(0, -2), Vector2i(-1, 0)]:
		var c := at + Vector3i(o.x, 0, o.y)
		wall_cells.append([c, w.get_cell(c.x, c.y, c.z), w.is_natural(c.x, c.y, c.z)])
		w.set_cell(c.x, c.y, c.z, Mat.of_role("ore", Mat.STONE))
		main.actions.cell_changed.emit(c)


## Picks the moss off the stone tops in an L of cells from `at` (see Grass.stone_moss),
## as hands would.
func pick_moss(w, at: Vector3i) -> void:
	var cells: Array[Vector3i] = []
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(-1, 0)]:
		var c := at + Vector3i(o.x, 0, o.y)
		if Grass.stone_moss(w, c.x, c.y, c.z):
			cells.append(c)
	main.actions.mow(main.host.player, cells)


## Standing spot at the nearest place of a kind (see WorldGen.find_place):
## the chunks there are built first, then a dry spot by the water is picked.
func place(w, what: String) -> Vector3:
	var at: Vector3 = main.player.position
	var near := Vector2i(int(at.x / CELL), int(at.z / CELL))
	var p := Vector2(main.gen.find_place("mountain" if what == "mountain-cave" else what, near))
	if what == "mountain-cave":
		p = mountain_cave(p)
	elif not what in ["lake", "river", "canyon", "gorge",
			"mesa", "tor", "cliffs", "beach", "waterfall", "rapids", "delta", "pit", "adit", "peak", "mountain"]:
		p = inland(what, near, p)
	main.player.position = Vector3(p.x + 0.5, w.size_y - 1, p.y + 0.5) * CELL
	main.chunks.build_around()
	match what:
		"waterfall":
			return falls_view(w, p, 2)
		"rapids":
			return falls_view(w, p, 1)
		"lake", "river", "canyon", "swamp", "delta":
			return dry_near(w, p, 24)
		"cliffs":
			return coast(w, p, seaward(w, p), 3.0)
		"beach":
			return coast(w, p, seaward(w, p), 4.0)
	return dry_near(w, p, 20)


## The heart of the biome `what` within `reach` cells of `near`: of the columns a grid of
## STEP cells apart, the one with the most of its 7×7 neighbours in that biome, the
## nearest of those; `p` when the biome is not there. The nearest place is on an edge,
## where the neighbours' trees and grounds mix in.
func inland(what: String, near: Vector2i, p: Vector2, reach := 3200) -> Vector2:
	const STEP := 32
	var n := reach * 2 / STEP
	var x0 := near.x - reach
	var z0 := near.y - reach
	var lay: Dictionary = main.gen.lay_out(x0, z0, n, n, STEP)
	var hit := PackedByteArray()
	hit.resize(n * n)
	for j in n * n:
		hit[j] = 1 if main.gen._is_place(what, lay, j) else 0
	var best := p
	var best_score := -1.0
	for z in range(3, n - 3):
		for x in range(3, n - 3):
			if hit[z * n + x] == 0:
				continue
			var count := 0
			for dz in range(-3, 4):
				for dx in range(-3, 4):
					count += hit[(z + dz) * n + x + dx]
			var at := Vector2(x0 + x * STEP, z0 + z * STEP)
			var score := count - at.distance_to(Vector2(near)) / 100000.0
			if score > best_score:
				best_score = score
				best = at
	return best


## Nearest dry standing spot to the cell point `p` within `radius` cells.
func dry_near(w, p: Vector2, radius: int) -> Vector3:
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


## A spot before the mouth of the nearest cave cut into a mountain's side (see
## WorldGen._tunnels) to the cell point `p`, looking in.
func mountain_cave(p: Vector2) -> Vector2:
	var g := Vector2i(floori(p.x / WorldGen.TUNNEL_GRID), floori(p.y / WorldGen.TUNNEL_GRID))
	for r in 8:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var t: Array = main.gen._tunnel(g.x + dx, g.y + dz)
				if not t.is_empty():
					return Vector2(t[0], t[1]) - t[2] * 3.0
	return p


## A dry spot beside a step of a river near the cell point `p` that drops `drop`
## levels or more to the south (seen from the front), with no crowns over it, level
## with its top or above, so the fall is not cut away.
func falls_view(w, p: Vector2, drop: int) -> Vector3:
	var best := Vector3i(-1, -1, -1)
	var best_d := INF
	for dz in range(-60, 61):
		for dx in range(-60, 61):
			var x := int(p.x) + dx
			var z := int(p.y) + dz
			var y: int = w.surface_y(x, z)
			if y >= 0:
				continue
			var top: int = w.size_y - 1
			while top > 0 and w.get_cell(x, top, z) == Mat.AIR:
				top -= 1
			if w.get_cell(x, top, z) != Mat.WATER:
				continue
			# Falls to the south first, then to the east or west.
			var k := 0
			var turn := 0.0
			for o: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if k == 0 and w.get_cell(x + o.x, top, z + o.y) == Mat.AIR:
					k = 1
					while w.get_cell(x + o.x, top - k, z + o.y) == Mat.AIR:
						k += 1
					turn = 0.0 if o.y > 0 else 20.0
			if k < drop or Vector2(dx, dz).length() + turn >= best_d:
				continue
			var leafy := false
			for oz in range(-2, 7):
				for ox in range(-4, 5):
					leafy = leafy or w.leaf_col(x + ox, z + oz) != 0
			if leafy:
				continue
			best_d = Vector2(dx, dz).length() + turn
			best = Vector3i(x, top, z)
	if best.y < 0:
		return dry_near(w, p, 24)
	for r in range(2, 16):
		for dz in range(-r, r + 1):
			for dx in [-r, r]:
				var y: int = w.surface_y(best.x + dx, best.z + dz)
				if y > best.y and y < best.y + 4 and w.get_cell(best.x + dx, y, best.z + dz) == Mat.AIR:
					return Vector3(best.x + dx + 0.5, y, best.z + dz + 0.5) * CELL
	return Vector3(best.x + 0.5, best.y + 1, best.z - 1.5) * CELL


## The one of eight directions from the cell point `p` in which the sea is nearest.
func seaward(w, p: Vector2) -> Vector2:
	var best := Vector2.DOWN
	var best_d := INF
	for k in 8:
		var dir := Vector2.RIGHT.rotated(k * PI / 4.0)
		for i in 120:
			var q := p + dir * i
			if w.surface_y(int(q.x), int(q.y)) <= w.sea_level:
				if i < best_d:
					best_d = i
					best = dir
				break
	return best


## Walks from the cell point `from` toward `dir` until the sea, and stands `back`
## cells before it.
func coast(w, from: Vector2, dir: Vector2, back: float) -> Vector3:
	var p := from
	for i in 200:
		var q := p + dir
		if w.surface_y(int(q.x), int(q.y)) <= w.sea_level:
			break
		p = q
	return dry_near(w, p - dir * back, 4)


## Nearest dry cell next to open water, to look at the shore.
func shore(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var best := from
	var best_d := INF
	for z in range(int(from.z) - SEARCH, int(from.z) + SEARCH):
		for x in range(int(from.x) - SEARCH, int(from.x) + SEARCH):
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
func in_water(w, at: Vector3, depth: int) -> Vector3:
	var from := at / CELL
	var sea: int = w.sea_level
	var best := at
	var best_d := INF
	for z in range(int(from.z) - SEARCH, int(from.z) + SEARCH):
		for x in range(int(from.x) - SEARCH, int(from.x) + SEARCH):
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
func hills(w, at: Vector3) -> Vector3:
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
func corners(w, at: Vector3) -> Vector3:
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


## The cave floor near `at` deepest under the ground, under a roof the cut can find,
## with room to stand around it.
static func cave(w, at: Vector3) -> Vector3:
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
				# A roof within the levels the cut looks at (see ChunkStreamer.update_cut),
				# or the spot is the floor of a tall cavern and the view stays uncut.
				var roofed := false
				for ry in range(y + 2, mini(y + 18, top)):
					if Mat.is_roof(w.get_cell(x, ry, z)):
						roofed = true
						break
				if not roofed:
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
func hut(w, at: Vector3) -> Vector3:
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
				var m := maxi(Mat.index("materials:planks"), Mat.STONE) if dy == 4 or wall and not (door and dy < 2) else Mat.AIR
				w.set_cell(best.x + dx, best.y + dy, best.z + dz, m)
	# Bushes inside would hide the player.
	for c: Vector3i in w.bushes.keys():
		if absi(c.x - best.x) <= 5 and absi(c.z - best.z) <= 5:
			w.remove_bush(c)
	for dz in range(-8, 9, 8):
		for dx in range(-8, 9, 8):
			main.chunks.on_cell_changed(best + Vector3i(dx, 0, dz))
	return (Vector3(best) + Vector3(0.5, 0.0, 0.5)) * CELL


## Blocks of stone round the campfire whose north-west cell is `fire`, kept in
## wall_cells to be taken away again: a wall two high to the south-west, a low wall to
## the south-east, a pillar three high to the north-east and a lone block to the
## north-west.
func fire_blocks(w, fire: Vector3i) -> void:
	var cells := []
	for x in range(fire.x - 7, fire.x - 3):
		for y in 2:
			cells.append(Vector3i(x, fire.y + y, fire.z + 4))
	for x in range(fire.x + 3, fire.x + 6):
		cells.append(Vector3i(x, fire.y, fire.z + 6))
	for y in 3:
		cells.append(Vector3i(fire.x + 6, fire.y + y, fire.z - 3))
	cells.append(Vector3i(fire.x - 3, fire.y, fire.z - 4))
	for c: Vector3i in cells:
		wall_cells.append([c, w.get_cell(c.x, c.y, c.z), w.is_natural(c.x, c.y, c.z)])
		w.set_cell(c.x, c.y, c.z, Mat.STONE)
		w.set_natural(c.x, c.y, c.z, false)
		main.actions.cell_changed.emit(c)


## Puts back the cells in wall_cells one by one.
func unwall_cells(w) -> void:
	for c in wall_cells:
		w.set_cell(c[0].x, c[0].y, c[0].z, c[1])
		w.set_natural(c[0].x, c[0].y, c[0].z, c[2])
		main.actions.cell_changed.emit(c[0])
	wall_cells.clear()


func wall(w, at: Vector3i, north := false) -> void:
	for z in (range(at.z - 2, at.z) if north else range(at.z + 2, at.z + 4)):
		for x in range(at.x - 5, at.x + 6):
			for y in range(at.y, at.y + 3):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.STONE)
				w.set_natural(x, y, z, false)
	wall_changed(at)


func unwall(w, at: Vector3i) -> void:
	for c in wall_cells:
		w.set_cell(c[0].x, c[0].y, c[0].z, c[1])
		w.set_natural(c[0].x, c[0].y, c[0].z, c[2])
	wall_cells.clear()
	wall_changed(at)
	main.roof.build(w)


## Digs a trench three cells wide and four deep running north to south through `at`
## (kept in wall_cells to be filled again) and returns the spot on its floor.
func trench(w, at: Vector3i) -> Vector3:
	for z in range(at.z - 10, at.z + 11):
		for x in range(at.x - 1, at.x + 2):
			for y in range(at.y - 4, at.y):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.AIR)
	for z in range(at.z - 16, at.z + 17, 8):
		wall_changed(Vector3i(at.x, at.y, z - 2))
	main.roof.build(w)
	return Vector3(at.x + 0.5, at.y - 4, at.z + 0.5) * CELL


func wall_changed(at: Vector3i) -> void:
	for x in range(at.x - 8, at.x + 9, 8):
		for dz in [-2, 2]:
			main.chunks.on_cell_changed(Vector3i(x, at.y, at.z + dz))


func lab(w, at: Vector3i) -> void:
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
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5) * CELL


## A flat meadow at `at` with trees of every species: oaks in the back row (some go
## bare in winter, the others keep their leaves), spruces of three sizes in front,
## bushes of every type between them.
## Grown once; later grove shots reuse it.
func grove(w, at: Vector3i) -> void:
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
		for key: Vector2i in w.trees.keys():
			if absi(key.x - at.x) < 52 and absi(key.y - at.z) < 40:
				w.remove_tree(key.x, key.y)
		for b: Vector3i in w.bushes.keys():
			if absi(b.x - at.x) <= 46 and absi(b.z - at.z) <= 36:
				w.remove_bush(b)
		# Bushes of every type in turn in a row before the spruces, blueberries between
		# them.
		var k := 0
		for dx in range(-21, 22, 6):
			Bushes.place(w, at.x + dx, h, at.z + 10 + (k % 2), k % Bushes.TYPES.size())
			k += 1
		for dx in [-9, -7, 7, 9]:
			Bushes.place(w, at.x + dx, h, at.z + 4 + absi(dx) % 3, Bushes.first(true, 1))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		# Oaks that go bare in winter and oaks that keep their leaves, in turn.
		for i in oaks.size():
			var x: int = (at.x + oaks[i]) | 1
			while Foliage.goes_bare(Vector2i(x, (at.z - 8) | 1), Trees.first(Trees.BROAD)) != (i % 2 == 0):
				x += 2
			Trees.place(w, x, h, (at.z - 8) | 1, Trees.first(Trees.BROAD), rng)
		var sizes := [0.75, 1.0, 1.2]
		for i in spruces.size():
			Trees.place(w, (at.x + spruces[i]) | 1, h, (at.z + 6) | 1, Trees.first(Trees.NEEDLES), rng, sizes[i])
		for z in range(at.z - 38, at.z + 34, 8):
			for x in range(at.x - 48, at.x + 50, 8):
				main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = Vector3(at.x + 0.5, h, at.z + 0.5) * CELL


## A flat orchard at `at`: one tree of every loaded species in a row behind the player
## (the ground plants of the shade grow under their crowns on their own), a bush of every
## type in a row before them.
func orchard(w, at: Vector3i) -> void:
	var h: int = w.surface_y(at.x, at.z)
	var span := 6 * maxi(Trees.SPECIES.size(), Bushes.TYPES.size()) + 8
	for z in range(at.z - 30, at.z + 20):
		for x in range(at.x - span, at.x + span):
			for y in w.size_y:
				var m := Mat.AIR
				if y < h:
					m = Mat.GRASS if y == h - 1 else Mat.DIRT
				w.set_cell(x, y, z, m)
				w.set_natural(x, y, z, true)
	for key: Vector2i in w.trees.keys():
		if absi(key.x - at.x) < span + 10 and key.y - at.z > -40 and key.y - at.z < 30:
			w.remove_tree(key.x, key.y)
	for b: Vector3i in w.bushes.keys():
		if absi(b.x - at.x) <= span and b.z - at.z >= -30 and b.z - at.z <= 20:
			w.remove_bush(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := Trees.SPECIES.size()
	for i in n:
		Trees.place(w, (at.x + (i - n / 2) * 11) | 1, h, (at.z - 8) | 1, i, rng, Trees.fit(i, w.size_y - h))
	var k := Bushes.TYPES.size()
	for i in k:
		Bushes.place(w, at.x + (i - k / 2) * 6, h, at.z + 5 + (i % 2), i)
	for z in range(at.z - 32, at.z + 24, 8):
		for x in range(at.x - span - 8, at.x + span + 8, 8):
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = (Vector3(at.x, h, at.z) + Vector3(0.5, 0.0, 0.5)) * CELL


## A flat bare plate of sand at `at`, wider than a crown, with nothing on it but a row
## of trees of `species` (ids of trees.yaml) 22 cells apart, north of the player, at
## their full size: for looking at trees' shapes and light alone. The air over it is cleared up to the world's top.
func specimen(w, at: Vector3i, species: Array) -> void:
	var h: int = w.surface_y(at.x, at.z)
	var sand := Mat.index("resources:sand")
	var ground := sand if sand >= 0 else Mat.STONE
	for z in range(at.z - 28, at.z + 20):
		for x in range(at.x - 40, at.x + 40):
			for y in w.size_y:
				w.set_cell(x, y, z, ground if y < h else Mat.AIR)
				w.set_natural(x, y, z, true)
	for key: Vector2i in w.trees.keys():
		if absi(key.x - at.x) < 50 and key.y - at.z > -38 and key.y - at.z < 30:
			w.remove_tree(key.x, key.y)
	for b: Vector3i in w.bushes.keys():
		if absi(b.x - at.x) <= 40 and b.z - at.z >= -28 and b.z - at.z <= 20:
			w.remove_bush(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in species.size():
		var kind := Trees.index(species[i])
		Trees.place(w, (at.x + (i * 2 - species.size() + 1) * 11) | 1, h, (at.z - 6) | 1, kind, rng, Trees.fit(kind, w.size_y - h))
	for z in range(at.z - 32, at.z + 24, 8):
		for x in range(at.x - 44, at.x + 44, 8):
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	# The player stands behind, in a gap between the crowns (none turns see-through),
	# so the row is in the middle of the picture.
	main.player.position = (Vector3(at.x + 11 * (species.size() % 2), h, at.z - 15) + Vector3(0.5, 0.0, 0.5)) * CELL


## A flat clearing at `at` (level of the ground there) with an oak west of the player
## and a spruce east of them, grown afresh each time; `fell` fells both away from the
## player a cell above their feet, as the axe would.
func clearing(w, at: Vector3i, fell: bool, species: Array = []) -> void:
	var h: int = w.surface_y(at.x, at.z)
	for z in range(at.z - 24, at.z + 24):
		for x in range(at.x - 30, at.x + 30):
			for y in w.size_y:
				var m := Mat.AIR
				if y < h:
					m = Mat.GRASS if y == h - 1 else Mat.DIRT
				w.set_cell(x, y, z, m)
	for key: Vector2i in w.trees.keys():
		if absi(key.x - at.x) < 40 and absi(key.y - at.z) < 34:
			w.remove_tree(key.x, key.y)
	for b: Vector3i in w.bushes.keys():
		if absi(b.x - at.x) <= 30 and absi(b.z - at.z) <= 24:
			w.remove_bush(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var oak := Vector2i((at.x - 7) | 1, (at.z - 3) | 1)
	var spruce := Vector2i((at.x + 7) | 1, (at.z - 3) | 1)
	# `species` names the two trees instead, west and east (ids of trees.yaml).
	var west := Trees.index(species[0]) if species.size() > 0 else Trees.first(Trees.BROAD)
	var east := Trees.index(species[1]) if species.size() > 1 else Trees.first(Trees.NEEDLES)
	Trees.place(w, oak.x, h, oak.y, west, rng, minf(1.0, Trees.fit(west, w.size_y - h)))
	Trees.place(w, spruce.x, h, spruce.y, east, rng, minf(0.8, Trees.fit(east, w.size_y - h)))
	for z in range(at.z - 28, at.z + 28, 8):
		for x in range(at.x - 34, at.x + 34, 8):
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	main.player.position = (Vector3(at.x, h, at.z) + Vector3(0.5, 0.0, 0.5)) * CELL
	if fell:
		for t in [oak, spruce]:
			main.actions.fell(main.host.player, Vector3i(t.x, h + 1, t.y))


## The open spot near `at` with the most crowns around it.
func forest(w, at: Vector3) -> Vector3:
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
					# Columns with leaves (surface_y looks through crowns, so it
					# cannot tell a tree from the ground under it).
					var cx := x + dx
					var cz := z + dz
					if w.leaf_col(cx, cz) != 0:
						n += 1
			if n > best_n:
				best_n = n
				best = Vector3(x + 0.5, y, z + 0.5)
	return best * CELL


## The open spot near `at` with the most trees standing apart from the others.
func lone_trees(w, at: Vector3) -> Vector3:
	var from := at / CELL
	var trunks: Array[Vector2i] = []
	for z in range(int(from.z) - SEARCH, int(from.z) + SEARCH):
		for x in range(int(from.x) - SEARCH, int(from.x) + SEARCH):
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
