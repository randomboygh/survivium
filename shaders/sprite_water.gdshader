// The part of the player under the water surface, tinted with the water's colour,
// more the deeper it lies. Drawn after the water (a higher render priority than the
// water's), which writes no depth, so the body shows through deep water too, while
// walls and banks in front still hide it.
shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D sprite_texture : source_color, filter_nearest;
// The frame of a sprite sheet to show, as in sprite.gdshader.
uniform vec4 frame_uv = vec4(0.0, 0.0, 1.0, 1.0);
// Height of the water surface around the body, in world units.
uniform float water_line = -1000.0;
uniform vec3 shallow : source_color = vec3(0.36, 0.62, 0.6);
uniform vec3 deep : source_color = vec3(0.13, 0.29, 0.42);

varying vec3 world_pos;
varying float clouds;

// Where the point is in the picture, for the dither of the light rings (light_texel).
varying vec2 light_xz;

void vertex() {
	// Upright: turned to the camera about its origin.
	VERTEX = face_view(VERTEX, MODEL_MATRIX[3].xyz);
	world_pos = VERTEX;
	VERTEX = shear(stand_tall(VERTEX, MODEL_MATRIX[3].xyz));
	light_xz = VERTEX.xz;
}

void fragment() {
	vec2 uv = frame_uv.xy + UV * frame_uv.zw;
	vec4 c = texture(sprite_texture, uv);
	// The texel row along the surface is the ripple line of sprite.gdshader.
	if (c.a < 0.5 || world_pos.y >= water_line) {
		discard;
	}
	// Two steps of tint: a texel row or more under the surface, then deeper than a
	// cell, so the pixel art stays flat.
	float under = water_line - world_pos.y;
	float t = under > CELL ? 1.0 : 0.0;
	vec3 water = mix(shallow, deep, 0.35 + 0.4 * t);
	vec3 col = mix(c.rgb, water, 0.45 + 0.2 * t);
	vec4 veiled = veil(world_pos, depth_fade(world_pos.y));
	ALBEDO = col * (1.0 - veiled.a);
	EMISSION = veiled.rgb;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.6, 0.0)).xyz);
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	clouds = cloud_light(world_pos);
}

void light() {
	// A sprite stands up in the drawn world, not in the world (stand_tall): its light
	// rings go by the drawn way to the light, only the range undone (light_reach).
	DIFFUSE_LIGHT += toon_light(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL, clouds, light_texel(light_xz),
		light_reach);
}
