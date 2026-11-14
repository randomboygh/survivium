// Sunlight among the trees (sun_rays.gd): mode 0 a shaft of light from the instance's
// origin (on its tree's middle plane) down along the light to the ground (COLOR: width,
// height over the ground, phase, strength), drawn as a band across the view that ends
// where it meets the ground; mode 1 a fleck of sun on the
// ground (COLOR: size, -, phase, strength). Light added to the picture, in a few
// dithered steps like the rest of the light.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform int mode = 0;
uniform float amount = 0.0;
uniform vec3 light_color SRGB = vec3(1.0, 0.95, 0.8);
// The way the light runs, down to the ground.
uniform vec3 light_down = vec3(0.0, -1.0, 0.0);
// World units a shaft is drawn nearer the camera than it is: little, so the leaves of
// its crown in front of it hide it and it shows coming out of the crown.
uniform float depth_lift = 0.4;

varying vec2 band;
varying float phase;
varying float strength;
// How long the shaft is, in world units.
varying float span;
varying vec3 world_pos;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 q = (VERTEX - o).xy;
	phase = COLOR.b;
	strength = COLOR.a;
	band = vec2(q.x + 0.5, q.y);
	if (mode == 0) {
		span = COLOR.g / max(-light_down.y, 0.05);
		vec3 bottom = o + light_down * span;
		vec3 a = shear(o);
		vec3 b = shear(bottom);
		vec2 run = normalize(b.xz - a.xz);
		vec2 across = vec2(-run.y, run.x) * q.x * COLOR.r;
		world_pos = mix(o, bottom, q.y);
		// Lifted a little towards the camera (only in depth: the camera looks straight
		// down), so the ground it ends on does not cut it.
		VERTEX = vec3(mix(a.x, b.x, q.y) + across.x, mix(a.y, b.y, q.y) + depth_lift, mix(a.z, b.z, q.y) + across.y);
	} else {
		span = 1.0;
		// Drifting a little with the leaves moving in the wind.
		float sway = sin(TIME * 0.7 + phase * 6.28) * 0.04;
		world_pos = o + vec3(q.x * COLOR.r + sway * wind.x, 0.02, (q.y - 0.5) * COLOR.r + sway * wind.y);
		VERTEX = shear(world_pos);
	}
}

void fragment() {
	if (gone_above(world_pos)) {
		discard;
	}
	ivec2 b = ivec2(mod(FRAGCOORD.xy, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float dither = (float(m[b.y * 4 + b.x]) + 0.5) / 16.0;
	float k;
	if (mode == 0) {
		// Soft at the sides, faded in over its first unit inside the crown, ending sharp
		// on the ground; each shaft breathes in its own time.
		float side = 1.0 - abs(band.x * 2.0 - 1.0);
		float along = smoothstep(0.0, 1.0, band.y * span);
		float breathe = 0.6 + 0.4 * sin(TIME * 0.45 + phase * 6.28);
		k = (smoothstep(0.0, 0.25, side) * 0.6 + step(0.6, side) * 0.4) * along * breathe * strength * amount * 0.7;
		// Three steps of light, dithered between them.
		k = floor(k * 12.0 + dither) / 12.0;
	} else {
		// A round fleck that comes and goes as the leaves above move.
		float d = length(band * 2.0 - vec2(1.0));
		float shimmer = smoothstep(0.35, 0.75, 0.5 + 0.5 * sin(TIME * (1.1 + phase) + phase * 6.28));
		// Crisp, in two steps: the middle brighter.
		k = (step(d, 0.9) * 0.6 + step(d, 0.45) * 0.4) * step(0.5, shimmer) * strength * amount * 0.7;
	}
	if (k <= 0.0) {
		discard;
	}
	ALBEDO = light_color * k * (mode == 1 ? vec3(1.0, 0.92, 0.7) : vec3(1.0));
	// No COMPAT_ALBEDO: added to the picture in sRGB on Compatibility, in linear light on Mobile,
	// where the colour as it is adds about as much over the ground's middle tones.
}
