// Shared by every 3D shader of the world.
//
// Oblique 3/4 view: the camera looks straight down, and each vertex is moved north by
// its height (z -= y). On screen a cell's top and its south wall are then both exactly
// 16x16 pixels, like a classic 2D 3/4 tile, while depth, shadows and lights still work
// on real 3D geometry. Shaders keep the unsheared position in `world_pos` for the
// cutaway, snow and texel maths. Godot renders shadow maps with the same vertex
// function, so casters and receivers are sheared alike.

global uniform float cut_height;
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
// Warmth around fires, one texel per cell: r = heat 0..1, g = level of the fire / 64.
global uniform sampler2D heat_map : filter_linear;
global uniform vec2 world_size;

const float TEXELS = 16.0;
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

// Each cell's top uses its tile mirrored one of four ways, so the 16x16 tile does
// not repeat visibly.
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

// Levels below the cut get darker, like looking down into a pit.
float cut_shade(float y) {
	if (cut_height > 999.0) {
		return 1.0;
	}
	return 1.0 - clamp(max(0.0, cut_height - 1.0 - y) * 0.12, 0.0, 0.6);
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
