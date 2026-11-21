extends "res://tests/unit/test_case.gd"
## The slopes of natural ground (curved patches, corners going down two levels, corners
## cut half a cell along each side) against the rules written out one cell at a time.

const OldSlopeMesher := preload("res://src/client/world/old_slope_mesher.gd")


func run() -> void:
	_test_corners()
	_test_diagonal_ridge()
	_test_diagonal_shore()
	_test_shapes()


## Wild stone floor with a two-level wild stone block at x, z 3..6 missing its
## north-east quarter (x 5..6, z 3..4), so it has outer corners and one inner corner.
func _corner_world() -> WorldData:
	var w := WorldData.new(6, Vector2i(10, 10))
	var c: WorldData.Chunk = w.chunks[Vector2i.ZERO]
	c.natural.fill(WorldData.WILD)
	for z in 10:
		for x in 10:
			c.cells[z * 16 + x] = Mat.STONE
			if x >= 3 and x <= 6 and z >= 3 and z <= 6 and not (x >= 5 and z <= 4):
				for y in range(1, 3):
					c.cells[(y * 16 + z) * 16 + x] = Mat.STONE
	w.rebuild_columns()
	return w


func _test_corners() -> void:
	var w := _corner_world()
	_check(w.corner_cut(3, 2, 3, 0) and w.corner_cut(3, 1, 3, 0), "an outer corner of a cliff is cut on every level")
	_check(not w.corner_cut(4, 2, 3, 0) and not w.corner_cut(3, 2, 3, 2), "straight edges and inner sides are not cut")
	_check(w.corner_fill(5, 1, 4, 3) and w.corner_fill(5, 2, 4, 3), "an inner corner is filled on every level")
	_check(w.corner_fills(5, 3, 4) == 0, "nothing is filled above the cliff")
	_check(is_equal_approx(w.ground_height(3.05, 3.05), 1.0) and is_equal_approx(w.ground_height(3.4, 3.4), 3.0),
		"a cut corner leaves the ground below it open")
	_check(is_equal_approx(w.ground_height(5.1, 4.9), 3.0), "a filled corner is ground up to the cliff top")
	var player = PlayerScript.new()
	player.body.world = w
	_check(not player.body._collides(Vector3(2.6, 1.0, 2.6)) and player.body._collides(Vector3(3.05, 1.0, 3.05)),
		"a walker fits into a cut corner but not into the cliff")
	_check(player.body._collides(Vector3(5.6, 1.0, 4.55)) and not player.body._collides(Vector3(5.9, 1.0, 4.0)),
		"a filled corner blocks a walker")
	var meshes: Array = ChunkMesher.build_chunk(w, 0, 0, 16)
	var normals: PackedVector3Array = (meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var diagonal := false
	for n in normals:
		diagonal = diagonal or (absf(n.x) > 0.6 and absf(n.z) > 0.6 and absf(n.y) < 0.01)
	_check(diagonal, "cut and filled corners get diagonal walls")
	# Placed blocks keep their corners.
	w.set_cell(3, 2, 3, Mat.STONE)
	_check(not w.corner_cut(3, 2, 3, 0) and not w.corner_cut(3, 1, 3, 0), "placed blocks stay square")
	player.free()


## A ridge of dirt a level high and two cells wide on the diagonal (cells k, k and k,
## k + 1, k 2..7) on a dirt floor: no slope rising to a peak at each cell, but cubes cut
## at their corners, drawn straight along the diagonal and round only at the ends.
func _test_diagonal_ridge() -> void:
	var w := WorldData.new(6, Vector2i(12, 12))
	var c: WorldData.Chunk = w.chunks[Vector2i.ZERO]
	c.natural.fill(WorldData.WILD)
	for z in 12:
		for x in 12:
			c.cells[z * 16 + x] = Mat.DIRT
	for k in range(2, 8):
		for z: int in [k, k + 1]:
			c.cells[(16 + z) * 16 + k] = Mat.DIRT
	w.rebuild_columns()
	w.refresh_shapes()
	var peaks := 0
	for k in range(3, 7):
		peaks += int(w._shape(k, 1, k) & 15 != 0) + int(w._shape(k, 1, k + 1) & 15 != 0)
	_check(peaks == 0, "a ridge two cells wide on the diagonal stays cubes, no peak at each cell")
	_check(w.corner_cut(4, 1, 4, 1) and w.corner_fill(5, 1, 4, 3) and w.corner_cut(4, 1, 5, 3),
		"its sides are cut and filled on the diagonal")
	var round := Mat.corner_shape[Mat.DIRT]
	_check(round != 0, "dirt has round corners")
	_check(ChunkMesher._cap_shape(w, 4, 1, 4, 1, round) == 0 and ChunkMesher._cap_shape(w, 5, 1, 4, 3, round) == 0,
		"a cut and a fill going on along the diagonal are drawn straight")
	_check(ChunkMesher._cap_shape(w, 2, 1, 2, 0, round) == round, "the end of the ridge keeps its rounding")


## The shapes the world works out a column at a time match the rules written out for
## one cell at a time (below), on a generated world and after digging and building.
## A dirt shore on the diagonal (land where x + z >= 12 on level 1, water below that
## line, a dirt floor under it all): its outer and inner corners rise along the diagonal
## (WorldData.PATCH_DIAG), so the water's line runs straight through the middles of the
## cells' sides instead of in stairs; the same staircase on dry ground keeps its curves.
func _test_diagonal_shore() -> void:
	var worlds := []
	for wet in [true, false]:
		var w := WorldData.new(6, Vector2i(16, 16))
		var c: WorldData.Chunk = w.chunks[Vector2i.ZERO]
		c.natural.fill(WorldData.WILD)
		for z in 16:
			for x in 16:
				c.cells[z * 16 + x] = Mat.DIRT
				c.cells[(16 + z) * 16 + x] = Mat.DIRT if x + z >= 12 else (Mat.WATER if wet else Mat.AIR)
		w.rebuild_columns()
		w.refresh_shapes()
		worlds.append(w)
	var w: WorldData = worlds[0]
	# (6, 6) has water west, north and north-west: an outer corner, high in the south-east;
	# (7, 6) only the water north-west of it: an inner corner, low in the north-west.
	var outer := w.surface_patch(6, 1, 6)
	var inner := w.surface_patch(7, 1, 6)
	_check(outer.size() == WorldData.PATCH_DIAG + 1 and int(outer[WorldData.PATCH_DIAG]) == 2
		and inner.size() == WorldData.PATCH_DIAG + 1 and int(inner[WorldData.PATCH_DIAG]) == 4,
		"the corners of a shore on the diagonal rise along it")
	var straight := true
	for t in 5:
		var f := t / 4.0
		# The line half a cell from the odd corner: x + z = 1.5 on the outer, 0.5 on the inner.
		straight = straight and absf(WorldData.patch_height(outer, 0.5 + f * 0.5, 1.0 - f * 0.5) - 0.5) < 0.06
		straight = straight and absf(WorldData.patch_height(inner, f * 0.5, 0.5 - f * 0.5) - 0.5) < 0.06
	_check(straight, "the water meets a shore's corners on the diagonal")
	_check(WorldData.patch_height(outer, 0.4, 0.4) < 0.01 and WorldData.patch_height(inner, 0.9, 0.9) > 0.99,
		"past the diagonal a shore's corner is level with the corners beside")
	_check((worlds[1] as WorldData).surface_patch(6, 1, 6).size() == 12, "dry ground keeps its curved corners")
	var sides := true
	for z in range(3, 10):
		for x in range(3, 10):
			if w.slope_mask(x, 1, z) == WorldData.FULL:
				continue
			var p := w.surface_patch(x, 1, z)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if w.slope_mask(x + d.x, 1, z + d.y) == WorldData.FULL or w.get_cell(x + d.x, 1, z + d.y) != Mat.DIRT:
					continue
				var q := w.surface_patch(x + d.x, 1, z + d.y)
				for t in 5:
					var f := t / 4.0
					var a := WorldData.patch_height(p, 1.0, f) if d.x == 1 else WorldData.patch_height(p, f, 1.0)
					var b := WorldData.patch_height(q, 0.0, f) if d.x == 1 else WorldData.patch_height(q, f, 0.0)
					sides = sides and absf(a - b) < 0.001
	_check(sides, "a shore's corners meet the slopes beside them along the whole side")
	var c := w.padded(false, Mat.STONE, -2, -2, 18, 18)
	var sh := w.padded(true, 0, -2, -2, 18, 18)
	var dz := 16 + 4
	var dy := dz * (16 + 4)
	var same := true
	for z in range(3, 10):
		for x in range(3, 10):
			if w.slope_mask(x, 1, z) == WorldData.FULL:
				continue
			var a: PackedFloat32Array = OldSlopeMesher.patch(c, sh, 2 * dy + (z + 2) * dz + x + 2, dy, dz)
			same = same and a == w.surface_patch(x, 1, z)
	_check(same, "the mesher draws a shore's corners as the walkers stand on them")
	_test_flush_shore()


## A lake at the sea's level, whose water fills its cells flush with the land, on the same
## diagonal shore with one step two cells long ((6, 5) is land too, a straight bit of
## shore between two diagonals): its water lies wherever the ground of a shore is under
## its surface and nowhere the ground comes up to it, so the water's line is the same on
## a straight shore, on the diagonal and where one turns into the other (cut half a cell
## short on the diagonal, it went into sharp corners there, thread «Исправить
## диагональный берег»). The ground's grid bends along an inner corner's diagonal.
func _test_flush_shore() -> void:
	var w := WorldData.new(6, Vector2i(16, 16))
	w.sea_level = 1
	var c: WorldData.Chunk = w.chunks[Vector2i.ZERO]
	c.natural.fill(WorldData.WILD)
	for z in 16:
		for x in 16:
			c.cells[z * 16 + x] = Mat.DIRT
			c.cells[(16 + z) * 16 + x] = Mat.DIRT if x + z >= 12 or Vector2i(x, z) == Vector2i(6, 5) else Mat.WATER
	w.rebuild_columns()
	w.refresh_shapes()
	var meshes: Array = ChunkMesher.build_chunk(w, 0, 0, 16)
	var tris := _triangles(meshes[1])
	var ground := _triangles(meshes[0])
	var kinds := {}
	var wet := true
	var bent := true
	for z in range(2, 11):
		for x in range(2, 11):
			if w.get_cell(x, 1, z) != Mat.DIRT or w.slope_mask(x, 1, z) == WorldData.FULL:
				continue
			var p := w.surface_patch(x, 1, z)
			kinds[int(p[WorldData.PATCH_DIAG]) if p.size() > WorldData.PATCH_DIAG else -1] = true
			for b in 7:
				for a in 7:
					var u := (a + 0.5) / 7.0
					var v := (b + 0.5) / 7.0
					var h := WorldData.patch_height(p, u, v)
					if absf(h - 1.0) < 0.02:
						continue
					var q := Vector2(x + u, z + v)
					var drawn := false
					for t: PackedVector2Array in tris:
						drawn = drawn or _inside(q, t)
					if drawn != (h < 1.0):
						wet = false
			# No triangle of an inner corner's ground reaches across its diagonal.
			if p.size() > WorldData.PATCH_DIAG and int(p[WorldData.PATCH_DIAG]) >= 4:
				for t: PackedVector2Array in ground:
					var mid := (t[0] + t[1] + t[2]) / 3.0
					if floori(mid.x) != x or floori(mid.y) != z:
						continue
					var near := false
					var far := false
					for n in 3:
						var s := WorldData.diag_reach(p, t[n].x - x, t[n].y - z)
						near = near or s < 1.0 - 0.01
						far = far or s > 1.0 + 0.01
					bent = bent and not (near and far)
	_check(kinds.has(2) and kinds.has(4) and kinds.has(-1), "a lake's shore has outer, inner and straight bits")
	_check(wet, "water flush with the land lies wherever a shore's ground is under it, and only there")
	_check(bent, "the ground of a shore's inner corner bends along its diagonal")


## True when point `q` lies in triangle `t` or on its edges.
func _inside(q: Vector2, t: PackedVector2Array) -> bool:
	var d1 := (t[1] - t[0]).cross(q - t[0])
	var d2 := (t[2] - t[1]).cross(q - t[1])
	var d3 := (t[0] - t[2]).cross(q - t[2])
	var e := 1e-6
	return (d1 >= -e and d2 >= -e and d3 >= -e) or (d1 <= e and d2 <= e and d3 <= e)


## The triangles of a mesh's first surface seen from above, in cells.
func _triangles(mesh: ArrayMesh) -> Array:
	var out := []
	var arrays := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, idx.size(), 3):
		var t := PackedVector2Array()
		for n in 3:
			var v: Vector3 = vs[idx[i + n]] / WorldData.CELL
			t.append(Vector2(v.x, v.z))
		out.append(t)
	return out


