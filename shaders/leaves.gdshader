// Tree crowns made of round leaf clumps (MultiMesh, see foliage.gd). Each clump is
// shaded as a small ball, bent toward the outside of the crown, so the stepped light
// gives each clump a lit cap and a shaded underside, like t3ssel8r's trees. Clumps sway in whole pixels, thin out in winter, take
// snow on top, and turn see-through around the player when they hide them.
// INSTANCE_CUSTOM: xyz = outward direction of the crown, w = sway phase.
// COLOR: per-clump tint.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D clump_texture : filter_nearest;
uniform float clump_size = 1.25;

varying vec3 center;
varying flat vec4 custom;
varying vec4 tint;
varying float clouds;

void vertex() {
	center = VERTEX - vec3((UV.x - 0.5) * clump_size, (0.5 - UV.y) * clump_size, 0.0);
	custom = INSTANCE_CUSTOM;
	tint = COLOR;
	float sway = sin(TIME * 1.1 + center.x * 0.4 + custom.w * 6.28) * (0.3 + length(wind) * 1.4);
	VERTEX.x += round(sway) / TEXELS;
	VERTEX = shear(VERTEX);
}

void fragment() {
	float variant = mod(floor(custom.w * 4.0), 4.0);
	vec4 m = texture(clump_texture, vec2((variant + UV.x) / 4.0, UV.y));
	vec2 texel = floor(vec2(center.x, center.z - center.y) * TEXELS + UV * clump_size * TEXELS);
	if (m.a < 0.5 || cut_dither(center.y, texel)) {
		discard;
	}
	// Leaves fall clump by clump (the same cells as their shadow discs), and the
	// remaining clumps thin out a little.
	if (hash13(floor(center)) > leaf_amount || hash12(texel + custom.w * 31.0) > 0.6 + 0.4 * leaf_amount) {
		discard;
	}
	// See-through around the player when the clump is nearer the viewer than them.
	vec2 frag = vec2(center.x + (UV.x - 0.5) * clump_size, center.z - center.y - (0.5 - UV.y) * clump_size);
	vec2 body = vec2(player_pos.x, player_pos.z - player_pos.y - 0.5);
	if (center.y + center.z > player_pos.y + player_pos.z + 1.0 && length(frag - body) < 1.1) {
		ivec2 f = ivec2(FRAGCOORD.xy);
		if ((f.x + f.y) % 2 == 0) {
			discard;
		}
	}
	vec2 q = (UV - 0.5) * 2.0;
	q.y = -q.y;
	float nz = sqrt(max(0.0, 1.0 - dot(q, q)));
	vec3 ball = q.x * vec3(1.0, 0.0, 0.0) + q.y * vec3(0.0, 0.7071, -0.7071) + nz * vec3(0.0, 0.7071, 0.7071);
	// The clump's own roundness bent toward the outside of the crown, so each clump
	// gets a clean lit cap and a shaded underside; the leafy lumps of the texture
	// (not per-texel noise) break the band edges up.
	vec3 n = normalize(ball * 0.8 + custom.xyz * 0.6 + (m.r - 0.5) * vec3(0.3, 1.5, 0.0) + vec3(0.0, 0.15, 0.0));
	// Autumn colours differ from clump to clump.
	vec3 season = foliage_tint * (1.0 + (hash12(floor(center.xz) + 5.0) - 0.5) * (foliage_tint - 1.0) * vec3(0.5, 0.8, 1.0));
	vec3 col = tint.rgb * season * mix(0.86, 1.06, m.r);
	// Clumps marked in the alpha of their colour carry berries.
	if (tint.a < 0.99 && hash12(texel + 11.0) > 0.95 && leaf_amount > 0.5) {
		col = vec3(0.72, 0.14, 0.16) * mix(0.8, 1.2, m.r);
	}
	if (n.y > 0.25 && hash12(texel * 1.7) < snow_amount * 1.3 - 0.1) {
		col = vec3(0.9, 0.93, 1.0);
	}
	col *= 1.0 - 0.25 * wetness;
	float fade = depth_fade(center.y);
	ALBEDO = col * (1.0 - fade);
	EMISSION = depth_haze * fade;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(center);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
}
