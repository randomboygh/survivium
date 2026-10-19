extends RefCounted
## Grass tufts and tree crowns for one chunk, as MultiMesh instance buffers.
## Tufts stand on grass tops. A crown is drawn the way t3ssel8r draws his trees: leaf
## cluster cards cover its open faces, and each card is lit with the normal of the crown
## at that spot (away from the middle of the leaves around it), bent toward a few large
## bumps, so the light falls on the crown as one mass with some big lumps instead of on
## each card. Every exposed leaf cell also gets a flat shadow-only disc, so crowns cast
## round shadows.

const Mat := preload("res://src/shared/materials.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const WorldData := preload("res://src/shared/world_data.gd")

## Lush patches keep all of them, thin meadows fewer (see grass.gdshader).
const TUFTS_PER_CELL := 7
const TUFT_SIZE := 0.5
## Leaf cluster cards: size in cells (16 px, see PixelTextures.CLUMP), cards on each
## open face of a leaf cell the camera sees.
const CLUMP_SIZE := 1.0
const CARDS_PER_FACE := 2
## Leaves within this many cells give the crown's middle for the light.
const CROWN_REACH := 2
## How much the bumps of a crown (a smooth wave about two cells across) bend its normal.
const BUMP := 0.45
## Bushes are made of smaller clusters, this many pixels across, this many per bush.
const BUSH_CLUMP := 10
const BUSH_CARDS := 6
const BUSH_DISC := 0.9
const SHADOW_DISC := 1.6
const PX := 1.0 / 16.0


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
## 3D transforms; grass has custom data, clumps colours and custom data.
static func build_chunk(w, x0: int, z0: int, size: int) -> Dictionary:
	var cells: PackedByteArray = w.cells
	var sx: int = w.size_x
	var sy: int = w.size_y
	var sz: int = w.size_z
	var layer := sx * sz
	var x1 := mini(x0 + size, sx)
	var z1 := mini(z0 + size, sz)
	var grass := PackedFloat32Array()
	var clumps := PackedFloat32Array()
	var shadows := PackedFloat32Array()
	var ng := 0
	var nc := 0
	var ns := 0
	var rng := RandomNumberGenerator.new()
	for y in sy:
		for z in range(z0, z1):
			for x in range(x0, x1):
				var i := y * layer + z * sx + x
				var m := cells[i]
				if m == Mat.GRASS:
					if y + 1 < sy and cells[i + layer] != Mat.AIR:
						continue
					rng.seed = hash(Vector3i(x, y, z))
					var mask: int = w.slope_mask(x, y, z)
					for k in TUFTS_PER_CELL:
						var fx := rng.randi_range(1, 15) * PX
						var fz := rng.randi_range(1, 15) * PX
						put(grass, Vector3(x + fx, y + WorldData.slope_height(mask, fx, fz), z + fz))
						grass.append_array([float(rng.randi_range(0, 3)), rng.randf_range(0.88, 1.1), rng.randf(), 0.0])
						ng += 1
				elif m == Mat.LEAVES:
					var faces := _open_faces(w, x, y, z)
					if faces.is_empty():
						continue
					var middle := _crown_middle(w, x, y, z)
					rng.seed = hash(Vector3i(x, y, z))
					var tree := hash(Vector2i(x / 3, z / 3)) % 3
					var base: Color = [Color(0.27, 0.43, 0.25), Color(0.3, 0.46, 0.22), Color(0.25, 0.41, 0.27)][tree]
					for f in faces:
						# Cards cover each face the camera can see, poking out of it a
						# little, so the outline is a ragged edge of leaves and no gap
						# shows the trunk inside.
						var count := CARDS_PER_FACE
						for k in count:
							var c := Vector3(x + 0.5, y + 0.5, z + 0.5) + Vector3(f) * (0.4 + rng.randi_range(0, 3) * PX)
							var spread := Vector3(rng.randi_range(-4, 4), rng.randi_range(-4, 4), rng.randi_range(-4, 4)) * PX
							c += spread - Vector3(f) * Vector3(f).dot(spread)
							c = PixelView.snap(c)
							put(clumps, c)
							clumps.append_array([base.r, base.g, base.b, 1.0])
							var n := _card_normal(c, middle)
							clumps.append_array([n.x, n.y, n.z, rng.randf()])
							nc += 1
					put(shadows, Vector3(x + 0.5, y + 0.5, z + 0.5))
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
			put(buf, PixelView.snap(Vector3(cell.x + 0.5, cell.y + 0.3, cell.z + 0.5) + o))
			# Alpha below 1 marks a cluster with berries (see leaves.gdshader).
			buf.append_array([0.3, 0.46, 0.22, 0.5])
			var n := (o + Vector3(0.0, 0.25, 0.0)).normalized()
			buf.append_array([n.x, n.y, n.z, rng.randf()])
	return [cells.size() * BUSH_CARDS, buf]


## Faces of a leaf cell the camera can see (top, south, east, west) that touch
## neither leaves nor a trunk.
static func _open_faces(w, x: int, y: int, z: int) -> Array[Vector3i]:
	var open: Array[Vector3i] = []
	for d in [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
		var n: int = w.get_cell(x + d.x, y + d.y, z + d.z)
		if n != Mat.LEAVES and n != Mat.LOG:
			open.append(d)
	return open


## Middle of the leaves within CROWN_REACH of a leaf cell, in world units.
static func _crown_middle(w, x: int, y: int, z: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for dy in range(-CROWN_REACH, CROWN_REACH + 1):
		for dz in range(-CROWN_REACH, CROWN_REACH + 1):
			for dx in range(-CROWN_REACH, CROWN_REACH + 1):
				if w.get_cell(x + dx, y + dy, z + dz) == Mat.LEAVES:
					sum += Vector3(dx, dy, dz)
					n += 1
	return Vector3(x + 0.5, y + 0.5, z + 0.5) + sum / n


## Normal for a card at `c`: away from the crown's middle, bent by a few large bumps,
## and a little up, so a lone or flat canopy faces the sky.
static func _card_normal(c: Vector3, middle: Vector3) -> Vector3:
	var bump := Vector3(sin(c.y * 2.1 + c.z * 1.3 + 1.0), sin(c.x * 1.7 + c.z * 2.3), sin(c.x * 1.1 + c.y * 1.9 + 2.0))
	var n := (c - middle).normalized() + bump * BUMP + Vector3(0.0, 0.3, 0.0)
	return n.normalized()


## Appends a translation-only transform in MultiMesh buffer order.
static func put(buf: PackedFloat32Array, p: Vector3) -> void:
	buf.append_array([1.0, 0.0, 0.0, p.x, 0.0, 1.0, 0.0, p.y, 0.0, 0.0, 1.0, p.z])
