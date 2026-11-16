extends "res://src/client/world/mesh_faces.gd"
## Water in the chunk meshes: the surface with its shore, murk and depth colours,
## the water of cut corners, waterfalls with their sheet and foam, and the water
## on a shore that follows the slope under it. Called by ChunkMesher a column at a time.

const Slopes := preload("res://src/client/world/slope_mesher.gd")


## Water standing in the cut corners of padded cell `i` beside water with air above,
## up to the curve of corner shape `shape`.
static func cut_water(w, water, c: PackedByteArray, i: int, dy: int, base: Vector3, cuts: int, shape := 0) -> void:
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		if cuts & (1 << k) and c[i + o.x] == WATER and c[i + o.x + dy] == AIR:
			var depth := 1
			while depth < 8 and w.get_cell(int(base.x) + o.x, int(base.y) - depth, int(base.z)) == WATER:
				depth += 1
			var foam := 1 << (12 + k) | shape << (16 + 2 * k)
			var murk: int = w.murk(int(base.x) + o.x, int(base.y), int(base.z))
			var col := water_color(depth - WATER_TOP, 1.0, kind(false, murk / 2.0),
				w.sea(int(base.x) + o.x, int(base.y), int(base.z)))
			_piece(water, base, WATER_TOP, k, CORNER, Vector3.UP, col, Vector2(float(foam), float(depth)), shape)


## Foam bits of the water in padded cell `i`: the half edges (see HALF_CORNER) that
## touch land, not where the land beside has its corner cut and the water goes on, nor
## where the water goes on up the slope of a shore (see shore).
static func foam(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int) -> int:
	var foam := 0
	var shores := 0
	for e in 4:
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
		if cov[c[n]] and sh[n] & 15 != 0 and not cov[c[n + dy]] and shore(c, cov, n, dy, dz):
			shores |= 1 << e
	for h in 8:
		var e := h >> 1
		var n: int = i + (-dz if e == 0 else (dz if e == 1 else (-1 if e == 2 else 1)))
		if cov[c[n]] and sh[n] >> 4 & (1 << HALF_CORNER[h]) == 0 and shores & (1 << e) == 0:
			foam |= 1 << h
	return foam


## The sides a waterfall can face, in DIRS order, and for each the sides of the cell it
## lands in that its foam may spill over: [out, left, right] (left and right across it,
## left the lower x or z).
const FALL_DIRS := [0, 1, 4, 5]
const FALL_SIDES := [[0, 5, 4], [1, 5, 4], [4, 1, 0], [5, 1, 0]]
## How far the foam of a fall spills over the open water beside the cell it lands in,
## out along the fall and to each side, in cells.
const FOAM_OUT := 1.0
const FOAM_SIDE := 0.5


## Water falling over a step of a river from padded cell `i` (see WorldGen.FALL_STEP):
## a key for each side open to the air over lower water or ground, added to `keys` (the
## cell `lx`, `lz` from the chunk's corner and level `y`, the side, the drop, whether it
## lands in water and over which sides of that cell its foam spills, see fall_faces).
## They are drawn after the chunk's other water (ChunkMesher.step), so the foam and the
## spray lie over the pool they land in whichever of its cells came later.
static func falls(keys: PackedInt32Array, c: PackedByteArray, nb: PackedByteArray, side_offsets: PackedInt32Array,
		i: int, dy: int, lx: int, lz: int, y: int) -> void:
	if nb[2] != AIR:
		return
	for q in 4:
		var d: int = FALL_DIRS[q]
		if nb[d] != AIR:
			continue
		var n := i + side_offsets[d]
		var k := 1
		while k < 12 and c[n - k * dy] == AIR:
			k += 1
		var landing := n - k * dy
		var wet := c[landing] == WATER
		var spill := 0
		if wet:
			var sides: Array = FALL_SIDES[q]
			for e in 3:
				var o: int = landing + side_offsets[sides[e]]
				if c[o] == WATER and c[o + dy] == AIR:
					spill |= 1 << e
		keys.append((((((y * 8 + spill) * 2 + int(wet)) * 16 + k - 1) * 4 + q) << 12) | lz << 6 | lx)


