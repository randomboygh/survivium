// The fog over the edge of the world built (edge_haze.gd, setting «Туман на краю»): a dense
// white fog over the chunks on the screen with no ground yet, with white heads of cumulus
// over it, which thins out over the built chunks beside them and, once a chunk is built,
// dissolves over it: the clouds shrink into the fog and the fog melts by dithering.
// `amounts` holds how much fog each chunk has (0..1, a texel a chunk, see EdgeHaze), read
// between the chunks' middles, so the fog's edge lies across the chunks' borders.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D amounts : filter_linear;
// The world point (x, z) of the texture's corner and how many world units it spans.
uniform vec2 origin = vec2(0.0);
uniform float span = 256.0;
// The fog's light (white by day, towards the sky's background at night), and the clouds'
// shaded underside.
uniform vec3 color SRGB = vec3(1.0);
uniform vec3 shade SRGB = vec3(0.8, 0.83, 0.9);

// The fog's own shade under the clouds, and where the noise turns into a cloud's head.
const vec3 FOG_SHADE = vec3(0.91, 0.92, 0.95);
const float CLOUD_FROM = 0.62;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

// The clouds' noise at `q` (world units on the image plane): big round heads with
// billowy edges, drifting slowly.
float puffs(vec2 q) {
	vec2 d = vec2(TIME * 0.08, TIME * 0.03);
	return texture(cloud_noise, (q + d) / 22.0).r * 0.75 + texture(cloud_noise, (q + d) / 7.0 + 0.37).r * 0.25;
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	float a = texture(amounts, (world_pos.xz - origin) / span).r;
	// A texel of the picture: the fog and the clouds are drawn in its pixels.
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	vec2 q = (texel + 0.5) / TEXELS;
	float n = puffs(q);
	// The fog: whole over a chunk with no ground (a 1 there; 0.5 at its border with a built
	// one), thinning a few units into the built one, its rim torn by the noise.
	float fog_d = smoothstep(0.12, 0.5, a + (n - 0.5) * 0.3);
	// The heads of cumulus: where the noise is high, bigger the more fog there is; as a
	// chunk's fog dissolves they shrink into it.
	float rise = a * 0.12 - CLOUD_FROM;
	float head = n + rise;
	// Down the picture is +y on the image plane: a head's flat underside is where the noise
	// a little lower falls below it, its lit top where the noise above does.
	float below = puffs(q + vec2(0.0, 0.3)) + rise;
	float above = puffs(q - vec2(0.0, 0.25)) + rise;
	vec3 c = color * FOG_SHADE;
	float alpha = fog_d;
	if (head > 0.0) {
		alpha = 1.0;
		c = color;
		if (below < 0.0) {
			c = shade * color;
		} else if (above >= 0.0) {
			c = color * 0.97;
		}
	}
	// Melts by dithering in pixels, whole where the fog is whole.
	if (alpha < bayer4(texel)) {
		discard;
	}
	ALBEDO = c;
	COMPAT_ALBEDO
}
