extends SceneTree
## Finds the places of a patch of land a body falls into but cannot walk out of:
## godot --headless --path . --script res://tools/escape_map.gd -- [cells] [seed] [place] [settings] [file.png]
## `place` is "x,z", a find_place name ("gorge", "canyon", "cave"…) or "-" for the
## spawn; `settings` "key=value,…" as on the «New world» screen. A body stands where two
## cells are open (air or leaves) over ground or water; it walks to a column beside at
## its level or lower (falling) and up one level (a jump, with a cell of room over its
## head). A stand it can reach from the patch's edge but from which it cannot get back
## to the edge is a trap. Prints the traps grouped into pits (stands joined across),
## each with its size, its lowest and highest level and where it lies; with a file,
## draws the patch from above, the traps red, cave stands dark, the rest by height.
## With ESC_EDGES set, also prints where trapped stands border stands that get out.

const Mat := preload("res://src/shared/content/materials.gd")
const WorldGen := preload("res://src/shared/world/world_gen.gd")
const WorldData := preload("res://src/shared/world/world_data.gd")

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cells: int = int(args[0]) if args.size() > 0 else 192
	var seed_value: int = int(args[1]) if args.size() > 1 else 20261018
	var options := {}
	if args.size() > 3 and args[3] != "-":
		for kv in args[3].split(","):
			options[kv.get_slice("=", 0)] = int(kv.get_slice("=", 1))
	var gen := WorldGen.new(seed_value, 48, options)
	var at := Vector2i(gen.spawn_guess.x, gen.spawn_guess.z)
	if args.size() > 2 and args[2].contains(","):
		at = Vector2i(int(args[2].get_slice(",", 0)), int(args[2].get_slice(",", 1)))
	elif args.size() > 2 and args[2] != "-":
		at = gen.find_place(args[2], at)
	var traps := find(gen, at, cells)
	var open := 0
	for p: Dictionary in traps.pits:
		open += 0 if p.roofed else p.size
	print("patch %d cells round %s: %d stands (%d in caves reached), %d trapped in %d pits, %d of them open to the sky" % [
		cells, at, traps.stands, traps.caves, traps.trapped, traps.pits.size(), open])
	for p: Dictionary in traps.pits.slice(0, 30):
		print("  pit of %d stands at x %d z %d, levels %d..%d, %s" % [p.size, p.at.x, p.at.z, p.low, p.high,
			"under a roof" if p.roofed else "open to the sky"])
	for e: Array in traps.entries.slice(0, 12):
		print("  in from %s to %s" % e)
	if args.size() > 4:
		traps.picture.save_png(args[4])
	quit()


## The traps of the patch `cells` wide round `at` (see the script's header): a dictionary
## of `stands`, `caves` (stands under a roof reached from the edge), `trapped`,
## `trapcells` (each trapped stand, x, level, z), `pits` (largest first: size, at, low,
## high, roofed), `entries` (stand outside, stand inside) and a `picture`.
static func find(gen: WorldGen, at: Vector2i, cells: int) -> Dictionary:
	var x0 := at.x - cells / 2
	var z0 := at.y - cells / 2
	gen.generate_area(WorldData.chunk_key(x0, z0), WorldData.chunk_key(x0 + cells - 1, z0 + cells - 1))
	var w := gen.world
	var sy: int = w.size_y
	var n := cells * cells * sy
	# 0 open, 1 ground, 2 water.
	var kind := PackedByteArray()
	kind.resize(n)
	for z in cells:
		for x in cells:
			for y in sy:
				var m: int = w.get_cell(x0 + x, y, z0 + z)
				var k := 0
				if m == Mat.WATER:
					k = 2
				elif m != Mat.LEAVES and Mat.is_solid(m):
					k = 1
				kind[(y * cells + z) * cells + x] = k
	var stand := PackedByteArray()
	stand.resize(n)
	var count := 0
	for z in cells:
		for x in cells:
			for y in range(1, sy - 1):
				var i := (y * cells + z) * cells + x
				if kind[i] == 0 and kind[i + cells * cells] == 0 and kind[i - cells * cells] != 0:
					stand[i] = 1
					count += 1
	# Forward from the edge: what a body coming in can reach; backward: what can get out.
	var reach := _spread(kind, stand, cells, sy, false)
	var out := _spread(kind, stand, cells, sy, true)
	# Stands under a roof a body walks into from the edge: the caves one can visit.
	var caves := 0
	for i in n:
		if stand[i] and reach[i]:
			var y := i / (cells * cells)
			var col := i % (cells * cells)
			for yy in range(y + 2, sy):
				if kind[yy * cells * cells + col] == 1:
					caves += 1
					break
	var trapped := PackedByteArray()
	trapped.resize(n)
	var total := 0
	for i in n:
		if stand[i] and reach[i] and not out[i]:
			trapped[i] = 1
			total += 1
	# Pits: trapped stands joined across or up and down by one.
	var pits := []
	var seen := PackedByteArray()
	seen.resize(n)
	for i in n:
		if not trapped[i] or seen[i]:
			continue
		var todo := [i]
		seen[i] = 1
		var p := {"size": 0, "low": sy, "high": 0, "roofed": false, "at": Vector3i.ZERO}
		var sum := Vector2.ZERO
		while not todo.is_empty():
			var c: int = todo.pop_back()
			var y := c / (cells * cells)
			var z := (c / cells) % cells
			var x := c % cells
			p.size += 1
			p.low = mini(p.low, y)
			p.high = maxi(p.high, y)
			sum += Vector2(x, z)
			for yy in range(y + 2, sy):
				if kind[(yy * cells + z) * cells + x] == 1:
					p.roofed = true
					break
			for d: Vector2i in DIRS:
				var nx := x + d.x
				var nz := z + d.y
				if nx < 0 or nz < 0 or nx >= cells or nz >= cells:
					continue
				for dy in [-1, 0, 1]:
					var ny: int = y + dy
					if ny < 0 or ny >= sy:
						continue
					var j := (ny * cells + nz) * cells + nx
					if trapped[j] and not seen[j]:
						seen[j] = 1
						todo.append(j)
		var mid: Vector2 = sum / float(p.size)
		p.at = Vector3i(x0 + roundi(mid.x), 0, z0 + roundi(mid.y))
		pits.append(p)
	# Where a body walks into each trap from a stand that is not one (the first few).
	var entries := []
	var layer := cells * cells
	for c in n:
		if not stand[c] or trapped[c] or not reach[c]:
			continue
		var y := c / layer
		var z := (c / cells) % cells
		var x := c % cells
		for d: Vector2i in DIRS:
			var nx := x + d.x
			var nz := z + d.y
			if nx < 0 or nz < 0 or nx >= cells or nz >= cells:
				continue
			for ny in range(0, y + 2):
				var j := ny * layer + nz * cells + nx
				if trapped[j] and _walks(kind, layer, z * cells + x, nz * cells + nx, y, ny):
					entries.append([Vector3i(x0 + x, y, z0 + z), Vector3i(x0 + nx, ny, z0 + nz)])
	if OS.has_environment("ESC_EDGES"):
		var shown := 0
		for c in n:
			if not trapped[c] or shown > 12:
				continue
			var y := c / layer
			var z := (c / cells) % cells
			var x := c % cells
			for d: Vector2i in DIRS:
				var nx := x + d.x
				var nz := z + d.y
				if nx < 0 or nz < 0 or nx >= cells or nz >= cells:
					continue
				for ny in range(maxi(0, y - 1), mini(sy - 1, y + 2)):
					var j := ny * layer + nz * cells + nx
					if stand[j] and not trapped[j] and out[j]:
						print("edge %s -> %s walks %s" % [Vector3i(x0 + x, y, z0 + z), Vector3i(x0 + nx, ny, z0 + nz),
							_walks(kind, layer, z * cells + x, nz * cells + nx, y, ny)])
						shown += 1
	pits.sort_custom(func(a, b): return a.size > b.size)
	var trapcells := []
	for c in n:
		if trapped[c]:
			trapcells.append(Vector3i(x0 + c % cells, c / layer, z0 + (c / cells) % cells))
	return {"trapcells": trapcells, "stands": count, "caves": caves, "trapped": total, "pits": pits, "entries": entries, "picture": _picture(kind, stand, trapped, cells, sy)}


