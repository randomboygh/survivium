extends RefCounted
## Growing vertex buffers for one mesh surface.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


## `p` and `uv` hold 4 corners in clockwise order (Godot front faces). `packed` goes to
## UV2 and is decoded by the shader (see world.gdshader). `cols`, when given, is a
## colour per corner in place of `color`.
func quad(p: Array, n: Vector3, uv: Array, color: Color, packed: Vector2, cols := []) -> void:
	var start := verts.size()
	for i in 4:
		verts.append(p[i])
		normals.append(n)
		uvs.append(uv[i])
		uv2s.append(packed)
		colors.append(cols[i] if cols else color)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


## One triangle, corners clockwise like `quad`.
func tri(p: Array, n: Vector3, uv: Array, color: Color, packed: Vector2, cols := []) -> void:
	var start := verts.size()
	for i in 3:
		verts.append(p[i])
		normals.append(n)
		uvs.append(uv[i])
		uv2s.append(packed)
		colors.append(cols[i] if cols else color)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2]))


## One triangle with a normal per corner (a curved surface), corners clockwise.
func tri_n(p: Array, n: Array, uv: Array, color: Color, packed: Vector2) -> void:
	var start := verts.size()
	for i in 3:
		verts.append(p[i])
		normals.append(n[i])
		uvs.append(uv[i])
		uv2s.append(packed)
		colors.append(color)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2]))


func is_empty() -> bool:
	return verts.is_empty()


## The mesh, its vertices scaled by `scale` (cells to world units for the world).
func to_mesh(scale := 1.0) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts if scale == 1.0 else Transform3D.IDENTITY.scaled(Vector3.ONE * scale) * verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
