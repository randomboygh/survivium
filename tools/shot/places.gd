extends RefCounted
## Where tools/shot.gd puts the player: spots searched in the world around them (a
## shore, deep water, hills, corners, a cave, a forest, lone trees, dry ground by the
## sea or a waterfall) and scenes built out of cells for a shot (a hut, walls, a trench,
## a lab of ground shapes, a grove, a clearing, blocks round a fire), put back after it,
## since all the shots of one run share one world. `main` is the game.


const WorldData := preload("res://src/shared/world/world_data.gd")
const WorldCells := preload("res://src/shared/world/world_cells.gd")
const Mat := preload("res://src/shared/content/materials.gd")
const Plans := preload("res://src/shared/game/plans.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const Trees := preload("res://src/shared/content/trees.gd")
const Growth := preload("res://src/shared/world/growth.gd")
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
## The cell of the sign written in front of the player (signs).
var sign_cell := Vector3i.ZERO


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
	if what == "ring":
		return find_ring(w, cx, cz)
	if what == "murk":
		return find_murk(w, cx, cz, p)
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


## A spot six cells south of the nearest murky water (a swamp's pool, WorldCells.murk),
## where the will-o'-the-wisps hang; `p` when there is none.
func find_murk(w, cx: int, cz: int, p: Vector3) -> Vector3:
	for r in range(0, 200):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var x := cx + dx
				var z := cz + dz
				var y: int = WorldCells.top_level(w.water_col(x, z))
				if y < 0 or w.murk(x, y, z) == 0:
					continue
				var sy: int = w.surface_y(x, z + 6)
				return Vector3(x + 0.5, maxi(sy, y + 1), z + 6.5) * CELL
	return p


## A spot south of the middle of the nearest fairy ring on open grass (Grass.fairy_ring),
## the ring in front of the player; the spot over cx, cz when there is none.
func find_ring(w, cx: int, cz: int) -> Vector3:
	var g := Vector2i(floori(float(cx) / Grass.RING_GRID), floori(float(cz) / Grass.RING_GRID))
	for r in range(0, 12):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var ring := Grass.fairy_ring((g.x + dx) * Grass.RING_GRID, (g.y + dz) * Grass.RING_GRID)
				var x := floori(ring.x)
				var z := floori(ring.y)
				if ring.z <= 0.0 or w.chunk_at(x, z) == null:
					continue
				var y: int = w.surface_y(x, z)
				if y > w.sea_level and w.get_cell(x, y - 1, z) == Mat.GRASS and w.leaf_col(x, z) == 0:
					return (Vector3(x, y, z + ceili(ring.z) + 2) + Vector3(0.5, 0.0, 0.5)) * CELL
	return Vector3(cx + 0.5, w.surface_y(cx, cz), cz + 0.5) * CELL


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


## A spot two cells south of the patch round `p` where plant `id` grows most thickly in
## the open (counted on a coarse grid of the loaded ground), so a field of it fills the view; `p`
## when it grows nowhere near.
func find_patch(w, p: Vector3, id: String) -> Vector3:
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	var best := p
	var best_n := 0
	for z in range(cz - 120, cz + 121, 6):
		for x in range(cx - 120, cx + 121, 6):
			var n := 0
			for dz in range(-8, 3, 2):
				for dx in range(-10, 11, 2):
					var y: int = w.surface_y(x + dx, z + dz)
					# Only where no crown hides it from the camera.
					if y > w.sea_level and w.leaf_col(x + dx, z + dz) == 0 and Grass.plants_on(w, x + dx, y - 1, z + dz).has(id):
						n += 1
			var y0: int = w.surface_y(x, z + 2)
			if n > best_n and y0 > w.sea_level and w.leaf_col(x, z + 2) == 0:
				best_n = n
				best = (Vector3(x, y0, z + 2) + Vector3(0.5, 0.0, 0.5)) * CELL
	print("patch of %s: %d cells" % [id, best_n])
	return best


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


## Pulls the grass up with bare hands for fibre in an L of cells round `at` (its
## column; the ground's top found), as gathering in a meadow does.
func pick_fiber(w, at: Vector3i) -> void:
	main.controls.put_in_hand("", -1, false)
	var cells: Array[Vector3i] = []
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(0, -2), Vector2i(-1, 0),
			Vector2i(1, -1)]:
		var c := at + Vector3i(o.x, 0, o.y)
		c.y = w.surface_y(c.x, c.z) - 1
		for k in 2:
			if main.actions.can_mow(c):
				var one: Array[Vector3i] = [c]
				main.actions.mow(main.host.player, one)


