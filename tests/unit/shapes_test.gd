extends "res://tests/unit/test_case.gd"
## The shapes of natural ground (slopes, their split, cut and filled corners) against
## the rules written out one cell at a time.


## The reference cuts worked out lately (see _ref_cut), emptied before each look.
var _cuts := {}


func run() -> void:
	_test_corners()
	_test_shapes()
	_test_soft()


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
	_check(w.corner_cut(4, 2, 3, 1) and w.corner_cut(6, 2, 5, 1) and not w.corner_fill(6, 2, 4, 2),
		"the corners round a notch are cut along one diagonal, not cut and filled into a saw")
	_check(is_equal_approx(w.ground_height(3.05, 3.05), 1.0) and is_equal_approx(w.ground_height(3.4, 3.4), 1.0)
		and is_equal_approx(w.ground_height(3.6, 3.6), 3.0), "a cut corner leaves the half of the cell beyond its diagonal open")
	_check(is_equal_approx(w.ground_height(5.1, 4.9), 3.0), "a filled corner is ground up to the cliff top")
	var player = PlayerScript.new()
	player.body.world = w
	_check(not player.body._collides(Vector3(2.6, 1.0, 2.6)) and player.body._collides(Vector3(3.3, 1.0, 3.3)),
		"a walker fits into a cut corner but not into the cliff")
	_check(player.body._collides(Vector3(5.6, 1.0, 4.55)) and not player.body._collides(Vector3(5.9, 1.0, 3.8)),
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


## Soft slopes (world setting slopes 1): no slope steeper than 45 degrees and no post
## at the tip of a ridge a cell wide. Dirt on a stone floor: a ridge a cell high along x
## 2..6 at z 1, a block two high at x, z 4..9.
func _test_soft() -> void:
	var w := WorldData.new(6, Vector2i(12, 12))
	w.soft_slopes = true
	var c: WorldData.Chunk = w.chunks[Vector2i.ZERO]
	c.natural.fill(WorldData.WILD)
	for z in 12:
		for x in 12:
			c.cells[z * 16 + x] = Mat.STONE
			var h := 1 if z == 1 and x >= 2 and x <= 6 else (2 if x >= 4 and x <= 9 and z >= 4 and z <= 9 else 0)
			for y in range(1, h + 1):
				c.cells[(y * 16 + z) * 16 + x] = Mat.DIRT
	w.rebuild_columns()
	w.refresh_shapes()
	_check(w._shape(6, 1, 1) & 15 == WorldData.NE | WorldData.SE and w._shape(2, 1, 1) & 15 == WorldData.NW | WorldData.SW,
		"soft slopes: the tips of a ridge a cell wide ramp down to their ends")
	_check(w._shape(4, 1, 1) & 15 == 0, "soft slopes: the ridge between its tips stays level")
	_check(w._shape(6, 2, 4) & 15 == 0 and w._shape(4, 2, 6) & 15 == 0,
		"soft slopes: no slope over a drop of two levels (it would be steeper than 45 degrees)")
	_check(w.corner_cut(4, 2, 4, 0), "soft slopes: the corner of a cliff two high is cut on the diagonal")


## The shapes the world works out a column at a time match the rules written out for
## one cell at a time (below), on a generated world and after digging and building.
func _test_shapes() -> void:
	var land := _land(7)
	var g: WorldData = land.world
	var keys: Array = land.area
	var from: Vector2i = keys[0] * 16
	var to: Vector2i = keys[keys.size() - 1] * 16 + Vector2i(16, 16)
	_check(_shapes_match(g, from, to), "shapes of a generated world follow the rules")
	_check(_patches_match(g, from, to), "the mesher's slope surfaces are those the walkers stand on")
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
	_cuts.clear()
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
	var inside := WorldData.corners_at(fx, fz)
	for y in range(w.size_y - 1, -1, -1):
		var m := w.get_cell(cx, y, cz)
		if m == Mat.AIR or m == Mat.LEAVES or m == Mat.WATER:
			if m != Mat.LEAVES and w.corner_fills(cx, y, cz) & inside:
				return y + 1.0
			if m == Mat.WATER:
				return y + 1.0 if w.water_frozen else -1.0
			continue
		var cut := w.corner_cuts(cx, y, cz) & inside
		if cut:
			var o: Vector2i = WorldData.CORNER_DIRS[WorldData.level_of(cut)]
			if w.get_cell(cx + o.x, y, cz) == Mat.WATER and not w.water_frozen:
				return -1.0
			continue
		var mask := w.slope_mask(cx, y, cz)
		if mask == WorldData.FULL:
			return y + 1.0
		return y + _ref_height(WorldData.FULL & ~mask, _ref_split(w, cx, y, cz), fx, fz)
	return 0.0


## Height of a top with low corners `lows` split as `ne_sw` says at (fx, fz): on the
## plane through the three corners of the triangle the point is in.
func _ref_height(lows: int, ne_sw: bool, fx: float, fz: float) -> float:
	var corners: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var tri: Array
	if ne_sw:
		tri = [0, 1, 3] if fx + fz <= 1.0 else [1, 2, 3]
	else:
		tri = [0, 1, 2] if fx >= fz else [0, 2, 3]
	var pts := []
	for k: int in tri:
		pts.append(Vector3(corners[k].x, 0.0 if lows & (1 << k) else 1.0, corners[k].y))
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0])
	return pts[0].y - (n.x * (fx - pts[0].x) + n.z * (fz - pts[0].z)) / n.y


