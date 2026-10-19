extends RefCounted
## Grass tufts and tree crowns for one chunk, as MultiMesh instance buffers.
## Tufts stand on grass tops; every exposed point of a crown becomes a round leaf clump
## plus a flat shadow-only disc, so crowns look soft and cast round shadows.

const Mat := preload("res://src/shared/materials.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const WorldData := preload("res://src/shared/world_data.gd")

## Lush patches keep all of them, thin meadows fewer (see grass.gdshader).
const TUFTS_PER_CELL := 2
const TUFT_SIZE := 0.5
const CLUMP_SIZE := 1.25
## Bushes are made of smaller clumps, this many pixels across.
const BUSH_CLUMP := 12
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
				# Outward direction of the crown: away from the leaves around this clump.
				var out := Vector3.ZERO
				var open := false
				for ny in range(-1, 2):
					for nz in range(-1, 2):
						for nx in range(-1, 2):
							var n: int = w.get_cell(x + 2 * nx, y + 2 * ny, z + 2 * nz)
							if n != Mat.LEAVES and n != Mat.LOG:
								out += Vector3(nx, ny, nz)
								open = open or absi(nx) + absi(ny) + absi(nz) == 1
				if not open:
					continue
				rng.seed = hash(Vector3i(x, y, z))
				var mid := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * CELL
				var c := mid + Vector3(rng.randi_range(-4, 4) * PX, rng.randi_range(-4, 4) * PX, 0.0)
				put(clumps, PixelView.snap(c))
				var shade := rng.randf_range(0.9, 1.08)
				var tree := hash(Vector2i(x / 6, z / 6)) % 3
				var base: Color = [Color(0.3, 0.47, 0.22), Color(0.33, 0.5, 0.2), Color(0.28, 0.44, 0.24)][tree]
				clumps.append_array([base.r * shade, base.g * shade, base.b * shade, 1.0])
				out = out.normalized() if out.length() > 0.01 else Vector3.UP
				clumps.append_array([out.x, out.y, out.z, rng.randf()])
				nc += 1
				put(shadows, mid)
				ns += 1
	return {"grass": [ng, grass], "clumps": [nc, clumps], "shadows": [ns, shadows]}


## Clumps of berry bushes standing on the given cells: [count, buffer] like crowns.
static func bushes(cells: Array[Vector3i]) -> Array:
	var buf := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	var offsets := [Vector2(-3, 0), Vector2(3, 1), Vector2(0, 5)]
	for cell in cells:
		rng.seed = hash(cell)
		var mid := (Vector3(cell) + Vector3(0.5, 0.0, 0.5)) * CELL
		for o in offsets:
			var p := mid + Vector3((o.x + rng.randi_range(-1, 1)) * PX, 0.4 + o.y * PX, 0.0)
			put(buf, PixelView.snap(p))
			var shade := rng.randf_range(0.9, 1.05)
			# Alpha below 1 marks a clump with berries (see leaves.gdshader).
			buf.append_array([0.3 * shade, 0.46 * shade, 0.22 * shade, 0.5])
			var out := Vector3(o.x / 4.0, 0.6 + o.y / 6.0, 0.3).normalized()
			buf.append_array([out.x, out.y, out.z, rng.randf()])
	return [cells.size() * offsets.size(), buf]


## Appends a translation-only transform in MultiMesh buffer order.
static func put(buf: PackedFloat32Array, p: Vector3) -> void:
	buf.append_array([1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z])
