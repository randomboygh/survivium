extends RefCounted
## Growing vertex buffers for one mesh surface.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


## `p` and `uv` hold 4 corners in clockwise order (Godot front faces). `packed` goes to
## UV2 and is decoded by the shader (see world.gdshader).
func quad(p: Array, n: Vector3, uv: Array, color: Color, packed: Vector2) -> void:
	var start := verts.size()
	for i in 4:
		verts.append(p[i])
		normals.append(n)
		uvs.append(uv[i])
		uv2s.append(packed)
		colors.append(color)
	indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))


func is_empty() -> bool:
	return verts.is_empty()


func to_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