func _test_shapes() -> void:
	var land := _land(7, {})
	var g: WorldData = land.world
	var keys: Array = land.area
	var from: Vector2i = keys[0] * 16
	var to: Vector2i = keys[keys.size() - 1] * 16 + Vector2i(16, 16)
	var store := preload("res://src/shared/world/world_store.gd")
	_check(store.world_dir(7, {"slopes": 1}) != store.world_dir(7, {}),
		"worlds of the slopes setting 0 and 1 keep their own folders (the setting no longer counts)")
	_check(_shapes_match(g, from, to), "shapes of a generated world follow the rules")
	_check(_patches_match(g, from, to), "the mesher's slope surfaces are those the walkers stand on")
	_check(_sides_meet(g, from, to), "slopes that share their corners meet along the whole side")
	var slopes := 0
	var cuts := 0
	var fills := 0
	for key: Vector2i in keys:
		var c: WorldData.Chunk = g.chunks[key]
		for col in WorldData.LAYER:
			slopes += int(c.sloped[col] != 0)
		for i in c.shapes.size():
			cuts += int(c.shapes[i] >= 16 and Mat.is_solid(c.cells[i]))
			fills += int(c.shapes[i] >= 16 and not Mat.is_solid(c.cells[i]))
	_check(slopes > 0 and cuts > 0 and fills > 0, "generated ground has slopes and cut and filled corners")
	_check(_ground_matches(g, from, to), "the ground a walker stands on is the one found level by level from the sky")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 300:
		var x := rng.randi_range(from.x, to.x - 1)
		var z := rng.randi_range(from.y, to.y - 1)
		var y := clampi(g.surface_y(x, z) + rng.randi_range(-2, 1), 0, g.size_y - 1)
		g.set_cell(x, y, z, [Mat.AIR, Mat.DIRT, Mat.STONE][i % 3])
	_check(_shapes_match(g, from, to), "shapes follow the rules after digging and building")
	_check(_ground_matches(g, from, to), "and so does the ground a walker stands on")


