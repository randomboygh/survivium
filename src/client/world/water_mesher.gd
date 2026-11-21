extends "res://src/client/world/mesh_faces.gd"
## Water in the chunk meshes: the surface with its shore, murk and depth colours,
## the water of cut corners, waterfalls with their sheet and foam, the water on a
## shore that follows the slope under it, and the surf washing up over the land level
## with the sea (swash). Called by ChunkMesher a column at a time.

const OldSlopes := preload("res://src/client/world/old_slope_mesher.gd")


## Water standing in the cut corners of padded cell `i` beside water with air above,
## up to the curve of each corner's shape (`shapes`, 2 bits a corner, NW lowest).
static func cut_water(w, water, c: PackedByteArray, i: int, dy: int, base: Vector3, cuts: int, shapes := 0) -> void:
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		if cuts & (1 << k) and c[i + o.x] == WATER and c[i + o.x + dy] == AIR:
			var shape := shapes >> (2 * k) & 3
			var depth := 1
			while depth < 8 and w.get_cell(int(base.x) + o.x, int(base.y) - depth, int(base.z)) == WATER:
				depth += 1
			var foam := 1 << (12 + k) | shape << (16 + 2 * k)
			var murk: int = w.murk(int(base.x) + o.x, int(base.y), int(base.z))
			var top := water_top(int(base.y))
			var sea: bool = w.sea(int(base.x) + o.x, int(base.y), int(base.z))
			var col := water_color(depth - 1.0 + top, 1.0, kind(false, murk / 2.0), sea, surf_here(sea, int(base.y)))
			_piece(water, base, top, k, CORNER, Vector3.UP, col, Vector2(float(foam), float(depth)), shape)


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
		var bits: int = 1 << HALF_CORNER[h]
		if cov[c[n]] and sh[n] >> 4 & bits == 0 and shores & (1 << e) == 0:
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
## lands in water, over which sides of that cell its foam spills, and which halves of the
## side the diagonal lip leaves out, see trims and fall_faces); a key of a diagonal fall
## for each corner the lip cuts off (see lip_cuts). They are drawn after the chunk's other
## water (ChunkMesher.step), so the foam and the spray lie over the pool they land in
## whichever of its cells came later.
static func falls(keys: PackedInt32Array, c: PackedByteArray, nb: PackedByteArray, side_offsets: PackedInt32Array,
		i: int, dy: int, dz: int, lx: int, lz: int, y: int) -> void:
	if nb[2] != AIR:
		return
	for q in 4:
		var d: int = FALL_DIRS[q]
		if nb[d] != AIR:
			continue
		var trim := trims(c, i, dy, dz, d, side_offsets[d])
		if trim == 3:
			continue
		var n := i + side_offsets[d]
		var k := _drop(c, n, dy)
		var landing := n - k * dy
		var wet := c[landing] == WATER
		var spill := 0
		if wet:
			var sides: Array = FALL_SIDES[q]
			for e in 3:
				var o: int = landing + side_offsets[sides[e]]
				if c[o] == WATER and c[o + dy] == AIR:
					spill |= 1 << e
		keys.append(_key(lx, lz, y, q, k, wet, spill, trim, false))
	var cuts := lip_cuts(c, i, dy, dz)
	for q in 4:
		if cuts & (1 << q):
			var o: Vector2i = CORNER_DIRS[q]
			var n := i + o.x + o.y * dz
			var k := _drop(c, n, dy)
			keys.append(_key(lx, lz, y, q, k, c[n - k * dy] == WATER, 0, 0, true))


## Levels from padded cell `n` (air) down to the first that is not air (up to 12).
static func _drop(c: PackedByteArray, n: int, dy: int) -> int:
	var k := 1
	while k < 12 and c[n - k * dy] == AIR:
		k += 1
	return k


