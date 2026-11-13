// Footprints: small flat quads laid on the ground behind people and animals, which
// darken whatever is under them (multiplied in), so they read as dents in snow, mud
// or trampled grass alike, and fade away by dithering as they age; the fog and the levels
// below fading out hide them as they hide the ground.
// COLOR: tint multiplied into the ground (bluish on snow, brownish on soil).
// INSTANCE_CUSTOM: x = the clock when the print was made, y = its life in seconds,
// z = 1 for a boot (two texels wide, three long) or 0 for a paw (two by two),
// w = 1 for a left foot, which puts the toe of a boot on the other side.
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mul, depth_draw_never, cull_disabled;

#include "res://shaders/common.gdshaderinc"

// The game's clock in seconds, wrapping at 2048 like the stamps (see Tracks.WRAP).
uniform float now = 0.0;

varying vec3 world_pos;
varying flat vec4 custom;
varying flat vec4 tint;

void vertex() {
	world_pos = VERTEX;
	custom = INSTANCE_CUSTOM;
	tint = COLOR;
	VERTEX = shear(VERTEX);
}

void fragment() {
	float age = now - custom.x;
	if (age < 0.0) {
		age += 2048.0;
	}
	vec2 texel = floor(screen_plane(world_pos) * TEXELS);
	float left = clamp((custom.y - age) / (custom.y * 0.4), 0.0, 1.0);
	if (left <= 0.0 || bayer4(texel) > left || above_cut(world_pos)) {
		discard;
	}
	// The quad is four texels square; the print sits in its middle two columns.
	ivec2 t = ivec2(floor(UV * 4.0));
	bool on = t.x >= 1 && t.x <= 2;
	if (custom.z > 0.5) {
		// A boot: three rows, the toe row one texel wide.
		on = on && t.y <= 2 && (t.y < 2 || t.x == (custom.w > 0.5 ? 1 : 2));
	} else {
		on = on && t.y >= 1 && t.y <= 2;
	}
	if (!on) {
		discard;
	}
	// Multiplied into the fog over the ground the print would darken the fog itself. It
	// darkens only the ground's share of the pixel: the ground (about 0.3 bright when lit)
	// left by the veil, against the fog's own light added over it.
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	float ground = (1.0 - veiled.a) * 0.3;
	float share = ground / max(ground + dot(veiled.rgb, vec3(0.3, 0.59, 0.11)), 0.001);
	// In a fog, where the fog thins round the player too, a print is half as dark.
	share *= 1.0 - 0.5 * smoothstep(0.0, 0.15, fog > 0.0 ? fog_at(world_pos) : 0.0);
	ALBEDO = mix(vec3(1.0), tint.rgb, share);
	COMPAT_ALBEDO
}
