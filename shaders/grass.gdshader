// Ground plants standing on the ground (MultiMesh, see foliage.gd and
// PixelTextures.build_plants): grass tufts coloured from the ground texture under them,
// lighter at the tips, in three tiers (low, the ordinary tufts, tall meadow grass), and
// plants in their own colours: flowers, ears of dry grass, reeds and low herbs, moss and
// mushrooms in the shade of the crowns, glowing mushrooms that shine at night with
// spores rising from them (single texels carried up, see foliage.gd). Tips
// sway with the wind in whole pixels and bend away from the player; a tall meadow
// waves as one. Tufts sink under snow; the ordinary tufts are thinned by the ground
// patches (see ground_patch), flowers show on the lush patches, reeds stand at the
// water, and all of them stand up again around fires.
// INSTANCE_CUSTOM: x = plant 0..28, y = brightness, z = sway phase and thinning draw.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
// Grass, flowers and ears are low: the player's silhouette does not show behind them
// (see sprite_xray).
stencil_mode write, compare_always, 2;

#include "res://shaders/common.gdshaderinc"

global uniform sampler2D terrain_atlas : source_color, filter_nearest;
uniform sampler2D plant_texture : filter_nearest;
// 0 by day, 1 at night (sky.gd): how much the glowing mushrooms shine.
global uniform float night_glow;

const float WIDTH = 0.5;
const float HEIGHT = 1.5;
// Plants in the texture: the engine's 29 and the mods' own after them (main.gd).
uniform float plant_count = 29.0;
const int GRASS_TOP = 3;
// Kinds of plant by their index in the texture.
const int GRASS = 0;
const int FLOWER = 1;
const int EAR = 2;
const int REED = 3;
const int HERB = 4;
const int LOW = 5;
const int TALL = 6;
const int MOSS = 7;
const int MUSHROOM = 8;
const int GLOW = 9;
const int SPORE = 10;
const int HALO = 11;
// The mods' own plants (Grass.CUSTOM), drawn as their pictures are.
const int CUSTOM = 12;
// A halo's card is this much larger than the others (foliage.gd scales it).
const float HALO_SCALE = 2.5;
const vec3 GLOW_COLOR = vec3(0.35, 0.95, 0.8);
// How long a spore takes to rise and how high it goes, in seconds and world units.
const float SPORE_TIME = 9.0;
const float SPORE_RISE = 1.1;

varying vec3 root;
varying flat vec3 custom;
varying flat float snow_here;
varying flat float sky;
varying flat int kind;
varying float clouds;
// How far a spore is through its rise, 0..1.
varying flat float life;

int kind_of(int plant) {
	if (plant >= 30) {
		return CUSTOM;
	}
	if (plant >= 22) {
		return plant < 24 ? MOSS : (plant < 26 ? MUSHROOM : (plant < 28 ? GLOW : (plant < 29 ? SPORE : HALO)));
	}
	return plant < 4 ? GRASS : (plant < 8 ? FLOWER : (plant < 10 ? EAR : (plant < 12 ? REED : (plant < 14 ? HERB : (plant < 18 ? LOW : TALL)))));
}

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;
// Where the point is drawn (sheared), to tell which light shines on it (light_hidden).
varying vec3 drawn;