## A waterfall's key (see falls): the cell, its side (or corner, for a diagonal fall),
## the drop `k`, whether it lands in water, the sides its foam spills over, the halves of
## the side left out (a diagonal fall: 1 when it is a filled corner's, see lip_fill).
static func _key(lx: int, lz: int, y: int, q: int, k: int, wet: bool, spill: int, trim: int, diag: bool) -> int:
	return ((((((((y * 2 + int(diag)) * 4 + trim) * 8 + spill) * 2 + int(wet)) * 16 + k - 1) * 4 + q) << 12) \
		| lz << 6 | lx)


## The diagonal lip of a step of a river: water seen from above runs straight across the
## step instead of in stairs. Its corners where the three cells around it on its level
## are air (the lower side of the step) are cut off along the diagonal across it, as
## the land's corners are (WorldData.update_corners), so the
## water lines up with the bed under it, cut the same way; an air cell whose three cells
## around a corner are water with air above (the step turning back) gets that corner of
## water (lip_fill). The corners of the water cut off in padded cell `i`, as bits 1 << k.
static func lip_cuts(c: PackedByteArray, i: int, dy: int, dz: int) -> int:
	var cuts := 0
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var x := i + o.x
		var z := i + o.y * dz
		if c[x] == AIR and c[z] == AIR and c[x + o.y * dz] == AIR:
			cuts |= 1 << k
	return cuts


## The corners of air cell `i` that the water of a step's lip fills (see lip_cuts): the
## three cells around it on its level are water with air above.
static func lip_fills(c: PackedByteArray, i: int, dy: int, dz: int) -> int:
	var fills := 0
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var x := i + o.x
		var z := i + o.y * dz
		var d := x + o.y * dz
		if c[x] == WATER and c[z] == WATER and c[d] == WATER and c[x + dy] == AIR and c[z + dy] == AIR \
				and c[d + dy] == AIR:
			fills |= 1 << k
	return fills


## The halves of side `d` (`off` the way to the cell beside) of water cell `i` that its
## fall leaves out (bit 0 the half at the side's first corner, see SIDE_CORNERS, bit 1
## the other): where the lip runs diagonally across the corner there, cut from this cell
## or filled into the air cell beside (see lip_cuts, lip_fills).
static func trims(c: PackedByteArray, i: int, dy: int, dz: int, d: int, off: int) -> int:
	var out := 0
	var ks: Array = SIDE_CORNERS[d]
	for h in 2:
		var o: Vector2i = CORNER_DIRS[ks[h]]
		var e := o.y * dz if d < 2 else o.x
		var b := c[i + e]
		var bd := c[i + off + e]
		if b == AIR and bd == AIR or b == WATER and bd == WATER and c[i + e + dy] == AIR and c[i + off + e + dy] == AIR:
			out |= 1 << h
	return out


