// Sunlight among the trees (sun_rays.gd): mode 0 a shaft of light from the instance's
// origin (on its tree's middle plane) down along the light to the ground (COLOR: width,
// height over the ground, phase, strength), drawn as a band across the view that fades
// away as it nears the ground; mode 1 the fleck of sun where a shaft meets the ground,
// in its crown's shadow (COLOR: the shaft's width, -, phase, strength), stretched along
// the light as a slanting shaft's patch is, and breathing with its shaft. Light added to
// the picture, in a few dithered steps like the rest of the light, the dither held to the
// world's texels (light_texel) so it does not crawl as the camera moves. New light
// dissolves in texel by texel while the old dissolves out (`fade`, `fade_out`).
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
// How far the new light has dissolved in, 0..1: drawn where a texel's dither is under it,
// or, for the old light going (`fade_out`), where it is not.
uniform float fade = 1.0;
uniform bool fade_out = false;

varying vec2 band;
// A fleck's size to its shaft's width.
const float FLECK_SIZE = 0.7;

varying float phase;
varying float strength;
// How long the shaft is, in world units.
varying float span;
varying vec3 world_pos;
// Where it is in the picture, sheared (see light_texel).
varying vec2 sheared_xz;

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
		vec2 side_way = vec2(-run.y, run.x);
		// The leaves moving in the wind: each shaft grows wider and narrower and shifts a
		// little, slowly, the shafts of a bunch (close phases) nearly together.
		float t = TIME + phase * 37.0;
		float widen = 0.8 + 0.2 * sin(t * 0.37) + 0.08 * sin(t * 0.61 + 1.7);
		float shift = (0.06 * sin(t * 0.29 + 0.6) + 0.03 * sin(t * 0.53)) * (1.0 - 0.5 * q.y);
		vec2 across = side_way * (q.x * COLOR.r * widen + shift);
		world_pos = mix(o, bottom, q.y);
		// Lifted a little towards the camera (only in depth: the camera looks straight
		// down), so the ground it ends on does not cut it.
		VERTEX = vec3(mix(a.x, b.x, q.y) + across.x, mix(a.y, b.y, q.y) + depth_lift, mix(a.z, b.z, q.y) + across.y);
		sheared_xz = VERTEX.xz;
	} else {
		span = 1.0;
		// The shaft's patch on the ground: a little narrower than the shaft (FLECK_SIZE),
		// longer along the light the lower the sun; wider and narrower, and shifting,
		// with its shaft.
		vec2 level_way = vec2(light_down.x, light_down.z);
		vec2 run = length(level_way) > 0.01 ? normalize(level_way) : vec2(0.0, 1.0);
		vec2 side_way = vec2(-run.y, run.x);
		float stretch = 1.0 / max(sqrt(1.0 - dot(level_way, level_way)), 0.4);
		float t = TIME + phase * 37.0;
		float widen = 0.8 + 0.2 * sin(t * 0.37) + 0.08 * sin(t * 0.61 + 1.7);
		float shift = 0.5 * (0.06 * sin(t * 0.29 + 0.6) + 0.03 * sin(t * 0.53));
		float size = COLOR.r * widen * FLECK_SIZE;
		vec2 at = side_way * (q.x * size + shift) + run * ((q.y - 0.5) * size * stretch);
		world_pos = o + vec3(at.x, 0.02, at.y);
		VERTEX = shear(world_pos);
		sheared_xz = VERTEX.xz;
	}
}

void fragment() {
	if (gone_above(world_pos)) {
		discard;
	}
	vec2 texel = light_texel(sheared_xz);
	if (fade < 1.0 && (bayer4(texel + vec2(1.0, 3.0)) < fade) == fade_out) {
		discard;
	}
	float dither = bayer4(texel);
	float k;
	if (mode == 0) {
		// Soft at the sides, faded in over its first unit inside the crown and away over
		// its lower part, gone as it meets the ground (its fleck lights the ground there);
		// each shaft grows paler and brighter, slowly, as the leaves move.
		float side = 1.0 - abs(band.x * 2.0 - 1.0);
		float along = smoothstep(0.0, 1.0, band.y * span) * (1.0 - smoothstep(0.3, 0.95, band.y));
		float t = TIME + phase * 37.0;
		float breathe = 0.65 + 0.25 * sin(t * 0.41 + 0.9) + 0.1 * sin(t * 0.73 + 2.3);
		// Low contrast: mostly the soft part, a little brighter in the middle.
		k = (smoothstep(0.0, 0.4, side) * 0.75 + step(0.6, side) * 0.25) * along * breathe * strength * amount * 0.55;
		// Three steps of light, dithered between them.
		k = floor(k * 12.0 + dither) / 12.0;
	} else {
		// A patch of sun at the end of its shaft, paler and brighter with it: crisp, of
		// a ragged shape of its own (the gap in the leaves), the middle a step brighter.
		vec2 v = band * 2.0 - vec2(1.0);
		float a = atan(v.y, v.x);
		float d = length(v) * (1.0 + 0.22 * sin(3.0 * a + phase * 6.28) + 0.13 * sin(5.0 * a + phase * 17.0));
		float t = TIME + phase * 37.0;
		float breathe = 0.65 + 0.25 * sin(t * 0.41 + 0.9) + 0.1 * sin(t * 0.73 + 2.3);
		k = (step(d, 0.8) * 0.65 + step(d, 0.45) * 0.35) * breathe * strength * amount * 0.85;
		k = floor(k * 8.0 + 0.5) / 8.0;
	}
	if (k <= 0.0) {
		discard;
	}
	ALBEDO = light_color * k * (mode == 1 ? vec3(1.0, 0.92, 0.7) : vec3(1.0));
	// No COMPAT_ALBEDO: added to the picture in sRGB on Compatibility, in linear light on Mobile,
	// where the colour as it is adds about as much over the ground's middle tones.
}
