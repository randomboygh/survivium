// Pixel particles (fire, sparks, smoke, rain, snow, fireflies, falling leaves):
// tiny upright squares, coloured by the particle's colour ramp.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, blend_mix, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float brightness = 1.0;
// 1 for weather (rain, snow, leaves, pollen, fireflies), which never falls under a
// roof, an overhang or a cave ceiling; 0 for fire, which burns anywhere.
uniform float sky_only = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (world_pos.y > cut_height + 0.01 || COLOR.a < 0.02) {
		discard;
	}
	if (sky_only > 0.5 && roofed(world_pos.xz, floor(world_pos.y / CELL))) {
		discard;
	}
	ALBEDO = COLOR.rgb * brightness;
	ALPHA = COLOR.a;
}