## Draws the waterfalls of `keys` (see falls) of the chunk with its corner at `x0`, `z0`,
## from the `from`-th, `runs` of them; returns where it stopped. On each, a sheet slants
## out from the lip down to the water or ground below (so a fall to the east or west
## shows from above too); where it lands in water, foam on the pool, spilling over the
## open water beside, and an upright quad of spray and mist at its foot. They are marked
## by vertex alpha (FALL_SHEET, FALL_FOAM, FALL_SPRAY, see water.gdshader).
static func fall_faces(buf, faces: Array, keys: PackedInt32Array, x0: int, z0: int, from := 0,
		runs := 1 << 30) -> int:
	var j := from
	var n := keys.size()
	while j < n and runs > 0:
		runs -= 1
		var key := keys[j]
		j += 1
		var q := key >> 12 & 3
		var k := (key >> 14 & 15) + 1
		var wet := (key >> 18 & 1) == 1
		var spill := key >> 19 & 7
		var base := Vector3(x0 + (key & 63), key >> 22, z0 + (key >> 6 & 63))
		var d: int = FALL_DIRS[q]
		var foot := base.y - k + (WATER_TOP if wet else 1.0)
		var out := Vector3(DIRS[d])
		var size := Vector3(1.0, WATER_TOP - (foot - base.y), 1.0)
		var lift := Vector3(0.0, foot - base.y, 0.0)
		var face: Dictionary = faces[d]
		var pts := []
		var uvs := []
		for corner: Vector3 in face.corners:
			var v: Vector3 = lift + corner * size
			pts.append(base + v + out * (0.04 if corner.y > 0.5 else FALL_SPREAD))
			uvs.append(face_uv(d, v))
		# UV2: the levels of its lip and of its foot.
		buf.quad(pts, (face.normal + Vector3.UP * FALL_SPREAD / size.y).normalized(), uvs, Color(0, 1, 0, FALL_SHEET),
			Vector2(base.y + WATER_TOP, foot))
		if wet:
			_fall_foam(buf, faces, base + out + Vector3(0.0, -k, 0.0), out, spill)
			_fall_spray(buf, base + out + Vector3(0.0, -k, 0.0), out, k, float((key & 4095) % 97))
	return j


## The foam on the pool cell at `cell` (its corner) a fall towards `out` lands in, spilling
## over the sides of `spill` (see falls). UV: cells along the fall from the step and
## across the cell; UV2: where the patch ends along it, and which sides spill (1 left,
## 2 right), for its ragged edge.
static func _fall_foam(buf, faces: Array, cell: Vector3, out: Vector3, spill: int) -> void:
	var far := 1.0 + (FOAM_OUT if spill & 1 else 0.0)
	var left := -FOAM_SIDE if spill & 2 else 0.0
	var right := 1.0 + (FOAM_SIDE if spill & 4 else 0.0)
	# The patch in the cell's own x and z.
	var along := Vector2(0.0, far) if out.x + out.z > 0.0 else Vector2(1.0 - far, 1.0)
	var lo := Vector2(along.x, left) if out.x != 0.0 else Vector2(left, along.x)
	var hi := Vector2(along.y, right) if out.x != 0.0 else Vector2(right, along.y)
	var pts := []
	var uvs := []
	for corner: Vector3 in faces[FACE_TOP].corners:
		var x := lerpf(lo.x, hi.x, corner.x)
		var z := lerpf(lo.y, hi.y, corner.z)
		pts.append(cell + Vector3(x, WATER_TOP + 0.02, z))
		var a := x if out.x > 0.0 else (1.0 - x if out.x < 0.0 else (z if out.z > 0.0 else 1.0 - z))
		uvs.append(Vector2(a, z if out.x != 0.0 else x))
	buf.quad(pts, Vector3.UP, uvs, Color(0, 1, 0, FALL_FOAM), Vector2(far, float(spill >> 1)))


## The spray and mist over the foot of a fall of `k` levels towards `out` into the pool
## cell at `cell`: an upright quad turned to the camera by the shader, so all its corners
## lie at its root and UV holds each corner's offset from it in cells; UV2 its height in
## cells and a number of its own for the drops.
static func _fall_spray(buf, cell: Vector3, out: Vector3, k: int, seed: float) -> void:
	var root := cell + Vector3(0.5, WATER_TOP, 0.5) + out * (FALL_SPREAD - 0.4)
	var tall := minf(1.0 + 0.4 * k, SPRAY_HIGH)
	var pts := [root, root, root, root]
	var uvs := [Vector2(-SPRAY_HALF, 0.0), Vector2(-SPRAY_HALF, tall), Vector2(SPRAY_HALF, tall), Vector2(SPRAY_HALF, 0.0)]
	buf.quad(pts, Vector3.UP, uvs, Color(0, 1, 0, FALL_SPRAY), Vector2(tall, seed))


