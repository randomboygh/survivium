// The blueprint's ghost (PlanView): the shape the blueprint will make, merged and see-through,
// its faces tinted by the vertex colour (cold blue to build, red to dig out; alpha in it).
// Hidden behind what stands in front of it and above the level cut, like the cells; the
// ground to dig is drawn through the ground (plan_cut.gdshader). Drawn twice (PlanView):
// first with `strength` 0 only into depth, then its colour over that, so only its nearest
// faces show and none is tinted twice.
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, cull_back, depth_draw_always, shadows_disabled;

uniform float strength = 1.0;

#include "res://shaders/common.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos) || above_build_cut(world_pos)) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * strength;
	COMPAT_ALBEDO
}
