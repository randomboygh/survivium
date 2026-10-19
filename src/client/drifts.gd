extends RefCounted
## Snowdrifts: low mounds on open level ground that show up with the snow cover. They
## are drawn with the terrain shader, so they take the snow colour and the stepped
## light, and they are never walked on: the body passes through them.

const Mat := preload("res://src/shared/materials.gd")
const PixelView := preload("res://src/client/pixel_view.gd")
const WorldData := preload("res://src/shared/world_data.gd")

const CELL := WorldData.CELL
## UV2.x of the terrain shader for "colour from COLOR only" (tile 63, no edges).
const PLAIN := 63.0
## Snow in the shade of the mound's steep sides (its tops take the snow pattern).
const SHADE := Color(0.8, 0.84, 0.92)
## One candidate column in this many, on a grid of every other column.
const SPARSITY := 23


## A faceted low dome one unit across and one high, flat shaded, with the vertex data
## the terrain shader expects.
static func mound_mesh() -> ArrayMesh:
	var sides := 8
	# Rings from the base up: radius and height as fractions.
	var rings := [Vector2(0.5, 0.0), Vector2(0.4, 0.5), Vector2(0.22, 0.85)]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in rings.size():
		var lower: Vector2 = rings[i]
		var upper: Vector2 = rings[i + 1] if i + 1 < rings.size() else Vector2(0.0, 1.0)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p00 := Vector3(cos(a0) * lower.x, lower.y, sin(a0) * lower.x)
			var p01 := Vector3(cos(a1) * lower.x, lower.y, sin(a1) * lower.x)
			var p10 := Vector3(cos(a0) * upper.x, upper.y, sin(a0) * upper.x)
			var p11 := Vector3(cos(a1) * upper.x, upper.y, sin(a1) * upper.x)
			_triangle(verts, normals, p00, p10, p01)
			if upper.x > 0.0:
				_triangle(verts, normals, p01, p10, p11)
	var n := verts.size()
	var uvs := PackedVector2Array()
	uvs.resize(n)
	var uv2 := PackedVector2Array()
	uv2.resize(n)
	uv2.fill(Vector2(PLAIN, 0.0))
	var colors := PackedColorArray()
	colors.resize(n)
	colors.fill(SHADE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _triangle(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	# Wound to face outward.
	if nrm.dot(a + b + c) < 0.0:
		var t := b
		b = c
		c = t
		nrm = -nrm
	verts.append_array([a, b, c])
	normals.append_array([nrm, nrm, nrm])


## Mound transforms for the world: [count, MultiMesh buffer]. Mounds lie on level
## loose ground with level open ground all around, a few cells apart, each of its
## own size, stretch and turn.
static func build(w) -> Array:
	var buf := PackedFloat32Array()
	var count := 0
	var rng := RandomNumberGenerator.new()
	var sea: int = w.sea_level
	for z in range(2, w.size_z - 2, 2):
		for x in range(2, w.size_x - 2, 2):
			if hash(Vector2i(x, z)) % SPARSITY != 0:
				continue
			var y: int = w.surface_y(x, z)
			if y <= sea or y >= w.size_y - 1 or not Mat.can_slope(w.get_cell(x, y - 1, z)) \
					or w.slope_mask(x, y - 1, z) != WorldData.FULL:
				continue
			var flat := true
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if w.surface_y(x + dx, z + dz) != y or w.get_cell(x + dx, y, z + dz) != Mat.AIR:
						flat = false
			if not flat:
				continue
			rng.seed = hash(Vector3i(x, y, z))
			var r := rng.randf_range(0.7, 1.3)
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
				* Basis.from_scale(Vector3(r, rng.randf_range(0.12, 0.25), r * rng.randf_range(0.65, 1.0)))
			var p := PixelView.snap(Vector3(x + 0.5 + rng.randf_range(-0.3, 0.3), y, z + 0.5 + rng.randf_range(-0.3, 0.3)) * CELL)
			buf.append_array([basis.x.x, basis.y.x, basis.z.x, p.x, basis.x.y, basis.y.y, basis.z.y, p.y,
				basis.x.z, basis.y.z, basis.z.z, p.z])
			count += 1
	return [count, buf]