## The water of the corners `fills` of air cell `i` at the lip of a step (see lip_fills):
## a corner of surface each, coloured as the water beside, and a diagonal fall from it.
static func lip_fill(buf, keys: PackedInt32Array, w, c: PackedByteArray, i: int, dy: int, dz: int, base: Vector3,
		fills: int, lx: int, lz: int) -> void:
	for k in 4:
		if fills & (1 << k) == 0:
			continue
		var o: Vector2i = CORNER_DIRS[k]
		var n := i + o.x + o.y * dz
		var depth := 1
		while depth < 8 and c[n - depth * dy] == WATER:
			depth += 1
		var x := int(base.x) + o.x
		var z := int(base.z) + o.y
		var murk: int = w.murk(x, int(base.y), z)
		var top := water_top(int(base.y))
		var col := water_color(depth - 1.0 + top, 1.0, kind(false, murk / 2.0), w.sea(x, int(base.y), z))
		_piece(buf, base, top, k, CORNER, Vector3.UP, col, Vector2(0.0, float(depth)))
		var drop := _drop(c, i, dy)
		keys.append(_key(lx, lz, int(base.y), k, drop, c[i - drop * dy] == WATER, 0, 1, true))


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
		var trim := key >> 22 & 3
		var base := Vector3(x0 + (key & 63), key >> 25, z0 + (key >> 6 & 63))
		var foot := base.y - k + (water_top(int(base.y) - k) if wet else 1.0)
		var lip := water_top(int(base.y))
		if key >> 24 & 1:
			_diag_fall(buf, base, q, trim == 1, k, wet, foot, float((key & 4095) % 97))
			continue
		var d: int = FALL_DIRS[q]
		var out := Vector3(DIRS[d])
		var size := Vector3(1.0, lip - (foot - base.y), 1.0)
		var lift := Vector3(0.0, foot - base.y, 0.0)
		var face: Dictionary = faces[d]
		# The part of the side drawn, along it: the halves the diagonal lip leaves out
		# are not (see trims).
		var lo := 0.5 if trim & 1 else 0.0
		var hi := 0.5 if trim & 2 else 1.0
		var pts := []
		var uvs := []
		for corner: Vector3 in face.corners:
			var cc := corner
			if d < 2:
				cc.z = lerpf(lo, hi, corner.z)
			else:
				cc.x = lerpf(lo, hi, corner.x)
			var v: Vector3 = lift + cc * size
			pts.append(base + v + out * (0.04 if corner.y > 0.5 else FALL_SPREAD))
			uvs.append(face_uv(d, v))
		# UV2: the levels of its lip and of its foot.
		buf.quad(pts, (face.normal + Vector3.UP * FALL_SPREAD / size.y).normalized(), uvs, Color(0, 1, 0, FALL_SHEET),
			Vector2(base.y + lip, foot))
		if wet:
			_fall_foam(buf, faces, base + out + Vector3(0.0, -k, 0.0), out, spill)
			_fall_spray(buf, base + out + Vector3(0.5, foot - base.y, 0.5) + out * (FALL_SPREAD - 0.4), k,
				float((key & 4095) % 97))
	return j


## A fall over the diagonal lip of a step (see lip_cuts) across corner `q` of the cell at
## `base`: off the cut corner of the water there, or (`filled`) from the corner of water
## in the air cell beside the step (lip_fill), facing away from that corner. It runs from
## the middle of one side to the middle of the next; its foot spreads out along those
## sides as the falls over them do, so it meets them and the next diagonal piece without
## a gap. The foam where it lands reaches a cell out the same way.
static func _diag_fall(buf, base: Vector3, q: int, filled: bool, k: int, wet: bool, foot: float, seed: float) -> void:
	var o := Vector2(CORNER_DIRS[q]) * (-1.0 if filled else 1.0)
	var line := corner_curve(q, 0)
	var out := Vector3(o.x, 0.0, o.y).normalized()
	var spread := PackedVector3Array()
	for p in line:
		# Along the axis of the side it lies on, outwards.
		spread.append(Vector3(o.x, 0.0, 0.0) if p.x == 0.0 or p.x == 1.0 else Vector3(0.0, 0.0, o.y))
	var lip := water_top(int(base.y))
	var high := base.y + lip
	var tall := high - foot
	var a := base + Vector3(line[0].x, lip, line[0].y)
	var b := base + Vector3(line[1].x, lip, line[1].y)
	var drop := Vector3(0.0, -tall, 0.0)
	var pts := [a + out * 0.04, b + out * 0.04, b + drop + spread[1] * FALL_SPREAD, a + drop + spread[0] * FALL_SPREAD]
	var uvs := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, tall), Vector2(0.0, tall)]
	_wound(buf, pts, (out + Vector3.UP * FALL_SPREAD / tall).normalized(), uvs, Color(0, 1, 0, FALL_SHEET),
		Vector2(high, foot))
	if not wet:
		return
	var lift := Vector3(0.0, 0.02, 0.0)
	var fa := a + drop + lift
	var fb := b + drop + lift
	var foam := [fa, fb, fb + spread[1], fa + spread[0]]
	_wound(buf, foam, Vector3.UP, [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)],
		Color(0, 1, 0, FALL_FOAM), Vector2(1.0, 0.0))
	_fall_spray(buf, (fa + fb) * 0.5 - lift + out * (0.5 + FALL_SPREAD - 0.4), k, seed)


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
		pts.append(cell + Vector3(x, water_top(int(cell.y)) + 0.02, z))
		var a := x if out.x > 0.0 else (1.0 - x if out.x < 0.0 else (z if out.z > 0.0 else 1.0 - z))
		uvs.append(Vector2(a, z if out.x != 0.0 else x))
	buf.quad(pts, Vector3.UP, uvs, Color(0, 1, 0, FALL_FOAM), Vector2(far, float(spill >> 1)))


