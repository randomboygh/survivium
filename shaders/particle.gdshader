// Pixel particles (fire, sparks, smoke, rain, snow, fireflies, falling leaves):
// tiny upright squares, coloured by the particle's colour ramp; with a `shape` its
// opaque pixels only (the star sparkles over a death sack).
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, blend_mix, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float brightness = 1.0;
// 1 for weather (rain, snow, leaves, pollen, fireflies), which never falls under a
// roof, an overhang or a cave ceiling; 0 for fire, which burns anywhere.
uniform float sky_only = 0.0;
// How lit the open sky is: weather is unshaded, so it dims with the night.
uniform float light = 1.0;
uniform sampler2D shape : filter_nearest, source_color, hint_default_white;

varying vec3 world_pos;

void vertex() {
	// Upright: turned to the camera about its origin.
	VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (world_pos.y > cut_height + 0.01 || COLOR.a < 0.02) {
		discard;
	}
	if (sky_only > 0.5 && roofed(world_pos.xz, world_pos.y)) {
		discard;
	}
	vec4 s = texture(shape, UV);
	if (s.a < 0.5) {
		discard;
	}
	ALBEDO = COLOR.rgb * s.rgb * brightness * light;
	ALPHA = COLOR.a;
}
