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

const float TEXELS = 16.0;

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

// Levels below the cut get darker, like looking down into a pit.
float cut_shade(float y) {
	if (cut_height > 999.0) {
		return 1.0;
	}
	return 1.0 - clamp(max(0.0, cut_height - 1.0 - y) * 0.12, 0.0, 0.6);
}

// Toon light: a few flat bands instead of smooth shading, hard sun shadows,
// stepped rings around torches and fires.
vec3 toon_light(vec3 normal, vec3 light, vec3 light_color, float attenuation, bool directional, float clouds) {
	float ndl = clamp(dot(normal, light), 0.0, 1.0);
	if (directional) {
		float shadow = mix(0.2, 1.0, step(0.5, attenuation)) * clouds;
		float lit = ndl > 0.55 ? 1.0 : (ndl > 0.2 ? 0.7 : (ndl > 0.02 ? 0.4 : 0.0));
		return light_color * lit * shadow / PI;
	}
	float a = ndl * attenuation;
	float lit = a > 0.45 ? 1.0 : (a > 0.2 ? 0.6 : (a > 0.07 ? 0.3 : 0.0));
	return light_color * lit / PI;
}
