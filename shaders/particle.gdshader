// Pixel particles (fire, sparks, smoke, rain, snow, fireflies, falling leaves):
// tiny upright squares, coloured by the particle's colour ramp; with a `shape` its
// opaque pixels only (the star sparkles over a death sack).
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_disabled, blend_mix, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform float brightness = 1.0;
// 1 for weather (rain, snow, leaves, pollen, fireflies), which never falls under a
// roof, an overhang or a cave ceiling; 0 for fire, which burns anywhere.
uniform float sky_only = 0.0;
// How lit the open sky is: weather is unshaded, so it dims with the night.
uniform float light = 1.0;
// World units this is drawn farther from the camera in depth alone (the flames of a light
// a hand holds behind the body, Effects.flame_behind, so the body hides them).
uniform float behind = 0.0;
// How much the fog on the ground veils this, 0..1: smoke fully, a fire's or a torch's
// flames and sparks half (they burn inside the fog, but their own light shines through
// it: fully veiled, a fire at night faded to a grey smudge), the rest (weather, falling
// through the air above the fog) not at all.
uniform float fogged = 0.0;
uniform sampler2D shape : filter_nearest, hint_default_white SRGB_HINT;
// World units a streak's top lies upwind of its foot per unit of height:
// rain driven by the wind leans along its fall (see Effects.rain_lean).
uniform vec2 lean = vec2(0.0);
// A `shape` of `frames` pictures side by side and `rows` rows of them (falling leaves, each
// turning over as it flutters down, TreeHits): row `row` drawn, each particle starting at a
// frame of its own (its random animation offset) and going on `flips` frames over its life.
uniform int frames = 1;
uniform int rows = 1;
uniform int row = 0;
uniform float flips = 0.0;

varying vec3 world_pos;
varying flat float frame;

void vertex() {
	// Upright: turned to the camera about its origin.
	VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	VERTEX.xz -= lean * (VERTEX.y - MODEL_MATRIX[3].y);
	world_pos = VERTEX;
	VERTEX = shear(stand_tall(VERTEX, MODEL_MATRIX[3].xyz));
	frame = frames > 1 ? mod(floor(INSTANCE_CUSTOM.z * float(frames) + INSTANCE_CUSTOM.y * flips), float(frames)) : 0.0;
	// `behind`: the clip depth of a point that much farther along the view, its place on the
	// screen kept (an orthogonal view only). Written in every case: a shader that writes
	// POSITION anywhere gets no position of Godot's own.
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(VERTEX, 1.0));
	if (PROJECTION_MATRIX[3][3] > 0.5) {
		POSITION.z -= PROJECTION_MATRIX[2][2] * behind * POSITION.w;
	}
}

void fragment() {
	if (gone_above(world_pos) || COLOR.a < 0.02) {
		discard;
	}
	if (sky_only > 0.5 && roofed(world_pos.xz, world_pos.y)) {
		discard;
	}
	vec4 s = texture(shape, (UV + vec2(frame, float(row))) / vec2(float(frames), float(rows)));
	if (s.a < 0.5) {
		discard;
	}
	ALBEDO = COLOR.rgb * s.rgb * brightness * light;
	if (fogged > 0.0) {
		vec4 veiled = veil(world_pos, depth_fade(world_pos.y)) * fogged;
		ALBEDO = ALBEDO * (1.0 - veiled.a) + veiled.rgb;
	}
	ALPHA = COLOR.a;
	COMPAT_ALBEDO
}
