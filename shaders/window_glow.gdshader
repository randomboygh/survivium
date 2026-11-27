// The glass of a window lit from inside (window_glow.gd): the panes' faces that look away
// from the lights in the room glow warm, laid over the glass (bright blue glass by day
// turns warm too, which adding light would only whiten), in a few dithered steps like the
// rest of the light, flickering with the fires behind them.
shader_type spatial;
render_mode world_vertex_coords, unshaded, cull_back, blend_mix, depth_draw_never, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

// How strongly the panes glow, 0 none (set by window_glow.gd as the room and the night go).
uniform float amount = 0.0;
// Where the lights in the room stand, weighted by their strength (world units).
uniform vec3 source = vec3(0.0);
// How much of the light is a fire's (it flickers), 0..1.
uniform float flicker = 0.0;
// A number of the window's own, so windows side by side flicker apart.
uniform float seed = 0.0;
uniform vec3 glow_color SRGB = vec3(1.0, 0.8, 0.42);
// World units a pane is drawn nearer the camera than the glass under it, so it is not
// lost in the glass's own depth (the camera looks straight down: only the depth moves).
uniform float depth_lift = 0.01;

varying vec3 world_pos;
varying float facing;
// Where it is in the picture, sheared (see light_texel): the dither is held to the
// world's texels, so it does not crawl as the camera moves.
varying vec2 sheared_xz;

void vertex() {
	world_pos = VERTEX;
	// Out of the room: the face looks the way from the lights to the glass.
	vec3 out_way = VERTEX - source;
	out_way.y = 0.0;
	facing = dot(normalize(NORMAL), normalize(out_way + vec3(1e-4, 0.0, 0.0)));
	VERTEX = shear(VERTEX);
	sheared_xz = VERTEX.xz;
	VERTEX.y += depth_lift;
}

void fragment() {
	if (facing < 0.3 || gone_above(world_pos) || above_build_cut(world_pos)) {
		discard;
	}
	float dither = bayer4(light_texel(sheared_xz));
	float t = TIME * 7.0 + seed * 13.0;
	float wave = 0.6 * sin(t) + 0.3 * sin(t * 2.3 + 1.1) + 0.1 * sin(t * 5.7 + 2.9);
	float k = amount * (1.0 - flicker * 0.18 * (0.5 + 0.5 * wave));
	// Six steps of light, dithered between them.
	k = floor(k * 6.0 + dither) / 6.0;
	if (k <= 0.0) {
		discard;
	}
	ALBEDO = glow_color;
	ALPHA = k;
	COMPAT_ALBEDO;
}