## The diagonal a top is split along (see WorldData.split_ne_sw), from its corners and
## the slopes beside it.
func _ref_split(w: WorldData, x: int, y: int, z: int) -> bool:
	var cut := w.corner_cuts(x, y, z)
	if cut == 0:
		cut = w.corner_cuts(x, y + 1, z)
	if cut != 0:
		return cut & (WorldData.NW | WorldData.SE) != 0
	var lows := WorldData.FULL & ~w.slope_mask(x, y, z)
	var odd := -1
	for k in 4:
		var others := 0
		for j in 4:
			if j != k and (lows & (1 << j) != 0) != (lows & (1 << k) != 0):
				others += 1
		if others == 3:
			odd = k
	if odd < 0:
		return lows == WorldData.NW | WorldData.SE
	var o: Vector2i = WorldData.CORNER_DIRS[odd]
	var ramp := false
	for n: Vector2i in [Vector2i(o.x, 0), Vector2i(0, o.y)]:
		var nl := WorldData.FULL & ~w.slope_mask(x + n.x, y, z + n.y)
		if w.corner_cuts(x + n.x, y, z + n.y) == 0 and w.corner_fills(x + n.x, y, z + n.y) == 0 \
				and nl in [WorldData.NW | WorldData.NE, WorldData.SE | WorldData.SW, WorldData.NW | WorldData.SW,
				WorldData.NE | WorldData.SE]:
			ramp = true
	# A hip or valley creases through the odd corner, a chamfer across it.
	return ramp != (odd == 0 or odd == 2)


