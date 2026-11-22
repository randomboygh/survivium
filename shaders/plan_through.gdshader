// The ground the blueprint digs out (PlanView, PlanGhost): its shape tinted red through
// the ground over it, so its depth shows; hidden above the level cut.
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, cull_back, depth_test_disabled, depth_draw_never, shadows_disabled;

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
	COMPAT_ALBEDO
}
