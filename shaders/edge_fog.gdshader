// The fog over the edge of the world built (edge_haze.gd, setting «Туман на краю»): a dense
// white fog over the chunks on the screen with no ground yet, which thins out over the built
// chunks beside them and, once a chunk is built, melts over it by dithering (no clouds
// over it, user 2026-11-16). `amounts` holds how much fog each chunk has
// (0..1, a texel a chunk, see EdgeHaze), read between the chunks' middles, so the fog's edge
// lies across the borders.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D amounts : filter_linear;
// The world point (x, z) of the texture's corner and how many world units it spans.
uniform vec2 origin = vec2(0.0);
uniform float span = 256.0;
// The fog's light (white by day, towards the sky's background at night): the same colour
// as the background while the fog is on (Sky), so the two meet with no seam.
uniform vec3 color SRGB = vec3(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	float a = texture(amounts, (world_pos.xz - origin) / span).r;
	// A texel of the picture: the fog is drawn in its pixels.
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	float n = texture(cloud_noise, (texel + 0.5) / TEXELS / 9.0).r;
	// Whole over a chunk with no ground (a 1 there; 0.5 at its border with a built one),
	// thinning a few units into the built one, its rim torn by the noise; melts by
	// dithering in pixels.
	float fog_d = smoothstep(0.12, 0.5, a + (n - 0.5) * 0.3);
	if (fog_d < bayer4(texel)) {
		discard;
	}
	ALBEDO = color;
	COMPAT_ALBEDO
}
