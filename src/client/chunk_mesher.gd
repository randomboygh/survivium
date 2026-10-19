extends RefCounted
## Builds meshes from the cell grid: one quad per visible cell face, with the data the
## world shader needs for edges and material transitions (see world.gdshader).
## A chunk mesh holds all levels of a 16x16 column; the cutaway hides upper levels
## in the shader, and `build_cap` closes the cut with dark tops. Leaves are not cubes:
## Foliage draws them as leaf clumps.

const Mat := preload("res://src/shared/materials.gd")
const MeshBuffers := preload("res://src/client/mesh_buffers.gd")

const DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const FACE_TOP := 2
const FACE_BOTTOM := 3
const FACE_SOUTH := 4
const CORNERS := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)],
]
const WATER_TOP := 0.875
const AIR := Mat.AIR
const WATER := Mat.WATER
const LEAVES := Mat.LEAVES
## Tile index meaning "no texture" (voxels) or "no neighbour" (transitions).
const NO_TILE := 63
## Edge codes, 2 bits per edge in the order N, S, W, E (see world.gdshader).
const LIGHT := 1
const DARK := 2
const CONTACT := 3
const EDGE_N := 0
const EDGE_S := 2
const EDGE_W := 4
const EDGE_E := 6
## Face flags (see world.gdshader): a season-tinted voxel, a wall with open sky above.
const FOLIAGE_VOXEL := 1
const OPEN_TOP := 2
## A tree trunk is drawn 6 texels wide.
const TRUNK_MIN := 5.0 / 16.0
const TRUNK_MAX := 11.0 / 16.0

static var _faces: Array = []
## Per direction: [corners, uvs, normal] of a whole cell face.
static var _cell_faces: Array = []
static var _covers_lut := PackedByteArray()


## Per direction: corners in clockwise order seen from outside, and the normal.
static func face_table() -> Array:
	if not _faces.is_empty():
		return _faces
	for d in 6:
		var di: Vector3i = DIRS[d]
		var n := Vector3(di.x, di.y, di.z)
		var c: Array = CORNERS[d].duplicate()
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var e: Vector3 = c[2]
		if (b - a).cross(e - a).dot(n) > 0.0:
			c.reverse()
		_faces.append({"corners": c, "normal": n})
	return _faces


## Texture position of a point on a face: x/z on tops and bottoms, across and down on
## walls (v = 0 at the top of a wall and at the north edge of a top).
static func face_uv(d: int, v: Vector3) -> Vector2:
	if d == FACE_TOP or d == FACE_BOTTOM:
		return Vector2(v.x, v.z)
	if d < 2:
		return Vector2(v.z, 1.0 - v.y)
	return Vector2(v.x, 1.0 - v.y)


## Packs a face's tile, edge codes and flag into UV2.x (see world.gdshader).
static func pack(tile: int, edges: int, flag: int) -> float:
	return float(tile + 64 * edges + 16384 * flag)