## Standing spot at the nearest place of a kind (see WorldGen.find_place):
## the chunks there are built first, then a dry spot by the water is picked.
func place(w, what: String) -> Vector3:
	var at: Vector3 = main.player.position
	var near := Vector2i(int(at.x / CELL), int(at.z / CELL))
	var p := Vector2(main.gen.find_place("mountain" if what == "mountain-cave" else what, near))
	if what == "mountain-cave":
		p = mountain_cave(p)
	elif not what in ["lake", "river", "canyon", "gorge",
			"mesa", "tor", "cliffs", "beach", "tropical_beach", "waterfall", "rapids", "delta", "pit", "adit", "peak", "mountain"]:
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
		"beach", "tropical_beach":
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


## A cliff of the landscape's materials in layers north of the player on flat ground
## near `at`, twelve cells wide and five high, its face to the camera: turf over soil,
## then stone with veins of every ore, a lens of sand, one of clay and a block of brick
## in it, to look at how the materials meet on the sides of cells.
func strata(w, at: Vector3) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var stone: int = Mat.STONE
	var rows := [Mat.GRASS, Mat.DIRT, stone, stone, stone]
	var veins := {}
	var ores := ["materials:copper_ore", "materials:iron_ore", "materials:tin_ore", "materials:gold_ore", "materials:silver_ore"]
	var spots := [[Vector2i(-5, 2), Vector2i(-4, 2), Vector2i(-4, 3)], [Vector2i(-1, 3), Vector2i(0, 3), Vector2i(0, 4)],
		[Vector2i(3, 2)], [Vector2i(5, 4), Vector2i(6, 4)], [Vector2i(1, 2)]]
	for k in ores.size():
		var m: int = Mat.index(ores[k])
		if m > 0:
			for o: Vector2i in spots[k]:
				veins[o] = m
	var lenses := [["resources:sand", [Vector2i(-6, 1), Vector2i(-5, 1), Vector2i(-6, 2)]],
		["resources:clay", [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]], ["materials:brick", [Vector2i(-2, 4), Vector2i(-2, 3)]]]
	for l: Array in lenses:
		var m: int = Mat.index(l[0])
		if m > 0:
			for o: Vector2i in l[1]:
				veins[o] = m
	for dx in range(-6, 7):
		for row in rows.size():
			var m: int = veins.get(Vector2i(dx, row), rows[row])
			for dz in range(-6, -3):
				var c := spot + Vector3i(dx, 4 - row, dz)
				wall_cells.append([c, w.get_cell(c.x, c.y, c.z), w.is_natural(c.x, c.y, c.z)])
				w.set_cell(c.x, c.y, c.z, m)
				main.actions.cell_changed.emit(c)
	return (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL


## Short walls of every building material in a row on flat grass near `at`, each three
## cells long and three high on a floor of its own laid flush with the ground, the
## player in front of them (the building stage, materials as cells), and stairs.
func walls(w, at: Vector3) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var names := ["core:stone", "materials:planks", "materials:brick", "materials:log_wall", "materials:wattle", "materials:cut_stone"]
	for i in names.size():
		var m: int = Mat.index(names[i])
		if m <= 0:
			continue
		var x0 := spot.x - 11 + i * 4
		for dx in 3:
			for dz in range(-3, 0):
				w.set_cell(x0 + dx, spot.y - 1, spot.z + dz, m)
			for dy in 3:
				w.set_cell(x0 + dx, spot.y + dy, spot.z - 4, m)
	# A flight of stairs two wide west of them, three steps up to a landing of planks,
	# planks under each, and a lone stairs turned to rise east before it.
	var planks: int = maxi(Mat.index("materials:planks"), Mat.STONE)
	var x1 := spot.x - 15
	for x in [x1, x1 + 1]:
		for i in 3:
			for y in range(spot.y, spot.y + i):
				w.set_cell(x, y, spot.z - 1 - i, planks)
			main.session.placed.put("tools:stairs", Vector3i(x, spot.y + i, spot.z - 1 - i))
		for z in range(spot.z - 6, spot.z - 3):
			for y in range(spot.y, spot.y + 3):
				w.set_cell(x, y, z, planks)
	main.session.placed.put("tools:stairs", Vector3i(x1 + 3, spot.y, spot.z), null, true, -1.0, null, 1)
	# West of the stairs a wall of planks with a door shut, one open and a window.
	for x in range(x1 - 9, x1 - 1):
		for y in 3:
			var gap := (x == x1 - 7 or x == x1 - 4) and y < 2 or x == x1 - 2 and y == 1
			w.set_cell(x, spot.y + y, spot.z - 4, Mat.AIR if gap else planks)
	main.session.placed.put("tools:door", Vector3i(x1 - 7, spot.y, spot.z - 4))
	main.session.placed.put("tools:door", Vector3i(x1 - 4, spot.y, spot.z - 4), null, true, -1.0, null, 0, true)
	main.session.placed.put("tools:window", Vector3i(x1 - 2, spot.y + 1, spot.z - 4))
	for c: Vector3i in w.bushes.keys():
		if absi(c.x - spot.x) <= 26 and c.z >= spot.z - 7 and c.z <= spot.z + 2:
			w.remove_bush(c)
	for dx in range(-32, 17, 8):
		main.chunks.on_cell_changed(spot + Vector3i(dx, 0, -2))
	return (Vector3(spot) + Vector3(-6.5, 0.0, 2.5)) * CELL


## Doors and windows of every size in a brick wall on flat ground near `at`, from the
## west: a door 2×3, a door 2×2 open, a door 1×2, windows 1×2, 2×1, 2×2 and 3×2; before
## its east end a fireplace burning, a wide cupboard, a barrel and a cupboard. Returns
## where the player stands: in the middle, or by the cupboards with `by_storage`.
func openings(w, at: Vector3, by_storage := false) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var brick: int = maxi(Mat.index("materials:brick"), Mat.STONE)
	var x0 := spot.x - 15
	var z := spot.z - 4
	# [item, first x, cells wide, from level, cells high, open]
	var gaps := [["tools:door_2x3", 0, 2, 0, 3, false], ["tools:door_2x2", 3, 2, 0, 2, true], ["tools:door", 6, 1, 0, 2, false],
		["tools:window_1x2", 8, 1, 1, 2, false], ["tools:window_2x1", 10, 2, 2, 1, false],
		["tools:window_2x2", 13, 2, 1, 2, false], ["tools:window_3x2", 16, 3, 1, 2, false]]
	for x in range(x0 - 1, x0 + 31):
		for dz in range(-3, 4):
			for y in range(spot.y, spot.y + 5):
				if w.get_cell(x, y, z + dz) != Mat.AIR:
					w.set_cell(x, y, z + dz, Mat.AIR)
		if x > x0 + 20:
			continue
		for y in 4:
			var gap := false
			for g: Array in gaps:
				gap = gap or x >= x0 + g[1] and x < x0 + g[1] + g[2] and y >= g[3] and y < g[3] + g[4]
			if not gap:
				w.set_cell(x, spot.y + y, z, brick)
	var p = main.session.placed
	for g: Array in gaps:
		p.put(g[0], Vector3i(x0 + g[1], spot.y + g[3], z), null, true, -1.0, null, 0, g[5])
	for x in range(x0 + 21, x0 + 31):
		for y in 3:
			w.set_cell(x, spot.y + y, z, brick)
	p.put("tools:fireplace", Vector3i(x0 + 21, spot.y, z + 1), null, true, 2400.0)
	p.put("tools:wide_cupboard", Vector3i(x0 + 24, spot.y, z + 1))
	p.put("tools:barrel", Vector3i(x0 + 26, spot.y, z + 1))
	p.put("tools:cupboard", Vector3i(x0 + 27, spot.y, z + 1))
	for c: Vector3i in w.bushes.keys():
		if c.x >= x0 - 2 and c.x <= x0 + 32 and absi(c.z - z) <= 4:
			w.remove_bush(c)
	for dx in range(-16, 33, 8):
		main.chunks.on_cell_changed(Vector3i(x0 + dx, spot.y, z))
	if by_storage:
		return (Vector3(x0 + 25, spot.y, z + 3) + Vector3(0.5, 0.0, 0.5)) * CELL
	return (Vector3(x0 + 15, spot.y, z + 5) + Vector3(0.5, 0.0, 0.5)) * CELL


## Fences and the rest of stage 1's building near `at`, on flat ground: a pen of fence
## 8×6 with a wicket open in its south side and a gate shut in its east side; west of it a
## brick wall with the big gates 3×3, the west ones shut; east of it a wall four high with
## a ladder up it, and a deck of planks on it with a hatch open and a wide one shut.
## Returns where the player stands: south of the pen.
func fences(w, at: Vector3) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var brick: int = maxi(Mat.index("materials:brick"), Mat.STONE)
	var planks: int = maxi(Mat.index("materials:planks"), Mat.STONE)
	var p = main.session.placed
	var y := spot.y
	for x in range(spot.x - 16, spot.x + 18):
		for z in range(spot.z - 12, spot.z + 4):
			for dy in 8:
				if w.get_cell(x, y + dy, z) != Mat.AIR:
					w.set_cell(x, y + dy, z, Mat.AIR)
	# The pen: x -4..3, z -9..-4, on trodden bare ground (tall grass hid the fence).
	var a := Vector2i(spot.x - 4, spot.z - 9)
	var b := Vector2i(spot.x + 3, spot.z - 4)
	for x in range(a.x - 2, b.x + 3):
		for z in range(a.y - 2, b.y + 4):
			if w.get_cell(x, y - 1, z) == Mat.GRASS:
				w.set_cell(x, y - 1, z, Mat.DIRT)
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			if x != a.x and x != b.x and z != a.y and z != b.y:
				continue
			if z == b.y and x == spot.x - 1 or x == b.x and (z == a.y + 2 or z == a.y + 3):
				continue
			p.put("tools:fence", Vector3i(x, y, z), null, true, -1.0, null, 0 if z == a.y or z == b.y else 1)
	p.put("tools:wicket", Vector3i(spot.x - 1, y, b.y), null, true, -1.0, null, 0, true)
	p.put("tools:gate", Vector3i(b.x - 1, y, a.y + 2), null, true, -1.0, null, 3)
	# The barn wall to the west with the big gates.
	var wx := spot.x - 15
	for x in range(wx, wx + 8):
		for dy in 4:
			var gap := x >= wx + 2 and x < wx + 5 and dy < 3
			if not gap:
				w.set_cell(x, y + dy, spot.z - 6, brick)
	p.put("tools:door_3x3", Vector3i(wx + 2, y, spot.z - 6))
	# The wall to the east, four high, a deck of planks on it to the north, a ladder up it.
	var ex := spot.x + 8
	for x in range(ex, ex + 7):
		for z in range(spot.z - 9, spot.z - 4):
			for dy in 4:
				var edge := z == spot.z - 5 or x == ex or x == ex + 6 or z == spot.z - 9
				if edge or dy == 3:
					w.set_cell(x, y + dy, z, planks if dy == 3 else brick)
	p.put("tools:hatch", Vector3i(ex + 2, y + 3, spot.z - 7), null, true, -1.0, null, 0, true)
	w.set_cell(ex + 2, y + 3, spot.z - 7, Mat.AIR)
	for c: Vector3i in [Vector3i(ex + 4, y + 3, spot.z - 8), Vector3i(ex + 5, y + 3, spot.z - 8),
			Vector3i(ex + 4, y + 3, spot.z - 7), Vector3i(ex + 5, y + 3, spot.z - 7)]:
		w.set_cell(c.x, c.y, c.z, Mat.AIR)
	p.put("tools:hatch_2x2", Vector3i(ex + 4, y + 3, spot.z - 8))
	for dy in 4:
		p.put("tools:ladder", Vector3i(ex + 3, y + dy, spot.z - 4))
	for c: Vector3i in w.bushes.keys():
		if c.x >= spot.x - 17 and c.x <= spot.x + 18 and c.z >= spot.z - 12 and c.z <= spot.z + 4:
			w.remove_bush(c)
	for dx in range(-16, 25, 8):
		for dz in [-8, 0]:
			main.chunks.on_cell_changed(Vector3i(spot.x + dx, y, spot.z + dz))
	return (Vector3(spot) + Vector3(0.5, 0.0, 1.5)) * CELL


## Signs near `at` on flat ground (decision 183): a board on a brick wall to the north, a
## sign written south-west of it and a signpost south-east of that pointing on; the
## sign's cell is kept in sign_cell. Returns where the player stands: by the board when
## `near` is "board", on the cleared ground with no signs when "none", by a cross where
## someone died (Placed.put_grave) and no signs when "grave", else between the sign and the signpost (their text is read within
## Placed.SIGN_READ cells).
func signs(w, at: Vector3, near := "posts") -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var brick: int = maxi(Mat.index("materials:brick"), Mat.STONE)
	var p = main.session.placed
	var y := spot.y
	for x in range(spot.x - 8, spot.x + 9):
		for z in range(spot.z - 10, spot.z + 6):
			for dy in 6:
				if w.get_cell(x, y + dy, z) != Mat.AIR:
					w.set_cell(x, y + dy, z, Mat.AIR)
			if w.get_cell(x, y - 1, z) == Mat.GRASS:
				w.set_cell(x, y - 1, z, Mat.DIRT)
	for x in range(spot.x - 3, spot.x + 4):
		for dy in 3:
			w.set_cell(x, y + dy, spot.z - 7, brick)
	if near == "grave":
		p.put_grave((Vector3(spot) + Vector3(0.5, 0.0, -1.5)) * CELL, {"name": "Тихон", "cause": "cold", "day": 12,
			"days": 3.4, "life": {"walked": 4650.0, "trees": 23.0, "built": 140.0, "dug": 60.0, "jumps": 12.0}})
		for dx in range(-8, 9, 8):
			for dz in [-8, 0]:
				main.chunks.on_cell_changed(Vector3i(spot.x + dx, y, spot.z + dz))
		return (Vector3(spot) + Vector3(0.5, 0.0, 1.0)) * CELL
	if near == "none":
		for dx in range(-8, 9, 8):
			for dz in [-8, 0]:
				main.chunks.on_cell_changed(Vector3i(spot.x + dx, y, spot.z + dz))
		return (Vector3(spot) + Vector3(0.5, 0.0, -2.5)) * CELL
	p.put("tools:notice_board", Vector3i(spot.x, y, spot.z - 6), null, true, -1.0, null, 0, false,
		"Правила лагеря:\nне рубить у ручья\nкостёр тушить на ночь\nсундук общий")
	sign_cell = Vector3i(spot.x - 2, y, spot.z - 1)
	p.put("tools:sign", sign_cell, null, true, -1.0, null, 0, false, "Лагерь «Ручей»\nдобро пожаловать")
	p.put("tools:signpost", Vector3i(spot.x + 2, y, spot.z + 2), null, true, -1.0, null, 0, false, "К озеру\n120 шагов")
	for c: Vector3i in w.bushes.keys():
		if c.x >= spot.x - 9 and c.x <= spot.x + 9 and c.z >= spot.z - 11 and c.z <= spot.z + 6:
			w.remove_bush(c)
	for dx in range(-8, 9, 8):
		for dz in [-8, 0]:
			main.chunks.on_cell_changed(Vector3i(spot.x + dx, y, spot.z + dz))
	if near == "board":
		return (Vector3(spot) + Vector3(0.5, 0.0, -3.5)) * CELL
	return (Vector3(spot) + Vector3(0.5, 0.0, 1.0)) * CELL


## A shut room of brick 9×9 inside, three levels high under a roof, on flat ground near
## `at`: in its east wall from the north a window 1×2, a door 1×2 (open with `open_door`)
## and a window 2×2 (the door first, where the low morning sun lands in view, with
## `door_first`), so the sun shines in through the windows and not the shut door; with
## `lamps` a lantern stands outside before each of them. Returns where the player
## stands: inside, by the west wall.
func lit_room(w, at: Vector3, open_door := false, lamps := false, door_first := false) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var brick: int = maxi(Mat.index("materials:brick"), Mat.STONE)
	var a := spot + Vector3i(-4, 0, -4)
	var east := a.x + 9
	# [item, first z, cells wide, from level, cells high]
	var gaps := [["tools:window_1x2", 1, 1, 1, 2], ["tools:door", 4, 1, 0, 2], ["tools:window_2x2", 7, 2, 1, 2]]
	if door_first:
		gaps = [["tools:door", 1, 1, 0, 2], ["tools:window_1x2", 4, 1, 1, 2], ["tools:window_2x2", 7, 2, 1, 2]]
	# Clear of trees far to the east and the south, where the morning sun comes from.
	for x in range(a.x - 4, a.x + 30):
		for z in range(a.z - 4, a.z + 30):
			for y in range(a.y, a.y + 24):
				var inside := x >= a.x - 1 and x <= east and z >= a.z - 1 and z <= a.z + 9
				var wall := x == a.x - 1 or x == east or z == a.z - 1 or z == a.z + 9
				var m := Mat.AIR
				# The roof stops short of the east wall: the low sun comes in under its eave.
				if inside and y == a.y + 3 and x < east:
					m = brick
				elif inside and wall and y < a.y + 3:
					m = brick
					for g: Array in gaps:
						if x == east and z >= a.z + g[1] and z < a.z + g[1] + g[2] and y - a.y >= g[3] and y - a.y < g[3] + g[4]:
							m = Mat.AIR
				if w.get_cell(x, y, z) != m:
					w.set_cell(x, y, z, m)
	var p = main.session.placed
	for g: Array in gaps:
		# Turned a quarter back, the square's west column (its cells) stands in the wall.
		p.put(g[0], Vector3i(east, a.y + g[3], a.z + g[1]), null, true, -1.0, null, 3, open_door and g[0] == "tools:door")
		if lamps:
			p.put_light("tools:lantern", Vector3i(east + 1, a.y, a.z + g[1]))
	for c: Vector3i in w.bushes.keys():
		if c.x >= a.x - 6 and c.x <= a.x + 32 and c.z >= a.z - 6 and c.z <= a.z + 32:
			w.remove_bush(c)
	for dx in range(-8, 33, 8):
		for dz in range(-8, 33, 8):
			main.chunks.on_cell_changed(a + Vector3i(dx, 0, dz))
	return (Vector3(a.x + 2, a.y, a.z + 4) + Vector3(0.5, 0.0, 0.5)) * CELL


## Furniture on a floor of planks 10×7 on flat ground near `at`, low walls of planks on
## its west and north sides: a table with a stool each side, a bed, a cupboard and a
## barrel by the north wall, a rug in the middle. Returns where the player stands.
func furniture(w, at: Vector3) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var planks: int = maxi(Mat.index("materials:planks"), Mat.STONE)
	var a := spot + Vector3i(-5, 0, -9)
	for x in range(a.x, a.x + 10):
		for z in range(a.z, a.z + 7):
			w.set_cell(x, a.y - 1, z, planks)
			for y in range(a.y, a.y + 3):
				if w.get_cell(x, y, z) != Mat.AIR:
					w.set_cell(x, y, z, Mat.AIR)
	for x in range(a.x - 1, a.x + 10):
		w.set_cell(x, a.y, a.z - 1, planks)
	for z in range(a.z - 1, a.z + 7):
		w.set_cell(a.x - 1, a.y, z, planks)
	var p = main.session.placed
	p.put("tools:wooden_bed", a + Vector3i(0, 0, 0))
	p.put("tools:cupboard", a + Vector3i(3, 0, 0))
	p.put("tools:barrel", a + Vector3i(4, 0, 0))
	p.put("tools:table", a + Vector3i(6, 0, 2))
	p.put("tools:stool", a + Vector3i(5, 0, 2), null, true, -1.0, null, 3)
	p.put("tools:stool", a + Vector3i(8, 0, 3), null, true, -1.0, null, 1)
	p.put("tools:rug", a + Vector3i(2, 0, 3))
	for c: Vector3i in w.bushes.keys():
		if c.x - spot.x >= -20 and c.x - spot.x <= 16 and absi(c.z - spot.z + 6) <= 10:
			w.remove_bush(c)
	for dx in range(-16, 17, 8):
		main.chunks.on_cell_changed(a + Vector3i(dx, 0, 2))
	return (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL


## The blueprint on flat ground near `at` (Plans): a room of planks 7×6 three levels high
## with its lowest level built, a floor's ghost inside, a brick wall's ghost to the east.
## Returns where the player stands, south of the room.
func plan(w, at: Vector3) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var plans = main.session.plans
	var a := spot + Vector3i(-4, 0, -9)
	var room := Plans.shape("square", a, a + Vector3i(6, 0, 5), 3, Vector2(spot.x, spot.z) * CELL)
	var planks: int = maxi(Mat.index("materials:planks"), Mat.STONE)
	var ghost: Array = []
	for c: Vector3i in room:
		if c.y == a.y:
			w.set_cell(c.x, c.y, c.z, planks)
		else:
			ghost.append(c)
			plans.cells[c] = "materials:planks"
	plans.changed.emit(ghost, "materials:planks")
	var floor := Plans.shape("plane", a + Vector3i(1, -1, 1), a + Vector3i(5, -1, 4), 1)
	for c: Vector3i in floor:
		plans.cells[c] = "materials:planks"
	plans.changed.emit(floor, "materials:planks")
	var wall := Plans.shape("line", a + Vector3i(9, 0, 0), a + Vector3i(9, 0, 5), 2)
	for c: Vector3i in wall:
		plans.cells[c] = "materials:brick"
	plans.changed.emit(wall, "materials:brick")
	# The forms of built blocks (WorldData.forms) west of the room: a flight of stairs
	# rising east on stone, ramps rising north, upturned ramps over a plank wall, and the
	# ghost of a flight of ramps.
	var stone := Mat.STONE
	for i in 3:
		for z in range(1, 4):
			var c := a + Vector3i(-12 + i, i, z)
			for y in range(a.y, c.y):
				w.set_cell(c.x, y, c.z, stone)
			w.set_cell(c.x, c.y, c.z, planks)
			w.set_form(c.x, c.y, c.z, WorldData.FORM_STAIRS | 1 << 2)
	for x in range(-12, -9):
		var c := a + Vector3i(x, 0, 5)
		w.set_cell(c.x, c.y, c.z, stone)
		w.set_form(c.x, c.y, c.z, WorldData.FORM_RAMP)
		for y in 2:
			w.set_cell(c.x, c.y + y, c.z + 2, planks)
		w.set_cell(c.x, c.y + 2, c.z + 1, planks)
		w.set_form(c.x, c.y + 2, c.z + 1, WorldData.FORM_UPPER | 2 << 2)
	var ramps: Array = []
	for i in 3:
		var c := a + Vector3i(-7, i, -2 + i)
		ramps.append(c)
		plans.cells[c] = "materials:planks"
		plans.forms[c] = WorldData.FORM_RAMP | 2 << 2
	plans.changed.emit(ramps, "materials:planks")
	for c: Vector3i in w.bushes.keys():
		if c.x - spot.x >= -20 and c.x - spot.x <= 16 and absi(c.z - spot.z + 6) <= 10:
			w.remove_bush(c)
	for dx in range(-16, 17, 8):
		main.chunks.on_cell_changed(a + Vector3i(dx, 0, 2))
	return (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL


## The forms of built blocks (WorldData.forms) on flat ground near `at`: a row of
## stairs, of ramps and of upturned ramps (over a stone each), each facing north, east,
## south and west, and a flight of stairs and one of ramps going up north. Returns where
## the player stands, south of them.
func forms(w, at: Vector3, only := 0) -> Vector3:
	var spot := Vector3i((flat_near(w, at) / CELL).floor())
	var planks: int = maxi(Mat.index("materials:planks"), Mat.STONE)
	var stone := Mat.STONE
	for c: Vector3i in w.bushes.keys():
		if absi(c.x - spot.x) <= 14 and absi(c.z - spot.z + 6) <= 10:
			w.remove_bush(c)
	# A stone floor under them, so no grass hides them.
	for z in range(-12, 0):
		for x in range(-10, 9):
			w.set_cell(spot.x + x, spot.y - 1, spot.z + z, stone)
	var kinds := [WorldData.FORM_STAIRS, WorldData.FORM_RAMP, WorldData.FORM_UPPER]
	if only != 0:
		kinds = [only]
	for r in kinds.size():
		for side in 4:
			var c := spot + Vector3i(-8 + 2 * side, 0, -10 + 3 * r)
			if kinds[r] == WorldData.FORM_UPPER:
				w.set_cell(c.x, c.y, c.z, stone)
				c.y += 1
			w.set_cell(c.x, c.y, c.z, planks)
			w.set_form(c.x, c.y, c.z, kinds[r] | side << 2)
	for f in (2 if only == 0 else 0):
		for i in 3:
			for x in 2:
				var c := spot + Vector3i(2 + 3 * f + x, i, -4 - i)
				for y in range(spot.y, c.y):
					w.set_cell(c.x, y, c.z, stone)
				w.set_cell(c.x, c.y, c.z, planks if f == 0 else stone)
				w.set_form(c.x, c.y, c.z, WorldData.FORM_STAIRS if f == 0 else WorldData.FORM_RAMP)
	for dx in range(-16, 17, 8):
		for dz in [-8, 0]:
			main.chunks.on_cell_changed(spot + Vector3i(dx, 0, dz))
	return (Vector3(spot) + Vector3(0.5, 0.0, 0.5)) * CELL


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


## Raises stone `depth` cells high all round `at` but for a pit of 7 by 5 cells it stands
## in (kept in wall_cells), as if the player had dug it out.
func pit_round(w, at: Vector3i, depth: int) -> void:
	for x in range(at.x - 14, at.x + 15):
		for z in range(at.z - 14, at.z + 15):
			if absi(x - at.x) <= 3 and absi(z - at.z) <= 2:
				continue
			for y in range(at.y, at.y + depth):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.STONE)
	for x in range(at.x - 16, at.x + 17, 8):
		for z in range(at.z - 16, at.z + 17, 8):
			main.chunks.on_cell_changed(Vector3i(x, at.y, z))


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


## Hollows a room seven cells across and two high in the rock with its floor at `at`
## (kept in wall_cells to be filled again): a cave round the player.
func room(w, at: Vector3i) -> void:
	for z in range(at.z - 3, at.z + 4):
		for x in range(at.x - 3, at.x + 4):
			for y in range(at.y, at.y + 2):
				wall_cells.append([Vector3i(x, y, z), w.get_cell(x, y, z), w.is_natural(x, y, z)])
				w.set_cell(x, y, z, Mat.AIR)
	wall_changed(Vector3i(at.x, at.y, at.z))
	main.roof.build(w)


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
			Growth.place_bush(w, at.x + dx, h, at.z + 10 + (k % 2), k % Bushes.TYPES.size())
			k += 1
		for dx in [-9, -7, 7, 9]:
			Growth.place_bush(w, at.x + dx, h, at.z + 4 + absi(dx) % 3, Bushes.first(true, 1))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		# Oaks that go bare in winter and oaks that keep their leaves, in turn.
		for i in oaks.size():
			var x: int = (at.x + oaks[i]) | 1
			while Foliage.goes_bare(Vector2i(x, (at.z - 8) | 1), Trees.first(Trees.BROAD)) != (i % 2 == 0):
				x += 2
			Growth.place(w, x, h, (at.z - 8) | 1, Trees.first(Trees.BROAD), rng)
		var sizes := [0.75, 1.0, 1.2]
		for i in spruces.size():
			Growth.place(w, (at.x + spruces[i]) | 1, h, (at.z + 6) | 1, Trees.first(Trees.NEEDLES), rng, sizes[i])
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
		Growth.place(w, (at.x + (i - n / 2) * 11) | 1, h, (at.z - 8) | 1, i, rng, Growth.fit(i, w.size_y - h))
	var k := Bushes.TYPES.size()
	for i in k:
		Growth.place_bush(w, at.x + (i - k / 2) * 6, h, at.z + 5 + (i % 2), i)
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
		Growth.place(w, (at.x + (i * 2 - species.size() + 1) * 11) | 1, h, (at.z - 6) | 1, kind, rng, Growth.fit(kind, w.size_y - h))
	for z in range(at.z - 32, at.z + 24, 8):
		for x in range(at.x - 44, at.x + 44, 8):
			main.chunks.on_cell_changed(Vector3i(x, h, z))
	# The player stands behind, in a gap between the crowns (none turns see-through),
	# so the row is in the middle of the picture.
	main.player.position = (Vector3(at.x + 11 * (species.size() % 2), h, at.z - 15) + Vector3(0.5, 0.0, 0.5)) * CELL


## A flat clearing at `at` (level of the ground there) with an oak west of the player
## and a spruce east of them, grown afresh each time; `fell` fells both away from the
## player a cell above their feet, as the axe would. With `bank` the ground behind them
## stands a level higher, as a river's bank does, and wraps round the oak's west side
## and the spruce's east side: their feet stand against it.
func clearing(w, at: Vector3i, fell: bool, species: Array = [], bank := false) -> void:
	var h: int = w.surface_y(at.x, at.z)
	for z in range(at.z - 24, at.z + 24):
		for x in range(at.x - 30, at.x + 30):
			var top := h
			if bank and (z < (at.z - 3) | 1 or z == (at.z - 3) | 1 and (x < ((at.x - 7) | 1) or x > ((at.x + 7) | 1))):
				top = h + 1
			for y in w.size_y:
				var m := Mat.AIR
				if y < top:
					m = Mat.GRASS if y == top - 1 else Mat.DIRT
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
	Growth.place(w, oak.x, h, oak.y, west, rng, minf(1.0, Growth.fit(west, w.size_y - h)))
	Growth.place(w, spruce.x, h, spruce.y, east, rng, minf(0.8, Growth.fit(east, w.size_y - h)))
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


## A spot near `at` (world units) by the tallest slope turned to the camera within 60
## cells: the ground going down southward a level a cell at most, 5 cells along.
func steep(w, at: Vector3) -> Vector3:
	var c0 := Vector2i(int(at.x / CELL), int(at.z / CELL))
	var best := -1
	var spot := c0
	for dz in range(-60, 60):
		for dx in range(-60, 60):
			var x := c0.x + dx
			var z := c0.y + dz
			var ok := true
			for k in 4:
				var d: int = w.surface_y(x, z - 2 + k) - w.surface_y(x, z - 1 + k)
				ok = ok and d >= 0 and d <= 1
			var drop: int = w.surface_y(x, z - 2) - w.surface_y(x, z + 2)
			if ok and drop > best:
				best = drop
				spot = Vector2i(x, z)
	main.player.position = Vector3(spot.x + 0.5, w.surface_y(spot.x, spot.y) + 1, spot.y + 0.5) * CELL
	main.chunks.build_around()
	return main.player.position

