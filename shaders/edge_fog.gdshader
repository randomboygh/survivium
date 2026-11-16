// The fog over the edge of the world built (edge_haze.gd, setting «Туман на краю»): a dense
// white fog over the chunks on the screen with no ground yet, with puffy pixel cumulus over
// it (user's examples 2026-11-16: heaps of round heads, white where the light falls, pale
// blue in their shade, a flat base), which thins out over the built chunks beside them and,
// once a chunk is built, dissolves over it: the clouds' heads shrink and the fog melts by
// dithering. `amounts` holds how much fog each chunk has (0..1, a texel a chunk, see
// EdgeHaze), read between the chunks' middles, so the fog's edge lies across the borders.
shader_type spatial;
render_mode world_vertex_coords, unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D amounts : filter_linear;
// The world point (x, z) of the texture's corner and how many world units it spans.
uniform vec2 origin = vec2(0.0);
uniform float span = 256.0;
// The fog's light (white by day, towards the sky's background at night), and the clouds'
// shade (multiplies it).
uniform vec3 color SRGB = vec3(1.0);
uniform vec3 shade SRGB = vec3(0.72, 0.82, 0.95);

// The fog's own tone under the clouds.
const vec3 FOG_TONE = vec3(0.9, 0.93, 0.98);
// A cloud a cell of CLOUD_CELL world units of the image plane (one cloud or none): a row of
// round heads on a flat base, a second tier of smaller ones over its middle and a crown.
const float CLOUD_CELL = 14.0;
const int HEADS = 9;
// How fast the clouds drift (world units a second).
const vec2 DRIFT = vec2(0.12, 0.02);

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
	VERTEX = shear(VERTEX);
}

vec2 hash2(vec2 c) {
	return fract(sin(vec2(dot(c, vec2(127.1, 311.7)), dot(c, vec2(269.5, 183.3)))) * 43758.5453);
}

// Head `i` of the cloud of cell `c` (hashes `h`), `big` its size: xy its middle, z its
// radius (0: none). Heads 0-4 the base row, 5-7 the tier over it, 8 the crown.
vec3 head(vec2 c, vec2 h, int i, vec2 mid, float big) {
	vec2 j = hash2(c + float(i) * 7.31) - 0.5;
	float t;
	float lift;
	float r;
	if (i < 5) {
		t = float(i) - 2.0;
		lift = 0.0;
		r = big * (1.0 - 0.18 * abs(t)) * (0.8 + 0.3 * j.x);
		if (abs(t) > 1.5 && h.y < 0.4) {
			return vec3(0.0);
		}
	} else if (i < 8) {
		t = float(i) - 6.0;
		lift = big * 1.0;
		r = big * (0.85 - 0.12 * abs(t)) * (0.8 + 0.3 * j.x);
	} else {
		t = (h.x - 0.5) * 0.8;
		lift = big * 1.9;
		r = big * 0.75 * (0.75 + 0.5 * h.y);
		if (h.y < 0.3) {
			return vec3(0.0);
		}
	}
	return vec3(mid + vec2(t * big * 1.05 + j.y * big * 0.3, -r * 0.5 - lift), r);
}

// How much fog there is (0..1) at world point `p` (x, z).
float fog_amount(vec2 p) {
	return texture(amounts, (p - origin) / span).r;
}

// The cloud head over `q` (image plane, world units; world point `p` of this pixel) nearest
// the viewer (lowest on the picture): xy where `q` is in it as a share of its radius (from
// its middle), w 1 when found; `low` how near `q` is to its cloud's flat base (1 on it). A
// cloud is as big as the fog under its middle is thick: it shrinks whole as that dissolves.
vec4 head_at(vec2 q, vec3 p, out float low) {
	vec4 best = vec4(0.0);
	float best_y = -1e9;
	low = 0.0;
	vec2 cell = floor(q / CLOUD_CELL);
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			vec2 h = hash2(c);
			if (h.x < 0.2) {
				continue;
			}
			// The cloud's base, anywhere in its cell (the rows staggered), and its size.
			vec2 mid = (c + vec2(0.2 + 0.6 * h.y, 0.45 + 0.5 * fract(h.x * 7.0))) * CLOUD_CELL;
			// The fog under the cloud's middle: from this pixel along the image plane to it
			// (right and up the picture), the shear undone.
			vec2 to = mid - q;
			vec2 right = vec2(-view_up.y, view_up.x);
			vec2 along = to.x * right - to.y * view_up;
			float grow = smoothstep(0.3, 0.9, fog_amount(p.xz + unshear_dir(vec3(along.x, 0.0, along.y)).xz));
			float big = (1.5 + 1.4 * h.x) * grow;
			if (big < 0.3) {
				continue;
			}
			float floor_y = mid.y + big * 0.3;
			if (q.y > floor_y || abs(q.x - mid.x) > big * 4.0 || q.y < mid.y - big * 4.0) {
				continue;
			}
			for (int i = 0; i < HEADS; i++) {
				vec3 o = head(c, h, i, mid, big);
				vec2 d = q - o.xy;
				// Nearer the viewer: the lower its bottom on the picture.
				float front = o.y + o.z;
				if (o.z > 0.0 && dot(d, d) < o.z * o.z && front > best_y) {
					best_y = front;
					best = vec4(d / o.z, o.z, 1.0);
					low = clamp(1.0 - (floor_y - q.y) / (big * 0.7), 0.0, 1.0);
				}
			}
		}
	}
	return best;
}

void fragment() {
	if (above_cut(world_pos)) {
		discard;
	}
	float a = fog_amount(world_pos.xz);
	// A texel of the picture: the fog and the clouds are drawn in its pixels.
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	vec2 q = (texel + 0.5) / TEXELS + DRIFT * TIME;
	float n = texture(cloud_noise, q / 9.0).r;
	// The fog: whole over a chunk with no ground (a 1 there; 0.5 at its border with a built
	// one), thinning a few units into the built one, its rim torn by the noise.
	float fog_d = smoothstep(0.12, 0.5, a + (n - 0.5) * 0.3);
	vec3 c = color * FOG_TONE;
	float alpha = fog_d;
	// The heads, as big as the fog is thick (they shrink as it dissolves).
	float low;
	vec4 h = head_at(q, world_pos, low);
	if (h.w > 0.0) {
		alpha = 1.0;
		// Three tones, as a pixel cloud's: white where the head's top faces the light,
		// pale blue on its lower side and round its rim (a head stands out of the one
		// behind it), blue at the flat base; their borders dithered.
		vec2 d = h.xy;
		float lit = -d.y * 0.9 - d.x * 0.25 - max(length(d) - 0.8, 0.0) * 2.5 - low * 0.9;
		lit += (bayer4(texel) - 0.5) * 0.2;
		if (lit > 0.05) {
			c = color;
		} else if (lit > -0.75) {
			c = color * mix(vec3(1.0), shade, 0.45);
		} else {
			c = color * shade;
		}
	}
	// Melts by dithering in pixels, whole where the fog is whole.
	if (alpha < bayer4(texel)) {
		discard;
	}
	ALBEDO = c;
	COMPAT_ALBEDO
}