## True when the mesher builds the same surface for every sloping top of the columns
## from..to as the walkers stand on, and some tops are hips or valleys and some
## chamfers.
func _patches_match(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	var c := w.padded(false, Mat.STONE, from.x - 2, from.y - 2, to.x + 2, to.y + 2)
	var sh := w.padded(true, 0, from.x - 2, from.y - 2, to.x + 2, to.y + 2)
	var dz := to.x - from.x + 4
	var dy := dz * (to.y - from.y + 4)
	var steps := Vector2i(4, 4)
	var odd := [0, 0]
	for y in w.size_y:
		for z in range(from.y, to.y):
			for x in range(from.x, to.x):
				if w.slope_mask(x, y, z) == WorldData.FULL or not w.get_cell(x, y + 1, z) in [Mat.AIR, Mat.WATER]:
					continue
				var i := (y + 1) * dy + (z - from.y + 2) * dz + x - from.x + 2
				var hs := SlopeMesher.surface_grid(c, sh, i, dy, dz, steps)
				var lows := WorldData.FULL & ~w.slope_mask(x, y, z)
				var ne_sw := _ref_split(w, x, y, z)
				if SlopeMesher.split(sh, i, dz) != ne_sw or w.split_at(x, y, z) != ne_sw:
					printerr("split differs at %s" % Vector3i(x, y, z))
					return false
				for b in 5:
					for a in 5:
						var want := _ref_height(lows, ne_sw, a / 4.0, b / 4.0)
						if not is_equal_approx(hs[b * 5 + a], want) \
								or not is_equal_approx(w.surface_height(x, y, z, a / 4.0, b / 4.0), want):
							printerr("surface differs at %s: %s / %s" % [Vector3i(x, y, z), hs[b * 5 + a], want])
							return false
				if lows in [1, 2, 4, 8, 7, 11, 13, 14] and w.corner_cuts(x, y, z) == 0:
					var hip := ne_sw != (lows in [WorldData.NW, WorldData.SE, WorldData.FULL & ~WorldData.NW,
						WorldData.FULL & ~WorldData.SE])
					odd[0 if hip else 1] += 1
	if odd[0] == 0 or odd[1] == 0:
		printerr("hips or valleys, chamfers: %s" % [odd])
	return odd[0] > 0 and odd[1] > 0


## True when the shapes of the columns from..to follow the rules.
func _shapes_match(w: WorldData, from: Vector2i, to: Vector2i) -> bool:
	_cuts.clear()
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


## Slope mask of a cell (corners at full height): loose wild ground with open air or
## water above loses both corners of each side where the ground is a level lower, and
## a corner where only the column across it is lower and both beside it may slope; a
## top with every corner down stays whole.
func _ref_slope(w: WorldData, x: int, y: int, z: int) -> int:
	if not _ref_can_slope(w, x, y, z) and not _ref_floor(w, x, y, z):
		return WorldData.FULL
	return _ref_lows(w, x, y, z)


## The slope of an open top (not the ground under a cut): what cuts and fills look at.
func _ref_top(w: WorldData, x: int, y: int, z: int) -> int:
	return _ref_lows(w, x, y, z) if _ref_can_slope(w, x, y, z) else WorldData.FULL


func _ref_lows(w: WorldData, x: int, y: int, z: int) -> int:
	var low := 0
	for k in 4:
		var o: Vector2i = WorldData.CORNER_DIRS[k]
		if _ref_low(w, x + o.x, y, z) or _ref_low(w, x, y, z + o.y) or _ref_low(w, x + o.x, y, z + o.y) \
				and _ref_can_slope(w, x + o.x, y, z) and _ref_can_slope(w, x, y, z + o.y):
			low |= 1 << k
	return WorldData.FULL if low == WorldData.FULL else WorldData.FULL & ~low


## Loose wild ground under the lowest of a run of cut cells, not cut itself: its top
## shows in the cut and slopes as an open top would.
func _ref_floor(w: WorldData, x: int, y: int, z: int) -> bool:
	if not (w.in_bounds(x, y, z) and w.is_natural(x, y, z) and Mat.can_slope(w.get_cell(x, y, z))) \
			or y + 1 >= w.size_y:
		return false
	var above := false
	for k in 4:
		above = above or _ref_cut(w, x, y + 1, z, k)
		if _ref_cut(w, x, y, z, k):
			return false
	return above


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


func _ref_open(w: WorldData, x: int, y: int, z: int) -> bool:
	return w.chunk_at(x, z) != null and w.get_cell(x, y, z) in [Mat.AIR, Mat.WATER]


func _ref_cut_here(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = WorldData.CORNER_DIRS[k]
	var a := w.get_cell(x + o.x, y, z)
	if a != Mat.AIR and a != Mat.WATER or w.get_cell(x, y, z + o.y) != a or w.get_cell(x + o.x, y, z + o.y) != a:
		return false
	if not (_ref_ground(w, x, y, z) and w.is_natural(x, y, z) and w.is_natural(x + o.x, y, z) \
			and w.is_natural(x, y, z + o.y) and w.is_natural(x + o.x, y, z + o.y)):
		return false
	var mask := _ref_top(w, x, y, z)
	if mask == WorldData.FULL:
		return true
	# A slope: only at a low corner, where the ground drops further than a level beside.
	var drop := false
	for n: Vector2i in [Vector2i(o.x, 0), Vector2i(0, o.y), o]:
		drop = drop or not _ref_low(w, x + n.x, y, z + n.y)
	return mask & (1 << k) == 0 and drop


func _ref_cut_any(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	while _ref_cut_here(w, x, y, z, k):
		var above := w.get_cell(x, y + 1, z)
		if above == Mat.AIR or above == Mat.WATER or above == Mat.LEAVES:
			return true
		y += 1
	return false


## Cut at corner k and at no other corner (remembered in _cuts until the world changes).
func _ref_cut(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var key := Vector4i(x, y, z, k)
	if _cuts.has(key):
		return _cuts[key]
	var out := _ref_cut_any(w, x, y, z, k)
	for j in 4:
		if out and j != k and _ref_cut_any(w, x, y, z, j):
			out = false
	_cuts[key] = out
	return out


func _ref_fill_here(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	var o: Vector2i = WorldData.CORNER_DIRS[k]
	var m := w.get_cell(x, y, z)
	if m != Mat.AIR and m != Mat.WATER:
		return false
	# A side open round its corner facing this cell.
	for n: Vector2i in [Vector2i(-o.x, 0), Vector2i(0, -o.y)]:
		var b := Vector2i(x, z) + n
		var e := b + (Vector2i(0, o.y) if n.x != 0 else Vector2i(o.x, 0))
		if w.get_cell(b.x, y, b.y) == m and w.get_cell(e.x, y, e.y) == m and _ref_open(w, b.x, y, b.y) \
				and _ref_open(w, e.x, y, e.y):
			return false
	return _ref_ground(w, x + o.x, y, z) and _ref_ground(w, x, y, z + o.y) and _ref_ground(w, x + o.x, y, z + o.y) \
		and w.is_natural(x, y, z) and w.is_natural(x + o.x, y, z) and w.is_natural(x, y, z + o.y) \
		and w.is_natural(x + o.x, y, z + o.y) and _ref_top(w, x + o.x, y, z) == WorldData.FULL \
		and _ref_top(w, x, y, z + o.y) == WorldData.FULL


func _ref_fill_any(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	while _ref_fill_here(w, x, y, z, k):
		var below := w.get_cell(x, y - 1, z)
		if below != Mat.AIR and below != Mat.WATER and below != Mat.LEAVES:
			return true
		y -= 1
	return false


## Filled at corner k and at no other corner.
func _ref_fill(w: WorldData, x: int, y: int, z: int, k: int) -> bool:
	if not _ref_fill_any(w, x, y, z, k):
		return false
	for j in 4:
		if j != k and _ref_fill_any(w, x, y, z, j):
			return false
	return true
