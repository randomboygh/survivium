// Shared by every 3D shader of the world.
//
// Oblique 3/4 view: the camera looks straight down, and each vertex is moved north by
// its height (z -= y). On screen a cell's top and its south wall are then both exactly
// 8x8 pixels, like a classic 2D 3/4 tile, while depth, shadows and lights still work
// on real 3D geometry. Shaders keep the unsheared position in `world_pos` for the
// cutaway, snow and texel maths. Godot renders shadow maps with the same vertex
// function, so casters and receivers are sheared alike.

global uniform float cut_height;
// 1 when the cut follows the player under a roof and what lies above shows as a ghost,
// 0 when the player moved the cut by hand to look at the levels below.
global uniform float cut_ghost;
global uniform float snow_amount;
global uniform float wetness;
global uniform vec3 foliage_tint;
global uniform vec3 grass_tint;
global uniform vec2 wind;
global uniform vec2 cloud_offset;
global uniform float cloud_cover;
global uniform vec3 player_pos;
// 1 in leaf, falls to a few leaves in winter.
global uniform float leaf_amount;
// How many fallen leaves lie under the crowns, 0..1 (see sky.gd).
global uniform float leaf_litter;
global uniform sampler2D cloud_noise : filter_linear, repeat_enable;
// Warmth around fires, one texel per world unit: r = heat 0..1, g = height of the
// fire's unit / 64.
global uniform sampler2D heat_map : filter_linear, repeat_enable;
// One texel per column: r = the level of the highest cell that keeps the weather off,
// plus one, over 255; g = 1 under a tree's crown (see roof_map.gd).
global uniform sampler2D roof_map : filter_nearest, repeat_enable;
// The world has no edge: the heat and roof maps repeat every wrap_size world units.
global uniform vec2 wrap_size;
// Height of the ground the player last stood on, and what the levels far below it
// fade into (the background outdoors, darkness in a cave or a room), see depth_fade.
global uniform float view_height;
global uniform vec3 depth_haze;
// Fog lying on the ground (see Sky._update_fog): how thick it is (0 none), how deep
// above the ground in the low places, its colour, how far its banks have drifted with
// the wind, and the height of the sea's surface (the lowest land).
global uniform float fog;
global uniform float fog_depth;
global uniform vec3 fog_color;
global uniform vec2 fog_drift;
global uniform float fog_sea;
// Puddles after rain: x how much water stands (0 dry .. 1 after a long rain), y how
// hard it rains on them now.
global uniform vec2 puddles;

// Texels per world unit, and per cell (a cell is half a unit, see WorldData.CELL).
// Texture tiles are 16x16 and span two cells.
const float TEXELS = 16.0;
const float CELL = 0.5;
const float CELL_TEXELS = 8.0;
// Rings of light around a torch or a fire: outer edges as shares of the light's range,
// 1, 2, 3 and 5 parts of 5 (Fibonacci), and how bright each ring is.
const vec4 LIGHT_RING_EDGES = vec4(0.2, 0.4, 0.6, 1.0);
const vec4 LIGHT_RING_LEVELS = vec4(1.0, 0.55, 0.3, 0.14);
// The edges between the rings are dithered over this share of the range on either
// side, so the light falls off smoothly in whole texels.
const float LIGHT_RING_DITHER = 0.05;
// The least a face gets of the sun or the moon: what level ground gets in a shadow.
const float SHADOW_FLOOR = 0.14;

vec3 shear(vec3 p) {
	return vec3(p.x, p.y, p.z - p.y);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

// Share of its leaves a tree still has, by what it does over the year (the alpha of
// its leaf cards' colour, see Foliage): a bare one (0.8) drops them all once winter
// comes, one that keeps them (1) holds most of its dry leaves, evergreens (0.6) keep
// their needles, bushes (below 0.5) go bare like the bare ones.
float leaves_left(float kind) {
	if (kind > 0.5 && kind < 0.7) {
		return 1.0;
	}
	if (kind > 0.7 && kind < 0.9 || kind < 0.5) {
		// The last leaves go between 0.7 and the 0.55 of winter (sooner in a windy
		// autumn, see Clock.leaf_fall).
		return leaf_amount < 0.7 ? max(0.0, leaf_amount - 0.55) / 0.15 * 0.7 : leaf_amount;
	}
	return 0.35 + 0.65 * leaf_amount;
}

// Ordered 4x4 dither: the threshold (0..1) of texel `t`.
float bayer4(vec2 t) {
	ivec2 i = ivec2(mod(t, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i.y * 4 + i.x]) + 0.5) / 16.0;
}

