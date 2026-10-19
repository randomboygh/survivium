extends RefCounted
## Grass tufts and tree crowns for one chunk, as MultiMesh instance buffers.
## Tufts stand on grass tops. A crown is drawn the way t3ssel8r draws his trees: leaf
## cluster cards cover its open faces, and each card is lit with the normal of the crown
## at that spot (away from the middle of the leaves around it), bent toward a few large
## bumps, so the light falls on the crown as one mass with some big lumps instead of on
## each card. Every exposed point of a crown also gets a flat shadow-only disc, so
## crowns cast round shadows.

const Mat := preload("res://src/shared/materials.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const WorldData := preload("res://src/shared/world_data.gd")

## Lush patches keep all of them, thin meadows fewer (see grass.gdshader).
const TUFTS_PER_CELL := 2
const TUFT_SIZE := 0.5
## Leaf cluster cards: size in world units (24 px, see PixelTextures.CLUMP; the bunch of
## leaves in a card is one of three sizes), cards on each open face of a crown point the
## camera sees.
const CLUMP_SIZE := 1.5
const CARDS_PER_FACE := 1
## Tint of the layer of large cards deeper in the crown, which fills the gaps between
## the outer cards: darker and cooler, as light gets less far into the leaves.
const DEEP := Color(0.7, 0.76, 0.84)
## Crown points within this many steps give the crown's middle for the light.
const CROWN_REACH := 2
## How much the bumps of a crown (a smooth wave about two units across) bend its normal.
const BUMP := 0.45
## Bushes are made of smaller clusters, this many pixels across, this many per bush.
const BUSH_CLUMP := 10
const BUSH_CARDS := 6
const BUSH_DISC := 0.9
const SHADOW_DISC := 1.6
## One pixel and one cell in world units.
const PX := 1.0 / 16.0
const CELL := WorldData.CELL
## Levels 0, 2, 4.. of a column mask.
const EVEN_LEVELS := 0x5555555555555555


## Upright quad of `size`, bottom edge (or centre when `centered`) at the origin.
static func quad_mesh(size: float, centered: bool) -> ArrayMesh:
	var h := size * 0.5
	var y0 := -h if centered else 0.0
	var y1 := y0 + size
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, y0, 0), Vector3(-h, y1, 0), Vector3(h, y1, 0), Vector3(h, y0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Flat square of `size` lying in the x-z plane, centred on the origin.
static func disc_mesh(size: float) -> ArrayMesh:
	var h := size * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Returns {"grass": [count, buffer], "clumps": [count, buffer], "shadows": [count, buffer]}
## for the cells x0..x0+size, z0..z0+size. Buffers are laid out for MultiMesh with
## 3D transforms in world units; grass has custom data, clumps colours and custom data.
## Leaf clumps stand on a lattice two cells apart (odd x and z, even levels), where the
## generator centres its crowns.
static func build_chunk(w, x0: int, z0: int, size: int) -> Dictionary:
	w.refresh_shapes()
	var cells: PackedByteArray = w.cells
	var shapes: PackedByteArray = w.shapes
	var sx: int = w.size_x
	var sz: int = w.size_z
	var layer: int = sx * sz
	var x1 := mini(x0 + size, sx)
	var z1 := mini(z0 + size, sz)
	var grass := PackedFloat32Array()
	var clumps := PackedFloat32Array()
	var shadows := PackedFloat32Array()
	var ng := 0
	var nc := 0
	var ns := 0
	var rng := RandomNumberGenerator.new()
	for z in range(z0, z1):
		for x in range(x0, x1):
			var col := z * sx + x
			var air: int = w.air_cols[col]
			# Ground with air above.
			var tops: int = ~(air | w.water_cols[col] | w.leaf_cols[col]) & w.all_bits & ((air >> 1) | w.top_bit)
			while tops != 0:
				var bit := tops & -tops
				tops ^= bit
				var y := WorldData.level_of(bit)
				var i := y * layer + col
				if cells[i] != Mat.GRASS:
					continue
				rng.seed = hash(Vector3i(x, y, z))
				var mask := WorldData.FULL & ~(shapes[i] & 15)
				var cuts := shapes[i] >> 4
				for k in TUFTS_PER_CELL:
					var fx := rng.randi_range(1, 7) / 8.0
					var fz := rng.randi_range(1, 7) / 8.0
					var q := WorldData.corner_at(fx, fz)
					if cuts & (1 << q) and WorldData.in_corner(q, fx, fx, fz, fz):
						continue
					put(grass, Vector3(x + fx, y + WorldData.slope_height(mask, fx, fz, cuts), z + fz) * CELL)
					grass.append_array([float(rng.randi_range(0, 3)), rng.randf_range(0.88, 1.1), rng.randf(), 0.0])
					ng += 1
			if x & 1 == 0 or z & 1 == 0:
				continue
			var leaves: int = w.leaf_cols[col] & EVEN_LEVELS
			while leaves != 0:
				var bit := leaves & -leaves
				leaves ^= bit
				var y := WorldData.level_of(bit)
				var faces := _open_faces(w, x, y, z)
				if faces.is_empty():
					continue
				var mid := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * CELL
				var middle := mid + _crown_offset(w, x, y, z)
				rng.seed = hash(Vector3i(x, y, z))
				var tree := hash(Vector2i(x / 6, z / 6)) % 3
				var base: Color = [Color(0.27, 0.43, 0.25), Color(0.3, 0.46, 0.22), Color(0.25, 0.41, 0.27)][tree]
				# Large bunches on the inside of the crown, smaller ones toward its
				# outline (points open on three or more sides), the smallest at the very
				# edge, so the middle is dense and the edge jagged.
				var rows := [0, 1] if faces.size() < 3 else [1, 2]
				for f in faces:
					# Cards cover each face the camera can see, poking out of it a
					# little, so no gap shows the trunk inside.
					for k in CARDS_PER_FACE:
						var c := mid + Vector3(f) * (0.4 + rng.randi_range(0, 3) * PX)
						var spread := Vector3(rng.randi_range(-4, 4), rng.randi_range(-4, 4), rng.randi_range(-4, 4)) * PX
						c += spread - Vector3(f) * Vector3(f).dot(spread)
						_card(clumps, PixelView.snap(c), middle, base, rows[rng.randi_range(0, 1)], rng)
						nc += 1
				# A deeper, darker layer behind the outer cards (a little inward and
				# north, so it is drawn behind them) fills the gaps between them.
				var deep := mid + Vector3(0.0, 0.0, -0.25) - (mid - middle).limit_length(0.3)
				_card(clumps, PixelView.snap(deep), middle, base * DEEP, 0, rng)
				nc += 1
				put(shadows, mid)
				ns += 1
	return {"grass": [ng, grass], "clumps": [nc, clumps], "shadows": [ns, shadows]}


## Leaf clusters of berry bushes standing on the given cells: [count, buffer] like
## crowns, lit as one low dome per bush.
static func bushes(cells: Array[Vector3i]) -> Array:
	var buf := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	for cell in cells:
		rng.seed = hash(cell)
		for k in BUSH_CARDS:
			var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / BUSH_CARDS
			var o := Vector3(cos(a) * 0.22, rng.randf_range(0.0, 0.15), sin(a) * 0.15)
			if k == 0:
				o = Vector3(0.0, 0.2, 0.0)
			put(buf, PixelView.snap((Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL + Vector3(0.0, 0.3, 0.0) + o))
			# Alpha below 1 marks a cluster with berries (see leaves.gdshader).
			buf.append_array([0.3, 0.46, 0.22, 0.5])
			var n := (o + Vector3(0.0, 0.25, 0.0)).normalized()
			buf.append_array([n.x, n.y, n.z, rng.randf() * 0.99])
	return [cells.size() * BUSH_CARDS, buf]


## Faces of a crown point the camera can see (top, south, east, west) whose
## neighbouring point (two cells on) is neither leaves nor a trunk.
static func _open_faces(w, x: int, y: int, z: int) -> Array[Vector3i]:
	var open: Array[Vector3i] = []
	for d in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
		var n: int = w.get_cell(x + 2 * d.x, y + 2 * d.y, z + 2 * d.z)
		if n != Mat.LEAVES and n != Mat.LOG:
			open.append(d)
	return open


## Appends a leaf cluster card at `c`: transform, tint, and the crown's normal with the
## card's row of the clump texture plus a sway phase in the last value.
static func _card(buf: PackedFloat32Array, c: Vector3, middle: Vector3, tint: Color, row: int, rng: RandomNumberGenerator) -> void:
	put(buf, c)
	buf.append_array([tint.r, tint.g, tint.b, 1.0])
	var n := _card_normal(c, middle)
	buf.append_array([n.x, n.y, n.z, row + rng.randf() * 0.99])


## Offset in world units from a crown point to the middle of the crown points within
## CROWN_REACH steps of it (a step is two cells, one world unit).
static func _crown_offset(w, x: int, y: int, z: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for dy in range(-CROWN_REACH, CROWN_REACH + 1):
		for dz in range(-CROWN_REACH, CROWN_REACH + 1):
			for dx in range(-CROWN_REACH, CROWN_REACH + 1):
				if w.get_cell(x + 2 * dx, y + 2 * dy, z + 2 * dz) == Mat.LEAVES:
					sum += Vector3(dx, dy, dz)
					n += 1
	return sum / n


## Normal for a card at `c`: away from the crown's middle, bent by a few large bumps,
## and a little up, so a lone or flat canopy faces the sky.
static func _card_normal(c: Vector3, middle: Vector3) -> Vector3:
	var bump := Vector3(sin(c.y * 2.1 + c.z * 1.3 + 1.0), sin(c.x * 1.7 + c.z * 2.3), sin(c.x * 1.1 + c.y * 1.9 + 2.0))
	var n := (c - middle).normalized() + bump * BUMP + Vector3(0.0, 0.3, 0.0)
	return n.normalized()


## Appends a translation-only transform in MultiMesh buffer order.
static func put(buf: PackedFloat32Array, p: Vector3) -> void:
	buf.append_array([1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z])
