// The sphere of the view in a sphere itself, for a test (setting «Пещеры» → «Сфера:
// показать», CaveSphere): see-through, lit and casting a shadow, sheared like all else,
// over everything, so it shows where it stands under the ground too.
shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_never, depth_test_disabled, cull_back;

#include "res://shaders/common.gdshaderinc"

void vertex() {
	// The normal of a sheared surface: the shear undone, transposed.
	vec3 n = NORMAL;
	NORMAL = normalize(vec3(dot(n, unshear_dir(vec3(1.0, 0.0, 0.0))),
		dot(n, unshear_dir(vec3(0.0, 1.0, 0.0))), dot(n, unshear_dir(vec3(0.0, 0.0, 1.0)))));
	VERTEX = shear(VERTEX);
}

void fragment() {
	ALBEDO = vec3(0.35, 0.65, 1.0);
	ALPHA = 0.35;
	ROUGHNESS = 0.6;
}
