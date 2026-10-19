// Tree crowns made of small leaf cluster cards (MultiMesh, see foliage.gd). Like
// t3ssel8r's trees, every card takes the normal of the crown as a whole, so the
// stepped light gives the crown (not each card) a lit side and a shaded underside;
// single leaves of the texture tilt that normal a little, so band edges run along
// leaves instead of smooth curves. Cards sway in whole pixels, thin out in winter,
// take snow on top, and turn see-through around the player when they hide them.
// INSTANCE_CUSTOM: xyz = outward normal of the crown, w = sway phase.
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
	if (m.a < 0.5 || center.y > cut_height + 0.01) {
		discard;
	}
	vec2 texel = floor(vec2(center.x, center.z - center.y) * TEXELS + UV * clump_size * TEXELS);
	// Leaves fall cluster by cluster, and single leaves of the remaining clusters
	// thin out (the green and blue of a texel tell its leaf apart).
	float leaf = hash12(m.gb * 97.0 + custom.w * 31.0);
	if (hash13(floor(center)) > leaf_amount || leaf > 0.6 + 0.4 * leaf_amount) {
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
	// The crown's normal, tilted by the leaf this texel belongs to.
	vec2 tilt = m.gb * 2.0 - 1.0;
	vec3 n = normalize(custom.xyz + vec3(tilt.x * 0.45, tilt.y * 0.4, -tilt.y * 0.15));
	// Autumn colours differ from tree to tree.
	vec3 season = foliage_tint * (1.0 + (hash12(floor(center.xz / 3.0) + 5.0) - 0.5) * (foliage_tint - 1.0) * vec3(0.5, 0.8, 1.0));
	vec3 col = tint.rgb * season * mix(0.84, 1.1, m.r);
	// The underside of the crown is shaded by the crown itself, whatever the sun does:
	// two steps darker toward the bottom, the step edges running along leaves.
	float under = custom.y + tilt.y * 0.25;
	col *= under < -0.2 ? 0.72 : (under < 0.2 ? 0.88 : 1.0);
	// Clumps marked in the alpha of their colour carry berries.
	if (tint.a < 0.99 && hash12(texel + 11.0) > 0.95 && leaf_amount > 0.5) {
		col = vec3(0.72, 0.14, 0.16) * mix(0.8, 1.2, m.r);
	}
	// Snow lies on the leaves of the crown's top.
	if (under > 0.45 && fract(leaf * 7.3) < snow_amount * 1.2 - 0.1) {
		col = vec3(0.9, 0.93, 1.0);
	}
	col *= 1.0 - 0.25 * wetness;
	ALBEDO = col * cut_shade(center.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(center);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
	// Some sunlight comes through the leaves, so the shaded side stays green, not black.
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += LIGHT_COLOR * 0.15 / PI;
	}
}