## Returns [solid_mesh_or_null, water_mesh_or_null] for the column of cells x0..x0+size, z0..z0+size.
## Works on a copy of the chunk's cells with a border of one cell (outside the map is
## air, below it is stone), so neighbour lookups are plain array reads.
static func build_chunk(w, x0: int, z0: int, size: int) -> Array:
	var faces := face_table()
	var solid := MeshBuffers.new()
	var water := MeshBuffers.new()
	var sy: int = w.size_y
	var x1 := mini(x0 + size, w.size_x)
	var z1 := mini(z0 + size, w.size_z)
	var c := padded(w, x0 - 1, z0 - 1, x1 + 1, z1 + 1)
	var cov := covers_table()
	# Strides of the padded grid: +x, +z, +y.
	var dx := 1
	var dz: int = x1 - x0 + 2
	var dy: int = dz * (z1 - z0 + 2)
	var white := Color(1, 1, 1)
	var no_tiles := float(NO_TILE * 0x41041)
	var nb := PackedByteArray()
	nb.resize(6)
	for y in sy:
		for z in range(z0, z1):
			var i := (y + 1) * dy + (z - z0 + 1) * dz + 1
			for x in range(x0, x1):
				var m := c[i]
				if m == AIR or m == LEAVES:
					i += 1
					continue
				# Neighbours in DIRS order: +x, -x, +y, -y, +z, -z.
				nb[0] = c[i + dx]
				nb[1] = c[i - dx]
				nb[2] = c[i + dy]
				nb[3] = c[i - dy]
				nb[4] = c[i + dz]
				nb[5] = c[i - dz]
				var base := Vector3(x, y, z)
				if m == WATER:
					_water_faces(w, water, faces, nb, x, y, z)
				elif m == Mat.LOG and _is_trunk(nb):
					_trunk_faces(solid, faces, nb, base, m)
				else:
					for d in 6:
						var n := nb[d]
						if n != AIR and n != WATER and n != LEAVES:
							# The ground under a thin trunk still shows around it.
							if not (d == FACE_TOP and n == Mat.LOG and _trunk_at(w, x, y + 1, z)):
								continue
						var tile := m * 3 + (0 if d == FACE_TOP else (2 if d == FACE_BOTTOM else 1))
						var edges := 0
						var flag := 0
						var around := no_tiles
						if d == FACE_TOP:
							# What the oblique view shows next to each edge: a wall below
							# the south edge (light rim), something lower and farther
							# behind an edge (dark outline), or a wall rising from it
							# (contact shadow).
							if cov[c[i + dy - dz]]:
								edges |= CONTACT << EDGE_N
							elif not cov[c[i - dz]]:
								edges |= DARK << EDGE_N
							if not cov[c[i + dz]]:
								edges |= LIGHT << EDGE_S
							if cov[c[i + dy - dx]]:
								edges |= CONTACT << EDGE_W
							elif not cov[c[i - dx]] and not cov[c[i + dy - dx + dz]]:
								edges |= DARK << EDGE_W
							if cov[c[i + dy + dx]]:
								edges |= CONTACT << EDGE_E
							elif not cov[c[i + dx]] and not cov[c[i + dy + dx + dz]]:
								edges |= DARK << EDGE_E
							# Top tiles of level neighbours N, S, W, E for transitions.
							var tn := c[i - dz] * 3 if cov[c[i - dz]] and not cov[c[i - dz + dy]] else NO_TILE
							var ts := c[i + dz] * 3 if cov[c[i + dz]] and not cov[c[i + dz + dy]] else NO_TILE
							var tw := c[i - dx] * 3 if cov[c[i - dx]] and not cov[c[i - dx + dy]] else NO_TILE
							var te := c[i + dx] * 3 if cov[c[i + dx]] and not cov[c[i + dx + dy]] else NO_TILE
							around = float(tn | ts << 6 | tw << 12 | te << 18)
						elif d == FACE_SOUTH:
							if not cov[c[i + dy]]:
								flag = OPEN_TOP
							# Outlines where nothing nearer or level is beside or below.
							if not cov[c[i - dy + dz]] and not cov[c[i - dy]]:
								edges |= DARK << EDGE_S
							if not cov[c[i - dx]] and not cov[c[i - dx + dz]] and not cov[c[i - dx + dz + dy]]:
								edges |= DARK << EDGE_W
							if not cov[c[i + dx]] and not cov[c[i + dx + dz]] and not cov[c[i + dx + dz + dy]]:
								edges |= DARK << EDGE_E
						_add_cell_face(solid, d, base, white, Vector2(pack(tile, edges, flag), around))
				i += 1
	return [null if solid.is_empty() else solid.to_mesh(), null if water.is_empty() else water.to_mesh()]


## Copy of the cells in x0..x1, z0..z1 (exclusive ends, may reach outside the map)
## and levels -1..size_y, in that order (x fastest).
static func padded(w, x0: int, z0: int, x1: int, z1: int) -> PackedByteArray:
	var sx: int = w.size_x
	var sy: int = w.size_y
	var sz: int = w.size_z
	var cells: PackedByteArray = w.cells
	var width := x1 - x0
	var air_row := PackedByteArray()
	air_row.resize(width)
	var stone_row := PackedByteArray()
	stone_row.resize(width)
	stone_row.fill(Mat.STONE)
	var left := PackedByteArray()
	left.resize(maxi(0, -x0))
	var right := PackedByteArray()
	right.resize(maxi(0, x1 - sx))
	var a := maxi(x0, 0)
	var b := mini(x1, sx)
	var c := PackedByteArray()
	for y in range(-1, sy + 1):
		for z in range(z0, z1):
			if y < 0:
				c.append_array(stone_row)
			elif y >= sy or z < 0 or z >= sz:
				c.append_array(air_row)
			else:
				var row := (y * sz + z) * sx
				c.append_array(left)
				c.append_array(cells.slice(row + a, row + b))
				c.append_array(right)
	return c


## 1 for materials that hide what is behind them (not air, water or leaves).
static func covers_table() -> PackedByteArray:
	if _covers_lut.is_empty():
		_covers_lut.resize(256)
		for m in 256:
			_covers_lut[m] = 1 if _covers(m) else 0
	return _covers_lut