## The spray and mist over the foot of a fall of `k` levels, rising from `root` on the
## pool: an upright quad turned to the camera by the shader, so all its corners lie at its
## root and UV holds each corner's offset from it in cells; UV2 its height in cells and a
## number of its own for the drops.
static func _fall_spray(buf, root: Vector3, k: int, seed: float) -> void:
	var tall := minf(1.0 + 0.4 * k, SPRAY_HIGH)
	var pts := [root, root, root, root]
	var uvs := [Vector2(-SPRAY_HALF, 0.0), Vector2(-SPRAY_HALF, tall), Vector2(SPRAY_HALF, tall), Vector2(SPRAY_HALF, 0.0)]
	buf.quad(pts, Vector3.UP, uvs, Color(0, 1, 0, FALL_SPRAY), Vector2(tall, seed))


## Water: the top face carries foam bits (UV2.x: the half edges that touch land, then
## the filled corners, then the cut corners of the land beside, see water.gdshader) and
## the depth to the bottom in cells (UV2.y); `corners` are the vertex colours at the
## top's corners NW, NE, SE, SW (see water_color). Filled corners, and `cuts`, those the
## lip of a step cuts off (see lip_cuts), are left out of the top.
static func water_faces(buf, faces: Array, nb: PackedByteArray, base: Vector3, depth: int, foam: int,
		corners: PackedColorArray, cuts := 0) -> void:
	if nb[0] != AIR and nb[1] != AIR and nb[2] != AIR and nb[4] != AIR and nb[5] != AIR:
		return
	var h := water_top(int(base.y)) if nb[2] == AIR else 1.0
	var fills := foam >> 8 & 15
	var data := Vector2(float(foam), float(depth))
	var mid: Color = corners[0].lerp(corners[1], 0.5).lerp(corners[3].lerp(corners[2], 0.5), 0.5)
	for d in 6:
		if d != FACE_BOTTOM and nb[d] == AIR:
			if d == FACE_TOP and ((fills | cuts) != 0 or corners[1] != corners[0] or corners[2] != corners[0] \
					or corners[3] != corners[0]):
				for q in 4:
					_piece(buf, base, h, q, quarter_kind(fills | cuts, q), Vector3.UP, mid, data,
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
## (WorldData.SEA_WATER: the plankton glows there), SURF_ALPHA on the sea's in its top
## level (`surf`, see surf_here), else 1.
static func water_color(depth: float, shore: float, kind: float, sea := false, surf := false) -> Color:
	return Color(clampf(depth / 8.0, 0.0, 1.0), clampf(shore, 0.0, 1.0), kind,
		SURF_ALPHA if surf else (SEA_ALPHA if sea else 1.0))


## Whether the sea's water at level `y` (`sea`: it is the sea's) meets its shore through
## the surf: in the sea's top level, flush with the land beside, which the surf (swash)
## runs up over with the foam line at its front, so the water draws no foam of its own.
static func surf_here(sea: bool, y: int) -> bool:
	return sea and y == sea_level


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
		var h := OldSlopes.corner_height(sh, n, dy, k)
		return float(h) if h < 1 else NAN
	var d := 1
	while d < 8 and c[n - d * dy] == WATER:
		d += 1
	var b := n - d * dy
	if not cov[c[b]]:
		return 1.0 - d
	return float(OldSlopes.corner_height(sh, b, dy, k) - d)


## Colours at the corners NW, NE, SE, SW of the top of water cell `i`: the depth over
## the ground at each corner, from the ground of the four columns that meet there, so
## the water darkens smoothly over a sloping bed instead of cell by cell.
static func water_corners(c: PackedByteArray, sh: PackedByteArray, cov: PackedByteArray, i: int, dy: int, dz: int,
		depth: int, murks: PackedFloat32Array, sea := false, top := WATER_TOP, surf := false) -> PackedColorArray:
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
		out.append(water_color(maxf(0.0, top - sum / count), 1.0, kind(false, murks[k]), sea, surf))
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
## Under water flush with the land (water_top 1: a lake or a river at the sea's level,
## without the sea's surf) the ground of a shore comes up to the surface only where it is
## level with the land: along the land's side of a straight slope, at the high corner
## of an outer corner on the diagonal, and past the diagonal of an inner one
## (WorldData.PATCH_DIAG), where it lies level at the surface over half the cell. There
## the water stops on that diagonal, so the two never fight over one height, and its foam
## runs along it from the straight shores' on into the next diagonal: the line the water
## meets the land on is the same on every kind of shore (cut half a cell short of it
## on the diagonal, it went into sharp corners where a shore turned from straight to
## diagonal, thread «Исправить диагональный берег»).
static func shore_water(buf, w, c: PackedByteArray, sh: PackedByteArray, i: int, dy: int, dz: int,
		base: Vector3, foam := 0) -> void:
	var murks := murk_corners(w, c, i, dz, base)
	var top := water_top(int(base.y))
	var sea := sea_near(w, int(base.x), int(base.y), int(base.z))
	# The sea's top level is flush with the land (water_top): the slope of a beach down
	# into it lies all under the water, and the surf (swash) outlines it, not a foam line.
	var surf := surf_here(sea, int(base.y))
	if surf:
		foam = 0
	var steps := Vector2i(OldSlopes.PATCH_STEPS, OldSlopes.PATCH_STEPS)
	var p := OldSlopes.patch(c, sh, i, dy, dz)
	var hs: PackedFloat32Array = OldSlopes.patch_grid(p, 0.0, steps)[0]
	var start: int = buf.verts.size()
	var nu := steps.x + 1
	# The points past the diagonal of an inner corner flush with the water (see above).
	var level := PackedByteArray()
	var diag := int(p[WorldData.PATCH_DIAG]) if top >= 1.0 and not surf and p.size() > WorldData.PATCH_DIAG else -1
	if diag >= 4:
		level.resize(nu * (steps.y + 1))
	if diag >= 0:
		# Foam as wide as along a straight shore's land (the half edges' foam): along the
		# diagonal, and at the high corner of an outer corner, where the foam of the two
		# diagonals beside meets (water.gdshader, corner shape 3).
		var k := diag & 3
		foam |= (1 << (12 + k) if diag >= 4 else 1 << (8 + k)) | 3 << (16 + 2 * k)
	var data := Vector2(float(foam), 1.0)
	for b in steps.y + 1:
		var z := float(b) / steps.y
		for a in nu:
			var x := float(a) / steps.x
			var under := top - hs[b * nu + a]
			buf.verts.append(base + Vector3(x, top, z))
			buf.normals.append(Vector3.UP)
			buf.uvs.append(Vector2(x, z))
			buf.uv2s.append(data)
			var murk := lerpf(lerpf(murks[0], murks[1], x), lerpf(murks[3], murks[2], x), z)
			buf.colors.append(water_color(maxf(under, 0.0), under, kind(true, murk), sea, surf))
			if not level.is_empty():
				level[b * nu + a] = 1 if WorldData.diag_reach(p, x, z) > 1.0 + OldSlopes.DIAG_EPS else 0
	# A square's two triangles, split as the ground's grid is (OldSlopes.crease_flip), so
	# the water's edge on an inner corner's diagonal is the ground's.
	var tris := PackedInt32Array([0, 1, nu, 1, nu + 1, nu]) if OldSlopes.crease_flip(p) \
		else PackedInt32Array([0, 1, nu + 1, 0, nu + 1, nu])
	for b in steps.y:
		for a in steps.x:
			var j := b * nu + a
			for t in 2:
				var q0: int = j + tris[3 * t]
				var q1: int = j + tris[3 * t + 1]
				var q2: int = j + tris[3 * t + 2]
				if not level.is_empty() and level[q0] + level[q1] + level[q2] > 0:
					continue
				buf.indices.append(start + q0)
				buf.indices.append(start + q1)
				buf.indices.append(start + q2)


## Surf: the sea washes up over the land whose top is level with it (the sea's level,
## where its water fills the cell, see water_top) in a thin sheet with foam
## at its front, up to SWASH_REACH cells from the waterline (water.gdshader draws the
## waves). The flat beaches of worlds with the setting shores 1 lie at that level.
const SWASH_REACH := 8.0
## How far over the ground the sheet lies, in cells.
const SWASH_LIFT := 0.03
## swash_map's value of a slope under the sea's flush water by the waterline.
const SWASH_UNDER := 0.0
## The sheet's vertex green over such a slope: the water.gdshader draws the sea where
## it is behind the waterline (shore_water leaves the slope out).
const SWASH_UNDER_G := 0.5


## How far each column of x0 - 1..x1 + 1, z0 - 1..z1 + 1 (ends exclusive, row by row)
## lies from the sea's waterline, in cells, going only over land whose top is at the
## sea's level: from the middle of the column, -0.5 on the sea's water at its edge, INF
## where it is farther than SWASH_REACH or not level; empty when the surf reaches none
## of them. A chamfer distance (two passes) over a window SWASH_REACH + 2 wider all
## round, from its column masks; the sea is told only for the water next to land.
static func swash_map(w, x0: int, z0: int, x1: int, z1: int) -> PackedFloat32Array:
	var lv: int = w.sea_level
	if lv < 0 or lv + 1 >= w.size_y:
		return PackedFloat32Array()
	var m := int(SWASH_REACH) + 2
	var gx0 := x0 - m
	var gz0 := z0 - m
	var gw := x1 - x0 + 2 * m
	var gh := z1 - z0 + 2 * m
	var masks: Dictionary = w.column_masks(gx0, gz0, gx0 + gw, gz0 + gh)
	var air: PackedInt64Array = masks.air
	var water: PackedInt64Array = masks.water
	var leaf: PackedInt64Array = masks.leaf
	var wet := 1 << lv
	var above: int = w.all_bits & ~((1 << (lv + 1)) - 1)
	# 1 land with its top at the sea's level, 2 water with open air over it there, 3 a
	# slope of that land under the water (below).
	var kind := PackedByteArray()
	kind.resize(gw * gh)
	var lands := false
	var waters := false
	for k in gw * gh:
		var open: int = air[k] | leaf[k]
		if open & above != above or open & wet != 0:
			continue
		if water[k] & wet != 0:
			kind[k] = 2
			waters = true
		else:
			kind[k] = 1
			lands = true
	if not lands or not waters:
		return PackedFloat32Array()
	var d := PackedFloat32Array()
	d.resize(gw * gh)
	d.fill(INF)
	var any := false
	for z in range(1, gh - 1):
		for x in range(1, gw - 1):
			var k := z * gw + x
			if kind[k] != 2:
				continue
			if (kind[k - 1] == 1 or kind[k + 1] == 1 or kind[k - gw] == 1 or kind[k + gw] == 1
					or kind[k - gw - 1] == 1 or kind[k - gw + 1] == 1 or kind[k + gw - 1] == 1 or kind[k + gw + 1] == 1) \
					and w.sea(gx0 + x, lv, gz0 + z):
				d[k] = -0.5
				any = true
	# A beach's slope down into the sea (one beside the sea's water, also across a corner)
	# lies under its flush water: SWASH_UNDER, the waterline running through it, so on a
	# diagonal shore it runs straight along the diagonal (see swash).
	var sloped: PackedInt64Array = masks.sloped
	var under := PackedInt32Array()
	for z in range(1, gh - 1):
		for x in range(1, gw - 1):
			var k := z * gw + x
			if kind[k] == 1 and sloped[k] & wet != 0:
				for n: int in [k - 1, k + 1, k - gw, k + gw, k - gw - 1, k - gw + 1, k + gw - 1, k + gw + 1]:
					if kind[n] == 2 and d[n] < 0.0:
						under.append(k)
						break
	for k in under:
		kind[k] = 3
		d[k] = SWASH_UNDER
		any = true
	if not any:
		return PackedFloat32Array()
	const DIAG := 1.4142
	for z in range(1, gh - 1):
		for x in range(1, gw - 1):
			var k := z * gw + x
			if kind[k] == 1:
				d[k] = minf(d[k], minf(minf(d[k - 1] + 1.0, d[k - gw] + 1.0), minf(d[k - gw - 1] + DIAG, d[k - gw + 1] + DIAG)))
	for z in range(gh - 2, 0, -1):
		for x in range(gw - 2, 0, -1):
			var k := z * gw + x
			if kind[k] == 1:
				d[k] = minf(d[k], minf(minf(d[k + 1] + 1.0, d[k + gw] + 1.0), minf(d[k + gw + 1] + DIAG, d[k + gw - 1] + DIAG)))
	var out := PackedFloat32Array()
	var reached := false
	for z in range(m - 1, gh - m + 1):
		for x in range(m - 1, gw - m + 1):
			var v := d[z * gw + x]
			if v > SWASH_REACH + 1.0:
				v = INF
			elif v > 0.0:
				reached = true
			out.append(v)
	return out if reached else PackedFloat32Array()


## The surf's sheet over the filled corners `fills` of the sea's water cell at `base` in
## its top level (see surf_here; `foam` its foam bits, with the corners' shapes): the land
## of a fill is level with the water, so the surf runs on over it from the diagonal, as
## over the land beside. The distance from the waterline is 0 on the diagonal and grows
## to the corner (the bilinear blend of the cell's corners gives the mid-sides, 0).
## A fill whose land beside slopes down under the water (swash_map counts it as the
## sea's, below 0) lies under the water too: no sheet, the surf starts at the slopes' top.
static func swash_fills(buf, base: Vector3, fills: int, foam: int, sw: PackedFloat32Array, sw_w: int, gx: int,
		gz: int) -> void:
	var tip := 0.35
	var rest := -0.35
	var g := gz * sw_w + gx
	for k in 4:
		if fills & (1 << k) == 0:
			continue
		var o: Vector2i = CORNER_DIRS[k]
		if sw[g + o.x] <= SWASH_UNDER or sw[g + o.y * sw_w] <= SWASH_UNDER:
			continue
		var corners := PackedColorArray()
		for n in 4:
			var far := tip if n == k else rest
			corners.append(Color(clampf((far + 0.5) / 8.0, 0.0, 1.0), 1.0, 0.0, SWASH_ALPHA))
		_piece(buf, base, 1.0 + SWASH_LIFT, k, CORNER, Vector3.UP, corners[k], Vector2.ZERO, foam >> (16 + 2 * k) & 3,
			corners)


## The corners of column `g` of the map `sw` (swash_map, `sw_w` a row): the mean of the
## columns that meet there, NW, NE, SE, SW.
static func _swash_corners(sw: PackedFloat32Array, sw_w: int, g: int) -> PackedFloat32Array:
	var corners := PackedFloat32Array()
	for k in 4:
		var o: Vector2i = CORNER_DIRS[k]
		var sum := 0.0
		var count := 0
		for n: int in [g, g + o.x, g + o.y * sw_w, g + o.x + o.y * sw_w]:
			if sw[n] < INF:
				sum += sw[n]
				count += 1
		corners.append(sum / count)
	return corners


## Over a slope under the sea's flush water by the waterline (SWASH_UNDER), one flat
## sheet at the water's surface: the sea's water behind the waterline (below 0, drawn
## as the water there), the surf beyond it, the waterline running through the cell, so
## along a diagonal shore it is straight, not stepping round the cells.
static func _swash_under(buf, sw: PackedFloat32Array, sw_w: int, g: int, base: Vector3) -> void:
	var corners := _swash_corners(sw, sw_w, g)
	var start: int = buf.verts.size()
	for k in 4:
		var x := 1.0 if k == 1 or k == 2 else 0.0
		var z := 1.0 if k >= 2 else 0.0
		buf.verts.append(base + Vector3(x, water_top(int(base.y)) + SWASH_LIFT, z))
		buf.normals.append(Vector3.UP)
		buf.uvs.append(Vector2(x, z))
		buf.uv2s.append(Vector2.ZERO)
		buf.colors.append(Color(clampf((corners[k] + 0.5) / 8.0, 0.0, 1.0), SWASH_UNDER_G, 0.0, SWASH_ALPHA))
	for j: int in [0, 1, 2, 0, 2, 3]:
		buf.indices.append(start + j)


## Whether column `gx`, `gz` of the map `sw` (see swash_map) is a slope under the sea's
## water by the waterline, which the surf's sheet covers instead of shore_water.
static func under_swash(sw: PackedFloat32Array, sw_w: int, gx: int, gz: int) -> bool:
	return not sw.is_empty() and sw[gz * sw_w + gx] == SWASH_UNDER


## The surf's sheet over the top of land cell `i` (see swash), column `gx`, `gz` of the
## map `sw` (swash_map, `sw_w` columns a row): over the cell's top, its slope's where it
## slopes, never under the water's surface; each point tells the shader how far from the
## waterline it is, from the columns that meet at the cell's corners.
static func swash(buf, sw: PackedFloat32Array, sw_w: int, c: PackedByteArray, sh: PackedByteArray, i: int, dy: int,
		dz: int, gx: int, gz: int, base: Vector3) -> void:
	var g := gz * sw_w + gx
	if sw[g] > SWASH_REACH or sw[g] < 0.0:
		return
	if sw[g] == SWASH_UNDER:
		_swash_under(buf, sw, sw_w, g, base)
		return
	var corners := _swash_corners(sw, sw_w, g)
	# Never behind the waterline: where the sea's water meets the land at a corner
	# (a diagonal shore), the corner lies on it, and the land's whole top is covered.
	for k in 4:
		corners[k] = maxf(corners[k], 0.0)
	var sloped := sh[i] & 15 != 0
	var steps := Vector2i(OldSlopes.PATCH_STEPS, OldSlopes.PATCH_STEPS) if sloped else Vector2i(1, 1)
	var hs := PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
	if sloped:
		hs = OldSlopes.patch_grid(OldSlopes.patch(c, sh, i, dy, dz), 0.0, steps)[0]
	var start: int = buf.verts.size()
	var nu := steps.x + 1
	for b in steps.y + 1:
		var z := float(b) / steps.y
		for a in nu:
			var x := float(a) / steps.x
			# Corners NW, NE, SE, SW at (0, 0), (1, 0), (1, 1), (0, 1).
			var far := lerpf(lerpf(corners[0], corners[1], x), lerpf(corners[3], corners[2], x), z)
			buf.verts.append(base + Vector3(x, maxf(hs[b * nu + a], water_top(int(base.y))) + SWASH_LIFT, z))
			buf.normals.append(Vector3.UP)
			buf.uvs.append(Vector2(x, z))
			buf.uv2s.append(Vector2.ZERO)
			buf.colors.append(Color(clampf((far + 0.5) / 8.0, 0.0, 1.0), 1.0, 0.0, SWASH_ALPHA))
	for b in steps.y:
		for a in steps.x:
			var j := start + b * nu + a
			buf.indices.append(j)
			buf.indices.append(j + 1)
			buf.indices.append(j + nu + 1)
			buf.indices.append(j)
			buf.indices.append(j + nu + 1)
			buf.indices.append(j + nu)
