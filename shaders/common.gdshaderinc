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
global uniform sampler2D cloud_noise : filter_linear, repeat_enable;
// Warmth around fires, one texel per world unit: r = heat 0..1, g = height of the
// fire's unit / 64.
global uniform sampler2D heat_map : filter_linear;
global uniform vec2 world_size;
// Height of the ground the player last stood on, and what the levels far below it
// fade into (the background outdoors, darkness in a cave or a room), see depth_fade.
global uniform float view_height;
global uniform vec3 depth_haze;

// Texels per world unit, and per cell (a cell is half a unit, see WorldData.CELL).
// Texture tiles are 16x16 and span two cells.
const float TEXELS = 16.0;
const float CELL = 0.5;
const float CELL_TEXELS = 8.0;
// Rings of light around a torch or fire before it fades out.
const float LIGHT_RINGS = 7.0;

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
		return leaf_amount < 0.7 ? 0.0 : leaf_amount;
	}
	return 0.35 + 0.65 * leaf_amount;
}

// Moving cloud shadows: 1 in the sun, lower under a cloud. Sampled per world texel,
// so cloud edges are pixel steps like everything else.
float cloud_light(vec3 p) {
	vec2 t = floor(p.xz * TEXELS) / TEXELS;
	float n = texture(cloud_noise, (t + cloud_offset) / 96.0).r;
	float edge = 1.0 - cloud_cover;
	return mix(1.0, 0.6, step(edge, n));
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
	vec4 h = texture(heat_map, floor(p.xz * TEXELS) / TEXELS / world_size);
	return h.r * step(abs(p.y - h.g * 64.0 - 0.5), 2.5);
}

// 1 in the warm circle around a fire where snow melts and rain dries, with a
// dithered rim (`jitter` is a per-texel random number).
float warm_spot(vec3 p, float jitter) {
	return step(0.45 + (jitter - 0.5) * 0.2, heat_at(p));
}

// Ordered 4x4 dither: the threshold (0..1) of texel `t`.
float bayer4(vec2 t) {
	ivec2 i = ivec2(mod(t, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i.y * 4 + i.x]) + 0.5) / 16.0;
}

// Levels above a cut under a roof stay faintly visible instead of vanishing, so a cave
// or a room shows how much lies above it and how tall the trees around are: the four
// levels over the cut keep every other texel, the next four every fourth, the four
// after that every eighth, and the rest is gone. Texels are counted on the screen
// plane, so the pattern stays put on the world as the view moves; the player always
// shows through. A cut moved by hand hides everything above it. True where the texel
// of height `y` at `texel` is left out.
bool cut_dither(float y, vec2 texel) {
	if (y <= cut_height + 0.01) {
		return false;
	}
	if (cut_ghost < 0.5) {
		return true;
	}
	// The ghost leaves a clear window around the player.
	vec2 body = vec2(player_pos.x, player_pos.z - player_pos.y - 0.5);
	if (length((texel + 0.5) / TEXELS - body) < 1.75) {
		return true;
	}
	float band = floor(floor((y - cut_height) / CELL - 0.01) / 4.0);
	return band > 2.5 || bayer4(texel) >= 0.5 / exp2(band);
}

bool above_cut(vec3 p) {
	return cut_dither(p.y, floor(vec2(p.x, p.z - p.y) * TEXELS));
}

// How much of the colour at height `y` gives way to `depth_haze`: levels below the
// player's feet fade one even step per level, so a pit or a drop shows its depth,
// and what shows above the cut is a dim ghost, dimmer higher up.
float depth_fade(float y) {
	if (y > cut_height + 0.01) {
		return clamp(0.35 + 0.03 * floor((y - cut_height) / CELL - 0.01), 0.0, 0.7);
	}
	float below = floor((view_height - y) / CELL + 0.01) - 1.0;
	return clamp(below * 0.04, 0.0, 0.5);
}

// Toon light: a few flat bands instead of smooth shading, hard sun shadows,
// stepped rings around torches and fires. A cloud does not darken what is already
// in shadow, so cloud and tree shadows merge instead of stacking, and caves (in the
// shadow of the rock above) never see clouds.
vec3 toon_light(vec3 normal, vec3 light, vec3 light_color, float attenuation, bool directional, float clouds) {
	float ndl = clamp(dot(normal, light), 0.0, 1.0);
	if (directional) {
		float shadow = min(mix(0.2, 1.0, step(0.5, attenuation)), clouds);
		// The top band is only reached by slopes facing the sun, never by flat ground.
		float lit = ndl > 0.9 ? 1.12 : (ndl > 0.55 ? 1.0 : (ndl > 0.2 ? 0.7 : (ndl > 0.02 ? 0.4 : 0.0)));
		return light_color * lit * shadow / PI;
	}
	// Rings of equal steps in log brightness: tight next to the flame, wider and
	// paler farther out, as the light falls off.
	float a = ndl * attenuation;
	float ring = floor(-log2(max(a, 1e-4)) * 1.25);
	float lit = pow(max(0.0, 1.0 - max(ring, 0.0) / LIGHT_RINGS), 1.4);
	return light_color * lit / PI;
}