## Dark tops of solid cells on `level` that are covered by solid cells above:
## what you see in the cut when looking into a mountain.
static func build_cap(w, level: int) -> ArrayMesh:
	if level < 0 or level >= w.size_y - 1:
		return null
	var top: Dictionary = face_table()[FACE_TOP]
	var buf := MeshBuffers.new()
	var cells: PackedByteArray = w.cells
	var sx: int = w.size_x
	var sz: int = w.size_z
	var layer: int = sx * sz
	var row: int = level * layer
	var dark := Color(0.4, 0.4, 0.4)
	for z in sz:
		for x in sx:
			var i: int = row + z * sx + x
			var m: int = cells[i]
			var above: int = cells[i + layer]
			if _covers(m) and _covers(above):
				_add(buf, top, FACE_TOP, Vector3(x, level, z), Vector3.ONE, Vector3.ZERO, dark,
					Vector2(pack(m * 3, 0, 0), float(NO_TILE * 0x41041)))
	return null if buf.is_empty() else buf.to_mesh()


## Adds the whole face `d` of the cell at `base`.
static func _add_cell_face(buf, d: int, base: Vector3, color: Color, packed: Vector2) -> void:
	if _cell_faces.is_empty():
		var faces := face_table()
		for k in 6:
			var uvs := []
			for v in faces[k].corners:
				uvs.append(face_uv(k, v))
			_cell_faces.append([faces[k].corners, uvs, faces[k].normal])
	var f: Array = _cell_faces[d]
	var corners: Array = f[0]
	buf.quad([base + corners[0], base + corners[1], base + corners[2], base + corners[3]], f[2], f[1], color, packed)


## Adds a face of the box `offset`..`offset + size` inside the cell at `base`.
static func _add(buf, face: Dictionary, d: int, base: Vector3, size: Vector3, offset: Vector3, color: Color, packed: Vector2) -> void:
	var pts := []
	var uvs := []
	for c in face.corners:
		var v: Vector3 = offset + c * size
		pts.append(base + v)
		uvs.append(face_uv(d, v))
	buf.quad(pts, face.normal, uvs, color, packed)


## Cells that hide what is behind them; leaves and water do not.
static func _covers(m: int) -> bool:
	return m != AIR and m != WATER and m != LEAVES


## A log with open sides that continues up into a trunk or crown is a tree trunk.
static func _is_trunk(nb: PackedByteArray) -> bool:
	return not _covers(nb[0]) and not _covers(nb[1]) and not _covers(nb[4]) and not _covers(nb[5]) \
		and (nb[2] == Mat.LOG or nb[2] == LEAVES)


static func _trunk_at(w, x: int, y: int, z: int) -> bool:
	var nb := PackedByteArray([w.get_cell(x + 1, y, z), w.get_cell(x - 1, y, z), w.get_cell(x, y + 1, z),
		w.get_cell(x, y - 1, z), w.get_cell(x, y, z + 1), w.get_cell(x, y, z - 1)])
	return w.get_cell(x, y, z) == Mat.LOG and _is_trunk(nb)


static func _trunk_faces(buf, faces: Array, nb: PackedByteArray, base: Vector3, m: int) -> void:
	var offset := Vector3(TRUNK_MIN, 0.0, TRUNK_MIN)
	var size := Vector3(TRUNK_MAX - TRUNK_MIN, 1.0, TRUNK_MAX - TRUNK_MIN)
	var white := Color(1, 1, 1)
	for d in 6:
		if (d == FACE_TOP or d == FACE_BOTTOM) and _covers(nb[d]) or d == FACE_TOP and nb[d] == Mat.LOG:
			continue
		var tile := m * 3 + (0 if d == FACE_TOP else 1)
		var edges := 0
		if d == FACE_SOUTH:
			edges = (DARK << EDGE_W) | (DARK << EDGE_E)
		elif d == FACE_TOP:
			edges = (DARK << EDGE_N) | (DARK << EDGE_W) | (DARK << EDGE_E) | (LIGHT << EDGE_S)
		_add(buf, faces[d], d, base, size, offset, white, Vector2(pack(tile, edges, 0), float(NO_TILE * 0x41041)))


## Water: the top face carries foam bits for the edges that touch land (N, S, W, E in
## UV2.x) and the depth to the bottom in cells (UV2.y).
static func _water_faces(w, buf, faces: Array, nb: PackedByteArray, x: int, y: int, z: int) -> void:
	if nb[0] != AIR and nb[1] != AIR and nb[2] != AIR and nb[4] != AIR and nb[5] != AIR:
		return
	var h := WATER_TOP if nb[2] == AIR else 1.0
	var depth := 1
	while depth < 8 and w.get_cell(x, y - depth, z) == WATER:
		depth += 1
	var foam := 0
	var bit := 0
	for o in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _covers(w.get_cell(x + o.x, y, z + o.y)):
			foam |= 1 << bit
		bit += 1
	var white := Color(1, 1, 1)
	for d in 6:
		if d != FACE_BOTTOM and nb[d] == AIR:
			_add(buf, faces[d], d, Vector3(x, y, z), Vector3(1.0, h, 1.0), Vector3.ZERO, white,
				Vector2(float(foam), float(depth)))
