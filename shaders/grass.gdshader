// Grass tufts standing on grass tops (MultiMesh, see foliage.gd). Coloured from the
// ground texture under each tuft, lighter at the tips; tips sway with the wind in
// whole pixels and bend away from the player. They sink under snow, grow in patches
// (see ground_patch) and stand up again around fires.
// INSTANCE_CUSTOM: x = variant 0..3, y = brightness, z = sway phase.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

#include "res://shaders/common.gdshaderinc"

global uniform sampler2D terrain_atlas : source_color, filter_nearest;
uniform sampler2D tuft_texture : filter_nearest;

const float SIZE = 0.5;
const int GRASS_TOP = 3;

varying vec3 root;
varying flat vec3 custom;
varying flat float snow_here;
varying float clouds;

void vertex() {
	root = VERTEX - vec3((UV.x - 0.5) * SIZE, (1.0 - UV.y) * SIZE, 0.0);
	custom = INSTANCE_CUSTOM.xyz;
	float tip = 1.0 - UV.y;
	float sway = sin(TIME * 1.6 + root.x * 0.9 + root.z * 0.5 + custom.z * 6.28) * (0.6 + length(wind) * 1.2) + wind.x * 1.5;
	vec2 away = root.xz - player_pos.xz;
	float d = length(away);
	if (d < 0.6 && abs(root.y - player_pos.y) < 0.6) {
		sway += sign(away.x + 0.001) * 2.0 * (1.0 - d / 0.6) + 0.5 * sign(away.x);
	}
	VERTEX.x += round(sway) / TEXELS * tip;
	snow_here = snow_amount * (1.0 - warm_spot(root, custom.z));
	VERTEX.y = root.y + (VERTEX.y - root.y) * (1.0 - snow_here * 0.9);
	VERTEX = shear(VERTEX);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 cell = vec2(float(int(custom.x + 0.5)) * 8.0, 0.0);
	vec4 m = texture(tuft_texture, (cell + UV * 8.0) / vec2(32.0, 8.0));
	if (m.a < 0.5 || root.y > cut_height + 0.01 || snow_here > 0.85) {
		discard;
	}
	// No tufts on bare spots, fewer on thin meadows, all of them on lush islands.
	float patch = ground_patch(root.xz, 0.0);
	if (bare_ground(root.xz) > 0.5 || custom.z > 0.2 + patch * 1.3) {
		discard;
	}
	ivec2 t = tile_mirror(ivec2(floor(fract(root.xz) * TEXELS)), floor(root.xz));
	vec2 origin = vec2(float(GRASS_TOP % 8), float(GRASS_TOP / 8)) * TEXELS;
	vec3 ground = texture(terrain_atlas, (origin + vec2(t) + 0.5) / (8.0 * TEXELS)).rgb;
	vec3 col = ground * grass_tint * grass_variation(root.xz) * mix(0.8, 1.18, m.r) * custom.y;
	col *= 1.0 - 0.3 * wetness * (1.0 - 0.7 * warm_spot(root, custom.z));
	ALBEDO = col * cut_shade(root.y);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(root);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
}