## True when WorldData.ground_height, which starts below the highest cells around,
## finds the same ground as a look down every level of the column from the top, at
## points all over the columns from..to, with the water open and frozen.
func _ground_matches(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ok := true
	for frozen in [false, true]:
		w.water_frozen = frozen
		for i in 3000:
			var x := rng.randf_range(from.x, to.x)
			var z := rng.randf_range(from.y, to.y)
			if w.ground_height(x, z) != _ground_from_sky(w, x, z):
				ok = false
	w.water_frozen = false
	return ok


func _ground_from_sky(w: WorldData, x: float, z: float) -> float:
	var cx := floori(x)
	var cz := floori(z)
	var fx := x - cx
	var fz := z - cz
	var k := WorldData.corner_at(fx, fz)
	var inside := WorldData.in_corner(k, fx, fx, fz, fz)
	for y in range(w.size_y - 1, -1, -1):
		var m := w.get_cell(cx, y, cz)
		if m == Mat.AIR or m == Mat.LEAVES or m == Mat.WATER:
			if inside and w.corner_fill(cx, y, cz, k):
				return y + 1.0
			if m == Mat.WATER:
				return y + 1.0 if w.water_frozen else -1.0
			continue
		if inside and w.corner_cut(cx, y, cz, k):
			var o: Vector2i = WorldData.CORNER_DIRS[k]
			if w.get_cell(cx + o.x, y, cz) == Mat.WATER and not w.water_frozen:
				return -1.0
			continue
		if w.slope_mask(cx, y, cz) == WorldData.FULL:
			return y + 1.0
		return y + w.surface_height(cx, y, cz, fx, fz)
	return 0.0


## True when the mesher builds the same surface for every sloping top of the columns
## from..to as the world does, and some slopes go down two levels.
func _patches_match(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	var c := w.padded(false, Mat.STONE, from.x - 2, from.y - 2, to.x + 2, to.y + 2)
	var sh := w.padded(true, 0, from.x - 2, from.y - 2, to.x + 2, to.y + 2)
	var dz := to.x - from.x + 4
	var dy := dz * (to.y - from.y + 4)
	var deep := 0
	for y in w.size_y:
		for z in range(from.y, to.y):
			for x in range(from.x, to.x):
				if w.slope_mask(x, y, z) == WorldData.FULL or not w.get_cell(x, y + 1, z) in [Mat.AIR, Mat.WATER]:
					continue
				var i := (y + 1) * dy + (z - from.y + 2) * dz + x - from.x + 2
				var a: PackedFloat32Array = OldSlopeMesher.patch(c, sh, i, dy, dz)
				var b: PackedFloat32Array = w.surface_patch(x, y, z)
				if a.size() != b.size():
					printerr("patch differs at %s: %s / %s" % [Vector3i(x, y, z), a, b])
					return false
				for k in a.size():
					if not is_equal_approx(a[k], b[k]):
						printerr("patch differs at %s: %s / %s" % [Vector3i(x, y, z), a, b])
						return false
				deep += int(w.corner_heights(x, y, z).has(-1))
	return deep > 0


## True when every two sloping tops side by side whose corners meet at both ends of
## the side they share have the same curve along it (no gap to see through).
func _sides_meet(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	var shared := 0
	for z in range(from.y, to.y - 1):
		for x in range(from.x, to.x - 1):
			var y := w.surface_y(x, z) - 1
			if not _ref_can_slope(w, x, y, z) or w.slope_mask(x, y, z) == WorldData.FULL:
				continue
			var p := w.surface_patch(x, y, z)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for dl in [0, -1, 1]:
					if not _ref_can_slope(w, x + d.x, y + dl, z + d.y):
						continue
					var q := w.surface_patch(x + d.x, y + dl, z + d.y)
					var a := PackedFloat32Array()
					var b := PackedFloat32Array()
					for t in 5:
						var f := t / 4.0
						a.append(WorldData.patch_height(p, 1.0, f) if d.x == 1 else WorldData.patch_height(p, f, 1.0))
						b.append((WorldData.patch_height(q, 0.0, f) if d.x == 1 else WorldData.patch_height(q, f, 0.0)) + dl)
					if absf(a[0] - b[0]) < 0.01 and absf(a[4] - b[4]) < 0.01:
						shared += 1
						for t in 5:
							if absf(a[t] - b[t]) > 0.01:
								printerr("sides differ at %s toward %s: %s / %s" % [Vector3i(x, y, z), d, a, b])
								return false
					break
	return shared > 0


## True when the shapes of the columns from..to follow the rules.
func _shapes_match(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	for y in w.size_y:
		for z in range(from.y, to.y):
			for x in range(from.x, to.x):
				var corners := 0
				var m := w.get_cell(x, y, z)
				for k in 4:
					if _ref_cut(w, x, y, z, k) or _ref_fill(w, x, y, z, k):
						corners |= 1 << k
				if w.slope_mask(x, y, z) != _ref_slope(w, x, y, z) \
						or w.corner_cuts(x, y, z) | w.corner_fills(x, y, z) != corners:
					printerr("shape differs at %s (%s): slope %d / %d, corners %d / %d" % [Vector3i(x, y, z), Mat.NAMES[m],
						w.slope_mask(x, y, z), _ref_slope(w, x, y, z), w.corner_cuts(x, y, z) | w.corner_fills(x, y, z), corners])
					return false
	return true


## Slope mask of a cell: its sloping top's, or for a covered cell the corners the
## slope above goes down into.
func _ref_slope(w: WorldData, x: int, y: int, z: int) -> int:
	var top := _ref_top_slope(w, x, y, z)
	return top if top != WorldData.FULL else WorldData.FULL & ~_ref_deep(w, x, y, z)


## Corners of the slope above covered cell (x, y, z) that go down into it: low there,
## and every other column around meets it a level lower, is a slope on its level low
## there and going down too, is open further down, or (east or west only) stands as
## high or higher (at least one meets it lower); the cells going down are wild ground
## of any material.
func _ref_deep(w: WorldData, x: int, y: int, z: int) -> int:
	var mask := _ref_top_slope(w, x, y + 1, z)
	if mask == WorldData.FULL or not _ref_deepable(w, x, y, z):
		return 0
	var out := 0
	for k in 4:
		if mask & (1 << k):
			continue
		var o: Vector2i = WorldData.CORNER_DIRS[k]
		var ok := true
		var lower := false
		for n: Vector2i in [Vector2i(o.x, 0), Vector2i(0, o.y), o]:
			var kk := k
			if n.x != 0:
				kk ^= 1
			if n.y != 0:
				kk = 3 - kk
			var nx := x + n.x
			var nz := z + n.y
			if w.get_cell(nx, y + 1, nz) in [Mat.AIR, Mat.WATER]:
				if w.get_cell(nx, y, nz) in [Mat.AIR, Mat.WATER]:
					# Open further down than the corner: no part in it unless its top is high.
					lower = lower or _ref_ground(w, nx, y - 1, nz) and _ref_top_slope(w, nx, y - 1, nz) & (1 << kk) != 0
				else:
					ok = ok and _ref_ground(w, nx, y, nz) and _ref_top_slope(w, nx, y, nz) & (1 << kk) == 0
					lower = true
			elif n.y != 0:
				# A column east or west as high or higher has no part in it.
				ok = ok and _ref_ground(w, nx, y + 1, nz) and _ref_top_slope(w, nx, y + 1, nz) & (1 << kk) == 0 \
					and _ref_deepable(w, nx, y, nz)
		if ok and lower:
			out |= 1 << k
	return out


func _ref_deepable(w: WorldData, x: int, y: int, z: int) -> bool:
	return w.in_bounds(x, y, z) and w.chunk_at(x, z).natural[y * WorldData.LAYER + WorldData.col_of(x, z)] == WorldData.WILD \
		and _ref_ground(w, x, y, z)


func _ref_top_slope(w: WorldData, x: int, y: int, z: int) -> int:
	if not _ref_can_slope(w, x, y, z):
		return WorldData.FULL
	var low := 0
	for k in 4:
		var o: Vector2i = WorldData.SIDES[k]
		if _ref_low(w, x + o.x, y, z + o.y):
			low |= 1 << k
	if low != 0:
		var high: int = WorldData.RAMPS[low]
		# One high corner with the column across it lower: a ridge on the diagonal stays a cube.
		for k in 4:
			var o: Vector2i = WorldData.CORNER_DIRS[k]
			if high == 1 << k and _ref_low(w, x + o.x, y, z + o.y):
				return WorldData.FULL
		return high
	var mask := WorldData.FULL
	for k in 4:
		var o: Vector2i = WorldData.CORNER_DIRS[k]
		if _ref_low(w, x + o.x, y, z + o.y) and _ref_can_slope(w, x + o.x, y, z) and _ref_can_slope(w, x, y, z + o.y):
			if mask != WorldData.FULL:
				return WorldData.FULL
			mask = WorldData.FULL & ~(1 << k)
	return mask


func _ref_can_slope(w: WorldData, x: int, y: int, z: int) -> bool:
	return w.in_bounds(x, y, z) and w.chunk_at(x, z).natural[y * WorldData.LAYER + WorldData.col_of(x, z)] == WorldData.WILD \
		and Mat.can_slope(w.get_cell(x, y, z)) and w.get_cell(x, y + 1, z) in [Mat.AIR, Mat.WATER]


func _ref_low(w: WorldData, x: int, y: int, z: int) -> bool:
	if w.chunk_at(x, z) == null:
		return false
	var m := w.get_cell(x, y, z)
	return (m == Mat.AIR or m == Mat.WATER) and w.get_cell(x, y - 1, z) != Mat.AIR


func _ref_ground(w: WorldData, x: int, y: int, z: int) -> bool:
	var m := w.get_cell(x, y, z)
	return m != Mat.AIR and m != Mat.WATER and m != Mat.LEAVES and m != Mat.LOG


func _ref_cut_here(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = WorldData.CORNER_DIRS[k]
	var a := w.get_cell(x + o.x, y, z)
	if a != Mat.AIR and a != Mat.WATER or w.get_cell(x, y, z + o.y) != a or w.get_cell(x + o.x, y, z + o.y) != a:
		return false
	# Not over an open cell (a cave under a thin roof), unless the three columns beside
	# are open from the level under it up to the sky (an overhang's roof).
	if not _ref_ground(w, x, y - 1, z):
		var b := w.get_cell(x + o.x, y - 1, z)
		if b != Mat.AIR and b != Mat.WATER or w.get_cell(x, y - 1, z + o.y) != b \
				or w.get_cell(x + o.x, y - 1, z + o.y) != b:
			return false
		for p: Vector2i in [Vector2i(o.x, 0), Vector2i(0, o.y), o]:
			for yy in range(y - 1, w.size_y):
				if _ref_ground(w, x + p.x, yy, z + p.y):
					return false
	if not (_ref_ground(w, x, y, z) and w.is_natural(x, y, z) and w.is_natural(x + o.x, y, z) \
			and w.is_natural(x, y, z + o.y) and w.is_natural(x + o.x, y, z + o.y)):
		return false
	var mask := _ref_top_slope(w, x, y, z)
	return mask == WorldData.FULL or mask & (1 << k) == 0 and _ref_deep(w, x, y - 1, z) & (1 << k) == 0


func _ref_cut(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	while _ref_cut_here(w, x, y, z, k):
		var above := w.get_cell(x, y + 1, z)
		if above == Mat.AIR or above == Mat.WATER or above == Mat.LEAVES:
			return true
		y += 1
	return false


func _ref_fill_here(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = WorldData.CORNER_DIRS[k]
	var m := w.get_cell(x, y, z)
	if m != Mat.AIR and m != Mat.WATER:
		return false
	return _ref_ground(w, x + o.x, y, z) and _ref_ground(w, x, y, z + o.y) and _ref_ground(w, x + o.x, y, z + o.y) \
		and w.is_natural(x, y, z) and w.is_natural(x + o.x, y, z) and w.is_natural(x, y, z + o.y) \
		and w.is_natural(x + o.x, y, z + o.y) and _ref_top_slope(w, x + o.x, y, z) == WorldData.FULL \
		and _ref_top_slope(w, x, y, z + o.y) == WorldData.FULL


func _ref_fill(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	while _ref_fill_here(w, x, y, z, k):
		var below := w.get_cell(x, y - 1, z)
		if below != Mat.AIR and below != Mat.WATER and below != Mat.LEAVES:
			return true
		y -= 1
	return false
