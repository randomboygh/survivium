// Footprints: small flat quads laid on the ground behind people and animals, which
// darken whatever is under them (multiplied in), so they read as dents in snow, mud
// or trampled grass alike, and fade away by dithering as they age.
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
	vec2 texel = floor(vec2(world_pos.x, world_pos.z - world_pos.y) * TEXELS);
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
	ALBEDO = tint.rgb;
}
