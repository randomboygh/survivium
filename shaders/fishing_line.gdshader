// A fishing line and its float (see fishing_line.gd): one-pixel lines in the colours of
// their vertices, hidden behind what stands in front and above the level cut like the
// cells.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, shadows_disabled;

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
}