void vertex() {
	custom = INSTANCE_CUSTOM.xyz;
	kind = kind_of(int(custom.x + 0.5));
	root = VERTEX - vec3((UV.x - 0.5) * WIDTH, (1.0 - UV.y) * HEIGHT, 0.0) * (kind == HALO ? HALO_SCALE : 1.0);
	// The quad is as tall as the tall grass; the other plants fill two thirds of it, so
	// their tips bend as far as tall tips do.
	float tip = (1.0 - UV.y) * (kind == TALL ? 1.0 : 1.5);
	// Moss and mushrooms are too stiff to sway.
	if (kind >= MOSS) {
		tip = 0.0;
	}
	// Tall blades keep nearly the same phase as their neighbours, so the wind runs
	// over a meadow in waves, and they bend farther.
	float phase = kind == TALL ? custom.z * 1.2 : custom.z * 6.28;
	float reach = kind == TALL ? 1.7 : 1.0;
	float sway = sin(TIME * 1.6 + root.x * 0.9 + root.z * 0.5 + phase) * (0.6 + length(wind) * 1.2) * reach + wind.x * 1.5 * reach;
	vec2 away = root.xz - player_pos.xz;
	float d = length(away);
	if (d < 0.6 && abs(root.y - player_pos.y) < 0.6) {
		sway += sign(away.x + 0.001) * 2.0 * (1.0 - d / 0.6) + 0.5 * sign(away.x);
	}
	VERTEX.x += round(sway) / TEXELS * tip;
	// A wind from the north or the south lays the tips over that way a little.
	VERTEX.z += round(wind.y * 1.2 * reach) / TEXELS * tip;
	// Plants under a roof or an overhang see no snow and no rain.
	sky = roofed(root.xz, root.y) ? 0.0 : 1.0;
	snow_here = sky * snow_amount * (1.0 - warm_spot(root, custom.z));
	// Tufts and herbs sink under the snow, reeds and ears poke out of it.
	float sink = kind == REED ? 0.3 : (kind == EAR ? 0.5 : 0.9);
	VERTEX.y = root.y + (VERTEX.y - root.y) * (1.0 - snow_here * sink);
	life = 0.0;
	if (kind == SPORE) {
		// A spore drifts up from its mushroom, wavering, and starts again from it.
		life = fract(TIME / SPORE_TIME + custom.z * 7.3);
		float t = TIME * 0.7 + custom.z * 40.0;
		VERTEX += vec3(round(sin(t) * 2.0 * life) / TEXELS, life * SPORE_RISE, round(cos(t * 0.8) * 1.5 * life) / TEXELS);
	}
	VERTEX = shear(stand_tall(face_view(VERTEX, root), root));
	light_xz = VERTEX.xz;
	drawn = VERTEX;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 cell = vec2(float(int(custom.x + 0.5)) * 8.0, 0.0);
	vec4 m = texture(plant_texture, (cell + UV * vec2(8.0, 24.0)) / vec2(8.0 * plant_count, 24.0));
	// Plants are too small to show above the cut (in the open cave view, only in front
	// of the player). (A halo is drawn without the texture.)
	if ((m.a < 0.5 && kind != HALO) || gone_above(root)) {
		discard;
	}
	float patch = ground_patch(root.xz, 0.0);
	bool bare = bare_ground(root.xz) > 0.5;
	vec3 col;
	if (kind == GRASS || kind == LOW || kind == TALL) {
		// No tufts on bare spots, except that a tall meadow grows over them. The
		// ordinary tufts are thinned by the patch, about half of them on a plain
		// meadow, so the ground shows between them; low and tall grass is placed by
		// its tier and stays as placed.
		if ((bare && kind != TALL) || snow_here > 0.85 || (kind == GRASS && custom.z > patch * 1.1 - 0.05)) {
			discard;
		}
		ivec2 t = tile_mirror(ivec2(floor(fract(root.xz) * TEXELS)), floor(root.xz));
		vec3 ground = texture(terrain_atlas, atlas_uv(GRASS_TOP, vec2(t))).rgb;
		// Tall blades run from a shaded base to a lit tip.
		float light = kind == TALL ? mix(0.7, 1.22, m.r) : mix(0.8, 1.18, m.r);
		col = ground * grass_tint * grass_variation(root.xz) * light * custom.y;
	} else if (kind == FLOWER) {
		// Flowers bloom on the lush patches and are gone under the first snow.
		if (bare || patch < 0.5 || snow_here > 0.3) {
			discard;
		}
		col = m.rgb * custom.y;
	} else if (kind == EAR) {
		// Ears are placed in fields on fertile ground (foliage.gd) and poke out of
		// the early snow.
		if (bare || snow_here > 0.6) {
			discard;
		}
		col = m.rgb * custom.y;
	} else if (kind == REED) {
		if (snow_here > 0.95) {
			discard;
		}
		col = m.rgb * mix(vec3(1.0), grass_tint, 0.5) * custom.y;
	} else if (kind == MOSS) {
		if (snow_here > 0.6) {
			discard;
		}
		col = m.rgb * mix(vec3(1.0), grass_tint, 0.4) * custom.y;
	} else if (kind == CUSTOM) {
		if (snow_here > 0.6) {
			discard;
		}
		col = m.rgb * custom.y;
	} else if (kind == MUSHROOM || kind == GLOW) {
		// Mushrooms are gone under the snow.
		if (snow_here > 0.4) {
			discard;
		}
		col = m.rgb * custom.y * (kind == GLOW ? 0.7 : 1.0);
	} else if (kind == SPORE) {
		// Spores only show in the dark, and are gone near the top of their rise.
		if (night_glow < 0.3 || life > 0.92 || snow_here > 0.4) {
			discard;
		}
		col = vec3(0.0);
	} else if (kind == HALO) {
		// A soft round glow about the glowing mushrooms at night, dithered thinner
		// toward its edge. The dither goes by the texels of the card, not of the
		// screen, so it moves with the glow instead of crawling over it as the camera
		// moves.
		vec2 p = floor(vec2((UV.x - 0.5) * 8.0, (1.0 - UV.y) * 24.0) * HALO_SCALE);
		float k = max(1.0 - length(p + vec2(0.5, -2.5)) / 9.0, 0.0);
		k = k * k * night_glow;
		if (k <= 0.0 || snow_here > 0.4 || bayer4(p + 64.0) > k * 1.2) {
			discard;
		}
		col = vec3(0.0);
	} else {
		if (bare || snow_here > 0.85) {
			discard;
		}
		col = m.rgb * grass_tint * custom.y;
	}
	col *= 1.0 - 0.3 * sky * wetness * (1.0 - 0.7 * warm_spot(root, custom.z));
	vec4 veiled = veil(vec3(root.x, root.y + (1.0 - UV.y) * HEIGHT, root.z), depth_fade(root.y));
	ALBEDO = col * (1.0 - veiled.a);
	EMISSION = veiled.rgb;
	if (kind == GLOW) {
		// The caps (green well above red) glow at night, breathing slowly.
		float cap = clamp((m.g - m.r) * 2.5, 0.0, 1.0);
		EMISSION += m.rgb * cap * night_glow * (2.6 + 0.6 * sin(TIME * 1.1 + custom.z * 6.28)) * (1.0 - veiled.a);
	} else if (kind == SPORE) {
		EMISSION += m.rgb * night_glow * custom.y * 3.0 * (1.0 - life * 0.6);
	} else if (kind == HALO) {
		EMISSION += GLOW_COLOR * custom.y * 0.6 * (1.0 - veiled.a);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(root);
}

void light() {
	// A plant is a flat card standing in the light with a normal pointing up: a fire
	// lights all of it, tip too, even where the tip stands higher than the flame.
	vec3 normal = LIGHT_IS_DIRECTIONAL ? NORMAL : LIGHT;
	// The plant stands up in the drawn world (stand_tall): its light rings go by the way
	// from its foot to the light in the world where that light is known (light_spots),
	// so they match the ground's; else by the drawn way.
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz);
	float stretch = light_reach;
	int spot = LIGHT_IS_DIRECTIONAL ? -1 : light_spot(drawn, dir);
	if (spot >= 0) {
		vec4 s = texelFetch(light_spots, ivec2(spot, 0), 0);
		stretch = distance(root, s.xyz) / s.w / max(light_share(ATTENUATION), 1e-4);
	}
	vec3 lit = toon_light(normal, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz),
		stretch);
	// None where a block stands between the plant's foot and the light, like the
	// ground it grows on.
	if (spot >= 0 && lit != vec3(0.0) && light_blocked(spot, root + vec3(0.0, 0.1, 0.0))) {
		lit = vec3(0.0);
	}
	DIFFUSE_LIGHT += lit;
}
