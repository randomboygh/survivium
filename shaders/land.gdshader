// The borders of the land claimed (land_view.gd): thin lines over the ground in the
// colour of each vertex, shown through what stands in front, hidden above the level cut.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
