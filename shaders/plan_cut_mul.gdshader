// The ground the blueprint digs out, first pass (PlanView): what is there takes the green
// and blue out, so the red over it (plan_cut.gdshader, the next pass) reads red on grass.
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mul, cull_back, depth_test_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform vec3 factor = vec3(1.0, 0.62, 0.55);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	ALBEDO = factor;
	COMPAT_MUL
}
