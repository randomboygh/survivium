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
			var col := water_color(depth - WATER_TOP, 1.0, kind(false, murk / 2.0))
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


## Water falling over a step of a river from padded cell `i` (see WorldGen.FALL_STEP):
## on each side open to the air over lower water or ground, a sheet slants out from the
## lip down to the water or ground below (so a fall to the east or west shows from
## above too), with churning foam on the water where it lands. Both are marked by vertex alpha (FALL_SHEET, FALL_FOAM, see
## water.gdshader); UV2.y of the sheet is the level of its foot.
static func falls(buf, faces: Array, c: PackedByteArray, nb: PackedByteArray, side_offsets: PackedInt32Array, i: int,
		dy: int, base: Vector3) -> void:
	if nb[2] != AIR:
		return
	for d: int in [0, 1, 4, 5]:
		if nb[d] != AIR:
			continue
		var n := i + side_offsets[d]
		var k := 1
		while k < 12 and c[n - k * dy] == AIR:
			k += 1
		var landing: int = c[n - k * dy]
		var foot := base.y - k + (WATER_TOP if landing == WATER else 1.0)
		if foot >= base.y:
			continue
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
		buf.quad(pts, (face.normal + Vector3.UP * FALL_SPREAD / size.y).normalized(), uvs, Color(1, 1, 1, FALL_SHEET),
			Vector2(0.0, foot))
		if landing == WATER:
			var under := base + Vector3(DIRS[d]) + Vector3(0.0, -k, 0.0)
			_add(buf, faces[FACE_TOP], FACE_TOP, under, Vector3(1.0, WATER_TOP + 0.02, 1.0), Vector3.ZERO,
				Color(1, 1, 1, FALL_FOAM), Vector2(0.0, 1.0))


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
## water goes all the way down), b its kind (see kind).
static func water_color(depth: float, shore: float, kind: float) -> Color:
	return Color(clampf(depth / 8.0, 0.0, 1.0), clampf(shore, 0.0, 1.0), kind)


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
		depth: int, murks: PackedFloat32Array) -> PackedColorArray:
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
		out.append(water_color(maxf(0.0, WATER_TOP - sum / count), 1.0, kind(false, murks[k])))
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
static func shore_water(buf, w, c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int,
		base: Vector3) -> void:
	var murks := murk_corners(w, c, i, dz, base)
	var steps := Vector2i(Slopes.PATCH_STEPS, Slopes.PATCH_STEPS)
	var hs: PackedFloat32Array = Slopes.patch_grid(Slopes.patch(c, sh, i, dy, dz), 0.0, steps)[0]
	var start: int = buf.verts.size()
	var nu := steps.x + 1
	var data := Vector2(0.0, 1.0)
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
			buf.colors.append(water_color(maxf(under, 0.0), under, kind(true, murk)))
	for b in steps.y:
		for a in steps.x:
			var j := start + b * nu + a
			buf.indices.append(j)
			buf.indices.append(j + 1)
			buf.indices.append(j + nu + 1)
			buf.indices.append(j)
			buf.indices.append(j + nu + 1)
			buf.indices.append(j + nu)