## Stands reached from the edge of the patch (`back` false) or from which the edge is
## reached (`back` true).
static func _spread(kind: PackedByteArray, stand: PackedByteArray, cells: int, sy: int, back: bool) -> PackedByteArray:
	var n := kind.size()
	var got := PackedByteArray()
	got.resize(n)
	var todo := PackedInt32Array()
	for z in cells:
		for x in cells:
			if x != 0 and z != 0 and x != cells - 1 and z != cells - 1:
				continue
			for y in sy:
				var i := (y * cells + z) * cells + x
				if stand[i]:
					got[i] = 1
					todo.append(i)
	var layer := cells * cells
	var head := 0
	while head < todo.size():
		var c := todo[head]
		head += 1
		var y := c / layer
		var z := (c / cells) % cells
		var x := c % cells
		for d: Vector2i in DIRS:
			var nx: int = x + d.x
			var nz: int = z + d.y
			if nx < 0 or nz < 0 or nx >= cells or nz >= cells:
				continue
			var col := nz * cells + nx
			# Every stand of the column beside that the step joins with this one.
			for ny in range(0, sy - 1):
				var j := ny * layer + col
				if not stand[j] or got[j]:
					continue
				var ok := _walks(kind, layer, col, z * cells + x, ny, y) if back else _walks(kind, layer, z * cells + x, col, y, ny)
				if ok:
					got[j] = 1
					todo.append(j)
	return got


## Whether a body standing at level `fy` of column `from` gets to the stand at level
## `ty` of column `to` beside it: up by one with room over its head, or across and down.
static func _walks(kind: PackedByteArray, layer: int, from: int, to: int, fy: int, ty: int) -> bool:
	if ty > fy + 1:
		return false
	if ty == fy + 1:
		return kind[(fy + 2) * layer + from] == 0 and kind[(fy + 2) * layer + to] == 0
	# Across at its own level, then down the column beside.
	for y in range(ty, fy + 2):
		if kind[y * layer + to] != 0:
			return false
	return true


static func _picture(kind: PackedByteArray, stand: PackedByteArray, trapped: PackedByteArray, cells: int, sy: int) -> Image:
	var img := Image.create(cells, cells, false, Image.FORMAT_RGB8)
	var layer := cells * cells
	for z in cells:
		for x in cells:
			var col := z * cells + x
			var top := 0
			var trap := false
			var cave := false
			for y in sy:
				if trapped[y * layer + col]:
					trap = true
			for y in range(sy - 1, -1, -1):
				if kind[y * layer + col] != 0:
					top = y
					break
			for y in range(1, top):
				if stand[y * layer + col]:
					cave = true
			var v := float(top) / sy
			var c := Color(v, v, v)
			if kind[top * layer + col] == 2:
				c = Color(0.2, 0.3, 0.6 + v * 0.4)
			if cave:
				c = c.darkened(0.5)
			if trap:
				c = Color(1.0, 0.1, 0.1)
			img.set_pixel(x, z, c)
	return img