## Water: the top face carries foam bits (UV2.x: the half edges that touch land, then
## the filled corners, then the cut corners of the land beside, see water.gdshader) and
## the depth to the bottom in cells (UV2.y); `corners` are the vertex colours at the
## top's corners NW, NE, SE, SW (see water_color). Filled corners are left out of the
## top.
static func water_faces(buf, faces: Array, nb: PackedByteArray, base: Vector3, depth: int, foam: int,
		corners: PackedColorArray) -> void:
	if nb[0] != AIR and nb[1] != AIR and nb[2] != AIR and nb[4] != AIR and nb[5] != AIR:
		return
	var h := WATER_TOP if nb[2] == AIR else 1.0
	var fills := foam >> 8 & 15
	var data := Vector2(float(foam), float(depth))
	var mid: Color = corners[0].lerp(corners[1], 0.5).lerp(corners[3].lerp(corners[2], 0.5), 0.5)
	for d in 6:
		if d != FACE_BOTTOM and nb[d] == AIR:
			if d == FACE_TOP and (fills != 0 or corners[1] != corners[0] or corners[2] != corners[0] \
					or corners[3] != corners[0]):
				for q in 4:
					_piece(buf, base, h, q, CUT if fills & (1 << q) else QUARTER, Vector3.UP, mid, data,
						foam >> (16 + 2 * q) & 3, corners)
				continue
			# A side open to the air under the open sky is a fall's: its sheet covers it.
			if d != FACE_TOP and nb[2] == AIR:
				continue
			_add(buf, faces[d], d, base, Vector3(1.0, h, 1.0), Vector3.ZERO, mid, data)


## The kind of water for the shader (COLOR.b, see water_color): SHORE_WATER for water
## lying over the slope of a shore, which ice does not lift, plus how murky it is, from
## 0 clear through 0.5 a swamp's to 1 a bog's (WorldData.murk / 2), times MURK.
const SHORE_WATER := 0.5


const MURK := 0.45


static func kind(shore: bool, murk: float) -> float:
	return (SHORE_WATER if shore else 0.0) + murk * MURK


## Vertex colour of water for water.gdshader: r the depth of the water over the ground
## in cells (/ 8), g how far the ground of a shore lies under the surface (1 where the
## water goes all the way down), b its kind (see kind), alpha SEA_ALPHA on the sea's
## (WorldData.SEA_WATER: the plankton glows there), else 1.
static func water_color(depth: float, shore: float, kind: float, sea := false) -> Color:
	return Color(clampf(depth / 8.0, 0.0, 1.0), clampf(shore, 0.0, 1.0), kind, SEA_ALPHA if sea else 1.0)


## Whether water cell `cell` or one beside it is the sea's (see water_color).
static func sea_near(w, x: int, y: int, z: int) -> bool:
	return w.sea(x, y, z) or w.sea(x + 1, y, z) or w.sea(x - 1, y, z) or w.sea(x, y, z + 1) or w.sea(x, y, z - 1)


## True when the bed under the top water cell `i` (`depth` cells of water) and under the
## water all around lies level at the same depth, so the water is as deep everywhere
## over the cell (where the bed is 8 cells down or more, it all looks as deep).
static func level_bed(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int,
		depth: int) -> bool:
	if depth < 8 and (sh[i - depth * dy] & 15 != 0 or not cov[c[i - depth * dy]]):
		return false
	for o: int in [1, -1, dz, -dz, dz + 1, dz - 1, 1 - dz, -1 - dz]:
		var n := i + o
		if c[n] != WATER:
			return false
		if depth == 8:
			if c[n - 7 * dy] != WATER:
				return false
		elif c[n - (depth - 1) * dy] != WATER or c[n - depth * dy] == WATER or sh[n - depth * dy] & 15 != 0:
			return false
	return true


## Height of the ground at corner k of padded column `n`, from the bottom of the level of
## `n`: the bed's under water, a slope's where it goes down into the water on this
## level; NAN where the column is open or its ground stands above the water (a bank
## does not make the water beside it shallow).
static func _ground_at(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, n: int, dy: int, k: int) -> float:
	var m := c[n]
	if m != WATER:
		if not cov[m] or cov[c[n + dy]]:
			return NAN
		var h := Slopes.corner_height(sh, n, dy, k)
		return float(h) if h < 1 else NAN
	var d := 1
	while d < 8 and c[n - d * dy] == WATER:
		d += 1
	var b := n - d * dy
	if not cov[c[b]]:
		return 1.0 - d
	return float(Slopes.corner_height(sh, b, dy, k) - d)