// How bright the rings of a torch or a fire are at `d`, the distance as a share of its
// range, on `texel` of the picture (see light_texel): flat rings with dithered edges.
float light_ring(float d, vec2 texel) {
	d += (bayer4(texel) - 0.5) * 2.0 * LIGHT_RING_DITHER;
	return d < LIGHT_RING_EDGES.x ? LIGHT_RING_LEVELS.x
		: (d < LIGHT_RING_EDGES.y ? LIGHT_RING_LEVELS.y
		: (d < LIGHT_RING_EDGES.z ? LIGHT_RING_LEVELS.z
		: (d < LIGHT_RING_EDGES.w ? LIGHT_RING_LEVELS.w : 0.0)));
}

// The texel of the picture a point is on, from its sheared x and z (VERTEX.xz after
// shear(), kept for light() in a varying): x and z - y of the world in texels.
vec2 light_texel(vec2 sheared_xz) {
	return floor(sheared_xz * TEXELS);
}

// How wide the soft rim of a cloud shadow is, in noise values on each side of its edge.
const float CLOUD_RIM = 0.035;

// Moving cloud shadows: 1 in the sun, lower under a cloud. Sampled per world texel,
// so cloud edges are pixel steps like everything else; the shadow is solid and thins
// out only over a narrow rim by an ordered dither, so its edge reads soft.
float cloud_light(vec3 p) {
	vec2 t = floor(p.xz * TEXELS);
	float n = texture(cloud_noise, (t / TEXELS + cloud_offset) / 96.0).r;
	float edge = 1.0 - cloud_cover;
	float k = clamp((n - edge) / (2.0 * CLOUD_RIM) + 0.5, 0.0, 1.0);
	return mix(1.0, 0.6, step(bayer4(t), k));
}

// Large soft patches of the ground (0..1), the same everywhere a shader asks: bare
// spots and lush islands of grass, damp dirt, dunes, moss, snow drifts. `salt` picks
// an independent pattern. Sampled per world texel so patch edges are pixel steps.
float ground_patch(vec2 xz, float salt) {
	vec2 t = floor(xz * TEXELS) / TEXELS;
	float a = texture(cloud_noise, t / 23.0 + vec2(salt * 0.37, salt * 0.61)).r;
	float b = texture(cloud_noise, t / 7.0 + vec2(salt * 0.71, 0.5 + salt * 0.13)).r;
	// Spread about 0.22 around 0.5: 0.2 and below is the lowest tenth.
	return clamp((a - 0.5) + (b - 0.5) * 0.45 + 0.5, 0.0, 1.0);
}

// 1 where a texel of grass ground is bare dirt: the low spots of the patch noise,
// with a dithered rim.
float bare_ground(vec2 xz) {
	vec2 t = floor(xz * TEXELS);
	return step(ground_patch(xz, 0.0) + (hash12(t) - 0.5) * 0.06, 0.2);
}

// Colour of grass at this spot: darker lush islands and drier yellowish meadows.
vec3 grass_variation(vec2 xz) {
	float lush = ground_patch(xz, 0.0);
	float dry = ground_patch(xz, 3.0);
	vec3 k = vec3(1.0);
	k *= lush > 0.68 ? vec3(0.88, 0.94, 0.9) : (lush < 0.4 ? vec3(1.05, 1.03, 0.96) : vec3(1.0));
	k *= dry > 0.7 ? vec3(1.1, 1.02, 0.78) : vec3(1.0);
	return k;
}

// Each 16x16 tile on the ground (two by two cells) is mirrored one of four ways, so it
// does not repeat visibly.
ivec2 tile_mirror(ivec2 t, vec2 cell) {
	float h = hash12(cell + 71.0);
	if (h < 0.5) {
		t.x = 15 - t.x;
	}
	if (fract(h * 7.31) < 0.5) {
		t.y = 15 - t.y;
	}
	return t;
}

// Warmth of the nearest fire at p: 0 far away, up to 1 next to it.
float heat_at(vec3 p) {
	vec4 h = texture(heat_map, floor(p.xz * TEXELS) / TEXELS / wrap_size);
	return h.r * step(abs(p.y - h.g * 64.0 - 0.5), 2.5);
}

// 1 in the warm circle around a fire where snow melts and rain dries, with a
// dithered rim (`jitter` is a per-texel random number).
// Level of the highest cell over the column at `xz` that keeps rain and snow off,
// -1 when the sky is open all the way down.
float roof_level(vec2 xz) {
	return texture(roof_map, (floor(xz / CELL) + 0.5) * CELL / wrap_size).r * 255.0 - 1.0;
}

