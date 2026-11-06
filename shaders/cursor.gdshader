// The cursor frame round the cells a tap or the action button works on: one-pixel lines
// over everything (see cursor.gd), hidden above the level cut like the cells.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	// The lines' own colour (the cursor's light and red ones), white where none is given.
	ALBEDO = color.rgb * COLOR.rgb;
	ALPHA = color.a * COLOR.a;
}
