// Pixel particles (fire, sparks, smoke, rain, snow, fireflies, falling leaves):
// tiny upright squares, coloured by the particle's colour ramp.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, blend_mix, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float brightness = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (world_pos.y > cut_height + 0.01 || COLOR.a < 0.02) {
		discard;
	}
	ALBEDO = COLOR.rgb * brightness;
	ALPHA = COLOR.a;
}
