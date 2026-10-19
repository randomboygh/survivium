// Ground plants standing on the ground (MultiMesh, see foliage.gd and
// PixelTextures.build_plants): grass tufts coloured from the ground texture under them,
// lighter at the tips, and plants in their own colours: flowers, ears of dry grass,
// reeds and low herbs. Tips sway with the wind in whole pixels and bend away from the
// player. Tufts sink under snow and grow in patches (see ground_patch), flowers show on
// the lush patches and ears on the thin ones, reeds stand at the water, and all of
// them stand up again around fires.
// INSTANCE_CUSTOM: x = plant 0..13, y = brightness, z = sway phase and thinning draw.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

#include "res://shaders/common.gdshaderinc"

global uniform sampler2D terrain_atlas : source_color, filter_nearest;
uniform sampler2D plant_texture : filter_nearest;

const float WIDTH = 0.5;
const float HEIGHT = 1.0;
const float PLANTS = 14.0;
const int GRASS_TOP = 3;
// Kinds of plant by their index in the texture.
const int GRASS = 0;
const int FLOWER = 1;
const int EAR = 2;
const int REED = 3;
const int HERB = 4;

varying vec3 root;
varying flat vec3 custom;
varying flat float snow_here;
varying flat float sky;
varying flat int kind;
varying float clouds;

int kind_of(int plant) {
	return plant < 4 ? GRASS : (plant < 8 ? FLOWER : (plant < 10 ? EAR : (plant < 12 ? REED : HERB)));
}

void vertex() {
	root = VERTEX - vec3((UV.x - 0.5) * WIDTH, (1.0 - UV.y) * HEIGHT, 0.0);
	custom = INSTANCE_CUSTOM.xyz;
	kind = kind_of(int(custom.x + 0.5));
	float tip = 1.0 - UV.y;
	float sway = sin(TIME * 1.6 + root.x * 0.9 + root.z * 0.5 + custom.z * 6.28) * (0.6 + length(wind) * 1.2) + wind.x * 1.5;
	vec2 away = root.xz - player_pos.xz;
	float d = length(away);
	if (d < 0.6 && abs(root.y - player_pos.y) < 0.6) {
		sway += sign(away.x + 0.001) * 2.0 * (1.0 - d / 0.6) + 0.5 * sign(away.x);
	}
	VERTEX.x += round(sway) / TEXELS * tip;
	// Plants under a roof or an overhang see no snow and no rain.
	sky = roofed(root.xz, root.y) ? 0.0 : 1.0;
	snow_here = sky * snow_amount * (1.0 - warm_spot(root, custom.z));
	// Tufts and herbs sink under the snow, reeds and ears poke out of it.
	float sink = kind == REED ? 0.3 : (kind == EAR ? 0.5 : 0.9);
	VERTEX.y = root.y + (VERTEX.y - root.y) * (1.0 - snow_here * sink);
	VERTEX = shear(VERTEX);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 cell = vec2(float(int(custom.x + 0.5)) * 8.0, 0.0);
	vec4 m = texture(plant_texture, (cell + UV * vec2(8.0, 16.0)) / vec2(8.0 * PLANTS, 16.0));
	// Plants are too small to show above the cut.
	if (m.a < 0.5 || root.y > cut_height + 0.01) {
		discard;
	}
	float patch = ground_patch(root.xz, 0.0);
	bool bare = bare_ground(root.xz) > 0.5;
	vec3 col;
	if (kind == GRASS) {
		// No tufts on bare spots, about half of them on an ordinary meadow, all of
		// them on lush islands: the ground is meant to show between the tufts.
		if (bare || snow_here > 0.85 || custom.z > patch * 1.1 - 0.05) {
			discard;
		}
		ivec2 t = tile_mirror(ivec2(floor(fract(root.xz) * TEXELS)), floor(root.xz));
		vec2 origin = vec2(float(GRASS_TOP % 8), float(GRASS_TOP / 8)) * TEXELS;
		vec3 ground = texture(terrain_atlas, (origin + vec2(t) + 0.5) / (8.0 * TEXELS)).rgb;
		col = ground * grass_tint * grass_variation(root.xz) * mix(0.8, 1.18, m.r) * custom.y;
	} else if (kind == FLOWER) {
		// Flowers bloom on the lush patches and are gone under the first snow.
		if (bare || patch < 0.5 || snow_here > 0.3) {
			discard;
		}
		col = m.rgb * custom.y;
	} else if (kind == EAR) {
		// Dry ears stand where the grass is thin.
		if (bare || patch > 0.55 || snow_here > 0.6) {
			discard;
		}
		col = m.rgb * custom.y;
	} else if (kind == REED) {
		if (snow_here > 0.95) {
			discard;
		}
		col = m.rgb * mix(vec3(1.0), grass_tint, 0.5) * custom.y;
	} else {
		if (bare || snow_here > 0.85) {
			discard;
		}
		col = m.rgb * grass_tint * custom.y;
	}
	col *= 1.0 - 0.3 * sky * wetness * (1.0 - 0.7 * warm_spot(root, custom.z));
	float fade = depth_fade(root.y);
	ALBEDO = col * (1.0 - fade);
	EMISSION = depth_haze * fade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(root);
}

void light() {
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds);
}
