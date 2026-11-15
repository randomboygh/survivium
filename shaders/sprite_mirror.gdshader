// A figure mirrored in the water it stands by (WaterEffects): its sprite turned upside
// down under the surface, as pale as a reflection, rippling a pixel sideways row by
// row, fading with the depth. Drawn after the water and over the body's part under it
// (render priority 2), with no depth test: a pixel shows only where the water's surface
// that this pixel of the picture falls on is open water at the mirror's level, or the
// wet edge of the bank beside it (the roof map's columns), so the banks and the land in
// front keep it off. Unshaded: it takes the sky's light (`light`).
shader_type spatial;
render_mode world_vertex_coords, unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : filter_nearest SRGB_HINT;
// The frame of a sprite sheet to show, as in sprite.gdshader, and the animal's tint.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 tint = vec3(1.0);
// The water's surface the figure is mirrored in, world units.
uniform float level = -1000.0;
uniform float light = 1.0;
uniform vec3 water SRGB = vec3(0.3, 0.52, 0.58);

varying vec3 world_pos;
// The point as it is drawn (stand_tall), not sheared.
varying vec3 tall;

void vertex() {
	VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	world_pos = VERTEX;
	tall = stand_tall(VERTEX, MODEL_MATRIX[3].xyz);
	VERTEX = shear(tall);
}

// Whether the surface at `xz` shows the mirror: open water at the level, or the ground
// at the water's edge level with it (the foam on the sand, a bank half under water)
// with water beside it.
bool mirrors(vec2 xz) {
	vec2 c = floor(xz / CELL);
	vec4 col = column(c);
	float top = floor(col.b * 255.0 + 0.5) * CELL;
	if (col.a > 0.5) {
		return abs(top - level) <= 0.6;
	}
	if (abs(top - CELL * 0.5 - level) > 0.1) {
		return false;
	}
	return column(c + vec2(1.0, 0.0)).a > 0.5 || column(c - vec2(1.0, 0.0)).a > 0.5
		|| column(c + vec2(0.0, 1.0)).a > 0.5 || column(c - vec2(0.0, 1.0)).a > 0.5;
}

void fragment() {
	if (world_pos.y > level) {
		discard;
	}
	// The surface this pixel of the picture falls on: along the way to the camera from
	// the drawn point, up to the level.
	vec3 to = toward_camera();
	vec3 surface = tall + to * ((level - tall.y) / max(to.y, 0.05));
	if (!mirrors(surface.xz) || gone_above(surface)) {
		discard;
	}
	float depth = level - world_pos.y;
	// Rows of two texels wave a texel sideways, slowly.
	float row = floor(depth * TEXELS / 2.0);
	vec2 px = 1.0 / vec2(textureSize(sprite_texture, 0));
	float wave = floor(sin(row * 1.7 + TIME * 2.2) * 0.9 + 0.5);
	vec2 uv = frame_uv.xy + UV * frame_uv.zw + vec2(wave * px.x, 0.0);
	vec4 c = texture(sprite_texture, uv);
	if (c.a < 0.5) {
		discard;
	}
	vec3 rgb = mix(c.rgb * tint * 0.9, water, 0.4) * light;
	ALBEDO = rgb;
	// Fainter the deeper, dithered in steps so it stays pixel art.
	float a = 0.45 * (1.0 - smoothstep(0.3, 1.6, depth));
	ALPHA = a < bayer4(floor(surface.xz * TEXELS)) * 0.3 ? 0.0 : a;
	COMPAT_ALBEDO
}