// True when the column at `xz` lies under a tree's crown.
bool under_crown(vec2 xz) {
	return texture(roof_map, (floor(xz / CELL) + 0.5) * CELL / wrap_size).g > 0.5;
}

// True at height `y` under a roof, an overhang or a cave ceiling: below the bottom of
// the column's highest covering cell. The faces of that cell itself, its ramps and
// walls included, lie within its span and are not under it.
bool roofed(vec2 xz, float y) {
	return y < roof_level(xz) * CELL - 0.01;
}

float warm_spot(vec3 p, float jitter) {
	return step(0.45 + (jitter - 0.5) * 0.2, heat_at(p));
}

// Texel distance from texel t of a cell's top to the curve of corner k with corner
// shape `shape`, positive toward the middle of the cell: the row of texels on the
// curve is 0 on the middle's side and -1 on the corner's.
int corner_distance(ivec2 t, int k, int shape) {
	int mid = int(CELL_TEXELS) / 2;
	if (shape == 0) {
		return k == 0 ? t.x + t.y + 1 - mid : (k == 1 ? mid - t.x + t.y : (k == 2 ? 3 * mid - 1 - t.x - t.y : mid + t.x - t.y));
	}
	vec2 o = vec2(k == 1 || k == 2 ? 1.0 : -1.0, k >= 2 ? 1.0 : -1.0);
	vec2 uv = max((vec2(t) + 0.5 - float(mid)) * o, vec2(0.0));
	float p = shape == 1 ? 1.5 : 2.0;
	float r = pow(pow(uv.x, p) + pow(uv.y, p), 1.0 / p);
	return int(floor(float(mid) - r + 0.5));
}

// Levels above a cut under a roof stay faintly visible instead of vanishing, so a cave
// or a room shows how much lies above it and how tall the trees around are: the four
// levels over the cut keep every other texel, the next four every fourth, the four
// after that every eighth, and the rest is gone. A level picked by hand grades
// faster, one step per level, so a pit or a cave shows how many levels deep it is:
// the level above the picked one keeps every other texel, the next every fourth,
// then every eighth and sixteenth, and the fifth is gone. Texels are counted on the
// screen plane, so the pattern stays put on the world as the view moves; the player
// always shows through. True where the texel of height `y` at `texel` is left out.
bool cut_dither(float y, vec2 texel) {
	if (y <= cut_height + 0.01) {
		return false;
	}
	// The ghost leaves a clear window around the player.
	vec2 body = vec2(player_pos.x, player_pos.z - player_pos.y - 0.5);
	if (length((texel + 0.5) / TEXELS - body) < 1.75) {
		return true;
	}
	float above = floor((y - cut_height) / CELL - 0.01);
	float band = cut_ghost < 0.5 ? above : floor(above / 4.0);
	return band > (cut_ghost < 0.5 ? 3.5 : 2.5) || bayer4(texel) >= 0.5 / exp2(band);
}

bool above_cut(vec3 p) {
	return cut_dither(p.y, floor(vec2(p.x, p.z - p.y) * TEXELS));
}

// How much of the colour at height `y` gives way to `depth_haze`: levels below the
// player's feet (below the picked level, when one is picked by hand, then in bigger
// steps) fade one even step per level, so a pit or a drop shows its depth, and what
// shows above the cut is a dim ghost, dimmer higher up.
float depth_fade(float y) {
	if (y > cut_height + 0.01) {
		return clamp(0.35 + 0.03 * floor((y - cut_height) / CELL - 0.01), 0.0, 0.7);
	}
	float below = floor((view_height - y) / CELL + 0.01) - 1.0;
	return cut_ghost < 0.5 ? clamp(below * 0.08, 0.0, 0.6) : clamp(below * 0.04, 0.0, 0.5);
}

// The column `col` (whole cells x, z): r the roof (see roof_level), g the crown, b the
// top of the ground or water plus one, a 1 over water (see roof_map.gd).
vec4 column(vec2 col) {
	return texelFetch(roof_map, ivec2(mod(col, wrap_size / CELL)), 0);
}

// The height of the ground (or water) top of the column at `xz` plus `off` columns.
float ground_top(vec2 xz, vec2 off) {
	return floor(column(floor(xz / CELL) + off).b * 255.0 + 0.5) * CELL;
}

