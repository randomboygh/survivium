// The fog over the edge of the world built (edge_haze.gd, setting «Туман на краю»): a dense
// white fog along the camera's rays that end on a chunk with no ground yet (user
// 2026-11-16), so it is drawn where the chunk's square on the plane of the ground (the land
// round about, EdgeHaze.plane_y) is, over everything; a jump does not move it. Whole over
// the square and DENSE units past its edges, it thins out over REACH units further into the
// built chunks beside it, from a corner round; once a chunk is built its fog melts by dithering. `amounts` holds how much fog each
// chunk has (0..1, a texel a chunk, see EdgeHaze).
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D amounts : filter_nearest;
// The world point (x, z) of the texture's corner, how many world units it spans and how
// many chunks a side it holds.
uniform vec2 origin = vec2(0.0);
uniform float span = 256.0;
uniform int grid = 32;
// The fog's light (white by day, towards the sky's background at night).
uniform vec3 color SRGB = vec3(1.0);

// The fog's own tone.
const vec3 FOG_TONE = vec3(0.9, 0.93, 0.98);
// World units past a missing chunk's edge the fog stays whole, and over which it then thins.
const float DENSE = 0.5;
const float REACH = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	float size = span / float(grid);
	vec2 p = world_pos.xz - origin;
	ivec2 home = ivec2(floor(p / size));
	// The fog of each chunk round, by how far the point is from its square.
	float fog_d = 0.0;
	for (int dz = -1; dz <= 1; dz++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 k = home + ivec2(dx, dz);
			if (k.x < 0 || k.y < 0 || k.x >= grid || k.y >= grid) {
				continue;
			}
			float a = texelFetch(amounts, k, 0).r;
			if (a <= 0.0) {
				continue;
			}
			vec2 lo = vec2(k) * size;
			vec2 d = max(max(lo - p, p - lo - size), vec2(0.0));
			float t = 1.0 - clamp((length(d) - DENSE) / REACH, 0.0, 1.0);
			fog_d = max(fog_d, a * t * t);
		}
	}
	// A texel of the picture: the fog is drawn in its pixels, its rim torn by the noise.
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	float n = texture(cloud_noise, (texel + 0.5) / TEXELS / 9.0).r;
	// The noise only scales fog that is there: none where there is none (it added dots
	// all over the quad, user 2026-11-16).
	fog_d = fog_d >= 1.0 ? 1.0 : clamp(fog_d * (1.0 + (n - 0.5) * 0.8), 0.0, 1.0);
	if (fog_d <= bayer4(texel)) {
		discard;
	}
	ALBEDO = color * FOG_TONE;
	COMPAT_ALBEDO
}
