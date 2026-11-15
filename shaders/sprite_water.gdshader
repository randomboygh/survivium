// The part of the player under the water surface, tinted with the water's colour,
// more the deeper it lies. Drawn after the water (a higher render priority than the
// water's), which writes no depth, so the body shows through deep water too, while
// walls and banks in front still hide it. A fish (`whole`) is drawn by it all, tinted
// by how deep it swims, over its sprite.gdshader one, which only casts its shadow.
shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"
#include "res://shaders/ice.gdshaderinc"

uniform sampler2D sprite_texture : filter_nearest SRGB_HINT;
// The frame of a sprite sheet to show, as in sprite.gdshader.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Height of the water surface around the body, in world units.
uniform float water_line = -1000.0;
uniform vec3 shallow SRGB = vec3(0.36, 0.62, 0.6);
uniform vec3 deep SRGB = vec3(0.13, 0.29, 0.42);
// 1 for a fish: the whole picture is under the water, the surface as far over its
// origin as the sprite's scale along y goes past 1 (Creatures; undone here, the quad
// keeps its height): an instance uniform reads 0 in the web build.
uniform float whole = 0.0;
// A species' tint, as in sprite.gdshader.
uniform vec3 tint = vec3(1.0);
// How much the water is iced over (as water.gdshader's): a fish under the ice shows faint
// (every other texel, in the ice's colour), clearer under clear ice, as in water under a
// hole (ice.gdshaderinc, IceView).
uniform float ice_amount = 0.0;
// A fish shows as it is down to FISH_CLEAR world units under the surface, then a
// step more in the water's colour each FISH_STEP deeper, FISH_STEPS steps at most.
const float FISH_CLEAR = 0.25;
const float FISH_STEP = 0.35;
const float FISH_STEPS = 3.0;

varying vec3 world_pos;
varying float clouds;
// How much brighter a torch or a fire lights this than sea_bright left its colour (sea_undo).
varying vec3 lamp_gain;

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

// The water surface over this point, in world units (water_line, or a fish's own),
// and how deep a fish swims under it (-1 for the player).
varying float surface;
varying float swim_depth;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	surface = water_line;
	swim_depth = -1.0;
	if (whole > 0.5) {
		float sy = length(MODEL_MATRIX[1].xyz);
		surface = o.y + sy - 1.0;
		swim_depth = sy - 1.0;
		VERTEX.y = o.y + (VERTEX.y - o.y) / sy;
	}
	// Upright: turned to the camera about its origin.
	VERTEX = face_view(VERTEX, o);
	world_pos = VERTEX;
	VERTEX = shear(stand_tall(VERTEX, o));
	light_xz = VERTEX.xz;
}

void fragment() {
	vec2 uv = frame_uv.xy + UV * frame_uv.zw;
	vec4 c = texture(sprite_texture, uv);
	c.rgb *= tint;
	// The texel row along the surface is the ripple line of sprite.gdshader.
	if (c.a < 0.5 || (swim_depth < 0.0 && world_pos.y >= surface)) {
		discard;
	}
	vec3 col;
	if (swim_depth >= 0.0) {
		// A fish: the whole of it as deep as it swims, in FISH_STEPS steps of tint, so
		// the pixel art stays flat; near the surface it shows almost as it is.
		float k = clamp(floor((swim_depth - FISH_CLEAR) / FISH_STEP) + 1.0, 0.0, FISH_STEPS) / FISH_STEPS;
		vec3 water = mix(shallow, deep, 0.3 + 0.6 * k);
		col = mix(c.rgb, water, 0.12 + 0.6 * k);
		if (ice_amount > 0.0 && ice_hole(world_pos.xz) < 1.0) {
			if (ice_clear(world_pos.xz) > 0.5) {
				col = mix(col, vec3(0.4, 0.56, 0.64), 0.3 * ice_amount);
			} else {
				ivec2 px = ivec2(floor(uv * vec2(textureSize(sprite_texture, 0))));
				if (ice_amount > 0.5 && (px.x + px.y) % 2 == 0) {
					discard;
				}
				col = mix(col, vec3(0.46, 0.64, 0.72), 0.65 * ice_amount);
			}
		}
	} else {
		// Two steps of tint: a texel row or more under the surface, then deeper than a
		// cell, so the pixel art stays flat.
		float under = surface - world_pos.y;
		float t = under > CELL ? 1.0 : 0.0;
		vec3 water = mix(shallow, deep, 0.35 + 0.4 * t);
		col = mix(c.rgb, water, 0.45 + 0.2 * t);
	}
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	// The share of the sun's and the sky's light that comes down this deep; light()
	// undoes it for torches and fires (lamp_gain).
	float sun_part = sea_bright(world_pos.y);
	vec3 lit_col = col * (1.0 - veiled.a);
	ALBEDO = lit_col * sun_part;
	lamp_gain = sea_undo(lit_col, sun_part);
	EMISSION = veiled.rgb;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.6, 0.0)).xyz);
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
	COMPAT_COLORS
}

void light() {
	// A sprite stands up in the drawn world, not in the world (stand_tall): its light
	// rings go by the drawn way to the light, only the range undone (light_reach).
	vec3 lit = toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz),
		light_reach);
	DIFFUSE_LIGHT += LIGHT_IS_DIRECTIONAL ? compat_sun(lit, ALBEDO) : lit * lamp_gain;
}