// How thick the fog is at `p`, 0..1. It lies on the ground and follows it, deep in the
// low places and over water, a thin layer over the rest, its top rolling in banks that
// drift with the wind. The ground under it is blended between the column centres round
// `p`, a trunk or a wall standing no higher in it than a cell over the lowest of them,
// so the fog goes up their sides; nothing under a roof or in a cave gets any. A little
// thinner round the player, so they can see where they go.
float fog_at(vec3 p) {
	vec2 c = p.xz / CELL - 0.5;
	vec2 f = fract(c);
	vec2 b = floor(c);
	vec4 c00 = column(b);
	vec4 c10 = column(b + vec2(1.0, 0.0));
	vec4 c01 = column(b + vec2(0.0, 1.0));
	vec4 c11 = column(b + vec2(1.0, 1.0));
	vec4 tops = floor(vec4(c00.b, c10.b, c01.b, c11.b) * 255.0 + 0.5) * CELL;
	float lowest = min(min(tops.x, tops.y), min(tops.z, tops.w));
	if (p.y < lowest - CELL * 1.2) {
		return 0.0;
	}
	tops = min(tops, vec4(lowest + CELL));
	vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
	float ground = dot(tops, w);
	float water = dot(vec4(c00.a, c10.a, c01.a, c11.a), w);
	// Low places: below the ground about them, or near the sea's level.
	float around = (ground_top(p.xz, vec2(7.0, 7.0)) + ground_top(p.xz, vec2(-7.0, 7.0))
		+ ground_top(p.xz, vec2(7.0, -7.0)) + ground_top(p.xz, vec2(-7.0, -7.0))) * 0.25;
	float low = clamp((around - ground) / 1.5, 0.0, 1.0);
	low = max(max(low, clamp(1.0 - (ground - fog_sea) / 4.0, 0.0, 1.0) * 0.8), water);
	// Banks: two layers of drifting noise lift and lower the top and thin the fog.
	vec2 q = p.xz + fog_drift;
	float bank = texture(cloud_noise, q / 40.0).r * 0.65 + texture(cloud_noise, q / 13.0 + 0.37).r * 0.35;
	bank = clamp((bank - 0.3) * 2.2, 0.0, 1.0);
	float depth = fog_depth * mix(0.3, 1.0, low) * (0.45 + 0.9 * bank) + 0.15;
	float h = max(p.y - ground, 0.0);
	float m = clamp(1.0 - h / depth, 0.0, 1.0);
	m = m * (2.0 - m) * mix(0.45, 1.0, low) * (0.55 + 0.45 * bank) * fog;
	float near = length(p.xz - player_pos.xz);
	return m * mix(0.6, 1.0, smoothstep(1.0, 4.0, near));
}

// What veils the colour at `p`: the levels below fading away (`fade`, from
// depth_fade) and the fog on the ground, so trunks, walls and the player stand out of
// it and the crowns stay clear.
// rgb is the colour given off in place, a how much of the thing's own colour gives way.
vec4 veil(vec3 p, float fade) {
	if (fog <= 0.0) {
		return vec4(depth_haze * fade, fade);
	}
	float m = min(fog_at(p), 0.85);
	return vec4(depth_haze * fade * (1.0 - m) + fog_color * m, 1.0 - (1.0 - fade) * (1.0 - m));
}

// Toon light: a few flat bands instead of smooth shading, hard sun shadows,
// stepped rings around torches and fires, dithered from one to the next. A cloud does not darken what is already
// in shadow, so cloud and tree shadows merge instead of stacking, and caves (in the
// shadow of the rock above) never see clouds.
vec3 toon_light(vec3 normal, vec3 light, vec3 light_color, float attenuation, bool directional, float clouds,
		vec2 texel) {
	float ndl = clamp(dot(normal, light), 0.0, 1.0);
	if (directional) {
		float shadow = min(mix(0.2, 1.0, step(0.5, attenuation)), clouds);
		// The top band is only reached by slopes facing the sun, never by flat ground.
		float lit = ndl > 0.9 ? 1.12 : (ndl > 0.55 ? 1.0 : (ndl > 0.2 ? 0.7 : (ndl > 0.02 ? 0.4 : 0.0)));
		// A face turned away from a low sun is no darker than ground in a shadow, so
		// the slopes of a terraced shore merge with the shadows beside them instead of
		// cutting black triangles into it.
		return light_color * max(lit * shadow, SHADOW_FLOOR) / PI;
	}
	// Torches and fires have no falloff of their own (omni_attenuation 0), so Godot's
	// attenuation is (1 - (d/r)^4)^2 and gives back the distance d as a share of the
	// range r. The light is cut into flat rings by that distance, each paler and wider
	// than the one inside it.
	float d = sqrt(sqrt(max(1.0 - sqrt(attenuation), 0.0)));
	float lit = light_ring(d, texel);
	// Faces turned away from the light get none, grazing ones a little less.
	float face = ndl > 0.2 ? 1.0 : (ndl > 0.02 ? 0.7 : 0.0);
	return light_color * lit * face / PI;
}
