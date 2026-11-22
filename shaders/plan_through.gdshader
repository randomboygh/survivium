// See-through bodies drawn over the ground (PlanGhost): the ground the blueprint digs out,
// red, so its depth shows, and the build mode's strokes (Cursor.show_boxes), these with a
// light rim one pixel wide along the edges of the body (UV the place on a face, UV2.x its
// open edges, bit k from corner k to the next); hidden above the level cut.
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
	int rims = int(round(UV2.x));
	if (rims > 0) {
		// One pixel of the cell's 8 in from each open edge.
		float w = 1.0 / 8.0;
		bool rim = ((rims & 1) != 0 && UV.y < w) || ((rims & 2) != 0 && UV.x > 1.0 - w)
			|| ((rims & 4) != 0 && UV.y > 1.0 - w) || ((rims & 8) != 0 && UV.x < w);
		if (rim) {
			ALBEDO = mix(COLOR.rgb, vec3(1.0), 0.6);
			ALPHA = min(1.0, COLOR.a + 0.3);
		}
	}
	COMPAT_ALBEDO
}