## Colours at the corners NW, NE, SE, SW of the top of water cell `i`: the depth over
## the ground at each corner, from the ground of the four columns that meet there, so
## the water darkens smoothly over a sloping bed instead of cell by cell.
static func water_corners(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int,
		depth: int, murks: PackedFloat32Array, sea := false) -> PackedColorArray:
	var out := PackedColorArray()
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var sum := 0.0
		var count := 0
		for n in 4:
			var j := i + (o.x if n & 1 else 0) + (o.y * dz if n & 2 else 0)
			var kk: int = [k, k ^ 1, 3 - k, (k + 2) & 3][n]
			var g := _ground_at(c, sh, cov, j, dy, kk)
			if not is_nan(g):
				sum += g
				count += 1
		out.append(water_color(maxf(0.0, WATER_TOP - sum / count), 1.0, kind(false, murks[k]), sea))
	return out


## How murky the water is at the corners NW, NE, SE, SW of padded cell `i` (0 to 1, see
## kind): the mean of the water cells on its level that meet there, so the murk of a
## swamp fades into a bog's, or into clear water, across the cells instead of at their
## edges. A corner no water meets takes the mean of all the water around.
static func murk_corners(w, c: PackedByteArray, i: int, dz: int, base: Vector3) -> PackedFloat32Array:
	var around := PackedFloat32Array()
	var all := 0.0
	var wet := 0
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			if c[i + ox + oz * dz] == WATER:
				var m: float = w.murk(int(base.x) + ox, int(base.y), int(base.z) + oz) / 2.0
				around.append(m)
				all += m
				wet += 1
			else:
				around.append(-1.0)
	var out := PackedFloat32Array()
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var sum := 0.0
		var count := 0
		for n in 4:
			var m := around[4 + (o.x if n & 1 else 0) + (o.y * 3 if n & 2 else 0)]
			if m >= 0.0:
				sum += m
				count += 1
		out.append(sum / count if count > 0 else (all / wet if wet > 0 else 0.0))
	return out


## True when the sloping top of padded cell `i` lies at the shore of water standing
## beside it on its level: water with open air above beside it, and nothing else open
## around it (the slope goes down into the water, not to dry ground).
static func shore(c: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int) -> bool:
	var wet := false
	for o: int in [1, -1, dz, -dz, dz + 1, dz - 1, 1 - dz, -1 - dz]:
		var n := c[i + o]
		if n == WATER:
			wet = wet or c[i + o + dy] == AIR
		elif not cov[n]:
			return false
	return wet


## The water over the sloping top of shore cell `i` (see shore): a level surface over
## the whole cell, which the ground hides where it rises out of it, its points telling
## the shader how far under the surface the ground lies there (foam where it comes up).
## Its murk is that of the water beside, blended across the cell (see murk_corners).
## `foam`: its foam bits (see foam), for where it comes up to the side of land beside
## instead of to its own slope; without them the land showed bare teeth between the foam
## of the slopes down a shore.
static func shore_water(buf, w, c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int,
		base: Vector3, foam := 0) -> void:
	var murks := murk_corners(w, c, i, dz, base)
	var sea := sea_near(w, int(base.x), int(base.y), int(base.z))
	var steps := Vector2i(Slopes.PATCH_STEPS, Slopes.PATCH_STEPS)
	var hs: PackedFloat32Array = Slopes.patch_grid(Slopes.patch(c, sh, i, dy, dz), 0.0, steps)[0]
	var start: int = buf.verts.size()
	var nu := steps.x + 1
	var data := Vector2(float(foam), 1.0)
	for b in steps.y + 1:
		var z := float(b) / steps.y
		for a in nu:
			var x := float(a) / steps.x
			var under := WATER_TOP - hs[b * nu + a]
			buf.verts.append(base + Vector3(x, WATER_TOP, z))
			buf.normals.append(Vector3.UP)
			buf.uvs.append(Vector2(x, z))
			buf.uv2s.append(data)
			var murk := lerpf(lerpf(murks[0], murks[1], x), lerpf(murks[3], murks[2], x), z)
			buf.colors.append(water_color(maxf(under, 0.0), under, kind(true, murk), sea))
	for b in steps.y:
		for a in steps.x:
			var j := start + b * nu + a
			buf.indices.append(j)
			buf.indices.append(j + 1)
			buf.indices.append(j + nu + 1)
			buf.indices.append(j)
			buf.indices.append(j + nu + 1)
			buf.indices.append(j + nu)
